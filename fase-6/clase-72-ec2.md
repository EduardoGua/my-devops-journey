# Clase 72 — EC2, user-data y Session Manager

**Dónde:** tu Ubuntu (AWS CLI) + consola · **Tiempo:** 2 bloques (unas 4 h) · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** una **EC2** es una máquina virtual en AWS: eliges su **tipo** (CPU y memoria), su **AMI** (el disco con el sistema) y su red. Se configura sola en el primer arranque con ***user-data***, que es cloud-init, como en tu P2; recibe permisos de un **rol** sin guardar ninguna llave; y entras en ella con **Session Manager**, sin puerto 22. Al final, un NAT Gateway da salida a la subred privada… y se borra el mismo día.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las máquinas virtuales (clase 08) y SSH con llaves (clase 15).
> - cloud-init: `write_files`, `runcmd`, `final_message` y `cloud-init schema` (clase 37, tu P2).
> - Los roles, las credenciales `ASIA…` y la cadena de credenciales (clase 70).
> - Tu VPC y sus scripts `crear-vpc.sh` y `borrar-vpc.sh` (clase 71); el NAT (clase 30).
> - *Refused* frente a *timeout* (clases 26 y 29).

> 🔤 **Palabras nuevas de hoy:**
> - **tipo de instancia**: el tamaño de la máquina, como `t3.micro` (familia, generación, tamaño).
> - **AMI** (*Amazon Machine Image*): la plantilla del disco con el sistema operativo.
> - **EBS** (*Elastic Block Store*): el disco de red de la instancia.
> - ***user-data***: la configuración que cloud-init aplica en el primer arranque.
> - **perfil de instancia**: el envoltorio que mete un rol dentro de una EC2.
> - **IMDS** (servicio de metadatos): la dirección `169.254.169.254`, que solo existe dentro de la instancia.
> - **Session Manager**: entrar en una instancia a través de AWS, sin puertos abiertos ni llaves.
> - **SSRF**: un ataque que engaña a una aplicación para que haga peticiones por el atacante.

## Objetivo

- Elegir un **tipo de instancia** y una **AMI**, y entender qué pagas mientras la instancia está encendida, parada o terminada.
- Lanzar una EC2 con la CLI que se configura sola en el primer arranque con ***user-data*** (cloud-init, como en tu P2).
- Darle permisos con un **rol IAM** a través de un **perfil de instancia**, sin guardar llaves dentro.
- Entrar en ella con **Session Manager**, sin puerto 22, sin llaves SSH y sin IP pública si no hace falta.
- Usar los **metadatos de la instancia** (IMDSv2) y ver de dónde salen las credenciales de su rol.
- Crear un **NAT Gateway**, comprobar que da salida a internet a la subred privada y **borrarlo el mismo día**.

## Por qué importa

EC2 es el servicio más antiguo de AWS y sigue siendo la base de casi todo: Vigía v3 correrá en una. En esta clase se juntan tres piezas que ya conoces:
- **cloud-init:** lo que en la fase 3 hacías con Multipass, aquí lo hace el *user-data*;
- **roles:** la teoría de la clase 70, ahora en una máquina real;
- **la red de la clase 71:** cobra vida.

**Session Manager** cambia la forma de administrar servidores: sin puertos abiertos, sin llaves que perder y con cada sesión registrada. Es lo que se usa hoy en las empresas.

## Costo esperado

> 💰 **Unos 0,15 USD de créditos** si destruyes al terminar:
> - dos t3.micro durante un par de horas (0,0104 USD/h cada una);
> - sus IPv4 públicas (0,005 USD/h);
> - un NAT Gateway durante menos de una hora (0,045 USD/h + 0,045 USD/GB);
> - el disco, céntimos.
>
> ⚠️ El NAT Gateway, olvidado, son 33 USD al mes. Se borra en esta misma sesión.

## Cómo va esta clase

Ocho piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Son dos bloques: el primero, las **piezas 1 a 6** (una EC2 que se configura sola y en la que entras sin puertos); el segundo, las **piezas 7 y 8** (la subred privada y el NAT Gateway), el Rómpelo, el reto, la limpieza y el cierre. Si los haces en días distintos, al terminar el primero ejecuta "Destruir al terminar" y, al empezar el segundo, repite la preparación y las piezas 2 a 4.

**Preparación** (10 min): la red de la clase 71 y sus ID en variables.

```bash
cd ~/my-devops-journey/labs/clase-71 && bash crear-vpc.sh
mkdir -p ~/my-devops-journey/labs/clase-72 && cd ~/my-devops-journey/labs/clase-72
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }
VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'Vpcs[0].VpcId' --output text)
PUB=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-publica --query 'Subnets[0].SubnetId' --output text)
PRIV=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-privada --query 'Subnets[0].SubnetId' --output text)
RT_PRIV=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=lab-rutas-privada --query 'RouteTables[0].RouteTableId' --output text)
echo "$VPC $PUB $PRIV $RT_PRIV"
```

## Las piezas

### Pieza 1 — Los tipos de instancia

`t3.micro` se lee así: familia **t**, generación **3**, tamaño **micro**.

| Familia | Para qué | Ejemplos |
|---------|----------|----------|
| **t** (ráfagas) | uso general con CPU baja la mayor parte del tiempo: webs pequeñas, laboratorios | t3.micro, t3.small, t4g.small |
| **m** (general) | equilibrio entre CPU y memoria | m7i-flex.large |
| **c** (cómputo) | mucha CPU: compilar, codificar vídeo | c7i-flex.large |
| **r** (memoria) | mucha RAM: bases de datos en memoria, cachés | r7i.large |
| **i, d** (almacenamiento) | discos locales muy rápidos | i4i.large |
| **g, p** (aceleradas) | GPU: IA, gráficos | g6.xlarge |

Letras extra: **g** = procesador Graviton (ARM, más barato, como t4g), **a** = AMD, **i** = Intel, ***flex*** = versión más barata con rendimiento casi completo.

Las **t** acumulan **créditos de CPU** cuando están ociosas y los gastan en las ráfagas. Las t3 arrancan en modo ***unlimited***: si mantienes la CPU alta durante mucho tiempo, no se frenan, pero cobran el exceso (0,05 USD por vCPU-hora en Linux). En un laboratorio no pasa. Un proceso desbocado durante días, sí.

En el plan gratuito puedes usar: t3.micro, t3.small, t4g.micro, t4g.small, c7i-flex.large y m7i-flex.large. Hoy, **t3.micro**.

**Pruébalo:**

```bash
aws ec2 describe-instance-types --instance-types t3.micro t3.small t4g.micro \
  --query 'InstanceTypes[].[InstanceType,VCpuInfo.DefaultVCpus,MemoryInfo.SizeInMiB,ProcessorInfo.SupportedArchitectures[0]]' \
  --output table
```

👀 **Qué deberías ver:** `t3.micro` con 2 vCPU y 1024 MiB, `t3.small` con 2 vCPU y 2048 MiB (las dos `x86_64`), y `t4g.micro` con 2 vCPU, 1024 MiB y `arm64`: el procesador Graviton.

✋ **Sin mirar:** ¿qué pasa si una t3 mantiene la CPU al 100 % durante días?

<details>
<summary>Comprueba</summary>

No se frena (modo *unlimited*), pero cobra el exceso: unos 0,05 USD por vCPU-hora.
</details>

**En resumen:** familia + generación + tamaño; las t sirven para cargas a ráfagas, y hoy usas t3.micro.

### Pieza 2 — La AMI, los discos y el ciclo de vida

- **AMI:** la de Ubuntu la publica Canonical, y su ID **cambia** con cada actualización y en cada región. Por eso no se copia de un tutorial: se pide a un **parámetro público de SSM** que siempre apunta a la última:

  ```
  /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id
  ```

- **EBS:** sobrevive a un reinicio y a una parada; por defecto, el disco raíz **se borra al terminar** la instancia; se cobra por GB y mes, aunque la instancia esté parada.
- **Instance store:** discos físicos de algunos tipos de instancia; rapidísimos, pero **se pierden** al parar la instancia.

| Estado | ¿Cobra cómputo? | ¿Cobra disco? | ¿IP pública? |
|--------|-----------------|---------------|--------------|
| `running` | sí | sí | sí (y cobra) |
| `stopped` | no | **sí** | la automática se libera: al arrancar recibes **otra** |
| `terminated` | no | no (el raíz se borra) | no |

🔮 **Predice:** si pides el mismo parámetro con `--region eu-west-1`, ¿saldrá el mismo ID de AMI?

**Pruébalo:**

```bash
AMI=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text)
aws ec2 describe-images --image-ids "$AMI" --query 'Images[0].[ImageId,Name,CreationDate]' --output text
aws ssm get-parameter --region eu-west-1 \
  --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text
```

👀 **Qué deberías ver:** un ID como `ami-0abc…`, un nombre del tipo `ubuntu/images/hvm-ssd-gp3/ubuntu-…-26.04-amd64-server-<fecha>` y su fecha de creación. Y en Irlanda, **otro** ID: cada región tiene su copia de la AMI.

✋ **Sin mirar:** paras una instancia una semana. ¿Qué te sigue cobrando?

<details>
<summary>Comprueba</summary>

El disco EBS, por GB y mes. El cómputo no.
</details>

**En resumen:** la AMI se pide al parámetro de SSM, nunca se copia; EBS cobra aunque la instancia esté parada.

### Pieza 3 — El rol, el perfil de instancia y un security group

Una EC2 no puede "asumir" un rol como tú en la clase 70. El rol se mete en un **perfil de instancia** que se asigna al lanzarla. Para Session Manager, el rol necesita la política `AmazonSSMManagedInstanceCore`.

La instancia también necesita un **security group**, su firewall. Hoy crearás uno **sin reglas de entrada**: nada puede entrar, y para Session Manager no hace falta, porque el agente **sale** hacia AWS. En la clase 73 los verás a fondo.

**Pruébalo:**

```bash
cat > confianza-ec2.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role --role-name lab-ssm --assume-role-policy-document file://confianza-ec2.json \
  --tags Key=Proyecto,Value=lab --query Role.Arn --output text
aws iam attach-role-policy --role-name lab-ssm \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam create-instance-profile --instance-profile-name lab-ssm --tags Key=Proyecto,Value=lab
aws iam add-role-to-instance-profile --instance-profile-name lab-ssm --role-name lab-ssm
aws iam wait instance-profile-exists --instance-profile-name lab-ssm
sleep 10
SG=$(aws ec2 create-security-group --group-name lab-sin-entrada --vpc-id "$VPC" \
  --description "Lab: sin reglas de entrada" \
  --tag-specifications "$(etiquetas security-group lab-sin-entrada)" --query GroupId --output text)
aws ec2 describe-security-groups --group-ids "$SG" \
  --query 'SecurityGroups[0].[length(IpPermissions),IpPermissionsEgress[0].IpRanges[0].CidrIp]' --output text
```

El `sleep` no es un descuido: IAM es global y tarda unos segundos en propagar los cambios. Si lanzas la instancia al instante, puede fallar con `Invalid IAM Instance Profile name`. Es uno de los pocos sitios donde esperar a ciegas es la solución.

👀 **Qué deberías ver:** el ARN del rol, un JSON con el perfil de instancia y, al final, `0	0.0.0.0/0`: cero reglas de entrada y salida a todo internet, que es el valor por defecto.

✋ **Sin mirar:** ¿qué dice la política de confianza de `lab-ssm`, y por qué esa?

<details>
<summary>Comprueba</summary>

Que solo puede asumirlo el servicio `ec2.amazonaws.com`: el rol es para instancias, no para personas.
</details>

**En resumen:** rol (confianza en EC2 + `AmazonSSMManagedInstanceCore`) dentro de un perfil de instancia, y un security group sin entrada.

### Pieza 4 — *user-data*: tu P2, en la nube

El *user-data* es lo que en la clase 37 pasabas a Multipass con `--cloud-init`. AWS se lo da a cloud-init en el **primer arranque**: se ejecuta como root, **una sola vez** y con un límite de 16 KB. Dos avisos:
1. **Nunca pongas secretos en el *user-data*:** cualquiera con permiso para describir la instancia puede leerlo (Rómpelo 3). En Vigía v3, la contraseña de PostgreSQL se **generará dentro** de la instancia.
2. Que la instancia esté `running` no significa que cloud-init haya terminado. Compruébalo con `cloud-init status --wait --long`, como en el P2.

**Pruébalo.** Crea `web.yaml`. Instala nginx y escribe una página con datos que la instancia pide a sus propios metadatos (los verás en la pieza 6):

```yaml
#cloud-config
# Un servidor web mínimo: nginx con una página que dice quién es y dónde está.
package_update: true
packages:
  - nginx
write_files:
  - path: /usr/local/bin/pagina.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      # Pregunta a los metadatos de la instancia (IMDSv2: primero un token)
      TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
      dato() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
      cat > /var/www/html/index.html <<HTML
      <h1>Hola desde $(dato instance-id)</h1>
      <p>Zona: $(dato placement/availability-zone) · IP privada: $(dato local-ipv4)</p>
      HTML
runcmd:
  - [bash, /usr/local/bin/pagina.sh]
final_message: "lab-web lista tras $UPTIME segundos"
```

El script va en `write_files` y no directamente en `runcmd` por el YAML. Una línea de `runcmd` con `-H "X-…: 60"` contiene `: `, y YAML la entendería como un diccionario. Valídalo, lánzalo y prueba la web desde tu Ubuntu:

```bash
cloud-init schema -c web.yaml
ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PUB" --security-group-ids "$SG" \
  --iam-instance-profile Name=lab-ssm \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --user-data file://web.yaml \
  --tag-specifications "$(etiquetas instance lab-web)" "$(etiquetas volume lab-web)" \
  --query 'Instances[0].InstanceId' --output text)
echo "$ID"
aws ec2 wait instance-running --instance-ids "$ID"
aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,PrivateIpAddress,Placement.AvailabilityZone]' --output text
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl -m 5 "http://$IP"
```

Si no tienes `cloud-init` en tu Ubuntu: `sudo apt install cloud-init`. Solo usarás su validador.

🔮 **Predice:** ¿responderá el `curl`?

👀 **Qué deberías ver:** `Valid schema web.yaml`; el ID `i-0…`; `running`, una IP pública, una privada `10.20.1.x` y la zona. Y el `curl` termina en `timeout` a los 5 segundos: tiene IP pública y ruta al IGW, pero el security group no deja **entrar** nada. En la clase 73 sabrás por qué es un *timeout* y no un *connection refused*. Apunta la instancia en tu inventario mientras viva, con la hora.

✋ **Sin mirar:** ¿por qué no pones la contraseña de la base de datos en el *user-data*?

<details>
<summary>Comprueba</summary>

Porque cualquiera con permiso para describir la instancia puede leer el *user-data* entero (Rómpelo 3).
</details>

**En resumen:** `--user-data file://archivo.yaml` = cloud-init en el primer arranque; valida antes, sin secretos dentro.

### Pieza 5 — Session Manager: adiós al puerto 22

| | SSH clásico | Session Manager |
|---|---|---|
| Puerto de entrada | 22 abierto en el security group | **ninguno**: el agente de la instancia sale hacia AWS |
| Credenciales | una llave privada que hay que guardar, rotar y no perder | tu identidad de IAM (con MFA) |
| Registro | lo que configures | cada sesión queda en CloudTrail (y, si quieres, todo lo tecleado) |
| Instancias sin IP pública | hace falta un servidor intermedio | funciona igual, si la subred tiene salida (NAT o endpoints) |

Necesita tres cosas: 1) el **agente de SSM** en la instancia (las AMI de Ubuntu de Canonical lo traen instalado); 2) un **rol** con `AmazonSSMManagedInstanceCore`; 3) **salida** hacia los endpoints de SSM, por internet (IGW o NAT) o con *interface endpoints*. Si falta cualquiera, la instancia no aparece. Además, puede **reenviar un puerto** de la instancia a tu portátil, como un túnel SSH.

**Pruébalo.** Instala el plugin en tu Ubuntu (una vez):

```bash
curl -fsSLo /tmp/session-manager-plugin.deb \
  https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb
sudo dpkg -i /tmp/session-manager-plugin.deb
session-manager-plugin
```

La última orden debe decir que se instaló correctamente. Espera un par de minutos a que la instancia arranque del todo y registre su agente:

```bash
aws ssm describe-instance-information \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformName,PlatformVersion]' --output table
aws ssm start-session --target "$ID"
```

Ya estás dentro, sin puerto 22, sin llave y sin contraseña. Explora:

```bash
whoami
sudo cloud-init status --wait --long
curl -s localhost
ip -4 addr show | grep inet
exit
```

🔮 **Predice** qué dirán `whoami` e `ip addr`.

👀 **Qué deberías ver:** en la tabla, tu instancia con `Online`, `Ubuntu` y `26.04`. Dentro: `ssm-user` (un usuario que crea el agente, con `sudo`); `status: done`; tu página (`<h1>Hola desde i-0…</h1>`); y solo la IP **privada** (`10.20.1.x`). La pública no existe dentro de la máquina: vive en el Internet Gateway, que hace NAT uno a uno (clase 71).

Ahora, la web sin abrir puertos:

```bash
aws ssm start-session --target "$ID" --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'
```

En **otra terminal**: `curl -s localhost:8080`. Tu página, servida por una instancia que no admite ninguna conexión de entrada. Cierra el túnel con `Ctrl+C`.

✋ **Sin mirar:** ¿qué tres cosas necesita una instancia para aparecer en Session Manager?

<details>
<summary>Comprueba</summary>

El agente de SSM, un rol con `AmazonSSMManagedInstanceCore` y salida hacia los endpoints de SSM.
</details>

**En resumen:** `aws ssm start-session --target` para entrar y `AWS-StartPortForwardingSession` para un túnel; ningún puerto abierto.

### Pieza 6 — IMDS: los metadatos y las credenciales del rol

Dentro, los programas piden las credenciales del rol al **servicio de metadatos** (IMDS), en `169.254.169.254`, una dirección que solo existe dentro de la instancia. **IMDSv2** exige primero un **token** con una petición `PUT`, y después lo envía en cada consulta. Así se frenan los ataques **SSRF**, que engañan a una aplicación web para que haga peticiones `GET` a esa dirección y entregue las credenciales. Lánzalas siempre con `HttpTokens=required`, como hiciste en la pieza 4.

En la clase 79 aparecerá un ajuste más de IMDS: el **límite de saltos**.

🔮 **Predice:** ¿por qué letras empezará el `AccessKeyId` del rol?

**Pruébalo**, dentro de `lab-web` (`aws ssm start-session --target "$ID"`):

```bash
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ ; echo
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/lab-ssm | head -c 300; echo
exit
```

👀 **Qué deberías ver:** la lista de metadatos (`ami-id`, `instance-id`, `local-ipv4`, `placement/`, `iam/`…) y un JSON con `"AccessKeyId" : "ASIA…"`, su `Token` y su `Expiration`. Es la teoría de la clase 70 en una máquina real: la instancia recibe credenciales temporales de su rol y AWS las renueva solo. Ningún archivo de llaves en el disco.

✋ **Sin mirar:** ¿qué hace un ataque SSRF, y por qué IMDSv2 lo frena?

<details>
<summary>Comprueba</summary>

Engaña a una aplicación para que haga peticiones `GET` por el atacante, por ejemplo a `169.254.169.254`. IMDSv2 exige antes un token pedido con `PUT`, y un SSRF que solo hace `GET` no lo consigue.
</details>

**En resumen:** IMDS en `169.254.169.254`, con token (IMDSv2); de ahí salen las credenciales `ASIA…` del rol.

> ⏸️ Aquí termina el primer bloque.

### Pieza 7 — Una instancia sin salida

Una instancia en la subred **privada** no recibe IP pública, y su subred no tiene ruta fuera de la VPC (clase 71). Tiene rol y agente, pero el agente necesita **salir** hacia los endpoints de SSM.

🔮 **Predice:** ¿aparecerá en Session Manager?

**Pruébalo:**

```bash
IDP=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PRIV" --security-group-ids "$SG" \
  --iam-instance-profile Name=lab-ssm --metadata-options HttpTokens=required \
  --tag-specifications "$(etiquetas instance lab-privada)" "$(etiquetas volume lab-privada)" \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$IDP"
aws ec2 describe-instances --instance-ids "$IDP" --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' --output text
sleep 180
aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
```

👀 **Qué deberías ver:** `None` como IP pública (la subred privada no las asigna) y una privada `10.20.2.x`. Tras 3 minutos, en la lista de Session Manager solo está `lab-web`: `$IDP` no aparece.

✋ **Sin mirar:** ¿qué le falta exactamente a esta instancia para aparecer?

<details>
<summary>Comprueba</summary>

Salida hacia los endpoints de SSM: su subred no tiene ruta `0.0.0.0/0` hacia ningún NAT Gateway (ni *interface endpoints*).
</details>

**En resumen:** en la privada, sin NAT ni endpoints, el agente no puede salir y la instancia no aparece.

### Pieza 8 — El NAT Gateway: crear, probar y borrar

El NAT Gateway (clase 71) vive en la subred pública, con una IP elástica, y la tabla de rutas privada le manda `0.0.0.0/0`. Desde que se crea, el reloj corre a 0,045 USD/h.

🔮 **Predice:** ¿qué IP verá internet cuando salga la instancia privada?

**Pruébalo:**

```bash
EIP=$(aws ec2 allocate-address --domain vpc \
  --tag-specifications "$(etiquetas elastic-ip lab-nat)" --query AllocationId --output text)
NAT=$(aws ec2 create-nat-gateway --subnet-id "$PUB" --allocation-id "$EIP" \
  --tag-specifications "$(etiquetas natgateway lab-nat)" --query NatGateway.NatGatewayId --output text)
date
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT"
aws ec2 create-route --route-table-id "$RT_PRIV" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT"
aws ec2 reboot-instances --instance-ids "$IDP"
sleep 90
aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
aws ssm start-session --target "$IDP"
```

Apunta la hora del `date`. El agente reintenta solo, pero puede tardar unos minutos: el reinicio lo acelera. Dentro de la instancia privada:

```bash
curl -s https://checkip.amazonaws.com
ip -4 addr show | grep inet
exit
```

Y en tu Ubuntu, la IP elástica del NAT:

```bash
aws ec2 describe-addresses --allocation-ids "$EIP" --query 'Addresses[0].PublicIp' --output text
```

👀 **Qué deberías ver:** `$IDP` ya aparece `Online`; dentro, `checkip` devuelve **la IP elástica del NAT Gateway**, la misma que la última orden, y `ip addr` solo la privada `10.20.2.x`. La instancia sale a internet, pero nadie puede entrar hasta ella: es el modelo de la clase 30.

**Ahora, bórralo:**

```bash
aws ec2 delete-route --route-table-id "$RT_PRIV" --destination-cidr-block 0.0.0.0/0
aws ec2 delete-nat-gateway --nat-gateway-id "$NAT"
aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT"
aws ec2 release-address --allocation-id "$EIP"
date
```

Creado, probado y borrado en la misma sesión. Cuenta los minutos y calcula lo que costó.

✋ **Sin mirar:** ¿por qué hay que liberar la IP elástica después de borrar el NAT Gateway?

<details>
<summary>Comprueba</summary>

Porque la IP elástica es un recurso aparte y sigue cobrando aunque no la use nadie.
</details>

**En resumen:** IP elástica + NAT en la pública + ruta en la privada = salida sin entrada; se crea, se prueba y se borra el mismo día.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id` | la AMI de Ubuntu más reciente |
| `aws iam create-instance-profile` · `add-role-to-instance-profile` | meter un rol en un perfil de instancia |
| `aws ec2 run-instances --image-id … --instance-type … --subnet-id … --security-group-ids … --iam-instance-profile Name=… --metadata-options HttpTokens=required --user-data file://…` | lanzar |
| `aws ec2 wait instance-running` · `stop-instances` · `start-instances` · `terminate-instances` | el ciclo de vida |
| `aws ssm describe-instance-information` · `aws ssm start-session --target …` | Session Manager |
| `--document-name AWS-StartPortForwardingSession --parameters '{…}'` | un túnel a un puerto de la instancia |
| `curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300"` | el token de IMDSv2 |
| `aws ec2 allocate-address` · `create-nat-gateway` · `delete-nat-gateway` · `release-address` | IP elástica y NAT |
| `cloud-init status --wait --long` | ¿terminó el *user-data*? |

## Rómpelo

**1. Una instancia sin rol:**

```bash
SINROL=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PUB" --security-group-ids "$SG" --metadata-options HttpTokens=required \
  --tag-specifications "$(etiquetas instance lab-sin-rol)" --query 'Instances[0].InstanceId' --output text)
```

Espera 5 minutos y búscala en `describe-instance-information`. No aparece: sin rol, el agente no tiene credenciales para registrarse.

Es el "mi instancia no sale en Session Manager" más común. Los otros dos culpables son la falta de salida a internet (pieza 7) y la falta del agente.

Termínala: `aws ec2 terminate-instances --instance-ids "$SINROL"`.

**2. IMDSv1, rechazado.** Dentro de `lab-web` (`aws ssm start-session --target "$ID"`):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://169.254.169.254/latest/meta-data/
```

`401`: sin token no hay respuesta, gracias a `HttpTokens=required`. Una aplicación vulnerable a SSRF que solo puede hacer `GET` no puede robar las credenciales del rol.

**3. Tu *user-data* lo puede leer cualquiera con permisos:**

```bash
aws ec2 describe-instance-attribute --instance-id "$ID" --attribute userData \
  --query UserData.Value --output text | base64 -d
```

Ahí está tu `web.yaml` entero. Por eso no se ponen secretos en el *user-data*.

**4. Parar no es terminar:**

```bash
aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
aws ec2 stop-instances --instance-ids "$ID"
aws ec2 wait instance-stopped --instance-ids "$ID"
aws ec2 start-instances --instance-ids "$ID"
aws ec2 wait instance-running --instance-ids "$ID"
aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

La IP pública **cambió**: la automática se libera al parar. Mientras estuvo parada, el disco siguió cobrando. Si necesitas una IP fija, usa una IP elástica, que cobra siempre, también con la instancia parada.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Tu P2 en AWS.** Lanza una instancia con el `cloud-init.yaml` de tu P2 como *user-data* y compruébalo desde dentro, como en tu `verify.sh`.

> 🧩 **Ejemplo resuelto:** la pieza 4: `--user-data file://web.yaml` y, dentro, `sudo cloud-init status --wait --long`.

**Ahora tú, con huecos:**
```bash
sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/lab_ed25519.pub)|" \
  ~/my-devops-journey/projects/p2-cloud-init-server/cloud-init.yaml > /tmp/p2.yaml
ID2=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PUB" --security-group-ids "$SG" --iam-instance-profile Name=lab-ssm \
  --metadata-options HttpTokens=required --user-data file://____ \
  --tag-specifications "$(etiquetas instance lab-p2)" --query 'Instances[0].InstanceId' --output text)
aws ssm start-session --target "$ID2"
```
Dentro: `sudo cloud-init status --wait`, `systemctl is-active nginx fail2ban`, `sudo ufw status` y `curl -s localhost/health`. Completa: «En AWS sobra ____, porque el firewall de fuera ya es…. Sigue teniendo sentido ____, porque…».

<details>
<summary>Pista</summary>

La llave pública la pones aunque no la uses: no hay puerto 22 abierto. Piensa en qué protegía `fail2ban` en tu P2, y en la defensa en profundidad de la clase 71.
</details>

**2.** Lanza una **t4g.micro** (ARM, Graviton) y comprueba su arquitectura.

> 🧩 **Ejemplo resuelto:** el parámetro de la AMI de la pieza 2, con `amd64`, y la tabla de la pieza 1, donde `t4g.micro` es `arm64`.

**Ahora tú, con huecos:**
```bash
AMI_ARM=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/26.04/stable/current/____/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text)
ARM=$(aws ec2 run-instances --image-id "$AMI_ARM" --instance-type ____ \
  --subnet-id "$PUB" --security-group-ids "$SG" --iam-instance-profile Name=lab-ssm \
  --metadata-options HttpTokens=required \
  --tag-specifications "$(etiquetas instance lab-arm)" --query 'Instances[0].InstanceId' --output text)
```
Entra con Session Manager y ejecuta `uname -m`. Completa: «Dice ____».

<details>
<summary>Pista</summary>

Una AMI de `amd64` no arranca en un procesador ARM: el tipo de instancia y la arquitectura de la AMI tienen que coincidir.
</details>

**3.** Mira el arranque de una instancia sin entrar en ella.

> 🧩 **Ejemplo resuelto:** la línea `final_message: "lab-web lista tras $UPTIME segundos"` de `web.yaml`.

**Ahora tú, con huecos:**
```bash
aws ec2 get-console-output --instance-id "$ID" --latest --output text | grep "____"
```
Completa: «`lab-web` estuvo lista tras ____ segundos». Lo mismo se ve en la consola: la instancia → **Actions → Monitor and troubleshoot → Get system log**.

<details>
<summary>Pista</summary>

Busca el principio del `final_message`. Es tu forma de ver el arranque cuando ni Session Manager funciona.
</details>

## Destruir al terminar

`borrar-vpc.sh` termina las instancias de la VPC y borra todo lo demás, incluido el NAT y la IP elástica si te los dejaste:

```bash
cd ~/my-devops-journey/labs/clase-71 && bash borrar-vpc.sh
aws ec2 describe-instances --filters Name=tag:Proyecto,Values=lab \
  Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])'
aws ec2 describe-addresses --query 'length(Addresses)'
aws ec2 describe-nat-gateways --filter Name=state,Values=pending,available --query 'length(NatGateways)'
```

Las tres comprobaciones deben dar `0`. El rol y el perfil de instancia `lab-ssm` no cuestan nada: **déjalos** para la clase 73. Borra la entrada de la instancia de tu inventario.

## Cierre

En `notas/fase-6/clase-72.md`:

1. ¿Qué tres cosas necesita una instancia para aparecer en Session Manager? *(1–2 líneas. Empieza así: «El agente de SSM, un rol con… y salida hacia…»)*
2. ¿De dónde saca la EC2 las credenciales de su rol, y por qué `HttpTokens=required` la protege? *(2–3 líneas. Empieza así: «Del servicio de metadatos (IMDS, en 169.254.169.254), donde AWS… Con `HttpTokens=required`, solo responde a quien…»)*
3. ¿Qué diferencia hay, en dinero y en datos, entre parar y terminar una instancia? *(2 líneas. Empieza así: «Parada: no paga cómputo, pero sí… Terminada:…»)*
4. **Repaso (clase 71, sin mirar):** ¿qué hace pública a una subred? *(1 línea. Empieza así: «Su tabla de rutas:…»)*

Después, escríbeme `examíname clase-72`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El **agente** de SSM instalado y en marcha (las AMI de Ubuntu lo traen), un **rol** con `AmazonSSMManagedInstanceCore` en su perfil de instancia y **salida** hacia los endpoints de SSM: por un IGW con IP pública, por un NAT Gateway o con *interface endpoints*.

**2.** Del **servicio de metadatos** (IMDS, en `169.254.169.254`). AWS publica allí unas credenciales temporales del rol y las renueva antes de que caduquen; boto3 y la CLI las encuentran solos. Con `HttpTokens=required`, solo responde a quien primero pide un token con un `PUT` y lo envía en cada consulta. Un atacante que engaña a una aplicación para que haga peticiones `GET` (SSRF) no consigue las credenciales.

**3.** **Parada:** no paga cómputo, pero sí el disco EBS, que conserva los datos. Al arrancar recibe otra IP pública. **Terminada:** deja de existir y deja de cobrar; el disco raíz se borra con ella (salvo que cambies `DeleteOnTermination`), y sus datos también.

**4.** Su tabla de rutas: una ruta `0.0.0.0/0` hacia un Internet Gateway conectado a la VPC.

**Reto 1:** `file:///tmp/p2.yaml`. Sobra sobre todo lo del SSH: el puerto 22, el usuario `deploy` con llave y `fail2ban`, que protegía el SSH; el firewall de fuera es ahora el security group. Sigue teniendo sentido `ufw` como segunda capa (defensa en profundidad), igual que las actualizaciones automáticas y el *health check* de nginx.

**Reto 2:** `arm64` y `t4g.micro`; `uname -m` dice `aarch64`.

**Reto 3:** `grep "lab-web lista tras"`; el número de segundos depende del arranque, normalmente entre 60 y 120.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| instance type / AMI | tipo de instancia / imagen de máquina |
| EBS volume / instance store | volumen EBS / almacenamiento local de la instancia |
| user data | datos de usuario (la configuración del primer arranque) |
| instance profile | perfil de instancia |
| instance metadata service (IMDS) | servicio de metadatos de la instancia |
| Session Manager / port forwarding | Session Manager / reenvío de puertos |

🎙️ *"My instances have no port 22 open and no SSH keys. They get permissions from an IAM role through an instance profile, IMDSv2 is enforced, and I connect with Session Manager, even to instances in private subnets behind a NAT gateway."*

## Siguiente

[Clase 73 — Security groups y NACLs](clase-73-security-groups-y-nacls.md)
