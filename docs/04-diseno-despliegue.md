# 04 — Diseño de despliegue

Diagrama gráfico: [`diagrama-despliegue.png`](diagrama-despliegue.png) · Fuente editable (Mermaid): [`diagrama-despliegue.md`](diagrama-despliegue.md)

Se proponen **tres escenarios escalonados**. Se empieza por el A (piloto), se valida, y se pasa a B o C según volumen y exigencias de seguridad.

---

## Escenario A — Piloto / pruebas (todo en 1–2 hosts)
Objetivo: validar la recolección y los informes con el menor coste. **No** apto para publicar Open Data.

| Host | Contenido | CPU | RAM | Disco |
|---|---|---|---|---|
| `xroad-metrics-01` | MongoDB + Collector + Corrector + Reports (+ Anonymizer si se prueba) | 4 | 16 GB | 200 GB (crecer según cálculo) |
| `xroad-metrics-02` (opcional) | PostgreSQL + Opendata + Networking | 2 | 8 GB | 100 GB |

- Alternativa rápida oficial: usar el entorno **Docker Compose** del repositorio (`Docker/`): `docker compose up -d` y primera recolección con `update` + `collect` (ver guía de instalación). Incluye UI web de MongoDB (8081) y PostgreSQL (8082) **solo para pruebas, nunca expuestas en producción**.

## Escenario B — Producción recomendada (2 zonas, módulos agrupados)
El recomendado para la mayoría de operadores: mantiene la separación privado/público sin llegar a un host por módulo.

**Zona privada (VLAN-METRICS-PRIV)**
| Host | Contenido | CPU | RAM | Disco |
|---|---|---|---|---|
| `xroad-metrics-db` | MongoDB (nodo 1 del replica set) | 4 | 32 GB | Según cálculo, XFS, RAID-10 |
| `xroad-metrics-db2`, `xroad-metrics-db3` | MongoDB (nodos 2 y 3, pueden ser más pequeños: réplica/árbitro) | 2–4 | 16–32 GB | Igual que nodo 1 |
| `xroad-metrics-app` | Collector + Corrector + Reports | 4 | 16 GB | 50 GB |
| `xroad-metrics-anon` | Anonymizer (único con salida hacia PostgreSQL) | 2 | 4 GB | 20 GB |

**Zona pública / DMZ (VLAN-METRICS-PUB)**
| Host | Contenido | CPU | RAM | Disco |
|---|---|---|---|---|
| `xroad-metrics-opendata` | PostgreSQL + Opendata (Apache/HTTPS) | 4 | 16 GB | Según cálculo de datos públicos |
| `xroad-metrics-viz` | Networking/Visualizer (R Shiny + Apache/HTTPS) | 2 | 8 GB | 20 GB |

Regla de oro del firewall entre zonas: **el único flujo privado → público permitido es Anonymizer → PostgreSQL:5432 con datos ya anonimizados**. Ningún acceso desde la zona pública hacia MongoDB.

## Escenario C — Producción a gran escala (un host por módulo)
El de la documentación oficial, dimensionado para ~1 000 M de llamadas/año. Solo si tu volumen se acerca a esa escala:

| Host/Módulo | CPU | RAM | Disco |
|---|---|---|---|
| centraldb (MongoDB) | 4 | 32 GB | 5 TB (XFS, RAID-0/10, replica set ≥ 3 nodos) |
| collector | 2 | 2 GB | 10 GB |
| corrector | 4 | 8 GB | 10 GB |
| reports | 2 | 16 GB | 10 GB |
| anonymizer | 2 | 4 GB | 10 GB |
| opendata (+PostgreSQL) | 4 | 32 GB | 5 TB |
| networking | 2 | 8 GB | 10 GB |

> Nota oficial: Reports puede necesitar mucha RAM con volúmenes grandes (≈30 GB para un informe de 10 M de mensajes de un subsistema en un mes). Dimensionar Reports según el subsistema más grande, no según la media.

---

## Cálculo de capacidad (rellenar con tus datos)
Fórmulas (valores oficiales: registro crudo ≈ 900 B; limpio ≈ 2 KB; 2 registros por llamada):

```text
registros/día        = llamadas/día × 2
MongoDB crudo/día    ≈ registros/día × 900 B
MongoDB limpio/día   ≈ llamadas/día × 2 KB      (tras emparejar, ~1 registro limpio por llamada*)
disco 12 meses       ≈ (crudo retenido** + limpio) × 365 × 1,4 (índices y margen)
```
\* El Corrector fusiona la pareja consumidor+productor; en la referencia oficial, `clean_data` ≈ 0,7 × registros crudos en número, pero de mayor tamaño unitario.
\** Si `raw_messages` se purga a los 30–90 días (recomendado), el término crudo se calcula sobre esa retención, no sobre 12 meses.

**Ejemplo orientativo — instancia mediana (200 000 llamadas/día):**
| Concepto | Valor |
|---|---|
| Registros crudos/día | 400 000 |
| Crudo (purga 60 días) | ≈ 22 GB |
| Limpio (12 meses) | ≈ 146 GB |
| Índices + margen (×1,4) | ≈ 235 GB → **disco MongoDB de 500 GB** es razonable |
| PostgreSQL (anonimizado, 12 meses) | ≈ 50–100 GB |

## Reglas de red / firewall (aplican a B y C)
| Origen | Destino | Puerto | Permitir |
|---|---|---|---|
| Collector | Central Server | 80 (internalconf) | ✅ |
| Collector | SS cliente de monitoreo | 80/443 | ✅ |
| SS cliente de monitoreo | Resto de SS (tráfico X-Road normal) | 5500 (mensaje X-Road) | ✅ (ya existe en la plataforma) |
| Collector, Corrector, Reports, Anonymizer | MongoDB | 27017 | ✅ solo zona privada |
| Anonymizer, Networking | PostgreSQL | 5432 | ✅ único flujo hacia zona pública |
| Usuarios | Opendata, Networking | 443 | ✅ |
| Reports | SMTP / servidor de ficheros | 587 / 22 | ✅ opcional |
| Zona pública | MongoDB | cualquiera | ❌ denegar |
| Internet | MongoDB / PostgreSQL | cualquiera | ❌ denegar |

## Nombres, DNS y certificados
- Nombres sugeridos: `xroad-metrics-db`, `xroad-metrics-app`, `xroad-metrics-anon`, `xroad-metrics-opendata`, `xroad-metrics-viz` (+ sufijo de entorno: `-test`, `-prod`).
- Entradas DNS públicas solo para Opendata/Networking, con certificado TLS válido del operador en Apache.
- Sincronización horaria (NTP) obligatoria en todos los hosts: los datos operacionales son series temporales.
