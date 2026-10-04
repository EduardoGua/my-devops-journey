#!/bin/bash
# Laboratorio de incidentes del proyecto P1 (clase 28).
# Se ejecuta DENTRO de la VM "incidentes", con sudo.
#
#   sudo ./incidentes.sh preparar     → instala la tienda (nginx + app) en estado sano
#   sudo ./incidentes.sh comprobar    → dice si la tienda funciona (úsalo tras arreglar)
#   sudo ./incidentes.sh romper N     → provoca el incidente N (1-7) sobre una tienda sana
#   sudo ./incidentes.sh lista        → títulos de los incidentes, como los reportaría un usuario
#
# No leas las funciones de abajo antes de resolver: el ejercicio es diagnosticar a ciegas.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo con sudo"; exit 1; }

APP_DIR=/opt/shopapp
DATA_DIR=/var/lib/shop
WEB_DIR=/var/www/shop
UNIT=/etc/systemd/system/shopapp.service
SITE=/etc/nginx/sites-available/shop

preparar() {
  export DEBIAN_FRONTEND=noninteractive
  if ! command -v nginx >/dev/null || ! command -v ufw >/dev/null; then
    apt-get update -qq
    apt-get install -y -qq nginx curl ufw >/dev/null
  fi

  id shopapp >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin shopapp
  mkdir -p "$APP_DIR" "$DATA_DIR" "$WEB_DIR"

  cat > "$APP_DIR/app.py" <<'PY'
#!/usr/bin/env python3
"""API mínima de la tienda. Necesita DB_HOST y escribe cada petición en /var/lib/shop/requests.log."""
import json, os, sys, datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

DB_HOST = os.environ["DB_HOST"]          # falla al arrancar si no está definida
PORT = int(os.environ.get("PORT", "8080"))
LOG = "/var/lib/shop/requests.log"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            with open(LOG, "a") as f:
                f.write(f"{datetime.datetime.now().isoformat()} {self.path}\n")
            body = json.dumps({"service": "shop-api", "db": DB_HOST, "status": "ok"}).encode()
            self.send_response(200)
        except OSError as e:
            print(f"ERROR writing {LOG}: {e}", file=sys.stderr, flush=True)
            body = json.dumps({"error": "internal"}).encode()
            self.send_response(500)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

print(f"shop-api listening on 127.0.0.1:{PORT} (db={DB_HOST})", flush=True)
HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
PY
  chmod 755 "$APP_DIR/app.py"
  chown -R shopapp:shopapp "$DATA_DIR"

  cat > "$UNIT" <<'UNIT'
[Unit]
Description=Shop API
After=network-online.target

[Service]
User=shopapp
Environment=DB_HOST=db.shop.internal
Environment=PORT=8080
ExecStart=/usr/bin/python3 /opt/shopapp/app.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
  rm -rf /etc/systemd/system/shopapp.service.d

  cat > "$WEB_DIR/index.html" <<'HTML'
<!doctype html><title>Shop</title><h1>Shop</h1><p>Welcome to the shop.</p>
HTML
  chmod 755 "$WEB_DIR"; chmod 644 "$WEB_DIR/index.html"; chown -R root:root "$WEB_DIR"

  cat > "$SITE" <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/shop;

    location /api/ {
        proxy_pass http://api.shop.internal:8080/;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
NGINX
  rm -f /etc/nginx/sites-enabled/default
  ln -sf "$SITE" /etc/nginx/sites-enabled/shop
  sed -i '/shop\.internal/d' /etc/hosts
  echo "127.0.0.1 api.shop.internal" >> /etc/hosts

  # limpiar restos de incidentes anteriores
  rm -rf /var/lib/shop/.cache /var/log/shop-debug.log
  pkill -f "tail -f /var/log/shop-debug.log" 2>/dev/null || true
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow OpenSSH >/dev/null
  ufw allow 80/tcp >/dev/null
  ufw --force enable >/dev/null

  systemctl daemon-reload
  systemctl enable --now shopapp >/dev/null 2>&1
  systemctl restart shopapp
  nginx -t -q
  systemctl enable --now nginx >/dev/null 2>&1
  systemctl reload nginx
  sleep 1
  comprobar
}

comprobar() {
  local ok=1 web api
  web=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://127.0.0.1/ || echo "000")
  api=$(curl -s -o /dev/null -w "%{http_code}" -m 8 http://127.0.0.1/api/ || echo "000")
  [ "$web" = "200" ] || ok=0
  [ "$api" = "200" ] || ok=0
  ufw status | grep -qE "^80/tcp +ALLOW" || ok=0
  [ "$(df --output=pcent / | tail -1 | tr -dc 0-9)" -lt 90 ] || ok=0
  echo "web=$web api=$api"
  if [ $ok -eq 1 ]; then echo "✅ La tienda funciona."; else echo "❌ La tienda NO funciona del todo."; return 1; fi
}

lista() {
  cat <<'TXT'
1. "La página principal de la tienda da un error de acceso."
2. "La web carga, pero la API de la tienda devuelve error."
3. "Tras el último cambio de configuración, la API no funciona."
4. "La API devuelve error 500 y nadie ha tocado nada."
5. "La tienda entera está caída después de un reinicio de servicios."
6. "Desde fuera la tienda no carga: se queda pensando."
7. "El disco dice estar lleno, pero no encontramos qué lo ocupa."
TXT
}

romper() {
  preparar >/dev/null
  case "$1" in
    1) chown root:root "$WEB_DIR/index.html"; chmod 600 "$WEB_DIR/index.html" ;;
    2) sed -i 's/^Environment=PORT=8080/Environment=PORT=8081/' "$UNIT"
       systemctl daemon-reload; systemctl restart shopapp ;;
    3) sed -i '/^Environment=DB_HOST=/d' "$UNIT"
       systemctl daemon-reload; systemctl restart shopapp || true ;;
    4) mkdir -p /var/lib/shop/.cache
       avail=$(df --output=avail -B1 / | tail -1)
       fallocate -l $(( avail - 20000000 )) /var/lib/shop/.cache/blob.tmp
       dd if=/dev/zero of=/var/lib/shop/.cache/fill bs=1M count=50 2>/dev/null || true ;;
    5) sed -i '/api\.shop\.internal/d' /etc/hosts
       systemctl restart nginx 2>/dev/null || true ;;
    6) ufw delete allow 80/tcp >/dev/null; ufw deny 80/tcp >/dev/null ;;
    7) avail=$(df --output=avail -B1 / | tail -1)
       fallocate -l $(( avail - 200000000 )) /var/log/shop-debug.log
       nohup tail -f /var/log/shop-debug.log >/dev/null 2>&1 &
       sleep 1; rm -f /var/log/shop-debug.log ;;
    *) echo "Incidente desconocido: $1 (usa 1-7)"; exit 1 ;;
  esac
  echo "Incidente $1 en marcha: $(lista | sed -n "${1}p" | cut -d' ' -f2-)"
}

case "${1:-}" in
  preparar)  preparar ;;
  comprobar) comprobar ;;
  lista)     lista ;;
  romper)    romper "${2:?Indica el número: romper 1..7}" ;;
  *) sed -n '2,10p' "$0" ;;
esac
