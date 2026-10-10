# Clase 71 — VPC desde cero

**Dónde:** tu Ubuntu (AWS CLI) + consola · **Tiempo:** 2 bloques (unas 3 h) · **Bloque:** B. Los servicios básicos

## Objetivo

- Diseñar el direccionamiento de una VPC (el rango y las subredes) con lo que aprendiste en la fase 3.
- Crear con la CLI una VPC con una subred **pública** y otra **privada**, un **Internet Gateway** y sus **tablas de rutas**.
- Entender qué hace "pública" a una subred, qué es un **NAT Gateway** y por qué cuesta lo que cuesta.
- Explicar por qué la **base de datos va en la subred privada**.
- Convertir los pasos en dos scripts, uno para crear y otro para borrar, que usarás en las clases siguientes.

## Por qué importa

Todo lo que creas en AWS vive dentro de una red: la EC2 de Vigía, una base de datos o un clúster de Kubernetes. Una VPC es la fase 3 entera aplicada a la nube:
- rangos CIDR y subredes (clases 27 y 28);
- rutas y NAT (clase 30);
- firewall (clase 33).

"Dibújame la red de tu aplicación en AWS" es una pregunta de entrevista habitual, y el diseño de red es uno de los criterios de salida de la fase.

## Costo esperado

> 💰 **0 USD.** La VPC, las subredes, las tablas de rutas y el Internet Gateway son gratis. Lo que cuesta dinero en una red son el **NAT Gateway** y las **IPv4 públicas**, y hoy no creas ninguno: el NAT Gateway llega en la clase 72, y se borra el mismo día.

## Teoría

### Qué es una VPC

Una **VPC** (*Virtual Private Cloud*) es tu red privada dentro de una región de AWS:
- tiene un rango de direcciones, entre `/16` (65 536 direcciones) y `/28`;
- se divide en **subredes**, y cada subred vive en **una sola** zona de disponibilidad.

El rango, de los privados (clase 27): `10.0.0.0/8`, `172.16.0.0/12` o `192.168.0.0/16`. Elige uno que **no se solape** con redes que algún día quieras conectar: tu casa (seguramente `192.168.1.0/24`), la oficina u otras VPC. El curso usa `10.20.0.0/16`.

En cada subred, AWS **reserva 5 direcciones**. En una `/24`:

| Dirección | Para qué |
|-----------|----------|
| `.0` | la dirección de red |
| `.1` | el router de la VPC |
| `.2` | el DNS de AWS |
| `.3` | reservada para el futuro |
| `.255` | la de *broadcast* |

Quedan **251 utilizables** (no 254, como en la clase 28).

### Qué hace pública a una subred

No es una casilla que se marca: es su **tabla de rutas**.

| Subred | Su tabla de rutas | Qué significa |
|--------|-------------------|---------------|
| **Pública** | `10.20.0.0/16 → local` y `0.0.0.0/0 → Internet Gateway` | sus instancias con IP pública hablan con internet en los dos sentidos |
| **Privada** | solo `10.20.0.0/16 → local` | sin salida ni entrada desde internet |
| **Privada con NAT** | `local` y `0.0.0.0/0 → NAT Gateway` | sus instancias pueden **salir** (actualizar paquetes, descargar imágenes), pero nadie de fuera puede iniciar una conexión hacia ellas |

- Cada subred está asociada a **una** tabla de rutas. Si no la asocias a ninguna, usa la **tabla principal** de la VPC.
- La ruta `local` (toda la VPC) no se puede quitar: dentro de una VPC, todas las subredes se ven entre sí. Lo que filtra el tráfico interno son los security groups y las NACL (clase 73).
- Gana la ruta más específica, como en la clase 30.

### Internet Gateway y NAT Gateway

- **Internet Gateway (IGW):**
  - conecta la VPC con internet; es redundante, escala solo y es gratis;
  - traduce, uno a uno, la IP pública de cada instancia a su IP privada;
  - por eso, dentro de una EC2, `ip addr` solo muestra la privada: la pública no existe en el sistema operativo, vive en el IGW. Es NAT, como en la clase 30.
- **NAT Gateway:**
  - deja salir a internet a las subredes privadas;
  - vive en una subred **pública** y necesita una **IP elástica** (una IPv4 pública fija);
  - es gestionado y redundante dentro de su zona, pero cuesta 0,045 USD/h **más** 0,045 USD por cada GB que pasa por él: unos 33 USD al mes sin hacer nada.

Alternativas al NAT Gateway:
- los ***gateway endpoints*** de S3 y DynamoDB, **gratis**: la subred privada llega a S3 sin pasar por internet (Reto 2);
- los ***interface endpoints***, de pago, para otros servicios;
- una instancia NAT gestionada por ti: barata, pero te toca mantenerla.

### El diseño del laboratorio

```
lab-vpc 10.20.0.0/16 (us-east-1)                                    internet
├── lab-publica 10.20.1.0/24 (zona A) ── lab-rutas-publica:              │
│      aquí: servidores web, balanceadores,  10.20.0.0/16 → local        │
│      el NAT Gateway (clase 72)             0.0.0.0/0    → lab-igw ─────┤
├── lab-privada 10.20.2.0/24 (zona A) ── lab-rutas-privada:              │
│      aquí: la base de datos                10.20.0.0/16 → local        │
│                                            (0.0.0.0/0 → NAT, clase 72) │
└── lab-igw (Internet Gateway) ──────────────────────────────────────────┘
```

En producción repetirías el par pública/privada en dos o tres zonas, para que la caída de una no tumbe la aplicación (Reto 1). Para aprender, basta con una.

### Por qué la base de datos va en la privada

Es **defensa en profundidad**: varias capas, de modo que un error en una no deja la puerta abierta.
- Una subred privada no tiene ruta desde internet. Aunque alguien abra por error el puerto 5432 a `0.0.0.0/0` en un security group, **no hay camino** para llegar desde fuera.
- Solo llegan a la base de datos las máquinas de dentro de la VPC, como tu servidor de aplicación en la subred pública.
- La superficie de ataque es mínima: lo único expuesto a internet es lo que tiene que estarlo.

### La VPC por defecto

Cada región trae una (la viste en la clase 68): `172.31.0.0/16`, una subred **pública** por zona y su IGW. Es cómoda para una prueba rápida, pero todo lo que lanzas en ella es público. No la borres (algunas herramientas la esperan); simplemente, no la uses para tus proyectos.

### Para el examen: conectar redes

| Servicio | Para qué |
|----------|----------|
| **VPC peering** | unir dos VPC, punto a punto |
| **Transit Gateway** | un concentrador para unir muchas VPC y redes locales |
| **Site-to-Site VPN** | un túnel cifrado por internet entre tu oficina y la VPC |
| **Direct Connect** | una línea física dedicada entre tu centro de datos y AWS |
| **VPC endpoints / PrivateLink** | llegar a servicios de AWS sin salir a internet |
| **VPC Flow Logs** | registrar qué tráfico entra y sale de las interfaces de red |

## Práctica guiada

Desde tu Ubuntu, con `aws login` activo (clase 70):

```bash
mkdir -p ~/my-devops-journey/labs/clase-71 && cd ~/my-devops-journey/labs/clase-71
aws sts get-caller-identity --query Arn --output text
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }
```

La función `etiquetas` te evita escribir la misma etiqueta veinte veces: todo lo que crees llevará un `Name` y `Proyecto=lab`.

### 1. Diseña antes de crear (15 min)

En `notas/fase-6/clase-71.md`, escribe:
- la VPC: `10.20.0.0/16`;
- la pública: `10.20.1.0/24`;
- la privada: `10.20.2.0/24`.

🔮 **Predice:** ¿cuántas direcciones utilizables tendrá cada subred? ¿Y cuántas subredes `/24` caben en la VPC (clase 28)?

### 2. La VPC (10 min)

```bash
VPC=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --tag-specifications "$(etiquetas vpc lab-vpc)" --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC"
aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames '{"Value":true}'
echo "$VPC"
```

`--enable-dns-hostnames` da nombres DNS a las instancias. Lo necesitarán algunos servicios, como los endpoints de la clase 72.

### 3. Las subredes (15 min)

No todas las zonas tienen todos los tipos de instancia. Elige una con `t3.small`, la que usará Vigía:

```bash
AZ=$(aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=instance-type,Values=t3.small \
  --query 'sort(InstanceTypeOfferings[].Location)[0]' --output text)
echo "$AZ"
PUB=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.1.0/24 --availability-zone "$AZ" \
  --tag-specifications "$(etiquetas subnet lab-publica)" --query Subnet.SubnetId --output text)
PRIV=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.2.0/24 --availability-zone "$AZ" \
  --tag-specifications "$(etiquetas subnet lab-privada)" --query Subnet.SubnetId --output text)
aws ec2 modify-subnet-attribute --subnet-id "$PUB" --map-public-ip-on-launch
```

La última orden hace que las instancias de la pública reciban una IPv4 pública automática. Eso no basta para ser pública: falta el camino.

### 4. El Internet Gateway y las rutas (20 min)

```bash
IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(etiquetas internet-gateway lab-igw)" \
  --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"

RT_PUB=$(aws ec2 create-route-table --vpc-id "$VPC" \
  --tag-specifications "$(etiquetas route-table lab-rutas-publica)" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RT_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW"
aws ec2 associate-route-table --route-table-id "$RT_PUB" --subnet-id "$PUB"

RT_PRIV=$(aws ec2 create-route-table --vpc-id "$VPC" \
  --tag-specifications "$(etiquetas route-table lab-rutas-privada)" --query RouteTable.RouteTableId --output text)
aws ec2 associate-route-table --route-table-id "$RT_PRIV" --subnet-id "$PRIV"
```

La privada tiene su propia tabla, vacía salvo `local`, en lugar de usar la principal. Así, en la clase 72, le añadirás la ruta al NAT sin tocar nada más.

### 5. Comprueba lo que has construido (15 min)

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,AvailableIpAddressCount]' \
  --output table
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PUB" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output text
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PRIV" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output text
```

🔮 **Predice:**
- **`AvailableIpAddressCount`:** 251 en las dos subredes.
- **Rutas de la pública:** `local` y `0.0.0.0/0 → igw-…`.
- **Rutas de la privada:** solo `local`.

Ahora en la consola: **VPC → Your VPCs → lab-vpc → Resource map**. Es el diagrama de la teoría, dibujado por AWS. Úsalo para comprobar tus redes y para explicarlas.

### 6. Los dos scripts (45 min)

Has creado la red a mano, orden a orden. En las clases 72, 73 y 78 la necesitarás otra vez, y no tiene sentido teclearlo cada vez. Además, borrar a mano una VPC con cosas dentro es un rompecabezas: AWS exige un orden (Rómpelo 3).

1. **`crear-vpc.sh`:** escríbelo tú en `labs/clase-71/` con las órdenes de los pasos 2 a 4.
   - Que empiece por `set -euo pipefail` (clase 19).
   - Que no haga nada si ya existe una `lab-vpc`: compruébalo con `aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'length(Vpcs)'`.
   - Que al final imprima los ID.
2. **`borrar-vpc.sh`:** cópialo de [`recursos/clase-71/borrar-vpc.sh`](../recursos/clase-71/borrar-vpc.sh) y **léelo entero**:

   ```bash
   cp ~/my-devops-journey/recursos/clase-71/borrar-vpc.sh .
   less borrar-vpc.sh
   ```

   Busca dónde y cómo resuelve cada uno de estos problemas:
   - encuentra la VPC por su etiqueta;
   - borra en orden: lo que está dentro, antes que lo que lo contiene;
   - espera a que las instancias y los NAT Gateways terminen de borrarse;
   - vacía las reglas de los security groups que se referencian entre sí;
   - reintenta lo que AWS tarda unos segundos en soltar.

   La lista de lo que borra incluye cosas que todavía no has creado (instancias, NAT, IP elásticas, security groups): las crearás en las próximas clases, y este script lo limpiará todo.

Pruébalos, un ciclo completo:

```bash
bash borrar-vpc.sh
bash crear-vpc.sh
bash crear-vpc.sh          # la segunda vez debe negarse
bash borrar-vpc.sh
bash borrar-vpc.sh         # y esto, decir que no hay nada que borrar
```

<details>
<summary>Compara tu <code>crear-vpc.sh</code> con el mío (ábrelo después de escribir el tuyo)</summary>

Está en [`recursos/clase-71/crear-vpc.sh`](../recursos/clase-71/crear-vpc.sh). Si el tuyo hace lo mismo con otras palabras, está bien. Si algo falla en las clases siguientes y no encuentras por qué, usa ese.
</details>

Termina con la red **creada** si vas a hacer el Reto hoy, o **borrada** si no.

## Rómpelo

Con la VPC creada (`bash crear-vpc.sh`) y sus ID en variables:

```bash
VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'Vpcs[0].VpcId' --output text)
PUB=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=lab-publica --query 'Subnets[0].SubnetId' --output text)
RT_PUB=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=lab-rutas-publica --query 'RouteTables[0].RouteTableId' --output text)
```

Estas tres líneas son la forma de **encontrar recursos por su etiqueta**. Las verás en todas las clases siguientes.

**1. Una subred fuera de la VPC:**

```bash
aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.30.1.0/24
```

`InvalidSubnet.Range`: una subred tiene que estar dentro del rango de su VPC.

**2. Dos subredes que se solapan:**

```bash
aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.1.128/25
```

`InvalidSubnet.Conflict`: `10.20.1.128/25` está dentro de `10.20.1.0/24`, que ya existe (clase 28).

**3. Borrar la VPC con cosas dentro:**

```bash
aws ec2 delete-vpc --vpc-id "$VPC"
```

`DependencyViolation`. AWS no borra en cascada: primero lo de dentro. Para eso es `borrar-vpc.sh`.

**4. La subred "pública" que dejó de serlo:**

```bash
ASOC=$(aws ec2 describe-route-tables --route-table-ids "$RT_PUB" \
  --query "RouteTables[0].Associations[?SubnetId=='$PUB'].RouteTableAssociationId" --output text)
aws ec2 disassociate-route-table --association-id "$ASOC"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" Name=association.main,Values=true \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output text
```

Sin asociación, la subred usa la tabla **principal**, que solo tiene `local`. Sigue llamándose `lab-publica`, sigue dando IP públicas a sus instancias… y ya **no es pública**: no hay ruta al IGW. Las instancias tendrían IP pública, pero no se podría llegar a ellas. Vuelve a asociarla:

```bash
aws ec2 associate-route-table --route-table-id "$RT_PUB" --subnet-id "$PUB"
```

Cuando "una instancia con IP pública no responde", la tabla de rutas de su subred es de lo primero que hay que mirar.

## Reto

1. **Alta disponibilidad.** Añade a tu `crear-vpc.sh` un segundo par de subredes en **otra zona**: `10.20.11.0/24` (pública) y `10.20.12.0/24` (privada), con las mismas tablas de rutas. ¿Por qué lo harías en producción? Pista: las bases de datos de RDS y los balanceadores piden subredes en al menos dos zonas (clase 77). ¿Tendrías que cambiar `borrar-vpc.sh`?
2. **Un camino gratis a S3.** Crea un *gateway endpoint* de S3 para la tabla de rutas privada:

   ```bash
   RT_PRIV=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=lab-rutas-privada --query 'RouteTables[0].RouteTableId' --output text)
   aws ec2 create-vpc-endpoint --vpc-id "$VPC" --vpc-endpoint-type Gateway \
     --service-name com.amazonaws.us-east-1.s3 --route-table-ids "$RT_PRIV" \
     --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Proyecto,Value=lab}]"
   aws ec2 describe-route-tables --route-table-ids "$RT_PRIV" \
     --query 'RouteTables[0].Routes[].[DestinationCidrBlock,DestinationPrefixListId,GatewayId]' --output text
   ```

   ¿Qué ruta nueva aparece? ¿Qué es un *prefix list* (`pl-…`)? ¿Por qué ahorra dinero frente a un NAT Gateway? `borrar-vpc.sh` ya sabe borrarlo.
3. Han pasado horas desde que tus recursos usaron la etiqueta `Proyecto`: actívala en **Billing → Cost allocation tags** (clase 68).

## Destruir al terminar

```bash
bash borrar-vpc.sh
aws ec2 describe-vpcs --filters Name=tag:Proyecto,Values=lab --query 'length(Vpcs)'
```

Debe decir `0`. Aunque la VPC no cuesta nada, un laboratorio que se queda a medias es como acaban las cuentas llenas de restos que nadie se atreve a borrar. En la clase 72, `bash crear-vpc.sh` la recrea en un minuto.

## Cierre

En `notas/fase-6/clase-71.md`:

1. ¿Qué hace exactamente que una subred sea pública? ¿Basta con que sus instancias tengan IP pública?
2. ¿Para qué sirve un NAT Gateway, dónde va y por qué cuesta tanto comparado con el resto de la VPC?
3. Explica, como en una entrevista, por qué la base de datos va en la subred privada.
4. **Repaso (clase 70, sin mirar):** ¿por qué empiezan por `ASIA` las llaves que devuelve `sts assume-role`, y qué significa encontrar una que empiece por `AKIA`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Diseño (paso 1):** 251 utilizables en cada `/24` (256 menos las 5 reservadas por AWS). En una `/16` caben 256 subredes `/24`.

**1.** Su tabla de rutas: tiene que llevar `0.0.0.0/0` hacia un **Internet Gateway** conectado a la VPC. No basta con la IP pública: sin esa ruta, los paquetes no tienen por dónde salir ni entrar (Rómpelo 4).

**2.** Deja salir a internet a las instancias de una subred privada (para actualizar paquetes o descargar imágenes) sin que nadie de fuera pueda iniciar una conexión hacia ellas. Va en una subred **pública**, con una IP elástica, y la tabla de rutas privada apunta a él. Cuesta porque se cobra **por hora** (0,045 USD, unos 33 al mes) y **por GB procesado**, mientras que la VPC, las subredes, las rutas y el IGW son gratis.

**3.** La subred privada no tiene ruta desde internet, así que la base de datos solo es alcanzable desde dentro de la VPC: desde el servidor de aplicación, que sí está en la pública. Es defensa en profundidad. Aunque un security group quede mal configurado (por ejemplo, el 5432 abierto a todo el mundo), no hay camino para llegar desde fuera. Lo único expuesto a internet es lo que debe estarlo.

**4.** `ASIA` es el prefijo de las credenciales **temporales** de STS: caducan solas. `AKIA` es el de las llaves **permanentes** de un usuario: si aparece una en un repositorio o un log, hay que desactivarla ya, porque vale hasta que alguien lo haga.

**Reto 2:** aparece una ruta cuyo destino es un *prefix list* (`pl-…`): la lista de rangos de IP de S3 en la región, mantenida por AWS. El tráfico de la subred privada hacia S3 va por el endpoint, dentro de la red de AWS: sin NAT Gateway, sin su coste por hora y sin su coste por GB.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| VPC / subnet / CIDR block | red virtual privada / subred / bloque CIDR |
| route table / main route table | tabla de rutas / tabla principal |
| Internet Gateway / NAT Gateway | puerta de enlace a internet / de NAT |
| public / private subnet | subred pública / privada |
| defense in depth | defensa en profundidad |
| gateway endpoint | punto de enlace de tipo gateway |

🎙️ *"My VPC has a public subnet whose route table sends 0.0.0.0/0 to an Internet Gateway, and a private subnet with only the local route. The database lives in the private one, so even a misconfigured security group can't expose it to the internet."*

## Siguiente

[Clase 72 — EC2, user-data y Session Manager](clase-72-ec2.md)
