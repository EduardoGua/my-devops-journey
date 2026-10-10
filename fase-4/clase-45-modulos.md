# Clase 45 — Módulos, paquetes y la biblioteca estándar

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

## Objetivo

- Importar código con `import` y `from … import …`, y saber dónde lo busca Python.
- Repartir tu código en **módulos** (archivos) y **paquetes** (carpetas) y ejecutarlos con `python3 -m`.
- Entender por fin `if __name__ == "__main__":`.
- Conocer las piezas de la biblioteca estándar que más usarás en operaciones: `datetime`, `time`, `collections`, `statistics`, `socket` e `ipaddress`.

## Por qué importa

Python viene "con las pilas incluidas": su biblioteca estándar resuelve sin instalar nada fechas, estadísticas, DNS, redes IP, archivos comprimidos y mucho más. Saber qué hay ahí evita reinventar (y depurar) lo que ya existe. Y repartir el código en módulos es lo que te permitirá organizar Vigía en piezas pequeñas: configuración, chequeo, almacenamiento y API.

## Teoría

### Formas de importar

```python
import math                          # usas math.sqrt(16)
from pathlib import Path             # usas Path(...) directamente
from datetime import datetime, timezone
import statistics as st              # con alias: st.mean(...)
```

Pon los `import` al principio del archivo: primero la biblioteca estándar, después lo instalado con pip y por último tus módulos.

### Módulos y paquetes

- Un **módulo** es un archivo `.py`. Si tienes `red.py`, otro archivo de la misma carpeta puede hacer `import red`.
- Un **paquete** es una carpeta con un archivo `__init__.py` (puede estar vacío) y módulos dentro: `from herramientas.red import resolver`.

```
labs/clase-45/
├── diagnostico.py
└── herramientas/
    ├── __init__.py
    ├── red.py
    └── tiempo.py
```

`python3 -m herramientas.red` ejecuta un módulo de un paquete como programa. Así arrancarás Vigía: `python3 -m vigia check`.

### `__name__` y `"__main__"`

Cada módulo tiene una variable `__name__`. Si lo **ejecutas**, vale `"__main__"`; si lo **importas**, vale su nombre (`"herramientas.red"`). Por eso:

```python
if __name__ == "__main__":
    main()            # solo al ejecutar el archivo, nunca al importarlo
```

### Dónde busca Python los módulos

En este orden: la carpeta del script que ejecutas (o la actual, con `-m` o en modo interactivo), después la biblioteca estándar y por último lo instalado con pip. Consecuencia peligrosa: si llamas `random.py` o `json.py` a un archivo tuyo, **tapa** el módulo estándar del mismo nombre (Rómpelo 1).

### La biblioteca estándar para operaciones

| Módulo | Para qué | Ejemplo |
|--------|----------|---------|
| `datetime` | fechas y horas | `datetime.now(timezone.utc).isoformat(timespec="seconds")` |
| `time` | esperar y cronometrar | `time.sleep(2)`, `time.perf_counter()` |
| `collections` | contar y agrupar | `Counter(codigos).most_common(3)` |
| `statistics` | media, mediana, percentiles | `statistics.median(tiempos)` |
| `socket` | DNS y conexiones de red | `socket.gethostbyname("example.com")` |
| `ipaddress` | IPs y subredes | `ipaddress.ip_network("10.0.0.0/16").subnets(new_prefix=18)` |
| `os`, `sys`, `pathlib`, `shutil` | sistema y archivos | clases 43 y 50 |
| `json`, `csv` | datos | clase 47 |
| `argparse`, `logging` | programas de línea de comandos | clase 48 |
| `subprocess` | lanzar comandos | clase 50 |
| `sqlite3` | base de datos | clase 51 |

**Fechas con zona horaria.** `datetime.now()` a secas da la hora local sin zona, y es ambiguo en cuanto mezclas servidores (una EC2 vive en UTC). En registros y bases de datos, usa siempre `datetime.now(timezone.utc)`.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-45/herramientas && cd ~/my-devops-journey/labs/clase-45
```

### 1. Tu primer paquete

```bash
touch herramientas/__init__.py

cat > herramientas/red.py <<'EOF'
"""red.py: utilidades de red."""
import ipaddress
import socket
import sys


def resolver(host: str) -> list[str]:
    """Devuelve las IPv4 de un nombre (lista vacía si no resuelve)."""
    try:
        datos = socket.getaddrinfo(host, None, family=socket.AF_INET)
    except socket.gaierror:
        return []
    return sorted({d[4][0] for d in datos})


def es_privada(ip: str) -> bool:
    """True si la IP es privada (10/8, 172.16/12, 192.168/16…)."""
    return ipaddress.ip_address(ip).is_private


if __name__ == "__main__":
    for host in sys.argv[1:]:
        ips = resolver(host)
        print(f"{host}: {', '.join(ips) if ips else 'no resuelve'}")
EOF

cat > herramientas/tiempo.py <<'EOF'
"""tiempo.py: fechas y cronómetro."""
import time
from datetime import datetime, timezone


def ahora_iso() -> str:
    """Fecha y hora actual en UTC, formato ISO 8601."""
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def cronometrar(funcion, *args):
    """Ejecuta funcion(*args) y devuelve (resultado, segundos que tardó)."""
    inicio = time.perf_counter()
    resultado = funcion(*args)
    return resultado, time.perf_counter() - inicio
EOF

cat > diagnostico.py <<'EOF'
#!/usr/bin/env python3
"""diagnostico.py: resuelve unos nombres y mide cuánto tarda cada uno."""
from herramientas.red import es_privada, resolver
from herramientas.tiempo import ahora_iso, cronometrar

print(f"Diagnóstico de DNS · {ahora_iso()}")
for host in ["example.com", "github.com", "localhost", "no-existe.invalid"]:
    ips, segundos = cronometrar(resolver, host)
    tipo = "privada" if ips and es_privada(ips[0]) else "pública" if ips else "-"
    print(f"{host:<20} {segundos * 1000:6.1f} ms  {', '.join(ips) or 'no resuelve':<18} {tipo}")
EOF
python3 diagnostico.py
python3 -m herramientas.red example.com wikipedia.org
```

🔮 **Predice:** ¿qué IP tendrá `localhost` y será "privada"? ¿Cuál tardará menos la segunda vez que ejecutes el diagnóstico? (Piensa en la caché DNS de la clase 31.)

Funciones que reciben otra función (`cronometrar(resolver, host)`) son normales en Python: las funciones son valores como cualquier otro. `*args` recoge "el resto de argumentos" y los pasa tal cual.

### 2. `__name__` en acción

```bash
python3 -c 'import herramientas.red as r; print(r.__name__)'
python3 -m herramientas.red localhost
```

Al importarlo, `__name__` vale `herramientas.red` y el bloque del final no se ejecuta. Al lanzarlo con `-m`, vale `"__main__"` y sí.

### 3. Contar y estadísticas sin escribir bucles

```bash
cat > estadisticas.py <<'EOF'
import statistics
from collections import Counter
from pathlib import Path

log = Path.home() / "my-devops-journey" / "recursos" / "clase-05" / "access.log"
codigos = [linea.split()[8] for linea in log.read_text(encoding="utf-8").splitlines()]
print("Más frecuentes:", Counter(codigos).most_common(3))

tiempos = [0.21, 0.25, 0.23, 0.95, 0.22, 0.24, 2.80, 0.26, 0.23, 0.25]
print(f"media   {statistics.mean(tiempos):.3f} s")
print(f"mediana {statistics.median(tiempos):.3f} s")
print(f"p90     {statistics.quantiles(tiempos, n=10, method='inclusive')[-1]:.3f} s")
EOF
python3 estadisticas.py
```

🔮 **Predice:** con un tiempo de 2,80 s entre los demás, ¿qué se parecerá más a "lo normal", la media o la mediana? Por eso los paneles de monitoreo muestran medianas y percentiles (lo verás en la fase 10), no solo medias.

`method='inclusive'` hace que el percentil se calcule solo con tus datos. Con pocos valores, el método por defecto extrapola y puede darte un p95 **mayor que el máximo**.

### 4. Subredes sin calcular a mano

```bash
python3 -c '
import ipaddress
red = ipaddress.ip_network("10.0.0.0/16")
for subred in red.subnets(new_prefix=18):
    print(subred, subred.num_addresses, "direcciones")
print(ipaddress.ip_address("172.20.5.4") in ipaddress.ip_network("172.16.0.0/12"))
'
```

Es el ejercicio de un criterio de salida de la fase 3. Sigue sabiendo hacerlo en papel: Python solo te sirve para **comprobarlo**.

## Rómpelo

**1. Tapar la biblioteca estándar:**
```bash
echo 'print("¡soy un random falso!")' > random.py
python3 -c 'import random; print(random.randint(1, 6))'
rm random.py
```
Python encuentra **tu** `random.py` (está en la carpeta actual) antes que el de la biblioteca estándar: imprime el mensaje falso y después `AttributeError: module 'random' has no attribute 'randint'`. Python 3.14 incluso añade la pista: `consider renaming '…/random.py' since it has the same name as the standard library module`. Nunca nombres un archivo como un módulo estándar (`json.py`, `random.py`, `email.py`, `logging.py`…).

**2. Importar desde la carpeta equivocada:**
```bash
cd /tmp && python3 -m herramientas.red example.com; cd -
```
`No module named herramientas`: con `-m`, Python busca el paquete en la carpeta actual. Hay que lanzarlo desde la carpeta que **contiene** el paquete.

**3. Una fecha sin zona horaria:**
```bash
python3 -c '
from datetime import datetime, timezone
sin_zona = datetime.now()
con_zona = datetime.now(timezone.utc)
print(sin_zona.isoformat(), "|", con_zona.isoformat())
print(con_zona - sin_zona)
'
```
`TypeError: can't subtract offset-naive and offset-aware datetimes`. Python no deja mezclar fechas con zona y sin ella porque el resultado sería ambiguo. Elige UTC y úsala siempre.

## Reto

1. Añade a `herramientas/red.py` una función `puerto_abierto(host, puerto, timeout=3) -> bool` que intente una conexión TCP con `socket.create_connection((host, puerto), timeout)`. Debe devolver `False` (sin traza) si la conexión se rechaza o se agota el tiempo. Pruébala con `example.com` en el 443 y el 81, y con `127.0.0.1` en un puerto donde no escuche nada. Pista: `except OSError`.
2. `percentiles.py`: con la lista de `tiempos` de la práctica 3, imprime la mediana, el percentil 95 (`statistics.quantiles(tiempos, n=100, method='inclusive')[94]`) y el máximo. ¿Cuál usarías para decir "casi todas las peticiones tardan menos de X"?
3. Usa `datetime` y `timedelta` para imprimir la fecha (UTC) dentro de 7 días y hace 7 días, en formato ISO. ¿Te recuerda a la rotación de backups de la clase 20?

## Cierre

En `notas/fase-4/clase-45.md`:

1. ¿Qué diferencia hay entre un módulo y un paquete? ¿Cómo ejecutas un módulo que está dentro de un paquete?
2. Explica qué vale `__name__` al ejecutar un archivo y al importarlo, y para qué sirve `if __name__ == "__main__":`.
3. ¿Por qué un archivo tuyo llamado `random.py` puede romper otro programa? ¿Cómo lo evitas?
4. **Repaso (clase 44, sin mirar):** ¿por qué no se debe usar `except:` a secas?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un módulo es un archivo `.py`; un paquete es una carpeta con `__init__.py` que agrupa módulos. Un módulo de un paquete se ejecuta con `python3 -m paquete.modulo`, desde la carpeta que contiene el paquete.

**2.** Al ejecutar el archivo, `__name__` vale `"__main__"`; al importarlo, el nombre del módulo. El `if` hace que el código de arranque solo se ejecute al lanzarlo directamente, de modo que otros archivos (y las pruebas) pueden importar sus funciones sin efectos secundarios.

**3.** Porque Python busca primero en la carpeta del script o en la actual, así que tu `random.py` tapa el módulo estándar y cualquier `import random` de esa carpeta carga el tuyo. Se evita no usando nombres de módulos estándar ni de paquetes instalados para tus archivos.

**4.** Porque captura todo, también `KeyboardInterrupt` (el `Ctrl+C`) y errores de programación que deberían verse, como una errata. Hay que capturar las excepciones concretas que sabes tratar.

**Reto 1 (una solución):**
```python
def puerto_abierto(host: str, puerto: int, timeout: float = 3) -> bool:
    """True si se puede abrir una conexión TCP a host:puerto."""
    try:
        with socket.create_connection((host, puerto), timeout=timeout):
            return True
    except OSError:
        return False
```
`OSError` cubre la conexión rechazada, el tiempo agotado y el nombre que no resuelve.

**Reto 2:** el percentil 95. "El 95 % de las peticiones tarda menos de X" describe la experiencia de casi todos los usuarios sin que un caso extremo la deforme, como le pasa a la media.

**Reto 3:**
```python
from datetime import datetime, timedelta, timezone
ahora = datetime.now(timezone.utc)
print((ahora + timedelta(days=7)).isoformat(timespec="seconds"))
print((ahora - timedelta(days=7)).isoformat(timespec="seconds"))
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| module / package | módulo / paquete |
| standard library | biblioteca estándar |
| import path | ruta de búsqueda de módulos |
| timezone-aware | con zona horaria |
| percentile | percentil |

🎙️ *"Before installing a dependency, I check the standard library: datetime, statistics, ipaddress and pathlib cover a lot of everyday operations work."*

## Siguiente

[Clase 46 — Entornos virtuales y dependencias](clase-46-entornos-virtuales.md)
