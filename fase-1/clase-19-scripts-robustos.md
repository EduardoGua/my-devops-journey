# Clase 19 — Funciones y scripts robustos: set -euo pipefail, trap y logs

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** C. Scripting con Bash

## Objetivo

- Organizar un script en **funciones** con variables `local` y códigos de retorno.
- Activar el modo estricto `set -euo pipefail` y saber qué hace cada parte… y dónde **no** te protege.
- Limpiar siempre al salir con `trap` y archivos temporales de `mktemp`.
- Dejar un log con fecha y nivel, y enviar avisos al journal con `logger`.
- Revisar tus scripts con `shellcheck` antes de usarlos.

## Por qué importa

Un script que sigue adelante después de un error es peor que no tener script: hace el 80 % del trabajo y deja el sistema a medias. `set -euo pipefail` es la primera línea de casi cualquier script profesional: la verás en Dockerfiles, en pipelines de CI y en Vigía. `shellcheck` es el analizador que muchos equipos ejecutan en cada pull request. En la clase 04 viste que un pipe esconde los fallos: hoy lo arreglas.

## Teoría

### Funciones

```bash
saludar() {
  local nombre="$1"         # local: solo existe dentro de la función
  echo "Hola, $nombre"
}
saludar "Ana"
```

- Dentro de una función, `$1`, `$2` y `"$@"` son **sus** argumentos, no los del script.
- Una función **devuelve datos** escribiéndolos en stdout (se capturan con `$(...)`) y **devuelve un estado** con `return N` o con el código de su último comando.
- Sin `local`, una variable creada dentro de la función es global y puede pisar otra del script.

### Modo estricto

```bash
#!/bin/bash
set -euo pipefail
```

| Opción | Qué hace | Lo que evita |
|--------|----------|--------------|
| `-e` (*errexit*) | el script sale en cuanto un comando falla | seguir trabajando después de un error |
| `-u` (*nounset*) | usar una variable que no existe es un error | el `$DIRETORIO` vacío de la clase 16 |
| `-o pipefail` | un pipe falla si falla **cualquiera** de sus comandos | el pipe "en verde" de la clase 04 |

Con `-u`, una variable opcional se lee con valor por defecto: `${APP_ENV:-}` vale vacío en lugar de dar error.

### Dónde `set -e` no actúa

`set -e` **no** detiene el script cuando el comando que falla está:
- en la condición de un `if`, un `while` o un `until`;
- a la izquierda de `&&` o de `||`;
- negado con `!`.

Es a propósito: así se manejan los fallos que **esperas**.

```bash
if ! grep -q "^ana:" /etc/passwd; then echo "ana no existe"; fi   # fallo esperado y tratado
N="$(grep -c "zzz" archivo || true)"                             # "no hay coincidencias" no es un error
```

Y tiene dos trampas que conviene conocer:
- `(( contador++ ))` con `contador=0` devuelve 1 (la expresión vale 0, que en aritmética es "falso") y **mata el script**. Usa `contador=$(( contador + 1 ))`.
- `local x=$(comando)` oculta el fallo del comando: el código que ve `set -e` es el de `local`, que siempre funciona. Separa: `local x; x=$(comando)`.

`set -e` es una red de seguridad, no un sustituto de comprobar los errores importantes.

### `trap`: limpiar siempre

```bash
TMP="$(mktemp -d)"                 # crea un directorio temporal con nombre único
trap 'rm -rf "$TMP"' EXIT          # se ejecuta al salir: por éxito, por error o con Ctrl+C
```

### Logs

```bash
log() { echo "$(date '+%F %T') [$1] ${*:2}" >&2; }   # log NIVEL mensaje…
log INFO "empiezo"
log ERROR "no encuentro el archivo"
logger -t mi-script "copia terminada"               # al journal: journalctl -t mi-script
```

`${*:2}` son todos los argumentos desde el segundo, unidos en un texto.

### `shellcheck`

Un analizador estático para scripts de shell: lee el script **sin ejecutarlo** y avisa de errores típicos (comillas que faltan, `cd` sin comprobar, `$(ls)` en un bucle…). Cada aviso tiene un código `SCxxxx` con una explicación en su wiki. Lo instalarás hoy.

### La plantilla

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

`main "$@"` va en la última línea: bash lee todas las funciones antes de ejecutar nada, y el flujo del script queda arriba, a la vista.

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

El `cd` falló, el script siguió y creó el archivo **en la carpeta equivocada**, y encima devolvió 0. Ahora imagina `rm -rf *` en lugar de `touch`. Activa el modo estricto e inténtalo de nuevo:

```bash
sed -i '2i set -euo pipefail' sin-estricto.sh     # inserta la línea en la posición 2
head -3 sin-estricto.sh
rm marca-sin-estricto
./sin-estricto.sh ; echo "código: $?"
ls marca-sin-estricto
```

Se detiene en el `cd`, con código 1, y no crea nada.

### 3. `set -u`

```bash
bash -c 'set -u; DIRECTORIO=/tmp; echo "$DIRETORIO"' ; echo "código: $?"
bash -c 'set -u; echo "modo: ${APP_ENV:-desarrollo}"'
```

`DIRETORIO: variable sin asignar`: la errata de la clase 16 ya no pasa en silencio.

### 4. `pipefail`: el arreglo de la clase 04

```bash
bash -c 'cat /no-existe | wc -l; echo "código: $?"'
bash -c 'set -o pipefail; cat /no-existe | wc -l; echo "código: $?"'
```

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
cd "$DIR"
rm -rf "${DIR:?}"/*
EOF
shellcheck bueno.sh && echo "shellcheck: sin avisos"
```

(No lo ejecutes contra una carpeta que te importe: vacía su contenido.)

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

1. Reescribe `esperar-url.sh` (clase 18) con la plantilla: `set -euo pipefail`, funciones `log`, `die` y `main`, y que `shellcheck` no dé ningún aviso.
2. `limpiar-viejos.sh <carpeta> <días> [--dry-run]`: borra los archivos de la carpeta con más de N días (`find "$DIR" -type f -mtime +"$DIAS" -print -delete`). Valida que la carpeta existe y que los días son un número. Con `--dry-run`, solo lista lo que borraría. Pruébalo en una carpeta de prueba con archivos creados con `touch -d "10 days ago" viejo.txt`.
3. Pasa `shellcheck` a tus scripts de las clases 16 a 18. Arregla al menos tres avisos y apunta en tus notas qué significaba cada código.

## Cierre

En `notas/fase-1/clase-19.md`:

1. Explica qué hace cada parte de `set -euo pipefail` con un ejemplo de lo que evita.
2. Nombra dos situaciones en las que `set -e` no detiene el script. ¿Cómo manejas un fallo que esperas?
3. ¿Para qué sirve `trap '…' EXIT`? Pon un ejemplo real.
4. **Repaso (clase 18, sin mirar):** ¿por qué `cmd | while read …` pierde las variables al terminar?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `-e`: el script se detiene en cuanto un comando falla; evita, por ejemplo, seguir después de un `cd` fallido y borrar en la carpeta equivocada. `-u`: usar una variable que no existe es un error; evita que una errata convierta `"$DIRETORIO"/*` en `/*`. `-o pipefail`: un pipe falla si falla cualquiera de sus partes, no solo la última; evita que `cat archivo-que-no-existe | wc -l` parezca un éxito.

**2.** Cuando el comando está en la condición de un `if`/`while`/`until`, a la izquierda de `&&` o `||`, o negado con `!`. También dentro de una función llamada desde un `if`. Un fallo esperado se maneja precisamente así: `if ! comando; then …` o `comando || true` cuando el fallo no importa, siempre de forma explícita.

**3.** Para ejecutar código de limpieza al salir, termine el script bien, con error o con `Ctrl+C`. Ejemplos: borrar un directorio temporal de `mktemp`, liberar un bloqueo, parar un servidor de pruebas que el script arrancó o desmontar un disco.

**4.** Porque cada lado del pipe corre en un proceso hijo: el `while` cambia su copia de la variable, que desaparece al terminar el pipe. Se arregla con `while …; done < archivo` o `done < <(comando)`.

**Reto 1 (una solución):**
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

**Reto 2 (la parte central):**
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
