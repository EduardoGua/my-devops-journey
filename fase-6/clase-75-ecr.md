# Clase 75 — ECR: tu registro de imágenes

**Dónde:** tu Ubuntu (Docker + AWS CLI) · **Tiempo:** 75 min · **Bloque:** B. Los servicios básicos

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

## Teoría

### Registro, repositorio, imagen

```
123456789012.dkr.ecr.us-east-1.amazonaws.com / lab-web : 1.0.0
└────────────── registro ──────────────────┘  └repo─┘  └etiqueta┘
```

- Cada cuenta tiene **un registro por región**.
- Dentro hay **repositorios**, uno por imagen (`vigia`, `lab-web`…), y en cada repositorio, las versiones con sus **etiquetas**.
- A diferencia de Docker Hub, el repositorio **se crea antes** de subir: un `docker push` a un repositorio que no existe falla (Rómpelo 2).

### Autenticación

Docker no habla IAM. ECR le da una **contraseña temporal**: `aws ecr get-login-password` devuelve un token válido **12 horas**, y se lo pasas a `docker login` con el usuario literal `AWS`. Docker lo guarda en `~/.docker/config.json`, en base64, sin cifrar: por eso te avisa.

En una EC2 nadie teclea `docker login`. Se instala el ***credential helper*** de ECR (`amazon-ecr-credential-helper`) y se configura en `~/.docker/config.json`. Cada vez que Docker necesita credenciales para ECR, se las pide al helper, y el helper usa **el rol de la instancia** para pedir un token nuevo:
- no hay contraseñas guardadas;
- no caduca nada a las 12 horas.

El rol solo necesita la política administrada `AmazonEC2ContainerRegistryPullOnly`.

### Etiquetas inmutables

Con `IMMUTABLE`, una etiqueta subida **no se puede sobrescribir**. `vigia:3.0.0` será siempre la misma imagen, byte a byte:
- **reproducible:** lo que probaste es lo que se despliega;
- **seguro:** nadie puede cambiar en silencio la imagen que corre en producción.

A cambio, cada cambio necesita una etiqueta nueva, y `latest` deja de tener sentido (solo se podría subir una vez). Es la disciplina de versiones de la clase 64, ahora obligatoria.

### Escaneo y ciclo de vida

- **Escaneo básico:** gratis. Con `scanOnPush`, ECR revisa cada imagen al subirla y la compara con bases de datos de vulnerabilidades (CVE).
- **Escaneo mejorado:** de pago, con **Amazon Inspector**. Revisa continuamente y también las dependencias de tu lenguaje. Para el examen: *Inspector* busca vulnerabilidades en EC2, imágenes de ECR y Lambda.
- **Política de ciclo de vida:** reglas que borran imágenes. Por ejemplo, "las sin etiqueta, al día" y "conserva las 5 más recientes". Sin ella, un pipeline que sube una imagen por commit llena el repositorio (y la factura).

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-75 && cd ~/my-devops-journey/labs/clase-75
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
echo "$REGISTRO"
```

### 1. El repositorio (5 min)

```bash
aws ecr create-repository --repository-name lab-web \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --tags Key=Proyecto,Value=lab \
  --query 'repository.repositoryUri' --output text
aws ecr describe-repositories --repository-names lab-web \
  --query 'repositories[0].[imageTagMutability,imageScanningConfiguration.scanOnPush,encryptionConfiguration.encryptionType]' --output text
```

Inmutable, con escaneo y cifrado (`AES256`) por defecto.

### 2. Una imagen pequeña (10 min)

```bash
cat > Dockerfile <<'EOF'
FROM nginx:1.29-alpine
COPY index.html /usr/share/nginx/html/index.html
EOF
echo '<h1>lab-web 1.0.0</h1>' > index.html
docker build -t "$REGISTRO/lab-web:1.0.0" .
docker images "$REGISTRO/lab-web"
```

El nombre de la imagen **es** su destino: registro, repositorio y etiqueta (clase 64).

### 3. Iniciar sesión y subir (10 min)

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRO"
docker push "$REGISTRO/lab-web:1.0.0"
aws ecr describe-images --repository-name lab-web \
  --query 'imageDetails[].[imageTags[0],imageSizeInBytes,imagePushedAt]' --output table
```

La contraseña va por una tubería a `--password-stdin`: nunca aparece en la línea de órdenes ni en el historial de Bash.

🔮 **Predice:** ¿coincidirá `imageSizeInBytes` con el tamaño que da `docker images`? No: ECR muestra el tamaño **comprimido** de las capas, bastante menor. Es lo que se descarga y lo que se cobra.

### 4. El escaneo (15 min)

```bash
aws ecr wait image-scan-complete --repository-name lab-web --image-id imageTag=1.0.0
aws ecr describe-image-scan-findings --repository-name lab-web --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findingSeverityCounts'
aws ecr describe-image-scan-findings --repository-name lab-web --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findings[].[severity,name]' --output text | sort | head -20
```

Compáralo con `trivy` (clase 59):

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --severity HIGH,CRITICAL "$REGISTRO/lab-web:1.0.0"
```

¿Encuentran lo mismo? Rara vez coinciden del todo: usan bases de datos distintas. Lo importante es tener un escaneo **automático** en cada subida y mirar los críticos. Si sale 0, perfecto: las imágenes `alpine` recientes suelen salir limpias.

### 5. Inmutable de verdad (10 min)

Cambia la página y sube **con la misma etiqueta**:

```bash
echo '<h1>lab-web 1.0.0, versión pirata</h1>' > index.html
docker build -t "$REGISTRO/lab-web:1.0.0" .
docker push "$REGISTRO/lab-web:1.0.0"
```

🔮 **Predice:** ¿qué dirá ECR? Que la etiqueta `1.0.0` ya existe y no se puede sobrescribir porque el repositorio es inmutable. Súbela como lo que es, una versión nueva:

```bash
docker tag "$REGISTRO/lab-web:1.0.0" "$REGISTRO/lab-web:1.0.1"
docker push "$REGISTRO/lab-web:1.0.1"
aws ecr describe-images --repository-name lab-web --query 'imageDetails[].imageTags' --output text
```

### 6. Ciclo de vida (10 min)

Crea `ciclo-ecr.json`:

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

La vista previa dice qué borraría la política **sin borrar nada**. Con dos imágenes, nada. Las reglas se evalúan por `rulePriority`, y la de `tagStatus: any` tiene que ser la última.

## Rómpelo

**1. Sin sesión:**

```bash
docker logout "$REGISTRO"
docker push "$REGISTRO/lab-web:1.0.1"
```

`no basic auth credentials`. Lo mismo pasa a las 12 horas de tu `docker login`: el token caduca. Vuelve a entrar con la orden del paso 3.

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

1. **Docker sin contraseñas guardadas.** Instala el helper (`sudo apt install amazon-ecr-credential-helper`) y haz que tu Docker lo use para tu registro, en lugar de `docker login`.
   - En `~/.docker/config.json`, añade `"credHelpers": {"<tu registro>": "ecr-login"}`.
   - El helper es un programa antiguo y no entiende las sesiones de `aws login`. Usa el truco que documenta AWS para estos casos: un perfil que pide las credenciales a la CLI. En `~/.aws/config`:

     ```
     [profile ecr]
     credential_process = aws configure export-credentials --profile default --format process
     region = us-east-1
     ```
   - Después: `docker logout "$REGISTRO"` y `AWS_PROFILE=ecr docker pull "$REGISTRO/lab-web:1.0.1"`.

   ¿Funciona sin `docker login`? ¿Qué queda ahora en `~/.docker/config.json`? Si falla en tu equipo, tráemelo: es la parte de la clase que no pude probar en una cuenta real.
2. ¿Qué etiqueta tiene `nginx:1.29-alpine` por debajo? Busca su *digest* (`docker inspect --format '{{index .RepoDigests 0}}' nginx:1.29-alpine`). ¿Por qué un `FROM` con *digest* (`nginx@sha256:…`) es aún más reproducible que con etiqueta?
3. Escribe en tus notas la política de IAM mínima para que la EC2 de Vigía **descargue** su imagen. Compárala con la administrada `AmazonEC2ContainerRegistryPullOnly`.

## Destruir al terminar

```bash
aws ecr delete-repository --repository-name lab-web --force --query repository.repositoryName --output text
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text
docker logout "$REGISTRO"
docker image rm "$REGISTRO/lab-web:1.0.0" "$REGISTRO/lab-web:1.0.1"
```

El segundo comando no debe listar `lab-web`. El `logout` borra el token de `~/.docker/config.json`. Si hiciste el Reto 1, puedes dejar el helper configurado: no guarda nada.

## Cierre

En `notas/fase-6/clase-75.md`:

1. ¿Qué ventajas tiene ECR sobre Docker Hub para las imágenes de una empresa que despliega en AWS?
2. ¿Qué ganas con las etiquetas inmutables, y qué te obligan a hacer?
3. ¿Cómo descargará la EC2 de Vigía su imagen sin que nadie haga `docker login`?
4. **Repaso (clase 74, sin mirar):** ¿por qué un bucket con versionado da `BucketNotEmpty` aunque `aws s3 ls` no muestre nada?

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

**Reto 2:** una etiqueta como `1.29-alpine` se **mueve**: cada actualización de nginx la apunta a una imagen nueva. Un *digest* (`sha256:…`) es la huella del contenido y no cambia nunca: con él, la imagen base es siempre la misma, byte a byte. El precio es que tienes que actualizarlo tú para recibir los parches de seguridad.
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
