# Clase 42 — Funciones

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

> 💡 **La idea de hoy:** una **función** es un trozo de código con nombre que recibe datos (sus **parámetros**), hace **una** cosa y **devuelve** un resultado con `return`. Un script bien hecho es un puñado de funciones pequeñas y un `main()` que las usa. Así se entiende, se reutiliza y, en la clase 52, se prueba automáticamente.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las funciones de Bash, `local` y `main "$@"` (clase 19).
> - `if`, `for` y las comprensiones (clases 40 y 41).
> - Las tuplas y el desempaquetado: `a, b = (1, 2)` (clase 41, pieza 2).
> - El docstring de un archivo (clase 39, pieza 4).

> 🔤 **Palabras nuevas de hoy:**
> - **`def`**: la palabra que define una función.
> - **parámetro / argumento**: el nombre en la definición / el valor que le pasas al llamarla.
> - **`return`**: devuelve un valor y termina la función.
> - **valor por defecto**: el que toma un parámetro si no le pasas nada: `unidad="ms"`.
> - **anotación de tipo** (*type hint*): `codigo: int` o `-> str`, que documenta qué tipo esperas.
> - **alcance**: dónde existe una variable; las de dentro de una función son **locales**.

## Objetivo

- Definir funciones con parámetros, valores por defecto y `return`.
- Llamarlas con argumentos por posición y por nombre.
- Documentarlas con un *docstring* y anotar los tipos (*type hints*).
- Entender el alcance de las variables y esquivar la trampa del valor por defecto mutable.
- Organizar un script con funciones pequeñas y un `main()`.

## Por qué importa

Una función bien hecha hace **una** cosa, tiene un nombre que lo dice y se puede probar sola. Es lo que separa un script que solo entiende su autor de una herramienta que otros pueden mantener. En la clase 52 escribirás pruebas automáticas, y solo se pueden probar con comodidad las funciones pequeñas que reciben datos y devuelven un resultado. En Vigía, `revisar(url)` será una de ellas.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea (en la 3, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 30 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-42 && cd ~/my-devops-journey/labs/clase-42
```

## Las piezas

### Pieza 1 — Definir y llamar una función

```python
def clasificar(codigo):
    """Devuelve "UP" si el código HTTP es 2xx o 3xx, y "DOWN" en otro caso."""
    if 200 <= codigo < 400:
        return "UP"
    return "DOWN"

print(clasificar(200))      # UP
estado = clasificar(503)    # el valor devuelto se puede guardar
```

- `def nombre(parámetros):` y un bloque sangrado.
- `return` devuelve un valor y **termina** la función. Sin `return`, la función devuelve `None`.
- El *docstring* (el texto entre `"""` justo debajo del `def`) explica qué hace. `help(clasificar)` lo muestra.

Compáralo con las funciones de Bash (clase 19): allí "devolvías" datos imprimiéndolos y un estado con `return N`. En Python, `return` devuelve cualquier valor: un número, un texto, una lista o un diccionario.

**Pruébalo:**

```bash
python3 -c '
def clasificar(codigo):
    """Devuelve UP si el código HTTP es 2xx o 3xx, y DOWN en otro caso."""
    if 200 <= codigo < 400:
        return "UP"
    return "DOWN"

print(clasificar(200), clasificar(503))
estado = clasificar(301)
print("guardado:", estado)
print(clasificar.__doc__)
'
```

👀 **Qué deberías ver:** `UP DOWN`, `guardado: UP` y el texto del docstring.

✋ **Sin mirar:** además de devolver un valor, ¿qué más hace `return`?

<details>
<summary>Comprueba</summary>

Termina la función en ese momento: lo que haya debajo ya no se ejecuta. Por eso `clasificar` no necesita `else`.
</details>

**En resumen:** `def nombre(params):` define, `return` devuelve y termina, y el docstring explica qué hace.

### Pieza 2 — Valores por defecto, y argumentos por nombre

```python
def formatear_tiempo(segundos, unidad="ms", decimales=0):
    if unidad == "ms":
        return f"{segundos * 1000:.{decimales}f} ms"
    return f"{segundos:.{decimales}f} s"

formatear_tiempo(0.2614)                          # '261 ms'
formatear_tiempo(0.2614, "s", 3)                  # '0.261 s'
formatear_tiempo(0.2614, decimales=1)             # '261.4 ms'  ← por nombre
```

Los argumentos por nombre hacen las llamadas legibles, sobre todo con valores `True`/`False`: compara `revisar(url, True)` con `revisar(url, seguir_redirecciones=True)`. Y por nombre, el orden da igual.

**Pruébalo:**

```bash
python3 -c '
def formatear_tiempo(segundos, unidad="ms", decimales=0):
    if unidad == "ms":
        return f"{segundos * 1000:.{decimales}f} ms"
    return f"{segundos:.{decimales}f} s"

print(formatear_tiempo(0.2614))
print(formatear_tiempo(0.2614, "s", 3))
print(formatear_tiempo(0.2614, decimales=1))
print(formatear_tiempo(unidad="s", segundos=1.5, decimales=2))
'
```

👀 **Qué deberías ver:** `261 ms`, `0.261 s`, `261.4 ms` y `1.50 s`.

✋ **Sin mirar:** ¿por qué es mejor escribir `revisar(url, seguir_redirecciones=True)` que `revisar(url, True)`?

<details>
<summary>Comprueba</summary>

Porque quien lo lee sabe qué significa ese `True` sin ir a mirar la definición de la función.
</details>

**En resumen:** un parámetro con `=valor` es opcional; por nombre (`decimales=1`) la llamada se lee sola y el orden da igual.

### Pieza 3 — Devolver varios valores, y las anotaciones de tipo

Una función puede devolver **varios** valores: en realidad devuelve una tupla, que se desempaqueta (clase 41):

```python
def resumen(codigos):
    arriba = sum(1 for c in codigos if 200 <= c < 400)
    return arriba, len(codigos) - arriba      # una tupla

ok, caidos = resumen([200, 503, 301])        # se desempaqueta
```

Y se pueden **anotar** los tipos de los parámetros y del resultado:

```python
def disponibilidad(arriba: int, total: int) -> float:
    """Porcentaje de chequeos correctos."""
    return arriba / total * 100
```

`arriba: int` y `-> float` **no cambian** cómo se ejecuta el código: documentan qué esperas, y los editores (VS Code) y herramientas como `mypy` las usan para avisarte de errores. Úsalas en las funciones que otros vayan a llamar.

**Pruébalo:**

```bash
python3 -c '
def resumen(codigos: list[int]) -> tuple[int, int]:
    arriba = sum(1 for c in codigos if 200 <= c < 400)
    return arriba, len(codigos) - arriba

ok, caidos = resumen([200, 503, 301])
print(f"UP: {ok}  DOWN: {caidos}")

def doble(n: int) -> int:
    return n * 2
print(doble("ab"))
'
```

👀 **Qué deberías ver:** `UP: 2  DOWN: 1` y `abab`: la anotación dice `int`, pero Python no la comprueba al ejecutar, y `"ab" * 2` es un texto repetido.

✋ **Sin mirar:** si anotas `codigo: int` y le pasas un texto, ¿Python se niega a ejecutar la función?

<details>
<summary>Comprueba</summary>

No: las anotaciones no cambian la ejecución. Lo avisan el editor o `mypy`, antes de ejecutar; Python fallará solo si el código hace algo imposible con ese texto.
</details>

**En resumen:** `return a, b` devuelve una tupla que se desempaqueta; las anotaciones (`x: int`, `-> float`) documentan los tipos, sin cambiar la ejecución.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — El alcance: dentro y fuera

Las variables que creas dentro de una función son **locales**: nacen y mueren con cada llamada. Una función puede **leer** una variable de fuera, pero si le **asigna** un valor, Python la trata como local (lo verás en el Rómpelo 2). La regla práctica: lo que la función necesite, que le llegue como parámetro; lo que produzca, que lo devuelva.

**Pruébalo.** 🔮 **Predice** qué imprime cada línea:

```bash
python3 -c '
limite = 400
def es_ok(codigo):
    calculado = codigo < limite      # LEE limite, de fuera: funciona
    return calculado
print(es_ok(200))
print(calculado)
'
```

👀 **Qué deberías ver:** `True` y después `NameError: name 'calculado' is not defined`: `calculado` era local de `es_ok` y desapareció al terminar la llamada.

✋ **Sin mirar:** una función crea `x = 5` dentro. Después de llamarla, ¿existe `x` fuera?

<details>
<summary>Comprueba</summary>

No: `x` es local de la función. Si quieres el valor fuera, la función tiene que devolverlo.
</details>

**En resumen:** lo de dentro de una función es local; lo que necesita entra por parámetros y lo que produce sale por `return`.

### Pieza 5 — El esqueleto de un script, con `main()`

```python
#!/usr/bin/env python3
"""informe.py: qué hace, en una línea."""


def funcion_pequena(dato):
    ...


def main():
    ...


if __name__ == "__main__":
    main()
```

`if __name__ == "__main__":` significa "solo si ejecutas este archivo directamente". Así, otro programa (o una prueba) puede importar tus funciones sin que se ejecute `main()`. Lo entenderás del todo en la clase 45; por ahora, úsalo siempre.

**Pruébalo: las funciones que usará Vigía.**

```bash
cat > vigia_mini.py <<'EOF'
#!/usr/bin/env python3
"""vigia_mini.py: funciones que usará Vigía, probadas con datos de ejemplo."""


def clasificar(codigo: int) -> str:
    """Devuelve "UP" si el código HTTP es 2xx o 3xx, y "DOWN" en otro caso."""
    if 200 <= codigo < 400:
        return "UP"
    return "DOWN"


def disponibilidad(codigos: list[int]) -> float:
    """Porcentaje de códigos que cuentan como UP. 0.0 si la lista está vacía."""
    if not codigos:
        return 0.0
    arriba = sum(1 for c in codigos if clasificar(c) == "UP")
    return arriba / len(codigos) * 100


def formatear_tiempo(segundos: float, unidad: str = "ms") -> str:
    """Devuelve el tiempo como texto en milisegundos o en segundos."""
    if unidad == "ms":
        return f"{segundos * 1000:.0f} ms"
    return f"{segundos:.3f} s"


def main():
    codigos = [200, 200, 503, 301, 0]
    for c in codigos:
        print(f"{c:>3} → {clasificar(c)}")
    print(f"Disponibilidad: {disponibilidad(codigos):.1f} %")
    print(formatear_tiempo(0.2614), "|", formatear_tiempo(0.2614, unidad="s"))


if __name__ == "__main__":
    main()
EOF
python3 vigia_mini.py
```

🔮 **Predice** la disponibilidad antes de ejecutar. `disponibilidad` llama a `clasificar`: las funciones se apoyan unas en otras.

👀 **Qué deberías ver:** cada código con su estado, `Disponibilidad: 60.0 %` (3 de 5) y `261 ms | 0.261 s`.

Ahora úsalo como **módulo**, desde otro programa:

```bash
python3 -c 'import vigia_mini; print(vigia_mini.clasificar(404))'
python3 -c 'import vigia_mini; help(vigia_mini.disponibilidad)'
```

👀 **Qué deberías ver:** `DOWN`, y la ayuda de `disponibilidad` con su docstring (pulsa `q` para salir). Fíjate en que `main()` **no** se ejecutó: es el efecto del `if __name__ == "__main__":`.

✋ **Sin mirar:** ¿qué muestra `help(funcion)`?

<details>
<summary>Comprueba</summary>

Su nombre, sus parámetros (con las anotaciones) y su docstring.
</details>

**En resumen:** funciones pequeñas, un `main()` que las usa y `if __name__ == "__main__": main()` al final, para poder importarlas sin ejecutar nada.

## Tu chuleta de la clase

| Escribes | Qué es |
|----------|--------|
| `def f(a, b=1):` | definir, con un parámetro opcional |
| `return x` · `return a, b` | devolver un valor · devolver una tupla |
| `f(1)` · `f(1, b=2)` · `f(b=2, a=1)` | llamar: por posición · mezclado · por nombre |
| `"""docstring"""` · `help(f)` | documentar · leer la documentación |
| `def f(x: int) -> str:` | anotar los tipos |
| `def f(lista=None): if lista is None: lista = []` | el valor por defecto mutable, bien hecho |
| `if __name__ == "__main__": main()` | ejecutar `main()` solo si lanzas el archivo |
| `import modulo` · `from modulo import f` | usar las funciones de otro archivo |

## Rómpelo

**1. El `return` olvidado:**
```bash
python3 -c '
def doble(n):
    resultado = n * 2
print(doble(4))
'
```
`None`. La función calculó `8`, pero no lo devolvió. Si una función "no da nada", busca primero el `return`.

**2. Asignar a una variable de fuera:**
```bash
python3 -c '
contador = 0
def sumar():
    contador = contador + 1
sumar()
'
```
`UnboundLocalError: cannot access local variable 'contador' where it is not associated with a value`. Al asignar `contador` dentro, Python la trata como local, y la estás leyendo antes de darle valor. El arreglo correcto no es `global`: es pasar el valor y devolver el resultado (`contador = sumar(contador)`).

**3. El valor por defecto mutable:**
```bash
python3 -c '
def agregar(sitio, lista=[]):
    lista.append(sitio)
    return lista
print(agregar("a.com"))
print(agregar("b.com"))
'
```
🔮 **Predice** antes de ejecutar. Sale `['a.com']` y luego `['a.com', 'b.com']`: la lista por defecto se crea **una sola vez**, al definir la función, y se comparte entre llamadas. El patrón correcto:
```python
def agregar(sitio, lista=None):
    if lista is None:
        lista = []
    lista.append(sitio)
    return lista
```

**4. Argumentos de más o de menos:**
```bash
python3 -c 'from vigia_mini import clasificar; clasificar()'
python3 -c 'from vigia_mini import clasificar; clasificar(200, 301)'
```
`TypeError: clasificar() missing 1 required positional argument: 'codigo'` y `takes 1 positional argument but 2 were given`. Python comprueba que cada llamada encaja con la definición.

## Reto

En `labs/clase-42/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Convierte el reto de la clase 41 en funciones con docstring y anotaciones, más un `main()` que las use.

> 🧩 **Ejemplo resuelto:** una de las tres, `nunca_arriba`.
> ```python
> def nunca_arriba(resultados: list[dict]) -> set:
>     """URLs que no estuvieron arriba en ningún chequeo."""
>     todas = {r["url"] for r in resultados}
>     return todas - {r["url"] for r in resultados if r["up"]}
> ```

**Ahora tú, con huecos:**
```python
def mas_lento(resultados: list[dict]) -> dict:
    """El chequeo que más tardó."""
    return max(resultados, key=lambda r: ____)


def disponibilidad_por_url(resultados: list[dict]) -> ____:
    """Porcentaje de chequeos arriba, por URL."""
    totales, arriba = {}, {}
    for r in resultados:
        totales[r["url"]] = totales.get(r["url"], 0) + 1
        arriba[r["url"]] = arriba.get(r["url"], 0) + (1 if r["up"] else 0)
    return {url: arriba[url] / totales[url] * 100 for url in ____}


def main():
    resultados = [...]          # la lista de la clase 41
    print(disponibilidad_por_url(resultados))
    print(nunca_arriba(resultados))
    print(____(resultados))


if __name__ == "__main__":
    main()
```

<details>
<summary>Pista</summary>

El cuerpo de cada función es el código que ya escribiste en la clase 41: aquí solo lo metes dentro de un `def` y cambias el `print` por un `return`.
</details>

**2.** Escribe `es_ip_privada(ip: str) -> bool`, que devuelva `True` para las direcciones que empiecen por `10.` o `192.168.`, o estén entre `172.16.` y `172.31.` (clase 27). Pruébala con 5 direcciones.

> 🧩 **Ejemplo resuelto:** solo el primer rango.
> ```python
> def es_de_la_diez(ip: str) -> bool:
>     """True si la IPv4 está en 10.0.0.0/8."""
>     return ip.split(".")[0] == "10"
> ```
> `ip.split(".")` parte `"10.1.2.3"` en `["10", "1", "2", "3"]`.

**Ahora tú, con huecos:**
```python
def es_ip_privada(ip: str) -> bool:
    """True si la IPv4 está en 10.0.0.0/8, 172.16.0.0/12 o 192.168.0.0/16."""
    a, b = (int(x) for x in ip.split(".")[:2])
    return a == 10 or (a == 172 and ____ <= b <= ____) or (a == ____ and b == ____)
```

<details>
<summary>Pista</summary>

`[:2]` se queda con los dos primeros números, y `int()` los convierte para poder compararlos. Los límites del rango `172.16/12` los calculaste en la clase 27.
</details>

**3.** Escribe `barra(porcentaje: float, ancho: int = 20) -> str`, que devuelva una barra de texto: `barra(55)` → `[###########---------]  55 %`.

> 🧩 **Ejemplo resuelto:** repetir un texto con `*`: `"#" * 5 + "-" * 15` → `#####---------------`.

**Ahora tú, con huecos:**
```python
def barra(porcentaje: float, ancho: int = 20) -> str:
    llenos = round(porcentaje / 100 * ____)
    return f"[{'#' * llenos}{'-' * (____ - llenos)}] {porcentaje:3.0f} %"
```

<details>
<summary>Pista</summary>

Si la barra mide `ancho` caracteres, la parte llena es ese porcentaje del ancho, y la vacía, lo que falta hasta el ancho.
</details>

## Cierre

En `notas/fase-4/clase-42.md`:

1. ¿Qué devuelve una función sin `return`? ¿Qué síntoma ves cuando lo olvidas? *(2 líneas. Empieza así: «Devuelve `None`. El síntoma es que donde esperaba un valor sale…»)*
2. ¿Para qué sirve `if __name__ == "__main__":`? *(2 líneas. Empieza así: «Para que `main()` se ejecute solo cuando lanzo el archivo, y no cuando…»)*
3. Explica la trampa del valor por defecto mutable y cómo se evita. *(2–3 líneas. Empieza así: «El valor por defecto se crea una sola vez, al definir la función, así que una lista…: Se evita con `None`…»)*
4. **Repaso (clase 41, sin mirar):** ¿por qué `b = a` no copia una lista? *(1–2 líneas. Empieza así: «Porque los dos nombres apuntan a… Se copia con…»)*

Después, escríbeme `examíname clase-42`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `None`. El síntoma típico: al usar el resultado sale `None` donde esperabas un valor, o un error como `TypeError: unsupported operand type(s) for +: 'NoneType' and 'int'` más adelante, lejos de la función culpable.

**2.** Para que el código de debajo (normalmente `main()`) se ejecute solo cuando lanzas ese archivo directamente, y no cuando otro archivo lo importa. Así puedes reutilizar sus funciones o probarlas sin efectos secundarios.

**3.** El valor por defecto se evalúa una vez, al definir la función. Si es mutable (una lista o un diccionario), todas las llamadas comparten el mismo objeto y los cambios se acumulan de una llamada a otra. Se evita usando `None` como valor por defecto y creando la lista dentro: `if lista is None: lista = []`.

**4.** Porque `b = a` hace que los dos nombres apunten a la misma lista. Se copia con `a.copy()` o `list(a)`.

**Reto 1:** `r["segundos"]`, `dict`, `totales` y `mas_lento`.

**Reto 2 (una solución):**
```python
def es_ip_privada(ip: str) -> bool:
    """True si la IPv4 está en 10.0.0.0/8, 172.16.0.0/12 o 192.168.0.0/16."""
    a, b = (int(x) for x in ip.split(".")[:2])
    return a == 10 or (a == 172 and 16 <= b <= 31) or (a == 192 and b == 168)
```
(En la clase 45 verás que el módulo `ipaddress` ya lo hace: `ipaddress.ip_address(ip).is_private`.)

**Reto 3 (una solución):**
```python
def barra(porcentaje: float, ancho: int = 20) -> str:
    llenos = round(porcentaje / 100 * ancho)
    return f"[{'#' * llenos}{'-' * (ancho - llenos)}] {porcentaje:3.0f} %"
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| function / to call | función / llamar |
| parameter / argument | parámetro / argumento |
| return value | valor devuelto |
| default value | valor por defecto |
| type hint | anotación de tipo |

🎙️ *"I keep functions small and pure: they take inputs and return a value, so I can test them without touching the network or the disk."*

## Siguiente

[Clase 43 — Texto, archivos y rutas](clase-43-texto-y-archivos.md)
