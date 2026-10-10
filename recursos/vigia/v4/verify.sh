#!/bin/bash
# verify.sh — pruebas de aceptación de Vigía v4 (CI/CD con GitHub Actions).
#
# Comprueba el pipeline desde tres sitios: tu repositorio (los workflows y el
# historial), GitHub (la protección de main y las ejecuciones) y AWS (OIDC, ECR y
# la instancia). Solo lee: no cambia nada ni en GitHub ni en AWS.
#
# Uso, dentro de tu repositorio y con `gh auth login` y `aws login` hechos:
#   cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v4/verify.sh
set -u
export AWS_PAGER=""
FALLOS=0
ok()  { echo "✅ $1"; }
mal() { echo "❌ $1"; FALLOS=$((FALLOS + 1)); }
fin() { echo "Fallos: $FALLOS"; exit $(( FALLOS > 0 )); }

[[ -d .git ]] || { echo "Ejecútalo dentro de tu repositorio de Vigía (cd ~/vigia)."; exit 2; }
shopt -s nullglob
WF=(.github/workflows/*.yml .github/workflows/*.yaml)

echo "== Los workflows"
if (( ${#WF[@]} == 0 )); then mal "no hay workflows en .github/workflows"; fin; fi
ok "${#WF[@]} workflow(s): ${WF[*]}"
if docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 > /tmp/vigia-actionlint.txt 2>&1; then
  ok "actionlint no encuentra problemas"
else
  mal "actionlint encuentra problemas:"; sed 's/^/     /' /tmp/vigia-actionlint.txt | head -20
fi
SIN_FIJAR=$(grep -hE '^[[:space:]]*(-[[:space:]]*)?uses:' "${WF[@]}" | grep -vE 'uses:[[:space:]]*\./' \
  | grep -vE '@[0-9a-f]{40}([[:space:]]|$)' || true)
if [[ -z $SIN_FIJAR ]]; then
  ok "todas las actions están fijadas por su commit (SHA de 40 caracteres)"
else
  mal "actions sin fijar por SHA:"; echo "$SIN_FIJAR" | sed 's/^ */     /'
fi
for f in "${WF[@]}"; do
  if grep -q '^permissions:' "$f"; then ok "$f declara 'permissions:' para todo el workflow"; else mal "$f no declara 'permissions:' en el nivel del workflow"; fi
  if awk '/^permissions:/ {p=1; next} /^[^[:space:]#]/ {p=0} p' "$f" | grep -qE 'id-token:[[:space:]]*write'; then
    mal "$f da 'id-token: write' a todo el workflow: dáselo solo a los jobs que asumen el rol"
  fi
  if grep -q 'pull_request_target' "$f"; then mal "$f usa pull_request_target, peligroso con código de PR ajenos"; fi
done
if grep -qiE 'aws-access-key-id|aws-secret-access-key|AWS_SECRET_ACCESS_KEY' "${WF[@]}"; then
  mal "algún workflow usa llaves de acceso de AWS: usa OIDC"
else
  ok "ningún workflow usa llaves de acceso de AWS"
fi

echo "== El historial de Git"
if git log --all -p 2>/dev/null | grep -qE 'AKIA[0-9A-Z]{16}|aws_secret_access_key[[:space:]]*='; then
  mal "el historial contiene algo que parece una llave de AWS (aunque la borraras después, sigue ahí)"
else
  ok "ninguna llave de AWS en todo el historial"
fi

echo "== GitHub"
if ! gh auth status >/dev/null 2>&1; then mal "gh no tiene sesión: gh auth login"; fin; fi
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
[[ $(gh repo view --json visibility -q .visibility) == PUBLIC ]] && ok "$REPO es público" || mal "$REPO no es público"
CHECKS=$(gh api "repos/$REPO/rules/branches/main" --jq '[.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | join(" ")' 2>/dev/null)
CON_PR=$(gh api "repos/$REPO/rules/branches/main" --jq 'any(.[]; .type == "pull_request")' 2>/dev/null)
if [[ -z $CHECKS ]]; then  # quizá con la protección clásica de ramas en lugar de reglas
  CHECKS=$(gh api "repos/$REPO/branches/main/protection" --jq '[(.required_status_checks.checks // [])[].context] | join(" ")' 2>/dev/null)
  CON_PR=$(gh api "repos/$REPO/branches/main/protection" --jq '.required_pull_request_reviews != null' 2>/dev/null)
fi
[[ ${CON_PR:-} == true ]] && ok "main solo admite cambios por pull request" || mal "main admite push directo: exige pull request"
if [[ -n $CHECKS ]]; then ok "main exige comprobaciones en verde: $CHECKS"; else mal "main no exige comprobaciones en verde antes de unir"; fi
[[ " $CHECKS " == *test* ]] && ok "las pruebas están entre las comprobaciones obligatorias" || mal "las pruebas (el job test) no son una comprobación obligatoria"
if gh secret list --json name -q '.[].name' 2>/dev/null | grep -qiE '^AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY)$'; then
  mal "hay secretos con llaves de AWS en el repositorio: bórralos y usa OIDC"
else
  ok "ningún secreto con llaves de AWS"
fi
VARIABLES=$(gh variable list --json name -q '.[].name' 2>/dev/null)
for v in AWS_ROLE_ARN AWS_REGION; do
  grep -qx "$v" <<< "$VARIABLES" && ok "la variable $v está definida" || mal "falta la variable $v (Settings → Secrets and variables → Actions → Variables)"
done
gh api "repos/$REPO/environments/production" >/dev/null 2>&1 && ok "existe el entorno production" || mal "no existe el entorno production"
git fetch -q origin main 2>/dev/null
HEAD=$(git rev-parse origin/main)
CORRIDAS=$(gh run list --branch main --event push --limit 30 --json headSha,conclusion \
  -q "[.[] | select(.headSha == \"$HEAD\") | .conclusion] | join(\" \")")
if [[ -z $CORRIDAS ]]; then
  mal "no hay ejecuciones del pipeline para el último commit de main ($HEAD)"
elif [[ $CORRIDAS =~ ^(success ?)+$ ]]; then
  ok "el pipeline del último commit de main terminó en verde"
else
  mal "el pipeline del último commit de main no está en verde: $CORRIDAS"
fi

echo "== AWS"
if ! aws sts get-caller-identity >/dev/null 2>&1; then mal "no hay sesión de AWS: aws login"; fin; fi
PROVEEDOR=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?ends_with(Arn, 'oidc-provider/token.actions.githubusercontent.com')].Arn | [0]" --output text)
if [[ -n $PROVEEDOR && $PROVEEDOR != None ]]; then
  ok "existe el proveedor OIDC de GitHub"
  aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVEEDOR" --query ClientIDList --output text \
    | grep -qw sts.amazonaws.com && ok "su audiencia es sts.amazonaws.com" || mal "el proveedor no tiene la audiencia sts.amazonaws.com"
else
  mal "no existe el proveedor OIDC token.actions.githubusercontent.com"
fi
ROL_ARN=$(gh variable get AWS_ROLE_ARN 2>/dev/null)
ROL=${ROL_ARN##*/}
IDS=$(gh api "repos/$REPO" --jq '"\(.id) \(.owner.id)"')
CONFIANZA=$(aws iam get-role --role-name "$ROL" --query Role.AssumeRolePolicyDocument --output json 2>/dev/null)
if [[ -z $CONFIANZA ]]; then
  mal "no encuentro el rol de AWS_ROLE_ARN ($ROL_ARN)"
else
  VEREDICTO=$(python3 - "$CONFIANZA" "$REPO" $IDS <<'PY'
import json, sys
doc, repo, repo_id, owner_id = json.loads(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
dueno, nombre = repo.split("/")
problemas = []
for st in [s for s in doc["Statement"] if s.get("Effect") == "Allow"]:
    fed = st.get("Principal", {}).get("Federated", "")
    if not str(fed).endswith("token.actions.githubusercontent.com"):
        problemas.append("una declaración confía en algo que no es el proveedor OIDC de GitHub")
        continue
    cond = {}
    for operador, claves in st.get("Condition", {}).items():
        for clave, valor in claves.items():
            cond[clave.split(":")[-1]] = (operador, valor if isinstance(valor, list) else [valor])
    if cond.get("aud", ("", []))[1] != ["sts.amazonaws.com"]:
        problemas.append("no exige aud = sts.amazonaws.com")
    por_id = cond.get("repository_id", ("", []))[1] == [repo_id]
    subs = cond.get("sub", ("", []))[1]
    por_sub = bool(subs) and all(s.startswith((f"repo:{repo}:", f"repo:{dueno}@{owner_id}/{nombre}@{repo_id}:")) for s in subs)
    if not (por_id or por_sub):
        problemas.append(f"no limita el rol a {repo} (por repository_id o por un sub exacto)")
print("; ".join(problemas) or "OK")
PY
)
  [[ $VEREDICTO == OK ]] && ok "el rol $ROL solo lo puede asumir $REPO desde GitHub Actions" || mal "el rol $ROL: $VEREDICTO"
  if aws iam list-attached-role-policies --role-name "$ROL" --query 'AttachedPolicies[].PolicyName' --output text \
      | grep -qE 'AdministratorAccess|PowerUserAccess'; then
    mal "el rol $ROL tiene permisos de administrador: dale solo lo que el pipeline necesita"
  else
    ok "el rol $ROL no tiene permisos de administrador"
  fi
fi
if aws ecr describe-images --repository-name vigia --image-ids "imageTag=$HEAD" >/dev/null 2>&1; then
  ok "ECR tiene vigia:$HEAD, la imagen del último commit de main"
else
  mal "ECR no tiene la imagen vigia:$HEAD"
fi

echo "== El despliegue"
read -r ID IP <<< "$(aws ec2 describe-instances --filters Name=tag:Proyecto,Values=vigia Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress]' --output text)"
if [[ -z ${ID:-} || $ID == None ]]; then
  mal "no hay una instancia de Vigía en marcha: lánzala (guía de la v3) y despliega para comprobarlo"
else
  CMD=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript --comment "verify de Vigia v4" \
    --parameters '{"commands":["echo corriendo=$(docker ps | grep -c '"$HEAD"')"]}' --query Command.CommandId --output text 2>/dev/null)
  SALIDA=""
  for _ in $(seq 1 15); do
    sleep 2
    SALIDA=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --query StandardOutputContent --output text 2>/dev/null)
    [[ $SALIDA == *corriendo=* ]] && break
  done
  if (( $(sed -n 's/^corriendo=//p' <<< "$SALIDA" | head -1 | tr -dc '0-9' || echo 0) >= 2 )); then
    ok "la instancia ejecuta la API y el chequeo con vigia:$HEAD"
  else
    mal "la instancia no ejecuta vigia:$HEAD (¿falló el despliegue o no se lanzó?)"
  fi
  if curl -fsS -m 10 "http://$IP/health" 2>/dev/null | grep -q '"ok"'; then ok "/health responde desde tu IP"; else mal "http://$IP/health no responde desde tu IP"; fi
fi

fin
