# 03 — Arquitectura del sistema

## 1. Vista general
X-Road Metrics es una colección de módulos (Python, salvo Networking que es R) que recolectan, procesan y presentan los datos de monitoreo operacional de los Security Servers. Hay **dos niveles de privacidad**:

- **Privado (MongoDB):** datos crudos y limpios. Pueden contener direcciones IP y datos personales → solo administradores de la plataforma.
- **Público (PostgreSQL):** datos **anonimizados**, pensados para publicación.

```text
                    PLATAFORMA X-ROAD (existente)
 ┌─────────────┐   config. global    ┌──────────────────┐
 │ Central     │◄────────────────────│                  │
 │ Server      │   (internalconf)    │                  │
 └─────────────┘                     │     COLLECTOR    │
 ┌─────────────┐  getSecurityServer  │  (cron, 2–3 h)   │
 │ Security    │  OperationalData    │                  │
 │ Servers     │◄──── vía SS cliente └───────┬──────────┘
 │ (OpMon)     │      de monitoreo           │ inserta
 └─────────────┘                             ▼
                                  ┌────────────────────┐      ┌──────────────┐
                                  │  MongoDB           │      │  REPORTS     │
                                  │  raw_messages      │─────►│  PDF / CSV   │
                                  │  clean_data        │      └──────────────┘
                                  └───────┬────────────┘
                                          ▲  │
                          corrige/limpia  │  │ lee limpios
                                  ┌───────┴───▼──────┐  anon. ┌──────────────┐
                                  │    CORRECTOR     │──────►│  ANONYMIZER  │
                                  │  (servicio cont.)│       └──────┬───────┘
                                  └──────────────────┘              │ sube solo
                                                                    ▼ anonimizados
                                  ┌──────────────────┐      ┌──────────────┐
                                  │  NETWORKING /    │◄─────│  PostgreSQL  │
                                  │  VISUALIZER (R)  │ lee  │  (Open Data) │
                                  └──────────────────┘      └──────┬───────┘
                                                                 ▲ sirve
                                                          ┌──────┴───────┐
                                                          │   OPENDATA   │
                                                          │  Web UI + API│
                                                          └──────────────┘
```

## 2. Módulos

| Módulo | Paquete | Función | Ejecución |
|---|---|---|---|
| Database | (MongoDB) | Almacén central: `raw_messages`, `clean_data`, estados por módulo | Servicio continuo |
| Collector | `xroad-metrics-collector` | Obtiene la lista de SS del CS (configuración global), consulta a cada SS vía el SS cliente de monitoreo (`getSecurityServerOperationalData`) y guarda en MongoDB | Cron (paquete: cada 3 h; referencia de arquitectura: cada 2 h) |
| Corrector | `xroad-metrics-corrector` | Transforma datos crudos en limpios: deduplica y empareja consumidor–productor | Servicio continuo |
| Reports | `xroad-metrics-reports` | Genera informes periódicos por miembro/subsistema (PDF; CSV opcional) y notifica por correo / publica en servidor de ficheros | Mensual (cron) |
| Anonymizer | `xroad-metrics-anonymizer` | Prepara los datos limpios para publicación: anonimiza y los carga en PostgreSQL; también genera las estadísticas de la instancia | Diario (cron) |
| Opendata | `xroad-metrics-opendata` | Portal web + API para consultar/descargar los datos anonimizados (`/api/harvest`, `/api/statistics`, etc.) | Servicio web (Apache, HTTPS) |
| Networking / Visualizer | `xroad-metrics-networking` | UI web (R Shiny) con el grafo de relaciones entre miembros y servicios (últimos 30 días) | Diario + servicio web |
| Opendata Collector | `xroad-metrics-opendata-collector` | (Opcional) Recolecta Open Data de **otras** instancias de Metrics vía su API, para una plataforma central de analítica | Cron |
| Analysis | — (experimental, **no publicado**) | Detección de anomalías. No incluir en el despliegue. | — |

**Orden oficial de instalación:** Database → Collector → Corrector → Reports → Anonymizer → Opendata → Networking → Opendata Collector.

## 3. Flujo de datos (paso a paso)
1. Cada SS, con el complemento OpMon, registra localmente los metadatos de cada llamada y los expone como servicio X-Road.
2. El **Collector** descarga del CS la configuración global → lista de SS de la instancia.
3. Por cada SS, el Collector pide sus datos operacionales del periodo **a través del SS cliente de monitoreo** (es una llamada X-Road normal, firmada y con control de acceso) y los inserta en MongoDB como `raw_messages`. Cada llamada genera 2 registros (consumidor y productor).
4. El **Corrector** procesa `raw_messages` de forma continua → `clean_data` (sin duplicados, parejas emparejadas).
5. **Reports** lee `clean_data` y produce informes periódicos.
6. El **Anonymizer** transforma `clean_data` → filas anonimizadas en **PostgreSQL** (único flujo que cruza de la zona privada a la pública).
7. **Opendata** sirve esos datos por web/API; **Networking** los visualiza como grafo.

## 4. Especificaciones operacionales de referencia (instancia grande, Estonia)
Útiles como techo de diseño, **no** como dimensionamiento por defecto:

- Hasta 1 000 M de llamadas/año → 2 000 M de registros/año (~5,5 M/día).
- Registro crudo ≈ 900 B en JSON; registro limpio ≈ 2 KB.
- MongoDB: retener 1 año en disco, 1 semana en RAM, en replica set.
- PostgreSQL: retener 1 año de datos públicos.

Para una instancia pequeña/mediana, el cálculo de capacidad de `04-diseno-despliegue.md` reduce estas cifras a valores realistas.

## 5. Interfaces y puertos (resumen — detalle en el diseño de despliegue)
| Destino | Cliente | Puerto | Uso |
|---|---|---|---|
| MongoDB (`centraldb`) | collector, corrector, reports, anonymizer | 27017 | Base de datos privada |
| PostgreSQL (host opendata) | anonymizer, networking | 5432 | Datos anonimizados |
| Opendata UI | Internet / red de usuarios | 443 | Portal web |
| Networking UI | Internet / red de usuarios | 443 | Visualizador |
| Central Server | collector | 80 | API internalconf (lista de SS) |
| SS cliente de monitoreo | collector | 80/443 | Servicio `getSecurityServerOperationalData` |
| SMTP | reports | 25/465/587 | (Opcional) Notificaciones |
| Servidor de ficheros | reports | 22 | (Opcional) Publicar informes (scp/rsync) |

## 6. Decisiones de arquitectura adoptadas
1. **Producto oficial sin modificaciones** en fase 1 (paquetes `.deb` de NIIS o Docker Compose oficial para piloto).
2. **Separación privado/público por red** desde el primer despliegue productivo, aunque el piloto sea todo-en-uno.
3. **Un perfil por entorno** (`settings_PROD.yaml`, `settings_TEST.yaml`…) si se recolecta de varias instancias.
4. **Open Data es opcional y se activa en fase 2**, tras validar la anonimización; el monitoreo funcional interno (objetivo principal) no lo necesita.
