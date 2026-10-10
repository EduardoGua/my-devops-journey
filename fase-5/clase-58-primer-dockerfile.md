# Clase 58 — Tu primer Dockerfile: capas, caché y .dockerignore

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

## Objetivo

- Escribir un Dockerfile con `FROM`, `WORKDIR`, `COPY`, `RUN`, `ENV`, `EXPOSE` y `CMD`.
- Construir una imagen con `docker build` y ejecutarla.
- Entender las **capas** y la **caché**, y ordenar el Dockerfile para que reconstruir tarde segundos.
- Usar `.dockerignore` para no meter en la imagen lo que no debe ir.
- Saber por qué `CMD` va en forma de lista (*exec form*) y por qué una app en un contenedor debe escuchar en `0.0.0.0`.

## Por qué importa

Hasta ahora usabas imágenes de otros. Un Dockerfile es la receta de **tu** imagen: código, dependencias y la forma de arrancarlo, todo versionado en Git. Esa imagen es el artefacto que viajará por el pipeline de la fase 7 y se desplegará en AWS (fase 6) y en Kubernetes (fase 9). Un Dockerfile bien ordenado reconstruye en segundos; uno mal ordenado reinstala todas las dependencias por cambiar una línea de código.

## Teoría

### Las instrucciones básicas

```dockerfile
FROM python:3.14-slim               # imagen base: siempre con versión
WORKDIR /app                        # carpeta de trabajo (la crea si no existe)
COPY requirements.txt .             # copia del contexto de construcción a la imagen
RUN pip install --no-cache-dir -r requirements.txt   # ejecuta un comando AL CONSTRUIR
COPY app.py .
ENV APP_ENV=produccion              # variable de entorno por defecto
EXPOSE 8000                         # documenta el puerto (no lo publica)
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]   # qué ejecutar AL ARRANCAR
```

| Instrucción | Cuándo actúa |
|-------------|--------------|
| `RUN` | al **construir** la imagen; su resultado queda guardado en una capa |
| `CMD` / `ENTRYPOINT` | al **arrancar** cada contenedor |

`ENTRYPOINT` es el programa y `CMD`, sus argumentos por defecto: con `ENTRYPOINT ["python", "-m", "vigia"]` y `CMD ["serve"]`, `docker run imagen check` sustituye solo el `CMD`. Lo usarás en Vigía.

### Capas y caché

Cada instrucción crea una **capa**: los cambios que hizo, apilados sobre la anterior. Al reconstruir, Docker reutiliza (`CACHED`) cada capa cuya instrucción y archivos de entrada no cambiaron… **hasta la primera que cambia**: esa y todas las siguientes se rehacen.

```
FROM python:3.14-slim        ← casi nunca cambia
COPY requirements.txt .      ← cambia cuando añades una dependencia
RUN pip install …            ← lento (minutos): solo se rehace si cambió la de arriba
COPY app.py .                ← cambia en cada commit
```

Regla: **de lo que menos cambia a lo que más cambia**. Si copiaras todo el código antes del `pip install`, cada cambio de una línea reinstalaría todas las dependencias (Rómpelo 3).

### El contexto y `.dockerignore`

`docker build .` envía al constructor la carpeta `.` entera: el **contexto**. `COPY` solo puede copiar desde ahí. El archivo `.dockerignore` (misma sintaxis que `.gitignore`) excluye lo que no debe viajar: `.venv`, `.git`, bases de datos, `.env` con secretos…

### Forma *exec* frente a forma *shell*

```dockerfile
CMD ["uvicorn", "app:app"]          # exec: uvicorn es el PID 1 y recibe las señales
CMD uvicorn app:app                 # shell: el PID 1 es /bin/sh -c "uvicorn app:app"
```

En la forma shell, el PID 1 es un `sh` que **no reenvía** SIGTERM a tu aplicación. `docker stop` espera 10 segundos y la mata con SIGKILL, sin cierre ordenado (Rómpelo 1). Usa siempre la forma de lista.

### `0.0.0.0` dentro del contenedor

Dentro del contenedor, `127.0.0.1` es **el propio contenedor**. Una aplicación que escucha solo ahí no recibe nada de lo que Docker le reenvía desde `-p`, que llega por la interfaz de red del contenedor. Es la diferencia de la clase 29: dentro de un contenedor, la app escucha en `0.0.0.0`, y es `-p 127.0.0.1:8000:8000` en el host lo que decide quién puede llegar (clase 61).

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-58 && cd ~/my-devops-journey/labs/clase-58
```

### 1. La aplicación

Una API mínima con FastAPI (clase 53):

```bash
cat > app.py <<'EOF'
"""app.py: una API mínima para aprender Docker."""
import os
import socket

from fastapi import FastAPI

app = FastAPI(title="Saludo")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/info")
def info():
    return {"equipo": socket.gethostname(), "entorno": os.environ.get("APP_ENV", "desarrollo"),
            "version": os.environ.get("APP_VERSION", "dev")}
EOF
printf 'fastapi==0.143.0\nuvicorn==0.54.0\n' > requirements.txt
```

### 2. El Dockerfile

```bash
cat > Dockerfile <<'EOF'
FROM python:3.14-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
printf '.venv/\n__pycache__/\n*.db\n.env\n.git/\n' > .dockerignore
docker build -t saludo:1 .
docker images saludo
```

Lee la salida de `docker build`: cada paso numerado es una instrucción. `--no-cache-dir` evita que pip guarde su caché de descargas dentro de la imagen.

### 3. Ejecutarla

```bash
docker run -d --name saludo -p 8000:8000 saludo:1
sleep 2
curl -s localhost:8000/info ; echo
docker run --rm -e APP_ENV=produccion -e APP_VERSION=1.0 saludo:1 python -c 'import app, json; print(json.dumps(app.info()))'
```

🔮 **Predice** qué dirá `equipo` en `/info`: el ID del contenedor (clase 56). El segundo comando sustituye el `CMD` por otro: la misma imagen sirve para ejecutar otra cosa.

### 4. Las capas y la caché

```bash
docker history saludo:1
echo "# un cambio en el código" >> app.py
time docker build -t saludo:2 .
```

🔮 **Predice:** ¿se reinstalarán las dependencias? En la salida, el paso del `pip install` dice `CACHED`: cambió `app.py`, pero `requirements.txt` no, así que solo se rehace la última capa. `docker history` muestra el tamaño de cada capa: el `pip install` pesa unos 30 MB.

### 5. Ver qué hay dentro

```bash
docker exec saludo sh -c 'cat /proc/1/cmdline | tr "\0" " "; echo; whoami; ls -la /app'
docker rm -f saludo
```

El PID 1 es `uvicorn`, gracias a la forma exec. La imagen `slim` ni siquiera trae `ps`: por eso se lee `/proc/1/cmdline` (clase 11). Y fíjate en `whoami`: **root**. Lo arreglas en la clase 59.

## Rómpelo

**1. `CMD` en forma shell:**
```bash
sed 's|^CMD .*|CMD uvicorn app:app --host 0.0.0.0 --port 8000|' Dockerfile > Dockerfile.shell
docker build -q -t saludo:shell -f Dockerfile.shell .
docker run -d --name s-shell saludo:shell && sleep 2
docker exec s-shell sh -c 'cat /proc/1/cmdline | tr "\0" " "'; echo
time docker stop s-shell
docker rm s-shell
```
El PID 1 es `/bin/sh -c uvicorn…` y `docker stop` tarda **10 segundos**: el shell no reenvió SIGTERM y Docker acabó matando el contenedor con SIGKILL. Con la forma exec, `docker stop saludo` tarda menos de un segundo. En Kubernetes (fase 9) y en cada despliegue, esos 10 segundos por contenedor se notan, y la app muere sin cerrar conexiones.

**2. La app que escucha en `127.0.0.1`:**
```bash
sed 's|"--host", "0.0.0.0", ||' Dockerfile > Dockerfile.local
docker build -q -t saludo:local -f Dockerfile.local .
docker run -d --name s-local -p 8001:8000 saludo:local && sleep 2
curl -sS -m 3 localhost:8001/health ; echo
docker logs s-local 2>&1 | tail -1
docker rm -f s-local
```
`Connection reset by peer`, y el log dice `Uvicorn running on http://127.0.0.1:8000`. Docker reenvía el tráfico a la interfaz de red del contenedor, pero la app solo escucha en su `127.0.0.1`. Es el error más común al contenerizar una aplicación, y Vigía lo tendría (su `serve` escucha en `127.0.0.1` por defecto).

**3. El orden que rompe la caché:**
```bash
cat > Dockerfile.mal <<'EOF'
FROM python:3.14-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
docker build -q -t saludo:mal -f Dockerfile.mal .
echo "# otro cambio" >> app.py
time docker build -t saludo:mal -f Dockerfile.mal .
```
Ahora el `pip install` se repite entero por cambiar un comentario: `COPY . .` cambió, y todo lo de debajo se rehace. Además, `COPY . .` copió también `Dockerfile.shell`, `Dockerfile.local`… a la imagen.

**4. Sin `.dockerignore`:**
```bash
python3 -m venv .venv && .venv/bin/pip install -q fastapi uvicorn
du -sh .venv
mv .dockerignore dockerignore.bak
docker build -t saludo:mal -f Dockerfile.mal . 2>&1 | grep -i "transferring context"
docker run --rm saludo:mal du -sh /app/.venv
mv dockerignore.bak .dockerignore
```
El contexto de construcción pasa de unos KB a decenas de MB, y el `.venv` de tu máquina (que además no funcionaría dentro: sus rutas son las de tu Ubuntu, clase 46) acaba en la imagen. Con un `.env` pasaría lo mismo con tus secretos.

## Reto

1. Añade al Dockerfile una instrucción `HEALTHCHECK` que use Python para pedir `/health` (la imagen no trae `curl`): `HEALTHCHECK --interval=10s CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]`. Arranca el contenedor y mira la columna `STATUS` de `docker ps` hasta que diga `(healthy)`.
2. Añade `ARG APP_VERSION=dev` y `ENV APP_VERSION=$APP_VERSION`, y construye con `docker build --build-arg APP_VERSION=1.2.0 -t saludo:1.2.0 .`. Comprueba que `/info` muestra la versión.
3. Borra las imágenes de prueba (`saludo:shell`, `saludo:local`, `saludo:mal`) y mira con `docker system df` cuánto espacio recuperas.

## Cierre

En `notas/fase-5/clase-58.md`:

1. ¿Qué diferencia hay entre `RUN` y `CMD`?
2. ¿Por qué se copia `requirements.txt` y se hace el `pip install` **antes** de copiar el código?
3. Explica por qué la forma shell de `CMD` hace que `docker stop` tarde 10 segundos.
4. **Repaso (clase 57, sin mirar):** ¿por qué se perdió el `index.html` que cambiaste al recrear el contenedor de nginx?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `RUN` se ejecuta al **construir** la imagen, y su resultado (por ejemplo, las dependencias instaladas) queda guardado en una capa. `CMD` se ejecuta al **arrancar** cada contenedor: es el proceso principal.

**2.** Por la caché de capas: Docker reutiliza cada capa mientras su instrucción y sus archivos no cambien. `requirements.txt` cambia poco y el código cambia en cada commit; si el código va después, cambiarlo solo rehace la última capa y las dependencias salen de la caché. Al revés, cada cambio de código reinstalaría todas las dependencias.

**3.** Porque en la forma shell el PID 1 es `/bin/sh -c "…"`, que no reenvía las señales a la aplicación. `docker stop` envía SIGTERM al PID 1, el shell lo ignora, Docker espera los 10 segundos de cortesía y termina con SIGKILL: la aplicación muere sin cierre ordenado.

**4.** Porque el cambio vivía en la capa escribible de aquel contenedor, que se borró con él; el nuevo arrancó limpio desde la imagen.

**Reto 2:**
```dockerfile
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
```
`ARG` solo existe al construir; `ENV` lo convierte en una variable del contenedor. (Nunca pases secretos con `ARG`: quedan visibles en `docker history`, como verás en la clase 59.)
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| Dockerfile / build | receta / construir |
| layer / build cache | capa / caché de construcción |
| build context | contexto de construcción |
| exec form / shell form | forma de lista / forma de shell |
| graceful shutdown | parada ordenada |

🎙️ *"I order Dockerfile instructions from least to most frequently changed, copy the requirements before the code to keep the dependency layer cached, and always use the exec form so the app is PID 1 and receives SIGTERM."*

## Siguiente

[Clase 59 — Imágenes pequeñas y seguras](clase-59-imagenes-seguras.md)
