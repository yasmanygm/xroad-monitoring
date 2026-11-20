# 05 — Guía de instalación

Instalación nativa con paquetes `.deb` oficiales (recomendada para producción). Al final se incluye la alternativa Docker Compose para piloto/pruebas.

> Versiones soportadas: **Ubuntu Server 22.04 LTS o 24.04 LTS** · **MongoDB 7.x/8.x** · **PostgreSQL 14.x–18.x** · X-Road Metrics **v1.4.0** (última documentada; verificar la vigente al instalar).

---

## Paso 0 — Requisitos previos en la plataforma X-Road (imprescindible)
Sin esto, Metrics no tiene de dónde recolectar:

1. **OpMon habilitado en cada Security Server.** Cada SS debe tener instalado/activo el complemento de monitoreo operacional (`xroad-opmonitor`), que registra los datos y ofrece los servicios:
   - `getSecurityServerOperationalData`
   - `getSecurityServerHealthData`
2. **Cliente de monitoreo registrado.** Debe existir un miembro/subsistema X-Road que actúe como *Monitoring Client*, con **derechos de acceso** al servicio `getSecurityServerOperationalData` de **todos** los SS (cada SS autoriza a ese cliente en su gestión de servicios / vía configuración del operador, según la política de la instancia).
3. **Un Security Server como puerta de entrada.** El Collector no habla «directo» con cada SS: envía las peticiones X-Road a través de un SS (normalmente el del propio operador/centro). Anotar su host: `<MONITORING_SS_HOST>`.
4. **Acceso al Central Server.** El Collector descarga la configuración global (API *internalconf*, puerto 80) para enumerar los SS de la instancia.
5. **Datos de partida** (rellenar en `01-descripcion-proyecto.md` §6): código de instancia, hosts, subsistema cliente, credenciales seguras.

**Verificación previa:** desde el SS cliente de monitoreo, hacer una llamada de prueba a `getSecurityServerHealthData` de un SS piloto y confirmar que responde.

---

## Paso 1 — Preparar los hosts
En cada host (según el escenario elegido en `04-diseno-despliegue.md`):
```bash
sudo apt update && sudo apt -y upgrade
timedatectl            # verificar NTP/hora correcta
lsb_release -a         # debe ser 22.04 o 24.04
```
Crear las entradas DNS internas y aplicar las reglas de firewall de `04-diseno-despliegue.md`.

## Paso 2 — Instalar MongoDB (Database module) — siempre primero
En el host `centraldb` (ejemplo para Ubuntu 22.04 / MongoDB 7.0):
```bash
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install --yes mongodb-org
sudo systemctl enable --now mongod.service
```
> Para Ubuntu 24.04 se usa el repositorio de MongoDB 8.0 (`noble/mongodb-org/8.0`, clave `server-8.0.asc`), con la misma mecánica.

Configuración mínima (`/etc/mongod.conf`):
- `net.port: 27017`, `net.bindIp: 127.0.0.1,<IP-privada-del-host>`
- `security.authorization: enabled`
- Filesystem **XFS** recomendado; desactivar Transparent Huge Pages (`never`) según avisos de MongoDB.
- En producción (Escenario B/C): configurar **replica set de ≥ 3 nodos**.

Crear el usuario root:
```javascript
// mongosh
use admin
db.createUser({ user: "root", pwd: passwordPrompt(),
  roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ] })
```
Guardar la contraseña en el gestor de secretos. Reiniciar: `sudo systemctl restart mongod.service`.

## Paso 3 — Añadir el repositorio de paquetes X-Road Extensions (en todos los hosts con módulos)
```bash
curl -fsSL https://x-road.eu/gpg/key/public/niis-artifactory-public.gpg | sudo tee /usr/share/keyrings/niis-artifactory-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/niis-artifactory-keyring.gpg] https://artifactory.niis.org/xroad-extensions-release-deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/xroad-extensions.list > /dev/null
sudo apt update
```
Verificación de la clave: fingerprint `A01B FE41 B9D8 EAF4 872F A3F1 FB0D 532C 10F6 EC5B`.

## Paso 4 — Instalar el Collector y crear usuarios/índices de MongoDB
```bash
sudo apt install xroad-metrics-collector
```
El paquete crea: usuario/grupo del sistema, `/etc/xroad-metrics/collector/settings.yaml`, cron en `/etc/cron.d/xroad-metrics-collector-cron` (cada 3 h) y logs en `/var/log/xroad-metrics/collector/`.

Crear automáticamente un usuario de MongoDB **por módulo** y los índices por defecto:
```bash
sudo su xroad-metrics
xroad-metrics-init-mongo --host xroad-metrics-centraldb:27017 --user root --password <PWD_ROOT> <INSTANCE>
# Ejemplo: xroad-metrics-init-mongo --host xroad-metrics-centraldb:27017 --user root --password mysecret EX
```
⚠️ La salida lista usuarios y contraseñas generadas (`collector_<INSTANCE>`, `corrector_<INSTANCE>`, `reports_<INSTANCE>`, `anonymizer_<INSTANCE>`, …) con su versión «escapada» para YAML. **Guardarla en el gestor de secretos**: se necesita para configurar cada módulo y no se vuelve a mostrar.

Configurar el Collector (`sudo vi /etc/xroad-metrics/collector/settings.yaml`):
- Instancia X-Road (`xroad.instance`)
- Host del Central Server y del SS cliente de monitoreo
- Identidad del cliente X-Road de monitoreo (member/subsystem)
- Usuario/contraseña/host de MongoDB (usuario `collector_<INSTANCE>`)
- (Recomendado) mTLS hacia el SS: `security-server.tls-client-certificate`, `tls-client-key`, `tls-server-certificate`

Primera ejecución manual (siempre `update` antes que `collect` la primera vez):
```bash
sudo su xroad-metrics
xroad-metrics-collector list       # lista los SS detectados desde el CS
xroad-metrics-collector update     # guarda la lista de SS en MongoDB
xroad-metrics-collector collect    # primera recolección
```
Verificar en el log (`/var/log/xroad-metrics/collector/logs/log_collector_<INSTANCE>.json`) la línea `collector_end` con errores = 0, y que `raw_messages` tiene documentos en MongoDB.

## Paso 5 — Instalar el Corrector
```bash
sudo apt install xroad-metrics-corrector
sudo vi /etc/xroad-metrics/corrector/settings.yaml   # instancia + MongoDB (usuario corrector_<INSTANCE>)
```
Corre como servicio continuo. Verificar que `clean_data` empieza a crecer y revisar su log/heartbeat.

## Paso 6 — Instalar Reports
```bash
sudo apt install xroad-metrics-reports
sudo vi /etc/xroad-metrics/reports/settings.yaml     # instancia + MongoDB (solo lectura sobre query_db) + salida de informes + SMTP si aplica
```
Generar un informe de prueba del último mes antes de activar el cron mensual. Nota de capacidad: informes grandes consumen mucha RAM (ver diseño).

## Paso 7 — (Fase 2) Anonymizer + PostgreSQL + Opendata
Solo si se aprueba publicar datos anonimizados:
```bash
# En el host opendata: instalar PostgreSQL 14–18 y crear la BD/usuarios según docs oficiales del módulo Opendata
sudo apt install xroad-metrics-anonymizer   # en el host anonymizer (zona privada)
sudo apt install xroad-metrics-opendata     # en el host opendata (zona pública)
```
- Configurar en el Anonymizer: MongoDB (lectura), PostgreSQL (escritura), mapeo de campos a anonimizar y, para estadísticas, el bloque `xroad.central-server`.
- El Anonymizer corre por cron (diario). Comprobar que en PostgreSQL **solo** aparecen campos anonimizados.
- Opendata instala Apache como proxy inverso HTTPS con certificado autofirmado: **sustituirlo por el certificado del operador** y publicar el DNS.
- Decidir el retardo de publicación (la referencia de Estonia publica con 10 días de retraso) y si se desactiva el endpoint `/api/harvest` (`opendata.disable-opendata-harvest`).

## Paso 8 — (Fase 2) Networking / Visualizer
```bash
sudo apt install xroad-metrics-networking    # requiere RStudio Shiny Server 1.5.23
```
Lee de PostgreSQL los últimos 30 días y publica el grafo por HTTPS (Apache). Sustituir también su certificado autofirmado.

## Paso 9 — (Opcional) Opendata Collector
Solo para una plataforma central que agregue varias instancias de Metrics: `xroad-metrics-opendata-collector`, apuntando al `/api/harvest` de cada instancia origen.

---

## Alternativa para piloto: Docker Compose oficial
En el repositorio oficial, carpeta `Docker/`:
```bash
git clone https://github.com/nordic-institute/X-Road-Metrics.git
cd X-Road-Metrics/Docker
# Revisar y ajustar docker-compose.yaml y las variables setting_* (instancia, usuarios, contraseñas)
docker compose up -d
docker compose run --rm collector_module update    # primera vez: update…
docker compose run --rm collector_module collect   # …y después collect
```
- UI web de MongoDB en el puerto **8081** y de PostgreSQL en **8082** (solo entorno de pruebas, con las credenciales del `docker-compose.yaml`).
- Ideal para el Escenario A y para formar al equipo antes del despliegue nativo.

## Checklist de fin de instalación
- [ ] `list` muestra todos los SS esperados
- [ ] Primera recolección sin errores; `raw_messages` > 0
- [ ] `clean_data` crece (Corrector activo)
- [ ] Informe de prueba generado (Reports)
- [ ] Cron del Collector activo y logs/heartbeat escribiéndose
- [ ] (Fase 2) Datos anonimizados en PostgreSQL y portal por HTTPS con certificado válido
- [ ] Respaldos configurados (ver `07-operacion-mantenimiento.md`)
- [ ] Pruebas de aceptación superadas (`09-pruebas-aceptacion.md`)
