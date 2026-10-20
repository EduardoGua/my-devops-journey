# Clase 59 — Imágenes pequeñas y seguras

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** una imagen buena para producción es **pequeña** (menos que descargar y menos paquetes con vulnerabilidades), **no corre como root** y **no lleva secretos dentro**. Hoy aprendes las cuatro herramientas para conseguirlo: una base `slim`, la construcción en varias etapas, la instrucción `USER` y el escáner `trivy`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El Dockerfile, las capas, `docker history`, `ARG` y `ENV` (clase 58, con su reto 2).
> - Por qué root en un contenedor es root en el host (clase 56); `docker inspect` (clase 57).
> - `useradd` y los UID (clase 09); `apt-get install` (clase 10); el entorno virtual (clase 46).
> - Que lo que entra en la historia de Git se queda (clase 22).

> 🔤 **Palabras nuevas de hoy:**
> - **imagen `slim`**: la variante reducida de una imagen base, sin compiladores ni herramientas de más.
> - ***multi-stage***: un Dockerfile con varias etapas (`FROM … AS nombre`); la final copia solo lo que necesita.
> - **`USER`**: la instrucción que elige con qué usuario corre el proceso del contenedor.
> - **CVE**: el identificador público de una vulnerabilidad conocida, como `CVE-2026-33634`.
> - **escáner de vulnerabilidades** (`trivy`): compara los paquetes de una imagen con las listas de CVE.
> - **ataque a la cadena de suministro** (*supply-chain attack*): atacar una herramienta o dependencia que otros usan, para llegar a ellos.

## Objetivo

- Elegir la imagen base con criterio: completa, `slim` o `alpine`.
- Construir en varias etapas (*multi-stage*) para dejar fuera de la imagen final las herramientas de construcción.
- Ejecutar tu aplicación con un usuario sin privilegios.
- Mantener los secretos fuera de la imagen, y ver por qué `ARG` y `ENV` no sirven para eso.
- Escanear una imagen en busca de vulnerabilidades conocidas con `trivy`, y leer el resultado con criterio.

## Por qué importa

Una imagen grande tarda más en subirse, en descargarse en cada servidor y en arrancar en Kubernetes, y cada paquete de más es una posible vulnerabilidad. Una imagen que corre como root convierte cualquier fallo de tu aplicación en un problema de toda la máquina (clase 56). Y un secreto horneado en una imagen publicada en Docker Hub es un secreto publicado. Los equipos de seguridad revisan estas tres cosas en cada imagen, y muchos pipelines bloquean las que no las cumplen.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Partes de la API de la clase 58.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 50 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre. La pieza 5 descarga la base de datos de vulnerabilidades: deja unos minutos para eso.

```bash
mkdir -p ~/my-devops-journey/labs/clase-59 && cd ~/my-devops-journey/labs/clase-59
cp ../clase-58/app.py ../clase-58/requirements.txt ../clase-58/.dockerignore .
```

## Las piezas

### Pieza 1 — La imagen base

Con la API de la clase 58, medido en tu Ubuntu:

| Base | Tamaño con la app | Comentario |
|------|-------------------|------------|
| `python:3.14` | 1,66 GB | Debian completo con compiladores y herramientas: cómodo para construir, enorme para ejecutar |
| `python:3.14-slim` | 218 MB | Debian mínimo: el punto de partida razonable |
| `python:3.14-alpine` | menos aún | usa `musl` en lugar de `glibc`: algunas librerías de Python no tienen paquetes precompilados y hay que compilarlas |

Para Python, `slim` es el equilibrio habitual. Y siempre con versión: `python:3.14-slim`, no `python`.

🔮 **Predice** la diferencia de tamaño entre la imagen completa y la `slim`, con la misma aplicación.

**Pruébalo:**

```bash
cat > Dockerfile.completa <<'EOF'
FROM python:3.14
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
sed 's/^FROM python:3.14$/FROM python:3.14-slim/' Dockerfile.completa > Dockerfile.slim
docker build -q -t saludo:completa -f Dockerfile.completa .
docker build -q -t saludo:slim -f Dockerfile.slim .
docker images saludo
```

👀 **Qué deberías ver:** `saludo:completa` con unos 1,66 GB y `saludo:slim` con unos 218 MB: más de siete veces menos, con la misma aplicación. La primera construcción tarda: descarga más de 1 GB de imagen base.

✋ **Sin mirar:** ¿por qué `alpine` no es siempre la mejor opción para Python?

<details>
<summary>Comprueba</summary>

Porque usa `musl` en lugar de `glibc`, y algunas librerías de Python no tienen paquetes precompilados para ella: hay que compilarlas, lo que alarga y complica la construcción.
</details>

**En resumen:** para Python, `python:3.14-slim`; la completa es para construir, no para ejecutar.

### Pieza 2 — *Multi-stage*: construir en una imagen, ejecutar en otra

Algunas dependencias necesitan compiladores para instalarse (`build-essential`, cabeceras de C…), pero tu aplicación no los necesita para **ejecutarse**. Con varias etapas, la primera tiene las herramientas y la segunda solo copia el resultado:

```dockerfile
# Etapa 1: herramientas de construcción + dependencias en un entorno virtual
FROM python:3.14-slim AS construccion
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Etapa 2: solo lo necesario para ejecutar
FROM python:3.14-slim
RUN useradd --system --uid 10001 --no-create-home app
WORKDIR /app
COPY --from=construccion /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
COPY app.py .
USER app
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

`COPY --from=construccion` copia de la etapa anterior; lo demás de esa etapa (compiladores incluidos) no llega a la imagen final. El entorno virtual en `/opt/venv` (clase 46) es lo que se lleva: todas las dependencias en una carpeta. `PYTHONUNBUFFERED=1` hace que Python escriba los logs al momento, sin retenerlos en un búfer. (`useradd` y `USER` son de la pieza 3.)

**Pruébalo.** Primero, en una sola etapa con los compiladores dentro; después, en dos etapas:

```bash
cat > Dockerfile.herramientas <<'EOF'
FROM python:3.14-slim
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
docker build -q -t saludo:herramientas -f Dockerfile.herramientas .
cat > Dockerfile <<'EOF'
# Etapa 1: herramientas de construcción + dependencias en un entorno virtual
FROM python:3.14-slim AS construccion
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Etapa 2: solo lo necesario para ejecutar
FROM python:3.14-slim
RUN useradd --system --uid 10001 --no-create-home app
WORKDIR /app
COPY --from=construccion /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
COPY app.py .
USER app
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
docker build -q -t saludo:2 .
docker images saludo
docker run --rm saludo:herramientas sh -c 'command -v gcc'
docker run --rm saludo:2 sh -c 'command -v gcc || echo "sin compiladores"'
```

👀 **Qué deberías ver:** `saludo:herramientas` con unos 647 MB y `saludo:2` con unos 221 MB; `/usr/bin/gcc` en la primera y `sin compiladores` en la segunda. Si tus dependencias no necesitan compilarse, como estas, `slim` en una sola etapa ya es pequeña. El *multi-stage* brilla cuando la construcción necesita herramientas que no quieres en producción.

✋ **Sin mirar:** en un Dockerfile de dos etapas, ¿qué llega a la imagen final de la primera etapa?

<details>
<summary>Comprueba</summary>

Solo lo que copias con `COPY --from=construccion` (aquí, `/opt/venv`). El resto, compiladores incluidos, se queda fuera.
</details>

**En resumen:** la primera etapa construye con herramientas; la final copia solo el resultado con `COPY --from=`.

### Pieza 3 — Un usuario sin privilegios

Por defecto, el proceso de un contenedor es **root**, y si alguien explota tu aplicación y escapa del contenedor, es root en el host. `useradd --system` crea un usuario de sistema y `USER app` hace que todo lo que viene después, incluido el proceso al arrancar, corra con él. Un UID alto y fijo (10001) evita chocar con usuarios del host y facilita dar permisos en volúmenes.

Consecuencia: ese usuario no puede escribir en `/app` (es de root). Lo que la aplicación deba escribir (datos, archivos temporales) va a una carpeta suya o, mejor, a un volumen (clase 60).

🔮 **Predice:** ¿podrá el usuario `app` crear un archivo en `/app`?

**Pruébalo:**

```bash
docker run --rm saludo:2 id
docker run --rm saludo:slim id
docker run --rm saludo:2 sh -c 'touch /app/prueba'
docker run -d --name s2 -p 8000:8000 saludo:2 && sleep 2 && curl -s localhost:8000/health ; echo
docker rm -f s2
```

👀 **Qué deberías ver:** `uid=10001(app) gid=… groups=…` en `saludo:2` y `uid=0(root) gid=0(root)…` en `saludo:slim`; `touch: cannot touch '/app/prueba': Permission denied`, porque la carpeta es de root, y así debe ser; y aun así `{"status":"ok"}`: la aplicación funciona igual, porque solo necesita **leer** su código.

✋ **Sin mirar:** tu aplicación necesita escribir una base de datos. ¿Lo arreglas volviendo a root?

<details>
<summary>Comprueba</summary>

No: le das una carpeta suya (`RUN mkdir /datos && chown app /datos`) o, mejor, un volumen (clase 60).
</details>

**En resumen:** `useradd --system --uid 10001` + `USER app`: el proceso no es root, y solo escribe donde tú le dejes.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-59`.

### Pieza 4 — Los secretos no van en la imagen

| Forma | ¿Queda en la imagen? |
|-------|----------------------|
| `ENV DB_PASSWORD=…` | sí, y se ve con `docker inspect` |
| `ARG TOKEN` + `--build-arg TOKEN=…` | sí, se ve con `docker history` |
| `COPY .env .` | sí, dentro del sistema de archivos |
| variable de entorno **al arrancar** (`docker run -e`, Compose) | no: la recibe el contenedor, no la imagen |

Las imágenes se suben a registros y se comparten: todo lo que hay en ellas, incluidas sus capas intermedias, debe poder verse. Los secretos llegan al **ejecutar**: variables de entorno o archivos de secretos en Compose (clase 62), Secrets en Kubernetes (fase 9), Secrets Manager en AWS. (Si un secreto hace falta para **construir**, BuildKit tiene `RUN --mount=type=secret`, que no lo deja en ninguna capa.)

**Pruébalo:**

```bash
cat > Dockerfile.secreto <<'EOF'
FROM python:3.14-slim
ARG API_TOKEN
ENV DB_PASSWORD=supersecreta
RUN echo "usando el token $API_TOKEN" > /dev/null
CMD ["sleep", "1"]
EOF
docker build -q -t secreto -f Dockerfile.secreto --build-arg API_TOKEN=tok_123456 .
docker history secreto --no-trunc --format '{{.CreatedBy}}' | grep -E 'API_TOKEN|DB_PASSWORD'
docker inspect secreto --format '{{json .Config.Env}}'
docker rmi secreto
```

👀 **Qué deberías ver:** en `docker history`, las líneas con `API_TOKEN=tok_123456` y `DB_PASSWORD=supersecreta`; en `docker inspect`, `"DB_PASSWORD=supersecreta"` dentro de la lista de variables. Cualquiera que descargue la imagen puede leerlos, aunque nunca arranque un contenedor.

✋ **Sin mirar:** ¿cómo debe llegar la contraseña de la base de datos a tu contenedor?

<details>
<summary>Comprueba</summary>

Al ejecutarlo: una variable de entorno con `docker run -e` o un archivo de secretos de Compose; en Kubernetes, un Secret; en AWS, Secrets Manager. Nunca dentro de la imagen.
</details>

**En resumen:** `ENV`, `ARG` y `COPY` dejan los secretos en la imagen; los secretos se pasan al arrancar.

### Pieza 5 — Escanear vulnerabilidades con `trivy`

`trivy` compara los paquetes de una imagen con las bases de datos públicas de vulnerabilidades (CVE). Para leer su informe con criterio:
- **Severidad**: `CRITICAL` y `HIGH` primero.
- **¿Tiene arreglo?** Muchas vulnerabilidades del sistema base todavía no tienen versión corregida. `--ignore-unfixed` muestra solo las que puedes resolver hoy, normalmente actualizando la imagen base o una dependencia.
- Menos paquetes, menos vulnerabilidades: por eso la imagen final no debe llevar compiladores.

> **El escáner también se ataca.** En marzo de 2026, alguien con credenciales robadas publicó una versión maliciosa de Trivy, la 0.69.4, y reescribió las etiquetas de sus GitHub Actions (CVE-2026-33634). La lección vale para cualquier herramienta: fija la **versión exacta**, y en la fase 7 fijarás las *actions* por su commit, no por su etiqueta. Aquí usarás `aquasec/trivy:0.75.0`, publicada en octubre de 2026.

**Pruébalo:**

```bash
docker pull aquasec/trivy:0.75.0
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --severity HIGH,CRITICAL saludo:2
```

La primera vez descarga la base de datos de vulnerabilidades (unos minutos); el volumen `trivy-cache` la guarda para las siguientes. Montar el socket le permite leer tus imágenes locales (y, recuerda la clase 56, le da poder de root: hazlo solo con herramientas de confianza y versión fijada).

👀 **Qué deberías ver:** una tabla para el sistema (Debian) y otra para los paquetes de Python, cada fila con la librería, el CVE, la severidad, la versión instalada y la que lo corrige, si existe. Ahora, solo lo que tiene arreglo, y el total de la imagen con compiladores:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --quiet --severity HIGH,CRITICAL --ignore-unfixed saludo:2
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --quiet --severity HIGH,CRITICAL saludo:herramientas | grep Total
```

🔮 **Predice:** ¿cuál tendrá más vulnerabilidades, la imagen con compiladores o la de dos etapas?

👀 **Qué deberías ver:** medido en octubre de 2026, unas 100 en la imagen con compiladores frente a unas 50 en la de dos etapas, casi todas del sistema base y sin arreglo todavía. Con `--ignore-unfixed` quedan solo unas pocas, en paquetes de Python que la imagen base trae dentro de `pip`. Tus números serán otros: la base de datos de vulnerabilidades cambia cada día.

✋ **Sin mirar:** ¿qué hace `--ignore-unfixed`, y por qué es útil?

<details>
<summary>Comprueba</summary>

Muestra solo las vulnerabilidades que ya tienen una versión corregida: las que puedes resolver hoy, actualizando la imagen base o una dependencia.
</details>

**En resumen:** `trivy image --severity HIGH,CRITICAL [--ignore-unfixed] imagen`, con la versión de `trivy` fijada; menos paquetes, menos vulnerabilidades.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `FROM python:3.14-slim` | base reducida, con versión |
| `FROM … AS construccion` · `COPY --from=construccion /opt/venv /opt/venv` | multi-stage |
| `apt-get install -y --no-install-recommends … && rm -rf /var/lib/apt/lists/*` | instalar sin dejar restos en la capa |
| `RUN useradd --system --uid 10001 --no-create-home app` · `USER app` | usuario sin privilegios |
| `ENV PYTHONUNBUFFERED=1` | logs al momento |
| `docker history --no-trunc` · `docker inspect --format '{{json .Config.Env}}'` | dónde se ven los secretos horneados |
| `docker run -e SECRETO=…` | el secreto al arrancar, no en la imagen |
| `trivy image --severity HIGH,CRITICAL --ignore-unfixed imagen` | escanear |
| `docker save imagen` | exportar la imagen con todas sus capas |

## Rómpelo

**1. "Lo quito en la capa siguiente":**
```bash
cat > Dockerfile.borrado <<'EOF'
FROM python:3.14-slim
RUN echo "API_KEY=abc123" > /secreto.txt
RUN rm /secreto.txt
CMD ["sleep", "1"]
EOF
docker build -q -t borrado -f Dockerfile.borrado .
docker run --rm borrado ls /secreto.txt
docker save borrado | grep -a -o 'API_KEY=abc123' | head -1
docker rmi borrado
```
En el contenedor el archivo ya no está, pero sigue dentro de la capa del primer `RUN`: las capas solo se añaden, nunca se reescriben. `docker save` exporta la imagen con todas sus capas en un archivo `tar`, y `grep -a` (que busca también en datos binarios) encuentra el secreto ahí dentro. Es la versión en contenedores de la lección de Git de la clase 22: lo que entra en la historia, se queda.

**2. Escribir donde no se puede:**
```bash
docker run --rm saludo:2 python -c 'open("/app/datos.db", "w").write("x")'
```
`PermissionError`. Si tu aplicación necesita escribir, dale una carpeta suya (`RUN mkdir /datos && chown app /datos`) o un volumen (clase 60). No se arregla volviendo a root.

## Reto

En `labs/clase-59/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escanea `nginx:1.29` y `nginx:1.29-alpine` y compara el número de vulnerabilidades HIGH y CRITICAL con arreglo y el tamaño de cada una.

> 🧩 **Ejemplo resuelto:** el segundo escaneo de la pieza 5, con `--quiet --severity HIGH,CRITICAL --ignore-unfixed`.

**Ahora tú, con huecos:**
```bash
for img in nginx:1.29 nginx:1.29-____; do
  docker pull -q "$img"
  echo "== $img $(docker images --format '{{.Size}}' "$img")"
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
    aquasec/trivy:0.75.0 image --quiet --severity HIGH,CRITICAL --ignore-____ "$img" | grep ____
done
```

<details>
<summary>Pista</summary>

La línea que resume cada tabla empieza por `Total:`. La variante Alpine trae muchos menos paquetes.
</details>

**2.** Pide a `trivy` el informe en JSON y cuenta con `jq` las vulnerabilidades HIGH de `saludo:2`.

> 🧩 **Ejemplo resuelto:** `jq '.[].url'` de la clase 53, pieza 3: `[]` recorre una lista y `.url` saca un campo.

**Ahora tú, con huecos:**
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --quiet --format ____ saludo:2 > informe.json
jq '[.Results[].Vulnerabilities[]? | select(.Severity == "____")] | length' informe.json
```

<details>
<summary>Pista</summary>

`Results` tiene una sección por tipo (sistema, paquetes de Python), y cada una su lista `Vulnerabilities`. El `?` evita un error en las secciones sin vulnerabilidades, donde esa lista no existe.
</details>

**3.** Añade un `HEALTHCHECK` a tu Dockerfile de dos etapas y comprueba que funciona también con el usuario `app`.

> 🧩 **Ejemplo resuelto:** la línea `HEALTHCHECK --interval=10s CMD ["python", "-c", "…"]` del reto 1 de la clase 58.

**Ahora tú, con huecos:** copia esa línea antes del `CMD` del `Dockerfile`, y:
```bash
docker build -q -t saludo:hc2 .
docker run -d --name hc2 saludo:hc2 && sleep 15
docker inspect hc2 --format '{{.State.Health.____}}'
docker exec hc2 ____
docker rm -f hc2
```

<details>
<summary>Pista</summary>

El chequeo corre con el usuario de la imagen (`app`), y pedir `http://127.0.0.1:8000/health` no necesita privilegios. `docker exec hc2 id` te dice con qué usuario corre.
</details>

Al terminar, borra las imágenes de prueba de esta clase: `docker rmi saludo:completa saludo:herramientas saludo:slim saludo:hc2`.

## Cierre

En `notas/fase-5/clase-59.md`:

1. ¿Cuándo reduce de verdad el tamaño una construcción en varias etapas? Pon el ejemplo de la clase. *(2 líneas. Empieza así: «Cuando construir necesita herramientas que ejecutar no necesita, como… En la clase: … MB en una etapa frente a … MB en dos.»)*
2. ¿Por qué tu imagen debe correr con un usuario que no sea root? ¿Qué consecuencia tiene para la aplicación? *(2 líneas. Empieza así: «Porque si alguien explota la aplicación y escapa del contenedor, será… Consecuencia: la aplicación no puede escribir en…»)*
3. ¿Por qué no sirven `ENV` ni `ARG` para pasar secretos? ¿Cómo llegan entonces? *(2 líneas. Empieza así: «Porque quedan guardados en la imagen: `ENV` se ve con… y `ARG` con… Los secretos se pasan al…»)*
4. **Repaso (clase 58, sin mirar):** ¿por qué la forma shell de `CMD` hace que `docker stop` tarde 10 segundos? *(1–2 líneas. Empieza así: «Porque el PID 1 es `/bin/sh -c`, que…»)*

Después, escríbeme `examíname clase-59`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Cuando construir necesita herramientas que ejecutar no necesita: compiladores, cabeceras, `git`… La primera etapa las tiene y la segunda copia solo el resultado (aquí, el entorno virtual). En la clase: 647 MB con `build-essential` en una sola etapa, frente a 221 MB en dos. Si las dependencias no necesitan compilarse, la diferencia es mínima, y lo que de verdad reduce es pasar de `python:3.14` a `python:3.14-slim` (1,66 GB → 218 MB).

**2.** Porque si alguien explota la aplicación y logra escapar del contenedor, será root en el host (el root del contenedor es el root del host). Con un usuario sin privilegios, el daño se limita a lo que ese usuario puede hacer. Consecuencia: la aplicación no puede escribir en carpetas de root como `/app`; lo que deba escribir va a una carpeta suya o a un volumen.

**3.** Porque quedan guardados en la imagen: `ENV` se ve con `docker inspect` y `ARG` en `docker history`, y la imagen se sube a registros y se comparte. Los secretos se pasan al **ejecutar**: variables de entorno o archivos de secretos de Compose, Secrets de Kubernetes, o un gestor como AWS Secrets Manager.

**4.** Porque el PID 1 es `/bin/sh -c "…"`, que no reenvía SIGTERM a la aplicación. Docker espera los 10 segundos de cortesía y la termina con SIGKILL.

**Reto 1:** `nginx:1.29-alpine`, `--ignore-unfixed` y `grep Total`. La de Alpine pesa varias veces menos y tiene muchas menos vulnerabilidades (a menudo ninguna con arreglo), porque trae muchos menos paquetes.

**Reto 2:** `--format json` y `"HIGH"`.

**Reto 3:** `{{.State.Health.Status}}` → `healthy`, y `docker exec hc2 id` → `uid=10001(app)…`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| base image / slim image | imagen base / imagen reducida |
| multi-stage build | construcción en varias etapas |
| non-root user / least privilege | usuario sin privilegios / mínimo privilegio |
| vulnerability scan / CVE | escaneo de vulnerabilidades / vulnerabilidad catalogada |
| supply-chain attack | ataque a la cadena de suministro |

🎙️ *"My images use a slim base, a multi-stage build so compilers never reach production, run as a non-root user, never contain secrets, and get scanned with a pinned version of Trivy in CI."*

## Siguiente

[Clase 60 — Volúmenes y persistencia](clase-60-volumenes.md)
