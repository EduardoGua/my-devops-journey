# Clase 52 — Pruebas con pytest

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

## Objetivo

- Escribir pruebas con `pytest`: funciones `test_…` y `assert`.
- Ejecutarlas, leer un fallo e ir directo a la causa.
- Usar *fixtures*: carpetas temporales (`tmp_path`), variables de entorno (`monkeypatch`) y las tuyas propias.
- Probar muchos casos con `parametrize` y comprobar errores con `pytest.raises`.
- Probar código que hace peticiones HTTP sin depender de internet, con un servidor falso local.

## Por qué importa

Una prueba automática es una pregunta que tu código responde cada vez que la ejecutas: "¿un 301 sigue contando como UP?". Con pruebas puedes cambiar el código sin miedo, porque si rompes algo lo sabes en segundos y no en producción. En la fase 7, GitHub Actions ejecutará tus pruebas en cada pull request, y un PR con pruebas en rojo no se podrá unir a `main`. Y Vigía v1 se entrega con pruebas: las tuyas (al menos 5, criterio de salida) y las de aceptación del curso.

## Teoría

### Una prueba

```python
# test_vigia_mini.py
from vigia_mini import clasificar

def test_un_200_es_up():
    assert clasificar(200) == "UP"
```

- `pytest` busca archivos `test_*.py` y, dentro, funciones `test_*`.
- `assert` comprueba algo; si es falso, la prueba falla y `pytest` te enseña **qué valores** había.
- Cada prueba sigue tres pasos: preparar, actuar y comprobar.

| Comando | Qué hace |
|---------|----------|
| `pytest` | ejecuta todas las pruebas que encuentre |
| `pytest -v` | una línea por prueba |
| `pytest -k disponibilidad` | solo las que contienen esa palabra |
| `pytest -x` | se detiene en el primer fallo |
| `pytest --lf` | repite solo las que fallaron la última vez |

### Muchos casos con `parametrize`

```python
import pytest

@pytest.mark.parametrize("codigo, esperado", [(200, "UP"), (301, "UP"), (404, "DOWN"), (0, "DOWN")])
def test_clasificar(codigo, esperado):
    assert clasificar(codigo) == esperado
```

Una función, cuatro pruebas: si falla el 301, `pytest` dice exactamente cuál.

### Comprobar que algo falla

```python
def test_porcentaje_con_total_cero():
    with pytest.raises(ValueError, match="total"):
        porcentaje(1, 0)
```

### *Fixtures*: lo que una prueba necesita

Una *fixture* prepara algo para la prueba y lo limpia después. `pytest` trae varias; basta con nombrarlas como parámetro:

| Fixture | Te da |
|---------|-------|
| `tmp_path` | una carpeta temporal nueva para cada prueba (un `Path`) |
| `monkeypatch` | cambiar variables de entorno o funciones solo durante la prueba |
| `capsys` | capturar lo que el código imprime |

Y puedes crear las tuyas con `@pytest.fixture`. Si hace limpieza, usa `yield`: lo de antes prepara y lo de después limpia, como un `try`/`finally`.

### Pruebas que no dependen de internet

Una prueba que llama a `https://example.com` falla cuando no hay red o cuando el sitio cambia, aunque tu código esté bien: es una prueba **frágil**. La solución es levantar dentro de la prueba un **servidor HTTP falso** en `127.0.0.1`, que responde lo que tú quieras (200, 404, 500 o tarda 3 segundos). Así funcionan las pruebas de aceptación de Vigía v1.

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
pip install pytest
mkdir -p ~/my-devops-journey/labs/clase-52 && cd ~/my-devops-journey/labs/clase-52
cp ../clase-42/vigia_mini.py ../clase-43/cargar_urls.py ../clase-48/filtrar.py ../clase-49/revisar.py .
```

Vas a probar funciones que escribiste en clases anteriores.

### 1. Tus primeras pruebas

```bash
cat > test_vigia_mini.py <<'EOF'
import pytest

from vigia_mini import clasificar, disponibilidad, formatear_tiempo


@pytest.mark.parametrize("codigo, esperado", [
    (200, "UP"), (204, "UP"), (301, "UP"), (399, "UP"),
    (400, "DOWN"), (404, "DOWN"), (500, "DOWN"), (0, "DOWN"),
])
def test_clasificar(codigo, esperado):
    assert clasificar(codigo) == esperado


def test_disponibilidad_mixta():
    assert disponibilidad([200, 503, 200, 0]) == 50.0


def test_disponibilidad_lista_vacia():
    assert disponibilidad([]) == 0.0


def test_formatear_tiempo_en_ms_y_s():
    assert formatear_tiempo(0.2614) == "261 ms"
    assert formatear_tiempo(0.2614, unidad="s") == "0.261 s"
EOF
pytest -v
```

🔮 **Predice** cuántas pruebas contará `pytest` (cuenta los casos de `parametrize`).

### 2. Ver fallar una prueba

Rompe el código a propósito: abre `vigia_mini.py` y cambia `200 <= codigo < 400` por `200 <= codigo < 300`.

```bash
pytest -q
```

Lee el informe: qué prueba falló (`test_clasificar[301-UP]`), qué devolvió (`'DOWN'`) y qué esperabas (`'UP'`). Deshaz el cambio y vuelve a ejecutar. Si al romper el código **ninguna** prueba falla, tus pruebas no protegen eso: ahí falta una.

### 3. `tmp_path`: archivos sin ensuciar tu carpeta

```bash
cat > test_cargar_urls.py <<'EOF'
from cargar_urls import cargar_urls


def test_ignora_comentarios_vacias_y_espacios(tmp_path):
    archivo = tmp_path / "urls.txt"
    archivo.write_text("# comentario\nhttps://a.com\n\n   https://b.com  \nhttps://c.com", encoding="utf-8")
    assert cargar_urls(archivo) == ["https://a.com", "https://b.com", "https://c.com"]


def test_archivo_vacio(tmp_path):
    archivo = tmp_path / "urls.txt"
    archivo.write_text("", encoding="utf-8")
    assert cargar_urls(archivo) == []
EOF
pytest -v test_cargar_urls.py
```

La última URL no termina en salto de línea, como en la clase 18: la prueba confirma que tu función la lee igual.

### 4. Probar errores y códigos de salida

`filtrar.py` (clase 48) tiene un `main(argv)` que devuelve el código de salida, así que se puede probar sin lanzar procesos:

```bash
cat > test_filtrar.py <<'EOF'
import csv
import json

import pytest

from filtrar import filtrar, leer_chequeos, main

CHEQUEOS = [
    {"url": "https://a.com", "estado": "UP", "codigo": 200, "segundos": 0.2},
    {"url": "https://b.com", "estado": "DOWN", "codigo": 0, "segundos": 10.0},
]


def test_filtrar_por_estado():
    assert [c["url"] for c in filtrar(CHEQUEOS, "DOWN")] == ["https://b.com"]


def test_filtrar_salta_los_incompletos():
    assert filtrar([{"url": "x"}] + CHEQUEOS, "UP")[0]["url"] == "https://a.com"


def test_json_invalido_da_valueerror(tmp_path):
    roto = tmp_path / "roto.json"
    roto.write_text('[{"url": "a",}]', encoding="utf-8")
    with pytest.raises(ValueError, match="no es JSON válido"):
        leer_chequeos(roto)


def test_main_escribe_el_csv(tmp_path):
    entrada, salida = tmp_path / "in.json", tmp_path / "out.csv"
    entrada.write_text(json.dumps(CHEQUEOS), encoding="utf-8")
    assert main([str(entrada), str(salida)]) == 0
    with open(salida, newline="", encoding="utf-8") as f:
        assert [fila["url"] for fila in csv.DictReader(f)] == ["https://b.com"]


def test_main_sin_archivo_devuelve_2(tmp_path):
    assert main([str(tmp_path / "no-existe.json"), str(tmp_path / "x.csv")]) == 2
EOF
pytest -v test_filtrar.py
```

### 5. `monkeypatch`: variables de entorno

```bash
cat > ajustes.py <<'EOF'
import os


def leer_timeout() -> float:
    """El timeout de la variable APP_TIMEOUT, o 10 si no existe."""
    return float(os.environ.get("APP_TIMEOUT", "10"))
EOF
cat > test_ajustes.py <<'EOF'
from ajustes import leer_timeout


def test_timeout_por_defecto(monkeypatch):
    monkeypatch.delenv("APP_TIMEOUT", raising=False)
    assert leer_timeout() == 10.0


def test_timeout_desde_el_entorno(monkeypatch):
    monkeypatch.setenv("APP_TIMEOUT", "2.5")
    assert leer_timeout() == 2.5
EOF
pytest -q test_ajustes.py
```

`monkeypatch` deshace los cambios al terminar la prueba: tu terminal no se entera.

### 6. Un servidor HTTP falso para probar `revisar()`

```bash
cat > test_revisar.py <<'EOF'
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from revisar import revisar


class Falso(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/lento":
            time.sleep(2)
        codigo = {"/ok": 200, "/redir": 301, "/no-existe": 404, "/error": 500}.get(self.path, 200)
        try:
            self.send_response(codigo)
            self.send_header("Content-Length", "0")
            self.end_headers()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *args):
        pass                                     # sin mensajes en la salida de pytest


@pytest.fixture(scope="module")
def servidor():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), Falso)       # puerto 0: el sistema elige uno libre
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_address[1]}"
    srv.shutdown()


@pytest.mark.parametrize("ruta, codigo, estado", [
    ("/ok", 200, "UP"), ("/redir", 301, "UP"), ("/no-existe", 404, "DOWN"), ("/error", 500, "DOWN"),
])
def test_codigos(servidor, ruta, codigo, estado):
    r = revisar(servidor + ruta, timeout=5)
    assert (r["codigo"], r["estado"], r["error"]) == (codigo, estado, None)


def test_timeout(servidor):
    r = revisar(servidor + "/lento", timeout=0.5)
    assert (r["codigo"], r["estado"], r["error"]) == (0, "DOWN", "timeout")
    assert r["segundos"] < 1.5


def test_nombre_que_no_existe():
    r = revisar("http://no-existe.invalid/", timeout=5)
    assert r["estado"] == "DOWN" and r["error"] == "connection"
EOF
time pytest -v test_revisar.py
```

🔮 **Predice:** ¿cuánto tardará? ¿Funcionaría sin internet? (Solo la última prueba, la del DNS, consulta a tu resolvedor: el resto vive en `127.0.0.1`.)

### 7. Todas juntas

```bash
pytest -q
```

## Rómpelo

**1. Una prueba que no puede fallar:**
```bash
cat > test_inutil.py <<'EOF'
from vigia_mini import clasificar

def test_clasificar_funciona():
    resultado = clasificar(404)
    assert resultado
EOF
pytest -q test_inutil.py
```
Pasa, pero no comprueba nada: `"DOWN"` y `"UP"` son textos no vacíos, así que `assert resultado` siempre es verdadero. Rompe `clasificar` para que devuelva siempre `"UP"`: la prueba sigue en verde. Es la lección del `verify.sh` del P2: **un test que no puede fallar no prueba nada**. Compara siempre con el valor exacto (`== "DOWN"`). Borra `test_inutil.py`.

**2. El nombre que `pytest` no ve:**
```bash
cat > comprobaciones.py <<'EOF'
def test_algo():
    assert 1 == 2
EOF
pytest -q comprobaciones.py ; pytest -q --co
```
Con `pytest comprobaciones.py` se ejecuta porque lo nombraste, pero `pytest` a secas **no lo encuentra**: el archivo no empieza por `test_`. `--co` (*collect only*) lista las pruebas sin ejecutarlas. Borra `comprobaciones.py`.

**3. Pruebas que dependen unas de otras:**
```bash
cat > test_orden.py <<'EOF'
vistos = []

def test_primero():
    vistos.append("a")
    assert vistos == ["a"]

def test_segundo():
    assert vistos == ["a"]
EOF
pytest -q test_orden.py ; pytest -q test_orden.py -k segundo
```
Juntas pasan; sola, la segunda falla, porque dependía de que la primera hubiera modificado una variable compartida. Cada prueba debe preparar lo suyo (para eso están las fixtures). Borra `test_orden.py`.

## Reto

1. Escribe `test_backup.py` para el `backup.py` de la clase 50: que `hacer_backup` cree un `.tar.gz` que contiene el archivo original, y que `rotar` borre solo las copias viejas. Pista: `os.utime(ruta, (viejo, viejo))` cambia la fecha de un archivo, y `tarfile.open(ruta).getnames()` lista lo que hay dentro.
2. Añade a `test_filtrar.py` pruebas para `--estado UP`, para un JSON que no es una lista y para un CSV que no se puede escribir (`tmp_path / "no-existe" / "x.csv"`).
3. Ejecuta `pytest --durations=3`. ¿Cuáles son tus pruebas más lentas y por qué?

## Cierre

En `notas/fase-4/clase-52.md`:

1. ¿Cómo encuentra `pytest` las pruebas? ¿Qué pasa si un archivo no empieza por `test_`?
2. ¿Para qué sirven `tmp_path` y `monkeypatch`?
3. ¿Por qué no conviene que una prueba dependa de internet? ¿Qué haces en su lugar?
4. **Repaso (clase 51, sin mirar):** ¿por qué se pasan los valores de una consulta SQL con `?`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Busca archivos `test_*.py` (o `*_test.py`) y, dentro, funciones que empiezan por `test_`. Un archivo con otro nombre no se recoge al ejecutar `pytest` a secas, así que esas pruebas no corren y nadie se entera.

**2.** `tmp_path` da a cada prueba una carpeta temporal nueva para crear archivos sin tocar los tuyos. `monkeypatch` cambia variables de entorno, atributos o funciones solo durante la prueba y lo deshace al terminar.

**3.** Porque falla por motivos que no tienen que ver con tu código (sin red, el sitio cambió, el límite de peticiones), y una prueba que falla "a veces" acaba ignorada. En su lugar, un servidor HTTP falso local que responde lo que necesitas, o sustituir la llamada de red con `monkeypatch`.

**4.** Para que la base de datos trate el valor siempre como dato y nunca como SQL, lo que evita la inyección SQL.

**Reto 1 (una solución):**
```python
import os
import tarfile
import time

from backup import hacer_backup, rotar


def test_hacer_backup_incluye_los_archivos(tmp_path):
    origen = tmp_path / "datos"
    origen.mkdir()
    (origen / "a.txt").write_text("hola", encoding="utf-8")
    archivo = hacer_backup(origen, tmp_path / "copias")
    assert archivo.name.startswith("datos-") and archivo.name.endswith(".tar.gz")
    assert "datos/a.txt" in tarfile.open(archivo).getnames()


def test_rotar_borra_solo_las_viejas(tmp_path):
    vieja = tmp_path / "datos-vieja.tar.gz"
    nueva = tmp_path / "datos-nueva.tar.gz"
    vieja.touch()
    nueva.touch()
    hace_10_dias = time.time() - 10 * 86400
    os.utime(vieja, (hace_10_dias, hace_10_dias))
    assert rotar(tmp_path, "datos", dias=7) == 1
    assert not vieja.exists() and nueva.exists()
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| unit test / test suite | prueba unitaria / conjunto de pruebas |
| assertion | comprobación |
| fixture | preparación de una prueba |
| flaky test | prueba frágil (falla a veces) |
| test double / fake | doble de prueba / falso |

🎙️ *"My tests don't depend on the internet: I spin up a local fake HTTP server, so they're fast, deterministic and run the same in CI."*

## Siguiente

[Clase 53 — Una API mínima con FastAPI](clase-53-fastapi.md)
