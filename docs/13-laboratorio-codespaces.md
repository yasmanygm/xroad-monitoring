# 13 — Laboratorio temporal gratuito en GitHub Codespaces

**Para qué:** ver el laboratorio del doc 12 funcionando y tomar instantáneas (capturas de Opendata/Networking), **sin servidor y sin coste**, de forma temporal y desechable. No es un despliegue permanente: es una sesión de trabajo en la nube de GitHub que se crea en minutos y se borra al terminar.

## Por qué Codespaces (verificado el 2026-11-21)
- Tu cuenta de GitHub ya es la del proyecto: el codespace se crea **desde este mismo repositorio**.
- La cuota gratuita de una cuenta personal GitHub Free incluye **120 horas-núcleo/mes**: la máquina de **4 núcleos y 16 GB de RAM** consume 4 horas-núcleo por hora, así que son **~30 horas reales al mes** — de sobra para montar el laboratorio, mirarlo y capturar.
- **Sin tarjeta y sin riesgo de cobro:** por defecto el límite de gasto es 0 $; si se agota la cuota, el entorno se detiene, no se factura.
- Trae Docker dentro (configurado en `.devcontainer/devcontainer.json` de este repo, con Docker-in-Docker y requisitos mínimos de 4 núcleos/16 GB), que es lo que necesitan la pila X-Road y los composes.
- **La imagen base está fijada a `ubuntu-24.04`, no uses la etiqueta genérica `base:ubuntu`:** esa etiqueta hoy apunta a Ubuntu «resolute» y la feature Docker-in-Docker falló al instalarse en ella (creation.log del 2026-11-21: *The 'moby' option is not supported on ubuntu 'resolute' because 'moby-cli' and related system packages are not available in that distribution*), dejando el codespace en el contenedor de recuperación Alpine, sin Docker y sin permisos para ejecutarlo a mano. Con 24.04 (noble) los paquetes moby sí existen y la feature se instala bien.
- Los puertos se pueden **reenviar con URL propia** (`*.app.github.dev`): los de Opendata (8000) y Networking (8001) se pueden poner **públicos** para verlos y compartir la vista; las consolas de administración de X-Road (4100/4200/4300) se quedan **privadas** (solo tú, con tu sesión de GitHub).

Descartado tras comprobarlo: Oracle Cloud «Always Free» ofrece máquinas ARM potentes, pero X-Road y el módulo Networking de Metrics son **amd64**; no sirven para este laboratorio. Los créditos de prueba de Google/AWS/Azure sí valdrían, pero exigen tarjeta y son más trámite para algo temporal.

## Límites a tener en cuenta
- **Disco: 32 GB.** Las imágenes de X-Road son grandes; alcanza para el laboratorio, pero no instales cosas extra y **borra el codespace al terminar** (el almacenamiento guardado también consume cuota mensual: 15 GB-mes gratis).
- **Apagado por inactividad:** 30 min por defecto (se puede subir a 4 h en la configuración del codespace). Al reactivarse, los contenedores hay que volver a levantarlos (`docker compose up -d` / repetir el arranque); los datos permanecen mientras no borres el codespace.
- **Rendimiento justo:** 4 núcleos/16 GB es el mínimo del laboratorio; la primera construcción de imágenes tardará. Paciencia en los Pasos 2 y 4.

## Cómo lanzarlo
1. En este repo en GitHub: **Code → Codespaces → Create codespace on main** (si te deja elegir máquina, la de **4-core / 16 GB RAM**; la configuración del repo ya la exige como mínimo).
2. Espera a que abra el editor web con una terminal. A partir de ahí, sigue **el doc 12** en esa terminal, con estas equivalencias:
   - **Paso 2 (X-Road de prueba):** clona X-Road **fijado en el commit `1ffb1405`** y arranca con `./local-dev-run.sh --initialize`, según el doc 12 corregido.
   - **Paso 3 (cliente de monitoreo):** las consolas del CS (4100) y de `ss0` (4200) aparecen en la pestaña **Ports** del editor: ábrelas con visibilidad **Private** y registra `COM/1234/metrics` en `ss0`.
   - **Paso 4 (Metrics):** `bash desplegar.sh piloto` desde `deploy/docker` de este repo (ya está clonado: es el propio codespace).
   - **Paso 5 (tráfico):** `bash deploy/docker/lab/generar-trafico.sh 50` (usa `localhost:4310`, que dentro del codespace es el proxy de `ss1`), y luego `collector update` + `collect` y `anonymizer`, como dice el doc 12.
   - **Pasos 6–7 (supervisar y compartir):** en la pestaña **Ports**, pon los puertos **8000** y **8001** en visibilidad **Public** y abre sus URLs: esas son tus vistas de Opendata y Networking, listas para ver y capturar. (El túnel de Cloudflare del doc 12 no hace falta aquí: el reenvío público de Codespaces cumple ese papel dentro de esta sesión temporal.)
3. Al terminar: **borra el codespace** (repo → Code → Codespaces → ⋯ → Delete, o en github.com/codespaces). Borrarlo detiene todo consumo de cuota.

## Qué queda tras la sesión
Nada en la nube — y es lo buscado. Las capturas que tomes y cualquier ajuste que hagas a los documentos/scripts **súbelo al repo** (commit desde el propio codespace) antes de borrarlo, o se pierde con la sesión.
