#!/usr/bin/env bash
# ============================================================
# generar-trafico.sh — Genera llamadas de servicio de PRUEBA
# a través de un Security Server del laboratorio, para que
# X-Road Metrics tenga un flujo que recolectar y mostrar.
#
# Hace llamadas SOAP (protocolo X-Road 4.0) al SS consumidor.
# Cada N llamadas envía una a un servicio inexistente, para
# generar también registros con fallo (útiles para ver en
# Opendata/Networking cómo se refleja un error).
#
# AJUSTA las variables a lo que tenga registrado tu pila de
# laboratorio (compruébalo en la UI del SS: servicios y clientes
# dados de alta). Los valores por defecto son los del entorno
# de desarrollo oficial (instancia DEV).
#
# Uso:  ./generar-trafico.sh [nº de llamadas]     (defecto: 50)
# ============================================================
set -euo pipefail

SS_URL="${SS_URL:-http://localhost:8080}"        # proxy de mensajes del SS consumidor
INSTANCE="${XROAD_INSTANCE:-DEV}"
CLIENT_CLASS="${CLIENT_CLASS:-COM}"
CLIENT_CODE="${CLIENT_CODE:-1234}"
CLIENT_SUBSYSTEM="${CLIENT_SUBSYSTEM:-testClient}"
SERVICE_CLASS="${SERVICE_CLASS:-COM}"
SERVICE_CODE="${SERVICE_CODE:-1234}"
SERVICE_SUBSYSTEM="${SERVICE_SUBSYSTEM:-testService}"
SERVICE_NAME="${SERVICE_NAME:-getRandom}"        # servicio de prueba a invocar
USER_ID="${USER_ID:-LAB-USER-1}"
TOTAL="${1:-50}"
CADA_FALLO=10

call() {
  local service="$1" id="$2"
  cat > /tmp/xroad-req.xml <<XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xrd="http://x-road.eu/xsd/xroad.xsd"
    xmlns:id="http://x-road.eu/xsd/identifiers">
  <SOAP-ENV:Header>
    <xrd:client id:objectType="SUBSYSTEM">
      <id:xRoadInstance>${INSTANCE}</id:xRoadInstance>
      <id:memberClass>${CLIENT_CLASS}</id:memberClass>
      <id:memberCode>${CLIENT_CODE}</id:memberCode>
      <id:subsystemCode>${CLIENT_SUBSYSTEM}</id:subsystemCode>
    </xrd:client>
    <xrd:service id:objectType="SERVICE">
      <id:xRoadInstance>${INSTANCE}</id:xRoadInstance>
      <id:memberClass>${SERVICE_CLASS}</id:memberClass>
      <id:memberCode>${SERVICE_CODE}</id:memberCode>
      <id:subsystemCode>${SERVICE_SUBSYSTEM}</id:subsystemCode>
      <id:serviceCode>${service}</id:serviceCode>
    </xrd:service>
    <xrd:userId>${USER_ID}</xrd:userId>
    <xrd:id>${id}</xrd:id>
    <xrd:protocolVersion>4.0</xrd:protocolVersion>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <ns1:${service} xmlns:ns1="http://test.x-road.global/producer"/>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
XML
  local code
  code=$(curl -s -o /tmp/xroad-resp.xml -w "%{http_code}" \
    -H "Content-Type: text/xml;charset=UTF-8" \
    --data-binary @/tmp/xroad-req.xml "$SS_URL" || echo "000")
  if grep -q "SOAP-ENV:Fault\|<faultcode" /tmp/xroad-resp.xml 2>/dev/null; then
    echo "  -> respuesta con FALLO SOAP (esperado en las llamadas de error)"
  else
    echo "  -> HTTP $code"
  fi
}

echo "Generando $TOTAL llamadas contra $SS_URL (servicio ${SERVICE_NAME}; 1 de cada $CADA_FALLO con error)"
for i in $(seq 1 "$TOTAL"); do
  if (( i % CADA_FALLO == 0 )); then
    printf "[%s] llamada %d (error inducido)\n" "$(date +%T)" "$i"
    call "servicioInexistente" "lab-$i"
  else
    printf "[%s] llamada %d\n" "$(date +%T)" "$i"
    call "$SERVICE_NAME" "lab-$i"
  fi
  sleep 1
done
echo "Listo. Ahora recolecta: docker compose -f compose.piloto.yaml run --rm collector_module update && ... collect"
