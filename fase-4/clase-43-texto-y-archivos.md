# Clase 43 — Texto, archivos y rutas

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Python desde cero

## Objetivo

- Manipular texto con los métodos de `str`: `strip`, `split`, `join`, `startswith`, `replace`…
- Leer y escribir archivos de forma segura con `with open(...)`.
- Trabajar con rutas usando `pathlib`: unir, comprobar, listar y crear carpetas.
- Procesar un log real línea a línea y escribir un informe.

## Por qué importa

Gran parte del trabajo de operaciones consiste en leer archivos de texto (logs, configuraciones, listas de servidores) y escribir otros (informes, inventarios). En las clases 05 y 18 lo hiciste con `awk`, `cut` y bucles de Bash. En Python es más legible y mucho más rápido que un bucle de Bash, y con `pathlib` las rutas dejan de ser texto que se rompe con un espacio.

## Teoría

### Métodos de texto

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

### Abrir archivos con `with`

```python
with open("urls.txt", encoding="utf-8") as f:       # "r" (leer) es el modo por defecto
    for linea in f:                                  # línea a línea, sin cargar todo
        print(linea.strip())

with open("informe.txt", "w", encoding="utf-8") as f:   # "w" vacía el archivo antes
    f.write("primera línea\n")

with open("historial.log", "a", encoding="utf-8") as f: # "a" añade al final
    print("otra línea", file=f)
```

`with` cierra el archivo al salir del bloque, también si hay un error. Es el equivalente a cerrar bien un recurso, y así se trabaja siempre. Los modos recuerdan a la clase 04: `"w"` es como `>` y `"a"` como `>>`.

Escribe siempre `encoding="utf-8"`: así tu programa lee igual tildes y eñes en cualquier sistema.

### `pathlib`: rutas que no se rompen

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

### Rutas relativas a tu script

Una ruta relativa se resuelve desde la carpeta **actual**, igual que en Bash: desde cron (clase 20), esa carpeta es tu HOME. Para encontrar archivos que viven junto al script:

```python
AQUI = Path(__file__).resolve().parent
config = AQUI / "urls.txt"
```

Es el equivalente en Python del `DIR="$(cd "$(dirname "$0")" && pwd)"` de Vigía v0.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-43 && cd ~/my-devops-journey/labs/clase-43
```

### 1. Métodos de texto

```bash
python3
```

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

🔮 **Predice** qué hay en `partes[5]` antes de verlo. `split()` corta por espacios, así que la comilla de `"POST` sigue pegada. `strip('"')` la quita. `startswith` acepta una tupla: "¿empieza por alguna de estas?".

### 2. Leer una lista de URLs, como Vigía

```bash
cat > urls.txt <<'EOF'
# Sitios que quiero vigilar
https://example.com

   https://www.wikipedia.org
https://github.com
EOF

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

La segunda ejecución, desde `/tmp`, funciona igual gracias a `Path(__file__)`. Compara con el bucle `while read` de la clase 18: sin `IFS=`, sin `-r` y sin el truco de la última línea sin salto, porque Python la lee igual.

### 3. Analizar el log de nginx de la clase 05

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

🔮 **Predice** los totales: son los mismos que dio tu `contar-codigos.sh` de la clase 18 (1611, 155, 252 y 102). Compara también el tiempo con el del bucle de Bash.

### 4. Escribir un informe

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

`date.today()` da la fecha de hoy en formato `2026-10-20`, como el `date +%F` de Bash.

### 5. Recorrer carpetas

```bash
python3 -c '
from pathlib import Path
curso = Path.home() / "my-devops-journey"
for readme in sorted(curso.glob("fase-*/README.md")):
    print(readme.parent.name, readme.stat().st_size, "bytes")
'
```

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

1. `grandes.py <carpeta>`: lista los 5 archivos más grandes dentro de una carpeta y de sus subcarpetas (`Path.rglob("*")`, `is_file()` y `stat().st_size`), con el tamaño en KB. Recibe la carpeta con `sys.argv[1]` (`import sys`; `sys.argv` es la lista de argumentos, como `$@`).
2. `errores.py`: guarda en `errores-5xx.txt` solo las líneas del `access.log` con código 5xx y di cuántas escribiste.
3. `limpiar.py`: lee `urls.txt` y escribe `urls-limpias.txt` sin comentarios, sin líneas vacías, sin repetidos y en orden alfabético.

## Cierre

En `notas/fase-4/clase-43.md`:

1. ¿Por qué se abre un archivo con `with`? ¿Qué pasaría si el programa falla a mitad sin `with`?
2. ¿Qué diferencia hay entre los modos `"w"` y `"a"`? ¿A qué operadores de Bash equivalen?
3. ¿Por qué `Path(__file__).resolve().parent` hace que un script funcione desde cron?
4. **Repaso (clase 42, sin mirar):** ¿qué devuelve una función que no tiene `return`?

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
