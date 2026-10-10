#!/bin/bash
# verify.sh — pruebas de aceptación de Vigía v2 (Docker y Compose).
#
# Ejecútalo desde la raíz de tu repo de Vigía, con tu .env creado:
#   bash ~/my-devops-journey/recursos/vigia/v2/verify.sh
#
# Construye la imagen, levanta tu Compose, lo comprueba desde fuera y lo deja
# corriendo. Con --limpiar, al terminar hace `docker compose down` (sin borrar datos).
# Necesita: docker con el plugin compose, curl y python3. Tarda unos 2-3 minutos.
set -u
LIMPIAR=0
[[ ${1:-} == --limpiar ]] && LIMPIAR=1
FALLOS=0
API=http://127.0.0.1:8000

ok()   { echo "✅ $1"; }
mal()  { echo "❌ $1"; FALLOS=$((FALLOS + 1)); }
check() {   # check "descripción" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else mal "$desc"; fi
}
esperar() {   # esperar <segundos> comando... → 0 en cuanto el comando funciona
  local limite=$(( SECONDS + $1 )); shift
  until "$@" >/dev/null 2>&1; do
    (( SECONDS >= limite )) && return 1
    sleep 2
  done
}
json() { python3 -c "import json, sys; d = json.load(sys.stdin); print($1)"; }
filas() { docker compose exec -T db psql -U vigia -d vigia -tAc "SELECT COUNT(*) FROM checks" 2>/dev/null | tr -d '[:space:]'; }

echo "== Archivos"
check "existe un Dockerfile" test -f Dockerfile
check "existe compose.yaml (o docker-compose.yaml)" bash -c 'ls compose.yaml compose.yml docker-compose.yaml docker-compose.yml 2>/dev/null | grep -q .'
check "existe .dockerignore y excluye .venv y .env" bash -c 'grep -q "\.venv" .dockerignore && grep -qx "\.env" .dockerignore'
check "existe .env.example" test -f .env.example
check ".env está en .gitignore y Git no lo sigue" bash -c 'grep -qx "\.env" .gitignore && ! git ls-files --error-unmatch .env'
check "el Dockerfile es multi-stage (al menos 2 FROM)" bash -c '(( $(grep -ciE "^FROM " Dockerfile) >= 2 ))'
check "el Dockerfile cambia a un usuario que no es root" bash -c 'grep -iE "^USER " Dockerfile | tail -1 | grep -viqE "USER (root|0)\b"'
check "la contraseña no está escrita en el compose (usa \${...})" bash -c '! grep -E "POSTGRES_PASSWORD:" compose*.y*ml docker-compose*.y*ml 2>/dev/null | grep -v "\${" | grep -q .'

echo "== Construir y arrancar"
if ! docker compose config -q; then mal "docker compose config: el compose no es válido"; echo "Fallos: $FALLOS"; exit 1; fi
ok "docker compose config: el compose es válido"
if ! docker compose build -q; then mal "docker compose build"; echo "Fallos: $FALLOS"; exit 1; fi
ok "docker compose build"
docker compose up -d --remove-orphans >/dev/null 2>&1 || mal "docker compose up -d"
if esperar 120 curl -fsS "$API/health"; then ok "la API responde en $API/health"; else mal "la API no responde en $API/health tras 2 minutos"; fi
check "/health devuelve {\"status\": \"ok\"}" bash -c "curl -fsS $API/health | grep -q '\"ok\"'"

echo "== Seguridad y red"
check "la API corre con un usuario que no es root" bash -c '[[ $(docker compose exec -T api id -u) != 0 ]]'
check "el checker corre con un usuario que no es root" bash -c '[[ $(docker compose exec -T checker id -u) != 0 ]]'
check "el puerto de la API solo se publica en 127.0.0.1" bash -c 'docker compose port api 8000 | grep -q "^127.0.0.1:"'
check "la base de datos no publica puertos" bash -c 'p=$(docker compose port db 5432 2>/dev/null); [[ -z $p || $p == ":0" ]]'
check "la imagen de la API pesa menos de 400 MB" bash -c '(( $(docker image inspect "$(docker compose images -q api | head -1)" --format "{{.Size}}") < 400000000 ))'
check "el archivo .env no está dentro de la imagen" bash -c '! docker compose exec -T api sh -c "test -e /app/.env"'

echo "== Funcionamiento"
if esperar 150 bash -c "curl -fsS $API/status | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)[\"sites\"] else 1)'"; then
  ok "el checker guardó resultados y /status los muestra"
else
  mal "/status sigue sin sitios tras 150 s: ¿el checker escribe en la misma base de datos?"
fi
check "/status trae up y down" bash -c "curl -fsS $API/status | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if {\"up\",\"down\"} <= set(d) else 1)'"
n=$(filas)
if [[ -n $n ]] && (( n > 0 )); then ok "los datos están en PostgreSQL ($n filas)"; else mal "no encuentro filas en la tabla checks de PostgreSQL"; fi
check "todos los servicios se reinician solos (restart)" bash -c '
  for c in $(docker compose ps -q); do
    p=$(docker inspect "$c" --format "{{.HostConfig.RestartPolicy.Name}}")
    [[ $p == always || $p == unless-stopped || $p == on-failure ]] || exit 1
  done'

echo "== Persistencia"
antes=$(filas)
docker compose down >/dev/null 2>&1
docker compose up -d >/dev/null 2>&1
esperar 120 curl -fsS "$API/health"
esperar 30 bash -c '[[ -n $(docker compose exec -T db psql -U vigia -d vigia -tAc "SELECT 1" 2>/dev/null) ]]'
despues=$(filas)
if [[ -n $antes && -n $despues ]] && (( despues >= antes )); then
  ok "los datos sobreviven a docker compose down y up ($antes → $despues filas)"
else
  mal "los datos no sobrevivieron a docker compose down y up (${antes:-?} → ${despues:-?} filas): ¿tienes un volumen con nombre?"
fi

echo "== Parada ordenada"
inicio=$SECONDS
docker compose stop checker >/dev/null 2>&1
if (( SECONDS - inicio < 8 )); then ok "el checker se detiene en menos de 8 s (atiende SIGTERM)"; else mal "el checker tardó $((SECONDS - inicio)) s en pararse: ¿ENTRYPOINT en forma exec y SIGTERM atendido?"; fi
docker compose start checker >/dev/null 2>&1

if (( LIMPIAR )); then docker compose down >/dev/null 2>&1; fi
echo "Fallos: $FALLOS"
exit $(( FALLOS > 0 ))
