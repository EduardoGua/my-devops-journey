# Clase 47 — JSON, CSV y YAML

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

> 💡 **La idea de hoy:** casi todo lo que no es código en DevOps son **datos con estructura**: la respuesta de una API y la salida de la AWS CLI son **JSON**; la configuración de Docker Compose, Kubernetes o GitHub Actions es **YAML**; y el informe que se abre en una hoja de cálculo es **CSV**. Python convierte los tres en las listas y diccionarios de la clase 41, y de vuelta, en pocas líneas.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Listas, diccionarios y comprensiones (clase 41).
> - Leer y escribir archivos con `with open` y `encoding="utf-8"` (clase 43).
> - `try` / `except`, mensajes por stderr y el código 2 (clase 44).
> - El entorno de `labs` y `pip install` (clase 46).
> - La sangría con espacios de YAML (clase 37, el `cloud-init.yaml`).

> 🔤 **Palabras nuevas de hoy:**
> - **JSON**: el formato de las APIs: objetos `{}`, arrays `[]`, textos con comillas dobles, `true`, `false` y `null`.
> - **CSV**: filas de valores separados por comas, con una fila de cabecera.
> - **YAML**: el formato de configuración escrito por personas, con sangría y comentarios.
> - **`json.load` / `json.dump`**: de archivo a Python / de Python a archivo.
> - **`yaml.safe_load`**: la forma segura de leer YAML.
> - **`jq`**: la herramienta de terminal para filtrar JSON.

## Objetivo

- Leer y escribir **JSON**, el formato de las APIs y de la AWS CLI.
- Leer y escribir **CSV**, el formato de los informes y las hojas de cálculo.
- Leer **YAML** con seguridad, el formato de la configuración en Docker Compose, Kubernetes y GitHub Actions, y esquivar sus trampas.
- Escribir un programa que lee un JSON, filtra los datos y escribe un CSV, con manejo de errores. Es un criterio de salida de esta fase.

## Por qué importa

En DevOps, casi todo lo que no es código es **datos estructurados**: la respuesta de una API (JSON), la salida de `aws ec2 describe-instances` (JSON), un `docker-compose.yaml`, un manifiesto de Kubernetes o un workflow de GitHub Actions (YAML), y el informe que te pide tu jefe para abrirlo en una hoja de cálculo (CSV). Convertir de uno a otro, filtrar y validar es trabajo diario, y en Python son pocas líneas.

## Cómo va esta clase

Cuatro piezas: una por formato y una última con el criterio de salida, de JSON a CSV. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, la **pieza 4**, el Rómpelo, el reto y el cierre.

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
pip install PyYAML
mkdir -p ~/my-devops-journey/labs/clase-47 && cd ~/my-devops-journey/labs/clase-47
```

## Las piezas

### Pieza 1 — JSON ⇄ Python

| JSON | Python |
|------|--------|
| `{"clave": valor}` (objeto) | `dict` |
| `[1, 2, 3]` (array) | `list` |
| `"texto"` | `str` |
| `200`, `0.26` | `int`, `float` |
| `true` / `false` | `True` / `False` |
| `null` | `None` |

```python
import json

with open("servidores.json", encoding="utf-8") as f:
    servidores = json.load(f)              # archivo → objetos de Python
texto = json.dumps(servidores, indent=2, ensure_ascii=False)   # objetos → texto bonito
datos = json.loads('{"codigo": 200}')       # texto → objetos ("s" de string)
with open("salida.json", "w", encoding="utf-8") as f:
    json.dump(servidores, f, indent=2, ensure_ascii=False)     # objetos → archivo
```

`ensure_ascii=False` escribe las tildes tal cual (`Vigía`) en lugar de `Vigía`. JSON es estricto: comillas **dobles**, ninguna coma al final de la última clave y nada de comentarios.

**Pruébalo: leer, filtrar y volver a escribir.**

```bash
cat > chequeos.json <<'EOF'
[
  {"url": "https://example.com",  "estado": "UP",   "codigo": 200, "segundos": 0.21},
  {"url": "https://github.com",   "estado": "UP",   "codigo": 200, "segundos": 0.95},
  {"url": "https://caido.dev",    "estado": "DOWN", "codigo": 0,   "segundos": 10.0},
  {"url": "https://example.com/x","estado": "DOWN", "codigo": 404, "segundos": 0.18},
  {"url": "https://wikipedia.org","estado": "UP",   "codigo": 301, "segundos": 0.33}
]
EOF
python3 -m json.tool chequeos.json | head -8
jq '.[] | select(.estado == "DOWN") | .url' chequeos.json
python3 -c '
import json
with open("chequeos.json", encoding="utf-8") as f:
    chequeos = json.load(f)
print(type(chequeos), len(chequeos), type(chequeos[0]))
caidos = [c for c in chequeos if c["estado"] == "DOWN"]
print(json.dumps(caidos, indent=2, ensure_ascii=False))
'
```

👀 **Qué deberías ver:** el JSON formateado (`python3 -m json.tool` lo valida y lo ordena); con `jq`, las dos URLs caídas entre comillas; y en Python, `<class 'list'> 5 <class 'dict'>` y los dos chequeos `DOWN`, con sangría de 2 espacios.

`jq`, que ya tienes instalado, filtra JSON desde la terminal y es muy útil con la salida de la AWS CLI (fase 6). Para transformaciones más largas, Python.

✋ **Sin mirar:** ¿qué devuelve `json.loads('{"ok": true, "error": null}')`?

<details>
<summary>Comprueba</summary>

El diccionario `{'ok': True, 'error': None}`.
</details>

**En resumen:** `json.load` / `json.loads` convierten JSON en diccionarios y listas; `json.dump` / `json.dumps`, al revés.

### Pieza 2 — CSV

```python
import csv

with open("informe.csv", "w", newline="", encoding="utf-8") as f:
    escritor = csv.DictWriter(f, fieldnames=["url", "estado", "segundos"])
    escritor.writeheader()
    escritor.writerow({"url": "https://example.com", "estado": "UP", "segundos": 0.26})

with open("informe.csv", newline="", encoding="utf-8") as f:
    for fila in csv.DictReader(f):          # cada fila es un diccionario de textos
        print(fila["url"], fila["estado"])
```

- `newline=""` lo pide la documentación de `csv` para que los saltos de línea dentro de un campo se escriban bien.
- Todo lo que lees de un CSV es **texto**: `float(fila["segundos"])` para hacer cuentas.
- El módulo se encarga de las comillas cuando un campo contiene comas.

**Pruébalo:**

```bash
python3 -c '
import csv
with open("informe.csv", "w", newline="", encoding="utf-8") as f:
    escritor = csv.DictWriter(f, fieldnames=["url", "estado", "segundos"])
    escritor.writeheader()
    escritor.writerow({"url": "https://example.com", "estado": "UP", "segundos": 0.26})
    escritor.writerow({"url": "https://a.com/?x=1,2", "estado": "DOWN", "segundos": 10})
with open("informe.csv", newline="", encoding="utf-8") as f:
    for fila in csv.DictReader(f):
        print(fila["url"], fila["estado"], repr(fila["segundos"]))
'
cat informe.csv
```

👀 **Qué deberías ver:** cada fila leída, con `'0.26'` y `'10'` **entre comillas**: son textos. Y en el archivo, la URL que tiene una coma va entre comillas dobles (`"https://a.com/?x=1,2"`): el módulo lo hizo por ti.

✋ **Sin mirar:** lees `fila["segundos"]` de un CSV y vale `0.26`. ¿Qué tipo tiene?

<details>
<summary>Comprueba</summary>

`str`: en un CSV todo es texto. Para hacer cuentas, `float(fila["segundos"])`.
</details>

**En resumen:** `csv.DictWriter` escribe filas desde diccionarios y `csv.DictReader` las lee como diccionarios de textos.

### Pieza 3 — YAML, con `safe_load`

```yaml
# config.yaml: la configuración de un programa
timeout: 10
urls:
  - https://example.com
  - https://github.com
aviso:
  dias_certificado: 14
```

```python
import yaml                                   # paquete PyYAML: pip install PyYAML

with open("config.yaml", encoding="utf-8") as f:
    config = yaml.safe_load(f)                # → {'timeout': 10, 'urls': [...], 'aviso': {...}}
```

- **Usa siempre `yaml.safe_load`.** El viejo `yaml.load` podía construir objetos arbitrarios de Python a partir del archivo, lo que permite ejecutar código si el YAML viene de otra persona. En PyYAML 6, `yaml.load` sin más ni siquiera funciona.
- La sangría (con espacios, **nunca** tabuladores) define la estructura, como en Python.
- YAML adivina tipos, y a veces adivina mal (Rómpelo 3).

**Pruébalo: la configuración de un programa.**

```bash
cat > config.yaml <<'EOF'
# Configuración de prueba, con el formato que usará Vigía
timeout: 10
database: vigia.db
urls:
  - https://example.com
  - https://github.com
EOF
python3 -c '
import yaml
with open("config.yaml", encoding="utf-8") as f:
    config = yaml.safe_load(f)
print(config)
print(type(config["timeout"]), config["urls"][0])
'
```

👀 **Qué deberías ver:** `{'timeout': 10, 'database': 'vigia.db', 'urls': ['https://example.com', 'https://github.com']}` y `<class 'int'> https://example.com`: `yaml.safe_load` devuelve diccionarios, listas, números y textos de Python, igual que `json.load`.

✋ **Sin mirar:** ¿qué carácter no se puede usar nunca para sangrar en YAML?

<details>
<summary>Comprueba</summary>

El tabulador: la sangría de YAML va siempre con espacios.
</details>

**En resumen:** `yaml.safe_load` lee YAML como diccionarios y listas; sangría con espacios y, ante la duda, comillas.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `source ~/my-devops-journey/labs/.venv/bin/activate`.

### Pieza 4 — El criterio de salida: de JSON a CSV, con los errores bien tratados

Un programa de verdad: lee un JSON, filtra por estado y escribe un CSV, y cualquier error esperable (archivo que no existe, JSON roto, chequeo incompleto, carpeta de salida que no existe) se explica en una línea, sin traza. La estructura: tres funciones pequeñas que hacen una cosa cada una (leer, filtrar, escribir) y un `main()` que decide qué hacer con los errores y **devuelve** el código de salida.

**Pruébalo:**

```bash
cat > filtrar.py <<'EOF'
#!/usr/bin/env python3
"""filtrar.py: lee chequeos de un JSON, filtra por estado y escribe un CSV.

Uso: filtrar.py <entrada.json> <salida.csv> [ESTADO]     (por defecto, DOWN)
"""
import csv
import json
import sys
from pathlib import Path

CAMPOS = ["url", "estado", "codigo", "segundos"]


def leer_chequeos(ruta: Path) -> list[dict]:
    """Devuelve la lista de chequeos del JSON. Lanza ValueError si no se puede usar."""
    try:
        with open(ruta, encoding="utf-8") as f:
            datos = json.load(f)
    except OSError as e:
        raise ValueError(f"no puedo leer {ruta}: {e.strerror}")
    except json.JSONDecodeError as e:
        raise ValueError(f"{ruta} no es JSON válido (línea {e.lineno}, columna {e.colno}): {e.msg}")
    if not isinstance(datos, list):
        raise ValueError(f"{ruta} debe contener una lista de chequeos")
    return datos


def filtrar(chequeos: list[dict], estado: str) -> list[dict]:
    """Los chequeos con ese estado; avisa y salta los que no tienen los campos."""
    elegidos = []
    for posicion, chequeo in enumerate(chequeos):
        if not isinstance(chequeo, dict) or not all(campo in chequeo for campo in CAMPOS):
            print(f"aviso: el chequeo {posicion} no tiene los campos {CAMPOS}, lo salto", file=sys.stderr)
            continue
        if chequeo["estado"] == estado:
            elegidos.append({campo: chequeo[campo] for campo in CAMPOS})
    return elegidos


def escribir_csv(filas: list[dict], ruta: Path) -> None:
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=CAMPOS)
        escritor.writeheader()
        escritor.writerows(filas)


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    entrada, salida = Path(sys.argv[1]), Path(sys.argv[2])
    estado = sys.argv[3] if len(sys.argv) == 4 else "DOWN"
    try:
        filas = filtrar(leer_chequeos(entrada), estado)
        escribir_csv(filas, salida)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"Error: no puedo escribir {salida}: {e.strerror}", file=sys.stderr)
        return 2
    print(f"{len(filas)} chequeos {estado} escritos en {salida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
python3 filtrar.py chequeos.json caidos.csv ; echo "código: $?"
cat caidos.csv
python3 filtrar.py chequeos.json arriba.csv UP && cat arriba.csv
```

🔮 **Predice** qué filas tendrá `caidos.csv`.

👀 **Qué deberías ver:** `2 chequeos DOWN escritos en caidos.csv` y `código: 0`; el CSV con la cabecera `url,estado,codigo,segundos` y las dos filas caídas; y después, los 3 chequeos `UP` en `arriba.csv`.

`sys.exit(main())` entrega al sistema el número que devuelve `main()`. `__doc__` es el docstring del módulo: el script imprime su propia línea de uso.

**Ahora, los casos difíciles:**

```bash
python3 filtrar.py no-existe.json x.csv ; echo "código: $?"
printf '[{"url": "a", "estado": "DOWN",}]' > roto.json
python3 filtrar.py roto.json x.csv ; echo "código: $?"
printf '[{"url": "a"}, {"url": "b", "estado": "DOWN", "codigo": 0, "segundos": 1}]' > incompleto.json
python3 filtrar.py incompleto.json x.csv ; echo "código: $?"
python3 filtrar.py chequeos.json /no-existe/x.csv ; echo "código: $?"
python3 filtrar.py ; echo "código: $?"
```

👀 **Qué deberías ver:** ninguna traza. Cada error en una línea, en stderr, con código 2: `no puedo leer no-existe.json: No such file or directory`, `roto.json no es JSON válido (línea 1, columna …): Illegal trailing comma…`, `no puedo escribir /no-existe/x.csv…` y la línea de uso. El incompleto genera un **aviso** para el chequeo 0, procesa el 1 y termina con `1 chequeos DOWN escritos` y código 0.

✋ **Sin mirar:** ¿por qué `main()` devuelve un número y se llama con `sys.exit(main())`?

<details>
<summary>Comprueba</summary>

Para que el código de salida (0 bien, 2 error controlado) llegue al sistema: así lo ven tu shell, cron o un pipeline. Y `main()` sigue siendo una función normal, fácil de probar.
</details>

**En resumen:** leer, filtrar y escribir en funciones pequeñas; los errores esperables, en un mensaje y un código 2; y `sys.exit(main())`.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `json.load(f)` · `json.loads(texto)` | JSON → Python |
| `json.dump(x, f, indent=2, ensure_ascii=False)` · `json.dumps(x, …)` | Python → JSON |
| `python3 -m json.tool archivo.json` | validar y formatear un JSON |
| `jq '.[] \| select(.estado == "DOWN") \| .url' archivo.json` | filtrar JSON en la terminal |
| `csv.DictWriter(f, fieldnames=[…])` · `.writeheader()` · `.writerow(d)` | escribir un CSV |
| `csv.DictReader(f)` | leer un CSV fila a fila, como diccionarios de textos |
| `open(…, newline="", encoding="utf-8")` | abrir un CSV |
| `yaml.safe_load(f)` | leer YAML de forma segura |
| `except json.JSONDecodeError as e:` · `e.lineno`, `e.colno`, `e.msg` | un JSON roto, y dónde |

| Formato | Lo usa | Ventaja | Cuidado con |
|---------|--------|---------|-------------|
| JSON | APIs, AWS CLI, logs estructurados | estricto y universal | sin comentarios |
| YAML | configuración escrita por personas | legible y con comentarios | la sangría y los tipos adivinados |
| CSV | informes, hojas de cálculo | lo abre cualquiera | todo es texto, sin estructura anidada |

## Rómpelo

**1. Un JSON con coma de más:**
```bash
python3 -c 'import json; json.loads("{\"a\": 1,}")'
```
`json.decoder.JSONDecodeError: Illegal trailing comma before end of object: line 1 column 8 (char 7)`. La línea y la columna te llevan al sitio exacto. También fallan las comillas simples (`{'a': 1}`): eso es un diccionario de Python, no JSON.

**2. Un tabulador en el YAML:**
```bash
printf 'urls:\n\t- https://example.com\n' > tab.yaml
python3 -c 'import yaml; yaml.safe_load(open("tab.yaml"))'
```
`found character '\t' that cannot start any token`. YAML prohíbe los tabuladores para sangrar. Configura tu editor para insertar espacios (VS Code lo hace por defecto en `.yaml`).

**3. Los tipos que YAML adivina:**
```bash
cat > trampas.yaml <<'EOF'
pais: NO
version: 3.10
hora: 1:30
permisos: 0755
texto: "NO"
EOF
python3 -c 'import yaml; print(yaml.safe_load(open("trampas.yaml")))'
```
🔮 **Predice** antes de ejecutar. Sale `{'pais': False, 'version': 3.1, 'hora': 90, 'permisos': 493, 'texto': 'NO'}`. PyYAML sigue la especificación YAML 1.1: `NO`, `no`, `on` y `off` son booleanos (el "problema de Noruega", por el código del país), `3.10` es un decimal, `1:30` es base 60 y `0755` es octal. La regla: **entre comillas todo lo que deba ser texto** (versiones, códigos de país, permisos y horas).

**4. El `load` inseguro:**
```bash
python3 -c 'import yaml; yaml.load("a: 1")'
```
`TypeError: load() missing 1 required positional argument: 'Loader'`. PyYAML 6 ya no deja usar `load` sin elegir explícitamente cómo cargar. Usa `safe_load`.

## Reto

En `labs/clase-47/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** `csv_a_json.py <entrada.csv> <salida.json>`: convierte el `caidos.csv` de la pieza 4 en JSON, con `codigo` como entero y `segundos` como decimal (no como texto).

> 🧩 **Ejemplo resuelto:** leer el CSV y ver los textos: `for fila in csv.DictReader(f): print(fila)` → `{'url': '…', 'estado': 'DOWN', 'codigo': '0', 'segundos': '10.0'}`.

**Ahora tú, con huecos:**
```python
import csv
import json
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as f:
    filas = [
        fila | {"codigo": ____(fila["codigo"]), "segundos": ____(fila["segundos"])}
        for fila in csv.DictReader(f)
    ]
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.____(filas, f, indent=2, ensure_ascii=False)
```

<details>
<summary>Pista</summary>

`fila | {...}` une dos diccionarios: los valores de la derecha reemplazan a los de la izquierda. Las conversiones son las de la clase 39.
</details>

**2.** Añade a `filtrar.py` una quinta columna calculada, `ms`, con los segundos en milisegundos y sin decimales.

> 🧩 **Ejemplo resuelto:** un campo calculado al construir un diccionario: `{"url": c["url"], "lento": c["segundos"] > 1}`.

**Ahora tú, con huecos:** añade `"ms"` a `CAMPOS` y, en `filtrar`, cambia el `append` por:
```python
elegidos.append({campo: chequeo[campo] for campo in CAMPOS if campo != "ms"} | {"ms": round(chequeo["segundos"] * ____)})
```
Cuidado: la comprobación `all(campo in chequeo for campo in CAMPOS)` también tiene que saltarse `"ms"`.

<details>
<summary>Pista</summary>

`ms` no viene en el JSON: lo calculas tú. Por eso se excluye al copiar los campos y al comprobar que están todos.
</details>

**3.** `validar_config.py config.yaml`: comprueba que `urls` es una lista no vacía de textos que empiezan por `http://` o `https://`, y que `timeout` es un número positivo. Sale con 0 si todo está bien o con 2 y un mensaje por cada problema. Pruébalo con tres archivos rotos de formas distintas.

> 🧩 **Ejemplo resuelto:** la comprobación de `timeout`.
> ```python
> problemas = []
> timeout = config.get("timeout")
> if not isinstance(timeout, (int, float)) or timeout <= 0:
>     problemas.append(f"timeout debe ser un número positivo, no {timeout!r}")
> ```

**Ahora tú, con huecos:**
```python
urls = config.get("urls")
if not isinstance(urls, ____) or not urls:
    problemas.append("urls debe ser una lista no vacía")
else:
    for url in urls:
        if not isinstance(url, str) or not url.startswith((____, ____)):
            problemas.append(f"url no válida: {url!r}")
for p in problemas:
    print(f"Error: {p}", file=sys.stderr)
sys.exit(2 if problemas else ____)
```

<details>
<summary>Pista</summary>

`isinstance(x, list)` comprueba el tipo. `startswith` acepta una tupla de prefijos (clase 43).
</details>

**4.** Con `jq`, saca de `chequeos.json` la media de `segundos` de los chequeos `UP`.

> 🧩 **Ejemplo resuelto:** las URLs de los caídos, como en la pieza 1: `jq '.[] | select(.estado == "DOWN") | .url' chequeos.json`.

**Ahora tú, con huecos:** `jq 'map(select(.estado == "____") | .____) | add / length' chequeos.json`

<details>
<summary>Pista</summary>

`map(…)` crea una lista con los segundos de los `UP`; `add` los suma y `length` cuenta cuántos hay.
</details>

## Cierre

En `notas/fase-4/clase-47.md`:

1. ¿Qué tipos de Python corresponden a un objeto, un array, `true` y `null` de JSON? *(1 línea. Empieza así: «Objeto → `dict`, array →…»)*
2. ¿Por qué se usa `yaml.safe_load` y no `yaml.load`? *(2 líneas. Empieza así: «Porque `yaml.load` podía construir objetos de Python descritos en el propio archivo, y un YAML malicioso…»)*
3. Da dos ejemplos de valores que YAML convierte de forma inesperada y cómo lo evitas. *(2 líneas. Empieza así: «`NO` se convierte en… y `3.10` en… Lo evito poniendo…»)*
4. **Repaso (clase 46, sin mirar):** ¿por qué no se sube la carpeta `.venv` a Git y qué se sube en su lugar? *(2 líneas. Empieza así: «Porque pesa, depende de… y se recrea… Se sube…»)*

Después, escríbeme `examíname clase-47`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Objeto → `dict`, array → `list`, `true` → `True`, `null` → `None` (y los textos son `str`, y los números, `int` o `float`).

**2.** Porque `yaml.load` podía construir objetos arbitrarios de Python descritos en el propio YAML, y un archivo malicioso podría ejecutar código al cargarse. `safe_load` solo crea tipos básicos (diccionarios, listas, textos, números, booleanos y `None`). En PyYAML 6, `load` sin `Loader` ni siquiera funciona.

**3.** `NO` (o `no`, `on`, `off`) se convierte en booleano; `3.10` en el decimal `3.1`; `1:30` en `90`; `0755` en octal (`493`). Se evita poniendo entre comillas los valores que deban ser texto: `pais: "NO"`, `version: "3.10"`.

**4.** Porque pesa, depende de tu máquina (guarda rutas absolutas) y se recrea en un minuto. Se sube `requirements.txt` (y `requirements-dev.txt`) con las versiones fijadas, y cualquiera recrea el entorno con `pip install -r`.

**Reto 1:** `int`, `float` y `dump`.

**Reto 2:** `1000`.

**Reto 3:** `list`, `"http://"` y `"https://"`, y `0`.

**Reto 4:** `jq 'map(select(.estado == "UP") | .segundos) | add / length' chequeos.json` → `0.49666666666666665`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to parse / to serialize | analizar / convertir a texto |
| structured data | datos estructurados |
| trailing comma | coma final sobrante |
| safe loading | carga segura |
| header row | fila de cabecera |

🎙️ *"I always load YAML with safe_load and quote values that must stay strings, like versions and country codes, because YAML guesses types."*

## Siguiente

[Clase 48 — Programas de línea de comandos: argparse y logging](clase-48-argparse-y-logging.md)
