#!/bin/bash
# Averías aleatorias para la clase 24. Se ejecuta en servidor-02 con sudo.
#   sudo ./averia.sh           → provoca UNA avería al azar (sin decir cuál)
#   sudo ./averia.sh --reset   → deja el backend como al terminar la práctica guiada
#   sudo ./averia.sh --solucion → muestra qué avería se provocó (solo después de intentarlo)
# No leas el resto del archivo antes de diagnosticar: estropearía el ejercicio.
set -euo pipefail

UNIT=/etc/systemd/system/backend.service
ESTADO=/root/.averia-clase24

[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo con sudo"; exit 1; }
[ -f "$UNIT" ] || { echo "No existe $UNIT: termina antes la práctica guiada de la clase 24"; exit 1; }

reset() {
  sed -i -E 's/--bind [0-9.]+/--bind 0.0.0.0/; s/http\.server [0-9]+/http.server 8080/' "$UNIT"
  systemctl daemon-reload
  while ufw status numbered | grep -qE "8080/tcp( \(v6\))? +DENY"; do
    n=$(ufw status numbered | grep -E "8080/tcp( \(v6\))? +DENY" | head -1 | sed -E 's/^\[ *([0-9]+)\].*/\1/')
    ufw --force delete "$n" >/dev/null
  done
  systemctl reset-failed backend 2>/dev/null || true
  systemctl enable backend >/dev/null 2>&1
  systemctl restart backend
  rm -f "$ESTADO"
  sleep 2   # dar tiempo al backend a arrancar antes de que se pruebe
  echo "Backend restaurado: 0.0.0.0:8080, activo, sin reglas DENY en el 8080."
}

case "${1:-}" in
  --reset) reset; exit 0 ;;
  --solucion) cat "$ESTADO" 2>/dev/null || echo "No hay ninguna avería registrada."; exit 0 ;;
esac

reset >/dev/null
n=$(( RANDOM % 4 + 1 ))
case $n in
  1) systemctl stop backend
     echo "1: el servicio backend está parado. Síntoma: refused. Arreglo: systemctl start backend (y comprobar enabled)." > "$ESTADO" ;;
  2) sed -i -E 's/--bind [0-9.]+/--bind 127.0.0.1/' "$UNIT"; systemctl daemon-reload; systemctl restart backend
     echo "2: el backend escucha solo en 127.0.0.1. Síntoma: refused desde fuera, OK con curl local. Se ve en ss -tlnp." > "$ESTADO" ;;
  3) ufw insert 1 deny 8080/tcp >/dev/null
     echo "3: regla de firewall DENY en el 8080. Síntoma: timeout. Se ve en ufw status y en [UFW BLOCK] del log del kernel." > "$ESTADO" ;;
  4) sed -i -E 's/http\.server [0-9]+/http.server 8081/' "$UNIT"; systemctl daemon-reload; systemctl restart backend
     echo "4: el backend escucha en el 8081 en vez del 8080. Síntoma: refused en el 8080. Se ve en ss -tlnp y en la unit." > "$ESTADO" ;;
esac
chmod 600 "$ESTADO"
sleep 1
echo "Avería provocada. Ahora el servicio falla visto desde servidor-01. ¡A diagnosticar!"
