# Clase 73 — Security groups y NACLs

**Dónde:** tu Ubuntu (AWS CLI) + CloudShell · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** en AWS hay dos firewalls. El **security group** va en cada instancia, tiene estado y solo admite reglas de permitir; la **NACL** va en cada subred, no tiene estado y tiene reglas numeradas de permitir y denegar. Hoy abres un servidor solo a tu IP, haces que la "base de datos" acepte conexiones **de un grupo** y no de una IP, ves en vivo por qué una NACL sin los puertos efímeros lo rompe todo y aprendes a leer el síntoma: *timeout* frente a *refused*.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La teoría de security groups y NACLs, y que los dos descartan en silencio (clase 33).
> - Los puertos efímeros, *refused* frente a *timeout* y `ss -tlnp` (clase 29); `systemctl` (clase 12).
> - Tu VPC y `borrar-vpc.sh` (clase 71); el rol `lab-ssm`, `web.yaml` y Session Manager (clase 72); CloudShell (clase 68).

> 🔤 **Palabras nuevas de hoy:**
> - **security group** (SG): el firewall de cada interfaz de red; con estado, solo permite.
> - **NACL** (*network ACL*): el firewall de una subred; sin estado, permite y deniega por orden.
> - **con estado / sin estado** (*stateful / stateless*): recuerda la conexión y deja pasar su respuesta / trata cada paquete por separado.
> - **SG como origen**: una regla que admite a "cualquier interfaz que lleve tal SG".
> - **`send-command`**: ejecutar órdenes en instancias por SSM, sin entrar en ellas.

## Objetivo

- Abrir un servicio **solo a tu IP** con un security group, y comprobarlo desde dentro y desde fuera.
- Usar **otro security group como origen**: "la base de datos acepta conexiones del servidor web", sin escribir ninguna IP.
- Comprobar en vivo que las **NACL no tienen estado**, y por qué olvidar los puertos efímeros rompe todo.
- Diagnosticar por el síntoma: un ***timeout*** (algo descarta el paquete) frente a un ***connection refused*** (llegaste, pero nadie escucha).

## Por qué importa

En la clase 33 viste la teoría y la tabla de security groups frente a NACLs. Hoy la aplicas en AWS de verdad.

Casi todos los "no conecta" después de un despliegue son una regla que falta. Casi todos los "nos entraron" empiezan por una regla que sobra: el 22 o la base de datos abiertos a `0.0.0.0/0`. Es el hallazgo número uno de cualquier auditoría de seguridad en AWS, y Vigía v3 tendrá que pasar la suya (clase 78).

## Costo esperado

> 💰 **Unos 0,05 USD de créditos:** dos t3.micro y una IPv4 pública durante algo más de una hora. Sin NAT Gateway.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 50 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto, la limpieza y el cierre. Si paras entre medias, ejecuta "Destruir al terminar" (sin borrar el rol) y, al volver, repite la preparación y la pieza 1.

**Preparación:** la red de la clase 71 y el rol `lab-ssm` de la 72.

```bash
cd ~/my-devops-journey/labs/clase-71 && bash crear-vpc.sh
mkdir -p ~/my-devops-journey/labs/clase-73 && cd ~/my-devops-journey/labs/clase-73
cp ../clase-72/web.yaml .
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }
VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'Vpcs[0].VpcId' --output text)
PUB=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-publica --query 'Subnets[0].SubnetId' --output text)
PRIV=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-privada --query 'Subnets[0].SubnetId' --output text)
AMI=$(aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id --query Parameter.Value --output text)
MI_IP=$(curl -s https://checkip.amazonaws.com)
echo "Mi IP pública: $MI_IP"
```

`checkip.amazonaws.com` te dice con qué IP sales a internet: la que verá AWS.

## Las piezas

### Pieza 1 — El security group: el servidor web, abierto solo a ti

| | Security group (SG) | Network ACL (NACL) |
|-|---------------------|--------------------|
| Se aplica a | cada interfaz de red (una EC2, una base de datos de RDS, un balanceador) | la **subred** entera |
| Estado | **con estado**: las respuestas pasan solas | **sin estado**: cada sentido necesita su regla |
| Reglas | solo **permitir** | **permitir y denegar**, numeradas: gana la de **menor número** que encaje |
| Por defecto | uno nuevo: nada entra, todo sale | la NACL por defecto de la VPC permite todo; **una nueva lo deniega todo** |
| Origen | un CIDR, **otro SG** o una *prefix list* | solo CIDR |

Los dos **descartan en silencio**, así que una regla que falta se ve como *timeout* (clase 33).

🔮 **Predice:** desde CloudShell, ¿qué verás al pedir la web?

**Pruébalo:**

```bash
SG_WEB=$(aws ec2 create-security-group --group-name lab-web --vpc-id "$VPC" \
  --description "Lab: HTTP solo desde mi IP" \
  --tag-specifications "$(etiquetas security-group lab-web)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_WEB" \
  --protocol tcp --port 80 --cidr "$MI_IP/32"
ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PUB" --security-group-ids "$SG_WEB" \
  --iam-instance-profile Name=lab-ssm --metadata-options HttpTokens=required \
  --user-data file://web.yaml \
  --tag-specifications "$(etiquetas instance lab-web)" "$(etiquetas volume lab-web)" \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids "$ID"
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl -s "http://$IP"
echo "$IP"
```

`instance-status-ok` espera a que la instancia pase sus comprobaciones de estado: unos 2 o 3 minutos más que `instance-running`, lo justo para que cloud-init instale nginx. Si `curl` no responde todavía, espera un minuto.

Ahora prueba desde **otra IP**: abre **CloudShell** y lanza `curl -m 5 http://<la IP de lab-web>`.

👀 **Qué deberías ver:** desde tu Ubuntu, tu página (`<h1>Hola desde i-0…</h1>`). Desde CloudShell, `curl: (28) Connection timed out` a los 5 segundos: su IP es de AWS, no la tuya, y la regla solo admite `$MI_IP/32`. El SG descarta en silencio.

✋ **Sin mirar:** ¿qué deja entrar y salir un security group recién creado?

<details>
<summary>Comprueba</summary>

No deja entrar nada y deja salir todo.
</details>

**En resumen:** `authorize-security-group-ingress … --cidr TU_IP/32` abre un puerto solo para ti; el resto ve *timeout*.

### Pieza 2 — El síntoma: *timeout* frente a *refused*

| Lo que ves | Qué significa | Dónde mirar |
|------------|---------------|-------------|
| ***timeout*** | algo **descartó** el paquete por el camino, o no hay camino | SG, NACL, tabla de rutas, IP pública, que la instancia esté encendida |
| ***connection refused*** | **llegaste** a la máquina, pero nadie escucha en ese puerto | el servicio: `systemctl status`, `ss -tlnp` (clases 12 y 29) |
| **respuesta HTTP con error** (502, 404…) | la red está bien; el problema es la aplicación | los logs de la aplicación |

Un *refused* es una buena noticia para la red: toda la cadena de reglas funcionó.

`send-command` es la otra cara de Session Manager: ejecutar órdenes en una o cien instancias sin entrar en ninguna. En la fase 7 desplegarás así desde GitHub Actions.

🔮 **Predice:** con nginx parado, ¿*timeout* o *refused* desde tu Ubuntu? ¿Y desde CloudShell?

**Pruébalo:**

```bash
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["systemctl stop nginx"]}' --query Command.CommandId --output text
sleep 5
curl -m 5 "http://$IP"
```

Repite el `curl -m 5` en CloudShell, y después vuelve a arrancar nginx:

```bash
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["systemctl start nginx"]}' --query Command.CommandId --output text
```

👀 **Qué deberías ver:** desde tu Ubuntu, `curl: (7) Failed to connect … Connection refused`, al instante: el SG te deja pasar, el paquete llega, y el kernel de la instancia responde "aquí no escucha nadie". Desde CloudShell, el mismo *timeout* de antes. El mismo puerto, dos síntomas distintos, dos causas distintas.

✋ **Sin mirar:** recibes *connection refused*. ¿Dónde está el problema, en la red o en el servicio?

<details>
<summary>Comprueba</summary>

En el servicio: llegaste a la máquina, así que la red funcionó. Mira `systemctl status` y `ss -tlnp`.
</details>

**En resumen:** *timeout* = algo descarta (SG, NACL, rutas); *refused* = llegaste y nadie escucha.

### Pieza 3 — Un security group como origen

Una regla con **otro security group como origen** significa "cualquier interfaz que tenga ese SG puesto". Si mañana el servidor web cambia de IP, o pasas a tener diez detrás de un balanceador, la regla sigue valiendo: la identidad es el **grupo**, no la dirección.

```
internet ──80 (solo mi IP)──► [ SG lab-web ]  lab-web  ──8080──►  [ SG lab-db ]  lab-db
                                                                   origen: SG lab-web
```

Cada VPC trae un SG llamado **`default`**: permite todo el tráfico entre las interfaces que lo llevan. Una instancia lanzada sin indicar SG recibe ese. La buena práctica es no usarlo: crea SG con nombre y propósito.

**Pruébalo.** Una segunda instancia en la subred **privada** hará de base de datos. Para no instalar PostgreSQL, sirve una página en el puerto 8080 con el servidor web de Python. Crea `db.yaml`:

```yaml
#cloud-config
# Una "base de datos" de mentira: un servidor HTTP en el 8080.
write_files:
  - path: /srv/demo/index.html
    content: "<p>Soy la base de datos (de mentira)</p>\n"
runcmd:
  - [systemd-run, --unit=demo, python3, -m, http.server, "8080", --directory, /srv/demo]
```

No necesita internet: Python ya viene en la AMI. Su SG admite el 8080 **solo desde el SG `lab-web`**:

```bash
cloud-init schema -c db.yaml
SG_DB=$(aws ec2 create-security-group --group-name lab-db --vpc-id "$VPC" \
  --description "Lab: 8080 solo desde lab-web" \
  --tag-specifications "$(etiquetas security-group lab-db)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_DB" \
  --ip-permissions "IpProtocol=tcp,FromPort=8080,ToPort=8080,UserIdGroupPairs=[{GroupId=$SG_WEB,Description=desde-lab-web}]"
IDDB=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PRIV" --security-group-ids "$SG_DB" --metadata-options HttpTokens=required \
  --user-data file://db.yaml \
  --tag-specifications "$(etiquetas instance lab-db)" "$(etiquetas volume lab-db)" \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids "$IDDB"
DB_IP=$(aws ec2 describe-instances --instance-ids "$IDDB" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
echo "$DB_IP"
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG_DB" \
  --query 'SecurityGroupRules[?!IsEgress].[FromPort,CidrIpv4,ReferencedGroupInfo.GroupId]' --output text
```

La regla no tiene CIDR: tiene un SG (`8080 None sg-…`). Prueba desde `lab-web` con `aws ssm start-session --target "$ID"` y, dentro, `curl -m 5 http://<DB_IP>:8080`; después, `exit`.

🔮 **Predice:** si le quitas a `lab-web` su SG y le pones el `default`, ¿llegará a `lab-db`? ¿Seguirá funcionando Session Manager?

```bash
SG_DEF=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" Name=group-name,Values=default \
  --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 modify-instance-attribute --instance-id "$ID" --groups "$SG_DEF"
aws ssm start-session --target "$ID"
```

Repite el `curl` dentro, sal, y devuélvele su SG:

```bash
aws ec2 modify-instance-attribute --instance-id "$ID" --groups "$SG_WEB"
```

👀 **Qué deberías ver:** la primera vez, `<p>Soy la base de datos (de mentira)</p>`: `lab-web` lleva el SG `lab-web`, y eso basta. Con el `default`, *timeout*: la máquina es la misma, con la misma IP, pero ya no es "miembro" de `lab-web`. Y Session Manager sigue funcionando, porque la sesión **sale** de la instancia, y los SG no filtran la salida por defecto.

✋ **Sin mirar:** ¿por qué la regla de `lab-db` sigue valiendo si recreas el servidor web y cambia su IP?

<details>
<summary>Comprueba</summary>

Porque admite al grupo `lab-web`, no a una IP: cualquier interfaz que lleve ese SG puede entrar.
</details>

**En resumen:** con un SG como origen, la regla va con la identidad del grupo; el SG `default`, mejor no usarlo.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Una NACL sin estado y los puertos efímeros

Cuando tu portátil abre una conexión al puerto 80, lo hace **desde** un puerto alto al azar: el puerto **efímero** (clase 29). La respuesta del servidor va **hacia** ese puerto. Un SG lo recuerda y deja pasar la respuesta; una NACL no recuerda nada. Por eso, en una NACL personalizada:
- la **salida** necesita una regla para `1024-65535` hacia los clientes, o las respuestas mueren;
- la **entrada** necesita otra regla para `1024-65535`, o mueren las respuestas a las conexiones que **inicia** la instancia (`apt`, el agente de SSM…).

**Pruébalo.** Una NACL nueva lo deniega todo. Créala, míralo y ponla en la subred pública:

```bash
NACL=$(aws ec2 create-network-acl --vpc-id "$VPC" \
  --tag-specifications "$(etiquetas network-acl lab-nacl-publica)" --query NetworkAcl.NetworkAclId --output text)
aws ec2 describe-network-acls --network-acl-ids "$NACL" \
  --query 'NetworkAcls[0].Entries[].[Egress,RuleNumber,RuleAction,CidrBlock]' --output table
NACL_DEF=$(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$PUB" \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
asociacion() { aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$PUB" \
  --query "NetworkAcls[0].Associations[?SubnetId=='$PUB'].NetworkAclAssociationId" --output text; }
aws ec2 replace-network-acl-association --association-id "$(asociacion)" --network-acl-id "$NACL"
curl -m 5 "http://$IP"
```

👀 **Qué deberías ver:** solo la regla `*` (32767) que deniega todo, en los dos sentidos; y *timeout*: la subred entera está sellada. Ahora, paso a paso.

**a)** Deja entrar el 80 desde tu IP:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 100 \
  --protocol tcp --port-range From=80,To=80 --cidr-block "$MI_IP/32" --rule-action allow
curl -m 5 "http://$IP"
```

🔮 **Predice:** ¿funciona ya?

👀 **Qué deberías ver:** no: *timeout*. La petición **entra**, pero la respuesta, que va del puerto 80 a tu puerto efímero, no tiene regla de **salida**. Sin estado, cada sentido es un mundo.

**b)** Deja salir las respuestas hacia tus puertos efímeros:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --egress --rule-number 100 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block "$MI_IP/32" --rule-action allow
curl -m 5 "http://$IP"
```

👀 **Qué deberías ver:** tu página.

**c)** Pero Session Manager está muerto: `aws ssm start-session --target "$ID"` no conecta. El agente **inicia** conexiones HTTPS hacia AWS, y la NACL no las deja salir ni deja volver sus respuestas:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --egress --rule-number 110 \
  --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 110 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow
```

👀 **Qué deberías ver:** en un minuto o dos, Session Manager vuelve.

✋ **Sin mirar:** en una NACL personalizada, ¿qué dos reglas de puertos efímeros hacen falta y para qué?

<details>
<summary>Comprueba</summary>

Una de salida a `1024-65535`, para las respuestas a quien se conecta a la instancia; y una de entrada a `1024-65535`, para las respuestas a las conexiones que inicia la instancia.
</details>

**En resumen:** una NACL nueva lo deniega todo, y sin estado cada sentido necesita su regla, efímeros incluidos.

### Pieza 5 — El orden de las reglas de una NACL

En una NACL, las reglas se evalúan por **número**, de menor a mayor, y gana la primera que encaja, sea de permitir o de denegar. Así se usan las NACL de verdad: para bloquear de golpe un rango de IP atacante en toda la subred, algo que un SG no puede hacer porque no tiene reglas de denegar.

🔮 **Predice:** añades una regla 90 que deniega el 80 desde tu IP. ¿Qué gana, la 90 o la 100?

**Pruébalo:**

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 90 \
  --protocol tcp --port-range From=80,To=80 --cidr-block "$MI_IP/32" --rule-action deny
curl -m 5 "http://$IP"
aws ec2 describe-network-acls --network-acl-ids "$NACL" \
  --query 'NetworkAcls[0].Entries[?!Egress] | sort_by(@, &RuleNumber)[].[RuleNumber,RuleAction,PortRange.From,CidrBlock]' --output text
```

Y deja la subred como estaba:

```bash
aws ec2 replace-network-acl-association --association-id "$(asociacion)" --network-acl-id "$NACL_DEF"
aws ec2 delete-network-acl --network-acl-id "$NACL"
curl -s "http://$IP"
```

👀 **Qué deberías ver:** *timeout*: la 90 se evalúa antes que la 100 y gana. La lista ordenada muestra `90 deny`, `100 allow`, `110 allow` y `32767 deny`. Después de devolver la NACL por defecto, la página vuelve. La lección práctica: las NACL por defecto (que lo permiten todo) y unos SG bien hechos cubren casi todos los casos. Si algún día tocas una NACL, recuerda los efímeros **en los dos sentidos**.

✋ **Sin mirar:** quieres bloquear un rango de IP atacante en toda una subred. ¿SG o NACL, y por qué?

<details>
<summary>Comprueba</summary>

NACL: tiene reglas de denegar y se aplica a la subred entera. Un SG solo puede permitir.
</details>

**En resumen:** en una NACL gana la regla de menor número que encaje; sirve para denegar rangos en toda la subred.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws ec2 create-security-group --group-name … --vpc-id … --description …` | crear un SG |
| `aws ec2 authorize-security-group-ingress --group-id … --protocol tcp --port 80 --cidr IP/32` | abrir un puerto a una IP |
| `--ip-permissions "IpProtocol=tcp,FromPort=…,ToPort=…,UserIdGroupPairs=[{GroupId=…}]"` | abrir un puerto a otro SG |
| `aws ec2 describe-security-group-rules --filters Name=group-id,Values=…` | ver las reglas |
| `aws ec2 modify-instance-attribute --instance-id … --groups …` | cambiar los SG de una instancia |
| `aws ssm send-command --document-name AWS-RunShellScript --parameters '{"commands":[…]}'` | una orden sin entrar |
| `aws ec2 create-network-acl` · `create-network-acl-entry --rule-number … --rule-action allow/deny` | NACL y sus reglas |
| `aws ec2 replace-network-acl-association --association-id … --network-acl-id …` | cambiar la NACL de una subred |
| *timeout* → SG, NACL, rutas · *refused* → el servicio | el diagnóstico por el síntoma |

## Rómpelo

**1. Tu IP cambió.** Conéctate desde el móvil (comparte datos al portátil) y repite `curl -m 5 "http://$IP"`. *Timeout*: tu IP de salida ya no es `$MI_IP`. Pasa a menudo con conexiones domésticas que cambian de IP. El arreglo es actualizar la regla, no abrir a `0.0.0.0/0`.

**2. La regla duplicada.**

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_WEB" --protocol tcp --port 80 --cidr "$MI_IP/32"
```

`InvalidPermission.Duplicate`. Los SG no admiten la misma regla dos veces. En los scripts, compruébalo antes o captura el error.

**3. Borrar un SG que otro referencia.**

```bash
aws ec2 delete-security-group --group-id "$SG_WEB"
```

Falla, porque `lab-web` está en uso por una instancia **y** referenciado por la regla de `lab-db`. Por eso `borrar-vpc.sh` vacía las reglas de entrada antes de borrar los SG.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Ver los paquetes descartados con VPC Flow Logs.** Activa los *flow logs* de la subred pública, solo los rechazos, hacia CloudWatch Logs con 1 día de retención, y encuentra el `curl` de CloudShell.

> 🧩 **Ejemplo resuelto:** así se lee una línea de *flow log*:
> ```
> 2 123456789012 eni-0abc… 3.85.12.40 10.20.1.15 51234 80 6 1 60 1761000000 1761000060 REJECT OK
> ```
> versión, cuenta, interfaz, **IP de origen**, IP de destino, puerto de origen (efímero), **puerto de destino**, protocolo (6 = TCP), paquetes, bytes, inicio, fin, **acción** y estado.

**Ahora tú, con huecos:**
```bash
aws logs create-log-group --log-group-name /lab/flow --tags Proyecto=lab
aws logs put-retention-policy --log-group-name /lab/flow --retention-in-days 1
cat > confianza-flow.json <<'EOF'
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow",
  "Principal": {"Service": "vpc-flow-logs.amazonaws.com"}, "Action": "sts:AssumeRole"}]}
EOF
cat > permisos-flow.json <<'EOF'
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow",
  "Action": ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"],
  "Resource": "*"}]}
EOF
aws iam create-role --role-name lab-flow --assume-role-policy-document file://confianza-flow.json --query Role.Arn --output text
aws iam put-role-policy --role-name lab-flow --policy-name escribir-logs --policy-document file://permisos-flow.json
CUENTA=$(aws sts get-caller-identity --query Account --output text)
aws ec2 create-flow-logs --resource-type Subnet --resource-ids "$PUB" --traffic-type ____ \
  --log-group-name /lab/flow --deliver-logs-permission-arn "arn:aws:iam::$CUENTA:role/lab-flow"
```
Lanza el `curl` desde CloudShell, espera unos 10 minutos (los *flow logs* van con retraso) y lee con `aws logs tail /lab/flow --since ____`. Completa: «Veo la IP de origen ____, el puerto de destino ____ y la acción ____».

<details>
<summary>Pista</summary>

Solo los rechazos: `REJECT`. Para el `tail`, `30m` (los últimos 30 minutos). La IP de CloudShell la ves con `curl -s https://checkip.amazonaws.com` desde el propio CloudShell. Al terminar, borra el *flow log* (`aws ec2 delete-flow-logs`; el ID lo da `describe-flow-logs`), el grupo de logs y el rol `lab-flow`: primero `delete-role-policy` y después `delete-role`.
</details>

**2.** **Las reglas de Vigía v3.** Escribe en tus notas el SG que tendrá la EC2 de Vigía (clase 78).

> 🧩 **Ejemplo resuelto:** el SG `lab-web` de la pieza 1: TCP 80 solo desde tu IP `/32`.

**Ahora tú, con huecos:** «Entra: TCP ____ desde ____. No entra: el ____, porque entro con Session Manager, ni nada desde ____. El 5432 de PostgreSQL no aparece porque…».

<details>
<summary>Pista</summary>

En Vigía v2, PostgreSQL corre en un contenedor que no publica su puerto, y la API y el chequeo le hablan por la red interna de Docker (clase 61).
</details>

**3.** Con la NACL personalizada de la pieza 4 puesta en la subred pública, ¿llegaría `lab-web` a `lab-db:8080`? ¿Qué reglas faltarían, y en qué NACL?

> 🧩 **Ejemplo resuelto:** el paso b de la pieza 4: para que tu `curl` funcionara, hizo falta una regla de salida hacia los puertos efímeros de tu IP.

**Ahora tú, con huecos:** «No llegaría. El tráfico entre subredes pasa por ____ NACL. En la de la ____, faltaría la salida hacia `10.20.2.0/24` en el ____ y la entrada de sus respuestas a los puertos ____. En la de la privada no falta nada, porque…».

<details>
<summary>Pista</summary>

Dibuja el camino: el paquete sale de la subred pública (su NACL, salida) y entra en la privada (su NACL, entrada); la respuesta hace el camino inverso. La privada sigue con la NACL por defecto.
</details>

## Destruir al terminar

```bash
cd ~/my-devops-journey/labs/clase-71 && bash borrar-vpc.sh
aws ec2 describe-instances --filters Name=tag:Proyecto,Values=lab \
  Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])'
```

Debe dar `0`. Los laboratorios de red terminan aquí, así que borra también el rol de la clase 72:

```bash
aws iam remove-role-from-instance-profile --instance-profile-name lab-ssm --role-name lab-ssm
aws iam delete-instance-profile --instance-profile-name lab-ssm
aws iam detach-role-policy --role-name lab-ssm --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name lab-ssm
```

## Cierre

En `notas/fase-6/clase-73.md`:

1. Desde tu portátil, `curl` a una instancia da *timeout*; desde dentro de la instancia, `curl localhost` responde. Nombra tres causas posibles, ordenadas por dónde mirarías primero. *(3 líneas, una por causa. Empieza así: «1. El SG: ¿admite ese puerto desde mi IP actual?»)*
2. ¿Qué ventaja tiene usar un SG como origen de una regla en lugar de la IP del servidor web? *(2 líneas. Empieza así: «La regla queda ligada a la identidad (ser miembro del grupo) y no a una dirección, así que…»)*
3. En una NACL personalizada, permitiste la entrada al 80 y el `curl` sigue sin responder. ¿Qué falta y por qué con un SG no faltaría? *(2 líneas. Empieza así: «Falta la regla de salida hacia los puertos efímeros del cliente, porque… Un SG tiene estado:…»)*
4. **Repaso (clase 72, sin mirar):** ¿por qué no se ponen secretos en el *user-data*? *(1–2 líneas. Empieza así: «Porque cualquiera con permiso para describir la instancia…»)*

Después, escríbeme `examíname clase-73`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un *timeout* significa que algo descarta los paquetes o que no hay camino. Por orden:
1. El **SG**: ¿admite ese puerto desde **tu IP actual**?
2. La **NACL** de la subred: ¿permite la entrada **y** la salida a los puertos efímeros?
3. La **tabla de rutas** de la subred: ¿tiene `0.0.0.0/0` hacia el IGW? ¿Y la instancia tiene IP pública?

El servicio funciona (responde en `localhost`), así que el problema está en el camino. Además, comprueba que el servicio escucha en `0.0.0.0` y no solo en `127.0.0.1` (clase 29): eso daría *refused*, no *timeout*.

**2.** La regla queda ligada a la **identidad** (ser miembro del grupo) y no a una dirección. Sigue valiendo si el servidor cambia de IP, si lo recreas o si pones diez detrás de un balanceador con Auto Scaling. Y se lee mejor: "el 8080 solo desde el servidor web".

**3.** Falta la regla de **salida** hacia los puertos efímeros del cliente (`1024-65535`): la respuesta sale del 80 hacia el puerto alto desde el que conectaste. La NACL no tiene estado y trata la respuesta como tráfico nuevo. Un SG sí tiene estado: recuerda la conexión y deja pasar su respuesta sin regla.

**4.** Porque cualquiera con permiso para describir la instancia (`ec2:DescribeInstanceAttribute`) puede leerlo, en texto claro tras decodificar el base64. Los secretos se generan dentro de la instancia o se leen al arrancar de un almacén de secretos (Secrets Manager o Parameter Store), con el rol de la instancia.

**Reto 1:** `--traffic-type REJECT` y `--since 30m`. Verás líneas con la IP de CloudShell como origen, el puerto de destino `80` y `REJECT`.

**Reto 2:** entra el TCP 80 solo desde tu IP `/32`. No entra el 22 (Session Manager) ni nada desde `0.0.0.0/0`. El 5432 no aparece porque PostgreSQL corre en un contenedor que no publica su puerto: la API y el chequeo le hablan por la red interna de Docker (clase 61), sin salir de la instancia.

**Reto 3:** no. El tráfico entre subredes pasa por **las dos** NACL:
- En la **pública**, faltaría la salida hacia `10.20.2.0/24` en el 8080 y la entrada de sus respuestas a los puertos efímeros.
- La **privada** sigue con la NACL por defecto (todo permitido), así que ahí no falta nada.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| security group / network ACL | grupo de seguridad / lista de control de acceso de red |
| stateful / stateless | con estado / sin estado |
| inbound / outbound rule | regla de entrada / de salida |
| ephemeral ports | puertos efímeros |
| connection timed out / connection refused | conexión agotada / rechazada |
| VPC Flow Logs | registros de flujo de la VPC |

🎙️ *"A timeout means something dropped the packet: a security group, a network ACL or a missing route. Connection refused means I reached the host but nothing is listening. Security groups are stateful and can reference other groups; NACLs are stateless, so they need rules for ephemeral ports in both directions."*

## Siguiente

[Clase 74 — S3: buckets, versiones y acceso](clase-74-s3.md)
