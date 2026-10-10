# Clase 64 — Registros: publicar en Docker Hub

**Dónde:** tu Ubuntu + Docker Hub · **Tiempo:** 75 min · **Bloque:** A. Contenedores

## Objetivo

- Entender qué son un registro, un repositorio, una etiqueta y un *digest*.
- Crear una cuenta de Docker Hub y entrar desde la terminal con un **token de acceso**, no con tu contraseña.
- Etiquetar y publicar una imagen tuya, y descargarla en limpio para comprobarla.
- Decidir qué etiquetas usar (`1.0.0`, `latest`, el commit) y por qué `latest` no sirve para desplegar.
- Saber dónde guarda Docker tus credenciales y cómo protegerlas.

## Por qué importa

Una imagen que solo existe en tu portátil no la puede desplegar nadie. El registro es el almacén del que tiran los servidores (fase 6), los pipelines (fase 7) y Kubernetes (fase 9): tú publicas `usuario/vigia:2.0.0` y cualquier máquina del mundo arranca exactamente esa imagen. Además, tu perfil de Docker Hub es otra parte visible de tu portafolio.

## Teoría

### Los nombres de una imagen

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

### Qué etiquetas usar

| Etiqueta | Para qué |
|----------|----------|
| `1.0.0` (versión semántica) | lo que despliegas: fija y explícita |
| `1.0`, `1` | comodidad para quien quiere "la última de la 1.0" |
| `latest` | probar a mano; **nunca** para desplegar |
| el commit (`a8c549e`) | trazabilidad: qué código exacto hay dentro. La usarás en el pipeline (fase 7) |

Una misma imagen puede tener varias etiquetas a la vez.

### Entrar con un token, no con tu contraseña

Un **token de acceso personal** (PAT) es una contraseña de un solo uso específico: tiene permisos limitados, puede caducar y se revoca sin cambiar tu contraseña. Docker Hub los ofrece con cuatro niveles: *Repo Public Read-only*, *Repo Read-only*, *Repo Read & Write* y *Repo Read, Write, Delete*. Para publicar desde tu portátil basta *Read & Write*, y en un pipeline pondrás uno distinto, revocable por separado. Con la verificación en dos pasos activada, la terminal **solo** acepta tokens.

### Dónde quedan tus credenciales

Tras `docker login`, Docker guarda las credenciales en `~/.docker/config.json`… codificadas en Base64, que **no es cifrado** (Rómpelo 3). En tu portátil, la alternativa segura es un *credential helper* que las guarda en el llavero del sistema (el de GNOME en Ubuntu).

### Límites de descarga

Docker Hub limita cuántas imágenes descarga una IP: hoy, 100 cada 6 horas sin cuenta y 200 con una cuenta gratis (verificado en octubre de 2026 en su documentación). En tu portátil no lo notarás; en un pipeline que descarga en cada ejecución, sí, y por eso los pipelines inician sesión.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-64 && cd ~/my-devops-journey/labs/clase-64
```

### 1. Tu cuenta y tu token

1. Crea una cuenta gratis en `hub.docker.com` (usa el mismo nombre que en GitHub si está libre: así tu portafolio es coherente). Activa la verificación en dos pasos.
2. Crea un token: tu avatar (arriba a la derecha) → **Account settings** → **Personal access tokens** → **Generate new token**. Nombre: `portatil-eduardo`; caducidad: 90 días; permisos: **Repo Read & Write**.
3. Cópialo en el momento: Docker Hub lo muestra **una sola vez**.

```bash
docker login -u TU_USUARIO
```

Cuando pida la contraseña, pega el **token**. Debe responder `Login Succeeded`.

### 2. Etiquetar y publicar

Usa la imagen de dos etapas de la clase 59:

```bash
USUARIO=TU_USUARIO
docker images saludo
docker tag saludo:2 "$USUARIO/saludo:1.0.0"
docker tag saludo:2 "$USUARIO/saludo:latest"
docker images "$USUARIO/saludo"
docker push "$USUARIO/saludo:1.0.0"
docker push "$USUARIO/saludo:latest"
```

🔮 **Predice:** las dos etiquetas, ¿ocupan el doble en Docker Hub? No: `docker images` muestra el mismo `IMAGE ID`, son dos nombres para la misma imagen, y el segundo `push` dice `Layer already exists` en cada capa.

Copia el *digest* que imprime el `push` (`1.0.0: digest: sha256:… size: …`). Abre `hub.docker.com/r/TU_USUARIO/saludo`: ahí están tus dos etiquetas. El repositorio se creó solo con el primer `push`, público por defecto.

### 3. Comprobarla desde cero

```bash
docker rmi "$USUARIO/saludo:1.0.0" "$USUARIO/saludo:latest"
docker run -d --name desde-hub -p 127.0.0.1:8000:8000 "$USUARIO/saludo:1.0.0"
sleep 2 && curl -s localhost:8000/health ; echo
docker rm -f desde-hub
```

`docker run` no encontró la imagen en local y la descargó de Docker Hub: es lo que hará una EC2.

### 4. Fijar por *digest*

```bash
docker pull "$USUARIO/saludo@sha256:PEGA_AQUI_EL_DIGEST"
docker images --digests "$USUARIO/saludo"
```

Con el *digest* tienes la garantía de que es **exactamente** esa imagen, aunque alguien mueva la etiqueta. Es lo más seguro para producción; lo verás en los manifiestos de Kubernetes.

### 5. Una etiqueta con el commit

```bash
COMMIT=$(git -C ~/my-devops-journey rev-parse --short HEAD)
docker tag saludo:2 "$USUARIO/saludo:$COMMIT"
docker push "$USUARIO/saludo:$COMMIT"
```

Aquí la imagen no sale de ese repo, pero la idea es la que usarás en la fase 7: cada imagen etiquetada con el commit del que salió.

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
Has movido `latest` a otra imagen (la que corre como root, de la clase 59): quien despliegue `latest` mañana recibe algo distinto de lo que probó ayer. `1.0.0` sigue apuntando a la buena. Devuelve `latest` a su sitio: `docker tag saludo:2 "$USUARIO/saludo:latest" && docker push "$USUARIO/saludo:latest"`.

**3. Tus credenciales, a la vista:**
```bash
grep -A2 auths ~/.docker/config.json
jq -r '.auths["https://index.docker.io/v1/"].auth // empty' ~/.docker/config.json | base64 -d ; echo
```
Si la segunda línea muestra `TU_USUARIO:dckr_pat_…`, tu token está en un archivo legible, solo codificado. Cualquier programa que corra con tu usuario puede leerlo. Arréglalo con el Reto 1 y, si alguna vez este archivo sale de tu máquina, revoca el token en Docker Hub (*Account settings → Personal access tokens*).

## Reto

1. **Guardar las credenciales en el llavero.** Instala el *helper*: `sudo apt install golang-docker-credential-helpers`. Haz `docker logout`, añade `"credsStore": "secretservice"` a `~/.docker/config.json` (es un JSON: respeta las llaves y las comas) y vuelve a hacer `docker login`. Comprueba que `config.json` ya no tiene la clave `auth`. Si `docker login` da error después, quita esa línea y vuelve a como estaba.
2. Publica la imagen del contador de la clase 62 como `TU_USUARIO/contador:1.0.0`, con su `README` en la página del repositorio de Docker Hub (pestaña *Overview*).
3. Borra la etiqueta del commit desde la web de Docker Hub (pestaña *Tags*) y comprueba que `docker pull` de esa etiqueta ya falla.

## Cierre

En `notas/fase-5/clase-64.md`:

1. ¿Qué diferencia hay entre una etiqueta y un *digest*? ¿Cuál usarías para desplegar en producción y por qué?
2. ¿Por qué entras en Docker Hub con un token de acceso y no con tu contraseña?
3. ¿Qué problema tiene desplegar siempre `latest`?
4. **Repaso (clase 63, sin mirar):** ¿qué te dice un código de salida 137 y cómo distingues un OOM de otra causa?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La etiqueta es un nombre móvil que se puede reasignar a otra imagen; el *digest* identifica el contenido exacto y no cambia nunca. Para producción, una etiqueta de versión fija (`1.0.0`) como mínimo, y el *digest* cuando necesitas la garantía total de que nadie ha cambiado la imagen.

**2.** Porque el token tiene permisos limitados (puedes darle solo lectura y escritura de repositorios), puede caducar y se revoca por separado si se filtra, sin cambiar tu contraseña ni afectar a tus otros accesos. Con la verificación en dos pasos, además, la terminal solo acepta tokens.

**3.** Que `latest` se mueve con cada publicación: el mismo despliegue puede traer imágenes distintas según el día, nadie sabe qué versión corre en cada máquina y volver atrás es difícil porque `latest` ya apunta a otra cosa.

**4.** Que el proceso murió por SIGKILL (128 + 9). Si `docker inspect` dice `OOMKilled: true`, fue el kernel por falta de memoria; si dice `false`, lo mató otra cosa, como un `docker stop` que agotó sus 10 segundos.

**Reto 1:** con el *helper*, `config.json` queda así (y ya sin `auth` dentro de `auths`):
```json
{
  "auths": { "https://index.docker.io/v1/": {} },
  "credsStore": "secretservice"
}
```
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
