# Clase 40 — Decisiones y bucles en Python

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

> 💡 **La idea de hoy:** decidir (`if`) y repetir (`for`, `while`) en Python es la misma lógica que en Bash (clases 17 y 18), con menos símbolos: no hay `[[ ]]`, ni `fi`, ni `done`. Lo que está **dentro** de un `if` o de un bucle lo marca la **sangría**: cuatro espacios. Y Python decide qué es "verdadero" con una regla sencilla: lo vacío y el cero son falsos; todo lo demás, verdadero.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `if`, `elif`, `else` y `case` en Bash (clase 17).
> - `for`, `while`, `break` y `continue` en Bash, y saltar líneas vacías y comentarios (clase 18).
> - Los tipos, `bool()` y las f-strings (clase 39).
> - La sangría es sintaxis en Python (clase 39, Rómpelo 3).

> 🔤 **Palabras nuevas de hoy:**
> - **bloque**: las líneas sangradas que van detrás de los dos puntos `:`.
> - **falso** (*falsy*): un valor que en un `if` cuenta como falso: `0`, `""`, `None`, `[]`…
> - **`in`**: «¿está dentro?», para listas y para texto.
> - **`range`**: una serie de números para recorrer con `for`.
> - **backoff**: esperar cada vez más entre reintentos (1, 2, 4, 8…).

## Objetivo

- Tomar decisiones con `if`, `elif` y `else`, y combinar condiciones con `and`, `or` y `not`.
- Repetir con `for` (sobre una lista o un `range`) y con `while`, y cortar con `break` y `continue`.
- Saber qué valores cuentan como "falsos" en Python.
- Traducir mentalmente un `if` y un bucle de Bash a Python.

## Por qué importa

Es la misma lógica de las clases 17 y 18 con una sintaxis más limpia: sin `[[ ]]`, sin `fi` ni `done` y sin comillas defensivas. Todo programa de operaciones decide (¿está caído?, ¿supera el umbral?) y repite (cada servidor, cada URL, cada reintento). En Python lo escribirás más rápido y con menos errores.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea (en la 2, dos que van juntas) y la pruebas enseguida con un script pequeño; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-40 && cd ~/my-devops-journey/labs/clase-40
```

## Las piezas

### Pieza 1 — `if`, `elif` y `else`

```python
codigo = 503
if 200 <= codigo < 400:
    estado = "UP"
elif codigo >= 500:
    estado = "DOWN (error del servidor)"
else:
    estado = "DOWN"
print(estado)
```

- Los dos puntos `:` abren el bloque, y la **sangría de 4 espacios** marca qué está dentro. No hay `fi`: el bloque termina cuando la sangría vuelve atrás.
- `200 <= codigo < 400` es una comparación encadenada, poco habitual en otros lenguajes y muy legible.
- Y un `if` cabe en una sola línea cuando solo eliges entre dos valores: `estado = "UP" if arriba else "DOWN"`.

| Bash | Python |
|------|--------|
| `if [[ $c -ge 500 ]]; then … fi` | `if c >= 500:` + bloque sangrado |
| `-eq -ne -lt -gt` | `== != < >` (y `<=`, `>=`) |
| `&& \|\| !` | `and or not` |
| `[[ $s == web-* ]]` | `s.startswith("web-")` |

**Pruébalo: clasifica códigos HTTP como lo hará Vigía.**

```bash
cat > clasificar.py <<'EOF'
#!/usr/bin/env python3
"""clasificar.py: clasifica códigos HTTP como lo hará Vigía."""
for codigo in [200, 301, 404, 500, 503, 0]:
    if codigo == 0:
        estado = "DOWN (sin respuesta)"
    elif 200 <= codigo < 400:
        estado = "UP"
    elif 400 <= codigo < 500:
        estado = "DOWN (error del cliente)"
    else:
        estado = "DOWN (error del servidor)"
    print(f"{codigo:>3} → {estado}")
EOF
python3 clasificar.py
```

🔮 **Predice** qué saldrá para el `0`.

👀 **Qué deberías ver:** `200 → UP`, `301 → UP`, `404 → DOWN (error del cliente)`, `500` y `503 → DOWN (error del servidor)` y `  0 → DOWN (sin respuesta)`. ¿Importa el orden de las ramas? Prueba a poner la rama `else` en otro sitio y verás que no se puede: `else` siempre va la última.

✋ **Sin mirar:** ¿cómo se escriben en Python el `-ge` y el `&&` de Bash?

<details>
<summary>Comprueba</summary>

`>=` y `and`.
</details>

**En resumen:** `if condición:` y un bloque sangrado; `elif` para más casos y `else` al final.

### Pieza 2 — Lo que es "falso", e `in`

`False`, `None`, `0`, `0.0`, `""` (texto vacío) y las colecciones vacías (`[]`, `{}`) son falsos. Todo lo demás es verdadero. Por eso es idiomático escribir `if nombre:` en lugar de `if nombre != "":`.

Y `in` pregunta si algo **está dentro**, de una lista o de un texto:

```python
if codigo in (500, 502, 503, 504):
    print("error del servidor o del proxy")
if "error" in mensaje:
    print("el mensaje habla de un error")
```

**Pruébalo.** 🔮 **Predice** antes de ejecutar:

```bash
cat > falsos.py <<'EOF'
for valor in [0, 1, "", "0", None, [], [0], 0.0]:
    if valor:
        print(f"{valor!r:>6} es verdadero")
    else:
        print(f"{valor!r:>6} es falso")
EOF
python3 falsos.py
python3 -c 'print(503 in (500, 502, 503, 504), "error" in "connection error", "ok" in "error")'
```

👀 **Qué deberías ver:** falsos: `0`, `''`, `None`, `[]` y `0.0`; verdaderos: `1`, `'0'` y `[0]` (una lista con algo dentro). Y en la última línea, `True True False`.

`!r` muestra el valor "tal cual", con comillas si es texto, para distinguir `""` de `"0"`.

✋ **Sin mirar:** ¿cómo compruebas, en una sola condición, si `codigo` es 500, 502, 503 o 504?

<details>
<summary>Comprueba</summary>

`if codigo in (500, 502, 503, 504):`.
</details>

**En resumen:** lo vacío, el cero y `None` son falsos; `in` pregunta si algo está dentro.

### Pieza 3 — `for`: recorrer

```python
for sitio in ["example.com", "wikipedia.org", "github.com"]:
    print(f"revisando {sitio}")

for i in range(1, 4):          # 1, 2, 3: el final no se incluye
    print(f"intento {i}")
```

`range(n)` va de 0 a n−1; `range(inicio, fin)` incluye el inicio y no el fin; `range(inicio, fin, paso)` salta de `paso` en `paso`.

**Pruébalo: cuenta los UP y los DOWN.**

```bash
cat > contar.py <<'EOF'
codigos = [200, 200, 503, 200, 0, 301, 404, 200]
arriba = 0
caidos = 0
for codigo in codigos:
    if 200 <= codigo < 400:
        arriba += 1
    else:
        caidos += 1
total = len(codigos)
print(f"UP: {arriba}  DOWN: {caidos}  disponibilidad: {arriba / total * 100:.1f} %")
EOF
python3 contar.py
```

👀 **Qué deberías ver:** `UP: 5  DOWN: 3  disponibilidad: 62.5 %`.

Compáralo con el bucle de Bash de la clase 18: no hacen falta `$(( ))`, la división da decimales y el formato del porcentaje es una sola expresión. (`arriba += 1` es lo mismo que `arriba = arriba + 1`.)

✋ **Sin mirar:** ¿qué números recorre `range(1, 4)`?

<details>
<summary>Comprueba</summary>

`1`, `2` y `3`: el final no se incluye.
</details>

**En resumen:** `for x in lista:` recorre una lista; `for i in range(a, b):` cuenta de `a` a `b − 1`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — `while`, y cortar con `break`

```python
intento = 1
while intento <= 3:
    print(f"intento {intento}")
    intento += 1
```

`while` repite mientras la condición sea verdadera. `break` sale del bucle, igual que en Bash. Y un `while` puede llevar un `else`, que se ejecuta solo si el bucle terminó **sin** `break`: "si agotaste los intentos".

**Pruébalo: reintentos.**

```bash
cat > reintentos.py <<'EOF'
import random
import time

intento = 1
maximo = 5
while intento <= maximo:
    responde = random.random() < 0.3      # 30 % de probabilidad de responder
    if responde:
        print(f"responde en el intento {intento}")
        break
    print(f"intento {intento}/{maximo}: no responde, espero 1 s")
    time.sleep(1)
    intento += 1
else:
    print("no respondió nunca")
EOF
python3 reintentos.py
python3 reintentos.py
```

`import` trae módulos de la biblioteca estándar (los verás en la clase 45): `random` para simular el azar y `time` para esperar.

🔮 **Predice:** ejecútalo varias veces. ¿Por qué no sale siempre lo mismo?

👀 **Qué deberías ver:** unas veces `responde en el intento N` tras algunos intentos fallidos, y otras, los 5 intentos seguidos de `no respondió nunca`: `random.random()` da un número distinto cada vez.

✋ **Sin mirar:** ¿cuándo se ejecuta el `else` de un `while`?

<details>
<summary>Comprueba</summary>

Cuando el bucle termina sin pasar por un `break`: aquí, cuando se agotan los intentos.
</details>

**En resumen:** `while condición:` repite; `break` sale, y el `else` del `while` solo corre si no hubo `break`.

### Pieza 5 — `continue`: saltar una vuelta

`continue` pasa a la siguiente vuelta sin ejecutar el resto del bloque, igual que en Bash. Es la forma de saltar lo que no interesa.

**Pruébalo: la regla de la clase 18, "salta vacías y comentarios", traducida.**

```bash
cat > saltar.py <<'EOF'
lineas = ["# sitios a vigilar", "https://example.com", "", "https://github.com"]
for linea in lineas:
    if not linea or linea.startswith("#"):
        continue
    print(f"vigilaré {linea}")
EOF
python3 saltar.py
```

👀 **Qué deberías ver:** solo `vigilaré https://example.com` y `vigilaré https://github.com`.

✋ **Sin mirar:** ¿qué diferencia hay entre `break` y `continue`?

<details>
<summary>Comprueba</summary>

`break` sale del bucle entero; `continue` solo salta el resto de esa vuelta y sigue con la siguiente.
</details>

**En resumen:** `continue` salta a la siguiente vuelta; `if not linea or linea.startswith("#")` es el filtro de vacías y comentarios.

## Tu chuleta de la clase

| Escribes | Qué es |
|----------|--------|
| `if c >= 500:` · `elif …:` · `else:` | decidir, con el bloque sangrado 4 espacios |
| `200 <= c < 400` | comparación encadenada |
| `and` · `or` · `not` | y · o · no |
| `x in (500, 502)` · `"err" in texto` | ¿está dentro? |
| `s.startswith("web-")` | ¿empieza por…? |
| `a if condición else b` | un `if` en una línea |
| `for x in lista:` · `for i in range(1, 4):` | recorrer · contar (sin incluir el final) |
| `while condición:` · `break` · `continue` | repetir · salir · saltar la vuelta |
| `x += 1` | `x = x + 1` |

Falsos: `False`, `None`, `0`, `0.0`, `""`, `[]`, `{}`. Todo lo demás es verdadero.

## Rómpelo

**1. `=` en lugar de `==`:**
```bash
printf 'x = 5\nif x = 5:\n    print("cinco")\n' > igual.py
python3 igual.py
```
`SyntaxError: invalid syntax. Maybe you meant '==' or ':=' instead of '='?`. `=` asigna y `==` compara. Python lo detecta antes de ejecutar nada y te sugiere el arreglo.

**2. Los dos puntos que faltan:**
```bash
printf 'x = 5\nif x == 5\n    print("cinco")\n' > puntos.py
python3 puntos.py
```
`SyntaxError: expected ':'`. La flecha `^` señala dónde esperaba los dos puntos.

**3. Un bucle infinito:**
```bash
python3 -c '
n = 0
while n < 10:
    print(n)
'
```
Se olvidó el `n += 1`: imprime `0` sin parar. Pulsa `Ctrl+C`: verás `KeyboardInterrupt`, la forma en que Python recibe la señal SIGINT (clase 11).

**4. Comparar texto con números:**
```bash
python3 -c 'print("10" > 9)'
```
`TypeError: '>' not supported between instances of 'str' and 'int'`. Recuerda la clase 17: Bash comparaba `10` y `9` como texto y daba un resultado equivocado sin avisar. Python se niega a comparar y te obliga a convertir: `int("10") > 9`.

## Reto

En `labs/clase-40/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** `semaforo.py`: recorre la lista de usos de disco `[45, 81, 92, 60, 99]` e imprime `OK` (menos de 80), `AVISO` (80 a 89) o `CRÍTICO` (90 o más) para cada uno, con el número alineado.

> 🧩 **Ejemplo resuelto:** dos niveles, con un umbral.
> ```python
> for uso in [45, 92]:
>     nivel = "CRÍTICO" if uso >= 90 else "OK"
>     print(f"{uso:>3} % {nivel}")
> ```

**Ahora tú, con huecos:**
```python
for uso in [45, 81, 92, 60, 99]:
    if uso >= ____:
        nivel = "CRÍTICO"
    elif uso >= ____:
        nivel = "AVISO"
    else:
        nivel = "OK"
    print(f"{uso:>3} % {nivel}")
```

<details>
<summary>Pista</summary>

El orden de las ramas importa: pregunta primero por el umbral **más alto**. Si preguntaras primero por 80, un 92 se quedaría en «AVISO».
</details>

**2.** Recorre `range(0, 101, 25)` e imprime cada valor. ¿Por qué aparece el 100 y no el 125?

> 🧩 **Ejemplo resuelto:** `for i in range(0, 10, 5): print(i)` → `0` y `5`; el 10 no sale porque `range` no incluye el final.

**Ahora tú, con huecos:** `for i in range(0, 101, ____): print(i)` → `____`

<details>
<summary>Pista</summary>

De 25 en 25 desde 0. El final es 101: ¿qué números son menores que 101?
</details>

**3.** `espera.py`: con un `while`, imprime las esperas de un *backoff* exponencial (1, 2, 4, 8, 16 segundos) sin esperar de verdad, y al final el total de segundos que se habría esperado.

> 🧩 **Ejemplo resuelto:** esperas que crecen de 1 en 1, hasta 3.
> ```python
> espera = 1
> while espera <= 3:
>     print(f"esperaría {espera} s")
>     espera += 1
> ```

**Ahora tú, con huecos:**
```python
espera = 1
total = 0
while espera <= ____:
    print(f"esperaría {espera} s")
    total += ____
    espera *= ____
print(f"total: {total} s")
```

<details>
<summary>Pista</summary>

En un *backoff* exponencial, cada espera es el **doble** de la anterior. `*=` multiplica, como `+=` suma.
</details>

**4.** Con los `codigos` de la pieza 3, imprime la posición del primer código caído y detén el bucle en ese momento.

> 🧩 **Ejemplo resuelto:** la posición del primer `200`.
> ```python
> posicion = 0
> for codigo in codigos:
>     if codigo == 200:
>         print(f"primer 200 en la posición {posicion}")
>         break
>     posicion += 1
> ```

**Ahora tú, con huecos:**
```python
posicion = 0
for codigo in codigos:
    if not 200 <= codigo < ____:
        print(f"primer caído en la posición {posicion}: {codigo}")
        ____
    posicion += 1
```

<details>
<summary>Pista</summary>

«Caído» es «no está entre 200 y 399». Y para detener el bucle, la palabra de la pieza 4.
</details>

## Cierre

En `notas/fase-4/clase-40.md`:

1. ¿Cómo sabe Python dónde termina un bloque `if` o un bucle, si no hay `fi` ni `done`? *(2 líneas. Empieza así: «Por la sangría: todo lo que va sangrado después de los dos puntos… y el bloque termina en…»)*
2. Nombra cuatro valores que Python considera falsos. ¿Por qué `bool("0")` es `True`? *(2 líneas. Empieza así: «`False`, `None`,… `"0"` es verdadero porque…»)*
3. Traduce a Python: `if [[ $uso -ge 80 && $uso -lt 90 ]]; then echo aviso; fi`. *(2 líneas de código. Empieza así: `if 80 <= uso …`)*
4. **Repaso (clase 39, sin mirar):** ¿qué imprime `f"{0.261431 * 1000:.0f} ms"`? *(1 línea. Empieza así: «Imprime…»)*

Después, escríbeme `examíname clase-40`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Por la sangría: todo lo que va sangrado después de los dos puntos está dentro del bloque, y el bloque termina en la primera línea que vuelve al nivel anterior. Por eso la sangría en Python no es estética: es sintaxis.

**2.** `False`, `None`, `0`, `0.0`, `""`, `[]` y `{}`. `"0"` es un texto con un carácter dentro: no está vacío, así que es verdadero, aunque ese carácter sea un cero.

**3.**
```python
if 80 <= uso < 90:
    print("aviso")
```
(o `if uso >= 80 and uso < 90:`)

**4.** `261 ms`.

**Reto (soluciones posibles):**
```python
# semaforo.py
for uso in [45, 81, 92, 60, 99]:
    if uso >= 90:
        nivel = "CRÍTICO"
    elif uso >= 80:
        nivel = "AVISO"
    else:
        nivel = "OK"
    print(f"{uso:>3} % {nivel}")

# espera.py
espera = 1
total = 0
while espera <= 16:
    print(f"esperaría {espera} s")
    total += espera
    espera *= 2
print(f"total: {total} s")        # 31 s
```
Reto 2: `25`; salen `0 25 50 75 100`. `range` no incluye el final (101), y saltando de 25 en 25 desde 0 el siguiente a 100 sería 125, que ya se pasa.

Reto 4: `400` y `break`.
```python
posicion = 0
for codigo in codigos:
    if not 200 <= codigo < 400:
        print(f"primer caído en la posición {posicion}: {codigo}")
        break
    posicion += 1
```
(Sale `primer caído en la posición 2: 503`. En la clase 41 verás `enumerate`, que da la posición sin contador manual.)
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| condition / branch | condición / rama |
| loop / iteration | bucle / vuelta |
| indentation | sangría |
| truthy / falsy | que cuenta como verdadero / falso |
| infinite loop | bucle infinito |

🎙️ *"Python's indentation-based blocks make the logic of a script easy to read, which matters when someone else has to fix it at 3 a.m."*

## Siguiente

[Clase 41 — Listas, diccionarios y compañía](clase-41-listas-y-diccionarios.md)
