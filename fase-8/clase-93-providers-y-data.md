# Clase 93 — Providers, versiones, resources y data

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

## Objetivo

- Entender qué es un **provider**, cómo se fija su versión y para qué sirve `.terraform.lock.hcl`.
- Poner etiquetas a todo con `default_tags`, sin repetirlas en cada recurso.
- Distinguir un bloque **`resource`** (algo que Terraform crea y gestiona) de un bloque **`data`** (algo que solo consulta).
- Referenciar atributos entre bloques y explorarlos con `terraform console`.
- Leer en la documentación del Registry los argumentos y atributos de cualquier recurso.

## Por qué importa

Terraform no sabe nada de AWS: lo sabe su **provider**, un programa aparte que traduce tus bloques en llamadas a la API. Si no fijas su versión, el `init` de mañana puede traer otra versión con cambios, y un pipeline que funcionaba deja de hacerlo.

Los bloques `data` te dejan **preguntar** en lugar de escribir a mano datos que cambian: la AMI más reciente, las zonas de la región, tu número de cuenta. Es la diferencia entre un código que funciona en cualquier cuenta y región y uno que solo funciona en la tuya hoy.

## Costo esperado

> 💰 **0 USD.** Una VPC y una subred, gratis.

## Teoría

### Providers y versiones

```hcl
terraform {
  required_version = "~> 1.16"          # versión de Terraform aceptada
  required_providers {
    aws = {
      source  = "hashicorp/aws"         # dónde está: registry.terraform.io/hashicorp/aws
      version = "~> 6.68"               # qué versiones acepta
    }
  }
}
```

| Restricción | Acepta |
|-------------|--------|
| `= 6.68.0` | solo esa |
| `>= 6.68` | 6.68 o cualquiera posterior, también la 7.0 (arriesgado) |
| `~> 6.68` | 6.68, 6.69… pero **no** la 7.0: el operador "pesimista", lo habitual |
| `~> 6.68.0` | 6.68.x, solo correcciones |

- **`.terraform.lock.hcl`** guarda la versión **exacta** que eligió `init` y sus *hashes*. Con él en Git, todo el equipo y el pipeline usan la misma, hasta que alguien la sube a propósito con `terraform init -upgrade` y revisa el cambio en un PR. Es el `requirements.txt` de Terraform (clase 46).
- **Las versiones mayores** de un provider (de la 5 a la 6) traen cambios incompatibles. Se suben a mano, leyendo su guía de actualización.

### `resource` frente a `data`

| | `resource "aws_vpc" "lab"` | `data "aws_availability_zones" "zonas"` |
|---|---|---|
| Qué hace | **crea y gestiona** algo: lo cambia y lo destruye | **consulta** algo que ya existe, sin tocarlo |
| En el estado | sí, como algo suyo | se vuelve a leer en cada `plan` |
| Con `destroy` | lo borra | no le pasa nada |
| Se cita como | `aws_vpc.lab.id` | `data.aws_availability_zones.zonas.names` |

Usos típicos de `data`:
- tu cuenta (`aws_caller_identity`) y tu región (`aws_region`);
- las zonas disponibles;
- la AMI más reciente, desde el parámetro de SSM de Canonical (clase 72);
- un recurso que gestiona otra persona u otro equipo, como una VPC compartida.

### Referencias y atributos

Cada recurso tiene:
- **argumentos:** lo que tú escribes (`cidr_block`);
- **atributos:** lo que AWS devuelve al crearlo (`id`, `arn`).

Cuando un bloque cita el atributo de otro, Terraform sabe que tiene que crearlos **en ese orden**: es la base del grafo de la clase 95. Para saber qué argumentos y atributos tiene un recurso, la referencia es su página en el Registry: *Argument Reference* y *Attribute Reference*.

### `default_tags`

```hcl
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = { Proyecto = "lab", Clase = "93" }
  }
}
```

Todo lo que cree este provider lleva esas etiquetas, sin repetirlas. Las etiquetas de cada recurso se suman a ellas, y Terraform enseña el resultado en el atributo `tags_all`. En Vigía, `Proyecto=vigia` en todo, como exige la regla de la fase 6.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-93 && cd ~/my-devops-journey/labs/clase-93
```

### 1. Una VPC que pregunta por sus datos (20 min)

Crea `main.tf`:

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
    tags = {
      Proyecto = "lab"
      Clase    = "93"
    }
  }
}

data "aws_caller_identity" "yo" {}

data "aws_region" "actual" {}

data "aws_availability_zones" "zonas" {
  state = "available"
}

resource "aws_vpc" "lab" {
  cidr_block = "10.30.0.0/16"
  tags       = { Name = "lab-tf" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.30.1.0/24"
  availability_zone = data.aws_availability_zones.zonas.names[0]
  tags              = { Name = "lab-tf-a" }
}

output "cuenta" {
  value = data.aws_caller_identity.yo.account_id
}

output "region" {
  value = data.aws_region.actual.region
}

output "zonas" {
  value = data.aws_availability_zones.zonas.names
}

output "subred" {
  value = aws_subnet.a.id
}
```

```bash
terraform init && terraform fmt && terraform validate
terraform plan
```

🔮 **Predice:** ¿cuántos recursos creará? Dos: la VPC y la subred. Los tres `data` no se crean, se **leen**: en el plan aparecen como `Reading…`. Fíjate en el `vpc_id` de la subred: `(known after apply)`, porque la VPC todavía no existe.

```bash
terraform apply
terraform output
aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-tf --query 'Vpcs[0].Tags' --output table
```

La VPC lleva `Name` (del recurso) y también `Proyecto` y `Clase` (del provider), sin haberlas escrito en ella.

### 2. Explorar con `terraform console` (15 min)

```bash
terraform console
```

Dentro, escribe una a una estas expresiones (sal con `exit`):

```
data.aws_availability_zones.zonas.names
length(data.aws_availability_zones.zonas.names)
aws_vpc.lab.cidr_block
aws_vpc.lab.tags_all
aws_subnet.a.availability_zone
cidrsubnet(aws_vpc.lab.cidr_block, 8, 2)
upper(data.aws_region.actual.region)
```

La consola evalúa expresiones con el estado actual. Es la forma rápida de comprobar una referencia o una función **antes** de escribirla en el código. `cidrsubnet("10.30.0.0/16", 8, 2)` devuelve la tercera `/24` de la VPC (`10.30.2.0/24`): el *subnetting* de la clase 28, hecho por una función.

### 3. El provider y su bloqueo (15 min)

```bash
terraform providers
grep -A3 'provider "registry.terraform.io/hashicorp/aws"' .terraform.lock.hcl
du -sh .terraform/providers
```

🔮 **Predice:** ¿qué versión quedó fijada? La 6.x más reciente que cumple `~> 6.68`. Los `hashes` permiten comprobar que el binario descargado es el bueno: si alguien manipulara el Registry, `init` lo detectaría.

Ahora cambia la restricción a `~> 6.60` y repite `terraform init`.

🔮 **Predice:** ¿bajará la versión? No. El archivo de bloqueo manda mientras la versión fijada cumpla la nueva restricción. Para cambiarla a propósito: `terraform init -upgrade`. Deja otra vez `~> 6.68`.

### 4. Leer la documentación (15 min)

En registry.terraform.io → `hashicorp/aws` → *Documentation*, busca `aws_subnet`:
- en *Argument Reference*, ¿qué argumento hace que sus instancias reciban IP pública?
- en *Attribute Reference*, ¿qué atributos exporta?

Busca también el data source `aws_ssm_parameter`. Lo usarás en la clase 95 para la AMI de Ubuntu, con el parámetro de Canonical de la clase 72.

Esta búsqueda la harás en cada recurso nuevo: nadie se sabe de memoria los argumentos de cientos de recursos.

## Rómpelo

**1. Una versión imposible.** Pon `version = "~> 99.0"` y haz `terraform init`. *no available releases match the given constraints*: Terraform no instala nada que no cumpla la restricción. Devuélvela.

**2. Cambiar algo que no se puede cambiar.** Cambia el `cidr_block` de la subred a `10.30.5.0/24` y planifica.

`-/+ destroy and then create replacement`, porque el rango de una subred no se puede cambiar. Con instancias dentro, Terraform tendría que destruirlas antes. No apliques; deshazlo.

**3. Un atributo que no existe:**

```hcl
output "malo" {
  value = aws_vpc.lab.nombre
}
```

`terraform validate` lo para: *Unsupported attribute*. Terraform conoce los atributos de cada recurso gracias al esquema del provider. Quítalo.

## Reto

1. Añade un data source `aws_vpc` con `default = true` y un output con el `cidr_block` de la VPC por defecto de tu cuenta. ¿Qué pasaría con esa VPC en un `terraform destroy`?
2. Crea una **segunda** subred en la **segunda** zona de la región sin escribir ni el rango ni el nombre de la zona a mano: usa `cidrsubnet` y `data.aws_availability_zones.zonas.names[1]`.
3. Lee la guía de actualización de la versión 5 a la 6 del provider de AWS (en la documentación del Registry). Apunta dos cambios que habrían roto código escrito para la 5.

## Destruir al terminar

```bash
terraform destroy
aws ec2 describe-vpcs --filters Name=tag:Proyecto,Values=lab --query 'length(Vpcs)'
```

Debe dar `0` (si la `lab-vpc` de la fase 6 no está viva). La VPC por defecto del Reto 1 no se toca: es un `data`.

## Cierre

En `notas/fase-8/clase-93.md`:

1. ¿Qué diferencia hay entre `version = "~> 6.68"` en el código y la versión de `.terraform.lock.hcl`? ¿Cuál manda?
2. ¿Qué diferencia hay entre un bloque `resource` y un bloque `data`? Pon un ejemplo de cada uno para Vigía.
3. ¿Para qué sirve `default_tags`, y dónde ves el resultado?
4. **Repaso (clase 92, sin mirar):** ¿qué significa `-/+` en un plan y por qué es peligroso?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La restricción del código dice qué versiones **se aceptan**. El archivo de bloqueo dice cuál se **usa**, exactamente, con sus *hashes*. Manda el archivo de bloqueo mientras su versión cumpla la restricción. Para cambiar de versión hay que pedirlo (`terraform init -upgrade`) y subir el archivo nuevo a Git, de modo que el cambio pasa por un PR.

**2.** Un `resource` crea y gestiona algo: lo cambia, y lo borra en un `destroy`. Un `data` solo consulta algo que ya existe, sin hacerse responsable de ello. En Vigía:
- `resource "aws_instance" "vigia"` y `resource "aws_s3_bucket" "informes"`;
- `data "aws_ssm_parameter" "ubuntu"` para la AMI, y `data "aws_caller_identity"` para el número de cuenta del nombre del bucket.

**3.** Para que todos los recursos que crea ese provider lleven unas etiquetas comunes (`Proyecto`, `Clase`) sin repetirlas en cada bloque, y que nunca se olvide ninguna. El resultado está en el atributo `tags_all` de cada recurso (en el plan, en `terraform console` o en `terraform show`) y, por supuesto, en AWS.

**4.** Que Terraform destruirá el recurso y creará otro en su lugar, porque el cambio no se puede hacer en el sitio (`forces replacement`). Es peligroso porque lo viejo desaparece, con sus datos, y lo nuevo tiene otro ID: una base de datos, un bucket con datos o una IP de la que dependen otros.

**Reto 1:** nada: un `data` solo se lee, y `destroy` solo borra lo que el estado registra como `resource`.

**Reto 2:**

```hcl
resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = cidrsubnet(aws_vpc.lab.cidr_block, 8, 2)
  availability_zone = data.aws_availability_zones.zonas.names[1]
  tags              = { Name = "lab-tf-b" }
}
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| provider / registry | proveedor (el plugin) / registro de providers y módulos |
| version constraint / lock file | restricción de versión / archivo de bloqueo |
| data source | fuente de datos |
| attribute reference | referencia a un atributo |
| default tags | etiquetas por defecto |

🎙️ *"Providers are pinned with a pessimistic constraint and the lock file is committed, so everyone and the CI use the exact same version. I use data sources for anything I should look up, like the latest Ubuntu AMI or the availability zones, instead of hardcoding it."*

## Siguiente

[Clase 94 — Variables, outputs, locals y tipos](clase-94-variables-y-tipos.md)
