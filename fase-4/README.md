# Fase 4 — Python para automatizar

**Horas (Ruta 2.0):** 50–70 h.
**Al terminar:** escribes programas de Python con su entorno virtual, sus dependencias fijadas y sus pruebas; lees y escribes JSON, CSV y YAML; consumes APIs con `requests`, y publicas una API propia. Vigía v1 es una herramienta de Python con base de datos, línea de comandos, API y pruebas.

Bash sirve para tareas cortas; Python, para automatizaciones que crecen, para consumir APIs y, en la fase 6, para manejar AWS desde código.

## Qué necesitas

Python 3.14, `python3-venv` y `pipx` ya vienen en tu Ubuntu 26.04. Las librerías (`requests`, `PyYAML`, `pytest`, FastAPI…) se instalan dentro de entornos virtuales a partir de la clase 46. Opcional, desde la clase 51: el cliente `sqlite3` (`sudo apt install sqlite3`).

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Python desde cero** | | |
| 39 | [Tu primer programa: el intérprete, tipos y f-strings](clase-39-primer-programa.md) | Ubuntu | 75 min |
| 40 | [Decisiones y bucles](clase-40-decisiones-y-bucles.md) | Ubuntu | 75 min |
| 41 | [Listas, diccionarios y compañía](clase-41-listas-y-diccionarios.md) | Ubuntu | 90 min |
| 42 | [Funciones](clase-42-funciones.md) | Ubuntu | 75 min |
| 43 | [Texto, archivos y rutas](clase-43-texto-y-archivos.md) | Ubuntu | 90 min |
| 44 | [Errores y excepciones](clase-44-errores.md) | Ubuntu | 75 min |
| 45 | [Módulos, paquetes y la biblioteca estándar](clase-45-modulos.md) | Ubuntu | 75 min |
| | **B. Python para operaciones** | | |
| 46 | [Entornos virtuales y dependencias](clase-46-entornos-virtuales.md) | Ubuntu | 75 min |
| 47 | [JSON, CSV y YAML](clase-47-json-csv-yaml.md) | Ubuntu | 90 min |
| 48 | [Programas de línea de comandos: argparse y logging](clase-48-argparse-y-logging.md) | Ubuntu | 75 min |
| 49 | [Consumir APIs con requests](clase-49-requests.md) | Ubuntu | 90 min |
| 50 | [Automatizar el sistema: subprocess, shutil y variables de entorno](clase-50-automatizar-el-sistema.md) | Ubuntu | 75 min |
| 51 | [SQLite desde Python](clase-51-sqlite.md) | Ubuntu | 90 min |
| 52 | [Pruebas con pytest](clase-52-pytest.md) | Ubuntu | 90 min |
| 53 | [Una API mínima con FastAPI](clase-53-fastapi.md) | Ubuntu | 90 min |
| | **C. Proyecto** | | |
| 54 | [Vigía v1 (I): el chequeo en Python](clase-54-vigia-v1-chequeo.md) | Ubuntu + GitHub | 2 bloques largos |
| 55 | [Vigía v1 (II): la API, tus pruebas y la versión](clase-55-vigia-v1-api.md) | Ubuntu + GitHub | 2 bloques largos |

Las pruebas de aceptación de Vigía v1 están en [`recursos/vigia/v1/`](../recursos/vigia/v1/README.md).

## Cómo encajan los bloques

```
A. El lenguaje ──────────────► B. Las herramientas de operaciones ──────────► C. Vigía v1
   tipos, bucles, colecciones,     venv, JSON/YAML, CLI, APIs, sistema,          chequeo + SQLite
   funciones, archivos, errores    SQLite, pruebas, FastAPI                       + API + pruebas
```

Ya programabas en Bash: el bloque A traduce lo que sabes y añade lo que Bash no tiene (tipos, colecciones, excepciones). El bloque B son las piezas de Vigía, una por clase.

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Escribes un script que lee un JSON, filtra datos y escribe un CSV, con manejo de errores (clases 47 y 48)
- Llamas a una API pública con `requests` y manejas un error de red sin que el script se caiga (clase 49)
- Tu proyecto tiene `venv`, `requirements.txt` y al menos 5 pruebas con `pytest` (clases 46, 52 y 55)
- Vigía v1 devuelve el estado en JSON (clase 55)

## Datos que caducan

Versiones con las que se probaron las clases. Antes de empezar la fase, pídeme `revisa la fase 4` y las compruebo de nuevo.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| Python de Ubuntu 26.04 | 3.14.4 | 2026-10-09 | `python3 --version` |
| requests | 2.34.2 | 2026-10-09 | pypi.org/project/requests |
| PyYAML | 6.0.3 | 2026-10-09 | pypi.org/project/PyYAML |
| FastAPI · uvicorn · httpx2 | 0.143.0 · 0.54.0 · 2.13.1 | 2026-10-09 | pypi.org (Starlette 1.x pide `httpx2` para `TestClient`) |
| pytest | 9.1.1 | 2026-10-09 | pypi.org/project/pytest |
| ruff (con `pipx`) | 0.17.0 | 2026-10-09 | pypi.org/project/ruff |
| Límite de la API de GitHub sin autenticar | 60 peticiones por hora | 2026-10-09 | cabecera `X-RateLimit-Limit` |

## Recursos de apoyo

Las clases son el recurso principal. Para repasar o ir más allá:
- *Hello-Python* de MoureDev: curso gratis en español desde cero.
- La [documentación oficial de Python](https://docs.python.org/es/3/), en español, como consulta.
- Las documentaciones de [requests](https://requests.readthedocs.io), [pytest](https://docs.pytest.org) y [FastAPI](https://fastapi.tiangolo.com/es/) (esta última, también en español).

## Siguiente fase

[Fase 5 — Docker](../fase-5/README.md)
