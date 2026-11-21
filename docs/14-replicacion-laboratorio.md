# 14 — Replicación del laboratorio e incidencias

**Para qué:** reconstruir el laboratorio de los docs 12 y 13 desde cero en un codespace nuevo, aplicando todos los parches y rodeos descubiertos en la primera puesta en marcha (2026-11-21). Si el codespace se borra, esta guía junto con los docs 12 y 13 basta para replicarlo todo; no hace falta ningún conocimiento fuera de este repositorio. La puesta en marcha inicial se **completó y verificó el 2026-11-21**: la inicialización corrió de principio a fin y los clientes de `ss1` quedaron `REGISTERED`. El clon ya parcheado vive además en el repo privado **yasmanygm/X-Road-lab**, rama `laboratorio-metrics` (vía rápida del paso 2).

## Qué se pierde y qué no cuando el codespace desaparece

- **Apagado por inactividad (timeout):** no se pierde nada. El disco del codespace persiste y los contenedores quedan parados, no eliminados, con su configuración dentro. Al reabrirlo basta relanzar la pila con `./local-dev-run.sh` (sin `--initialize`) desde `~/X-Road/Docker/xrd-dev-stack` y seguir.
- **Codespace eliminado** (borrado manual o retención de GitHub): se pierde el entorno — el clon de X-Road, los contenedores y su configuración. Los parches no se pierden: viven en **yasmanygm/X-Road-lab** (rama `laboratorio-metrics`) y en el paso 3 de esta guía. Se replica con la secuencia de abajo; el coste es el tiempo de construcción de imágenes e inicialización.
- El README de `xrd-dev-stack` dice que los contenedores no tienen volúmenes persistentes, pero es impreciso para los SS: cada SS monta **cuatro volúmenes anónimos** (`/etc/xroad`, `/var/lib/xroad`, `/var/lib/softhsm/tokens`, `/var/lib/postgresql/16/main`) que Compose vuelve a adjuntar al recrear el contenedor, así que un `--force-recreate` a secas **no** deja un SS virgen (el CS sí se limpia al recrearlo). Para reiniciar un SS de verdad hay que recrearlo con `--renew-anon-volumes` (incidencia 4). No elimines contenedores salvo que esta guía lo indique.

## Secuencia de replicación (desde cero)

1. **Crear el codespace** desde este repo (máquina de 4 núcleos / 16 GB; sube el idle timeout a 4 h en la configuración de Codespaces). La imagen del devcontainer está fijada a `ubuntu-24.04` (incidencia 1).
2. **Obtener el clon de X-Road.** Vía rápida: clonar el repo privado **yasmanygm/X-Road-lab**, rama `laboratorio-metrics` (es el commit `1ffb1405` con todos los parches ya aplicados y los nombres de miembro del apartado «Datos fijos»; salta al paso 4). Es privado: desde el codespace se clona por SSH con la clave registrada en la cuenta (la del primer codespace quedó en `~/.ssh/lab` de aquel entorno; en uno nuevo hay que crearla y darla de alta en GitHub). Vía larga: clonar el oficial fijado en el commit verificado y aplicar el paso 3:

   ```bash
   git clone https://github.com/nordic-institute/X-Road.git ~/X-Road
   cd ~/X-Road && git checkout 1ffb1405
   ```

3. **Aplicar los parches** (solo en la vía larga) *antes* de que se construya la imagen `hurl`, porque los scenarios se copian dentro de la imagen al construirla. Son siete líneas en el `setup.hurl` (incidencias 3 y 9), una en la captura del token de `ss1` (incidencia 10) y dos en el `vars.env` (incidencia 11):

   ```bash
   cd ~/X-Road/development/hurl/scenarios
   sed -i '/acme_server_directory_url/a default_csr_format: DER' setup.hurl
   sed -i '\|url: http://{{ca_host}}:8888|a cost_type: FREE' setup.hurl
   sed -i '\|url: http://{{ca_host}}:8899|a cost_type: FREE' setup.hurl
   sed -i '/"name": "{{tsa_name}}",/a\    "cost_type": "FREE",' setup.hurl
   sed -i '/ss1_token_id/s/ nth 0$//' setup.hurl
   sed -i 's/^ss0_proxy=localhost/ss0_proxy=ss0/; s/^ss1_proxy=localhost/ss1_proxy=ss1/' vars.env
   grep -n "cost_type\|default_csr_format" setup.hurl; grep "_proxy" vars.env
   ```

   El primer `grep` debe imprimir **5 líneas** (el `default_csr_format: DER`, los dos `cost_type: FREE` de multipart y los dos `"cost_type": "FREE"` de JSON) y el segundo, `ss0_proxy=ss0` y `ss1_proxy=ss1`; si falta algo, ese parche no se aplicó. Ojo al formato CSR: es **DER**, no PEM (incidencia 3).

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

   Es el mismo comando que ejecuta `local-dev-run.sh --initialize` por dentro, sin el chequeo que bloquea `isopenapi`. Lánzalo solo cuando `cs`, `ss0` y `ss1` estén `healthy` (`docker compose -f compose.yaml -f compose.dev.yaml ps`): si sale al instante con «Failed to connect to cs:4000» es solo tiempo de arranque — espera y repite el mismo comando, sin recrear nada. Tarda unos minutos y **al terminar no imprime nada**: en `hurl` el silencio significa que todas las aserciones pasaron (la corrida completa del 2026-11-21 terminó exactamente así).

6. **Verificar la inicialización:** consola del CS (puerto 4100, HTTPS, visibilidad Private) con `xrd` / `secret` → debe verse el panel con la instancia **DEV**, sin formulario de configuración inicial; consola de `ss0` (4200) → clientes del miembro `COM/1234`. La verificación definitiva es por API (flujo de sesión de la incidencia 5): `GET /api/v1/security-servers` en el CS lista `DEV:COM:1234:SS0` y `DEV:COM:4321:SS1`, y `GET /api/v1/clients` en `ss1` muestra el propietario `4321`, `TestClient` y `test-consumer` todos en estado `REGISTERED` (así quedó verificado el 2026-11-21).

7. **Seguir con el doc 12**, Pasos 3 a 7: registrar el cliente de monitoreo `COM/1234/metrics` en `ss0`, `bash desplegar.sh piloto`, generar tráfico, verificar y publicar solo los puertos 8000/8001.

## Incidencias encontradas (2026-11-21)

1. **Docker-in-Docker no se instalaba con `base:ubuntu`.** Esa etiqueta apunta hoy a Ubuntu «resolute», donde los paquetes *moby* no existen; la feature fallaba al instalarse y Codespaces abría un contenedor de recuperación Alpine sin los permisos que Docker necesita (sin CAP_NET_ADMIN ni CAP_SYS_ADMIN: ni con `apk` ni a mano se puede ejecutar Docker ahí). Corregido en este repo fijando la imagen a `ubuntu-24.04` (commit `5052d99`). Detalle en el doc 13.
2. **`isopenapi` queda «unhealthy» aunque funciona.** Su healthcheck (`curl -f -k http://localhost:8080/v3/api-docs` dentro del contenedor) falla, pero la aplicación responde 200 en `http://localhost:4700/v3/api-docs`. Ese estado bloquea cualquier `docker compose` que lo tenga como dependencia («dependency failed to start: container isopenapi is unhealthy»), incluida la inicialización oficial. Rodeo: lanzar el `hurl` con `run --no-deps` (paso 5). `isopenapi` es un auxiliar del Information System, ajeno a la cadena de monitoreo.
3. **Bug del commit fijado: al `setup.hurl` le faltan tres parámetros que la API exige.** La API de `1ffb1405` pide datos que el `setup.hurl` del mismo commit no envía; cada hueco detiene la inicialización con un `400 {"status":400}` y el motivo exacto («Required request parameter '…' … is not present») consta en el log de auditoría del CS (`/var/log/xroad/centralserver-admin-service.log` dentro del contenedor `cs`):
   - `default_csr_format` al crear el servicio de certificación: sin él, `POST /api/v1/certification-services` devuelve `400` y el script se detiene en su línea 165. Arreglo: añadir `default_csr_format: DER` tras la línea `acme_server_directory_url` (paso 3). **El valor importa:** con PEM el servicio también se crea, pero después los Security Servers no pueden generar sus CSR — el propio `setup.hurl` las pide en DER en los cinco pasos `keys-with-csrs` — y la inicialización muere en `ss0` con `invalid_csr_format` (incidencia 8).
   - `cost_type` al añadir el respondedor OCSP: sin él, `POST /api/v1/certification-services/<id>/ocsp-responders` devuelve `400` y el script se detiene en su línea 178. Arreglo: añadir `cost_type: FREE` tras la línea `url: http://{{ca_host}}:8888`.
   - `cost_type` al crear el servicio de sellado de tiempo (`POST /api/v1/timestamping-services`), paso de la misma forma que el anterior. Arreglo: añadir `cost_type: FREE` tras la línea `url: http://{{ca_host}}:8899`. Probado a mano antes de parchear: con el campo, el CS creó el TSA (id 1, intervalo 60).

   Cada arreglo se verificó primero repitiendo la llamada a mano con la sesión de la API (incidencia 5) y solo después se dejó en el script. Si un parche se aplica *después* de construir la imagen `hurl`, hay que reconstruirla: `docker compose -f compose.yaml -f compose.dev.yaml --env-file .env build hurl`.
4. **Si la inicialización ya corrió a medias**, el script no es re-ejecutable sobre un CS ya inicializado (el `POST /initialization` fallaría y abortaría el resto). Recrear **solo** el CS y repetir desde el paso 5:

   ```bash
   docker compose -f compose.yaml -f compose.dev.yaml --env-file .env up -d --force-recreate cs
   until [ "$(docker inspect cs --format '{{.State.Health.Status}}')" = "healthy" ]; do sleep 10; done; echo "cs sano"
   ```

   Qué contenedores recrear depende de hasta dónde llegó el script, y se comprueba con la API (incidencia 5): `GET /api/v1/security-servers` en el CS y `GET /api/v1/clients` en cada SS. Si el fallo fue en la sección del CS, `ss0` y `ss1` aún no se habían tocado y basta recrear `cs`. Si el script ya entró en la sección de un SS, ese SS quedó inicializado a medias (p. ej. `ss0` con su miembro propietario en estado `SAVED` y sin certificado de firma válido) y hay que recrearlo también:

   ```bash
   docker compose -f compose.yaml -f compose.dev.yaml --env-file .env up -d --force-recreate --renew-anon-volumes cs ss0
   ```

   El `--renew-anon-volumes` es imprescindible en los SS: cada uno monta cuatro volúmenes anónimos (ver «Qué se pierde y qué no») que Compose reataja al contenedor recreado, así que sin esa opción el SS conserva su configuración a medias y la siguiente corrida muere en `POST /api/v1/system/anchor` con un `409` (el SS ya tiene ancla). Síntoma y arreglo verificados el 2026-11-21. Si la corrida llegó también a `ss1`, se recrean los tres: `up -d --force-recreate --renew-anon-volumes cs ss0 ss1`.
5. **Acceso a la API del CS para diagnóstico.** No acepta autenticación básica (401). El flujo es de sesión: `GET https://localhost:4100/` (siembra la cookie `XSRF-TOKEN`) → `POST /login` con `username=xrd&password=secret` guardando las cookies → en cada llamada, cabecera `X-XSRF-TOKEN` con el valor de esa cookie (sin ella, 403). Usuario de consolas y API: `xrd` / `secret`. PIN del token de software: `Secret1234` (no `1234`; ese es solo el SO-PIN del token de `ss1`). Instancia: `DEV`. Dirección del Central Server: `cs` (nombre interno de la red Docker; la URL `*.app.github.dev` es solo la puerta del navegador, no se guarda en la configuración). El mismo flujo de sesión sirve en los SS (puertos 4200/4300), y el log de auditoría de un SS es `/var/log/xroad/proxy_ui_api.log` dentro de su contenedor (en los SS no existe ningún `*admin-service.log`).
6. **Puertos de la pila.** Consolas web (HTTPS): **4100** CS, **4200** ss0, **4300** ss1 — en la pestaña Ports quedan en **Private** y el 4200 con protocolo **HTTPS** (si queda en HTTP, la UI responde «Bad Request: This combination of host and port requires TLS»). Los puertos **4120/4220/4320** son PostgreSQL, no webs. Proxies de mensajería: 4210 (ss0) y **4310** (ss1, el del tráfico de prueba).
7. **El certificado de la CA no está en el repo.** `testca` lo genera al arrancar y lo deja en el volumen Docker `xrd-dev-stack_ca-volume` (`ca.pem`, `ocsp.pem`, `tsa.pem`); el servicio `hurl` lo monta en `/hurl-files/ca`. Que `find` no encuentre ningún `ca.pem` en el clon es normal. El certificado verificado: auto-firmado `O = Test, CN = Test CA`, válido 2026–2046. El servidor ACME de `testca` responde en el puerto 8887 (`/directory` devuelve el directorio ACME).
8. **Si el formato CSR del CS no coincide con el que pide el script, `ss0` no puede generar sus claves.** Síntoma: la inicialización completa la sección del CS y se detiene en la de `ss0`. Su log de auditoría (`/var/log/xroad/proxy_ui_api.log`) repite cada 10 s (los reintentos del `hurl`): *Generate key and CSR failed … reason: Error[code=invalid_csr_format]*, en `POST /api/v1/tokens/0/keys-with-csrs`. Causa: el servicio de certificación del CS quedó con `default_csr_format: PEM` y el `setup.hurl` pide las CSR en `DER`. Arreglo: dejar el parche de la incidencia 3 en **DER**, recrear `cs` y `ss0` (incidencia 4) y repetir la inicialización. El estado intermedio que deja este fallo: CS completo pero sin Security Servers registrados, `ss0` inicializado a medias (miembro `DEV:COM:1234` en estado `SAVED`, sin certificado de firma) y `ss1` sin inicializar (su API responde «Server conf is not initialized!»).
9. **El sellado de tiempo en los SS pide `cost_type` en el JSON, y en el cable va en snake_case.** Cuarto hueco del mismo tipo que la incidencia 3, pero en la API de los SS: sin el campo, `POST /api/v1/system/timestamping-services` devuelve `400` y su `proxy_ui_api.log` dice que el campo `costType` «must not be null». La trampa: ese nombre es el del campo Java del mensaje de validación; en el cable la API usa snake_case (como todos los demás cuerpos del script) y con `"costType"` el JSON se ignora en silencio y el campo sigue a null. El nombre bueno es `"cost_type"`. Discriminador usado: `GET /api/v1/timestamping-services` en `ss0` devuelve el servicio con `"cost_type":"FREE"`, y el POST manual con `cost_type` y los valores reales dio `201`. Arreglo (paso 3): añadir `"cost_type": "FREE",` tras cada línea `"name": "{{tsa_name}}",` — dos sitios, el de `ss0` y el de `ss1`. En la API del CS el campo también es `cost_type` (multipart): es snake_case en todas partes.
10. **La captura del token hardware de `ss1` lleva un `nth 0` que la versión actual de `hurl` rechaza.** Síntoma: la corrida supera el CS y todo `ss0`, y se detiene en la sección de `ss1` al capturar `ss1_token_id`, con error del propio `hurl` («invalid filter input type: actual string, expected list»; la aserción HTTP 200 previa sí pasa). La consulta jsonpath ya devuelve el id como cadena única (solo hay un token hardware) y `nth` espera una lista: es deriva de versión de la imagen `hurl:latest` frente a cuando se escribió el script. Arreglo (paso 3): quitar ` nth 0` de esa línea. `ss0` no hace esta captura (usa el token `0` directamente). Ojo: tras un reinicio o recreación, los tokens de un SS quedan deslogueados; el login del token hardware de `ss1` es `PUT /api/v1/tokens/<id>/login` con `{"password":"Secret1234"}` y el id se extrae de `GET /api/v1/tokens` (en el codespace no hay `python3`: se filtra con `tr '{' '\n'` y `grep`).
11. **`vars.env` registra los SS con dirección `localhost` y `ss1` se envía los mensajes de gestión a sí mismo.** La causa raíz de los fallos de registro en `ss1`, y la incidencia que más costó: el `vars.env` trae `ss0_proxy=localhost` y `ss1_proxy=localhost`, y el script registra esas direcciones en el CS como la dirección de cada SS. La configuración global dice por tanto que SS0 está en «localhost», y desde el contenedor de `ss1` eso es él mismo: su clientproxy entrega los mensajes de gestión (y entregaría los de servicio) a su propio serverproxy. Cadena de síntomas: (a) el registro de `TestClient` devuelve `500` con `ssl_authentication_failed: Client 'SUBSYSTEM:DEV/COM/1234/MANAGEMENT' is not registered at security server SERVER:DEV/COM/4321/SS1` — es el clientproxy de `ss1` verificando el certificado del «servidor» al que conectó (él mismo) contra el proveedor `MANAGEMENT`; (b) si se registra `MANAGEMENT` como cliente de `ss1` a mano (alta local + petición con origen CENTER en el CS + aprobación, que lo deja `REGISTERED`), esa puerta pasa y el mensaje muere en el serverproxy local con `signer.unknown_member` para `MANAGEMENT`, porque su clave vive en `ss0`. Ni `ss0` ni el CS ven nada en sus logs y el id de correlación del fallo solo existe en los de `ss1` — esa fue la pista definitiva, junto con el `proxy.log` de `ss1` mostrando a su serverproxy procesando el mensaje. **No falta ningún paso de registro de `MANAGEMENT` en el script**: su diseño es correcto (el mensaje va con cliente = miembro propietario del SS que registra y servicio = `clientReg` de `MANAGEMENT`, confirmado en el código de NIIS); lo único roto es la dirección. Arreglo (paso 3): en `vars.env`, `ss0_proxy=ss0` y `ss1_proxy=ss1`, los nombres de contenedor de la red `xroad-network`. Con eso, y sin ningún paso extra, la inicialización completa pasó de principio a fin.

## Datos fijos de la pila (recordatorio)

- Instancia **DEV**; miembro de gestión `COM/1234` con subsistema `MANAGEMENT` (el CS lo usa como su servicio de gestión).
- Nombres de los miembros (visibles, elegidos el 2026-11-21): `COM/1234` se llama **Xroad Identidad** y `COM/4321`, **Xroad GD**. En el clon parcheado ya van así (`member_name` y campo `O` de las CSR); los códigos no cambian.
- Productor en `ss0`: `DEV:COM:1234:TestService`, servicio `getRandom` v1. Consumidor en `ss1`: `DEV:COM:4321:TestClient`.
- Cliente de monitoreo a registrar en `ss0`: `COM/1234/metrics` (doc 12, Paso 3). El Central Server no recolecta métricas: salen solo del OpMon de los Security Servers a través de `ss0`.
- En cualquier enlace público solo se exponen **Opendata (8000)** y **Networking (8001)**, con datos anonimizados. Consolas de administración y bases de datos, nunca.
