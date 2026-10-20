# Clase 96 — El estado: backend S3 con bloqueo

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

> 💡 **La idea de hoy:** el estado es la memoria de Terraform: qué recurso real corresponde a cada bloque, con todos sus atributos, secretos incluidos. Por eso no puede vivir en tu portátil ni en Git: va a un **bucket de S3** con versionado, privado y con **bloqueo**, para que dos `apply` nunca escriban a la vez.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El estado local y lo que pasa si se pierde (clase 92, Rómpelo 2).
> - El versionado, el bloqueo del acceso público y las versiones de un objeto en S3 (clase 74).
> - `jq` para leer JSON (clase 47); `pkill` para matar un proceso por nombre (clase 11).
> - `prevent_destroy` y `force_destroy` (clases 92 y 95); la configuración de la clase 94, con su VPC y sus tres subredes.

> 🔤 **Palabras nuevas de hoy:**
> - **backend**: dónde guarda Terraform el estado (`local` por defecto, `s3` hoy).
> - **`key`**: la ruta del estado dentro del bucket; cada configuración tiene la suya.
> - **bloqueo** (*state lock*): la marca que impide que dos procesos usen el mismo estado a la vez.
> - **`use_lockfile`**: el bloqueo nativo de S3, con un objeto `.tflock`.
> - **escritura condicional**: "crea este objeto solo si no existe".
> - **configuración parcial**: dejar valores del backend fuera del código y pasarlos con `-backend-config`.
> - **recurso huérfano**: un recurso real que ya no está en ningún estado.

## Objetivo

- Entender qué guarda el estado, por qué es crítico y por qué no puede vivir en tu portátil ni en Git.
- Crear el **bucket del estado** (con versionado y sin acceso público) y resolver el problema del huevo y la gallina.
- Llevar un estado local a un **backend S3** con **`use_lockfile = true`**, con `terraform init -migrate-state`.
- Ver el **bloqueo** en acción: dos procesos a la vez, y cómo liberarlo si se queda colgado.
- Usar los comandos `terraform state` y recuperar una versión anterior del estado desde S3.

## Por qué importa

Con el estado en tu portátil:
- si el disco muere, Terraform olvida tu infraestructura (el Rómpelo 2 de la clase 92);
- si un compañero o el pipeline (clase 100) aplican, cada uno tiene su copia, y se pisan.

El estado remoto, compartido, con **bloqueo** y con **versiones**, es requisito para trabajar con Terraform en serio, y uno de los criterios de salida de la fase.

Hasta hace poco, el bloqueo en AWS necesitaba una tabla de DynamoDB. Hoy está **obsoleto**: S3 lo hace solo con `use_lockfile`. Muchos tutoriales siguen enseñando DynamoDB; tú ya no lo necesitas.

## Costo esperado

> 💰 **0 USD.** Un bucket con unos KB y dos o tres VPC vacías durante la clase.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan la configuración de la clase 94.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 35 min); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre. Puedes dejarlo todo creado entre los dos días: ni la VPC ni el bucket cuestan nada.

La pieza 4 necesita **dos terminales** abiertas en la misma carpeta.

```bash
cd ~/my-devops-journey/labs/clase-94 && terraform apply
ls -la terraform.tfstate
```

Si destruiste la clase 94, el `apply` la vuelve a crear con estado **local**: la VPC y sus tres subredes.

## Las piezas

### Pieza 1 — Qué hay en el estado

`terraform.tfstate` es un JSON con:
- **la versión de Terraform**, un **`serial`** (cuántas veces ha cambiado) y un **`lineage`** (la identidad de ese estado);
- **cada recurso** con su dirección (`aws_vpc.lab`) y **todos** sus atributos tal como los devolvió AWS: ID, ARN y también cualquier valor sensible, **en texto claro**.

De ahí salen sus tres reglas:

| Regla | Por qué |
|-------|---------|
| fuera de Git | puede tener secretos, y cada clon tendría una copia distinta |
| en un sitio compartido, con bloqueo | si dos procesos escriben a la vez, el estado se corrompe |
| con historial | si se estropea o se pierde, tiene que poder recuperarse |

Para leerlo, nunca abras el JSON a mano: usa los comandos de `terraform state`.

**Pruébalo** (en `labs/clase-94`):

```bash
terraform state list
terraform state show 'aws_subnet.esta["publica-a"]'
terraform state pull | jq '{version, terraform_version, serial, lineage, recursos: (.resources | length)}'
```

Las comillas simples alrededor de la dirección hacen falta: `[` y `"` significan algo para Bash.

🔮 **Predice:** ¿cuántos recursos tiene el estado, y cuántos atributos guarda de una subred: los que escribiste o más?

👀 **Qué deberías ver:** cuatro direcciones (`aws_vpc.lab` y las tres `aws_subnet.esta[…]`). La subred muestra muchos más atributos de los que escribiste: `arn`, `id`, `owner_id`, `availability_zone_id`… Y el JSON resumido, con tu `serial` y un `lineage` largo, del tipo `"a1b2c3d4-…"`.

✋ **Sin mirar:** ¿por qué no se sube el estado a Git?

<details>
<summary>Comprueba</summary>

Porque puede contener secretos en texto claro, y porque cada clon tendría su propia copia: dos personas aplicando con estados distintos se pisan.
</details>

**En resumen:** el estado guarda todos los atributos reales, secretos incluidos; va fuera de Git, compartido, con bloqueo y con historial.

### Pieza 2 — El huevo y la gallina: el bucket del estado

Un bucket de S3 con versionado y con el acceso público bloqueado (clase 74) cumple las tres reglas. Pero el bucket del estado es un recurso de AWS, y te gustaría crearlo con Terraform… ¿dónde guardas el estado del bucket del estado?

La práctica habitual:
1. una configuración **pequeña y aparte** crea el bucket con estado **local**;
2. se aplica una vez;
3. su `terraform.tfstate` se guarda en sitio seguro, o se migra al propio bucket.

Ese bucket lleva `prevent_destroy` (clase 95): borrarlo sería borrar la memoria de toda tu infraestructura.

**Pruébalo:**

```bash
mkdir -p ~/my-devops-journey/labs/clase-96/estado && cd ~/my-devops-journey/labs/clase-96/estado
```

`main.tf`:

```hcl
# El bucket del estado de los laboratorios. Se crea con estado LOCAL: es el huevo de la gallina.
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
    tags = { Proyecto = "lab", Clase = "96" }
  }
}

data "aws_caller_identity" "yo" {}

resource "aws_s3_bucket" "estado" {
  bucket        = "lab-tfstate-${data.aws_caller_identity.yo.account_id}"
  force_destroy = true # solo en el laboratorio: el de Vigía llevará prevent_destroy
}

resource "aws_s3_bucket_versioning" "estado" {
  bucket = aws_s3_bucket.estado.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "estado" {
  bucket                  = aws_s3_bucket.estado.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

output "bucket" {
  value = aws_s3_bucket.estado.bucket
}
```

- **`data "aws_caller_identity"`:** tu número de cuenta, para que el nombre del bucket sea único sin escribirlo a mano.
- **`force_destroy`:** deja que `destroy` vacíe el bucket al final de la clase. En Vigía (clase 97) será al revés: `prevent_destroy`.

```bash
terraform init && terraform apply
BUCKET=$(terraform output -raw bucket)
aws s3api get-bucket-versioning --bucket "$BUCKET"
```

👀 **Qué deberías ver:** `Apply complete! Resources: 3 added`; `$BUCKET` vale `lab-tfstate-` y tu número de cuenta; y el versionado, `"Status": "Enabled"`. El estado de **esta** configuración está en local, en `labs/clase-96/estado/terraform.tfstate`.

✋ **Sin mirar:** ¿por qué la configuración que crea el bucket del estado usa estado local?

<details>
<summary>Comprueba</summary>

Porque su estado no puede estar en un bucket que todavía no existe. Se aplica una vez con estado local, y ese archivo se guarda en sitio seguro (o se migra después al propio bucket).
</details>

**En resumen:** el bucket del estado se crea aparte, con estado local, versionado y sin acceso público.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, antes de la pieza 3, vuelve a calcular el nombre: `BUCKET=$(terraform -chdir=$HOME/my-devops-journey/labs/clase-96/estado output -raw bucket)`.

### Pieza 3 — El backend S3: llevar un estado local al bucket

```hcl
terraform {
  backend "s3" {
    bucket       = "lab-tfstate-123456789012"
    key          = "labs/clase-94/terraform.tfstate"   # la "ruta" de este estado en el bucket
    region       = "us-east-1"
    use_lockfile = true                                # bloqueo nativo de S3
    encrypt      = true                                # cifrado en el bucket
  }
}
```

- **Un bucket, muchos estados.** Cada configuración usa su propio `key`. Es como Vigía y los laboratorios convivirán.
- **El bloque `backend` no admite variables:** se evalúa antes que todo lo demás. Lo que cambie entre cuentas, como el nombre del bucket, se pasa al inicializar: `terraform init -backend-config="bucket=…"`. Es la **configuración parcial** que usará Vigía (Rómpelo 1).
- **Permisos:** quien use el backend necesita `s3:ListBucket` en el bucket, `s3:GetObject` y `s3:PutObject` en el estado, y además `s3:DeleteObject` en el `.tflock` (pieza 4).

**Pruébalo.** Crea `backend.tf` en `labs/clase-94` (cambia el número de cuenta por el tuyo):

```hcl
terraform {
  backend "s3" {
    bucket       = "lab-tfstate-123456789012"
    key          = "labs/clase-94/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

🔮 **Predice:** al cambiar de backend, ¿qué te preguntará `terraform init`?

```bash
cd ~/my-devops-journey/labs/clase-94
terraform init -migrate-state
```

Te pregunta si quieres **copiar** el estado existente al backend nuevo. Contesta `yes`. Comprueba:

```bash
aws s3 ls "s3://$BUCKET" --recursive
terraform state list
terraform plan
```

👀 **Qué deberías ver:** en el bucket, `labs/clase-94/terraform.tfstate`; las mismas cuatro direcciones de la pieza 1; y `No changes`: Terraform sigue sabiendo qué es suyo.

Borra la copia local, que ya no se usa y solo puede confundir:

```bash
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan
```

Sigue diciendo `No changes`: ahora lee de S3.

✋ **Sin mirar:** ¿por qué no puedes escribir `bucket = var.bucket_estado` en el backend?

<details>
<summary>Comprueba</summary>

Porque el backend se lee antes que las variables. Lo que cambia se pasa al inicializar, con `terraform init -backend-config="bucket=…"`.
</details>

**En resumen:** un bucket guarda muchos estados, uno por `key`; `init -migrate-state` copia el estado local al backend.

### Pieza 4 — El bloqueo, con dos terminales

Con `use_lockfile`, Terraform escribe junto al estado un objeto `terraform.tfstate.tflock` con una **escritura condicional** ("créalo solo si no existe"):
- si otro proceso ya lo tiene, la escritura falla y Terraform se niega a seguir;
- al terminar, el dueño lo borra;
- si el proceso muere, el `.tflock` se queda. Se quita con `terraform force-unlock <ID>`, **solo** si sabes que nadie está aplicando.

**Pruébalo.** En la **terminal 1**, empieza un cambio y **no contestes** a la pregunta:

```bash
cd ~/my-devops-journey/labs/clase-94
terraform apply -var 'etiquetas={Nota="espera"}'
```

Se queda en `Enter a value:`, con el bloqueo puesto. En la **terminal 2**:

```bash
cd ~/my-devops-journey/labs/clase-94
aws s3 ls "s3://lab-tfstate-$(aws sts get-caller-identity --query Account --output text)" --recursive
terraform plan
```

🔮 **Predice:** ¿qué verás en el bucket, y qué hará el `plan` de la terminal 2?

👀 **Qué deberías ver:**
- **El bucket:** junto al estado, aparece `terraform.tfstate.tflock`.
- **El `plan` de la terminal 2:** falla con `Error acquiring the state lock`. El motivo es `PreconditionFailed`: la escritura condicional no pudo crear el `.tflock` porque ya existe.
- **Lock Info:** el ID del bloqueo, quién lo tiene, desde qué máquina, qué operación y desde cuándo.

Contesta `no` en la terminal 1: Terraform cancela y borra el `.tflock`. Repite el `plan` de la terminal 2: ahora funciona.

**Un bloqueo colgado.** Vuelve a empezar el `apply` de la terminal 1 y, en lugar de contestar, mata el proceso desde la terminal 2:

```bash
pkill -9 terraform
terraform plan
```

El `.tflock` se quedó: nadie lo borró. Con el ID que muestra el error:

```bash
terraform force-unlock <ID>
terraform plan
```

`force-unlock` te pide confirmación; contesta `yes`. Si lo usas con un `apply` de verdad a medias, dos procesos escribirán el mismo estado.

✋ **Sin mirar:** ¿por qué se quedó el `.tflock` después del `pkill -9`?

<details>
<summary>Comprueba</summary>

Porque el que lo borra es el propio proceso al terminar, y `-9` lo mató sin dejarle hacer nada. Nadie más sabe que ya no hay nadie aplicando.
</details>

**En resumen:** el `.tflock` impide dos operaciones a la vez; si se queda colgado, `force-unlock`, y solo si estás seguro.

### Pieza 5 — Mover, olvidar y volver atrás

| Orden | Qué hace |
|-------|----------|
| `terraform state mv <de> <a>` | cambiar la dirección de un recurso sin destruirlo. Hoy se prefiere un bloque `moved` (clase 98) |
| `terraform state rm <dirección>` | olvidar un recurso **sin** borrarlo de AWS. Hoy se prefiere un bloque `removed` (clase 99) |
| `terraform state push <archivo>` | subir un estado entero; solo para recuperar uno |

Y como el bucket tiene versionado, cada `apply` deja una versión del estado. Si uno se corrompiera, descargarías la anterior con `aws s3api get-object --version-id …` (clase 74) y la restaurarías con `terraform state push`. Nunca lo hagas con prisa: primero entiende qué cambió entre las dos.

**Workspaces:** `terraform workspace` permite varios estados para una misma carpeta (por ejemplo, `dev` y `prod`). En este curso usarás lo más claro y lo más común en AWS: un `key` distinto por entorno.

**Pruébalo.** Aplica un cambio y mira las versiones del estado:

```bash
terraform apply -var 'etiquetas={Nota="v2"}'
aws s3api list-object-versions --bucket "lab-tfstate-$(aws sts get-caller-identity --query Account --output text)" \
  --prefix labs/clase-94/terraform.tfstate --query 'Versions[].[VersionId,LastModified,Size]' --output table
```

👀 **Qué deberías ver:** una tabla con varias filas, una por cada vez que el estado cambió (la migración y cada `apply`), con su `VersionId` y su hora. El `--prefix` también encuentra versiones del `.tflock` si las hay: fíjate en el tamaño, el estado pesa varios KB.

✋ **Sin mirar:** quieres que Terraform deje de gestionar un recurso, pero sin borrarlo de AWS. ¿Qué usas?

<details>
<summary>Comprueba</summary>

`terraform state rm <dirección>` o, mejor, un bloque `removed` (clase 99): Terraform lo olvida y el recurso sigue en AWS.
</details>

**En resumen:** `state mv` y `state rm` cambian el estado sin tocar AWS; el versionado del bucket permite volver atrás.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `backend "s3" { bucket, key, region, use_lockfile = true, encrypt = true }` | el estado en S3, con bloqueo y cifrado |
| `terraform init -migrate-state` | copiar el estado al backend nuevo |
| `terraform init -reconfigure -backend-config="bucket=…"` | configuración parcial del backend |
| `terraform state list` · `state show '<dir>'` · `state pull` | leer el estado |
| `terraform state mv` · `state rm` · `state push` | cambiar el estado sin tocar AWS |
| `terraform force-unlock <ID>` | quitar un bloqueo colgado |
| `aws s3api list-object-versions --prefix <key>` | las versiones del estado |
| `data "aws_caller_identity" "yo" {}` | tu número de cuenta |

## Rómpelo

**1. Variables en el backend.** Cambia en `backend.tf` el bucket por `bucket = var.bucket_estado` y haz `terraform init`. *Variables not allowed*: el backend se lee antes que las variables. La solución es la configuración parcial: quita la línea del bucket y pásala al inicializar:

```bash
terraform init -reconfigure -backend-config="bucket=lab-tfstate-<tu cuenta>"
```

Así lo hará Vigía, con un bucket que lleva tu número de cuenta en el nombre.

**2. Dos estados para lo mismo.** Copia la carpeta de la clase 94 a otra, cambia su `key` a `labs/copia/terraform.tfstate`, haz `terraform init` y `terraform plan`. `Plan: 4 to add`: para ese estado no existe nada, y aplicarlo crearía **otra** VPC igual. No apliques. El `key` es la identidad del estado: dos configuraciones nunca deben compartirlo, y una misma configuración nunca debe cambiarlo sin migrar. Borra la copia.

**3. Leer secretos del estado.** Busca en el estado algo que no se ve en el plan:

```bash
terraform state pull | jq '.resources[] | {tipo: .type, atributos: (.instances[0].attributes | keys | length)}'
```

Cuenta los atributos de cada recurso: muchos más de los que escribiste. Si alguno fuera una contraseña, estaría ahí, legible. Por eso el bucket no es público, está cifrado y solo lo lee quien debe.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escribe la política de IAM **mínima** para que un rol pueda usar el backend de la clase 94 (y solo ese `key`), con los permisos de la pieza 3. La usarás en la clase 100 para el rol del pipeline.

> 🧩 **Ejemplo resuelto:** en la clase 69, la política para leer los informes daba un permiso sobre el bucket y otro sobre un prefijo:
> ```json
> {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::<bucket>"},
> {"Effect": "Allow", "Action": "s3:GetObject", "Resource": "arn:aws:s3:::<bucket>/reports/*"}
> ```

**Ahora tú, con huecos:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "____", "Resource": "arn:aws:s3:::lab-tfstate-<cuenta>"},
    {"Effect": "Allow", "Action": ["s3:GetObject", "____"],
     "Resource": "arn:aws:s3:::lab-tfstate-<cuenta>/labs/clase-94/____"},
    {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "____"],
     "Resource": "arn:aws:s3:::lab-tfstate-<cuenta>/labs/clase-94/____"}
  ]
}
```

<details>
<summary>Pista</summary>

`ListBucket` se da sobre el **bucket** (sin `/…`); los demás, sobre los **objetos**. El `.tflock` se crea y se borra en cada operación, así que necesita un permiso más que el estado.
</details>

**2.** Migra el estado del bucket del estado (`labs/clase-96/estado`) a su propio bucket, con otro `key`. ¿Qué problema aparece si algún día quieres destruir ese bucket con Terraform?

> 🧩 **Ejemplo resuelto:** la pieza 3: `backend.tf` con `key = "labs/clase-94/terraform.tfstate"` y `terraform init -migrate-state`.

**Ahora tú, con huecos:** `backend.tf` en `labs/clase-96/estado` con `key = "____/terraform.tfstate"` y `terraform init ____`. Completa: «Si quiero destruirlo, el problema es que su estado vive…, así que primero tendría que…».

<details>
<summary>Pista</summary>

Piensa dónde guarda Terraform el estado mientras ejecuta `destroy`, y qué es lo último que borra.
</details>

**3.** Averigua en la documentación del backend S3 qué hace el argumento `workspace_key_prefix`, y cómo se combina con `terraform workspace new dev`.

> 🧩 **Ejemplo resuelto:** el `key` de la pieza 3 decide la ruta del estado: `labs/clase-94/terraform.tfstate`.

**Ahora tú, con huecos:** busca `workspace_key_prefix` en la página del backend `s3` (developer.hashicorp.com, *Backend Configuration*). Completa: «Su valor por defecto es `____`. Con `terraform workspace new dev`, el estado de ese workspace se guarda en `____/____/labs/clase-94/terraform.tfstate`».

<details>
<summary>Pista</summary>

Puedes comprobarlo de verdad: `terraform workspace new dev`, `terraform plan`… y `aws s3 ls "s3://$BUCKET" --recursive`. Vuelve con `terraform workspace select default` y borra el otro con `terraform workspace delete dev`.
</details>

## Destruir al terminar

Primero lo que guarda su estado en el bucket, y al final el bucket:

```bash
cd ~/my-devops-journey/labs/clase-94 && terraform destroy
cd ~/my-devops-journey/labs/clase-96/estado && terraform destroy
aws s3 ls | grep tfstate
```

Si lo haces al revés, la configuración de la clase 94 se queda sin estado y sus recursos quedan **huérfanos**: tendrías que borrarlos a mano. En la clase 97 crearás el bucket del estado de Vigía, que no se destruirá.

## Cierre

En `notas/fase-8/clase-96.md`:

1. ¿Qué guarda el estado y por qué tiene que estar en un sitio compartido, con bloqueo y con historial? *(3 líneas. Empieza así: «Qué recurso real corresponde a cada bloque, con todos sus atributos… Compartido, para que…»)*
2. ¿Cómo funciona el bloqueo con `use_lockfile`, y qué pasó en tu terminal 2? *(2–3 líneas. Empieza así: «Al empezar, Terraform intenta crear un `.tflock` con una escritura condicional…»)*
3. ¿Qué es el problema del huevo y la gallina del bucket del estado, y cómo lo resolviste? *(2 líneas. Empieza así: «El estado del bucket del estado no puede estar en él antes de que exista, así que…»)*
4. **Repaso (clase 95, sin mirar):** ¿para qué sirve `prevent_destroy`, y dónde lo pondrás en Vigía? *(1–2 líneas. Empieza así: «Hace fallar cualquier plan que…»)*

Después, escríbeme `examíname clase-96`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Qué recursos reales corresponden a cada bloque del código, con todos sus atributos tal como los devolvió AWS (secretos incluidos), más su versión y su `serial`.
- **Compartido:** que todos (y el pipeline) trabajen sobre la misma memoria.
- **Con bloqueo:** que dos `apply` a la vez no lo corrompan.
- **Con historial:** que se pueda recuperar si se estropea o alguien se equivoca.

**2.** Al empezar, Terraform intenta crear `<key>.tflock` con una escritura **condicional** de S3 que solo funciona si el objeto no existe. La terminal 1 lo creó y se quedó esperando tu `yes`. La escritura de la terminal 2 falló (`PreconditionFailed`), y Terraform se negó a seguir y enseñó quién tenía el bloqueo. Al terminar o cancelar, el dueño borra el `.tflock`. Si el proceso muere, el bloqueo se queda y se quita con `force-unlock`.

**3.** El bucket del estado es un recurso más, pero su propio estado no puede estar en él antes de que exista. Se crea con una configuración pequeña y aparte, con estado **local**, que se aplica una vez y se guarda en lugar seguro (o se migra después al propio bucket). Y se protege con versionado, sin acceso público y, en Vigía, con `prevent_destroy`.

**4.** Hace fallar cualquier plan que destruya el recurso. En Vigía, en el bucket del estado y, si quieres, en el de informes: perderlos sería perder la memoria de la infraestructura o el historial de los informes.

**Reto 1:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::lab-tfstate-123456789012"},
    {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject"],
     "Resource": "arn:aws:s3:::lab-tfstate-123456789012/labs/clase-94/terraform.tfstate"},
    {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
     "Resource": "arn:aws:s3:::lab-tfstate-123456789012/labs/clase-94/terraform.tfstate.tflock"}
  ]
}
```

**Reto 2:** por ejemplo, `key = "labs/estado/terraform.tfstate"` y `terraform init -migrate-state`. Su estado vive dentro de él: destruirlo con Terraform significaría borrar el bucket que contiene el estado que está usando para borrarlo. Primero tendrías que volver a traer ese estado a local (quitar el `backend.tf` y `terraform init -migrate-state`).

**Reto 3:** el valor por defecto es `env:`. El workspace `default` usa el `key` tal cual; cualquier otro guarda su estado en `<workspace_key_prefix>/<workspace>/<key>`: con `terraform workspace new dev`, en `env:/dev/labs/clase-94/terraform.tfstate`. Así una misma carpeta tiene un estado por workspace dentro del mismo bucket.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| remote backend / partial configuration | backend remoto / configuración parcial |
| state locking / lock file | bloqueo del estado / archivo de bloqueo |
| to migrate state | migrar el estado |
| conditional write | escritura condicional |
| orphaned resources | recursos huérfanos |

🎙️ *"Our Terraform state lives in a versioned, private, encrypted S3 bucket with native locking: use_lockfile writes a lock object with a conditional put, so two applies can never run at once. DynamoDB locking is deprecated. The state bucket itself is bootstrapped once with local state and protected with prevent_destroy."*

## Siguiente

[Clase 97 — La infraestructura de Vigía en código](clase-97-vigia-en-codigo.md)
