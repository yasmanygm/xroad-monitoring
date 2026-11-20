# Referencias oficiales

Toda la documentación de este proyecto se apoya en fuentes oficiales de NIIS. Consultadas el 2026-11-20.

## X-Road Metrics (NIIS)
- Repositorio y documentación: https://github.com/nordic-institute/X-Road-Metrics — carpeta `docs/`
  - System Architecture: `docs/system_architecture.md` (módulos, especificaciones operacionales, puertos, hardware recomendado, infraestructura de producción y de pruebas)
  - Database Module: `docs/database_module.md` (MongoDB, usuarios por módulo, `xroad-metrics-init-mongo`, índices)
  - Collector Module: `docs/collector_module.md` (repositorio de paquetes, instalación, `settings.yaml`, perfiles, mTLS, cron, logs/heartbeat)
  - Corrector, Reports, Anonymizer, Opendata, Networking, Opendata Collector: un documento por módulo en la misma carpeta
- Release notes v1.4.0 (13-02-2025; plataformas soportadas Ubuntu 20.04/22.04 en esa versión; la documentación vigente en GitHub ya lista 22.04/24.04, MongoDB 7.x/8.x y PostgreSQL 14.x–18.x): https://nordic-institute.atlassian.net/wiki/spaces/XRDKB/pages/959119361/X-Road+Metrics+v1.4.0+Release+Notes
- Contexto en el ecosistema: «Additional Building Blocks of an X-Road Ecosystem», NIIS: https://www.niis.org/blog/2022/3/27/additional-building-blocks-of-an-x-road-ecosystem

## X-Road — Monitoreo operacional (docs.x-road.global)
- PR-OPMON — X-Road Operational Monitoring Protocol v1.7 (servicios `getSecurityServerOperationalData` y `getSecurityServerHealthData`): https://docs.x-road.global/OperationalMonitoring/Protocols/pr-opmon_x-road_operational_monitoring_protocol_Y-1096-2.html
- ARC-OPMOND — Operational Monitoring Daemon Architecture: https://docs.x-road.global/OperationalMonitoring/Architecture/arc-opmond_x-road_operational_monitoring_daemon_architecture_Y-1096-1.html
- ARC-SS — Security Server Architecture (componentes OpMonitor y Operational Monitoring Services): https://docs.x-road.global/Architecture/arc-ss_x-road_security_server_architecture.html
- PR-OPMONJMX — Operational Monitoring JMX Protocol (interfaz JMX, desactivada por defecto, útil para monitoreo técnico tipo Zabbix): https://docs.x-road.global/OperationalMonitoring/Protocols/pr-opmonjmx_x-road_operational_monitoring_jmx_protocol_Y-1096-3.html

## Nota de alcance
Las cifras de la instancia de Estonia (1 000 M de llamadas/año, discos de 5 TB) son la referencia de diseño del producto, no un requisito: este proyecto dimensiona con las fórmulas de `04-diseno-despliegue.md` y los datos reales del piloto.
