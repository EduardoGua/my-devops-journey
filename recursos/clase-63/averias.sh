#!/bin/bash
# Averías de contenedores para la clase 63.
#   bash averias.sh            → arranca los cinco contenedores averiados (averia-1 … averia-5)
#   bash averias.sh limpiar    → los borra
# Regla de honor: no leas el resto del archivo antes de diagnosticarlas.
set -u

if [[ ${1:-} == limpiar ]]; then
  docker rm -f averia-1 averia-2 averia-3 averia-4 averia-5 >/dev/null 2>&1
  echo "Averías borradas."
  exit 0
fi

docker rm -f averia-1 averia-2 averia-3 averia-4 averia-5 >/dev/null 2>&1
echo "Preparando las imágenes (la primera vez tarda un poco)…"
docker pull -q python:3.14-slim >/dev/null && docker pull -q nginx:1.29-alpine >/dev/null || {
  echo "No pude descargar las imágenes: ¿hay internet?"; exit 1; }

docker run -d --name averia-1 python:3.14-slim pyhton -m http.server 8000 >/dev/null 2>&1
docker run -d --name averia-2 --restart unless-stopped python:3.14-slim \
  python -c 'import os, time; print("conectando a", os.environ["DATABASE_URL"]); time.sleep(3600)' >/dev/null
docker run -d --name averia-3 --memory 64m python:3.14-slim \
  python -c 'datos = []
while True:
    datos.append(bytearray(8 * 1024 * 1024))' >/dev/null
docker run -d --name averia-4 --health-cmd 'wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1' \
  --health-interval 3s --health-retries 2 nginx:1.29-alpine >/dev/null
docker run -d --name averia-5 -p 127.0.0.1:8085:80 python:3.14-slim python -m http.server 8000 >/dev/null

sleep 8
echo "Listo. Los avisos, como los reportaría un usuario:"
echo "  averia-1: «el contenedor ni siquiera arranca»"
echo "  averia-2: «se reinicia sin parar»"
echo "  averia-3: «muere al poco de arrancar, sin ningún error en su log»"
echo "  averia-4: «funciona, pero Docker dice que está mal»"
echo "  averia-5: «curl http://127.0.0.1:8085 no responde»"
