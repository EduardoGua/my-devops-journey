# Clase 72 — EC2, user-data y Session Manager

**Dónde:** tu Ubuntu (AWS CLI) + consola · **Tiempo:** 2 bloques (unas 4 h) · **Bloque:** B. Los servicios básicos

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

## Teoría

### Tipos de instancia

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

### AMI, discos y ciclo de vida

- **AMI** (*Amazon Machine Image*): la plantilla del disco con el sistema operativo. La de Ubuntu la publica Canonical, y su ID **cambia** con cada actualización y en cada región. Por eso no se copia de un tutorial: se pide a un **parámetro público de SSM** que siempre apunta a la última:

  ```
  /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id
  ```

- **EBS** (*Elastic Block Store*): el disco de red de la instancia.
  - Sobrevive a un reinicio y a una parada.
  - Por defecto, el disco raíz **se borra al terminar** la instancia.
  - Se cobra por GB y mes, aunque la instancia esté parada.
- **Instance store:** discos físicos de algunos tipos de instancia; rapidísimos, pero **se pierden** al parar la instancia.

| Estado | ¿Cobra cómputo? | ¿Cobra disco? | ¿IP pública? |
|--------|-----------------|---------------|--------------|
| `running` | sí | sí | sí (y cobra) |
| `stopped` | no | **sí** | la automática se libera: al arrancar recibes **otra** |
| `terminated` | no | no (el raíz se borra) | no |

### *user-data*: tu P2, en la nube

El *user-data* es lo que en la clase 37 pasabas a Multipass con `--cloud-init`. AWS se lo da a cloud-init en el **primer arranque**:
- se ejecuta como root;
- se ejecuta **una sola vez**;
- tiene un límite de 16 KB.

Dos avisos:
1. **Nunca pongas secretos en el *user-data*:** cualquiera con permiso para describir la instancia puede leerlo (Rómpelo 3). En Vigía v3, la contraseña de PostgreSQL se **generará dentro** de la instancia.
2. Que la instancia esté `running` no significa que cloud-init haya terminado. Compruébalo con `cloud-init status --wait --long`, como en el P2.

### Session Manager: adiós al puerto 22

| | SSH clásico | Session Manager |
|---|---|---|
| Puerto de entrada | 22 abierto en el security group | **ninguno**: el agente de la instancia sale hacia AWS |
| Credenciales | una llave privada que hay que guardar, rotar y no perder | tu identidad de IAM (con MFA) |
| Registro | lo que configures | cada sesión queda en CloudTrail (y, si quieres, todo lo tecleado) |
| Instancias sin IP pública | hace falta un servidor intermedio | funciona igual, si la subred tiene salida (NAT o endpoints) |

Necesita tres cosas:
1. El **agente de SSM** en la instancia. Las AMI de Ubuntu de Canonical lo traen instalado.
2. Un **rol** con la política `AmazonSSMManagedInstanceCore`.
3. **Salida** hacia los endpoints de SSM: por internet (IGW o NAT) o con *interface endpoints*.

Si falta cualquiera, la instancia no aparece.

### Perfil de instancia e IMDS

Una EC2 no puede "asumir" un rol como tú en la clase 70. El rol se mete en un **perfil de instancia** (*instance profile*) que se asigna al lanzarla. Dentro, los programas piden las credenciales al **servicio de metadatos** (IMDS), en `169.254.169.254`, una dirección que solo existe dentro de la instancia.

**IMDSv2** exige primero un **token** con una petición `PUT`, y después lo envía en cada consulta. Así se frenan los ataques SSRF, que engañan a una aplicación web para que haga peticiones `GET` a esa dirección y entregue las credenciales. Lánzalas siempre con `HttpTokens=required`.

En la clase 79 aparecerá un ajuste más de IMDS: el **límite de saltos**.

## Práctica guiada

### Bloque 1 · Una EC2 que se configura sola

#### 1. La red y las variables (10 min)

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

#### 2. El rol de la instancia (15 min)

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
```

El `sleep` no es un descuido: IAM es global y tarda unos segundos en propagar los cambios. Si lanzas la instancia al instante, puede fallar con `Invalid IAM Instance Profile name`. Es uno de los pocos sitios donde esperar a ciegas es la solución.

#### 3. Un security group sin entrada (5 min)

```bash
SG=$(aws ec2 create-security-group --group-name lab-sin-entrada --vpc-id "$VPC" \
  --description "Lab: sin reglas de entrada" \
  --tag-specifications "$(etiquetas security-group lab-sin-entrada)" --query GroupId --output text)
aws ec2 describe-security-groups --group-ids "$SG" \
  --query 'SecurityGroups[0].[length(IpPermissions),IpPermissionsEgress[0].IpRanges[0].CidrIp]' --output text
```

`0` reglas de entrada y salida a `0.0.0.0/0`, que es el valor por defecto. Nada puede entrar, y para Session Manager no hace falta: el agente **sale**. En la clase 73 verás los security groups a fondo.

#### 4. La AMI y el *user-data* (15 min)

```bash
AMI=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text)
aws ec2 describe-images --image-ids "$AMI" --query 'Images[0].[ImageId,Name,CreationDate]' --output text
```

🔮 **Predice:** si haces lo mismo con `--region eu-west-1`, ¿saldrá el mismo ID? No: cada región tiene su copia de la AMI, con su propio ID.

Crea `web.yaml`. Instala nginx y escribe una página con datos que la instancia pide a sus propios metadatos:

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

El script va en `write_files` y no directamente en `runcmd` por el YAML. Una línea de `runcmd` con `-H "X-…: 60"` contiene `: `, y YAML la entendería como un diccionario. Valídalo antes de lanzar, como en el P2:

```bash
cloud-init schema -c web.yaml
```

Si no tienes `cloud-init` en tu Ubuntu: `sudo apt install cloud-init`. Solo usarás su validador.

#### 5. Lanzar (15 min)

```bash
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
```

Apúntala en tu inventario mientras viva, con la hora. Y desde tu Ubuntu, prueba la web:

```bash
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl -m 5 "http://$IP"
```

🔮 **Predice:** ¿responderá? No. Tiene IP pública y ruta al IGW, pero el security group no deja **entrar** nada. Te quedas con un `timeout`, y en la clase 73 sabrás por qué es un *timeout* y no un *connection refused*.

#### 6. Session Manager (25 min)

Instala el plugin en tu Ubuntu (una vez):

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
```

🔮 **Predice:**
- **`whoami`:** `ssm-user`, un usuario que crea el agente, con `sudo`.
- **`ip addr`:** solo la IP **privada** (`10.20.1.x`). La pública no existe dentro de la máquina: vive en el Internet Gateway, que hace NAT uno a uno (clase 71).

Ahora, los metadatos y las credenciales del rol:

```bash
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ ; echo
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/lab-ssm | head -c 300; echo
```

Ahí está la magia de la clase 70: un `AccessKeyId` que empieza por **`ASIA`**, con su `Token` y su `Expiration`. La instancia recibe credenciales temporales de su rol y AWS las renueva solo. Ningún archivo de llaves en el disco. Sal con `exit`.

#### 7. Ver la web sin abrir puertos (10 min)

Session Manager puede reenviar un puerto de la instancia a tu portátil, como un túnel SSH:

```bash
aws ssm start-session --target "$ID" --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'
```

En **otra terminal**: `curl -s localhost:8080`. Tu página, servida por una instancia que no admite ninguna conexión de entrada. Cierra el túnel con `Ctrl+C`.

### Bloque 2 · La subred privada y el NAT Gateway

#### 8. Una instancia sin salida (15 min)

Lanza otra instancia, esta vez en la subred **privada**:

```bash
IDP=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PRIV" --security-group-ids "$SG" \
  --iam-instance-profile Name=lab-ssm --metadata-options HttpTokens=required \
  --tag-specifications "$(etiquetas instance lab-privada)" "$(etiquetas volume lab-privada)" \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$IDP"
aws ec2 describe-instances --instance-ids "$IDP" --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' --output text
```

`None` como IP pública, porque la subred privada no las asigna. Espera 3 minutos y busca su agente:

```bash
aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
```

🔮 **Predice:** ¿aparece `$IDP`? No. Tiene rol y agente, pero el agente necesita **salir** hacia los endpoints de SSM, y la subred privada no tiene ruta a ningún sitio fuera de la VPC.

#### 9. El NAT Gateway: crear, probar y borrar (35 min)

```bash
EIP=$(aws ec2 allocate-address --domain vpc \
  --tag-specifications "$(etiquetas elastic-ip lab-nat)" --query AllocationId --output text)
NAT=$(aws ec2 create-nat-gateway --subnet-id "$PUB" --allocation-id "$EIP" \
  --tag-specifications "$(etiquetas natgateway lab-nat)" --query NatGateway.NatGatewayId --output text)
date
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT"
aws ec2 create-route --route-table-id "$RT_PRIV" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT"
```

Desde el `date`, el reloj corre a 0,045 USD/h. Apunta la hora.

El agente reintenta solo, pero puede tardar unos minutos. Para no esperar, reinicia la instancia:

```bash
aws ec2 reboot-instances --instance-ids "$IDP"
sleep 90
aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
aws ssm start-session --target "$IDP"
```

Dentro de la instancia privada:

```bash
curl -s https://checkip.amazonaws.com
ip -4 addr show | grep inet
exit
```

Compara con la IP elástica del NAT:

```bash
aws ec2 describe-addresses --allocation-ids "$EIP" --query 'Addresses[0].PublicIp' --output text
```

🔮 **Predice:** ¿qué IP ve internet cuando sale la instancia privada? La **IP elástica del NAT Gateway**, no una suya. La instancia sale a internet, pero nadie puede entrar hasta ella: es el modelo de la clase 30.

**Ahora, bórralo:**

```bash
aws ec2 delete-route --route-table-id "$RT_PRIV" --destination-cidr-block 0.0.0.0/0
aws ec2 delete-nat-gateway --nat-gateway-id "$NAT"
aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT"
aws ec2 release-address --allocation-id "$EIP"
date
```

Creado, probado y borrado en la misma sesión. Cuenta los minutos y calcula lo que costó.

## Rómpelo

**1. Una instancia sin rol:**

```bash
SINROL=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --subnet-id "$PUB" --security-group-ids "$SG" --metadata-options HttpTokens=required \
  --tag-specifications "$(etiquetas instance lab-sin-rol)" --query 'Instances[0].InstanceId' --output text)
```

Espera 5 minutos y búscala en `describe-instance-information`. No aparece: sin rol, el agente no tiene credenciales para registrarse.

Es el "mi instancia no sale en Session Manager" más común. Los otros dos culpables son la falta de salida a internet (paso 8) y la falta del agente.

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

1. **Tu P2 en AWS.** Lanza una instancia con el `cloud-init.yaml` de tu P2 como *user-data*.
   - Sustituye `__SSH_PUBKEY__` por tu llave pública, aunque no la usarás: no hay puerto 22.
   - Entra con Session Manager y comprueba como en tu `verify.sh`, pero desde dentro: `systemctl is-active nginx fail2ban`, `sudo ufw status` y `curl -s localhost/health`.

   ¿Qué partes del P2 sobran en AWS (pista: el firewall de fuera ya es el security group)? ¿Cuáles siguen teniendo sentido (defensa en profundidad)?
2. Lanza una **t4g.micro** (ARM, Graviton). ¿Qué cambia en el parámetro de la AMI? Pista: `amd64` → `arm64`. Entra y ejecuta `uname -m`.
3. En la consola, abre la instancia → **Actions → Monitor and troubleshoot → Get system log**. Busca el `final_message` de cloud-init. Es tu forma de ver el arranque cuando ni Session Manager funciona.

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

1. ¿Qué tres cosas necesita una instancia para aparecer en Session Manager?
2. ¿De dónde saca la EC2 las credenciales de su rol, y por qué `HttpTokens=required` la protege?
3. ¿Qué diferencia hay, en dinero y en datos, entre parar y terminar una instancia?
4. **Repaso (clase 71, sin mirar):** ¿qué hace pública a una subred?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El **agente** de SSM instalado y en marcha (las AMI de Ubuntu lo traen), un **rol** con `AmazonSSMManagedInstanceCore` en su perfil de instancia y **salida** hacia los endpoints de SSM: por un IGW con IP pública, por un NAT Gateway o con *interface endpoints*.

**2.** Del **servicio de metadatos** (IMDS, en `169.254.169.254`). AWS publica allí unas credenciales temporales del rol y las renueva antes de que caduquen; boto3 y la CLI las encuentran solos. Con `HttpTokens=required`, solo responde a quien primero pide un token con un `PUT` y lo envía en cada consulta. Un atacante que engaña a una aplicación para que haga peticiones `GET` (SSRF) no consigue las credenciales.

**3.** **Parada:** no paga cómputo, pero sí el disco EBS, que conserva los datos. Al arrancar recibe otra IP pública. **Terminada:** deja de existir y deja de cobrar; el disco raíz se borra con ella (salvo que cambies `DeleteOnTermination`), y sus datos también.

**4.** Su tabla de rutas: una ruta `0.0.0.0/0` hacia un Internet Gateway conectado a la VPC.

**Reto 1:** sobra sobre todo el SSH: el puerto 22, el usuario `deploy` con llave y `fail2ban`, que protegía el SSH. El firewall de fuera es ahora el security group. Sigue teniendo sentido `ufw` como segunda capa (defensa en profundidad), igual que las actualizaciones automáticas y el *health check* de nginx.
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
