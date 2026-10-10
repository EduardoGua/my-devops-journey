# Clase 95 — Dependencias y ciclo de vida

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

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

> 💰 **Unos 0,02 USD:** una t3.micro durante unos 30 minutos, en la VPC por defecto, más un security group y un bucket vacío, gratis.

## Teoría

### El grafo

Cada referencia (`aws_security_group.web.id` dentro de la instancia) es una **flecha** del grafo:
- **al crear**, Terraform sigue las flechas: primero lo que no depende de nada, y en paralelo todo lo que puede;
- **al destruir**, las recorre al revés.

```
data.aws_vpc.defecto ◄── aws_security_group.web ◄── aws_vpc_security_group_ingress_rule.http
                                   ▲
data.aws_ssm_parameter.ubuntu ◄── aws_instance.web
```

`terraform graph` lo dibuja en formato DOT (el de Graphviz). Las líneas con `->` son las flechas.

### `depends_on`: solo cuando no hay referencia

Si un recurso **necesita** que otro exista pero no usa ninguno de sus atributos, Terraform no puede adivinarlo. El caso típico: una instancia cuyo programa, al arrancar, escribe en un grupo de logs que también crea Terraform. La instancia no cita el grupo, pero si arranca antes de que exista, el programa falla.

```hcl
resource "aws_instance" "vigia" {
  # …
  depends_on = [aws_cloudwatch_log_group.vigia]
}
```

Úsalo solo en esos casos: una referencia normal ya crea la dependencia, y `depends_on` de más vuelve los planes más lentos y conservadores.

### `lifecycle`

| Opción | Qué hace | Cuándo |
|--------|----------|--------|
| `create_before_destroy = true` | al reemplazar, crea el nuevo **antes** de borrar el viejo (`+/-` en lugar de `-/+`) | un security group o una plantilla de los que dependen otros: sin hueco sin servicio. Necesita nombres que no choquen, con `name_prefix` |
| `prevent_destroy = true` | cualquier plan que destruya el recurso **falla** | lo que no se puede perder: el bucket del estado (clase 96), una base de datos |
| `ignore_changes = [tags["Owner"]]` | no corrige esos atributos si cambian fuera de Terraform | atributos que gestiona otra herramienta u otro equipo |
| `replace_triggered_by = [aws_x.y]` | reemplaza este recurso cuando cambia otro | por ejemplo, recrear una instancia cuando cambia su configuración en otro recurso |

Y fuera del bloque `lifecycle`:
- **`terraform apply -replace=aws_instance.web`:** reemplazar un recurso a propósito, aunque el código no haya cambiado. Es el sustituto del antiguo `terraform taint`.
- **`user_data_replace_on_change = true`** en una instancia: si cambia el *user-data*, se crea **otra instancia**. Sin esa opción, AWS solo cambia el texto guardado, y cloud-init no lo vuelve a ejecutar: la instancia se quedaría con la configuración vieja (clase 72). Es la infraestructura inmutable de la clase 78.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-95 && cd ~/my-devops-journey/labs/clase-95
cp ../clase-72/web.yaml .
```

### 1. Una web con su firewall (20 min)

Para un laboratorio de media hora, la VPC por defecto basta. `main.tf`:

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

```bash
echo "mi_ip = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform.tfvars
terraform init && terraform apply
curl -s "$(terraform output -raw url)"
```

Si la web aún no responde, espera un minuto: cloud-init está instalando nginx.

### 2. El grafo (10 min)

```bash
terraform graph | grep -- '->' | grep -v provider
```

🔮 **Predice:** ¿de qué depende la instancia? Del security group y del parámetro de la AMI. Ni las reglas ni el bucket están en su camino, así que Terraform los creó **en paralelo**: fíjate en el orden de las líneas `Creating…` del `apply`.

### 3. Un cambio que reemplaza la instancia (10 min)

En `web.yaml`, cambia el texto de la página (`Hola desde` por `Hola otra vez desde`) y planifica:

```bash
terraform plan
```

`# aws_instance.web must be replaced`, y en el *user-data*, `# forces replacement`: gracias a `user_data_replace_on_change`. Aplica, espera y comprueba con `curl` que la página cambió **y que la IP también**: es otra instancia. Así se actualizará la instancia de Vigía: se sustituye, no se parchea.

### 4. Crear antes de destruir (10 min)

Cambia la `description` del security group a `"Lab 95: web"`. La descripción de un SG no se puede editar, así que obliga a reemplazarlo.

```bash
terraform plan | grep -E "replacement|Plan:"
```

🔮 **Predice:** ¿`-/+` o `+/-`? `+/-` (*create replacement and then destroy*) para el SG, por su `create_before_destroy`. Se crea el nuevo, la instancia se pasa a él y, al final, se borra el viejo: la instancia nunca se queda sin SG. Sin esa opción, Terraform intentaría borrar primero un SG que la instancia está usando.

Para que no choquen los dos SG a la vez, el nombre es un `name_prefix`: Terraform añade un sufijo único. Aplica.

### 5. Reemplazar a propósito (5 min)

```bash
terraform plan -replace=aws_instance.web | grep -E "replaced|Plan:"
```

`will be replaced, as requested`. Úsalo cuando una instancia esté rota por algo que el código no ve. No apliques: con ver el plan basta.

## Rómpelo

**1. Lo que no se puede destruir:**

```bash
terraform destroy
```

`Instance cannot be destroyed… has lifecycle.prevent_destroy set`. Ni siquiera llega a preguntarte: el plan entero se rechaza. Es la protección que tendrá el bucket del estado en la clase 96.

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

1. Escribe en tus notas el orden exacto en que `terraform destroy` borraría estos recursos (sin el bucket). Compruébalo leyendo las líneas `Destroying…` cuando destruyas.
2. Añade un recurso `terraform_data` con `input = filesha256("web.yaml")` y pon en la instancia `replace_triggered_by = [terraform_data.version_web]`. ¿Qué consigues que no conseguía `user_data_replace_on_change`?
3. Busca en la documentación de `aws_instance` qué atributos obligan a reemplazarla y cuáles se cambian en el sitio. ¿El tipo de instancia (`instance_type`)? ¿Las etiquetas?

## Destruir al terminar

`prevent_destroy` no te deja: quita ese bloque `lifecycle` del bucket y destruye.

```bash
terraform destroy
aws ec2 describe-instances --filters Name=tag:Clase,Values=95 Name=instance-state-name,Values=running --query 'length(Reservations)'
```

Debe dar `0`.

## Cierre

En `notas/fase-8/clase-95.md`:

1. ¿Cómo decide Terraform en qué orden crear los recursos, y qué puede hacer en paralelo?
2. ¿Cuándo hace falta `depends_on`? Pon un ejemplo de Vigía.
3. ¿Qué hacen `create_before_destroy`, `prevent_destroy` y `user_data_replace_on_change`?
4. **Repaso (clase 94, sin mirar):** ¿por qué es más seguro `for_each` que `count` para una colección con nombres?

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

**Reto 1:** las reglas del SG y la instancia, a la vez, porque las dos dependen del SG; después el SG. Los `data` no se destruyen.

**Reto 2:** reemplazar la instancia cuando cambia **cualquier cosa** que tú elijas, no solo el texto del *user-data*. Por ejemplo, el contenido de otro archivo que la instancia descarga al arrancar.
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
