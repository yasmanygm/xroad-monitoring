# 07 — Operación y mantenimiento

## 1. Rutina diaria (automatizada, con revisión semanal humana)
- Comprobar heartbeats: Collector, Corrector y Anonymizer en `SUCCEEDED`.
- Comprobar antigüedad del dato más reciente en `clean_data` (no debe superar 2× el intervalo de recolección).
- Comprobar espacio en disco de MongoDB y PostgreSQL (alerta al 70 % / 85 %).

## 2. Rutina mensual
- Verificar que el informe mensual se generó y notificó.
- Revisar crecimiento real vs. cálculo de capacidad (`04-diseno-despliegue.md`) y proyectar cuándo ampliar disco.
- Ejecutar la purga de `raw_messages` según la retención definida y registrar cuántos documentos se eliminaron.
- Revisar usuarios y accesos a MongoDB/PostgreSQL.

## 3. Respaldos
| Qué | Cómo | Frecuencia | Retención sugerida |
|---|---|---|---|
| MongoDB | `mongodump` por instancia / snapshot del volumen (con replica set, respaldar un secundario) | Diario | 30 días |
| PostgreSQL | `pg_dump` / respaldo base + WAL si se requiere PITR | Diario | 30 días |
| Configuración | Copia cifrada de todos los `settings.yaml`, crontabs y configuración de Apache | Tras cada cambio | Indefinida (en gestor seguro) |
| Informes generados | Ya residen en el servidor de ficheros de informes | — | 12 meses |

**Restauración probada:** al menos una vez antes del go-live y una vez al año, restaurar ambas BD en TEST y repetir las pruebas de `09-pruebas-aceptacion.md`.

## 4. Actualizaciones
1. Leer las *release notes* oficiales de la nueva versión de X-Road Metrics (Knowledge Base de NIIS) y de X-Road: hay cambios que afectan a los datos (p. ej. campos nuevos como `restPath` en X-Road 7.6 / Metrics 1.4.0, que obligan a revisar el mapeo del Anonymizer antes de publicar).
2. Actualizar primero en TEST con un perfil de datos real anonimizado.
3. Ventana de mantenimiento en PROD: `sudo apt update && sudo apt install <paquetes xroad-metrics-*>` en el orden de instalación.
4. No aplicar actualizaciones **MAJOR** de MongoDB/PostgreSQL sin plan específico; PATCH sí, MINOR con pruebas.
5. Registrar versión anterior/nueva y resultado en el historial de cambios del proyecto (Issue en GitHub).

## 5. Incidencias frecuentes
| Síntoma | Causa probable | Acción |
|---|---|---|
| Collector: «no operational data found» en un SS | OpMon no habilitado, sin datos en la ventana, o error de comunicación disfrazado | Probar `getSecurityServerHealthData` a ese SS; revisar derechos del cliente de monitoreo y conectividad |
| Un SS desaparece de `list` | Salió de la configuración global o cambió su registro en el CS | Ejecutar `update`; verificar el registro en el CS |
| `clean_data` deja de crecer pero `raw_messages` crece | Corrector detenido o con error | Revisar servicio y log del Corrector; reiniciar; comprobar RAM |
| Informes fallan por memoria | Volumen del subsistema mayor de lo previsto | Aumentar RAM del host de Reports o dividir el informe por subsistemas |
| Disco de MongoDB crece más de lo previsto | Purga de crudos no aplicada o índices extra | Aplicar purga; revisar índices (cada índice extra penaliza al Corrector) |
| Datos sensibles visibles en Open Data | Mapeo del Anonymizer desactualizado tras una actualización | **Detener la publicación**, corregir el mapeo, re-anonimizar y auditar lo ya publicado |

## 6. Monitoreo del propio Metrics (con el sistema técnico existente: Zabbix/Prometheus/Nagios)
- Heartbeat de cada módulo (edad y estado).
- Procesos/servicios: `mongod`, `postgresql`, Apache, Corrector.
- Disco, RAM y CPU por host (umbrales de `04-diseno-despliegue.md`).
- Trabajos cron: código de salida del Collector/Anonymizer.
- Certificados TLS de Opendata/Networking: aviso 30 días antes de caducar.
