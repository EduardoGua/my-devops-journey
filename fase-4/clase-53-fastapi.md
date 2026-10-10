# Clase 53 — Una API mínima con FastAPI

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

## Objetivo

- Entender qué es una API web: rutas, métodos, códigos de estado y respuestas JSON.
- Crear una API con FastAPI: rutas con parámetros, validación automática y errores 404.
- Arrancarla con `uvicorn`, probarla con `curl` y ver su documentación automática en `/docs`.
- Escribir pruebas de la API con `TestClient`.
- Evitar dos trampas de las APIs: el puerto ocupado y una conexión de SQLite compartida entre hilos.

## Por qué importa

Hasta ahora tus programas se usan desde la terminal. Una API permite que los use **otro programa**: un panel web, un sistema de alertas, Prometheus (fase 10) o el *health check* de un balanceador de AWS (fase 6). Exponer el estado de un servicio por HTTP es tan común que todo servicio serio tiene un `/health`. Vigía v1 tendrá su API: `GET /health` y `GET /status`.

## Teoría

### Una API en diez líneas

```python
from fastapi import FastAPI, HTTPException

app = FastAPI(title="Historial")

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

Las anotaciones de tipo de la clase 42 aquí no son decoración: FastAPI las usa para validar la entrada y para escribir la documentación.

### `uvicorn`: el servidor

FastAPI define la aplicación; `uvicorn` es el servidor que escucha en un puerto y le pasa las peticiones.

```bash
uvicorn api:app --port 8000            # "api" es api.py y "app" la variable FastAPI de dentro
uvicorn api:app --port 8000 --reload   # se reinicia al guardar cambios (solo para desarrollar)
```

Por defecto escucha en `127.0.0.1`: solo tu máquina puede llegar. Para que la alcancen otras máquinas, `--host 0.0.0.0`. Es exactamente la diferencia de la clase 29, y en un contenedor (fase 5) tendrás que usar `0.0.0.0`.

Con la API en marcha, `http://127.0.0.1:8000/docs` muestra una documentación interactiva generada sola.

### Una conexión de base de datos por petición

FastAPI ejecuta las funciones normales (`def`) en varios **hilos** a la vez, para atender varias peticiones en paralelo. Una conexión de SQLite solo puede usarse en el hilo que la creó, así que **abre una conexión dentro de cada petición** (Rómpelo 2). Con SQLite es barato.

### Probar una API sin arrancarla

```python
from fastapi.testclient import TestClient

cliente = TestClient(app)
r = cliente.get("/health")
assert r.status_code == 200 and r.json() == {"status": "ok"}
```

`TestClient` habla con la aplicación directamente, sin puertos ni procesos. Necesita el paquete `httpx2` (versiones antiguas usaban `httpx`; si `pytest` muestra un aviso que menciona `httpx2`, es eso).

### Una fábrica para poder probar

Si la ruta de la base de datos está escrita dentro de la API, las pruebas usarían tu base de datos real. Mejor una función que **crea** la aplicación con la ruta que le pases:

```python
def crear_app(ruta_db: str) -> FastAPI:
    app = FastAPI()
    ...                                   # las rutas usan ruta_db
    return app

app = crear_app(os.environ.get("HISTORIAL_DB", "historial.db"))   # la que arranca uvicorn
```

En producción la ruta llega del entorno (clase 50); en las pruebas, `crear_app(tmp_path / "prueba.db")`. Vigía usará la misma idea.

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
pip install fastapi uvicorn httpx2
mkdir -p ~/my-devops-journey/labs/clase-53 && cd ~/my-devops-journey/labs/clase-53
cp ../clase-51/historial.db .
```

Vas a publicar como API la base de datos de la clase 51.

### 1. La API

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

Deja `uvicorn` corriendo y abre **otra terminal** para las siguientes prácticas. En la primera verás una línea de log por cada petición.

### 2. Probarla con `curl`

```bash
source ~/my-devops-journey/labs/.venv/bin/activate && cd ~/my-devops-journey/labs/clase-53
curl -s localhost:8000/health
curl -s "localhost:8000/checks?limite=2" | jq
curl -s "localhost:8000/checks?limite=3&solo_caidos=true" | jq '.[].url'
curl -s localhost:8000/stats | jq
curl -s -w "\ncódigo %{http_code}\n" localhost:8000/checks/99999
curl -s -w "\ncódigo %{http_code}\n" localhost:8000/checks/abc
```

🔮 **Predice** el código de las dos últimas. `99999` es un entero que no existe: 404, con tu mensaje. `abc` ni siquiera es un entero: FastAPI responde 422 y explica qué esperaba, sin que escribieras una sola comprobación.

Abre `http://127.0.0.1:8000/docs` en el navegador y prueba `/stats` con el botón *Try it out*.

### 3. Pruebas con `TestClient`

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

Cada prueba trabaja con su propia base de datos de tres filas, gracias a `crear_app`: tu `historial.db` no se toca y los resultados son siempre los mismos.

## Rómpelo

**1. El puerto ocupado.** Con el primer `uvicorn` aún corriendo, en la segunda terminal:
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

**3. Escuchar solo en `127.0.0.1`.** Con `api.py` corriendo como en la práctica 1, desde la segunda terminal:
```bash
IP=$(hostname -I | awk '{print $1}')
curl -s -m 3 http://$IP:8000/health || echo "no llega por la IP de la red"
```
Con la IP de tu red local no llega (*connection refused*), porque `uvicorn` escucha en `127.0.0.1`. Detén la API y arráncala con `uvicorn api:app --port 8000 --host 0.0.0.0`: ahora sí. Recuerda la regla de la clase 33: abrir el puerto en el firewall es otra decisión, y en una red pública no lo harías sin pensarlo.

## Reto

1. Añade a la API `GET /checks?url=…` para filtrar por URL (combinable con `solo_caidos`), con su prueba.
2. Añade `GET /status`: el **último** chequeo de cada URL (la consulta de la clase 51), con `up` como `true`/`false` y no como 1/0. Pruébalo con `TestClient`.
3. Valida `limite`: debe estar entre 1 y 100. Pista: `from fastapi import Query` y `limite: int = Query(5, ge=1, le=100)`. ¿Qué código devuelve con `limite=0`?

## Cierre

En `notas/fase-4/clase-53.md`:

1. ¿Qué diferencia hay entre un parámetro de ruta y uno de consulta? Pon un ejemplo de cada uno en la API de la clase.
2. ¿Por qué `/checks/abc` devuelve 422 sin que escribieras ninguna comprobación?
3. ¿Por qué hay que abrir la conexión de SQLite dentro de cada petición?
4. **Repaso (clase 52, sin mirar):** ¿por qué una prueba no debería depender de internet?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El de ruta forma parte del camino e identifica un recurso: `/checks/42` (`check_id`). El de consulta va detrás de `?` y modifica o filtra la respuesta: `/checks?limite=5&solo_caidos=true`.

**2.** Porque la función declara `check_id: int` y FastAPI valida la entrada con esa anotación: si el texto no se puede convertir en entero, responde 422 con un JSON que explica qué campo falló y por qué.

**3.** Porque FastAPI atiende las peticiones de las funciones normales en varios hilos, y una conexión de SQLite solo se puede usar en el hilo que la creó. Abrirla dentro de la petición (y cerrarla al terminar) evita el error y no comparte estado entre peticiones.

**4.** Porque puede fallar por motivos ajenos a tu código (sin red, el sitio cambió o te limita), y una prueba que falla "a veces" deja de servir. Se usa un servidor falso local o se sustituye la llamada de red.

**Reto 2 (una solución):**
```python
@app.get("/status")
def status():
    filas = consultar(
        "SELECT c.* FROM checks c"
        " JOIN (SELECT url, MAX(id) AS id FROM checks GROUP BY url) m ON c.id = m.id"
        " ORDER BY c.url"
    )
    return [fila | {"up": bool(fila["up"])} for fila in filas]
```

**Reto 3:** con `Query(5, ge=1, le=100)`, `limite=0` devuelve 422: FastAPI valida también los rangos.
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
