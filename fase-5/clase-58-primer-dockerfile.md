# Clase 58 — Tu primer Dockerfile: capas, caché y .dockerignore

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** un **Dockerfile** es la receta de **tu** imagen: de qué imagen partes, qué copias, qué instalas y qué se ejecuta al arrancar. Cada instrucción crea una **capa**, y al reconstruir Docker reutiliza las que no cambiaron: por eso el orden importa (de lo que menos cambia a lo que más). Y dos reglas para que la app se porte bien dentro de un contenedor: `CMD` en forma de lista y escuchar en `0.0.0.0`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `docker run -d -p -e`, `exec`, `logs` y `/proc/1/cmdline` para ver el proceso principal (clase 57).
> - FastAPI y `uvicorn --host --port` (clase 53); `requirements.txt` con versiones fijadas (clase 46).
> - SIGTERM, SIGKILL y el PID 1 (clase 11).
> - La diferencia entre escuchar en `127.0.0.1` y en `0.0.0.0` (clase 29); la sintaxis de `.gitignore` (clase 22).

> 🔤 **Palabras nuevas de hoy:**
> - **Dockerfile**: el archivo con las instrucciones para construir una imagen.
> - **capa** (*layer*): los cambios que hizo una instrucción, apilados sobre la anterior.
> - **caché de construcción**: las capas que Docker reutiliza porque no cambiaron (`CACHED`).
> - **contexto de construcción**: la carpeta que `docker build` envía al constructor; `COPY` solo copia desde ahí.
> - **`.dockerignore`**: la lista de lo que no viaja en el contexto.
> - **forma exec / forma shell**: `CMD ["programa", "arg"]` (el programa es el PID 1) frente a `CMD programa arg` (el PID 1 es un `sh`).

## Objetivo

- Escribir un Dockerfile con `FROM`, `WORKDIR`, `COPY`, `RUN`, `ENV`, `EXPOSE` y `CMD`.
- Construir una imagen con `docker build` y ejecutarla.
- Entender las **capas** y la **caché**, y ordenar el Dockerfile para que reconstruir tarde segundos.
- Usar `.dockerignore` para no meter en la imagen lo que no debe ir.
- Saber por qué `CMD` va en forma de lista (*exec form*) y por qué una app en un contenedor debe escuchar en `0.0.0.0`.

## Por qué importa

Hasta ahora usabas imágenes de otros. Un Dockerfile es la receta de **tu** imagen: código, dependencias y la forma de arrancarlo, todo versionado en Git. Esa imagen es el artefacto que viajará por el pipeline de la fase 7 y se desplegará en AWS (fase 6) y en Kubernetes (fase 9). Un Dockerfile bien ordenado reconstruye en segundos; uno mal ordenado reinstala todas las dependencias por cambiar una línea de código.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Todas usan la misma API mínima.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-58 && cd ~/my-devops-journey/labs/clase-58
```

## Las piezas

### Pieza 1 — Las instrucciones básicas y `docker build`

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

`docker build -t nombre:etiqueta .` construye la imagen con el Dockerfile de la carpeta actual. `--no-cache-dir` evita que pip guarde su caché de descargas dentro de la imagen.

**Pruébalo.** Primero, una API mínima con FastAPI (clase 53) y sus dependencias:

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

Y el Dockerfile:

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
docker build -t saludo:1 .
docker images saludo
```

👀 **Qué deberías ver:** la salida de `docker build` con un paso numerado por instrucción (`[1/5] FROM …`, `[2/5] WORKDIR /app`…); el `pip install` es el que más tarda. Al final, `naming to docker.io/library/saludo:1`, y en `docker images`, `saludo 1 … 218MB` más o menos: casi todo es la imagen base de Python.

✋ **Sin mirar:** ¿qué instrucción se ejecuta al construir la imagen y cuál cada vez que arranca un contenedor?

<details>
<summary>Comprueba</summary>

`RUN` al construir (su resultado queda en una capa); `CMD` al arrancar cada contenedor.
</details>

**En resumen:** `FROM` la base, `WORKDIR`, `COPY`, `RUN` para instalar y `CMD` para arrancar; `docker build -t nombre:etiqueta .` la construye.

### Pieza 2 — Ejecutar tu imagen, y `ENTRYPOINT` frente a `CMD`

`ENTRYPOINT` es el programa y `CMD`, sus argumentos por defecto: con `ENTRYPOINT ["python", "-m", "vigia"]` y `CMD ["serve"]`, `docker run imagen check` sustituye solo el `CMD`. Lo usarás en Vigía. Si una imagen solo tiene `CMD`, lo que escribas tras el nombre de la imagen en `docker run` lo sustituye entero.

🔮 **Predice** qué dirá `equipo` en `/info`.

**Pruébalo:**

```bash
docker run -d --name saludo -p 8000:8000 saludo:1
sleep 2
curl -s localhost:8000/info ; echo
docker run --rm -e APP_ENV=produccion -e APP_VERSION=1.0 saludo:1 python -c 'import app, json; print(json.dumps(app.info()))'
```

👀 **Qué deberías ver:** `{"equipo":"c36549322d62","entorno":"desarrollo","version":"dev"}`: el `equipo` es el ID del contenedor (clase 56). El segundo comando sustituye el `CMD` por otro: la misma imagen sirve para ejecutar otra cosa, y con `-e` cambian `entorno` y `version`. Deja `saludo` corriendo.

✋ **Sin mirar:** una imagen tiene `ENTRYPOINT ["python", "-m", "vigia"]` y `CMD ["serve"]`. ¿Qué ejecuta `docker run imagen check`?

<details>
<summary>Comprueba</summary>

`python -m vigia check`: lo que escribes tras la imagen sustituye al `CMD`, y el `ENTRYPOINT` se queda.
</details>

**En resumen:** tu imagen se usa como cualquier otra; el `CMD` se puede sustituir al arrancar y el `ENTRYPOINT`, no.

### Pieza 3 — Capas y caché

Cada instrucción crea una **capa**: los cambios que hizo, apilados sobre la anterior. Al reconstruir, Docker reutiliza (`CACHED`) cada capa cuya instrucción y archivos de entrada no cambiaron… **hasta la primera que cambia**: esa y todas las siguientes se rehacen.

```
FROM python:3.14-slim        ← casi nunca cambia
COPY requirements.txt .      ← cambia cuando añades una dependencia
RUN pip install …            ← lento (minutos): solo se rehace si cambió la de arriba
COPY app.py .                ← cambia en cada commit
```

Regla: **de lo que menos cambia a lo que más cambia**. Si copiaras todo el código antes del `pip install`, cada cambio de una línea reinstalaría todas las dependencias (Rómpelo 3).

🔮 **Predice:** si cambias solo `app.py`, ¿se reinstalarán las dependencias?

**Pruébalo:**

```bash
docker history saludo:1
echo "# un cambio en el código" >> app.py
time docker build -t saludo:2 .
```

👀 **Qué deberías ver:** `docker history` lista las capas de arriba abajo, con su tamaño: el `pip install` pesa unos 30 MB y los `COPY`, unos KB. En la reconstrucción, los pasos hasta el `pip install` dicen `CACHED`: cambió `app.py`, pero `requirements.txt` no, así que solo se rehace la última capa, en uno o dos segundos.

✋ **Sin mirar:** cambias `requirements.txt`. ¿Qué capas se rehacen?

<details>
<summary>Comprueba</summary>

El `COPY requirements.txt` y todas las de debajo: el `pip install` y el `COPY app.py`. Las de arriba (`FROM`, `WORKDIR`) salen de la caché.
</details>

**En resumen:** cada instrucción es una capa; la caché vale hasta la primera que cambia; ordena de lo que menos cambia a lo que más.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-58` y, si paraste el contenedor, `docker start saludo`.

### Pieza 4 — El contexto y `.dockerignore`

`docker build .` envía al constructor la carpeta `.` entera: el **contexto**. `COPY` solo puede copiar desde ahí. El archivo `.dockerignore` (misma sintaxis que `.gitignore`) excluye lo que no debe viajar: `.venv`, `.git`, bases de datos, `.env` con secretos…

**Pruébalo:**

```bash
printf '.venv/\n__pycache__/\n*.db\n.env\n.git/\n' > .dockerignore
cat .dockerignore
docker build -t saludo:2 . 2>&1 | grep -i "transferring context"
```

👀 **Qué deberías ver:** las cinco líneas del archivo y algo como `transferring context: 1.20kB`: solo viajan `Dockerfile`, `app.py`, `requirements.txt` y el propio `.dockerignore`. En el Rómpelo 4 verás qué pasa sin él cuando hay un `.venv` en la carpeta.

✋ **Sin mirar:** ¿por qué no conviene que un `.env` con contraseñas viaje en el contexto?

<details>
<summary>Comprueba</summary>

Porque un `COPY . .` lo metería dentro de la imagen, y cualquiera que tenga la imagen podría leerlo.
</details>

**En resumen:** el contexto es lo que `docker build` envía; `.dockerignore` deja fuera `.venv`, `.git`, bases de datos y secretos.

### Pieza 5 — Forma exec y `0.0.0.0` dentro del contenedor

```dockerfile
CMD ["uvicorn", "app:app"]          # exec: uvicorn es el PID 1 y recibe las señales
CMD uvicorn app:app                 # shell: el PID 1 es /bin/sh -c "uvicorn app:app"
```

En la forma shell, el PID 1 es un `sh` que **no reenvía** SIGTERM a tu aplicación. `docker stop` espera 10 segundos y la mata con SIGKILL, sin cierre ordenado (Rómpelo 1). Usa siempre la forma de lista.

Y dentro del contenedor, `127.0.0.1` es **el propio contenedor**. Una aplicación que escucha solo ahí no recibe nada de lo que Docker le reenvía desde `-p`, que llega por la interfaz de red del contenedor. Es la diferencia de la clase 29: dentro de un contenedor, la app escucha en `0.0.0.0`, y es `-p 127.0.0.1:8000:8000` en el host lo que decide quién puede llegar (clase 61). Lo verás en el Rómpelo 2.

**Pruébalo:**

```bash
docker exec saludo sh -c 'cat /proc/1/cmdline | tr "\0" " "; echo; whoami; ls -la /app'
time docker stop saludo
docker rm saludo
```

👀 **Qué deberías ver:** el PID 1 es `/usr/local/bin/python3.14 /usr/local/bin/uvicorn app:app --host 0.0.0.0 --port 8000`: uvicorn directamente, gracias a la forma exec. `whoami` dice **root** (lo arreglas en la clase 59), y en `/app` están `app.py`, `requirements.txt` y el `__pycache__` que creó Python al arrancar. `docker stop` tarda menos de un segundo: uvicorn recibió SIGTERM y cerró ordenadamente.

✋ **Sin mirar:** ¿en qué dirección debe escuchar una aplicación dentro de un contenedor para que le llegue el tráfico de `-p`?

<details>
<summary>Comprueba</summary>

En `0.0.0.0`. En `127.0.0.1` solo la alcanzaría el propio contenedor.
</details>

**En resumen:** `CMD` en forma de lista para que la app sea el PID 1 y reciba SIGTERM; dentro del contenedor, escuchar en `0.0.0.0`.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `FROM imagen:version` | la base, siempre con versión |
| `WORKDIR /app` · `COPY origen destino` | carpeta de trabajo · copiar del contexto |
| `RUN comando` | ejecutar al construir (crea una capa) |
| `ENV CLAVE=valor` · `EXPOSE 8000` | variable por defecto · documentar el puerto |
| `CMD ["programa", "arg"]` · `ENTRYPOINT [...]` | qué ejecutar al arrancar, en forma exec |
| `docker build -t nombre:etiqueta [-f otro.Dockerfile] .` | construir |
| `docker history imagen` | las capas y su tamaño |
| `.dockerignore` | lo que no viaja en el contexto |
| `--host 0.0.0.0` | escuchar en todas las interfaces del contenedor |

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
El PID 1 es `/bin/sh -c uvicorn…` y `docker stop` tarda **10 segundos**: el shell no reenvió SIGTERM y Docker acabó matando el contenedor con SIGKILL. Con la forma exec, `docker stop saludo` tardó menos de un segundo. En Kubernetes (fase 9) y en cada despliegue, esos 10 segundos por contenedor se notan, y la app muere sin cerrar conexiones.

**2. La app que escucha en `127.0.0.1`:**
```bash
sed 's|"--host", "0.0.0.0", ||' Dockerfile > Dockerfile.local
docker build -q -t saludo:local -f Dockerfile.local .
docker run -d --name s-local -p 8001:8000 saludo:local && sleep 2
curl -sS -m 3 localhost:8001/health ; echo
docker logs s-local 2>&1 | tail -1
docker rm -f s-local
```
`curl: (56) Recv failure: Conexión reinicializada por la máquina remota` (*connection reset by peer*), y el log dice `Uvicorn running on http://127.0.0.1:8000`. Docker reenvía el tráfico a la interfaz de red del contenedor, pero la app solo escucha en su `127.0.0.1`. Es el error más común al contenerizar una aplicación, y Vigía lo tendría (su `serve` escucha en `127.0.0.1` por defecto).

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

En `labs/clase-58/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade al Dockerfile una instrucción `HEALTHCHECK` que pida `/health` cada 10 segundos, y mira la columna `STATUS` de `docker ps` hasta que diga `(healthy)`.

> 🧩 **Ejemplo resuelto:** el `CMD ["uvicorn", "app:app", …]` de la pieza 1: `HEALTHCHECK … CMD [...]` usa la misma forma de lista.

**Ahora tú, con huecos** (añádelo antes del `CMD`):
```dockerfile
HEALTHCHECK --interval=____ CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:____/health', timeout=2)"]
```
Después: `docker build -t saludo:hc .`, `docker run -d --name hc saludo:hc` y `docker ps` varias veces.

<details>
<summary>Pista</summary>

La imagen `slim` no trae `curl`; por eso se usa Python. El chequeo corre **dentro** del contenedor, y ahí `127.0.0.1` es el propio contenedor: llega a la app. Si `urlopen` falla, Python sale con código distinto de 0 y Docker lo cuenta como fallo.
</details>

**2.** Haz que la versión de la imagen llegue a `/info` al construir: `docker build --build-arg APP_VERSION=1.2.0 -t saludo:1.2.0 .`.

> 🧩 **Ejemplo resuelto:** `ENV APP_ENV=produccion` de la pieza 1 deja una variable fija en la imagen; `-e APP_VERSION=1.0` de la pieza 2 la cambia al arrancar.

**Ahora tú, con huecos** (dos líneas después del `FROM`):
```dockerfile
ARG APP_VERSION=____
ENV APP_VERSION=$____
```
Comprueba: `docker run --rm saludo:1.2.0 python -c 'import app; print(app.info()["____"])'`.

<details>
<summary>Pista</summary>

`ARG` solo existe mientras se construye; `ENV` copia su valor en una variable que tendrá cada contenedor. (Nunca pases secretos con `ARG`: quedan visibles en `docker history`, como verás en la clase 59.)
</details>

**3.** Borra las imágenes de prueba (`saludo:shell`, `saludo:local`, `saludo:mal`) y mira con `docker system df` cuánto espacio recuperas.

> 🧩 **Ejemplo resuelto:** `docker system df` y `docker image prune` de la clase 57, pieza 5.

**Ahora tú, con huecos:**
```bash
docker system df
docker rmi saludo:____ saludo:____ saludo:____
docker system df
```
Completa: «Las imágenes pasaron de ____ a ____».

<details>
<summary>Pista</summary>

Las imágenes comparten capas (todas parten de `python:3.14-slim`), así que recuperas mucho menos que la suma de los tamaños que muestra `docker images`.
</details>

## Cierre

En `notas/fase-5/clase-58.md`:

1. ¿Qué diferencia hay entre `RUN` y `CMD`? *(2 líneas. Empieza así: «`RUN` se ejecuta al construir la imagen y su resultado… `CMD` se ejecuta…»)*
2. ¿Por qué se copia `requirements.txt` y se hace el `pip install` **antes** de copiar el código? *(2 líneas. Empieza así: «Por la caché de capas: Docker reutiliza cada capa mientras… El código cambia en cada commit, así que…»)*
3. Explica por qué la forma shell de `CMD` hace que `docker stop` tarde 10 segundos. *(2 líneas. Empieza así: «Porque en la forma shell el PID 1 es `/bin/sh -c`, que no reenvía… Docker espera 10 segundos y…»)*
4. **Repaso (clase 57, sin mirar):** ¿por qué se perdió el `index.html` que cambiaste al recrear el contenedor de nginx? *(1–2 líneas. Empieza así: «Porque el cambio vivía en la capa escribible de…»)*

Después, escríbeme `examíname clase-58`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `RUN` se ejecuta al **construir** la imagen, y su resultado (por ejemplo, las dependencias instaladas) queda guardado en una capa. `CMD` se ejecuta al **arrancar** cada contenedor: es el proceso principal.

**2.** Por la caché de capas: Docker reutiliza cada capa mientras su instrucción y sus archivos no cambien. `requirements.txt` cambia poco y el código cambia en cada commit; si el código va después, cambiarlo solo rehace la última capa y las dependencias salen de la caché. Al revés, cada cambio de código reinstalaría todas las dependencias.

**3.** Porque en la forma shell el PID 1 es `/bin/sh -c "…"`, que no reenvía las señales a la aplicación. `docker stop` envía SIGTERM al PID 1, el shell lo ignora, Docker espera los 10 segundos de cortesía y termina con SIGKILL: la aplicación muere sin cierre ordenado.

**4.** Porque el cambio vivía en la capa escribible de aquel contenedor, que se borró con él; el nuevo arrancó limpio desde la imagen.

**Reto 1:** `--interval=10s` y el puerto `8000`. A los 10–20 segundos, `docker ps` pasa de `(health: starting)` a `(healthy)`.

**Reto 2:** `ARG APP_VERSION=dev`, `ENV APP_VERSION=$APP_VERSION` y `info()["version"]`, que imprime `1.2.0`.

**Reto 3:** `docker rmi saludo:shell saludo:local saludo:mal`. Lo que recuperes depende de tu caso, pero será poco: comparten casi todas las capas con `saludo:1`.
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
