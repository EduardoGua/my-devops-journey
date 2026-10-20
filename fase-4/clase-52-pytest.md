# Clase 52 — Pruebas con pytest

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

> 💡 **La idea de hoy:** una prueba automática es una pregunta que tu código responde cada vez que la ejecutas: "¿un 301 sigue contando como UP?". Con `pytest`, una prueba es una función `test_…` con un `assert`. Si al cambiar el código rompes algo, lo sabes en segundos y no en producción. Y una buena prueba no depende de internet: si necesita un servidor, lo levanta ella misma en `127.0.0.1`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las funciones de `vigia_mini.py` (clase 42), `cargar_urls` (clase 43), `filtrar.py` con su `main(argv=None)` (clase 48), `revisar()` (clase 49) y `backup.py` (clase 50): hoy las pruebas tú.
> - `with`, las excepciones y `try`/`finally` (clases 43 y 44); las variables de entorno con `os.environ` (clase 50).
> - La lección del `verify.sh` del P2: un test que no puede fallar no prueba nada (clase 37).

> 🔤 **Palabras nuevas de hoy:**
> - **prueba** (*test*): una función que ejecuta tu código y comprueba el resultado.
> - **`assert`**: la comprobación; si es falsa, la prueba falla.
> - ***fixture***: algo que `pytest` prepara para una prueba (una carpeta temporal, un servidor) y limpia después.
> - **`parametrize`**: una prueba que se ejecuta con muchos casos.
> - **prueba frágil** (*flaky test*): la que falla a veces por motivos ajenos a tu código.
> - **servidor falso** (*fake*): un servidor de mentira, dentro de la prueba, que responde lo que tú quieras.

## Objetivo

- Escribir pruebas con `pytest`: funciones `test_…` y `assert`.
- Ejecutarlas, leer un fallo e ir directo a la causa.
- Usar *fixtures*: carpetas temporales (`tmp_path`), variables de entorno (`monkeypatch`) y las tuyas propias.
- Probar muchos casos con `parametrize` y comprobar errores con `pytest.raises`.
- Probar código que hace peticiones HTTP sin depender de internet, con un servidor falso local.

## Por qué importa

Una prueba automática es una pregunta que tu código responde cada vez que la ejecutas: "¿un 301 sigue contando como UP?". Con pruebas puedes cambiar el código sin miedo, porque si rompes algo lo sabes en segundos y no en producción. En la fase 7, GitHub Actions ejecutará tus pruebas en cada pull request, y un PR con pruebas en rojo no se podrá unir a `main`. Y Vigía v1 se entrega con pruebas: las tuyas (al menos 5, criterio de salida) y las de aceptación del curso.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Vas a probar funciones que escribiste en clases anteriores, y en la 6, sin internet.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 45 min); el segundo, las **piezas 5 y 6**, el Rómpelo, el reto y el cierre.

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
pip install pytest
mkdir -p ~/my-devops-journey/labs/clase-52 && cd ~/my-devops-journey/labs/clase-52
cp ../clase-42/vigia_mini.py ../clase-43/cargar_urls.py ../clase-48/filtrar.py ../clase-49/revisar.py .
```

## Las piezas

### Pieza 1 — Una prueba: `test_…` y `assert`

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

**Pruébalo:**

```bash
cat > test_vigia_mini.py <<'EOF'
from vigia_mini import clasificar, disponibilidad, formatear_tiempo


def test_un_200_es_up():
    assert clasificar(200) == "UP"


def test_disponibilidad_mixta():
    assert disponibilidad([200, 503, 200, 0]) == 50.0


def test_disponibilidad_lista_vacia():
    assert disponibilidad([]) == 0.0


def test_formatear_tiempo_en_ms_y_s():
    assert formatear_tiempo(0.2614) == "261 ms"
    assert formatear_tiempo(0.2614, unidad="s") == "0.261 s"
EOF
pytest -v
pytest -v -k disponibilidad
```

👀 **Qué deberías ver:** cuatro líneas `test_vigia_mini.py::test_… PASSED` y `4 passed`. Con `-k disponibilidad`, solo las dos que llevan esa palabra en el nombre (`2 passed, 2 deselected`).

✋ **Sin mirar:** ¿qué dos condiciones tiene que cumplir una prueba para que `pytest` a secas la encuentre?

<details>
<summary>Comprueba</summary>

Estar en un archivo que empiece por `test_` y ser una función cuyo nombre empiece por `test_`.
</details>

**En resumen:** una prueba es una función `test_…` con `assert` en un archivo `test_*.py`; `pytest -v` las ejecuta y dice cuál pasa.

### Pieza 2 — Muchos casos con `parametrize`, y ver fallar una prueba

```python
import pytest

@pytest.mark.parametrize("codigo, esperado", [(200, "UP"), (301, "UP"), (404, "DOWN"), (0, "DOWN")])
def test_clasificar(codigo, esperado):
    assert clasificar(codigo) == esperado
```

Una función, cuatro pruebas: si falla el 301, `pytest` dice exactamente cuál. Vas a sustituir `test_un_200_es_up` por una versión con ocho casos.

🔮 **Predice** cuántas pruebas contará `pytest` ahora (cuenta los casos de `parametrize`).

**Pruébalo:**

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

👀 **Qué deberías ver:** `11 passed`: ocho casos de `test_clasificar`, cada uno con su nombre (`test_clasificar[301-UP]`), más las otras tres.

Ahora **rómpelo a propósito**: abre `vigia_mini.py` y cambia `200 <= codigo < 400` por `200 <= codigo < 300`.

```bash
pytest -q
```

👀 **Qué deberías ver:** `2 failed, 9 passed`. Lee el informe: qué prueba falló (`test_clasificar[301-UP]` y `test_clasificar[399-UP]`), qué devolvió y qué esperabas (`assert 'DOWN' == 'UP'`), y en qué línea. Deshaz el cambio y vuelve a ejecutar: todo en verde. Si al romper el código **ninguna** prueba falla, tus pruebas no protegen eso: ahí falta una.

✋ **Sin mirar:** en `assert 'DOWN' == 'UP'`, ¿cuál es el valor que devolvió tu código y cuál el que esperabas?

<details>
<summary>Comprueba</summary>

`'DOWN'` es lo que devolvió `clasificar(301)`; `'UP'` es lo esperado, el lado derecho del `==`.
</details>

**En resumen:** `@pytest.mark.parametrize` convierte una prueba en muchas; el informe de un fallo dice qué caso, qué valor y qué línea.

### Pieza 3 — *Fixtures*: `tmp_path`

Una *fixture* prepara algo para la prueba y lo limpia después. `pytest` trae varias; basta con nombrarlas como parámetro de la prueba:

| Fixture | Te da |
|---------|-------|
| `tmp_path` | una carpeta temporal nueva para cada prueba (un `Path`) |
| `monkeypatch` | cambiar variables de entorno o funciones solo durante la prueba |
| `capsys` | capturar lo que el código imprime |

**Pruébalo:**

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
ls
```

👀 **Qué deberías ver:** `2 passed`, y en `ls` ningún `urls.txt`: los archivos se crearon en carpetas temporales que `pytest` gestiona. La última URL no termina en salto de línea, como en la clase 18: la prueba confirma que tu función la lee igual.

✋ **Sin mirar:** ¿cómo pide una prueba una carpeta temporal?

<details>
<summary>Comprueba</summary>

Poniendo `tmp_path` como parámetro: `def test_algo(tmp_path):`. `pytest` ve el nombre y le pasa un `Path` a una carpeta nueva.
</details>

**En resumen:** una fixture se pide por su nombre como parámetro; `tmp_path` da una carpeta nueva para cada prueba.

### Pieza 4 — Comprobar errores y códigos de salida

```python
def test_porcentaje_con_total_cero():
    with pytest.raises(ValueError, match="total"):
        porcentaje(1, 0)
```

`pytest.raises` hace que la prueba **pase** solo si dentro del `with` se lanza esa excepción; `match` comprueba además el mensaje. Y como `filtrar.py` (clase 48) tiene un `main(argv)` que devuelve el código de salida, se puede probar sin lanzar procesos: `main(["in.json", "out.csv"]) == 0`.

**Pruébalo:**

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

👀 **Qué deberías ver:** `5 passed`. Fíjate en `test_main_escribe_el_csv`: prepara un JSON, llama a `main` con una lista de argumentos inventada y lee el CSV que se escribió. Es el programa entero, probado sin terminal.

✋ **Sin mirar:** ¿cuándo **pasa** una prueba con `with pytest.raises(ValueError):`?

<details>
<summary>Comprueba</summary>

Cuando el código de dentro del `with` lanza un `ValueError`. Si no lanza nada, o lanza otra excepción, la prueba falla.
</details>

**En resumen:** `pytest.raises` prueba que algo falla como debe; `main(argv)` permite probar el programa entero con argumentos inventados.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `source ~/my-devops-journey/labs/.venv/bin/activate` y `cd ~/my-devops-journey/labs/clase-52`.

### Pieza 5 — `monkeypatch`: variables de entorno

`monkeypatch.setenv` y `monkeypatch.delenv` cambian una variable de entorno **solo durante la prueba**: al terminar, todo vuelve a como estaba y tu terminal no se entera.

**Pruébalo:**

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
echo "APP_TIMEOUT en tu terminal: '${APP_TIMEOUT:-}'"
```

👀 **Qué deberías ver:** `2 passed`, y `APP_TIMEOUT en tu terminal: ''`: la variable que puso la prueba no salió de ella. `raising=False` evita un error si la variable ya no existía.

✋ **Sin mirar:** ¿por qué la primera prueba borra `APP_TIMEOUT` antes de comprobar el valor por defecto?

<details>
<summary>Comprueba</summary>

Porque si tu terminal tuviera `APP_TIMEOUT` puesta, la prueba leería ese valor y fallaría. Así cada prueba prepara lo suyo y no depende de tu entorno.
</details>

**En resumen:** `monkeypatch` cambia el entorno solo durante la prueba y lo deshace al terminar.

### Pieza 6 — Un servidor HTTP falso para probar `revisar()`

Una prueba que llama a `https://example.com` falla cuando no hay red o cuando el sitio cambia, aunque tu código esté bien: es una prueba **frágil**. La solución es levantar dentro de la prueba un **servidor HTTP falso** en `127.0.0.1`, que responde lo que tú quieras (200, 404, 500 o tarda 2 segundos). Así funcionan las pruebas de aceptación de Vigía v1.

El servidor lo prepara **tu propia fixture**, con `@pytest.fixture`. Lo de antes del `yield` prepara; lo de después limpia, como un `try`/`finally`. Con `scope="module"`, el servidor se levanta una sola vez para todas las pruebas del archivo.

```python
@pytest.fixture(scope="module")
def servidor():
    srv = ...arrancar...
    yield "http://127.0.0.1:<puerto>"     # esto recibe la prueba
    srv.shutdown()                        # limpieza, al terminar
```

🔮 **Predice:** ¿cuánto tardará? ¿Funcionaría sin internet?

**Pruébalo:**

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
pytest -q
```

👀 **Qué deberías ver:** `6 passed` en alrededor de un segundo: los cuatro códigos, el tiempo agotado (medio segundo, no dos) y el nombre que no existe. Funcionaría sin internet: todo vive en `127.0.0.1`, salvo la última prueba, que consulta a tu resolvedor DNS. Y `pytest -q`, todas juntas: `26 passed`.

✋ **Sin mirar:** en una fixture con `yield`, ¿cuándo se ejecuta lo que va después del `yield`?

<details>
<summary>Comprueba</summary>

Al terminar las pruebas que la usan (aquí, al final del archivo, por el `scope="module"`): es la limpieza, como un `finally`.
</details>

**En resumen:** un servidor falso en `127.0.0.1`, levantado por tu propia fixture, hace las pruebas de red rápidas y deterministas.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `def test_algo(): assert valor == esperado` | una prueba |
| `pytest -v` · `-q` · `-k palabra` · `-x` · `--lf` · `--co` | ejecutar: detalle · resumen · filtrar · parar · repetir fallos · solo listar |
| `@pytest.mark.parametrize("a, b", [(1, 2), (3, 4)])` | muchos casos |
| `with pytest.raises(ValueError, match="texto"):` | comprobar que algo falla |
| `def test_x(tmp_path):` | una carpeta temporal |
| `monkeypatch.setenv("X", "1")` · `monkeypatch.delenv("X", raising=False)` | cambiar el entorno solo en la prueba |
| `@pytest.fixture(scope="module")` + `yield` | tu propia fixture, con limpieza |
| `ThreadingHTTPServer(("127.0.0.1", 0), Manejador)` | un servidor falso en un puerto libre |
| `pytest --durations=3` | las 3 pruebas más lentas |

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

En `labs/clase-52/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escribe `test_backup.py` para el `backup.py` de la clase 50: que `hacer_backup` cree un `.tar.gz` que contiene el archivo original, y que `rotar` borre solo las copias viejas.

> 🧩 **Ejemplo resuelto:** `test_ignora_comentarios_vacias_y_espacios` de la pieza 3: crea archivos dentro de `tmp_path`, llama a la función y compara con el resultado exacto.

**Ahora tú, con huecos** (antes, `cp ../clase-50/backup.py .`):
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
    assert "____" in tarfile.open(archivo).getnames()


def test_rotar_borra_solo_las_viejas(tmp_path):
    vieja = tmp_path / "datos-vieja.tar.gz"
    nueva = tmp_path / "datos-nueva.tar.gz"
    vieja.touch()
    nueva.touch()
    hace_10_dias = time.time() - 10 * 86400
    os.utime(vieja, (hace_10_dias, hace_10_dias))
    assert rotar(tmp_path, "datos", dias=7) == ____
    assert not vieja.exists() and nueva.____()
```

<details>
<summary>Pista</summary>

`os.utime(ruta, (viejo, viejo))` cambia la fecha de un archivo, como `touch -d` en la clase 50. `tarfile.open(ruta).getnames()` lista lo que hay dentro con las mismas rutas que te dio `tar -tzf` en la pieza 4 de la clase 50.
</details>

**2.** Añade a `test_filtrar.py` pruebas para `--estado UP`, para un JSON que no es una lista y para un CSV que no se puede escribir.

> 🧩 **Ejemplo resuelto:** `test_main_escribe_el_csv` y `test_json_invalido_da_valueerror` de la pieza 4.

**Ahora tú, con huecos:**
```python
def test_main_estado_up(tmp_path):
    entrada, salida = tmp_path / "in.json", tmp_path / "out.csv"
    entrada.write_text(json.dumps(CHEQUEOS), encoding="utf-8")
    assert main([str(entrada), str(salida), "--estado", "____"]) == 0
    with open(salida, newline="", encoding="utf-8") as f:
        assert [fila["url"] for fila in csv.DictReader(f)] == ["____"]


def test_json_que_no_es_lista(tmp_path):
    archivo = tmp_path / "dicc.json"
    archivo.write_text('{"url": "a"}', encoding="utf-8")
    with pytest.raises(ValueError, match="____"):
        leer_chequeos(archivo)


def test_csv_que_no_se_puede_escribir(tmp_path):
    entrada = tmp_path / "in.json"
    entrada.write_text(json.dumps(CHEQUEOS), encoding="utf-8")
    assert main([str(entrada), str(tmp_path / "no-existe" / "x.csv")]) == ____
```

<details>
<summary>Pista</summary>

Mira en `filtrar.py` qué mensaje lanza `leer_chequeos` cuando el JSON no es una lista, y qué devuelve `main` en el `except OSError`. La carpeta `no-existe` no existe, así que el CSV no se puede crear.
</details>

**3.** Ejecuta `pytest --durations=3`. ¿Cuáles son tus pruebas más lentas y por qué?

> 🧩 **Ejemplo resuelto:** cada línea dice el tiempo, la fase y la prueba. Por ejemplo, `0.02s setup test_x.py::test_algo` significaría que preparar sus fixtures tardó 0,02 s; `call` es la prueba en sí y `teardown`, la limpieza.

**Ahora tú, con huecos:** completa «La más lenta es ____ (fase `call`), porque espera ____. La otra es el `teardown` de ____, porque `srv.shutdown()` espera ____».

<details>
<summary>Pista</summary>

Mira qué `timeout` usa `test_timeout`. Y `serve_forever` comprueba cada medio segundo si le han pedido parar: `shutdown()` espera a esa comprobación.
</details>

## Cierre

En `notas/fase-4/clase-52.md`:

1. ¿Cómo encuentra `pytest` las pruebas? ¿Qué pasa si un archivo no empieza por `test_`? *(2 líneas. Empieza así: «Busca archivos `test_*.py` y, dentro, funciones… Si el archivo se llama de otra forma, `pytest` a secas…»)*
2. ¿Para qué sirven `tmp_path` y `monkeypatch`? *(2 líneas. Empieza así: «`tmp_path` da a cada prueba… `monkeypatch` cambia… y lo deshace…»)*
3. ¿Por qué no conviene que una prueba dependa de internet? ¿Qué haces en su lugar? *(2 líneas. Empieza así: «Porque puede fallar por motivos que no son mi código, como… En su lugar, levanto…»)*
4. **Repaso (clase 51, sin mirar):** ¿por qué se pasan los valores de una consulta SQL con `?`? *(1 línea. Empieza así: «Para que la base de datos trate el valor siempre como…»)*

Después, escríbeme `examíname clase-52`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Busca archivos `test_*.py` (o `*_test.py`) y, dentro, funciones que empiezan por `test_`. Un archivo con otro nombre no se recoge al ejecutar `pytest` a secas, así que esas pruebas no corren y nadie se entera.

**2.** `tmp_path` da a cada prueba una carpeta temporal nueva para crear archivos sin tocar los tuyos. `monkeypatch` cambia variables de entorno, atributos o funciones solo durante la prueba y lo deshace al terminar.

**3.** Porque falla por motivos que no tienen que ver con tu código (sin red, el sitio cambió, el límite de peticiones), y una prueba que falla "a veces" acaba ignorada. En su lugar, un servidor HTTP falso local que responde lo que necesitas, o sustituir la llamada de red con `monkeypatch`.

**4.** Para que la base de datos trate el valor siempre como dato y nunca como SQL, lo que evita la inyección SQL.

**Reto 1:** `"datos/a.txt"`, `== 1` y `nueva.exists()`.

**Reto 2:** `"UP"` y `["https://a.com"]`; `match="debe contener una lista"`; y `== 2`.

**Reto 3:** `test_revisar.py::test_timeout`, unos 0,5 s, porque espera a que se agote el `timeout=0.5`; y el `teardown` de la fixture `servidor` (aparece junto a la última prueba que la usó o la última del archivo), otros 0,5 s, porque `shutdown()` espera a que `serve_forever` compruebe si debe parar, cosa que hace cada medio segundo.
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
