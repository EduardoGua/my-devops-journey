#!/bin/bash
# sesion.sh — mide el tiempo que estudias, sin apuntarlo a ojo
# Uso:
#   bash ~/my-devops-journey/recursos/sesion.sh empezar 06     empieza a contar una sesión de la clase 06
#   bash ~/my-devops-journey/recursos/sesion.sh terminar       la cierra y guarda los minutos
#   bash ~/my-devops-journey/recursos/sesion.sh terminar 40    la cierra con 40 minutos (si olvidaste cerrarla a tiempo)
#   bash ~/my-devops-journey/recursos/sesion.sh cancelar       descarta la sesión abierta, sin guardar nada
#   bash ~/my-devops-journey/recursos/sesion.sh estado         la sesión abierta y tus horas de hoy, 7 días y el mes
#   bash ~/my-devops-journey/recursos/sesion.sh hoy            resumen de fase, clase de hoy, deudas y próximo compromiso
#   bash ~/my-devops-journey/recursos/sesion.sh calentamiento [N]  elige N preguntas de cierres anteriores (repaso espaciado)
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

# 6 → 06 · clase-06 → 06 · repaso-a → repaso-a (10# evita que 08 se lea en octal)
etiqueta() {
  local arg=${1#clase-}                        # cerrar-clase.sh suma por número
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
    minutos=$((10#$1))                         # 040 → 40, no 32 (octal)
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

hoy() {
  python3 - "$REPO" <<'PY'
import glob, os, re, sys
repo = sys.argv[1]
progreso = open(os.path.join(repo, "PROGRESO.md"), encoding="utf-8").read()

fase_actual = None
hechos = total = 0
paso_hoy = None
en_criterios = False
fases = []

for linea in progreso.splitlines():
    if m := re.match(r"^## (Fase [^\n]+)", linea):
        if fase_actual:
            fases.append((fase_actual, hechos, total, paso_hoy))
        fase_actual = m.group(1).replace(" — ", " · ")
        hechos = total = 0
        paso_hoy = None
        en_criterios = False
    elif linea.startswith("### Criterios de salida") or linea.startswith("### La prueba"):
        en_criterios = True
    elif linea.startswith("### "):
        en_criterios = False
    elif fase_actual and not en_criterios:
        if m := re.match(r"^- \[([ xX])\] (.+?)(?: ·(?:\s*\d{4}-\d{2}-\d{2})?\s*)?$", linea):
            total += 1
            if m.group(1).strip():
                hechos += 1
            elif paso_hoy is None:
                paso_hoy = m.group(2).strip()
if fase_actual:
    fases.append((fase_actual, hechos, total, paso_hoy))

actual = next(((f, h, t, p) for f, h, t, p in fases if p is not None), None)
print("# Estado actual del curso (PROGRESO.md)")
if not actual:
    print("- Todas las fases están completadas.")
    sys.exit(0)

f_titulo, h, t, paso = actual
print(f"- Fase actual: {f_titulo} ({h} de {t} pasos completados).")
if ("Fase NOC" in f_titulo or "Fase 4" in f_titulo) and h == 0:
    print("- 📌 Recordatorio: al cerrar la Fase 3 / antes de empezar la Fase 4, lanza con subagentes la auditoría línea por línea de las clases intermedias de las Fases 4 a 10.")
if m := re.match(r"^(\d+) · ", paso):
    num = m.group(1)
    archivos = glob.glob(os.path.join(repo, f"fase-*/clase-{num}-*.md"))
    notas = glob.glob(os.path.join(repo, f"notas/fase-*/clase-{num}.md"))
    labs = glob.glob(os.path.join(repo, f"labs/clase-{num}/*"))
    arch_str = f" Archivo: `{os.path.relpath(archivos[0], repo)}`." if archivos else ""
    nota_str = f" Nota: `{os.path.relpath(notas[0], repo)}`." if notas else f" Nota aún no creada (`bash recursos/nueva-nota.sh {num}`)."
    lab_str = f" (Ya hay {len(labs)} elementos en `labs/clase-{num}/`)." if labs else ""
    print(f"- Clase de hoy: {paso}.{arch_str}{nota_str}{lab_str}")
else:
    print(f"- Paso de hoy: {paso}.")

deudas = []
for ruta in sorted(glob.glob(os.path.join(repo, "notas/fase-*/*.md"))):
    txt = open(ruta, encoding="utf-8").read()
    flojas = sum(len(re.findall(r"[🟡❌]", l)) for l in txt.splitlines() if re.match(r"^(Cierre|Reto|Preguntas):", l))
    corr = sum(1 for l in txt.splitlines() if re.match(r"^Correcci[oó]n(?!es)", l, re.I))
    n = max(0, flojas - corr)
    if n > 0:
        deudas.append((os.path.relpath(ruta, repo), n))

total_deudas = sum(n for _, n in deudas)
if total_deudas == 0:
    print("- Deudas abiertas: ninguna (máximo 2).")
else:
    detalle = ", ".join(f"{r}: {n}" for r, n in deudas)
    print(f"- Deudas abiertas: {total_deudas} ({detalle}). Con 2 deudas no se empieza clase nueva.")
PY
  estado
}

calentamiento() {
  local cuantas="${1:-3}"
  python3 - "$REPO" "$cuantas" <<'PY'
import datetime, glob, json, os, re, sys

repo = sys.argv[1]
cuantas = int(sys.argv[2])
hoy_str = datetime.date.today().isoformat()
store_path = os.path.join(repo, "notas", ".calentamiento.json")
vistos = json.loads(open(store_path, encoding="utf-8").read()) if os.path.exists(store_path) else {}

progreso = open(os.path.join(repo, "PROGRESO.md"), encoding="utf-8").read()
fechas_cierre = {
    f"clase-{m.group(1)}": m.group(2)
    for m in re.finditer(r"^- \[[xX]\] (\d+) · .* · (\d{4}-\d{2}-\d{2})\s*$", progreso, re.M)
}

for nota_path in sorted(glob.glob(os.path.join(repo, "notas/fase-*/clase-*.md"))):
    clase = os.path.splitext(os.path.basename(nota_path))[0]
    txt = open(nota_path, encoding="utf-8").read()
    m_fecha = re.search(r"^Fecha:\s*(\d{4}-\d{2}-\d{2})", txt, re.M)
    fecha = (m_fecha.group(1) if m_fecha else None) or fechas_cierre.get(clase, hoy_str)
    linea_cierre = next((l for l in txt.splitlines() if l.startswith("Cierre:")), "")
    for m_cal in re.finditer(r"(\d+)\s*(✅|🟡|❌)", linea_cierre):
        clave = f"{clase}#{m_cal.group(1)}"
        if clave not in vistos:
            nota_cal = m_cal.group(2)
            vistos[clave] = {"ultima": fecha, "nota": nota_cal, "racha": 1 if nota_cal == "✅" else 0}

os.makedirs(os.path.dirname(store_path), exist_ok=True)
with open(store_path, "w", encoding="utf-8") as f:
    json.dump(vistos, f, ensure_ascii=False, indent=2)

def seccion(texto, titulo):
    lineas = texto.splitlines()
    try:
        ini = next(i for i, l in enumerate(lineas) if l.strip() == f"## {titulo}")
    except StopIteration:
        return []
    fin = next((i for i in range(ini + 1, len(lineas)) if lineas[i].startswith("## ")), len(lineas))
    return lineas[ini + 1:fin]

preguntas = []
for clase_path in sorted(glob.glob(os.path.join(repo, "fase-*/clase-*.md"))):
    m_c = re.match(r"^(clase-\d+)-", os.path.basename(clase_path))
    if not m_c:
        continue
    clase = m_c.group(1)
    txt = open(clase_path, encoding="utf-8").read()
    respuestas = {}
    actual = None
    for l in seccion(txt, "Autocorrección"):
        if m_r := re.match(r"^\*\*(\d+)\.\*\*\s*(.*)$", l):
            actual = int(m_r.group(1))
            respuestas[actual] = [m_r.group(2)]
        elif actual is not None and l.strip() and not re.match(r"^(\*\*|</details>|```)", l.strip()):
            respuestas[actual].append(l.strip())
        else:
            actual = None
    for l in seccion(txt, "Cierre"):
        m_p = re.match(r"^(\d+)\.\s+(.+)$", l)
        if not m_p or "Solo para leer" in m_p.group(2):
            continue
        num = int(m_p.group(1))
        resp = " ".join(respuestas.get(num, [])).strip()
        if not resp:
            continue
        limpia = re.sub(r"\s*\*\(.*\)\*\s*$", "", m_p.group(2))
        limpia = re.sub(r"^\*\*Repaso \(([^)]*?),? sin mirar\):\*\*\s*", r"Repaso de la \1: ", limpia)
        clave = f"{clase}#{num}"
        if clave in vistos:
            preguntas.append({"clave": clave, "clase": clase, "texto": limpia, "respuesta": resp})

espera_acertada = [2, 4, 8, 16, 32]
peso = {"❌": 2, "🟡": 1, "✅": 0}
hoy_dt = datetime.date.fromisoformat(hoy_str)

def atraso(v):
    esp = 0 if v["nota"] == "❌" else (1 if v["nota"] == "🟡" else espera_acertada[min(max(v.get("racha", 1), 1), len(espera_acertada)) - 1])
    dias = (hoy_dt - datetime.date.fromisoformat(v["ultima"])).days
    return dias - esp

ordenadas = sorted(
    preguntas,
    key=lambda p: (-atraso(vistos[p["clave"]]), -peso[vistos[p["clave"]]["nota"]], p["clave"]),
)
elegidas = []
for p in ordenadas:
    if len(elegidas) < cuantas and all(e["clase"] != p["clase"] for e in elegidas):
        elegidas.append(p)
for p in ordenadas:
    if len(elegidas) < cuantas and p not in elegidas:
        elegidas.append(p)

for i, p in enumerate(elegidas, 1):
    v = vistos[p["clave"]]
    print(f"{i}. [{p['clave']}] (última: {v['ultima']} {v['nota']}, racha: {v.get('racha', 0)})")
    print(f"   Pregunta: {p['texto']}")
    print(f"   Referencia: {p['respuesta']}\n")
PY
}

anotar_calentamiento() {
  local clave="${1:-}" nota="${2:-}"
  [[ -n $clave && $nota =~ ^(✅|🟡|❌)$ ]] || die "Uso: sesion.sh anotar-calentamiento <clase-NN#N> <✅|🟡|❌>"
  python3 - "$REPO" "$clave" "$nota" <<'PY'
import datetime, json, os, sys
repo, clave, nota = sys.argv[1], sys.argv[2], sys.argv[3]
store_path = os.path.join(repo, "notas", ".calentamiento.json")
vistos = json.loads(open(store_path, encoding="utf-8").read()) if os.path.exists(store_path) else {}
antes = vistos.get(clave, {})
racha = (antes.get("racha", 0) + 1 if antes.get("nota") == "✅" else 1) if nota == "✅" else 0
vistos[clave] = {"ultima": datetime.date.today().isoformat(), "nota": nota, "racha": racha}
os.makedirs(os.path.dirname(store_path), exist_ok=True)
with open(store_path, "w", encoding="utf-8") as f:
    json.dump(vistos, f, ensure_ascii=False, indent=2)
print(f"✔ Anotado {clave}: {nota} (racha: {racha})")
PY
}

main() {
  local orden="${1:-}"
  shift || true
  case $orden in
    empezar)              empezar "$@" ;;
    terminar)             terminar "$@" ;;
    cancelar)             cancelar ;;
    estado)               estado ;;
    hoy)                  hoy ;;
    calentamiento)        calentamiento "$@" ;;
    anotar-calentamiento) anotar_calentamiento "$@" ;;
    mes)                  mes "$@" ;;
    *)                    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
  esac
}

main "$@"
