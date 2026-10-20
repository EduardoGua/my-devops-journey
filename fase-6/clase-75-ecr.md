# Clase 75 — ECR: tu registro de imágenes

**Dónde:** tu Ubuntu (Docker + AWS CLI) · **Tiempo:** 75 min · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** en AWS, las imágenes de una empresa viven en **ECR**: un registro privado por región, con permisos de IAM, cerca de tus servidores y sin límites de descarga. Hoy creas un repositorio con **etiquetas inmutables** (una versión subida no se puede cambiar) y **escaneo** de vulnerabilidades al subir, subes una imagen, le pones una política de **ciclo de vida** y ves cómo la descargará una EC2 sin `docker login`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las etiquetas, los *digest*, `docker login`, `push` y el `credsStore` de Docker (clase 64).
> - `trivy` (clase 59) y los Dockerfile (clase 58).
> - Las políticas de IAM (clase 69) y el ciclo de vida de S3 (clase 74).
> - El rol de la instancia y el IMDS (clase 72).

> 🔤 **Palabras nuevas de hoy:**
> - **ECR** (*Elastic Container Registry*): el registro de imágenes de AWS; uno por cuenta y región.
> - **etiquetas inmutables**: una etiqueta subida no se puede volver a usar para otra imagen.
> - **escaneo al subir** (*scan on push*): ECR revisa cada imagen en busca de vulnerabilidades al recibirla.
> - **política de ciclo de vida**: reglas que borran imágenes viejas o sin etiqueta.
> - ***credential helper***: un programa al que Docker pide las credenciales en lugar de guardarlas.
> - **Amazon Inspector**: el servicio que busca vulnerabilidades en EC2, imágenes de ECR y Lambda.

## Objetivo

- Crear un repositorio privado en **ECR** con etiquetas **inmutables** y **escaneo** de vulnerabilidades al subir.
- Autenticar Docker contra ECR y subir una imagen.
- Leer el resultado del escaneo y compararlo con `trivy` (clase 59).
- Escribir una **política de ciclo de vida** para no acumular imágenes viejas.
- Entender cómo descargará la imagen una EC2 **sin `docker login`**: con su rol y el *credential helper*.

## Por qué importa

En la fase 5 publicaste en Docker Hub. En AWS, las imágenes de una empresa viven en **ECR**, por varias razones:
- es privado por defecto;
- los permisos son de IAM;
- está en la misma región que tus servidores: la descarga es rápida y no paga transferencia;
- no tiene los límites de descarga de Docker Hub.

Vigía v3 se descargará de aquí (clase 78). En la fase 7, GitHub Actions construirá y subirá cada versión a ECR, y en la 9 Kubernetes la descargará de ahí.

## Costo esperado

> 💰 **Prácticamente 0 USD.** ECR cobra 0,10 USD por GB y mes de almacenamiento; tu imagen pesa unos 20 MB comprimida y vivirá una hora. Descargar desde una EC2 de la misma región es gratis.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto, la limpieza y el cierre. El token de `docker login` dura 12 horas: al volver, repite el `docker login` de la pieza 2.

```bash
mkdir -p ~/my-devops-journey/labs/clase-75 && cd ~/my-devops-journey/labs/clase-75
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
echo "$REGISTRO"
```

## Las piezas

### Pieza 1 — Registro, repositorio y etiqueta

```
123456789012.dkr.ecr.us-east-1.amazonaws.com / lab-web : 1.0.0
└────────────── registro ──────────────────┘  └repo─┘  └etiqueta┘
```

- Cada cuenta tiene **un registro por región**.
- Dentro hay **repositorios**, uno por imagen (`vigia`, `lab-web`…), y en cada repositorio, las versiones con sus **etiquetas**.
- A diferencia de Docker Hub, el repositorio **se crea antes** de subir: un `docker push` a un repositorio que no existe falla (Rómpelo 2).

**Pruébalo:**

```bash
aws ecr create-repository --repository-name lab-web \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --tags Key=Proyecto,Value=lab \
  --query 'repository.repositoryUri' --output text
aws ecr describe-repositories --repository-names lab-web \
  --query 'repositories[0].[imageTagMutability,imageScanningConfiguration.scanOnPush,encryptionConfiguration.encryptionType]' --output text
```

👀 **Qué deberías ver:** la URI del repositorio, `<cuenta>.dkr.ecr.us-east-1.amazonaws.com/lab-web`, y `IMMUTABLE True AES256`: inmutable, con escaneo y cifrado por defecto.

✋ **Sin mirar:** ¿qué diferencia hay con Docker Hub a la hora de subir la primera imagen?

<details>
<summary>Comprueba</summary>

En ECR el repositorio se crea antes de subir; en Docker Hub se crea solo con el primer `push`.
</details>

**En resumen:** un registro por cuenta y región; un repositorio por imagen, creado antes de subir.

### Pieza 2 — Autenticarse y subir

Docker no habla IAM. ECR le da una **contraseña temporal**: `aws ecr get-login-password` devuelve un token válido **12 horas**, y se lo pasas a `docker login` con el usuario literal `AWS`. Docker lo guarda en `~/.docker/config.json`, en base64, sin cifrar: por eso te avisa.

En una EC2 nadie teclea `docker login`. Se instala el ***credential helper*** de ECR (`amazon-ecr-credential-helper`) y se configura en `~/.docker/config.json`. Cada vez que Docker necesita credenciales para ECR, se las pide al helper, y el helper usa **el rol de la instancia** para pedir un token nuevo: no hay contraseñas guardadas ni nada caduca a las 12 horas. El rol solo necesita la política administrada `AmazonEC2ContainerRegistryPullOnly`.

🔮 **Predice:** ¿coincidirá el tamaño que da ECR con el de `docker images`?

**Pruébalo:**

```bash
cat > Dockerfile <<'EOF'
FROM nginx:1.29-alpine
COPY index.html /usr/share/nginx/html/index.html
EOF
echo '<h1>lab-web 1.0.0</h1>' > index.html
docker build -t "$REGISTRO/lab-web:1.0.0" .
docker images "$REGISTRO/lab-web"
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRO"
docker push "$REGISTRO/lab-web:1.0.0"
aws ecr describe-images --repository-name lab-web \
  --query 'imageDetails[].[imageTags[0],imageSizeInBytes,imagePushedAt]' --output table
```

El nombre de la imagen **es** su destino: registro, repositorio y etiqueta (clase 64). La contraseña va por una tubería a `--password-stdin`: nunca aparece en la línea de órdenes ni en el historial de Bash.

👀 **Qué deberías ver:** la imagen construida (unos 50 MB en `docker images`); `Login Succeeded`, con el aviso de que la credencial queda sin cifrar; cada capa subida en el `push`, que termina con `1.0.0: digest: sha256:…`; y en la tabla, un `imageSizeInBytes` bastante menor que el de `docker images`: ECR muestra el tamaño **comprimido** de las capas, que es lo que se descarga y lo que se cobra.

✋ **Sin mirar:** ¿cuánto dura el token de `aws ecr get-login-password`, y cómo evita una EC2 tener que renovarlo?

<details>
<summary>Comprueba</summary>

12 horas. La EC2 usa el *credential helper* de ECR, que pide un token nuevo con el rol de la instancia cada vez que Docker lo necesita.
</details>

**En resumen:** `get-login-password | docker login --username AWS --password-stdin`, y el nombre de la imagen dice adónde va.

### Pieza 3 — El escaneo de vulnerabilidades

- **Escaneo básico:** gratis. Con `scanOnPush`, ECR revisa cada imagen al subirla y la compara con bases de datos de vulnerabilidades (CVE).
- **Escaneo mejorado:** de pago, con **Amazon Inspector**. Revisa continuamente y también las dependencias de tu lenguaje. Para el examen: *Inspector* busca vulnerabilidades en EC2, imágenes de ECR y Lambda.

**Pruébalo:**

```bash
aws ecr wait image-scan-complete --repository-name lab-web --image-id imageTag=1.0.0
aws ecr describe-image-scan-findings --repository-name lab-web --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findingSeverityCounts'
aws ecr describe-image-scan-findings --repository-name lab-web --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findings[].[severity,name]' --output text | sort | head -20
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --severity HIGH,CRITICAL "$REGISTRO/lab-web:1.0.0"
```

👀 **Qué deberías ver:** un recuento por severidad (por ejemplo, `{"MEDIUM": 2, "LOW": 1}`) o `null` si no encontró nada; la lista de CVE; y el informe de `trivy`. Rara vez coinciden del todo: usan bases de datos distintas. Lo importante es tener un escaneo **automático** en cada subida y mirar los críticos. Si sale 0, perfecto: las imágenes `alpine` recientes suelen salir limpias.

✋ **Sin mirar:** ¿qué servicio de AWS hace el escaneo mejorado y continuo?

<details>
<summary>Comprueba</summary>

Amazon Inspector, que revisa EC2, imágenes de ECR y Lambda.
</details>

**En resumen:** `scanOnPush` revisa cada imagen gratis al subirla; lo importante es que sea automático y mirar los críticos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Etiquetas inmutables

Con `IMMUTABLE`, una etiqueta subida **no se puede sobrescribir**. `vigia:3.0.0` será siempre la misma imagen, byte a byte:
- **reproducible:** lo que probaste es lo que se despliega;
- **seguro:** nadie puede cambiar en silencio la imagen que corre en producción.

A cambio, cada cambio necesita una etiqueta nueva, y `latest` deja de tener sentido (solo se podría subir una vez). Es la disciplina de versiones de la clase 64, ahora obligatoria.

🔮 **Predice:** ¿qué dirá ECR si subes otra imagen con la etiqueta `1.0.0`?

**Pruébalo:**

```bash
echo '<h1>lab-web 1.0.0, versión pirata</h1>' > index.html
docker build -t "$REGISTRO/lab-web:1.0.0" .
docker push "$REGISTRO/lab-web:1.0.0"
docker tag "$REGISTRO/lab-web:1.0.0" "$REGISTRO/lab-web:1.0.1"
docker push "$REGISTRO/lab-web:1.0.1"
aws ecr describe-images --repository-name lab-web --query 'imageDetails[].imageTags' --output text
```

👀 **Qué deberías ver:** el primer `push` falla: la etiqueta `1.0.0` ya existe y no se puede sobrescribir porque el repositorio es inmutable (`tag invalid … cannot be overwritten because the repository is immutable`). Subida como lo que es, una versión nueva, `1.0.1` entra sin problema, y el repositorio tiene `1.0.0` y `1.0.1`.

✋ **Sin mirar:** en un repositorio inmutable, ¿por qué no tiene sentido la etiqueta `latest`?

<details>
<summary>Comprueba</summary>

Porque solo se podría subir una vez: después ya no se puede mover a la imagen siguiente.
</details>

**En resumen:** inmutable = una etiqueta, una imagen para siempre; cada cambio, una versión nueva.

### Pieza 5 — El ciclo de vida

Una **política de ciclo de vida** son reglas que borran imágenes. Por ejemplo, "las sin etiqueta, al día" y "conserva las 5 más recientes". Sin ella, un pipeline que sube una imagen por commit llena el repositorio (y la factura). Las reglas se evalúan por `rulePriority`, y la de `tagStatus: any` tiene que ser la última.

**Pruébalo.** Crea `ciclo-ecr.json`:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Borra al día las imágenes sin etiqueta",
      "selection": {"tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 1},
      "action": {"type": "expire"}
    },
    {
      "rulePriority": 2,
      "description": "Conserva solo las 5 imágenes más recientes",
      "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 5},
      "action": {"type": "expire"}
    }
  ]
}
```

```bash
aws ecr put-lifecycle-policy --repository-name lab-web --lifecycle-policy-text file://ciclo-ecr.json
aws ecr start-lifecycle-policy-preview --repository-name lab-web
sleep 10
aws ecr get-lifecycle-policy-preview --repository-name lab-web --query '[status,previewResults]'
```

👀 **Qué deberías ver:** `["COMPLETE", []]`: la vista previa dice qué borraría la política **sin borrar nada**, y con dos imágenes no borraría ninguna.

✋ **Sin mirar:** ¿qué pasa en un repositorio sin política de ciclo de vida al que un pipeline sube una imagen por commit?

<details>
<summary>Comprueba</summary>

Que se acumulan imágenes sin fin, y con ellas el coste de almacenamiento.
</details>

**En resumen:** reglas por prioridad que expiran imágenes; la vista previa enseña qué borrarían.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws ecr create-repository --repository-name … --image-tag-mutability IMMUTABLE --image-scanning-configuration scanOnPush=true` | crear un repositorio |
| `aws ecr get-login-password \| docker login --username AWS --password-stdin "$REGISTRO"` | entrar con Docker (12 h) |
| `docker build -t "$REGISTRO/repo:1.0.0" .` · `docker push "$REGISTRO/repo:1.0.0"` | construir y subir |
| `aws ecr describe-images --repository-name …` | las imágenes de un repositorio |
| `aws ecr wait image-scan-complete` · `describe-image-scan-findings` | el escaneo |
| `aws ecr put-lifecycle-policy --lifecycle-policy-text file://…` · `start-lifecycle-policy-preview` | ciclo de vida y su vista previa |
| `aws ecr delete-repository --repository-name … --force` | borrar con imágenes dentro |
| `amazon-ecr-credential-helper` + `"credHelpers"` | Docker sin contraseñas guardadas |
| `AmazonEC2ContainerRegistryPullOnly` | la política para que una EC2 descargue |

## Rómpelo

**1. Sin sesión:**

```bash
docker logout "$REGISTRO"
docker push "$REGISTRO/lab-web:1.0.1"
```

`no basic auth credentials`. Lo mismo pasa a las 12 horas de tu `docker login`: el token caduca. Vuelve a entrar con la orden de la pieza 2.

**2. Un repositorio que no existe:**

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRO"
docker tag "$REGISTRO/lab-web:1.0.1" "$REGISTRO/lab-otro:1.0.0"
docker push "$REGISTRO/lab-otro:1.0.0"
```

El push falla y te dice que el repositorio no existe en tu registro. En ECR, primero se crea el repositorio y luego se sube.

**3. Borrar un repositorio con imágenes:**

```bash
aws ecr delete-repository --repository-name lab-web
```

`RepositoryNotEmptyException`. ECR te obliga a decirlo claro: `--force` (en "Destruir al terminar").

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Docker sin contraseñas guardadas.** Haz que tu Docker use el *credential helper* de ECR para tu registro, en lugar de `docker login`.

> 🧩 **Ejemplo resuelto:** el reto 1 de la clase 64: `"credsStore": "secretservice"` hacía que Docker pidiera las credenciales de Docker Hub al llavero de GNOME.

**Ahora tú, con huecos:**
1. `sudo apt install amazon-ecr-credential-____`
2. En `~/.docker/config.json`, añade `"credHelpers": {"____": "ecr-login"}` (cuidado con las comas del JSON).
3. El helper es un programa antiguo y no entiende las sesiones de `aws login`. Usa el truco que documenta AWS para estos casos: un perfil que pide las credenciales a la CLI. En `~/.aws/config`:

   ```
   [profile ecr]
   credential_process = aws configure export-credentials --profile default --format process
   region = us-east-1
   ```
4. `docker logout "$REGISTRO"` y `AWS_PROFILE=____ docker pull "$REGISTRO/lab-web:1.0.1"`.

Completa: «Funciona sin `docker login`, y en `~/.docker/config.json` queda ____».

<details>
<summary>Pista</summary>

El paquete es `amazon-ecr-credential-helper`, la clave de `credHelpers` es tu registro (`echo "$REGISTRO"`) y el perfil se llama `ecr`. Si falla en tu equipo, tráemelo: es la parte de la clase que no pude probar en una cuenta real.
</details>

**2.** ¿Qué hay por debajo de `nginx:1.29-alpine`? ¿Por qué un `FROM` con *digest* es aún más reproducible que con etiqueta?

> 🧩 **Ejemplo resuelto:** la pieza 1 de la clase 64: `docker image inspect nginx:1.29 --format '{{json .RepoDigests}}'` daba `nginx@sha256:…`.

**Ahora tú, con huecos:**
```bash
docker inspect --format '{{index .RepoDigests ____}}' nginx:1.29-alpine
```
Completa: «Es `nginx@sha256:____…`. Un `FROM nginx@sha256:…` es más reproducible porque… El precio es que…».

<details>
<summary>Pista</summary>

`index` saca un elemento de la lista por su posición, empezando por 0. Piensa en qué pasa con la etiqueta `1.29-alpine` cuando sale un parche de nginx.
</details>

**3.** Escribe en tus notas la política de IAM mínima para que la EC2 de Vigía **descargue** su imagen del repositorio `vigia`, y compárala con la administrada `AmazonEC2ContainerRegistryPullOnly`.

> 🧩 **Ejemplo resuelto:** `subir-informes.json` del reto 3 de la clase 74: una acción, sobre un recurso concreto.

**Ahora tú, con huecos:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "____"},
    {"Effect": "Allow",
     "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"],
     "Resource": "arn:aws:ecr:us-east-1:____:repository/____"}
  ]
}
```

<details>
<summary>Pista</summary>

El token de acceso es del registro entero, no de un repositorio: `GetAuthorizationToken` solo admite `"Resource": "*"`. Lee la administrada con `aws iam get-policy-version` (clase 69) y fíjate en su `Resource`.
</details>

## Destruir al terminar

```bash
aws ecr delete-repository --repository-name lab-web --force --query repository.repositoryName --output text
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text
docker logout "$REGISTRO"
docker image rm "$REGISTRO/lab-web:1.0.0" "$REGISTRO/lab-web:1.0.1"
```

El segundo comando no debe listar `lab-web`. El `logout` borra el token de `~/.docker/config.json`. Si hiciste el reto 1, puedes dejar el helper configurado: no guarda nada.

## Cierre

En `notas/fase-6/clase-75.md`:

1. ¿Qué ventajas tiene ECR sobre Docker Hub para las imágenes de una empresa que despliega en AWS? *(2–3 líneas. Empieza así: «Es privado por defecto y los permisos son de IAM; está en la misma región, así que…»)*
2. ¿Qué ganas con las etiquetas inmutables, y qué te obligan a hacer? *(2 líneas. Empieza así: «Una etiqueta identifica siempre la misma imagen:… A cambio, cada cambio necesita…»)*
3. ¿Cómo descargará la EC2 de Vigía su imagen sin que nadie haga `docker login`? *(2 líneas. Empieza así: «Con el credential helper de ECR y un rol con… Cuando Docker necesita descargar, el helper…»)*
4. **Repaso (clase 74, sin mirar):** ¿por qué un bucket con versionado da `BucketNotEmpty` aunque `aws s3 ls` no muestre nada? *(1–2 líneas. Empieza así: «Porque `aws s3 rm` solo añadió marcas de borrado:…»)*

Después, escríbeme `examíname clase-75`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Las ventajas:
- es **privado** por defecto y los permisos son de **IAM**: los mismos usuarios, roles y políticas que el resto de la cuenta;
- está en la **misma región** que tus servidores: descarga rápida y sin coste de transferencia;
- trae **escaneo** de vulnerabilidades y ciclo de vida;
- no tiene los límites de descarga de Docker Hub;
- las EC2, ECS, EKS y Lambda lo usan sin contraseñas, con sus roles.

**2.** Una etiqueta identifica siempre la misma imagen: lo que pruebas es lo que despliegas, y nadie puede cambiar en silencio lo que corre en producción. A cambio, cada cambio necesita una versión nueva (`3.0.1`, `3.0.2`…), y no puedes reutilizar `latest`.

**3.** Con el *credential helper* de ECR configurado en `/root/.docker/config.json` (`"credsStore": "ecr-login"`) y un rol con `AmazonEC2ContainerRegistryPullOnly` en su perfil de instancia. Cuando Docker necesita descargar de ECR, el helper pide un token con las credenciales temporales del rol, que obtiene del IMDS (clase 72). Sin contraseñas guardadas y sin caducidades que vigilar.

**4.** Porque `aws s3 rm` solo añadió marcas de borrado encima de cada objeto: las versiones siguen guardadas, y S3 no borra un bucket que tiene versiones. Hay que borrar cada versión y cada marca (`list-object-versions` + `delete-objects`).

**Reto 1:** `amazon-ecr-credential-helper`, tu registro como clave y `AWS_PROFILE=ecr`. En `config.json` queda solo el `"credHelpers"`, sin ninguna entrada `auth` para tu registro.

**Reto 2:** `{{index .RepoDigests 0}}`. Una etiqueta como `1.29-alpine` se **mueve**: cada actualización de nginx la apunta a una imagen nueva. Un *digest* (`sha256:…`) es la huella del contenido y no cambia nunca: con él, la imagen base es siempre la misma, byte a byte. El precio es que tienes que actualizarlo tú para recibir los parches de seguridad.

**Reto 3:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*"},
    {"Effect": "Allow",
     "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"],
     "Resource": "arn:aws:ecr:us-east-1:123456789012:repository/vigia"}
  ]
}
```
`AmazonEC2ContainerRegistryPullOnly` da esas mismas acciones sobre **todos** los repositorios (`"Resource": "*"`); la tuya, solo sobre `vigia`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| container registry / repository | registro de contenedores / repositorio |
| immutable tags | etiquetas inmutables |
| scan on push / vulnerability findings | escaneo al subir / hallazgos de vulnerabilidades |
| lifecycle policy | política de ciclo de vida |
| credential helper | asistente de credenciales |
| image digest | resumen (huella) de la imagen |

🎙️ *"Our images live in ECR with immutable tags and scan on push, and a lifecycle policy expires old ones. Servers never run docker login: the ECR credential helper uses the instance role to fetch short-lived tokens."*

## Siguiente

[Clase 76 — CloudWatch: métricas, logs y alarmas](clase-76-cloudwatch.md)
