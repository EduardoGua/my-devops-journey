# Clase 93 — Providers, versiones, resources y data

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

> 💡 **La idea de hoy:** Terraform no sabe nada de AWS: lo sabe su **provider**, que se fija con una restricción de versión y un archivo de bloqueo para que mañana se use exactamente la misma. Un bloque **`resource`** crea y gestiona algo; uno **`data`** solo **pregunta** (tu cuenta, las zonas, la AMI más reciente), en lugar de escribir a mano datos que cambian. Y `default_tags` pone las etiquetas en todo, sin repetirlas.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El ciclo `init` → `plan` → `apply` → `destroy`, el estado y `.terraform.lock.hcl` (clase 92).
> - `requirements.txt` con las versiones fijadas (clase 46).
> - El CIDR y el *subnetting* (clase 28); la VPC y sus subredes (clase 71).
> - El parámetro de SSM con la AMI de Ubuntu (clase 72); la etiqueta `Proyecto` en todo (clases 67 y 71).

> 🔤 **Palabras nuevas de hoy:**
> - **restricción de versión**: qué versiones del provider se aceptan; `~> 6.68` es la habitual.
> - **archivo de bloqueo** (`.terraform.lock.hcl`): la versión exacta que se usa, con sus *hashes*.
> - ***data source***: un bloque `data` que consulta algo que ya existe, sin crearlo.
> - **argumento / atributo**: lo que escribes en un bloque / lo que AWS devuelve al crearlo, como `id` o `arn`.
> - **`terraform console`**: una consola para probar expresiones con el estado actual.
> - **`default_tags` / `tags_all`**: etiquetas para todo lo que crea el provider / el resultado en cada recurso.

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

## Cómo va esta clase

Cuatro piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan la misma VPC.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 40 min); el segundo, las **piezas 3 y 4**, el Rómpelo, el reto y el cierre. Puedes dejar la VPC creada entre los dos días: no cuesta nada.

```bash
mkdir -p ~/my-devops-journey/labs/clase-93 && cd ~/my-devops-journey/labs/clase-93
```

## Las piezas

### Pieza 1 — `resource` frente a `data`, y `default_tags`

| | `resource "aws_vpc" "lab"` | `data "aws_availability_zones" "zonas"` |
|---|---|---|
| Qué hace | **crea y gestiona** algo: lo cambia y lo destruye | **consulta** algo que ya existe, sin tocarlo |
| En el estado | sí, como algo suyo | se vuelve a leer en cada `plan` |
| Con `destroy` | lo borra | no le pasa nada |
| Se cita como | `aws_vpc.lab.id` | `data.aws_availability_zones.zonas.names` |

Usos típicos de `data`: tu cuenta (`aws_caller_identity`) y tu región (`aws_region`); las zonas disponibles; la AMI más reciente, desde el parámetro de SSM de Canonical (clase 72); y un recurso que gestiona otra persona u otro equipo, como una VPC compartida.

Con **`default_tags`** en el provider, todo lo que cree lleva esas etiquetas, sin repetirlas. Las etiquetas de cada recurso se suman a ellas, y Terraform enseña el resultado en el atributo `tags_all`. En Vigía, `Proyecto=vigia` en todo, como exige la regla de la fase 6.

**Pruébalo.** Crea `main.tf` (las líneas de `required_version` y `version` las verás en la pieza 3):

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

🔮 **Predice:** ¿cuántos recursos creará?

```bash
terraform init && terraform fmt && terraform validate
terraform plan
terraform apply
terraform output
aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-tf --query 'Vpcs[0].Tags' --output table
```

👀 **Qué deberías ver:** en el plan, `Plan: 2 to add`: la VPC y la subred. Los tres `data` no se crean, se **leen**: aparecen como `Reading…` y `Read complete`. El `vpc_id` de la subred sale `(known after apply)`, porque la VPC todavía no existe. Tras el `apply`, los cuatro outputs (tu cuenta, `us-east-1`, la lista de zonas y el ID de la subred) y, en la tabla, `Name`, `Proyecto` y `Clase`: las dos últimas vienen del provider, sin haberlas escrito en la VPC.

✋ **Sin mirar:** ¿qué le pasa a lo que lee un bloque `data` cuando haces `terraform destroy`?

<details>
<summary>Comprueba</summary>

Nada: un `data` solo consulta. `destroy` borra lo que el estado registra como `resource`.
</details>

**En resumen:** `resource` crea y gestiona; `data` pregunta; `default_tags` etiqueta todo lo del provider.

### Pieza 2 — Referencias, atributos y `terraform console`

Cada recurso tiene **argumentos** (lo que tú escribes, como `cidr_block`) y **atributos** (lo que AWS devuelve al crearlo, como `id` o `arn`). Cuando un bloque cita el atributo de otro (`vpc_id = aws_vpc.lab.id`), Terraform sabe que tiene que crearlos **en ese orden**: es la base del grafo de la clase 95.

`terraform console` evalúa expresiones con el estado actual. Es la forma rápida de comprobar una referencia o una función **antes** de escribirla en el código.

🔮 **Predice:** ¿qué devolverá `cidrsubnet(aws_vpc.lab.cidr_block, 8, 2)`?

**Pruébalo:**

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

👀 **Qué deberías ver:** la lista de zonas (`"us-east-1a"`, `"us-east-1b"`…) y su número (6); `"10.30.0.0/16"`; un mapa con `Clase`, `Name` y `Proyecto`; la zona de la subred, la primera de la lista; `"10.30.2.0/24"`, la tercera `/24` de la VPC, el *subnetting* de la clase 28 hecho por una función; y `"US-EAST-1"`.

✋ **Sin mirar:** ¿qué es `aws_vpc.lab.id`, un argumento o un atributo?

<details>
<summary>Comprueba</summary>

Un atributo: no lo escribes tú, lo devuelve AWS al crear la VPC.
</details>

**En resumen:** `tipo.nombre.atributo` cita a otro recurso (y ordena el grafo); `terraform console` prueba expresiones antes de usarlas.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-93`.

### Pieza 3 — Providers, versiones y el archivo de bloqueo

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

**Pruébalo:**

```bash
terraform providers
grep -A3 'provider "registry.terraform.io/hashicorp/aws"' .terraform.lock.hcl
du -sh .terraform/providers
```

🔮 **Predice:** si cambias la restricción a `~> 6.60` y repites `terraform init`, ¿bajará la versión?

Cámbiala, repite `terraform init` y vuelve a mirar el archivo de bloqueo. Después, deja otra vez `~> 6.68`.

👀 **Qué deberías ver:** `provider[registry.terraform.io/hashicorp/aws] ~> 6.68`; en el archivo de bloqueo, `version = "6.x.y"` (la más reciente que cumple `~> 6.68`), `constraints` y los `hashes`, que permiten comprobar que el binario descargado es el bueno; y varios cientos de MB en `.terraform/providers`. Con `~> 6.60`, la versión **no** cambia: el archivo de bloqueo manda mientras la versión fijada cumpla la nueva restricción. Para cambiarla a propósito: `terraform init -upgrade`.

✋ **Sin mirar:** ¿acepta `~> 6.68` la versión 7.0 del provider?

<details>
<summary>Comprueba</summary>

No: acepta 6.68 y posteriores dentro de la 6, pero no la siguiente versión mayor.
</details>

**En resumen:** la restricción dice qué se acepta; el archivo de bloqueo, qué se usa; `init -upgrade` lo cambia a propósito.

### Pieza 4 — Leer la documentación del Registry

Nadie se sabe de memoria los argumentos de cientos de recursos. La referencia es la página de cada uno en el Registry, con dos secciones: *Argument Reference* (lo que puedes escribir) y *Attribute Reference* (lo que puedes citar).

**Pruébalo.** En registry.terraform.io → `hashicorp/aws` → *Documentation*, busca `aws_subnet`:
- en *Argument Reference*, ¿qué argumento hace que sus instancias reciban IP pública?
- en *Attribute Reference*, ¿qué atributos exporta?

Busca también el data source `aws_ssm_parameter`: lo usarás en la clase 95 para la AMI de Ubuntu, con el parámetro de Canonical de la clase 72.

👀 **Qué deberías ver:** `map_public_ip_on_launch` (el `--map-public-ip-on-launch` de la clase 71); entre los atributos, `id`, `arn` y `owner_id`, además de los argumentos; y en `aws_ssm_parameter`, el argumento `name` y el atributo `value`.

✋ **Sin mirar:** ¿en qué sección de la documentación miras qué puedes citar de un recurso desde otro bloque?

<details>
<summary>Comprueba</summary>

En *Attribute Reference*.
</details>

**En resumen:** *Argument Reference* para escribir un recurso, *Attribute Reference* para citarlo.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `required_version = "~> 1.16"` · `version = "~> 6.68"` | versiones aceptadas de Terraform y del provider |
| `terraform providers` · `terraform init -upgrade` | ver los providers · subir la versión a propósito |
| `provider "aws" { default_tags { tags = {…} } }` | etiquetas para todo |
| `data "aws_caller_identity" "yo" {}` · `data "aws_region" "actual" {}` | tu cuenta · tu región |
| `data "aws_availability_zones" "zonas" { state = "available" }` | las zonas |
| `aws_vpc.lab.id` · `data.aws_availability_zones.zonas.names[0]` | citar un recurso · un data |
| `terraform console` | probar expresiones |
| `cidrsubnet(cidr, bits, n)` · `length(lista)` · `upper(texto)` | funciones útiles |
| registry.terraform.io → *Argument* / *Attribute Reference* | la documentación de cada recurso |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Muestra en un output el `cidr_block` de la VPC por defecto de tu cuenta. ¿Qué pasaría con esa VPC en un `terraform destroy`?

> 🧩 **Ejemplo resuelto:** el `data "aws_availability_zones" "zonas" { state = "available" }` de la pieza 1, con su output.

**Ahora tú, con huecos:**
```hcl
data "aws_vpc" "por_defecto" {
  ____ = true
}

output "vpc_por_defecto" {
  value = data.aws_vpc.____.cidr_block
}
```
Completa: «En un `destroy`, a esa VPC ____, porque…».

<details>
<summary>Pista</summary>

En la documentación del data source `aws_vpc`, busca el argumento que selecciona la VPC por defecto. La VPC por defecto tiene el rango `172.31.0.0/16` (clase 68).
</details>

**2.** Crea una **segunda** subred en la **segunda** zona de la región sin escribir ni el rango ni el nombre de la zona a mano.

> 🧩 **Ejemplo resuelto:** la subred `a` de la pieza 1, y `cidrsubnet(aws_vpc.lab.cidr_block, 8, 2)` de la pieza 2.

**Ahora tú, con huecos:**
```hcl
resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.lab.____
  cidr_block        = cidrsubnet(aws_vpc.lab.cidr_block, 8, ____)
  availability_zone = data.aws_availability_zones.zonas.names[____]
  tags              = { Name = "lab-tf-b" }
}
```

<details>
<summary>Pista</summary>

Las listas empiezan en 0: la segunda zona es la `[1]`. El tercer número de `cidrsubnet` elige qué `/24`: la subred `a` usa la 1 (`10.30.1.0/24`).
</details>

**3.** Lee la guía de actualización de la versión 5 a la 6 del provider de AWS y apunta dos cambios que habrían roto código escrito para la 5.

> 🧩 **Ejemplo resuelto:** en la 6, el atributo `name` del data source `aws_region` deja paso a `region`: por eso el output de la pieza 1 usa `data.aws_region.actual.region`.

**Ahora tú, con huecos:** «Cambio 1: ____. Cambio 2: ____».

<details>
<summary>Pista</summary>

En el Registry, dentro de la documentación del provider, sección *Guides* → *Version 6 Upgrade Guide*. Busca los apartados de recursos que ya conoces: S3, EC2, IAM.
</details>

## Destruir al terminar

```bash
terraform destroy
aws ec2 describe-vpcs --filters Name=tag:Proyecto,Values=lab --query 'length(Vpcs)'
```

Debe dar `0` (si la `lab-vpc` de la fase 6 no está viva). La VPC por defecto del reto 1 no se toca: es un `data`.

## Cierre

En `notas/fase-8/clase-93.md`:

1. ¿Qué diferencia hay entre `version = "~> 6.68"` en el código y la versión de `.terraform.lock.hcl`? ¿Cuál manda? *(2 líneas. Empieza así: «La restricción del código dice qué versiones se aceptan; el archivo de bloqueo, cuál se usa… Manda…»)*
2. ¿Qué diferencia hay entre un bloque `resource` y un bloque `data`? Pon un ejemplo de cada uno para Vigía. *(2 líneas. Empieza así: «Un `resource` crea y gestiona algo:…; un `data` solo consulta… En Vigía:…»)*
3. ¿Para qué sirve `default_tags`, y dónde ves el resultado? *(1–2 líneas. Empieza así: «Para que todos los recursos que crea ese provider lleven… El resultado está en…»)*
4. **Repaso (clase 92, sin mirar):** ¿qué significa `-/+` en un plan y por qué es peligroso? *(1–2 líneas. Empieza así: «Que Terraform destruirá el recurso y creará otro, porque…»)*

Después, escríbeme `examíname clase-93`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La restricción del código dice qué versiones **se aceptan**. El archivo de bloqueo dice cuál se **usa**, exactamente, con sus *hashes*. Manda el archivo de bloqueo mientras su versión cumpla la restricción. Para cambiar de versión hay que pedirlo (`terraform init -upgrade`) y subir el archivo nuevo a Git, de modo que el cambio pasa por un PR.

**2.** Un `resource` crea y gestiona algo: lo cambia, y lo borra en un `destroy`. Un `data` solo consulta algo que ya existe, sin hacerse responsable de ello. En Vigía:
- `resource "aws_instance" "vigia"` y `resource "aws_s3_bucket" "informes"`;
- `data "aws_ssm_parameter" "ubuntu"` para la AMI, y `data "aws_caller_identity"` para el número de cuenta del nombre del bucket.

**3.** Para que todos los recursos que crea ese provider lleven unas etiquetas comunes (`Proyecto`, `Clase`) sin repetirlas en cada bloque, y que nunca se olvide ninguna. El resultado está en el atributo `tags_all` de cada recurso (en el plan, en `terraform console` o en `terraform show`) y, por supuesto, en AWS.

**4.** Que Terraform destruirá el recurso y creará otro en su lugar, porque el cambio no se puede hacer en el sitio (`forces replacement`). Es peligroso porque lo viejo desaparece, con sus datos, y lo nuevo tiene otro ID: una base de datos, un bucket con datos o una IP de la que dependen otros.

**Reto 1:** `default = true` y `data.aws_vpc.por_defecto.cidr_block`, que da `172.31.0.0/16`. En un `destroy`, a esa VPC **no le pasa nada**, porque un `data` solo se lee, y `destroy` solo borra lo que el estado registra como `resource`.

**Reto 2:**

```hcl
resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = cidrsubnet(aws_vpc.lab.cidr_block, 8, 2)
  availability_zone = data.aws_availability_zones.zonas.names[1]
  tags              = { Name = "lab-tf-b" }
}
```

**Reto 3:** respuesta según tu lectura; entre los cambios de la 6 están el `region` de `aws_region`, argumentos de S3 y de EC2 que se retiran o cambian de nombre, y la posibilidad de indicar la región en cada recurso.
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
