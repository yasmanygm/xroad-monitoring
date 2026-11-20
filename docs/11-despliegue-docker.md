# 11 — Despliegue con Docker Compose

Además de la instalación nativa con paquetes (doc 05), el proyecto incluye un despliegue con Docker Compose en [`deploy/docker/`](../deploy/docker/README.md), construido sobre el setup Docker oficial de NIIS:

| Compose | Uso |
|---|---|
| `deploy/docker/compose.piloto.yaml` | Todo en un host: piloto y pruebas (Escenario A) |
| `deploy/docker/compose.privado.yaml` | Zona privada de producción: MongoDB, Collector, Corrector, Reports, Anonymizer |
| `deploy/docker/compose.publico.yaml` | Zona pública/DMZ: PostgreSQL, Opendata, Networking |

Piezas de apoyo en la misma carpeta: `.env.example` con todas las variables, `generar-init.sh` (adapta a tu instancia y contraseñas los scripts de inicialización de BD, que en el repo oficial vienen fijos para `DEV`), `desplegar.sh` (clona el repo oficial, construye las imágenes y levanta cada modo) y un README con el paso a paso.

Notas clave:
- Las imágenes de los módulos se **construyen en local** desde el repo oficial (`Docker/prepare-containers.sh`); no hay imágenes publicadas en un registro.
- NIIS presenta su setup Docker como orientado a pruebas limitadas: es la vía recomendada aquí para el **piloto**; la producción soportada por NIIS es la instalación nativa (doc 05), y el Escenario B con Docker exige asumir el endurecimiento descrito en `deploy/docker/README.md` (secretos por `.env`, puertos atados a localhost/proxy HTTPS, separación de zonas).
- Los módulos bajo demanda (Collector, Reports, Anonymizer) se ejecutan con `docker compose run --rm ...` y se programan con el cron/systemd del host.
