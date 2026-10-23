# Repaso del bloque A — Linux en tu equipo

**Dónde:** tus notas, sin terminal hasta el final · **Tiempo:** unos 60 min · **Cuándo:** después de la clase 07 y antes de la 08

> 💡 **Por qué este repaso:** han pasado un par de semanas desde la clase 01 y empiezas a olvidar. Es justo el momento en que recordar fija más. Las preguntas vienen **mezcladas**, sin decirte de qué clase son, como en una entrevista o en un incidente: parte del ejercicio es reconocer qué herramienta toca.

## Cómo hacerlo

1. Crea tu archivo: `bash ~/my-devops-journey/recursos/nueva-nota.sh repaso-a`.
2. Responde **sin mirar** clases ni notas, en 30 minutos como máximo. Si no sabes algo, escribe «no lo sé» y sigue: es información útil, no un fracaso.
3. Las preguntas con 💻 compruébalas en la terminal **después** de responderlas.
4. Corrige con la autocorrección y califica cada una (✅ 🟡 ❌).
5. Cada 🟡 o ❌ es una tarjeta de Anki y 10 minutos de vuelta a la clase que indica la respuesta.
6. Termina con tu chuleta (abajo).

Si lo haces en dos mañanas: el primer día, los pasos 1 a 4 (preguntas, 💻 y autocorrección: unos 40 min); el segundo, los pasos 5 y 6 (las vueltas a las clases y la chuleta).

## Preguntas

1. En un servidor mínimo, escribes `pyhton3 --version` y ves `pyhton3: orden no encontrada`. ¿Quién da el error, en qué paso de «Qué pasa cuando pulsas Enter» y qué compruebas primero?
2. Estás en `/var/log/nginx`. Escribe la ruta relativa y la absoluta hasta `/etc/nginx/nginx.conf`.
3. Vas a ejecutar `rm *.log` en un servidor. ¿Qué dos comandos escribes antes y qué te dice cada uno?
4. 💻 Sin ejecutarlo: ¿qué se ve en pantalla con `ls /etc/hostname /nada 2>/dev/null | wc -l`? ¿Y qué muestra `echo $?` justo después?
5. ¿Por qué `sort lista.txt > lista.txt` deja el archivo vacío? ¿Cómo se hace bien?
6. 💻 Escribe un pipeline que muestre las 3 rutas (campo 7) con más errores 5xx (campo 9 mayor o igual que 500) en `~/my-devops-journey/recursos/clase-05/access.log`.
7. En un log de producción, `grep -c " 500 " access.log` dice 58 y `awk '$9 == 500' access.log | wc -l` dice 57. ¿Cuál te crees y por qué?
8. Traduce `640` a letras (`rwx`) y di qué puede hacer cada uno. ¿Y `750` en un **directorio**?
9. El directorio `caja` tiene para ti `r--` (lectura sin `x`). ¿Qué pasa con `ls caja` y con `cat caja/dato.txt`? ¿Por qué?
10. Haces `export ENTORNO=prod` y ejecutas `./script.sh`, que dentro hace `export ENTORNO=dev`. Al terminar, ¿qué vale `$ENTORNO` en tu terminal? ¿Y si lo lanzas con `source script.sh`?
11. Un compañero instaló una herramienta en `/opt/tool/bin/tool`. Escribe `tool` y sale `no se encontró la orden`. Explícale por qué y dale dos soluciones.
12. 💻 **Caso mezclado.** Ejecutas `./backup.sh > log.txt`. En pantalla sale `bash: ./backup.sh: Permiso denegado`, y `log.txt` existe pero está vacío. Explica **las dos cosas**.

## Tu chuleta

En 10 minutos y **sin mirar**, escribe en `notas/fase-1/chuleta-bloque-a.md` todos los comandos del bloque que recuerdes, agrupados por tarea: moverme, archivos, leer, buscar y filtrar, redirigir, permisos y entorno. Una línea por comando, con lo que hace en tus palabras.

Después repasa las clases 01 a 07 y añade lo que faltaba marcado con ➕. Lo marcado es lo que tu memoria aún no tiene: ahí van tus próximas tarjetas de Anki. La chuleta te servirá en el examen de la clase 38 y en Bandit.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El **shell**, en el paso 3: buscó un programa llamado `pyhton3` en las carpetas del PATH y no lo encontró. Lo primero, la ortografía: es `python3`. Si estuviera bien escrito, `type -a python3` y `echo $PATH` dicen si existe y dónde. *(Clases 01 y 07.)*

**2.** Relativa: `../../../etc/nginx/nginx.conf` (tres niveles arriba: `nginx` → `log` → `var` → `/`). Absoluta: `/etc/nginx/nginx.conf`. En scripts y en cron se usa la absoluta, porque no depende de dónde estés. *(Clase 02.)*

**3.** `pwd`, porque el comodín se expande en la carpeta **actual**. Y `echo *.log` (o `ls *.log`), porque el shell expande el comodín **antes** de ejecutar `rm`: `echo` te enseña exactamente la lista que recibiría `rm`. *(Clase 03.)*

**4.** Se ve `1`: stdout trae una línea (`/etc/hostname`) y el error fue a `/dev/null`. `echo $?` muestra `0`, el código de `wc`, el último comando del pipe, aunque `ls` devolvió 2. Lo arreglarás con `set -o pipefail` en la clase 19. *(Clase 04.)*

**5.** El shell aplica `>` (vacía el archivo) **antes** de arrancar `sort`, que lee un archivo ya vacío. Bien hecho: `sort -o lista.txt lista.txt`, o escribir en otro archivo y después `mv`. *(Clase 04.)*

**6.** `awk '$9 >= 500 {print $7}' access.log | sort | uniq -c | sort -rn | head -3`. Con el log del curso: `/api/orders` (28), `/static/style.css` (15) y `/static/app.js` (13). *(Clase 05.)*

**7.** El de `awk`: filtra por la **columna** del estado. `grep " 500 "` busca el texto en cualquier parte de la línea, y una respuesta de 500 **bytes** también coincide. *(Clase 05.)*

**8.** `640` = `rw-r-----`: el dueño lee y escribe, el grupo solo lee y los demás nada. `750` en un directorio = `rwxr-x---`: el dueño hace de todo; el grupo puede listar y entrar, pero no crear ni borrar; los demás ni siquiera entran. *(Clase 06.)*

**9.** `ls caja` muestra los **nombres** (`r` deja leer la lista), y quizá con avisos al pedir detalles. `cat caja/dato.txt` falla: sin `x` no puedes entrar en el directorio para acceder a lo que hay dentro. *(Clase 06.)*

**10.** `prod`. `./script.sh` corre en un proceso **hijo** con una copia de tu entorno, y un hijo nunca cambia el del padre. Con `source`, el script corre en **tu** shell y la variable queda en `dev`. *(Clase 07.)*

**11.** `/opt/tool/bin` no está en su PATH, así que el shell no lo encuentra en el paso 3. Soluciones: usar la ruta completa (`/opt/tool/bin/tool`); `export PATH="/opt/tool/bin:$PATH"` para esta terminal (clase 07, pieza 5); y para siempre, añadir la carpeta al PATH **en un solo sitio** (`~/.profile`). *(Clases 01 y 07.)*

**12.** (a) `backup.sh` no tiene permiso de ejecución: el kernel se niega a ejecutarlo (clase 06). Quien se queja es `bash`, por stderr, que no estaba redirigido: por eso lo ves en pantalla (clase 04). (b) `log.txt` está vacío porque el shell crea el archivo y aplica `>` **antes** de intentar ejecutar el comando, igual que con `sort` en la pregunta 5. Arreglo: `chmod u+x backup.sh`. *(Clases 04 y 06.)*
</details>

## Siguiente

[Clase 08 — Tu primer servidor](clase-08-primer-servidor.md)
