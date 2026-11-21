#!/usr/bin/env bash
# ============================================================
# generar-init.sh — Genera los scripts de inicialización de BD
# adaptados a TU instancia y a TUS contraseñas.
#
# Por qué existe: los scripts oficiales (Docker/mongodb-init y
# Docker/postgresql-init del repo X-Road-Metrics) vienen FIJOS
# para la instancia DEV y con contraseñas de desarrollo
# (collectordevpw, anonymizer_devsecret, base opendata_dev...).
# Si tu instancia o tus contraseñas son otras, la autenticación
# de los módulos falla. Este script copia esos ficheros a
# ./init-generado/ y sustituye instancia y contraseñas usando
# los valores del .env.
#
# IMPORTANTE: los scripts de init de MongoDB/PostgreSQL SOLO se
# ejecutan cuando el volumen de datos está vacío (primer
# arranque). Si cambias .env después, hay que recrear los
# volúmenes (docker compose down -v) o aplicar los cambios a mano.
#
# Uso:  ./generar-init.sh        (desde la carpeta Docker/ del
#        repo oficial, con el .env ya copiado en esa carpeta)
# ============================================================
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "ERROR: no hay .env en esta carpeta. Copia .env.example a .env y rellénalo." >&2
  exit 1
fi
set -a; # shellcheck disable=SC1091
source .env; set +a

INSTANCE="${XROAD_INSTANCE:?Define XROAD_INSTANCE en .env}"
LOWER="${INSTANCE_LOWER:?Define INSTANCE_LOWER en .env (la instancia en minusculas)}"

for d in mongodb-init postgresql-init; do
  [[ -d "$d" ]] || { echo "ERROR: no existe ./$d — ¿estás en la carpeta Docker/ del repo oficial?" >&2; exit 1; }
done

rm -rf init-generado
mkdir -p init-generado
cp -r mongodb-init init-generado/mongodb-init
cp -r postgresql-init init-generado/postgresql-init

# --- MongoDB: contraseñas por módulo y sufijo de instancia en las BD ---
# (Los nombres de usuario oficiales <modulo>dev se mantienen: son solo
#  identificadores y los composes los usan tal cual.)
sed -i "s/collectordevpw/${MONGO_COLLECTOR_PASSWORD}/g"                 init-generado/mongodb-init/mongo-init-collector.js
sed -i "s/correctordevpw/${MONGO_CORRECTOR_PASSWORD}/g"                 init-generado/mongodb-init/mongo-init-corrector.js
sed -i "s/anonymizerdevpw/${MONGO_ANONYMIZER_PASSWORD}/g"               init-generado/mongodb-init/mongo-init-anonymizer.js
sed -i "s/reportsdevpw/${MONGO_REPORTS_PASSWORD}/g"                     init-generado/mongodb-init/mongo-init-reports.js
sed -i "s/opendatacollectordevpw/${MONGO_OPENDATA_COLLECTOR_PASSWORD}/g" init-generado/mongodb-init/mongo-init-opendata-collector.js
sed -i "s/_DEV/_${INSTANCE}/g" init-generado/mongodb-init/*.js

# --- PostgreSQL: contraseñas, usuarios y BD con la instancia real ---
SQL=init-generado/postgresql-init/init-opendata-db.sql
sed -i "s/anonymizer_devsecret/${PG_ANONYMIZER_PASSWORD}/g" "$SQL"
sed -i "s/opendata_devsecret/${PG_OPENDATA_PASSWORD}/g"     "$SQL"
sed -i "s/networking_devsecret/${PG_NETWORKING_PASSWORD}/g" "$SQL"
sed -i "s/anonymizer_dev/anonymizer_${LOWER}/g"             "$SQL"
sed -i "s/networking_dev/networking_${LOWER}/g"             "$SQL"
sed -i "s/opendata_dev/opendata_${LOWER}/g"                 "$SQL"

# --- Verificación: no deben quedar las contraseñas de desarrollo de la plantilla ---
# (El sufijo _DEV en los nombres de BD es correcto cuando la instancia es DEV;
#  solo es un resto sin sustituir si la instancia es otra.)
if grep -RInE "devpw|devsecret" init-generado/ ; then
  echo "ERROR: quedan contraseñas de desarrollo sin sustituir (revisa lo anterior)." >&2
  exit 1
fi
if [[ "$INSTANCE" != "DEV" ]] && grep -RIn "_DEV" init-generado/ ; then
  echo "ERROR: quedan nombres de BD de la instancia DEV sin sustituir." >&2
  exit 1
fi

echo "OK: scripts generados en ./init-generado/ para la instancia ${INSTANCE}."
echo "Recuerda: solo se aplican en el PRIMER arranque con el volumen vacío."
