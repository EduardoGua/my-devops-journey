# Clase 41 — Listas, diccionarios y compañía

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Python desde cero

> 💡 **La idea de hoy:** casi todos los datos de operaciones son **colecciones**: una lista de URLs, un servidor con sus campos, la respuesta de una API. Python tiene cuatro: la **lista** (en orden), el **diccionario** (clave → valor), la **tupla** (fija) y el **conjunto** (sin repetidos). Con ellas recorres, filtras y cuentas sin partir texto con `awk` y `cut`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `for`, `if`, `in` y lo que es "falso" (clase 40).
> - Contar UP y DOWN con un bucle (clase 40, pieza 3).
> - Contar con `sort | uniq -c` en Bash (clase 05): hoy, lo mismo con un diccionario.
> - Las f-strings con alineación (clase 39).

> 🔤 **Palabras nuevas de hoy:**
> - **lista**: una secuencia ordenada que puede cambiar: `["a", "b"]`.
> - **diccionario**: pares clave → valor: `{"nombre": "web-01"}`.
> - **tupla**: una secuencia fija, que no cambia: `("10.0.1.0/24", "us-east-1a")`.
> - **conjunto** (*set*): una colección sin repetidos: `{"a", "b"}`.
> - **comprensión**: una forma corta de crear una lista a partir de otra: `[c for c in codigos if c >= 500]`.
> - **`lambda`**: una función de una sola línea, para decir por qué ordenar.

## Objetivo

- Guardar colecciones de datos: **listas** (en orden), **tuplas** (fijas), **diccionarios** (clave → valor) y **conjuntos** (sin repetidos).
- Recorrerlas, filtrarlas, ordenarlas y contar con ellas.
- Representar datos como los de una API: una lista de diccionarios.
- Evitar dos trampas clásicas: el alias de una lista y modificarla mientras la recorres.

## Por qué importa

Aquí está la gran ventaja de Python sobre Bash. Un inventario de servidores, la respuesta de una API, los resultados de Vigía o la salida de `aws ec2 describe-instances` son colecciones: listas de diccionarios. En Bash los manejarías con `awk` y `cut`, y un espacio de más lo rompería todo. En Python son estructuras de verdad: las recorres, filtras y cuentas sin partir texto.

## Cómo va esta clase

Cinco piezas: una por colección y una última que las junta en un inventario. En cada una lees **una** idea (en la 2 y la 4, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-41 && cd ~/my-devops-journey/labs/clase-41
```

## Las piezas

### Pieza 1 — Listas: en orden, y cambian

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

**Pruébalo:**

```bash
python3 -c '
sitios = ["example.com", "github.com", "wikipedia.org"]
print(sitios[0], sitios[-1], sitios[0:2], len(sitios))
sitios.append("aws.amazon.com")
print("github.com" in sitios, sorted(sitios))
'
```

👀 **Qué deberías ver:** `example.com wikipedia.org ['example.com', 'github.com'] 3`, y después `True` con las cuatro en orden alfabético (`aws.amazon.com` la primera).

✋ **Sin mirar:** en una lista de 3 elementos, ¿qué posiciones son válidas? ¿Y qué devuelve `[-1]`?

<details>
<summary>Comprueba</summary>

`0`, `1` y `2` (se cuenta desde 0); `[-1]` devuelve el último.
</details>

**En resumen:** una lista va en orden y se cuenta desde 0; `append` añade, `in` busca y `sorted` ordena.

### Pieza 2 — Diccionarios (clave → valor), y tuplas

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

Una **tupla** es como una lista que no cambia. Se usa para datos que van juntos, y para que una función devuelva varios valores (clase 42):

```python
punto = ("10.0.1.0/24", "us-east-1a")
cidr, zona = punto              # desempaquetar: cada valor a su variable
```

**Pruébalo:**

```bash
python3 -c '
servidor = {"nombre": "web-01", "ip": "10.0.1.15", "rol": "web", "activo": True}
print(servidor["ip"], servidor.get("zona", "?"))
servidor["zona"] = "us-east-1a"
for clave, valor in servidor.items():
    print(f"  {clave:<7} {valor}")
cidr, zona = ("10.0.1.0/24", "us-east-1a")
print(cidr, "en", zona)
'
```

👀 **Qué deberías ver:** `10.0.1.15 ?`; las cinco claves con su valor, `zona` la última; y `10.0.1.0/24 en us-east-1a`.

✋ **Sin mirar:** ¿qué hace `cidr, zona = punto`?

<details>
<summary>Comprueba</summary>

Desempaqueta la tupla: el primer valor va a `cidr` y el segundo a `zona`.
</details>

**En resumen:** un diccionario guarda campos con nombre (`d["clave"]`, o `d.get("clave", defecto)` si es opcional); una tupla, valores fijos que van juntos.

### Pieza 3 — Conjuntos: sin repetidos, y para comparar grupos

```python
zonas = {"us-east-1a", "us-east-1b", "us-east-1a"}   # se queda con 2
inventario = {"web-01", "web-02", "db-01"}
responden = {"web-01", "db-01"}
inventario - responden          # {"web-02"}: los que no responden
```

`-` da lo que está en el primero y no en el segundo, y `&`, lo que está en los dos.

**Pruébalo: una auditoría real**, "¿qué servidores no tienen monitoreo?".

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

👀 **Qué deberías ver:** `Sin monitorizar: {'web-02'}`; `…que no están en el inventario: {'cache-01'}`; y los tres de los dos (`web-01`, `web-03`, `db-01`), en un orden cualquiera: un conjunto no guarda el orden.

✋ **Sin mirar:** tienes `inventario` y `monitorizados`. ¿Qué operación da los servidores del inventario que **no** están monitorizados?

<details>
<summary>Comprueba</summary>

`inventario - monitorizados`.
</details>

**En resumen:** un conjunto no tiene repetidos ni orden; `-` y `&` comparan grupos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Comprensiones, `enumerate` y `zip`

Una **comprensión** crea una lista a partir de otra, en una línea:

```python
codigos = [200, 503, 200, 404]
caidos = [c for c in codigos if not 200 <= c < 400]     # [503, 404]
en_ms = [t * 1000 for t in [0.12, 0.26]]                # [120.0, 260.0]
```

Se lee: "`c` para cada `c` en `codigos` si cumple la condición". Úsala cuando quepa en una línea legible; si no, un `for` normal.

Y dos ayudas para recorrer: `enumerate` da la posición junto a cada elemento, y `zip` recorre dos listas a la vez:

```python
for posicion, sitio in enumerate(sitios):      # 0 example.com, 1 github.com…
    print(posicion, sitio)
for sitio, codigo in zip(sitios, [200, 503, 200]):   # recorre dos listas a la vez
    print(sitio, codigo)
```

**Pruébalo:**

```bash
python3 -c '
codigos = [200, 503, 200, 404]
print([c for c in codigos if not 200 <= c < 400])
sitios = ["example.com", "github.com", "wikipedia.org"]
for i, sitio in enumerate(sitios, start=1):
    print(f"{i}. {sitio}")
for sitio, codigo in zip(sitios, [200, 503, 200]):
    print(sitio, codigo)
primero, *resto = sitios
print(primero, resto)
'
```

👀 **Qué deberías ver:** `[503, 404]`; la lista numerada desde 1; cada sitio con su código; y `example.com ['github.com', 'wikipedia.org']`: con `*resto`, lo que sobra va a una lista.

✋ **Sin mirar:** lee en voz alta `[t for t in tiempos if t > 1]`. ¿Qué lista crea?

<details>
<summary>Comprueba</summary>

«`t` para cada `t` en `tiempos` si `t` es mayor que 1»: la lista de los tiempos de más de un segundo.
</details>

**En resumen:** `[x for x in lista if …]` filtra o transforma en una línea; `enumerate` da la posición y `zip` empareja dos listas.

### Pieza 5 — Todo junto: un inventario como lista de diccionarios

Así devuelven los datos las APIs: una **lista de diccionarios**. Hoy la recorres, filtras, cuentas y ordenas con lo de las piezas 1 a 4. Dos detalles nuevos:
- Para **contar**, el patrón `d[clave] = d.get(clave, 0) + 1`: "lo que hubiera (o 0 si no había nada) más uno". Es la forma de contar más usada en Python, y la usarás en Vigía para la disponibilidad por sitio.
- `sorted(lista, key=lambda s: s["cpu"])` le dice a `sorted` **por qué** ordenar. Una `lambda` es una función de una línea: "dado `s`, devuelve `s['cpu']`". Las funciones de verdad llegan en la clase 42.

**Pruébalo:**

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

👀 **Qué deberías ver:** `Hay 4 servidores`; `Primero: web-01`; los tres activos; avisos para `db-01` (82 %) y `web-03` (91 %); `Por rol: {'web': 3, 'db': 1}`; las dos zonas; y la tabla de CPU de `web-03` a `web-02`.

Dentro de una f-string con comillas dobles, las claves van con comillas simples: `f"{s['nombre']}"`.

✋ **Sin mirar:** ¿para qué sirve `key=lambda s: s["cpu"]` en `sorted`?

<details>
<summary>Comprueba</summary>

Para decirle a `sorted` por qué campo ordenar: por la CPU de cada servidor, y no por el diccionario entero.
</details>

**En resumen:** una lista de diccionarios se recorre con `for`, se filtra con una comprensión, se cuenta con `get(…, 0) + 1` y se ordena con `key=`.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `l[0]` · `l[-1]` · `l[0:2]` · `len(l)` | el primero · el último · un trozo · cuántos |
| `l.append(x)` · `x in l` · `sorted(l)` · `l.sort()` | añadir · ¿está? · lista nueva ordenada · ordenar la misma |
| `d["k"]` · `d.get("k", defecto)` · `d["k"] = v` | leer (falla si no está) · leer sin fallar · añadir o cambiar |
| `for k, v in d.items():` | recorrer un diccionario |
| `a, b = tupla` · `primero, *resto = lista` | desempaquetar |
| `a - b` · `a & b` · `set(lista)` | conjuntos: diferencia · comunes · quitar repetidos |
| `[x for x in l if cond]` | comprensión: filtrar o transformar |
| `enumerate(l, start=1)` · `zip(a, b)` | con la posición · dos listas a la vez |
| `d[k] = d.get(k, 0) + 1` | contar |
| `sorted(l, key=lambda x: x["campo"], reverse=True)` · `max(l, key=…)` | ordenar por un campo · el mayor |
| `l.copy()` | una copia de verdad |

| Necesitas… | Usa |
|------------|-----|
| una secuencia ordenada que crece | lista |
| un registro con campos con nombre | diccionario |
| datos fijos que van juntos | tupla |
| quitar repetidos o comparar grupos | conjunto |

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

En `labs/clase-41/reto.py`, con esta lista de resultados de chequeos:

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Calcula la **disponibilidad** de cada URL (porcentaje de chequeos `up`) con un diccionario de contadores, e imprímela ordenada de menor a mayor.

> 🧩 **Ejemplo resuelto:** cuántos chequeos tiene cada URL.
> ```python
> totales = {}
> for r in resultados:
>     totales[r["url"]] = totales.get(r["url"], 0) + 1
> print(totales)      # {'https://example.com': 3, 'https://github.com': 2, 'https://caido.dev': 1}
> ```

**Ahora tú, con huecos:**
```python
totales, arriba = {}, {}
for r in resultados:
    totales[r["url"]] = totales.get(r["url"], 0) + 1
    arriba[r["url"]] = arriba.get(r["url"], 0) + (1 if ____ else 0)
for url in sorted(totales, key=lambda u: arriba[u] / totales[u]):
    print(f"{url:<22} {arriba[url] / totales[url] * 100:5.1f} %")
```

<details>
<summary>Pista</summary>

Suma 1 a `arriba` solo cuando el chequeo estuvo arriba: el campo que lo dice es `r["up"]`.
</details>

**2.** ¿Qué URLs no estuvieron arriba **nunca**? Usa conjuntos.

> 🧩 **Ejemplo resuelto:** todas las URLs, sin repetir: `{r["url"] for r in resultados}`.

**Ahora tú, con huecos:**
```python
todas = {r["url"] for r in resultados}
alguna_vez_arriba = {r["url"] for r in resultados if ____}
print("Nunca arriba:", todas ____ alguna_vez_arriba)
```

<details>
<summary>Pista</summary>

«Nunca arriba» son las que están en `todas` y no en `alguna_vez_arriba`: la operación de la pieza 3.
</details>

**3.** Con una comprensión, la lista de tiempos de los chequeos `up`, y su media.

> 🧩 **Ejemplo resuelto:** la lista de **todos** los tiempos: `[r["segundos"] for r in resultados]`.

**Ahora tú, con huecos:**
```python
tiempos = [r["segundos"] for r in resultados if ____]
print(f"Media: {sum(tiempos) / len(____):.3f} s")
```

<details>
<summary>Pista</summary>

La media es la suma entre cuántos hay. La condición es la misma del punto 2.
</details>

**4.** Imprime el chequeo más lento con `max`.

> 🧩 **Ejemplo resuelto:** el servidor con más CPU de la pieza 5: `max(servidores, key=lambda s: s["cpu"])`.

**Ahora tú, con huecos:**
```python
lento = max(resultados, key=lambda r: ____)
print("Más lento:", lento["url"], lento["segundos"])
```

<details>
<summary>Pista</summary>

`max` con `key=` funciona como `sorted` con `key=`: le dices qué campo comparar.
</details>

## Cierre

En `notas/fase-4/clase-41.md`:

1. ¿Cuándo usarías una lista, un diccionario, una tupla y un conjunto? Un ejemplo de cada uno. *(4 líneas, una por colección. Empieza así: «Lista: una secuencia ordenada que crece, como… Diccionario:… Tupla:… Conjunto:…»)*
2. ¿Qué diferencia hay entre `d["clave"]` y `d.get("clave")`? ¿Cuándo prefieres cada uno? *(2 líneas. Empieza así: «`d["clave"]` lanza `KeyError` si…; `d.get` devuelve… Uso `[]` cuando la clave…»)*
3. ¿Por qué `b = a` no copia una lista? ¿Cómo la copias? *(2 líneas. Empieza así: «Porque en Python una variable es un nombre que apunta a…, y `b = a` hace que… Se copia con…»)*
4. **Repaso (clase 40, sin mirar):** ¿qué valores son "falsos" en Python? *(1 línea. Empieza así: «`False`, `None`,…»)*

Después, escríbeme `examíname clase-41`.

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
for url in sorted(totales, key=lambda u: arriba[u] / totales[u]):
    print(f"{url:<22} {arriba[url] / totales[url] * 100:5.1f} %")
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
