# Clase 51 — SQLite desde Python

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

> 💡 **La idea de hoy:** un log de texto sirve para leerlo; una base de datos sirve para **preguntar**: ¿cuál fue el último estado de cada sitio?, ¿qué disponibilidad tuvo GitHub esta semana? SQLite es una base de datos completa en un solo archivo, incluida en Python. Hoy aprendes el SQL básico (crear una tabla, insertar, filtrar, ordenar y resumir por grupos) y la regla de seguridad de siempre: los valores van **aparte**, con `?`, nunca dentro del texto de la consulta.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Contar y resumir una lista de diccionarios por un campo (clase 41): en SQL es `GROUP BY`.
> - `datetime`, `timedelta` y las fechas ISO 8601 en UTC; `random` (clase 45).
> - `with` para abrir y cerrar recursos (clase 43).
> - La inyección de comandos con `shell=True` (clase 50): la inyección SQL es la misma idea.

> 🔤 **Palabras nuevas de hoy:**
> - **tabla / fila / columna**: los datos en forma de cuadrícula; cada fila es un registro y cada columna, un campo con su tipo.
> - **clave primaria** (*primary key*): la columna que identifica cada fila sin repetirse.
> - **SQL**: el lenguaje para crear tablas y hacer consultas.
> - **consulta** (*query*): una pregunta a la base de datos, como `SELECT … FROM … WHERE …`.
> - **transacción**: un grupo de cambios que se guarda entero (`commit`) o se deshace entero (`rollback`).
> - **inyección SQL**: cuando un dato de fuera acaba cambiando la consulta.

## Objetivo

- Entender qué es una base de datos relacional: tablas, filas, columnas y clave primaria.
- Escribir el SQL básico: `CREATE TABLE`, `INSERT`, `SELECT` con `WHERE`, `ORDER BY`, `LIMIT` y `GROUP BY`.
- Usar `sqlite3` desde Python con **parámetros** (nunca f-strings) y transacciones.
- Crear la tabla de resultados de Vigía y responder con SQL las preguntas que hará su API: el último estado y la disponibilidad de cada sitio.

## Por qué importa

Un log de texto sirve para leerlo; una base de datos sirve para **preguntar**: ¿cuál fue el último estado de cada sitio?, ¿qué disponibilidad tuvo GitHub esta semana?, ¿cuántas caídas hubo ayer? Vigía v1 guardará cada chequeo en SQLite, una base de datos completa en un solo archivo, sin servidor, incluida en Python. En la fase 5 pasarás a PostgreSQL, y el SQL que aprendes hoy sirve casi igual. Y en la nube, RDS (fase 6) es esto mismo, gestionado por AWS.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. La 4 es la consulta que usará la API de Vigía.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 40 min); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre.

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
mkdir -p ~/my-devops-journey/labs/clase-51 && cd ~/my-devops-journey/labs/clase-51
```

Para la pieza 5, el cliente de SQLite de la terminal (opcional, pero útil para mirar dentro de cualquier base de datos SQLite):

```bash
sudo apt install -y sqlite3
```

## Las piezas

### Pieza 1 — Tablas, filas y la clave primaria

Una **tabla** es como una hoja de cálculo con reglas: cada **columna** tiene un nombre y un tipo, y cada **fila** es un registro. La **clave primaria** identifica cada fila sin repetirse.

```sql
CREATE TABLE IF NOT EXISTS checks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,  -- 1, 2, 3… lo pone la base de datos
    url         TEXT    NOT NULL,
    status_code INTEGER NOT NULL,                   -- 0 = no hubo respuesta
    seconds     REAL    NOT NULL,
    up          INTEGER NOT NULL,                   -- 1 = UP, 0 = DOWN
    error       TEXT,                               -- NULL si hubo respuesta HTTP
    checked_at  TEXT    NOT NULL                    -- fecha ISO 8601 en UTC
);

INSERT INTO checks (url, status_code, seconds, up, error, checked_at)
VALUES ('https://example.com', 200, 0.26, 1, NULL, '2026-10-20T02:05:01+00:00');
```

Es la tabla que usará Vigía v1. SQLite no tiene un tipo booleano (se usa `INTEGER` 0/1) ni un tipo fecha: una fecha ISO 8601 como texto se ordena bien porque el año va primero. `NOT NULL` obliga a dar un valor; `NULL` es "sin valor" (el `None` de Python).

**Pruébalo** con una tabla pequeña en memoria (`:memory:` crea una base de datos que desaparece al salir). Por ahora, `con.execute("…")` solo ejecuta SQL; en la pieza 2 verás cómo hacerlo bien desde un programa.

```bash
python
```

```python
>>> import sqlite3
>>> con = sqlite3.connect(":memory:")
>>> con.execute("CREATE TABLE checks (id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT NOT NULL, up INTEGER NOT NULL)")
>>> con.execute("INSERT INTO checks (url, up) VALUES ('https://example.com', 1)")
>>> con.execute("INSERT INTO checks (url, up) VALUES ('https://caido.dev', 0)")
>>> con.execute("SELECT * FROM checks").fetchall()
>>> con.execute("INSERT INTO checks (up) VALUES (1)")
>>> exit()
```

👀 **Qué deberías ver:** cada `execute` responde con `<sqlite3.Cursor object at 0x…>` (es normal); el `SELECT` da `[(1, 'https://example.com', 1), (2, 'https://caido.dev', 0)]`, con los `id` puestos por SQLite; y el último `INSERT`, sin `url`, falla con `sqlite3.IntegrityError: NOT NULL constraint failed: checks.url`.

✋ **Sin mirar:** si no das el `id` al insertar, ¿qué valor pone SQLite?

<details>
<summary>Comprueba</summary>

El siguiente entero (1, 2, 3…): es lo que hace `INTEGER PRIMARY KEY AUTOINCREMENT`.
</details>

**En resumen:** `CREATE TABLE` define columnas, tipos y la clave primaria; `INSERT` añade filas; `SELECT * FROM tabla` las lee.

### Pieza 2 — `sqlite3` en Python: parámetros y transacciones

```python
import sqlite3
from contextlib import closing

with closing(sqlite3.connect("vigia.db")) as con:       # closing: cierra la conexión al salir
    con.row_factory = sqlite3.Row                       # filas que se leen por nombre: fila["url"]
    with con:                                           # una transacción: commit al salir, rollback si hay error
        con.execute(
            "INSERT INTO checks (url, status_code, seconds, up, error, checked_at) VALUES (?, ?, ?, ?, ?, ?)",
            (url, 200, 0.26, 1, None, ahora),           # los valores van APARTE
        )
    for fila in con.execute("SELECT url, up FROM checks WHERE url = ?", (url,)):
        print(fila["url"], fila["up"])
```

- **Parámetros `?`**: los valores se pasan aparte, en una tupla. La base de datos los trata siempre como datos, nunca como SQL. Montar la consulta con una f-string abre la puerta a la **inyección SQL** (Rómpelo 1). Ojo con la tupla de un solo elemento: `(url,)`, con coma.
- **`with con:`** agrupa los cambios en una transacción: si todo va bien, `commit`; si hay una excepción, `rollback`. Pero **no cierra** la conexión: para eso está `closing`.
- Sin `commit`, los cambios no se guardan (Rómpelo 2).

**Pruébalo:** este programa crea la tabla de Vigía y guarda 300 chequeos inventados de hace unos días.

```bash
cat > historial.py <<'EOF'
#!/usr/bin/env python3
"""historial.py: guarda y consulta resultados de chequeos en SQLite."""
import random
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

RUTA = Path("historial.db")
ESQUEMA = """
CREATE TABLE IF NOT EXISTS checks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    url         TEXT    NOT NULL,
    status_code INTEGER NOT NULL,
    seconds     REAL    NOT NULL,
    up          INTEGER NOT NULL,
    error       TEXT,
    checked_at  TEXT    NOT NULL
)
"""


def conectar() -> sqlite3.Connection:
    con = sqlite3.connect(RUTA)
    con.row_factory = sqlite3.Row
    return con


def crear_tabla() -> None:
    with closing(conectar()) as con, con:
        con.execute(ESQUEMA)


def guardar(url: str, codigo: int, segundos: float, error: str | None, fecha: str) -> None:
    arriba = 1 if 200 <= codigo < 400 else 0
    with closing(conectar()) as con, con:
        con.execute(
            "INSERT INTO checks (url, status_code, seconds, up, error, checked_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (url, codigo, segundos, arriba, error, fecha),
        )


def simular(n: int) -> None:
    """Guarda n chequeos inventados de los últimos días."""
    sitios = {"https://example.com": 0.98, "https://github.com": 0.90, "https://caido.dev": 0.10}
    inicio = datetime.now(timezone.utc) - timedelta(days=3)
    for i in range(n):
        url = random.choice(list(sitios))
        responde = random.random() < sitios[url]
        codigo, error = (200, None) if responde else random.choice([(503, None), (0, "timeout")])
        segundos = round(random.uniform(0.1, 1.0) if responde else 10.0, 3)
        fecha = (inicio + timedelta(minutes=5 * i)).isoformat(timespec="seconds")
        guardar(url, codigo, segundos, error, fecha)


if __name__ == "__main__":
    random.seed(42)            # mismos datos "aleatorios" en cada ejecución
    RUTA.unlink(missing_ok=True)
    crear_tabla()
    simular(300)
    print(f"{RUTA} creado")
EOF
python historial.py
ls -l historial.db
```

👀 **Qué deberías ver:** `historial.db creado` y un archivo de unos 32 KB: toda la base de datos es ese archivo. `random.seed(42)` hace que el azar sea siempre el mismo: tus números de la pieza 3 coincidirán con los de esta clase. `with closing(conectar()) as con, con:` son dos `with` en una línea: el primero cierra la conexión y el segundo hace la transacción.

✋ **Sin mirar:** ¿por qué se escribe `(url,)`, con coma, y no `(url)`?

<details>
<summary>Comprueba</summary>

Porque `(url,)` es una tupla de un elemento; `(url)` es solo `url` entre paréntesis, un texto, y `execute` espera una tupla de valores.
</details>

**En resumen:** valores con `?` en una tupla aparte, `with con:` para la transacción y `closing` para cerrar la conexión.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `source ~/my-devops-journey/labs/.venv/bin/activate` y `cd ~/my-devops-journey/labs/clase-51`.

### Pieza 3 — Preguntar con SQL: filtrar, ordenar y resumir

```sql
SELECT url, status_code FROM checks WHERE up = 0 ORDER BY id DESC LIMIT 5;

SELECT url, COUNT(*) AS chequeos, ROUND(AVG(up) * 100, 1) AS disponibilidad
FROM checks GROUP BY url;
```

| Cláusula | Para qué |
|----------|----------|
| `WHERE` | filtrar filas |
| `ORDER BY … DESC` | ordenar (descendente) |
| `LIMIT n` | quedarse con las primeras n |
| `GROUP BY` + `COUNT`, `AVG`, `SUM`, `MAX` | resumir por grupos |

`AS` le pone nombre a una columna calculada. `UPDATE` y `DELETE` cambian o borran filas; **sin `WHERE` afectan a todas** (Rómpelo 3).

🔮 **Predice:** ¿qué sitio tendrá la disponibilidad más baja?

**Pruébalo:**

```bash
cat > consultas.py <<'EOF'
import sqlite3
from contextlib import closing

with closing(sqlite3.connect("historial.db")) as con:
    con.row_factory = sqlite3.Row
    total = con.execute("SELECT COUNT(*) FROM checks").fetchone()[0]
    print(f"{total} chequeos guardados\n")

    print("Los 3 últimos:")
    for f in con.execute("SELECT id, url, status_code, up FROM checks ORDER BY id DESC LIMIT 3"):
        print(f"  #{f['id']} {f['url']:<22} {f['status_code']:>3} {'UP' if f['up'] else 'DOWN'}")

    print("\nDisponibilidad por sitio:")
    consulta = """
        SELECT url, COUNT(*) AS n, ROUND(AVG(up) * 100, 1) AS pct,
               ROUND(AVG(CASE WHEN up = 1 THEN seconds END), 3) AS media_up
        FROM checks GROUP BY url ORDER BY pct DESC
    """
    for f in con.execute(consulta):
        print(f"  {f['url']:<22} {f['n']:>3} chequeos  {f['pct']:>5} %  media {f['media_up']} s")
EOF
python consultas.py
```

👀 **Qué deberías ver:** `300 chequeos guardados`; los 3 últimos, `#300 https://caido.dev 503 DOWN`, `#299 https://github.com 200 UP` y `#298 https://github.com 503 DOWN`; y la disponibilidad: `https://example.com` con 102 chequeos y 99.0 %, `https://github.com` con 93 y 95.7 %, y `https://caido.dev` con 105 y 6.7 %. `CASE WHEN up = 1 THEN seconds END` calcula la media solo de los chequeos que respondieron (los demás valen `NULL` y `AVG` los ignora).

✋ **Sin mirar:** ¿por qué `AVG(up) * 100` da el porcentaje de chequeos UP?

<details>
<summary>Comprueba</summary>

Porque `up` vale 1 o 0: la media de unos y ceros es la proporción de unos. Por 100, el porcentaje.
</details>

**En resumen:** `WHERE` filtra, `ORDER BY … DESC LIMIT n` da los n más recientes y `GROUP BY` con `COUNT`/`AVG` resume cada grupo.

### Pieza 4 — El último estado de cada sitio

Es la consulta que usará la API de Vigía: para cada URL busca el `id` más alto (el chequeo más reciente) y se queda con esa fila. La subconsulta entre paréntesis da una tabla temporal `m` con `url` y su `MAX(id)`; `JOIN … ON c.id = m.id` junta cada una con su fila completa de `checks`.

```sql
SELECT c.url, c.status_code, c.up, c.checked_at FROM checks c
JOIN (SELECT url, MAX(id) AS id FROM checks GROUP BY url) m ON c.id = m.id
ORDER BY c.url;
```

**Pruébalo:**

```bash
cat > ultimo.py <<'EOF'
import sqlite3
from contextlib import closing

ULTIMO = """
    SELECT c.url, c.status_code, c.up, c.checked_at FROM checks c
    JOIN (SELECT url, MAX(id) AS id FROM checks GROUP BY url) m ON c.id = m.id
    ORDER BY c.url
"""

with closing(sqlite3.connect("historial.db")) as con:
    con.row_factory = sqlite3.Row
    print("Último estado de cada sitio:")
    for f in con.execute(ULTIMO):
        print(f"  {f['url']:<22} {'UP' if f['up'] else 'DOWN':<4} {f['status_code']:>3} {f['checked_at']}")
EOF
python ultimo.py
```

👀 **Qué deberías ver:** una línea por sitio, en orden alfabético: `https://caido.dev DOWN 503`, `https://example.com UP 200` y `https://github.com UP 200`, cada una con la fecha de su último chequeo (de hace unos dos días, porque los datos simulados empiezan hace tres).

✋ **Sin mirar:** ¿por qué el chequeo más reciente de cada URL es el de `id` más alto?

<details>
<summary>Comprueba</summary>

Porque `AUTOINCREMENT` da números crecientes en el orden de inserción, y los chequeos se guardan en el orden en que ocurren.
</details>

**En resumen:** `MAX(id)` por grupo en una subconsulta, y un `JOIN` para recuperar la fila completa.

### Pieza 5 — Mirar dentro desde la terminal

Si instalaste `sqlite3`, puedes abrir cualquier base de datos SQLite sin escribir un programa. Las órdenes que empiezan por punto son del cliente, no SQL.

**Pruébalo:**

```bash
sqlite3 historial.db '.tables'
sqlite3 historial.db '.schema checks'
sqlite3 -header -column historial.db 'SELECT url, COUNT(*) FROM checks WHERE up = 0 GROUP BY url;'
```

👀 **Qué deberías ver:** `checks`; el `CREATE TABLE` completo; y una tabla con las caídas de cada sitio: 98 de `https://caido.dev`, 4 de `https://github.com` y 1 de `https://example.com` (los restos del 6.7 %, 95.7 % y 99.0 %). Muy útil para comprobar que tu programa guardó lo que crees.

✋ **Sin mirar:** ¿con qué orden del cliente ves cómo se creó la tabla `checks`?

<details>
<summary>Comprueba</summary>

`.schema checks`.
</details>

**En resumen:** `sqlite3 archivo.db '.tables'`, `'.schema tabla'` y cualquier `SELECT`, directamente desde la terminal.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY AUTOINCREMENT, …)` | crear una tabla con clave primaria |
| `INSERT INTO t (a, b) VALUES (?, ?)` | añadir una fila |
| `SELECT … FROM t WHERE … ORDER BY id DESC LIMIT 5` | filtrar, ordenar, limitar |
| `SELECT url, COUNT(*), AVG(up) FROM t GROUP BY url` | resumir por grupos |
| `UPDATE t SET … WHERE …` · `DELETE FROM t WHERE …` | cambiar · borrar (¡con `WHERE`!) |
| `with closing(sqlite3.connect("x.db")) as con, con:` | conexión que se cierra y transacción |
| `con.execute(sql, (valor,))` · `.fetchone()` · `.fetchall()` | ejecutar con parámetros · leer |
| `con.row_factory = sqlite3.Row` | leer las columnas por nombre: `fila["url"]` |
| `sqlite3 x.db '.tables'` · `'.schema t'` | mirar dentro desde la terminal |

## Rómpelo

**1. Inyección SQL:**
```bash
cat > inyeccion.py <<'EOF'
import sqlite3

con = sqlite3.connect("historial.db")
url = "x' OR '1'='1"                       # lo que "escribe un usuario"
consulta = f"SELECT COUNT(*) FROM checks WHERE url = '{url}'"
print("Consulta montada con una f-string:", consulta)
print("filas devueltas:", con.execute(consulta).fetchone()[0])
print("con parámetro ?:", con.execute("SELECT COUNT(*) FROM checks WHERE url = ?", (url,)).fetchone()[0])
EOF
python inyeccion.py
```
Con la f-string, el texto del usuario cambia la consulta: `OR '1'='1'` es siempre verdadero y devuelve **todas** las filas (300). Con un `DELETE`, las borraría todas. Con el parámetro `?`, ese texto es solo un valor que no coincide con ninguna URL: 0 filas.

**2. El `commit` olvidado:**
```bash
python -c '
import sqlite3
con = sqlite3.connect("historial.db")
con.execute("INSERT INTO checks (url, status_code, seconds, up, checked_at) VALUES (?, ?, ?, ?, ?)",
            ("https://olvidado.dev", 200, 0.1, 1, "2026-10-20T00:00:00+00:00"))
con.close()
otra = sqlite3.connect("historial.db")
print(otra.execute("SELECT COUNT(*) FROM checks WHERE url = ?", ("https://olvidado.dev",)).fetchone()[0])
'
```
`0`: la fila nunca se guardó. Sin `commit` (o sin `with con:`), al cerrar la conexión los cambios se descartan.

**3. `UPDATE` sin `WHERE`:**
```bash
cp historial.db prueba.db
python -c '
import sqlite3
from contextlib import closing
with closing(sqlite3.connect("prueba.db")) as con, con:
    cambiadas = con.execute("UPDATE checks SET up = 0").rowcount
print("filas cambiadas:", cambiadas)
'
```
Querías marcar **una** fila y marcaste las 300. `UPDATE` y `DELETE` sin `WHERE` son el `rm -rf` de las bases de datos. Antes de ejecutarlos, prueba el mismo `WHERE` con un `SELECT COUNT(*)`.

**4. Una columna que no existe:**
```bash
python -c 'import sqlite3; sqlite3.connect("historial.db").execute("SELECT codigo FROM checks")'
```
`sqlite3.OperationalError: no such column: codigo`. Las columnas se llaman como en el `CREATE TABLE` (`status_code`).

## Reto

En `labs/clase-51/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade a `historial.py` una función `disponibilidad(url, horas)` que calcule el porcentaje de chequeos `up` de una URL en las últimas `horas` horas.

> 🧩 **Ejemplo resuelto:** la consulta de disponibilidad de la pieza 3 (`ROUND(AVG(up) * 100, 1)`) y la fecha de inicio de `simular`: `datetime.now(timezone.utc) - timedelta(days=3)`.

**Ahora tú, con huecos:**
```python
def disponibilidad(url: str, horas: int) -> float | None:
    desde = (datetime.now(timezone.utc) - timedelta(hours=____)).isoformat(timespec="seconds")
    with closing(conectar()) as con:
        pct = con.execute(
            "SELECT AVG(up) * 100 FROM checks WHERE url = ? AND checked_at >= ?", (____, ____)
        ).fetchone()[0]
    return None if pct is None else round(pct, 1)
```

<details>
<summary>Pista</summary>

Los datos simulados son de hace entre 3 y 2 días: prueba con `disponibilidad("https://github.com", 72)` y con `24`, que da `None` porque no hay chequeos en ese periodo (`AVG` de nada es `NULL`). Comparar fechas ISO como texto funciona porque todas tienen el mismo formato y la misma zona (UTC).
</details>

**2.** `caidas.py`: lista los momentos en los que `https://caido.dev` estuvo caído (fecha, código y error), los 10 más recientes.

> 🧩 **Ejemplo resuelto:** "Los 3 últimos" de la pieza 3: `SELECT id, url, status_code, up FROM checks ORDER BY id DESC LIMIT 3`.

**Ahora tú, con huecos** (dentro de un `with closing(…) as con:` con `row_factory`, como en `consultas.py`):
```python
for f in con.execute(
    "SELECT checked_at, status_code, error FROM checks"
    " WHERE url = ? AND up = ____ ORDER BY id ____ LIMIT ____",
    ("https://caido.dev",),
):
    print(f["checked_at"], f["status_code"], f["error"] or "")
```

<details>
<summary>Pista</summary>

DOWN se guarda como `up = 0`. Para los más recientes primero, orden descendente.
</details>

**3.** Convierte `historial.py` en una pequeña CLI con `argparse`: `historial.py agregar <url> <codigo> <segundos>`, `historial.py ultimos --limite 5` y `historial.py resumen`.

> 🧩 **Ejemplo resuelto:** `inventario.py` de la clase 48, pieza 4, con sus subcomandos `listar` y `buscar`.

**Ahora tú, con huecos** (sustituye el bloque `if __name__ == "__main__":` y añade `import argparse` arriba):
```python
if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="historial")
    sub = parser.add_subparsers(dest="comando", required=True)
    agregar = sub.add_parser("agregar")
    agregar.add_argument("url")
    agregar.add_argument("codigo", type=____)
    agregar.add_argument("segundos", type=____)
    ultimos = sub.add_parser("ultimos")
    ultimos.add_argument("--limite", type=int, default=____)
    sub.add_parser("resumen")
    args = parser.parse_args()

    crear_tabla()
    if args.comando == "agregar":
        ahora = datetime.now(timezone.utc).isoformat(timespec="seconds")
        guardar(args.url, args.codigo, args.segundos, None, ahora)
    elif args.comando == "____":
        with closing(conectar()) as con:
            for f in con.execute("SELECT id, url, status_code FROM checks ORDER BY id DESC LIMIT ?",
                                 (args.limite,)):
                print(f["id"], f["url"], f["status_code"])
    else:
        ...   # la consulta de disponibilidad de la pieza 3
```

<details>
<summary>Pista</summary>

Sin `RUTA.unlink(…)`: si no, cada `agregar` borraría la base de datos. `LIMIT ?` también admite un parámetro. `crear_tabla()` no hace nada si la tabla ya existe, gracias a `IF NOT EXISTS`.
</details>

## Cierre

En `notas/fase-4/clase-51.md`:

1. ¿Qué es la clave primaria de una tabla? ¿Cuál es en la tabla `checks`? *(1–2 líneas. Empieza así: «La columna que identifica cada fila sin repetirse. En `checks` es…»)*
2. ¿Por qué se pasan los valores con `?` y no dentro de la consulta con una f-string? *(2 líneas. Empieza así: «Porque con `?` la base de datos trata el valor siempre como… Con una f-string, un valor con comillas…»)*
3. Escribe la consulta que da la disponibilidad de cada URL y explica qué hace `GROUP BY`. *(La consulta y 1 línea. Empieza así: «`SELECT url, … FROM checks GROUP BY url;`. `GROUP BY` junta…»)*
4. **Repaso (clase 50, sin mirar):** ¿por qué no se usa `shell=True` con datos que vienen de fuera? *(1–2 líneas. Empieza así: «Porque el shell interpretaría…»)*

Después, escríbeme `examíname clase-51`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La columna (o columnas) que identifica cada fila sin repetirse. En `checks` es `id`, un entero que SQLite asigna solo (`AUTOINCREMENT`).

**2.** Porque con `?` la base de datos trata el valor siempre como dato, nunca como parte del SQL. Con una f-string, un valor con comillas puede cambiar la consulta (inyección SQL): devolver o borrar todas las filas, o algo peor.

**3.** `SELECT url, ROUND(AVG(up) * 100, 1) AS disponibilidad FROM checks GROUP BY url;` `GROUP BY url` junta las filas que tienen la misma URL y calcula el resumen (aquí, la media de `up`, que vale 1 o 0, multiplicada por 100) para cada grupo.

**4.** Porque el shell interpretaría los caracteres especiales del dato (`;`, `|`, `$()`) y un valor malicioso o raro podría ejecutar otros comandos. Es la misma idea que la inyección SQL: los datos nunca deben convertirse en código.

**Reto 1:** `hours=horas` y `(url, desde)`.

**Reto 2:** `up = 0`, `ORDER BY id DESC` y `LIMIT 10`.

**Reto 3:** `type=int`, `type=float`, `default=5` y `"ultimos"`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| table / row / column | tabla / fila / columna |
| primary key | clave primaria |
| query | consulta |
| SQL injection | inyección SQL |
| transaction / commit / rollback | transacción / confirmar / deshacer |

🎙️ *"I always use parameterized queries, so user input is treated as data and never as SQL."*

## Siguiente

[Clase 52 — Pruebas con pytest](clase-52-pytest.md)
