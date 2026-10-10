# Clase 99 — Secretos, import y drift

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** B. Vigía en código

## Objetivo

- Saber dónde **no** pueden ir los secretos en Terraform:
  - el código y los `.tfvars` versionados;
  - en muchos casos, el propio estado.
- Proteger un secreto con `sensitive` y con un argumento de **solo escritura**.
- Detectar el ***drift***, los cambios hechos fuera de Terraform, y decidir qué hacer: revertir, aceptar o ignorar.
- Descubrir lo que Terraform **no** ve, como una regla de firewall añadida a mano.
- Importar con generación de código (`-generate-config-out`) y dejar de gestionar un recurso sin borrarlo (`removed`).

## Por qué importa

Es el último criterio de salida de la fase: *explicar qué pasa si alguien cambia a mano un recurso que maneja Terraform*. En un equipo pasa constantemente:
- alguien abre un puerto "un momento" para depurar;
- alguien sube la retención de los logs desde la consola;
- un servicio de AWS cambia una etiqueta.

Saber leer el *drift* y decidir qué hacer con él es parte del trabajo diario. Igual que saber que el estado **no** es un lugar seguro para los secretos, aunque esté en un bucket privado.

## Costo esperado

> 💰 **0 USD.** Un grupo de logs, dos security groups vacíos y dos parámetros de SSM estándar, gratis.

## Teoría

### Secretos: tres sitios donde se escapan

| Dónde | El problema | Qué hacer |
|-------|-------------|-----------|
| **El código** (`password = "secreto123"`) | va a Git, para siempre (clase 22) | nunca. Que llegue por variable |
| **Un `.tfvars` versionado** | igual: va a Git | `terraform.tfvars` en `.gitignore`, o el valor desde `TF_VAR_` o desde un gestor de secretos |
| **El estado** | Terraform guarda **todos** los atributos, también los secretos, en texto claro (Rómpelo 3 de la clase 96) | bucket privado y cifrado, pocos con acceso y, si se puede, que el secreto no pase por Terraform |

Herramientas para lo que sí tiene que pasar por Terraform:
- **`sensitive = true`** en una variable o en un output: no se muestra en el plan ni en la salida, aparece como `(sensitive value)`. Pero **sí** se guarda en el estado.
- **Argumentos de solo escritura** (*write-only*, desde Terraform 1.11), como `value_wo` en `aws_ssm_parameter`: el valor llega a AWS, pero **no se guarda** en el estado. Como Terraform no lo recuerda, para cambiarlo se sube un número de versión (`value_wo_version`).
- **Que no pase por Terraform:** es lo que hace Vigía, que genera su contraseña de PostgreSQL **dentro** de la instancia (clase 78). Otra opción es guardar el secreto en Secrets Manager o en Parameter Store y que la aplicación lo lea con su rol.

### *Drift*: cuando la realidad y el código se separan

Antes de cada `plan`, Terraform **refresca**: pregunta a AWS por cada recurso del estado. Si algo cambió fuera:

| Comando | Qué propone |
|---------|-------------|
| `terraform plan` | **volver** a lo que dice el código |
| `terraform plan -refresh-only` | solo enseñar qué cambió fuera (*Objects have changed outside of Terraform*) |
| `terraform apply -refresh-only` | **aceptar** la realidad en el estado, sin tocar AWS. Si el código no cambia, el siguiente `plan` volverá a proponer revertir |

Ante un *drift*, hay tres respuestas:
1. **Revertir:** `terraform apply`. Lo normal si fue un error o un cambio temporal.
2. **Aceptar:** cambiar el código para que diga lo mismo que la realidad, y aplicar. El cambio pasa a estar revisado y versionado.
3. **Ignorar ese atributo:** `ignore_changes` (clase 95), si de verdad lo gestiona otro.

### Lo que Terraform no ve

Terraform solo compara lo que **está en su estado**. Con las reglas de un security group en recursos aparte (`aws_vpc_security_group_ingress_rule`), cada regla es un recurso, y una regla añadida a mano no es de nadie: Terraform no la ve.

Con las reglas **dentro** del propio security group (`ingress { … }`), Terraform gestiona el conjunto entero, y cualquier regla de más aparece en el plan para quitarla. Lo probarás en el paso 3.

La forma recomendada sigue siendo la de recursos aparte, porque es más clara y evita conflictos. Pero significa que hace falta otra vigilancia para lo que Terraform no gestiona, como AWS Config (clase 76) o el `verify-aws.sh` de la v3, que comprueba que no haya nada abierto a `0.0.0.0/0`.

### Importar y dejar de gestionar

| Necesidad | Herramienta |
|-----------|-------------|
| adoptar algo que existe | un bloque **`import`** (clase 97) |
| que Terraform **escriba** el código de lo importado | `terraform plan -generate-config-out=generado.tf`: un punto de partida que siempre hay que limpiar |
| la forma antigua, sin dejar rastro en el código | `terraform import <dirección> <id>` |
| dejar de gestionar algo **sin borrarlo** de AWS | un bloque **`removed`** con `destroy = false`. Sustituye a `terraform state rm`, y queda en el PR |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-99 && cd ~/my-devops-journey/labs/clase-99
```

### 1. El laboratorio (15 min)

`main.tf`:

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
    tags = { Proyecto = "lab", Clase = "99" }
  }
}

variable "secreto" {
  description = "Un secreto de prueba"
  type        = string
  sensitive   = true
}

data "aws_vpc" "defecto" {
  default = true
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/lab/clase-99"
  retention_in_days = 7
}

# Reglas en recursos aparte: Terraform solo vigila LAS SUYAS
resource "aws_security_group" "sueltas" {
  name   = "lab-tf-reglas-sueltas"
  vpc_id = data.aws_vpc.defecto.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.sueltas.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "203.0.113.7/32"
}

# Reglas dentro del propio SG: Terraform vigila EL CONJUNTO
resource "aws_security_group" "dentro" {
  name   = "lab-tf-reglas-dentro"
  vpc_id = data.aws_vpc.defecto.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["203.0.113.7/32"]
  }
}

# El secreto en el estado…
resource "aws_ssm_parameter" "clasico" {
  name  = "/lab/clase-99/clasico"
  type  = "SecureString"
  value = var.secreto
}

# …y fuera de él: un argumento de solo escritura
resource "aws_ssm_parameter" "solo_escritura" {
  name             = "/lab/clase-99/solo-escritura"
  type             = "SecureString"
  value_wo         = var.secreto
  value_wo_version = 1
}
```

El secreto llega por el entorno, no por un archivo:

```bash
export TF_VAR_secreto="no-lo-subas-123"
terraform init && terraform apply
```

🔮 **Predice:** ¿qué muestra el plan del `value` de los parámetros? `(sensitive value)`: la variable es sensible, y Terraform la tapa en todas partes, también en lo que se calcula a partir de ella.

### 2. ¿Dónde está el secreto? (10 min)

```bash
terraform state pull | jq '.resources[] | select(.type == "aws_ssm_parameter") | {nombre: .name, value: .instances[0].attributes.value}'
aws ssm get-parameter --name /lab/clase-99/solo-escritura --with-decryption --query Parameter.Value --output text
```

- **El parámetro `clasico`:** `"no-lo-subas-123"`, **legible** en el estado. `sensitive` lo tapó en el plan, no en el estado.
- **El de solo escritura:** `value` está vacío en el estado. AWS sí lo tiene: la segunda orden lo devuelve.

Esa es la diferencia que importa.

Para cambiarlo, como Terraform no recuerda el valor, sube `value_wo_version` a `2` y aplica.

### 3. *Drift* (25 min)

**Un cambio a mano.** Alguien sube la retención desde la consola:

```bash
aws logs put-retention-policy --log-group-name /lab/clase-99 --retention-in-days 30
terraform plan
terraform plan -refresh-only
```

🔮 **Predice:**
- **`plan`:** `retention_in_days = 30 -> 7`. Quiere **volver** al código.
- **`plan -refresh-only`:** *Objects have changed outside of Terraform*, `7 -> 30`. Es lo que pasó fuera.

Decide:
- **revertir:** `terraform apply`;
- **o aceptar:** cambia el código a `30` y aplica.

Haz una de las dos y comprueba que el siguiente `plan` dice `No changes`.

**Una puerta abierta a mano.** Alguien abre el SSH a todo internet en los dos SG:

```bash
for n in sueltas dentro; do
  SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=lab-tf-reglas-$n --query 'SecurityGroups[0].GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr 0.0.0.0/0
done
terraform plan
```

🔮 **Predice:** ¿en cuál de los dos lo detecta?
- **`dentro`:** Terraform propone quitar la regla del 22 (`- from_port = 22`): gestiona el conjunto entero.
- **`sueltas`:** **nada**. La regla nueva no es de ningún recurso de su estado, así que no existe para él.

Aplica: el SG `dentro` vuelve a estar limpio, y el `sueltas` sigue con el 22 abierto a todo internet. Bórrala a mano:

```bash
SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=lab-tf-reglas-sueltas --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 revoke-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr 0.0.0.0/0
```

Por eso el `verify-aws.sh` de la v3 comprueba los SG de verdad, y no lo que dice el código.

### 4. Importar con código generado (15 min)

Alguien creó a mano un grupo de logs:

```bash
aws logs create-log-group --log-group-name /lab/a-mano
cat > importar.tf <<'EOF'
import {
  to = aws_cloudwatch_log_group.a_mano
  id = "/lab/a-mano"
}
EOF
terraform plan -generate-config-out=generado.tf
cat generado.tf
```

Terraform escribió el bloque `resource` con todos los atributos que leyó, incluidos los que no hace falta poner, como `tags_all` o `kms_key_id = null`. **Límpialo**:
- quita lo calculado;
- pon una retención (`retention_in_days = 0` es "para siempre", clase 76);
- muévelo a `main.tf`.

Aplica y borra `importar.tf`.

### 5. Dejar de gestionarlo sin borrarlo (10 min)

Ese grupo de logs, al final, lo gestiona otro equipo. Que Terraform se olvide de él **sin borrarlo**: quita su bloque `resource` y añade:

```hcl
removed {
  from = aws_cloudwatch_log_group.a_mano

  lifecycle {
    destroy = false
  }
}
```

```bash
terraform plan
terraform apply
aws logs describe-log-groups --log-group-name-prefix /lab/a-mano --query 'logGroups[].logGroupName'
```

*will no longer be managed by Terraform, but will not be destroyed*: sale del estado y sigue existiendo en AWS. Sin el bloque `removed`, quitar el `resource` lo habría **destruido**.

## Ahora, en Vigía (10 min)

En tu `infra/`:
1. Busca secretos: `grep -rniE 'password|secret|token' infra/ --include=*.tf`. Lo único que debería salir son nombres de variables o de recursos, nunca un valor.
2. `terraform plan -refresh-only`: ¿ha cambiado algo fuera desde la clase 97? Si sí, decide: revertir o aceptar.
3. Piensa qué de Vigía es como el SG `sueltas`: cosas que Terraform no vería si alguien las cambiara a mano. Apúntalo en el README, en *Limitations*.

## Rómpelo

1. **Un output sensible sin marcar.** Añade `output "el_secreto" { value = var.secreto }` y planifica. *Output refers to sensitive values*: Terraform no te deja sacar un secreto sin decirlo explícitamente (`sensitive = true`). Quítalo.
2. **Aceptar sin cambiar el código.** Cambia la retención a mano a 14 días, haz `terraform apply -refresh-only` y después `terraform plan`. El plan vuelve a proponer 7: aceptar en el estado no cambia lo que dice el código. "Aceptar" de verdad es cambiar el código.
3. **El `removed` que se olvida de `destroy = false`.** Crea otro grupo a mano, impórtalo y quítalo con un bloque `removed` sin `lifecycle`. ¿Qué dice el plan? Que lo **destruirá**. El `destroy = false` es lo que lo salva.

## Reto

1. Mueve el secreto del laboratorio a **Secrets Manager**, creado a mano, y léelo con el data source `aws_secretsmanager_secret_version`. ¿Dónde acaba el valor? Pista: un `data` también se guarda en el estado.
2. Busca en la documentación qué son los recursos **efímeros** (`ephemeral`, desde Terraform 1.10) y en qué se diferencian de un `data`. ¿Resolverían el Reto 1?
3. Escribe un script que lance `terraform plan -refresh-only -detailed-exitcode` cada noche y avise si el código de salida es 2. Es la detección de *drift* que muchos equipos programan en su CI.

## Destruir al terminar

```bash
terraform destroy
aws logs delete-log-group --log-group-name /lab/a-mano
unset TF_VAR_secreto
```

El grupo `/lab/a-mano` lo borras a mano: Terraform ya no lo gestiona.

## Cierre

En `notas/fase-8/clase-99.md`:

1. ¿Qué pasa si alguien cambia a mano un recurso que gestiona Terraform? ¿Qué opciones tienes?
2. ¿Por qué Terraform no vio la regla del puerto 22 en el SG con reglas sueltas, y qué harías para no depender de eso?
3. ¿Qué diferencia hay entre `sensitive = true` y un argumento de solo escritura?
4. **Repaso (clase 98, sin mirar):** ¿para qué sirve un bloque `moved`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** En el siguiente `plan`, Terraform refresca el estado, ve la diferencia (el *drift*) y propone volver a lo que dice el código. Las opciones:
- **revertir**, aplicando;
- **aceptar el cambio**, escribiéndolo en el código y aplicando, para que quede revisado y versionado;
- **ignorar ese atributo** con `ignore_changes`, si lo gestiona otro.

Con `plan -refresh-only` se ve el cambio sin proponer nada. Mientras no decidas, el próximo `apply` de cualquier persona revertirá el cambio, quizá sin que lo note.

**2.** Porque Terraform solo compara lo que está en su estado. Con reglas en recursos aparte, cada regla es un recurso, y una regla nueva hecha a mano no pertenece a ninguno. No hay nada con qué compararla. Para no depender de eso:
- **comprobar la realidad:** el `verify-aws.sh` de la v3, que mira los SG de verdad, o reglas de AWS Config que avisen de cualquier SG abierto a `0.0.0.0/0`;
- **restringir quién puede cambiar los SG a mano,** con IAM.

**3.** `sensitive = true` solo **oculta** el valor en el plan y en la salida: sigue guardado en el estado en texto claro. Un argumento de solo escritura (`value_wo`) se envía a AWS pero **no se guarda** en el estado, y para cambiarlo hay que subir su versión, porque Terraform no lo recuerda.

**4.** Para cambiar la dirección de un recurso en el código (por ejemplo, al moverlo a un módulo o al renombrarlo) sin que Terraform lo destruya y lo cree de nuevo. Le dice que `from` y `to` son el mismo objeto.

**Reto 1:** en el estado, porque un `data` guarda lo que lee. Lo resuelven los recursos efímeros o, mejor, que la aplicación lea el secreto con su rol al arrancar, sin pasar por Terraform.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| configuration drift | deriva de la configuración (cambios hechos fuera de Terraform) |
| refresh-only mode | modo de solo refresco |
| sensitive value / write-only argument | valor sensible / argumento de solo escritura |
| to generate configuration | generar la configuración |
| to stop managing a resource | dejar de gestionar un recurso |

🎙️ *"When someone changes a Terraform-managed resource by hand, the next plan shows the drift and proposes reverting it; we either apply, or codify the change in a pull request. Terraform can't see what isn't in its state, like a standalone security group rule added by hand, so we also check the real configuration."*

## Siguiente

[Clase 100 — Terraform en CI](clase-100-terraform-en-ci.md)
