# Clase 21 — Proyecto: Vigía v0

**Dónde:** tu Ubuntu · **Tiempo:** 2 bloques largos (unas 4–6 h) · **Bloque:** D. Proyecto · **Proyecto de portafolio**

## Qué es Vigía

**Vigía** es un monitor de disponibilidad de sitios web: revisa una lista de URLs cada pocos minutos, guarda si respondieron y cuánto tardaron, y avisa cuando algo se cae. Es tu proyecto de portafolio y **crece en cada fase** de la Ruta 2.0:

| Versión | Fase | Qué le añades |
|---------|------|---------------|
| **v0** | 1 · Linux y Bash | script de Bash + cron (hoy) |
| v0.1 | 2 · Git | repo en GitHub, ramas y pull requests |
| v0.2 | 3 · Redes | mide el DNS y el vencimiento del certificado TLS |
| v1 | 4 · Python | reescritura en Python, SQLite, API mínima y pruebas |
| v2 | 5 · Docker | Dockerfile y `docker compose` |
| v3 | 6 · AWS | despliegue en EC2, S3 y CloudWatch |
| v4 | 7 · CI/CD | pipeline de GitHub Actions |
| v5 | 8 · Terraform | toda la infraestructura en código |
| v6 | 9 · Kubernetes | Deployment y CronJob en kind |
| v7 | 10 · Observabilidad | métricas, Prometheus, Grafana y alertas |

Al final tendrás **una** pieza de portafolio completa que muestra el ciclo DevOps entero, en lugar de diez ejercicios sueltos.

**La regla del proyecto:** cada versión se cierra con un commit etiquetado (`v0`, `v0.1`…) y una nota corta en el README sobre **qué se rompió y cómo lo diagnosticaste**. Esa nota muestra cómo piensas cuando algo falla, y es material directo para entrevistas.

## Objetivo de la v0

Un script `vigia.sh` que lee una lista de URLs, prueba cada una con `curl` (código HTTP y tiempo de respuesta), escribe una línea por URL en un log y se ejecuta solo, con cron, cada 5 minutos.

## Requisitos

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Repo propio en `~/vigia`, **fuera** del repo del curso, con Git desde el primer commit | receta de `COMO-ESTUDIAR` |
| R2 | `vigia.sh` empieza con `set -euo pipefail` y `shellcheck` no da ningún aviso | 19 |
| R3 | Lee las URLs de `urls.txt` (junto al script) o del archivo que reciba como argumento. Ignora líneas vacías y comentarios `#` | 16, 18 |
| R4 | Por cada URL escribe **una** línea: `fecha url código tiempo estado`. Ejemplo: `2026-10-20T21:05:01-05:00 https://example.com 200 0.261431 UP` | 16, 17 |
| R5 | `UP` si el código es 2xx o 3xx; `DOWN` en cualquier otro caso, `000` incluido. **Una URL caída no detiene el script**: revisa todas | 17, 19 |
| R6 | Ninguna petición espera más de 10 segundos | 17 |
| R7 | El log va a `$VIGIA_LOG` o, si no está definida, a `~/vigia.log` (fuera del repo) | 07, 16 |
| R8 | Sale con 0 si todas están `UP` y con 1 si alguna está `DOWN`. Con 2 si no puede leer la lista | 17 |
| R9 | Cron lo ejecuta cada 5 minutos con rutas absolutas, y funciona igual desde cron que desde tu terminal | 20 |
| R10 | `README.md` en **inglés**: qué hace, cómo se ejecuta, tu `crontab -l`, un extracto del log y la sección *What broke and how I found it* | — |
| R11 | Commits pequeños y una etiqueta `v0` al terminar | receta |

La fecha en formato ISO 8601 la da `date -Is`. El tiempo, tal cual lo escribe `curl` (segundos con decimales).

## Plan de trabajo

**Bloque 1 (2–3 h):** R1 a R6. Repo, lista de URLs y un script que revisa cada URL y escribe su línea en el log.
**Bloque 2 (2–3 h):** R7 a R11. Código de salida, robustez (Rómpelo), cron, README y etiqueta.

Trabaja en pasos pequeños y haz commit cada vez que algo funcione. Si te atascas más de 30 minutos, abre **una** pista.

### Para empezar

```bash
mkdir -p ~/vigia && cd ~/vigia
git init -b main
cat > urls.txt <<'EOF'
# Sitios que vigila Vigía (uno por línea)
https://example.com
https://www.wikipedia.org
https://github.com
EOF
git add urls.txt && git commit -m "Add initial list of URLs to monitor"
```

Añade a la lista 2–3 sitios que te importen de verdad. Los mensajes de commit de Vigía van en inglés: es tu proyecto público.

Todavía no lo subes a GitHub. Eso es la v0.1 (clase 25), cuando ya sepas trabajar con ramas y pull requests.

## Pistas

<details><summary>Pista 1 — código y tiempo en una sola llamada</summary>

```bash
curl -s -o /dev/null -w '%{http_code} %{time_total}' --max-time 10 "$URL"
```
Imprime algo como `200 0.261431`. Para separar los dos valores: `read -r CODIGO TIEMPO <<< "$RESULTADO"`. El `<<<` (*here-string*) pasa el texto de la variable a `read` como si fuera un archivo de una línea.
</details>

<details><summary>Pista 2 — el script muere en la primera URL caída</summary>

Con `set -e`, cuando `curl` no puede conectar devuelve un código distinto de 0 (6 si el nombre no resuelve, 28 si se agota el tiempo) y el script termina ahí. Pero un sitio caído no es un error de **tu** script: es justo lo que quieres medir. Repasa en la clase 19 dónde `set -e` no actúa. Si escribes `RESULTADO="$(curl …)" || true`, guardas igualmente el `000` que imprime curl.
</details>

<details><summary>Pista 3 — contar las caídas sin morir</summary>

Escribe una función `revisar <url>` que escriba la línea en el log y devuelva 1 si la URL está caída. Llámala con `revisar "$URL" || CAIDAS=$(( CAIDAS + 1 ))`: el `||` evita que `set -e` actúe. Y recuerda la trampa de `(( CAIDAS++ ))` de la clase 19.
</details>

<details><summary>Pista 4 — funciona en mi terminal pero no desde cron</summary>

Repasa la tabla del entorno de cron de la clase 20. Usa la ruta absoluta del script en el crontab, y dentro del script calcula su propia carpeta para encontrar `urls.txt`:
```bash
DIR="$(cd "$(dirname "$0")" && pwd)"
URLS="${1:-$DIR/urls.txt}"
```
</details>

<details><summary>Pista 5 — si quieres hacer cuentas con los tiempos</summary>

La v0 no lo necesita, pero si calculas medias con `awk`, ojo: tu Ubuntu está en español, y `awk` lee `0.261` como `0` porque espera una coma decimal. Pruébalo: `echo 0.261 | awk '{print $1 * 1000}'` frente a `echo 0.261 | LC_ALL=C awk '{print $1 * 1000}'`. En scripts que hacen cuentas con decimales, usa `LC_ALL=C`.
</details>

## Rómpelo: pruébalo antes de darlo por bueno

Un monitor que solo has probado con sitios sanos no está probado. Crea una lista de prueba con todos los casos difíciles y ejecútala con un log aparte:

```bash
cat > /tmp/urls-dificiles.txt <<'EOF'
# casos difíciles
https://example.com
https://no-existe.invalid
https://example.com/no-existe
http://192.0.2.1
   https://www.wikipedia.org   
EOF
printf 'https://github.com' >> /tmp/urls-dificiles.txt
time VIGIA_LOG=/tmp/prueba.log ./vigia.sh /tmp/urls-dificiles.txt ; echo "código: $?"
cat /tmp/prueba.log
```

🔮 **Predice** antes de ejecutar: qué línea saldrá para cada URL, cuánto tardará en total y qué código devolverá.

| URL | Qué simula | Debe salir |
|-----|------------|------------|
| `no-existe.invalid` | un nombre que no existe (`.invalid` está reservado para eso) | `000 … DOWN` al instante |
| `example.com/no-existe` | una página que no existe | `404 … DOWN` |
| `192.0.2.1` | una IP reservada para documentación: nadie responde | `000 … DOWN` a los 10 s |
| Wikipedia con espacios | un archivo editado a mano | `200 … UP`, sin los espacios en el log |
| `github.com` sin salto final | la última línea sin `\n` | revisada igual |

Y además:
1. Sin argumento y sin `urls.txt`, o con un archivo que no existe: un mensaje claro y código 2.
2. Desde **otra carpeta** (`cd /tmp && ~/vigia/vigia.sh`): debe encontrar su `urls.txt`.
3. Suspende el portátil 15 minutos con Vigía en cron y mira el log después: verás un **hueco**. Cron no ejecuta lo que se perdió. Es una limitación real de la v0: anótala en el README.

## Programarlo

```bash
crontab -l > ~/crontab.respaldo 2>/dev/null
crontab -e
```

```
# Vigía v0: revisa mis sitios cada 5 minutos
*/5 * * * * /home/educo/vigia/vigia.sh >> /home/educo/logs/vigia-cron.log 2>&1
```

El log de **resultados** lo escribe el propio script en `~/vigia.log`. `vigia-cron.log` recoge cualquier error del script (debería quedar vacío). Comprueba las tres cosas: `journalctl -u cron`, `~/vigia.log` y `~/logs/vigia-cron.log`.

Para pararlo más adelante: `crontab -e` y pon un `#` delante de la línea.

## Entregable

`~/vigia/`:
- `vigia.sh`: ejecutable, `set -euo pipefail` y `shellcheck` sin avisos.
- `urls.txt`: tus sitios.
- `README.md` en inglés, con esta estructura:

````markdown
# Vigía

A small uptime monitor. It checks a list of URLs every 5 minutes and logs
the HTTP status code and response time of each one.

> **v0 — Bash + cron.** Part of my Cloud & DevOps learning path: each version adds
> a layer (Python, Docker, AWS, CI/CD, Terraform, Kubernetes, observability).

## How it works
(3–4 lines in your own words, and the log format: `timestamp url status_code seconds UP|DOWN`)

## Run it
```bash
./vigia.sh                               # uses urls.txt next to the script
VIGIA_LOG=/tmp/test.log ./vigia.sh other-urls.txt
```
Exit codes: 0 all up · 1 at least one site down · 2 cannot read the URL list.

## Schedule it
(your `crontab -l` line)

## Sample log
(8–10 real lines from your log, including at least one DOWN)

## What broke and how I found it
(3–6 lines: the symptom, how you diagnosed it, the fix. For example: the script
stopped at the first unreachable site because of `set -e`; `bash -x` showed curl
returning 6…)

## Limitations
(what v0 can't do yet: only runs while my laptop is on, the log grows forever,
nobody gets notified…)
````

Cierra la versión:

```bash
git add . && git commit -m "Add Vigia v0: Bash uptime checks with cron"
git tag -a v0 -m "v0: Bash + cron"
git log --oneline --decorate
```

Una **etiqueta** (*tag*) es un nombre fijo para un commit: la rama `main` avanzará, pero `v0` siempre señalará esta versión. Las verás a fondo en la clase 25.

## Cierre

En `notas/fase-1/clase-21.md`:

1. ¿Qué hace tu script cuando una URL no resuelve? ¿Por qué no se detiene, a pesar de `set -e`?
2. ¿Qué diferencia hay entre "el script terminó bien" y "todos los sitios están bien"? ¿Cómo lo refleja tu código de salida?
3. Nombra tres limitaciones de la v0 y qué versión futura de Vigía resuelve cada una (mira la tabla del principio).
4. **Repaso (clase 20, sin mirar):** ¿por qué un `%` puede romper una línea de crontab sin dejar rastro en tu log?

## Autocorrección

<details>
<summary>Ábrelo solo cuando tu versión funcione y hayas hecho el Rómpelo</summary>

**Comprueba tu entrega:**
- [ ] `shellcheck vigia.sh` no dice nada.
- [ ] Con la lista difícil: 3 `UP` y 3 `DOWN`, unos 12 s en total, código 1.
- [ ] Con una lista de sitios sanos, código 0.
- [ ] Desde `/tmp` encuentra su `urls.txt`. Con un archivo inexistente, código 2.
- [ ] `journalctl -u cron` muestra una ejecución cada 5 minutos, `~/vigia.log` crece y `vigia-cron.log` está vacío.
- [ ] El README tiene las seis secciones, y la de *What broke* cuenta algo que te pasó de verdad.
- [ ] `git tag` muestra `v0`.

**Una solución de referencia** (la tuya puede ser distinta y estar igual de bien):
```bash
#!/bin/bash
# vigia.sh — revisa una lista de URLs y registra código HTTP, tiempo y estado
# Uso: vigia.sh [archivo-de-urls]     (por defecto, urls.txt junto al script)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
URLS="${1:-$DIR/urls.txt}"
LOG="${VIGIA_LOG:-$HOME/vigia.log}"
TIMEOUT=10

revisar() {   # revisar <url> → escribe una línea en el log; devuelve 1 si está caída
  local url="$1" resultado codigo tiempo estado
  resultado="$(curl -s -o /dev/null -w '%{http_code} %{time_total}' --max-time "$TIMEOUT" "$url")" || true
  read -r codigo tiempo <<< "$resultado"
  if [[ $codigo == [23]* ]]; then estado=UP; else estado=DOWN; fi
  echo "$(date -Is) $url $codigo $tiempo $estado" >> "$LOG"
  [[ $estado == UP ]]
}

main() {
  [[ -r $URLS ]] || { echo "Error: no puedo leer $URLS" >&2; exit 2; }
  local url caidas=0
  while read -r url || [[ -n $url ]]; do
    [[ -z $url || $url == \#* ]] && continue
    revisar "$url" || caidas=$((caidas + 1))
  done < "$URLS"
  (( caidas == 0 ))
}

main "$@"
```
Probado en Ubuntu 26.04 con la lista difícil: 3 `UP`, 3 `DOWN`, código 1, unos 12 s (los 10 s de `192.0.2.1` más el resto).

**Cierre:**
1. `curl` no recibe respuesta, imprime `000` y devuelve un código de error (6). El `|| true` hace que ese fallo no active `set -e`, así que la línea se escribe con `000 … DOWN`. La función devuelve 1, y la llamada `revisar … || caidas=…` está a la izquierda de un `||`, donde `set -e` tampoco actúa.
2. Que el script termine bien significa que hizo su trabajo: leyó la lista y revisó todo. Que los sitios estén bien es el **resultado** de ese trabajo. Por eso hay tres códigos: 0 (todo arriba), 1 (alguno caído: el script funcionó, pero hay un problema que avisar) y 2 (el propio script no pudo trabajar).
3. Por ejemplo: solo corre con el portátil encendido (v3, en AWS); el log crece sin límite y es texto plano (v1, con SQLite); no avisa a nadie (v7, con alertas); revisar más sitios en paralelo o en más máquinas (v6, en Kubernetes); el tiempo total mezcla DNS, conexión y TLS (v0.2 empieza a separarlos).
4. Cron convierte el `%` en un salto de línea y corta el comando ahí: la redirección `>> log` queda en la parte cortada y nunca se ejecuta. El error va a la salida del trabajo, que cron descarta porque no hay correo configurado. Solo queda la línea `CMD (…)` truncada en `journalctl -u cron`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| uptime / availability | disponibilidad |
| response time / latency | tiempo de respuesta / latencia |
| status code | código de estado HTTP |
| uptime monitor | monitor de disponibilidad |
| release tag | etiqueta de versión |

🎙️ *"I built a small uptime monitor in Bash. It reads a list of URLs, records each status code and response time with curl, runs every five minutes from cron, and exits non-zero when any site is down."*

## Al terminar la fase 1

1. Marca la clase 21 y Vigía v0 en [`PROGRESO.md`](../PROGRESO.md).
2. Revisa los **criterios de salida de la fase 1** en `PROGRESO.md` y márcalos solo si los cumples **sin mirar**.
3. Anota tus horas del mes en el registro mensual de la Ruta 2.0.

## Siguiente

[Fase 2 — Clase 22: Git por dentro](../fase-2/clase-22-git-por-dentro.md)
