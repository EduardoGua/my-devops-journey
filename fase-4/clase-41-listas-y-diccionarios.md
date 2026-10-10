# Clase 41 — Listas, diccionarios y compañía

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Python desde cero

## Objetivo

- Guardar colecciones de datos: **listas** (en orden), **tuplas** (fijas), **diccionarios** (clave → valor) y **conjuntos** (sin repetidos).
- Recorrerlas, filtrarlas, ordenarlas y contar con ellas.
- Representar datos como los de una API: una lista de diccionarios.
- Evitar dos trampas clásicas: el alias de una lista y modificarla mientras la recorres.

## Por qué importa

Aquí está la gran ventaja de Python sobre Bash. Un inventario de servidores, la respuesta de una API, los resultados de Vigía o la salida de `aws ec2 describe-instances` son colecciones: listas de diccionarios. En Bash los manejarías con `awk` y `cut`, rezando para que nadie meta un espacio. En Python son estructuras de verdad: las recorres, filtras y cuentas sin partir texto.

## Teoría

### Listas: en orden, cambian

```python
sitios = ["example.com", "github.com", "wikipedia.org"]
sitios[0]            # "example.com": se cuenta desde 0
sitios[-1]           # "wikipedia.org": el último
sitios[0:2]          # ["example.com", "github.com"]: del 0 al 2, sin incluir el 2
len(sitios)          # 3
sitios.append("aws.amazon.com")
"github.com" in sitios         # True
sorted(sitios)       # una lista NUEVA ordenada; sitios.sort() ordena la misma lista
```

### Tuplas: en orden, fijas

```python
punto = ("10.0.1.0/24", "us-east-1a")
cidr, zona = punto              # desempaquetar: cada valor a su variable
```

Se usan para datos que van juntos y no cambian, y para que una función devuelva varios valores (clase 42).

### Diccionarios: clave → valor

```python
servidor = {"nombre": "web-01", "ip": "10.0.1.15", "rol": "web", "activo": True}
servidor["ip"]                  # "10.0.1.15"
servidor.get("zona", "?")       # "?": get no falla si la clave no existe
servidor["zona"] = "us-east-1a" # añade o cambia
"rol" in servidor               # True: in mira las claves
for clave, valor in servidor.items():
    print(clave, valor)
```

Las claves suelen ser textos y no se repiten. Desde Python 3.7, un diccionario recuerda el orden en que añadiste las claves.

### Conjuntos: sin repetidos

```python
zonas = {"us-east-1a", "us-east-1b", "us-east-1a"}   # se queda con 2
inventario = {"web-01", "web-02", "db-01"}
responden = {"web-01", "db-01"}
inventario - responden          # {"web-02"}: los que no responden
```

### Listas por comprensión

Una forma compacta de crear una lista a partir de otra:

```python
codigos = [200, 503, 200, 404]
caidos = [c for c in codigos if not 200 <= c < 400]     # [503, 404]
en_ms = [t * 1000 for t in [0.12, 0.26]]                # [120.0, 260.0]
```

Se lee: "`c` para cada `c` en `codigos` si cumple la condición". Úsala cuando quepa en una línea legible; si no, un `for` normal.

### `enumerate` y `zip`

```python
for posicion, sitio in enumerate(sitios):      # 0 example.com, 1 github.com…
    print(posicion, sitio)
for sitio, codigo in zip(sitios, [200, 503, 200]):   # recorre dos listas a la vez
    print(sitio, codigo)
```

### ¿Cuál elijo?

| Necesitas… | Usa |
|------------|-----|
| una secuencia ordenada que crece | lista |
| un registro con campos con nombre | diccionario |
| datos fijos que van juntos | tupla |
| quitar repetidos o comparar grupos | conjunto |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-41 && cd ~/my-devops-journey/labs/clase-41
```

### 1. Un inventario como lista de diccionarios

```bash
cat > inventario.py <<'EOF'
#!/usr/bin/env python3
"""inventario.py: un inventario de servidores como lo devolvería una API."""
servidores = [
    {"nombre": "web-01", "rol": "web", "zona": "us-east-1a", "activo": True,  "cpu": 35},
    {"nombre": "web-02", "rol": "web", "zona": "us-east-1b", "activo": False, "cpu": 0},
    {"nombre": "db-01",  "rol": "db",  "zona": "us-east-1a", "activo": True,  "cpu": 82},
    {"nombre": "web-03", "rol": "web", "zona": "us-east-1b", "activo": True,  "cpu": 91},
]

print(f"Hay {len(servidores)} servidores")
print("Primero:", servidores[0]["nombre"])

# filtrar
activos = [s for s in servidores if s["activo"]]
print("Activos:", [s["nombre"] for s in activos])

# buscar los que pasan del 80 % de CPU
for s in servidores:
    if s["cpu"] > 80:
        print(f"⚠️  {s['nombre']} al {s['cpu']} % de CPU")

# contar por rol con un diccionario
por_rol = {}
for s in servidores:
    por_rol[s["rol"]] = por_rol.get(s["rol"], 0) + 1
print("Por rol:", por_rol)

# zonas sin repetir
print("Zonas:", sorted({s["zona"] for s in servidores}))

# ordenar por CPU, de mayor a menor
for s in sorted(servidores, key=lambda s: s["cpu"], reverse=True):
    print(f"{s['nombre']:<8} {s['cpu']:>3} %")
EOF
python3 inventario.py
```

🔮 **Predice** antes de ejecutar: ¿qué quedará en `por_rol`?

Dos detalles nuevos:
- Dentro de una f-string con comillas dobles, las claves van con comillas simples: `f"{s['nombre']}"`.
- `key=lambda s: s["cpu"]` le dice a `sorted` **por qué** ordenar. Una `lambda` es una función de una línea: "dado `s`, devuelve `s['cpu']`". Las funciones de verdad llegan en la clase 42.

### 2. El patrón "contar con `get`"

`por_rol.get(rol, 0) + 1` significa "lo que hubiera (o 0 si no había nada) más uno". Es la forma de contar más usada en Python, y la usarás en Vigía para calcular la disponibilidad por sitio.

### 3. Conjuntos para comparar grupos

```bash
cat > comparar.py <<'EOF'
inventario = {"web-01", "web-02", "web-03", "db-01"}
monitorizados = {"web-01", "web-03", "db-01", "cache-01"}
print("Sin monitorizar:", inventario - monitorizados)
print("Monitorizados que no están en el inventario:", monitorizados - inventario)
print("En los dos:", inventario & monitorizados)
EOF
python3 comparar.py
```

Es una auditoría real: "¿qué servidores no tienen monitoreo?". Con conjuntos son tres líneas.

### 4. Desempaquetar y `enumerate`

```bash
python3 -c '
sitios = ["example.com", "github.com", "wikipedia.org"]
for i, sitio in enumerate(sitios, start=1):
    print(f"{i}. {sitio}")
primero, *resto = sitios
print(primero, resto)
'
```

## Rómpelo

**1. Una posición que no existe:**
```bash
python3 -c 'sitios = ["a", "b"]; print(sitios[2])'
```
`IndexError: list index out of range`. Con 2 elementos, las posiciones válidas son 0 y 1.

**2. Una clave que no existe:**
```bash
python3 -c 'd = {"nombre": "web-01"}; print(d.get("zona", "sin zona")); print(d["zona"])'
```
`get` devuelve el valor por defecto; `d["zona"]` lanza `KeyError: 'zona'`. Usa `[]` cuando la clave **debe** existir (y quieres un error si falta) y `get` cuando es opcional.

**3. El alias que cambia "las dos" listas:**
```bash
python3 -c '
a = [1, 2]
b = a
b.append(3)
print("a =", a)
c = a.copy()
c.append(4)
print("a =", a, " c =", c)
'
```
🔮 **Predice** antes de ejecutar. `b = a` **no copia** la lista: crea otro nombre para la misma lista. Por eso `a` también cambia. Para una copia de verdad: `a.copy()` o `list(a)`.

**4. Borrar mientras recorres:**
```bash
python3 -c '
codigos = [200, 503, 500, 200]
for c in codigos:
    if c >= 500:
        codigos.remove(c)
print(codigos)
'
```
Esperabas `[200, 200]` y sale `[200, 500, 200]`: al borrar un elemento, la lista se desplaza y el bucle se salta el siguiente. No modifiques una lista mientras la recorres: crea una nueva con una comprensión (`[c for c in codigos if c < 500]`).

## Reto

Usa esta lista de resultados de chequeos:

```python
resultados = [
    {"url": "https://example.com", "up": True,  "segundos": 0.21},
    {"url": "https://github.com",  "up": True,  "segundos": 0.95},
    {"url": "https://example.com", "up": False, "segundos": 10.0},
    {"url": "https://caido.dev",   "up": False, "segundos": 0.01},
    {"url": "https://github.com",  "up": True,  "segundos": 0.88},
    {"url": "https://example.com", "up": True,  "segundos": 0.25},
]
```

1. Calcula la **disponibilidad** de cada URL (porcentaje de chequeos `up`) con un diccionario de contadores, e imprímela ordenada de menor a mayor.
2. ¿Qué URLs no estuvieron arriba **nunca**? Usa conjuntos.
3. Con una comprensión, la lista de tiempos de los chequeos `up`, y su media (`sum(...) / len(...)`).
4. Imprime el chequeo más lento con `max(resultados, key=…)`.

## Cierre

En `notas/fase-4/clase-41.md`:

1. ¿Cuándo usarías una lista, un diccionario, una tupla y un conjunto? Un ejemplo de operaciones para cada uno.
2. ¿Qué diferencia hay entre `d["clave"]` y `d.get("clave")`? ¿Cuándo prefieres cada uno?
3. ¿Por qué `b = a` no copia una lista? ¿Cómo la copias?
4. **Repaso (clase 40, sin mirar):** ¿qué valores son "falsos" en Python?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Lista: una secuencia ordenada que crece, como las URLs a vigilar o los resultados de una revisión. Diccionario: un registro con campos con nombre, como un servidor (`nombre`, `ip`, `rol`) o la configuración. Tupla: datos fijos que van juntos, como `(cidr, zona)` o los valores que devuelve una función. Conjunto: quitar repetidos o comparar grupos, como inventario frente a monitorizados.

**2.** `d["clave"]` lanza `KeyError` si no existe; `d.get("clave")` devuelve `None` (o el valor por defecto que le pases). `[]` cuando la clave es obligatoria y su ausencia es un error que quieres ver; `get` cuando es opcional y tienes un valor razonable por defecto.

**3.** Porque en Python las variables son nombres que apuntan a un objeto: `b = a` hace que `b` apunte a la **misma** lista. Se copia con `a.copy()`, `list(a)` o `a[:]`. (Para listas que contienen otras listas o diccionarios, `copy.deepcopy`.)

**4.** `False`, `None`, `0`, `0.0`, `""` y las colecciones vacías: `[]`, `{}`, `()`, `set()`.

**Reto (una solución):**
```python
totales, arriba = {}, {}
for r in resultados:
    totales[r["url"]] = totales.get(r["url"], 0) + 1
    arriba[r["url"]] = arriba.get(r["url"], 0) + (1 if r["up"] else 0)
disponibilidad = {url: arriba[url] / totales[url] * 100 for url in totales}
for url, pct in sorted(disponibilidad.items(), key=lambda par: par[1]):
    print(f"{url:<22} {pct:5.1f} %")
# https://caido.dev    0.0 % · https://example.com 66.7 % · https://github.com 100.0 %

todas = {r["url"] for r in resultados}
alguna_vez_arriba = {r["url"] for r in resultados if r["up"]}
print("Nunca arriba:", todas - alguna_vez_arriba)          # {'https://caido.dev'}

tiempos = [r["segundos"] for r in resultados if r["up"]]
print(f"Media: {sum(tiempos) / len(tiempos):.3f} s")      # 0.573 s

lento = max(resultados, key=lambda r: r["segundos"])
print("Más lento:", lento["url"], lento["segundos"])      # https://example.com 10.0
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| list / tuple | lista / tupla |
| dictionary (dict) / key / value | diccionario / clave / valor |
| set | conjunto |
| list comprehension | lista por comprensión |
| to iterate over | recorrer |

🎙️ *"When an API returns JSON, I treat it as a list of dictionaries in Python: filter it with a comprehension and count with a dictionary, instead of parsing text with awk."*

## Siguiente

[Clase 42 — Funciones](clase-42-funciones.md)
