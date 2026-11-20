# 02 — Requisitos

Prioridades: **Alta** (imprescindible para el go-live), **Media** (fase 2), **Baja** (deseable).
Estados: Pendiente / En análisis / Aprobado / En desarrollo / Completado / Descartado.

## Requisitos funcionales

| ID | Requisito | Prioridad | Criterios de aceptación |
|---|---|---|---|
| REQ-001 | El sistema debe recolectar automáticamente los datos operacionales de todos los Security Servers de la instancia, mediante el servicio `getSecurityServerOperationalData`, a través de un Security Server cliente de monitoreo autorizado. | Alta | El Collector lista los SS desde la configuración global del CS y el log de recolección muestra `Total collected` = N.º de SS sin error en una corrida completa. |
| REQ-002 | La recolección debe ser periódica y desatendida (cron), con frecuencia configurable (referencia oficial: cada 2–3 h). | Alta | Cron activo; existen registros nuevos en `raw_messages` tras cada ventana sin intervención manual. |
| REQ-003 | El sistema debe soportar varias instancias/entornos X-Road (DEV, TEST, PROD) con perfiles de configuración separados. | Media | Perfiles `settings_<ENV>.yaml` creados; `xroad-metrics-collector --profile TEST collect` y `--profile PROD collect` funcionan de forma independiente. |
| REQ-004 | El sistema debe corregir los datos crudos: deduplicar y emparejar registros consumidor–productor, generando datos limpios consultables. | Alta | El Corrector corre como servicio continuo y `clean_data` crece; el % de registros emparejados se mantiene dentro del umbral definido (p. ej. > 95 % excluyendo fallos reales). |
| REQ-005 | El sistema debe permitir consultar estadísticas de uso: llamadas por servicio, por miembro consumidor/productor, por subsistema, en un periodo dado. | Alta | Una consulta de prueba sobre MongoDB/Open Data devuelve totales coherentes con los registros del SS en el mismo periodo. |
| REQ-006 | El sistema debe medir rendimiento funcional: duración de las llamadas y tasa de éxito/fallo por servicio. | Alta | Es posible obtener, por servicio: n.º de llamadas, duración media/p95 y % de fallos en un periodo. |
| REQ-007 | El sistema debe generar informes periódicos (PDF y, opcionalmente, CSV) por miembro/subsistema y notificar su disponibilidad (correo y/o servidor de ficheros). | Media | Se genera el informe del mes de prueba y se recibe la notificación; el informe incluye promedios de servicio correctos. |
| REQ-008 | Si se aprueba Open Data: el sistema debe anonimizar los datos y publicarlos en un portal web con API, con el retardo de publicación configurado. | Media | El portal responde por HTTPS; ningún campo clasificado como sensible aparece en PostgreSQL; el retardo configurado se respeta. |
| REQ-009 | Si se aprueba visualización: el sistema debe mostrar el grafo de relaciones entre miembros/servicios (Networking/Visualizer). | Baja | La UI web muestra el grafo con los datos de los últimos 30 días. |
| REQ-010 | El sistema debe registrar logs estructurados y un fichero *heartbeat* por módulo con el resultado de cada ejecución (SUCCEEDED/FAILED). | Alta | Existen logs y heartbeat por módulo/instancia; un fallo de recolección queda registrado como FAILED. |
| REQ-011 | El sistema debe permitir incorporar un Security Server nuevo sin cambios de código: basta con que aparezca en la configuración global y tenga OpMon habilitado. | Alta | Tras registrar un SS de prueba y ejecutar `update` + `collect`, sus datos aparecen en MongoDB. |
| REQ-012 | El sistema debe exponer endpoints de estadísticas de la instancia (si Open Data está activo): totales de consultas, miembros, servicios y top de servicios. | Baja | `/api/statistics` devuelve los datos y la fecha de última actualización. |

## Requisitos no funcionales

| ID | Requisito | Categoría | Prioridad | Criterios de aceptación |
|---|---|---|---|---|
| RNF-001 | Plataforma soportada: Ubuntu Server 22.04 LTS o 24.04 LTS; MongoDB 7.x/8.x oficial (no variantes compatibles tipo DocumentDB/CosmosDB); PostgreSQL 14.x–18.x (si Open Data); Python 3.10+ (incluido en los paquetes). | Compatibilidad | Alta | Instalación realizada solo con versiones soportadas, verificadas con `mongod --version`, `psql --version`, `lsb_release -a`. |
| RNF-002 | Los datos crudos y limpios (MongoDB) pueden contener IP y datos personales: deben residir en una red privada, accesible solo a administradores de la plataforma. | Seguridad / Privacidad | Alta | MongoDB no expuesto fuera de la VLAN privada; firewall verificado; acceso solo con usuarios por módulo (mínimo privilegio). |
| RNF-003 | Los datos públicos (PostgreSQL/Open Data) deben estar **aislados por red** de los datos confidenciales, con enrutamiento cortafuegos que solo permita subir datos anonimizados. | Seguridad | Alta | Dos VLAN/segmentos (privado y público) según el diagrama de despliegue; prueba de conectividad cruzada denegada salvo flujos documentados. |
| RNF-004 | Todas las interfaces web deben servirse por HTTPS con certificados válidos del operador (los paquetes instalan Apache como proxy inverso con autofirmado por defecto, que debe sustituirse). | Seguridad | Alta | Navegador sin advertencias en Open Data/Networking; certificado del operador instalado. |
| RNF-005 | Las conexiones Collector→SS deben poder usar mTLS con certificado de cliente X-Road; las conexiones a MongoDB/PostgreSQL deben poder usar TLS. | Seguridad | Media | mTLS configurado en `settings.yaml` del Collector y recolección exitosa por HTTPS. |
| RNF-006 | Retención: MongoDB conserva 12 meses de datos; los `raw_messages` se purgan periódicamente tras su corrección. PostgreSQL conserva 12 meses de datos públicos. | Datos | Alta | Tarea de purga documentada y ejecutada; consulta de antigüedad máxima lo confirma. |
| RNF-007 | Capacidad: el dimensionamiento debe calcularse con la regla oficial: ~900 B por registro crudo, 2 registros por llamada (consumidor+productor) y ~2 KB por registro limpio. Ver § dimensionamiento en `04-diseno-despliegue.md`. | Rendimiento / Capacidad | Alta | Hoja de cálculo de capacidad aprobada antes de aprovisionar discos. |
| RNF-008 | Disponibilidad: en producción, MongoDB debe correr en *replica set* de mínimo 3 nodos. | Disponibilidad | Media | `rs.status()` muestra 3 miembros sanos (aplica al escenario de producción, no al piloto). |
| RNF-009 | Respaldo: copia periódica de MongoDB, PostgreSQL y de todos los `settings.yaml`, con restauración probada. | Continuidad | Alta | Respaldo ejecutado y restauración de prueba en entorno TEST documentada. |
| RNF-010 | Cada módulo debe usar un usuario de base de datos propio, con permisos mínimos (los genera `xroad-metrics-init-mongo`). Las credenciales se guardan en un gestor de secretos, nunca en el repositorio Git. | Seguridad | Alta | Usuarios por módulo creados; ningún secreto en el repo (revisión previa a cada commit). |
| RNF-011 | El sistema de monitoreo debe ser a su vez monitoreado (logs, heartbeat, espacio en disco, antigüedad del último dato recolectado) con alertas al equipo operador. | Operación | Media | Alerta de prueba disparada al detener el Collector en TEST. |
| RNF-012 | Sin impacto en producción X-Road: la recolección no debe degradar los Security Servers (consultas por ventanas de tiempo, fuera de horas pico si el volumen lo exige). | Rendimiento | Alta | Ventana y frecuencia acordadas; sin incidencias de rendimiento en SS durante el piloto. |

## Trazabilidad
Cada requisito se gestiona además como Issue en GitHub con la plantilla **Requisito** (`.github/ISSUE_TEMPLATE/requisito.md`), usando el mismo ID (REQ-xxx / RNF-xxx).
