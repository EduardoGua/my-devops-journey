#!/bin/bash
# verify-aws.sh — pruebas de aceptación de Vigía v3 (AWS).
#
# Comprueba desde tu Ubuntu, con la AWS CLI, que tu despliegue cumple el contrato
# de las clases 78 y 79. No crea ni borra nada en tu cuenta: solo lee, y lanza en
# la instancia un comando de solo lectura con Session Manager.
#
# Uso, con la sesión de `aws login` abierta:
#   VIGIA_BUCKET=nombre-de-tu-bucket bash ~/my-devops-journey/recursos/vigia/v3/verify-aws.sh
# La región sale de AWS_REGION o de tu perfil (si no hay ninguna, us-east-1).
set -u
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null)}"
export AWS_REGION="${REGION:-us-east-1}" AWS_PAGER=""
BUCKET="${VIGIA_BUCKET:?Indica tu bucket: VIGIA_BUCKET=nombre bash verify-aws.sh}"
FALLOS=0

ok()  { echo "✅ $1"; }
mal() { echo "❌ $1"; FALLOS=$((FALLOS + 1)); }
fin() { echo "Fallos: $FALLOS"; exit $(( FALLOS > 0 )); }

echo "== Sesión"
QUIEN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null) || { mal "no hay sesión de AWS: ejecuta aws login"; fin; }
ok "sesión de AWS abierta ($QUIEN, región $AWS_REGION)"

echo "== La instancia"
FILTRO=(--filters Name=tag:Proyecto,Values=vigia Name=instance-state-name,Values=running)
CUANTAS=$(aws ec2 describe-instances "${FILTRO[@]}" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)
if [[ -z $CUANTAS || $CUANTAS == 0 ]]; then
  mal "no hay ninguna instancia en marcha con la etiqueta Proyecto=vigia en $AWS_REGION"; fin
fi
(( CUANTAS > 1 )) && mal "hay $CUANTAS instancias Proyecto=vigia en marcha: deja solo una (cada una cobra por hora)"
read -r ID IP PERFIL TOKENS SALTOS <<< "$(aws ec2 describe-instances "${FILTRO[@]}" \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,IamInstanceProfile.Arn,MetadataOptions.HttpTokens,MetadataOptions.HttpPutResponseHopLimit]' \
  --output text)"
ok "instancia $ID en marcha, IP pública $IP"
[[ $PERFIL != None ]] && ok "tiene un rol IAM (perfil de instancia)" || mal "la instancia no tiene rol IAM"
[[ $TOKENS == required ]] && ok "IMDSv2 obligatorio" || mal "IMDSv2 no es obligatorio (HttpTokens=$TOKENS)"
if [[ $SALTOS =~ ^[0-9]+$ ]] && (( SALTOS >= 2 )); then
  ok "límite de saltos de metadatos $SALTOS: los contenedores llegan al rol"
else
  mal "límite de saltos de metadatos $SALTOS: los contenedores no podrán usar el rol (pon 2)"
fi

echo "== El firewall (security groups)"
SGS=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text)
read -r P22 ABIERTO <<< "$(aws ec2 describe-security-groups --group-ids $SGS --query 'SecurityGroups[].IpPermissions[]' --output json | python3 -c '
import json, sys
p22 = abierto = False
for r in json.load(sys.stdin):
    desde, hasta = r.get("FromPort", 0), r.get("ToPort", 65535)
    if r.get("IpProtocol") == "-1" or desde == -1:
        desde, hasta = 0, 65535
    p22 = p22 or desde <= 22 <= hasta
    abierto = abierto or any(x.get("CidrIp") == "0.0.0.0/0" for x in r.get("IpRanges", [])) \
                      or any(x.get("CidrIpv6") == "::/0" for x in r.get("Ipv6Ranges", []))
print(int(p22), int(abierto))')"
[[ $P22 == 0 ]] && ok "el puerto 22 está cerrado" || mal "el puerto 22 está abierto: entra con Session Manager"
[[ $ABIERTO == 0 ]] && ok "ninguna regla de entrada abierta a todo internet" || mal "hay reglas de entrada abiertas a todo internet (0.0.0.0/0 o ::/0)"

echo "== Vigía responde"
if curl -fsS -m 10 "http://$IP/health" 2>/dev/null | grep -q '"ok"'; then ok "/health responde desde tu IP"; else mal "http://$IP/health no responde desde tu IP"; fi
if curl -fsS -m 10 "http://$IP/status" 2>/dev/null | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["sites"] else 1)' 2>/dev/null; then
  ok "/status muestra sitios"
else
  mal "/status no muestra sitios"
fi

echo "== Dentro de la instancia (Session Manager)"
PING=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$ID" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
if [[ $PING == Online ]]; then
  ok "el agente de Session Manager está conectado"
  CMD=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript --comment "verify-aws de Vigia v3" \
    --parameters '{"commands":[
      "if test -e /root/.aws/credentials || test -e /home/ubuntu/.aws/credentials || grep -qs AWS_SECRET_ACCESS_KEY /opt/vigia/.env; then echo llaves=si; else echo llaves=no; fi",
      "echo ecr=$(docker ps | grep -c dkr.ecr)",
      "echo timer=$(systemctl is-active vigia-report.timer)"]}' \
    --query Command.CommandId --output text 2>/dev/null)
  SALIDA=""
  for _ in $(seq 1 15); do
    sleep 2
    SALIDA=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --query StandardOutputContent --output text 2>/dev/null)
    [[ $SALIDA == *timer=* ]] && break
  done
  if [[ $SALIDA != *timer=* ]]; then
    mal "el comando de comprobación no terminó en la instancia (mira Run Command en la consola)"
  else
    grep -q '^llaves=no' <<< "$SALIDA" && ok "no hay llaves de AWS guardadas en la instancia" || mal "hay llaves de AWS guardadas en la instancia (~/.aws/credentials o .env)"
    (( $(sed -n 's/^ecr=//p' <<< "$SALIDA") >= 2 )) && ok "la API y el chequeo corren con la imagen de ECR" || mal "la API y el chequeo no corren con una imagen de ECR"
    grep -q '^timer=active' <<< "$SALIDA" && ok "el timer del informe diario está activo" || mal "el timer vigia-report.timer no está activo"
  fi
else
  mal "Session Manager no ve la instancia (estado: ${PING:-ninguno}): ¿rol con AmazonSSMManagedInstanceCore y salida a internet?"
fi

echo "== CloudWatch Logs"
for g in /vigia/api /vigia/checker; do
  if [[ -z $(aws logs describe-log-groups --log-group-name-prefix "$g" --query "logGroups[?logGroupName=='$g'].logGroupName" --output text 2>/dev/null) ]]; then
    mal "no existe el grupo de logs $g"; continue
  fi
  RET=$(aws logs describe-log-groups --log-group-name-prefix "$g" --query "logGroups[?logGroupName=='$g'] | [0].retentionInDays" --output text)
  [[ $RET != None ]] && ok "$g existe y caduca a los $RET días" || mal "$g no tiene retención: guarda los logs para siempre (y cobra)"
done
DESDE=$(( ($(date +%s) - 1800) * 1000 ))
if aws logs filter-log-events --log-group-name /vigia/checker --start-time "$DESDE" --limit 1 --query 'events[0].message' --output text 2>/dev/null | grep -qv '^None$'; then
  ok "el chequeo ha escrito en CloudWatch en la última media hora"
else
  mal "no hay logs del chequeo en CloudWatch en la última media hora"
fi

echo "== S3"
BPA=$(aws s3api get-public-access-block --bucket "$BUCKET" --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text 2>/dev/null)
[[ $BPA == $'True\tTrue\tTrue\tTrue' ]] && ok "el bucket bloquea todo acceso público" || mal "el bucket no bloquea todo acceso público"
[[ $(aws s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text 2>/dev/null) == Enabled ]] && ok "el versionado está activado" || mal "el versionado no está activado"
HOY=$(date -u +%F)
if aws s3 cp "s3://$BUCKET/reports/$HOY.json" - 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["sites"] and "availability" in d["sites"][0] else 1)' 2>/dev/null; then
  ok "el informe de hoy (reports/$HOY.json) está en S3, con la disponibilidad de cada sitio"
else
  mal "no hay un informe válido en s3://$BUCKET/reports/$HOY.json (lánzalo a mano: sudo systemctl start vigia-report.service)"
fi

fin
