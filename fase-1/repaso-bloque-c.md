# Repaso del bloque C — Scripting con Bash

**Dónde:** tus notas y, para la práctica final, tu Ubuntu · **Tiempo:** 50 min · **Cuándo:** después de la clase 20 y antes de Vigía v0

> 💡 **Por qué este repaso:** Vigía v0 junta todo el bloque C. Recordar sin mirar justo antes del proyecto te dice qué piezas tienes firmes y cuáles tendrás que buscar. La práctica final es un script pequeño escrito desde cero: el mismo músculo que usarás en Vigía y en una prueba técnica.

## Cómo hacerlo

1. Crea tu archivo: `bash ~/my-devops-journey/recursos/nueva-nota.sh repaso-c`.
2. Responde **sin mirar** clases ni notas, en 25 minutos como máximo. Las preguntas con 💻 compruébalas después en la terminal.
3. Haz la práctica final, también sin mirar (15 minutos).
4. Corrige con la autocorrección y califica cada una (✅ 🟡 ❌).
5. Cada 🟡 o ❌ es una tarjeta de Anki y 10 minutos de vuelta a la clase que indica la respuesta.

## Preguntas

1. ¿Qué diferencia hay entre `./script.sh`, `bash script.sh` y `source script.sh`? ¿Cuál puede cambiar las variables de tu shell?
2. 💻 Con `F=informe.final.tar.gz`, ¿qué imprimen `"${F%%.*}"`, `"${F%.*}"` y `"${F#*.}"`?
3. Escribe las dos líneas que van al principio de un script que exige **exactamente un** argumento y que ese argumento sea un directorio existente. Debe salir con 2 si falta el argumento y con 1 si no es un directorio.
4. 💻 ¿Qué imprime `[[ 10 < 9 ]] && echo sí || echo no`? ¿Y `(( 10 < 9 )) && echo sí || echo no`?
5. 💻 Este código imprime `0` aunque `lista.txt` tiene 5 líneas. Explica el fallo y arréglalo: `N=0; cat lista.txt | while read -r L; do N=$((N + 1)); done; echo $N`
6. Escribe un bucle que reintente `curl -fs -o /dev/null http://localhost:8080` hasta 5 veces, con 2 segundos entre intentos, y que salga con 1 si nunca responde.
7. Con `set -e`, ¿por qué el script muere en `(( i++ ))` cuando `i` vale 0? ¿Qué escribes en su lugar?
8. ¿Qué hace `trap 'rm -rf "$TMP"' EXIT` y cuándo se ejecuta? Da un caso real.
9. Escribe la línea de crontab que ejecute cada día a las 2:30 `/home/educo/bin/limpiar.sh` y guarde su salida y sus errores en `/home/educo/logs/limpiar.log`.
10. Un script usa `aws`, instalado en `~/.local/bin`. En tu terminal funciona, pero desde cron el log dice que no encuentra `aws`. ¿Por qué, y cómo lo arreglas?
11. **(Bloque B)** ¿Cuándo elegirías un timer de systemd en lugar de cron? Da dos razones.
12. **(Bloque A)** `./vigia.sh` responde `Permiso denegado`, pero `bash vigia.sh` funciona. ¿Por qué? ¿Qué arreglo es el correcto pensando en cron?

## Práctica final 💻

Sin mirar, escribe `alerta-disco.sh [límite]` en `~/my-devops-journey/labs/repaso-c/`:
- Si el uso del disco `/` supera el límite (80 por defecto), escribe un aviso en **stderr** y sale con **1**.
- Si no, imprime `OK` con el porcentaje y sale con **0**.
- Si el límite no es un número, muestra el uso y sale con **2**.
- Empieza con `set -euo pipefail` y `shellcheck` no da avisos.

Pista, solo si te atascas más de 5 minutos: `df --output=pcent /` da el porcentaje con una cabecera, y `tr -dc '0-9'` deja solo los dígitos.

Pruébalo con `./alerta-disco.sh 99`, `./alerta-disco.sh 1` y `./alerta-disco.sh abc`, y mira el código de salida de cada uno.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `./script.sh` necesita el permiso `x`, usa el shebang y corre en un proceso hijo. `bash script.sh` no necesita `x`, ignora el shebang y también corre en un hijo. `source script.sh` lo ejecuta **en tu shell actual**: es el único que puede cambiar tus variables. *(Clases 07 y 16.)*

**2.** `informe` · `informe.final.tar` · `final.tar.gz`. `%%` quita por la derecha lo más largo, `%` lo más corto y `#` quita por la izquierda lo más corto. *(Clase 16.)*

**3.**
```bash
[[ $# -eq 1 ]] || { echo "Uso: $0 <carpeta>" >&2; exit 2; }
[[ -d $1 ]]    || { echo "Error: '$1' no es un directorio" >&2; exit 1; }
```
*(Clase 17.)*

**4.** `sí` y `no`. Dentro de `[[ ]]`, `<` compara **texto** en orden alfabético, y `"1"` va antes que `"9"`. `(( ))` compara números. *(Clase 17.)*

**5.** Cada lado de un pipe corre en un proceso hijo: el `while` suma en **su copia** de `N`, que desaparece al terminar el pipe. Arreglo: `N=0; while read -r L; do N=$((N + 1)); done < lista.txt; echo $N`. *(Clases 07 y 18.)*

**6.**
```bash
for (( i = 1; i <= 5; i++ )); do
  curl -fs -o /dev/null http://localhost:8080 && exit 0
  sleep 2
done
echo "No respondió tras 5 intentos" >&2
exit 1
```
*(Clase 18.)*

**7.** `(( ))` devuelve 1 cuando la expresión vale 0, y `i++` vale el valor **anterior** de `i`, 0. Para `set -e` eso es un fallo. En su lugar: `i=$(( i + 1 ))`. *(Clase 19.)*

**8.** Ejecuta la limpieza al **salir** del script, termine bien, con error o con `Ctrl+C`. Casos: borrar el directorio temporal de `mktemp`, parar un servidor de pruebas que arrancó el script o liberar un bloqueo. *(Clase 19.)*

**9.** `30 2 * * * /home/educo/bin/limpiar.sh >> /home/educo/logs/limpiar.log 2>&1`. Minuto 30, hora 2, todos los días. *(Clases 04 y 20.)*

**10.** Cron arranca con un PATH mínimo, `/usr/bin:/bin`, que no incluye `~/.local/bin`. Arreglo: la ruta completa (`/home/educo/.local/bin/aws`) o un `PATH=` al principio del script o del crontab. *(Clases 07 y 20.)*

**11.** Con `Persistent=true`, el timer recupera la ejecución si el equipo estaba apagado a esa hora, y cron no. Además, sus logs van solos al journal (`journalctl -u nombre`), y puedes fijar el usuario y las dependencias como en cualquier servicio. Cron gana en sencillez, y su sintaxis es la que usan Kubernetes y GitHub Actions. *(Clases 12 y 20.)*

**12.** El archivo no tiene permiso de ejecución: con `./` el kernel se niega, mientras que `bash vigia.sh` solo necesita **leerlo**. El arreglo correcto es `chmod +x vigia.sh` y llamarlo en el crontab por su **ruta absoluta**, para que se use su shebang. *(Clases 06, 16 y 20.)*

**Práctica final (una solución):**
```bash
#!/bin/bash
# alerta-disco.sh — avisa si el disco / supera un límite de uso
# Uso: alerta-disco.sh [límite-en-%]     (por defecto, 80)
set -euo pipefail

LIMITE="${1:-80}"
[[ $LIMITE =~ ^[0-9]+$ ]] || { echo "Uso: $0 [límite-en-%]" >&2; exit 2; }

USO="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
if (( USO > LIMITE )); then
  echo "AVISO: / al ${USO} % (límite: ${LIMITE} %)" >&2
  exit 1
fi
echo "OK: / al ${USO} %"
```
Códigos esperados: 0 con 99, 1 con 1 y 2 con `abc`. Si lo programas en cron, ya sabes qué hacer con el aviso: redirigirlo a un log (clase 20). En Vigía harás lo mismo con webs en lugar de discos.
</details>

## Siguiente

[Clase 21 — Proyecto: Vigía v0](clase-21-vigia-v0.md)
