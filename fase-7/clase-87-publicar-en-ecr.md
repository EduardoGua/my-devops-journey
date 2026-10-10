# Clase 87 — Construir y publicar la imagen en ECR

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Entrega y despliegue continuos

## Objetivo

- Añadir al pipeline un job que, al llegar un cambio a `main`, **construye la imagen y la publica en ECR**, entrando con OIDC.
- Etiquetar cada imagen con el **commit** que la produjo, y meter esa versión dentro de la imagen para saber siempre qué está corriendo.
- Dar al rol del pipeline **solo** los permisos de subir a **un** repositorio.
- Hacer el job **idempotente**: si lo repites, no falla ni duplica nada.

## Por qué importa

Esto es **entrega continua**: cada cambio que pasa las pruebas queda empaquetado, versionado y listo para desplegar, sin que nadie construya nada en su portátil.

La etiqueta con el SHA del commit da **trazabilidad**: ante cualquier imagen que corra en producción, sabes exactamente qué código lleva y quién lo aprobó. Ante un fallo, es la primera pregunta: "¿qué versión está corriendo?".

## Costo esperado

> 💰 **Céntimos al mes.** ECR cobra 0,10 USD por GB y mes. La imagen comprimida de `saludo` pesa unos 60 MB, y la política de ciclo de vida guardará como mucho 10.

## Teoría

### Qué etiqueta lleva cada imagen

| Etiqueta | Para qué |
|----------|----------|
| **el SHA del commit** (`lab-actions:3f9c2…`) | cada imagen que produce el pipeline: única, inmutable y trazable |
| la versión (`saludo:1.2.0`) | las *releases* que anuncias, por ejemplo al crear una etiqueta `v1.2.0` en Git (Reto 1) |
| `latest` | nunca para desplegar (clase 64). Con etiquetas inmutables, además, no se podría mover |

Con el repositorio en **IMMUTABLE** (clase 75), cada SHA solo se puede subir una vez. Eso tiene una consecuencia: si repites el job de un commit ya publicado, el `push` falla (Rómpelo 1). Un job de publicación tiene que ser **idempotente**: si la imagen ya existe, no hace nada.

### Las piezas del job

| Paso | Qué hace |
|------|----------|
| `aws-actions/configure-aws-credentials` | OIDC → credenciales temporales del rol (clase 86) |
| `aws-actions/amazon-ecr-login` | `docker login` contra tu registro de ECR. Su salida `registry` es `<cuenta>.dkr.ecr.us-east-1.amazonaws.com`, y oculta la contraseña en el log |
| `docker/setup-buildx-action` | prepara **BuildKit**, el constructor moderno de Docker, con caché y varias arquitecturas |
| `docker/build-push-action` | construye y sube. Con `cache-from` y `cache-to` `type=gha`, guarda las capas en la caché de GitHub Actions: la siguiente construcción solo rehace lo que cambió (clase 58) |

Las **etiquetas OCI** (`org.opencontainers.image.revision`, `…source`) son metadatos estándar dentro de la imagen: el commit y la URL del repositorio. Cualquier herramienta puede leerlos con `docker inspect`.

### Permisos para subir, y nada más

Para subir a ECR, el rol necesita:
- `ecr:GetAuthorizationToken`: obtener el token de `docker login`. No se puede limitar a un repositorio y va sobre `*`;
- las acciones de subida, solo sobre **el ARN de ese repositorio**: `BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload` y `PutImage`;
- `BatchGetImage` y `DescribeImages`, para consultar lo que ya hay.

No puede borrar imágenes, ni tocar otros repositorios, ni crear repositorios nuevos.

## Práctica guiada

### 1. El repositorio de ECR (10 min)

```bash
mkdir -p ~/my-devops-journey/labs/clase-87 && cd ~/my-devops-journey/labs/clase-87
CUENTA=$(aws sts get-caller-identity --query Account --output text)
aws ecr create-repository --repository-name lab-actions --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true --tags Key=Proyecto,Value=lab \
  --query repository.repositoryUri --output text
cat > ciclo-ecr.json <<'EOF'
{"rules": [{"rulePriority": 1, "description": "Conserva las 10 más recientes",
  "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 10},
  "action": {"type": "expire"}}]}
EOF
aws ecr put-lifecycle-policy --repository-name lab-actions --lifecycle-policy-text file://ciclo-ecr.json
```

Con una imagen por commit, sin la política de ciclo de vida el repositorio crecería sin fin.

### 2. Permiso para subir (10 min)

```bash
cat > subir-a-ecr.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IniciarSesionEnECR",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "SubirAlRepositorio",
      "Effect": "Allow",
      "Action": ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
                 "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages"],
      "Resource": "arn:aws:ecr:us-east-1:$CUENTA:repository/lab-actions"
    }
  ]
}
EOF
aws iam put-role-policy --role-name lab-github --policy-name subir-a-ecr --policy-document file://subir-a-ecr.json
aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY --policy-document file://subir-a-ecr.json --query findings
```

Una política *inline* (clase 69), porque solo tiene sentido para este rol.

### 3. La versión dentro de la imagen (10 min)

En `lab-actions`, rama `publicar`. En el `Dockerfile`, justo después de `COPY app.py .`:

```dockerfile
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
```

Es el Reto 2 de la clase 58: el argumento de construcción se convierte en variable de entorno, y `/info` la muestra. Pruébalo:

```bash
docker build -q --build-arg APP_VERSION=prueba-local -t saludo:v .
docker run -d --name sv -p 8010:8000 saludo:v && sleep 2 && curl -s localhost:8010/info && docker rm -f sv
```

Una versión no es un secreto: `ARG` sirve para esto.

### 4. El job `publicar` (20 min)

Añade al final de `.github/workflows/ci.yml`, al mismo nivel que `imagen`:

```yaml
  publicar:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [lint, test, imagen]
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - id: ecr
        uses: aws-actions/amazon-ecr-login@03f1aad4c6c7ffd436567f42f9384779290529bd # v2.1.7
      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1
      - uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: .
          push: true
          tags: ${{ steps.ecr.outputs.registry }}/lab-actions:${{ github.sha }}
          build-args: APP_VERSION=${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          labels: |
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
```

- **`if:`** solo publica en los `push` a `main`. En los PR, el job aparece como **saltado** (*skipped*): nada sin revisar llega a ECR.
- **`needs:`** solo publica si `lint`, `test` e `imagen` pasaron.
- **`id-token: write`** solo lo tiene este job; el resto del workflow sigue con `contents: read`.

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git add -A && git commit -m "Publicar la imagen en ECR al unir a main" && git push -u origin publicar
gh pr create --fill && gh pr checks --watch
gh pr merge --squash --delete-branch
sleep 10 && gh run watch
```

🔮 **Predice:**
- **En el PR:** `publicar` sale como *skipped*.
- **En `main`:** corre después de los otros tres y sube `lab-actions:<SHA del commit de main>`.

### 5. Comprobar lo publicado (10 min)

```bash
git switch main && git pull
SHA=$(git rev-parse HEAD)
aws ecr describe-images --repository-name lab-actions \
  --query 'imageDetails[].[imageTags[0],imagePushedAt,imageSizeInBytes]' --output table
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRO"
docker run -d --name publicada -p 8011:8000 "$REGISTRO/lab-actions:$SHA" && sleep 2
curl -s localhost:8011/info; echo
docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$REGISTRO/lab-actions:$SHA"
docker rm -f publicada && docker logout "$REGISTRO"
```

🔮 **Predice:** ¿qué `version` devuelve `/info`? El SHA del commit, el mismo que la etiqueta y que la etiqueta OCI. De una imagen corriendo, al código exacto, en un paso.

## Rómpelo

**1. Repetir el job: la etiqueta ya existe.**

```bash
gh run list --workflow ci.yml --branch main --limit 1
gh run rerun <id>
```

`publicar` falla: la etiqueta `<SHA>` ya existe y el repositorio es inmutable. Hazlo **idempotente**. Antes de `setup-buildx-action`, añade este step:

```yaml
      - name: ¿Ya está esta versión en ECR?
        id: existe
        run: |
          if aws ecr describe-images --repository-name lab-actions --image-ids "imageTag=$GITHUB_SHA" >/dev/null 2>&1; then
            echo "si=true" >> "$GITHUB_OUTPUT"
            echo "::notice::lab-actions:$GITHUB_SHA ya existe: no se vuelve a subir"
          fi
```

Pon `if: steps.existe.outputs.si != 'true'` en los dos steps de Docker. Une el cambio con un PR, que creará otro commit y otra imagen, y repite el `rerun` de ese commit: ahora termina en verde con un aviso.

**2. Un permiso de menos.** Quita `ecr:PutImage` de `subir-a-ecr.json`, aplícala (`put-role-policy`) y une cualquier cambio pequeño:
- las capas se suben;
- el último paso falla con `not authorized to perform: ecr:PutImage`.

Devuélvelo. Leer qué acción exacta falta y añadir **solo esa** es cómo se llega al mínimo privilegio.

**3. Un PR que intenta publicar.** En un PR, cambia el `if:` del job por `if: true` y mira el resultado. `configure-aws-credentials` no consigue el rol: el token del PR tiene `ref` = `refs/pull/<n>/merge`, y tu política de confianza exige `refs/heads/main`. Aunque te equivoques en el workflow, AWS te protege. Cierra el PR sin unir.

## Reto

1. **Una release con su versión.** Añade un workflow que se dispare con `push: tags: ["v*"]` y suba también la etiqueta `lab-actions:1.2.0` cuando crees en Git la etiqueta `v1.2.0`.
   - Pista: `${GITHUB_REF_NAME#v}`.
   - ¿Qué tendrías que cambiar en la política de confianza del rol? El `ref` de ese token es `refs/tags/v1.2.0`.
2. Mira el log de `build-push-action` en dos ejecuciones seguidas: ¿cuántas capas salen como `CACHED` la segunda vez?
3. ¿Qué devuelve `aws ecr describe-image-scan-findings` para la última imagen? ¿Fallarías el pipeline si hubiera hallazgos `CRITICAL`? ¿Cómo lo harías?

## Destruir al terminar

Nada que cobre por hora. Deja el repositorio `lab-actions` de ECR y la política del rol para las clases 88 y 89. Si te quedó algún contenedor local: `docker rm -f publicada sv`.

## Cierre

En `notas/fase-7/clase-87.md`:

1. ¿Por qué la imagen se etiqueta con el SHA del commit y no con `latest`?
2. ¿Qué significa que el job de publicación es idempotente, y por qué un repositorio inmutable te obliga a hacerlo así?
3. Lista los permisos del rol para subir a ECR y por qué `GetAuthorizationToken` va sobre `*`.
4. **Repaso (clase 86, sin mirar):** ¿qué cuatro condiciones tiene tu política de confianza y qué deja fuera cada una?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque el SHA identifica una versión **única** del código: cada imagen es distinta, nunca se sobrescribe (el repositorio es inmutable) y lleva directo al commit, su PR y sus pruebas. `latest` es una etiqueta que se mueve y no dice qué contiene: con ella no sabrías qué está corriendo ni podrías volver a una versión concreta.

**2.** Que repetirlo produce el mismo resultado sin fallar ni duplicar: si la imagen de ese commit ya existe, la deja como está. Con etiquetas inmutables, un segundo `push` de la misma etiqueta falla, así que el job comprueba antes si la imagen existe. En un pipeline, los *reruns* son normales (un fallo de red, un job cancelado).

**3.**
- **`ecr:GetAuthorizationToken`:** el token de `docker login`. Es una acción de cuenta, no de repositorio, así que no admite otro recurso que `*`.
- **`BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload` y `PutImage`:** subir capas y el manifiesto.
- **`BatchGetImage` y `DescribeImages`:** consultar lo que ya existe.

Todas, menos la primera, solo sobre el ARN de `lab-actions`.

**4.**
- **`aud` = `sts.amazonaws.com`:** deja fuera tokens emitidos para otros servicios.
- **`repository_owner_id`:** deja fuera repositorios de otros dueños.
- **`repository_id`:** deja fuera tus otros repositorios y cualquier *fork*.
- **`ref` = `refs/heads/main`:** deja fuera las demás ramas, los PR y las etiquetas.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| build and push | construir y subir |
| image provenance / traceability | procedencia / trazabilidad de la imagen |
| idempotent job | job idempotente (repetirlo da el mismo resultado) |
| build cache | caché de construcción |
| artifact | artefacto (lo que produce el pipeline) |

🎙️ *"When a change lands on main, the pipeline builds the image once, tags it with the commit SHA, bakes the version into it and pushes it to an immutable ECR repository using OIDC. The publish job is idempotent, and its role can only push to that one repository."*

## Siguiente

[Clase 88 — Desplegar en EC2 con Session Manager](clase-88-desplegar-con-ssm.md)
