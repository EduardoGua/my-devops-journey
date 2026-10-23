#!/bin/bash
# cerrar-clase.sh — cierra una clase de una vez: comprueba la calificación, marca PROGRESO.md,
#                   apunta el tiempo medido en el registro y, si le dices que sí, hace commit y push
# Uso:
#   bash ~/my-devops-journey/recursos/cerrar-clase.sh 06                      (cierra la clase 06)
#   bash ~/my-devops-journey/recursos/cerrar-clase.sh 06 "me costó la pieza 5"  (con una nota para el registro)
#   bash ~/my-devops-journey/recursos/cerrar-clase.sh repaso-a                (cierra el repaso del bloque A)
# El tiempo sale de notas/horas.csv (sesion.sh). Si no mediste ninguna sesión, te lo pregunta.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PROGRESO="$REPO/PROGRESO.md"
CSV="$REPO/notas/horas.csv"
ABIERTA="$REPO/notas/.sesion-abierta"

die() { echo "Error: $*" >&2; exit 1; }
aviso() { echo "⚠ $*" >&2; }

duracion() {
  local m=$1
  if (( m >= 60 )); then echo "$((m / 60)) h $((m % 60)) min"; else echo "$m min"; fi
}

# 1 → "1 sesión" · 3 → "3 sesiones"
sesiones_txt() {
  if (( $1 == 1 )); then echo "1 sesión"; else echo "$1 sesiones"; fi
}

main() {
  local arg="${1:-}" comentario="${2:-}"
  local nombre clase linea_progreso seccion
  shopt -s nullglob

  if [[ $arg =~ ^[0-9]+$ ]]; then
    clase="$(printf '%02d' "$((10#$arg))")"
    nombre="clase-$clase"
    linea_progreso="^- \[ \] $clase · "
    seccion="Cierre"
  elif [[ $arg =~ ^repaso-([a-z])$ ]]; then
    clase="$arg"
    nombre="$arg"
    linea_progreso="^- \[ \] Repaso del bloque ${BASH_REMATCH[1]^^} ·"
    seccion="Preguntas"
  else
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
  fi

  # 1. La nota existe y está calificada
  local notas=("$REPO"/notas/fase-*/"$nombre".md)
  (( ${#notas[@]} == 1 )) || die "no encuentro notas/fase-*/$nombre.md. Créala con: bash recursos/nueva-nota.sh $arg"
  local nota="${notas[0]}"

  # cuántas preguntas tiene la clase (las líneas "N. …" de su sección), para exigir una marca por pregunta
  local origenes n_preguntas=0
  if [[ $clase == repaso-* ]]; then
    origenes=("$REPO"/fase-*/repaso-bloque-"${clase#repaso-}".md)
  else
    origenes=("$REPO"/fase-*/"$nombre"-*.md)
  fi
  if (( ${#origenes[@]} == 1 )); then
    n_preguntas="$(awk -v titulo="## $seccion" '$0 == titulo {dentro = 1; next} /^## / {dentro = 0} dentro && /^[0-9]+\. /' "${origenes[0]}" | wc -l)"
  fi

  local marcas resto
  marcas="$(grep -m1 "^$seccion:" "$nota" || true)"
  resto="${marcas#*:}"
  if [[ $resto =~ ^[[:space:]]*$ ]] && (( n_preguntas == 0 )); then
    :                                                   # la clase no tiene cierre (clase 38): nada que calificar
  elif [[ -z $marcas ]]; then
    die "no encuentro la línea «$seccion: …» en ${nota#"$REPO"/}"
  else
    # cada pregunta, separada por «·», tiene que llevar ✅, 🟡, ❌ o — (omitida)
    if ! awk -F'·' '{for (i = 1; i <= NF; i++) if ($i !~ /✅|🟡|❌|—/) exit 1}' <<< "$resto"; then
      die "falta calificar el $seccion: «$marcas». Escríbeme «examíname $nombre» o usa la autocorrección de la clase"
    fi
    local n_marcas
    n_marcas="$(awk -F'·' '{print NF}' <<< "$resto")"
    if (( n_marcas < n_preguntas )); then
      die "el $seccion tiene $n_preguntas preguntas y veo $n_marcas marcas: «$marcas». Una por pregunta, separadas por «·»"
    fi
  fi
  # el reto solo existe en las clases que lo tienen; si está la línea, tiene que llevar sus marcas
  if grep -q '^Reto:' "$nota" && { grep -q '^Reto: (✅ o ❌ por punto)' "$nota" || ! grep -qE '^Reto:.*(✅|❌)' "$nota"; }; then
    die "falta marcar el reto en ${nota#"$REPO"/} (✅ o ❌ por punto)"
  fi
  if grep -qE '^Práctica final:[[:space:]]*$' "$nota"; then
    die "falta marcar la práctica final en ${nota#"$REPO"/}"
  fi
  # 2. La clase está sin marcar en PROGRESO.md, y el registro existe
  local n_linea titulo ultima
  n_linea="$(grep -n -m1 -E "$linea_progreso" "$PROGRESO" | cut -d: -f1 || true)"
  if [[ -z $n_linea ]]; then
    die "no encuentro «${linea_progreso//\\/}» sin marcar en PROGRESO.md (¿ya estaba cerrada?)"
  fi
  titulo="$(sed -n "${n_linea}p" "$PROGRESO" | sed -E 's/^- \[ \] ([0-9]+ · )?//; s/ ·[[:space:]]*$//')"
  ultima="$(awk '/^## Registro/ {r = 1} r && /^\|/ {n = NR} END {print n + 0}' "$PROGRESO")"
  (( ultima > 0 )) || die "no encuentro la tabla de «## Registro» en PROGRESO.md"

  local flojas
  flojas="$({ grep -E "^($seccion|Reto):" "$nota" || true; } | { grep -oE '🟡|❌' || true; } | wc -l)"
  if (( flojas > 0 )); then
    local correcciones
    correcciones="$(awk '/^Correcciones/ {dentro = 1; sub(/^[^:]*:/, ""); if ($0 ~ /[^ ]/) n++; next} dentro && /[^ ]/ {n++} END {print n + 0}' "$nota")"
    (( correcciones > 0 )) || aviso "tienes $flojas 🟡/❌ y no veo correcciones escritas: sin ellas, cuentan como deuda"
  fi

  # 3. El tiempo: cierra la sesión abierta de esta clase y suma las medidas
  if [[ -f $ABIERTA ]]; then
    local abierta
    read -r abierta _ < "$ABIERTA"
    if [[ $abierta == "$clase" ]]; then
      if ! bash "$REPO/recursos/sesion.sh" terminar; then
        # más de 4 h abierta: sesion.sh no adivina, así que se apuntan los minutos reales
        local reales=""
        [[ -t 0 ]] && { read -rp "¿Cuántos minutos estudiaste de verdad en esa sesión? " reales || reales=""; }
        [[ $reales =~ ^[0-9]+$ ]] || die "cierra la sesión con «sesion.sh terminar <minutos>» y vuelve a ejecutar cerrar-clase.sh"
        bash "$REPO/recursos/sesion.sh" terminar "$reales"
      fi
    else
      aviso "hay una sesión abierta de '$abierta': no la toco"
    fi
  fi
  local minutos=0 sesiones=0 tiempo
  if [[ -f $CSV ]]; then
    minutos="$(awk -F, -v c="$clase" 'NR > 1 && $2 == c {s += $5} END {print s + 0}' "$CSV")"
    sesiones="$(awk -F, -v c="$clase" 'NR > 1 && $2 == c' "$CSV" | wc -l)"
  fi
  if (( minutos > 0 )); then
    tiempo="$(duracion "$minutos") en $(sesiones_txt "$sesiones")"
  elif [[ -t 0 ]]; then
    local respuesta
    read -rp "No hay sesiones medidas de '$clase'. ¿Cuántos minutos le dedicaste? (Enter: sin dato) " respuesta || respuesta=""
    if [[ $respuesta =~ ^[0-9]+$ ]]; then tiempo="$(duracion "$respuesta"), a ojo"; else tiempo="—"; fi
  else
    tiempo="—"
  fi

  # 4. Escribe: el tiempo en la nota (si está vacío), la casilla y la fila del registro
  local hoy
  hoy="$(date +%F)"
  # [[:space:]]* por si el editor quitó el espacio final, y se comprueba antes de seguir
  sed -i -E "${n_linea}s/^- \[ \] (.*) ·[[:space:]]*$/- [x] \1 · $hoy/" "$PROGRESO"
  sed -n "${n_linea}p" "$PROGRESO" | grep -q '^- \[x\]' \
    || die "no pude marcar la línea $n_linea de PROGRESO.md: tiene que terminar en « ·». Revísala y repite"
  sed -i -E "s/^Tiempo:[[:space:]]*$/Tiempo: $tiempo/" "$nota"

  local fila="| $hoy | $clase | $tiempo | ${comentario//|/\/} |"
  FILA="$fila" awk -v n="$ultima" '{print} NR == n {print ENVIRON["FILA"]}' "$PROGRESO" > "$PROGRESO.tmp"
  mv "$PROGRESO.tmp" "$PROGRESO"

  local mensaje="Clase $clase: $titulo"                  # el mismo formato de commit que COMO-ESTUDIAR
  [[ $clase == repaso-* ]] && mensaje="$titulo"
  echo "✔ PROGRESO.md: [x] $titulo · $hoy"
  echo "✔ Registro: $fila"

  # 5. Git: solo si estás delante y dices que sí, y solo los archivos del cierre (nada de git add .)
  cd "$REPO"
  local archivos=("${nota#"$REPO"/}" PROGRESO.md) labs="labs/$nombre"
  [[ -f $CSV ]] && archivos+=("notas/horas.csv")
  echo
  git status --short
  if [[ ! -t 0 ]]; then
    echo "Sin terminal interactiva: no hago commit. Revisa y sube tú: git add ${archivos[*]} && git commit && git push"
    return
  fi
  if [[ -n $(git status --porcelain -- "$labs") ]]; then
    local con_labs
    echo
    git status --short -- "$labs"
    read -rp "¿Subo también $labs/? Revisa que no haya llaves ni contraseñas. [s/N] " con_labs || con_labs=""
    [[ $con_labs =~ ^[sS]$ ]] && archivos+=("$labs")
  fi
  local ok
  read -rp "Subo solo esto: ${archivos[*]}. ¿Hago commit y push? [s/N] " ok || ok=""
  if [[ $ok =~ ^[sS]$ ]]; then
    git add -- "${archivos[@]}"
    if git commit -q -m "$mensaje" -- "${archivos[@]}"; then
      echo "✔ Commit: $mensaje"
      git push -q && echo "✔ Subido a GitHub" || aviso "el push falló: revisa la conexión y repite con git push"
    else
      aviso "el commit falló: no hago push"
    fi
  else
    echo "Sin commit. Cuando quieras: git add ${archivos[*]} && git commit -m \"$mensaje\" && git push"
  fi
}

main "$@"
