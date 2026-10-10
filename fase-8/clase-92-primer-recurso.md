# Clase 92 — Instalar Terraform y tu primer recurso

**Dónde:** tu Ubuntu + AWS · **Tiempo:** 75 min · **Bloque:** A. Terraform desde cero

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

## Teoría

### Imperativo frente a declarativo

| | Tus scripts de la CLI (fase 6) | Terraform |
|---|---|---|
| Describes | **los pasos**: crea esto, después aquello | **el resultado**: quiero que exista esto |
| Si lo ejecutas dos veces | intenta crearlo todo otra vez | no hace nada: ya está como lo pediste (**idempotente**) |
| Si cambias algo | escribes otro script para cambiarlo | cambias el archivo; Terraform calcula la diferencia |
| Para borrar | otro script, con el orden correcto | `terraform destroy`: conoce las dependencias |
| Qué existe | lo preguntas cada vez a AWS | lo recuerda en su **estado** |

### El ciclo de trabajo

```
escribir .tf ─► terraform init      (descarga el provider de AWS; una vez por carpeta)
            ─► terraform fmt       (formatea el código)
            ─► terraform validate  (¿es correcto el código?)
            ─► terraform plan      (¿qué haría? sin tocar nada)
            ─► terraform apply     (lo hace, después de enseñarte el plan y pedirte "yes")
            ─► terraform destroy   (borra todo lo que creó esta carpeta)
```

Los archivos `.tf` usan **HCL**, el lenguaje de HashiCorp: bloques con un tipo, unas etiquetas y unos argumentos.

```hcl
resource "aws_s3_bucket" "primero" {   # tipo de bloque, tipo de recurso, nombre local
  bucket_prefix = "lab-terraform-"     # argumento = valor
}
```

El nombre local (`primero`) es para Terraform: así lo citas en otros bloques (`aws_s3_bucket.primero.bucket`). El nombre real del bucket lo decide AWS a partir del prefijo.

### El estado

Al aplicar, Terraform guarda en `terraform.tfstate` qué recursos creó y sus atributos: el ID de cada uno en AWS.
- Con ese archivo sabe que `aws_s3_bucket.primero` es **ese** bucket concreto.
- Sin él, pensaría que no existe nada y lo crearía otra vez.

Por ahora, el estado vive en tu carpeta. En la clase 96 lo llevarás a S3 con bloqueo, que es como se trabaja de verdad.

Dos reglas desde hoy:
1. **El estado no va a Git:** puede contener secretos, y en equipo provoca conflictos.
2. **No se edita a mano:** para eso existen los comandos `terraform state`.

## Práctica guiada

### 1. Instalar Terraform (10 min)

Un repositorio de apt como los de la clase 10, pero de HashiCorp. Primero se guarda su llave, para que `apt` compruebe que los paquetes los firmó HashiCorp; después se añade el repositorio en `/etc/apt/sources.list.d/`:

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version
terraform -install-autocomplete
```

🔮 **Predice:** ¿qué versión instala? La última 1.16 (al escribir esta clase, la 1.16.5). `apt upgrade` la mantendrá al día.

La última orden añade a tu `~/.bashrc` el autocompletado con el tabulador: abre otra terminal para que funcione.

**Las credenciales:** Terraform usa las mismas que la AWS CLI, por la misma cadena de la clase 70. Con tu `aws login` activo debería bastar. Si al hacer `plan` te dice que no encuentra credenciales, usa el perfil con `credential_process` de la clase 75: `export AWS_PROFILE=ecr`. Ese perfil sirve para cualquier herramienta que todavía no entienda `aws login`.

### 2. Tu primer archivo (10 min)

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

### 3. `init`, `fmt` y `validate` (10 min)

```bash
terraform init
ls -la
cat .terraform.lock.hcl | head -12
terraform fmt
terraform validate
```

🔮 **Predice:** ¿qué crea `init` en la carpeta? `.terraform/`, con el provider descargado (un ejecutable de cientos de MB), y `.terraform.lock.hcl`, con la versión exacta y sus *hashes*. La carpeta `.terraform/` **no** va a Git; el archivo de bloqueo **sí**, para que todos usen la misma versión del provider. Lo verás a fondo en la clase 93.

`fmt` alinea los `=` y la indentación: el estilo de Terraform no se discute. `validate` comprueba que el código es correcto sin preguntar a AWS.

### 4. `plan` y `apply` (15 min)

```bash
terraform plan
```

Lee el plan entero:
- `+ create` con todos los atributos del bucket;
- muchos marcados como `(known after apply)`, porque AWS los decide al crear;
- al final, `Plan: 1 to add, 0 to change, 0 to destroy.`

No ha creado nada. Ahora sí:

```bash
terraform apply
```

Te enseña **otra vez** el plan y pide `yes`. Escríbelo.

```bash
terraform output nombre
aws s3 ls | grep lab-terraform
terraform state list
terraform show | head -30
ls -la terraform.tfstate
```

El bucket existe, y el estado lo recuerda con todos sus atributos. Ahora repite:

```bash
terraform apply
```

🔮 **Predice:** ¿qué hará la segunda vez? Nada: `No changes. Your infrastructure matches the configuration.` Eso es la **idempotencia**: tu `crear-vpc.sh` necesitaba una comprobación a mano para esto.

### 5. Cambiar y reemplazar (15 min)

Añade una etiqueta en `tags`: `Clase = "92"`.

```bash
terraform plan
```

`~ update in-place`: añadir una etiqueta no necesita destruir nada. Aplícalo.

Ahora cambia `bucket_prefix` a `"lab-tf-"` y vuelve a planificar.

🔮 **Predice:** ¿podrá cambiarlo en el sitio? No. Un bucket no se puede renombrar, así que verás `-/+ destroy and then create replacement`, y en el atributo, `# forces replacement`.

**Esta es la línea que hay que buscar en cada plan**: con un bucket vacío no pasa nada; con una base de datos, perderías los datos. Deshaz el cambio sin aplicarlo.

### 6. Destruir (5 min)

```bash
terraform destroy
aws s3 ls | grep lab-terraform
terraform state list
```

Pide `yes`, borra el bucket y deja el estado vacío.

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

1. Busca en la documentación del provider (registry.terraform.io → hashicorp/aws → `aws_s3_bucket`) qué argumento haría que `destroy` borre el bucket **aunque tenga objetos**. ¿Por qué no viene activado por defecto?
2. Añade un segundo recurso, `aws_s3_bucket_versioning`, que active el versionado del bucket. Pista: necesita `bucket = aws_s3_bucket.primero.id`. ¿En qué orden los crea Terraform y cómo lo sabe?
3. ¿Qué pasaría si dos personas aplicaran a la vez esta misma carpeta, cada una con su propio `terraform.tfstate`? Guarda la respuesta para la clase 96.

## Destruir al terminar

```bash
terraform destroy
aws s3 ls | grep lab-terraform
```

No debe quedar ningún bucket `lab-terraform`. Si te quedó un huérfano del Rómpelo 2, bórralo con `aws s3 rb`. La carpeta `labs/clase-92` puedes subirla a Git: `.gitignore` deja fuera `.terraform/` y el estado, y el archivo `.terraform.lock.hcl` sí debe ir.

## Cierre

En `notas/fase-8/clase-92.md`:

1. ¿Qué diferencia hay entre describir los pasos (tus scripts de la CLI) y describir el resultado (Terraform)?
2. ¿Qué es el estado, para qué lo usa Terraform y por qué no va a Git?
3. En un plan, ¿qué significan `+`, `~` y `-/+`, y cuál es peligroso?
4. **Repaso (clase 91, sin mirar):** ¿qué cuatro partes tiene una historia STAR?

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

**Reto 2:** primero el bucket y después el versionado, porque el versionado **cita** al bucket (`aws_s3_bucket.primero.id`). Terraform construye un grafo con esas referencias (clase 95).

**Reto 3:** cada una tendría un estado distinto. Cada una creería ser la única dueña de los recursos, se pisarían los cambios y podrían crear duplicados. La solución es un estado compartido, con un **bloqueo** que impide aplicar a dos a la vez (clase 96).
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
