# Clase 99 — Secretos, import y drift

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** B. Vigía en código

> 💡 **La idea de hoy:** los secretos se escapan por tres sitios: el código, los `.tfvars` versionados y el propio estado; `sensitive` solo los **tapa** en pantalla, y un argumento de **solo escritura** evita que lleguen al estado. Cuando alguien cambia a mano algo que gestiona Terraform, hay ***drift***: el siguiente plan propone volver al código, y tú decides si revertir, aceptar o ignorar. Pero Terraform solo ve lo que está en su estado.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Que un secreto en Git queda para siempre (clase 22); `TF_VAR_` y `sensitive` (clase 94).
> - Los secretos legibles en el estado (clase 96, Rómpelo 3); `ignore_changes` (clase 95).
> - Los bloques `import` (clase 97); `moved` (clase 98).
> - Parameter Store, de donde sale la AMI (clase 95), y Secrets Manager (clase 80); la retención de logs y AWS Config (clase 76).
> - El `verify-aws.sh` de la v3, que comprueba los SG reales (clase 79).

> 🔤 **Palabras nuevas de hoy:**
> - ***drift***: la diferencia entre lo que dice el estado y lo que hay de verdad en AWS, por un cambio hecho fuera de Terraform.
> - **refrescar**: preguntar a AWS cómo está cada recurso del estado, antes de planificar.
> - **`-refresh-only`**: un plan o un `apply` que solo mira (o acepta) lo que cambió fuera.
> - **argumento de solo escritura** (*write-only*): se envía a AWS, pero no se guarda en el estado (`value_wo`).
> - **`-generate-config-out`**: que Terraform escriba el código de lo que importas.
> - **bloque `removed`**: dejar de gestionar un recurso; con `destroy = false`, sin borrarlo.

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

## Cómo va esta clase

Seis piezas y, al final, una revisión de Vigía. En cada pieza lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan el mismo laboratorio.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 25 min); el segundo, las **piezas 3 a 6**, Vigía, el Rómpelo, el reto y el cierre. Puedes dejar el laboratorio creado: no cuesta nada.

```bash
mkdir -p ~/my-devops-journey/labs/clase-99 && cd ~/my-devops-journey/labs/clase-99
```

## Las piezas

### Pieza 1 — Secretos: tres sitios donde se escapan

| Dónde | El problema | Qué hacer |
|-------|-------------|-----------|
| **El código** (`password = "secreto123"`) | va a Git, para siempre (clase 22) | nunca. Que llegue por variable |
| **Un `.tfvars` versionado** | igual: va a Git | `terraform.tfvars` en `.gitignore`, o el valor desde `TF_VAR_` o desde un gestor de secretos |
| **El estado** | Terraform guarda **todos** los atributos, también los secretos, en texto claro (Rómpelo 3 de la clase 96) | bucket privado y cifrado, pocos con acceso y, si se puede, que el secreto no pase por Terraform |

**`sensitive = true`**, en una variable o en un output, hace que el valor no se muestre en el plan ni en la salida: aparece como `(sensitive value)`. Lo verás en la pieza 2: **sí** se guarda en el estado.

**Pruébalo.** `main.tf`, con todo el laboratorio de la clase:

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

Los dos security groups y los dos parámetros son para las piezas 2 y 4. El secreto llega por el entorno, no por un archivo:

```bash
export TF_VAR_secreto="no-lo-subas-123"
terraform init && terraform apply
```

🔮 **Predice:** ¿qué muestra el plan del `value` de los parámetros?

👀 **Qué deberías ver:** `(sensitive value)`: la variable es sensible, y Terraform la tapa en todas partes, también en lo que se calcula a partir de ella. Al final, `Apply complete! Resources: 6 added`.

✋ **Sin mirar:** ¿por qué el secreto llega con `TF_VAR_secreto` y no en `terraform.tfvars`?

<details>
<summary>Comprueba</summary>

Porque un archivo puede acabar en Git por un descuido; una variable de entorno vive solo en tu sesión. En CI, llega de un gestor de secretos.
</details>

**En resumen:** los secretos nunca en el código ni en un `.tfvars` versionado; `sensitive` los tapa en pantalla.

### Pieza 2 — `sensitive` frente a solo escritura

- **`sensitive`** tapa el valor en el plan y en la salida, pero lo guarda en el estado en texto claro.
- **Argumentos de solo escritura** (*write-only*, desde Terraform 1.11), como `value_wo` en `aws_ssm_parameter`: el valor llega a AWS, pero **no se guarda** en el estado. Como Terraform no lo recuerda, para cambiarlo se sube un número de versión (`value_wo_version`).
- **Que no pase por Terraform:** es lo que hace Vigía, que genera su contraseña de PostgreSQL **dentro** de la instancia (clase 78). Otra opción es guardar el secreto en Secrets Manager o en Parameter Store y que la aplicación lo lea con su rol.

🔮 **Predice:** ¿en cuál de los dos parámetros verás el secreto si lees el estado?

**Pruébalo:**

```bash
terraform state pull | jq '.resources[] | select(.type == "aws_ssm_parameter") | {nombre: .name, value: .instances[0].attributes.value}'
aws ssm get-parameter --name /lab/clase-99/solo-escritura --with-decryption --query Parameter.Value --output text
```

👀 **Qué deberías ver:**
- **El parámetro `clasico`:** `"no-lo-subas-123"`, **legible** en el estado. `sensitive` lo tapó en el plan, no en el estado.
- **El de solo escritura:** `value` está vacío en el estado. AWS sí lo tiene: la segunda orden lo devuelve.

Esa es la diferencia que importa. Para cambiarlo, como Terraform no recuerda el valor, sube `value_wo_version` a `2` y aplica.

✋ **Sin mirar:** cambias el valor de `TF_VAR_secreto` y aplicas. ¿Se actualiza el parámetro de solo escritura?

<details>
<summary>Comprueba</summary>

No: Terraform no guarda el valor, así que no puede ver que ha cambiado. Solo lo vuelve a enviar si subes `value_wo_version`.
</details>

**En resumen:** `sensitive` oculta; solo escritura no guarda; lo mejor, que el secreto no pase por Terraform.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, antes de seguir, vuelve a hacer `export TF_VAR_secreto="no-lo-subas-123"`: las variables de entorno no sobreviven a la sesión.

### Pieza 3 — *Drift*: cuando la realidad y el código se separan

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

**Pruébalo.** Alguien sube la retención desde la consola:

```bash
aws logs put-retention-policy --log-group-name /lab/clase-99 --retention-in-days 30
terraform plan
terraform plan -refresh-only
```

🔮 **Predice:** ¿qué propone cada uno de los dos planes?

👀 **Qué deberías ver:**
- **`plan`:** `retention_in_days = 30 -> 7`. Quiere **volver** al código.
- **`plan -refresh-only`:** *Objects have changed outside of Terraform*, `7 -> 30`. Es lo que pasó fuera.

Decide:
- **revertir:** `terraform apply`;
- **o aceptar:** cambia el código a `30` y aplica.

Haz una de las dos y comprueba que el siguiente `plan` dice `No changes`.

✋ **Sin mirar:** si no haces nada con un *drift*, ¿qué pasará la próxima vez que alguien aplique?

<details>
<summary>Comprueba</summary>

Que su `apply` revertirá el cambio hecho a mano, quizá sin que lo note: el plan propone volver al código en cada ejecución.
</details>

**En resumen:** `plan` propone revertir; `-refresh-only` enseña lo que cambió; aceptar de verdad es cambiar el código.

### Pieza 4 — Lo que Terraform no ve

Terraform solo compara lo que **está en su estado**. Con las reglas de un security group en recursos aparte (`aws_vpc_security_group_ingress_rule`), cada regla es un recurso, y una regla añadida a mano no es de nadie: Terraform no la ve.

Con las reglas **dentro** del propio security group (`ingress { … }`), Terraform gestiona el conjunto entero, y cualquier regla de más aparece en el plan para quitarla.

La forma recomendada sigue siendo la de recursos aparte, porque es más clara y evita conflictos. Pero significa que hace falta otra vigilancia para lo que Terraform no gestiona, como AWS Config (clase 76) o el `verify-aws.sh` de la v3, que comprueba que no haya nada abierto a `0.0.0.0/0`.

**Pruébalo.** Alguien abre el SSH a todo internet en los dos SG:

```bash
for n in sueltas dentro; do
  SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=lab-tf-reglas-$n --query 'SecurityGroups[0].GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr 0.0.0.0/0
done
terraform plan
```

🔮 **Predice:** ¿en cuál de los dos lo detecta?

👀 **Qué deberías ver:**
- **`dentro`:** Terraform propone quitar la regla del 22 (`- from_port = 22`): gestiona el conjunto entero.
- **`sueltas`:** **nada**. La regla nueva no es de ningún recurso de su estado, así que no existe para él.

Aplica: el SG `dentro` vuelve a estar limpio, y el `sueltas` sigue con el 22 abierto a todo internet. Bórrala a mano:

```bash
SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=lab-tf-reglas-sueltas --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 revoke-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr 0.0.0.0/0
```

Por eso el `verify-aws.sh` de la v3 comprueba los SG de verdad, y no lo que dice el código.

✋ **Sin mirar:** ¿por qué Terraform no ve la regla nueva del SG `sueltas`?

<details>
<summary>Comprueba</summary>

Porque cada regla es un recurso aparte, y esa no pertenece a ninguno de su estado: no hay nada con qué compararla.
</details>

**En resumen:** Terraform no ve lo que no está en su estado; para eso, comprobar la realidad.

### Pieza 5 — Importar con código generado

| Necesidad | Herramienta |
|-----------|-------------|
| adoptar algo que existe | un bloque **`import`** (clase 97) |
| que Terraform **escriba** el código de lo importado | `terraform plan -generate-config-out=generado.tf`: un punto de partida que siempre hay que limpiar |
| la forma antigua, sin dejar rastro en el código | `terraform import <dirección> <id>` |

**Pruébalo.** Alguien creó a mano un grupo de logs:

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

👀 **Qué deberías ver:** el plan dice `1 to import`, y `generado.tf` empieza con un comentario (`# __generated__ by Terraform`) y un bloque `resource "aws_cloudwatch_log_group" "a_mano"` con todos los atributos que leyó, incluidos los que no hace falta poner, como `tags_all` o `kms_key_id = null`.

**Límpialo**:
- quita lo calculado;
- pon una retención (`retention_in_days = 0` es "para siempre", clase 76);
- muévelo a `main.tf` y borra `generado.tf`.

Aplica y borra `importar.tf`.

✋ **Sin mirar:** ¿por qué hay que limpiar el código generado?

<details>
<summary>Comprueba</summary>

Porque copia **todo** lo que leyó, también lo que calcula AWS o el provider. Ese ruido hace el código difícil de leer y, a veces, provoca cambios o errores en el siguiente plan.
</details>

**En resumen:** `-generate-config-out` escribe un borrador del `resource`; tú lo limpias.

### Pieza 6 — Dejar de gestionarlo sin borrarlo

Un bloque **`removed`** con `destroy = false` hace que Terraform olvide un recurso sin borrarlo de AWS. Sustituye a `terraform state rm` (clase 96), y queda en el PR.

**Pruébalo.** Ese grupo de logs, al final, lo gestiona otro equipo. Quita su bloque `resource` de `main.tf` y añade:

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

👀 **Qué deberías ver:** *will no longer be managed by Terraform, but will not be destroyed*. Sale del estado y sigue existiendo en AWS: la última orden devuelve `["/lab/a-mano"]`.

✋ **Sin mirar:** si quitas el bloque `resource` sin añadir el `removed`, ¿qué pasa?

<details>
<summary>Comprueba</summary>

Que Terraform lo **destruye**: un recurso del estado que ya no está en el código es, para él, algo que hay que borrar.
</details>

**En resumen:** `removed` con `destroy = false` olvida sin borrar.

## Ahora, en Vigía (10 min)

En tu `infra/`:
1. Busca secretos: `grep -rniE 'password|secret|token' infra/ --include=*.tf`. Lo único que debería salir son nombres de variables o de recursos, nunca un valor.
2. `terraform plan -refresh-only`: ¿ha cambiado algo fuera desde la clase 97? Si sí, decide: revertir o aceptar.
3. Piensa qué de Vigía es como el SG `sueltas`: cosas que Terraform no vería si alguien las cambiara a mano. Apúntalo en el README, en *Limitations*.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `variable "x" { sensitive = true }` | tapar el valor en el plan y la salida (no en el estado) |
| `value_wo = var.x` + `value_wo_version = 1` | un secreto que no llega al estado |
| `terraform plan -refresh-only` | qué cambió fuera de Terraform |
| `terraform apply -refresh-only` | aceptar la realidad en el estado, sin tocar AWS |
| `terraform plan -generate-config-out=generado.tf` | escribir el código de lo importado |
| `removed { from = …  lifecycle { destroy = false } }` | dejar de gestionar sin borrar |
| `terraform plan -detailed-exitcode` | 0 sin cambios, 1 error, 2 hay cambios |

## Rómpelo

1. **Un output sensible sin marcar.** Añade `output "el_secreto" { value = var.secreto }` y planifica. *Output refers to sensitive values*: Terraform no te deja sacar un secreto sin decirlo explícitamente (`sensitive = true`). Quítalo.
2. **Aceptar sin cambiar el código.** Cambia la retención a mano a 14 días, haz `terraform apply -refresh-only` y después `terraform plan`. El plan vuelve a proponer 7: aceptar en el estado no cambia lo que dice el código. "Aceptar" de verdad es cambiar el código.
3. **El `removed` que se olvida de `destroy = false`.** Crea otro grupo a mano, impórtalo y quítalo con un bloque `removed` sin `lifecycle`. ¿Qué dice el plan? Que lo **destruirá**. El `destroy = false` es lo que lo salva.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Mueve el secreto del laboratorio a **Secrets Manager**, creado a mano, y léelo con el data source `aws_secretsmanager_secret_version`. ¿Dónde acaba el valor?

> 🧩 **Ejemplo resuelto:** en la clase 95, `data "aws_ssm_parameter" "ubuntu"` leía la AMI de Parameter Store, y su valor quedaba en el estado.

**Ahora tú, con huecos:**
```bash
aws secretsmanager create-secret --name lab/clase-99 --secret-string "no-lo-subas-123"
```
```hcl
data "aws_secretsmanager_secret_version" "lab" {
  secret_id = "____"
}
```
Completa: «Después de `terraform apply`, el valor está en ____, porque un `data`…».

<details>
<summary>Pista</summary>

Búscalo como en la pieza 2: `terraform state pull | jq '.resources[] | select(.type == "aws_secretsmanager_secret_version")'`. Al terminar, bórralo: `aws secretsmanager delete-secret --secret-id lab/clase-99 --force-delete-without-recovery`.
</details>

**2.** Busca en la documentación qué son los recursos **efímeros** (`ephemeral`, desde Terraform 1.10) y en qué se diferencian de un `data`. ¿Resolverían el reto 1?

> 🧩 **Ejemplo resuelto:** la pieza 2: un argumento de solo escritura se envía a AWS, pero no se guarda en el estado.

**Ahora tú, con huecos:** busca *Ephemeral resources* en developer.hashicorp.com. Completa: «Un bloque `ephemeral` lee un valor que ____ se guarda en el estado ni en el plan. A diferencia de un `data`,… Solo se puede usar en ____. Resolvería el reto 1 si…».

<details>
<summary>Pista</summary>

Mira en qué sitios se puede usar un valor efímero: argumentos de solo escritura, la configuración de un provider, `locals`… Y si el provider de AWS tiene `ephemeral "aws_secretsmanager_secret_version"`.
</details>

**3.** Escribe un script que lance `terraform plan -refresh-only -detailed-exitcode` cada noche y avise si el código de salida es 2. Es la detección de *drift* que muchos equipos programan en su CI.

> 🧩 **Ejemplo resuelto:** el `case` de la clase 17 para actuar según un valor, y el `crontab` de la clase 20 para lanzarlo cada noche.

**Ahora tú, con huecos:**
```bash
#!/usr/bin/env bash
set -uo pipefail                       # sin -e: el 2 no es un error
cd ~/vigia/infra
terraform plan -refresh-only -detailed-exitcode -input=false -no-color > /tmp/drift.txt
codigo=$?
case $codigo in
  0) echo "sin drift" ;;
  2) logger -t vigia-drift "____" ;;
  *) logger -t vigia-drift "____" ;;
esac
exit "$codigo"
```
Y en `crontab -e`: `0 3 * * * ____`.

<details>
<summary>Pista</summary>

`logger` escribe en el journal (clase 13): luego lo lees con `journalctl -t vigia-drift`. El 1 es un error de Terraform (credenciales, red), distinto de "hay *drift*". El cron necesita las credenciales de AWS en su entorno: compruébalo lanzándolo a mano primero.
</details>

## Destruir al terminar

```bash
terraform destroy
aws logs delete-log-group --log-group-name /lab/a-mano
unset TF_VAR_secreto
```

El grupo `/lab/a-mano` lo borras a mano: Terraform ya no lo gestiona.

## Cierre

En `notas/fase-8/clase-99.md`:

1. ¿Qué pasa si alguien cambia a mano un recurso que gestiona Terraform? ¿Qué opciones tienes? *(3 líneas. Empieza así: «En el siguiente `plan`, Terraform refresca, ve la diferencia y propone… Puedo revertir,…»)*
2. ¿Por qué Terraform no vio la regla del puerto 22 en el SG con reglas sueltas, y qué harías para no depender de eso? *(2 líneas. Empieza así: «Porque Terraform solo compara lo que está en su estado, y…»)*
3. ¿Qué diferencia hay entre `sensitive = true` y un argumento de solo escritura? *(2 líneas. Empieza así: «`sensitive` solo oculta el valor en…; el de solo escritura…»)*
4. **Repaso (clase 98, sin mirar):** ¿para qué sirve un bloque `moved`? *(1–2 líneas. Empieza así: «Para cambiar la dirección de un recurso en el código sin que…»)*

Después, escríbeme `examíname clase-99`.

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

**Reto 1:** `secret_id = "lab/clase-99"`. El valor acaba **en el estado**, en `secret_string`, porque un `data` guarda lo que lee. Lo resuelven los recursos efímeros (reto 2) o, mejor, que la aplicación lea el secreto con su rol al arrancar, sin pasar por Terraform.

**Reto 2:** un bloque `ephemeral` lee un valor que **nunca** se guarda en el estado ni en el plan: se pide en cada ejecución y se olvida al terminar. Un `data`, en cambio, guarda en el estado todo lo que lee. Un valor efímero solo se puede usar en sitios que tampoco lo guardan: argumentos de solo escritura, la configuración de un provider, `locals`, variables y outputs efímeros. Resolvería el reto 1 si el secreto se usa en un argumento de solo escritura, por ejemplo `value_wo` de otro parámetro o la contraseña de una base de datos (`password_wo`).

**Reto 3:** por ejemplo:

```bash
  2) logger -t vigia-drift "Drift en Vigía: revisa /tmp/drift.txt" ;;
  *) logger -t vigia-drift "terraform falló con código $codigo" ;;
```

Y `0 3 * * * $HOME/my-devops-journey/labs/clase-99/drift.sh` (con la ruta completa y el script ejecutable). Sin `set -e`, porque `-detailed-exitcode` devuelve 2 cuando hay cambios y eso no es un error. En la clase 100 lo harás en GitHub Actions.
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
