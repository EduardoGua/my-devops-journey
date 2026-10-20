# Clase 94 — Variables, outputs, locals y tipos

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

> 💡 **La idea de hoy:** una configuración con todo escrito a mano solo sirve para un caso. Con **variables** (con tipo, descripción y validación), la misma sirve para otra región, otra cuenta u otro entorno; con **`locals`** das nombre a los cálculos que repites; con **outputs** devuelves resultados; y con **`for_each`**, diez subredes son un mapa de diez líneas. Las variables son también la frontera entre el código, que va a Git, y los datos de tu entorno.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los providers, los `data`, `terraform console`, `cidrsubnet` y las etiquetas (clase 93).
> - Las variables de entorno y `export` (clase 07).
> - Las listas, los diccionarios y los booleanos de Python (clases 40 y 41), y sus comprensiones: las expresiones `for` de Terraform se parecen mucho.
> - JSON (clase 47).

> 🔤 **Palabras nuevas de hoy:**
> - **variable de entrada**: un bloque `variable`, con tipo, descripción, valor por defecto y validación.
> - **`terraform.tfvars`**: el archivo con los valores de tu entorno; Terraform lo carga solo.
> - **`TF_VAR_<nombre>`**: dar valor a una variable desde el entorno.
> - **`locals`**: valores calculados con nombre, para no repetir una expresión.
> - **`map(object({…}))`**: un mapa de objetos con campos tipados, la colección típica de `for_each`.
> - **`for_each`**, **`each.key`** y **`each.value`**: crear una copia del recurso por elemento; su clave y su valor.
> - **expresión `for`**: construir una lista o un mapa recorriendo otro, como una comprensión de Python.

## Objetivo

- Parametrizar una configuración con **variables** con tipo, descripción, valor por defecto y **validación**.
- Darles valor de cuatro formas: valor por defecto, `terraform.tfvars`, `-var` y `TF_VAR_…`.
- Calcular valores intermedios con **`locals`** y devolver resultados con **outputs**.
- Usar los tipos complejos (`list`, `map`, `object`) y crear varios recursos con **`for_each`**.
- Entender por qué `count` con una lista puede destruir lo que no tocaste.

## Por qué importa

Una configuración con todo escrito a mano solo sirve para un caso. Con variables, la misma sirve para otra región, otra cuenta u otro entorno (desarrollo y producción) sin copiar archivos. Y con `for_each`, diez subredes son un mapa de diez líneas, no diez bloques casi iguales.

Las variables son también la frontera entre el código, que va a Git, y los datos de **tu** entorno, como tu IP o tus ID, que no tienen por qué ir.

## Costo esperado

> 💰 **0 USD.** Una VPC y tres subredes.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Terraform lee **todos** los `.tf` de la carpeta como si fueran uno; por convención, la configuración se reparte en `versions.tf`, `variables.tf`, `main.tf` y `outputs.tf`.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 35 min, sin crear nada en AWS); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-94 && cd ~/my-devops-journey/labs/clase-94
```

## Las piezas

### Pieza 1 — Variables y tipos

```hcl
variable "cidr" {
  description = "Rango de la VPC, de /16 a /24"
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr)) && tonumber(split("/", var.cidr)[1]) <= 24
    error_message = "cidr debe ser un rango válido de /16 a /24, por ejemplo 10.40.0.0/16."
  }
}
```

- **`description`:** escríbela siempre. Es la documentación de tu configuración.
- **`type`:** valida el tipo antes de tocar nada.
- **Sin `default`,** la variable es **obligatoria**.
- **`validation`:** reglas propias, con tu mensaje de error. `can(…)` devuelve `false` si la expresión falla, en lugar de romper.
- **`sensitive = true`:** Terraform no la muestra en el plan ni en la salida, pero **sí** la guarda en el estado (clase 99).

| Tipo | Ejemplo |
|------|---------|
| `string`, `number`, `bool` | `"t3.small"`, `7`, `true` |
| `list(string)` | `["api", "checker"]`: ordenada, admite repetidos |
| `set(string)` | sin orden y sin repetidos (lo que pide `for_each`) |
| `map(string)` | `{ Proyecto = "vigia" }`: claves y valores del mismo tipo |
| `object({…})` | `{ numero = number, publica = bool }`: campos con su tipo |
| `map(object({…}))` | un mapa de objetos: perfecto para `for_each` |

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
}
```

`variables.tf`:

```hcl
variable "nombre" {
  description = "Prefijo de los nombres de los recursos"
  type        = string
  default     = "lab-tf"
}

variable "cidr" {
  description = "Rango de la VPC, de /16 a /24"
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr)) && tonumber(split("/", var.cidr)[1]) <= 24
    error_message = "cidr debe ser un rango válido de /16 a /24, por ejemplo 10.40.0.0/16."
  }
}

variable "subredes" {
  description = "Subredes: nombre → número de la /24 dentro de la VPC, y si es pública"
  type = map(object({
    numero  = number
    publica = bool
  }))
  default = {
    publica-a = { numero = 1, publica = true }
    privada-a = { numero = 2, publica = false }
  }
}

variable "etiquetas" {
  description = "Etiquetas que se añaden a todos los recursos"
  type        = map(string)
  default     = {}
}
```

```bash
terraform init && terraform validate
terraform console
```

Dentro de la consola (sal con `exit`):

```
var.cidr
var.subredes
var.subredes["publica-a"].numero
keys(var.subredes)
```

👀 **Qué deberías ver:** `Success!`; `"10.40.0.0/16"`; el mapa de las dos subredes con sus objetos; `1`; y `["privada-a", "publica-a"]`: las claves de un mapa salen ordenadas alfabéticamente.

✋ **Sin mirar:** ¿qué pasa con una variable que no tiene `default`?

<details>
<summary>Comprueba</summary>

Es obligatoria: si no le das valor, Terraform te lo pregunta, o falla con `-input=false` (Rómpelo 3).
</details>

**En resumen:** cada variable con `description`, `type` y, si hace falta, `validation`; los tipos complejos describen colecciones.

### Pieza 2 — `locals` y `for_each`

- **`locals`:** valores calculados que usas varias veces, para no repetir la expresión. Por ejemplo, las etiquetas comunes o el nombre de la imagen de Vigía.
- **`for_each`:** una copia del recurso por cada elemento de un mapa o un conjunto. Dentro, `each.key` es el nombre (`publica-a`) y `each.value`, el objeto (`{ numero = 1, publica = true }`).

| | `count = 3` | `for_each = { a = …, b = … }` |
|---|---|---|
| Cada copia se llama | `aws_subnet.esta[0]`, `[1]`, `[2]` | `aws_subnet.esta["a"]`, `["b"]` |
| Si quitas un elemento del principio | las de detrás **cambian de índice** y Terraform las reemplaza | solo desaparece ese elemento |
| Úsalo para | "N copias iguales", o `count = var.activar ? 1 : 0` | cualquier colección de cosas con nombre |

La regla práctica: **`for_each` por defecto**, `count` solo para "cuántas" o "sí o no" (lo verás en el Rómpelo 2).

**Pruébalo.** `main.tf`:

```hcl
locals {
  etiquetas = merge({ Proyecto = "lab", Clase = "94" }, var.etiquetas)
  prefijo   = tonumber(split("/", var.cidr)[1])
}

data "aws_availability_zones" "zonas" {
  state = "available"
}

resource "aws_vpc" "lab" {
  cidr_block = var.cidr
  tags       = merge(local.etiquetas, { Name = "${var.nombre}-vpc" })
}

resource "aws_subnet" "esta" {
  for_each = var.subredes

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = cidrsubnet(var.cidr, 24 - local.prefijo, each.value.numero)
  availability_zone       = data.aws_availability_zones.zonas.names[0]
  map_public_ip_on_launch = each.value.publica
  tags                    = merge(local.etiquetas, { Name = "${var.nombre}-${each.key}" })
}
```

`cidrsubnet(var.cidr, 24 - local.prefijo, n)` da la *n*-ésima `/24` de la VPC, sea cual sea su prefijo.

🔮 **Predice:** ¿cómo se llamarán en el plan las dos subredes, y qué rangos tendrán?

```bash
terraform fmt && terraform validate && terraform plan
```

👀 **Qué deberías ver:** `Plan: 3 to add`: la VPC, `aws_subnet.esta["privada-a"]` con `10.40.2.0/24` y `aws_subnet.esta["publica-a"]` con `10.40.1.0/24`, cada una por su **clave**. No apliques todavía.

✋ **Sin mirar:** dentro de un recurso con `for_each = var.subredes`, ¿qué es `each.key` y qué `each.value`?

<details>
<summary>Comprueba</summary>

`each.key` es la clave del mapa (`publica-a`); `each.value`, su valor (el objeto con `numero` y `publica`).
</details>

**En resumen:** `locals` para no repetir; `for_each` sobre un mapa, con `each.key` y `each.value`; cada copia, por su clave.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-94`.

### Pieza 3 — Outputs y expresiones `for`, con tus valores

Un **output** es lo que la configuración **devuelve**: lo ves al terminar el `apply` y con `terraform output`; lo usan los scripts (`terraform output -raw url`); y en la clase 98 es la forma en que un módulo entrega sus valores a quien lo usa. Las **expresiones `for`** recorren una colección y construyen otro mapa o una lista, con un `if` opcional para filtrar: como una comprensión de Python.

**Pruébalo.** `outputs.tf`:

```hcl
output "vpc_id" {
  value = aws_vpc.lab.id
}

output "subredes" {
  description = "El ID de cada subred, por su nombre"
  value       = { for nombre, subred in aws_subnet.esta : nombre => subred.id }
}

output "rangos_publicos" {
  description = "Los rangos de las subredes públicas"
  value       = [for nombre, subred in aws_subnet.esta : subred.cidr_block if var.subredes[nombre].publica]
}
```

Y tus valores en `terraform.tfvars`, que se carga solo:

```hcl
nombre = "lab-tf"
subredes = {
  publica-a = { numero = 1, publica = true }
  privada-a = { numero = 2, publica = false }
  privada-b = { numero = 3, publica = false }
}
```

```bash
terraform apply
terraform output
terraform output -json subredes | jq
terraform output -raw vpc_id; echo
```

👀 **Qué deberías ver:** `Apply complete! Resources: 4 added` (la VPC y tres subredes); los tres outputs, con `rangos_publicos = ["10.40.1.0/24"]`; el mapa de subredes como JSON; y el ID de la VPC sin comillas: `-raw` lo deja listo para un script, como `aws ec2 describe-vpcs --vpc-ids "$(terraform output -raw vpc_id)"`.

✋ **Sin mirar:** ¿qué hace el `if` al final de una expresión `for`?

<details>
<summary>Comprueba</summary>

Filtra: solo entran en el resultado los elementos que cumplen la condición.
</details>

**En resumen:** los outputs devuelven resultados (`-raw` para scripts); las expresiones `for` transforman y filtran colecciones.

### Pieza 4 — Las cuatro fuentes de un valor

De dónde sale el valor de una variable, de menos a más prioridad:

| Fuente | Ejemplo | Para qué |
|--------|---------|----------|
| `default` | en el bloque `variable` | un valor razonable para casi todos |
| `TF_VAR_<nombre>` | `export TF_VAR_mi_ip=203.0.113.7/32` | valores del pipeline o secretos que no quieres en un archivo |
| `terraform.tfvars` (o `*.auto.tfvars`) | `cidr = "10.50.0.0/16"` | los valores de **tu** entorno; se carga solo |
| `-var` / `-var-file` | `terraform plan -var 'cidr=10.60.0.0/16'` | una prueba puntual, otro entorno |

Sin valor para una obligatoria, Terraform te la pregunta. En un pipeline, con `-input=false`, falla.

🔮 **Predice:** con `TF_VAR_nombre`, ¿qué nombre gana: el del entorno o el de `terraform.tfvars`?

**Pruébalo:**

```bash
terraform plan -var 'nombre=prueba' | grep -E "Name|Plan:"
TF_VAR_nombre=desde-entorno terraform plan | grep -E "Name|Plan:"
```

👀 **Qué deberías ver:** con `-var`, los `Name` cambian a `prueba-…` (y el plan propone 4 cambios): `-var` gana a todos. Con `TF_VAR_nombre`, `No changes`: gana `terraform.tfvars`, que tiene más prioridad que `TF_VAR_`.

✋ **Sin mirar:** ¿qué fuente gana a todas las demás?

<details>
<summary>Comprueba</summary>

`-var` (o `-var-file`) en la línea de órdenes.
</details>

**En resumen:** `default` < `TF_VAR_` < `terraform.tfvars` < `-var`; gana la última que se aplica.

### Pieza 5 — Funciones en la consola

La consola (clase 93) es el sitio para probar una función antes de escribirla en el código.

🔮 **Predice:** `merge({ a = 1 }, { b = 2 }, { a = 3 })`, ¿con qué valor de `a` se queda?

**Pruébalo:**

```bash
terraform console
```

```
keys(var.subredes)
{ for k, v in var.subredes : k => v.numero }
cidrsubnet("10.40.0.0/16", 8, 3)
merge({ a = 1 }, { b = 2 }, { a = 3 })
lookup(var.etiquetas, "Equipo", "sin equipo")
var.nombre == "lab-tf" ? "es el de siempre" : "es otro"
format("%s-%03d", "web", 7)
jsonencode({ Version = "2012-10-17" })
```

👀 **Qué deberías ver:** las tres claves; `{ "privada-a" = 2, "privada-b" = 3, "publica-a" = 1 }`; `"10.40.3.0/24"`; `{ a = 3, b = 2 }`: con claves repetidas, `merge` se queda con la **última**; `"sin equipo"` (el valor por defecto de `lookup`); `"es el de siempre"`; `"web-007"`; y `"{\"Version\":\"2012-10-17\"}"`: `jsonencode` convierte un objeto de Terraform en JSON. Así escribirás las políticas de IAM de Vigía, sin *heredocs*.

✋ **Sin mirar:** ¿qué devuelve `lookup(mapa, "clave", "otro")` si la clave no existe?

<details>
<summary>Comprueba</summary>

`"otro"`, el valor por defecto que le das.
</details>

**En resumen:** `merge`, `lookup`, `format`, `jsonencode`, el `? :` y las expresiones `for`: pruébalas en la consola.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `variable "x" { description, type, default, validation {…} }` | una variable con tipo y validación |
| `var.x` · `local.y` · `each.key` · `each.value` | citar variables, locals y la copia actual |
| `locals { etiquetas = merge(…) }` | valores calculados con nombre |
| `for_each = var.mapa` | una copia por elemento, por su clave |
| `{ for k, v in mapa : k => v.campo }` · `[for x in lista : x if cond]` | expresiones `for` |
| `output "x" { value = … }` · `terraform output -raw x` | devolver y leer resultados |
| `terraform.tfvars` · `TF_VAR_x` · `-var 'x=…'` · `-var-file=archivo` | dar valores |
| `merge` · `lookup` · `format` · `jsonencode` · `cidrsubnet` · `can` | funciones útiles |
| `-input=false` | no preguntar nada (en pipelines) |

## Rómpelo

**1. Una validación que falla:**

```bash
terraform plan -var 'cidr=10.40.0.0/28'
terraform plan -var 'cidr=esto-no-es-un-rango'
```

Tu `error_message` en los dos casos: la validación se comprueba **antes** de llamar a AWS.

**2. `count` y el índice que se mueve.** Crea `prueba-count.tf`:

```hcl
variable "grupos" {
  type    = list(string)
  default = ["web", "api", "db"]
}

resource "aws_security_group" "con_count" {
  count  = length(var.grupos)
  name   = "lab-tf-${var.grupos[count.index]}"
  vpc_id = aws_vpc.lab.id
}
```

Aplícalo. Después quita `"web"` de la lista (`default = ["api", "db"]`) y planifica.

🔮 **Predice:** ¿cuántos cambios propone, si solo quitaste uno? Tres. `[0]` pasa de `web` a `api` y `[1]` de `api` a `db`: el nombre de un SG obliga a reemplazarlo, así que los recrea, y `[2]` se destruye.

Ahora cámbialo a `for_each = toset(var.grupos)` con `name = "lab-tf-${each.key}"`, aplica con los tres grupos y quita otra vez `"web"`: solo se destruye `web`. Borra el archivo y aplica para limpiar.

**3. Una variable obligatoria en un pipeline.** Quita el `default` de `nombre`, borra `nombre` de `terraform.tfvars` y lanza `terraform plan -input=false`. *No value for required variable*: en CI no hay nadie que conteste. Deshazlo.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade una variable `crear_privadas` de tipo `bool` y haz que las subredes privadas solo existan si vale `true`.

> 🧩 **Ejemplo resuelto:** el output `rangos_publicos` de la pieza 3 filtra con `if var.subredes[nombre].publica`.

**Ahora tú, con huecos:**
```hcl
variable "crear_privadas" {
  description = "Si se crean las subredes privadas"
  type        = ____
  default     = true
}
# … y en aws_subnet.esta:
  for_each = { for nombre, s in var.subredes : nombre => s if s.____ || var.____ }
```
Pruébalo con `terraform plan -var 'crear_privadas=false'`.

<details>
<summary>Pista</summary>

Una subred entra si es pública **o** si quieres privadas. El plan debe proponer destruir solo las privadas.
</details>

**2.** Añade un output `resumen` que devuelva una sola cadena, por ejemplo `"lab-tf: 3 subredes, 1 pública"`.

> 🧩 **Ejemplo resuelto:** `format("%s-%03d", "web", 7)` de la pieza 5 da `"web-007"`: `%s` es un texto y `%d`, un número.

**Ahora tú, con huecos:**
```hcl
output "resumen" {
  value = format("%s: %d subredes, %d pública", var.____, length(aws_subnet.esta),
                 length([for s in var.subredes : s if s.____]))
}
```

<details>
<summary>Pista</summary>

`length()` cuenta los elementos de una lista o un mapa. Para contar solo las públicas, primero fíltralas con una expresión `for`.
</details>

**3.** Crea `desarrollo.tfvars` con otro `cidr` y otro `nombre`, y planifica con él. ¿Qué te falta para tener desarrollo y producción a la vez?

> 🧩 **Ejemplo resuelto:** tu `terraform.tfvars` de la pieza 3.

**Ahora tú, con huecos:** `desarrollo.tfvars` con `cidr = "10.____.0.0/16"` y `nombre = "lab-____"`, y `terraform plan -var-file=____`. Completa: «Me falta ____, porque con un solo estado, aplicar desarrollo…».

<details>
<summary>Pista</summary>

Mira qué propone el plan: ¿crear algo nuevo al lado, o cambiar lo que ya existe? Lo resolverás en la clase 96.
</details>

## Destruir al terminar

```bash
terraform destroy
```

`terraform.tfvars` no contiene nada privado en este laboratorio: puedes subirlo. En Vigía, con tu IP y tus ID, irá a `.gitignore`, y subirás solo un `terraform.tfvars.example`.

## Cierre

En `notas/fase-8/clase-94.md`:

1. ¿En qué orden de prioridad se aplican `default`, `terraform.tfvars`, `TF_VAR_` y `-var`? *(1 línea, de menos a más. Empieza así: «`default` → …»)*
2. ¿Para qué sirven `locals` y para qué los outputs? *(2 líneas. Empieza así: «`locals`, para dar nombre a valores calculados que… Los outputs, para…»)*
3. Explica con tu ejemplo del Rómpelo 2 por qué `for_each` es más seguro que `count` para una colección con nombres. *(2 líneas. Empieza así: «Con `count`, cada copia se identifica por su posición, así que al quitar `web`… Con `for_each`,…»)*
4. **Repaso (clase 93, sin mirar):** ¿qué diferencia hay entre un bloque `resource` y uno `data`? *(1–2 líneas. Empieza así: «Un `resource` crea y gestiona algo…»)*

Después, escríbeme `examíname clase-94`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** De menos a más prioridad: `default` → `TF_VAR_<nombre>` → `terraform.tfvars` → `*.auto.tfvars` → `-var` y `-var-file`, en el orden en que los escribas. Gana el último que se aplica.

**2.** **`locals`:** dar nombre a valores calculados que se usan varias veces (las etiquetas comunes, un prefijo, el nombre completo de una imagen), para escribir la expresión una vez. **Outputs:** devolver resultados al terminar (la URL, un ID) para leerlos tú o un script (`terraform output -raw`) y, en los módulos, para pasar valores a quien los usa.

**3.** Con `count`, cada copia se identifica por su **posición**. Al quitar un elemento del principio, los de detrás cambian de índice y Terraform cree que han cambiado, así que los reemplaza (tres cambios por quitar uno). Con `for_each`, cada copia se identifica por su **clave**: quitar `web` solo destruye `web`.

**4.** Un `resource` crea y gestiona algo, y lo destruye en un `destroy`. Un `data` solo consulta algo que ya existe y no se hace responsable de ello.

**Reto 1:** `type = bool` y:

```hcl
for_each = { for nombre, s in var.subredes : nombre => s if s.publica || var.crear_privadas }
```

**Reto 2:** `var.nombre` y `s.publica`; con tus valores, `"lab-tf: 3 subredes, 1 pública"`.

**Reto 3:** el plan propone **cambiar** la VPC y las subredes que ya existen, no crear otras al lado: falta **un estado distinto para cada entorno**. Con un solo estado, aplicar desarrollo destruiría producción. Se resuelve con una carpeta (o un `key` del backend) por entorno, o con *workspaces* (clase 96).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| input variable / variable definitions file | variable de entrada / archivo de valores (`.tfvars`) |
| local value | valor local |
| output value | valor de salida |
| complex types: list, map, object | tipos complejos: lista, mapa, objeto |
| for expression | expresión `for` |

🎙️ *"I parametrize configurations with typed, validated variables and keep environment values in tfvars files that never reach Git. For collections I use for_each with meaningful keys instead of count, so removing one element never recreates the others."*

## Siguiente

[Clase 95 — Dependencias y ciclo de vida](clase-95-dependencias-y-ciclo-de-vida.md)
