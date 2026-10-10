# Clase 47 — JSON, CSV y YAML

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

## Objetivo

- Leer y escribir **JSON**, el formato de las APIs y de la AWS CLI.
- Leer y escribir **CSV**, el formato de los informes y las hojas de cálculo.
- Leer **YAML** con seguridad, el formato de la configuración en Docker Compose, Kubernetes y GitHub Actions, y esquivar sus trampas.
- Escribir un programa que lee un JSON, filtra los datos y escribe un CSV, con manejo de errores. Es un criterio de salida de esta fase.

## Por qué importa

En DevOps, casi todo lo que no es código es **datos estructurados**: la respuesta de una API (JSON), la salida de `aws ec2 describe-instances` (JSON), un `docker-compose.yaml`, un manifiesto de Kubernetes o un workflow de GitHub Actions (YAML), y el informe que te pide tu jefe para abrirlo en una hoja de cálculo (CSV). Convertir de uno a otro, filtrar y validar es trabajo diario, y en Python son pocas líneas.

## Teoría

### JSON ⇄ Python

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

### CSV

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

### YAML

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

### ¿Cuál uso?

| Formato | Lo usa | Ventaja | Cuidado con |
|---------|--------|---------|-------------|
| JSON | APIs, AWS CLI, logs estructurados | estricto y universal | sin comentarios |
| YAML | configuración escrita por personas | legible y con comentarios | la sangría y los tipos adivinados |
| CSV | informes, hojas de cálculo | lo abre cualquiera | todo es texto, sin estructura anidada |

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
pip install PyYAML
mkdir -p ~/my-devops-journey/labs/clase-47 && cd ~/my-devops-journey/labs/clase-47
```

### 1. JSON: leer, filtrar y volver a escribir

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

`python3 -m json.tool` valida y formatea un JSON. `jq`, que ya tienes instalado, filtra JSON desde la terminal y es muy útil con la salida de la AWS CLI (fase 6). Para transformaciones más largas, Python.

### 2. El criterio de salida: de JSON a CSV, con errores bien tratados

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

🔮 **Predice** qué filas tendrá `caidos.csv`. Fíjate en la estructura: tres funciones pequeñas que hacen una cosa cada una (leer, filtrar, escribir) y un `main()` que decide qué hacer con los errores y devuelve el código de salida. `sys.exit(main())` lo entrega al sistema. `__doc__` es el docstring del módulo: el script imprime su propia línea de uso.

Ahora, los casos difíciles:

```bash
python3 filtrar.py no-existe.json x.csv ; echo "código: $?"
printf '[{"url": "a", "estado": "DOWN",}]' > roto.json
python3 filtrar.py roto.json x.csv ; echo "código: $?"
printf '[{"url": "a"}, {"url": "b", "estado": "DOWN", "codigo": 0, "segundos": 1}]' > incompleto.json
python3 filtrar.py incompleto.json x.csv ; echo "código: $?"
python3 filtrar.py chequeos.json /no-existe/x.csv ; echo "código: $?"
python3 filtrar.py ; echo "código: $?"
```

Ninguno muestra una traza: cada error se explica en una línea, en stderr, con código 2. Un chequeo incompleto genera un aviso y el resto se procesa.

### 3. YAML: la configuración de un programa

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

`yaml.safe_load` devuelve diccionarios, listas, números y textos de Python, igual que `json.load`.

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

1. `csv_a_json.py <entrada.csv> <salida.json>`: convierte el `caidos.csv` de la práctica en JSON, con `codigo` como entero y `segundos` como decimal (no como texto).
2. Añade a `filtrar.py` una cuarta columna calculada, `ms`, con los segundos en milisegundos y sin decimales.
3. `validar_config.py config.yaml`: comprueba que `urls` es una lista no vacía de textos que empiezan por `http://` o `https://`, y que `timeout` es un número positivo. Sale con 0 si todo está bien o con 2 y un mensaje por cada problema. Pruébalo con tres archivos rotos de formas distintas.
4. Con `jq`, saca de `chequeos.json` la media de `segundos` de los chequeos `UP`. Pista: `map(select(.estado == "UP") | .segundos) | add / length`.

## Cierre

En `notas/fase-4/clase-47.md`:

1. ¿Qué tipos de Python corresponden a un objeto, un array, `true` y `null` de JSON?
2. ¿Por qué se usa `yaml.safe_load` y no `yaml.load`?
3. Da dos ejemplos de valores que YAML convierte de forma inesperada y cómo lo evitas.
4. **Repaso (clase 46, sin mirar):** ¿por qué no se sube la carpeta `.venv` a Git y qué se sube en su lugar?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Objeto → `dict`, array → `list`, `true` → `True`, `null` → `None` (y los textos son `str`, y los números, `int` o `float`).

**2.** Porque `yaml.load` podía construir objetos arbitrarios de Python descritos en el propio YAML, y un archivo malicioso podría ejecutar código al cargarse. `safe_load` solo crea tipos básicos (diccionarios, listas, textos, números, booleanos y `None`). En PyYAML 6, `load` sin `Loader` ni siquiera funciona.

**3.** `NO` (o `no`, `on`, `off`) se convierte en booleano; `3.10` en el decimal `3.1`; `1:30` en `90`; `0755` en octal (`493`). Se evita poniendo entre comillas los valores que deban ser texto: `pais: "NO"`, `version: "3.10"`.

**4.** Porque pesa, depende de tu máquina (guarda rutas absolutas) y se recrea en un minuto. Se sube `requirements.txt` (y `requirements-dev.txt`) con las versiones fijadas, y cualquiera recrea el entorno con `pip install -r`.

**Reto 1 (una solución):**
```python
import csv
import json
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as f:
    filas = [
        fila | {"codigo": int(fila["codigo"]), "segundos": float(fila["segundos"])}
        for fila in csv.DictReader(f)
    ]
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(filas, f, indent=2, ensure_ascii=False)
```
`fila | {...}` une dos diccionarios: los valores de la derecha reemplazan a los de la izquierda.

**Reto 4:** `jq 'map(select(.estado == "UP") | .segundos) | add / length' chequeos.json` → `0.4966…`
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
