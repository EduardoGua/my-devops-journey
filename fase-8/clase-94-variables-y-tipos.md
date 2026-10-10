# Clase 94 — Variables, outputs, locals y tipos

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

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

## Teoría

### Variables

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

De dónde sale el valor, de menos a más prioridad:

| Fuente | Ejemplo | Para qué |
|--------|---------|----------|
| `default` | en el bloque `variable` | un valor razonable para casi todos |
| `terraform.tfvars` (o `*.auto.tfvars`) | `cidr = "10.50.0.0/16"` | los valores de **tu** entorno; se carga solo |
| `TF_VAR_<nombre>` | `export TF_VAR_mi_ip=203.0.113.7/32` | valores del pipeline o secretos que no quieres en un archivo |
| `-var` / `-var-file` | `terraform plan -var 'cidr=10.60.0.0/16'` | una prueba puntual, otro entorno |

Sin valor para una obligatoria, Terraform te la pregunta. En un pipeline, con `-input=false`, falla.

### Tipos

| Tipo | Ejemplo |
|------|---------|
| `string`, `number`, `bool` | `"t3.small"`, `7`, `true` |
| `list(string)` | `["api", "checker"]`: ordenada, admite repetidos |
| `set(string)` | sin orden y sin repetidos (lo que pide `for_each`) |
| `map(string)` | `{ Proyecto = "vigia" }`: claves y valores del mismo tipo |
| `object({…})` | `{ numero = number, publica = bool }`: campos con su tipo |
| `map(object({…}))` | un mapa de objetos: perfecto para `for_each` |

### `locals` y outputs

- **`locals`:** valores calculados que usas varias veces, para no repetir la expresión. Por ejemplo, las etiquetas comunes o el nombre de la imagen de Vigía.
- **`output`:**
  - lo que la configuración **devuelve**: lo ves al terminar el `apply` y con `terraform output`;
  - lo usan los scripts: `terraform output -raw url`;
  - en la clase 98, son la forma en que un módulo entrega sus valores a quien lo usa.

### `for_each` frente a `count`

Los dos crean varias copias de un recurso:

| | `count = 3` | `for_each = { a = …, b = … }` |
|---|---|---|
| Cada copia se llama | `aws_subnet.esta[0]`, `[1]`, `[2]` | `aws_subnet.esta["a"]`, `["b"]` |
| Si quitas un elemento del principio | las de detrás **cambian de índice** y Terraform las reemplaza | solo desaparece ese elemento |
| Úsalo para | "N copias iguales", o `count = var.activar ? 1 : 0` | cualquier colección de cosas con nombre |

La regla práctica: **`for_each` por defecto**, `count` solo para "cuántas" o "sí o no".

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-94 && cd ~/my-devops-journey/labs/clase-94
```

### 1. Tres archivos (20 min)

Terraform lee **todos** los `.tf` de la carpeta como si fueran uno. Por convención:

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

`main.tf`:

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

Y `outputs.tf`:

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

- **Dentro del recurso con `for_each`:** `each.key` es el nombre (`publica-a`) y `each.value`, el objeto (`{ numero = 1, publica = true }`).
- **Las expresiones `for`** de los outputs recorren el mapa de subredes y construyen otro mapa, o una lista filtrada con `if`.
- **`cidrsubnet(var.cidr, 24 - local.prefijo, n)`:** la *n*-ésima `/24` de la VPC, sea cual sea su prefijo.

```bash
terraform init && terraform fmt && terraform validate && terraform plan
```

🔮 **Predice:** ¿cómo se llaman en el plan las dos subredes? `aws_subnet.esta["privada-a"]` y `aws_subnet.esta["publica-a"]`, por su clave. ¿Y sus rangos? `10.40.1.0/24` y `10.40.2.0/24`.

### 2. Tus valores en `terraform.tfvars` (10 min)

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
terraform output -raw vpc_id
```

`-raw` devuelve el texto sin comillas, listo para un script: `aws ec2 describe-vpcs --vpc-ids "$(terraform output -raw vpc_id)"`.

### 3. Las cuatro fuentes de un valor (15 min)

```bash
terraform plan -var 'nombre=prueba' | grep -E "Name|Plan:"
TF_VAR_nombre=desde-entorno terraform plan | grep -E "Name|Plan:"
```

🔮 **Predice:** con `TF_VAR_nombre`, ¿qué nombre gana: el del entorno o el de `terraform.tfvars`? El de **`terraform.tfvars`**, que tiene más prioridad que `TF_VAR_`. En cambio, `-var` gana a todos. Si la tabla de la teoría te parecía teórica, aquí está en acción.

### 4. Probar funciones en la consola (15 min)

```bash
terraform console
```

```
var.subredes
keys(var.subredes)
{ for k, v in var.subredes : k => v.numero }
cidrsubnet("10.40.0.0/16", 8, 3)
merge({ a = 1 }, { b = 2 }, { a = 3 })
lookup(var.etiquetas, "Equipo", "sin equipo")
var.nombre == "lab-tf" ? "es el de siempre" : "es otro"
format("%s-%03d", "web", 7)
jsonencode({ Version = "2012-10-17" })
```

`merge` con claves repetidas se queda con la **última**. `jsonencode` convierte un objeto de Terraform en JSON: así escribirás las políticas de IAM de Vigía, sin heredocs.

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

1. Añade una variable `crear_privadas` de tipo `bool` y haz que las subredes privadas solo existan si vale `true`. Pista: filtra el mapa del `for_each` con una expresión `for … if`.
2. Añade un output `resumen` que devuelva una sola cadena, por ejemplo `"lab-tf: 3 subredes, 1 pública"`. Pista: `length()` y `format()`.
3. Crea `desarrollo.tfvars` con otro `cidr` y otro `nombre`, y planifica con `terraform plan -var-file=desarrollo.tfvars`. ¿Qué te falta para tener desarrollo y producción a la vez? Pista: el estado es uno solo (clase 96).

## Destruir al terminar

```bash
terraform destroy
```

`terraform.tfvars` no contiene nada privado en este laboratorio: puedes subirlo. En Vigía, con tu IP y tus ID, irá a `.gitignore`, y subirás solo un `terraform.tfvars.example`.

## Cierre

En `notas/fase-8/clase-94.md`:

1. ¿En qué orden de prioridad se aplican `default`, `terraform.tfvars`, `TF_VAR_` y `-var`?
2. ¿Para qué sirven `locals` y para qué los outputs?
3. Explica con tu ejemplo del Rómpelo 2 por qué `for_each` es más seguro que `count` para una colección con nombres.
4. **Repaso (clase 93, sin mirar):** ¿qué diferencia hay entre un bloque `resource` y uno `data`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** De menos a más prioridad: `default` → `TF_VAR_<nombre>` → `terraform.tfvars` → `*.auto.tfvars` → `-var` y `-var-file`, en el orden en que los escribas. Gana el último que se aplica.

**2.** **`locals`:** dar nombre a valores calculados que se usan varias veces (las etiquetas comunes, un prefijo, el nombre completo de una imagen), para escribir la expresión una vez. **Outputs:** devolver resultados al terminar (la URL, un ID) para leerlos tú o un script (`terraform output -raw`) y, en los módulos, para pasar valores a quien los usa.

**3.** Con `count`, cada copia se identifica por su **posición**. Al quitar un elemento del principio, los de detrás cambian de índice y Terraform cree que han cambiado, así que los reemplaza (tres cambios por quitar uno). Con `for_each`, cada copia se identifica por su **clave**: quitar `web` solo destruye `web`.

**4.** Un `resource` crea y gestiona algo, y lo destruye en un `destroy`. Un `data` solo consulta algo que ya existe y no se hace responsable de ello.

**Reto 1:**

```hcl
for_each = { for nombre, s in var.subredes : nombre => s if s.publica || var.crear_privadas }
```

**Reto 3:** un estado distinto para cada entorno. Con un solo estado, aplicar desarrollo destruiría producción. Se resuelve con una carpeta (o un `key` del backend) por entorno, o con *workspaces* (clase 96).
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
