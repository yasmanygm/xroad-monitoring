#!/usr/bin/env bash
# ============================================================
# desplegar.sh — Prepara y levanta X-Road Metrics con Docker.
#
#   ./desplegar.sh piloto     Un solo host, todo en uno (pruebas)
#   ./desplegar.sh privado    Host de la zona privada
#   ./desplegar.sh publico    Host de la zona pública / DMZ
#
# Qué hace:
#  1. Clona el repo oficial X-Road-Metrics si no existe (XRM_DIR).
#  2. Construye las imágenes locales con Docker/prepare-containers.sh.
#  3. Copia el compose elegido, generar-init.sh y el .env a
#     XRM_DIR/Docker/ (los composes reutilizan los init oficiales).
#  4. Genera los init de BD adaptados (generar-init.sh).
#  5. Crea la red externa xroad-network si no existe (piloto/privado).
#  6. Valida el compose y levanta las bases de datos y los
#     servicios continuos del modo elegido.
# Los módulos bajo demanda (collector, reports, anonymizer) NO se
# levantan solos: en el README de esta carpeta están los comandos.
# ============================================================
set -euo pipefail

MODO="${1:-}"
case "$MODO" in
  piloto|privado|publico) ;;
  *) echo "Uso: $0 [piloto|privado|publico]" >&2; exit 1 ;;
esac

ORIGEN="$(cd "$(dirname "$0")" && pwd)"
XRM_DIR="${XRM_DIR:-$ORIGEN/X-Road-Metrics}"
DOCKER_DIR="$XRM_DIR/Docker"
COMPOSE="compose.${MODO}.yaml"

command -v docker >/dev/null || { echo "ERROR: instala Docker Engine + Compose v2 primero." >&2; exit 1; }
docker compose version >/dev/null

if [[ ! -d "$XRM_DIR" ]]; then
  echo ">> Clonando X-Road-Metrics oficial en $XRM_DIR"
  git clone https://github.com/nordic-institute/X-Road-Metrics.git "$XRM_DIR"
fi

if [[ ! -f "$ORIGEN/.env" ]]; then
  cp "$ORIGEN/.env.example" "$ORIGEN/.env"
  echo ">> He creado $ORIGEN/.env desde la plantilla."
  echo "   EDÍTALO (instancia, hosts X-Road, contraseñas) y vuelve a ejecutar."
  exit 2
fi

echo ">> Construyendo imágenes (prepare-containers.sh) — puede tardar"
bash "$DOCKER_DIR/prepare-containers.sh"

cp "$ORIGEN/$COMPOSE" "$ORIGEN/generar-init.sh" "$ORIGEN/.env" "$DOCKER_DIR/"
cd "$DOCKER_DIR"
chmod +x generar-init.sh
./generar-init.sh

if [[ "$MODO" != "publico" ]]; then
  docker network inspect xroad-network >/dev/null 2>&1 || docker network create xroad-network
fi

echo ">> Validando $COMPOSE"
docker compose -f "$COMPOSE" config -q

case "$MODO" in
  piloto)  docker compose -f "$COMPOSE" up -d mongodb postgresql corrector_module opendata_module networking_module ;;
  privado) docker compose -f "$COMPOSE" up -d mongodb corrector_module ;;
  publico) docker compose -f "$COMPOSE" up -d postgresql opendata_module networking_module ;;
esac

echo
echo ">> Servicios continuos levantados. Siguientes pasos (desde $DOCKER_DIR):"
echo "   docker compose -f $COMPOSE run --rm collector_module update"
echo "   docker compose -f $COMPOSE run --rm collector_module collect"
[[ "$MODO" != "publico" ]] && echo "   docker compose -f $COMPOSE run --rm anonymizer_module   # tras recolectar (y con PostgreSQL accesible)"
echo "   docker compose -f $COMPOSE ps   ·   logs: docker compose -f $COMPOSE logs -f"
