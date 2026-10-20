#!/bin/bash
# sesion.sh — mide el tiempo que estudias, sin apuntarlo a ojo
# Uso:
#   bash ~/my-devops-journey/recursos/sesion.sh empezar 06     empieza a contar una sesión de la clase 06
#   bash ~/my-devops-journey/recursos/sesion.sh terminar       la cierra y guarda los minutos
#   bash ~/my-devops-journey/recursos/sesion.sh terminar 40    la cierra con 40 minutos (si olvidaste cerrarla a tiempo)
#   bash ~/my-devops-journey/recursos/sesion.sh cancelar       descarta la sesión abierta, sin guardar nada
#   bash ~/my-devops-journey/recursos/sesion.sh estado         la sesión abierta y tus horas de hoy, 7 días y el mes
#   bash ~/my-devops-journey/recursos/sesion.sh mes [2026-10]  las horas del mes, por clase (para la Ruta)
# Además de números de clase acepta otras etiquetas: repaso-a, vigia, anki, noc-a…
# Las sesiones se guardan en notas/horas.csv: fecha,clase,inicio,fin,minutos
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CSV="$REPO/notas/horas.csv"
ABIERTA="$REPO/notas/.sesion-abierta"        # "clase epoch" mientras hay una sesión en marcha
MAX_MIN=240                                  # más de 4 h seguidas: probablemente olvidaste cerrarla

die() { echo "Error: $*" >&2; exit 1; }

# 125 → "2 h 5 min" · 40 → "40 min"
duracion() {
  local m=$1
  if (( m >= 60 )); then echo "$((m / 60)) h $((m % 60)) min"; else echo "$m min"; fi
}

# 1 → "1 sesión" · 3 → "3 sesiones"
sesiones_txt() {
  if (( $1 == 1 )); then echo "1 sesión"; else echo "$1 sesiones"; fi
}

# 6 → 06 · repaso-a → repaso-a (10# evita que 08 se lea en octal)
etiqueta() {
  local arg=$1
  if [[ $arg =~ ^[0-9]+$ ]]; then
    printf '%02d' "$((10#$arg))"
  elif [[ $arg =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "$arg"
  else
    die "etiqueta no válida: '$arg' (usa un número de clase o algo como repaso-a, vigia, anki)"
  fi
}

# suma los minutos de las filas cuyo campo N cumple la condición de awk
sumar() {
  [[ -f $CSV ]] || { echo 0; return; }
  awk -F, -v filtro="$1" 'NR > 1 && $0 ~ filtro {s += $5} END {print s + 0}' "$CSV"
}

empezar() {
  local clase
  clase="$(etiqueta "${1:-}")"
  if [[ -f $ABIERTA ]]; then
    local abierta inicio
    read -r abierta inicio < "$ABIERTA"
    die "ya hay una sesión abierta de '$abierta' desde las $(date -d "@$inicio" +%H:%M). Ciérrala con: sesion.sh terminar"
  fi
  mkdir -p "$(dirname "$CSV")"
  echo "$clase $(date +%s)" > "$ABIERTA"
  echo "▶ Sesión de '$clase' empezada a las $(date +%H:%M). Al terminar: bash ~/my-devops-journey/recursos/sesion.sh terminar"
}

terminar() {
  [[ -f $ABIERTA ]] || die "no hay ninguna sesión abierta. Empieza una con: sesion.sh empezar <clase>"
  local clase inicio fin minutos
  read -r clase inicio < "$ABIERTA"
  fin="$(date +%s)"
  if [[ -n ${1:-} ]]; then
    [[ $1 =~ ^[0-9]+$ ]] || die "los minutos tienen que ser un número: '$1'"
    minutos=$1
  else
    minutos=$(( (fin - inicio + 30) / 60 ))   # redondeado al minuto
    if (( minutos > MAX_MIN )); then
      die "la sesión lleva $(duracion "$minutos") abierta. Si olvidaste cerrarla, apunta lo que estudiaste de verdad: sesion.sh terminar <minutos>"
    fi
  fi
  [[ -f $CSV ]] || echo "fecha,clase,inicio,fin,minutos" > "$CSV"
  echo "$(date -d "@$inicio" +%F),$clase,$(date -d "@$inicio" +%H:%M),$(date -d "@$fin" +%H:%M),$minutos" >> "$CSV"
  rm -f "$ABIERTA"
  local total sesiones
  total="$(sumar ",$clase,")"
  sesiones="$(awk -F, -v c="$clase" 'NR > 1 && $2 == c' "$CSV" | wc -l)"
  echo "■ Sesión de '$clase': $(duracion "$minutos"). Total de '$clase': $(duracion "$total") en $(sesiones_txt "$sesiones")."
}

cancelar() {
  [[ -f $ABIERTA ]] || die "no hay ninguna sesión abierta"
  rm -f "$ABIERTA"
  echo "Sesión abierta descartada: no se guardó nada."
}

estado() {
  if [[ -f $ABIERTA ]]; then
    local clase inicio
    read -r clase inicio < "$ABIERTA"
    echo "▶ Sesión abierta: '$clase', desde las $(date -d "@$inicio" +%H:%M) ($(duracion $(( ($(date +%s) - inicio) / 60 )))) "
  else
    echo "No hay ninguna sesión abierta."
  fi
  local hoy semana=0 i
  hoy="$(sumar "^$(date +%F),")"
  for i in 0 1 2 3 4 5 6; do
    semana=$(( semana + $(sumar "^$(date -d "-$i days" +%F),") ))
  done
  echo "Hoy: $(duracion "$hoy") · Últimos 7 días: $(duracion "$semana") · Este mes: $(duracion "$(sumar "^$(date +%Y-%m)-")")"
}

mes() {
  local m="${1:-$(date +%Y-%m)}"
  [[ $m =~ ^[0-9]{4}-[0-9]{2}$ ]] || die "el mes va así: 2026-10"
  [[ -f $CSV ]] || die "todavía no hay sesiones guardadas"
  echo "Horas de $m, por clase:"
  awk -F, -v m="$m" 'NR > 1 && index($1, m "-") == 1 {s[$2] += $5; n[$2]++; t += $5}
    END {
      for (c in s) printf "  %-10s %4d min  (%d %s)\n", c, s[c], n[c], (n[c] == 1 ? "sesión" : "sesiones") | "sort"
      close("sort")
      printf "  Total: %d h %d min\n", t / 60, t % 60
    }' "$CSV"
}

main() {
  local orden="${1:-}"
  shift || true
  case $orden in
    empezar)  empezar "$@" ;;
    terminar) terminar "$@" ;;
    cancelar) cancelar ;;
    estado)   estado ;;
    mes)      mes "$@" ;;
    *)        sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
  esac
}

main "$@"
