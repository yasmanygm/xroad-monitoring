# 06 — Configuración

## 1. Ficheros de configuración
Cada módulo tiene su `settings.yaml`, editable solo por el usuario del sistema `xroad-metrics`:

| Módulo | Ruta |
|---|---|
| Collector | `/etc/xroad-metrics/collector/settings.yaml` |
| Corrector | `/etc/xroad-metrics/corrector/settings.yaml` |
| Reports | `/etc/xroad-metrics/reports/settings.yaml` |
| Anonymizer | `/etc/xroad-metrics/anonymizer/settings.yaml` |
| Opendata | `/etc/xroad-metrics/opendata/settings.yaml` |
| Networking | `/etc/xroad-metrics/networking/settings.yaml` |

Reglas:
- **Ningún secreto en Git.** Este repositorio guarda solo plantillas con marcadores `<...>`; los valores reales viven en el servidor y en el gestor de secretos.
- Tras cambiar un `settings.yaml`, reiniciar el servicio del módulo (o esperar a la siguiente ejecución cron, según el módulo) y verificar el log.

## 2. Valores que hay que rellenar (por módulo)
**Comunes:** `xroad.instance`, host de MongoDB/PostgreSQL, usuario y contraseña **propios del módulo** (generados por `xroad-metrics-init-mongo`, usar la columna «Escaped Password»), nivel de log y rutas de log/heartbeat.

**Collector (específicos):**
```yaml
xroad:
  instance: <INSTANCE>                 # p. ej. PROD
  central-server: <CENTRAL_SERVER_HOST>
security-server:
  protocol: https://
  host: <MONITORING_SS_HOST>           # SS puerta de entrada
  timeout: 60.0
  tls-client-certificate: /path/to/client.crt   # mTLS (recomendado)
  tls-client-key: /path/to/client.key
  tls-server-certificate: /path/to/server.crt   # o False solo en pruebas
# + identidad del cliente X-Road de monitoreo (member class/code, subsystem)
# + mongodb: host, user collector_<INSTANCE>, password
```

**Anonymizer (específicos):** mapeo de campos a anonimizar/eliminar (revisar especialmente campos nuevos como `restPath` al actualizar versión), usuarios de solo lectura de PostgreSQL, bloque `xroad.central-server` si se generan estadísticas, y cron de estadísticas si se activa.

**Opendata (específicos):** `opendata.disable-opendata-harvest: true` si no se quiere exponer la cosecha por API; retardo de publicación definido por la política del operador.

**Reports (específicos):** periodo, miembros/subsistemas incluidos, `generate-csv: true` si se quieren CSV además de PDF, destino de publicación (carpeta/servidor de ficheros) y SMTP de notificación.

## 3. Perfiles por entorno/instancia
Un fichero por instancia, ejecutando con `--profile`:
```bash
# /etc/xroad-metrics/collector/settings_DEV.yaml, settings_TEST.yaml, settings_PROD.yaml
xroad-metrics-collector --profile TEST update
xroad-metrics-collector --profile TEST collect
```
Y en cron, una línea por perfil (ejemplo cada 6 h):
```cron
15 */6 * * * xroad-metrics xroad-metrics-collector --profile PROD update && xroad-metrics-collector --profile PROD collect
30 */6 * * * xroad-metrics xroad-metrics-collector --profile TEST update && xroad-metrics-collector --profile TEST collect
```

## 4. Programación (cron) de referencia
| Tarea | Frecuencia de referencia | Nota |
|---|---|---|
| Collector `update` + `collect` | Cada 2–3 h | El paquete instala 3 h; ajustar a volumen/ventana operativa |
| Corrector | Continuo (servicio) | No es cron |
| Anonymizer | Diario (madrugada) | Antes de la ventana de publicación |
| Opendata | Servicio web continuo | Los datos se renuevan tras el Anonymizer |
| Networking | Diario | Usa los últimos 30 días de PostgreSQL |
| Reports | Mensual | Tras cerrar el mes; prever RAM |
| Purga de `raw_messages` | Semanal/mensual | Según retención definida (30–90 días sugerido) |
| Respaldo BD | Diario | Ver `07-operacion-mantenimiento.md` |

## 5. Logs y heartbeat
- Logs JSON por módulo en `/var/log/xroad-metrics/<modulo>/logs/` (una línea por evento: timestamp, módulo, nivel, actividad, mensaje).
- Heartbeat en `/var/log/xroad-metrics/<modulo>/heartbeat/` con el último estado: `SUCCEEDED` / `FAILED`. Es la señal que debe vigilar el monitoreo técnico.
- Configurar `logrotate` por módulo (referencia del Collector: rotar 10 ficheros de 2 MB; adaptar a volumen real).
