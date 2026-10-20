# Clase 54 — Proyecto: Vigía v1 (I): el chequeo en Python

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

> 💡 **La idea de hoy:** Vigía pasa de Bash a Python. Hoy escribes el chequeo: leer y validar `config.yaml`, revisar cada URL con `requests` y guardar cada resultado como una fila en SQLite, todo detrás de `python -m vigia check`. Unas pruebas de aceptación del curso comprueban desde fuera que cumples el contrato; cómo lo organizas por dentro es cosa tuya.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Paquetes, `import` y `if __name__ == "__main__":` (clase 45); `.venv` y `requirements.txt` (clase 46).
> - `yaml.safe_load` y validar una configuración (clase 47); `argparse` con subcomandos y `logging` (clase 48).
> - Tu excepción propia `ConfigError` y los códigos de salida (clase 44).
> - `revisar()` con `requests`: `Timeout` antes que `ConnectionError` y un `User-Agent` propio (clase 49).
> - La tabla `checks` y el `INSERT` con `?` (clase 51); `pytest` (clase 52).
> - El flujo rama → PR de la v0.1 (clases 24 y 25) y tu línea de cron (clase 20).

> 🔤 **Palabras nuevas de hoy:**
> - **prueba de aceptación**: la que comprueba el programa desde fuera, como lo usaría alguien, sin mirar el código.
> - **contrato**: lo que el programa promete (argumentos, códigos de salida, columnas de la tabla) y que esas pruebas comprueban.
> - **`python -m paquete`**: ejecutar un paquete; Python busca y ejecuta su `__main__.py`.
> - **separación de responsabilidades**: un módulo por tarea (configuración, chequeo, almacenamiento, línea de comandos).

## Objetivo

Reescribir el corazón de Vigía en Python: leer la configuración de un YAML, revisar cada URL con `requests` y guardar cada resultado en una base de datos SQLite, con una línea de comandos `python -m vigia check`. En la clase 55 le añadirás la API, tus pruebas y la versión `v1`.

Es la versión que pide la Ruta 2.0 para la fase 4: *reescritura en Python con requests, configuración en YAML, resultados en SQLite y una API mínima que devuelve el estado en JSON*.

## Por qué en dos partes

Vigía v1 junta todo lo de esta fase: tipos y funciones (39–42), archivos y errores (43–44), módulos (45), entorno virtual (46), YAML (47), `argparse` y `logging` (48), `requests` (49), SQLite (51), pruebas (52) y FastAPI (53). Es demasiado para un solo bloque. Hoy, el chequeo; en la 55, la API.

## El contrato

Las **pruebas de aceptación** del curso (`~/my-devops-journey/recursos/vigia/v1/`) comprueban Vigía desde fuera, así que tu programa tiene que respetar este contrato. Cómo lo organices por dentro es cosa tuya.

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Un paquete `vigia/` que se ejecuta con `python -m vigia` (necesita `vigia/__main__.py`), un entorno `.venv` ignorado por Git, `requirements.txt` con las versiones fijadas y `requirements-dev.txt` | 45, 46 |
| R2 | `python -m vigia check --config RUTA` revisa todas las URLs una vez. Sin `--config`, usa `config.yaml` de la carpeta actual | 48 |
| R3 | La configuración es YAML: `urls` (lista no vacía; cada URL empieza por `http://` o `https://`), `timeout` (número mayor que 0, por defecto 10) y `database` (ruta del archivo SQLite, por defecto `vigia.db`) | 47 |
| R4 | Si `database` es una ruta **relativa**, se interpreta desde la carpeta del archivo de configuración, no desde la carpeta actual (así funciona igual desde cron) | 43 |
| R5 | Una configuración que no se puede usar (no existe, YAML roto, sin `urls`, lista vacía, URL sin esquema, `timeout` no positivo) termina con código **2** y un mensaje claro en stderr, **sin traza** | 44 |
| R6 | Cada URL se revisa con `GET`, **sin seguir redirecciones**, con el `timeout` de la configuración y con un `User-Agent` propio que empiece por `Vigia/` (por ejemplo, `Vigia/1.0 (+https://github.com/TU_USUARIO/vigia)`). Un 3xx cuenta como UP, igual que en la v0 | 49 |
| R7 | Cada revisión añade **una fila** a la tabla `checks` (abajo), en el orden de la configuración. Las filas se acumulan: nunca se borran ni se reemplazan | 51 |
| R8 | `status_code`: el código HTTP, o `0` si no hubo respuesta · `seconds`: lo que tardó, también si falló · `up`: `1` si el código está entre 200 y 399 · `error`: `NULL` si hubo respuesta HTTP y un texto corto si no (`timeout`, `connection`…) · `checked_at`: fecha ISO 8601 **con zona horaria** (UTC) | 45, 49 |
| R9 | Código de salida: 0 si todas están arriba, 1 si alguna está caída | 44 |
| R10 | Una línea de log por URL en stderr, con fecha y nivel | 48 |

La tabla, exactamente con estas columnas:

```sql
CREATE TABLE IF NOT EXISTS checks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    url         TEXT    NOT NULL,
    status_code INTEGER NOT NULL,
    seconds     REAL    NOT NULL,
    up          INTEGER NOT NULL,
    error       TEXT,
    checked_at  TEXT    NOT NULL
);
```

Y un ejemplo de configuración:

```yaml
# config.yaml
timeout: 10
database: vigia.db
urls:
  - https://example.com
  - https://www.wikipedia.org
  - https://github.com
```

## Estructura sugerida

```
~/vigia/
├── vigia/
│   ├── __init__.py       # puede quedar vacío, o con __version__ = "1.0.0"
│   ├── __main__.py       # 2 líneas: importa main de cli.py y sale con su código
│   ├── config.py         # cargar y validar el YAML → ConfigError si algo falla
│   ├── checker.py        # revisar(url, timeout) → el resultado de una URL
│   ├── storage.py        # crear la tabla, guardar un resultado (y en la 55, leer)
│   └── cli.py            # argparse + logging: el subcomando check
├── tests/                # tus pruebas (las escribirás en la 55)
├── config.yaml
├── requirements.txt
├── requirements-dev.txt
└── README.md
```

Un módulo por responsabilidad: así cada pieza se puede probar sola, y en la fase 5 podrás cambiar SQLite por PostgreSQL tocando solo `storage.py`.

## Plan de trabajo

Todo en tu repo de Vigía, con el flujo de la v0.1: una rama y un pull request.

**Bloque 1: esqueleto, configuración y chequeo**
1. `cd ~/vigia && git switch main && git pull && git switch -c python-rewrite`.
2. Crea `.venv`, instala `requests`, `PyYAML`, `fastapi` y `uvicorn` y congélalos en `requirements.txt`. En `requirements-dev.txt`: `-r requirements.txt`, `pytest` y `httpx2` (para el `TestClient` de la clase 55). Añade al `.gitignore` `.venv/`, `__pycache__/`, `*.db` y `.pytest_cache/`.
3. `vigia/__main__.py` y un `cli.py` con el subcomando `check` que, de momento, solo imprima la configuración. Commit.
4. `config.py` con su `ConfigError` y todas las validaciones de R3 a R5. Pruébalas a mano con YAML rotos. Commit.
5. `checker.py` con `revisar(url, timeout)`. Pruébala desde el intérprete con las URLs difíciles de la clase 49. Commit.

**Bloque 2: base de datos, códigos de salida y pruebas de aceptación**

6. `storage.py`: crear la tabla y guardar un resultado. Conecta todo en `cli.py`. Commit.
7. Ejecuta las pruebas de aceptación del chequeo (abajo) y arregla lo que falle, **una prueba cada vez**, empezando por la primera.
8. Actualiza la línea de cron (abajo). Abre el PR; lo fusionarás al terminar la clase 55.

### Las pruebas de aceptación

```bash
cd ~/vigia
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest ~/my-devops-journey/recursos/vigia/v1 -v -m "not api"
```

`-m "not api"` deja fuera las 4 pruebas de la API (llegan en la clase 55). Las otras 22 arrancan un servidor HTTP falso en `127.0.0.1` que responde 200, 301, 404, 500 o tarda 3 segundos, y añaden un nombre que no existe. Cada prueba que falla explica qué esperaba y qué encontró.

## Pistas

Ábrelas de una en una, solo tras 30 minutos atascado.

<details><summary>Pista 1 — <code>python -m vigia</code> no encuentra el módulo</summary>

`python -m vigia` busca el paquete en la carpeta actual: ejecútalo desde `~/vigia`, con `vigia/__init__.py` y `vigia/__main__.py` dentro. Un `__main__.py` mínimo:

```python
from vigia.cli import main

raise SystemExit(main())
```
`raise SystemExit(codigo)` hace lo mismo que `sys.exit(codigo)`.
</details>

<details><summary>Pista 2 — <code>check --config x.yaml</code> da "unrecognized arguments"</summary>

Es el Rómpelo 3 de la clase 48: las opciones del parser principal van antes del subcomando. Para que `--config` funcione **después** de `check` (y, en la 55, de `serve`), créalo en un parser "común" y pásaselo a cada subcomando:

```python
comun = argparse.ArgumentParser(add_help=False)
comun.add_argument("--config", default="config.yaml")
parser = argparse.ArgumentParser(prog="vigia")
sub = parser.add_subparsers(dest="comando", required=True)
sub.add_parser("check", parents=[comun], help="revisa todas las URLs una vez")
```
</details>

<details><summary>Pista 3 — la base de datos aparece en la carpeta equivocada</summary>

R4: la ruta relativa se calcula desde la carpeta del archivo de configuración.

```python
ruta_db = Path(datos.get("database", "vigia.db"))
if not ruta_db.is_absolute():
    ruta_db = Path(ruta_config).parent / ruta_db
```
</details>

<details><summary>Pista 4 — un YAML roto muestra una traza</summary>

R5: captura `OSError` al leer el archivo y `yaml.YAMLError` al interpretarlo, y conviértelos en tu `ConfigError` con un mensaje claro (clase 44). En `cli.py`, captura `ConfigError`, regístrala con `log.error` y devuelve 2. Recuerda también que `yaml.safe_load` de un archivo vacío devuelve `None`, y de `urls: []` una lista vacía.
</details>

<details><summary>Pista 5 — el timeout se clasifica como "connection"</summary>

Es el Rómpelo 2 de la clase 49: `ConnectTimeout` es a la vez `Timeout` y `ConnectionError`. Captura `Timeout` antes.
</details>

<details><summary>Pista 5b — Wikipedia sale DOWN con un 403</summary>

Es el Rómpelo 6 de la clase 49: algunos sitios bloquean el `User-Agent` genérico de `requests`. Pásale a `requests.get` `headers={"User-Agent": "Vigia/1.0 (+https://github.com/TU_USUARIO/vigia)"}`. Una de las pruebas de aceptación comprueba que te identificas.
</details>

<details><summary>Pista 6 — <code>checked_at</code> no tiene zona horaria</summary>

`datetime.now(timezone.utc).isoformat(timespec="seconds")` da `2026-10-20T02:05:01+00:00`. Sin `timezone.utc`, la fecha no lleva zona y la prueba lo detecta (clase 45).
</details>

## Rómpelo: antes de abrir el PR

1. **Sin red.** Desconecta el wifi y ejecuta `python -m vigia check`. Todas las URLs deben salir DOWN con `error`, el código debe ser 1 y no debe haber trazas. Vuelve a conectar.
2. **Desde otra carpeta**, como lo haría cron: `cd /tmp && ~/vigia/.venv/bin/python -m vigia check --config ~/vigia/config.yaml`. ¿Falla? Lee la pista 1: `-m` busca el paquete en la carpeta actual. Por eso la línea de cron entra primero en `~/vigia`.
3. **Mira dentro de la base de datos**: `sqlite3 -header -column vigia.db 'SELECT * FROM checks ORDER BY id DESC LIMIT 6;'` (si instalaste el cliente en la clase 51) o con un `SELECT` desde Python. ¿Coincide con lo que dijo el log?
4. **Una URL lenta.** Añade `http://192.0.2.1` a una configuración de prueba con `timeout: 2`. Esa fila debe tardar unos 2 s y tener `error`.

## La nueva línea de cron

Cron no activa entornos virtuales: llama al Python de `.venv` por su ruta (clase 46) y entra antes en la carpeta del proyecto:

```
*/5 * * * * cd /home/educo/vigia && .venv/bin/python -m vigia check >> /home/educo/logs/vigia-cron.log 2>&1
```

Sustituye la línea de la v0 con `crontab -e`. Comprueba a los 5 minutos `journalctl -u cron`, el log y la base de datos.

## Cierre

En `notas/fase-4/clase-54.md`:

1. Escribe cómo viaja una revisión por tus módulos, desde `python -m vigia check` hasta la fila en `checks`. *(Una línea con flechas. Empieza así: «`__main__.py` → `cli.main()` (lee los argumentos y…) → `config.____()` (…) → por cada URL, `checker.____()` → `storage.____()` → …»)*
2. ¿Por qué la ruta relativa de `database` se resuelve desde la carpeta del archivo de configuración y no desde la carpeta actual? *(2 líneas. Empieza así: «Porque la carpeta actual depende de quién lance el programa (yo, cron…), y la del archivo de configuración…»)*
3. ¿Qué prueba de aceptación te costó más hacer pasar y qué aprendiste al arreglarla? *(1–2 líneas. Empieza así: «La que más me costó fue `test_…`: fallaba porque… y lo arreglé…»)*
4. **Repaso (clase 53, sin mirar):** ¿por qué hay que abrir la conexión de SQLite dentro de cada petición en una API de FastAPI? *(1–2 líneas. Empieza así: «Porque FastAPI atiende las peticiones en varios hilos, y…»)*

Después, escríbeme `examíname clase-54`.

## Autocorrección

<details>
<summary>Ábrelo cuando las 22 pruebas del chequeo pasen</summary>

**Comprueba tu entrega:**
- [ ] `pytest ~/my-devops-journey/recursos/vigia/v1 -m "not api"` → `22 passed`.
- [ ] `ruff check vigia/` no da avisos.
- [ ] Con la red cortada: todo DOWN, código 1 y ninguna traza.
- [ ] Cron ejecuta la v1 cada 5 minutos y la tabla `checks` crece.
- [ ] `git status` limpio: ni `.venv` ni `vigia.db` ni `__pycache__` aparecen como archivos nuevos.

**Cierre:**
1. Algo como: `__main__.py` → `cli.main()` (lee los argumentos y configura el log) → `config.load_config()` (lee y valida el YAML; si falla, código 2) → por cada URL, `checker.revisar()` (petición y clasificación) → `storage.guardar()` (INSERT) → log de la línea → al final, código 0 o 1 según las caídas.
2. Porque la carpeta actual depende de quién lance el programa (tú desde `~/vigia`, cron desde tu HOME, un servicio desde `/`), y la del archivo de configuración no. Así, el mismo `config.yaml` apunta siempre a la misma base de datos.
3. Respuesta personal. Las más habituales: la ruta relativa de la base de datos, el orden de los `except` de `requests` y las trazas con configuraciones rotas.
4. Porque FastAPI atiende las peticiones de las funciones normales en varios hilos, y una conexión de SQLite solo puede usarse en el hilo que la creó.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| rewrite | reescritura |
| acceptance test | prueba de aceptación |
| contract / interface | contrato / interfaz |
| separation of concerns | separación de responsabilidades |
| history (of results) | historial |

🎙️ *"I rewrote my uptime monitor from Bash to Python: a YAML config, requests with timeouts, results stored in SQLite, and a CLI with proper exit codes, all checked by black-box acceptance tests."*

## Siguiente

[Clase 55 — Proyecto: Vigía v1 (II): la API, tus pruebas y la versión](clase-55-vigia-v1-api.md)
