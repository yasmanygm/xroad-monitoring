# 08 — Seguridad y privacidad

## 1. Clasificación de los datos
| Nivel | Datos | Dónde | Quién accede |
|---|---|---|---|
| **Confidencial** | Registros crudos y limpios: pueden incluir IP de Security Servers/sistemas, identificadores de miembros y, según la instancia, datos personales en identificadores | MongoDB (zona privada) | Solo administradores de la plataforma X-Road |
| **Público** | Registros anonimizados y agregados estadísticos | PostgreSQL (zona pública/DMZ) | Cualquiera (si se activa Open Data) |

La anonimización es la frontera: **nada cruza a la zona pública sin pasar por el Anonymizer**.

## 2. Controles obligatorios
1. **Segmentación de red:** VLAN privada y VLAN pública con firewall; único flujo cruzado permitido: Anonymizer → PostgreSQL:5432 (ver `04-diseno-despliegue.md`).
2. **Autenticación en bases de datos:** MongoDB con `authorization: enabled`; un usuario por módulo con mínimo privilegio (generados por `xroad-metrics-init-mongo`); PostgreSQL igual. Sin usuarios compartidos.
3. **Cifrado en tránsito:** HTTPS en todas las UI (certificado válido del operador, no el autofirmado de instalación); mTLS Collector↔SS recomendado; TLS disponible para MongoDB y PostgreSQL entre hosts.
4. **Control de acceso en origen:** el cliente de monitoreo solo tiene derecho al servicio de monitoreo operacional; cada SS autoriza explícitamente a ese cliente. Revocar el acceso = revocar en el SS.
5. **Secretos:** contraseñas y claves en gestor de secretos; nunca en Git, ni en tickets, ni en el historial de comandos compartido. Los `settings.yaml` solo son legibles por el usuario `xroad-metrics`.
6. **Retardo y revisión antes de publicar:** aplicar un retardo de publicación (referencia: 10 días) y una revisión del mapeo de anonimización tras **cada** actualización de X-Road/Metrics (los campos nuevos no nacen anonimizados).
7. **Exclusiones legales:** si la normativa de la instancia excluye a ciertos miembros (p. ej. organismos de seguridad, como hace Estonia), el Anonymizer debe excluirlos de la publicación. Definir la lista con el responsable legal antes de activar Open Data.
8. **Registro y auditoría:** logs JSON por módulo con rotación; accesos a MongoDB limitados por red y usuario; revisión mensual de cuentas.
9. **Endurecimiento básico:** hosts solo con paquetes soportados, actualizaciones de seguridad automáticas, SSH con claves, sin UI de bases de datos (puertos 8081/8082 del entorno Docker) fuera de pruebas.

## 3. Riesgos principales y mitigación
| Riesgo | Impacto | Mitigación |
|---|---|---|
| Filtración de datos personales vía Open Data | Alto (legal/reputacional) | Anonimización revisada, retardo, exclusiones, auditoría previa al go-live de fase 2 |
| Compromiso del host público alcanza MongoDB | Alto | Segmentación: la zona pública no tiene ruta a MongoDB |
| El cliente de monitoreo se usa para consultar SS sin autorización | Medio | Derechos limitados al servicio OpMon; revisión periódica de autorizaciones en los SS |
| Credenciales en el repositorio | Medio | Plantillas con marcadores, revisión pre-commit, rotación si ocurre |
| Crecimiento de disco detiene la recolección | Medio | Alertas de disco, purga programada, cálculo de capacidad vivo |
