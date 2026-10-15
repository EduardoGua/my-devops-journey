# Clase 17 — Decisiones: if, test y case

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** C. Scripting con Bash

> 💡 **La idea de hoy:** `if` no entiende de «verdadero» o «falso»: **ejecuta un comando y mira su código de salida**. Si es 0, entra en `then`. Los corchetes `[[ ]]` son solo otro comando que responde 0 o 1. Con eso, tu script comprueba antes de actuar y, si algo no cuadra, **falla pronto y con un mensaje claro** en vez de romper algo a medias.

## Objetivo

- Entender que `if` **no evalúa expresiones**: ejecuta un comando y mira su código de salida.
- Comprobar archivos, textos y números con `[[ ]]` y `(( ))`.
- Validar argumentos y dependencias al principio del script: fallar pronto y con un mensaje claro.
- Elegir entre varias acciones con `case`.
- Escribir tu primer *health check*: un script que dice si una web responde.

## Por qué importa

Un script sin comprobaciones hace daño en silencio: sigue después de un fallo, trabaja en la carpeta equivocada o dice "todo bien" con el servicio caído. Los *health checks* de un balanceador, los pasos de un pipeline de CI y los scripts de despliegue son, en el fondo, decisiones sobre códigos de salida. Hoy arreglas `tamano.sh`, que en la clase 16 mentía.

## Teoría

Cinco piezas. La 1 es la idea que cambia cómo ves los scripts: léela despacio.

### 1. `if` mira la nota de un comando

Recuerda la **nota** que deja cada programa al terminar (clase 04): 0 si fue bien, otra cosa si falló. `if` no evalúa «verdadero o falso»: **ejecuta un comando y mira su nota**.

```bash
if grep -q "^educo:" /etc/passwd; then      # ejecuta grep (-q: sin imprimir nada)...
  echo "el usuario existe"                  # ...si su nota es 0, viene aquí
else
  echo "no existe"                          # ...si no, aquí
fi
```

No hay corchetes porque no hacen falta: `grep` ya deja su nota. Para encadenar varios casos existe `elif` («y si no, si…»):

```bash
if [[ $USO -ge 90 ]]; then echo "crítico"
elif [[ $USO -ge 80 ]]; then echo "aviso"
else echo "bien"
fi
```

### 2. `[[ ]]`: un comando que solo sabe hacer preguntas

Los corchetes dobles **también son un comando**: hacen una pregunta y dejan nota 0 si la respuesta es «sí». Las preguntas más útiles:

| Sobre… | Pregunta | Ejemplo |
|--------|----------|---------|
| archivos | ¿existe? ¿es un archivo? ¿es un directorio? | `[[ -e $F ]]` · `[[ -f $F ]]` · `[[ -d $D ]]` |
| texto | ¿está vacío? ¿es igual a…? ¿se parece a…? | `[[ -z $V ]]` · `[[ $V == si ]]` · `[[ $V == web-* ]]` |
| números | ¿es igual? ¿menor? ¿mayor o igual? | `[[ $N -eq 0 ]]` · `[[ $N -lt 10 ]]` · `[[ $N -ge 80 ]]` |

Los números se comparan con letras (`-eq` *equal*, `-lt` *less than*, `-ge` *greater or equal*…) porque `<` y `>` dentro de `[[ ]]` comparan **texto**, por orden alfabético. Lo comprobarás en el Rómpelo 2.

Verás también corchetes **simples**, `[ … ]`: es la versión clásica, que funciona en cualquier `sh` pero es más frágil con las variables vacías. En tus scripts de bash, usa siempre los dobles.

### 3. `(( ))`: cuentas con números enteros

```bash
(( INTENTOS > 3 )) && echo "demasiados intentos"   # comparar: nota 0 si es verdad
TOTAL=$(( A + B * 2 ))                            # calcular
```

Dentro de `(( ))` no hace falta el `$` delante de las variables, y `<` y `>` sí comparan números. Solo trabaja con **enteros**: nada de decimales.

### 4. `case`: elegir entre varias opciones

Cuando un valor puede ser una de varias cosas (como las opciones de un menú), `case` es más legible que una cadena de `elif`:

```bash
case "$1" in
  start)      echo "arrancando" ;;
  stop)       echo "parando" ;;
  -h|--help)  echo "Uso: $0 start|stop" ;;
  *)          echo "Opción desconocida: $1" >&2; exit 2 ;;
esac
```

Cada opción termina en `;;`. `|` separa alternativas («esto o aquello») y `*` es «cualquier otra cosa».

### 5. Fallar pronto: el portero en la entrada

Un buen script comprueba **al principio** que tiene todo lo que necesita, como un portero que revisa en la entrada en vez de echarte a mitad de la fiesta:

```bash
#!/bin/bash
# Uso: ./copia.sh <carpeta>
[[ $# -eq 1 ]]  || { echo "Uso: $0 <carpeta>" >&2; exit 2; }
[[ -d $1 ]]     || { echo "Error: '$1' no es un directorio" >&2; exit 1; }
command -v tar > /dev/null || { echo "Error: falta tar" >&2; exit 1; }
# a partir de aquí, todo lo que el script necesita existe
```

Cada línea se lee «comprueba esto **o** (`||`) quéjate y sal». `{ …; }` agrupa varios comandos para hacerlos juntos, y `command -v tar` deja nota 0 si el programa `tar` existe. Es mucho mejor que fallar a mitad del trabajo con un error confuso y las cosas a medias.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. En `if grep -q root /etc/passwd; then …`, ¿qué decide si se entra en el `then`?
2. ¿Cómo preguntas si `/srv/datos` es un directorio?
3. ¿Con qué comparas números dentro de `[[ ]]`: con `<` o con `-lt`?

<details>
<summary>Comprueba</summary>

1. La **nota** (el código de salida) de `grep`: si es 0, entra. 2. `[[ -d /srv/datos ]]`. 3. Con `-lt`: `<` compararía texto. (O usa `(( ))`, donde `<` sí compara números).
</details>

### Tu chuleta de la clase

| Pregunta | Operadores |
|----------|------------|
| Archivos | `-e` existe · `-f` es un archivo · `-d` es un directorio · `-r` / `-w` / `-x` se puede leer, escribir, ejecutar · `-s` no está vacío |
| Texto | `-z` vacío · `-n` no vacío · `==` igual · `!=` distinto · `== patrón*` como un comodín · `=~ regex` como una expresión regular |
| Números | `-eq` igual · `-ne` distinto · `-lt` menor · `-le` menor o igual · `-gt` mayor · `-ge` mayor o igual |
| Juntar preguntas | `&&` (y) · `\|\|` (o) · `!` (no), dentro de los corchetes |

| Estructura | Forma |
|------------|-------|
| decidir | `if cmd; then …; elif cmd; then …; else …; fi` |
| contar | `(( N > 3 ))` · `N=$(( N + 1 ))` |
| elegir | `case "$X" in a) …;; b\|c) …;; *) …;; esac` |
| fallar pronto | `[[ condición ]] \|\| { echo "Error…" >&2; exit 1; }` |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-17 && cd ~/my-devops-journey/labs/clase-17
```

### 1. `if` con comandos

🔮 **Predice:** ¿qué imprime cada línea?

```bash
if ls /etc/hostname > /dev/null 2>&1; then echo "existe"; else echo "no existe"; fi
if ls /no-existe > /dev/null 2>&1; then echo "existe"; else echo "no existe"; fi
if echo hola; then echo "echo devolvió 0"; fi
if ping -c1 -W1 1.1.1.1 > /dev/null 2>&1; then echo "hay internet"; fi
```

### 2. Comprobaciones

```bash
ARCHIVO=/etc/hostname
[[ -f $ARCHIVO ]] && echo "es un archivo"
[[ -d $ARCHIVO ]] || echo "no es un directorio"
[[ -w $ARCHIVO ]] && echo "puedo escribirlo" || echo "no puedo escribirlo"

VACIA=""
[[ -z $VACIA ]] && echo "está vacía"

NOMBRE="servidor-01"
[[ $NOMBRE == servidor-* ]] && echo "es un servidor"
[[ $NOMBRE =~ ^servidor-[0-9]+$ ]] && echo "y su nombre tiene el formato correcto"

USO=85
(( USO >= 80 )) && echo "disco por encima del 80 %"
```

`[[ -w /etc/hostname ]]` dice que no: el archivo es de root (clase 06).

### 3. Arreglar `tamano.sh`

```bash
cp ../clase-16/tamano.sh .
nano tamano.sh
```

Déjalo así:

```bash
#!/bin/bash
# Uso: ./tamano.sh <ruta>
# Imprime cuánto ocupa una ruta. Sale con 1 si la ruta no existe.
RUTA="${1:?Uso: $0 <ruta>}"
if [[ ! -e $RUTA ]]; then
  echo "Error: $RUTA no existe" >&2
  exit 1
fi
TAMANO="$(du -sh "$RUTA" | cut -f1)"
echo "$RUTA ocupa $TAMANO"
```

🔮 **Predice:** ¿qué código devuelve ahora con `/no-existe`?

```bash
./tamano.sh /no-existe ; echo "código: $?"
./tamano.sh ~/my-devops-journey ; echo "código: $?"
```

Ahora el script dice la verdad: quien lo use (una persona, cron o un pipeline) sabe que falló.

### 4. Tu primer health check

```bash
cat > revisar-url.sh <<'EOF'
#!/bin/bash
# Uso: ./revisar-url.sh <url>
# Sale con 0 si la URL responde con un código 2xx o 3xx, y con 1 si no.
URL="${1:?Uso: $0 <url>}"
CODIGO="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL")"
if [[ $CODIGO == [23]* ]]; then
  echo "UP   $CODIGO $URL"
else
  echo "DOWN $CODIGO $URL"
  exit 1
fi
EOF
chmod +x revisar-url.sh
```

Las opciones de `curl`:
- `-s` (*silent*): sin barra de progreso.
- `-o /dev/null`: descarta el cuerpo de la página. No lo necesitas.
- `-w '%{http_code}'`: al terminar, escribe solo el código HTTP.
- `--max-time 10`: no esperes más de 10 segundos.

🔮 **Predice** la salida y el código de cada una:

```bash
./revisar-url.sh https://example.com ; echo "código: $?"
./revisar-url.sh https://example.com/no-existe ; echo "código: $?"
./revisar-url.sh https://no-existe.invalid ; echo "código: $?"
```

`000` significa que **no hubo respuesta HTTP**: el nombre no se resolvió, la conexión se rechazó o se agotó el tiempo. Recuérdalo: lo verás a menudo en los logs de Vigía.

### 5. `case`: un servicio de mentira

```bash
cat > servicio.sh <<'EOF'
#!/bin/bash
# Uso: ./servicio.sh start|stop|status
ESTADO=/tmp/servicio-clase17.estado
case "${1:-}" in
  start)
    echo "activo" > "$ESTADO"
    echo "arrancado" ;;
  stop)
    rm -f "$ESTADO"
    echo "parado" ;;
  status)
    if [[ -f $ESTADO ]]; then
      echo "activo"
    else
      echo "inactivo"
      exit 3
    fi ;;
  -h|--help)
    echo "Uso: $0 start|stop|status" ;;
  *)
    echo "Uso: $0 start|stop|status" >&2
    exit 2 ;;
esac
EOF
chmod +x servicio.sh
./servicio.sh status ; echo "código: $?"
./servicio.sh start && ./servicio.sh status ; echo "código: $?"
./servicio.sh stop
./servicio.sh reiniciar ; echo "código: $?"
```

El código 3 para "inactivo" no es casual: `systemctl status` usa la misma convención (clase 12). Compruébalo con `systemctl status apt-daily.service > /dev/null; echo $?`.

## Rómpelo

**1. `[ ]` con una variable vacía:**
```bash
VACIA=""
[ $VACIA = "x" ] && echo "igual"
```
`[: =: se esperaba un operador unario`. Sin comillas, `$VACIA` desaparece y `[` recibe `[ = x ]`, que no tiene sentido. Con `[ "$VACIA" = "x" ]` o con `[[ $VACIA == x ]]` funciona. Es una de las razones para preferir `[[ ]]`.

**2. Comparar números como si fueran texto:**
```bash
[[ 10 < 9 ]] && echo "¿10 es menor que 9?"
[[ 10 -lt 9 ]] || echo "con -lt, no"
(( 10 < 9 )) || echo "con (( )), tampoco"
```
Dentro de `[[ ]]`, `<` compara **texto** en orden alfabético: `"1"` va antes que `"9"`. Para números, `-lt` o `(( ))`.

**3. Sin espacios dentro de los corchetes:**
```bash
[[-f /etc/hostname]] && echo ok
```
`[[-f: no se encontró la orden`. `[[` es una palabra del shell y necesita espacios a los dos lados, igual que cualquier comando y sus argumentos.

**4. El corchete que sobra:**
```bash
if [[ grep -q root /etc/passwd ]]; then echo "sí"; fi
```
Error de sintaxis. `if` ya ejecuta comandos: se escribe `if grep -q root /etc/passwd; then …`. Los corchetes son solo para las comprobaciones de la tabla.

## Reto

En `labs/clase-17/`. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** En una sola línea: si `~/.bashrc` existe y no está vacío, imprime cuántas líneas tiene.

<details>
<summary>Pista</summary>

`[[ -s archivo ]]` pregunta «¿existe y no está vacío?». Después, `&&` y `wc -l < ~/.bashrc` (con `<`, `wc` imprime solo el número).
</details>

**2.** `revisar-servicio.sh <servicio>`: con `systemctl is-active --quiet "$1"`, imprime `OK: <servicio> activo` y sale con 0, o `CAÍDO: <servicio>` y sale con 1. Sin argumento, mensaje de uso y salida con 2. Pruébalo con `cron` (activo en tu Ubuntu) y con un nombre inventado.

<details>
<summary>Pista</summary>

La estructura `if comando; then … else … fi` de la pieza 1, con `systemctl is-active --quiet "$1"` como comando. Para el argumento que falta, el portero de la pieza 5.
</details>

**3.** `es-par.sh <número>`: comprueba que el argumento es un número entero positivo con `[[ $N =~ ^[0-9]+$ ]]` («solo dígitos, del principio al final»). Si no lo es, sale con 2 y un mensaje de uso. Si lo es, imprime `par` o `impar`.

<details>
<summary>Pista</summary>

Dentro de `(( ))`, `%` es el **resto** de dividir: `7 % 2` es 1 y `8 % 2` es 0. Un número es par si el resto de dividirlo entre 2 es 0: `(( N % 2 == 0 ))`. Para validar, copia la línea del portero de la pieza 5.
</details>

**4.** Mejora `revisar-url.sh` con `case`: `-h` o `--help` muestran el uso, y sin argumento revisa `https://example.com`.

<details>
<summary>Pista</summary>

Un `case "${1:-}" in` con tres opciones: `-h|--help)`, `"")` (no llegó nada) y `*)` (cualquier otra cosa: es la URL).
</details>

## Cierre

En `notas/fase-1/clase-17.md`:

1. ¿Qué evalúa exactamente `if`? Pon un ejemplo sin corchetes.
2. ¿Por qué conviene validar los argumentos y las dependencias al principio de un script?
3. ¿Qué diferencia hay entre `[[ 10 < 9 ]]` y `(( 10 < 9 ))`?
4. **Repaso (clase 16, sin mirar):** ¿qué hace `${1:?mensaje}` y para qué sirve?

Después, escríbeme `examíname clase-17`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El **código de salida** del comando que le sigue: 0 entra en `then`, cualquier otro valor en `else`. Ejemplo: `if grep -q root /etc/passwd; then echo "existe"; fi`. `[[ ]]` es solo un comando que devuelve 0 o 1 según la comprobación.

**2.** Para fallar pronto y con un mensaje claro, **antes** de cambiar nada. Si el script descubre a mitad de camino que falta una carpeta o un programa, puede dejar el trabajo a medias (un backup incompleto, un despliegue parcial) y el error que se ve suele ser confuso.

**3.** `[[ 10 < 9 ]]` compara texto en orden alfabético y es **verdadero**, porque `"1"` va antes que `"9"`. `(( 10 < 9 ))` compara números y es falso. Para números: `(( ))` o `-lt`, `-gt`…

**4.** Si `$1` está vacío o no existe, imprime el mensaje en stderr y el script **sale con error** sin ejecutar nada más. Sirve para declarar argumentos obligatorios en una sola línea.

**Reto (soluciones posibles):**
```bash
cat > es-par.sh <<'EOF'
#!/bin/bash
# Uso: ./es-par.sh <número>
N="${1:-}"
[[ $N =~ ^[0-9]+$ ]] || { echo "Uso: $0 <número entero positivo>" >&2; exit 2; }
if (( N % 2 == 0 )); then echo "par"; else echo "impar"; fi
EOF

cat > revisar-servicio.sh <<'EOF'
#!/bin/bash
# Uso: ./revisar-servicio.sh <servicio>
SERVICIO="${1:-}"
[[ -n $SERVICIO ]] || { echo "Uso: $0 <servicio>" >&2; exit 2; }
if systemctl is-active --quiet "$SERVICIO"; then
  echo "OK: $SERVICIO activo"
else
  echo "CAÍDO: $SERVICIO"
  exit 1
fi
EOF
```
Reto 4: envuelve la lógica en `case "${1:-}" in -h|--help) …; exit 0 ;; "") URL=https://example.com ;; *) URL="$1" ;; esac`.

Reto 1: `[[ -s ~/.bashrc ]] && wc -l < ~/.bashrc`
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| conditional | condicional |
| to validate input | validar la entrada |
| fail fast | fallar pronto |
| health check | comprobación de salud |
| usage message | mensaje de uso |

🎙️ *"My scripts fail fast: they validate their arguments and dependencies at the top, and exit with a clear message and a non-zero code."*

## Siguiente

[Clase 18 — Bucles: for, while y leer archivos](clase-18-bucles.md)
