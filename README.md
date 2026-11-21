# xroad-monitoring

Monitoreo funcional de la plataforma X-Road mediante **X-Road Metrics** (herramienta oficial de código abierto de NIIS): recolección, procesamiento, análisis y publicación de los datos de monitoreo operacional de los Security Servers.

## Documentación del proyecto

| Doc | Contenido |
|---|---|
| [01 — Descripción del proyecto](docs/01-descripcion-proyecto.md) | Propósito, alcance, datos monitoreados, actores y parámetros de la plataforma por completar |
| [02 — Requisitos](docs/02-requisitos.md) | Requisitos funcionales (REQ) y no funcionales (RNF) con criterios de aceptación |
| [03 — Arquitectura](docs/03-arquitectura.md) | Módulos, flujo de datos, niveles de privacidad, puertos |
| [04 — Diseño de despliegue](docs/04-diseno-despliegue.md) | Tres escenarios (piloto / producción recomendada / gran escala), dimensionamiento y reglas de firewall |
| [05 — Guía de instalación](docs/05-guia-instalacion.md) | Paso a paso: requisitos previos en X-Road, MongoDB, paquetes, primera recolección y alternativa Docker |
| [06 — Configuración](docs/06-configuracion.md) | `settings.yaml` por módulo, perfiles por entorno, cron, logs y heartbeat |
| [07 — Operación y mantenimiento](docs/07-operacion-mantenimiento.md) | Rutinas, respaldos, actualizaciones e incidencias frecuentes |
| [08 — Seguridad](docs/08-seguridad.md) | Clasificación de datos, controles obligatorios y riesgos |
| [09 — Pruebas y aceptación](docs/09-pruebas-aceptacion.md) | Casos de prueba y criterios de go-live |
| [10 — Plan de implementación](docs/10-plan-implementacion.md) | Fases 0–3, riesgos y decisiones pendientes |
| [Diagrama de despliegue](docs/diagrama-despliegue.md) | Diagrama (PNG + fuente Mermaid editable) |
| [11 — Despliegue con Docker](docs/11-despliegue-docker.md) | Composes para piloto, zona privada y zona pública, sobre el setup Docker oficial |
| [12 — Laboratorio X-Road de prueba](docs/12-laboratorio-xroad-prueba.md) | Laboratorio completo: X-Road de prueba (xrd-dev-stack) + Metrics + tráfico generado + enlace público de supervisión |
| [13 — Laboratorio en Codespaces](docs/13-laboratorio-codespaces.md) | Opción temporal y gratuita: el laboratorio en GitHub Codespaces (4 núcleos/16 GB, ~30 h/mes gratis) para verlo y tomar instantáneas |
| [14 — Replicación e incidencias](docs/14-replicacion-laboratorio.md) | Cómo reconstruir el laboratorio desde cero si el codespace se borra, con las incidencias de la primera puesta en marcha (parche `default_csr_format`, healthcheck de isopenapi, imagen del devcontainer) |
| [Referencias](docs/referencias.md) | Fuentes oficiales de NIIS utilizadas |

## Despliegue con Docker
En [`deploy/docker/`](deploy/docker/README.md) hay tres Docker Compose listos (piloto todo-en-uno, zona privada y zona pública), con `.env` de ejemplo y scripts de preparación y despliegue.

## Cómo incorporar un requisito nuevo
1. Abre un Issue con la plantilla **Requisito** (`.github/ISSUE_TEMPLATE/requisito.md`).
2. Asigna prioridad (Alta / Media / Baja) y tipo (Funcional / No funcional).
3. Cuando se apruebe, añádelo a `docs/02-requisitos.md` con su ID (REQ-xxx / RNF-xxx).

## Estado
Fase 0 — Documentación inicial completa. Pendiente: completar los parámetros de la plataforma (doc 01, §6) y las decisiones del doc 10 para iniciar el piloto.
