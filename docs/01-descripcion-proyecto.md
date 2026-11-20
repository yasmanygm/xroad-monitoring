# 01 — Descripción del proyecto

## 1. Nombre
**xroad-monitoring** — Monitoreo funcional de la plataforma X-Road mediante X-Road Metrics.

## 2. Propósito
Disponer de una capacidad centralizada para **recolectar, almacenar, procesar, analizar y publicar** los datos de monitoreo operacional que generan los Security Servers de la plataforma X-Road, con el fin de:

- Medir el **uso real de los servicios** (quién consume qué servicio, cuántas veces, con qué tamaño de petición/respuesta).
- Medir la **salud y el rendimiento funcional** de los servicios (tiempos de respuesta, tasa de errores/fallos).
- Entender las **dependencias entre miembros y subsistemas** del ecosistema.
- Generar **informes periódicos** para la operación y para los miembros.
- Opcionalmente, **publicar estadísticas anonimizadas como datos abiertos** (Open Data).

> X-Road Metrics es la herramienta oficial de código abierto (licencia MIT) mantenida por NIIS para este fin: recolecta los datos que expone el complemento de *operational monitoring* de los Security Servers y los procesa de forma centralizada. No sustituye al monitoreo técnico de infraestructura (CPU/RAM/red, tipo Zabbix/Nagios/Prometheus): lo **complementa** con monitoreo **funcional** (a nivel de servicio/mensaje X-Road).

## 3. Alcance

### 3.1 Dentro del alcance
- Instalación y configuración de X-Road Metrics (módulos oficiales) en la infraestructura del operador.
- Recolección automática y periódica de datos operacionales de **todos los Security Servers** registrados en la configuración global de la instancia X-Road.
- Limpieza/corrección de los datos (emparejamiento consumidor–productor, deduplicación).
- Almacenamiento centralizado: datos crudos y limpios en MongoDB; datos anonimizados en PostgreSQL.
- Generación de informes (Reports) y, si se decide, publicación Open Data y visualización de red (Networking/Visualizer).
- Documentación, procedimientos de operación, respaldo y seguridad del sistema de monitoreo.

### 3.2 Fuera del alcance
- Cambios en el código fuente de X-Road o de X-Road Metrics (se instala el producto oficial, sin fork en la fase 1).
- Monitoreo del contenido de los mensajes (payload): Metrics trabaja con **metadatos** operacionales, no con el contenido de negocio.
- Monitoreo técnico de infraestructura de los Security Servers de los miembros (responsabilidad de cada miembro).

## 4. Datos que se monitorean (por cada llamada a un servicio)
Cada intercambio genera **dos registros** operacionales (lado consumidor y lado productor). Campos típicos:

| Campo | Descripción |
|---|---|
| `xRoadInstance`, `memberClass`, `memberCode`, `subsystemCode` | Identidad del consumidor y del productor |
| `serviceCode`, `serviceVersion`, `restPath` (si aplica) | Servicio invocado |
| `messageId`, `requestInTs`, `requestOutTs`, `responseInTs`, `responseOutTs` | Trazabilidad y tiempos → duración total y por tramo |
| `requestSize`, `responseSize` | Tamaños de petición/respuesta |
| `succeeded` / código de fallo | Resultado de la llamada |
| `clientSecurityServerAddress`, `producerSecurityServerAddress` | Security Servers involucrados |
| `xRoadVersion` | Versión de X-Road del Security Server |

Estos datos se obtienen con el servicio X-Road estándar **`getSecurityServerOperationalData`** (protocolo PR-OPMON) y, para salud, `getSecurityServerHealthData`.

## 5. Actores
| Actor | Rol en el proyecto |
|---|---|
| Operador de la plataforma X-Road (tu equipo) | Dueño del sistema Metrics: instala, opera, define retención y publicación |
| Administrador de cada Security Server (miembros) | Habilita el monitoreo operacional en su servidor y autoriza el acceso del cliente de monitoreo |
| Cliente de monitoreo (Monitoring Client) | Subsistema X-Road registrado que actúa como consumidor autorizado para consultar los datos operacionales de los Security Servers |
| Usuarios de informes | Dirección/operación: consumen Reports y, si aplica, el portal Open Data |
| NIIS / comunidad X-Road | Proveedor del software y de la documentación oficial |

## 6. Parámetros de la plataforma a completar (decisiones pendientes)
Estos valores definen el dimensionamiento final. Sustituir los marcadores antes de instalar:

| Parámetro | Valor |
|---|---|
| Código de instancia X-Road (p. ej. `CU`, `PROD`, `TEST`) | `<INSTANCE>` |
| Host del Central Server (API internalconf) | `<CENTRAL_SERVER_HOST>` |
| Security Server que actúa como cliente de monitoreo (host) | `<MONITORING_SS_HOST>` |
| Subsistema cliente de monitoreo (member/subsystem) | `<MONITORING_CLIENT>` |
| N.º de Security Servers a recolectar | `<N_SS>` |
| Llamadas a servicios por día (estimado) | `<CALLS_DAY>` |
| Retención de datos crudos/limpios | 12 meses (recomendado) |
| ¿Se publicará Open Data? (sí/no) | `<OPEN_DATA: sí/no>` |
| ¿Informes a miembros? (sí/no, periodicidad) | `<REPORTS: mensual>` |
| Entornos | DEV / TEST / PROD (perfiles separados) |

## 7. Glosario
- **SS**: Security Server. **CS**: Central Server.
- **OpMon**: Operational Monitoring, complemento del SS que registra los datos operacionales y los expone como servicio X-Road.
- **Raw data**: registros tal como llegan al Collector (`raw_messages` en MongoDB).
- **Clean data**: registros corregidos/emparejados por el Corrector (`clean_data` en MongoDB).
- **Anonimización**: transformación que elimina/oculta datos sensibles antes de publicar en PostgreSQL/Open Data.
