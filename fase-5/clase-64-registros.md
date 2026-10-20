# Clase 64 — Registros: publicar en Docker Hub

**Dónde:** tu Ubuntu + Docker Hub · **Tiempo:** 75 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** una imagen que solo existe en tu portátil no la puede desplegar nadie. Un **registro** (Docker Hub, GitHub, AWS ECR) es el almacén del que tiran los servidores, los pipelines y Kubernetes. Hoy publicas tu imagen con una **etiqueta** de versión (`1.0.0`), entras con un **token** en lugar de tu contraseña, y aprendes por qué para desplegar se usa la versión o el ***digest***, nunca `latest`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Tu imagen `saludo:2`, de dos etapas y sin root (clase 59); `docker images`, `pull` y `run` (clase 57).
> - Una rama se mueve y un commit no (clase 22); `git rev-parse --short HEAD`.
> - `jq` (clase 47) y Base64, que no es cifrado.
> - Las cuentas con verificación en dos pasos y los tokens de GitHub (clase 24).

> 🔤 **Palabras nuevas de hoy:**
> - **registro** (*registry*): el servidor que almacena imágenes; Docker Hub (`docker.io`) es el de por defecto.
> - **repositorio**: todas las versiones de una imagen, como `usuario/saludo`.
> - **etiqueta** (*tag*): un nombre **móvil** para una versión: `1.0.0`, `latest`.
> - ***digest***: `sha256:…`, el identificador **inmutable** del contenido exacto.
> - **token de acceso personal** (PAT): una credencial con permisos limitados, que caduca y se revoca por separado.
> - ***push* / *pull***: publicar / descargar una imagen.

## Objetivo

- Entender qué son un registro, un repositorio, una etiqueta y un *digest*.
- Crear una cuenta de Docker Hub y entrar desde la terminal con un **token de acceso**, no con tu contraseña.
- Etiquetar y publicar una imagen tuya, y descargarla en limpio para comprobarla.
- Decidir qué etiquetas usar (`1.0.0`, `latest`, el commit) y por qué `latest` no sirve para desplegar.
- Saber dónde guarda Docker tus credenciales y cómo protegerlas.

## Por qué importa

Una imagen que solo existe en tu portátil no la puede desplegar nadie. El registro es el almacén del que tiran los servidores (fase 6), los pipelines (fase 7) y Kubernetes (fase 9): tú publicas `usuario/vigia:2.0.0` y cualquier máquina del mundo arranca exactamente esa imagen. Además, tu perfil de Docker Hub es otra parte visible de tu portafolio.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Necesitas la imagen `saludo:2` de la clase 59: si la borraste, reconstrúyela en `labs/clase-59` con `docker build -t saludo:2 .`.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min, con la cuenta creada y la imagen publicada); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-64 && cd ~/my-devops-journey/labs/clase-64
```

## Las piezas

### Pieza 1 — Los nombres de una imagen

```
docker.io / eduardogua / saludo : 1.0.0
└registro┘  └─usuario─┘ └repo──┘ └etiqueta┘
```

| Pieza | Qué es |
|-------|--------|
| **Registro** | el servidor que almacena imágenes: Docker Hub (`docker.io`, el de por defecto), GitHub (`ghcr.io`), AWS ECR (fase 6)… |
| **Repositorio** | `usuario/nombre`: todas las versiones de una imagen. Las oficiales (`python`, `nginx`) no llevan usuario |
| **Etiqueta** (*tag*) | un nombre **móvil** para una versión: `1.0.0`, `latest` |
| ***Digest*** | `sha256:…`: el identificador **inmutable** del contenido exacto |

Una etiqueta se puede mover a otra imagen; un *digest*, nunca (como una rama frente a un commit en Git, clase 22). `latest` es solo la etiqueta que Docker usa cuando no escribes otra: no significa "la más reciente" ni "la estable".

**Pruébalo** con una imagen que ya tienes:

```bash
docker image inspect nginx:1.29 --format '{{json .RepoDigests}}'
docker tag nginx:1.29 mi-nginx:prueba
docker images | grep nginx
docker rmi mi-nginx:prueba
```

👀 **Qué deberías ver:** `["nginx@sha256:1881968a…"]`, el *digest* con el que se descargó; y en `docker images`, `nginx 1.29` y `mi-nginx prueba` con **el mismo `IMAGE ID`**: `docker tag` no copia nada, solo añade otro nombre a la misma imagen. `rmi` quita ese nombre, no la imagen.

✋ **Sin mirar:** ¿qué se puede mover a otra imagen, la etiqueta o el *digest*?

<details>
<summary>Comprueba</summary>

La etiqueta. El *digest* identifica un contenido exacto y no cambia nunca.
</details>

**En resumen:** `registro/usuario/repositorio:etiqueta`; la etiqueta es un nombre móvil y el *digest*, el contenido exacto.

### Pieza 2 — Tu cuenta y tu token

Un **token de acceso personal** (PAT) es una contraseña de un solo uso específico: tiene permisos limitados, puede caducar y se revoca sin cambiar tu contraseña. Docker Hub los ofrece con cuatro niveles: *Repo Public Read-only*, *Repo Read-only*, *Repo Read & Write* y *Repo Read, Write, Delete*. Para publicar desde tu portátil basta *Read & Write*, y en un pipeline pondrás uno distinto, revocable por separado. Con la verificación en dos pasos activada, la terminal **solo** acepta tokens.

**Pruébalo** (estos pasos los haces tú en el navegador):

1. Crea una cuenta gratis en `hub.docker.com` (usa el mismo nombre que en GitHub si está libre: así tu portafolio es coherente). Activa la verificación en dos pasos.
2. Crea un token: tu avatar (arriba a la derecha) → **Account settings** → **Personal access tokens** → **Generate new token**. Nombre: `portatil-eduardo`; caducidad: 90 días; permisos: **Repo Read & Write**.
3. Cópialo en el momento: Docker Hub lo muestra **una sola vez**.

```bash
docker login -u TU_USUARIO
```

Cuando pida la contraseña, pega el **token**.

👀 **Qué deberías ver:** `Login Succeeded`, y quizá un aviso de que las credenciales se guardan sin cifrar en `~/.docker/config.json` (lo arreglas en el reto 1).

✋ **Sin mirar:** ¿qué permisos le das al token de tu portátil, y por qué no usas el mismo en un pipeline?

<details>
<summary>Comprueba</summary>

*Repo Read & Write*, lo justo para publicar. En el pipeline, otro token distinto, para poder revocar uno sin romper el otro.
</details>

**En resumen:** cuenta con verificación en dos pasos, token *Read & Write* que caduca, y `docker login` con el token.

### Pieza 3 — Etiquetar y publicar

| Etiqueta | Para qué |
|----------|----------|
| `1.0.0` (versión semántica) | lo que despliegas: fija y explícita |
| `1.0`, `1` | comodidad para quien quiere "la última de la 1.0" |
| `latest` | probar a mano; **nunca** para desplegar |
| el commit (`a8c549e`) | trazabilidad: qué código exacto hay dentro. La usarás en el pipeline (fase 7) |

Una misma imagen puede tener varias etiquetas a la vez.

🔮 **Predice:** las dos etiquetas, ¿ocupan el doble en Docker Hub?

**Pruébalo:**

```bash
USUARIO=TU_USUARIO
docker images saludo
docker tag saludo:2 "$USUARIO/saludo:1.0.0"
docker tag saludo:2 "$USUARIO/saludo:latest"
docker images "$USUARIO/saludo"
docker push "$USUARIO/saludo:1.0.0"
docker push "$USUARIO/saludo:latest"
```

👀 **Qué deberías ver:** las dos etiquetas con el mismo `IMAGE ID`; el primer `push` sube cada capa, y el segundo dice `Layer already exists` en todas: son dos nombres para la misma imagen. Cada `push` termina con una línea `…: digest: sha256:… size: …`: **copia ese *digest***, lo usarás en la pieza 4. Abre `hub.docker.com/r/TU_USUARIO/saludo`: ahí están tus dos etiquetas. El repositorio se creó solo con el primer `push`, público por defecto.

✋ **Sin mirar:** ¿qué etiqueta pondrías en el despliegue de un servidor: `latest` o `1.0.0`?

<details>
<summary>Comprueba</summary>

`1.0.0`: fija y explícita. `latest` se mueve con cada publicación.
</details>

**En resumen:** `docker tag imagen usuario/repo:etiqueta` y `docker push`; varias etiquetas, una sola imagen.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-64` y `USUARIO=TU_USUARIO`.

### Pieza 4 — Comprobarla desde cero y fijar por *digest*

`docker run` busca la imagen en local y, si no la tiene, la descarga del registro: es lo que hará una EC2. Y con `imagen@sha256:…` en lugar de `imagen:etiqueta` tienes la garantía de que es **exactamente** esa imagen, aunque alguien mueva la etiqueta. Es lo más seguro para producción; lo verás en los manifiestos de Kubernetes.

Docker Hub limita cuántas imágenes descarga una IP: hoy, 100 cada 6 horas sin cuenta y 200 con una cuenta gratis (verificado en octubre de 2026 en su documentación). En tu portátil no lo notarás; en un pipeline que descarga en cada ejecución, sí, y por eso los pipelines inician sesión.

**Pruébalo:**

```bash
docker rmi "$USUARIO/saludo:1.0.0" "$USUARIO/saludo:latest"
docker run -d --name desde-hub -p 127.0.0.1:8000:8000 "$USUARIO/saludo:1.0.0"
sleep 2 && curl -s localhost:8000/health ; echo
docker rm -f desde-hub
docker pull "$USUARIO/saludo@sha256:PEGA_AQUI_EL_DIGEST"
docker images --digests "$USUARIO/saludo"
```

👀 **Qué deberías ver:** `Unable to find image … locally`, la descarga desde Docker Hub y `{"status":"ok"}`. Después, el `pull` por *digest* y, en `docker images --digests`, la columna `DIGEST` con el mismo `sha256:…` que copiaste.

✋ **Sin mirar:** alguien mueve `1.0.0` a otra imagen. ¿Qué despliegue sigue recibiendo la imagen de siempre?

<details>
<summary>Comprueba</summary>

El que usa el *digest* (`usuario/saludo@sha256:…`): el *digest* no se mueve.
</details>

**En resumen:** `docker run` descarga lo que no tiene; `@sha256:…` fija el contenido exacto.

### Pieza 5 — Una etiqueta con el commit

Para saber qué código exacto hay en cada imagen, se etiqueta con el commit del que salió. Aquí la imagen no sale de ese repo, pero la idea es la que usarás en la fase 7: el pipeline construye, etiqueta con el commit y publica.

**Pruébalo:**

```bash
COMMIT=$(git -C ~/my-devops-journey rev-parse --short HEAD)
echo "$COMMIT"
docker tag saludo:2 "$USUARIO/saludo:$COMMIT"
docker push "$USUARIO/saludo:$COMMIT"
```

👀 **Qué deberías ver:** el commit corto (7 caracteres, como `23195f9`) y, otra vez, `Layer already exists` en cada capa: la tercera etiqueta de la misma imagen. En la web, en la pestaña *Tags*, aparecen `1.0.0`, `latest` y el commit.

✋ **Sin mirar:** ¿qué te dice una etiqueta con el commit que no te dice `1.0.0`?

<details>
<summary>Comprueba</summary>

Qué código exacto hay dentro: puedes ir a ese commit en Git y ver los archivos con los que se construyó.
</details>

**En resumen:** etiqueta de versión para desplegar, etiqueta del commit para la trazabilidad.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker login -u USUARIO` (con el token) · `docker logout` | entrar · salir |
| `docker tag origen usuario/repo:etiqueta` | otro nombre para la misma imagen |
| `docker push usuario/repo:etiqueta` | publicar |
| `docker pull usuario/repo:etiqueta` · `…@sha256:…` | descargar por etiqueta · por *digest* |
| `docker images --digests` · `docker image inspect … --format '{{json .RepoDigests}}'` | ver los *digest* |
| `git rev-parse --short HEAD` | el commit corto, para etiquetar |
| `~/.docker/config.json` | donde quedan tus credenciales |
| `"credsStore": "secretservice"` | guardarlas en el llavero del sistema |

## Rómpelo

**1. Publicar en un nombre que no es tuyo:**
```bash
docker tag saludo:2 saludo-sin-usuario:1.0
docker push saludo-sin-usuario:1.0
```
`denied: requested access to the resource is denied`. Sin usuario, el nombre apunta a las imágenes oficiales (`library/`), donde no puedes escribir. El mismo error sale si no has hecho `docker login` o si tu token es de solo lectura.

**2. `latest` se mueve:**
```bash
docker tag saludo:slim "$USUARIO/saludo:latest"
docker push "$USUARIO/saludo:latest"
docker run --rm "$USUARIO/saludo:latest" id
docker run --rm "$USUARIO/saludo:1.0.0" id
```
Has movido `latest` a otra imagen (la que corre como root, de la clase 59; si la borraste, reconstrúyela con `docker build -t saludo:slim -f Dockerfile.slim .` en `labs/clase-59`): quien despliegue `latest` mañana recibe algo distinto de lo que probó ayer. `1.0.0` sigue apuntando a la buena. Devuelve `latest` a su sitio: `docker tag saludo:2 "$USUARIO/saludo:latest" && docker push "$USUARIO/saludo:latest"`.

**3. Tus credenciales, a la vista:**

Tras `docker login`, Docker guarda las credenciales en `~/.docker/config.json`… codificadas en Base64, que **no es cifrado**. En tu portátil, la alternativa segura es un *credential helper* que las guarda en el llavero del sistema (el de GNOME en Ubuntu).

```bash
grep -A2 auths ~/.docker/config.json
jq -r '.auths["https://index.docker.io/v1/"].auth // empty' ~/.docker/config.json | base64 -d ; echo
```
Si la segunda línea muestra `TU_USUARIO:dckr_pat_…`, tu token está en un archivo legible, solo codificado. Cualquier programa que corra con tu usuario puede leerlo. Arréglalo con el reto 1 y, si alguna vez este archivo sale de tu máquina, revoca el token en Docker Hub (*Account settings → Personal access tokens*).

## Reto

En `labs/clase-64/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Guarda tus credenciales de Docker en el llavero del sistema, en lugar de en `config.json`.

> 🧩 **Ejemplo resuelto:** así debe quedar `~/.docker/config.json` al terminar, sin `auth` dentro de `auths`:
> ```json
> {
>   "auths": { "https://index.docker.io/v1/": {} },
>   "credsStore": "secretservice"
> }
> ```

**Ahora tú, con huecos:**
```bash
sudo apt install golang-docker-credential-____
docker logout
nano ~/.docker/config.json          # añade "credsStore": "____" (cuidado con las comas)
docker login -u TU_USUARIO
grep -c '"auth"' ~/.docker/config.json
```
El último comando debe dar ____.

<details>
<summary>Pista</summary>

El paquete se llama `golang-docker-credential-helpers`, y el llavero de GNOME es `secretservice`. Si `docker login` da error después del cambio, quita esa línea, vuelve a como estaba y entra otra vez.
</details>

**2.** Publica la imagen del contador de la clase 62 como `TU_USUARIO/contador:1.0.0`, con una descripción en la página del repositorio.

> 🧩 **Ejemplo resuelto:** la pieza 3: `docker tag saludo:2 "$USUARIO/saludo:1.0.0"` y `docker push`.

**Ahora tú, con huecos:**
```bash
cd ~/my-devops-journey/labs/clase-62 && docker compose build web
docker images | grep clase-62
docker tag clase-62-web "$USUARIO/____:1.0.0"
docker push "$USUARIO/contador:____"
```
Y en Docker Hub, pestaña *Overview*, pega esta descripción con tus datos:
```markdown
# contador
A tiny FastAPI app that counts visits in PostgreSQL. I built it in class 62 of my DevOps course.
Run it with the `compose.yaml` from https://github.com/____/my-devops-journey.
Tags: `1.0.0`.
```

<details>
<summary>Pista</summary>

Compose llama a la imagen que construye `proyecto-servicio`: aquí, `clase-62-web`.
</details>

**3.** Borra la etiqueta del commit desde la web de Docker Hub y comprueba que ya no se puede descargar.

> 🧩 **Ejemplo resuelto:** el Rómpelo 3 de la clase 57: `docker pull nginx:no-existe-esta-etiqueta` → `not found`.

**Ahora tú, con huecos:** en `hub.docker.com/r/TU_USUARIO/saludo`, pestaña *Tags*, borra la del commit. Después:
```bash
docker rmi "$USUARIO/saludo:$COMMIT"
docker pull "$USUARIO/saludo:____"
```
Completa: «El `pull` responde ____».

<details>
<summary>Pista</summary>

Borra antes la copia local con `rmi`, para que no te confunda. Si `$COMMIT` está vacío, vuelve a calcularlo como en la pieza 5.
</details>

## Cierre

En `notas/fase-5/clase-64.md`:

1. ¿Qué diferencia hay entre una etiqueta y un *digest*? ¿Cuál usarías para desplegar en producción y por qué? *(2 líneas. Empieza así: «La etiqueta es un nombre móvil que…; el digest… Para producción usaría… porque…»)*
2. ¿Por qué entras en Docker Hub con un token de acceso y no con tu contraseña? *(2 líneas. Empieza así: «Porque el token tiene permisos limitados, puede caducar y…»)*
3. ¿Qué problema tiene desplegar siempre `latest`? *(1–2 líneas. Empieza así: «Que `latest` se mueve con cada publicación:…»)*
4. **Repaso (clase 63, sin mirar):** ¿qué te dice un código de salida 137 y cómo distingues un OOM de otra causa? *(1–2 líneas. Empieza así: «Que el proceso murió por SIGKILL (128 + 9). Si `OOMKilled`…»)*

Después, escríbeme `examíname clase-64`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La etiqueta es un nombre móvil que se puede reasignar a otra imagen; el *digest* identifica el contenido exacto y no cambia nunca. Para producción, una etiqueta de versión fija (`1.0.0`) como mínimo, y el *digest* cuando necesitas la garantía total de que nadie ha cambiado la imagen.

**2.** Porque el token tiene permisos limitados (puedes darle solo lectura y escritura de repositorios), puede caducar y se revoca por separado si se filtra, sin cambiar tu contraseña ni afectar a tus otros accesos. Con la verificación en dos pasos, además, la terminal solo acepta tokens.

**3.** Que `latest` se mueve con cada publicación: el mismo despliegue puede traer imágenes distintas según el día, nadie sabe qué versión corre en cada máquina y volver atrás es difícil porque `latest` ya apunta a otra cosa.

**4.** Que el proceso murió por SIGKILL (128 + 9). Si `docker inspect` dice `OOMKilled: true`, fue el kernel por falta de memoria; si dice `false`, lo mató otra cosa, como un `docker stop` que agotó sus 10 segundos.

**Reto 1:** `golang-docker-credential-helpers`, `"credsStore": "secretservice"`, y `grep -c '"auth"'` da `0`: el token ya está en el llavero de GNOME.

**Reto 2:** `contador` y `1.0.0`.

**Reto 3:** `docker pull` responde con un error `not found`: la etiqueta ya no existe en el registro. Las demás (`1.0.0`, `latest`) siguen ahí, porque eran nombres distintos de la misma imagen.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| registry / repository | registro / repositorio |
| tag / digest | etiqueta / identificador inmutable |
| personal access token (PAT) | token de acceso personal |
| to push / to pull | publicar / descargar |
| rate limit | límite de peticiones |

🎙️ *"We deploy images by version tag or digest, never latest, and authenticate to registries with scoped, revocable access tokens."*

## Siguiente

[Clase 65 — Proyecto: Vigía v2 (I): PostgreSQL y el Dockerfile](clase-65-vigia-v2-imagen.md)
