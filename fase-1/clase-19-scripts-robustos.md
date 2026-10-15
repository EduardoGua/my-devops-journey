# Clase 19 — Funciones y scripts robustos: set -euo pipefail, trap y logs

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** C. Scripting con Bash

> 💡 **La idea de hoy:** un script de verdad tiene que **fallar de forma segura**. `set -euo pipefail` lo para en el primer error en lugar de seguir a ciegas, `trap` limpia lo que dejó a medias termine como termine, y `shellcheck` lo revisa antes de ejecutarlo, como un corrector ortográfico para Bash.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Tus scripts con argumentos, `${1:?…}` y `exit N` (clase 16).
> - Los fallos que esconde un pipe, como `cat /no-existe | wc -l` (clase 04).
> - `if`, `||` y el portero en la entrada (clase 17), y el bucle de `esperar-url.sh` (clase 18).

> 🔤 **Palabras nuevas de hoy:**
> - **función**: un trozo de script con nombre, que llamas cuando lo necesitas.
> - **modo estricto**: `set -euo pipefail`, los tres cinturones de seguridad.
> - **trap**: lo que se ejecuta siempre al salir del script.
> - **archivo temporal**: uno que se crea para trabajar y se borra al terminar (`mktemp`).
> - **linter** (`shellcheck`): un programa que revisa tu código sin ejecutarlo.

## Objetivo

- Organizar un script en **funciones** con variables `local` y códigos de retorno.
- Activar el modo estricto `set -euo pipefail` y saber qué hace cada parte… y dónde **no** te protege.
- Limpiar siempre al salir con `trap` y archivos temporales de `mktemp`.
- Dejar un log con fecha y nivel, y enviar avisos al journal con `logger`.
- Revisar tus scripts con `shellcheck` antes de usarlos.

## Por qué importa

Un script que sigue adelante después de un error es peor que no tener script: hace el 80 % del trabajo y deja el sistema a medias. `set -euo pipefail` es la primera línea de casi cualquier script profesional: la verás en Dockerfiles, en pipelines de CI y en Vigía. `shellcheck` es el analizador que muchos equipos ejecutan en cada pull request. En la clase 04 viste que un pipe esconde los fallos: hoy lo arreglas.

## Teoría

Seis piezas. Todas sirven para lo mismo: que tu script **falle de forma segura** en lugar de seguir a ciegas.

### 1. Funciones: recetas dentro de la receta

Una función es un trozo de script con nombre, que llamas cuando lo necesitas, como una receta pequeña dentro de la grande:

```bash
saludar() {
  local nombre="$1"         # local: solo existe dentro de la función
  echo "Hola, $nombre"
}
saludar "Ana"
```

- Dentro de la función, `$1`, `$2` y `"$@"` son **sus** ingredientes, no los del script.
- `local` hace que la variable exista **solo** dentro de la función. Sin `local`, podría pisar otra variable del script con el mismo nombre.
- Una función devuelve cosas por los mismos dos sitios que cualquier programa: **datos** por la manguera 1 (que capturas con `$(...)`) y una **nota** con `return N` (o la del último comando que ejecutó).

**En resumen:** una función es un trozo de script con nombre; `local` guarda sus variables dentro de ella.

### 2. El modo estricto: tres cinturones de seguridad

Sin nada, un script sigue adelante aunque algo falle. Esta línea, justo debajo del shebang, le pone tres cinturones:

```bash
#!/bin/bash
set -euo pipefail
```

| Opción | Qué hace | Lo que evita |
|--------|----------|--------------|
| `-e` (*errexit*) | el script sale en cuanto un comando falla | seguir trabajando después de un error |
| `-u` (*nounset*) | usar una variable que no existe es un error | el `$DIRETORIO` vacío de la clase 16 |
| `-o pipefail` | un pipe falla si falla **cualquiera** de sus comandos | el pipe "en verde" de la clase 04 |

Con `-u`, una variable opcional se lee con valor por defecto (clase 16): `${APP_ENV:-}` vale vacío en lugar de dar error.

**En resumen:** `-e` para al primer fallo, `-u` no deja usar variables que no existen y `pipefail` no deja que un pipe esconda fallos.

### 3. Los fallos que esperas

`set -e` **no** para el script cuando el comando que falla está:
- en la pregunta de un `if` o de un `while`;
- a la izquierda de `&&` o de `||`;
- negado con `!`.

Es a propósito: así tratas los fallos que **esperas**, los que no son errores de verdad.

```bash
if ! grep -q "^ana:" /etc/passwd; then echo "ana no existe"; fi   # fallo esperado y tratado
N="$(grep -c "zzz" archivo || true)"                             # "no hay coincidencias" no es un error
```

Dos trampas que verás en el Rómpelo:
- `(( contador++ ))` con `contador=0` deja nota 1 y **mata el script**. Usa `contador=$(( contador + 1 ))`.
- `local x=$(comando)` esconde el fallo del comando: la nota que ve `set -e` es la de `local`, que siempre sale bien. Sepáralo en dos: `local x; x=$(comando)`.

`set -e` es una red de seguridad, no un sustituto de comprobar tú los errores importantes.

**En resumen:** en un `if`, con `||` o con `!`, el fallo es «esperado» y `set -e` no para el script.

### 4. `trap`: recoger al salir, pase lo que pase

Como quien cierra la cocina al irse, **termine como termine**:

```bash
TMP="$(mktemp -d)"                 # crea un directorio temporal con nombre único
trap 'rm -rf "$TMP"' EXIT          # se ejecuta al salir: por éxito, por error o con Ctrl+C
```

`mktemp -d` crea una carpeta temporal con un nombre único. `trap '…' EXIT` apunta lo que hay que hacer **al salir del script**: tanto si termina bien como si falla o pulsas `Ctrl+C`.

**En resumen:** `trap '…' EXIT` es la limpieza que se hace siempre, termine como termine el script.

### 5. Dejar rastro: logs

```bash
log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }   # log NIVEL mensaje…
log INFO "empiezo"
log ERROR "no encuentro el archivo"
logger -t mi-script "copia terminada"               # al journal: journalctl -t mi-script
```

`log INFO "mensaje"` escribe una línea con fecha, hora y nivel por la manguera 2. `${*:2}` son todos los argumentos desde el segundo, unidos en un texto. `logger` deja el mensaje en el journal (clase 13).

**En resumen:** `log` deja una línea con fecha y nivel; `logger` la deja en el journal.

### 6. `shellcheck`: el corrector ortográfico de Bash

`shellcheck script.sh` lee tu script **sin ejecutarlo** y te avisa de los errores típicos: comillas que faltan, `cd` sin comprobar, `$(ls)` en un bucle… Cada aviso tiene un código (`SC2086`…) con su explicación en la wiki de shellcheck. Lo instalarás hoy.

**En resumen:** pasa `shellcheck` a cada script antes de darlo por bueno.

### Todo junto: la plantilla

Así empezarán tus scripts a partir de ahora, Vigía incluido:

```bash
#!/bin/bash
# nombre.sh — qué hace, en una línea
# Uso: nombre.sh <argumento>
set -euo pipefail

log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }
die() { log ERROR "$*"; exit 1; }

main() {
  [[ $# -eq 1 ]] || { echo "Uso: $0 <argumento>" >&2; exit 2; }
  log INFO "trabajando con $1"
}

main "$@"
```

`main "$@"` va en la **última** línea: bash lee primero todas las funciones, y la lógica del script (`main`) queda arriba, fácil de leer.

**En resumen:** la plantilla junta todo: modo estricto, `log`, `die` y `main`.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Un script con `set -e` hace `cd /no-existe` y después `rm -rf *`. ¿Llega a ejecutar el `rm`?
2. Con `set -u`, escribes `$DIRETORIO` en lugar de `$DIRECTORIO`. ¿Qué pasa?
3. ¿Cuándo se ejecuta lo que pones en `trap '…' EXIT`?

<details>
<summary>Comprueba</summary>

1. No: el `cd` falla y `set -e` para el script ahí. Sin él, borraría lo que hubiera en la carpeta actual. 2. El script se para con `DIRETORIO: variable sin asignar` en lugar de seguir con un valor vacío. 3. Al salir del script, termine como termine: bien, con error o con `Ctrl+C`.
</details>

### Tu chuleta de la clase

| Escribes | Qué es |
|----------|--------|
| `nombre() { …; }` · `nombre arg1 arg2` | definir una función · llamarla |
| `local x="$1"` · `return 1` | variable solo de la función · terminar la función con nota 1 |
| `set -euo pipefail` | los tres cinturones: parar al fallar, variables sin definir, pipes |
| `if ! cmd; then …` · `cmd \|\| true` | tratar un fallo esperado · ignorarlo a propósito |
| `TMP="$(mktemp -d)"` · `trap '…' EXIT` | carpeta temporal · qué hacer al salir |
| `logger -t nombre "mensaje"` | escribir en el journal (`journalctl -t nombre`) |
| `shellcheck script.sh` | revisar el script sin ejecutarlo |
| `bash -x script.sh` | ver cada línea según se ejecuta (clase 16) |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-19 && cd ~/my-devops-journey/labs/clase-19
sudo apt install -y shellcheck
shellcheck --version
```

`shellcheck` es una herramienta de desarrollo, como `git`: va en tu Ubuntu.

### 1. Funciones

```bash
cat > funciones.sh <<'EOF'
#!/bin/bash
es_numero() {               # devuelve 0 si $1 es un entero positivo
  [[ $1 =~ ^[0-9]+$ ]]      # el estado de la función es el de su último comando
}
doble() {                   # imprime el doble de $1
  local n="$1"
  echo $(( n * 2 ))
}
for X in 4 hola 21; do
  if es_numero "$X"; then
    echo "$X → $(doble "$X")"
  else
    echo "$X no es un número" >&2
  fi
done
EOF
chmod +x funciones.sh && ./funciones.sh
```

👀 **Qué deberías ver:** `4 → 8`, `hola no es un número` y `21 → 42`.

`es_numero` responde con su **estado** (se usa en un `if`) y `doble` con su **salida** (se captura con `$(...)`).

### 2. `set -e`: antes y después

```bash
cat > sin-estricto.sh <<'EOF'
#!/bin/bash
cd /no-existe
touch marca-sin-estricto
echo "terminé (¿seguro?)"
EOF
chmod +x sin-estricto.sh
```

🔮 **Predice:** ¿dónde se creará `marca-sin-estricto`? ¿Qué código devolverá el script?

```bash
./sin-estricto.sh ; echo "código: $?"
ls marca-sin-estricto
```

<details>
<summary>Qué deberías ver</summary>

El error del `cd`, `terminé (¿seguro?)`, `código: 0` y el archivo `marca-sin-estricto` creado aquí: en la carpeta equivocada.
</details>

El `cd` falló, el script siguió y creó el archivo **en la carpeta equivocada**, y encima devolvió 0. Ahora imagina `rm -rf *` en lugar de `touch`. Activa el modo estricto e inténtalo de nuevo:

```bash
sed -i '2i set -euo pipefail' sin-estricto.sh     # inserta la línea en la posición 2
head -3 sin-estricto.sh
rm marca-sin-estricto
./sin-estricto.sh ; echo "código: $?"
ls marca-sin-estricto
```

👀 **Qué deberías ver:** las tres primeras líneas, con `set -euo pipefail` en la segunda; el error del `cd` y `código: 1`; y `ls` diciendo que `marca-sin-estricto` no existe.

Se detiene en el `cd`, con código 1, y no crea nada.

### 3. `set -u`

```bash
bash -c 'set -u; DIRECTORIO=/tmp; echo "$DIRETORIO"' ; echo "código: $?"
bash -c 'set -u; echo "modo: ${APP_ENV:-desarrollo}"'
```

👀 **Qué deberías ver:** `DIRETORIO: variable sin asignar`, con un código distinto de 0; y `modo: desarrollo`.

`DIRETORIO: variable sin asignar`: la errata de la clase 16 ya no pasa en silencio.

### 4. `pipefail`: el arreglo de la clase 04

```bash
bash -c 'cat /no-existe | wc -l; echo "código: $?"'
bash -c 'set -o pipefail; cat /no-existe | wc -l; echo "código: $?"'
```

👀 **Qué deberías ver:** en los dos, el error de `cat` y un `0`; pero `código: 0` en el primero y `código: 1` en el segundo.

### 5. Fallos que esperas

```bash
cat > esperado.sh <<'EOF'
#!/bin/bash
set -euo pipefail
if grep -q "^nadie:" /etc/passwd; then
  echo "existe"
else
  echo "no existe, y el script sigue"
fi
N="$(grep -c "zzz" /etc/passwd || true)"
echo "coincidencias: $N"
echo "fin"
EOF
chmod +x esperado.sh && ./esperado.sh
```

👀 **Qué deberías ver:** `no existe, y el script sigue`, `coincidencias: 0` y `fin`.

🔮 **Predice:** ¿qué pasaría sin el `|| true`? Quítalo, ejecuta y vuelve a ponerlo. `grep -c` imprime `0` y devuelve 1 cuando no encuentra nada, y con `set -e` eso detiene el script antes del `echo`.

### 6. `trap` y `mktemp`

```bash
cat > temporal.sh <<'EOF'
#!/bin/bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; echo "limpieza: borré $TMP" >&2' EXIT
echo "trabajando en $TMP"
date > "$TMP/datos.txt"
ls "$TMP"
false                       # simula un fallo a mitad del trabajo
echo "nunca llego aquí"
EOF
chmod +x temporal.sh
./temporal.sh ; echo "código: $?"
```

<details>
<summary>Qué deberías ver</summary>

`trabajando en /tmp/tmp.…`, `datos.txt`, `limpieza: borré /tmp/tmp.…` y `código: 1`: el `false` paró el script, pero la limpieza se hizo.
</details>

🔮 **Predice:** ¿se borra el temporal aunque el script falle? Compruébalo con `ls /tmp | grep tmp.` antes y después.

### 7. Logs en pantalla y en el journal

```bash
cat > con-log.sh <<'EOF'
#!/bin/bash
set -euo pipefail
log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }
log INFO "empiezo"
logger -t clase19 "hola desde mi script"
log INFO "dejé un mensaje en el journal"
EOF
chmod +x con-log.sh && ./con-log.sh
journalctl -t clase19 -n 3 --no-pager
```

👀 **Qué deberías ver:** dos líneas con fecha, hora e `[INFO]`, y tu `hola desde mi script` en el journal.

Puedes leer el journal sin `sudo` porque tu usuario está en el grupo `adm`.

### 8. `shellcheck` encuentra lo que tú no ves

```bash
cat > malo.sh <<'EOF'
#!/bin/bash
DIR=$1
for F in $(ls $DIR); do
  echo "Archivo: $F"
done
cd $DIR
rm -rf $DIR/*
EOF
shellcheck malo.sh
```

Lee cada aviso. Fíjate en **SC2115**: `rm -rf $DIR/*` se convierte en `rm -rf /*` si `$DIR` está vacío. Es la errata de Steam de la clase 16, detectada antes de ejecutar nada. Arréglalo hasta que `shellcheck` no diga nada:

```bash
cat > bueno.sh <<'EOF'
#!/bin/bash
# Uso: ./bueno.sh <carpeta> — lista una carpeta y vacía su contenido
set -euo pipefail
DIR="${1:?Uso: $0 <carpeta>}"
for F in "$DIR"/*; do
  echo "Archivo: $F"
done
rm -rf "${DIR:?}"/*
EOF
shellcheck bueno.sh && echo "shellcheck: sin avisos"
```

(No lo ejecutes contra una carpeta que te importe: vacía su contenido.)

¿Y el `cd "$DIR"` de `malo.sh`? Sobraba, y además era un error que shellcheck no ve: después de `cd prueba`, la ruta relativa `prueba/*` apunta a `prueba/prueba/*`. Con una ruta relativa, el `rm` no habría borrado nada… o habría borrado otra cosa. Un analizador encuentra erratas, no errores de lógica.

## Rómpelo

**1. El contador que mata el script:**
```bash
bash -c 'set -e; i=0; (( i++ )); echo "llegué, i=$i"' ; echo "código: $?"
bash -c 'set -e; i=0; i=$(( i + 1 )); echo "llegué, i=$i"'
```
El primero muere sin imprimir nada y con código 1. `(( i++ ))` devuelve el valor **anterior** de `i`, 0, y en aritmética 0 significa "falso". Usa siempre `i=$(( i + 1 ))`.

**2. `local` esconde el fallo:**
```bash
cat > local.sh <<'EOF'
#!/bin/bash
set -euo pipefail
leer() {
  local contenido=$(cat /no-existe)
  echo "leído: '$contenido'"
}
leer
echo "el script siguió"
EOF
bash local.sh ; echo "código: $?"
shellcheck local.sh
```
El `cat` falla, pero el script sigue y termina con 0: `set -e` vio el código de `local`, que funcionó. `shellcheck` lo avisa (SC2155). Arreglo: `local contenido; contenido=$(cat /no-existe)`.

**3. `set -e` se apaga dentro de una condición:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
bash -c 'set -e; f() { false; echo "f siguió tras el false"; }; if f; then echo "f devolvió 0"; fi'
```
Imprime las dos líneas. Cuando una función se llama en la condición de un `if`, `set -e` queda desactivado **dentro de toda la función**. En Vigía comprobarás los errores importantes tú mismo, sin confiar solo en `set -e`.

**4. Ctrl+C también limpia:**
```bash
cat > largo.sh <<'EOF'
#!/bin/bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; echo "limpieza hecha" >&2' EXIT
echo "trabajando en $TMP: pulsa Ctrl+C"
sleep 30
EOF
chmod +x largo.sh && ./largo.sh
```
Pulsa `Ctrl+C`: verás `limpieza hecha` y el directorio desaparece. Ejecuta `echo $?` justo después: 130 = 128 + 2, la señal SIGINT (clase 11).

## Reto

En `labs/clase-19/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Pasa `shellcheck` a tus scripts de las clases 16 a 18. Arregla al menos tres avisos y apunta en tus notas qué significaba cada código.

> 🧩 **Ejemplo resuelto:** leer los avisos de `malo.sh`, de la práctica 8.
> ```bash
> shellcheck malo.sh
> ```
> Cada aviso dice la línea, el código (`SC2086`…) y qué falla. El código se busca en `https://www.shellcheck.net/wiki/SC2086` (cambiando el número).

**Ahora tú, con huecos:** `cd ~/my-devops-journey/labs/clase-____ && shellcheck *.sh`

<details>
<summary>Pista</summary>

Repite con las carpetas 16, 17 y 18. Empieza por los avisos que ya conoces de la práctica, como las comillas que faltan.
</details>

**2.** Reescribe `esperar-url.sh` (clase 18) con la plantilla: `set -euo pipefail`, funciones `log`, `die` y `main`, y que `shellcheck` no dé ningún aviso.

> 🧩 **Ejemplo resuelto:** `log` en acción.
> ```bash
> log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }
> log INFO "empiezo"
> log WARN "algo raro"
> ```
> `log` escribe con fecha, hora y nivel por la manguera 2. `die` hace lo mismo con `ERROR` y además **termina** el script: no la pruebes en tu terminal, porque la cerraría.

**Ahora tú, con huecos:**
```bash
#!/bin/bash
# esperar-url.sh — espera a que una URL responda, con un límite de intentos
set -euo pipefail

log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }
die() { log ERROR "$*"; exit 1; }

main() {
  local url="${1:?Uso: $0 <url> [intentos]}"
  local max="${2:-5}" i
  for (( i = 1; i <= max; i++ )); do
    if curl -fs -o /dev/null --max-time 2 "$url"; then
      log ____ "$url responde (intento $i)"
      return 0
    fi
    log ____ "intento $i/$max: $url no responde"
    sleep 2
  done
  ____ "$url no respondió tras $max intentos"
}

____ "$@"
```

<details>
<summary>Pista</summary>

Dos niveles de `log` (uno para «bien» y otro para «aviso»), la función que termina con error, y la última línea de la plantilla.
</details>

**3.** `limpiar-viejos.sh <carpeta> <días> [--dry-run]`: borra los archivos de la carpeta con más de N días (`find "$DIR" -type f -mtime +"$DIAS" -print -delete`). Valida que la carpeta existe y que los días son un número. Con `--dry-run`, solo lista lo que borraría.

> 🧩 **Ejemplo resuelto:** listar, sin borrar, lo que tiene más de 7 días en una carpeta de prueba.
> ```bash
> mkdir -p prueba-viejos
> touch -d "10 days ago" prueba-viejos/viejo.txt
> touch prueba-viejos/nuevo.txt
> find prueba-viejos -type f -mtime +7 -print
> ```
> `touch -d` fabrica un archivo «viejo». `find` solo encuentra `viejo.txt`: `nuevo.txt` tiene menos de 7 días.

**Ahora tú, con huecos:**
```bash
#!/bin/bash
set -euo pipefail
DIR="${1:?Uso: $0 <carpeta> <días> [--dry-run]}"
DIAS="${2:?Uso: $0 <carpeta> <días> [--dry-run]}"
[[ -d $DIR ]] || { echo "Error: $DIR no es una carpeta" >&2; exit 1; }
[[ $DIAS =~ ^[0-9]+$ ]] || { echo "Error: los días deben ser un número" >&2; exit 2; }
if [[ ${3:-} == ____ ]]; then
  find "$DIR" -type f -mtime +"$DIAS" -print
else
  find "$DIR" -type f -mtime +"$DIAS" -print ____
fi
```

<details>
<summary>Pista</summary>

El primer hueco es la opción del modo de prueba, tal cual se escribe. El segundo, lo que hace que `find` borre lo que encuentra (está en el enunciado). Pruébalo primero con `--dry-run`.
</details>

## Cierre

En `notas/fase-1/clase-19.md`:

1. Explica qué hace cada parte de `set -euo pipefail` con un ejemplo de lo que evita. *(3 líneas, una por opción. Empieza así: «`-e` para el script cuando…, y evita… `-u`… `-o pipefail`…»)*
2. Nombra dos situaciones en las que `set -e` no detiene el script. ¿Cómo manejas un fallo que esperas? *(2 líneas. Empieza así: «No actúa en la condición de un `if` ni a la izquierda de… Un fallo que espero lo trato con…»)*
3. ¿Para qué sirve `trap '…' EXIT`? Pon un ejemplo real. *(2 líneas. Empieza así: «Para hacer algo al salir, termine como termine… Por ejemplo, borrar…»)*
4. **Repaso (clase 18, sin mirar):** ¿por qué `cmd | while read …` pierde las variables al terminar? *(2 líneas. Empieza así: «Porque cada parte del pipe corre en un…, y el `while` cambia su…»)*

Después, escríbeme `examíname clase-19`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `-e`: el script se detiene en cuanto un comando falla; evita, por ejemplo, seguir después de un `cd` fallido y borrar en la carpeta equivocada. `-u`: usar una variable que no existe es un error; evita que una errata convierta `"$DIRETORIO"/*` en `/*`. `-o pipefail`: un pipe falla si falla cualquiera de sus partes, no solo la última; evita que `cat archivo-que-no-existe | wc -l` parezca un éxito.

**2.** Cuando el comando está en la condición de un `if`/`while`/`until`, a la izquierda de `&&` o `||`, o negado con `!`. También dentro de una función llamada desde un `if`. Un fallo esperado se maneja precisamente así: `if ! comando; then …` o `comando || true` cuando el fallo no importa, siempre de forma explícita.

**3.** Para ejecutar código de limpieza al salir, termine el script bien, con error o con `Ctrl+C`. Ejemplos: borrar un directorio temporal de `mktemp`, liberar un bloqueo, parar un servidor de pruebas que el script arrancó o desmontar un disco.

**4.** Porque cada lado del pipe corre en un proceso hijo: el `while` cambia su copia de la variable, que desaparece al terminar el pipe. Se arregla con `while …; done < archivo` o `done < <(comando)`.

**Reto 2 (una solución):**
```bash
cat > esperar-url.sh <<'EOF'
#!/bin/bash
# esperar-url.sh — espera a que una URL responda, con un límite de intentos
# Uso: esperar-url.sh <url> [intentos]
set -euo pipefail

log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }
die() { log ERROR "$*"; exit 1; }

main() {
  local url="${1:?Uso: $0 <url> [intentos]}"
  local max="${2:-5}" i
  [[ $max =~ ^[0-9]+$ ]] || die "intentos debe ser un número: $max"
  for (( i = 1; i <= max; i++ )); do
    if curl -fs -o /dev/null --max-time 2 "$url"; then
      log INFO "$url responde (intento $i)"
      return 0
    fi
    log WARN "intento $i/$max: $url no responde"
    sleep 2
  done
  die "$url no respondió tras $max intentos"
}

main "$@"
EOF
```

**Reto 3 (la parte central):**
```bash
if [[ ${3:-} == --dry-run ]]; then
  find "$DIR" -type f -mtime +"$DIAS" -print
else
  find "$DIR" -type f -mtime +"$DIAS" -print -delete
fi
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| strict mode | modo estricto |
| cleanup / trap | limpieza / manejador de salida |
| linter / static analysis | analizador estático |
| temporary file | archivo temporal |
| log level | nivel de log (INFO, WARN, ERROR) |

🎙️ *"Every script I write starts with `set -euo pipefail`, cleans up its temporary files with a trap, and passes shellcheck before it's merged."*

## Siguiente

[Clase 20 — Tareas programadas: cron y backups](clase-20-cron-y-backups.md)
