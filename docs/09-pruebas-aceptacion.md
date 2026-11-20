# 09 — Pruebas y criterios de aceptación del despliegue

Ejecutar en TEST y repetir el subconjunto marcado ★ en PROD tras la instalación.

| # | Prueba | Pasos | Resultado esperado |
|---|---|---|---|
| P-01 ★ | Descubrimiento de SS | `xroad-metrics-collector list` | Lista idéntica a los SS registrados en la configuración global de la instancia |
| P-02 ★ | Primera recolección | `update` y luego `collect` sobre un SS piloto con tráfico conocido | Log `collector_end` con 0 errores; documentos nuevos en `raw_messages` |
| P-03 | Coherencia de conteo | Generar N llamadas de prueba entre dos subsistemas y esperar una recolección | En los datos aparecen 2 registros por llamada (consumidor + productor) con el mismo `messageId` |
| P-04 ★ | Corrección | Esperar al Corrector y consultar `clean_data` por ese `messageId` | Un registro limpio emparejado por llamada, sin duplicados al repetir la recolección de la misma ventana |
| P-05 | Métricas funcionales | Consultar llamadas, duración media y % de fallos de un servicio en un periodo | Valores coherentes con las llamadas de prueba (incluye un fallo provocado y se refleja) |
| P-06 | Informe | Generar el informe del periodo de prueba | PDF (y CSV si está activado) generado, con los servicios de prueba y promedios correctos; notificación recibida |
| P-07 | Incorporación de un SS nuevo | Registrar un SS de prueba en la instancia y ejecutar `update` + `collect` | Sus datos aparecen sin tocar código ni reconfigurar el Collector |
| P-08 | Fallo controlado | Cortar la conectividad a un SS y recolectar | El resto de SS se recolecta; el fallo queda en log y heartbeat como FAILED/parcial, sin detener el proceso |
| P-09 | (Fase 2) Anonimización | Ejecutar el Anonymizer y auditar PostgreSQL campo a campo | Ningún campo clasificado confidencial está presente; las estadísticas cuadran con `clean_data` |
| P-10 | (Fase 2) Portal Open Data | Acceder por HTTPS y usar la API (`/api/statistics`, descarga) | Certificado válido; datos visibles solo a partir del retardo configurado |
| P-11 | (Fase 2) Aislamiento de red | Desde el host opendata, intentar conectar a MongoDB:27017 | Conexión denegada por firewall |
| P-12 | Respaldo y restauración | Restaurar MongoDB y PostgreSQL del respaldo en TEST | Las consultas P-05 se repiten con los mismos resultados |
| P-13 ★ | Operación desatendida | Dejar el sistema 48 h sin intervención | Recolecciones cron exitosas; heartbeats en SUCCEEDED; sin crecimiento anómalo de disco |

**Criterio de go-live (fase 1):** P-01 a P-08 y P-13 superadas, respaldos configurados y documentación de operación entregada.
**Criterio adicional (fase 2, Open Data):** P-09 a P-11 superadas y revisión legal de exclusiones firmada.
