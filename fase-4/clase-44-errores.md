# Clase 44 — Errores y excepciones

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

## Objetivo

- Leer una traza (*traceback*) y encontrar la línea culpable.
- Capturar errores concretos con `try` / `except`, y usar `else` y `finally`.
- Lanzar tus propios errores con `raise` y crear una excepción propia.
- Convertir los errores en mensajes claros en stderr y en códigos de salida, como en tus scripts de Bash.

## Por qué importa

Un script de producción va a encontrarse con archivos que no existen, permisos que faltan, sitios caídos y datos mal escritos. La diferencia entre un script amateur y uno profesional no es que no falle: es **cómo** falla. O muestra una traza de 20 líneas y sale con 1, o dice `Error: no puedo leer config.yaml (no existe)`, sale con 2 y sigue con lo demás cuando tiene sentido. Vigía tendrá que sobrevivir a cada sitio caído, igual que la v0 sobrevivía a `curl` con `|| true`.

## Teoría

### Leer una traza

```
Traceback (most recent call last):
  File "/tmp/traza.py", line 8, in <module>
    cargar("config.yaml")
  File "/tmp/traza.py", line 2, in cargar
    return leer(ruta)
  File "/tmp/traza.py", line 5, in leer
    with open(ruta) as f:
FileNotFoundError: [Errno 2] No such file or directory: 'config.yaml'
```

Se lee **de abajo arriba**: la última línea dice qué pasó (el tipo de error y su mensaje). Las de encima son el camino de llamadas: la más baja es donde ocurrió (`leer`, línea 5), y las de más arriba, quién la llamó.

### Las excepciones que más verás

| Excepción | Cuándo |
|-----------|--------|
| `ValueError` | el tipo es correcto pero el valor no: `int("hola")` |
| `TypeError` | el tipo no encaja: `"5" + 3` |
| `KeyError` / `IndexError` | clave o posición que no existe |
| `FileNotFoundError`, `PermissionError` | problemas con archivos (son `OSError`, como los `Errno` del sistema) |
| `ZeroDivisionError` | dividir entre cero |
| `KeyboardInterrupt` | pulsaste `Ctrl+C` |

### `try` / `except` / `else` / `finally`

```python
try:
    texto = ruta.read_text(encoding="utf-8")       # lo que puede fallar
except FileNotFoundError:
    print(f"Error: {ruta} no existe", file=sys.stderr)
    sys.exit(2)
except PermissionError:
    print(f"Error: sin permiso para leer {ruta}", file=sys.stderr)
    sys.exit(2)
else:
    print("leído")                                  # solo si no hubo excepción
finally:
    print("esto se ejecuta siempre")                # limpieza: como el trap EXIT de la clase 19
```

- Captura **errores concretos**. Nunca `except:` a secas: atrapa hasta el `Ctrl+C` (Rómpelo 1).
- Pon dentro del `try` solo lo que puede fallar, no medio programa.
- `except (ValueError, TypeError) as e:` captura varias, y `e` es el error: `str(e)` da su mensaje.

### Lanzar errores

```python
def validar_timeout(valor):
    if valor <= 0:
        raise ValueError(f"el timeout debe ser positivo, no {valor}")
    return valor
```

Y una excepción propia para los errores de **tu** programa:

```python
class ConfigError(Exception):
    """La configuración no se puede usar."""

raise ConfigError("falta la lista 'urls'")
```

Así quien llama puede capturar exactamente tus errores (`except ConfigError`) sin tragarse los demás. Vigía usará una.

### Errores y códigos de salida

| Situación | Código | Cómo |
|-----------|--------|------|
| todo bien | 0 | terminar normalmente |
| una excepción sin capturar | 1 | Python imprime la traza y sale con 1 |
| `Ctrl+C` sin capturar | 130 | 128 + 2 (SIGINT), igual que en Bash |
| error que tú controlas | el que elijas | `sys.exit(2)` |

`sys.exit("mensaje")` imprime el mensaje en stderr y sale con 1: un atajo útil. La convención de tus scripts de Bash sigue valiendo: 0 bien, 1 fallo, 2 uso o configuración incorrectos.

### Pedir perdón mejor que pedir permiso

Python prefiere intentar y capturar el error (*EAFP*) antes que comprobarlo todo primero (*LBYL*):

```python
# comprobar antes: el archivo puede desaparecer entre la comprobación y el open
if ruta.exists():
    texto = ruta.read_text()

# intentar y capturar: una sola operación, sin hueco entre medias
try:
    texto = ruta.read_text()
except FileNotFoundError:
    ...
```

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-44 && cd ~/my-devops-journey/labs/clase-44
```

### 1. Leer una traza

```bash
cat > traza.py <<'EOF'
def cargar(ruta):
    return leer(ruta)

def leer(ruta):
    with open(ruta) as f:
        return f.read()

cargar("config.yaml")
EOF
python3 traza.py ; echo "código: $?"
```

🔮 **Predice:** ¿en qué función y en qué línea ocurrió el error? ¿Y qué código de salida verás?

### 2. Convertir texto en número sin explotar

```bash
cat > numeros.py <<'EOF'
#!/usr/bin/env python3
"""numeros.py: suma los argumentos que sean números y avisa de los demás."""
import sys

total = 0.0
for argumento in sys.argv[1:]:
    try:
        total += float(argumento)
    except ValueError:
        print(f"aviso: '{argumento}' no es un número, lo salto", file=sys.stderr)
print(f"total: {total}")
EOF
python3 numeros.py 10 2.5 hola 7
python3 numeros.py 10 2.5 hola 7 2>/dev/null
```

`sys.argv` es la lista de argumentos, como `"$@"` en Bash: `sys.argv[0]` es el script y `sys.argv[1:]` todos los demás. El aviso va a stderr, así que `2>/dev/null` lo oculta y el total sigue limpio en stdout (clase 04).

### 3. Una configuración que falla con elegancia

```bash
cat > leer_config.py <<'EOF'
#!/usr/bin/env python3
"""leer_config.py: lee un archivo clave=valor y explica bien cualquier error."""
import sys
from pathlib import Path


class ConfigError(Exception):
    """La configuración no se puede usar."""


def leer_config(ruta: Path) -> dict:
    try:
        texto = ruta.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise ConfigError(f"{ruta} no existe")
    except PermissionError:
        raise ConfigError(f"sin permiso para leer {ruta}")
    config = {}
    for numero, linea in enumerate(texto.splitlines(), start=1):
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        if "=" not in linea:
            raise ConfigError(f"{ruta}, línea {numero}: falta el '=' en {linea!r}")
        clave, valor = linea.split("=", 1)
        config[clave.strip()] = valor.strip()
    return config


def main():
    ruta = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("app.conf")
    try:
        config = leer_config(ruta)
    except ConfigError as e:
        print(f"Error de configuración: {e}", file=sys.stderr)
        sys.exit(2)
    print(config)


if __name__ == "__main__":
    main()
EOF
printf 'puerto = 8080\n# comentario\nregion = us-east-1\n' > app.conf
python3 leer_config.py ; echo "código: $?"
python3 leer_config.py no-existe.conf ; echo "código: $?"
printf 'puerto 8080\n' > roto.conf
python3 leer_config.py roto.conf ; echo "código: $?"
chmod 000 app.conf && python3 leer_config.py ; echo "código: $?" ; chmod 644 app.conf
```

🔮 **Predice** el mensaje y el código de cada llamada. Ninguna muestra una traza: los errores esperables se convierten en un mensaje y en el código 2. `split("=", 1)` corta solo en el primer `=`, por si el valor contiene otro.

### 4. `finally` para limpiar

```bash
cat > limpiar.py <<'EOF'
import tempfile
from pathlib import Path

temporal = Path(tempfile.mkdtemp())
print(f"trabajo en {temporal}")
try:
    (temporal / "datos.txt").write_text("borrador\n")
    1 / 0                                   # algo falla a mitad
finally:
    for archivo in temporal.iterdir():
        archivo.unlink()
    temporal.rmdir()
    print(f"limpieza hecha: ¿existe todavía? {temporal.exists()}")
EOF
python3 limpiar.py ; echo "código: $?"
```

El error sigue su camino (la traza y el código 1), pero `finally` limpió antes. Es el `trap '…' EXIT` de la clase 19.

## Rómpelo

**1. El `except` que se traga el `Ctrl+C`:**
```bash
cat > ciego.py <<'EOF'
import time
for i in range(5):
    try:
        print(f"trabajando {i}…")
        time.sleep(1)
    except:
        print("ignoro el error")
print("terminé")
EOF
python3 ciego.py
```
Pulsa `Ctrl+C` mientras corre. En lugar de detenerse, imprime `ignoro el error` y sigue. Un `except:` desnudo captura **todo**, también `KeyboardInterrupt`. Con un bucle infinito, no podrías pararlo con `Ctrl+C`. Por eso se captura siempre algo concreto.

**2. El error escondido:**
```bash
cat > escondido.py <<'EOF'
codigos = [200, 503, 200]
arriba = 0
for c in codigos:
    try:
        if 200 <= c < 400:
            arriba += 1
        porcentaje = arriba / len(codigo) * 100
    except Exception:
        pass
print(f"disponibilidad: {arriba}")
EOF
python3 escondido.py
```
🔮 ¿Qué error hay? `len(codigo)` tiene una errata (`codigo` en lugar de `codigos`), que lanza un `NameError` en cada vuelta… y `except Exception: pass` lo esconde. El programa "funciona" e imprime algo plausible pero incompleto. Quita el `try` y verás el error.

**3. El error en el sitio equivocado:**
```bash
python3 leer_config.py no-existe.conf > salida.txt
cat salida.txt
```
El mensaje sale por pantalla y `salida.txt` queda vacío: los errores van a stderr. Si los imprimieras con un `print` normal, acabarían mezclados con los datos.

## Reto

1. `sumar_archivo.py <archivo>`: lee un número por línea y muestra la suma. Las líneas que no son números generan un aviso en stderr (con el número de línea) y se saltan. Si el archivo no existe, sale con 2 y un mensaje claro, sin traza.
2. `porcentaje(arriba, total)`: lanza `ValueError` con un mensaje claro si `total` es 0 o negativo. Llámala dentro de un `try` y muestra el mensaje.
3. Añade a `leer_config.py` la validación de que `puerto` existe y es un número entre 1 y 65535. Si no, `ConfigError` con un mensaje que diga qué valor llegó.

## Cierre

En `notas/fase-4/clase-44.md`:

1. ¿Cómo se lee una traza? ¿Qué te dice la última línea y qué te dicen las de encima?
2. ¿Por qué hay que capturar excepciones concretas y no usar `except:` a secas ni `except Exception: pass`?
3. ¿Para qué sirve `finally`? ¿A qué equivale en Bash?
4. **Repaso (clase 43, sin mirar):** ¿qué diferencia hay entre abrir un archivo con `"w"` y con `"a"`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** De abajo arriba. La última línea dice qué tipo de error ocurrió y su mensaje. Las de encima son la cadena de llamadas: la más baja es la línea exacta donde se produjo, y cada una de las de arriba es quién llamó a esa función, hasta el principio del programa.

**2.** Porque `except:` captura todo, incluidos `KeyboardInterrupt` (no puedes parar el programa) y errores de programación como un `NameError`, que deberían verse. `except Exception: pass` esconde los fallos: el programa sigue con datos incompletos y el problema aparece después, lejos de su causa. Se captura lo que esperas y sabes tratar; lo demás debe fallar a la vista.

**3.** Para ejecutar código de limpieza pase lo que pase: haya o no un error, e incluso si el bloque hace `return`. Equivale al `trap '…' EXIT` de Bash.

**4.** `"w"` vacía el archivo y escribe desde cero (como `>`); `"a"` añade al final y conserva lo que había (como `>>`).

**Reto 1 (una solución):**
```python
#!/usr/bin/env python3
import sys
from pathlib import Path

if len(sys.argv) != 2:
    sys.exit(f"Uso: {sys.argv[0]} <archivo>")
ruta = Path(sys.argv[1])
try:
    lineas = ruta.read_text(encoding="utf-8").splitlines()
except OSError as e:
    print(f"Error: no puedo leer {ruta}: {e.strerror}", file=sys.stderr)
    sys.exit(2)
total = 0.0
for numero, linea in enumerate(lineas, start=1):
    try:
        total += float(linea)
    except ValueError:
        print(f"aviso: línea {numero} no es un número: {linea!r}", file=sys.stderr)
print(total)
```
`except OSError` cubre a la vez `FileNotFoundError` y `PermissionError`, y `e.strerror` da el texto del sistema ("No such file or directory").

(`sys.exit("Uso: …")` sale con 1; si quieres el 2 de la convención, `print(…, file=sys.stderr)` y `sys.exit(2)`.)
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| exception / to raise | excepción / lanzar |
| to catch / to handle | capturar / tratar |
| traceback / stack trace | traza |
| exit code | código de salida |
| fail loudly | fallar a la vista |

🎙️ *"I catch only the errors I know how to handle, turn them into a clear message and a non-zero exit code, and let everything else fail loudly."*

## Siguiente

[Clase 45 — Módulos, paquetes y la biblioteca estándar](clase-45-modulos.md)
