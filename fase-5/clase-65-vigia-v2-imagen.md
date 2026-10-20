# Clase 65 — Proyecto: Vigía v2 (I): PostgreSQL y el Dockerfile

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** B. Proyecto · **Proyecto de portafolio**

> 💡 **La idea de hoy:** Vigía se prepara para vivir en contenedores. En la v1, `check` y `serve` compartían un archivo SQLite; en contenedores serán dos procesos separados, así que la base de datos pasa a ser **PostgreSQL**, un servidor al que los dos se conectan por la red, y su dirección llega por la variable **`DATABASE_URL`**. Además, el chequeo aprende a repetirse cada N segundos y a pararse limpio cuando recibe SIGTERM, y Vigía estrena su Dockerfile de dos etapas sin root.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Tus `storage.py` y `cli.py`, y las 26 pruebas de aceptación de la v1 (clases 54 y 55).
> - `psycopg`, sus parámetros `%s` y PostgreSQL en un contenedor (clases 60 y 62).
> - La configuración por variables de entorno (clase 50); SIGTERM y `trap` (clases 11 y 19).
> - El Dockerfile en dos etapas con el usuario 10001 y `ENTRYPOINT` + `CMD` en forma exec (clases 58 y 59).
> - Las redes de Docker y `-p 127.0.0.1:…` (clase 61).

> 🔤 **Palabras nuevas de hoy:**
> - **`DATABASE_URL`**: la variable con la dirección de la base de datos, como `postgresql://usuario:contraseña@servidor:5432/base`.
> - **manejador de señal**: la función que Python ejecuta al recibir una señal, registrada con `signal.signal(signal.SIGTERM, función)`.
> - **parada limpia** (*graceful shutdown*): terminar lo que se está haciendo y salir al recibir SIGTERM, sin esperar a SIGKILL.
> - **almacén**: en Vigía, el objeto que guarda y lee los resultados, sea SQLite o PostgreSQL.

## Objetivo

Preparar Vigía para vivir en contenedores: que pueda guardar sus resultados en **PostgreSQL** además de en SQLite, que lea la base de datos de la variable `DATABASE_URL`, que el chequeo pueda repetirse solo y pararse limpiamente, y que tenga un Dockerfile de dos etapas que corra sin root. En la clase 66 lo juntarás todo con Docker Compose.

Es la primera mitad de la versión que pide la Ruta 2.0 para esta fase: *Dockerfile con usuario no root y docker compose con la API, el chequeo y una base de datos*.

## Por qué PostgreSQL

En la v1, `check` y `serve` compartían un archivo SQLite en tu disco. En contenedores, la API y el chequeo serán **dos contenedores distintos**, y compartir un archivo entre ellos es frágil (permisos, bloqueos, volúmenes compartidos). Lo normal es una base de datos con servidor, a la que ambos se conectan por la red: PostgreSQL, la misma que usarías en RDS (fase 6). SQLite se queda para tu portátil y para las pruebas.

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Si el destino de la base de datos empieza por `postgresql://` (o `postgres://`), Vigía usa PostgreSQL; si no, SQLite (una ruta, o `sqlite:///ruta`). La tabla `checks` tiene las mismas columnas en las dos | 51, 62 |
| R2 | El destino sale, por este orden, de la variable de entorno `DATABASE_URL`, de la opción `--db` o de `database` en la configuración | 50 |
| R3 | `check --interval N` repite la revisión cada N segundos hasta recibir **SIGTERM** (o `Ctrl+C`), y entonces termina en pocos segundos, sin traza. Sin `--interval`, revisa una vez, como en la v1 | 11, 19 |
| R4 | Si la base de datos no responde, `check` lo registra en el log y sale con 1, sin traza. En modo `--interval`, lo vuelve a intentar en la siguiente ronda | 44 |
| R5 | Las 26 pruebas de aceptación de la v1 **siguen pasando** (en modo SQLite) | 54, 55 |
| R6 | `Dockerfile` en dos etapas sobre `python:3.14-slim`, con un usuario sin privilegios, `ENTRYPOINT ["python", "-m", "vigia"]` en forma exec y, por defecto, `CMD ["serve", "--host", "0.0.0.0", "--port", "8000"]` | 58, 59 |
| R7 | `.dockerignore` que excluye al menos `.venv/`, `.git/`, `.env` y `*.db` | 58 |
| R8 | La imagen pesa menos de 400 MB y `docker run --rm vigia:dev --help` muestra la ayuda | 59 |

## Plan de trabajo

En tu repo de Vigía, rama nueva: `git switch main && git pull && git switch -c docker`.

**Bloque 1: PostgreSQL y las opciones nuevas**
1. Añade `psycopg[binary]` a `requirements.txt`, con su versión fijada, e instálalo en tu `.venv`.
2. En `storage.py`, una segunda clase para PostgreSQL con los mismos métodos que la de SQLite (guardar y "el último de cada URL"), y una función que elija una u otra según el destino (R1). Commit.
3. En `cli.py`, el orden de R2 y la opción `--interval` con su manejo de SIGTERM (R3), y el error de base de datos de R4. Commit.
4. Arranca un PostgreSQL de prueba y comprueba que Vigía escribe en él (abajo). Ejecuta las pruebas de la v1: siguen en verde (R5).

**Bloque 2: la imagen**

5. `Dockerfile` y `.dockerignore`. Construye y comprueba R6 a R8 (abajo). Commit y PR; lo fusionarás al terminar la clase 66.

### Probar con un PostgreSQL de verdad, sin Compose

```bash
docker network create vigia-prueba
docker run -d --name pg-prueba --network vigia-prueba -p 127.0.0.1:5432:5432 \
  -e POSTGRES_USER=vigia -e POSTGRES_PASSWORD=prueba -e POSTGRES_DB=vigia postgres:18
sleep 5
cd ~/vigia && source .venv/bin/activate
DATABASE_URL=postgresql://vigia:prueba@127.0.0.1:5432/vigia python -m vigia check
docker exec pg-prueba psql -U vigia -d vigia -c 'SELECT url, status_code, up FROM checks ORDER BY id DESC LIMIT 5;'
```

Desde tu Ubuntu llegas al contenedor por el puerto publicado en `127.0.0.1`. Fíjate en que tu `config.yaml` no cambió: la base de datos llega por el entorno. Cuando termines: `docker rm -f pg-prueba && docker network rm vigia-prueba`.

### Comprobar la imagen

```bash
docker build -t vigia:dev .
docker images vigia
docker run --rm vigia:dev --help
docker run --rm vigia:dev check
docker run --rm -e DATABASE_URL=sqlite:////tmp/vigia.db vigia:dev check
docker run --rm --entrypoint id vigia:dev
```

🔮 **Predice** qué hará el `check` del segundo comando. Falla: la configuración de la imagen apunta a `vigia.db` dentro de `/app`, y el usuario sin privilegios no puede escribir ahí (clase 59). Con `DATABASE_URL=sqlite:////tmp/vigia.db` (cuatro barras: `sqlite:///` y la ruta absoluta) funciona… y el resultado desaparece con el contenedor. Por eso, en la clase 66, los datos irán a PostgreSQL con su volumen.

## Pistas

<details><summary>Pista 1 — PostgreSQL desde Python</summary>

Como en el contador de la clase 62: `psycopg.connect(url)` con un `with`, que confirma y cierra al salir, y parámetros con `%s` en lugar de `?`. Para leer filas como diccionarios: `from psycopg.rows import dict_row` y `psycopg.connect(url, row_factory=dict_row)`. La columna `id` en PostgreSQL: `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` (el equivalente del `AUTOINCREMENT` de SQLite) y `seconds DOUBLE PRECISION`.
</details>

<details><summary>Pista 2 — elegir el almacén</summary>

Una función que reciba el destino y devuelva el objeto adecuado:

```python
def abrir_almacen(destino):
    if destino.startswith(("postgresql://", "postgres://")):
        return AlmacenPostgres(destino)
    if destino.startswith("sqlite:///"):
        destino = destino.removeprefix("sqlite:///")
    return AlmacenSQLite(destino)
```
Si las dos clases tienen los mismos métodos, el resto de Vigía no necesita saber cuál está usando.
</details>

<details><summary>Pista 3 — repetir y parar con SIGTERM</summary>

Un manejador de señal que solo levanta una bandera, y una espera troceada que la mira a menudo:

```python
import signal, time

parar = False

def al_recibir_senal(senal, marco):
    global parar
    parar = True

signal.signal(signal.SIGTERM, al_recibir_senal)
signal.signal(signal.SIGINT, al_recibir_senal)
while True:
    codigo = comprobar(cfg, destino)
    if not intervalo:
        return codigo
    fin = time.monotonic() + intervalo
    while time.monotonic() < fin and not parar:
        time.sleep(0.5)
    if parar:
        return 0
```
Sin manejador, un proceso que es el PID 1 de un contenedor **ignora** SIGTERM, y `docker stop` tarda 10 segundos (clase 58). Con el manejador, termina al momento.
</details>

<details><summary>Pista 4 — la base de datos no responde</summary>

`psycopg` lanza `psycopg.OperationalError` cuando no puede conectar. Captúrala al abrir el almacén y al guardar, regístrala con `log.error` y devuelve 1. Pruébalo: `DATABASE_URL=postgresql://vigia:prueba@127.0.0.1:5999/vigia python -m vigia check; echo $?`.
</details>

<details><summary>Pista 5 — el Dockerfile</summary>

Es el de dos etapas de la clase 59, con tres cambios: `COPY vigia/ vigia/` y `COPY config.yaml .` en la etapa final, `ENTRYPOINT ["python", "-m", "vigia"]` y `CMD ["serve", "--host", "0.0.0.0", "--port", "8000"]`. Con `ENTRYPOINT` + `CMD`, `docker run vigia:dev check --interval 60` sustituye solo los argumentos (clase 58). `psycopg[binary]` trae su propia librería de PostgreSQL: no necesitas instalar nada con `apt`.
</details>

## Rómpelo

1. **Parar en mitad de una espera.** `DATABASE_URL=sqlite:////tmp/v.db python -m vigia check --interval 30`, espera a la primera ronda y pulsa `Ctrl+C`. Debe terminar en menos de un segundo, sin traza.
2. **El contenedor y SIGTERM.** `docker run -d --name ciclo -e DATABASE_URL=sqlite:////tmp/v.db vigia:dev check --interval 30`, y después `time docker stop ciclo`. Menos de un segundo: tu manejador funciona. Si tarda 10, revisa la pista 3 y que el `ENTRYPOINT` esté en forma exec. Bórralo con `docker rm ciclo`.
3. **La base de datos caída.** Con el PostgreSQL de prueba parado (`docker stop pg-prueba`), `DATABASE_URL=postgresql://vigia:prueba@127.0.0.1:5432/vigia python -m vigia check`: una línea de error en el log, código 1 y ninguna traza.
4. **Las pruebas de la v1:** `pytest ~/my-devops-journey/recursos/vigia/v1 -q` → `26 passed`. Si alguna falla, el cambio de almacén rompió algo del contrato de la v1.

## Cierre

En `notas/fase-5/clase-65.md`:

1. ¿Por qué Vigía pasa a PostgreSQL en contenedores, si SQLite funcionaba en la v1? *(2 líneas. Empieza así: «Porque la API y el chequeo serán contenedores separados, y compartir un archivo SQLite…»)*
2. ¿Por qué la base de datos llega por `DATABASE_URL` y no escrita en `config.yaml`? *(2 líneas. Empieza así: «Porque la base de datos depende de dónde corre Vigía (…), no de qué vigila. Por el entorno,…»)*
3. Explica qué hace tu manejador de SIGTERM y qué pasaría en `docker stop` sin él. *(2 líneas. Empieza así: «Cuando llega SIGTERM, el manejador solo marca… Sin él, Python como PID 1…»)*
4. **Repaso (clase 64, sin mirar):** ¿qué diferencia hay entre una etiqueta y un *digest*? *(1 línea. Empieza así: «La etiqueta es un nombre móvil que…»)*

Después, escríbeme `examíname clase-65`.

## Autocorrección

<details>
<summary>Ábrelo cuando cumplas R1 a R8</summary>

**Comprueba tu entrega:**
- [ ] Con `DATABASE_URL=postgresql://…`, las filas aparecen en PostgreSQL; sin ella, en tu SQLite de siempre.
- [ ] `check --interval 30` termina en menos de un segundo con `Ctrl+C` y con `docker stop`.
- [ ] Con la base de datos caída: un error en el log, código 1 y ninguna traza.
- [ ] `pytest ~/my-devops-journey/recursos/vigia/v1` → `26 passed`.
- [ ] `docker images vigia` muestra menos de 400 MB y `docker run --rm --entrypoint id vigia:dev` no da `uid=0`.
- [ ] `ruff check vigia tests` sin avisos.

**Cierre:**
1. Porque la API y el chequeo serán contenedores separados, y compartir un archivo SQLite entre ellos obliga a montar el mismo volumen en los dos y a pelear con permisos y bloqueos. Con PostgreSQL, ambos se conectan por la red a un servidor que gestiona la concurrencia, como harían en producción.
2. Porque la base de datos depende de **dónde** corre Vigía (tu portátil, Compose, AWS), no de qué vigila. Por el entorno, la misma imagen y la misma configuración sirven en todas partes, y la contraseña no acaba escrita en un archivo del repo (clase 50, la aplicación de doce factores).
3. Cuando llega SIGTERM, el manejador solo marca que hay que parar; el bucle lo ve en menos de medio segundo y termina devolviendo 0. Sin manejador, Python como PID 1 de un contenedor ignoraría SIGTERM, `docker stop` esperaría los 10 segundos y lo mataría con SIGKILL a mitad de lo que estuviera haciendo.
4. La etiqueta es un nombre móvil que puede apuntar a otra imagen; el *digest* identifica el contenido exacto y nunca cambia.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| connection string / database URL | cadena de conexión |
| signal handler | manejador de señales |
| graceful shutdown | parada ordenada |
| backward compatibility | compatibilidad con lo anterior |
| twelve-factor config | configuración por el entorno |

🎙️ *"Version 2 reads its database from DATABASE_URL, so the same image works with SQLite on my laptop and PostgreSQL in Compose, and it handles SIGTERM so containers stop instantly."*

## Siguiente

[Clase 66 — Proyecto: Vigía v2 (II): Compose con API, chequeo y base de datos](clase-66-vigia-v2-compose.md)
