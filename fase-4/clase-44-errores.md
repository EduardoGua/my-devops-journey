# Clase 44 — Errores y excepciones

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

> 💡 **La idea de hoy:** cuando algo falla, Python lanza una **excepción**: un error con nombre (`FileNotFoundError`, `ValueError`…) que, si nadie la captura, para el programa y enseña una **traza**. Con `try` / `except` capturas **los errores que esperas** y los conviertes en un mensaje claro y un código de salida, como en tus scripts de Bash; los que no esperas, los dejas fallar a la vista.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Mensajes por stderr y códigos de salida: 0 bien, 1 fallo, 2 uso incorrecto (clase 16, pieza 5).
> - `trap '…' EXIT` para limpiar pase lo que pase (clase 19, pieza 4).
> - Ctrl+C es la señal SIGINT, y 130 = 128 + 2 (clases 11 y 19).
> - Leer y escribir archivos con `pathlib` (clase 43).
> - Leer una traza de abajo arriba (clase 39, Rómpelo 5).

> 🔤 **Palabras nuevas de hoy:**
> - **excepción**: el error que lanza Python, con un tipo y un mensaje.
> - **`try` / `except`**: intentar algo y, si lanza esa excepción, hacer otra cosa.
> - **`raise`**: lanzar tú una excepción.
> - **`finally`**: el bloque que se ejecuta siempre, haya error o no.
> - **`sys.exit(N)`**: terminar el programa con el código de salida N.
> - **EAFP**: intentar y capturar el error, en vez de comprobarlo todo antes.

## Objetivo

- Leer una traza (*traceback*) y encontrar la línea culpable.
- Capturar errores concretos con `try` / `except`, y usar `else` y `finally`.
- Lanzar tus propios errores con `raise` y crear una excepción propia.
- Convertir los errores en mensajes claros en stderr y en códigos de salida, como en tus scripts de Bash.

## Por qué importa

Un script de producción va a encontrarse con archivos que no existen, permisos que faltan, sitios caídos y datos mal escritos. La diferencia entre un script amateur y uno profesional no es que no falle: es **cómo** falla. O muestra una traza de 20 líneas y sale con 1, o dice `Error: no puedo leer config.yaml (no existe)`, sale con 2 y sigue con lo demás cuando tiene sentido. Vigía tendrá que sobrevivir a cada sitio caído, igual que la v0 sobrevivía a `curl` con `|| true`.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea (en la 1 y la 3, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-44 && cd ~/my-devops-journey/labs/clase-44
```

## Las piezas

### Pieza 1 — Leer una traza, y las excepciones que más verás

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

| Excepción | Cuándo |
|-----------|--------|
| `ValueError` | el tipo es correcto pero el valor no: `int("hola")` |
| `TypeError` | el tipo no encaja: `"5" + 3` |
| `KeyError` / `IndexError` | clave o posición que no existe |
| `FileNotFoundError`, `PermissionError` | problemas con archivos (son `OSError`, como los `Errno` del sistema) |
| `ZeroDivisionError` | dividir entre cero |
| `KeyboardInterrupt` | pulsaste `Ctrl+C` |

**Pruébalo:**

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

👀 **Qué deberías ver:** la traza de arriba, que termina en `FileNotFoundError: … 'config.yaml'`; el error ocurrió en `leer`, línea 5 (la más baja de la traza); y `código: 1`.

✋ **Sin mirar:** ¿qué excepción lanza `int("hola")`?

<details>
<summary>Comprueba</summary>

`ValueError`: el tipo (texto) vale para `int()`, pero ese valor no se puede convertir.
</details>

**En resumen:** una traza se lee de abajo arriba: la última línea es qué pasó y la de encima, dónde.

### Pieza 2 — `try` / `except`: capturar lo que esperas

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
```

- Captura **errores concretos**. Nunca `except:` a secas: atrapa hasta el `Ctrl+C` (Rómpelo 1).
- Pon dentro del `try` solo lo que puede fallar, no medio programa.
- `except (ValueError, TypeError) as e:` captura varias, y `e` es el error: `str(e)` da su mensaje.

**Pruébalo: convertir texto en número sin explotar.**

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

👀 **Qué deberías ver:** `aviso: 'hola' no es un número, lo salto` y `total: 19.5`; en la segunda, solo `total: 19.5`: el aviso va a stderr, así que `2>/dev/null` lo oculta y el total sigue limpio en stdout (clase 04).

`sys.argv` es la lista de argumentos, como `"$@"` en Bash: `sys.argv[0]` es el script y `sys.argv[1:]` todos los demás.

✋ **Sin mirar:** ¿por qué el aviso va por stderr y no con un `print` normal?

<details>
<summary>Comprueba</summary>

Para que no se mezcle con los datos: quien guarde o procese la salida (`> total.txt`, un pipe) recibe solo el total.
</details>

**En resumen:** `try:` lo que puede fallar, `except TipoConcreto:` qué hacer si falla, y los avisos por stderr.

### Pieza 3 — Lanzar tus errores, y los códigos de salida

Con `raise` lanzas tú una excepción:

```python
def validar_timeout(valor):
    if valor <= 0:
        raise ValueError(f"el timeout debe ser positivo, no {valor}")
    return valor
```

Y para los errores de **tu** programa, una excepción propia:

```python
class ConfigError(Exception):
    """La configuración no se puede usar."""

raise ConfigError("falta la lista 'urls'")
```

Así quien llama puede capturar exactamente tus errores (`except ConfigError`) sin tragarse los demás. Vigía usará una. Y al final, cada error se convierte en un código de salida:

| Situación | Código | Cómo |
|-----------|--------|------|
| todo bien | 0 | terminar normalmente |
| una excepción sin capturar | 1 | Python imprime la traza y sale con 1 |
| `Ctrl+C` sin capturar | 130 | 128 + 2 (SIGINT), igual que en Bash |
| error que tú controlas | el que elijas | `sys.exit(2)` |

`sys.exit("mensaje")` imprime el mensaje en stderr y sale con 1: un atajo útil. La convención de tus scripts de Bash sigue valiendo: 0 bien, 1 fallo, 2 uso o configuración incorrectos.

**Pruébalo: una configuración que falla con elegancia.**

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

🔮 **Predice** el mensaje y el código de cada llamada.

👀 **Qué deberías ver:** `{'puerto': '8080', 'region': 'us-east-1'}` y `código: 0`; después, tres errores **sin traza**, cada uno con su mensaje y `código: 2`: `no-existe.conf no existe`, `roto.conf, línea 1: falta el '=' en 'puerto 8080'` y `sin permiso para leer app.conf`. `split("=", 1)` corta solo en el primer `=`, por si el valor contiene otro.

✋ **Sin mirar:** ¿con qué código sale un programa con una excepción que nadie captura? ¿Y si pulsas Ctrl+C?

<details>
<summary>Comprueba</summary>

Con 1, y Python imprime la traza. Con Ctrl+C, 130 (128 + 2, la señal SIGINT).
</details>

**En resumen:** `raise` lanza un error; una excepción propia agrupa los de tu programa; y cada error esperado se convierte en un mensaje por stderr y `sys.exit(2)`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — `finally`: limpiar pase lo que pase

El bloque `finally` se ejecuta **siempre**: si todo fue bien, si hubo un error, e incluso si el `try` hizo `return`. Es el `trap '…' EXIT` de la clase 19.

**Pruébalo:**

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

👀 **Qué deberías ver:** `trabajo en /tmp/tmp…`, `limpieza hecha: ¿existe todavía? False`, y **después** la traza del `ZeroDivisionError` y `código: 1`. El error sigue su camino, pero `finally` limpió antes.

✋ **Sin mirar:** si dentro del `try` hay un `return`, ¿se ejecuta el `finally`?

<details>
<summary>Comprueba</summary>

Sí: `finally` se ejecuta siempre al salir del `try`, también con un `return`.
</details>

**En resumen:** `finally` es la limpieza que ocurre siempre, como `trap '…' EXIT`.

### Pieza 5 — Intentar y capturar, mejor que comprobar antes

Python prefiere intentar y capturar el error (*EAFP*: "es más fácil pedir perdón que permiso") antes que comprobarlo todo primero (*LBYL*: "mira antes de saltar"):

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

**Pruébalo:**

```bash
python3 -c '
from pathlib import Path
ruta = Path("quizas.txt")
try:
    print(ruta.read_text(encoding="utf-8"))
except FileNotFoundError:
    print(f"{ruta} no existe: uso la configuración por defecto")
'
echo "hola" > quizas.txt && python3 -c 'from pathlib import Path; print(Path("quizas.txt").read_text(encoding="utf-8"), end="")'
```

👀 **Qué deberías ver:** `quizas.txt no existe: uso la configuración por defecto`; y, una vez creado el archivo, `hola`.

✋ **Sin mirar:** ¿por qué `if ruta.exists():` seguido de `ruta.read_text()` puede fallar igualmente?

<details>
<summary>Comprueba</summary>

Porque el archivo puede desaparecer (o perder sus permisos) entre la comprobación y la lectura. Con `try`, es una sola operación y el error se captura igual.
</details>

**En resumen:** en Python se intenta y se captura el error concreto, en lugar de comprobarlo todo antes.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `try: … except FileNotFoundError: …` | capturar un error concreto |
| `except (ValueError, TypeError) as e:` · `str(e)` | varios a la vez · su mensaje |
| `except OSError as e:` · `e.strerror` | cualquier error de archivo · su texto del sistema |
| `else:` · `finally:` | solo si no hubo error · siempre |
| `raise ValueError("mensaje")` | lanzar un error |
| `class ConfigError(Exception): """…"""` | una excepción propia |
| `print("Error: …", file=sys.stderr)` · `sys.exit(2)` | mensaje por stderr · salir con un código |
| `sys.exit("mensaje")` | mensaje por stderr y salir con 1 |
| `sys.argv[1:]` | los argumentos del script, como `"$@"` |

| Código | Significa |
|--------|-----------|
| 0 | todo bien |
| 1 | excepción sin capturar (con su traza) |
| 2 | error de uso o de configuración que tú controlas |
| 130 | Ctrl+C sin capturar |

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

En `labs/clase-44/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** `sumar_archivo.py <archivo>`: lee un número por línea y muestra la suma. Las líneas que no son números generan un aviso en stderr (con el número de línea) y se saltan. Si el archivo no existe, sale con 2 y un mensaje claro, sin traza.

> 🧩 **Ejemplo resuelto:** `numeros.py` (pieza 2) hace lo mismo con los **argumentos** en vez de con las líneas de un archivo.

**Ahora tú, con huecos:**
```python
#!/usr/bin/env python3
import sys
from pathlib import Path

ruta = Path(sys.argv[1])
try:
    lineas = ruta.read_text(encoding="utf-8").splitlines()
except ____ as e:
    print(f"Error: no puedo leer {ruta}: {e.strerror}", file=sys.stderr)
    sys.exit(____)
total = 0.0
for numero, linea in enumerate(lineas, start=1):
    try:
        total += float(linea)
    except ____:
        print(f"aviso: línea {numero} no es un número: {linea!r}", file=sys.stderr)
print(total)
```

<details>
<summary>Pista</summary>

Hay una excepción que cubre a la vez el archivo que no existe y el permiso que falta (está en la chuleta). Y la que lanza `float("hola")` la viste en la pieza 1.
</details>

**2.** `porcentaje(arriba, total)`: lanza `ValueError` con un mensaje claro si `total` es 0 o negativo. Llámala dentro de un `try` y muestra el mensaje.

> 🧩 **Ejemplo resuelto:** `validar_timeout` de la pieza 3, que lanza `ValueError` si el valor no es positivo.

**Ahora tú, con huecos:**
```python
def porcentaje(arriba: int, total: int) -> float:
    if total <= ____:
        raise ____(f"el total debe ser positivo, no {total}")
    return arriba / total * 100

try:
    print(porcentaje(3, 0))
except ValueError as e:
    print(f"no se puede calcular: {____}")
```

<details>
<summary>Pista</summary>

El mensaje del error está dentro de `e`; para tenerlo como texto, `str(e)` (o directamente `e` dentro de la f-string).
</details>

**3.** Añade a `leer_config.py` la validación de que `puerto` existe y es un número entre 1 y 65535. Si no, `ConfigError` con un mensaje que diga qué valor llegó.

> 🧩 **Ejemplo resuelto:** comprobar que existe la clave `region`, justo antes del `return config`:
> ```python
> if "region" not in config:
>     raise ConfigError(f"{ruta}: falta 'region'")
> ```

**Ahora tú, con huecos:**
```python
if "puerto" not in config:
    raise ConfigError(f"{ruta}: falta 'puerto'")
try:
    puerto = int(config["____"])
except ____:
    raise ConfigError(f"{ruta}: 'puerto' no es un número: {config['puerto']!r}")
if not ____ <= puerto <= ____:
    raise ConfigError(f"{ruta}: 'puerto' fuera de rango: {puerto}")
```

<details>
<summary>Pista</summary>

Los puertos van del 1 al 65535 (clase 29). Pruébalo con `puerto = abc` y con `puerto = 70000` en `app.conf`.
</details>

## Cierre

En `notas/fase-4/clase-44.md`:

1. ¿Cómo se lee una traza? ¿Qué te dice la última línea y qué te dicen las de encima? *(2 líneas. Empieza así: «De abajo arriba. La última línea dice… Las de encima son…»)*
2. ¿Por qué hay que capturar excepciones concretas y no usar `except:` a secas ni `except Exception: pass`? *(2–3 líneas. Empieza así: «Porque `except:` captura todo, incluido… y `except Exception: pass` esconde…, así que el problema aparece…»)*
3. ¿Para qué sirve `finally`? ¿A qué equivale en Bash? *(1–2 líneas. Empieza así: «Para ejecutar la limpieza pase lo que pase… Equivale a…»)*
4. **Repaso (clase 43, sin mirar):** ¿qué diferencia hay entre abrir un archivo con `"w"` y con `"a"`? *(1–2 líneas. Empieza así: «`"w"` vacía el archivo y…; `"a"`…»)*

Después, escríbeme `examíname clase-44`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** De abajo arriba. La última línea dice qué tipo de error ocurrió y su mensaje. Las de encima son la cadena de llamadas: la más baja es la línea exacta donde se produjo, y cada una de las de arriba es quién llamó a esa función, hasta el principio del programa.

**2.** Porque `except:` captura todo, incluidos `KeyboardInterrupt` (no puedes parar el programa) y errores de programación como un `NameError`, que deberían verse. `except Exception: pass` esconde los fallos: el programa sigue con datos incompletos y el problema aparece después, lejos de su causa. Se captura lo que esperas y sabes tratar; lo demás debe fallar a la vista.

**3.** Para ejecutar código de limpieza pase lo que pase: haya o no un error, e incluso si el bloque hace `return`. Equivale al `trap '…' EXIT` de Bash.

**4.** `"w"` vacía el archivo y escribe desde cero (como `>`); `"a"` añade al final y conserva lo que había (como `>>`).

**Reto 1:** `OSError`, `2` y `ValueError`. `except OSError` cubre a la vez `FileNotFoundError` y `PermissionError`, y `e.strerror` da el texto del sistema ("No such file or directory"). Si falta el argumento, `sys.argv[1]` lanza `IndexError`: para un mensaje de uso, comprueba antes `if len(sys.argv) != 2: sys.exit(f"Uso: {sys.argv[0]} <archivo>")` (sale con 1; para el 2 de la convención, `print(…, file=sys.stderr)` y `sys.exit(2)`).

**Reto 2:** `0`, `ValueError` y `e`: sale `no se puede calcular: el total debe ser positivo, no 0`.

**Reto 3:** `"puerto"`, `ValueError`, `1` y `65535`.
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
