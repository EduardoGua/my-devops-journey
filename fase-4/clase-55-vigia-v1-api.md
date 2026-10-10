# Clase 55 — Proyecto: Vigía v1 (II): la API, tus pruebas y la versión

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

## Objetivo

Terminar Vigía v1: una API mínima con FastAPI (`python -m vigia serve`) que devuelve el estado de cada sitio en JSON, tus propias pruebas con `pytest` (al menos 5), un README en inglés al día y la etiqueta `v1`. Al terminar, cierras la fase 4.

## El contrato de la API

| # | Requisito | Clases |
|---|-----------|--------|
| R11 | `python -m vigia serve --config RUTA` arranca la API con `uvicorn`, en `--host` (por defecto `127.0.0.1`) y `--port` (por defecto `8000`) | 48, 53 |
| R12 | `python -m vigia --help` muestra los dos subcomandos, `check` y `serve` | 48 |
| R13 | `GET /health` → 200 y `{"status": "ok"}` | 53 |
| R14 | `GET /status` → 200 y el **último** resultado de cada URL que haya en la base de datos, con este formato: | 51, 53 |

```json
{
  "sites": [
    {"url": "https://example.com", "up": true, "status_code": 200,
     "seconds": 0.261, "error": null, "checked_at": "2026-10-20T02:05:01+00:00"}
  ],
  "up": 1,
  "down": 0
}
```

- `up` dentro de cada sitio es un booleano (`true`/`false`), no 1/0.
- `up` y `down` de fuera cuentan los sitios de la lista.
- Si haces otro `vigia check` mientras la API corre, `/status` debe mostrar el resultado **nuevo** sin reiniciarla: lee la base de datos en cada petición.

| # | Requisito | Clases |
|---|-----------|--------|
| R15 | Al menos **5 pruebas tuyas** en `tests/`, que pasan con `pytest`: de la configuración, del chequeo (con un servidor falso), del almacenamiento y de la API (con `TestClient`) | 52, 53 |
| R16 | Las 25 pruebas de aceptación pasan y `ruff check` no da avisos | 46, 52 |
| R17 | README en inglés: qué hace, cómo se instala desde cero, la configuración, `check` y `serve` con ejemplos de `curl`, la línea de cron, *What broke and how I found it* de esta versión y sus límites | — |
| R18 | PR fusionado, etiqueta `v1` y su release en GitHub | 25 |

## Plan de trabajo

**Bloque 1: la API**
1. En la misma rama `python-rewrite` de la clase 54: añade a `storage.py` una función que devuelva el último resultado de cada URL (la consulta con `MAX(id)` de la clase 51).
2. `vigia/api.py` con una fábrica `crear_app(ruta_db)` (clase 53) y las rutas `/health` y `/status`.
3. El subcomando `serve` en `cli.py`, que llama a `uvicorn.run(crear_app(ruta_db), host=…, port=…)`.
4. Pruébalo a mano: `python -m vigia check`, después `python -m vigia serve` y, en otra terminal, `curl -s localhost:8000/status | jq`. Commit.
5. Las pruebas de aceptación completas: `pytest ~/my-devops-journey/recursos/vigia/v1 -v`.

**Bloque 2: tus pruebas, el README y la versión**

6. Tus pruebas en `tests/` (abajo, ideas). Commit.
7. `ruff check vigia tests` hasta que no dé avisos.
8. Despídete de la v0: borra `vigia.sh` y `urls.txt` (el historial y la etiqueta `v0` los conservan) y explica en el README que la v0 era Bash.
9. README, PR con una buena descripción, *squash and merge*, etiqueta `v1` y release.

## Ideas para tus pruebas

No copies las de aceptación: escribe pruebas **unitarias**, de cada pieza por separado y con datos que tú controlas.

| Pieza | Qué probar | Herramienta |
|-------|------------|-------------|
| `config.py` | una configuración válida; que una URL sin esquema lanza `ConfigError`; la ruta relativa de `database` | `tmp_path`, `pytest.raises` |
| `checker.py` | 200 → up; 404 → down; el tiempo agotado da `status_code` 0 y `error` | un servidor falso (clase 52) |
| `storage.py` | guardar dos resultados de la misma URL y que "el último" devuelva el segundo | `tmp_path` |
| `api.py` | `/health`; `/status` con una base de datos de prueba | `TestClient` (clase 53) |

Para probar la API sin tocar tu base de datos real, crea en un `tmp_path` una base de datos con dos o tres filas, como en `test_api.py` de la clase 53.

## Pistas

<details><summary>Pista 1 — <code>/status</code> devuelve <code>up: 1</code> en lugar de <code>true</code></summary>

SQLite guarda 1/0. Conviértelo al construir la respuesta: `fila | {"up": bool(fila["up"])}` (clase 53, Reto 2).
</details>

<details><summary>Pista 2 — <code>/status</code> no cambia después de otro <code>check</code></summary>

Seguramente lees la base de datos una sola vez, al crear la app, y guardas el resultado. Haz la consulta **dentro** de la función de la ruta, y abre ahí la conexión (clase 53, Rómpelo 2).
</details>

<details><summary>Pista 3 — la prueba de la API no llega a arrancar</summary>

La prueba lanza `python -m vigia serve --config … --port …` y espera hasta 15 s a que `/health` responda. Lánzalo tú igual y mira el error: un `import` que falla, una opción que `serve` no acepta (¿has puesto `--config` en el parser común?) o el puerto ocupado.
</details>

<details><summary>Pista 4 — cómo arrancar uvicorn desde tu código</summary>

```python
import uvicorn
from vigia.api import crear_app

uvicorn.run(crear_app(ruta_db), host=args.host, port=args.port)
```
`uvicorn.run` bloquea hasta que pulsas `Ctrl+C`. Con una app ya creada (y no un texto como `"vigia.api:app"`), `--reload` no está disponible, y no hace falta.
</details>

## Rómpelo: antes de etiquetar

1. **La API con la base de datos vacía.** Borra `vigia.db`, arranca `serve` sin hacer `check` y pide `/status`. ¿Devuelve `{"sites": [], "up": 0, "down": 0}` o un error 500? Debe ser lo primero.
2. **Dos procesos a la vez.** Con `serve` corriendo, lanza `check` varias veces. SQLite admite un escritor y varios lectores; con este volumen, no debería haber errores. Si ves `database is locked`, revisa que cierras cada conexión.
3. **Desde fuera de tu máquina.** Arranca con `--host 0.0.0.0` y pide `/status` desde otra máquina o desde la IP de tu red (clase 53, Rómpelo 3). Después vuelve a `127.0.0.1`: la v1 no tiene autenticación, así que no la expongas.
4. **Un clon limpio**, como en la v0.1: `git clone` en `/tmp`, crea el entorno, instala `requirements-dev.txt` y ejecuta las pruebas siguiendo **solo** tu README. Lo que falte en el README, añádelo.

## Entregable

- El paquete `vigia/` con `check` y `serve`, `tests/` con al menos 5 pruebas y `config.yaml` de ejemplo.
- `requirements.txt` y `requirements-dev.txt` con las versiones fijadas.
- README en inglés con estas secciones:

````markdown
# Vigía

A small uptime monitor: it checks a list of URLs, stores every result in SQLite
and exposes the latest status of each site through a JSON API.

> **v1 — Python.** v0 was a Bash script with cron. Each version adds a layer:
> next come Docker, AWS, CI/CD, Terraform, Kubernetes and observability.

## Install
## Configure            (config.yaml, with the meaning of each key)
## Run                  (check and serve, with curl examples of /health and /status)
## Schedule             (the cron line, with the virtualenv's python)
## Tests                (how to run them)
## What broke and how I found it
## Limitations
````

- Etiqueta y release:

```bash
git switch main && git pull
git tag -a v1 -m "v1: Python rewrite with SQLite and a JSON API"
git push origin v1
gh release create v1 --title "v1" --notes "Python rewrite: YAML config, SQLite history, JSON API, tests."
```

## Cierre

En `notas/fase-4/clase-55.md`:

1. ¿Por qué `/status` lee la base de datos en cada petición en lugar de guardar los resultados en memoria al arrancar?
2. ¿Qué diferencia hay entre tus pruebas de `tests/` y las pruebas de aceptación del curso? ¿Por qué tienen sentido las dos?
3. Nombra tres límites de la v1 y qué versión de Vigía los resuelve.
4. **Repaso (clase 54, sin mirar):** ¿por qué la línea de cron entra en `~/vigia` antes de lanzar `python -m vigia`?

## Autocorrección

<details>
<summary>Ábrelo cuando todas las pruebas pasen</summary>

**Comprueba tu entrega:**
- [ ] `pytest ~/my-devops-journey/recursos/vigia/v1` → `25 passed`.
- [ ] `pytest tests/` → al menos 5 pruebas, todas en verde.
- [ ] `ruff check vigia tests` sin avisos.
- [ ] `curl -s localhost:8000/status | jq` muestra un sitio por URL, con `up` booleano.
- [ ] Un clon limpio funciona siguiendo solo el README.
- [ ] `git tag` muestra `v1`, GitHub tiene la release y cron ejecuta la v1.

**Cierre:**
1. Porque el chequeo y la API son procesos distintos: `check` lo lanza cron cada 5 minutos y `serve` corre todo el tiempo. Si la API guardara los datos al arrancar, mostraría siempre ese momento. Leyendo en cada petición, siempre enseña lo último que se guardó.
2. Las tuyas son **unitarias**: prueban cada pieza por dentro, rápidas y con datos controlados, y te dicen **dónde** está el fallo. Las de aceptación son **de caja negra**: prueban el programa entero como lo usaría alguien, a través de la CLI, la base de datos y la API. Las unitarias te dejan cambiar el código con confianza; las de aceptación garantizan que el contrato sigue cumpliéndose.
3. Por ejemplo: corre en tu portátil y solo mientras está encendido (v3, en AWS); hay que instalar Python y dependencias para usarla (v2, con Docker); nadie la prueba ni la despliega automáticamente (v4, con CI/CD); no avisa a nadie cuando algo se cae (v7, con alertas); la API no tiene autenticación (por eso no se expone).
4. Porque `python -m vigia` busca el paquete en la carpeta actual, y cron arranca los trabajos desde tu HOME (clase 20).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| unit test / acceptance test | prueba unitaria / de aceptación |
| black-box testing | pruebas de caja negra |
| latest status | último estado |
| release notes | notas de la versión |
| to deprecate | retirar (algo antiguo) |

🎙️ *"Version 1 of my monitor is a Python package with a CLI and a FastAPI endpoint. It has unit tests for each module, plus black-box acceptance tests that run the real CLI against a fake HTTP server."*

## Al terminar la fase 4

1. Marca las clases 54 y 55 y Vigía v1 en [`PROGRESO.md`](../PROGRESO.md).
2. Revisa los **criterios de salida de la fase 4** y márcalos solo si los cumples sin mirar.
3. Anota tus horas en el registro mensual de la Ruta 2.0.
4. Antes de empezar la fase 5, pídeme `revisa la fase 5`: compruebo que las versiones y los comandos siguen al día.

## Siguiente

[Fase 5 — Clase 56: Qué es un contenedor de verdad](../fase-5/clase-56-que-es-un-contenedor.md)
