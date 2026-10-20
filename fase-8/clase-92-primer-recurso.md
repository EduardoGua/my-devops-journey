# Clase 92 — Instalar Terraform y tu primer recurso

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 75 min · **Bloque:** A. Terraform desde cero

> 💡 **La idea de hoy:** con tus scripts de la CLI describías **los pasos**; con **Terraform** describes **el resultado**: qué quieres que exista. Terraform compara lo que pides con lo que recuerda (su **estado**) y con lo que hay en AWS, te enseña un **plan** y, si dices `yes`, lo aplica. Repetirlo no hace nada, cambiar es editar un archivo y `destroy` conoce el orden. Hoy recorres el ciclo completo con un bucket.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `crear-vpc.sh` y `borrar-vpc.sh`, y por qué el de crear comprobaba si la VPC ya existía (clase 71).
> - Los buckets de S3, sus nombres únicos y las etiquetas `Proyecto` (clase 74).
> - Añadir un repositorio de apt con su llave (clase 10).
> - La cadena de credenciales, `aws login` y el perfil `ecr` con `credential_process` (clases 70 y 75).
> - `.gitignore` y que un secreto en Git se queda para siempre (clase 22).

> 🔤 **Palabras nuevas de hoy:**
> - **infraestructura como código** (IaC): describir la infraestructura en archivos versionados.
> - **imperativo / declarativo**: describir los pasos / describir el resultado.
> - **HCL**: el lenguaje de los archivos `.tf`, con bloques, etiquetas y argumentos.
> - ***provider***: el complemento que sabe hablar con un servicio, como AWS.
> - **plan**: lo que Terraform haría, sin tocar nada.
> - **estado**: el archivo donde Terraform recuerda qué recursos reales corresponden a cada bloque.
> - **`forces replacement`**: la marca del plan que avisa de que un recurso se destruirá y se volverá a crear.

## Objetivo

- Entender qué es la **infraestructura como código** (IaC) y en qué se diferencia de tus scripts de la CLI.
- Instalar Terraform desde el repositorio oficial de HashiCorp.
- Recorrer el ciclo completo con un bucket de S3: `init`, `fmt`, `validate`, `plan`, `apply`, `show` y `destroy`.
- Leer un `plan`: qué se crea (`+`), qué cambia (`~`) y qué se destruye y se vuelve a crear (`-/+`).
- Ver por primera vez el **estado**, la memoria de Terraform, y lo que pasa cuando no coincide con la realidad.

## Por qué importa

En la clase 71 escribiste `crear-vpc.sh` y `borrar-vpc.sh`:
- **el de crear** no sabía qué existía ya: por eso la comprobación al principio;
- **el de borrar** tenía que conocer el orden de las dependencias;
- **ninguno** sabía cambiar algo que ya existía.

Terraform resuelve las tres cosas: describes **cómo quieres que esté** la infraestructura y él calcula qué crear, qué cambiar y en qué orden. Es la herramienta de IaC más pedida en las ofertas de DevOps y cloud.

## Costo esperado

> 💰 **0 USD.** Un bucket vacío durante unos minutos.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan el mismo bucket.

Si la haces en dos mañanas: el primer día, la preparación y las **piezas 1 a 3** (unos 30 min, sin crear nada en AWS); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

**Preparación: instalar Terraform** (10 min). Un repositorio de apt como los de la clase 10, pero de HashiCorp. Primero se guarda su llave, para que `apt` compruebe que los paquetes los firmó HashiCorp; después se añade el repositorio en `/etc/apt/sources.list.d/`:

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version
terraform -install-autocomplete
```

👀 **Qué deberías ver:** `Terraform v1.16.x` (al escribir esta clase, la 1.16.5); `apt upgrade` la mantendrá al día. La última orden añade a tu `~/.bashrc` el autocompletado con el tabulador: abre otra terminal para que funcione.

**Las credenciales:** Terraform usa las mismas que la AWS CLI, por la misma cadena de la clase 70. Con tu `aws login` activo debería bastar. Si al hacer `plan` te dice que no encuentra credenciales, usa el perfil con `credential_process` de la clase 75: `export AWS_PROFILE=ecr`. Ese perfil sirve para cualquier herramienta que todavía no entienda `aws login`.

## Las piezas

### Pieza 1 — Imperativo frente a declarativo

| | Tus scripts de la CLI (fase 6) | Terraform |
|---|---|---|
| Describes | **los pasos**: crea esto, después aquello | **el resultado**: quiero que exista esto |
| Si lo ejecutas dos veces | intenta crearlo todo otra vez | no hace nada: ya está como lo pediste (**idempotente**) |
| Si cambias algo | escribes otro script para cambiarlo | cambias el archivo; Terraform calcula la diferencia |
| Para borrar | otro script, con el orden correcto | `terraform destroy`: conoce las dependencias |
| Qué existe | lo preguntas cada vez a AWS | lo recuerda en su **estado** |

**Pruébalo, en papel.** Quieres añadir una etiqueta `Clase=92` a una subred que ya existe. Escribe qué harías con cada enfoque antes de abrir la respuesta.

<details>
<summary>Comprueba</summary>

Con la CLI, otra orden: `aws ec2 create-tags --resources <ID de la subred> --tags Key=Clase,Value=92`, y tendrías que buscar antes el ID. Con Terraform, añades la etiqueta al bloque de la subred, haces `plan` (que dice `~ update in-place`) y `apply`.
</details>

✋ **Sin mirar:** ¿qué hace Terraform si aplicas dos veces seguidas la misma configuración?

<details>
<summary>Comprueba</summary>

La segunda vez, nada: la infraestructura ya está como la pediste. Es idempotente.
</details>

**En resumen:** imperativo = los pasos; declarativo = el resultado, y Terraform calcula los pasos.

### Pieza 2 — HCL y tu primer archivo

```
escribir .tf ─► terraform init      (descarga el provider de AWS; una vez por carpeta)
            ─► terraform fmt       (formatea el código)
            ─► terraform validate  (¿es correcto el código?)
            ─► terraform plan      (¿qué haría? sin tocar nada)
            ─► terraform apply     (lo hace, después de enseñarte el plan y pedirte "yes")
            ─► terraform destroy   (borra todo lo que creó esta carpeta)
```

Los archivos `.tf` usan **HCL**: bloques con un tipo, unas etiquetas y unos argumentos.

```hcl
resource "aws_s3_bucket" "primero" {   # tipo de bloque, tipo de recurso, nombre local
  bucket_prefix = "lab-terraform-"     # argumento = valor
}
```

El nombre local (`primero`) es para Terraform: así lo citas en otros bloques (`aws_s3_bucket.primero.bucket`). El nombre real del bucket lo decide AWS a partir del prefijo.

**Pruébalo:**

```bash
mkdir -p ~/my-devops-journey/labs/clase-92 && cd ~/my-devops-journey/labs/clase-92
```

Crea `main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "primero" {
  bucket_prefix = "lab-terraform-"

  tags = {
    Proyecto = "lab"
  }
}

output "nombre" {
  value = aws_s3_bucket.primero.bucket
}
```

- **`terraform {}`:** dice qué *provider* necesita esta configuración: el de AWS, en cualquier versión 6.x.
- **`provider "aws"`:** lo configura; aquí, la región.
- **`resource`:** lo que quieres que exista.
- **`output`:** lo que Terraform te dirá al terminar.

👀 **Qué deberías ver:** `ls` muestra solo `main.tf`. Todavía no has ejecutado nada: el archivo es una descripción.

✋ **Sin mirar:** en `resource "aws_s3_bucket" "primero"`, ¿qué es `primero`?

<details>
<summary>Comprueba</summary>

El nombre local: con él citas el recurso en el código (`aws_s3_bucket.primero`). No es el nombre del bucket en AWS.
</details>

**En resumen:** `terraform {}` pide el provider, `provider` lo configura, `resource` describe lo que debe existir, `output` lo que quieres ver.

### Pieza 3 — `init`, `fmt` y `validate`

`init` prepara la carpeta, `fmt` formatea y `validate` comprueba el código **sin preguntar a AWS**. El estilo de Terraform no se discute: `fmt` alinea los `=` y la indentación.

🔮 **Predice:** ¿qué crea `init` en la carpeta?

**Pruébalo:**

```bash
terraform init
ls -la
head -12 .terraform.lock.hcl
terraform fmt
terraform validate
```

👀 **Qué deberías ver:** `Terraform has been successfully initialized!`; en `ls -la`, una carpeta `.terraform/`, con el provider descargado (un ejecutable de cientos de MB), y `.terraform.lock.hcl`, con la versión exacta del provider y sus *hashes*. La carpeta `.terraform/` **no** va a Git; el archivo de bloqueo **sí**, para que todos usen la misma versión del provider (lo verás a fondo en la clase 93). `fmt` imprime el nombre de los archivos que cambió (o nada), y `validate` termina con `Success! The configuration is valid.`

✋ **Sin mirar:** ¿cuál de los dos va a Git: `.terraform/` o `.terraform.lock.hcl`?

<details>
<summary>Comprueba</summary>

`.terraform.lock.hcl` sí, para fijar la versión del provider; `.terraform/` no: es lo descargado, y pesa cientos de MB.
</details>

**En resumen:** `init` descarga el provider y crea el archivo de bloqueo; `fmt` y `validate`, antes de cada `plan`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-92`.

### Pieza 4 — `plan`, `apply` y el estado

Al aplicar, Terraform guarda en `terraform.tfstate` qué recursos creó y sus atributos: el ID de cada uno en AWS.
- Con ese archivo sabe que `aws_s3_bucket.primero` es **ese** bucket concreto.
- Sin él, pensaría que no existe nada y lo crearía otra vez.

Por ahora, el estado vive en tu carpeta. En la clase 96 lo llevarás a S3 con bloqueo, que es como se trabaja de verdad. Dos reglas desde hoy:
1. **El estado no va a Git:** puede contener secretos, y en equipo provoca conflictos.
2. **No se edita a mano:** para eso existen los comandos `terraform state`.

**Pruébalo:**

```bash
terraform plan
```

Lee el plan entero, y después aplícalo (te enseña **otra vez** el plan y pide `yes`: escríbelo):

```bash
terraform apply
terraform output nombre
aws s3 ls | grep lab-terraform
terraform state list
terraform show | head -30
ls -la terraform.tfstate
```

👀 **Qué deberías ver:** en el plan, `+ create` con todos los atributos del bucket, muchos `(known after apply)` (AWS los decide al crear) y, al final, `Plan: 1 to add, 0 to change, 0 to destroy.`: no ha creado nada. Tras el `apply`, `Apply complete! Resources: 1 added`, el nombre del bucket (`lab-terraform-2026…`), el bucket en `aws s3 ls`, `aws_s3_bucket.primero` en el estado, sus atributos en `show` y el archivo `terraform.tfstate`.

🔮 **Predice:** ¿qué hará un segundo `terraform apply`?

```bash
terraform apply
```

👀 **Qué deberías ver:** `No changes. Your infrastructure matches the configuration.` Eso es la **idempotencia**: tu `crear-vpc.sh` necesitaba una comprobación a mano para esto.

✋ **Sin mirar:** ¿por qué el estado no va a Git?

<details>
<summary>Comprueba</summary>

Porque puede contener secretos en texto claro, y en equipo dos copias se desincronizan y se pisan. Va a un backend remoto con bloqueo (clase 96).
</details>

**En resumen:** `plan` enseña, `apply` hace y guarda en el estado; repetir no hace nada.

### Pieza 5 — Cambiar y reemplazar: leer el plan

En un plan:
- **`+`:** crear;
- **`~`:** cambiar en el sitio, sin destruir;
- **`-/+`:** destruir y volver a crear, porque ese cambio no se puede hacer en el sitio. Al lado del atributo culpable sale `# forces replacement`.

**Esta es la línea que hay que buscar en cada plan**: con un bucket vacío no pasa nada; con una base de datos, perderías los datos.

**Pruébalo.** Añade una etiqueta en `tags`: `Clase = "92"`, y planifica y aplica:

```bash
terraform plan
terraform apply
```

🔮 **Predice:** si cambias `bucket_prefix` a `"lab-tf-"`, ¿podrá cambiarlo en el sitio?

Cámbialo y planifica, **sin aplicar**:

```bash
terraform plan
```

👀 **Qué deberías ver:** con la etiqueta, `~ update in-place` y `tags` con la nueva línea `+ "Clase" = "92"`: añadir una etiqueta no destruye nada. Con el prefijo, `-/+ destroy and then create replacement` y, en el atributo, `# forces replacement`: un bucket no se puede renombrar. Deshaz el cambio del prefijo sin aplicarlo.

✋ **Sin mirar:** ¿qué marca del plan te avisa de que un recurso se va a destruir y crear de nuevo?

<details>
<summary>Comprueba</summary>

`-/+` en el recurso y `# forces replacement` junto al atributo que lo provoca.
</details>

**En resumen:** `~` cambia en el sitio; `-/+` con `forces replacement` destruye y crea: búscalo antes de escribir `yes`.

### Pieza 6 — Destruir

`terraform destroy` borra todo lo que creó esta carpeta, en el orden correcto, y deja el estado vacío. También enseña su plan y pide `yes`.

**Pruébalo:**

```bash
terraform destroy
aws s3 ls | grep lab-terraform
terraform state list
```

👀 **Qué deberías ver:** `Plan: 0 to add, 0 to change, 1 to destroy.`, `Destroy complete! Resources: 1 destroyed.`, y ni el bucket en `aws s3 ls` ni nada en `state list`.

✋ **Sin mirar:** ¿qué borra `terraform destroy`?

<details>
<summary>Comprueba</summary>

Todo lo que creó **esta carpeta** y está en su estado; nada más de tu cuenta.
</details>

**En resumen:** `destroy` borra lo de esta configuración, en orden, y vacía el estado.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `terraform init` | descargar el provider y crear `.terraform.lock.hcl` |
| `terraform fmt` · `terraform validate` | formatear · comprobar el código |
| `terraform plan` | qué haría, sin tocar nada |
| `terraform apply` · `terraform destroy` | hacerlo · borrarlo (los dos piden `yes`) |
| `terraform output [-raw] nombre` | el valor de un `output` |
| `terraform state list` · `terraform show` | qué hay en el estado · sus atributos |
| `+` · `~` · `-/+` con `# forces replacement` | crear · cambiar · destruir y crear |
| a Git: `*.tf` y `.terraform.lock.hcl` · fuera: `.terraform/` y `*.tfstate` | qué se versiona |

## Rómpelo

**1. Alguien lo borra a mano.** `terraform apply` para crear el bucket otra vez, bórralo con la CLI y planifica:

```bash
aws s3 rb "s3://$(terraform output -raw nombre)"
terraform plan
```

Terraform **refresca** el estado antes de planificar: pregunta a AWS por cada recurso, descubre que el bucket no está y propone crearlo de nuevo. El código es la verdad, y el plan te enseña cómo volver a ella. En la clase 99 verás esto a fondo: se llama *drift*.

**2. Sin memoria.** Con el bucket creado (`terraform apply`), aparta el estado y planifica:

```bash
mv terraform.tfstate /tmp/
terraform plan
```

`Plan: 1 to add`. Terraform no sabe que el bucket existe. Si aplicaras ahora, crearías un **segundo** bucket, y el primero quedaría huérfano: nadie lo gestiona y tú pagarías por él. No apliques. Devuelve el estado y destruye:

```bash
mv /tmp/terraform.tfstate . && terraform destroy
```

Perder el estado es de los peores incidentes con Terraform. Por eso, en la clase 96, irá a un bucket con versionado.

**3. Sin `init`.** Borra la carpeta del provider y planifica:

```bash
rm -rf .terraform && terraform plan
```

Terraform se niega: falta el provider que exige el archivo de bloqueo, y te dice que hagas `terraform init`.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Busca en la documentación del provider qué argumento haría que `destroy` borre el bucket **aunque tenga objetos**. ¿Por qué no viene activado por defecto?

> 🧩 **Ejemplo resuelto:** `tags` es un argumento del recurso: va dentro del bloque, como `tags = { Proyecto = "lab" }`.

**Ahora tú, con huecos:** en registry.terraform.io → hashicorp/aws → `aws_s3_bucket`, sección *Argument Reference*. Completa: «El argumento es `____ = true`, y no viene activado porque…».

<details>
<summary>Pista</summary>

Busca la palabra *destroy* en esa página. Piensa en qué pasaría con un `terraform destroy` por error en un bucket con datos de verdad.
</details>

**2.** Añade un segundo recurso, `aws_s3_bucket_versioning`, que active el versionado del bucket. ¿En qué orden los crea Terraform, y cómo lo sabe?

> 🧩 **Ejemplo resuelto:** el `output "nombre"` de la pieza 2 cita al bucket con `aws_s3_bucket.primero.bucket`.

**Ahora tú, con huecos:**
```hcl
resource "aws_s3_bucket_versioning" "primero" {
  bucket = aws_s3_bucket.____.____

  versioning_configuration {
    status = "____"
  }
}
```
Completa: «Terraform crea primero ____, porque el versionado…».

<details>
<summary>Pista</summary>

Usa el atributo `id` del bucket. El estado del versionado se escribe como en la clase 74, con mayúscula inicial.
</details>

**3.** ¿Qué pasaría si dos personas aplicaran a la vez esta misma carpeta, cada una con su propio `terraform.tfstate`? Guarda la respuesta para la clase 96.

> 🧩 **Ejemplo resuelto:** el Rómpelo 2: sin el estado, Terraform creería que no existe nada y crearía un segundo bucket.

**Ahora tú, con huecos:** «Cada una tendría ____. Las dos creerían ser…, se pisarían los cambios y podrían crear ____. La solución es un estado ____, con un ____ que impide aplicar a dos a la vez».

<details>
<summary>Pista</summary>

Piensa en qué sabe cada estado de lo que hizo la otra persona: nada.
</details>

## Destruir al terminar

```bash
terraform destroy
aws s3 ls | grep lab-terraform
```

No debe quedar ningún bucket `lab-terraform`. Si te quedó un huérfano del Rómpelo 2, bórralo con `aws s3 rb`. La carpeta `labs/clase-92` puedes subirla a Git: `.gitignore` deja fuera `.terraform/` y el estado, y el archivo `.terraform.lock.hcl` sí debe ir.

## Cierre

En `notas/fase-8/clase-92.md`:

1. ¿Qué diferencia hay entre describir los pasos (tus scripts de la CLI) y describir el resultado (Terraform)? *(2 líneas. Empieza así: «Un script imperativo dice qué hacer, paso a paso:… Con el enfoque declarativo describo…»)*
2. ¿Qué es el estado, para qué lo usa Terraform y por qué no va a Git? *(2–3 líneas. Empieza así: «Es la memoria de Terraform: qué recursos de AWS corresponden a… No va a Git porque…»)*
3. En un plan, ¿qué significan `+`, `~` y `-/+`, y cuál es peligroso? *(3 líneas, una por símbolo. Empieza así: «`+`: crear.»)*
4. **Repaso (clase 91, sin mirar):** ¿qué cuatro partes tiene una historia STAR? *(1 línea.)*

Después, escríbeme `examíname clase-92`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un script **imperativo** dice qué hacer, paso a paso: si lo repites, intenta crear lo que ya existe; para cambiar o borrar hacen falta otros scripts que conozcan el orden. Con el enfoque **declarativo** describes cómo quieres que esté la infraestructura, y Terraform compara eso con lo que existe y calcula los pasos. Repetirlo no hace nada (idempotencia), los cambios son editar un archivo y `destroy` conoce las dependencias.

**2.** Es la memoria de Terraform: qué recursos de AWS corresponden a cada bloque del código, con sus ID y atributos. Con ella sabe qué existe y puede calcular qué cambiar. No va a Git por tres motivos:
- puede contener **secretos** en texto claro;
- es **personal de cada aplicación**: dos copias en dos clones acaban desincronizadas;
- en equipo, dos personas lo sobrescribirían.

Va a un backend remoto con bloqueo (clase 96).

**3.**
- **`+`:** crear.
- **`~`:** cambiar en el sitio, sin destruir.
- **`-/+`:** destruir y volver a crear. Es el peligroso: el recurso viejo desaparece, con sus datos, y el nuevo tendrá otro ID. Hay que buscar `forces replacement` en cada plan.

**4.** Situación, Tarea, Acción y Resultado.

**Reto 1:** `force_destroy = true`. No viene activado porque borraría todos los objetos sin preguntar: en un bucket con datos de verdad, un `destroy` por error sería irreversible.

**Reto 2:** `aws_s3_bucket.primero.id` y `status = "Enabled"`. Primero el bucket y después el versionado, porque el versionado **cita** al bucket (`aws_s3_bucket.primero.id`). Terraform construye un grafo con esas referencias (clase 95).

**Reto 3:** cada una tendría **un estado distinto**. Cada una creería ser la única dueña de los recursos, se pisarían los cambios y podrían crear **duplicados**. La solución es un estado **compartido** (remoto), con un **bloqueo** que impide aplicar a dos a la vez (clase 96).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| infrastructure as code (IaC) | infraestructura como código |
| declarative / imperative | declarativo / imperativo |
| execution plan | plan de ejecución |
| state file | archivo de estado |
| forces replacement | obliga a reemplazar |
| idempotent | idempotente |

🎙️ *"With Terraform I describe the infrastructure I want, review the plan and apply it. It's idempotent, it knows the dependencies, and the state file records which real resources belong to the code. In every plan I look for 'forces replacement' before typing yes."*

## Siguiente

[Clase 93 — Providers, versiones, resources y data](clase-93-providers-y-data.md)
