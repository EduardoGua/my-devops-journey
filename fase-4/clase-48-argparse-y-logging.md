# Clase 48 — Programas de línea de comandos: argparse y logging

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** B. Python para operaciones

## Objetivo

- Leer argumentos y opciones con `argparse`: posicionales, opciones con valor por defecto, tipos, `choices` y banderas.
- Obtener gratis la ayuda (`--help`) y los mensajes de uso, con código de salida 2.
- Crear **subcomandos**, como `git commit` o `vigia check`.
- Registrar lo que hace tu programa con `logging`: niveles, formato con fecha y una opción `--verbose`.

## Por qué importa

Una herramienta de operaciones se usa desde la terminal, desde cron y desde un pipeline. Tiene que explicar cómo se usa, rechazar argumentos mal escritos con un mensaje claro y dejar un rastro de lo que hizo. En Bash lo hacías a mano con `case` y una función `log()` (clases 17 y 19); en Python, `argparse` y `logging` vienen en la biblioteca estándar y lo hacen mejor. Vigía v1 será una herramienta con dos subcomandos: `vigia check` y `vigia serve`.

## Teoría

### `argparse` en cinco líneas

```python
import argparse

parser = argparse.ArgumentParser(prog="filtrar", description="Filtra chequeos de un JSON a un CSV.")
parser.add_argument("entrada", help="archivo JSON con los chequeos")              # posicional, obligatorio
parser.add_argument("--estado", choices=["UP", "DOWN"], default="DOWN", help="estado a filtrar")
parser.add_argument("--timeout", type=float, default=10, help="segundos (por defecto: 10)")
parser.add_argument("-v", "--verbose", action="store_true", help="más detalle en el log")
args = parser.parse_args()          # lee sys.argv, valida y crea args.entrada, args.estado…
```

| Pieza | Qué hace |
|-------|----------|
| sin guiones (`"entrada"`) | argumento **posicional** y obligatorio |
| con guiones (`"--estado"`) | **opción**, normalmente con valor por defecto |
| `type=float`, `type=Path` | convierte el texto y rechaza lo que no encaja |
| `choices=[...]` | solo acepta esos valores |
| `action="store_true"` | bandera: `True` si aparece |
| `help=` | el texto de `--help` |

Si algo no encaja, `argparse` imprime el uso y un error en stderr, y sale con **2**: la misma convención que tus scripts de Bash.

### Subcomandos

```python
parser = argparse.ArgumentParser(prog="inventario")
sub = parser.add_subparsers(dest="comando", required=True)
listar = sub.add_parser("listar", help="muestra todos los servidores")
buscar = sub.add_parser("buscar", help="busca servidores por rol")
buscar.add_argument("rol")
args = parser.parse_args()
if args.comando == "listar":
    ...
```

Cada subcomando tiene sus propias opciones y su propia ayuda (`inventario buscar --help`).

### `logging` en lugar de `print`

```python
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("filtrar")

log.debug("detalle para depurar")        # oculto con nivel INFO
log.info("leídos %d chequeos", 5)
log.warning("chequeo incompleto, lo salto")
log.error("no puedo leer %s", "x.json")
```

| Nivel | Para qué |
|-------|----------|
| `DEBUG` | detalles para depurar (con `--verbose`) |
| `INFO` | lo que va haciendo el programa |
| `WARNING` | algo raro, pero sigue |
| `ERROR` | algo falló |
| `CRITICAL` | el programa no puede seguir |

Ventajas frente a `print`: cada mensaje lleva fecha y nivel; va a **stderr** (los datos de stdout quedan limpios); y subes o bajas el detalle cambiando una línea. El formato es el mismo de tu función `log()` de la clase 19.

- Llama a `logging.basicConfig` **una vez**, al principio de `main()`. Si no lo llamas, solo salen los mensajes de `WARNING` o más.
- Pasa los valores como argumentos (`log.info("leídos %d", n)`), no con una f-string: el texto solo se construye si el mensaje se va a mostrar.
- Dentro de un `except`, `log.exception("…")` registra el error **con** su traza.

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
mkdir -p ~/my-devops-journey/labs/clase-48 && cd ~/my-devops-journey/labs/clase-48
cp ../clase-47/chequeos.json .
```

### 1. La ayuda gratis

```bash
cat > saludo.py <<'EOF'
#!/usr/bin/env python3
"""saludo.py: prueba de argparse."""
import argparse

parser = argparse.ArgumentParser(prog="saludo", description="Saluda a alguien.")
parser.add_argument("nombre", help="a quién saludar")
parser.add_argument("--veces", type=int, default=1, help="cuántas veces (por defecto: 1)")
parser.add_argument("--gritar", action="store_true", help="en mayúsculas")
args = parser.parse_args()

texto = f"Hola, {args.nombre}"
if args.gritar:
    texto = texto.upper()
for _ in range(args.veces):
    print(texto)
EOF
python3 saludo.py --help
python3 saludo.py Ana --veces 2 --gritar
```

🔮 **Predice** el mensaje y el código de cada una:

```bash
python3 saludo.py ; echo "código: $?"
python3 saludo.py Ana --veces dos ; echo "código: $?"
python3 saludo.py Ana --color rojo ; echo "código: $?"
```

Tres errores distintos, cada uno con su mensaje y siempre con código 2, sin escribir ni una comprobación a mano.

### 2. `filtrar.py` con argparse y logging

Reescribe la herramienta de la clase 47:

```bash
cat > filtrar.py <<'EOF'
#!/usr/bin/env python3
"""filtrar.py: lee chequeos de un JSON, filtra por estado y escribe un CSV."""
import argparse
import csv
import json
import logging
import sys
from pathlib import Path

CAMPOS = ["url", "estado", "codigo", "segundos"]
log = logging.getLogger("filtrar")


def leer_chequeos(ruta: Path) -> list[dict]:
    try:
        with open(ruta, encoding="utf-8") as f:
            datos = json.load(f)
    except OSError as e:
        raise ValueError(f"no puedo leer {ruta}: {e.strerror}")
    except json.JSONDecodeError as e:
        raise ValueError(f"{ruta} no es JSON válido (línea {e.lineno}, columna {e.colno})")
    if not isinstance(datos, list):
        raise ValueError(f"{ruta} debe contener una lista")
    log.debug("leídos %d chequeos de %s", len(datos), ruta)
    return datos


def filtrar(chequeos: list[dict], estado: str) -> list[dict]:
    elegidos = []
    for posicion, chequeo in enumerate(chequeos):
        if not isinstance(chequeo, dict) or not all(c in chequeo for c in CAMPOS):
            log.warning("el chequeo %d está incompleto, lo salto", posicion)
            continue
        if chequeo["estado"] == estado:
            elegidos.append({c: chequeo[c] for c in CAMPOS})
    return elegidos


def escribir_csv(filas: list[dict], ruta: Path) -> None:
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=CAMPOS)
        escritor.writeheader()
        escritor.writerows(filas)


def crear_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="filtrar", description="Filtra chequeos de un JSON a un CSV.")
    parser.add_argument("entrada", type=Path, help="archivo JSON con los chequeos")
    parser.add_argument("salida", type=Path, help="archivo CSV que se escribirá")
    parser.add_argument("--estado", choices=["UP", "DOWN"], default="DOWN",
                        help="estado a filtrar (por defecto: DOWN)")
    parser.add_argument("-v", "--verbose", action="store_true", help="muestra detalles de depuración")
    return parser


def main(argv=None) -> int:
    args = crear_parser().parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s [%(levelname)s] %(message)s")
    try:
        filas = filtrar(leer_chequeos(args.entrada), args.estado)
        escribir_csv(filas, args.salida)
    except ValueError as e:
        log.error("%s", e)
        return 2
    except OSError as e:
        log.error("no puedo escribir %s: %s", args.salida, e.strerror)
        return 2
    log.info("%d chequeos %s escritos en %s", len(filas), args.estado, args.salida)
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
python3 filtrar.py --help
python3 filtrar.py chequeos.json caidos.csv
python3 filtrar.py chequeos.json arriba.csv --estado UP -v
python3 filtrar.py chequeos.json x.csv --estado MAYBE ; echo "código: $?"
python3 filtrar.py no-existe.json x.csv ; echo "código: $?"
python3 filtrar.py chequeos.json caidos.csv 2>/dev/null ; echo "código: $?"
```

🔮 **Predice:** con `2>/dev/null`, ¿qué verás? Los mensajes del log van a stderr, así que desaparecen y solo queda el código de salida. Así se comporta bien en cron: el log va a un archivo con `2>>` y los datos, a otro.

`main(argv=None)` permite llamar a `main(["chequeos.json", "x.csv"])` desde una prueba (clase 52) sin tocar `sys.argv`.

### 3. Subcomandos

```bash
cat > servidores.json <<'EOF'
[
  {"nombre": "web-01", "rol": "web", "zona": "us-east-1a", "activo": true},
  {"nombre": "web-02", "rol": "web", "zona": "us-east-1b", "activo": false},
  {"nombre": "db-01",  "rol": "db",  "zona": "us-east-1a", "activo": true}
]
EOF
cat > inventario.py <<'EOF'
#!/usr/bin/env python3
"""inventario.py: consulta un inventario de servidores."""
import argparse
import json
import sys
from pathlib import Path


def cargar(ruta: Path) -> list[dict]:
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="inventario", description="Consulta un inventario.")
    parser.add_argument("--archivo", type=Path, default=Path("servidores.json"))
    sub = parser.add_subparsers(dest="comando", required=True)
    sub.add_parser("listar", help="muestra todos los servidores")
    buscar = sub.add_parser("buscar", help="busca por rol")
    buscar.add_argument("rol", help="web, db…")
    buscar.add_argument("--solo-activos", action="store_true")
    args = parser.parse_args(argv)

    servidores = cargar(args.archivo)
    if args.comando == "buscar":
        servidores = [s for s in servidores if s["rol"] == args.rol]
        if args.solo_activos:
            servidores = [s for s in servidores if s["activo"]]
    for s in servidores:
        print(f"{s['nombre']:<8} {s['rol']:<4} {s['zona']:<11} {'activo' if s['activo'] else 'parado'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
python3 inventario.py --help
python3 inventario.py buscar --help
python3 inventario.py listar
python3 inventario.py buscar web --solo-activos
python3 inventario.py borrar ; echo "código: $?"
```

Fíjate en que `--solo-activos` se convierte en `args.solo_activos`: los guiones pasan a guiones bajos. Las opciones generales, como `--archivo`, van **antes** del subcomando: `python3 inventario.py --archivo otro.json listar`.

## Rómpelo

**1. El log que no aparece:**
```bash
cat > callado.py <<'EOF'
import logging
log = logging.getLogger("demo")
log.info("procesando…")
log.warning("cuidado")
EOF
python3 callado.py
```
Solo sale `cuidado`. Sin `basicConfig`, el nivel por defecto es `WARNING` y los `info` se descartan en silencio. Si "tu log no sale", lo primero es comprobar que llamas a `basicConfig` con el nivel adecuado.

**2. `basicConfig` llamado tarde:**
```bash
cat > tarde.py <<'EOF'
import logging
logging.warning("primer mensaje")
logging.basicConfig(level=logging.DEBUG, format="%(levelname)s %(message)s")
logging.debug("¿saldrá?")
EOF
python3 tarde.py
```
El `debug` no sale: el primer mensaje configuró el log con los valores por defecto, y el `basicConfig` posterior ya no hace nada. Configúralo una vez, al principio de `main()`, antes de cualquier mensaje.

**3. Opciones antes o después del subcomando:**
```bash
python3 inventario.py listar --archivo servidores.json ; echo "código: $?"
```
`unrecognized arguments: --archivo servidores.json`: `--archivo` pertenece al parser principal, así que va antes de `listar`. En Vigía usarás un parser "común" para que las opciones valgan después del subcomando (`vigia check --config …`).

## Reto

1. Añade a `filtrar.py` una opción `--min-segundos` (`float`, por defecto `0`) que, además del estado, filtre los chequeos más lentos que ese valor.
2. Añade a `inventario.py` un subcomando `zonas` que muestre cuántos servidores hay en cada zona, y una opción general `--json` que haga que `listar` imprima JSON en lugar de la tabla.
3. Haz que `filtrar.py` acepte `--log archivo.log` para escribir el log en un archivo en lugar de stderr (pista: el parámetro `filename=` de `basicConfig`).

## Cierre

En `notas/fase-4/clase-48.md`:

1. ¿Qué diferencia hay entre un argumento posicional y una opción en `argparse`? ¿Qué pasa si falta uno obligatorio?
2. ¿Por qué usar `logging` en lugar de `print` para los mensajes de un programa?
3. ¿Qué nivel de log usarías para "procesando 5 URLs", "una URL tardó más de lo normal" y "no puedo leer la configuración"?
4. **Repaso (clase 47, sin mirar):** ¿qué devuelve `yaml.safe_load` con `pais: NO` y cómo lo evitas?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El posicional se identifica por su posición y es obligatorio (`filtrar.py entrada.json salida.csv`); la opción lleva nombre con guiones, puede ir en cualquier orden y suele tener un valor por defecto (`--estado UP`). Si falta un obligatorio, `argparse` muestra el uso y `the following arguments are required: …` en stderr, y sale con 2.

**2.** Porque cada mensaje lleva fecha y nivel; va a stderr y no contamina los datos de stdout; puedes mostrar más o menos detalle cambiando el nivel (`--verbose`) sin tocar el código; y puedes mandarlo a un archivo. Con `print` no tienes nada de eso.

**3.** `INFO`, `WARNING` y `ERROR` (o `CRITICAL` si el programa no puede seguir).

**4.** `{'pais': False}`: YAML 1.1 interpreta `NO` como booleano. Se evita con comillas: `pais: "NO"`.

**Reto 1:** añade `parser.add_argument("--min-segundos", type=float, default=0)` y, en `filtrar`, la condición `chequeo["segundos"] >= min_segundos` (pasando el valor como parámetro).

**Reto 3:** `logging.basicConfig(level=…, format=…, filename=args.log)`. Con `filename=None`, el log sigue yendo a stderr, así que basta con `parser.add_argument("--log")`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| command-line interface (CLI) | interfaz de línea de comandos |
| positional argument / option / flag | argumento posicional / opción / bandera |
| subcommand | subcomando |
| log level | nivel de log |
| verbose | detallado |

🎙️ *"My tools have a proper CLI with --help, return exit code 2 on bad usage, and log to stderr with timestamps, so they behave well in cron and in pipelines."*

## Siguiente

[Clase 49 — Consumir APIs con requests](clase-49-requests.md)
