#!/bin/bash
# verify.sh — pruebas de aceptación de Vigía v7 (métricas, alertas, dashboards y SLO).
#
# Desde la raíz de tu repo de Vigía, con tu .env creado:
#   bash ~/my-devops-journey/recursos/vigia/v7/verify.sh            # comprueba (unos 3 minutos)
#   bash ~/my-devops-journey/recursos/vigia/v7/verify.sh --alerta   # y además prueba la alerta de punta a punta (unos 8 minutos más)
#
# Levanta tu Compose (Vigía y la observabilidad) y lo comprueba desde fuera: /metrics, Prometheus,
# las reglas y sus pruebas con promtool, Alertmanager, Grafana y el SLO del README.
# Con --alerta, inserta en PostgreSQL un chequeo caído de https://verify.invalid, espera a que
# VigiaSitioCaido llegue a Alertmanager y este avise a tu receptor, y lo borra al terminar.
# Necesita: docker con el plugin compose, curl, git y python3.
set -u
ALERTA=0
[[ ${1:-} == --alerta ]] && ALERTA=1
FALLOS=0
API=http://127.0.0.1:8000
PROM=http://127.0.0.1:9090
AM=http://127.0.0.1:9093
GRAFANA=http://127.0.0.1:3000
PROMTOOL=(docker run --rm --entrypoint promtool)
IMAGEN_PROM=prom/prometheus:v3.15.0

ok()  { echo "✅ $1"; }
mal() { echo "❌ $1"; FALLOS=$((FALLOS + 1)); }
fin() { echo "Fallos: $FALLOS"; exit $(( FALLOS > 0 )); }
esperar() {   # esperar <segundos> comando... → 0 en cuanto el comando funciona
  local limite=$(( SECONDS + $1 )); shift
  until "$@" >/dev/null 2>&1; do
    (( SECONDS >= limite )) && return 1
    sleep 3
  done
}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
consulta() { curl -fsS --data-urlencode "query=$1" "$PROM/api/v1/query"; }

[[ -d .git && -f config.yaml ]] || { echo "Ejecútalo en la raíz de tu repo de Vigía (cd ~/vigia)."; exit 2; }
for programa in docker curl git python3; do
  command -v "$programa" >/dev/null || { echo "Falta $programa."; exit 2; }
done
[[ -f .env ]] || { echo "Falta .env: cópialo de .env.example y pon tus contraseñas."; exit 2; }

echo "== El repositorio"
git ls-files | grep -qE '(^|/)\.env$' && mal ".env está en Git" || ok ".env no está en Git"
grep -qs 'GRAFANA_ADMIN_PASSWORD' .env.example && ok ".env.example incluye GRAFANA_ADMIN_PASSWORD" || mal ".env.example no incluye GRAFANA_ADMIN_PASSWORD"
mapfile -t YAMLS < <(git ls-files '*.yml' '*.yaml')
PROMCONF=$(grep -ls 'scrape_configs:' "${YAMLS[@]}" 2>/dev/null | head -1)
mapfile -t PRUEBAS < <(grep -ls '^rule_files:' "${YAMLS[@]}" 2>/dev/null | xargs -r grep -l '^tests:')
if [[ -n $PROMCONF ]]; then ok "configuración de Prometheus en Git: $PROMCONF"; else mal "no encuentro en Git la configuración de Prometheus (un YAML con scrape_configs:)"; fi
if [[ -n $PROMCONF ]]; then
  DIR=$(cd "$(dirname "$PROMCONF")" && pwd)
  if "${PROMTOOL[@]}" -v "$DIR:/r:ro" -w /r "$IMAGEN_PROM" check config "$(basename "$PROMCONF")" > "$TMP/check.txt" 2>&1; then
    ok "promtool check config: la configuración y sus reglas son válidas"
  else
    mal "promtool check config falla:"; grep -E 'FAILED|error' "$TMP/check.txt" | head -3 | sed 's/^/     /'
  fi
fi
if (( ${#PRUEBAS[@]} == 0 )); then
  mal "no hay pruebas unitarias de las reglas (un YAML con rule_files: y tests:, para promtool test rules)"
else
  for prueba in "${PRUEBAS[@]}"; do
    DIR=$(cd "$(dirname "$prueba")" && pwd)
    if "${PROMTOOL[@]}" -v "$DIR:/r:ro" -w /r "$IMAGEN_PROM" test rules "$(basename "$prueba")" > "$TMP/test.txt" 2>&1; then
      ok "promtool test rules $prueba"
    else
      mal "promtool test rules $prueba falla:"; grep -E 'FAILED|alertname|expr' "$TMP/test.txt" | head -4 | sed 's/^/     /'
    fi
  done
fi
# Una prueba propia sobre tus reglas: VigiaSitioCaido salta tras 5 minutos de caída, no antes, y no con un sitio que parpadea
if [[ -n $PROMCONF ]]; then
  DIR=$(cd "$(dirname "$PROMCONF")" && pwd)
  mapfile -t REGLAS < <(cd "$DIR" && python3 - "$(basename "$PROMCONF")" <<'PY'
import glob, re, sys
texto = open(sys.argv[1]).read()
bloque = re.search(r"^rule_files:\s*\n((?:\s+-\s*.+\n?)+)", texto, re.M)
for linea in (bloque.group(1).splitlines() if bloque else []):
    patron = linea.strip().lstrip("-").strip().strip("'\"")
    rutas = sorted(glob.glob(patron)) or sorted(glob.glob(patron.rsplit("/", 1)[-1]))   # /etc/prometheus/x.yml → x.yml
    for ruta in rutas:
        print(ruta)
PY
)
  if (( ${#REGLAS[@]} )); then
    mkdir -p "$TMP/reglas"
    for r in "${REGLAS[@]}"; do cp "$DIR/$r" "$TMP/reglas/$(basename "$r")"; done
    {
      echo "rule_files:"
      for r in "${REGLAS[@]}"; do echo "  - $(basename "$r")"; done
      cat <<'Y'
evaluation_interval: 15s
tests:
  - interval: 15s
    input_series:
      - series: 'vigia_site_up{job="vigia", instance="api:8000", url="https://caido.test"}'
        values: '0x40'
      - series: 'vigia_site_up{job="vigia", instance="api:8000", url="https://bien.test"}'
        values: '1x40'
      - series: 'vigia_site_up{job="vigia", instance="api:8000", url="https://parpadea.test"}'
        values: '0x10 1 0x10 1 0x10 1'
    promql_expr_test:
      - expr: count(ALERTS{alertname="VigiaSitioCaido", alertstate="firing"}) or vector(0)
        eval_time: 4m
        exp_samples:
          - value: 0
      - expr: count by (url) (ALERTS{alertname="VigiaSitioCaido", alertstate="firing"})
        eval_time: 7m
        exp_samples:
          - labels: '{url="https://caido.test"}'
            value: 1
Y
    } > "$TMP/reglas/verify_test.yml"
    if "${PROMTOOL[@]}" -v "$TMP/reglas:/r:ro" -w /r "$IMAGEN_PROM" test rules verify_test.yml > "$TMP/propia.txt" 2>&1; then
      ok "VigiaSitioCaido salta tras más de 5 minutos de caída, no antes, y no con un sitio que parpadea"
    else
      mal "VigiaSitioCaido no salta como debe: un sitio caído 7 minutos (y solo ese) debe estar en firing, y ninguno a los 4 minutos"
      grep -E 'exp:|got:' "$TMP/propia.txt" | head -4 | sed 's/^/     /'
    fi
  else
    mal "no encuentro los archivos de reglas de rule_files en $PROMCONF"
  fi
fi
if grep -qsiE '^#+ .*SLO|Service Level Objective' README.md && grep -qsiE 'error budget|presupuesto de errores' README.md; then
  ok "el README explica el SLO y su presupuesto de errores"
else
  mal "el README no tiene una sección del SLO con su presupuesto de errores (error budget)"
fi

echo "== Arrancar"
if ! docker compose config -q; then mal "docker compose config: el compose no es válido"; fin; fi
ok "docker compose config: el compose es válido"
docker compose up -d --build --remove-orphans > "$TMP/up.txt" 2>&1 || { mal "docker compose up -d falla:"; tail -5 "$TMP/up.txt" | sed 's/^/     /'; fin; }
esperar 150 curl -fsS "$API/health" && ok "la API responde en $API/health" || mal "la API no responde en $API/health"
esperar 120 curl -fsS "$PROM/-/ready" && ok "Prometheus responde en $PROM" || mal "Prometheus no responde en $PROM"
esperar 120 curl -fsS "$AM/-/ready" && ok "Alertmanager responde en $AM" || mal "Alertmanager no responde en $AM"
esperar 180 curl -fsS "$GRAFANA/api/health" && ok "Grafana responde en $GRAFANA" || mal "Grafana no responde en $GRAFANA"
for servicio_puerto in "prometheus 9090" "alertmanager 9093" "grafana 3000"; do
  read -r servicio puerto <<< "$servicio_puerto"
  publicado=$(docker compose port "$servicio" "$puerto" 2>/dev/null)
  if [[ -z $publicado ]]; then mal "$servicio no publica su puerto $puerto"
  elif [[ $publicado == 127.0.0.1:* ]]; then ok "$servicio solo se publica en 127.0.0.1"
  else mal "$servicio se publica en $publicado: solo en 127.0.0.1"; fi
done

echo "== /metrics"
URLS=$(grep -cE '^[[:space:]]*-[[:space:]]*https?://' config.yaml)
con_sitios() { (( $(curl -fsS "$API/metrics" | grep -c '^vigia_site_up{') >= URLS )); }
esperar 150 con_sitios && ok "vigia_site_up tiene una serie por cada URL de config.yaml ($URLS)" || mal "vigia_site_up no tiene una serie por cada URL de config.yaml ($URLS): ¿el checker escribe y /metrics lee la base de datos?"
for i in 1 2 3; do curl -s -o /dev/null "$API/no-existe-$i-$RANDOM"; done
curl -fsS "$API/status" >/dev/null 2>&1
curl -fsS "$API/metrics" > "$TMP/metrics.txt" 2>/dev/null
for par in "vigia_site_up gauge" "vigia_site_response_seconds gauge" "vigia_site_last_check_timestamp_seconds gauge" \
           "vigia_checks_total counter" "vigia_http_requests_total counter" "vigia_http_request_duration_seconds histogram"; do
  read -r nombre tipo <<< "$par"
  base=${nombre%_total}
  if grep -qE "^# TYPE ($nombre|$base) $tipo\$" "$TMP/metrics.txt"; then ok "/metrics publica $nombre ($tipo)"; else mal "/metrics no publica $nombre como $tipo"; fi
done
grep -qE '^vigia_checks_total\{.*result="(up|down)"' "$TMP/metrics.txt" && ok "vigia_checks_total lleva la etiqueta result (up/down)" || mal "vigia_checks_total no lleva la etiqueta result=\"up\"/\"down\""
if grep -E '^vigia_http_requests_total\{' "$TMP/metrics.txt" | grep -q 'no-existe-'; then
  mal "la etiqueta path de vigia_http_requests_total lleva la URL tal cual (cardinalidad): usa la plantilla de la ruta"
else
  ok "la etiqueta path no lleva URLs tal cual"
fi

echo "== Prometheus"
objetivo_arriba() { consulta 'up{job="vigia"}' | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; sys.exit(0 if r and r[0]["value"][1] == "1" else 1)'; }
esperar 60 objetivo_arriba && ok "Prometheus lee la API: up{job=\"vigia\"} = 1" || mal "Prometheus no lee la API: up{job=\"vigia\"} no es 1 (¿un job llamado vigia con el objetivo api:8000?)"
series_sitios() { consulta 'count(vigia_site_up)' | python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; sys.exit(0 if r and int(r[0]['value'][1]) >= $URLS else 1)"; }
esperar 60 series_sitios && ok "Prometheus tiene vigia_site_up de todos los sitios" || mal "Prometheus no tiene vigia_site_up de todos los sitios"
# Recién arrancado, Prometheus aún no ha evaluado las reglas (health "unknown"): espera hasta un minuto
reglas_evaluadas() {
  curl -fsS "$PROM/api/v1/rules" > "$TMP/reglas.json" 2>/dev/null &&
  python3 -c 'import json,sys; r=[x for g in json.load(open(sys.argv[1]))["data"]["groups"] for x in g["rules"]]; sys.exit(0 if r and all(x.get("health") != "unknown" for x in r) else 1)' "$TMP/reglas.json"
}
esperar 60 reglas_evaluadas
while IFS=$'\t' read -r estado mensaje; do
  [[ $estado == OK ]] && ok "$mensaje" || mal "$mensaje"
done < <(python3 - "$TMP/reglas.json" <<'PY'
import json, sys
reglas = [r for g in json.load(open(sys.argv[1]))["data"]["groups"] for r in g["rules"]]
def res(bien, mensaje):
    print(("OK" if bien else "MAL") + "\t" + mensaje)
por_nombre = {r["name"]: r for r in reglas}
caido = por_nombre.get("VigiaSitioCaido")
res(caido is not None and caido["type"] == "alerting", "Prometheus cargó la alerta VigiaSitioCaido")
if caido:
    res(caido.get("health") == "ok", "VigiaSitioCaido se evalúa sin errores")
    res(caido.get("labels", {}).get("severity") in ("critical", "warning", "page", "ticket"), "VigiaSitioCaido tiene la etiqueta severity")
    res(bool(caido.get("annotations", {}).get("summary")), "VigiaSitioCaido tiene la anotación summary")
api = por_nombre.get("VigiaApiCaida")
res(api is not None and api["type"] == "alerting" and "up" in api.get("query", ""), "Prometheus cargó la alerta VigiaApiCaida, sobre up")
grabadas = [r["name"] for r in reglas if r["type"] == "recording" and r["name"].startswith("vigia:")]
res(bool(grabadas), "reglas de registro del SLI (vigia:…): " + (", ".join(grabadas) if grabadas else "ninguna"))
res(all(r.get("health") == "ok" for r in reglas), "todas las reglas se evalúan sin errores")
PY
)
am_conectado() { curl -fsS "$PROM/api/v1/alertmanagers" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["data"]["activeAlertmanagers"] else 1)'; }
esperar 30 am_conectado && ok "Prometheus manda las alertas a Alertmanager" || mal "Prometheus no tiene ningún Alertmanager activo (alerting: en prometheus.yml)"
curl -fsS "$AM/api/v2/status" | python3 -c 'import json,sys; c=json.load(sys.stdin)["config"]["original"]; sys.exit(0 if "_configs:" in c else 1)' 2>/dev/null \
  && ok "Alertmanager tiene un receptor que avisa a alguna parte" || mal "Alertmanager no tiene ningún receptor con destino (webhook_configs, email_configs, telegram_configs…)"

echo "== Grafana"
PASS=$(sed -n 's/^GRAFANA_ADMIN_PASSWORD=//p' .env | tr -d '"'\''')
# Sin probar admin/admin: cada intento fallido cuenta, y tras unos pocos Grafana bloquea al usuario unos minutos
if [[ ${#PASS} -ge 12 && $PASS != admin && $PASS != cambia-esto ]]; then
  ok "GRAFANA_ADMIN_PASSWORD de .env es una contraseña de verdad (${#PASS} caracteres)"
else
  mal "GRAFANA_ADMIN_PASSWORD de .env está vacía, es corta o es la de ejemplo: openssl rand -hex 12"
fi
docker compose config --format json 2>/dev/null | python3 -c '
import json, sys
env = (json.load(sys.stdin)["services"].get("grafana") or {}).get("environment") or {}
sys.exit(0 if env.get("GF_SECURITY_ADMIN_PASSWORD") == sys.argv[1] else 1)' "$PASS" \
  && ok "Grafana recibe su contraseña de .env (GF_SECURITY_ADMIN_PASSWORD)" \
  || mal "Grafana no recibe GRAFANA_ADMIN_PASSWORD de .env en GF_SECURITY_ADMIN_PASSWORD: sin ella, entra cualquiera con admin/admin"
if curl -fsS -u "admin:$PASS" "$GRAFANA/api/datasources" > "$TMP/ds.json" 2>/dev/null; then
  ok "entro en Grafana con la contraseña de .env"
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if any(x["type"]=="prometheus" and x.get("readOnly") for x in d) else 1)' "$TMP/ds.json" \
    && ok "la fuente de datos Prometheus está aprovisionada desde archivos" || mal "no hay una fuente de datos Prometheus aprovisionada (provisioning/datasources)"
  curl -fsS -u "admin:$PASS" "$GRAFANA/api/search?type=dash-db" > "$TMP/dash.json" 2>/dev/null
  UID_DASH=$(python3 -c 'import json,sys; d=[x for x in json.load(open(sys.argv[1])) if "vig" in x["title"].lower()]; print(d[0]["uid"] if d else "")' "$TMP/dash.json")
  if [[ -z $UID_DASH ]]; then
    mal "no hay ningún dashboard con «Vigía» en el título"
  else
    curl -fsS -u "admin:$PASS" "$GRAFANA/api/dashboards/uid/$UID_DASH" > "$TMP/uno.json"
    while IFS=$'\t' read -r estado mensaje; do
      [[ $estado == OK ]] && ok "$mensaje" || mal "$mensaje"
    done < <(python3 - "$TMP/uno.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
def res(bien, mensaje):
    print(("OK" if bien else "MAL") + "\t" + mensaje)
def paneles(lista):
    for p in lista:
        yield p
        yield from paneles(p.get("panels", []))
exprs = " ".join(t.get("expr", "") for p in paneles(d["dashboard"].get("panels", [])) for t in p.get("targets", []))
res(d["meta"].get("provisioned", False), f"el dashboard «{d['dashboard']['title']}» está aprovisionado desde archivos")
res(any(m in exprs for m in ("vigia_site_up", "vigia_checks_total", "vigia:sitio")), "el dashboard muestra la disponibilidad de los sitios")
res("vigia_site_response_seconds" in exprs, "el dashboard muestra la latencia de los sitios (vigia_site_response_seconds)")
PY
)
  fi
else
  mal "no puedo entrar en Grafana con GRAFANA_ADMIN_PASSWORD de .env. Si la cambiaste después del primer arranque, Grafana conserva la vieja en su volumen; y tras varios intentos fallidos bloquea al usuario unos minutos"
fi

if (( ALERTA )); then
  echo "== La alerta, de punta a punta (unos 8 minutos)"
  avisos()   { curl -fsS "$AM/metrics" | awk '/^alertmanager_notifications_total/ {s += $2} END {print s + 0}'; }
  fallidos() { curl -fsS "$AM/metrics" | awk '/^alertmanager_notifications_failed_total/ {s += $2} END {print s + 0}'; }
  AVISOS_ANTES=$(avisos); FALLIDOS_ANTES=$(fallidos)
  AHORA=$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())')
  if docker compose exec -T db psql -U vigia -d vigia -v ON_ERROR_STOP=1 -c \
      "INSERT INTO checks (url, status_code, seconds, up, error, checked_at) VALUES ('https://verify.invalid', 0, 0.01, 0, 'verify', '$AHORA')" >/dev/null 2>&1; then
    disparada() { consulta 'ALERTS{alertname="VigiaSitioCaido", url="https://verify.invalid", alertstate="firing"}' | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["data"]["result"] else 1)'; }
    en_am() { curl -fsS "$AM/api/v2/alerts" | python3 -c 'import json,sys; sys.exit(0 if any(a["labels"].get("url") == "https://verify.invalid" for a in json.load(sys.stdin)) else 1)'; }
    if esperar 480 disparada; then ok "VigiaSitioCaido saltó para https://verify.invalid"; else mal "VigiaSitioCaido no saltó en 8 minutos para https://verify.invalid"; fi
    if esperar 90 en_am; then ok "y llegó a Alertmanager"; else mal "la alerta no llegó a Alertmanager"; fi
    avisado() { python3 -c "import sys; sys.exit(0 if float('$(avisos)') > float('$AVISOS_ANTES') else 1)"; }
    if esperar 150 avisado; then
      if python3 -c "import sys; sys.exit(0 if float('$(fallidos)') > float('$FALLIDOS_ANTES') else 1)"; then
        mal "Alertmanager intentó avisar a tu receptor y falló: mira docker compose logs alertmanager"
      else
        ok "Alertmanager avisó a tu receptor (alertmanager_notifications_total subió)"
      fi
    else
      mal "Alertmanager no mandó ningún aviso en 2 minutos y medio: revisa route, group_wait y el receptor"
    fi
    docker compose exec -T db psql -U vigia -d vigia -c "DELETE FROM checks WHERE url = 'https://verify.invalid'" >/dev/null 2>&1
    echo "   (borré el chequeo de prueba: la alerta se resolverá sola en unos minutos)"
  else
    mal "no pude insertar el chequeo de prueba en PostgreSQL (¿servicio db, usuario y base vigia, tabla checks?)"
  fi
fi

fin
