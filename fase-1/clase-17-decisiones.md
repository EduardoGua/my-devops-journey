# Clase 17 — Decisiones: if, test y case

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** C. Scripting con Bash

## Objetivo

- Entender que `if` **no evalúa expresiones**: ejecuta un comando y mira su código de salida.
- Comprobar archivos, textos y números con `[[ ]]` y `(( ))`.
- Validar argumentos y dependencias al principio del script: fallar pronto y con un mensaje claro.
- Elegir entre varias acciones con `case`.
- Escribir tu primer *health check*: un script que dice si una web responde.

## Por qué importa

Un script sin comprobaciones hace daño en silencio: sigue después de un fallo, trabaja en la carpeta equivocada o dice "todo bien" con el servicio caído. Los *health checks* de un balanceador, los pasos de un pipeline de CI y los scripts de despliegue son, en el fondo, decisiones sobre códigos de salida. Hoy arreglas `tamano.sh`, que en la clase 16 mentía.

## Teoría

### `if` ejecuta un comando

```bash
if grep -q "^educo:" /etc/passwd; then
  echo "el usuario existe"
else
  echo "no existe"
fi
```

`if` ejecuta el comando que le sigue: si devuelve **0**, entra en `then`; si devuelve otra cosa, en `else`. No hay corchetes porque no hacen falta: `grep -q` ya devuelve 0 o 1. Los corchetes `[[ ... ]]` son **un comando más**, que devuelve 0 si la comprobación es cierta.

También existe `elif` para encadenar casos:

```bash
if [[ $USO -ge 90 ]]; then echo "crítico"
elif [[ $USO -ge 80 ]]; then echo "aviso"
else echo "bien"
fi
```

### Comprobaciones con `[[ ]]`

| Tipo | Operadores |
|------|------------|
| Archivos | `-e` existe · `-f` es un archivo · `-d` es un directorio · `-r` / `-w` / `-x` legible, escribible, ejecutable · `-s` no está vacío |
| Texto | `-z` vacío · `-n` no vacío · `==` igual · `!=` distinto · `== patrón*` coincide con un comodín · `=~ regex` coincide con una expresión regular |
| Números | `-eq` `-ne` `-lt` `-le` `-gt` `-ge` (igual, distinto, menor, menor o igual…) |
| Lógica | `&&`, `\|\|` y `!` dentro de los corchetes |

Hay dos versiones de corchetes:
- `[ ... ]` es el comando `test` clásico (POSIX). Funciona en cualquier `sh`, pero parte las variables sin comillas por los espacios y no entiende patrones.
- `[[ ... ]]` es de bash: más seguro y más potente. **En tus scripts de bash, usa `[[ ]]`.** Aun así, verás `[ ]` en muchos sitios (Dockerfiles, scripts de `sh`), así que tienes que saber leerlo.

### Aritmética con `(( ))`

```bash
(( INTENTOS > 3 )) && echo "demasiados intentos"   # comparación: 0 si es verdad
TOTAL=$(( A + B * 2 ))                            # cálculo
```

Solo trabaja con **números enteros**. Dentro de `(( ))` no hace falta el `$` delante de las variables.

### `case`: elegir por patrón

```bash
case "$1" in
  start)      echo "arrancando" ;;
  stop)       echo "parando" ;;
  -h|--help)  echo "Uso: $0 start|stop" ;;
  *)          echo "Opción desconocida: $1" >&2; exit 2 ;;
esac
```

Cada rama termina en `;;`. `|` separa alternativas y `*` recoge todo lo demás. Es más legible que una cadena de `elif` cuando comparas un valor contra varias opciones.

### El patrón "falla pronto"

```bash
#!/bin/bash
# Uso: ./copia.sh <carpeta>
[[ $# -eq 1 ]]  || { echo "Uso: $0 <carpeta>" >&2; exit 2; }
[[ -d $1 ]]     || { echo "Error: '$1' no es un directorio" >&2; exit 1; }
command -v tar > /dev/null || { echo "Error: falta tar" >&2; exit 1; }
# a partir de aquí, todo lo que el script necesita existe
```

Valida al principio y sal con un mensaje claro. Es mucho mejor que fallar a mitad del trabajo con un error confuso. `command -v programa` devuelve 0 si el programa existe en el PATH.

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
`[[-f: orden no encontrada`. `[[` es una palabra del shell y necesita espacios a los dos lados, igual que cualquier comando y sus argumentos.

**4. El corchete que sobra:**
```bash
if [[ grep -q root /etc/passwd ]]; then echo "sí"; fi
```
Error de sintaxis. `if` ya ejecuta comandos: se escribe `if grep -q root /etc/passwd; then …`. Los corchetes son solo para las comprobaciones de la tabla.

## Reto

1. `es-par.sh <número>`: comprueba que el argumento es un entero positivo (`=~ ^[0-9]+$`). Si no lo es, sale con 2 y un mensaje de uso. Si lo es, imprime `par` o `impar` usando `(( N % 2 == 0 ))`.
2. `revisar-servicio.sh <servicio>`: con `systemctl is-active --quiet "$1"`, imprime `OK: <servicio> activo` y sale con 0, o `CAÍDO: <servicio>` y sale con 1. Sin argumento, mensaje de uso y salida con 2. Pruébalo con `cron` (que está activo en tu Ubuntu) y con un nombre inventado.
3. Mejora `revisar-url.sh` con `case`: `-h` o `--help` muestran el uso, y sin argumento revisa `https://example.com`.
4. En una sola línea: si `~/.bashrc` existe y no está vacío, imprime cuántas líneas tiene.

## Cierre

En `notas/fase-1/clase-17.md`:

1. ¿Qué evalúa exactamente `if`? Pon un ejemplo sin corchetes.
2. ¿Por qué conviene validar los argumentos y las dependencias al principio de un script?
3. ¿Qué diferencia hay entre `[[ 10 < 9 ]]` y `(( 10 < 9 ))`?
4. **Repaso (clase 16, sin mirar):** ¿qué hace `${1:?mensaje}` y para qué sirve?

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
Reto 3: envuelve la lógica en `case "${1:-}" in -h|--help) …; exit 0 ;; "") URL=https://example.com ;; *) URL="$1" ;; esac`.

Reto 4: `[[ -s ~/.bashrc ]] && wc -l < ~/.bashrc`
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
