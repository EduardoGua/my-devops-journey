# Clase 53 — Una API mínima con FastAPI

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

> 💡 **La idea de hoy:** hasta ahora tus programas se usan desde la terminal; una **API web** deja que los use otro programa, por HTTP. Con FastAPI, cada ruta es una función con un decorador: lo que devuelve sale como JSON, y las anotaciones de tipo validan la entrada solas (un `abc` donde esperas un entero recibe un 422 sin que escribas nada). `uvicorn` es el servidor que la pone a escuchar en un puerto.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los métodos y los códigos de estado HTTP, y `curl -w '%{http_code}'` (clase 32).
> - Un puerto solo lo puede usar un proceso, la diferencia entre `127.0.0.1` y `0.0.0.0`, y `ss -tlnp` (clase 29).
> - Las anotaciones de tipo (clase 42) y las variables de entorno (clase 50).
> - `historial.db` y el SQL con `?` (clase 51); `pytest`, las fixtures y `tmp_path` (clase 52).

> 🔤 **Palabras nuevas de hoy:**
> - **API web** y **ruta** (*endpoint*): un programa que responde peticiones HTTP; cada ruta es una URL a la que responde, como `/health`.
> - **decorador**: la línea `@app.get("/ruta")` encima de una función, que la registra como respuesta a esa ruta.
> - **parámetro de ruta / de consulta**: el que va dentro del camino (`/checks/42`) / el que va detrás de `?` (`/checks?limite=5`).
> - **422**: el código con que FastAPI rechaza una entrada que no encaja con los tipos.
> - **hilo** (*thread*): una línea de ejecución dentro de un proceso; FastAPI usa varios para atender peticiones a la vez.
> - **fábrica**: una función que crea y devuelve la aplicación, como `crear_app(ruta_db)`.

## Objetivo

- Entender qué es una API web: rutas, métodos, códigos de estado y respuestas JSON.
- Crear una API con FastAPI: rutas con parámetros, validación automática y errores 404.
- Arrancarla con `uvicorn`, probarla con `curl` y ver su documentación automática en `/docs`.
- Escribir pruebas de la API con `TestClient`.
- Evitar dos trampas de las APIs: el puerto ocupado y una conexión de SQLite compartida entre hilos.

## Por qué importa

Hasta ahora tus programas se usan desde la terminal. Una API permite que los use **otro programa**: un panel web, un sistema de alertas, Prometheus (fase 10) o el *health check* de un balanceador de AWS (fase 6). Exponer el estado de un servicio por HTTP es tan común que todo servicio serio tiene un `/health`. Vigía v1 tendrá su API: `GET /health` y `GET /status`.

## Cómo va esta clase

Cuatro piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. En la 3 publicas como API la base de datos de la clase 51.

Vas a usar **dos terminales**: en la primera corre la API (`uvicorn`) y en la segunda haces las peticiones con `curl`.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 50 min); el segundo, la **pieza 4**, el Rómpelo, el reto y el cierre.

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
pip install fastapi uvicorn httpx2
mkdir -p ~/my-devops-journey/labs/clase-53 && cd ~/my-devops-journey/labs/clase-53
cp ../clase-51/historial.db .
```

## Las piezas

### Pieza 1 — Una API en diez líneas

```python
from fastapi import FastAPI, HTTPException

app = FastAPI(title="Hola")

@app.get("/health")
def health():
    return {"status": "ok"}                          # un dict → respuesta JSON con código 200

@app.get("/checks/{check_id}")
def un_check(check_id: int):                         # parámetro de ruta, validado como entero
    if check_id != 1:
        raise HTTPException(status_code=404, detail="no existe")
    return {"id": check_id, "url": "https://example.com"}
```

| Pieza | Qué hace |
|-------|----------|
| `@app.get("/ruta")` | esta función responde a `GET /ruta` |
| `{check_id}` en la ruta + `check_id: int` | parámetro de **ruta**; si no es un entero, FastAPI responde **422** solo |
| `limite: int = 10` en la función | parámetro de **consulta**: `/checks?limite=5` |
| devolver un `dict` o una `list` | FastAPI lo convierte a JSON |
| `raise HTTPException(404, …)` | responde con ese código y el detalle en JSON |

Las anotaciones de tipo de la clase 42 aquí no son decoración: FastAPI las usa para validar la entrada y para escribir la documentación. FastAPI define la aplicación; **`uvicorn`** es el servidor que escucha en un puerto y le pasa las peticiones: `uvicorn hola:app` quiere decir "el objeto `app` del archivo `hola.py`".

**Pruébalo.** En la **primera terminal**:

```bash
cat > hola.py <<'EOF'
from fastapi import FastAPI, HTTPException

app = FastAPI(title="Hola")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/checks/{check_id}")
def un_check(check_id: int):
    if check_id != 1:
        raise HTTPException(status_code=404, detail="no existe")
    return {"id": check_id, "url": "https://example.com"}
EOF
uvicorn hola:app --port 8000
```

🔮 **Predice** el código de `/checks/7` y el de `/checks/abc`.

Abre la **segunda terminal**:

```bash
source ~/my-devops-journey/labs/.venv/bin/activate && cd ~/my-devops-journey/labs/clase-53
curl -s localhost:8000/health ; echo
curl -s localhost:8000/checks/1 ; echo
curl -s -w "\ncódigo %{http_code}\n" localhost:8000/checks/7
curl -s -w "\ncódigo %{http_code}\n" localhost:8000/checks/abc
```

👀 **Qué deberías ver:** en la primera terminal, `Uvicorn running on http://127.0.0.1:8000` y una línea de log por cada petición. En la segunda, `{"status":"ok"}`; `{"id":1,"url":"https://example.com"}`; `{"detail":"no existe"}` con `código 404`, tu mensaje; y para `abc`, `código 422` con un JSON que explica el problema (`"loc":["path","check_id"]`, `"msg":"Input should be a valid integer…"`), sin que escribieras ninguna comprobación.

✋ **Sin mirar:** ¿qué hace FastAPI con el `dict` que devuelve una función de ruta?

<details>
<summary>Comprueba</summary>

Lo convierte a JSON y lo envía como respuesta, con código 200.
</details>

**En resumen:** `@app.get("/ruta")` encima de una función; lo que devuelve sale como JSON; `HTTPException` para un 404; los tipos dan el 422 gratis.

### Pieza 2 — `uvicorn`, `--reload` y la documentación automática

```bash
uvicorn api:app --port 8000            # "api" es api.py y "app" la variable FastAPI de dentro
uvicorn api:app --port 8000 --reload   # se reinicia al guardar cambios (solo para desarrollar)
```

Por defecto escucha en `127.0.0.1`: solo tu máquina puede llegar. Para que la alcancen otras máquinas, `--host 0.0.0.0`. Es exactamente la diferencia de la clase 29 (lo verás en el Rómpelo 3), y en un contenedor (fase 5) tendrás que usar `0.0.0.0`.

**Pruébalo.** En la primera terminal, `Ctrl+C` para parar la API y arráncala con `--reload`:

```bash
uvicorn hola:app --port 8000 --reload
```

En la segunda, cambia el código mientras la API corre:

```bash
sed -i 's/"ok"/"funcionando"/' hola.py
sleep 2; curl -s localhost:8000/health ; echo
```

👀 **Qué deberías ver:** en la primera terminal, `StatReload detected changes in 'hola.py'. Reloading...`; en la segunda, `{"status":"funcionando"}`, sin reiniciar nada a mano.

Ahora abre `http://127.0.0.1:8000/docs` en el navegador: una documentación interactiva, generada sola a partir de tus rutas y sus tipos. Despliega `/checks/{check_id}`, pulsa *Try it out*, escribe un número y *Execute*.

✋ **Sin mirar:** arrancas `uvicorn` sin `--host`. ¿Puede llegar a tu API otra máquina de tu red?

<details>
<summary>Comprueba</summary>

No: por defecto escucha en `127.0.0.1`, que solo es accesible desde tu propia máquina. Haría falta `--host 0.0.0.0`.
</details>

**En resumen:** `uvicorn archivo:app --port N`; `--reload` para desarrollar; `/docs` para ver y probar la API; `127.0.0.1` salvo que pidas `--host 0.0.0.0`.

### Pieza 3 — La API del historial: una conexión por petición

FastAPI ejecuta las funciones normales (`def`) en varios **hilos** a la vez, para atender varias peticiones en paralelo. Una conexión de SQLite solo puede usarse en el hilo que la creó, así que **abre una conexión dentro de cada petición** (Rómpelo 2). Con SQLite es barato.

En esta API, las rutas están dentro de una función `crear_app(ruta_db)` que crea la aplicación y la devuelve: es una **fábrica**. Verás para qué en la pieza 4. La que arranca `uvicorn` es la última línea, que lee la ruta de la base de datos del entorno (clase 50).

**Pruébalo.** En la primera terminal, `Ctrl+C` y:

```bash
cat > api.py <<'EOF'
"""api.py: el historial de chequeos de la clase 51, por HTTP."""
import os
import sqlite3
from contextlib import closing

from fastapi import FastAPI, HTTPException


def crear_app(ruta_db: str) -> FastAPI:
    app = FastAPI(title="Historial de chequeos")

    def consultar(sql: str, parametros: tuple = ()) -> list[dict]:
        with closing(sqlite3.connect(ruta_db)) as con:       # una conexión por petición
            con.row_factory = sqlite3.Row
            return [dict(fila) for fila in con.execute(sql, parametros)]

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.get("/checks")
    def ultimos(limite: int = 5, solo_caidos: bool = False):
        filtro = "WHERE up = 0" if solo_caidos else ""
        return consultar(f"SELECT * FROM checks {filtro} ORDER BY id DESC LIMIT ?", (limite,))

    @app.get("/checks/{check_id}")
    def un_check(check_id: int):
        filas = consultar("SELECT * FROM checks WHERE id = ?", (check_id,))
        if not filas:
            raise HTTPException(status_code=404, detail=f"no existe el chequeo {check_id}")
        return filas[0]

    @app.get("/stats")
    def stats():
        return consultar(
            "SELECT url, COUNT(*) AS chequeos, ROUND(AVG(up) * 100, 1) AS disponibilidad"
            " FROM checks GROUP BY url ORDER BY url"
        )

    return app


app = crear_app(os.environ.get("HISTORIAL_DB", "historial.db"))
EOF
uvicorn api:app --port 8000
```

`filtro` es un trozo de SQL fijo que elige **tu** código, no algo que escribe el usuario. Los valores del usuario (`limite`, `check_id`) van siempre con `?` (clase 51).

En la segunda terminal:

```bash
curl -s "localhost:8000/checks?limite=2" | jq
curl -s "localhost:8000/checks?limite=3&solo_caidos=true" | jq '.[].url'
curl -s localhost:8000/stats | jq
curl -s -w "\ncódigo %{http_code}\n" localhost:8000/checks/99999
```

👀 **Qué deberías ver:** los chequeos 300 y 299 completos, con todas sus columnas; las URLs de las 3 últimas caídas (`caido.dev`, `github.com`, `caido.dev`); las tres disponibilidades de la clase 51 (6.7, 99.0 y 95.7); y `{"detail":"no existe el chequeo 99999"}` con `código 404`. Los parámetros de consulta llegan ya convertidos: `limite` como entero y `solo_caidos=true` como `True`.

Deja `api.py` corriendo: la usarás en el Rómpelo.

✋ **Sin mirar:** ¿por qué `consultar` abre y cierra una conexión cada vez, en lugar de abrir una al arrancar?

<details>
<summary>Comprueba</summary>

Porque FastAPI atiende cada petición en un hilo que puede ser distinto, y una conexión de SQLite solo se puede usar en el hilo que la creó.
</details>

**En resumen:** una conexión por petición; los valores del usuario con `?`; los parámetros de consulta son argumentos con valor por defecto.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí (para la API con `Ctrl+C`). Mañana, lo primero: `source ~/my-devops-journey/labs/.venv/bin/activate` y `cd ~/my-devops-journey/labs/clase-53`.

### Pieza 4 — Probar la API sin arrancarla: `TestClient` y la fábrica

```python
from fastapi.testclient import TestClient

cliente = TestClient(app)
r = cliente.get("/health")
assert r.status_code == 200 and r.json() == {"status": "ok"}
```

`TestClient` habla con la aplicación directamente, sin puertos ni procesos. Necesita el paquete `httpx2` (versiones antiguas usaban `httpx`; si `pytest` muestra un aviso que menciona `httpx2`, es eso).

Aquí se ve para qué sirve la fábrica: si la ruta de la base de datos estuviera escrita dentro de la API, las pruebas usarían tu base de datos real. Con `crear_app`, cada prueba crea **su** aplicación con una base de datos pequeña en `tmp_path`:

```python
def crear_app(ruta_db: str) -> FastAPI:
    app = FastAPI()
    ...                                   # las rutas usan ruta_db
    return app

app = crear_app(os.environ.get("HISTORIAL_DB", "historial.db"))   # la que arranca uvicorn
```

En producción la ruta llega del entorno; en las pruebas, `crear_app(tmp_path / "prueba.db")`. Vigía usará la misma idea.

**Pruébalo:**

```bash
cat > test_api.py <<'EOF'
import sqlite3

import pytest
from fastapi.testclient import TestClient

from api import crear_app


@pytest.fixture
def cliente(tmp_path):
    ruta = tmp_path / "prueba.db"
    con = sqlite3.connect(ruta)
    con.execute("CREATE TABLE checks (id INTEGER PRIMARY KEY, url TEXT, status_code INTEGER,"
                " seconds REAL, up INTEGER, error TEXT, checked_at TEXT)")
    con.executemany("INSERT INTO checks (url, status_code, seconds, up, error, checked_at)"
                    " VALUES (?, ?, ?, ?, ?, ?)", [
                        ("https://a.com", 200, 0.2, 1, None, "2026-10-20T00:00:00+00:00"),
                        ("https://a.com", 503, 0.3, 0, None, "2026-10-20T00:05:00+00:00"),
                        ("https://b.com", 0, 10.0, 0, "timeout", "2026-10-20T00:05:00+00:00"),
                    ])
    con.commit()
    con.close()
    return TestClient(crear_app(str(ruta)))


def test_health(cliente):
    assert cliente.get("/health").json() == {"status": "ok"}


def test_un_check_que_no_existe_da_404(cliente):
    assert cliente.get("/checks/999").status_code == 404


def test_un_id_que_no_es_numero_da_422(cliente):
    assert cliente.get("/checks/abc").status_code == 422


def test_solo_caidos(cliente):
    urls = [c["url"] for c in cliente.get("/checks", params={"solo_caidos": True}).json()]
    assert urls == ["https://b.com", "https://a.com"]


def test_stats(cliente):
    assert cliente.get("/stats").json() == [
        {"url": "https://a.com", "chequeos": 2, "disponibilidad": 50.0},
        {"url": "https://b.com", "chequeos": 1, "disponibilidad": 0.0},
    ]
EOF
pytest -v test_api.py
```

👀 **Qué deberías ver:** `5 passed`, sin ningún `uvicorn` en marcha. Cada prueba trabaja con su propia base de datos de tres filas: tu `historial.db` no se toca y los resultados son siempre los mismos.

✋ **Sin mirar:** ¿qué problema resuelve `crear_app(ruta_db)` frente a escribir la ruta de la base de datos dentro de la API?

<details>
<summary>Comprueba</summary>

Que las pruebas puedan crear la aplicación con una base de datos de prueba (en `tmp_path`) en lugar de usar la real, y que en producción la ruta llegue del entorno.
</details>

**En resumen:** `TestClient(app)` prueba la API sin puertos; la fábrica `crear_app` deja que cada prueba use su propia base de datos.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `app = FastAPI(title=…)` | crear la aplicación |
| `@app.get("/ruta")` + `def f(): return {…}` | una ruta que responde JSON |
| `@app.get("/x/{id}")` + `def f(id: int)` | parámetro de ruta, validado (422 si no encaja) |
| `def f(limite: int = 5, solo_caidos: bool = False)` | parámetros de consulta: `?limite=2&solo_caidos=true` |
| `raise HTTPException(status_code=404, detail=…)` | responder con un error |
| `uvicorn archivo:app --port 8000 [--reload] [--host 0.0.0.0]` | arrancar el servidor |
| `http://127.0.0.1:8000/docs` | la documentación automática |
| `TestClient(app).get("/ruta", params={…})` | probar sin arrancar |
| `def crear_app(ruta_db) -> FastAPI:` | la fábrica, para poder probar |

## Rómpelo

**1. El puerto ocupado.** Con `api.py` aún corriendo en la primera terminal, en la segunda:
```bash
uvicorn api:app --port 8000
```
`[Errno 98] … address already in use`: solo un proceso puede escuchar en una IP y un puerto (clase 29). Averigua cuál con `ss -tlnp | grep 8000`. Usa otro puerto (`--port 8001`) o detén el primero con `Ctrl+C`.

**2. Una conexión compartida entre hilos:**
```bash
cat > api_rota.py <<'EOF'
import sqlite3
from fastapi import FastAPI

app = FastAPI()
con = sqlite3.connect("historial.db")          # ❌ una sola conexión, creada al arrancar

@app.get("/total")
def total():
    return {"total": con.execute("SELECT COUNT(*) FROM checks").fetchone()[0]}
EOF
uvicorn api_rota:app --port 8001 &
sleep 2; curl -s -w "\ncódigo %{http_code}\n" localhost:8001/total
kill %1
```
`Internal Server Error` y código 500. En el log de `uvicorn`: `SQLite objects created in a thread can only be used in that same thread`. La conexión se creó en el hilo principal y la petición la atiende otro. Arreglo: abrir la conexión dentro de la función, como en `api.py`.

**3. Escuchar solo en `127.0.0.1`.** Con `api.py` corriendo como en la pieza 3, desde la segunda terminal:
```bash
IP=$(hostname -I | awk '{print $1}')
curl -s -m 3 http://$IP:8000/health || echo "no llega por la IP de la red"
```
Con la IP de tu red local no llega (*connection refused*), porque `uvicorn` escucha en `127.0.0.1`. Detén la API y arráncala con `uvicorn api:app --port 8000 --host 0.0.0.0`: ahora sí. Recuerda la regla de la clase 33: abrir el puerto en el firewall es otra decisión, y en una red pública no lo harías sin pensarlo.

## Reto

En `labs/clase-53/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade a la API `GET /checks?url=…` para filtrar por URL (combinable con `solo_caidos`), con su prueba.

> 🧩 **Ejemplo resuelto:** el parámetro `solo_caidos` de `ultimos`: un parámetro de consulta con valor por defecto que añade un `WHERE` fijo.

**Ahora tú, con huecos** (sustituye `ultimos` en `api.py`):
```python
    @app.get("/checks")
    def ultimos(limite: int = 5, solo_caidos: bool = False, url: str | None = None):
        condiciones, parametros = [], []
        if solo_caidos:
            condiciones.append("up = 0")
        if url is not None:
            condiciones.append("url = ____")
            parametros.append(____)
        filtro = ("WHERE " + " AND ".join(condiciones)) if condiciones else ""
        return consultar(f"SELECT * FROM checks {filtro} ORDER BY id DESC LIMIT ?",
                         tuple(parametros) + (____,))
```
Y en `test_api.py`:
```python
def test_filtrar_por_url(cliente):
    filas = cliente.get("/checks", params={"url": "https://a.com", "solo_caidos": True}).json()
    assert [(f["url"], f["status_code"]) for f in filas] == [("https://a.com", ____)]
```

<details>
<summary>Pista</summary>

La URL la escribe el usuario: va con `?` y su valor, en `parametros`. Los trozos de SQL fijos (`up = 0`, `WHERE`, `AND`) los elige tu código. `" AND ".join(lista)` junta textos con ` AND ` en medio (clase 43). En la base de datos de prueba, `a.com` solo cayó una vez.
</details>

**2.** Añade `GET /status`: el **último** chequeo de cada URL, con `up` como `true`/`false` y no como 1/0. Pruébalo con `TestClient`.

> 🧩 **Ejemplo resuelto:** la consulta `ULTIMO` de la clase 51, pieza 4, y la ruta `/stats` de `api.py`.

**Ahora tú, con huecos:**
```python
    @app.get("/status")
    def status():
        filas = consultar(
            "SELECT c.* FROM checks c"
            " JOIN (SELECT url, ____(id) AS id FROM checks GROUP BY url) m ON c.id = m.id"
            " ORDER BY c.url"
        )
        return [fila | {"up": ____(fila["up"])} for fila in filas]
```
Y su prueba:
```python
def test_status(cliente):
    estado = {f["url"]: f["up"] for f in cliente.get("/status").json()}
    assert estado == {"https://a.com": ____, "https://b.com": False}
```

<details>
<summary>Pista</summary>

`fila | {"up": …}` crea un diccionario nuevo con todo lo de `fila` y `up` sustituido. `bool(1)` es `True` y `bool(0)`, `False`. El último chequeo de `a.com` en la base de datos de prueba es el 503.
</details>

**3.** Valida `limite`: debe estar entre 1 y 100. ¿Qué código devuelve con `limite=0`?

> 🧩 **Ejemplo resuelto:** `check_id: int` en la pieza 1: con solo el tipo, FastAPI rechaza `abc` con 422.

**Ahora tú, con huecos:** `from fastapi import FastAPI, HTTPException, ____` arriba, y en `ultimos`, `limite: int = Query(5, ge=____, le=____)`. Después, con la API arrancada: `curl -s -w "\ncódigo %{http_code}\n" "localhost:8000/checks?limite=0"` → código ____.

<details>
<summary>Pista</summary>

`ge` es *greater or equal* (mayor o igual) y `le`, *less or equal* (menor o igual). El 5 es el valor por defecto, como antes.
</details>

## Cierre

En `notas/fase-4/clase-53.md`:

1. ¿Qué diferencia hay entre un parámetro de ruta y uno de consulta? Pon un ejemplo de cada uno en la API de la clase. *(2 líneas. Empieza así: «El de ruta forma parte del camino e identifica…: `/checks/42`. El de consulta va detrás de `?` y…: »)*
2. ¿Por qué `/checks/abc` devuelve 422 sin que escribieras ninguna comprobación? *(1–2 líneas. Empieza así: «Porque la función declara `check_id: int` y FastAPI…»)*
3. ¿Por qué hay que abrir la conexión de SQLite dentro de cada petición? *(2 líneas. Empieza así: «Porque FastAPI atiende las peticiones en varios hilos, y una conexión de SQLite…»)*
4. **Repaso (clase 52, sin mirar):** ¿por qué una prueba no debería depender de internet? *(1–2 líneas. Empieza así: «Porque puede fallar por motivos ajenos a mi código, como…»)*

Después, escríbeme `examíname clase-53`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El de ruta forma parte del camino e identifica un recurso: `/checks/42` (`check_id`). El de consulta va detrás de `?` y modifica o filtra la respuesta: `/checks?limite=5&solo_caidos=true`.

**2.** Porque la función declara `check_id: int` y FastAPI valida la entrada con esa anotación: si el texto no se puede convertir en entero, responde 422 con un JSON que explica qué campo falló y por qué.

**3.** Porque FastAPI atiende las peticiones de las funciones normales en varios hilos, y una conexión de SQLite solo se puede usar en el hilo que la creó. Abrirla dentro de la petición (y cerrarla al terminar) evita el error y no comparte estado entre peticiones.

**4.** Porque puede fallar por motivos ajenos a tu código (sin red, el sitio cambió o te limita), y una prueba que falla "a veces" deja de servir. Se usa un servidor falso local o se sustituye la llamada de red.

**Reto 1:** `"url = ?"`, `parametros.append(url)`, `(limite,)` y `503`.

**Reto 2:** `MAX(id)`, `bool(fila["up"])` y `False`: el último chequeo de `a.com` es el 503.

**Reto 3:** `Query`, `ge=1`, `le=100` y código 422: FastAPI valida también los rangos.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| endpoint / route | ruta de la API |
| path parameter / query parameter | parámetro de ruta / de consulta |
| health check endpoint | ruta de comprobación de salud |
| request validation | validación de la petición |
| to bind to an address | escuchar en una dirección |

🎙️ *"Every service I build exposes a /health endpoint, so a load balancer or a monitoring system can check it without knowing anything else about it."*

## Siguiente

[Clase 54 — Proyecto: Vigía v1 (I)](clase-54-vigia-v1-chequeo.md)
