# Clase 51 — SQLite desde Python

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

## Objetivo

- Entender qué es una base de datos relacional: tablas, filas, columnas y clave primaria.
- Escribir el SQL básico: `CREATE TABLE`, `INSERT`, `SELECT` con `WHERE`, `ORDER BY`, `LIMIT` y `GROUP BY`.
- Usar `sqlite3` desde Python con **parámetros** (nunca f-strings) y transacciones.
- Crear la tabla de resultados de Vigía y responder con SQL las preguntas que hará su API: el último estado y la disponibilidad de cada sitio.

## Por qué importa

Un log de texto sirve para leerlo; una base de datos sirve para **preguntar**: ¿cuál fue el último estado de cada sitio?, ¿qué disponibilidad tuvo GitHub esta semana?, ¿cuántas caídas hubo ayer? Vigía v1 guardará cada chequeo en SQLite, una base de datos completa en un solo archivo, sin servidor, incluida en Python. En la fase 5 pasarás a PostgreSQL, y el SQL que aprendes hoy sirve casi igual. Y en la nube, RDS (fase 6) es esto mismo, gestionado por AWS.

## Teoría

### Tablas, filas y columnas

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
```

Es la tabla que usará Vigía v1. SQLite no tiene un tipo booleano (se usa `INTEGER` 0/1) ni un tipo fecha: una fecha ISO 8601 como texto se ordena bien porque el año va primero.

### El SQL que necesitas

```sql
INSERT INTO checks (url, status_code, seconds, up, error, checked_at)
VALUES ('https://example.com', 200, 0.26, 1, NULL, '2026-10-20T02:05:01+00:00');

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

`UPDATE` y `DELETE` cambian o borran filas; **sin `WHERE` afectan a todas** (Rómpelo 3).

### `sqlite3` en Python

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

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
mkdir -p ~/my-devops-journey/labs/clase-51 && cd ~/my-devops-journey/labs/clase-51
```

Opcional, pero útil para mirar dentro de cualquier base de datos SQLite: el cliente de la terminal.

```bash
sudo apt install -y sqlite3
```

### 1. Crear la tabla y guardar resultados

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

`random.seed(42)` hace que el azar sea siempre el mismo: tus números coincidirán con los de la autocorrección. `with closing(conectar()) as con, con:` son dos `with` en una línea: el primero cierra la conexión y el segundo hace la transacción.

### 2. Preguntar con SQL

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

    print("\nÚltimo estado de cada sitio:")
    ultimo = """
        SELECT c.url, c.status_code, c.up, c.checked_at FROM checks c
        JOIN (SELECT url, MAX(id) AS id FROM checks GROUP BY url) m ON c.id = m.id
        ORDER BY c.url
    """
    for f in con.execute(ultimo):
        print(f"  {f['url']:<22} {'UP' if f['up'] else 'DOWN':<4} {f['status_code']:>3} {f['checked_at']}")
EOF
python consultas.py
```

🔮 **Predice:** ¿qué sitio tendrá la disponibilidad más baja? La última consulta es la que usará la API de Vigía: para cada URL busca el `id` más alto (el chequeo más reciente) y se queda con esa fila. `CASE WHEN up = 1 THEN seconds END` calcula la media solo de los chequeos que respondieron.

### 3. Mirar dentro desde la terminal (si instalaste `sqlite3`)

```bash
sqlite3 historial.db '.tables'
sqlite3 historial.db '.schema checks'
sqlite3 -header -column historial.db 'SELECT url, COUNT(*) FROM checks WHERE up = 0 GROUP BY url;'
```

Muy útil para comprobar que tu programa guardó lo que crees.

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
Con la f-string, el texto del usuario cambia la consulta: `OR '1'='1'` es siempre verdadero y devuelve **todas** las filas. Con un `DELETE`, las borraría todas. Con el parámetro `?`, ese texto es solo un valor que no coincide con ninguna URL: 0 filas.

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

1. Añade a `historial.py` una función `disponibilidad(url, horas)` que calcule el porcentaje de chequeos `up` de una URL en las últimas `horas` horas (`WHERE url = ? AND checked_at >= ?`, con la fecha límite calculada en Python con `timedelta`).
2. `caidas.py`: lista los periodos en los que `https://caido.dev` estuvo caído (fecha y código), los 10 más recientes.
3. Convierte `historial.py` en una pequeña CLI con `argparse`: `historial.py agregar <url> <codigo> <segundos>`, `historial.py ultimos --limite 5` y `historial.py resumen`.

## Cierre

En `notas/fase-4/clase-51.md`:

1. ¿Qué es la clave primaria de una tabla? ¿Cuál es en la tabla `checks`?
2. ¿Por qué se pasan los valores con `?` y no dentro de la consulta con una f-string?
3. Escribe la consulta que da la disponibilidad de cada URL y explica qué hace `GROUP BY`.
4. **Repaso (clase 50, sin mirar):** ¿por qué no se usa `shell=True` con datos que vienen de fuera?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La columna (o columnas) que identifica cada fila sin repetirse. En `checks` es `id`, un entero que SQLite asigna solo (`AUTOINCREMENT`).

**2.** Porque con `?` la base de datos trata el valor siempre como dato, nunca como parte del SQL. Con una f-string, un valor con comillas puede cambiar la consulta (inyección SQL): devolver o borrar todas las filas, o algo peor.

**3.** `SELECT url, ROUND(AVG(up) * 100, 1) AS disponibilidad FROM checks GROUP BY url;` `GROUP BY url` junta las filas que tienen la misma URL y calcula el resumen (aquí, la media de `up`, que vale 1 o 0, multiplicada por 100) para cada grupo.

**4.** Porque el shell interpretaría los caracteres especiales del dato (`;`, `|`, `$()`) y un valor malicioso o raro podría ejecutar otros comandos. Es la misma idea que la inyección SQL: los datos nunca deben convertirse en código.

**Práctica 2:** con `random.seed(42)` deberías ver `https://example.com` con 102 chequeos y 99.0 %, `https://github.com` con 93 y 95.7 %, y `https://caido.dev` con 105 y 6.7 %.

**Reto 1 (una solución):**
```python
def disponibilidad(url: str, horas: int) -> float | None:
    desde = (datetime.now(timezone.utc) - timedelta(hours=horas)).isoformat(timespec="seconds")
    with closing(conectar()) as con:
        pct = con.execute(
            "SELECT AVG(up) * 100 FROM checks WHERE url = ? AND checked_at >= ?", (url, desde)
        ).fetchone()[0]
    return None if pct is None else round(pct, 1)
```
Comparar fechas ISO como texto funciona porque todas tienen el mismo formato y la misma zona (UTC). Si no hay chequeos en ese periodo, `AVG` devuelve `NULL` (`None`).
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
