# Clase 96 — El estado: backend S3 con bloqueo

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 90 min · **Bloque:** A. Terraform desde cero

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

## Teoría

### Qué hay en el estado

`terraform.tfstate` es un JSON con:
- **la versión de Terraform**, un **`serial`** (cuántas veces ha cambiado) y un **`lineage`** (la identidad de ese estado);
- **cada recurso** con su dirección (`aws_vpc.lab`) y **todos** sus atributos tal como los devolvió AWS: ID, ARN y también cualquier valor sensible, **en texto claro**.

De ahí salen sus tres reglas:

| Regla | Por qué |
|-------|---------|
| fuera de Git | puede tener secretos, y cada clon tendría una copia distinta |
| en un sitio compartido, con bloqueo | si dos procesos escriben a la vez, el estado se corrompe |
| con historial | si se estropea o se pierde, tiene que poder recuperarse |

Un bucket de S3 con versionado y con el acceso público bloqueado (clase 74) cumple las tres.

### El backend S3

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
- **El bloque `backend` no admite variables:** se evalúa antes que todo lo demás. Lo que cambie entre cuentas, como el nombre del bucket, se pasa al inicializar: `terraform init -backend-config="bucket=…"`. Es la **configuración parcial** que usará Vigía.
- **Cómo bloquea:** con `use_lockfile`, Terraform escribe junto al estado un objeto `terraform.tfstate.tflock` con una **escritura condicional** ("créalo solo si no existe"). Si otro proceso ya lo tiene, la escritura falla y Terraform se niega a seguir. Al terminar, lo borra.
- **Permisos:** quien use el backend necesita `s3:ListBucket` en el bucket, `s3:GetObject` y `s3:PutObject` en el estado, y además `s3:DeleteObject` en el `.tflock`.

### El huevo y la gallina

El bucket del estado es un recurso de AWS, y te gustaría crearlo con Terraform… ¿pero dónde guardas el estado del bucket del estado?

La práctica habitual:
1. una configuración **pequeña y aparte** crea el bucket con estado **local**;
2. se aplica una vez;
3. su `terraform.tfstate` se guarda en sitio seguro, o se migra al propio bucket.

Ese bucket lleva `prevent_destroy` (clase 95): borrarlo sería borrar la memoria de toda tu infraestructura.

### Los comandos de `terraform state`

| Orden | Qué hace |
|-------|----------|
| `terraform state list` | las direcciones de todo lo que gestiona |
| `terraform state show <dirección>` | los atributos de un recurso |
| `terraform state pull` | el estado entero, en JSON |
| `terraform state mv <de> <a>` | cambiar la dirección de un recurso sin destruirlo. Hoy se prefiere un bloque `moved` (clase 98) |
| `terraform state rm <dirección>` | olvidar un recurso **sin** borrarlo de AWS. Hoy se prefiere un bloque `removed` (clase 99) |
| `terraform force-unlock <ID>` | quitar un bloqueo que se quedó colgado. Solo si estás seguro de que nadie está aplicando |

**Workspaces:** `terraform workspace` permite varios estados para una misma carpeta (por ejemplo, `dev` y `prod`). En este curso usarás lo más claro y lo más común en AWS: un `key` distinto por entorno.

## Práctica guiada

### 1. El bucket del estado (15 min)

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

```bash
terraform init && terraform apply
BUCKET=$(terraform output -raw bucket)
aws s3api get-bucket-versioning --bucket "$BUCKET"
```

`force_destroy` deja que `destroy` vacíe el bucket al final de la clase. En Vigía (clase 97) será al revés: `prevent_destroy`.

### 2. Llevar un estado local a S3 (15 min)

Usa la configuración de la clase 94: vuelve a crearla con estado local.

```bash
cd ~/my-devops-journey/labs/clase-94 && terraform apply
ls -la terraform.tfstate
```

Crea `backend.tf` en esa carpeta (cambia el número de cuenta por el tuyo):

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

```bash
terraform init -migrate-state
```

🔮 **Predice:** ¿qué te pregunta? Si quieres **copiar** el estado existente al backend nuevo. Contesta `yes`. Comprueba:

```bash
aws s3 ls "s3://$BUCKET" --recursive
terraform state list
terraform plan
```

El estado está en S3 y el plan dice `No changes`: Terraform sigue sabiendo qué es suyo. Borra la copia local, que ya no se usa y solo puede confundir:

```bash
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan
```

Sigue funcionando: ahora lee de S3.

### 3. El bloqueo, con dos terminales (20 min)

En la **terminal 1**, empieza un cambio y **no contestes** a la pregunta:

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

🔮 **Predice:**
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

`force-unlock` solo se usa si **sabes** que nadie está aplicando. Si lo usas con un `apply` de verdad a medias, dos procesos escribirán el mismo estado.

### 4. Los comandos del estado (10 min)

```bash
terraform state list
terraform state show 'aws_subnet.esta["publica-a"]'
terraform state pull | jq '{version, terraform_version, serial, lineage, recursos: (.resources | length)}'
```

Las comillas simples alrededor de la dirección hacen falta: `[` y `"` significan algo para Bash.

### 5. Volver atrás con las versiones (10 min)

Aplica un cambio (`terraform apply -var 'etiquetas={Nota="v2"}'`) y mira las versiones del estado:

```bash
aws s3api list-object-versions --bucket "lab-tfstate-$(aws sts get-caller-identity --query Account --output text)" \
  --prefix labs/clase-94/terraform.tfstate --query 'Versions[].[VersionId,LastModified,Size]' --output table
```

Cada `apply` dejó una versión. Si un estado se corrompiera, descargarías la anterior con `aws s3api get-object --version-id …` (clase 74) y la restaurarías con `terraform state push`. Nunca lo hagas con prisa: primero entiende qué cambió entre las dos.

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

1. Escribe la política de IAM **mínima** para que un rol pueda usar el backend de la clase 94 (y solo ese `key`), según los permisos de la teoría. La usarás en la clase 100 para el rol del pipeline.
2. Migra el estado del bucket del estado (`labs/clase-96/estado`) a su propio bucket, con otro `key`. ¿Qué problema aparece si algún día quieres destruir ese bucket con Terraform?
3. Lee en la documentación del backend S3 qué hace el argumento `workspace_key_prefix`, y cómo se combina con `terraform workspace new dev`.

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

1. ¿Qué guarda el estado y por qué tiene que estar en un sitio compartido, con bloqueo y con historial?
2. ¿Cómo funciona el bloqueo con `use_lockfile`, y qué pasó en tu terminal 2?
3. ¿Qué es el problema del huevo y la gallina del bucket del estado, y cómo lo resolviste?
4. **Repaso (clase 95, sin mirar):** ¿para qué sirve `prevent_destroy`, y dónde lo pondrás en Vigía?

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

**Reto 2:** su estado vive dentro de él. Destruirlo con Terraform significaría borrar el bucket que contiene el estado que está usando para borrarlo. Primero tendrías que migrar ese estado a local (`terraform init -migrate-state` sin backend).
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
