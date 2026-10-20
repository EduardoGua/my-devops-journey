# Clase 97 — La infraestructura de Vigía en código

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 2 bloques (unas 4 h) · **Bloque:** B. Vigía en código

> 💡 **La idea de hoy:** todo lo que creaste a mano en las fases 6 y 7 pasa a archivos de Terraform. Lo que guarda algo de valor (imágenes, informes, logs, el rol del pipeline) se **adopta** con bloques `import`, sin recrearlo; lo demás se borra y se vuelve a crear desde el código. Y antes de aplicar, se revisa el plan línea a línea.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Todo lo que hiciste a mano: la red (clase 71), el SG (73), S3 (74), ECR (75), los logs (76), la instancia de la v3 con su cloud-init (78 y 79) y el rol OIDC del pipeline (86 y 90).
> - `borrar-vpc.sh` (clase 71) y tu guía de destrucción (clase 79).
> - Variables con validación, `locals`, `for_each` y `jsonencode` (clase 94); `depends_on` y `user_data_replace_on_change` (clase 95).
> - El bucket del estado, el backend parcial y el `.gitignore` del estado (clase 96).

> 🔤 **Palabras nuevas de hoy:**
> - **adoptar** o **importar**: hacer que Terraform gestione un recurso que ya existe, sin recrearlo.
> - **bloque `import`**: `to` (la dirección en tu código) e `id` (el objeto real en AWS).
> - **plan guardado**: `terraform plan -out=archivo`; `terraform apply archivo` aplica exactamente eso.
> - **plan obsoleto** (*stale plan*): un plan guardado que ya no vale, porque el estado cambió después.
> - **`-target`**: limitar una operación a un recurso.

## Objetivo

- Crear el **bucket del estado de Vigía**, protegido para siempre.
- Escribir en Terraform toda la infraestructura que en las fases 6 y 7 creaste a mano:
  - la red y el security group;
  - los roles;
  - el bucket de informes, los logs y ECR;
  - la instancia con su cloud-init;
  - el rol del pipeline.
- **Adoptar** con bloques `import` lo que ya existe y tiene valor (imágenes, informes, logs, el rol del pipeline), en lugar de borrarlo.
- Aplicar, y comprobar que Vigía funciona igual que antes: las pruebas de la v3 en verde y el pipeline de la v4 desplegando en la instancia nueva.

## Por qué importa

Hasta hoy, la infraestructura de Vigía vivía en tu memoria, en tus notas y en la guía del README. Cuando termine esta clase vivirá en archivos:
- revisables en un PR;
- con historial en Git;
- que cualquiera puede aplicar en otra cuenta con su propio `terraform.tfvars`.

Es exactamente lo que harás en un trabajo: "llevar a Terraform" lo que se creó a mano, sin romper lo que está en uso. Se llama **adoptar** o **importar** infraestructura, y es una tarea muy habitual.

## Costo esperado

> 💰 **Unos 0,15 USD por sesión**, como la v3: la t3.small de Vigía y su IPv4. Destruye la instancia al terminar (clase 101).

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la aplicas enseguida a Vigía; no pases a la siguiente sin haber terminado la anterior.

Es una clase larga; repártela en **dos o tres mañanas**:
- **Primer día:** las **piezas 1 a 3** (unos 50 min). Preparas el terreno y conectas el backend.
- **Segundo día:** la **pieza 4** (unos 90 min). Escribes los recursos; no se crea nada en AWS.
- **Tercer día** (o el resto del segundo): las **piezas 5 y 6**, el Rómpelo y el cierre. Aquí se aplica y se crea la instancia, que es lo que cuesta.

Las marcas ⏸️ señalan dónde parar. Hasta la pieza 5 no hay nada que cobre por hora.

## Las piezas

### Pieza 1 — Qué se adopta y qué se recrea

| Recurso de las fases 6 y 7 | Qué hacer | Por qué |
|----------------------------|-----------|---------|
| el repositorio ECR `vigia` | **importar** | tiene tus imágenes, y el pipeline publica ahí |
| el bucket `vigia-informes-<cuenta>` | **importar** | tiene tus informes |
| los grupos `/vigia/api` y `/vigia/checker` | **importar** | tienen logs (7 días) |
| el proveedor OIDC y el rol `vigia-github` | **importar** | el pipeline de la v4 los usa |
| la `lab-vpc`, el SG `vigia-web`, el rol y el perfil `vigia-ec2` | **borrar a mano y recrear** | no tienen datos, y la red nueva será de Vigía, no del laboratorio |

La regla: se importa lo que **guarda algo** o lo que **otro sistema usa** por su nombre; lo demás se recrea desde el código, más limpio.

**Pruébalo.** Borra lo que no se va a adoptar:

```bash
cd ~/my-devops-journey/labs/clase-71 && bash borrar-vpc.sh
aws iam remove-role-from-instance-profile --instance-profile-name vigia-ec2 --role-name vigia-ec2
aws iam delete-instance-profile --instance-profile-name vigia-ec2
for p in $(aws iam list-attached-role-policies --role-name vigia-ec2 --query 'AttachedPolicies[].PolicyArn' --output text); do
  aws iam detach-role-policy --role-name vigia-ec2 --policy-arn "$p"
done
for p in $(aws iam list-role-policies --role-name vigia-ec2 --query 'PolicyNames' --output text); do
  aws iam delete-role-policy --role-name vigia-ec2 --policy-name "$p"
done
aws iam delete-role --role-name vigia-ec2
aws iam get-role --role-name vigia-ec2
```

Es parte de tu guía de destrucción de la clase 79. Si al terminar la fase 7 ya lo habías borrado todo, aquí no hay nada que hacer.

👀 **Qué deberías ver:** `borrar-vpc.sh` termina sin errores, y el último comando falla con `NoSuchEntity`: el rol ya no existe. Antes de borrar el rol hay que quitarle sus políticas y sacarlo del perfil; si no, AWS se niega (`DeleteConflict`).

✋ **Sin mirar:** ¿por qué se importa el repositorio de ECR en lugar de recrearlo?

<details>
<summary>Comprueba</summary>

Porque tiene tus imágenes y el pipeline publica ahí. Recrearlo sería perderlas; importarlo deja todo como está y solo hace que Terraform lo gestione.
</details>

**En resumen:** se adopta lo que guarda datos o lo que otros usan; lo demás se recrea desde el código.

### Pieza 2 — La estructura y el bucket del estado

```
vigia/
├── deploy/cloud-init.yaml      ← el de la v3, con sus marcadores __…__ (Terraform los rellena)
└── infra/
    ├── estado/main.tf          ← el bucket del estado: estado local, se aplica una vez
    ├── versions.tf             ← Terraform, el provider con default_tags y el backend S3
    ├── variables.tf            ← mi_ip, github_user, etiqueta_imagen, los ID de GitHub…
    ├── main.tf                 ← la red, ECR, S3, los logs, los roles, el SG y la instancia
    ├── github.tf               ← el proveedor OIDC y el rol del pipeline
    ├── importar.tf             ← lo que ya existía (se borra cuando se ha importado)
    ├── outputs.tf
    ├── terraform.tfvars.example  ← va a Git
    └── terraform.tfvars          ← tus valores: NO va a Git
```

Los dos directorios tienen **estados distintos**:
- `infra/estado` es pequeño, local y casi nunca cambia;
- `infra` guarda el suyo en el bucket que crea el primero.

**Pruébalo.** La rama y el `.gitignore`:

```bash
cd ~/vigia && git switch main && git pull && git switch -c terraform
mkdir -p infra/estado
cat >> .gitignore <<'EOF'

# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
infra/terraform.tfvars
EOF
```

`infra/estado/main.tf`, como el de la clase 96 pero **para siempre**:

```hcl
# El bucket del estado de Terraform. Se crea una vez, con estado local, antes que todo lo demás.
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
    tags = { Proyecto = "vigia", GestionadoPor = "terraform" }
  }
}

data "aws_caller_identity" "actual" {}

resource "aws_s3_bucket" "estado" {
  bucket = "vigia-tfstate-${data.aws_caller_identity.actual.account_id}"

  lifecycle {
    prevent_destroy = true
  }
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
cd infra/estado && terraform init && terraform apply && cd ..
git status --short
```

👀 **Qué deberías ver:** `Apply complete! Resources: 3 added` y el output `bucket = "vigia-tfstate-<tu cuenta>"`. En `git status`, el `.gitignore` modificado y `infra/` como nuevo, pero no el `terraform.tfstate`: el `.gitignore` lo deja fuera.

Su `terraform.tfstate` local es pequeño y no tiene secretos, pero **no** va a Git. Haz una copia en tus notas privadas o en un gestor de archivos seguro: es lo único que necesitas para gestionar ese bucket.

✋ **Sin mirar:** ¿qué diferencia hay entre este bucket y el de la clase 96?

<details>
<summary>Comprueba</summary>

Este lleva `prevent_destroy` en lugar de `force_destroy`: no se va a destruir nunca, y ningún plan puede borrarlo por error.
</details>

**En resumen:** dos configuraciones, dos estados: el bucket del estado, local y protegido; el resto de Vigía, en ese bucket.

### Pieza 3 — El backend parcial, el provider y las variables

`infra/versions.tf`, con el backend **parcial** (clase 96, Rómpelo 1): sin el nombre del bucket, que lleva tu número de cuenta.

```hcl
terraform {
  required_version = "~> 1.16"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
  backend "s3" {
    key          = "vigia/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Proyecto = "vigia", GestionadoPor = "terraform" }
  }
}
```

`Proyecto = "vigia"` en todo: el `verify-aws.sh` de la v3, el pipeline de la v4 y los permisos de `ssm:SendCommand` dependen de esa etiqueta.

**Pruébalo.** `infra/variables.tf`: escríbelo tú, con descripción y tipo en cada una. Necesitas:
- `region`, con `us-east-1` por defecto;
- `mi_ip`, con una validación que exija una sola IP en `/32` (clase 94);
- `github_user`;
- `etiqueta_imagen`: el SHA de un commit de `main` con imagen en ECR;
- `tipo_instancia`, con `t3.small` por defecto;
- `ami_parametro`, con el parámetro de Canonical por defecto (clase 95);
- `github_repository_id` y `github_owner_id` (clase 86).

`infra/terraform.tfvars.example`, que **sí** va a Git:

```hcl
mi_ip                = "203.0.113.7/32"
github_user          = "TU_USUARIO"
etiqueta_imagen      = "SHA_COMPLETO_DE_UN_COMMIT_DE_MAIN"
github_repository_id = "123456789"
github_owner_id      = "1234567"
```

Copia el ejemplo a `terraform.tfvars` con tus valores reales y conéctate al backend:

```bash
cp terraform.tfvars.example terraform.tfvars   # y edítalo
terraform init -backend-config="bucket=vigia-tfstate-$(aws sts get-caller-identity --query Account --output text)"
```

👀 **Qué deberías ver:** `Successfully configured the backend "s3"!` y `Terraform has been successfully initialized!`. Todavía no hay recursos: el estado de Vigía está vacío.

✋ **Sin mirar:** ¿por qué `terraform.tfvars.example` va a Git y `terraform.tfvars` no?

<details>
<summary>Comprueba</summary>

El ejemplo enseña qué variables hay que dar, con valores inventados. El de verdad lleva tu IP y tus ID: es de tu entorno, no del código.
</details>

**En resumen:** backend parcial con el bucket al inicializar, `default_tags` con `Proyecto = "vigia"` y un `.tfvars.example` para quien venga después.

> ⏸️ Si partes la clase en varias mañanas, el primer día termina aquí. No hay nada que cobre por hora.

### Pieza 4 — Los recursos, y el cloud-init desde Terraform

Escribe `infra/main.tf`, `infra/github.tf` y `infra/outputs.tf`. Este es el mapa: cada fila es algo que ya hiciste a mano, y la columna de la derecha, el recurso de Terraform que lo hace. Busca cada uno en el Registry (clase 93).

| Lo que hiciste a mano (clase) | Recurso de Terraform |
|-------------------------------|----------------------|
| la VPC, la subred pública, la privada, el IGW y las rutas (71) | `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association` |
| el SG `vigia-web`: TCP 80 solo desde tu IP (73, 78) | `aws_security_group`, `aws_vpc_security_group_ingress_rule`, `aws_vpc_security_group_egress_rule` |
| el repositorio ECR y su ciclo de vida (75) | `aws_ecr_repository`, `aws_ecr_lifecycle_policy` |
| el bucket de informes: bloqueo público, versionado, ciclo de vida, solo HTTPS (74, 79) | `aws_s3_bucket` y sus `aws_s3_bucket_public_access_block`, `_versioning`, `_lifecycle_configuration`, `_policy` |
| los grupos de logs con 7 días (76, 79) | `aws_cloudwatch_log_group` |
| el rol `vigia-ec2`, sus dos políticas de AWS y la tuya, y su perfil (78, 79) | `aws_iam_role`, `aws_iam_role_policy_attachment`, `aws_iam_role_policy`, `aws_iam_instance_profile` |
| la AMI de Ubuntu 26.04 (72) | `data "aws_ssm_parameter"` |
| la instancia con IMDSv2, límite de saltos 2 y tu cloud-init (78, 79) | `aws_instance` |
| el proveedor OIDC y el rol del pipeline (86, 90) | `aws_iam_openid_connect_provider`, `aws_iam_role`, `aws_iam_role_policy` |

Tres recursos como ejemplo, para que veas el estilo; los demás, tuyos.

```hcl
data "aws_caller_identity" "actual" {}

locals {
  cuenta = data.aws_caller_identity.actual.account_id
  imagen = "${local.cuenta}.dkr.ecr.${var.region}.amazonaws.com/vigia:${var.etiqueta_imagen}"
}

resource "aws_ecr_repository" "vigia" {
  name                 = "vigia"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "vigia" {
  repository = aws_ecr_repository.vigia.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conserva las 20 imágenes más recientes"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_cloudwatch_log_group" "vigia" {
  for_each          = toset(["api", "checker"])
  name              = "/vigia/${each.key}"
  retention_in_days = 7
}
```

- **`jsonencode()`** escribe el JSON de la política desde un objeto de Terraform. Así escribirás también las políticas de IAM y la del bucket, sin heredocs ni comillas escapadas.
- **Un `for_each`** con un `toset()` crea los dos grupos: `aws_cloudwatch_log_group.vigia["api"]` y `["checker"]`.

**El cloud-init.** La instancia usa **tu** `deploy/cloud-init.yaml` de la v3, con sus marcadores. Terraform puede leer el archivo y sustituirlos con funciones:
- `file()` lee el archivo;
- `replace()`, encadenada, cambia cada marcador por su valor: la imagen, la región, el bucket y tu usuario de GitHub (pista 1).

Con `user_data_replace_on_change = true` (clase 95), cambiar la imagen en `terraform.tfvars` crea una instancia nueva, como hacía tu guía de la v3.

¿Por qué no `templatefile()`? Porque tu script usa `${…}` de Bash, como `${IMAGEN%%/*}`, y `templatefile` intentaría interpretarlo como suyo. Habría que escaparlo todo con `$${…}`.

**Pruébalo.** Escribe los recursos con el mapa y las pistas de abajo. Cuando lo tengas:

```bash
terraform fmt
terraform validate
```

👀 **Qué deberías ver:** `terraform fmt` lista los archivos que ha reordenado (o nada, si ya estaban bien), y `validate` termina con `Success! The configuration is valid.` Si falla, el mensaje dice el archivo y la línea: suele ser una referencia a un recurso con otro nombre.

✋ **Sin mirar:** ¿por qué usas `replace()` y no `templatefile()` con tu `cloud-init.yaml`?

<details>
<summary>Comprueba</summary>

Porque el script usa `${…}` de Bash (`${IMAGEN%%/*}`), y `templatefile` lo interpretaría como suyo. Con `replace()` solo se tocan los marcadores `__…__`.
</details>

**En resumen:** cada paso que hiciste a mano es un recurso; el cloud-init se lee con `file()` y se rellena con `replace()`.

> ⏸️ Si partes la clase en varias mañanas, el segundo día termina aquí. Mañana empiezas aplicando: reserva tiempo para terminar y destruir la instancia el mismo día.

### Pieza 5 — Adoptar con `import`

Un bloque **`import`** dice "este recurso del código es **ese** objeto que ya existe en AWS":

```hcl
import {
  to = aws_ecr_repository.vigia
  id = "vigia"
}
```

- **Lo que pasa:** en el siguiente `plan`, Terraform lo lee y lo apunta en el estado; no crea nada.
- **El `id`:** depende del tipo de recurso. Lo dice la sección *Import* de su página en el Registry: un nombre, un ARN, `rol:política`…
- **Si el código no coincide exactamente con lo que existe,** el plan propone cambios para igualarlo. Por ejemplo, añadir las etiquetas de `default_tags`. Léelos: **nunca** debe salir un reemplazo (`-/+`) en algo que importas.
- **Un plan guardado** (`plan -out`) y después `apply` de ese archivo garantiza que se aplica exactamente lo que revisaste.

En la clase 99 verás el resto: generar el código de lo importado, y olvidar un recurso sin borrarlo.

**Pruébalo.** `infra/importar.tf`:

```hcl
# Lo que ya existía, creado a mano en las fases 6 y 7: Terraform lo adopta sin recrearlo.
import {
  to = aws_ecr_repository.vigia
  id = "vigia"
}

import {
  to = aws_s3_bucket.informes
  id = "vigia-informes-${local.cuenta}"
}

import {
  for_each = toset(["api", "checker"])
  to       = aws_cloudwatch_log_group.vigia[each.key]
  id       = "/vigia/${each.key}"
}

import {
  to = aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::${local.cuenta}:oidc-provider/token.actions.githubusercontent.com"
}

import {
  to = aws_iam_role.github
  id = "vigia-github"
}
```

Ajusta los nombres de la izquierda (`to`) a los de **tu** código. Si al terminar la fase 7 borraste alguno de esos recursos, quita su bloque.

¿Y las piezas del bucket (versionado, bloqueo, ciclo de vida, política) o la política del rol del pipeline? No hace falta importarlas: al "crearlas", Terraform escribe su configuración encima de la que había, sin borrar nada.

🔮 **Predice:** ¿qué dirá la última línea del plan?

```bash
terraform plan -out=vigia.tfplan
```

👀 **Qué deberías ver:** algo como `Plan: 6 to import, 23 to add, 5 to change, 0 to destroy`. Los cambios son, sobre todo, las etiquetas de `default_tags` en lo importado y las condiciones de la política de confianza del rol del pipeline.

Revisa el plan línea a línea, buscando dos cosas:
- **ningún `-/+`** en algo importado;
- **ningún `destroy`.**

Si ves un reemplazo en el repositorio de ECR o en el bucket, para: algún argumento de tu código no coincide con la realidad (por ejemplo, el nombre del bucket). Cuando el plan esté limpio:

```bash
terraform apply vigia.tfplan
terraform output
```

Con el `apply` terminado, borra `importar.tf`: lo importado ya está en el estado, y el siguiente `plan` debe decir `No changes`.

✋ **Sin mirar:** en el plan de algo que importas aparece un `-/+`. ¿Qué significa y qué haces?

<details>
<summary>Comprueba</summary>

Que algún argumento de tu código no coincide con lo que existe y no se puede cambiar en el sitio (por ejemplo, el nombre), así que Terraform lo borraría y lo crearía de nuevo, con sus datos. No apliques: corrige el código hasta que el plan no tenga reemplazos.
</details>

**En resumen:** `import` adopta sin recrear; revisa que no haya `-/+` ni `destroy` y aplica el plan guardado.

### Pieza 6 — ¿Funciona Vigía?

La instancia es nueva: tarda unos minutos en instalar Docker y arrancar Compose. Las mismas pruebas de la v3 dicen si Terraform la ha dejado igual que tu guía.

**Pruébalo:**

```bash
URL=$(terraform output -raw url) && sleep 240 && curl -s "$URL/health"; echo
VIGIA_BUCKET=$(terraform output -raw bucket_informes) bash ~/my-devops-journey/recursos/vigia/v3/verify-aws.sh
```

Si el informe de hoy no está, lánzalo a mano como en la clase 79 (`sudo systemctl start vigia-report.service`, por Session Manager).

👀 **Qué deberías ver:** `/health` devuelve un JSON con `"status": "ok"`, y `verify-aws.sh` termina en `Fallos: 0`.

Para terminar, que el pipeline de la v4 despliegue en esta instancia: lanza tu workflow a mano con el SHA de `main` (clase 90). Si la instancia lleva la etiqueta `Proyecto=vigia`, el pipeline la encuentra.

Commit y PR (sin `terraform.tfvars` ni estados: compruébalo con `git status`).

✋ **Sin mirar:** ¿por qué el pipeline de la v4 encuentra la instancia nueva sin que cambies nada en él?

<details>
<summary>Comprueba</summary>

Porque busca la instancia por la etiqueta `Proyecto=vigia`, no por su ID, y `default_tags` se la pone. El rol del pipeline también es el mismo: lo importaste.
</details>

**En resumen:** las pruebas de la v3 y el pipeline de la v4 confirman que la Vigía de Terraform es la misma que la de tu guía.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `import { to = aws_x.y  id = "…" }` | adoptar un recurso que ya existe |
| `import { for_each = …  to = aws_x.y[each.key] … }` | adoptar varios a la vez |
| `terraform plan -out=vigia.tfplan` · `terraform apply vigia.tfplan` | revisar un plan y aplicar exactamente ese |
| `terraform init -backend-config="bucket=…"` | backend parcial |
| `replace(file("…"), "__X__", valor)` | rellenar marcadores de un archivo |
| `jsonencode({ … })` | una política JSON desde un objeto |
| `terraform destroy -target=aws_instance.vigia` | destruir un solo recurso |

## Pistas

<details><summary>Pista 1 — el cloud-init con <code>replace()</code></summary>

```hcl
  user_data_replace_on_change = true
  user_data = replace(replace(replace(replace(
    file("${path.module}/../deploy/cloud-init.yaml"),
    "__IMAGE__", local.imagen),
    "__REGION__", var.region),
    "__BUCKET__", aws_s3_bucket.informes.bucket),
  "__GITHUB_USER__", var.github_user)
```

`path.module` es la carpeta del archivo `.tf`. Compruébalo en `terraform console`: `regexall("__[A-Z_]+__", aws_instance.vigia.user_data)` debe devolver una lista vacía, `[]`. Si devuelve algo, es el marcador que se quedó sin sustituir.
</details>

<details><summary>Pista 2 — la instancia arranca antes de que existan los logs</summary>

El driver `awslogs` falla si el grupo de logs no existe o si el rol aún no tiene permiso para escribir (clase 79). La instancia no cita esos recursos, así que Terraform no sabe que tiene que esperarlos: añade un `depends_on` con los grupos de logs y la política del rol (clase 95).
</details>

<details><summary>Pista 3 — IMDSv2 y el límite de saltos</summary>

```hcl
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
```

El 2 es por el contenedor del informe (clase 79).
</details>

<details><summary>Pista 4 — las políticas de IAM con <code>jsonencode</code></summary>

La política de confianza del rol de la instancia:

```hcl
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
```

En las de permisos, usa los atributos de los recursos en lugar de escribir ARN a mano: `"${aws_s3_bucket.informes.arn}/reports/*"` o `aws_ecr_repository.vigia.arn`. Si cambia el nombre de algo, la política lo sigue sola.
</details>

<details><summary>Pista 5 — la política del bucket falla al crearla</summary>

Si Terraform intenta poner la política (`aws_s3_bucket_policy`) antes que el bloqueo del acceso público, AWS puede rechazarla. La política no cita al bloqueo, así que añade `depends_on = [aws_s3_bucket_public_access_block.informes]`.
</details>

<details><summary>Pista 6 — el plan quiere reemplazar el rol del pipeline</summary>

Comprueba el `name` del recurso: si en tu código no es exactamente `vigia-github`, Terraform entiende que es otro rol. El nombre de un rol no se puede cambiar, así que intenta reemplazarlo. Y el pipeline dejaría de funcionar hasta que actualizaras `AWS_ROLE_ARN`.
</details>

## Rómpelo

1. **Un marcador sin sustituir.** Quita uno de los `replace()` y planifica. ¿Lo ves en el plan? El *user-data* aparece entero en el plan: busca `__REGION__`. Si aplicaras, cloud-init escribiría `__REGION__` en el `.env` y el driver de logs fallaría. Deshazlo.
2. **Importar algo que no existe.** Cambia el `id` del bloque de ECR por `vigia-no-existe` (antes de borrar `importar.tf`, o vuelve a crearlo un momento) y planifica: `Cannot import non-existent remote object`. Terraform comprueba que existe.
3. **Un plan guardado que caduca.**
   1. Guarda un plan con un cambio pequeño: la retención de `/vigia/api` a 14 días, con `terraform plan -out=uno.tfplan`.
   2. **Sin aplicarlo,** vuelve a poner 7 días y haz otro cambio cualquiera con un `apply` normal, por ejemplo una etiqueta: el estado cambia.
   3. Aplica el plan guardado: `terraform apply uno.tfplan`.

   *Saved plan is stale*: Terraform rechaza un plan si el **estado** cambió desde que lo guardaste, porque ya no sabe si sus pasos siguen siendo válidos. Planifica de nuevo y bórralo: `rm uno.tfplan`.

   Ojo: un cambio hecho **a mano** en AWS no cambia el estado, así que no invalida un plan guardado. Eso es el *drift*, de la clase 99.

## Destruir al terminar

**Termina solo la instancia**, que es lo que cobra por hora, y deja todo lo demás:

```bash
terraform destroy -target=aws_instance.vigia
```

`-target` limita la operación a un recurso. Úsalo poco: un estado aplicado a trozos se desordena con facilidad. En la clase 101 aprenderás a destruirlo y recrearlo **todo** de un golpe, que es el objetivo de la fase.

## Cierre

En `notas/fase-8/clase-97.md`:

1. ¿Qué recursos importaste y cuáles recreaste? ¿Por qué cada uno? *(2 líneas. Empieza así: «Importé…, porque guardan… o los usa… Recreé…, porque…»)*
2. ¿Por qué el bucket del estado tiene su propia configuración y su estado local? *(2 líneas. Empieza así: «Porque el bucket tiene que existir antes de que…»)*
3. ¿Qué buscas en el plan antes de aplicar algo que importa recursos, y por qué aplicas un plan guardado? *(2 líneas. Empieza así: «Que nada importado salga con…»)*
4. **Repaso (clase 96, sin mirar):** ¿por qué el bloque `backend` no admite variables y cómo le pasas el nombre del bucket? *(1–2 líneas. Empieza así: «Porque el backend se configura antes de…»)*

Después, escríbeme `examíname clase-97`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Comprueba tu entrega:**
- [ ] `terraform plan` → `No changes`.
- [ ] `verify-aws.sh` de la v3 → `Fallos: 0`.
- [ ] El pipeline de la v4 despliega en la instancia nueva.
- [ ] `git status` no muestra ni `terraform.tfvars` ni ningún `.tfstate`; `.terraform.lock.hcl` sí está en el commit.

**Cierre:**
1. **Importados:** el repositorio de ECR (con las imágenes que publica el pipeline), el bucket de informes (con los informes), los grupos de logs, el proveedor OIDC y el rol `vigia-github`, que usa el pipeline. **Recreados:** la red, el SG, el rol y el perfil de la instancia y la propia instancia, que no guardan nada que perder y son más limpios hechos desde cero.
2. Porque el bucket tiene que existir **antes** de que la configuración principal pueda guardar su estado en él: no puede estar dentro del estado que contiene. Una configuración pequeña y aparte, con estado local, lo crea una vez. Y `prevent_destroy` impide borrarlo por error.
3. Que nada importado salga con `-/+` ni con `destroy` (eso indicaría que el código no coincide con lo que existe), y que los cambios en el sitio sean los que esperas, como las etiquetas. Se aplica un plan **guardado** para que se haga exactamente lo que revisaste: si el estado cambió entretanto, por otro `apply`, Terraform lo rechaza.
4. Porque el backend se configura antes de evaluar el resto de la configuración, incluidas las variables. El nombre se pasa al inicializar, con la configuración parcial: `terraform init -backend-config="bucket=vigia-tfstate-<cuenta>"`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to import existing infrastructure | importar infraestructura existente |
| saved plan / stale plan | plan guardado / plan obsoleto |
| bootstrap configuration | configuración de arranque |
| to target a resource | limitar la operación a un recurso |
| infrastructure adoption | adopción de infraestructura |

🎙️ *"I moved Vigía's infrastructure from manual CLI steps to Terraform. Stateful resources like the ECR repository, the reports bucket and the CI role were adopted with import blocks, the rest was recreated, and the plan was reviewed line by line before applying a saved plan."*

## Siguiente

[Clase 98 — Módulos](clase-98-modulos.md)
