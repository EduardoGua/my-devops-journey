# Clase 62 — Docker Compose

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** con `docker run` y diez opciones por contenedor no se puede mantener una aplicación de tres servicios. **Compose** la describe en un archivo, `compose.yaml`: qué servicios hay, de qué imagen salen, con qué variables, volúmenes y puertos, y en qué orden arrancan. `docker compose up` la levanta entera; `docker compose down` la quita (y `down -v`, también sus datos).

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - YAML y su sangría estricta (clase 47); `${VAR:?mensaje}` para exigir una variable (clase 19).
> - `sqlite3` con parámetros (clase 51): `psycopg` se usa casi igual.
> - El Dockerfile en dos etapas con el usuario 10001 (clase 59) y el `HEALTHCHECK` (clase 58, reto 1).
> - Los volúmenes con nombre y la ruta de `postgres:18` (clase 60); las redes con DNS interno y `-p 127.0.0.1:…` (clase 61).
> - `.gitignore` y que un secreto en un commit publicado ya no se puede retirar (clase 22).

> 🔤 **Palabras nuevas de hoy:**
> - **servicio**: cada contenedor (o grupo de contenedores iguales) que describe el `compose.yaml`.
> - **proyecto**: el conjunto de servicios de un `compose.yaml`; se llama como su carpeta.
> - ***healthcheck*** / ***healthy***: la comprobación de que un servicio funciona / el estado "sano".
> - **`depends_on` con `condition: service_healthy`**: no arrancar un servicio hasta que otro esté sano.
> - **política de reinicio** (*restart policy*): qué hace Docker si el proceso se cae.
> - **`.env` / `.env.example`**: el archivo con los valores reales de las variables (fuera de Git) / la plantilla con valores de mentira (en Git).

## Objetivo

- Describir una aplicación de varios contenedores en un archivo `compose.yaml`: servicios, imágenes, puertos, variables, volúmenes y redes.
- Arrancarla, verla, seguir sus logs, entrar en ella y detenerla con `docker compose`.
- Hacer que un servicio espere a que otro esté **sano** con `healthcheck` y `depends_on`.
- Sacar los secretos del archivo con `.env` y dejar en Git solo un `.env.example`.
- Saber qué borra cada comando, y por qué `docker compose down -v` es peligroso.

## Por qué importa

Con `docker run` y diez opciones por contenedor no se puede mantener una aplicación de tres servicios. Compose la describe en un archivo legible y versionado: cualquiera la levanta con `docker compose up`, igual en tu portátil que en una EC2 (fase 6). Es el criterio de salida de esta fase para Vigía: *`docker compose up` levanta todo desde un clon limpio*. Y la idea (declarar lo que quieres en YAML y que una herramienta lo haga realidad) es la misma de Kubernetes (fase 9).

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Todas usan la misma aplicación: un contador de visitas en PostgreSQL.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min, todo preparado pero sin arrancar); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-62 && cd ~/my-devops-journey/labs/clase-62
```

## Las piezas

### Pieza 1 — La aplicación: un contador en PostgreSQL

`psycopg` es la librería de Python para PostgreSQL. Funciona como `sqlite3` (clase 51), con dos diferencias: se conecta con una URL (`postgresql://usuario:contraseña@servidor:5432/base`) y los parámetros se escriben `%s` en lugar de `?`. `with psycopg.connect(…)` confirma los cambios y cierra la conexión al salir.

**Pruébalo.** La aplicación, sus dependencias y el Dockerfile de dos etapas de la clase 59 (sin compiladores, que aquí no hacen falta):

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
ls -A
```

👀 **Qué deberías ver:** `.dockerignore  app.py  Dockerfile  requirements.txt`. Todavía no se puede arrancar: la aplicación necesita una `DATABASE_URL` y una base de datos detrás. Para eso está Compose.

✋ **Sin mirar:** ¿cómo se escribe un parámetro en una consulta de `psycopg`, y cómo en `sqlite3`?

<details>
<summary>Comprueba</summary>

`%s` en `psycopg` y `?` en `sqlite3`. En los dos, el valor va aparte, nunca dentro del texto de la consulta.
</details>

**En resumen:** `psycopg.connect(URL)` es el `sqlite3.connect` de PostgreSQL, con una URL y `%s`.

### Pieza 2 — Anatomía de un `compose.yaml`

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
- `docker compose config` valida el archivo y lo muestra con las variables sustituidas; con `-q`, solo valida.

🔮 **Predice** qué dirá `docker compose config -q` antes de que exista el `.env`.

**Pruébalo:**

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

👀 **Qué deberías ver:** Compose se niega: `required variable POSTGRES_PASSWORD is missing a value: falta POSTGRES_PASSWORD en .env`. Mejor fallar aquí que arrancar una base de datos sin contraseña.

✋ **Sin mirar:** en este `compose.yaml`, ¿con qué nombre encuentra `web` a la base de datos, y por qué?

<details>
<summary>Comprueba</summary>

Con `db`, el nombre del servicio: Compose crea una red propia para el proyecto, con el DNS interno de Docker (clase 61).
</details>

**En resumen:** `services:` con su `image` o `build`, `environment`, `volumes`, `ports`, `healthcheck` y `depends_on`; `volumes:` declara los volúmenes con nombre.

### Pieza 3 — Variables y secretos con `.env`

Compose lee automáticamente un archivo `.env` junto al `compose.yaml` y sustituye cada `${VARIABLE}`. `${VAR:?mensaje}` hace que Compose se niegue a arrancar si falta. Así, el `compose.yaml` va a Git sin secretos; el `.env` real **no** (al `.gitignore`), y en su lugar se sube un `.env.example` con valores de mentira que explica qué variables hay que definir.

**Pruébalo:**

```bash
printf 'POSTGRES_PASSWORD=cambia-esta-contrasena\n' > .env.example
cp .env.example .env
nano .env                                # pon una contraseña tuya
docker compose config | grep -A2 DATABASE_URL
```

👀 **Qué deberías ver:** `DATABASE_URL: postgresql://contador:<tu contraseña>@db:5432/contador`. `config` muestra el archivo final con las variables sustituidas: la forma de comprobar que Compose ve lo que crees.

✋ **Sin mirar:** ¿qué archivo sube a Git y cuál no: `.env` o `.env.example`?

<details>
<summary>Comprueba</summary>

`.env.example` (valores de mentira, explica qué variables hacen falta) sí; `.env` (los valores reales) no: va al `.gitignore`.
</details>

**En resumen:** los valores reales en `.env`, fuera de Git; la plantilla en `.env.example`; `${VAR:?}` para exigirlos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-62`.

### Pieza 4 — Arrancar, y por qué esperar a que `db` esté sana

Sin condición, `depends_on: [db]` solo garantiza que el contenedor de `db` **arranca** antes. PostgreSQL tarda unos segundos en aceptar conexiones, y una aplicación que conecta al arrancar falla en ese hueco (Rómpelo 2). Con `condition: service_healthy`, Compose espera a que el `healthcheck` de `db` dé verde. Y `restart: unless-stopped` es la red de seguridad para cuando la base de datos se cae más tarde.

| Comando | Qué hace |
|---------|----------|
| `docker compose up -d --build` | construye lo que haga falta y arranca todo en segundo plano |
| `docker compose up -d --wait` | arranca y espera a que todo esté sano (`healthy`) |
| `docker compose ps` | los contenedores del proyecto, con su estado y su salud |
| `docker compose logs -f web` | los logs de un servicio (sin nombre: de todos) |
| `docker compose exec db psql …` | un comando dentro de un servicio en marcha |
| `docker compose restart web` | reinicia un servicio |

**Pruébalo:**

```bash
docker compose up -d --build --wait
docker compose ps
for i in 1 2 3; do curl -s 127.0.0.1:8000/visitas; echo; done
docker compose logs --tail 5 web
docker compose exec db psql -U contador -d contador -c 'SELECT COUNT(*) FROM visitas;'
```

👀 **Qué deberías ver:** el orden de arranque en la salida de `up`: primero `db`, que pasa a `Healthy`, y solo entonces `web`; `--wait` vuelve cuando los dos están `healthy`. En `ps`, `clase-62-db-1` y `clase-62-web-1`, los dos `Up … (healthy)`. Después, `{"visitas":1}`, `{"visitas":2}` y `{"visitas":3}`. En los logs de `web` verás, además de tus peticiones, las del `healthcheck` cada 5 segundos. Y `psql` cuenta las mismas 3 filas.

✋ **Sin mirar:** sin `condition: service_healthy`, ¿qué garantiza `depends_on: [db]`?

<details>
<summary>Comprueba</summary>

Solo que el contenedor de `db` arranca antes que el de `web`, no que PostgreSQL acepte ya conexiones.
</details>

**En resumen:** `healthcheck` en `db` + `condition: service_healthy` en `web` = arrancar en el orden correcto; `up -d --build --wait` lo levanta todo.

### Pieza 5 — Qué sobrevive a qué: `down` y `down -v`

| Comando | Qué hace |
|---------|----------|
| `docker compose down` | para y **borra** los contenedores y la red. Los volúmenes **se quedan** |
| `docker compose down -v` | lo mismo y además **borra los volúmenes**: tus datos |

🔮 **Predice** el número de visitas después de `down` y `up`.

**Pruébalo:**

```bash
docker compose down
docker volume ls | grep datos
docker compose up -d --wait
curl -s 127.0.0.1:8000/visitas ; echo
docker compose down -v
docker compose up -d --wait
curl -s 127.0.0.1:8000/visitas ; echo
```

👀 **Qué deberías ver:** tras `down`, el volumen `clase-62_datos` sigue en la lista, y la siguiente visita es `{"visitas":4}`: `down` borró los contenedores y la red, pero no el volumen. Tras `down -v`, `{"visitas":1}`: la base de datos empezó de cero. `down -v` es el `rm -rf` de Compose: úsalo solo cuando quieras borrar los datos a propósito.

✋ **Sin mirar:** quieres apagar todo esta noche y seguir mañana con los mismos datos. ¿`down` o `down -v`?

<details>
<summary>Comprueba</summary>

`down`: conserva los volúmenes con nombre. `down -v` borraría la base de datos.
</details>

**En resumen:** `down` conserva los datos; `down -v` los borra.

### Pieza 6 — Un cambio de código

`up --build` reconstruye la imagen (con la caché de la clase 58) y recrea solo los servicios cuya configuración o imagen cambió.

**Pruébalo:**

```bash
sed -i 's/title="Contador"/title="Contador de visitas"/' app.py
docker compose up -d --build --wait
docker compose ps
curl -s 127.0.0.1:8000/openapi.json | python3 -c 'import json, sys; print(json.load(sys.stdin)["info"]["title"])'
```

👀 **Qué deberías ver:** en la salida de `up`, `db` aparece como `Running` (ni se entera) y `web` como `Recreated`/`Started`; en `ps`, `web` con un `Up` de unos segundos y `db` con el de antes; y `Contador de visitas`.

✋ **Sin mirar:** cambias `app.py` y haces `up -d --build`. ¿Se reinicia la base de datos?

<details>
<summary>Comprueba</summary>

No: solo se recrea `web`, cuya imagen cambió. `db` sigue como estaba.
</details>

**En resumen:** cambias el código, `up -d --build`, y solo se recrea lo que cambió.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker compose config [-q]` | validar y ver el archivo con las variables sustituidas |
| `docker compose up -d --build --wait` | construir, arrancar y esperar a que todo esté sano |
| `docker compose ps` · `logs -f web` · `exec db psql …` | estado · logs · un comando dentro |
| `docker compose restart web` · `stop db` · `start db` | reiniciar, parar y arrancar un servicio |
| `docker compose down` | borrar contenedores y red, **conservando** los volúmenes |
| `docker compose down -v` | borrar también los volúmenes (los datos) |
| `${VAR:?mensaje}` en el `compose.yaml` | exigir una variable del `.env` |
| `depends_on: {db: {condition: service_healthy}}` | esperar a que otro servicio esté sano |
| `restart: unless-stopped` | levantarlo si se cae |

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

En `labs/clase-62/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade un tercer servicio, `adminer` (imagen `adminer:5`), publicado en `127.0.0.1:8081`, para ver la base de datos desde el navegador. ¿Por qué `db` funciona como nombre de servidor?

> 🧩 **Ejemplo resuelto:** el servicio `web`: su `ports: ["127.0.0.1:8000:8000"]` publica su puerto 8000 solo para tu máquina.

**Ahora tú, con huecos** (dentro de `services:`, al mismo nivel que `db` y `web`):
```yaml
  adminer:
    image: adminer:____
    ports:
      - "127.0.0.1:____:8080"
    depends_on: [db]
```
Después, `docker compose up -d` y abre `http://127.0.0.1:8081`: sistema PostgreSQL, servidor ____, usuario ____ y tu contraseña.

<details>
<summary>Pista</summary>

Adminer escucha en el 8080 dentro de su contenedor; tú lo publicas en el 8081 de tu máquina. Para el servidor, piensa en cómo encuentra `web` a la base de datos.
</details>

**2.** Mete `adminer` en un **perfil**, para que solo arranque cuando lo pidas.

> 🧩 **Ejemplo resuelto:** `docker compose up -d` arranca todos los servicios del archivo que **no** tienen perfil.

**Ahora tú, con huecos:** añade a `adminer` la línea `profiles: ["____"]`, y comprueba:
```bash
docker compose down && docker compose up -d && docker compose ps --services
docker compose --profile ____ up -d && docker compose ps --services
```

<details>
<summary>Pista</summary>

Un servicio con `profiles` solo arranca si activas uno de sus perfiles con `--profile`. Llámalo `debug`.
</details>

**3.** Simula la caída de la base de datos, pide `/visitas` y mira el código HTTP. Vuelve a arrancarla. ¿Se recupera `web` sola?

> 🧩 **Ejemplo resuelto:** la tabla de comandos de la pieza 4: `docker compose restart web` reinicia un servicio.

**Ahora tú, con huecos:**
```bash
docker compose ____ db
curl -s -o /dev/null -w "%{http_code}\n" 127.0.0.1:8000/visitas
docker compose ____ db && sleep 5
curl -s 127.0.0.1:8000/visitas ; echo
```
Completa: «Con la base parada, `/visitas` da ____. Al arrancarla, `web` ____, porque abre una conexión nueva en…».

<details>
<summary>Pista</summary>

`stop` para un servicio sin borrarlo y `start` lo vuelve a arrancar. Mira la función `visitas` de `app.py`: ¿cuándo se conecta?
</details>

## Cierre

En `notas/fase-5/clase-62.md`:

1. ¿Qué hace `condition: service_healthy` y qué pasaría sin ella en esta aplicación? *(2 líneas. Empieza así: «Hace que Compose no arranque `web` hasta que… Sin ella, `web` arranca en cuanto…, intenta conectar y…»)*
2. ¿Qué diferencia hay entre `docker compose down` y `docker compose down -v`? *(2 líneas. Empieza así: «`down` para y borra los contenedores y la red, pero conserva… `down -v` borra además…»)*
3. ¿Cómo mantienes la contraseña de la base de datos fuera de Git y, aun así, explicas a otros qué variables necesitan? *(2 líneas. Empieza así: «La contraseña va en un `.env` incluido en el `.gitignore`… A Git subo un `.env.example` con…»)*
4. **Repaso (clase 61, sin mirar):** dentro de un contenedor, ¿qué es `localhost`? ¿Cómo llega la web a la base de datos? *(1–2 líneas. Empieza así: «`localhost` es el propio contenedor. La web llega por el nombre del servicio…»)*

Después, escríbeme `examíname clase-62`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Hace que Compose no arranque `web` hasta que el `healthcheck` de `db` dé verde, es decir, hasta que PostgreSQL acepta conexiones. Sin ella, `web` arranca en cuanto existe el contenedor de `db`, intenta conectar mientras PostgreSQL aún se inicia, falla al crear la tabla y termina con error.

**2.** `down` para y borra los contenedores y la red del proyecto, pero conserva los volúmenes con nombre: al volver a levantarlo, los datos siguen ahí. `down -v` borra además los volúmenes, y con ellos la base de datos.

**3.** La contraseña va en un archivo `.env` (que Compose lee solo) incluido en el `.gitignore`, y el `compose.yaml` la usa como `${POSTGRES_PASSWORD}`. A Git se sube un `.env.example` con las mismas variables y valores de ejemplo, y `${VAR:?mensaje}` hace que Compose explique qué falta si alguien se lo salta.

**4.** El propio contenedor. La web llega a la base de datos por el nombre del servicio, `db`, que el DNS interno de la red del proyecto resuelve a su IP, y por su puerto interno, el 5432.

**Reto 1:** `adminer:5`, el puerto `8081`, servidor `db` y usuario `contador`. `db` funciona porque `adminer` y `db` están en la misma red del proyecto, y el DNS de Docker resuelve el nombre del servicio.

**Reto 2:** `profiles: ["debug"]` y `--profile debug`. Sin el perfil, `ps --services` muestra solo `db` y `web`; con él, también `adminer`.

**Reto 3:** `stop` y `start`. Con la base de datos parada, `/visitas` da **500** (la conexión falla dentro de la petición). Al arrancar `db` de nuevo, `web` se recupera sola, porque abre una conexión nueva en cada petición, sin reiniciarse.
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
