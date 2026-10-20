# Clase 88 — Desplegar en EC2 con Session Manager

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 2 bloques (unas 3 h) · **Bloque:** B. Entrega y despliegue continuos

> 💡 **La idea de hoy:** el último paso del pipeline: **desplegar solo**. El job `desplegar` busca la instancia por su etiqueta, le envía el script de despliegue por **Session Manager** (Run Command), espera el resultado y falla si el despliegue falla. Sin SSH, sin puertos de entrada y sin llaves: el permiso lo da IAM, limitado a esa instancia por su etiqueta. Unes un PR y, minutos después, `/info` muestra el commit nuevo: **despliegue continuo**.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - EC2, *user-data*, el perfil de instancia, Session Manager y `send-command` (clases 72 y 73).
> - El *credential helper* de ECR con `credHelpers` (clases 75 y 78).
> - El rol `lab-github`, OIDC, su política `subir-a-ecr` y el job `publicar` (clases 86 y 87).
> - El entorno `production` (clase 85); las condiciones y el simulador de políticas (clase 69).
> - base64 y `jq` (clases 47 y 85).

> 🔤 **Palabras nuevas de hoy:**
> - **Run Command**: ejecutar órdenes en instancias a través de Systems Manager, sin entrar en ellas.
> - **`AWS-RunShellScript`**: el documento de SSM que ejecuta una lista de órdenes como un script de Bash.
> - **invocación y su estado**: cada ejecución de una orden en una instancia: `Pending`, `InProgress`, `Success`, `Failed`…
> - **preguntar el estado** (*poll*): consultar cada pocos segundos hasta que el estado sea final.
> - **`ssm:resourceTag/Name`**: la condición que limita un permiso a las instancias con cierta etiqueta.

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

## Cómo va esta clase

Seis piezas en dos bloques. El primero, las **piezas 1 a 3**, prepara la instancia y los permisos; el segundo, las **piezas 4 a 6**, escribe el job que despliega y lo comprueba. En cada pieza lees **una** idea y la pruebas enseguida.

Si haces los bloques en días distintos, al terminar el primero termina la instancia (`aws ec2 terminate-instances --instance-ids "$ID"`) y, al empezar el segundo, repite la preparación y la pieza 2.

**Preparación:** la red y las variables.

```bash
cd ~/my-devops-journey/labs/clase-71 && bash crear-vpc.sh
mkdir -p ~/my-devops-journey/labs/clase-88 && cd ~/my-devops-journey/labs/clase-88
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'Vpcs[0].VpcId' --output text)
PUB=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-publica --query 'Subnets[0].SubnetId' --output text)
MI_IP=$(curl -s https://checkip.amazonaws.com)
```

## Las piezas

### Pieza 1 — La instancia que recibe los despliegues: su rol y su firewall

Es la receta de las clases 72, 73 y 78, con un rol propio para esta instancia: **SSM** para recibir órdenes y **ECR** para descargar imágenes. Su security group solo deja entrar el 80 desde tu IP.

**Pruébalo:**

```bash
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

👀 **Qué deberías ver:** el ARN del rol `lab-saludo`, el JSON del perfil de instancia y, en la última orden, la regla creada (`"Return": true`).

✋ **Sin mirar:** ¿qué dos políticas administradas lleva el rol de la instancia, y para qué?

<details>
<summary>Comprueba</summary>

`AmazonSSMManagedInstanceCore`, para recibir órdenes por Session Manager, y `AmazonEC2ContainerRegistryPullOnly`, para descargar imágenes de ECR.
</details>

**En resumen:** la instancia: rol con SSM y ECR, y SG con el 80 solo para ti.

### Pieza 2 — Una instancia preparada, y Run Command por dentro

```
job "desplegar" ──ssm:SendCommand(instancia, AWS-RunShellScript, órdenes)──► SSM
                                                                              │
     el agente de la instancia, que ya estaba conectado a SSM (clase 72) ◄────┘
     ejecuta las órdenes como root y devuelve su salida
                                                                              │
job ◄── ssm:GetCommandInvocation (Pending → InProgress → Success / Failed) ───┘
```

- `send-command` es **asíncrono**: devuelve un ID al instante, y quien lo lanza tiene que preguntar hasta que el estado sea final. La CLI trae `aws ssm wait command-executed`, pero se rinde a los 100 segundos; un bucle propio da más margen.
- `get-command-invocation` devuelve los primeros 24 000 caracteres de la salida estándar y de errores. Para un despliegue, sobra.
- El documento `AWS-RunShellScript` recibe una lista de órdenes y las ejecuta como un script de Bash.

**Pruébalo.** `saludo.yaml`, el *user-data*: Docker y el helper de ECR, sin ninguna aplicación (la pondrá el pipeline):

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

Apunta la instancia en tu inventario. Ahora, lo que hará el pipeline, a mano: una orden de prueba por Run Command.

🔮 **Predice:** ¿con qué usuario se ejecutan las órdenes?

```bash
CMD=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["docker --version", "id"]}' --query Command.CommandId --output text)
sleep 5
aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --query '[Status,StandardOutputContent]' --output text
```

👀 **Qué deberías ver:** `Valid schema`, el `sleep` de la propagación de IAM (clase 72), `Online` tras unos minutos y, en la orden de prueba, `Success`, `Docker version …` y `uid=0(root)`. Por eso el `config.json` del helper está en `/root/.docker/`.

✋ **Sin mirar:** ¿qué devuelve `send-command` al instante, y cómo sabes después si la orden terminó bien?

<details>
<summary>Comprueba</summary>

Un ID de la orden. El resultado se pregunta con `get-command-invocation` hasta que el estado sea final (`Success`, `Failed`…).
</details>

**En resumen:** `send-command` es asíncrono; `get-command-invocation` da el estado y la salida; las órdenes corren como root.

### Pieza 3 — Permiso para desplegar, solo en `lab-saludo`

El rol del pipeline necesita `ssm:SendCommand` sobre dos recursos a la vez:
- **la instancia**, limitada por su etiqueta: `ssm:resourceTag/Name` = `lab-saludo`;
- **el documento** `AWS-RunShellScript`. Es de AWS, así que su ARN no lleva cuenta: `arn:aws:ssm:us-east-1::document/AWS-RunShellScript`.

Más `ec2:DescribeInstances`, para encontrarla, y `ssm:GetCommandInvocation`, para leer el resultado. Con eso, el pipeline puede ejecutar órdenes en `lab-saludo` y en ninguna otra instancia de tu cuenta.

**Pruébalo:**

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

👀 **Qué deberías ver:** `desplegar	subir-a-ecr`: el rol `lab-github` tiene ahora dos políticas *inline*.

✋ **Sin mirar:** mañana lanzas otra instancia con la etiqueta `Name=lab-saludo`. ¿Puede el pipeline desplegar en ella?

<details>
<summary>Comprueba</summary>

Sí: el permiso sigue a la etiqueta, no a una instancia concreta (lo verás en el Rómpelo 2).
</details>

**En resumen:** `SendCommand` sobre instancias con `Name=lab-saludo` y sobre el documento de shell; nada más.

> ⏸️ Aquí termina el primer bloque.

### Pieza 4 — El script de despliegue, y cómo viaja

El script vive en el repositorio (`scripts/desplegar.sh`), revisado por `shellcheck` como el resto del código. Si el contenedor no responde en 30 segundos, termina con error, y con él la orden de Run Command y el job. El job lo enviará **en base64**:

```
echo IyEvYmluL2Jhc2gK… | base64 -d > /tmp/desplegar.sh
bash /tmp/desplegar.sh <imagen>
```

- **Sin problemas de comillas:** las comillas, los `$` y los saltos de línea del script no se pelean con las del JSON de los parámetros.
- **Sin que SSM lo interprete:** SSM interpreta `{{ … }}` en los parámetros como referencias suyas, y un script de Docker suele tener `--format '{{…}}'`.

**Pruébalo.** En `lab-actions`, rama `desplegar`, crea `scripts/desplegar.sh`:

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

Y comprueba que el viaje en base64 no lo cambia:

```bash
cd ~/lab-actions && git switch main && git pull && git switch -c desplegar
# (crea scripts/desplegar.sh con el contenido de arriba)
bash -n scripts/desplegar.sh && echo "sintaxis correcta"
base64 -w0 scripts/desplegar.sh | base64 -d | diff - scripts/desplegar.sh && echo "llega igual"
```

👀 **Qué deberías ver:** `sintaxis correcta` y `llega igual`: codificado y decodificado, el script es idéntico, byte a byte.

✋ **Sin mirar:** ¿por qué el script viaja en base64 y no tal cual en los parámetros?

<details>
<summary>Comprueba</summary>

Porque así sus comillas, `$` y saltos de línea no chocan con el JSON, y SSM no interpreta sus `{{ … }}` como referencias suyas.
</details>

**En resumen:** el script, en el repositorio y revisado; en el viaje, en base64; en la instancia, decodificado y ejecutado.

### Pieza 5 — El job `desplegar`

El job hace lo de la pieza 2, pero desde el pipeline y con un bucle que espera: busca la instancia, construye el nombre de la imagen, envía el script y pregunta el estado hasta que sea final.

🔮 **Predice:** ¿cuántos jobs corren en `main`, y en qué orden?

**Pruébalo.** Añade a `ci.yml`, después de `publicar`:

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

👀 **Qué deberías ver:** cinco jobs en `main`: `lint`, `test` e `imagen` en paralelo; después `publicar`, y por último `desplegar`. En el log de `desplegar`, `OK: <imagen> responde` y `Estado: Success`. En la página principal del repositorio, *Deployments* con `production`.

✋ **Sin mirar:** ¿qué convierte un despliegue fallido en un job rojo?

<details>
<summary>Comprueba</summary>

La última línea, `test "$ESTADO" = Success`: cualquier estado que no sea `Success` termina el step con error.
</details>

**En resumen:** buscar por etiqueta → `send-command` con el script en base64 → preguntar el estado → `test` de `Success`.

### Pieza 6 — Comprobarlo desde fuera

Desde tu Ubuntu, que es la única IP que admite el SG, se ve el resultado: `/info` dice qué commit corre.

**Pruébalo:**

```bash
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
git -C ~/lab-actions log -1 --format=%H
curl -s "http://$IP/info"; echo
```

Ahora haz un cambio visible (por ejemplo, el `title` de FastAPI en `app.py`), pásalo por un PR y únelo. Minutos después, sin tocar la instancia, repite el `curl`.

👀 **Qué deberías ver:** el `version` de `/info` igual al SHA del último commit de `main`; y tras unir el cambio, el SHA nuevo, sin haber tocado la instancia: eso es **despliegue continuo**.

✋ **Sin mirar:** ¿qué pasos manuales hay entre unir un PR a `main` y que el cambio corra en `lab-saludo`?

<details>
<summary>Comprueba</summary>

Ninguno (salvo aprobar, si dejaste un revisor en `production`): el pipeline construye, publica y despliega solo.
</details>

**En resumen:** unes un PR, y `/info` muestra el commit nuevo: CI, entrega y despliegue, encadenados.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws ssm send-command --instance-ids … --document-name AWS-RunShellScript --parameters '{"commands":[…]}'` | una orden por Run Command |
| `aws ssm get-command-invocation --command-id … --instance-id … --query Status` | su estado |
| `--comment "saludo $GITHUB_SHA"` | dejar rastro de qué versión se despliega |
| `"Condition": {"StringEquals": {"ssm:resourceTag/Name": "lab-saludo"}}` | limitar `SendCommand` por etiqueta |
| `arn:aws:ssm:us-east-1::document/AWS-RunShellScript` | el documento de shell (sin cuenta) |
| `base64 -w0 script.sh` · `echo … \| base64 -d > /tmp/x.sh` | el script de ida y vuelta |
| `jq -nc --arg s "$SCRIPT" '{commands: […]}'` | los parámetros, sin pelearse con las comillas |
| `needs: publicar` + `environment: production` | desplegar solo tras publicar, con las reglas del entorno |
| `test "$ESTADO" = Success` | job rojo si el despliegue falla |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade al final del job `desplegar` una prueba de humo después del despliegue. ¿Por qué no puedes hacer `curl http://<IP>` desde el runner, y qué alternativa tienes?

> 🧩 **Ejemplo resuelto:** el bucle de `desplegar.sh`, que prueba `http://127.0.0.1/health` **dentro** de la instancia.

**Ahora tú, con huecos:** «Desde el runner no puedo, porque el SG de `lab-saludo` solo admite ____. La alternativa: comprobarlo ____ de la instancia, con otra orden de Run Command», por ejemplo:
```bash
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["curl -fsS http://127.0.0.1/____"]}' --query Command.CommandId --output text
```

<details>
<summary>Pista</summary>

Abrir el SG a todas las IP de los runners (miles, y cambian) sería peor que el problema. Después del `send-command`, el estado se pregunta con el mismo bucle del job.
</details>

**2.** Busca en CloudTrail los eventos `SendCommand` del rol `lab-github`. ¿Qué datos del despliegue aparecen? ¿Aparecen tus órdenes?

> 🧩 **Ejemplo resuelto:** la pieza 6 de la clase 86: el evento `AssumeRoleWithWebIdentity`, con el proveedor en `userIdentity` y el rol en `requestParameters`.

**Ahora tú, con huecos:** en **CloudTrail → Event history**, filtra por *Event name* = `SendCommand` y abre uno. Completa: «En `requestParameters` aparecen ____ (la instancia), ____ (el documento) y el comentario `saludo <SHA>`. Las órdenes ____ aparecen, porque…».

<details>
<summary>Pista</summary>

Mira el campo `parameters` del evento: CloudTrail no guarda en claro lo que podría ser sensible.
</details>

**3.** ¿Qué cambiaría si tuvieras **dos** instancias detrás de un balanceador? ¿Desplegarías en las dos a la vez?

> 🧩 **Ejemplo resuelto:** la pieza 2 de la clase 77: el balanceador hace comprobaciones de salud y deja de mandar tráfico a los destinos que no responden.

**Ahora tú, con huecos:** «No desplegaría en las dos ____, sino ____, para que mientras una se actualiza la otra… El balanceador saca del reparto la que…».

<details>
<summary>Pista</summary>

Con las dos a la vez, el Rómpelo 3 tumbaría las dos. Lo verás a fondo en la clase 89.
</details>

## Destruir al terminar

Si sigues hoy con la clase 89, déjalo todo. Si no:

```bash
cd ~/my-devops-journey/labs/clase-71 && bash borrar-vpc.sh
```

Eso termina `lab-saludo` y borra su security group. El rol `lab-saludo`, la política `desplegar` de `lab-github` y el repositorio de ECR no cobran por hora: se borran al final de la clase 89. Mientras no haya instancia, el pipeline omite el despliegue.

## Cierre

En `notas/fase-7/clase-88.md`:

1. ¿Por qué se despliega con Session Manager y no con SSH desde el pipeline? *(2 líneas. Empieza así: «Con SSH haría falta el puerto 22 abierto a… y una llave… Con Session Manager…»)*
2. ¿Qué hace exactamente el job `desplegar`, paso a paso? *(5–6 líneas, una por paso. Empieza así: «1. Entra en AWS con OIDC.»)*
3. ¿Qué limita a qué instancias puede enviar órdenes el pipeline? *(1–2 líneas. Empieza así: «La política del rol `lab-github`: `ssm:SendCommand` solo sobre instancias con la etiqueta…»)*
4. **Repaso (clase 87, sin mirar):** ¿por qué el job de publicación tiene que ser idempotente? *(1–2 líneas. Empieza así: «Porque los jobs se repiten y el repositorio de ECR es inmutable:…»)*

Después, escríbeme `examíname clase-88`.

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

**Reto 1:** el SG de `lab-saludo` solo admite **tu IP**, no las de los runners. Abrirlo a todas ellas sería peor que el problema. La prueba se hace **dentro** de la instancia, con otra orden de Run Command (`curl -fsS http://127.0.0.1/health`) y el mismo bucle de espera.

**Reto 2:** aparecen `instanceIds`, `documentName` (`AWS-RunShellScript`) y el `comment`. Las órdenes **no** aparecen: CloudTrail guarda los parámetros como `HIDDEN_DUE_TO_SECURITY_REASONS`, porque podrían llevar datos sensibles. Por eso el comentario con el SHA es útil.

**Reto 3:** no desplegaría en las dos **a la vez**, sino **una detrás de otra**, para que mientras una se actualiza la otra siga atendiendo. El balanceador saca del reparto la que **no pasa su comprobación de salud**, y solo se pasa a la segunda si la primera quedó sana.
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
