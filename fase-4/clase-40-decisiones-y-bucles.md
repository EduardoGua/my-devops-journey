# Clase 40 — Decisiones y bucles en Python

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

## Objetivo

- Tomar decisiones con `if`, `elif` y `else`, y combinar condiciones con `and`, `or` y `not`.
- Repetir con `for` (sobre una lista o un `range`) y con `while`, y cortar con `break` y `continue`.
- Saber qué valores cuentan como "falsos" en Python.
- Traducir mentalmente un `if` y un bucle de Bash a Python.

## Por qué importa

Es la misma lógica de las clases 17 y 18 con una sintaxis más limpia: sin `[[ ]]`, sin `fi` ni `done` y sin comillas defensivas. Todo programa de operaciones decide (¿está caído?, ¿supera el umbral?) y repite (cada servidor, cada URL, cada reintento). En Python lo escribirás más rápido y con menos errores.

## Teoría

### `if`, `elif`, `else`

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

| Bash | Python |
|------|--------|
| `if [[ $c -ge 500 ]]; then … fi` | `if c >= 500:` + bloque sangrado |
| `-eq -ne -lt -gt` | `== != < >` (y `<=`, `>=`) |
| `&& \|\| !` | `and or not` |
| `[[ $s == web-* ]]` | `s.startswith("web-")` |

### Lo que es "falso"

`False`, `None`, `0`, `0.0`, `""` (texto vacío) y las colecciones vacías (`[]`, `{}`) son falsos. Todo lo demás es verdadero. Por eso es idiomático escribir `if nombre:` en lugar de `if nombre != "":`.

### `in`: ¿está dentro?

```python
if codigo in (500, 502, 503, 504):
    print("error del servidor o del proxy")
if "error" in mensaje:
    print("el mensaje habla de un error")
```

### Un `if` en una línea

```python
estado = "UP" if arriba else "DOWN"
```

### `for`: recorrer

```python
for sitio in ["example.com", "wikipedia.org", "github.com"]:
    print(f"revisando {sitio}")

for i in range(1, 4):          # 1, 2, 3: el final no se incluye
    print(f"intento {i}")
```

`range(n)` va de 0 a n−1; `range(inicio, fin)` incluye el inicio y no el fin; `range(inicio, fin, paso)` salta de `paso` en `paso`.

### `while`: mientras se cumpla

```python
intento = 1
while intento <= 3:
    print(f"intento {intento}")
    intento += 1               # lo mismo que intento = intento + 1
```

`break` sale del bucle y `continue` pasa a la siguiente vuelta, igual que en Bash.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-40 && cd ~/my-devops-journey/labs/clase-40
```

### 1. Clasificar códigos HTTP

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

🔮 **Predice** qué saldrá para el `0`. ¿Importa el orden de las ramas? Prueba a poner la rama `else` en otro sitio y verás que no se puede: `else` siempre va la última.

### 2. Lo que es falso

🔮 **Predice** antes de ejecutar:

```bash
cat > falsos.py <<'EOF'
for valor in [0, 1, "", "0", None, [], [0], 0.0]:
    if valor:
        print(f"{valor!r:>6} es verdadero")
    else:
        print(f"{valor!r:>6} es falso")
EOF
python3 falsos.py
```

`!r` muestra el valor "tal cual", con comillas si es texto, para distinguir `""` de `"0"`.

### 3. Contar con un bucle

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

Compáralo con el bucle de Bash de la clase 18: no hacen falta `$(( ))`, la división da decimales y el formato del porcentaje es una sola expresión.

### 4. Reintentos con `while` y `break`

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

`import` trae módulos de la biblioteca estándar (los verás en la clase 45): `random` para simular el azar y `time` para esperar. El `else` de un `while` se ejecuta solo si el bucle terminó **sin** `break`. Es poco común, pero aquí encaja: "si agotaste los intentos".

🔮 **Predice:** ejecútalo varias veces. ¿Por qué no sale siempre lo mismo?

### 5. `continue` para saltar

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

Es la regla de la clase 18 ("salta vacías y comentarios"), traducida.

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

1. `semaforo.py`: recorre la lista de usos de disco `[45, 81, 92, 60, 99]` e imprime `OK` (menos de 80), `AVISO` (80 a 89) o `CRÍTICO` (90 o más) para cada uno, con el número alineado.
2. Recorre `range(0, 101, 25)` e imprime cada valor. ¿Por qué aparece el 100 y no el 125?
3. `espera.py`: con un `while`, imprime las esperas de un *backoff* exponencial (1, 2, 4, 8, 16 segundos) sin esperar de verdad, y al final el total de segundos que se habría esperado.
4. Con los `codigos` de la práctica 3, imprime la posición del primer código caído y detén el bucle en ese momento. Pista: un contador y `break`.

## Cierre

En `notas/fase-4/clase-40.md`:

1. ¿Cómo sabe Python dónde termina un bloque `if` o un bucle, si no hay `fi` ni `done`?
2. Nombra cuatro valores que Python considera falsos. ¿Por qué `bool("0")` es `True`?
3. Traduce a Python: `if [[ $uso -ge 80 && $uso -lt 90 ]]; then echo aviso; fi`.
4. **Repaso (clase 39, sin mirar):** ¿qué imprime `f"{0.261431 * 1000:.0f} ms"`?

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
Reto 2: `range` no incluye el final (101), y saltando de 25 en 25 desde 0 el siguiente a 100 sería 125, que ya se pasa.

Reto 4:
```python
posicion = 0
for codigo in codigos:
    if not 200 <= codigo < 400:
        print(f"primer caído en la posición {posicion}: {codigo}")
        break
    posicion += 1
```
(En la clase 41 verás `enumerate`, que da la posición sin contador manual.)
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
