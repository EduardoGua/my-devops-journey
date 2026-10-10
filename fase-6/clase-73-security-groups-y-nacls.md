# Clase 73 — Security groups y NACLs

**Dónde:** tu Ubuntu (AWS CLI) + CloudShell · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

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

## Teoría

### Repaso de la clase 33, en una tabla

| | Security group (SG) | Network ACL (NACL) |
|-|---------------------|--------------------|
| Se aplica a | cada interfaz de red (una EC2, una base de datos de RDS, un balanceador) | la **subred** entera |
| Estado | **con estado**: las respuestas pasan solas | **sin estado**: cada sentido necesita su regla |
| Reglas | solo **permitir** | **permitir y denegar**, numeradas: gana la de **menor número** que encaje |
| Por defecto | uno nuevo: nada entra, todo sale | la NACL por defecto de la VPC permite todo; **una nueva lo deniega todo** |
| Origen | un CIDR, **otro SG** o una *prefix list* | solo CIDR |

Los dos **descartan en silencio**, así que una regla que falta se ve como *timeout* (clase 33).

### SG que referencian a SG

Una regla con **otro security group como origen** significa "cualquier interfaz que tenga ese SG puesto". Si mañana el servidor web cambia de IP, o pasas a tener diez detrás de un balanceador, la regla sigue valiendo: la identidad es el **grupo**, no la dirección.

```
internet ──80 (solo mi IP)──► [ SG lab-web ]  lab-web  ──8080──►  [ SG lab-db ]  lab-db
                                                                   origen: SG lab-web
```

Cada VPC trae un SG llamado **`default`**: permite todo el tráfico entre las interfaces que lo llevan. Una instancia lanzada sin indicar SG recibe ese. La buena práctica es no usarlo: crea SG con nombre y propósito.

### Puertos efímeros y NACL

Cuando tu portátil abre una conexión al puerto 80, lo hace **desde** un puerto alto al azar: el puerto **efímero** (clase 29). La respuesta del servidor va **hacia** ese puerto. Un SG lo recuerda y deja pasar la respuesta; una NACL no recuerda nada. Por eso, en una NACL personalizada:
- la **salida** necesita una regla para `1024-65535` hacia los clientes, o las respuestas mueren;
- la **entrada** necesita otra regla para `1024-65535`, o mueren las respuestas a las conexiones que **inicia** la instancia (`apt`, el agente de SSM…).

### Diagnóstico por el síntoma

| Lo que ves | Qué significa | Dónde mirar |
|------------|---------------|-------------|
| ***timeout*** | algo **descartó** el paquete por el camino, o no hay camino | SG, NACL, tabla de rutas, IP pública, que la instancia esté encendida |
| ***connection refused*** | **llegaste** a la máquina, pero nadie escucha en ese puerto | el servicio: `systemctl status`, `ss -tlnp` (clases 12 y 29) |
| **respuesta HTTP con error** (502, 404…) | la red está bien; el problema es la aplicación | los logs de la aplicación |

Un *refused* es una buena noticia para la red: toda la cadena de reglas funcionó.

## Práctica guiada

Necesitas la red de la clase 71 y el rol `lab-ssm` de la 72:

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

### 1. El servidor web, abierto solo a ti (15 min)

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
```

`instance-status-ok` espera a que la instancia pase sus comprobaciones de estado: unos 2 o 3 minutos más que `instance-running`, lo justo para que cloud-init instale nginx. Si `curl` no responde todavía, espera un minuto.

Ahora prueba desde **otra IP**: abre **CloudShell** y lanza:

```bash
curl -m 5 http://<la IP de lab-web>
```

🔮 **Predice:** ¿qué verá CloudShell? Un *timeout*: su IP es de AWS, no la tuya, y la regla solo admite `$MI_IP/32`. El SG descarta en silencio.

### 2. *Timeout* frente a *refused* (10 min)

Para nginx con una orden remota de SSM, sin abrir sesión:

```bash
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["systemctl stop nginx"]}' --query Command.CommandId --output text
sleep 5
curl -m 5 "http://$IP"
```

🔮 **Predice:** ¿*timeout* o *refused*? *Connection refused*. El SG te deja pasar, el paquete llega a la instancia, y su kernel responde "aquí no escucha nadie". Compáralo con CloudShell, que sigue viendo *timeout*: el mismo puerto, dos síntomas distintos, dos causas distintas.

Vuelve a arrancarlo:

```bash
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["systemctl start nginx"]}' --query Command.CommandId --output text
```

`send-command` es la otra cara de Session Manager: ejecutar órdenes en una o cien instancias sin entrar en ninguna. En la fase 7 desplegarás así desde GitHub Actions.

### 3. La "base de datos", solo para el servidor web (25 min)

Una segunda instancia en la subred **privada** hará de base de datos. Para no instalar PostgreSQL, sirve una página en el puerto 8080 con el servidor web de Python. Crea `db.yaml`:

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

La regla no tiene CIDR: tiene un SG. Prueba desde `lab-web`:

```bash
aws ssm start-session --target "$ID"
```

Dentro:

```bash
curl -m 5 http://<DB_IP>:8080
exit
```

Responde: `lab-web` lleva el SG `lab-web`, y eso basta. Ahora quítale ese SG a `lab-web` y ponle el `default` de la VPC:

```bash
SG_DEF=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" Name=group-name,Values=default \
  --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 modify-instance-attribute --instance-id "$ID" --groups "$SG_DEF"
aws ssm start-session --target "$ID"
```

Repite el `curl` dentro.

🔮 **Predice:**
- **El `curl` hacia `lab-db`:** *timeout*. La máquina es la misma, con la misma IP, pero ya no es "miembro" de `lab-web`.
- **Session Manager:** sigue funcionando, porque la sesión **sale** de la instancia, y los SG no filtran la salida por defecto.

Devuélvele su SG:

```bash
aws ec2 modify-instance-attribute --instance-id "$ID" --groups "$SG_WEB"
```

### 4. Una NACL sin estado (30 min)

Las NACL nuevas lo deniegan todo. Crea una y míralo:

```bash
NACL=$(aws ec2 create-network-acl --vpc-id "$VPC" \
  --tag-specifications "$(etiquetas network-acl lab-nacl-publica)" --query NetworkAcl.NetworkAclId --output text)
aws ec2 describe-network-acls --network-acl-ids "$NACL" \
  --query 'NetworkAcls[0].Entries[].[Egress,RuleNumber,RuleAction,CidrBlock]' --output table
```

Solo la regla `*` (32767) que deniega todo, en los dos sentidos. Guarda la NACL actual de la subred pública y cámbiala por la nueva:

```bash
NACL_DEF=$(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$PUB" \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
asociacion() { aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$PUB" \
  --query "NetworkAcls[0].Associations[?SubnetId=='$PUB'].NetworkAclAssociationId" --output text; }
aws ec2 replace-network-acl-association --association-id "$(asociacion)" --network-acl-id "$NACL"
curl -m 5 "http://$IP"
```

*Timeout*: la subred entera está sellada. Ahora, paso a paso.

**a)** Deja entrar el 80 desde tu IP:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 100 \
  --protocol tcp --port-range From=80,To=80 --cidr-block "$MI_IP/32" --rule-action allow
curl -m 5 "http://$IP"
```

🔮 **Predice:** ¿funciona ya? No. La petición **entra**, pero la respuesta, que va del puerto 80 a tu puerto efímero, no tiene regla de **salida**. Sin estado, cada sentido es un mundo.

**b)** Deja salir las respuestas hacia tus puertos efímeros:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --egress --rule-number 100 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block "$MI_IP/32" --rule-action allow
curl -m 5 "http://$IP"
```

Funciona.

**c)** Pero Session Manager está muerto: `aws ssm start-session --target "$ID"` no conecta. El agente **inicia** conexiones HTTPS hacia AWS, y la NACL no las deja salir ni deja volver sus respuestas:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --egress --rule-number 110 \
  --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 110 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow
```

En un minuto o dos, Session Manager vuelve.

**d)** El orden importa. Una regla de denegar con un número **menor**:

```bash
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 90 \
  --protocol tcp --port-range From=80,To=80 --cidr-block "$MI_IP/32" --rule-action deny
curl -m 5 "http://$IP"
aws ec2 describe-network-acls --network-acl-ids "$NACL" \
  --query 'NetworkAcls[0].Entries[?!Egress] | sort_by(@, &RuleNumber)[].[RuleNumber,RuleAction,PortRange.From,CidrBlock]' --output text
```

*Timeout*: la 90 se evalúa antes que la 100 y gana. Así se usan las NACL de verdad: para bloquear de golpe un rango de IP atacante en toda la subred, algo que un SG no puede hacer porque no tiene reglas de denegar.

**e)** Deja la subred como estaba:

```bash
aws ec2 replace-network-acl-association --association-id "$(asociacion)" --network-acl-id "$NACL_DEF"
aws ec2 delete-network-acl --network-acl-id "$NACL"
curl -s "http://$IP"
```

La lección práctica: las NACL por defecto (que lo permiten todo) y unos SG bien hechos cubren casi todos los casos. Si algún día tocas una NACL, recuerda los efímeros **en los dos sentidos**.

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

1. **Ver los paquetes descartados con VPC Flow Logs.** Activa los *flow logs* de la subred pública, solo los rechazos, hacia CloudWatch Logs con 1 día de retención:

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
   aws ec2 create-flow-logs --resource-type Subnet --resource-ids "$PUB" --traffic-type REJECT \
     --log-group-name /lab/flow --deliver-logs-permission-arn "arn:aws:iam::$CUENTA:role/lab-flow"
   ```

   Lanza el `curl` desde CloudShell, espera unos 10 minutos (los *flow logs* van con retraso) y lee: `aws logs tail /lab/flow --since 30m`. ¿Encuentras la IP de CloudShell, el puerto 80 y `REJECT`?

   Al terminar, borra el *flow log* (`aws ec2 delete-flow-logs`; el ID lo da `describe-flow-logs`), el grupo de logs y el rol `lab-flow`: primero `delete-role-policy` y después `delete-role`.
2. **Las reglas de Vigía v3.** Escribe en tus notas el SG que tendrá la EC2 de Vigía (clase 78): qué entra, desde dónde y qué no entra. ¿Por qué el puerto 5432 de PostgreSQL no aparece en ninguna regla, si la base de datos corre en la misma instancia? Pista: clase 61.
3. Con la NACL personalizada del paso 4 puesta en la subred pública, ¿llegaría `lab-web` a `lab-db:8080`? ¿Qué reglas faltarían, y en qué NACL?

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

1. Desde tu portátil, `curl` a una instancia da *timeout*; desde dentro de la instancia, `curl localhost` responde. Nombra tres causas posibles, ordenadas por dónde mirarías primero.
2. ¿Qué ventaja tiene usar un SG como origen de una regla en lugar de la IP del servidor web?
3. En una NACL personalizada, permitiste la entrada al 80 y el `curl` sigue sin responder. ¿Qué falta y por qué con un SG no faltaría?
4. **Repaso (clase 72, sin mirar):** ¿por qué no se ponen secretos en el *user-data*?

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

**Reto 2:** entra el TCP 80 solo desde tu IP `/32`. No entra el 22 (Session Manager) ni nada abierto a `0.0.0.0/0`. El 5432 no aparece porque PostgreSQL corre en un contenedor que no publica su puerto: la API y el chequeo le hablan por la red interna de Docker (clase 61), sin salir de la instancia.

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
