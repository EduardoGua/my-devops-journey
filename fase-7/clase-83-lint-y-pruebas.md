# Clase 83 — Lint y pruebas en cada PR

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Integración continua

## Objetivo

- Montar la **integración continua** de una aplicación: lint, pruebas y construcción de la imagen en cada pull request y en cada `push` a `main`.
- Ordenar las comprobaciones de la más rápida a la más lenta, y que corran **en paralelo**.
- Acelerar el pipeline con la **caché** de dependencias, y cancelar las ejecuciones que ya no sirven con `concurrency`.
- Recoger los logs **cuando algo falla**, y escribir una **prueba de humo** reutilizable.

## Por qué importa

La integración continua es el primer escalón de CI/CD y el que más se usa en el trabajo. Cada PR llega con su veredicto: si rompe algo, se ve en minutos y en la propia página del PR, antes de que nadie lo revise.

Aquí lo montas sobre una aplicación pequeña, **saludo** (la API de la clase 58), para aprender sin miedo a romper Vigía. En la clase 90 harás lo mismo con Vigía, sin chuleta.

## Costo esperado

> 💰 **0 USD.** Repositorio público, runners estándar.

## Teoría

### Qué comprobar, y en qué orden

| Comprobación | Herramienta | Tarda | Encuentra |
|--------------|-------------|-------|-----------|
| **lint** | `ruff` (Python), `shellcheck` (Bash) | segundos | errores tontos: variables sin usar, comillas que faltan en Bash |
| **pruebas** | `pytest` (clase 52) | segundos o minutos | código que no hace lo que debe |
| **imagen** | `docker build` + arrancarla + una prueba de humo | minutos | un Dockerfile roto, una dependencia que falta, una app que no arranca |

En jobs **separados** corren en paralelo y, si uno falla, sabes **cuál** sin abrir nada. En la página del PR verás tres casillas con nombre: `lint`, `test`, `imagen`.

Una **prueba de humo** (*smoke test*) es la comprobación más simple de que algo vive: "¿responde `/health`?". No prueba que todo funcione; prueba que no está muerto. La escribirás una vez como script y la usarás aquí, al desplegar (clase 88) y para decidir si hay que volver atrás (clase 89).

### Más rápido y más limpio

- **Caché:** `actions/setup-python` con `cache: pip` guarda los paquetes descargados entre ejecuciones. La clave es el *hash* de `requirements-dev.txt`: si no cambias las dependencias, no se vuelven a descargar.
- **`concurrency`:** si subes otro commit al mismo PR mientras el pipeline corre, el resultado del anterior ya no le importa a nadie. Con `cancel-in-progress: true`, GitHub cancela la ejecución vieja.
- **`if: failure()`:** un step que solo corre si algo falló. Úsalo para volcar `docker logs`: el runner se destruye al terminar, y si no guardas los logs, se pierden.

## Práctica guiada

### 1. La aplicación en `lab-actions` (15 min)

```bash
cd ~/lab-actions && git switch main && git pull
cp ~/my-devops-journey/labs/clase-58/app.py .
mkdir -p tests scripts
printf 'fastapi==0.143.0\nuvicorn==0.54.0\n' > requirements.txt
printf -- '-r requirements.txt\npytest==9.1.1\nhttpx2==2.13.1\n' > requirements-dev.txt
printf '[pytest]\npythonpath = .\n' > pytest.ini
printf '.git/\n.github/\n.venv/\n__pycache__/\ntests/\n' > .dockerignore
printf '.venv/\n__pycache__/\n.pytest_cache/\n.ruff_cache/\n' > .gitignore
```

Si no conservas el `app.py` de la clase 58, está en el paso 1 de esa clase. `pythonpath = .` hace que `pytest` encuentre `app.py` desde `tests/`.

Las pruebas, en `tests/test_app.py`:

```python
from fastapi.testclient import TestClient

from app import app

cliente = TestClient(app)


def test_health_responde_ok():
    respuesta = cliente.get("/health")
    assert respuesta.status_code == 200
    assert respuesta.json() == {"status": "ok"}


def test_info_muestra_la_version(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    assert cliente.get("/info").json()["version"] == "1.2.3"
```

El `Dockerfile`, el de una etapa sin root (clase 59):

```dockerfile
FROM python:3.14-slim
RUN useradd --system --uid 10001 --no-create-home app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
USER app
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

Y la prueba de humo, en `scripts/humo.sh`:

```bash
#!/bin/bash
# humo.sh URL — prueba de humo: espera hasta 30 s a que URL/health responda "ok".
set -euo pipefail
URL="${1:?Uso: humo.sh URL}"
for _ in $(seq 1 15); do
  if curl -fsS -m 2 "$URL/health" 2>/dev/null | grep -q '"ok"'; then
    echo "OK: $URL responde"
    exit 0
  fi
  sleep 2
done
echo "FALLO: $URL no responde" >&2
exit 1
```

Antes de automatizar nada, comprueba que todo funciona **a mano**. Un pipeline no arregla lo que no funciona en tu máquina:

```bash
python3 -m venv .venv && .venv/bin/pip install -q -r requirements-dev.txt
.venv/bin/python -m pytest -v
ruff check .
docker build -t saludo:local . && docker run -d --name saludo -p 8000:8000 saludo:local
bash scripts/humo.sh http://127.0.0.1:8000
docker rm -f saludo
```

### 2. El workflow de CI (20 min)

Borra el `hola.yml` de la clase 82 (ya cumplió) y crea `.github/workflows/ci.yml`:

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0
        with:
          python-version: "3.14"
      - run: pip install ruff==0.17.0
      - run: ruff check .
      - run: shellcheck scripts/*.sh

  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0
        with:
          python-version: "3.14"
          cache: pip
          cache-dependency-path: requirements-dev.txt
      - run: pip install -r requirements-dev.txt
      - run: pytest -v

  imagen:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - run: docker build -t saludo:ci .
      - run: docker run -d --name saludo -p 8000:8000 -e APP_VERSION="$GITHUB_SHA" saludo:ci
      - run: bash scripts/humo.sh http://127.0.0.1:8000
      - name: Logs del contenedor si algo falló
        if: failure()
        run: docker logs saludo
```

Fíjate en tres cosas:
- `pull_request` y `push` a `main` disparan lo mismo. En el PR, para saber si **se puede** unir; en `main`, para saber que lo que se unió funciona.
- `shellcheck` ya viene en el runner, y `ruff` se instala con su versión fijada (clase 46).
- La prueba de humo es **tu** script: el pipeline ejecuta lo mismo que ejecutarías tú.

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git switch -c ci
git add -A && git commit -m "CI: lint, pruebas e imagen en cada PR" && git push -u origin ci
gh pr create --fill
gh pr checks --watch
```

🔮 **Predice:** ¿cuál de los tres jobs terminará primero? `lint`, en segundos. `imagen` será el último: construir y arrancar un contenedor tarda más. En la página del PR, las tres casillas se pondrán verdes una a una.

Une el PR (`gh pr merge --squash --delete-branch`) y mira cómo el `push` a `main` lanza el pipeline otra vez.

### 3. La caché, en números (10 min)

Abre la ejecución del job `test` del primer PR y la de `main`, y compara el step de `setup-python`:

```bash
gh run list --workflow ci.yml --limit 3
gh run view <id> --log | grep -iE "cache (restored|saved)|Cache hit"
```

La primera vez, la caché se **guarda**; la segunda, se **restaura**, y `pip install` ya no descarga nada. Con dos paquetes no se nota mucho; con las dependencias de Vigía (FastAPI, psycopg, boto3), sí.

### 4. Cancelar lo que sobra (10 min)

```bash
git switch -c prisa
echo "# primera" >> README.md && git commit -qam "uno" && git push -u origin prisa && gh pr create --fill
echo "# segunda" >> README.md && git commit -qam "dos" && git push
sleep 10 && gh run list --branch prisa --limit 4
```

🔮 **Predice:** ¿qué pasa con la ejecución del commit "uno"? Aparece como **cancelada**: `concurrency` con `cancel-in-progress` la paró en cuanto llegó "dos". Cierra el PR sin unir: `gh pr close prisa --delete-branch`.

## Rómpelo

En una rama nueva (`git switch main && git pull && git switch -c roto`), un fallo cada vez, en un PR:

**1. Una prueba rota.** En `tests/test_app.py`, cambia `"ok"` por `"OK"`. ¿Qué job falla y cuáles siguen en verde? Solo `test`: `lint` e `imagen` no dependen de él. Mira el error en `gh pr checks` y en el log, y deshazlo.

**2. Un Bash descuidado.** En `scripts/humo.sh`, quita las comillas de `"$URL/health"`. ¿Qué te dice `shellcheck` en el job `lint`? SC2086: una variable sin comillas puede partirse en varias palabras (clase 19).

**3. La imagen que no arranca.** En el `Dockerfile`, cambia el puerto del `CMD` a `8001`. `docker build` funciona, el contenedor arranca… y la prueba de humo falla, porque nada escucha en el 8000. El step con `if: failure()` te enseña en el log por qué. Ni `ruff` ni `pytest` lo habrían visto: por eso existe el job `imagen`.

Cierra el PR sin unir: `gh pr close roto --delete-branch`.

## Reto

1. Añade un step que publique en el resumen de la ejecución (`$GITHUB_STEP_SUMMARY`) cuántas pruebas pasaron. Pista: `pytest --junit-xml=informe.xml` y un poco de `grep`, o el resumen de `pytest -q` con `tail -1`.
2. Haz que `test` corra con Python 3.13 y 3.14 con una matriz (clase 82). ¿Cuántas casillas aparecen ahora en el PR, y cómo se llaman?
3. ¿Por qué `imagen` no lleva `needs: [lint, test]`? Piensa qué ganarías y qué perderías si lo llevara.

## Destruir al terminar

Nada que destruir. Si te queda algún contenedor de prueba en tu Ubuntu: `docker rm -f saludo`.

## Cierre

En `notas/fase-7/clase-83.md`:

1. ¿Por qué lint, pruebas e imagen van en jobs separados y no en uno solo?
2. ¿Qué hace la caché de `setup-python` y cuándo deja de servir?
3. ¿Qué encontró el job `imagen` que no encontraban ni `ruff` ni `pytest`?
4. **Repaso (clase 82, sin mirar):** ¿cómo pasa un dato de un job a otro?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Corren en **paralelo**, así que el pipeline tarda lo que el más lento y no la suma. Si uno falla, la casilla dice **cuál** sin abrir el log. Y se pueden exigir por separado al proteger `main` (clase 84).

**2.** Guarda los paquetes que descarga `pip` entre ejecuciones, con una clave calculada a partir de `requirements-dev.txt`. Mientras ese archivo no cambie, se restaura y no se descarga nada. Deja de servir cuando cambias las dependencias (la clave cambia y se crea otra caché) o cuando GitHub la borra por no usarla (hay un límite de 10 GB por repositorio).

**3.** Que la aplicación empaquetada no funcionaba: un `CMD` con el puerto equivocado. El código y sus pruebas estaban bien, pero lo que se entrega es la imagen, y solo construirla y arrancarla lo demuestra. Lo mismo pasa con un archivo que falta en el `COPY` o una dependencia que no está en `requirements.txt`.

**4.** Un step escribe `clave=valor` en `$GITHUB_OUTPUT`, el job lo declara en `outputs:`, y el job siguiente, con `needs:`, lo lee como `needs.<job>.outputs.<clave>`. Para archivos, artefactos.

**Reto 3:** con `needs`, la imagen solo se construiría si el lint y las pruebas pasan, lo que ahorra minutos de runner en los PR rotos. A cambio, el pipeline tardaría más (en serie, no en paralelo), y un PR con una prueba rota no te diría si además la imagen está bien. En un repositorio público los minutos son gratis, así que gana el paralelo.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| linter | analizador de estilo y errores |
| smoke test | prueba de humo |
| status check | comprobación de estado (las casillas del PR) |
| dependency cache | caché de dependencias |
| to cancel in progress | cancelar lo que está en curso |

🎙️ *"Every pull request runs lint, unit tests and a container smoke test in parallel jobs, with dependency caching. If anything fails, the failing check tells you exactly which stage broke, and the logs are captured before the runner disappears."*

## Siguiente

[Clase 84 — Comprobaciones obligatorias y leer un job fallido](clase-84-proteger-main.md)
