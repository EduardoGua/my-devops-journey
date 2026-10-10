#!/bin/bash
# verify.sh — pruebas de aceptación de Vigía v5 (toda la infraestructura en Terraform).
#
# Comprueba el código de infra/, el estado en S3, que AWS coincide con el código
# (un plan sin cambios) y, al final, el contrato de la v3 con su verify-aws.sh.
# Solo lee: no aplica nada.
#
# Uso, en la raíz de tu repositorio, con `aws login` y `terraform init` hechos en infra/:
#   cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v5/verify.sh
set -u
export AWS_PAGER=""
FALLOS=0
ok()  { echo "✅ $1"; }
mal() { echo "❌ $1"; FALLOS=$((FALLOS + 1)); }
fin() { echo "Fallos: $FALLOS"; exit $(( FALLOS > 0 )); }
AQUI=$(cd "$(dirname "$0")" && pwd)

[[ -d infra && -d .git ]] || { echo "Ejecútalo en la raíz de tu repositorio de Vigía (cd ~/vigia)."; exit 2; }
command -v terraform >/dev/null || { echo "No encuentro terraform (clase 92)."; exit 2; }

echo "== El código"
if terraform fmt -check -recursive infra >/dev/null 2>&1; then ok "terraform fmt no cambiaría nada"; else mal "terraform fmt cambiaría archivos: terraform fmt -recursive infra"; fi
grep -qs 'required_version' infra/*.tf && ok "fija la versión de Terraform (required_version)" || mal "falta required_version en infra/"
grep -A2 -hs 'source *= *"hashicorp/aws"' infra/*.tf | grep -q 'version' && ok "fija la versión del provider de AWS" || mal "el provider de AWS no tiene versión fijada"
if grep -qs 'backend "s3"' infra/*.tf && grep -qsE 'use_lockfile *= *true' infra/*.tf; then
  ok "backend S3 con use_lockfile = true"
else
  mal "el estado no usa el backend S3 con use_lockfile = true"
fi
grep -qs 'dynamodb_table' infra/*.tf && mal "usa dynamodb_table: el bloqueo con DynamoDB está obsoleto"
MODULOS=$(for d in infra/modules/*/; do [[ -f $d/variables.tf && -f $d/outputs.tf ]] && echo "$d"; done)
if [[ -n $MODULOS ]] && grep -qsE 'source *= *"\./modules/' infra/*.tf; then
  ok "módulo propio, con variables y outputs: $(echo $MODULOS | tr '\n' ' ')"
else
  mal "no hay un módulo propio en infra/modules/ con variables.tf y outputs.tf, usado desde infra/"
fi
grep -qs 'default_tags' infra/*.tf && grep -qsE 'Proyecto *= *"vigia"' infra/*.tf && ok "default_tags con Proyecto = vigia" || mal "faltan default_tags con Proyecto = \"vigia\""
SECRETOS=$(grep -rniE '\b(password|passwd|secret|secret_key|access_key|token|api_key)\b *= *"[^"$]' infra --include=*.tf | grep -vE '= *"test"' || true)
[[ -z $SECRETOS ]] && ok "ningún secreto escrito en el código" || { mal "parece haber secretos escritos en el código:"; echo "$SECRETOS" | sed 's/^/     /'; }

echo "== Git"
git ls-files --error-unmatch infra/.terraform.lock.hcl >/dev/null 2>&1 && ok ".terraform.lock.hcl está en Git" || mal "infra/.terraform.lock.hcl no está en Git"
[[ -z $(git ls-files | grep -E '\.tfstate|(^|/)\.terraform/') ]] && ok "ningún estado ni .terraform/ en Git" || mal "hay estados o .terraform/ en Git: quítalos con git rm --cached y revisa .gitignore"
[[ -z $(git ls-files | grep -E '(^|/)terraform\.tfvars$') ]] && ok "terraform.tfvars no está en Git" || mal "terraform.tfvars está en Git: tus valores no deben ir al repositorio"
WF=$(grep -ls 'terraform' .github/workflows/*.y*ml 2>/dev/null | xargs -r grep -l 'plan' | xargs -r grep -l 'fmt')
[[ -n $WF ]] && ok "un workflow hace fmt y plan: $WF" || mal "ningún workflow hace terraform fmt y plan en los PR"

echo "== El estado"
if ! aws sts get-caller-identity >/dev/null 2>&1; then mal "no hay sesión de AWS: aws login"; fin; fi
BACKEND=infra/.terraform/terraform.tfstate
if [[ ! -f $BACKEND ]]; then
  mal "infra/ no está inicializado: terraform -chdir=infra init -backend-config=\"bucket=…\""; fin
fi
read -r BUCKET CLAVE <<< "$(python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["backend"]["config"]; print(c.get("bucket"), c.get("key"))' "$BACKEND")"
[[ $(aws s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text 2>/dev/null) == Enabled ]] && ok "el bucket del estado ($BUCKET) tiene versionado" || mal "el bucket del estado $BUCKET no tiene versionado"
BPA=$(aws s3api get-public-access-block --bucket "$BUCKET" --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text 2>/dev/null)
[[ $BPA == $'True\tTrue\tTrue\tTrue' ]] && ok "el bucket del estado bloquea todo acceso público" || mal "el bucket del estado no bloquea todo acceso público"
aws s3api head-object --bucket "$BUCKET" --key "$CLAVE" >/dev/null 2>&1 && ok "el estado está en s3://$BUCKET/$CLAVE" || mal "no encuentro el estado en s3://$BUCKET/$CLAVE"

echo "== AWS coincide con el código"
if terraform -chdir=infra validate -no-color >/dev/null 2>&1; then ok "terraform validate"; else mal "terraform validate falla"; fi
terraform -chdir=infra plan -input=false -no-color -detailed-exitcode -lock-timeout=60s > /tmp/vigia-plan.txt 2>&1
case $? in
  0) ok "terraform plan: sin cambios" ;;
  2) mal "terraform plan propone cambios: el código y AWS no coinciden (drift o cambios sin aplicar):"
     grep -E '^\s*# |^Plan:' /tmp/vigia-plan.txt | head -10 | sed 's/^/     /' ;;
  *) mal "terraform plan falla:"; grep -E 'Error' -A3 /tmp/vigia-plan.txt | head -8 | sed 's/^/     /' ;;
esac
URL=$(terraform -chdir=infra output -raw url 2>/dev/null)
INFORMES=$(terraform -chdir=infra output -raw bucket_informes 2>/dev/null)
[[ $URL == http* ]] && ok "output url: $URL" || mal "falta el output url"
[[ -n $INFORMES ]] && ok "output bucket_informes: $INFORMES" || mal "falta el output bucket_informes"

echo "== El contrato de la v3"
if [[ -n $INFORMES ]] && VIGIA_BUCKET="$INFORMES" bash "$AQUI/../v3/verify-aws.sh" > /tmp/vigia-v3.txt 2>&1; then
  ok "verify-aws.sh de la v3 pasa entero"
else
  mal "verify-aws.sh de la v3 falla:"; grep '❌' /tmp/vigia-v3.txt | sed 's/^/     /'
fi

fin
