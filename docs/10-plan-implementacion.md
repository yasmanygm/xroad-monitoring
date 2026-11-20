# 10 — Plan de implementación

## Fases

### Fase 0 — Preparación (plazo orientativo: 1 semana)
- [ ] Completar los parámetros de la plataforma (`01-descripcion-proyecto.md` §6)
- [ ] Aprobar requisitos (`02-requisitos.md`) y escenario de despliegue (`04-diseno-despliegue.md`)
- [ ] Crear el repositorio `xroad-monitoring` en GitHub y subir esta documentación
- [ ] Aprovisionar hosts/DNS/firewall del escenario elegido
- [ ] Habilitar OpMon y autorizar al cliente de monitoreo en un **SS piloto** (y planificar el despliegue al resto)

### Fase 1 — Monitoreo funcional interno (núcleo del proyecto)
- [ ] Instalar MongoDB + Collector + Corrector (guía `05`, pasos 1–5)
- [ ] Primera recolección validada contra el SS piloto (pruebas P-01…P-05)
- [ ] Extender la autorización OpMon a todos los SS de la instancia
- [ ] Activar cron, logs, heartbeat, respaldos y monitoreo del propio Metrics
- [ ] Instalar Reports e informe mensual (paso 6)
- [ ] Aceptación: subconjunto de go-live de `09-pruebas-aceptacion.md`
- **Entregable:** estadísticas internas de uso y salud de servicios, operando de forma desatendida.

### Fase 2 — Publicación (opcional, tras decisión expresa)
- [ ] Revisión legal: campos a anonimizar, miembros excluidos, retardo de publicación
- [ ] Instalar Anonymizer + PostgreSQL + Opendata (paso 7) en zona pública separada
- [ ] Instalar Networking/Visualizer (paso 8)
- [ ] Auditoría de anonimización (P-09…P-11) y go-live del portal

### Fase 3 — Mejora continua
- Ajuste de frecuencia de recolección y retención según crecimiento real
- Evaluación del Opendata Collector si aparecen varias instancias que agregar
- Revisión trimestral de requisitos: nuevos informes, alertas funcionales (p. ej. caída de tasa de éxito de un servicio crítico)

## Riesgos del plan
| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Los SS de los miembros no tienen OpMon habilitado o no autorizan al cliente | Alta | Empezar por un piloto; circular del operador con instrucciones y fecha límite; la recolección funciona parcialmente mientras tanto |
| Volumen real muy superior al estimado | Media | Piloto mide el volumen real antes de dimensionar producción |
| Open Data se retrasa por revisión legal | Media | Está desacoplado: la fase 1 no depende de él |
| Actualización de X-Road introduce campos nuevos no anonimizados | Media | Procedimiento de actualización con revisión del Anonymizer (`07`) |

## Decisiones que necesito de ti para cerrar la fase 0
1. Código de instancia y entornos a monitorear (¿solo PROD o también TEST/DEV?)
2. Host del Central Server y del SS que actuará como puerta de entrada
3. Subsistema que será el cliente de monitoreo (¿existe ya o hay que registrarlo?)
4. N.º aproximado de Security Servers y de llamadas/día (si no lo sabes, lo medimos en el piloto)
5. Escenario de despliegue: A (piloto Docker/paquetes en 1 host), B (recomendado) o C (gran escala)
6. ¿Open Data en fase 2: sí, no, o decidir después? ¿Informes a miembros: sí/no?
