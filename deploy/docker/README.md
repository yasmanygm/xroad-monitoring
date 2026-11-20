# Despliegue con Docker Compose — X-Road Metrics

Tres composes, para que elijas según la fase (ver `docs/04-diseno-despliegue.md`):

| Fichero | Para qué | Servicios |
|---|---|---|
| `compose.piloto.yaml` | **Piloto / pruebas en un solo host** (Escenario A) | Todo: MongoDB, PostgreSQL, Collector, Corrector, Reports, Anonymizer, Opendata, Networking |
| `compose.privado.yaml` | **Zona privada** de producción (Escenario B) | MongoDB, Collector, Corrector, Reports, Anonymizer (+ Opendata Collector con perfil `agregador`) |
| `compose.publico.yaml` | **Zona pública / DMZ** de producción (Escenario B) | PostgreSQL, Opendata, Networking |

Ficheros de apoyo: `.env.example` (todas las variables), `generar-init.sh` (adapta los init de BD a tu instancia/contraseñas), `desplegar.sh` (automatiza todo lo de abajo).

> ⚠️ **Aviso honesto:** NIIS presenta su setup Docker oficial como pensado para *pruebas locales limitadas*. Estos composes lo adaptan y endurecen (secretos por `.env`, puertos atados a localhost, perfiles), pero para producción sostenida la vía soportada por NIIS sigue siendo la instalación nativa con paquetes (ver `docs/05-guia-instalacion.md`). Docker es ideal para el piloto y para entornos pequeños/medianos asumiendo ese mantenimiento.

## Cómo funcionan (léelo antes de tocar nada)
1. **Las imágenes de los módulos no se descargan de un registro**: se construyen en local desde el repo oficial con `Docker/prepare-containers.sh` (imágenes `xroad-metrics-*-module`). Solo MongoDB (`mongo:7`), PostgreSQL (`postgres:15`), Mongo Express y Adminer vienen de Docker Hub.
2. **Los composes se ejecutan dentro de la carpeta `Docker/` del repo oficial clonado**, porque reutilizan sus scripts `mongodb-init/` y `postgresql-init/`. `desplegar.sh` copia allí el compose, el `.env` y `generar-init.sh`.
3. **Los init oficiales vienen fijos para la instancia `DEV`** y con contraseñas de desarrollo (`collectordevpw`, `anonymizer_devsecret`, BD `opendata_dev`…). `generar-init.sh` genera `./init-generado/` con tu instancia y tus contraseñas del `.env`. Los init **solo se ejecutan con el volumen vacío** (primer arranque): si cambias el `.env` después, recrea los volúmenes o ajusta la BD a mano.
4. **Configuración por variables `setting_*`**: el entrypoint oficial sustituye en el `settings.yaml` de cada módulo cualquier variable de entorno con prefijo `setting_`. Por eso los composes no montan ficheros de configuración.
5. **Red `xroad-network`**: el Collector y el Anonymizer se conectan además a esta red externa (la crea la pila de desarrollo `xrd-dev-stack`; si no existe, `desplegar.sh` la crea vacía). En una plataforma real, los hosts del CS/SS deben ser alcanzables desde los contenedores (DNS/rutas del host Docker).

## Requisitos del host
- Docker Engine + Compose v2, `git`, y los recursos del escenario elegido (`docs/04`).
- El **cliente de monitoreo** registrado en X-Road y autorizado en los Security Servers (sin esto el Collector no recolecta nada: ver `docs/05`, Paso 0).
- Networking es `linux/amd64` (así lo fija el compose oficial).

## Uso rápido
```bash
cd deploy/docker
bash desplegar.sh piloto     # o: privado / publico (con bash no necesitas dar permisos de ejecucion)
```
La primera vez crea el `.env` desde la plantilla y se detiene: **edítalo** (instancia, `CENTRAL_SERVER_HOST`, `SECURITY_SERVER_HOST`, identidad del cliente de monitoreo y contraseñas) y vuelve a ejecutar.

## Uso manual (equivalente, paso a paso)
```bash
git clone https://github.com/nordic-institute/X-Road-Metrics.git
bash X-Road-Metrics/Docker/prepare-containers.sh
cp compose.piloto.yaml generar-init.sh .env X-Road-Metrics/Docker/
cd X-Road-Metrics/Docker && chmod +x generar-init.sh && ./generar-init.sh
docker network create xroad-network   # si no la creó xrd-dev-stack
docker compose -f compose.piloto.yaml up -d mongodb postgresql corrector_module opendata_module networking_module
```

## Operación de los módulos bajo demanda
Collector, Reports, Anonymizer y Opendata Collector no corren en continuo: se lanzan con `run` (en producción, prográmalos con el cron/systemd del host, ver `docs/06-configuracion.md`):
```bash
# Primera vez SIEMPRE update antes que collect:
docker compose -f compose.piloto.yaml run --rm collector_module update
docker compose -f compose.piloto.yaml run --rm collector_module collect
# Informes hasta hoy:
docker compose -f compose.piloto.yaml run --rm reports_module --end-date $(date +%Y-%m-%d) report
# Anonimizar y publicar en PostgreSQL (tras recolectar y corregir):
docker compose -f compose.piloto.yaml run --rm anonymizer_module
# Agregador de otras instancias (opcional, perfil agregador):
docker compose -f compose.piloto.yaml --profile agregador run --rm opendata_collector_module
```

## Puertos
| Servicio | Puerto | Exposición por defecto |
|---|---|---|
| Opendata | 8000 | `127.0.0.1` — publicar con proxy inverso HTTPS del host |
| Networking | 8001 | `127.0.0.1` — idem |
| Mongo Express (perfil `admin`) | 8081 | `127.0.0.1`, solo pruebas |
| Adminer (perfil `admin`) | 8082 | `127.0.0.1`, solo pruebas |
| MongoDB | 27017 | **sin publicar** (solo red interna del compose) |
| PostgreSQL (público) | 5432 | `127.0.0.1`; en modo dividido, atar a la IP de VLAN y filtrar solo desde el Anonymizer |

Perfiles: `docker compose -f <fichero> --profile admin up -d` levanta las UI de BD. **Nunca en producción.**

## Despliegue dividido (privado + público)
1. En el host privado: `.env` con `POSTGRES_HOST=<IP/host del PostgreSQL público>` y `./desplegar.sh privado`.
2. En el host público: mismo `.env` (misma instancia y contraseñas PostgreSQL) pero `POSTGRES_BIND_IP=<IP de este host en la VLAN hacia la zona privada>` y `./desplegar.sh publico`.
3. Firewall entre zonas: permitir **solo** Anonymizer → PostgreSQL:5432. La zona pública no debe tener ruta a MongoDB (comprobar con la prueba P-11 de `docs/09`).

## Limpieza
```bash
docker compose -f compose.piloto.yaml down      # conserva los datos (volúmenes)
docker compose -f compose.piloto.yaml down -v   # BORRA también los datos
```
