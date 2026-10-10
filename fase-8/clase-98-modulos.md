# Clase 98 — Módulos

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** B. Vigía en código

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

## Teoría

### Un módulo por dentro

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

### De dónde salen los módulos

| `source` | Ejemplo | Versión |
|----------|---------|---------|
| una carpeta local | `"./modules/red"` | la del propio repositorio |
| el Registry público | `"terraform-aws-modules/vpc/aws"` | con `version = "~> 6.0"` |
| un repositorio de Git | `"git::https://github.com/tu-usuario/modulos.git//red?ref=v1.2.0"` | la etiqueta del `ref` |

Los módulos del Registry ahorran mucho trabajo y están muy probados, pero:
- **son grandes:** el de VPC crea 17 recursos con lo mínimo (paso 4);
- **tienen decenas de opciones** que hay que entender;
- **siguen siendo código de terceros:** se fija su versión, igual que un provider o una action.

Para aprender, y para lo que es tuyo de verdad, un módulo propio y pequeño.

### Refactorizar sin destruir: `moved`

Si mueves `resource "aws_vpc" "vigia"` dentro de un módulo, su dirección pasa de `aws_vpc.vigia` a `module.red.aws_vpc.esta`. Terraform no sabe que es el mismo recurso: ve uno que desaparece del código (y lo **destruye**) y otro nuevo (y lo **crea**).

Un bloque `moved` se lo dice:

```hcl
moved {
  from = aws_vpc.vigia
  to   = module.red.aws_vpc.esta
}
```

En el plan aparece `has moved to`, y el recurso sigue siendo el mismo, con sus ID. Antes se hacía con `terraform state mv`, a mano y sin dejar rastro en el código. El bloque `moved` queda en el PR, se revisa y lo aplica también el resto del equipo.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-98/modules/red && cd ~/my-devops-journey/labs/clase-98
```

### 1. El "antes": una red sin módulo (10 min)

`versions.tf`:

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

Y `main.tf`, la red de la clase 71 en Terraform, tal como la escribiría cualquiera la primera vez:

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
```

### 2. El módulo `red` (25 min)

Mueve esos recursos a `modules/red/main.tf` y generalízalos. Los nombres, el rango y la zona salen de variables, y los rangos de las subredes se calculan con `cidrsubnet` (clase 94):

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

### 3. Usar el módulo, sin y con `moved` (20 min)

Sustituye el `main.tf` del módulo raíz por la llamada al módulo:

```hcl
module "red" {
  source = "./modules/red"
  nombre = "vigia"
}

output "subred_publica" {
  value = module.red.subred_publica_id
}
```

```bash
terraform init
terraform plan | grep Plan:
```

🔮 **Predice:** ¿cuántos recursos quiere destruir, si no has cambiado nada en AWS? **Los 8**, y crear otros 8. Para Terraform, `aws_vpc.vigia` ha desaparecido del código y `module.red.aws_vpc.esta` es nuevo. Con una base de datos o una instancia dentro, sería un desastre. **No apliques.**

Añade al final de `main.tf` un bloque `moved` por cada recurso:

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

Sigue tú con los otros seis: el IGW, las dos tablas de rutas y sus dos asociaciones, y la subred privada.

```bash
terraform plan
```

Busca `has moved to` en cada recurso y la última línea: `Plan: 0 to add, 0 to change, 0 to destroy.` Aplica: no cambia nada en AWS, solo las direcciones del estado.

```bash
terraform apply && terraform state list
```

### 4. Un módulo del Registry, solo planificado (10 min)

Crea `registro.tf`:

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

```bash
terraform init && terraform plan | grep -E "module.vpc_del_registro.*will be created|Plan:"
```

🔮 **Predice:** ¿cuántos recursos crea con tan poco? Unos 17: VPC, subredes, rutas, asociaciones, IGW y alguna pieza más que no pediste a propósito, como la NACL y el security group por defecto. Ábrelo en el Registry (`terraform-aws-modules/vpc/aws`) y mira cuántas variables tiene: más de cien. Por ejemplo, `enable_nat_gateway = true` crearía un NAT Gateway, con su coste (clase 71).

**No apliques**: borra `registro.tf` y haz `terraform init` otra vez.

## Ahora, en Vigía (20 min)

Haz lo mismo con la red de tu `infra/` de la clase 97, en una rama nueva:
1. Mueve tu red a `infra/modules/red/`, con sus `variables.tf` y `outputs.tf`. Puede ser el módulo de este laboratorio.
2. En `main.tf`, la llamada al módulo, y el SG y la instancia usando sus outputs.
3. Un bloque `moved` por cada recurso que cambió de dirección.
4. `terraform plan` → `0 to add, 0 to change, 0 to destroy`. Si sale algún `destroy`, te falta un `moved` o una dirección está mal escrita.
5. Aplica, commit y PR.

Los bloques `moved` pueden quedarse en el código: no hacen nada una vez aplicados, y sirven a quien tenga un estado viejo. Cuando estés seguro de que nadie lo tiene, puedes borrarlos en otro PR.

## Rómpelo

1. **Un output que el módulo no tiene.** Usa `module.red.vpc_cidr` en un output del módulo raíz. *Unsupported attribute… This object does not have an attribute named "vpc_cidr"*: desde fuera solo se ve lo que el módulo publica. Añádelo en `modules/red/outputs.tf` si lo necesitas.
2. **Una variable obligatoria sin pasar.** Quita `nombre = "vigia"` de la llamada: *Missing required argument*. Las variables sin `default` son los argumentos obligatorios del módulo.
3. **Un `moved` hacia algo que no existe.** Cambia el `to` de la VPC por `module.red.aws_vpc.otra` y planifica. Terraform hace el movimiento en el estado, pero esa dirección no está en el código: la VPC se **destruye**, se crea `module.red.aws_vpc.esta` desde cero, y las subredes y las rutas salen con `forces replacement` porque cambia su `vpc_id`. Una errata en un `moved` es tan peligrosa como no ponerlo: lee el plan. Deshazlo.

## Reto

1. Añade al módulo una variable `crear_nat` (`bool`, `false` por defecto) que, si vale `true`, cree un NAT Gateway con su IP elástica y la ruta de la subred privada (clase 72). Usa `count = var.crear_nat ? 1 : 0`. Planifícalo con `true`, sin aplicarlo.
2. Publica tu módulo en un repositorio de Git propio con la etiqueta `v1.0.0` y úsalo desde Vigía con `source = "git::https://github.com/<tú>/terraform-modulos.git//red?ref=v1.0.0"`. ¿Qué ganas y qué pierdes frente a la carpeta local?
3. Lee el `README` del módulo de VPC del Registry y apunta tres variables que no conocías y qué hacen.

## Destruir al terminar

```bash
cd ~/my-devops-journey/labs/clase-98 && terraform destroy
```

En Vigía no destruyas nada: el refactor no cambió AWS.

## Cierre

En `notas/fase-8/clase-98.md`:

1. ¿Qué es un módulo, y qué ve de él quien lo usa?
2. ¿Qué habría pasado con la red de Vigía si la hubieras movido al módulo sin bloques `moved`?
3. ¿Cuándo usarías un módulo del Registry y cuándo uno propio?
4. **Repaso (clase 97, sin mirar):** ¿qué buscas en un plan antes de aplicar algo que importa recursos?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Una carpeta de archivos de Terraform que se usa como una pieza, con entradas y salidas. Quien lo usa solo ve su interfaz: le pasa valores por sus **variables** y lee sus **outputs**. Sus recursos, sus `locals` y sus nombres internos quedan dentro (`module.red.aws_vpc.esta`).

**2.** Terraform habría visto los recursos viejos desaparecer del código y otros nuevos aparecer en el módulo, así que habría **destruido** la VPC, sus subredes y sus rutas para crear otras iguales. Para eso habría tenido que destruir antes la instancia, con su base de datos y sus datos. Con `moved`, solo cambia la dirección en el estado.

**3.** **Del Registry:** cuando el problema es estándar y el módulo es conocido, mantenido y está bien probado (una VPC multizona con NAT, un clúster de EKS), si entiendes sus opciones y fijas su versión. **Propio:** cuando es algo de tu equipo o pequeño, cuando quieres controlar cada recurso o cuando estás aprendiendo. Un módulo de cien variables para tres recursos es más complejidad que ayuda.

**4.** Que nada importado salga con `-/+` o con `destroy` (eso significaría que el código no coincide con lo que existe) y que los cambios en el sitio sean los esperados, como las etiquetas de `default_tags`.
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
