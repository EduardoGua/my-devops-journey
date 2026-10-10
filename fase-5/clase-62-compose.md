# Clase 62 — Docker Compose

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

## Objetivo

- Describir una aplicación de varios contenedores en un archivo `compose.yaml`: servicios, imágenes, puertos, variables, volúmenes y redes.
- Arrancarla, verla, seguir sus logs, entrar en ella y detenerla con `docker compose`.
- Hacer que un servicio espere a que otro esté **sano** con `healthcheck` y `depends_on`.
- Sacar los secretos del archivo con `.env` y dejar en Git solo un `.env.example`.
- Saber qué borra cada comando, y por qué `docker compose down -v` es peligroso.

## Por qué importa

Con `docker run` y diez opciones por contenedor no se puede mantener una aplicación de tres servicios. Compose la describe en un archivo legible y versionado: cualquiera la levanta con `docker compose up`, igual en tu portátil que en una EC2 (fase 6). Es el criterio de salida de esta fase para Vigía: *`docker compose up` levanta todo desde un clon limpio*. Y la idea (declarar lo que quieres en YAML y que una herramienta lo haga realidad) es la misma de Kubernetes (fase 9).

## Teoría

### Anatomía de un `compose.yaml`

```yaml
services:                          # cada servicio es un contenedor (o varios iguales)
  db:
    image: postgres:18             # una imagen de un registro…
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?falta POSTGRES_PASSWORD en .env}
    volumes:
      - datos:/var/lib/postgresql  # volumen con nombre (clase 60)
    healthcheck:                   # cómo saber si está sano
      test: ["CMD-SHELL", "pg_isready -U contador -d contador"]
      interval: 5s

  web:
    build: .                       # …o una imagen que construye con tu Dockerfile
    environment:
      DATABASE_URL: postgresql://contador:${POSTGRES_PASSWORD}@db:5432/contador
    ports:
      - "127.0.0.1:8000:8000"      # solo para tu máquina (clase 61)
    depends_on:
      db:
        condition: service_healthy # no arranques hasta que db esté sano
    restart: unless-stopped        # si se cae, levántalo

volumes:
  datos:                           # los volúmenes con nombre se declaran aquí
```

- Compose crea una **red** para el proyecto: los servicios se encuentran por su nombre (`db`).
- El proyecto se llama como la carpeta, y los contenedores, `carpeta-servicio-1`.
- Ya no hace falta la línea `version:` que verás en tutoriales antiguos.

### Variables y secretos con `.env`

Compose lee automáticamente un archivo `.env` junto al `compose.yaml` y sustituye cada `${VARIABLE}`. `${VAR:?mensaje}` hace que Compose se niegue a arrancar si falta. Así, el `compose.yaml` va a Git sin secretos; el `.env` real **no** (al `.gitignore`), y en su lugar se sube un `.env.example` con valores de mentira que explica qué variables hay que definir.

### `depends_on` no es "espera a que funcione"

Sin condición, `depends_on: [db]` solo garantiza que el contenedor de `db` **arranca** antes. PostgreSQL tarda unos segundos en aceptar conexiones, y una aplicación que conecta al arrancar falla en ese hueco (Rómpelo 2). Con `condition: service_healthy`, Compose espera a que el `healthcheck` de `db` dé verde. Y `restart: unless-stopped` es la red de seguridad para cuando la base de datos se cae más tarde.

### Los comandos

| Comando | Qué hace |
|---------|----------|
| `docker compose config` | valida el archivo y lo muestra con las variables sustituidas |
| `docker compose up -d --build` | construye lo que haga falta y arranca todo en segundo plano |
| `docker compose up -d --wait` | arranca y espera a que todo esté sano (`healthy`) |
| `docker compose ps` | los contenedores del proyecto, con su estado y su salud |
| `docker compose logs -f web` | los logs de un servicio (sin nombre: de todos) |
| `docker compose exec db psql …` | un comando dentro de un servicio en marcha |
| `docker compose restart web` | reinicia un servicio |
| `docker compose down` | para y **borra** los contenedores y la red. Los volúmenes **se quedan** |
| `docker compose down -v` | lo mismo y además **borra los volúmenes**: tus datos |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-62 && cd ~/my-devops-journey/labs/clase-62
```

### 1. La aplicación: un contador en PostgreSQL

```bash
cat > app.py <<'EOF'
"""app.py: cuenta las visitas en PostgreSQL."""
import os

import psycopg
from fastapi import FastAPI

URL = os.environ["DATABASE_URL"]

with psycopg.connect(URL) as con:          # al arrancar: si la base no responde, el proceso falla
    con.execute("CREATE TABLE IF NOT EXISTS visitas (id SERIAL PRIMARY KEY, momento TIMESTAMPTZ DEFAULT now())")

app = FastAPI(title="Contador")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/visitas")
def visitas():
    with psycopg.connect(URL) as con:
        con.execute("INSERT INTO visitas DEFAULT VALUES")
        total = con.execute("SELECT COUNT(*) FROM visitas").fetchone()[0]
    return {"visitas": total}
EOF
printf 'fastapi==0.143.0\nuvicorn==0.54.0\npsycopg[binary]==3.3.6\n' > requirements.txt
printf '.venv/\n__pycache__/\n.env\n' > .dockerignore
```

`psycopg` es la librería de Python para PostgreSQL. Funciona como `sqlite3` (clase 51), con dos diferencias: se conecta con una URL (`postgresql://usuario:contraseña@servidor:5432/base`) y los parámetros se escriben `%s` en lugar de `?`. `with psycopg.connect(…)` confirma los cambios y cierra la conexión al salir.

### 2. El Dockerfile (de la clase 59)

```bash
cat > Dockerfile <<'EOF'
FROM python:3.14-slim AS construccion
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

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
```

### 3. El `compose.yaml`

```bash
cat > compose.yaml <<'EOF'
services:
  db:
    image: postgres:18
    environment:
      POSTGRES_USER: contador
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?falta POSTGRES_PASSWORD en .env}
      POSTGRES_DB: contador
    volumes:
      - datos:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U contador -d contador"]
      interval: 5s
      timeout: 3s
      retries: 10

  web:
    build: .
    environment:
      DATABASE_URL: postgresql://contador:${POSTGRES_PASSWORD}@db:5432/contador
    ports:
      - "127.0.0.1:8000:8000"
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped

volumes:
  datos:
EOF
docker compose config -q
```

🔮 **Predice** qué dirá `docker compose config` antes de crear el `.env`. Se niega: `required variable POSTGRES_PASSWORD is missing a value: falta POSTGRES_PASSWORD en .env`. Mejor fallar aquí que arrancar una base de datos sin contraseña.

```bash
printf 'POSTGRES_PASSWORD=cambia-esta-contrasena\n' > .env.example
cp .env.example .env
nano .env                                # pon una contraseña tuya
docker compose config | grep -A2 DATABASE_URL
```

`config` muestra el archivo final con las variables sustituidas: la forma de comprobar que Compose ve lo que crees.

### 4. Arrancar y usar

```bash
docker compose up -d --build --wait
docker compose ps
for i in 1 2 3; do curl -s 127.0.0.1:8000/visitas; echo; done
docker compose logs --tail 5 web
docker compose exec db psql -U contador -d contador -c 'SELECT COUNT(*) FROM visitas;'
```

`--wait` vuelve cuando los dos servicios están `healthy`. Fíjate en el orden de arranque en la salida: primero `db`, que pasa a `Healthy`, y solo entonces `web`. En los logs de `web` verás, además de tus peticiones, las del `healthcheck` cada 5 segundos.

### 5. Qué sobrevive a qué

```bash
docker compose down
docker volume ls | grep datos
docker compose up -d --wait
curl -s 127.0.0.1:8000/visitas ; echo
```

🔮 **Predice** el número antes de ejecutar. Sale `{"visitas":4}`: `down` borró los contenedores y la red, pero no el volumen. Ahora, con `-v`:

```bash
docker compose down -v
docker compose up -d --wait
curl -s 127.0.0.1:8000/visitas ; echo
```

`{"visitas":1}`: la base de datos empezó de cero. `down -v` es el `rm -rf` de Compose: úsalo solo cuando quieras borrar los datos a propósito.

### 6. Un cambio de código

```bash
sed -i 's/title="Contador"/title="Contador de visitas"/' app.py
docker compose up -d --build --wait
docker compose ps
curl -s 127.0.0.1:8000/openapi.json | python3 -c 'import json, sys; print(json.load(sys.stdin)["info"]["title"])'
```

`up --build` reconstruye la imagen (con la caché de la clase 58) y recrea solo el servicio que cambió. La base de datos ni se entera.

## Rómpelo

**1. Un error de sangría:**
```bash
sed 's/^    image: postgres:18/  image: postgres:18/' compose.yaml > roto.yaml
docker compose -f roto.yaml config -q
rm roto.yaml
```
`yaml: line 4: mapping values are not allowed in this context`. YAML es estricto con la sangría (clase 47). `docker compose config` es tu primera comprobación tras cualquier cambio.

**2. `depends_on` sin esperar a que esté sano:**
```bash
docker compose down -v
sed -e '/condition: service_healthy/d' -e 's/^    depends_on:$/    depends_on: [db]/' -e '/^      db:$/d' \
    -e '/restart: unless-stopped/d' compose.yaml > impaciente.yaml
docker compose -f impaciente.yaml up -d
sleep 8 && docker compose -f impaciente.yaml ps -a
docker compose -f impaciente.yaml logs web | grep -i error | tail -2
docker compose -f impaciente.yaml down -v && rm impaciente.yaml
```
`web` aparece como `Exited (1)`, con `psycopg.OperationalError: … Connection refused` en su log. Arrancó en cuanto el contenedor de `db` existía, pero PostgreSQL aún no aceptaba conexiones, y sin `restart` nadie lo volvió a intentar. Con `condition: service_healthy` y `restart: unless-stopped` (como en tu `compose.yaml`) no pasa.

**3. El `.env` que se cuela en Git:**
```bash
git init -q /tmp/prueba-env && cp .env compose.yaml /tmp/prueba-env/ && cd /tmp/prueba-env
git add . && git status --short
printf '.env\n' > .gitignore && git rm -q --cached .env && git add .gitignore && git status --short
cd - && rm -rf /tmp/prueba-env
```
Sin `.gitignore`, `git add .` se lleva tu contraseña. Recuerda la clase 22: si llega a un commit publicado, ya no vale con borrarla, hay que cambiarla.

## Reto

1. Añade un tercer servicio, `adminer` (imagen `adminer:5`), publicado en `127.0.0.1:8081`, para ver la base de datos desde el navegador. Entra con servidor `db`, usuario `contador` y tu contraseña. ¿Por qué `db` funciona como nombre de servidor?
2. Mete `adminer` en un **perfil**: `profiles: ["debug"]`. Comprueba que `docker compose up -d` no lo arranca y que `docker compose --profile debug up -d` sí.
3. Simula la caída de la base de datos con `docker compose stop db`, pide `/visitas` y mira el código HTTP. Vuelve a arrancarla con `docker compose start db`. ¿Se recupera `web` sola?

## Cierre

En `notas/fase-5/clase-62.md`:

1. ¿Qué hace `condition: service_healthy` y qué pasaría sin ella en esta aplicación?
2. ¿Qué diferencia hay entre `docker compose down` y `docker compose down -v`?
3. ¿Cómo mantienes la contraseña de la base de datos fuera de Git y, aun así, explicas a otros qué variables necesitan?
4. **Repaso (clase 61, sin mirar):** dentro de un contenedor, ¿qué es `localhost`? ¿Cómo llega la web a la base de datos?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Hace que Compose no arranque `web` hasta que el `healthcheck` de `db` dé verde, es decir, hasta que PostgreSQL acepta conexiones. Sin ella, `web` arranca en cuanto existe el contenedor de `db`, intenta conectar mientras PostgreSQL aún se inicia, falla al crear la tabla y termina con error.

**2.** `down` para y borra los contenedores y la red del proyecto, pero conserva los volúmenes con nombre: al volver a levantarlo, los datos siguen ahí. `down -v` borra además los volúmenes, y con ellos la base de datos.

**3.** La contraseña va en un archivo `.env` (que Compose lee solo) incluido en el `.gitignore`, y el `compose.yaml` la usa como `${POSTGRES_PASSWORD}`. A Git se sube un `.env.example` con las mismas variables y valores de ejemplo, y `${VAR:?mensaje}` hace que Compose explique qué falta si alguien se lo salta.

**4.** El propio contenedor. La web llega a la base de datos por el nombre del servicio, `db`, que el DNS interno de la red del proyecto resuelve a su IP, y por su puerto interno, el 5432.

**Reto 1:** porque `adminer` y `db` están en la misma red del proyecto, y el DNS de Docker resuelve el nombre del servicio.

**Reto 3:** con la base de datos parada, `/visitas` da **500** (la conexión falla dentro de la petición). Al arrancar `db` de nuevo, `web` se recupera sola, porque abre una conexión nueva en cada petición, sin reiniciarse.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| service / project | servicio / proyecto |
| healthcheck / healthy | comprobación de salud / sano |
| restart policy | política de reinicio |
| environment file (.env) | archivo de variables |
| declarative configuration | configuración declarativa |

🎙️ *"With Compose, the whole stack is declared in one file: the app waits for the database's healthcheck, secrets come from an untracked .env file, and data lives in a named volume."*

## Siguiente

[Clase 63 — Depurar contenedores](clase-63-depurar.md)
