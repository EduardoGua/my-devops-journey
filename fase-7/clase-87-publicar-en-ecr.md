# Clase 87 — Construir y publicar la imagen en ECR

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Entrega y despliegue continuos

> 💡 **La idea de hoy:** esto es **entrega continua**: cada cambio que llega a `main` y pasa las pruebas queda **construido, etiquetado con su commit y publicado** en ECR, sin que nadie construya nada en su portátil. El pipeline entra en AWS con OIDC, su rol solo puede subir a **un** repositorio, y la versión va dentro de la imagen: de una imagen que corre, al código exacto, en un paso.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - ECR con etiquetas inmutables, escaneo y ciclo de vida (clase 75).
> - `ARG` y `ENV` para meter la versión en la imagen (clase 58, reto 2); la caché de capas (clase 58).
> - El rol `lab-github`, su variable `AWS_ROLE_ARN` y OIDC (clase 86).
> - `needs:`, `if:` y `outputs` (clase 82); el mínimo privilegio, las *inline* y Access Analyzer (clase 69).
> - Los scripts que se pueden repetir sin romper nada, como `crear-vpc.sh` (clase 71).

> 🔤 **Palabras nuevas de hoy:**
> - **trazabilidad**: poder ir de una imagen que corre al commit, al PR y a las pruebas que la produjeron.
> - **job idempotente**: el que, repetido, da el mismo resultado sin fallar ni duplicar nada.
> - **BuildKit**: el constructor moderno de Docker, con caché y varias arquitecturas.
> - **caché `type=gha`**: las capas de la imagen, guardadas en la caché de GitHub Actions.
> - **etiquetas OCI**: metadatos estándar dentro de la imagen, como el commit y la URL del repositorio.
> - **artefacto**: lo que produce el pipeline; aquí, la imagen.

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

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Las tres primeras preparan AWS y la imagen; las dos últimas, el job y su comprobación.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-87 && cd ~/my-devops-journey/labs/clase-87
CUENTA=$(aws sts get-caller-identity --query Account --output text)
```

## Las piezas

### Pieza 1 — Qué etiqueta lleva cada imagen, y su repositorio

| Etiqueta | Para qué |
|----------|----------|
| **el SHA del commit** (`lab-actions:3f9c2…`) | cada imagen que produce el pipeline: única, inmutable y trazable |
| la versión (`saludo:1.2.0`) | las *releases* que anuncias, por ejemplo al crear una etiqueta `v1.2.0` en Git (reto 1) |
| `latest` | nunca para desplegar (clase 64). Con etiquetas inmutables, además, no se podría mover |

Con el repositorio en **IMMUTABLE** (clase 75), cada SHA solo se puede subir una vez. Eso tiene una consecuencia: si repites el job de un commit ya publicado, el `push` falla (Rómpelo 1). Un job de publicación tiene que ser **idempotente**: si la imagen ya existe, no hace nada.

**Pruébalo:**

```bash
aws ecr create-repository --repository-name lab-actions --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true --tags Key=Proyecto,Value=lab \
  --query repository.repositoryUri --output text
cat > ciclo-ecr.json <<'EOF'
{"rules": [{"rulePriority": 1, "description": "Conserva las 10 más recientes",
  "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 10},
  "action": {"type": "expire"}}]}
EOF
aws ecr put-lifecycle-policy --repository-name lab-actions --lifecycle-policy-text file://ciclo-ecr.json \
  --query repositoryName --output text
```

👀 **Qué deberías ver:** la URI `<cuenta>.dkr.ecr.us-east-1.amazonaws.com/lab-actions` y `lab-actions`. Con una imagen por commit, sin la política de ciclo de vida el repositorio crecería sin fin.

✋ **Sin mirar:** ¿por qué la etiqueta de cada imagen del pipeline es el SHA del commit?

<details>
<summary>Comprueba</summary>

Porque identifica una versión única del código y lleva directo al commit, su PR y sus pruebas: trazabilidad.
</details>

**En resumen:** una imagen por commit, etiquetada con su SHA, en un repositorio inmutable con ciclo de vida.

### Pieza 2 — Permisos para subir, y nada más

Para subir a ECR, el rol necesita:
- `ecr:GetAuthorizationToken`: obtener el token de `docker login`. No se puede limitar a un repositorio y va sobre `*`;
- las acciones de subida, solo sobre **el ARN de ese repositorio**: `BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload` y `PutImage`;
- `BatchGetImage` y `DescribeImages`, para consultar lo que ya hay.

No puede borrar imágenes, ni tocar otros repositorios, ni crear repositorios nuevos. Va como política *inline* (clase 69), porque solo tiene sentido para este rol.

**Pruébalo:**

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
aws iam list-role-policies --role-name lab-github --query PolicyNames --output text
```

👀 **Qué deberías ver:** `[]` de Access Analyzer y `subir-a-ecr` como única política *inline* del rol.

✋ **Sin mirar:** ¿por qué `ecr:GetAuthorizationToken` va sobre `"Resource": "*"`?

<details>
<summary>Comprueba</summary>

Porque el token de `docker login` es del registro entero, no de un repositorio: esa acción no admite otro recurso.
</details>

**En resumen:** el token sobre `*`; subir y consultar, solo sobre el ARN de `lab-actions`.

### Pieza 3 — La versión dentro de la imagen

Es el reto 2 de la clase 58: el argumento de construcción `APP_VERSION` se convierte en variable de entorno, y `/info` la muestra. Una versión no es un secreto: `ARG` sirve para esto. En el pipeline, el valor será el SHA del commit.

**Pruébalo.** En `lab-actions`, rama `publicar`. En el `Dockerfile`, justo después de `COPY app.py .`:

```dockerfile
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
```

```bash
cd ~/lab-actions && git switch main && git pull && git switch -c publicar
docker build -q --build-arg APP_VERSION=prueba-local -t saludo:v .
docker run -d --name sv -p 8010:8000 saludo:v && sleep 2 && curl -s localhost:8010/info; echo
docker rm -f sv
```

👀 **Qué deberías ver:** `{"equipo":"…","entorno":"desarrollo","version":"prueba-local"}`.

✋ **Sin mirar:** ¿por qué aquí sí vale `ARG`, si en la clase 59 viste que deja el valor en `docker history`?

<details>
<summary>Comprueba</summary>

Porque una versión no es un secreto: que quede visible en la imagen es justo lo que quieres.
</details>

**En resumen:** `--build-arg APP_VERSION=…` → `ENV` → `/info`: la imagen dice qué versión es.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/lab-actions && git switch publicar` y las dos líneas de variables de "Cómo va esta clase".

### Pieza 4 — El job `publicar`

| Paso | Qué hace |
|------|----------|
| `aws-actions/configure-aws-credentials` | OIDC → credenciales temporales del rol (clase 86) |
| `aws-actions/amazon-ecr-login` | `docker login` contra tu registro de ECR. Su salida `registry` es `<cuenta>.dkr.ecr.us-east-1.amazonaws.com`, y oculta la contraseña en el log |
| `docker/setup-buildx-action` | prepara **BuildKit**, el constructor moderno de Docker, con caché y varias arquitecturas |
| `docker/build-push-action` | construye y sube. Con `cache-from` y `cache-to` `type=gha`, guarda las capas en la caché de GitHub Actions: la siguiente construcción solo rehace lo que cambió (clase 58) |

Las **etiquetas OCI** (`org.opencontainers.image.revision`, `…source`) son metadatos estándar dentro de la imagen: el commit y la URL del repositorio. Cualquier herramienta puede leerlos con `docker inspect`.

🔮 **Predice:** ¿qué pasará con `publicar` en el PR, y qué en `main`?

**Pruébalo.** Añade al final de `.github/workflows/ci.yml`, al mismo nivel que `imagen`:

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

👀 **Qué deberías ver:** en el PR, `publicar` como *skipped* (gris) junto a las otras tres en verde. En `main`, `publicar` corre después de las otras tres y su último step termina con la imagen subida, `lab-actions:<SHA del commit de main>`.

✋ **Sin mirar:** ¿qué impide que un PR sin revisar publique una imagen en ECR?

<details>
<summary>Comprueba</summary>

El `if:` del job (solo en los `push` a `main`) y, si alguien lo cambiara, la política de confianza del rol, que exige `refs/heads/main` (Rómpelo 3).
</details>

**En resumen:** `publicar` solo en `main`, después de las tres comprobaciones, con OIDC y caché `gha`.

### Pieza 5 — Comprobar lo publicado

De una imagen que corre se llega al código por tres caminos que deben coincidir: su etiqueta en ECR, la `version` de `/info` y la etiqueta OCI `revision`.

🔮 **Predice:** ¿qué `version` devolverá `/info`?

**Pruébalo:**

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

👀 **Qué deberías ver:** en la tabla, una imagen con el SHA completo de `main` como etiqueta; `/info` con `"version": "<ese SHA>"`; y la etiqueta OCI con el mismo SHA. De una imagen corriendo, al código exacto, en un paso.

✋ **Sin mirar:** una imagen de `lab-actions` falla en producción. ¿Cómo sabes qué código lleva?

<details>
<summary>Comprueba</summary>

Por su etiqueta (el SHA), por `/info` o por la etiqueta OCI `revision`: los tres dicen el commit, y en GitHub ese commit lleva a su PR y sus pruebas.
</details>

**En resumen:** etiqueta, `/info` y `revision`: el mismo SHA, de la imagen al commit.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws ecr create-repository … --image-tag-mutability IMMUTABLE` · `put-lifecycle-policy` | repositorio inmutable con ciclo de vida |
| `aws iam put-role-policy --role-name lab-github --policy-name subir-a-ecr …` | el permiso justo para subir |
| `ARG APP_VERSION=dev` + `ENV APP_VERSION=$APP_VERSION` | la versión dentro de la imagen |
| `if: github.event_name == 'push' && github.ref == 'refs/heads/main'` | publicar solo desde `main` |
| `needs: [lint, test, imagen]` | publicar solo si todo pasó |
| `aws-actions/amazon-ecr-login@<SHA>` → `steps.ecr.outputs.registry` | el registro |
| `docker/build-push-action@<SHA>` con `tags`, `build-args`, `cache-from/to: type=gha`, `labels` | construir y subir |
| `aws ecr describe-images --image-ids imageTag=…` | ¿existe ya esa versión? |
| `docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'` | el commit de una imagen |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Una release con su versión.** Un workflow nuevo, `release.yml`, que al crear en Git la etiqueta `v1.2.0` sube también `lab-actions:1.2.0`. ¿Qué tendrías que cambiar en la política de confianza del rol?

> 🧩 **Ejemplo resuelto:** el job `publicar` de la pieza 4, que etiqueta con `${{ github.sha }}`.

**Ahora tú, con huecos** (copia el job `publicar` en `release.yml`, sin el `if:` ni el `needs:`, y cambia esto):
```yaml
on:
  push:
    tags: ["____"]
# … antes de build-push-action:
      - id: version
        run: echo "valor=${GITHUB_REF_NAME#____}" >> "$GITHUB_OUTPUT"
# … en build-push-action:
          tags: ${{ steps.ecr.outputs.registry }}/lab-actions:${{ steps.version.outputs.____ }}
```
Completa: «En la política de confianza, la condición `ref` tendría que admitir también ____».

<details>
<summary>Pista</summary>

`${VAR#v}` quita la `v` del principio (clase 16). El token de una etiqueta trae `ref` = `refs/tags/v1.2.0`: con `StringLike` en lugar de `StringEquals` puedes admitir `refs/tags/v*`.
</details>

**2.** Mira el log de `build-push-action` en dos ejecuciones seguidas de `main`. ¿Cuántas capas salen como `CACHED` la segunda vez?

> 🧩 **Ejemplo resuelto:** en la pieza 3 de la clase 58, al cambiar solo `app.py`, los pasos hasta el `pip install` salían `CACHED`.

**Ahora tú, con huecos:**
```bash
gh run list --workflow ci.yml --branch main --limit 2
gh run view <id> --log | grep -c "____"
```
Completa: «La primera vez, ____ capas `CACHED`; la segunda, ____».

<details>
<summary>Pista</summary>

Busca la palabra `CACHED` en el log del job `publicar`. Con `cache-from: type=gha`, la segunda construcción reutiliza las capas guardadas por la primera.
</details>

**3.** Haz que el pipeline falle si el escaneo de ECR encuentra vulnerabilidades `CRITICAL`.

> 🧩 **Ejemplo resuelto:** la pieza 3 de la clase 75: `aws ecr describe-image-scan-findings … --query 'imageScanFindings.findingSeverityCounts'`.

**Ahora tú, con huecos** (un step al final de `publicar`):
```yaml
      - name: Sin vulnerabilidades críticas
        run: |
          aws ecr wait image-scan-complete --repository-name lab-actions --image-id "imageTag=$GITHUB_SHA"
          CRITICAS=$(aws ecr describe-image-scan-findings --repository-name lab-actions --image-id "imageTag=$GITHUB_SHA" \
            --query 'imageScanFindings.findingSeverityCounts.____' --output text)
          [ "$CRITICAS" = "None" ] || { echo "::error::$CRITICAS vulnerabilidades críticas"; exit ____; }
```

<details>
<summary>Pista</summary>

Las severidades van en mayúsculas. Si no hay ninguna crítica, la consulta devuelve `None`. El rol necesitará además `ecr:DescribeImageScanFindings` sobre el repositorio: añádelo a `subir-a-ecr.json`.
</details>

## Destruir al terminar

Nada que cobre por hora. Deja el repositorio `lab-actions` de ECR y la política del rol para las clases 88 y 89. Si te quedó algún contenedor local: `docker rm -f publicada sv`.

## Cierre

En `notas/fase-7/clase-87.md`:

1. ¿Por qué la imagen se etiqueta con el SHA del commit y no con `latest`? *(2 líneas. Empieza así: «Porque el SHA identifica una versión única del código:… `latest` se mueve y…»)*
2. ¿Qué significa que el job de publicación es idempotente, y por qué un repositorio inmutable te obliga a hacerlo así? *(2 líneas. Empieza así: «Que repetirlo produce el mismo resultado sin fallar:… Con etiquetas inmutables, un segundo push…»)*
3. Lista los permisos del rol para subir a ECR y por qué `GetAuthorizationToken` va sobre `*`. *(3 líneas. Empieza así: «`GetAuthorizationToken`, sobre `*`, porque… Las acciones de subida:… Y para consultar:…»)*
4. **Repaso (clase 86, sin mirar):** ¿qué cuatro condiciones tiene tu política de confianza y qué deja fuera cada una? *(4 líneas, una por condición. Empieza así: «`aud` = `sts.amazonaws.com`: deja fuera…»)*

Después, escríbeme `examíname clase-87`.

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

**Reto 1:** `tags: ["v*"]`, `${GITHUB_REF_NAME#v}` y `steps.version.outputs.valor`. En la política de confianza, la condición `ref` tendría que admitir también **`refs/tags/v*`** (con `StringLike`), o el job de la etiqueta no conseguiría el rol.

**Reto 2:** `grep -c "CACHED"`. La primera vez, ninguna o casi ninguna (la caché estaba vacía); la segunda, casi todas, salvo la del `COPY app.py` si cambió.

**Reto 3:** `findingSeverityCounts.CRITICAL` y `exit 1`, más el permiso `ecr:DescribeImageScanFindings` en el rol.
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
