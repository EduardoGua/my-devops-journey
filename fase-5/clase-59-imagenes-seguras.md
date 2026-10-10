# Clase 59 — Imágenes pequeñas y seguras

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

## Objetivo

- Elegir la imagen base con criterio: completa, `slim` o `alpine`.
- Construir en varias etapas (*multi-stage*) para dejar fuera de la imagen final las herramientas de construcción.
- Ejecutar tu aplicación con un usuario sin privilegios.
- Mantener los secretos fuera de la imagen, y ver por qué `ARG` y `ENV` no sirven para eso.
- Escanear una imagen en busca de vulnerabilidades conocidas con `trivy`, y leer el resultado con criterio.

## Por qué importa

Una imagen grande tarda más en subirse, en descargarse en cada servidor y en arrancar en Kubernetes, y cada paquete de más es una posible vulnerabilidad. Una imagen que corre como root convierte cualquier fallo de tu aplicación en un problema de toda la máquina (clase 56). Y un secreto horneado en una imagen publicada en Docker Hub es un secreto publicado. Los equipos de seguridad revisan estas tres cosas en cada imagen, y muchos pipelines bloquean las que no las cumplen.

## Teoría

### La imagen base

Con la API de la clase 58, medido en tu Ubuntu:

| Base | Tamaño con la app | Comentario |
|------|-------------------|------------|
| `python:3.14` | 1,66 GB | Debian completo con compiladores y herramientas: cómodo para construir, enorme para ejecutar |
| `python:3.14-slim` | 218 MB | Debian mínimo: el punto de partida razonable |
| `python:3.14-alpine` | menos aún | usa `musl` en lugar de `glibc`: algunas librerías de Python no tienen paquetes precompilados y hay que compilarlas |

Para Python, `slim` es el equilibrio habitual. Y siempre con versión: `python:3.14-slim`, no `python`.

### *Multi-stage*: construir en una imagen, ejecutar en otra

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

`COPY --from=construccion` copia de la etapa anterior; lo demás de esa etapa (compiladores incluidos) no llega a la imagen final. El entorno virtual en `/opt/venv` (clase 46) es lo que se lleva: todas las dependencias en una carpeta. `PYTHONUNBUFFERED=1` hace que Python escriba los logs al momento, sin retenerlos en un búfer.

### Un usuario sin privilegios

Por defecto, el proceso de un contenedor es **root**, y si alguien explota tu aplicación y escapa del contenedor, es root en el host. `useradd --system` crea un usuario de sistema y `USER app` hace que todo lo que viene después, incluido el proceso al arrancar, corra con él. Un UID alto y fijo (10001) evita chocar con usuarios del host y facilita dar permisos en volúmenes.

Consecuencia: ese usuario no puede escribir en `/app` (es de root). Lo que la aplicación deba escribir (datos, archivos temporales) va a una carpeta suya o, mejor, a un volumen (clase 60).

### Los secretos no van en la imagen

| Forma | ¿Queda en la imagen? |
|-------|----------------------|
| `ENV DB_PASSWORD=…` | sí, y se ve con `docker inspect` |
| `ARG TOKEN` + `--build-arg TOKEN=…` | sí, se ve con `docker history` |
| `COPY .env .` | sí, dentro del sistema de archivos |
| variable de entorno **al arrancar** (`docker run -e`, Compose) | no: la recibe el contenedor, no la imagen |

Las imágenes se suben a registros y se comparten: todo lo que hay en ellas, incluidas sus capas intermedias, debe poder verse. Los secretos llegan al **ejecutar**: variables de entorno o archivos de secretos en Compose (clase 62), Secrets en Kubernetes (fase 9), Secrets Manager en AWS. (Si un secreto hace falta para **construir**, BuildKit tiene `RUN --mount=type=secret`, que no lo deja en ninguna capa.)

### Escanear vulnerabilidades

`trivy` compara los paquetes de una imagen con las bases de datos públicas de vulnerabilidades (CVE). Para leer su informe con criterio:
- **Severidad**: `CRITICAL` y `HIGH` primero.
- **¿Tiene arreglo?** Muchas vulnerabilidades del sistema base todavía no tienen versión corregida. `--ignore-unfixed` muestra solo las que puedes resolver hoy, normalmente actualizando la imagen base o una dependencia.
- Menos paquetes, menos vulnerabilidades: por eso la imagen final no debe llevar compiladores.

> **El escáner también se ataca.** En marzo de 2026, alguien con credenciales robadas publicó una versión maliciosa de Trivy, la 0.69.4, y reescribió las etiquetas de sus GitHub Actions (CVE-2026-33634). La lección vale para cualquier herramienta: fija la **versión exacta**, y en la fase 7 fijarás las *actions* por su commit, no por su etiqueta. Aquí usarás `aquasec/trivy:0.75.0`, publicada en octubre de 2026.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-59 && cd ~/my-devops-journey/labs/clase-59
cp ../clase-58/app.py ../clase-58/requirements.txt ../clase-58/.dockerignore .
```

### 1. Comparar bases

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

🔮 **Predice** la diferencia de tamaño antes de mirarla. Medido en Ubuntu 26.04: 1,66 GB frente a 218 MB, con la misma aplicación.

### 2. Cuando hacen falta compiladores

Imagina que una dependencia necesita compilarse. En una sola etapa:

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
```

Y en dos etapas, con el Dockerfile de la teoría:

```bash
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

Medido: 647 MB con `gcc` dentro, frente a 221 MB sin compiladores. Si tus dependencias no necesitan compilarse, como estas, `slim` en una sola etapa ya es pequeña. El *multi-stage* brilla cuando la construcción necesita herramientas que no quieres en producción.

### 3. Sin privilegios

```bash
docker run --rm saludo:2 id
docker run --rm saludo:slim id
docker run --rm saludo:2 sh -c 'touch /app/prueba'
docker run -d --name s2 -p 8000:8000 saludo:2 && sleep 2 && curl -s localhost:8000/health ; echo
docker rm -f s2
```

🔮 **Predice:** ¿podrá el usuario `app` crear un archivo en `/app`? No (`Permission denied`): la carpeta es de root, y así debe ser. La aplicación funciona igual, porque solo necesita **leer** su código.

### 4. Un secreto horneado

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

El token del `ARG` y la contraseña del `ENV` aparecen en claro. Cualquiera que descargue la imagen puede leerlos, aunque nunca arranque un contenedor.

### 5. Escanear con `trivy`

```bash
docker pull aquasec/trivy:0.75.0
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --severity HIGH,CRITICAL saludo:2
```

La primera vez descarga la base de datos de vulnerabilidades (unos minutos); el volumen `trivy-cache` la guarda para las siguientes. Montar el socket le permite leer tus imágenes locales (y, recuerda la clase 56, le da poder de root: hazlo solo con herramientas de confianza y versión fijada).

Lee el informe: una tabla para el sistema (Debian) y otra para los paquetes de Python, con la severidad y la versión que lo corrige, si existe. Ahora, solo lo que tiene arreglo:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --quiet --severity HIGH,CRITICAL --ignore-unfixed saludo:2
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:0.75.0 image --quiet --severity HIGH,CRITICAL saludo:herramientas | grep Total
```

🔮 **Predice:** ¿cuál tendrá más vulnerabilidades, la imagen con compiladores o la de dos etapas? Medido en octubre de 2026: unas 100 frente a unas 50, casi todas del sistema base y sin arreglo todavía. Con `--ignore-unfixed` quedan solo unas pocas, en paquetes de Python que la imagen base trae dentro de `pip`. Tus números serán otros: la base de datos de vulnerabilidades cambia cada día.

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

1. Escanea `nginx:1.29` y `nginx:1.29-alpine` con `--severity HIGH,CRITICAL --ignore-unfixed` y compara el número de vulnerabilidades y el tamaño de cada una.
2. Pide a `trivy` el informe en JSON (`--format json`) y cuenta con `jq` las vulnerabilidades HIGH: `jq '[.Results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length'`.
3. Añade un `HEALTHCHECK` a tu Dockerfile de dos etapas (clase 58, Reto 1) y comprueba que funciona también con el usuario `app`.
4. Borra las imágenes de prueba de esta clase: `docker rmi saludo:completa saludo:herramientas saludo:slim`.

## Cierre

En `notas/fase-5/clase-59.md`:

1. ¿Cuándo reduce de verdad el tamaño una construcción en varias etapas? Pon el ejemplo de la clase.
2. ¿Por qué tu imagen debe correr con un usuario que no sea root? ¿Qué consecuencia tiene para la aplicación?
3. ¿Por qué no sirven `ENV` ni `ARG` para pasar secretos? ¿Cómo llegan entonces?
4. **Repaso (clase 58, sin mirar):** ¿por qué la forma shell de `CMD` hace que `docker stop` tarde 10 segundos?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Cuando construir necesita herramientas que ejecutar no necesita: compiladores, cabeceras, `git`… La primera etapa las tiene y la segunda copia solo el resultado (aquí, el entorno virtual). En la clase: 647 MB con `build-essential` en una sola etapa, frente a 221 MB en dos. Si las dependencias no necesitan compilarse, la diferencia es mínima, y lo que de verdad reduce es pasar de `python:3.14` a `python:3.14-slim` (1,66 GB → 218 MB).

**2.** Porque si alguien explota la aplicación y logra escapar del contenedor, será root en el host (el root del contenedor es el root del host). Con un usuario sin privilegios, el daño se limita a lo que ese usuario puede hacer. Consecuencia: la aplicación no puede escribir en carpetas de root como `/app`; lo que deba escribir va a una carpeta suya o a un volumen.

**3.** Porque quedan guardados en la imagen: `ENV` se ve con `docker inspect` y `ARG` en `docker history`, y la imagen se sube a registros y se comparte. Los secretos se pasan al **ejecutar**: variables de entorno o archivos de secretos de Compose, Secrets de Kubernetes, o un gestor como AWS Secrets Manager.

**4.** Porque el PID 1 es `/bin/sh -c "…"`, que no reenvía SIGTERM a la aplicación. Docker espera los 10 segundos de cortesía y la termina con SIGKILL.

**Reto 2:** el `?` después de `Vulnerabilities[]` evita un error en las secciones sin vulnerabilidades (en esas, la lista no existe).
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
