# Clase 43 — Texto, archivos y rutas

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Python desde cero

> 💡 **La idea de hoy:** casi todo en operaciones es leer un archivo de texto (un log, una lista de servidores) y escribir otro (un informe). Python lo hace en tres pasos: abrir el archivo con `with open(...)`, que lo cierra solo pase lo que pase; tratar cada línea con los métodos de texto (`strip`, `split`…); y manejar las rutas con `pathlib`, que no se rompen con un espacio ni dependen de en qué carpeta estés.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `>` y `>>` para escribir y añadir a un archivo (clase 04).
> - Contar campos de un log de nginx con `awk` (clase 05): el mismo `access.log`, hoy en Python.
> - Leer un archivo línea a línea en Bash y saltar vacías y comentarios (clase 18).
> - El problema de cron con las rutas relativas (clase 20, pieza 3).
> - Funciones, `main()` y contar con `get(…, 0) + 1` (clases 41 y 42).

> 🔤 **Palabras nuevas de hoy:**
> - **método de texto**: una función que se usa con un punto: `linea.strip()`, `texto.split()`.
> - **inmutable**: que no cambia; los textos de Python lo son, y sus métodos devuelven uno nuevo.
> - **`with open(...) as f`**: abrir un archivo de forma que se cierre solo al salir del bloque.
> - **modo**: cómo se abre: `"r"` (leer), `"w"` (escribir desde cero) o `"a"` (añadir al final).
> - **`pathlib`**: el módulo de Python para trabajar con rutas.
> - **`__file__`**: la ruta del propio script que se está ejecutando.

## Objetivo

- Manipular texto con los métodos de `str`: `strip`, `split`, `join`, `startswith`, `replace`…
- Leer y escribir archivos de forma segura con `with open(...)`.
- Trabajar con rutas usando `pathlib`: unir, comprobar, listar y crear carpetas.
- Procesar un log real línea a línea y escribir un informe.

## Por qué importa

Gran parte del trabajo de operaciones consiste en leer archivos de texto (logs, configuraciones, listas de servidores) y escribir otros (informes, inventarios). En las clases 05 y 18 lo hiciste con `awk`, `cut` y bucles de Bash. En Python es más legible y mucho más rápido que un bucle de Bash, y con `pathlib` las rutas dejan de ser texto que se rompe con un espacio.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. La última junta todo con el log de nginx de la clase 05.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-43 && cd ~/my-devops-journey/labs/clase-43
```

## Las piezas

### Pieza 1 — Los métodos de texto

| Método | Ejemplo | Resultado |
|--------|---------|-----------|
| `strip()` | `"  web-01\n".strip()` | `"web-01"` (quita espacios y saltos de los extremos) |
| `split()` | `"GET /api 200".split()` | `["GET", "/api", "200"]` (por espacios) |
| `split(sep)` | `"root:x:0:0".split(":")` | `["root", "x", "0", "0"]` |
| `join(lista)` | `", ".join(["a", "b"])` | `"a, b"` |
| `startswith / endswith` | `url.startswith("https://")` | `True` / `False` |
| `replace(a, b)` | `"web-01".replace("-", "_")` | `"web_01"` |
| `lower / upper` | `"UP".lower()` | `"up"` |
| `in` | `"error" in linea` | `True` / `False` |

Los textos son **inmutables**: los métodos no cambian el original, devuelven uno nuevo. `nombre.strip()` sin guardar el resultado no hace nada útil.

**Pruébalo**, en `python3`, con una línea del log de nginx:

```python
>>> linea = '203.0.113.6 - - [03/Oct/2026:08:00:08 +0000] "POST /login HTTP/1.1" 200 1879'
>>> partes = linea.split()
>>> partes[0], partes[5], partes[6], partes[8]
>>> metodo = partes[5].strip('"')
>>> metodo
>>> " | ".join(["web-01", "web-02"])
>>> "  https://example.com  \n".strip()
>>> "https://example.com".startswith(("http://", "https://"))
>>> exit()
```

🔮 **Predice** qué hay en `partes[5]` antes de verlo.

👀 **Qué deberías ver:** `('203.0.113.6', '"POST', '/login', '200')`: `split()` corta por espacios, así que la comilla de `"POST` sigue pegada, y `strip('"')` la quita (`'POST'`). Después, `'web-01 | web-02'`, `'https://example.com'` y `True`: `startswith` acepta una tupla, "¿empieza por alguna de estas?".

✋ **Sin mirar:** ¿qué pasa si escribes `nombre.strip()` en una línea, sin guardar el resultado?

<details>
<summary>Comprueba</summary>

Nada útil: el texto es inmutable, `strip()` devuelve uno nuevo y se pierde. Hay que guardarlo: `nombre = nombre.strip()`.
</details>

**En resumen:** `strip` limpia los extremos, `split` parte, `join` une y `startswith` pregunta cómo empieza; siempre devuelven un texto nuevo.

### Pieza 2 — Abrir archivos con `with`

```python
with open("urls.txt", encoding="utf-8") as f:       # "r" (leer) es el modo por defecto
    for linea in f:                                  # línea a línea, sin cargar todo
        print(linea.strip())

with open("informe.txt", "w", encoding="utf-8") as f:   # "w" vacía el archivo antes
    f.write("primera línea\n")

with open("historial.log", "a", encoding="utf-8") as f: # "a" añade al final
    print("otra línea", file=f)
```

`with` cierra el archivo al salir del bloque, también si hay un error. Así se trabaja siempre. Los modos recuerdan a la clase 04: `"w"` es como `>` y `"a"` como `>>`. Escribe siempre `encoding="utf-8"`: así tu programa lee igual tildes y eñes en cualquier sistema.

**Pruébalo:**

```bash
cat > urls.txt <<'EOF'
# Sitios que quiero vigilar
https://example.com

   https://www.wikipedia.org
https://github.com
EOF
python3 -c '
with open("urls.txt", encoding="utf-8") as f:
    for linea in f:
        print(f"[{linea.strip()}]")
with open("historial.log", "w", encoding="utf-8") as f:
    f.write("primera\n")
with open("historial.log", "a", encoding="utf-8") as f:
    print("segunda", file=f)
'
cat historial.log
```

👀 **Qué deberías ver:** cada línea de `urls.txt` entre corchetes y sin espacios en los extremos (también `[]` para la vacía y el comentario, que aún no saltamos); y en `historial.log`, `primera` y `segunda`.

✋ **Sin mirar:** ¿por qué conviene escribir siempre `encoding="utf-8"`?

<details>
<summary>Comprueba</summary>

Para que el programa lea y escriba igual las tildes y las eñes en cualquier sistema, sin depender de su configuración.
</details>

**En resumen:** `with open(ruta, modo, encoding="utf-8") as f:`; `"r"` lee, `"w"` empieza de cero y `"a"` añade.

### Pieza 3 — `pathlib`: rutas que no se rompen

```python
from pathlib import Path

casa = Path.home()                          # /home/educo
curso = casa / "my-devops-journey"          # el / une rutas
log = curso / "recursos" / "clase-05" / "access.log"
log.exists(), log.is_file()                 # True, True
log.name, log.stem, log.suffix              # 'access.log', 'access', '.log'
log.parent                                  # …/recursos/clase-05
log.stat().st_size                          # tamaño en bytes
texto = log.read_text(encoding="utf-8")     # todo el archivo de una vez
Path("salida").mkdir(parents=True, exist_ok=True)   # como mkdir -p
for p in curso.glob("fase-*/README.md"):    # comodines, como en Bash
    print(p)
```

**Pruébalo, primero un informe con fecha:**

```bash
cat > informe.py <<'EOF'
from datetime import date
from pathlib import Path

carpeta = Path("informes")
carpeta.mkdir(exist_ok=True)
destino = carpeta / f"informe-{date.today()}.txt"
lineas = ["web-01 UP", "web-02 DOWN", "db-01 UP"]
destino.write_text("\n".join(lineas) + "\n", encoding="utf-8")
print(f"escrito {destino} ({destino.stat().st_size} bytes)")
print(destino.read_text(encoding="utf-8"))
EOF
python3 informe.py
ls informes/
```

👀 **Qué deberías ver:** `escrito informes/informe-AAAA-MM-DD.txt (31 bytes)` con la fecha de hoy, sus tres líneas, y el archivo en `informes/`. `date.today()` da la fecha en formato `2026-10-20`, como el `date +%F` de Bash.

**Y recorrer carpetas:**

```bash
python3 -c '
from pathlib import Path
curso = Path.home() / "my-devops-journey"
for readme in sorted(curso.glob("fase-*/README.md")):
    print(readme.parent.name, readme.stat().st_size, "bytes")
'
```

👀 **Qué deberías ver:** una línea por fase (`fase-1`, `fase-10`, `fase-2`…, en orden alfabético) con el tamaño de su README.

✋ **Sin mirar:** ¿cómo creas con `pathlib` una carpeta, con todas las que falten por el camino, sin error si ya existe?

<details>
<summary>Comprueba</summary>

`Path("a/b/c").mkdir(parents=True, exist_ok=True)`: lo mismo que `mkdir -p`.
</details>

**En resumen:** `Path` une rutas con `/` y sabe mirar (`exists`, `stat`), leer y escribir (`read_text`, `write_text`), crear (`mkdir`) y buscar (`glob`).

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Rutas relativas a tu script

Una ruta relativa se resuelve desde la carpeta **actual**, igual que en Bash: desde cron (clase 20), esa carpeta es tu HOME. Para encontrar archivos que viven junto al script:

```python
AQUI = Path(__file__).resolve().parent
config = AQUI / "urls.txt"
```

Es el equivalente en Python del `DIR="$(cd "$(dirname "$0")" && pwd)"` de Vigía v0.

**Pruébalo: lee la lista de URLs como Vigía**, ignorando vacías y comentarios, y ejecútalo desde dos carpetas distintas.

```bash
cat > cargar_urls.py <<'EOF'
#!/usr/bin/env python3
"""cargar_urls.py: lee una lista de URLs ignorando vacías y comentarios."""
from pathlib import Path


def cargar_urls(ruta: Path) -> list[str]:
    """Devuelve las URLs del archivo, sin espacios, comentarios ni líneas vacías."""
    urls = []
    with open(ruta, encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if not linea or linea.startswith("#"):
                continue
            urls.append(linea)
    return urls


if __name__ == "__main__":
    for url in cargar_urls(Path(__file__).resolve().parent / "urls.txt"):
        print(f"[{url}]")
EOF
python3 cargar_urls.py
cd /tmp && python3 ~/my-devops-journey/labs/clase-43/cargar_urls.py; cd -
```

👀 **Qué deberías ver:** las tres URLs, sin espacios ni comentarios, **las dos veces**: la segunda, desde `/tmp`, funciona igual gracias a `Path(__file__)`. Compara con el bucle `while read` de la clase 18: sin `IFS=`, sin `-r` y sin el truco de la última línea sin salto, porque Python la lee igual.

✋ **Sin mirar:** ¿qué es `Path(__file__).resolve().parent`?

<details>
<summary>Comprueba</summary>

La carpeta donde está el propio script, en ruta absoluta, se ejecute desde donde se ejecute.
</details>

**En resumen:** para los archivos que acompañan al script, `Path(__file__).resolve().parent / "archivo"`; así funciona igual desde cron.

### Pieza 5 — Todo junto: analizar el log de nginx de la clase 05

Leer línea a línea con `with`, partir con `split`, contar con un diccionario y encontrar el archivo con `pathlib`.

**Pruébalo:**

```bash
cat > analizar_log.py <<'EOF'
#!/usr/bin/env python3
"""analizar_log.py: cuenta códigos de estado e IPs de un access.log de nginx."""
from pathlib import Path

LOG = Path.home() / "my-devops-journey" / "recursos" / "clase-05" / "access.log"


def main():
    por_grupo = {}
    por_ip = {}
    total = 0
    with open(LOG, encoding="utf-8") as f:
        for linea in f:
            campos = linea.split()
            ip, codigo = campos[0], campos[8]
            grupo = codigo[0] + "xx"
            por_grupo[grupo] = por_grupo.get(grupo, 0) + 1
            por_ip[ip] = por_ip.get(ip, 0) + 1
            total += 1
    print(f"{total} peticiones")
    for grupo in sorted(por_grupo):
        print(f"  {grupo}: {por_grupo[grupo]}")
    print("IPs con más peticiones:")
    for ip, n in sorted(por_ip.items(), key=lambda par: par[1], reverse=True)[:3]:
        print(f"  {ip:<15} {n}")


if __name__ == "__main__":
    main()
EOF
time python3 analizar_log.py
```

🔮 **Predice** los totales: son los mismos que dio tu `contar-codigos.sh` de la clase 18.

👀 **Qué deberías ver:** `2120 peticiones`; `2xx: 1611`, `3xx: 155`, `4xx: 252` y `5xx: 102`; y arriba del todo la IP `198.51.100.7`, con 169 peticiones: la del ataque de la clase 05. Compara también el tiempo con el del bucle de Bash.

✋ **Sin mirar:** si `codigo` vale `"503"`, ¿qué da `codigo[0] + "xx"`?

<details>
<summary>Comprueba</summary>

`"5xx"`: `codigo[0]` es el primer carácter del texto.
</details>

**En resumen:** un log se procesa con `with open`, `split` por línea y un diccionario para contar; mucho más rápido que un bucle de Bash.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `s.strip()` · `s.split()` · `s.split(":")` · `", ".join(l)` | limpiar · partir por espacios · por `:` · unir |
| `s.startswith(("http://", "https://"))` · `"x" in s` | ¿empieza por alguno? · ¿contiene? |
| `with open(ruta, encoding="utf-8") as f: for linea in f:` | leer línea a línea |
| `open(ruta, "w", …)` · `open(ruta, "a", …)` · `print(x, file=f)` | escribir desde cero · añadir · escribir una línea |
| `Path.home() / "carpeta" / "archivo"` | unir rutas |
| `p.exists()` · `p.is_file()` · `p.stat().st_size` · `p.name` · `p.parent` | mirar una ruta |
| `p.read_text(encoding="utf-8")` · `p.write_text(texto, encoding="utf-8")` | leer o escribir todo de una vez |
| `Path("d").mkdir(parents=True, exist_ok=True)` · `p.glob("*.log")` · `p.rglob("*")` | `mkdir -p` · buscar · buscar también en subcarpetas |
| `Path(__file__).resolve().parent` | la carpeta del propio script |
| `from datetime import date; date.today()` | la fecha de hoy (`2026-10-20`) |

## Rómpelo

**1. Un archivo que no existe:**
```bash
python3 -c 'open("no-existe.txt")'
```
`FileNotFoundError: [Errno 2] No such file or directory: 'no-existe.txt'`. El `Errno 2` es el mismo error del sistema que ves en `ls` o `cat`. En la clase 44 aprenderás a capturarlo y a dar un mensaje útil.

**2. `"w"` borra lo que había:**
```bash
echo "datos importantes" > valioso.txt
python3 -c '
with open("valioso.txt", "w", encoding="utf-8") as f:
    pass
'
cat valioso.txt; wc -c valioso.txt
```
El archivo quedó vacío: abrir en modo `"w"` lo vacía **antes** de escribir, igual que `>` en la clase 04. Para añadir, `"a"`.

**3. Leer un binario como texto:**
```bash
python3 -c 'open("/usr/bin/ls", encoding="utf-8").read()'
```
`UnicodeDecodeError: 'utf-8' codec can't decode byte…`. Los ejecutables, las imágenes y los `.tar.gz` no son texto. Para leerlos: `open(ruta, "rb")`, que devuelve *bytes*.

**4. La ruta relativa y la carpeta actual:**
```bash
cat > relativa.py <<'EOF'
from pathlib import Path
print(Path("urls.txt").exists())
EOF
python3 relativa.py
cd /tmp && python3 ~/my-devops-journey/labs/clase-43/relativa.py; cd -
```
`True` desde la carpeta de la clase y `False` desde `/tmp`. Es el mismo problema de cron de la clase 20. Arreglo: `Path(__file__).resolve().parent / "urls.txt"`.

## Reto

En `labs/clase-43/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** `grandes.py <carpeta>`: lista los 5 archivos más grandes dentro de una carpeta y de sus subcarpetas, con el tamaño en KB. Recibe la carpeta con `sys.argv[1]` (`import sys`; `sys.argv` es la lista de argumentos, como `$@`).

> 🧩 **Ejemplo resuelto:** los archivos de **una** carpeta, sin subcarpetas, con su tamaño.
> ```python
> from pathlib import Path
> for p in Path(".").glob("*"):
>     if p.is_file():
>         print(p.stat().st_size, p)
> ```

**Ahora tú, con huecos:**
```python
import sys
from pathlib import Path

carpeta = Path(sys.argv[____])
archivos = [p for p in carpeta.____("*") if p.is_file()]
for p in sorted(archivos, key=lambda p: p.stat().____, reverse=True)[:____]:
    print(f"{p.stat().st_size / 1024:10.1f} KB  {p}")
```

<details>
<summary>Pista</summary>

`sys.argv[0]` es el nombre del script, como `$0`; la carpeta llega en la siguiente posición. Para entrar también en las subcarpetas, el `glob` que lleva una `r` delante (está en la chuleta).
</details>

**2.** `errores.py`: guarda en `errores-5xx.txt` solo las líneas del `access.log` con código 5xx y di cuántas escribiste.

> 🧩 **Ejemplo resuelto:** contar (sin guardar) las peticiones `POST`.
> ```python
> n = 0
> with open(LOG, encoding="utf-8") as f:
>     for linea in f:
>         if linea.split()[5] == '"POST':
>             n += 1
> print(n, "POST")
> ```

**Ahora tú, con huecos:**
```python
n = 0
with open(LOG, encoding="utf-8") as entrada, open("errores-5xx.txt", "____", encoding="utf-8") as salida:
    for linea in entrada:
        if linea.split()[8].startswith("____"):
            salida.write(linea)
            n += 1
print(f"{n} líneas escritas en errores-5xx.txt")
```

<details>
<summary>Pista</summary>

Un `with` puede abrir dos archivos a la vez. La salida se escribe desde cero, y un código 5xx empieza por un carácter concreto. Deberían salir las mismas 102 de la pieza 5.
</details>

**3.** `limpiar.py`: lee `urls.txt` y escribe `urls-limpias.txt` sin comentarios, sin líneas vacías, sin repetidos y en orden alfabético.

> 🧩 **Ejemplo resuelto:** quitar repetidos y ordenar: `sorted(set(["b", "a", "b"]))` → `['a', 'b']`.

**Ahora tú, con huecos:**
```python
from pathlib import Path
from cargar_urls import cargar_urls

urls = sorted(____(cargar_urls(Path("urls.txt"))))
Path("urls-limpias.txt").write_text("\n".join(____) + "\n", encoding="utf-8")
```

<details>
<summary>Pista</summary>

`cargar_urls` ya quita comentarios y vacías (pieza 4). Lo que falta: quitar repetidos (la colección de la clase 41 que no los admite) y unir con saltos de línea.
</details>

## Cierre

En `notas/fase-4/clase-43.md`:

1. ¿Por qué se abre un archivo con `with`? ¿Qué pasaría si el programa falla a mitad sin `with`? *(2 líneas. Empieza así: «Porque `with` cierra el archivo al salir del bloque, también si… Sin él, un fallo a mitad podría dejar…»)*
2. ¿Qué diferencia hay entre los modos `"w"` y `"a"`? ¿A qué operadores de Bash equivalen? *(2 líneas. Empieza así: «`"w"` vacía el archivo y… como `>`; `"a"`…»)*
3. ¿Por qué `Path(__file__).resolve().parent` hace que un script funcione desde cron? *(2 líneas. Empieza así: «Porque calcula la carpeta del script a partir de…, en lugar de depender de… y cron ejecuta desde…»)*
4. **Repaso (clase 42, sin mirar):** ¿qué devuelve una función que no tiene `return`? *(1 línea. Empieza así: «Devuelve…»)*

Después, escríbeme `examíname clase-43`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `with` cierra el archivo al salir del bloque pase lo que pase, también con un error. Sin él, un fallo a mitad podría dejar el archivo abierto, con datos sin escribir en el disco (siguen en un búfer) o sin liberar el descriptor de archivo. En un programa que corre mucho tiempo, los descriptores sin cerrar se acumulan hasta el límite del sistema.

**2.** `"w"` vacía el archivo al abrirlo y escribe desde cero, como `>`. `"a"` conserva lo que había y añade al final, como `>>`.

**3.** Porque calcula la carpeta **del script** a partir de su propia ruta (`__file__`), en lugar de depender de la carpeta actual. Cron ejecuta los trabajos desde tu HOME, así que una ruta relativa como `urls.txt` apuntaría a `~/urls.txt`.

**4.** `None`.

**Reto 1 (una solución):**
```python
import sys
from pathlib import Path

carpeta = Path(sys.argv[1])
archivos = [p for p in carpeta.rglob("*") if p.is_file()]
for p in sorted(archivos, key=lambda p: p.stat().st_size, reverse=True)[:5]:
    print(f"{p.stat().st_size / 1024:10.1f} KB  {p}")
```

**Reto 2:** `"w"` y `"5"`: `102 líneas escritas en errores-5xx.txt`.

**Reto 3 (la parte central):**
```python
urls = sorted(set(cargar_urls(Path("urls.txt"))))
Path("urls-limpias.txt").write_text("\n".join(urls) + "\n", encoding="utf-8")
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| file handle | archivo abierto |
| to read / to write / to append | leer / escribir / añadir |
| path | ruta |
| encoding | codificación |
| context manager (`with`) | gestor de contexto |

🎙️ *"I use pathlib for file paths and always open files with a context manager, so they're closed even if something fails halfway."*

## Siguiente

[Clase 44 — Errores y excepciones](clase-44-errores.md)
