# Clase 98 — Módulos

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** B. Vigía en código

> 💡 **La idea de hoy:** un **módulo** es una carpeta de Terraform que se usa como una pieza: recibe valores por sus variables y devuelve sus outputs; lo de dentro no se ve. Para meter en un módulo recursos que **ya existen** sin destruirlos, se usan bloques **`moved`**: le dicen a Terraform que un recurso solo ha cambiado de dirección.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La red de la clase 71: VPC, subred pública y privada, IGW y tablas de rutas; el NAT Gateway y lo que cuesta (clases 71 y 72).
> - Variables con `default`, outputs, `cidrsubnet` y `for_each` (clases 93 y 94).
> - Las direcciones del estado y `terraform state mv` (clase 96).
> - Tu `infra/` de Vigía, en Terraform desde la clase 97.

> 🔤 **Palabras nuevas de hoy:**
> - **módulo raíz**: la carpeta en la que ejecutas `terraform`.
> - **módulo hijo**: una carpeta que el raíz llama con un bloque `module`.
> - **`source`**: de dónde sale un módulo (una carpeta, el Registry, un repositorio de Git).
> - **refactorizar**: reordenar el código sin cambiar lo que hace.
> - **bloque `moved`**: `from` (la dirección vieja) y `to` (la nueva) de un mismo recurso.
> - **`coalesce()`**: devuelve el primer valor que no sea nulo.

## Objetivo

- Entender qué es un **módulo**: una carpeta de Terraform con entradas (variables) y salidas (outputs) que se reutiliza como una pieza.
- Escribir un **módulo propio**, `red`, y usarlo con un bloque `module`.
- **Refactorizar** sin destruir: mover recursos que ya existen a un módulo con bloques **`moved`**.
- Usar módulos del **Registry** con su versión fijada, y saber cuándo conviene y cuándo no.
- Llevar la red de Vigía a su módulo, con `No changes` en el plan: un criterio de salida de la fase.

## Por qué importa

Cuando una configuración crece, los mismos patrones se repiten: la red de cada entorno, el bucket con todas sus protecciones, el rol de cada servicio. Un módulo los escribe **una vez**, con un interfaz claro, y se usa cuantas veces haga falta.

En un trabajo real verás:
- módulos propios del equipo, versionados en su repositorio;
- módulos públicos del Registry.

Y una situación muy común: alguien quiere ordenar el código sin tocar lo que ya funciona. Para eso existen los bloques `moved`. Sin ellos, mover un recurso de sitio en el código significa, para Terraform, **destruirlo y crear otro**.

## Costo esperado

> 💰 **0 USD.** Redes vacías, y un módulo del Registry que solo planificas.

## Cómo va esta clase

Cinco piezas y, al final, lo mismo en Vigía. En cada pieza lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan la misma red.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 35 min); el segundo, las **piezas 3 a 5**, Vigía, el Rómpelo, el reto y el cierre. Puedes dejar la red creada entre los dos días: no cuesta nada.

```bash
mkdir -p ~/my-devops-journey/labs/clase-98/modules/red && cd ~/my-devops-journey/labs/clase-98
```

## Las piezas

### Pieza 1 — El "antes": una red sin módulo

Para ver qué resuelve un módulo, primero la red tal como la escribiría cualquiera la primera vez: cada recurso con su nombre fijo. Funciona, pero para una segunda red tendrías que copiarlo todo y cambiar cada nombre a mano.

**Pruébalo.** `versions.tf`:

```hcl
terraform {
  required_version = "~> 1.16"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = { Proyecto = "lab", Clase = "98" }
  }
}
```

Y `main.tf`, la red de la clase 71 en Terraform:

```hcl
data "aws_availability_zones" "disponibles" {
  state = "available"
}

resource "aws_vpc" "vigia" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "vigia-vpc" }
}

resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.vigia.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.disponibles.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "vigia-publica" }
}

resource "aws_subnet" "privada" {
  vpc_id            = aws_vpc.vigia.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = data.aws_availability_zones.disponibles.names[0]
  tags              = { Name = "vigia-privada" }
}

resource "aws_internet_gateway" "vigia" {
  vpc_id = aws_vpc.vigia.id
  tags   = { Name = "vigia-igw" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.vigia.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vigia.id
  }
  tags = { Name = "vigia-rutas-publica" }
}

resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.vigia.id
  tags   = { Name = "vigia-rutas-privada" }
}

resource "aws_route_table_association" "privada" {
  subnet_id      = aws_subnet.privada.id
  route_table_id = aws_route_table.privada.id
}

output "subred_publica" {
  value = aws_subnet.publica.id
}
```

```bash
terraform init && terraform apply
terraform state list
```

👀 **Qué deberías ver:** `Apply complete! Resources: 8 added` y, en el estado, el `data` y las 8 direcciones: `aws_vpc.vigia`, `aws_subnet.publica`, `aws_route_table_association.privada`… Apúntalas: en la pieza 4 las necesitarás.

✋ **Sin mirar:** ¿cuántos recursos tiene esta red, y cuáles son?

<details>
<summary>Comprueba</summary>

Ocho: la VPC, las dos subredes, el IGW, las dos tablas de rutas y sus dos asociaciones. El `data` de las zonas no es un recurso: solo lee.
</details>

**En resumen:** una red sin módulo funciona, pero sus nombres y rangos están fijos en el código.

### Pieza 2 — Un módulo por dentro

Cualquier carpeta con archivos `.tf` es un módulo. La que ejecutas es el **módulo raíz**, y las que llama con bloques `module` son **módulos hijos**:

```
infra/
├── main.tf                      ← módulo raíz: module "red" { source = "./modules/red" … }
└── modules/red/
    ├── variables.tf             ← sus entradas: nombre, cidr, zona
    ├── main.tf                  ← sus recursos: la VPC, las subredes, el IGW, las rutas
    └── outputs.tf               ← sus salidas: vpc_id, subred_publica_id, subred_privada_id
```

```hcl
module "red" {
  source = "./modules/red"
  nombre = "vigia"               # las variables del módulo son sus argumentos
}

resource "aws_security_group" "web" {
  vpc_id = module.red.vpc_id     # sus outputs, lo único que se ve desde fuera
}
```

- **Un módulo es una caja cerrada.** Desde fuera solo se ven sus outputs. Sus recursos tienen direcciones como `module.red.aws_vpc.esta`.
- **Lo que recibe, lo recibe por variables.** No ve las variables ni los recursos de quien lo llama.
- **Tiene sus propios `required_providers`** si los necesita; usa el provider que le pasa el módulo raíz.

**Pruébalo.** Mueve los recursos de la pieza 1 a `modules/red/main.tf` y generalízalos. Los nombres, el rango y la zona salen de variables, y los rangos de las subredes se calculan con `cidrsubnet` (clase 93):

```hcl
# Módulo red: una VPC con una subred pública y otra privada en la misma zona.
data "aws_availability_zones" "disponibles" {
  state = "available"
}

locals {
  zona = coalesce(var.zona, data.aws_availability_zones.disponibles.names[0])
}

resource "aws_vpc" "esta" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  tags                 = { Name = "${var.nombre}-vpc" }
}

resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.esta.id
  cidr_block              = cidrsubnet(var.cidr, 8, 1)
  availability_zone       = local.zona
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.nombre}-publica" }
}

resource "aws_subnet" "privada" {
  vpc_id            = aws_vpc.esta.id
  cidr_block        = cidrsubnet(var.cidr, 8, 2)
  availability_zone = local.zona
  tags              = { Name = "${var.nombre}-privada" }
}

resource "aws_internet_gateway" "esta" {
  vpc_id = aws_vpc.esta.id
  tags   = { Name = "${var.nombre}-igw" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.esta.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.esta.id
  }
  tags = { Name = "${var.nombre}-rutas-publica" }
}

resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.esta.id
  tags   = { Name = "${var.nombre}-rutas-privada" }
}

resource "aws_route_table_association" "privada" {
  subnet_id      = aws_subnet.privada.id
  route_table_id = aws_route_table.privada.id
}
```

`modules/red/variables.tf`:

```hcl
variable "nombre" {
  description = "Prefijo de los nombres de los recursos"
  type        = string
}

variable "cidr" {
  description = "Rango de la VPC; las subredes serán sus /24 número 1 (pública) y 2 (privada)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "zona" {
  description = "Zona de disponibilidad; si no se da, la primera disponible"
  type        = string
  default     = null
}
```

`modules/red/outputs.tf`:

```hcl
output "vpc_id" {
  value = aws_vpc.esta.id
}

output "subred_publica_id" {
  value = aws_subnet.publica.id
}

output "subred_privada_id" {
  value = aws_subnet.privada.id
}
```

- **`default = null`:** la variable es opcional y, si no se da, no tiene valor. `coalesce` elige el primer valor que no sea nulo.
- **El estilo de nombres dentro del módulo:** `esta`, `publica`, `privada`. Dentro de un módulo de red, `aws_vpc.esta` se lee solo; el nombre real lo pone `var.nombre`.

Todavía **no** toques el `main.tf` del módulo raíz: lo harás en la pieza 3.

```bash
terraform fmt -recursive
```

👀 **Qué deberías ver:** `fmt` lista los archivos del módulo que ha reordenado, o nada. Con `-recursive` también entra en `modules/`.

✋ **Sin mirar:** desde el módulo raíz, ¿puedes leer `module.red.aws_vpc.esta.cidr_block`?

<details>
<summary>Comprueba</summary>

No: desde fuera solo se ven los outputs del módulo. Para leer el rango, el módulo tendría que publicarlo en `outputs.tf`.
</details>

**En resumen:** un módulo recibe por variables y devuelve por outputs; lo de dentro queda dentro.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. La red de la pieza 1 sigue creada, y no cuesta nada.

### Pieza 3 — Usar el módulo: sin `moved`, todo se destruye

Si mueves `resource "aws_vpc" "vigia"` dentro de un módulo, su dirección pasa de `aws_vpc.vigia` a `module.red.aws_vpc.esta`. Terraform no sabe que es el mismo recurso: ve uno que desaparece del código (y lo **destruye**) y otro nuevo (y lo **crea**).

**Pruébalo.** Sustituye el `main.tf` del módulo raíz por la llamada al módulo:

```hcl
module "red" {
  source = "./modules/red"
  nombre = "vigia"
}

output "subred_publica" {
  value = module.red.subred_publica_id
}
```

🔮 **Predice:** ¿cuántos recursos quiere destruir, si no has cambiado nada en AWS?

```bash
terraform init
terraform plan | grep Plan:
```

`init` hace falta cada vez que añades un módulo: lo registra en `.terraform/modules/`.

👀 **Qué deberías ver:** `Plan: 8 to add, 0 to change, 8 to destroy.` **Los 8**: para Terraform, `aws_vpc.vigia` ha desaparecido del código y `module.red.aws_vpc.esta` es nuevo. Con una base de datos o una instancia dentro, sería un desastre. **No apliques.**

✋ **Sin mirar:** ¿por qué Terraform no reconoce que es el mismo recurso?

<details>
<summary>Comprueba</summary>

Porque en el estado cada recurso se identifica por su **dirección**, y la dirección cambió. Terraform no compara el contenido para adivinar que son iguales.
</details>

**En resumen:** cambiar la dirección de un recurso, para Terraform, es destruirlo y crear otro.

### Pieza 4 — `moved`: refactorizar sin destruir

Un bloque `moved` le dice a Terraform que un recurso solo ha cambiado de dirección:

```hcl
moved {
  from = aws_vpc.vigia
  to   = module.red.aws_vpc.esta
}
```

En el plan aparece `has moved to`, y el recurso sigue siendo el mismo, con sus ID. Antes se hacía con `terraform state mv` (clase 96), a mano y sin dejar rastro en el código. El bloque `moved` queda en el PR, se revisa y lo aplica también el resto del equipo.

**Pruébalo.** Añade al final de `main.tf` un bloque `moved` por cada recurso:

```hcl
moved {
  from = aws_vpc.vigia
  to   = module.red.aws_vpc.esta
}

moved {
  from = aws_subnet.publica
  to   = module.red.aws_subnet.publica
}
```

Sigue tú con los otros seis: el IGW, las dos tablas de rutas y sus dos asociaciones, y la subred privada. Tienes las direcciones viejas de la pieza 1.

```bash
terraform plan
```

👀 **Qué deberías ver:** `has moved to` en cada recurso y la última línea: `Plan: 0 to add, 0 to change, 0 to destroy.` Si sale algún `destroy`, te falta un `moved` o una dirección está mal escrita. Aplica: no cambia nada en AWS, solo las direcciones del estado.

```bash
terraform apply && terraform state list
```

Ahora todas las direcciones empiezan por `module.red.`.

✋ **Sin mirar:** ¿qué ventaja tiene un bloque `moved` frente a `terraform state mv`?

<details>
<summary>Comprueba</summary>

Que está en el código: se revisa en el PR, queda en el historial de Git y lo aplica cualquiera que tenga el estado viejo. `state mv` es un cambio a mano que nadie ve.
</details>

**En resumen:** `moved` cambia la dirección en el estado sin tocar AWS, y deja rastro en el código.

### Pieza 5 — Módulos del Registry

| `source` | Ejemplo | Versión |
|----------|---------|---------|
| una carpeta local | `"./modules/red"` | la del propio repositorio |
| el Registry público | `"terraform-aws-modules/vpc/aws"` | con `version = "~> 6.0"` |
| un repositorio de Git | `"git::https://github.com/tu-usuario/modulos.git//red?ref=v1.2.0"` | la etiqueta del `ref` |

Los módulos del Registry ahorran mucho trabajo y están muy probados, pero:
- **son grandes:** el de VPC crea 17 recursos con lo mínimo;
- **tienen decenas de opciones** que hay que entender;
- **siguen siendo código de terceros:** se fija su versión, igual que un provider o una action.

Para aprender, y para lo que es tuyo de verdad, un módulo propio y pequeño.

**Pruébalo** (solo planificado). Crea `registro.tf`:

```hcl
module "vpc_del_registro" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name            = "lab-registro"
  cidr            = "10.50.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.50.1.0/24", "10.50.2.0/24"]
  private_subnets = ["10.50.11.0/24", "10.50.12.0/24"]
}
```

🔮 **Predice:** ¿cuántos recursos crea con tan poco?

```bash
terraform init && terraform plan | grep -E "module.vpc_del_registro.*will be created|Plan:"
```

👀 **Qué deberías ver:** unos 17: VPC, subredes, rutas, asociaciones, IGW y alguna pieza más que no pediste a propósito, como la NACL y el security group por defecto. Ábrelo en el Registry (`terraform-aws-modules/vpc/aws`) y mira cuántas variables tiene: más de cien. Por ejemplo, `enable_nat_gateway = true` crearía un NAT Gateway, con su coste (clase 71).

**No apliques**: borra `registro.tf` y haz `terraform init` otra vez.

✋ **Sin mirar:** ¿por qué se fija la versión de un módulo del Registry?

<details>
<summary>Comprueba</summary>

Porque es código de terceros que cambia: sin versión fija, un `init` cualquier día podría traer otra que cree o borre recursos distintos. Como un provider o una action.
</details>

**En resumen:** del Registry, para problemas estándar y con la versión fijada; propio, para lo pequeño y lo tuyo.

## Ahora, en Vigía (20 min)

Haz lo mismo con la red de tu `infra/` de la clase 97, en una rama nueva:
1. Mueve tu red a `infra/modules/red/`, con sus `variables.tf` y `outputs.tf`. Puede ser el módulo de este laboratorio.
2. En `main.tf`, la llamada al módulo, y el SG y la instancia usando sus outputs.
3. Un bloque `moved` por cada recurso que cambió de dirección.
4. `terraform plan` → `0 to add, 0 to change, 0 to destroy`. Si sale algún `destroy`, te falta un `moved` o una dirección está mal escrita.
5. Aplica, commit y PR.

Los bloques `moved` pueden quedarse en el código: no hacen nada una vez aplicados, y sirven a quien tenga un estado viejo. Cuando estés seguro de que nadie lo tiene, puedes borrarlos en otro PR.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `module "red" { source = "./modules/red"  nombre = "vigia" }` | usar un módulo, con sus variables como argumentos |
| `module.red.vpc_id` | leer un output del módulo |
| `moved { from = aws_vpc.vigia  to = module.red.aws_vpc.esta }` | cambiar la dirección sin destruir |
| `terraform init` | hace falta al añadir o cambiar un módulo |
| `terraform fmt -recursive` | formatear también los módulos |
| `source = "terraform-aws-modules/vpc/aws"` + `version = "~> 6.0"` | un módulo del Registry, con versión fijada |
| `variable "x" { default = null }` + `coalesce(var.x, …)` | una variable opcional |

## Rómpelo

1. **Un output que el módulo no tiene.** Usa `module.red.vpc_cidr` en un output del módulo raíz. *Unsupported attribute… This object does not have an attribute named "vpc_cidr"*: desde fuera solo se ve lo que el módulo publica. Añádelo en `modules/red/outputs.tf` si lo necesitas.
2. **Una variable obligatoria sin pasar.** Quita `nombre = "vigia"` de la llamada: *Missing required argument*. Las variables sin `default` son los argumentos obligatorios del módulo.
3. **Un `moved` hacia algo que no existe.** Cambia el `to` de la VPC por `module.red.aws_vpc.otra` y planifica. Terraform hace el movimiento en el estado, pero esa dirección no está en el código: la VPC se **destruye**, se crea `module.red.aws_vpc.esta` desde cero, y las subredes y las rutas salen con `forces replacement` porque cambia su `vpc_id`. Una errata en un `moved` es tan peligrosa como no ponerlo: lee el plan. Deshazlo.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade al módulo una variable `crear_nat` (`bool`, `false` por defecto) que, si vale `true`, cree un NAT Gateway con su IP elástica y la ruta de la subred privada (clase 72). Planifícalo con `true`, sin aplicarlo.

> 🧩 **Ejemplo resuelto:** el reto 1 de la clase 94: `crear_privadas` (`bool`) decidía si se creaban las subredes privadas.

**Ahora tú, con huecos:**
```hcl
variable "crear_nat" {
  type    = ____
  default = ____
}

resource "aws_eip" "nat" {
  count  = var.crear_nat ? ____ : ____
  domain = "vpc"
}

resource "aws_nat_gateway" "esta" {
  count         = var.crear_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.____.id
}
```
Y la ruta `0.0.0.0/0` de la tabla privada hacia `aws_nat_gateway.esta[0].id`, también con `count`.

<details>
<summary>Pista</summary>

El NAT va en la subred **pública** (necesita el IGW). Con `count`, el recurso es una lista: se lee con `[0]`. La ruta, como recurso aparte: `aws_route` con `route_table_id`, `destination_cidr_block` y `nat_gateway_id`. Desde el raíz: `module "red" { … crear_nat = true }`.
</details>

**2.** Publica tu módulo en un repositorio de Git propio con la etiqueta `v1.0.0` y úsalo desde Vigía. ¿Qué ganas y qué pierdes frente a la carpeta local?

> 🧩 **Ejemplo resuelto:** en la clase 84 fijabas cada action por su SHA (`actions/checkout@<sha>`): el workflow usa siempre la misma hasta que alguien la cambia a propósito.

**Ahora tú, con huecos:** `source = "git::https://github.com/<tú>/terraform-modulos.git//____?ref=____"`. Completa: «Gano que… varios repositorios pueden usar ____. Pierdo que, para cambiar el módulo, tengo que…».

<details>
<summary>Pista</summary>

`//red` es la carpeta dentro del repositorio; `?ref=` es la etiqueta. Para crearla: `git tag v1.0.0 && git push origin v1.0.0`. Tras cambiar el `source`, `terraform init`.
</details>

**3.** Lee el `README` del módulo de VPC del Registry y apunta tres variables que no conocías y qué hacen.

> 🧩 **Ejemplo resuelto:** `enable_nat_gateway` (`bool`): crea NAT Gateways para que las subredes privadas salgan a internet. Cuesta dinero.

**Ahora tú, con huecos:** «`____` (tipo `____`): …». Tres líneas así.

<details>
<summary>Pista</summary>

En la página del módulo, la pestaña *Inputs*. Busca alrededor de `single_nat_gateway`, `enable_dns_hostnames` o `create_database_subnet_group`.
</details>

## Destruir al terminar

```bash
cd ~/my-devops-journey/labs/clase-98 && terraform destroy
```

En Vigía no destruyas nada: el refactor no cambió AWS.

## Cierre

En `notas/fase-8/clase-98.md`:

1. ¿Qué es un módulo, y qué ve de él quien lo usa? *(2 líneas. Empieza así: «Una carpeta de Terraform que se usa como una pieza. Quien lo usa solo ve…»)*
2. ¿Qué habría pasado con la red de Vigía si la hubieras movido al módulo sin bloques `moved`? *(2 líneas. Empieza así: «Terraform habría visto los recursos viejos desaparecer…»)*
3. ¿Cuándo usarías un módulo del Registry y cuándo uno propio? *(2 líneas, una por caso.)*
4. **Repaso (clase 97, sin mirar):** ¿qué buscas en un plan antes de aplicar algo que importa recursos? *(1–2 líneas. Empieza así: «Que nada importado salga con…»)*

Después, escríbeme `examíname clase-98`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Una carpeta de archivos de Terraform que se usa como una pieza, con entradas y salidas. Quien lo usa solo ve su interfaz: le pasa valores por sus **variables** y lee sus **outputs**. Sus recursos, sus `locals` y sus nombres internos quedan dentro (`module.red.aws_vpc.esta`).

**2.** Terraform habría visto los recursos viejos desaparecer del código y otros nuevos aparecer en el módulo, así que habría **destruido** la VPC, sus subredes y sus rutas para crear otras iguales. Para eso habría tenido que destruir antes la instancia, con su base de datos y sus datos. Con `moved`, solo cambia la dirección en el estado.

**3.** **Del Registry:** cuando el problema es estándar y el módulo es conocido, mantenido y está bien probado (una VPC multizona con NAT, un clúster de EKS), si entiendes sus opciones y fijas su versión. **Propio:** cuando es algo de tu equipo o pequeño, cuando quieres controlar cada recurso o cuando estás aprendiendo. Un módulo de cien variables para tres recursos es más complejidad que ayuda.

**4.** Que nada importado salga con `-/+` o con `destroy` (eso significaría que el código no coincide con lo que existe) y que los cambios en el sitio sean los esperados, como las etiquetas de `default_tags`.

**Reto 1:** `type = bool`, `default = false`, `count = var.crear_nat ? 1 : 0` y `subnet_id = aws_subnet.publica.id`. La ruta:

```hcl
resource "aws_route" "salida_privada" {
  count                  = var.crear_nat ? 1 : 0
  route_table_id         = aws_route_table.privada.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.esta[0].id
}
```

Con `crear_nat = true`, el plan añade 3 recursos: la IP elástica, el NAT y la ruta.

**Reto 2:** `//red?ref=v1.0.0`. Ganas que varios repositorios (Vigía, otros proyectos, otro equipo) pueden usar **la misma versión probada**, y que un cambio en el módulo no afecta a nadie hasta que sube el `ref`. Pierdes comodidad: para cambiar el módulo tienes que hacer el cambio en su repositorio, crear otra etiqueta y subir el `ref` en Vigía.

**Reto 3:** por ejemplo:
- `single_nat_gateway` (`bool`): un solo NAT para todas las zonas, en lugar de uno por zona; más barato y menos disponible.
- `enable_dns_hostnames` (`bool`): nombres DNS para las instancias de la VPC.
- `database_subnets` (`list(string)`): subredes aparte para bases de datos, con su grupo de subredes para RDS.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| root module / child module | módulo raíz / módulo hijo |
| module source / module version | origen del módulo / versión del módulo |
| module inputs and outputs | entradas y salidas del módulo |
| refactoring / moved block | refactorizar / bloque `moved` |
| public module registry | registro público de módulos |

🎙️ *"I extracted Vigía's network into a small module with clear inputs and outputs, and used moved blocks so the refactor produced zero changes in AWS. I use registry modules with pinned versions when the problem is standard and I understand their options."*

## Siguiente

[Clase 99 — Secretos, import y drift](clase-99-secretos-import-drift.md)
