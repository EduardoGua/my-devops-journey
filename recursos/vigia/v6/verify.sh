#!/bin/bash
# verify.sh — pruebas de aceptación de Vigía v6 (Kubernetes en kind).
#
# Comprueba tus manifiestos de k8s/ y lo que corre en el namespace vigia de tu cluster:
# que el cluster coincide con Git, el Secret fuera del repositorio, sondas, recursos, que nada
# corre como root, el CronJob, la entrada desde fuera (Gateway o Ingress), que la API se cura
# sola y que los datos sobreviven a perder el pod de PostgreSQL.
# Para probar esas dos cosas borra un pod de la API y el de la base de datos; no cambia nada más.
#
# Uso, en la raíz de tu repositorio y con el cluster en marcha:
#   cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v6/verify.sh
# Necesita kubectl, curl, git y python3. Tarda unos 2-3 minutos.
set -u
NS=vigia
FALLOS=0
ok()  { echo "✅ $1"; }
mal() { echo "❌ $1"; FALLOS=$((FALLOS + 1)); }
fin() { echo "Fallos: $FALLOS"; exit $(( FALLOS > 0 )); }
k()   { kubectl -n "$NS" "$@"; }
esperar() {   # esperar <segundos> comando... → 0 en cuanto el comando funciona
  local limite=$(( SECONDS + $1 )); shift
  until "$@" >/dev/null 2>&1; do
    (( SECONDS >= limite )) && return 1
    sleep 3
  done
}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

[[ -d k8s && -d .git ]] || { echo "Ejecútalo en la raíz de tu repositorio de Vigía (cd ~/vigia), con tus manifiestos en k8s/."; exit 2; }
for programa in kubectl curl git python3; do
  command -v "$programa" >/dev/null || { echo "Falta $programa."; exit 2; }
done
CONTEXTO=$(kubectl config current-context 2>/dev/null)
[[ $CONTEXTO == kind-* ]] || { echo "El contexto actual es «${CONTEXTO:-ninguno}». Estas pruebas son para tu cluster de kind: kubectl config use-context kind-lab"; exit 2; }
kubectl get --raw /readyz >/dev/null 2>&1 || { echo "No llego al cluster $CONTEXTO: ¿está en marcha? (docker start lab-control-plane)"; exit 2; }

echo "== El repositorio"
mapfile -t MANIFIESTOS < <(git ls-files 'k8s/*.yaml' 'k8s/*.yml')
if (( ${#MANIFIESTOS[@]} )); then ok "${#MANIFIESTOS[@]} manifiestos de k8s/ en Git"; else mal "no hay manifiestos de k8s/ en Git (git add k8s)"; fi
SECRETOS=$(git grep -lE '^kind:[[:space:]]*Secret[[:space:]]*$' -- '*.yaml' '*.yml' 2>/dev/null)
[[ -z $SECRETOS ]] && ok "ningún Secret en Git" || mal "hay Secrets en Git ($(echo $SECRETOS)): créalos con kubectl create secret, sácalos del repositorio y cambia la contraseña"
git ls-files | grep -qE '(^|/)\.env$' && mal ".env está en Git" || ok ".env no está en Git"
if (( ${#MANIFIESTOS[@]} )); then
  MALAS=$(grep -hE '^[[:space:]]*(-[[:space:]]*)?image:' "${MANIFIESTOS[@]}" | sed -E 's/.*image:[[:space:]]*//; s/[[:space:]]*(#.*)?$//; s/["'\'']//g' |
    awk 'NF { n = split($0, p, "/"); if (p[n] !~ /[:@]/ || p[n] ~ /:latest$/) print }' | sort -u)
  [[ -z $MALAS ]] && ok "todas las imágenes llevan una etiqueta fija (ninguna latest)" || mal "imágenes sin etiqueta o con latest: $(echo $MALAS)"
fi
kubectl diff -f k8s/ > "$TMP/diff.txt" 2>&1
case $? in
  0) ok "el cluster coincide con k8s/ (kubectl diff vacío)" ;;
  1) mal "el cluster no coincide con k8s/: aplica lo que cambiaste en Git, o lleva a Git lo que cambiaste a mano:"
     grep -E '^[-+]([^-+]|$)' "$TMP/diff.txt" | grep -vE '^[-+][[:space:]]*(generation|resourceVersion|uid):' | head -8 | sed 's/^/     /' ;;
  *) mal "kubectl diff -f k8s/ falla:"; head -5 "$TMP/diff.txt" | sed 's/^/     /' ;;
esac

echo "== Lo que corre en el namespace $NS"
if ! kubectl get namespace "$NS" >/dev/null 2>&1; then mal "no existe el namespace $NS"; fin; fi
for objeto in deployment/api statefulset/db cronjob/checker service/api service/db; do
  k get "$objeto" >/dev/null 2>&1 || mal "falta $objeto en el namespace $NS"
done
# Si el cluster acaba de arrancar, da tiempo a que la API y PostgreSQL estén listos (hasta 90 s)
todo_listo() {
  local d l b
  read -r d l < <(k get deployment api -o jsonpath='{.spec.replicas} {.status.readyReplicas}' 2>/dev/null)
  b=$(k get statefulset db -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n $l && $l == "$d" && ${b:-0} -ge 1 ]]
}
esperar 90 todo_listo
k get deployment,statefulset,cronjob,service,pvc,endpointslice -o json > "$TMP/objetos.json" 2>/dev/null
SELECTOR_API=$(k get deployment api -o json 2>/dev/null |
  python3 -c 'import json,sys; print(",".join(f"{a}={b}" for a, b in json.load(sys.stdin)["spec"]["selector"]["matchLabels"].items()))' 2>/dev/null)
while IFS=$'\t' read -r estado mensaje; do
  [[ $estado == OK ]] && ok "$mensaje" || mal "$mensaje"
done < <(python3 - "$TMP/objetos.json" <<'PY'
import json, sys
from datetime import datetime, timezone

objetos = json.load(open(sys.argv[1]))["items"]
por_nombre = {(o["kind"], o["metadata"]["name"]): o for o in objetos}

def res(bien, mensaje):
    print(("OK" if bien else "MAL") + "\t" + mensaje)

def plantilla(o):
    if o["kind"] == "CronJob":
        return o["spec"]["jobTemplate"]["spec"]["template"]["spec"]
    return o["spec"]["template"]["spec"]

def sin_root(spec, c):
    return bool((c.get("securityContext") or {}).get("runAsNonRoot") or (spec.get("securityContext") or {}).get("runAsNonRoot"))

def usa_secret(spec):
    for c in spec["containers"]:
        if any((e.get("valueFrom") or {}).get("secretKeyRef") for e in c.get("env", [])) or any("secretRef" in e for e in c.get("envFrom", [])):
            return True
    return any("secret" in v for v in spec.get("volumes", []))

def usa_configmap(spec):
    for c in spec["containers"]:
        if any((e.get("valueFrom") or {}).get("configMapKeyRef") for e in c.get("env", [])) or any("configMapRef" in e for e in c.get("envFrom", [])):
            return True
    return any("configMap" in v for v in spec.get("volumes", []))

def comunes(nombre, spec):
    c = spec["containers"][0]
    res(sin_root(spec, c), f"{nombre}: runAsNonRoot: true (el kubelet se niega a arrancarlo como root)")
    res(spec.get("automountServiceAccountToken") is False, f"{nombre}: no monta el token de su ServiceAccount (automountServiceAccountToken: false)")
    res(usa_secret(spec), f"{nombre}: la contraseña llega de un Secret")
    res(usa_configmap(spec), f"{nombre}: la configuración llega de un ConfigMap")
    peticiones = (c.get("resources") or {}).get("requests") or {}
    limites = (c.get("resources") or {}).get("limits") or {}
    res("cpu" in peticiones and "memory" in peticiones and "memory" in limites, f"{nombre}: requests de cpu y memoria, y límite de memoria")

api = por_nombre.get(("Deployment", "api"))
if api:
    spec = plantilla(api)
    c = spec["containers"][0]
    deseadas = api["spec"].get("replicas", 1)
    listas = api.get("status", {}).get("readyReplicas", 0)
    res(deseadas >= 2, f"api: {deseadas} réplicas (al menos 2)")
    res(listas == deseadas, f"api: {listas} de {deseadas} réplicas listas")
    res("readinessProbe" in c, "api: tiene sonda readiness")
    res("livenessProbe" in c, "api: tiene sonda liveness")
    comunes("api", spec)

checker = por_nombre.get(("CronJob", "checker"))
if checker:
    spec = plantilla(checker)
    res(not checker["spec"].get("suspend", False), "checker: el CronJob no está suspendido")
    res(checker["spec"].get("concurrencyPolicy") == "Forbid", "checker: concurrencyPolicy: Forbid (nunca dos chequeos a la vez)")
    comunes("checker", spec)
    ultimo = checker.get("status", {}).get("lastSuccessfulTime")
    if ultimo:
        minutos = (datetime.now(timezone.utc) - datetime.fromisoformat(ultimo.replace("Z", "+00:00"))).total_seconds() / 60
        res(minutos <= 30, f"checker: su último Job bueno terminó hace {minutos:.0f} min (máximo 30)")
    else:
        res(False, "checker: ningún Job del CronJob ha terminado bien todavía (kubectl -n vigia create job --from=cronjob/checker prueba)")

db = por_nombre.get(("StatefulSet", "db"))
if db:
    plantillas = [p["metadata"]["name"] for p in db["spec"].get("volumeClaimTemplates", [])]
    res(bool(plantillas), "db: StatefulSet con volumeClaimTemplates")
    res(db.get("status", {}).get("readyReplicas", 0) >= 1, "db: PostgreSQL está listo")
    pvcs = [o for o in objetos if o["kind"] == "PersistentVolumeClaim" and any(o["metadata"]["name"].startswith(f"{p}-db-") for p in plantillas)]
    res(bool(pvcs) and all(p.get("status", {}).get("phase") == "Bound" for p in pvcs), f"db: {len(pvcs)} PVC del StatefulSet, Bound")

servicios = [o for o in objetos if o["kind"] == "Service"]
svc_api = por_nombre.get(("Service", "api"))
if svc_api:
    res(svc_api["spec"].get("type", "ClusterIP") == "ClusterIP", "service/api es ClusterIP: se entra por el Gateway o el Ingress")
expuestos = [s["metadata"]["name"] for s in servicios if s["spec"].get("type") in ("NodePort", "LoadBalancer")
             and any(p.get("port") == 5432 or p.get("targetPort") in (5432, "postgres") for p in s["spec"].get("ports", []))]
res(not expuestos, "PostgreSQL no se publica fuera del cluster" + (f": {', '.join(expuestos)}" if expuestos else ""))
listos = sum(1 for o in objetos if o["kind"] == "EndpointSlice" and o["metadata"].get("labels", {}).get("kubernetes.io/service-name") == "api"
             for e in o.get("endpoints") or [] if (e.get("conditions") or {}).get("ready"))
res(listos >= 2, f"service/api tiene {listos} endpoints listos (al menos 2)")
PY
)
REVISIONES=$(k rollout history deployment/api 2>/dev/null | grep -cE '^[0-9]+')
(( REVISIONES >= 2 )) && ok "api: $REVISIONES revisiones en kubectl rollout history (hubo al menos una actualización)" || mal "api: solo $REVISIONES revisión en kubectl rollout history: haz la actualización de la clase 115"

echo "== Desde fuera del cluster"
# Candidatos: cada Ingress con dirección y cada HTTPRoute con la dirección de su Gateway (y su host, si lo tiene).
# Se releen en cada intento: al reiniciar el cluster, cloud-provider-kind tarda en reconfigurarse y la IP puede cambiar.
candidatos() {
  { k get ingress -o json 2>/dev/null; k get gateway -o json 2>/dev/null; k get httproute -o json 2>/dev/null; } |
  python3 -c '
import json, sys
texto, objetos, pos = sys.stdin.read(), [], 0
decoder = json.JSONDecoder()
while pos < len(texto):
    while pos < len(texto) and texto[pos].isspace():
        pos += 1
    if pos >= len(texto):
        break
    lista, pos = decoder.raw_decode(texto, pos)
    objetos += lista.get("items", [])
direcciones = {o["metadata"]["name"]: [a["value"] for a in o.get("status", {}).get("addresses", [])]
               for o in objetos if o["kind"] == "Gateway"}
for o in objetos:
    if o["kind"] == "Ingress":
        ips = [i.get("ip") or i.get("hostname") for i in o.get("status", {}).get("loadBalancer", {}).get("ingress", [])]
        host = next((r.get("host") for r in o["spec"].get("rules", []) if r.get("host")), "")
        for ip in ips[:1]:
            print(f"{ip} {host}".strip())
    elif o["kind"] == "HTTPRoute":
        host = (o["spec"].get("hostnames") or [""])[0]
        for padre in o["spec"].get("parentRefs", []):
            for ip in direcciones.get(padre["name"], [])[:1]:
                print(f"{ip} {host}".strip())
'
}
ENTRADA=""; HOST=""; CANDIDATOS=()
encontrar_entrada() {
  local c ip host
  mapfile -t CANDIDATOS < <(candidatos)
  for c in "${CANDIDATOS[@]}"; do
    read -r ip host <<< "$c"
    if curl -fsS -m 5 ${host:+-H "Host: $host"} "http://$ip/health" 2>/dev/null | grep -q '"ok"'; then
      ENTRADA=$ip; HOST=$host; return 0
    fi
  done
  return 1
}
con_sitios() { curl -fsS -m 5 ${HOST:+-H "Host: $HOST"} "http://$ENTRADA/status" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("sites") else 1)'; }
limite=$(( SECONDS + 90 ))
until encontrar_entrada || (( SECONDS >= limite )); do sleep 3; done
if [[ -n $ENTRADA ]]; then
  ok "la API responde desde fuera: http://$ENTRADA/health${HOST:+ (Host: $HOST)}"
  if esperar 60 con_sitios; then ok "/status muestra los resultados del checker"; else mal "/status no tiene sitios: ¿el checker escribe en la misma base de datos?"; fi
elif (( ${#CANDIDATOS[@]} == 0 )); then
  mal "no hay ningún Gateway ni Ingress con dirección en el namespace $NS (¿está en marcha cloud-provider-kind?)"
else
  mal "ninguna entrada responde \"ok\" en /health ($(printf '%s; ' "${CANDIDATOS[@]}")). Si acabas de arrancar el cluster, espera un minuto: cloud-provider-kind tarda en reconfigurarse"
fi

echo "== Se cura sola"
if [[ -n $SELECTOR_API ]] && VICTIMA=$(k get pods -l "$SELECTOR_API" -o name 2>/dev/null | head -1) && [[ -n $VICTIMA ]]; then
  k delete "$VICTIMA" --wait=false >/dev/null 2>&1
  curado() {
    local d l
    read -r d l < <(k get deployment api -o jsonpath='{.spec.replicas} {.status.readyReplicas}')
    [[ $d == "$l" ]] && ! k get "$VICTIMA" >/dev/null 2>&1
  }
  sleep 2
  if esperar 120 curado; then ok "borré $VICTIMA y el Deployment volvió a tener todas sus réplicas listas"; else mal "borré $VICTIMA y en 2 minutos el Deployment no recuperó sus réplicas"; fi
else
  mal "no encuentro pods de la API para probarlo"
fi

echo "== Los datos sobreviven"
filas() { k exec db-0 -- psql -U vigia -d vigia -tAc "SELECT COUNT(*) FROM checks" 2>/dev/null | tr -d '[:space:]'; }
ANTES=$(filas)
if [[ -z $ANTES ]] || (( ANTES == 0 )); then
  mal "no encuentro filas en la tabla checks de PostgreSQL (db-0)"
else
  k delete pod db-0 --wait=true >/dev/null 2>&1
  esperar 180 k wait --for=condition=Ready pod/db-0 --timeout=5s
  esperar 60 bash -c "[[ -n \$(kubectl -n $NS exec db-0 -- psql -U vigia -d vigia -tAc 'SELECT 1' 2>/dev/null) ]]"
  DESPUES=$(filas)
  if [[ -n $DESPUES ]] && (( DESPUES >= ANTES )); then
    ok "borré el pod db-0 y los datos siguen ahí ($ANTES → $DESPUES filas)"
  else
    mal "borré el pod db-0 y se perdieron los datos (${ANTES} → ${DESPUES:-?} filas): ¿el volumen es un PVC del StatefulSet?"
  fi
  if [[ -n $ENTRADA ]]; then
    if esperar 60 con_sitios; then ok "la API sigue sirviendo /status después de reiniciar PostgreSQL"; else mal "la API dejó de servir /status después de reiniciar PostgreSQL"; fi
  fi
fi

fin
