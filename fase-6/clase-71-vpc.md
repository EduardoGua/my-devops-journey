# Clase 71 — VPC desde cero

**Dónde:** tu Ubuntu (AWS CLI) + consola · **Tiempo:** 2 bloques (unas 3 h) · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** una **VPC** es tu red privada dentro de una región de AWS: un rango CIDR dividido en subredes, cada una en una zona. Lo que hace **pública** a una subred no es una casilla, sino su **tabla de rutas**: una ruta `0.0.0.0/0` hacia un Internet Gateway. Hoy montas con la CLI una VPC con una subred pública y otra privada, y conviertes los pasos en dos scripts para crearla y borrarla en un minuto.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los rangos privados, el CIDR, el *subnetting* y los solapamientos (clases 27 y 28).
> - La tabla de rutas, que gane la ruta más específica, y el NAT (clase 30); el firewall (clase 33).
> - Las regiones, las zonas y la VPC por defecto `172.31.0.0/16` (clase 68).
> - `aws login`, `--query` y las variables con `$( … )` (clases 68 y 70); `set -euo pipefail` y las funciones de Bash (clase 19).

> 🔤 **Palabras nuevas de hoy:**
> - **VPC** (*Virtual Private Cloud*): tu red privada en una región de AWS.
> - **subred pública / privada**: con ruta a internet / sin ella.
> - **tabla de rutas principal**: la que usa una subred que no tiene ninguna asociada.
> - **Internet Gateway** (IGW): la puerta de la VPC a internet; gratis.
> - **NAT Gateway**: deja salir a internet a una subred privada; de pago.
> - **IP elástica**: una IPv4 pública fija que reservas en tu cuenta.
> - **defensa en profundidad**: varias capas de protección, para que un error en una no deje la puerta abierta.

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

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Las piezas 1 a 3 construyen la red orden a orden; la 6 la convierte en scripts.

Son dos bloques: el primero, las **piezas 1 a 3** (unos 75 min, con la red creada y comprobada); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto, la limpieza y el cierre. Si paras entre los dos, borra la red con la consola o espera al script de la pieza 6: no cuesta nada, pero no la dejes a medias semanas.

Desde tu Ubuntu, con `aws login` activo (clase 70):

```bash
mkdir -p ~/my-devops-journey/labs/clase-71 && cd ~/my-devops-journey/labs/clase-71
aws sts get-caller-identity --query Arn --output text
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }
```

La función `etiquetas` te evita escribir la misma etiqueta veinte veces: todo lo que crees llevará un `Name` y `Proyecto=lab`.

## Las piezas

### Pieza 1 — Qué es una VPC, y el diseño del laboratorio

Una **VPC** es tu red privada dentro de una región de AWS:
- tiene un rango de direcciones, entre `/16` (65 536 direcciones) y `/28`;
- se divide en **subredes**, y cada subred vive en **una sola** zona de disponibilidad.

El rango, de los privados (clase 27): `10.0.0.0/8`, `172.16.0.0/12` o `192.168.0.0/16`. Elige uno que **no se solape** con redes que algún día quieras conectar: tu casa (seguramente `192.168.1.0/24`), la oficina u otras VPC. El curso usa `10.20.0.0/16`.

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

En producción repetirías el par pública/privada en dos o tres zonas, para que la caída de una no tumbe la aplicación (reto 1). Para aprender, basta con una.

**Pruébalo.** Primero, en papel: en `notas/fase-6/clase-71.md`, escribe la VPC (`10.20.0.0/16`), la pública (`10.20.1.0/24`) y la privada (`10.20.2.0/24`), y calcula cuántas subredes `/24` caben en la VPC (clase 28). Después, créala:

```bash
VPC=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --tag-specifications "$(etiquetas vpc lab-vpc)" --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC"
aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames '{"Value":true}'
echo "$VPC"
```

👀 **Qué deberías ver:** un ID como `vpc-0abc123…`. `wait` no imprime nada: vuelve cuando la VPC está lista. `--enable-dns-hostnames` da nombres DNS a las instancias; lo necesitarán algunos servicios, como los endpoints de la clase 72. En la consola (**VPC → Your VPCs**), `lab-vpc` aparece junto a la de por defecto.

✋ **Sin mirar:** ¿por qué no usas `192.168.1.0/24` para tu VPC?

<details>
<summary>Comprueba</summary>

Porque seguramente se solapa con tu red de casa, y si algún día conectas las dos redes, las direcciones chocarían.
</details>

**En resumen:** una VPC = un rango privado que no se solape, en una región; se diseña en papel antes de crear.

### Pieza 2 — Las subredes, y las cinco direcciones que se queda AWS

En cada subred, AWS **reserva 5 direcciones**. En una `/24`:

| Dirección | Para qué |
|-----------|----------|
| `.0` | la dirección de red |
| `.1` | el router de la VPC |
| `.2` | el DNS de AWS |
| `.3` | reservada para el futuro |
| `.255` | la de *broadcast* |

Quedan **251 utilizables** (no 254, como en la clase 28).

No todas las zonas tienen todos los tipos de instancia: eliges una que tenga `t3.small`, la que usará Vigía.

🔮 **Predice:** ¿cuántas direcciones utilizables tendrá cada subred?

**Pruébalo:**

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
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,AvailableIpAddressCount]' \
  --output table
```

👀 **Qué deberías ver:** la zona elegida (normalmente `us-east-1a`) y una tabla con `lab-publica` y `lab-privada`, sus rangos, la misma zona, `True` en `MapPublicIpOnLaunch` solo para la pública y **251** direcciones disponibles en cada una. `--map-public-ip-on-launch` hace que las instancias de la pública reciban una IPv4 pública automática. Eso no basta para ser pública: falta el camino.

✋ **Sin mirar:** ¿qué hay en la dirección `.2` de cada subred de una VPC?

<details>
<summary>Comprueba</summary>

El DNS de AWS. La `.1` es el router de la VPC, y la `.0`, la `.3` y la `.255` también están reservadas.
</details>

**En resumen:** cada subred vive en una zona y pierde 5 direcciones; una `/24` deja 251.

### Pieza 3 — Qué hace pública a una subred: el Internet Gateway y las rutas

No es una casilla que se marca: es su **tabla de rutas**.

| Subred | Su tabla de rutas | Qué significa |
|--------|-------------------|---------------|
| **Pública** | `10.20.0.0/16 → local` y `0.0.0.0/0 → Internet Gateway` | sus instancias con IP pública hablan con internet en los dos sentidos |
| **Privada** | solo `10.20.0.0/16 → local` | sin salida ni entrada desde internet |
| **Privada con NAT** | `local` y `0.0.0.0/0 → NAT Gateway` | sus instancias pueden **salir** (actualizar paquetes, descargar imágenes), pero nadie de fuera puede iniciar una conexión hacia ellas |

- Cada subred está asociada a **una** tabla de rutas. Si no la asocias a ninguna, usa la **tabla principal** de la VPC.
- La ruta `local` (toda la VPC) no se puede quitar: dentro de una VPC, todas las subredes se ven entre sí. Lo que filtra el tráfico interno son los security groups y las NACL (clase 73).
- Gana la ruta más específica, como en la clase 30.

El **Internet Gateway** (IGW) conecta la VPC con internet; es redundante, escala solo y es gratis. Traduce, uno a uno, la IP pública de cada instancia a su IP privada: por eso, dentro de una EC2, `ip addr` solo muestra la privada. La pública no existe en el sistema operativo, vive en el IGW. Es NAT, como en la clase 30.

🔮 **Predice** las rutas de cada subred al terminar.

**Pruébalo:**

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

aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PUB" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output text
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PRIV" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output text
```

👀 **Qué deberías ver:** `{"Return": true}` al crear la ruta y un `AssociationId` en cada asociación. Las rutas de la pública: `10.20.0.0/16 local` y `0.0.0.0/0 igw-…`. Las de la privada: solo `10.20.0.0/16 local`. La privada tiene su propia tabla, vacía salvo `local`, en lugar de usar la principal: así, en la clase 72, le añadirás la ruta al NAT sin tocar nada más.

Ahora en la consola: **VPC → Your VPCs → lab-vpc → Resource map**. Es el diagrama de la pieza 1, dibujado por AWS. Úsalo para comprobar tus redes y para explicarlas.

✋ **Sin mirar:** una instancia tiene IP pública, pero su subred usa una tabla con solo `local`. ¿Se puede llegar a ella desde internet?

<details>
<summary>Comprueba</summary>

No: sin la ruta `0.0.0.0/0` hacia el Internet Gateway, los paquetes no tienen camino ni de entrada ni de salida.
</details>

**En resumen:** pública = su tabla de rutas lleva `0.0.0.0/0 → IGW`; privada = solo `local`.

> ⏸️ Aquí termina el primer bloque.

### Pieza 4 — El NAT Gateway, y por qué la base de datos va en la privada

El **NAT Gateway** deja salir a internet a las subredes privadas:
- vive en una subred **pública** y necesita una **IP elástica** (una IPv4 pública fija);
- es gestionado y redundante dentro de su zona, pero cuesta 0,045 USD/h **más** 0,045 USD por cada GB que pasa por él: unos 33 USD al mes sin hacer nada.

Alternativas al NAT Gateway:
- los ***gateway endpoints*** de S3 y DynamoDB, **gratis**: la subred privada llega a S3 sin pasar por internet (reto 2);
- los ***interface endpoints***, de pago, para otros servicios;
- una instancia NAT gestionada por ti: barata, pero te toca mantenerla.

**Por qué la base de datos va en la privada.** Es **defensa en profundidad**:
- Una subred privada no tiene ruta desde internet. Aunque alguien abra por error el puerto 5432 a `0.0.0.0/0` en un security group, **no hay camino** para llegar desde fuera.
- Solo llegan a la base de datos las máquinas de dentro de la VPC, como tu servidor de aplicación en la subred pública.
- La superficie de ataque es mínima: lo único expuesto a internet es lo que tiene que estarlo.

**Pruébalo, en papel.** Para cada pieza de Vigía v3, ¿subred pública o privada, y por qué? Escríbelo antes de abrir la respuesta:

1. La API de Vigía, a la que entras desde tu navegador.
2. Su base de datos PostgreSQL (si estuviera en AWS).
3. Un NAT Gateway para que la base de datos descargue actualizaciones.

<details>
<summary>Comprueba</summary>

1, pública: tiene que recibir conexiones de fuera. 2, privada: solo la usa la API, desde dentro de la VPC. 3, pública: el NAT Gateway siempre va en una subred pública, y la tabla de la privada apunta a él.
</details>

✋ **Sin mirar:** ¿cuánto cuesta al mes un NAT Gateway que no hace nada, más o menos?

<details>
<summary>Comprueba</summary>

Unos 33 USD (0,045 USD por hora × 730 horas), más 0,045 USD por cada GB que pase.
</details>

**En resumen:** el NAT deja salir a la privada y cuesta por hora y por GB; la base de datos, en la privada, sin camino desde internet.

### Pieza 5 — La VPC por defecto, y cómo se conectan las redes

Cada región trae una VPC por defecto (la viste en la clase 68): `172.31.0.0/16`, una subred **pública** por zona y su IGW. Es cómoda para una prueba rápida, pero todo lo que lanzas en ella es público. No la borres (algunas herramientas la esperan); simplemente, no la uses para tus proyectos.

Para el examen, los servicios que conectan redes:

| Servicio | Para qué |
|----------|----------|
| **VPC peering** | unir dos VPC, punto a punto |
| **Transit Gateway** | un concentrador para unir muchas VPC y redes locales |
| **Site-to-Site VPN** | un túnel cifrado por internet entre tu oficina y la VPC |
| **Direct Connect** | una línea física dedicada entre tu centro de datos y AWS |
| **VPC endpoints / PrivateLink** | llegar a servicios de AWS sin salir a internet |
| **VPC Flow Logs** | registrar qué tráfico entra y sale de las interfaces de red |

**Pruébalo:**

```bash
DEF=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEF" \
  --query 'Subnets[].[AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' --output table
```

👀 **Qué deberías ver:** una subred por zona (seis en `us-east-1`), cada una con un trozo de `172.31.0.0/16` (`172.31.0.0/20`, `172.31.16.0/20`…) y `True` en `MapPublicIpOnLaunch`: todas públicas. Por eso tus proyectos van en tu propia VPC.

✋ **Sin mirar:** tu empresa necesita una línea física dedicada entre su centro de datos y AWS. ¿Qué servicio es?

<details>
<summary>Comprueba</summary>

Direct Connect. Si basta con un túnel cifrado por internet, Site-to-Site VPN.
</details>

**En resumen:** la VPC por defecto es toda pública; para unir redes, peering, Transit Gateway, VPN o Direct Connect.

### Pieza 6 — Los dos scripts

Has creado la red a mano, orden a orden. En las clases 72, 73 y 78 la necesitarás otra vez, y no tiene sentido teclearlo cada vez. Además, borrar a mano una VPC con cosas dentro es un rompecabezas: AWS exige un orden (Rómpelo 3).

1. **`crear-vpc.sh`:** escríbelo tú en `labs/clase-71/` con las órdenes de las piezas 1 a 3.
   - Que empiece por `set -euo pipefail` (clase 19) y defina la función `etiquetas`.
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

**Pruébalo**, un ciclo completo:

```bash
bash borrar-vpc.sh
bash crear-vpc.sh
bash crear-vpc.sh          # la segunda vez debe negarse
bash borrar-vpc.sh
bash borrar-vpc.sh         # y esto, decir que no hay nada que borrar
```

👀 **Qué deberías ver:** el primer `borrar-vpc.sh` borra la red que hiciste a mano; `crear-vpc.sh` la crea e imprime los ID; la segunda vez se niega porque `lab-vpc` ya existe; y el último `borrar-vpc.sh` avisa de que no encuentra ninguna `lab-vpc`.

<details>
<summary>Compara tu <code>crear-vpc.sh</code> con el mío (ábrelo después de escribir el tuyo)</summary>

Está en [`recursos/clase-71/crear-vpc.sh`](../recursos/clase-71/crear-vpc.sh). Si el tuyo hace lo mismo con otras palabras, está bien. Si algo falla en las clases siguientes y no encuentras por qué, usa ese.
</details>

Termina con la red **creada** si vas a hacer el Rómpelo y el reto ahora, o **borrada** si no.

✋ **Sin mirar:** ¿por qué `borrar-vpc.sh` no puede empezar por `aws ec2 delete-vpc`?

<details>
<summary>Comprueba</summary>

Porque AWS no borra en cascada: con subredes, tablas de rutas o un IGW dentro, `delete-vpc` falla con `DependencyViolation`. Primero lo de dentro.
</details>

**En resumen:** `crear-vpc.sh` (idempotente) y `borrar-vpc.sh` (en orden, con esperas y reintentos): la red en un minuto, y fuera en otro.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws ec2 create-vpc --cidr-block …` · `wait vpc-available` | crear la VPC y esperar |
| `aws ec2 create-subnet --vpc-id … --cidr-block … --availability-zone …` | una subred en una zona |
| `aws ec2 modify-subnet-attribute --subnet-id … --map-public-ip-on-launch` | IPv4 pública automática |
| `aws ec2 create-internet-gateway` · `attach-internet-gateway` | el IGW y conectarlo |
| `aws ec2 create-route-table` · `create-route` · `associate-route-table` | rutas y asociación |
| `--tag-specifications "ResourceType=…,Tags=[{Key=Name,Value=…}]"` | etiquetar al crear |
| `--filters Name=tag:Name,Values=lab-vpc --query '…[0]…'` | encontrar recursos por su etiqueta |
| VPC → *Resource map* | el diagrama de tu red |
| `bash crear-vpc.sh` · `bash borrar-vpc.sh` | la red del laboratorio, sí o no |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Alta disponibilidad.** Añade a tu `crear-vpc.sh` un segundo par de subredes en **otra zona**: `10.20.11.0/24` (pública) y `10.20.12.0/24` (privada), con las mismas tablas de rutas.

> 🧩 **Ejemplo resuelto:** la pieza 2, que eligió la primera zona con `t3.small` y creó `lab-publica` y `lab-privada` en ella.

**Ahora tú, con huecos** (añádelo a tu script después de crear las tablas de rutas):
```bash
AZ2=$(aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=instance-type,Values=t3.small \
  --query 'sort(InstanceTypeOfferings[].Location)[____]' --output text)
PUB2=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.____.0/24 --availability-zone "$AZ2" \
  --tag-specifications "$(etiquetas subnet lab-publica-2)" --query Subnet.SubnetId --output text)
PRIV2=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.____.0/24 --availability-zone "$AZ2" \
  --tag-specifications "$(etiquetas subnet lab-privada-2)" --query Subnet.SubnetId --output text)
aws ec2 modify-subnet-attribute --subnet-id "$PUB2" --map-public-ip-on-launch
aws ec2 associate-route-table --route-table-id "$____" --subnet-id "$PUB2"
aws ec2 associate-route-table --route-table-id "$____" --subnet-id "$PRIV2"
```
Completa: «En producción lo haría porque…. `borrar-vpc.sh` ____ cambiar, porque busca las subredes por…».

<details>
<summary>Pista</summary>

`[0]` era la primera zona de la lista ordenada; la segunda es `[1]`. Las bases de datos de RDS y los balanceadores piden subredes en al menos dos zonas (clase 77). Mira la línea `for s in $(aws ec2 describe-subnets --filters "$F"…` de `borrar-vpc.sh`: ¿qué hay en `$F`?
</details>

**2.** **Un camino gratis a S3.** Crea un *gateway endpoint* de S3 para la tabla de rutas privada y mira qué ruta aparece.

> 🧩 **Ejemplo resuelto:** la lista de alternativas al NAT Gateway de la pieza 4: los *gateway endpoints* de S3 y DynamoDB son gratis.

**Ahora tú, con huecos:**
```bash
RT_PRIV=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=lab-rutas-privada --query 'RouteTables[0].RouteTableId' --output text)
aws ec2 create-vpc-endpoint --vpc-id "$VPC" --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.us-east-1.____ --route-table-ids "$RT_PRIV" \
  --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Proyecto,Value=lab}]"
aws ec2 describe-route-tables --route-table-ids "$RT_PRIV" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,DestinationPrefixListId,GatewayId]' --output text
```
Completa: «Aparece una ruta hacia `pl-…`, un *prefix list*, que es…. Ahorra frente a un NAT Gateway porque…».

<details>
<summary>Pista</summary>

El servicio se llama como el de S3, en minúsculas. Busca `prefix list` en la consola (**VPC → Managed prefix lists**) para ver qué contiene. `borrar-vpc.sh` ya sabe borrar el endpoint.
</details>

**3.** Han pasado horas desde que tus recursos usaron la etiqueta `Proyecto`: actívala para los informes de costos.

> 🧩 **Ejemplo resuelto:** la pieza 7 de la clase 68: las etiquetas solo aparecen en los informes si las activas en *Cost allocation tags*.

**Ahora tú, con huecos:** **Billing and Cost Management → Cost allocation tags**, busca ____ y pulsa ____. Completa: «Tarda hasta ____ en poder agrupar por ella en Cost Explorer».

<details>
<summary>Pista</summary>

Si la etiqueta todavía no aparece en la lista, espera un día: AWS necesita ver recursos con ella en la facturación. La activación tarda hasta 24 horas.
</details>

## Destruir al terminar

```bash
bash borrar-vpc.sh
aws ec2 describe-vpcs --filters Name=tag:Proyecto,Values=lab --query 'length(Vpcs)'
```

Debe decir `0`. Aunque la VPC no cuesta nada, un laboratorio que se queda a medias es como acaban las cuentas llenas de restos que nadie se atreve a borrar. En la clase 72, `bash crear-vpc.sh` la recrea en un minuto.

## Cierre

En `notas/fase-6/clase-71.md`:

1. ¿Qué hace exactamente que una subred sea pública? ¿Basta con que sus instancias tengan IP pública? *(2 líneas. Empieza así: «Su tabla de rutas: tiene que llevar `0.0.0.0/0` hacia… No basta con la IP pública, porque…»)*
2. ¿Para qué sirve un NAT Gateway, dónde va y por qué cuesta tanto comparado con el resto de la VPC? *(2–3 líneas. Empieza así: «Deja salir a internet a las instancias de una subred privada sin que… Va en una subred pública, con… Cuesta porque se cobra por hora y…»)*
3. Explica, como en una entrevista, por qué la base de datos va en la subred privada. *(2 líneas. Empieza así: «La subred privada no tiene ruta desde internet, así que la base de datos solo… Es defensa en profundidad: aunque un security group…»)*
4. **Repaso (clase 70, sin mirar):** ¿por qué empiezan por `ASIA` las llaves que devuelve `sts assume-role`, y qué significa encontrar una que empiece por `AKIA`? *(2 líneas. Empieza así: «`ASIA` es el prefijo de las credenciales temporales de STS…; `AKIA`…»)*

Después, escríbeme `examíname clase-71`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Diseño (pieza 1):** 251 utilizables en cada `/24` (256 menos las 5 reservadas por AWS). En una `/16` caben 256 subredes `/24`.

**1.** Su tabla de rutas: tiene que llevar `0.0.0.0/0` hacia un **Internet Gateway** conectado a la VPC. No basta con la IP pública: sin esa ruta, los paquetes no tienen por dónde salir ni entrar (Rómpelo 4).

**2.** Deja salir a internet a las instancias de una subred privada (para actualizar paquetes o descargar imágenes) sin que nadie de fuera pueda iniciar una conexión hacia ellas. Va en una subred **pública**, con una IP elástica, y la tabla de rutas privada apunta a él. Cuesta porque se cobra **por hora** (0,045 USD, unos 33 al mes) y **por GB procesado**, mientras que la VPC, las subredes, las rutas y el IGW son gratis.

**3.** La subred privada no tiene ruta desde internet, así que la base de datos solo es alcanzable desde dentro de la VPC: desde el servidor de aplicación, que sí está en la pública. Es defensa en profundidad. Aunque un security group quede mal configurado (por ejemplo, el 5432 abierto a todo el mundo), no hay camino para llegar desde fuera. Lo único expuesto a internet es lo que debe estarlo.

**4.** `ASIA` es el prefijo de las credenciales **temporales** de STS: caducan solas. `AKIA` es el de las llaves **permanentes** de un usuario: si aparece una en un repositorio o un log, hay que desactivarla ya, porque vale hasta que alguien lo haga.

**Reto 1:** `[1]`, `10.20.11.0/24` y `10.20.12.0/24`, `$RT_PUB` y `$RT_PRIV`. En producción, porque si cae una zona, la aplicación sigue en la otra, y RDS y los balanceadores lo exigen. `borrar-vpc.sh` **no** tiene que cambiar: busca las subredes por el ID de la VPC (`$F` es `Name=vpc-id,Values=$VPC`), así que encuentra también las nuevas.

**Reto 2:** `com.amazonaws.us-east-1.s3`. Aparece una ruta cuyo destino es un *prefix list* (`pl-…`): la lista de rangos de IP de S3 en la región, mantenida por AWS. El tráfico de la subred privada hacia S3 va por el endpoint, dentro de la red de AWS: sin NAT Gateway, sin su coste por hora y sin su coste por GB.

**Reto 3:** la etiqueta `Proyecto` y *Activate*; hasta 24 horas.
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
