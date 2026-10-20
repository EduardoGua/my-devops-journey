# Clase 95 — Dependencias y ciclo de vida

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

> 💡 **La idea de hoy:** Terraform decide el orden a partir de las **referencias** entre bloques: un **grafo** que recorre siguiendo las flechas al crear (en paralelo todo lo que puede) y al revés al destruir. `depends_on` solo hace falta cuando una dependencia no se ve en el código. Y el bloque **`lifecycle`** controla los momentos peligrosos: crear antes de destruir, impedir que algo se destruya o ignorar los cambios hechos fuera.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El orden escrito a mano de `borrar-vpc.sh` (clase 71).
> - Una EC2 con `web.yaml` como *user-data* e IMDSv2 (clase 72); el SG solo para tu IP (clase 73).
> - Recrear un servidor en lugar de repararlo (clase 78); los grupos de logs con retención (clase 76).
> - Las variables, `terraform.tfvars`, los `data` y el parámetro de SSM de la AMI (clases 93 y 94).

> 🔤 **Palabras nuevas de hoy:**
> - **grafo de dependencias**: los recursos y las flechas entre ellos, sacadas de las referencias.
> - **dependencia implícita / explícita**: la que sale de una referencia / la que declaras con `depends_on`.
> - **`lifecycle`**: el bloque que cambia cómo se crea, se reemplaza o se destruye un recurso.
> - **`create_before_destroy`**: al reemplazar, crear el nuevo antes de borrar el viejo.
> - **`prevent_destroy`**: hacer fallar cualquier plan que destruya el recurso.
> - **`-replace`**: reemplazar un recurso a propósito, aunque el código no haya cambiado.
> - **ciclo de dependencias**: A depende de B y B de A; Terraform no puede ordenarlos.

## Objetivo

- Entender el **grafo de dependencias**: cómo decide Terraform en qué orden crear y destruir, y qué hace en paralelo.
- Saber cuándo hace falta **`depends_on`** y cuándo sobra.
- Controlar los reemplazos con el bloque **`lifecycle`**:
  - `create_before_destroy`;
  - `prevent_destroy`;
  - `ignore_changes`;
  - `replace_triggered_by`.
- Forzar un reemplazo con `-replace` y entender `user_data_replace_on_change`, que usará Vigía.

## Por qué importa

Tu `borrar-vpc.sh` de la clase 71 tenía el orden escrito a mano: instancias, NAT, IP elásticas, subredes… Terraform lo calcula solo, a partir de las referencias entre bloques.

Pero hay cambios que obligan a **reemplazar**, y ahí se decide si tu servicio se queda unos segundos sin red o si borras una base de datos por un descuido. El bloque `lifecycle` es tu control sobre esos momentos.

## Costo esperado

> 💰 **Unos 0,02 USD:** una t3.micro durante unos 30 minutos, en la VPC por defecto, más un security group, un grupo de logs y un bucket vacío, gratis.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan la misma web.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 35 min); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre. Entre los dos días, destruye (mira "Destruir al terminar") para no pagar la instancia, y vuelve a aplicar al empezar.

```bash
mkdir -p ~/my-devops-journey/labs/clase-95 && cd ~/my-devops-journey/labs/clase-95
cp ../clase-72/web.yaml .
echo "mi_ip = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform.tfvars
```

## Las piezas

### Pieza 1 — El grafo

Cada referencia (`aws_security_group.web.id` dentro de la instancia) es una **flecha** del grafo:
- **al crear**, Terraform sigue las flechas: primero lo que no depende de nada, y en paralelo todo lo que puede;
- **al destruir**, las recorre al revés.

```
data.aws_vpc.defecto ◄── aws_security_group.web ◄── aws_vpc_security_group_ingress_rule.http
                                   ▲
data.aws_ssm_parameter.ubuntu ◄── aws_instance.web
```

`terraform graph` lo dibuja en formato DOT (el de Graphviz). Las líneas con `->` son las flechas.

**Pruébalo.** Para un laboratorio de media hora, la VPC por defecto basta. `main.tf` (los bloques `lifecycle` y `user_data_replace_on_change` los verás en las piezas 3 y 4):

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
    tags = { Proyecto = "lab", Clase = "95" }
  }
}

variable "mi_ip" {
  description = "Tu IP pública con /32"
  type        = string
}

variable "ami_parametro" {
  description = "Parámetro de SSM con la AMI de Ubuntu 26.04"
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_vpc" "defecto" {
  default = true
}

data "aws_ssm_parameter" "ubuntu" {
  name = var.ami_parametro
}

resource "aws_security_group" "web" {
  name_prefix = "lab-tf-web-"
  description = "Lab 95: HTTP solo desde mi IP"
  vpc_id      = data.aws_vpc.defecto.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.mi_ip
}

resource "aws_vpc_security_group_egress_rule" "todo" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.web.id]
  user_data                   = file("${path.module}/web.yaml")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "lab-tf-web" }
}

resource "aws_s3_bucket" "importante" {
  bucket_prefix = "lab-tf-importante-"

  lifecycle {
    prevent_destroy = true
  }
}

output "url" {
  value = "http://${aws_instance.web.public_ip}"
}
```

- **Las reglas del SG** son recursos propios (`aws_vpc_security_group_ingress_rule`), que es lo que recomienda hoy el provider. Las reglas dentro del propio security group, la forma antigua, se comportan distinto con el *drift* (clase 99).
- **`insecure_value`:** el valor de un parámetro de SSM, que Terraform marca como sensible por si acaso. Una AMI no es un secreto.

🔮 **Predice:** ¿de qué depende la instancia, y qué se crea en paralelo con ella?

```bash
terraform init && terraform apply
curl -s "$(terraform output -raw url)"
terraform graph | grep -- '->' | grep -v provider
```

👀 **Qué deberías ver:** en el `apply`, varias líneas `Creating…` a la vez: el bucket y el security group primero; después, las dos reglas y la instancia, en paralelo, porque todas dependen solo del SG. El `curl` devuelve tu página (si aún no responde, espera un minuto: cloud-init está instalando nginx). En el grafo, la instancia apunta al SG y al parámetro de la AMI; el bucket no está en el camino de nadie.

✋ **Sin mirar:** al destruir, ¿qué se borra antes, la instancia o su security group?

<details>
<summary>Comprueba</summary>

La instancia: al destruir, el grafo se recorre al revés, y la instancia depende del SG.
</details>

**En resumen:** las referencias forman el grafo; Terraform crea siguiendo las flechas, en paralelo lo independiente, y destruye al revés.

### Pieza 2 — `depends_on`: solo cuando no hay referencia

Si un recurso **necesita** que otro exista pero no usa ninguno de sus atributos, Terraform no puede adivinarlo. El caso típico: una instancia cuyo programa, al arrancar, escribe en un grupo de logs que también crea Terraform. La instancia no cita el grupo, pero si arranca antes de que exista, el programa falla.

```hcl
resource "aws_instance" "vigia" {
  # …
  depends_on = [aws_cloudwatch_log_group.vigia]
}
```

Úsalo solo en esos casos: una referencia normal ya crea la dependencia, y `depends_on` de más vuelve los planes más lentos y conservadores.

**Pruébalo.** Añade un grupo de logs y la dependencia explícita en la instancia:

```hcl
resource "aws_cloudwatch_log_group" "web" {
  name              = "/lab/tf-web"
  retention_in_days = 1
}
```

Y dentro de `aws_instance.web`, al final: `depends_on = [aws_cloudwatch_log_group.web]`.

```bash
terraform plan | grep -E "will be|Plan:"
terraform apply
terraform graph | grep -- '->' | grep log_group
```

👀 **Qué deberías ver:** el plan solo crea el grupo de logs (`Plan: 1 to add, 0 to change`): añadir un `depends_on` no cambia la instancia. En el grafo, una flecha nueva de `aws_instance.web` a `aws_cloudwatch_log_group.web`: desde ahora, al recrearla, Terraform esperará a que el grupo exista.

✋ **Sin mirar:** si la instancia ya cita `aws_security_group.web.id`, ¿hace falta un `depends_on` hacia el SG?

<details>
<summary>Comprueba</summary>

No: la referencia ya crea la dependencia. `depends_on` es solo para dependencias que no se ven en el código.
</details>

**En resumen:** `depends_on` para dependencias ocultas; para lo demás, bastan las referencias.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Destruye (sigue "Destruir al terminar", pero deja el `prevent_destroy` quitado) y, mañana, vuelve a ponerlo y aplica.

### Pieza 3 — `user_data_replace_on_change`: cambiar es recrear

Con **`user_data_replace_on_change = true`**, si cambia el *user-data* se crea **otra instancia**. Sin esa opción, AWS solo cambia el texto guardado, y cloud-init no lo vuelve a ejecutar: la instancia se quedaría con la configuración vieja (clase 72). Es la infraestructura desechable de la clase 78: se sustituye, no se parchea.

🔮 **Predice:** si cambias el texto de la página en `web.yaml`, ¿qué propondrá el plan?

**Pruébalo.** En `web.yaml`, cambia `Hola desde` por `Hola otra vez desde`:

```bash
terraform plan | grep -E "must be replaced|forces replacement|Plan:"
terraform apply
sleep 90; curl -s "$(terraform output -raw url)"
```

👀 **Qué deberías ver:** `# aws_instance.web must be replaced` y, en el *user-data*, `# forces replacement`. Tras aplicar y esperar, la página dice `Hola otra vez desde`, **y la IP es otra**: es otra instancia. Así se actualizará la instancia de Vigía.

✋ **Sin mirar:** sin `user_data_replace_on_change`, ¿qué pasaría al cambiar el *user-data*?

<details>
<summary>Comprueba</summary>

AWS cambiaría el texto guardado, pero cloud-init no lo volvería a ejecutar: la instancia seguiría con la configuración vieja.
</details>

**En resumen:** con `user_data_replace_on_change`, un cambio en el *user-data* crea una instancia nueva.

### Pieza 4 — El bloque `lifecycle`: crear antes de destruir

| Opción | Qué hace | Cuándo |
|--------|----------|--------|
| `create_before_destroy = true` | al reemplazar, crea el nuevo **antes** de borrar el viejo (`+/-` en lugar de `-/+`) | un security group o una plantilla de los que dependen otros: sin hueco sin servicio. Necesita nombres que no choquen, con `name_prefix` |
| `prevent_destroy = true` | cualquier plan que destruya el recurso **falla** | lo que no se puede perder: el bucket del estado (clase 96), una base de datos (Rómpelo 1) |
| `ignore_changes = [tags["Owner"]]` | no corrige esos atributos si cambian fuera de Terraform | atributos que gestiona otra herramienta u otro equipo (Rómpelo 2) |
| `replace_triggered_by = [aws_x.y]` | reemplaza este recurso cuando cambia otro | por ejemplo, recrear una instancia cuando cambia su configuración en otro recurso (reto 2) |

🔮 **Predice:** la descripción de un SG no se puede editar. Si la cambias, ¿verás `-/+` o `+/-`?

**Pruébalo.** Cambia la `description` del security group a `"Lab 95: web"`:

```bash
terraform plan | grep -E "replacement|Plan:"
terraform apply
```

👀 **Qué deberías ver:** `+/-` (*create replacement and then destroy*) para el SG, por su `create_before_destroy`. Se crea el nuevo, la instancia se pasa a él y, al final, se borra el viejo: la instancia nunca se queda sin SG. Sin esa opción, Terraform intentaría borrar primero un SG que la instancia está usando. Para que no choquen los dos SG a la vez, el nombre es un `name_prefix`: Terraform añade un sufijo único.

✋ **Sin mirar:** ¿por qué `create_before_destroy` necesita nombres que no choquen?

<details>
<summary>Comprueba</summary>

Porque durante un momento existen los dos recursos, el viejo y el nuevo; con el mismo nombre, el segundo no se podría crear.
</details>

**En resumen:** `create_before_destroy` evita el hueco; `prevent_destroy`, la pérdida; `ignore_changes`, la pelea con otros.

### Pieza 5 — Reemplazar a propósito

`terraform apply -replace=aws_instance.web` reemplaza un recurso aunque el código no haya cambiado. Úsalo cuando una instancia esté rota por algo que el código no ve. Es el sustituto del antiguo `terraform taint`.

**Pruébalo** (con ver el plan basta; no apliques):

```bash
terraform plan -replace=aws_instance.web | grep -E "replaced|Plan:"
```

👀 **Qué deberías ver:** `# aws_instance.web will be replaced, as requested` y `Plan: 1 to add, 0 to change, 1 to destroy.`

✋ **Sin mirar:** una instancia está rota pero su código no ha cambiado. ¿Cómo la recreas con Terraform?

<details>
<summary>Comprueba</summary>

Con `terraform apply -replace=aws_instance.web`.
</details>

**En resumen:** `-replace` recrea a propósito lo que el código no ve roto.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `terraform graph \| grep -- '->'` | las flechas del grafo |
| `depends_on = [aws_x.y]` | una dependencia que no se ve en el código |
| `lifecycle { create_before_destroy = true }` | crear el nuevo antes de borrar el viejo (`+/-`) |
| `lifecycle { prevent_destroy = true }` | ningún plan puede destruirlo |
| `lifecycle { ignore_changes = [tags["Owner"]] }` | no corregir esos atributos |
| `lifecycle { replace_triggered_by = [terraform_data.x] }` | reemplazar cuando cambia otro |
| `user_data_replace_on_change = true` | un *user-data* nuevo, una instancia nueva |
| `terraform apply -replace=aws_instance.web` | reemplazar a propósito |
| `name_prefix` en lugar de `name` | nombres que no chocan al reemplazar |

## Rómpelo

**1. Lo que no se puede destruir:**

```bash
terraform destroy
```

`Instance cannot be destroyed` (en Terraform, *instance* es cualquier recurso) y `Resource aws_s3_bucket.importante has lifecycle.prevent_destroy set`. Ni siquiera llega a preguntarte: el plan entero se rechaza. Es la protección que tendrá el bucket del estado en la clase 96.

**2. Un atributo que cambia otro.** Añade a mano una etiqueta a la instancia:

```bash
ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=lab-tf-web Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources "$ID" --tags Key=Owner,Value=otro-equipo
terraform plan | grep -B2 -A2 Owner
```

Terraform propone **quitarla**: no está en el código. Si de verdad otro equipo gestiona esa etiqueta, añade a la instancia:

```hcl
  lifecycle {
    ignore_changes = [tags["Owner"]]
  }
```

Vuelve a planificar: `No changes`. Úsalo con cuidado: lo ignorado deja de estar bajo tu control.

**3. Un `depends_on` imposible.** Añade al security group `depends_on = [aws_instance.web]`. ¿Qué dice `terraform validate`, o el `plan`? *Cycle*: la instancia depende del SG y el SG de la instancia. Terraform no puede ordenarlo. Quítalo.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escribe en tus notas el orden exacto en que `terraform destroy` borraría estos recursos (sin el bucket), y compruébalo al destruir.

> 🧩 **Ejemplo resuelto:** la pieza 1: al crear, primero el SG; después, las reglas y la instancia, en paralelo.

**Ahora tú, con huecos:** «Primero se destruyen, a la vez, ____ y ____, porque…; después, ____ y ____. Los `data` ____».

<details>
<summary>Pista</summary>

Al destruir, el grafo se recorre al revés. Mira las líneas `Destroying…` y `Destruction complete` de tu `destroy`. No olvides el grupo de logs de la pieza 2.
</details>

**2.** Reemplaza la instancia cuando cambie un archivo, aunque no sea su *user-data*.

> 🧩 **Ejemplo resuelto:** la pieza 3: `user_data_replace_on_change` recrea la instancia cuando cambia **su** *user-data*.

**Ahora tú, con huecos:**
```hcl
resource "terraform_data" "version_web" {
  input = filesha256("____")
}
# … dentro de aws_instance.web:
  lifecycle {
    replace_triggered_by = [____.version_web]
  }
```
Completa: «Consigo reemplazar la instancia cuando cambia…, no solo el *user-data*».

<details>
<summary>Pista</summary>

`filesha256()` calcula la huella de un archivo: si el archivo cambia, cambia el `input`, y con él el `terraform_data`. Pruébalo con `web.yaml` o con cualquier otro archivo de la carpeta.
</details>

**3.** ¿Qué atributos de `aws_instance` obligan a reemplazarla y cuáles se cambian en el sitio?

> 🧩 **Ejemplo resuelto:** en la clase 93, cambiar el `cidr_block` de una subred obligaba a reemplazarla (`-/+`).

**Ahora tú, con huecos:** cambia cada uno en el código, haz `terraform plan` sin aplicar y completa: «`instance_type`: ____. Las etiquetas: ____. `ami`: ____».

<details>
<summary>Pista</summary>

Busca en el plan `~ update in-place` o `-/+` con `# forces replacement`. Cambiar el tipo de instancia sí se puede en el sitio, pero AWS tiene que pararla y arrancarla.
</details>

## Destruir al terminar

`prevent_destroy` no te deja: quita ese bloque `lifecycle` del bucket y destruye.

```bash
terraform destroy
aws ec2 describe-instances --filters Name=tag:Clase,Values=95 Name=instance-state-name,Values=running --query 'length(Reservations)'
```

Debe dar `0`.

## Cierre

En `notas/fase-8/clase-95.md`:

1. ¿Cómo decide Terraform en qué orden crear los recursos, y qué puede hacer en paralelo? *(2 líneas. Empieza así: «Con un grafo construido a partir de las referencias: si un bloque cita un atributo de otro,… En paralelo hace…»)*
2. ¿Cuándo hace falta `depends_on`? Pon un ejemplo de Vigía. *(2 líneas. Empieza así: «Cuando un recurso necesita que otro exista pero no cita ninguno de sus atributos. En Vigía,…»)*
3. ¿Qué hacen `create_before_destroy`, `prevent_destroy` y `user_data_replace_on_change`? *(3 líneas, una por opción.)*
4. **Repaso (clase 94, sin mirar):** ¿por qué es más seguro `for_each` que `count` para una colección con nombres? *(1–2 líneas. Empieza así: «Con `count`, cada copia se identifica por su posición…»)*

Después, escríbeme `examíname clase-95`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Con un grafo construido a partir de las **referencias**: si un bloque cita un atributo de otro, depende de él. Crea siguiendo las flechas y destruye al revés. Todo lo que no depende entre sí lo hace en paralelo (por defecto, hasta 10 operaciones a la vez).

**2.** Cuando un recurso necesita que otro exista, pero no cita ninguno de sus atributos, así que no hay referencia de la que deducirlo. En Vigía: la instancia necesita que existan los grupos de logs `/vigia/api` y `/vigia/checker` antes de arrancar (el driver `awslogs` falla sin ellos) y que su rol tenga ya los permisos. Pero no los cita: `depends_on = [aws_cloudwatch_log_group.vigia, aws_iam_role_policy.…]`.

**3.**
- **`create_before_destroy`:** al reemplazar, crea el nuevo antes de borrar el viejo, así que no hay hueco (necesita nombres que no choquen).
- **`prevent_destroy`:** hace fallar cualquier plan que destruya el recurso.
- **`user_data_replace_on_change`:** hace que un cambio en el *user-data* recree la instancia, en lugar de solo cambiar un texto que cloud-init ya no volvería a leer.

**4.** Con `count`, cada copia se identifica por su posición, y quitar un elemento del principio mueve a los demás y provoca reemplazos. Con `for_each`, cada copia se identifica por su clave: solo cambia lo que tocas.

**Reto 1:** primero, a la vez, la **instancia** y las **reglas** del SG, porque dependen del SG (y la instancia, del grupo de logs); después, el **SG** y el **grupo de logs**. Los `data` no se destruyen.

**Reto 2:** `filesha256("web.yaml")` (u otro archivo) y `terraform_data.version_web`. Consigues reemplazar la instancia cuando cambia **cualquier cosa** que tú elijas, no solo el texto del *user-data*: por ejemplo, el contenido de otro archivo que la instancia descarga al arrancar.

**Reto 3:** `instance_type`: **en el sitio** (`~`), con la instancia parada y arrancada por AWS. Las etiquetas: **en el sitio**. `ami`: **obliga a reemplazarla** (`forces replacement`): el disco raíz sale de la AMI.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| dependency graph | grafo de dependencias |
| implicit / explicit dependency | dependencia implícita / explícita |
| create before destroy | crear antes de destruir |
| lifecycle meta-argument | metaargumento de ciclo de vida |
| dependency cycle | ciclo de dependencias |

🎙️ *"Terraform orders resources from the references between them and creates independent ones in parallel. I only use depends_on for hidden dependencies, protect critical resources with prevent_destroy, and use create_before_destroy where a replacement must not leave a gap."*

## Siguiente

[Clase 96 — El estado: backend S3 con bloqueo](clase-96-estado.md)
