# 14 — Replicación del laboratorio e incidencias

**Para qué:** reconstruir el laboratorio de los docs 12 y 13 desde cero en un codespace nuevo, aplicando todos los parches y rodeos descubiertos en la primera puesta en marcha (2026-11-21). Si el codespace se borra, esta guía junto con los docs 12 y 13 basta para replicarlo todo; no hace falta ningún conocimiento fuera de este repositorio.

## Qué se pierde y qué no cuando el codespace desaparece

- **Apagado por inactividad (timeout):** no se pierde nada. El disco del codespace persiste y los contenedores quedan parados, no eliminados, con su configuración dentro. Al reabrirlo basta relanzar la pila con `./local-dev-run.sh` (sin `--initialize`) desde `~/X-Road/Docker/xrd-dev-stack` y seguir.
- **Codespace eliminado** (borrado manual o retención de GitHub): se pierde el entorno — el clon de X-Road, los contenedores y su configuración, y el parche del punto 3 de la secuencia. Se replica con la secuencia de abajo; el coste es el tiempo de construcción de imágenes e inicialización.
- Los contenedores de la pila **no tienen volúmenes persistentes** (README de `xrd-dev-stack`): eliminar un contenedor borra su configuración. No elimines contenedores salvo que esta guía lo indique (recrear `cs` en la incidencia 4).

## Secuencia de replicación (desde cero)

1. **Crear el codespace** desde este repo (máquina de 4 núcleos / 16 GB; sube el idle timeout a 4 h en la configuración de Codespaces). La imagen del devcontainer está fijada a `ubuntu-24.04` (incidencia 1).
2. **Clonar la pila X-Road fijada** en el commit verificado:

   ```bash
   git clone https://github.com/nordic-institute/X-Road.git ~/X-Road
   cd ~/X-Road && git checkout 1ffb1405
   ```

3. **Aplicar el parche del `setup.hurl`** (incidencia 3) *antes* de que se construya la imagen `hurl`, porque los scenarios se copian dentro de la imagen al construirla:

   ```bash
   sed -i '/acme_server_directory_url/a default_csr_format: PEM' ~/X-Road/development/hurl/scenarios/setup.hurl
   grep -n "default_csr_format" ~/X-Road/development/hurl/scenarios/setup.hurl
   ```

   El `grep` debe imprimir la línea añadida; si no imprime nada, el parche no se aplicó.

4. **Levantar la pila** (sin `--initialize`; la inicialización va en el paso 5 por la incidencia 2):

   ```bash
   cd ~/X-Road/Docker/xrd-dev-stack
   ./local-dev-run.sh
   ```

   La terminal queda ocupada en primer plano con los logs (es normal; no la cierres ni pulses Ctrl+C). En otra terminal, `docker ps` debe mostrar todo `healthy` excepto `isopenapi` (esperado: incidencia 2).

5. **Inicializar** (Central Server + ss0 + ss1) lanzando el script de inicialización directamente, saltando el chequeo de dependencias:

   ```bash
   docker compose -f compose.yaml -f compose.dev.yaml --env-file .env run --rm --no-deps hurl --insecure --variables-file /hurl-src/vars.env --file-root /hurl-files /hurl-src/setup.hurl --retry 12 --retry-interval 10000
   ```

   Es el mismo comando que ejecuta `local-dev-run.sh --initialize` por dentro, sin el chequeo que bloquea `isopenapi`. Tarda unos minutos y al terminar devuelve el cursor.

6. **Verificar la inicialización:** consola del CS (puerto 4100, HTTPS, visibilidad Private) con `xrd` / `secret` → debe verse el panel con la instancia **DEV**, sin formulario de configuración inicial; consola de `ss0` (4200) → clientes del miembro `COM/1234`.

7. **Seguir con el doc 12**, Pasos 3 a 7: registrar el cliente de monitoreo `COM/1234/metrics` en `ss0`, `bash desplegar.sh piloto`, generar tráfico, verificar y publicar solo los puertos 8000/8001.

## Incidencias encontradas (2026-11-21)

1. **Docker-in-Docker no se instalaba con `base:ubuntu`.** Esa etiqueta apunta hoy a Ubuntu «resolute», donde los paquetes *moby* no existen; la feature fallaba al instalarse y Codespaces abría un contenedor de recuperación Alpine sin los permisos que Docker necesita (sin CAP_NET_ADMIN ni CAP_SYS_ADMIN: ni con `apk` ni a mano se puede ejecutar Docker ahí). Corregido en este repo fijando la imagen a `ubuntu-24.04` (commit `5052d99`). Detalle en el doc 13.
2. **`isopenapi` queda «unhealthy» aunque funciona.** Su healthcheck (`curl -f -k http://localhost:8080/v3/api-docs` dentro del contenedor) falla, pero la aplicación responde 200 en `http://localhost:4700/v3/api-docs`. Ese estado bloquea cualquier `docker compose` que lo tenga como dependencia («dependency failed to start: container isopenapi is unhealthy»), incluida la inicialización oficial. Rodeo: lanzar el `hurl` con `run --no-deps` (paso 5). `isopenapi` es un auxiliar del Information System, ajeno a la cadena de monitoreo.
3. **Bug del commit fijado: al `setup.hurl` le falta `default_csr_format`.** La API del CS de `1ffb1405` exige el parámetro multipart `default_csr_format` (tipo `CsrFormatDto`) al crear un servicio de certificación, y el `setup.hurl` del mismo commit no lo envía: `POST /api/v1/certification-services` devuelve `400 {"status":400}` y la inicialización se detiene en su línea 165. El motivo exacto consta en el log de auditoría del CS (`/var/log/xroad/centralserver-admin-service.log` dentro del contenedor `cs`): *Required request parameter 'default_csr_format' for method parameter type CsrFormatDto is not present*. Arreglo verificado: añadir `default_csr_format: PEM` tras la línea `acme_server_directory_url` (paso 3); con ese campo el CS crea el servicio (Test CA, id 1). Si el parche se aplica *después* de construir la imagen `hurl`, hay que reconstruirla: `docker compose -f compose.yaml -f compose.dev.yaml --env-file .env build hurl`.
4. **Si la inicialización ya corrió a medias**, el script no es re-ejecutable sobre un CS ya inicializado (el `POST /initialization` fallaría y abortaría el resto). Recrear **solo** el CS y repetir desde el paso 5:

   ```bash
   docker compose -f compose.yaml -f compose.dev.yaml --env-file .env up -d --force-recreate cs
   until [ "$(docker inspect cs --format '{{.State.Health.Status}}')" = "healthy" ]; do sleep 10; done; echo "cs sano"
   ```

   Si el fallo fue en la sección del CS (línea 165), `ss0` y `ss1` aún no se habían tocado y no hay que recrearlos.
5. **Acceso a la API del CS para diagnóstico.** No acepta autenticación básica (401). El flujo es de sesión: `GET https://localhost:4100/` (siembra la cookie `XSRF-TOKEN`) → `POST /login` con `username=xrd&password=secret` guardando las cookies → en cada llamada, cabecera `X-XSRF-TOKEN` con el valor de esa cookie (sin ella, 403). Usuario de consolas y API: `xrd` / `secret`. PIN del token de software: `Secret1234` (no `1234`; ese es solo el SO-PIN del token de `ss1`). Instancia: `DEV`. Dirección del Central Server: `cs` (nombre interno de la red Docker; la URL `*.app.github.dev` es solo la puerta del navegador, no se guarda en la configuración).
6. **Puertos de la pila.** Consolas web (HTTPS): **4100** CS, **4200** ss0, **4300** ss1 — en la pestaña Ports quedan en **Private** y el 4200 con protocolo **HTTPS** (si queda en HTTP, la UI responde «Bad Request: This combination of host and port requires TLS»). Los puertos **4120/4220/4320** son PostgreSQL, no webs. Proxies de mensajería: 4210 (ss0) y **4310** (ss1, el del tráfico de prueba).
7. **El certificado de la CA no está en el repo.** `testca` lo genera al arrancar y lo deja en el volumen Docker `xrd-dev-stack_ca-volume` (`ca.pem`, `ocsp.pem`, `tsa.pem`); el servicio `hurl` lo monta en `/hurl-files/ca`. Que `find` no encuentre ningún `ca.pem` en el clon es normal. El certificado verificado: auto-firmado `O = Test, CN = Test CA`, válido 2026–2046. El servidor ACME de `testca` responde en el puerto 8887 (`/directory` devuelve el directorio ACME).

## Datos fijos de la pila (recordatorio)

- Instancia **DEV**; miembro de gestión `COM/1234` con subsistema `MANAGEMENT` (el CS lo usa como su servicio de gestión).
- Productor en `ss0`: `DEV:COM:1234:TestService`, servicio `getRandom` v1. Consumidor en `ss1`: `DEV:COM:4321:TestClient`.
- Cliente de monitoreo a registrar en `ss0`: `COM/1234/metrics` (doc 12, Paso 3). El Central Server no recolecta métricas: salen solo del OpMon de los Security Servers a través de `ss0`.
- En cualquier enlace público solo se exponen **Opendata (8000)** y **Networking (8001)**, con datos anonimizados. Consolas de administración y bases de datos, nunca.
