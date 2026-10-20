# Clase 45 — Módulos, paquetes y la biblioteca estándar

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

> 💡 **La idea de hoy:** un **módulo** es un archivo `.py` cuyas funciones puedes usar desde otro con `import`, y un **paquete** es una carpeta de módulos. Python trae una **biblioteca estándar** enorme (fechas, estadísticas, DNS, IPs…) que se usa sin instalar nada. Saber qué hay ahí te ahorra escribir y depurar lo que ya existe, y repartir tu código en módulos es lo que te dejará organizar Vigía por piezas.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `import`, `from … import …` y `if __name__ == "__main__":` (clase 42, pieza 5).
> - Contar con un diccionario y el `access.log` de la clase 05 (clases 41 y 43).
> - DNS y la caché de `systemd-resolved` (clase 31).
> - Subredes y rangos privados (clases 27 y 28).
> - Capturar errores concretos con `try` / `except` (clase 44).

> 🔤 **Palabras nuevas de hoy:**
> - **módulo**: un archivo `.py` que se puede importar.
> - **paquete**: una carpeta con un `__init__.py` y módulos dentro.
> - **`python3 -m paquete.modulo`**: ejecutar un módulo de un paquete como programa.
> - **`__name__`**: el nombre del módulo; vale `"__main__"` cuando lo ejecutas directamente.
> - **biblioteca estándar**: los módulos que vienen con Python.
> - **mediana** y **percentil**: el valor del medio, y el valor por debajo del cual queda un porcentaje de los datos.

## Objetivo

- Importar código con `import` y `from … import …`, y saber dónde lo busca Python.
- Repartir tu código en **módulos** (archivos) y **paquetes** (carpetas) y ejecutarlos con `python3 -m`.
- Entender por fin `if __name__ == "__main__":`.
- Conocer las piezas de la biblioteca estándar que más usarás en operaciones: `datetime`, `time`, `collections`, `statistics`, `socket` e `ipaddress`.

## Por qué importa

Python viene "con las pilas incluidas" (*batteries included*, su lema): su biblioteca estándar resuelve sin instalar nada fechas, estadísticas, DNS, redes IP, archivos comprimidos y mucho más. Saber qué hay ahí evita reinventar (y depurar) lo que ya existe. Y repartir el código en módulos es lo que te permitirá organizar Vigía en piezas pequeñas: configuración, chequeo, almacenamiento y API.

## Cómo va esta clase

Seis piezas: tres sobre cómo se organiza el código y tres con la biblioteca estándar. En cada una lees **una** idea (en la 2, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-45/herramientas && cd ~/my-devops-journey/labs/clase-45
```

## Las piezas

### Pieza 1 — Las formas de importar

```python
import math                          # usas math.sqrt(16)
from pathlib import Path             # usas Path(...) directamente
from datetime import datetime, timezone
import statistics as st              # con alias: st.mean(...)
```

Pon los `import` al principio del archivo: primero la biblioteca estándar, después lo instalado con pip y por último tus módulos.

**Pruébalo:**

```bash
python3 -c '
import math
from pathlib import Path
import statistics as st
print(math.sqrt(16), Path.home(), st.mean([1, 2, 3, 4]))
'
```

👀 **Qué deberías ver:** `4.0 /home/educo 2.5`.

✋ **Sin mirar:** ¿en qué orden se ponen los `import` al principio de un archivo?

<details>
<summary>Comprueba</summary>

Primero la biblioteca estándar, después lo instalado con pip y al final tus propios módulos.
</details>

**En resumen:** `import x` y usas `x.algo`; `from x import algo` y usas `algo`; `as` pone un alias.

### Pieza 2 — Tu primer paquete, y `__name__`

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

Cada módulo tiene una variable `__name__`. Si lo **ejecutas**, vale `"__main__"`; si lo **importas**, vale su nombre (`"herramientas.red"`). Por eso `if __name__ == "__main__": main()` solo corre al ejecutar el archivo, nunca al importarlo.

**Pruébalo:**

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
python3 -m herramientas.red example.com wikipedia.org no-existe.invalid
python3 -c 'import herramientas.red as r; print(r.__name__, r.resolver("localhost"))'
```

👀 **Qué deberías ver:** cada nombre con sus IPv4 (y `no-existe.invalid: no resuelve`); y, al importarlo, `herramientas.red ['127.0.0.1']`, **sin** la lista de nombres: el bloque del final no se ejecutó porque `__name__` no valía `"__main__"`.

✋ **Sin mirar:** ¿qué archivo convierte una carpeta en un paquete de Python?

<details>
<summary>Comprueba</summary>

`__init__.py` (aunque esté vacío).
</details>

**En resumen:** un `.py` es un módulo y una carpeta con `__init__.py`, un paquete; `python3 -m paquete.modulo` lo ejecuta, y `__name__` dice si lo ejecutas o lo importas.

### Pieza 3 — Dónde busca Python los módulos

En este orden: la carpeta del script que ejecutas (o la actual, con `-m` o en modo interactivo), después la biblioteca estándar y por último lo instalado con pip. Consecuencia peligrosa: si llamas `random.py` o `json.py` a un archivo tuyo, **tapa** el módulo estándar del mismo nombre (Rómpelo 1).

**Pruébalo:**

```bash
python3 -c 'import sys; print(sys.path[:2])'
python3 -c 'import random; print(random.__file__)'
```

👀 **Qué deberías ver:** la lista de carpetas donde busca, empezando por `''` (la carpeta actual); y la ruta del `random` de verdad, dentro de `/usr/lib/python3.14/`.

✋ **Sin mirar:** ¿dónde busca Python un módulo **antes** que en la biblioteca estándar?

<details>
<summary>Comprueba</summary>

En la carpeta del script (o en la actual, con `-m` y en el intérprete). Por eso un archivo tuyo con el nombre de un módulo estándar lo tapa.
</details>

**En resumen:** Python busca primero en tu carpeta, después en la biblioteca estándar y luego en lo instalado; no nombres tus archivos como módulos estándar.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Fechas y cronómetro: `datetime` y `time`

| Módulo | Para qué | Ejemplo |
|--------|----------|---------|
| `datetime` | fechas y horas | `datetime.now(timezone.utc).isoformat(timespec="seconds")` |
| `time` | esperar y cronometrar | `time.sleep(2)`, `time.perf_counter()` |

**Fechas con zona horaria.** `datetime.now()` a secas da la hora local sin zona, y es ambiguo en cuanto mezclas servidores (una EC2 vive en UTC). En registros y bases de datos, usa siempre `datetime.now(timezone.utc)`.

**Pruébalo:** un módulo de tiempo y un diagnóstico que usa los dos módulos del paquete.

```bash
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
python3 diagnostico.py
```

🔮 **Predice:** ¿qué IP tendrá `localhost` y será "privada"? ¿Cuál tardará menos la segunda vez? (Piensa en la caché DNS de la clase 31.)

👀 **Qué deberías ver:** la fecha en UTC (`…+00:00`); cada nombre con su tiempo, sus IPs y si son públicas o privadas (`localhost` → `127.0.0.1`, privada); y, en la segunda ejecución, tiempos más bajos: las respuestas salen de la caché.

Funciones que reciben otra función (`cronometrar(resolver, host)`) son normales en Python: las funciones son valores como cualquier otro. `*args` recoge "el resto de argumentos" y los pasa tal cual.

✋ **Sin mirar:** ¿por qué se guardan las fechas en UTC en logs y bases de datos?

<details>
<summary>Comprueba</summary>

Porque la hora local depende de cada máquina y de su zona: con UTC, las fechas de varios servidores se comparan sin ambigüedad.
</details>

**En resumen:** `datetime.now(timezone.utc).isoformat()` para fechas, y `time.perf_counter()` para cronometrar.

### Pieza 5 — Contar y estadísticas sin bucles: `collections` y `statistics`

| Módulo | Para qué | Ejemplo |
|--------|----------|---------|
| `collections` | contar y agrupar | `Counter(codigos).most_common(3)` |
| `statistics` | media, mediana, percentiles | `statistics.median(tiempos)` |

**Pruébalo:**

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

🔮 **Predice:** con un tiempo de 2,80 s entre los demás, ¿qué se parecerá más a "lo normal", la media o la mediana?

👀 **Qué deberías ver:** `Más frecuentes: [('200', 1611), ('404', 132), ('401', 120)]`; `media 0.564 s`, `mediana 0.245 s` y `p90 1.135 s`. La mediana describe "lo normal"; la media la deforma un solo caso lento. Por eso los paneles de monitoreo muestran medianas y percentiles (fase 10), no solo medias.

`method='inclusive'` hace que el percentil se calcule solo con tus datos. Con pocos valores, el método por defecto extrapola y puede darte un p95 **mayor que el máximo**.

✋ **Sin mirar:** ¿qué devuelve `Counter(codigos).most_common(3)`?

<details>
<summary>Comprueba</summary>

Los 3 valores más repetidos, cada uno con cuántas veces aparece, de más a menos: lo que hacía `sort | uniq -c | sort -rn | head -3`.
</details>

**En resumen:** `Counter` cuenta en una línea, y `statistics` da media, mediana y percentiles.

### Pieza 6 — IPs y subredes sin calcular a mano: `ipaddress`

| Módulo | Para qué | Ejemplo |
|--------|----------|---------|
| `ipaddress` | IPs y subredes | `ipaddress.ip_network("10.0.0.0/16").subnets(new_prefix=18)` |
| `socket` | DNS y conexiones de red | `socket.gethostbyname("example.com")` |

Y para el resto de la fase: `os`, `sys`, `pathlib` y `shutil` (sistema y archivos, clases 43 y 50), `json` y `csv` (clase 47), `argparse` y `logging` (clase 48), `subprocess` (clase 50) y `sqlite3` (clase 51).

**Pruébalo:**

```bash
python3 -c '
import ipaddress
red = ipaddress.ip_network("10.0.0.0/16")
for subred in red.subnets(new_prefix=18):
    print(subred, subred.num_addresses, "direcciones")
print(ipaddress.ip_address("172.20.5.4") in ipaddress.ip_network("172.16.0.0/12"))
'
```

👀 **Qué deberías ver:** las cuatro `/18` (`10.0.0.0/18`, `10.0.64.0/18`, `10.0.128.0/18` y `10.0.192.0/18`), con 16384 direcciones cada una, y `True`.

Es el ejercicio de un criterio de salida de la fase 3. Sigue sabiendo hacerlo en papel: Python solo te sirve para **comprobarlo**.

✋ **Sin mirar:** ¿cómo compruebas con `ipaddress` si una IP está dentro de una red?

<details>
<summary>Comprueba</summary>

`ipaddress.ip_address("…") in ipaddress.ip_network("…/…")`.
</details>

**En resumen:** `ipaddress` divide redes, comprueba si una IP está dentro y si es privada.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `import x` · `from x import y` · `import x as z` | importar |
| `paquete/__init__.py` · `from paquete.modulo import f` | un paquete · usarlo |
| `python3 -m paquete.modulo args` | ejecutar un módulo de un paquete |
| `if __name__ == "__main__": main()` | solo al ejecutarlo, no al importarlo |
| `datetime.now(timezone.utc).isoformat(timespec="seconds")` | la fecha y hora en UTC |
| `timedelta(days=7)` | 7 días, para sumar o restar a una fecha |
| `time.perf_counter()` · `time.sleep(2)` | cronometrar · esperar |
| `Counter(lista).most_common(3)` | los más repetidos |
| `statistics.mean` · `median` · `quantiles(x, n=100, method="inclusive")[94]` | media · mediana · p95 |
| `socket.getaddrinfo(host, None)` · `socket.create_connection((host, puerto), timeout=3)` | resolver · conectar por TCP |
| `ipaddress.ip_network(r).subnets(new_prefix=N)` · `ip in red` · `.is_private` | dividir · ¿dentro? · ¿privada? |

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

En `labs/clase-45/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade a `herramientas/red.py` una función `puerto_abierto(host, puerto, timeout=3) -> bool` que intente una conexión TCP. Debe devolver `False` (sin traza) si la conexión se rechaza o se agota el tiempo. Pruébala con `example.com` en el 443 y el 81, y con `127.0.0.1` en un puerto donde no escuche nada.

> 🧩 **Ejemplo resuelto:** `resolver` (pieza 2) ya hace algo parecido con el DNS: intenta, captura `socket.gaierror` y devuelve una lista vacía en lugar de una traza.

**Ahora tú, con huecos:**
```python
def puerto_abierto(host: str, puerto: int, timeout: float = 3) -> bool:
    """True si se puede abrir una conexión TCP a host:puerto."""
    try:
        with socket.create_connection((host, ____), timeout=____):
            return ____
    except ____:
        return False
```

<details>
<summary>Pista</summary>

La conexión rechazada, el tiempo agotado y el nombre que no resuelve son, los tres, errores del sistema: la excepción que los cubre es la misma que usaste con los archivos en la clase 44.
</details>

**2.** `percentiles.py`: con la lista de `tiempos` de la pieza 5, imprime la mediana, el percentil 95 y el máximo. ¿Cuál usarías para decir "casi todas las peticiones tardan menos de X"?

> 🧩 **Ejemplo resuelto:** el p90 de la pieza 5: `statistics.quantiles(tiempos, n=10, method='inclusive')[-1]`.

**Ahora tú, con huecos:**
```python
p95 = statistics.quantiles(tiempos, n=____, method="inclusive")[____]
print(f"mediana {statistics.median(tiempos):.3f} · p95 {p95:.3f} · máximo {____(tiempos):.3f}")
```

<details>
<summary>Pista</summary>

Con `n=100`, `quantiles` devuelve 99 cortes: el p95 es el que ocupa la posición 95, es decir, el índice 94 (se cuenta desde 0).
</details>

**3.** Usa `datetime` y `timedelta` para imprimir la fecha (UTC) dentro de 7 días y hace 7 días, en formato ISO. ¿Te recuerda a la rotación de backups de la clase 20?

> 🧩 **Ejemplo resuelto:** mañana.
> ```python
> from datetime import datetime, timedelta, timezone
> ahora = datetime.now(timezone.utc)
> print((ahora + timedelta(days=1)).isoformat(timespec="seconds"))
> ```

**Ahora tú, con huecos:**
```python
print((ahora ____ timedelta(days=____)).isoformat(timespec="seconds"))
print((ahora ____ timedelta(days=____)).isoformat(timespec="seconds"))
```

<details>
<summary>Pista</summary>

Hacia el futuro se suma y hacia el pasado se resta. «Hace 7 días» es el límite del `find -mtime +7` de tu backup.
</details>

## Cierre

En `notas/fase-4/clase-45.md`:

1. ¿Qué diferencia hay entre un módulo y un paquete? ¿Cómo ejecutas un módulo que está dentro de un paquete? *(2 líneas. Empieza así: «Un módulo es…; un paquete es una carpeta con… Se ejecuta con `python3 -m`…, desde…»)*
2. Explica qué vale `__name__` al ejecutar un archivo y al importarlo, y para qué sirve `if __name__ == "__main__":`. *(2 líneas. Empieza así: «Al ejecutarlo vale `"__main__"`; al importarlo,… El `if` sirve para…»)*
3. ¿Por qué un archivo tuyo llamado `random.py` puede romper otro programa? ¿Cómo lo evitas? *(2 líneas. Empieza así: «Porque Python busca primero en la carpeta…, así que mi `random.py` tapa… Lo evito…»)*
4. **Repaso (clase 44, sin mirar):** ¿por qué no se debe usar `except:` a secas? *(1–2 líneas. Empieza así: «Porque captura todo, también…»)*

Después, escríbeme `examíname clase-45`.

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

**Reto 2:** `100` y `94`, y `max`: `mediana 0.245 · p95 1.968 · máximo 2.800`. El percentil 95: "el 95 % de las peticiones tarda menos de X" describe la experiencia de casi todos los usuarios sin que un caso extremo la deforme, como le pasa a la media.

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
