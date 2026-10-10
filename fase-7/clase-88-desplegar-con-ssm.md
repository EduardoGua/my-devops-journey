# Clase 88 — Desplegar en EC2 con Session Manager

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 2 bloques (unas 3 h) · **Bloque:** B. Entrega y despliegue continuos

## Objetivo

- Preparar una instancia de laboratorio, `lab-saludo`, que pueda recibir despliegues: Docker, el *credential helper* de ECR y un rol para descargar imágenes.
- Dar al rol del pipeline permiso para ejecutar órdenes **solo en esa instancia**.
- Añadir el job `desplegar`:
  - busca la instancia;
  - le envía el script de despliegue por **Session Manager** (Run Command);
  - espera el resultado y falla si el despliegue falla.
- Ver el **despliegue continuo** funcionando: unes un PR y, minutos después, `/info` muestra el commit nuevo.

## Por qué importa

La forma clásica de desplegar desde un pipeline es por SSH:
- el puerto 22 abierto, quizá a las IP de GitHub, que son miles y cambian;
- una llave privada guardada como secreto.

Con Session Manager:
- **ningún puerto** de entrada abierto;
- **ninguna llave**;
- el permiso es de IAM, limitado por etiquetas;
- cada orden queda registrada en CloudTrail.

Es lo mismo que haces tú con `aws ssm start-session` desde la clase 72, pero automatizado. Y es el segundo criterio de salida de la fase: al unir a `main`, la imagen se construye, se publica **y se despliega sola**.

## Costo esperado

> 💰 **Unos 0,05 USD por sesión de 2 horas:** una t3.micro (0,0104 USD/h) con su IPv4 pública (0,005 USD/h). Termínala al acabar: el pipeline omitirá el despliegue mientras no exista.

## Teoría

### Run Command, por dentro

```
job "desplegar" ──ssm:SendCommand(instancia, AWS-RunShellScript, órdenes)──► SSM
                                                                              │
     el agente de la instancia, que ya estaba conectado a SSM (clase 72) ◄────┘
     ejecuta las órdenes como root y devuelve su salida
                                                                              │
job ◄── ssm:GetCommandInvocation (Pending → InProgress → Success / Failed) ───┘
```

- `send-command` es **asíncrono**: devuelve un ID al instante, y el job tiene que preguntar hasta que el estado sea final. La CLI trae `aws ssm wait command-executed`, pero se rinde a los 100 segundos; un bucle propio da más margen.
- `get-command-invocation` devuelve los primeros 24 000 caracteres de la salida estándar y de errores. Para un despliegue, sobra.
- El documento `AWS-RunShellScript` recibe una lista de órdenes y las ejecuta como un script de Bash.

### Cómo viaja el script

El script de despliegue vive en el repositorio (`scripts/desplegar.sh`), revisado por `shellcheck` como el resto del código. El job lo envía **en base64**:

```
echo IyEvYmluL2Jhc2gK… | base64 -d > /tmp/desplegar.sh
bash /tmp/desplegar.sh <imagen>
```

- **Sin problemas de comillas:** las comillas, los `$` y los saltos de línea del script no se pelean con las del JSON de los parámetros.
- **Sin que SSM lo interprete:** SSM interpreta `{{ … }}` en los parámetros como referencias suyas, y un script de Docker suele tener `--format '{{…}}'`.

### Permisos, limitados por etiqueta

El rol del pipeline necesita `ssm:SendCommand` sobre dos recursos a la vez:
- **la instancia**, limitada por su etiqueta: `ssm:resourceTag/Name` = `lab-saludo`;
- **el documento** `AWS-RunShellScript`. Es de AWS, así que su ARN no lleva cuenta: `arn:aws:ssm:us-east-1::document/AWS-RunShellScript`.

Con eso, el pipeline puede ejecutar órdenes en `lab-saludo`, y en ninguna otra instancia de tu cuenta.

## Práctica guiada

### Bloque 1 · La instancia que recibe los despliegues

#### 1. La red, el rol de la instancia y el firewall (20 min)

```bash
cd ~/my-devops-journey/labs/clase-71 && bash crear-vpc.sh
mkdir -p ~/my-devops-journey/labs/clase-88 && cd ~/my-devops-journey/labs/clase-88
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'Vpcs[0].VpcId' --output text)
PUB=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-publica --query 'Subnets[0].SubnetId' --output text)
MI_IP=$(curl -s https://checkip.amazonaws.com)

cp ../clase-72/confianza-ec2.json .
aws iam create-role --role-name lab-saludo --assume-role-policy-document file://confianza-ec2.json \
  --tags Key=Proyecto,Value=lab --query Role.Arn --output text
aws iam attach-role-policy --role-name lab-saludo --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam attach-role-policy --role-name lab-saludo --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly
aws iam create-instance-profile --instance-profile-name lab-saludo --tags Key=Proyecto,Value=lab
aws iam add-role-to-instance-profile --instance-profile-name lab-saludo --role-name lab-saludo

SG=$(aws ec2 create-security-group --group-name lab-saludo --vpc-id "$VPC" --description "Lab: HTTP solo desde mi IP" \
  --tag-specifications "$(etiquetas security-group lab-saludo)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 --cidr "$MI_IP/32"
```

Es la receta de las clases 72, 73 y 78, con un rol propio para esta instancia: SSM para recibir órdenes, ECR para descargar.

#### 2. Una instancia preparada para Docker y ECR (20 min)

`saludo.yaml`, el *user-data*:

```yaml
#cloud-config
# lab-saludo: Docker y el helper de ECR, listos para que el pipeline despliegue.
package_update: true
packages:
  - docker.io
  - amazon-ecr-credential-helper
write_files:
  - path: /root/.docker/config.json
    content: |
      {"credHelpers": {"__REGISTRO__": "ecr-login"}}
```

```bash
sed "s|__REGISTRO__|$REGISTRO|" saludo.yaml > /tmp/saludo-user-data.yaml
cloud-init schema -c /tmp/saludo-user-data.yaml
AMI=$(aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text)
sleep 10
ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --subnet-id "$PUB" --security-group-ids "$SG" \
  --iam-instance-profile Name=lab-saludo --metadata-options HttpTokens=required \
  --user-data file:///tmp/saludo-user-data.yaml \
  --tag-specifications "$(etiquetas instance lab-saludo)" "$(etiquetas volume lab-saludo)" \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids "$ID"
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$ID" --query 'InstanceInformationList[0].PingStatus' --output text
```

No hay ninguna aplicación instalada: la pondrá el pipeline. Apunta la instancia en tu inventario.

Comprueba a mano lo que hará el pipeline: una orden de prueba por Run Command.

```bash
CMD=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["docker --version", "id"]}' --query Command.CommandId --output text)
sleep 5
aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --query '[Status,StandardOutputContent]' --output text
```

🔮 **Predice:** ¿con qué usuario se ejecutan las órdenes? `root`. Por eso el `config.json` del helper está en `/root/.docker/`.

#### 3. Permiso para desplegar, solo en `lab-saludo` (15 min)

```bash
cat > desplegar.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BuscarLaInstancia",
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    },
    {
      "Sid": "OrdenarSoloALabSaludo",
      "Effect": "Allow",
      "Action": "ssm:SendCommand",
      "Resource": "arn:aws:ec2:us-east-1:$CUENTA:instance/*",
      "Condition": {"StringEquals": {"ssm:resourceTag/Name": "lab-saludo"}}
    },
    {
      "Sid": "SoloConElDocumentoDeShell",
      "Effect": "Allow",
      "Action": "ssm:SendCommand",
      "Resource": "arn:aws:ssm:us-east-1::document/AWS-RunShellScript"
    },
    {
      "Sid": "LeerElResultado",
      "Effect": "Allow",
      "Action": "ssm:GetCommandInvocation",
      "Resource": "*"
    }
  ]
}
EOF
aws iam put-role-policy --role-name lab-github --policy-name desplegar --policy-document file://desplegar.json
aws iam list-role-policies --role-name lab-github --query PolicyNames --output text
```

El rol `lab-github` tiene ahora dos políticas *inline*: `subir-a-ecr` (clase 87) y `desplegar`.

### Bloque 2 · El job que despliega

#### 4. El script de despliegue (15 min)

En `lab-actions`, rama `desplegar`, crea `scripts/desplegar.sh`:

```bash
#!/bin/bash
# desplegar.sh IMAGEN — corre IMAGEN como el contenedor "saludo" en el puerto 80 y comprueba que responde.
set -euo pipefail
IMAGEN="${1:?Uso: desplegar.sh IMAGEN}"
docker pull --quiet "$IMAGEN"
docker rm -f saludo >/dev/null 2>&1 || true
docker run -d --name saludo --restart unless-stopped -p 80:8000 "$IMAGEN"
for _ in $(seq 1 15); do
  if curl -fsS -m 2 http://127.0.0.1/health >/dev/null 2>&1; then
    echo "OK: $IMAGEN responde"
    exit 0
  fi
  sleep 2
done
echo "FALLO: $IMAGEN no responde" >&2
exit 1
```

Si el contenedor no responde en 30 segundos, el script termina con error, y con él la orden de Run Command y el job. El job `lint` lo revisará con `shellcheck`.

#### 5. El job `desplegar` (25 min)

Añade a `ci.yml`, después de `publicar`:

```yaml
  desplegar:
    needs: publicar
    runs-on: ubuntu-24.04
    environment: production
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - name: Buscar la instancia
        id: instancia
        run: |
          ID=$(aws ec2 describe-instances \
            --filters Name=tag:Name,Values=lab-saludo Name=instance-state-name,Values=running \
            --query 'Reservations[0].Instances[0].InstanceId' --output text)
          if [ "$ID" = "None" ]; then
            echo "::notice::No hay ninguna instancia lab-saludo en marcha: el despliegue se omite"
          fi
          echo "id=$ID" >> "$GITHUB_OUTPUT"
      - name: Desplegar con Session Manager
        if: steps.instancia.outputs.id != 'None'
        env:
          ID: ${{ steps.instancia.outputs.id }}
        run: |
          CUENTA=$(aws sts get-caller-identity --query Account --output text)
          IMAGEN="$CUENTA.dkr.ecr.us-east-1.amazonaws.com/lab-actions:$GITHUB_SHA"
          SCRIPT=$(base64 -w0 scripts/desplegar.sh)
          PARAMETROS=$(jq -nc --arg s "$SCRIPT" --arg i "$IMAGEN" \
            '{commands: ["echo \($s) | base64 -d > /tmp/desplegar.sh", "bash /tmp/desplegar.sh \($i)"]}')
          CMD=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
            --comment "saludo $GITHUB_SHA" --parameters "$PARAMETROS" \
            --query Command.CommandId --output text)
          ESTADO=Pending
          for _ in $(seq 1 40); do
            sleep 5
            ESTADO=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
              --query Status --output text 2>/dev/null || echo Pending)
            case "$ESTADO" in Pending|InProgress|Delayed) ;; *) break ;; esac
          done
          aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
            --query '[StandardOutputContent,StandardErrorContent]' --output text
          echo "Estado: $ESTADO"
          test "$ESTADO" = Success
```

- **`needs: publicar`:** si `publicar` se salta (en los PR), este job también.
- **`environment: production`:** el despliegue aparece en el historial de *Deployments* del repositorio y respeta las reglas del entorno (clase 85). Si le dejaste un revisor, tendrás que aprobarlo.
- **Si la instancia no existe**, el job lo dice con un aviso y termina en verde. Es una decisión para el laboratorio: la instancia no vive entre sesiones. En un entorno real que debe existir siempre, eso sería un **fallo**.
- **El bucle:** pregunta cada 5 segundos, durante 200 segundos como mucho, hasta que el estado deja de ser `Pending`, `InProgress` o `Delayed`. La última línea, `test`, convierte cualquier estado que no sea `Success` en un job rojo.

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git add -A && git commit -m "Desplegar en lab-saludo con Session Manager" && git push -u origin desplegar
gh pr create --fill && gh pr checks --watch && gh pr merge --squash --delete-branch
sleep 10 && gh run watch
```

🔮 **Predice:** ¿cuántos jobs corren en `main`, y en qué orden? Cinco: `lint`, `test` e `imagen` en paralelo; después `publicar`, y por último `desplegar`.

#### 6. Comprobarlo desde fuera (10 min)

```bash
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
git -C ~/lab-actions log -1 --format=%H
curl -s "http://$IP/info"; echo
```

El `version` de `/info` es el SHA del último commit de `main`. Ahora haz un cambio visible (por ejemplo, el `title` de FastAPI en `app.py`), pásalo por un PR y únelo. Minutos después, sin tocar la instancia, `/info` muestra el commit nuevo: eso es **despliegue continuo**.

## Rómpelo

**1. Sin instancia.** Para la instancia (`aws ec2 stop-instances --instance-ids "$ID"`), une un cambio pequeño y mira el job `desplegar`: verde, con el aviso de que se omitió. Arráncala otra vez (`start-instances`). Su IP pública **cambia** (clase 72): vuelve a consultarla.

**2. Una instancia que el rol no puede tocar.** Pregúntaselo al simulador de políticas (clase 69): ¿puede `lab-github` enviar órdenes a una instancia, según su etiqueta `Name`?

```bash
ROL=arn:aws:iam::$CUENTA:role/lab-github
INSTANCIA=arn:aws:ec2:us-east-1:$CUENTA:instance/$ID
for nombre in lab-saludo otro-nombre; do
  aws iam simulate-principal-policy --policy-source-arn "$ROL" \
    --action-names ssm:SendCommand --resource-arns "$INSTANCIA" \
    --context-entries "ContextKeyName=ssm:resourceTag/Name,ContextKeyValues=$nombre,ContextKeyType=string" \
    --query 'EvaluationResults[0].EvalDecision' --output text
done
```

`allowed` con `lab-saludo` e `implicitDeny` con `otro-nombre`. El permiso sigue a la **etiqueta**, no a la instancia: si mañana lanzas otra instancia con `Name=lab-saludo`, el pipeline podrá desplegar en ella; cualquier otra de tu cuenta queda fuera.

**3. Un despliegue que falla.** Ocupa el puerto 80 de la instancia con otro contenedor:

```bash
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["docker rm -f saludo; docker run -d --name okupa -p 80:80 nginx:1.29"]}'
```

Relanza el último pipeline de `main` (`gh run rerun <id>`). `docker run` del script falla porque el puerto está ocupado, la orden termina en `Failed` y el job, en rojo, con el error de Docker en su log.

Fíjate en lo que pasó: el script ya había borrado el contenedor anterior. La aplicación se quedó **caída**. Arreglarlo es la clase 89. Limpia: `docker rm -f okupa` por Run Command, y vuelve a lanzar el pipeline.

## Reto

1. Añade al final del job `desplegar` una prueba **desde fuera** de la instancia. ¿Por qué no puedes hacer `curl http://<IP>` desde el runner? Pista: tu security group. ¿Qué alternativa tienes?
2. Busca en CloudTrail los eventos `SendCommand` del rol `lab-github`. ¿Qué datos del despliegue aparecen? ¿Aparecen tus órdenes?
3. Escribe en tus notas qué cambiaría si tuvieras **dos** instancias detrás de un balanceador. ¿Desplegarías en las dos a la vez? Lo verás en la clase 89.

## Destruir al terminar

Si sigues hoy con la clase 89, déjalo todo. Si no:

```bash
cd ~/my-devops-journey/labs/clase-71 && bash borrar-vpc.sh
```

Eso termina `lab-saludo` y borra su security group. El rol `lab-saludo`, la política `desplegar` de `lab-github` y el repositorio de ECR no cobran por hora: se borran al final de la clase 89. Mientras no haya instancia, el pipeline omite el despliegue.

## Cierre

En `notas/fase-7/clase-88.md`:

1. ¿Por qué se despliega con Session Manager y no con SSH desde el pipeline?
2. ¿Qué hace exactamente el job `desplegar`, paso a paso?
3. ¿Qué limita a qué instancias puede enviar órdenes el pipeline?
4. **Repaso (clase 87, sin mirar):** ¿por qué el job de publicación tiene que ser idempotente?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Con SSH hace falta el puerto 22 abierto a las IP de los runners (miles, y cambian) y una llave privada guardada como secreto, que puede filtrarse y no caduca. Con Session Manager no hay ningún puerto de entrada ni llaves: el agente de la instancia sale hacia SSM. El permiso lo da IAM, con credenciales temporales por OIDC, y cada orden queda en CloudTrail.

**2.**
1. Entra en AWS con OIDC.
2. Busca la instancia en marcha por su etiqueta `Name=lab-saludo`; si no hay ninguna, avisa y termina.
3. Construye el nombre de la imagen con la cuenta y el SHA del commit.
4. Codifica `scripts/desplegar.sh` en base64 y lo envía con `ssm send-command` (documento `AWS-RunShellScript`), junto con la orden de ejecutarlo con esa imagen.
5. Pregunta el estado cada 5 segundos hasta que es final.
6. Imprime la salida y termina en rojo si el estado no es `Success`.

En la instancia, el script descarga la imagen, sustituye el contenedor y espera a que `/health` responda.

**3.** La política del rol `lab-github`. `ssm:SendCommand` solo está permitido sobre instancias cuya etiqueta `Name` sea `lab-saludo` (`ssm:resourceTag/Name`) y solo con el documento `AWS-RunShellScript`. Antes, la política de confianza ya exige que sea tu repositorio y la rama `main`.

**4.** Porque los jobs se repiten (un *rerun* tras un fallo de red o una cancelación) y el repositorio de ECR es inmutable: subir otra vez la misma etiqueta fallaría. Si la imagen de ese commit ya existe, el job no hace nada y termina en verde.

**Reto 1:** el SG de `lab-saludo` solo admite tu IP, no las de los runners. Abrirlo a todas ellas sería peor que el problema. La prueba se hace **dentro** de la instancia, en el propio script (`curl` a `127.0.0.1`), o con otra orden de Run Command después del despliegue.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| Run Command | ejecutar órdenes (en instancias, con Systems Manager) |
| command invocation / status | invocación de la orden / estado |
| to poll | preguntar repetidamente por el estado |
| deployment history | historial de despliegues |
| inbound port | puerto de entrada |

🎙️ *"My pipeline deploys over AWS Systems Manager: no SSH, no open inbound ports, no keys stored in GitHub. The deploy job sends a versioned script with Run Command to the instance identified by its tag, waits for the result and fails the job if the health check fails."*

## Siguiente

[Clase 89 — Estrategias de despliegue y pruebas de humo](clase-89-estrategias-de-despliegue.md)
