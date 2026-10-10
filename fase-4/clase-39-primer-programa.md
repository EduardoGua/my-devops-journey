# Clase 39 — Tu primer programa: el intérprete, tipos y f-strings

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Python desde cero

## Objetivo

- Usar Python de dos formas: el intérprete interactivo y un script ejecutable.
- Conocer los tipos básicos: `int`, `float`, `str`, `bool` y `None`, y convertir entre ellos.
- Escribir texto con valores dentro usando **f-strings**, con decimales y alineación.
- Leer un mensaje de error de Python y saber qué línea lo provocó.

## Por qué importa

Bash es perfecto para encadenar comandos, pero se vuelve frágil en cuanto el script crece, maneja datos o habla con una API. Ahí entra Python: es el segundo idioma del trabajo DevOps. Con Python se escriben las automatizaciones que crecen, se consume la API de AWS (`boto3`), se programan las pruebas y se construyen herramientas internas. En esta fase reescribes Vigía en Python (clases 54 y 55).

La buena noticia: ya sabes programar. Variables, condiciones, bucles y funciones los viste en Bash (clases 16 a 19). Ahora aprendes la misma lógica con un lenguaje más claro y más estricto.

## Teoría

### El intérprete

Python es un **intérprete**: un programa que lee tu código y lo ejecuta línea a línea, igual que bash. En Ubuntu se llama `python3`. El comando `python`, a secas, **no existe** salvo que lo instales aparte: escribe siempre `python3`.

Se usa de dos formas:

| Forma | Cómo | Para qué |
|-------|------|----------|
| Interactiva (REPL) | `python3` y escribes después del `>>>` | probar una idea en segundos |
| Script | un archivo `.py` que ejecutas | todo lo que quieras repetir o guardar |

Para salir del modo interactivo: `exit()` o `Ctrl+D`.

### Tipos básicos

| Tipo | Ejemplos | Qué es |
|------|----------|--------|
| `int` | `42`, `-3`, `200` | entero |
| `float` | `0.261`, `3.5` | número con decimales |
| `str` | `"web-01"`, `'hola'` | texto (comillas simples o dobles: dan igual) |
| `bool` | `True`, `False` | verdadero o falso (con mayúscula) |
| `None` | `None` | "no hay valor" |

Diferencia clave con Bash: en Bash **todo es texto**. En Python cada valor tiene un tipo, y Python no mezcla tipos por su cuenta: `"5" + 3` es un error, no `"53"` ni `8`.

```python
codigo = 200                 # sin $ al usarla, sin problema con espacios alrededor del =
tiempo = 0.261
sitio = "example.com"
arriba = True
print(type(codigo))          # <class 'int'>
```

### Operaciones

| Operador | Ejemplo | Resultado |
|----------|---------|-----------|
| `+ - *` | `2 * 10` | `20` |
| `/` | `7 / 2` | `3.5`, siempre `float` |
| `//` | `7 // 2` | `3`, división entera |
| `%` | `7 % 2` | `1`, el resto |
| `**` | `2 ** 10` | `1024`, potencia |

Recuerda que Bash solo hacía aritmética entera y que `awk`, en tu Ubuntu en español, leía `0.261` como `0`. En Python los decimales funcionan, y siempre con punto.

### Convertir

`int("42")` → `42` · `float("0.26")` → `0.26` · `str(200)` → `"200"` · `bool("")` → `False`.

### f-strings: texto con valores dentro

```python
sitio = "example.com"
tiempo = 0.261431
print(f"{sitio} respondió en {tiempo:.3f} s")       # example.com respondió en 0.261 s
print(f"{tiempo * 1000:.0f} ms")                     # 261 ms
print(f"{sitio:<15}|{tiempo:>8.3f}")                 # alineado a la izquierda y a la derecha
```

Una f-string empieza por `f` antes de las comillas. Dentro de `{}` va cualquier expresión, y tras `:` el formato: `.3f` (3 decimales), `<15` (ocupar 15 caracteres, alineado a la izquierda), `>8` (8 caracteres, a la derecha).

### Un script ejecutable

```python
#!/usr/bin/env python3
"""hola.py: mi primer script de Python."""
print("Hola desde Python")
```

El shebang `#!/usr/bin/env python3` busca `python3` en el PATH (clase 07). Más adelante, dentro de un entorno virtual (clase 46), así encontrará el Python de ese entorno. El texto entre triples comillas al principio es un *docstring*: la descripción del archivo.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-39 && cd ~/my-devops-journey/labs/clase-39
python3 --version
python
```

El primer comando muestra la versión (3.14 en tu Ubuntu 26.04). El segundo falla con `orden no encontrada`: en Ubuntu, Python 3 se llama `python3`.

### 1. El intérprete interactivo

```bash
python3
```

🔮 **Predice** cada resultado antes de pulsar Enter. No escribas el `>>>`: es el *prompt* de Python, como el `$` de tu terminal.

```python
>>> 7 / 2
>>> 7 // 2
>>> 2 ** 10
>>> 0.1 + 0.2
>>> "ab" * 3
>>> len("web-01")
>>> "web-01".upper()
>>> exit()
```

`0.1 + 0.2` da `0.30000000000000004`. No es un fallo de Python: los `float` se guardan en binario y algunos decimales no tienen representación exacta, como 1/3 en decimal. Para mostrarlos, redondea: `round(0.1 + 0.2, 2)` o `f"{x:.2f}"`.

### 2. Variables y tipos

```bash
python3
```

```python
>>> codigo = 200
>>> tiempo = 0.261431
>>> sitio = "example.com"
>>> arriba = True
>>> type(codigo), type(tiempo), type(sitio), type(arriba), type(None)
>>> int("42") + 1
>>> float("0.26") * 1000
>>> str(5) + "5"
>>> bool(""), bool("0"), bool(0)
>>> exit()
```

`bool("0")` es `True`: un texto con algo dentro es verdadero, aunque ese algo sea un cero. Solo el texto vacío, el número 0 y `None` (y, como verás, las listas vacías) son "falsos".

### 3. Tu primer script

```bash
cat > hola.py <<'EOF'
#!/usr/bin/env python3
"""hola.py: mi primer script de Python."""
nombre = "Eduardo"
fase = 4
print(f"Hola, {nombre}. Empiezas la fase {fase}: Python.")
EOF
python3 hola.py
chmod +x hola.py
./hola.py
```

Igual que en Bash: `python3 hola.py` no necesita el permiso `x`; `./hola.py` sí, y usa el shebang.

### 4. f-strings para informes

```bash
cat > informe.py <<'EOF'
#!/usr/bin/env python3
"""informe.py: una línea de informe con formato."""
sitio = "example.com"
codigo = 200
tiempo = 0.261431
arriba = True

estado = "UP" if arriba else "DOWN"
print(f"{sitio:<20} {codigo:>3} {tiempo:>7.3f} s  {estado}")
print(f"{sitio:<20} {codigo:>3} {tiempo * 1000:>7.0f} ms {estado}")
EOF
python3 informe.py
```

🔮 **Predice** cómo quedarán alineadas las columnas. `estado = "UP" if arriba else "DOWN"` es un `if` en una sola línea: lo ves a fondo en la clase 40.

## Rómpelo

**1. Mezclar tipos:**
```bash
python3 -c 'print("5" + 3)'
```
`TypeError: can only concatenate str (not "int") to str`. Python no adivina si querías `"53"` o `8`: tienes que decirlo, con `int("5") + 3` o con `"5" + str(3)`. Es una ventaja: en Bash, ese tipo de confusión pasa en silencio.

**2. Una variable mal escrita:**
```bash
python3 -c 'nombre = "Eduardo"; print(nmbre)'
```
`NameError: name 'nmbre' is not defined. Did you mean: 'nombre'?`. Recuerda el `$DIRETORIO` vacío de la clase 16: Bash seguía sin avisar. Python se comporta **siempre** como si tuviera `set -u`, y además te sugiere el nombre correcto.

**3. La sangría importa:**
```bash
printf 'x = 1\n  y = 2\n' > sangria.py
python3 sangria.py
```
`IndentationError: unexpected indent`. En Python, los espacios al principio de la línea forman parte de la sintaxis: marcan qué está dentro de un `if`, de un bucle o de una función. Una línea suelta no puede ir sangrada. Usa **4 espacios** por nivel, nunca tabuladores.

**4. Un tutorial viejo:**
```bash
python3 -c 'print "hola"'
```
`SyntaxError: Missing parentheses in call to 'print'. Did you mean print(...)?`. Es sintaxis de Python 2, retirado en 2020. Si un tutorial escribe `print` sin paréntesis, busca otro.

**5. Leer una traza:**
```bash
cat > traza.py <<'EOF'
codigo = "200"
limite = 400
print(codigo < limite)
EOF
python3 traza.py
```
Lee la traza **de abajo arriba**: la última línea dice qué pasó (`TypeError: '<' not supported between instances of 'str' and 'int'`) y la de encima, en qué archivo y línea (`line 3`). `codigo` es texto porque lleva comillas.

## Reto

1. `unidades.py`: guarda en una variable un tamaño en bytes (por ejemplo `3_450_000_000`; los `_` solo facilitan la lectura) e imprime ese tamaño en KB, MB y GB con 2 decimales, usando potencias de 1024.
2. `disco.py`: con las variables `total = 233` y `usado = 129` (GB), imprime `Disco: 129 de 233 GB (55.4 %)`, con el porcentaje calculado y un decimal.
3. Sin ejecutarlo, ¿qué imprime `print(10 / 4, 10 // 4, 10 % 4, "10" * 2)`? Compruébalo después.
4. Escribe una tabla de tres sitios con su tiempo en ms, alineada como la de `informe.py`, usando una línea `print` por sitio.

## Cierre

En `notas/fase-4/clase-39.md`:

1. ¿Qué diferencia hay entre usar el intérprete interactivo y un script? ¿Cuándo usas cada uno?
2. ¿Por qué `"5" + 3` falla en Python y en Bash no hay un error equivalente? ¿Qué es mejor para un script de producción?
3. ¿Qué hacen `{t:.3f}` y `{s:<20}` dentro de una f-string?
4. **Repaso (clase 19, sin mirar):** ¿qué hace `set -u` en Bash? ¿Qué hace Python en el mismo caso?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El intérprete (`python3` y el `>>>`) ejecuta cada línea al momento: sirve para probar una idea, ver qué devuelve una función o hacer una cuenta. El script es un archivo que guardas, versionas con Git y ejecutas cuantas veces quieras: es lo que usas para todo lo que se repite.

**2.** Python tiene tipos y no convierte por su cuenta: no sabe si querías sumar o juntar texto, así que se niega. En Bash todo es texto y las variables se expanden sin comprobar nada, de modo que los errores de tipo pasan en silencio y aparecen más tarde, lejos de su causa. En producción es mejor fallar pronto y con un mensaje claro.

**3.** `{t:.3f}` muestra `t` con 3 decimales (`0.261`). `{s:<20}` muestra `s` ocupando 20 caracteres, alineado a la izquierda y rellenando con espacios: así las columnas quedan alineadas.

**4.** `set -u` hace que usar una variable no definida sea un error que detiene el script, en lugar de valer vacío. Python lo hace siempre: `NameError`, y el programa se detiene.

**Reto (soluciones posibles):**
```python
# unidades.py
tamano = 3_450_000_000
print(f"{tamano / 1024:.2f} KB")
print(f"{tamano / 1024**2:.2f} MB")
print(f"{tamano / 1024**3:.2f} GB")      # 3.21 GB

# disco.py
total = 233
usado = 129
print(f"Disco: {usado} de {total} GB ({usado / total * 100:.1f} %)")
```
Reto 3: `2.5 2 2 1010`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| interpreter | intérprete |
| data type | tipo de dato |
| string / integer / float | texto / entero / decimal |
| f-string (formatted string literal) | cadena con formato |
| traceback | traza del error |

🎙️ *"I use Bash to glue commands together, and Python when a script grows, needs real data structures or talks to an API."*

## Siguiente

[Clase 40 — Decisiones y bucles en Python](clase-40-decisiones-y-bucles.md)
