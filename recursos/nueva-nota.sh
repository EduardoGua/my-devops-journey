#!/bin/bash
# nueva-nota.sh — crea tu archivo de notas de una clase con las preguntas del cierre ya copiadas
# Uso: bash ~/my-devops-journey/recursos/nueva-nota.sh <número de clase>     (ejemplo: 04)
#      bash ~/my-devops-journey/recursos/nueva-nota.sh repaso-a              (repaso del bloque A)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

die() { echo "Error: $*" >&2; exit 1; }

main() {
  local arg="${1:-}" nombre seccion extra
  shopt -s nullglob
  local origenes=()

  if [[ $arg =~ ^[0-9]+$ ]]; then                 # una clase: fase-*/clase-NN-*.md
    nombre="clase-$(printf '%02d' "$((10#$arg))")" # 4 → 04 (10# evita que 08 se lea en octal)
    origenes=("$REPO"/fase-*/"$nombre"-*.md)
    seccion="Cierre"
    extra=""                                       # el reto se hace en la terminal: solo su marca
  elif [[ $arg =~ ^repaso-([a-z])$ ]]; then       # un repaso: fase-*/repaso-bloque-X.md
    nombre="$arg"
    origenes=("$REPO"/fase-*/repaso-bloque-"${BASH_REMATCH[1]}".md)
    seccion="Preguntas"
    extra=""                                       # solo si el repaso tiene "## Práctica final"
  else
    echo "Uso: $0 <número de clase, por ejemplo 04>   o   $0 repaso-a" >&2
    exit 2
  fi

  (( ${#origenes[@]} == 1 )) || die "no encuentro '$arg' en $REPO"
  local origen="${origenes[0]}"
  if [[ $seccion == Preguntas ]] && grep -q '^## Práctica final' "$origen"; then
    extra="Práctica final"
  fi

  local fase nota
  fase="$(basename "$(dirname "$origen")")"
  nota="$REPO/notas/$fase/$nombre.md"
  [[ -e $nota ]] && die "ya existe $nota: no lo toco"
  mkdir -p "$(dirname "$nota")"

  # Las preguntas son las líneas "N. …" entre "## <sección>" y la sección siguiente
  local preguntas
  preguntas="$(awk -v titulo="## $seccion" '$0 == titulo {dentro = 1; next} /^## / {dentro = 0} dentro && /^[0-9]+\. /' "$origen")"

  {
    head -1 "$origen"                             # el título de la clase o del repaso
    echo "Fecha: $(date +%F)"
    echo "Tiempo: "
    echo
    echo "## $seccion"
    echo
    if [[ -n $preguntas ]]; then
      while IFS= read -r pregunta; do
        echo "> $pregunta"
        echo
        echo
      done <<< "$preguntas"
    fi
    if [[ -n $extra ]]; then
      echo "## $extra"
      echo
      echo
    fi
    echo "## Autocorrección"
    echo
    echo "Lo más dinámico: escríbele a Claude «examíname $nombre». O califica tú con la autocorrección de la clase:"
    echo "✅ la idea clave con tus palabras · 🟡 a medias o sin el porqué · ❌ incorrecta"
    echo
    echo "$seccion: $(cut -d. -f1 <<< "$preguntas" | paste -sd' ' | sed 's/ / · /g')"
    if [[ -n $extra ]]; then
      echo "$extra: "
    elif [[ $seccion == Cierre ]]; then
      echo "Reto: (✅ o ❌ por punto)"
    fi
    echo
    echo "Correcciones (una por cada 🟡 o ❌, con tus palabras, sin copiar la clase):"
    echo
  } > "$nota"

  echo "Creado: ${nota#"$REPO"/}"
  echo "Ábrelo con:  code $nota"
  echo "Cuando esté calificado:  bash $REPO/recursos/cerrar-clase.sh ${nombre#clase-}"
}

main "$@"
