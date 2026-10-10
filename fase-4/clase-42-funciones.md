# Clase 42 — Funciones

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

## Objetivo

- Definir funciones con parámetros, valores por defecto y `return`.
- Llamarlas con argumentos por posición y por nombre.
- Documentarlas con un *docstring* y anotar los tipos (*type hints*).
- Entender el alcance de las variables y esquivar la trampa del valor por defecto mutable.
- Organizar un script con funciones pequeñas y un `main()`.

## Por qué importa

Una función bien hecha hace **una** cosa, tiene un nombre que lo dice y se puede probar sola. Es lo que separa un script que solo entiende su autor de una herramienta que otros pueden mantener. En la clase 52 escribirás pruebas automáticas, y solo se pueden probar con comodidad las funciones pequeñas que reciben datos y devuelven un resultado. En Vigía, `revisar(url)` será una de ellas.

## Teoría

### Definir y llamar

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

### Parámetros con valor por defecto y por nombre

```python
def formatear_tiempo(segundos, unidad="ms", decimales=0):
    if unidad == "ms":
        return f"{segundos * 1000:.{decimales}f} ms"
    return f"{segundos:.{decimales}f} s"

formatear_tiempo(0.2614)                          # '261 ms'
formatear_tiempo(0.2614, "s", 3)                  # '0.261 s'
formatear_tiempo(0.2614, decimales=1)             # '261.4 ms'  ← por nombre
```

Los argumentos por nombre hacen las llamadas legibles, sobre todo con valores `True`/`False`: compara `revisar(url, True)` con `revisar(url, seguir_redirecciones=True)`.

### Devolver varios valores

```python
def resumen(codigos):
    arriba = sum(1 for c in codigos if 200 <= c < 400)
    return arriba, len(codigos) - arriba      # una tupla

ok, caidos = resumen([200, 503, 301])        # se desempaqueta
```

### Anotaciones de tipo

```python
def disponibilidad(arriba: int, total: int) -> float:
    """Porcentaje de chequeos correctos."""
    return arriba / total * 100
```

`arriba: int` y `-> float` **no cambian** cómo se ejecuta el código: documentan qué esperas, y los editores (VS Code) y herramientas como `mypy` las usan para avisarte de errores. Úsalas en las funciones que otros vayan a llamar.

### Alcance: dentro y fuera

Las variables que creas dentro de una función son **locales**: nacen y mueren con cada llamada. Una función puede **leer** una variable de fuera, pero si le **asigna** un valor, Python la trata como local (lo verás en Rómpelo). La regla práctica: lo que la función necesite, que le llegue como parámetro; lo que produzca, que lo devuelva.

### El esqueleto de un script

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

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-42 && cd ~/my-devops-journey/labs/clase-42
```

### 1. Funciones pequeñas

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

### 2. Leer la ayuda de tus funciones

```bash
python3 -c 'import vigia_mini; help(vigia_mini.disponibilidad)'
python3 -c 'import vigia_mini; print(vigia_mini.clasificar(404))'
```

`import vigia_mini` carga el archivo como un módulo. Fíjate en que `main()` **no** se ejecutó: es el efecto del `if __name__ == "__main__":`. Pulsa `q` para salir de la ayuda.

### 3. Por posición y por nombre

```bash
python3 -c '
from vigia_mini import formatear_tiempo
print(formatear_tiempo(1.5))
print(formatear_tiempo(1.5, "s"))
print(formatear_tiempo(unidad="s", segundos=1.5))
'
```

Por nombre, el orden da igual.

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

1. Convierte el Reto de la clase 41 en funciones con docstring y anotaciones: `disponibilidad_por_url(resultados) -> dict`, `nunca_arriba(resultados) -> set` y `mas_lento(resultados) -> dict`, más un `main()` que las use.
2. Escribe `es_ip_privada(ip: str) -> bool`, que devuelva `True` para direcciones que empiecen por `10.`, `192.168.` o estén entre `172.16.` y `172.31.` (clase 27). Pista: `ip.split(".")` y convertir los dos primeros números con `int()`. Pruébala con 5 direcciones.
3. Escribe `barra(porcentaje: float, ancho: int = 20) -> str`, que devuelva una barra de texto: `barra(55)` → `[###########---------]  55 %`.

## Cierre

En `notas/fase-4/clase-42.md`:

1. ¿Qué devuelve una función sin `return`? ¿Qué síntoma ves cuando lo olvidas?
2. ¿Para qué sirve `if __name__ == "__main__":`?
3. Explica la trampa del valor por defecto mutable y cómo se evita.
4. **Repaso (clase 41, sin mirar):** ¿por qué `b = a` no copia una lista?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `None`. El síntoma típico: al usar el resultado sale `None` donde esperabas un valor, o un error como `TypeError: unsupported operand type(s) for +: 'NoneType' and 'int'` más adelante, lejos de la función culpable.

**2.** Para que el código de debajo (normalmente `main()`) se ejecute solo cuando lanzas ese archivo directamente, y no cuando otro archivo lo importa. Así puedes reutilizar sus funciones o probarlas sin efectos secundarios.

**3.** El valor por defecto se evalúa una vez, al definir la función. Si es mutable (una lista o un diccionario), todas las llamadas comparten el mismo objeto y los cambios se acumulan de una llamada a otra. Se evita usando `None` como valor por defecto y creando la lista dentro: `if lista is None: lista = []`.

**4.** Porque `b = a` hace que los dos nombres apunten a la misma lista. Se copia con `a.copy()` o `list(a)`.

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
