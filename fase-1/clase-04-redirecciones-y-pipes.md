# Clase 04 — Redirecciones, pipes y códigos de salida

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** cada programa es como un **grifo con una entrada y dos salidas**. Por una sale lo que pediste (los datos, *stdout*) y por la otra los avisos y errores (*stderr*). Redirigir es decidir a qué cubo va cada salida, y un **pipe** (`|`) es una manguera que lleva la salida de un programa a la entrada del siguiente. Al terminar, cada programa deja además una nota con su resultado: el **código de salida** (0 = todo bien).

## Objetivo

- Entender los **tres flujos** de todo programa: stdin, stdout y stderr.
- Redirigirlos a archivos o a `/dev/null`: `>`, `>>`, `2>`, `2>&1`.
- Encadenar programas con `|` y guardar resultados intermedios con `tee`.
- Leer el **código de salida** (`$?`) y usar `&&` y `||` para encadenar con lógica.

## Por qué importa

Esta clase es **la filosofía Unix**: programas pequeños que hacen una cosa bien y se encadenan. Con `|` analizarás logs de millones de líneas en un segundo. Los códigos de salida son el lenguaje con el que se comunican los scripts, los pipelines de CI/CD y los health checks: un job de GitHub Actions falla porque un comando devolvió un código distinto de 0.

## Teoría

### Tres flujos por programa

```
                ┌─────────────┐
 stdin (0)  ──► │  programa   │ ──► stdout (1)  salida normal
 (teclado)      │             │ ──► stderr (2)  errores y avisos
                └─────────────┘
```

Por defecto, stdout y stderr van a la pantalla, así que **parecen lo mismo**, pero son dos canales distintos. Separarlos te permite, por ejemplo, guardar los resultados en un archivo y ver los errores en pantalla.

| Sintaxis | Efecto |
|----------|--------|
| `cmd > f` | stdout a `f` (lo vacía antes) |
| `cmd >> f` | stdout al final de `f` |
| `cmd 2> f` | stderr a `f` |
| `cmd > f 2>&1` | stdout a `f` **y** stderr a donde vaya stdout |
| `cmd &> f` | atajo de bash para lo mismo |
| `cmd < f` | stdin desde `f` |
| `cmd > /dev/null` | descarta la salida (`/dev/null` es un agujero negro) |
| `a \| b` | stdout de `a` entra como stdin de `b` |
| `a \| tee f \| b` | copia el flujo en `f` y lo deja pasar |

`2>&1` se lee "manda el 2 a donde apunta el 1 **en este momento**". Por eso el orden importa (lo verás en Rómpelo).

### Cómo leer un mensaje de error

Casi todos los errores siguen el mismo molde: **quién se queja: sobre qué: por qué**.

```
ls: no se puede acceder a '/no-existe': No existe el archivo o directorio
└┬┘                       └─────┬────┘  └───────────────┬───────────────┘
quién                       sobre qué                por qué
```

El mensaje te dice **dónde buscar**:
- Si quien se queja es el programa (`ls`, `cp`, `grep`…), es que llegó a ejecutarse: el problema está en **lo que le pediste**.
- Si quien se queja es `bash`, o el mensaje es `nombre: no se encontró la orden`, el programa ni siquiera arrancó: el problema está en **cómo escribiste la orden** (el nombre, las comillas o el permiso para ejecutarla).

Es lo que viste en la clase 01 con `ls /esto-no-existe` frente a `lsss`, y te servirá en cada incidente del curso.

### Código de salida

Todo programa, al terminar, devuelve un número:
- **0** = éxito.
- **Distinto de 0** = algún fallo. El número concreto lo define cada programa (en `grep`: 1 = no encontró nada, 2 = error).

`$?` guarda el código del **último** comando.

| Operador | Ejecuta el segundo… |
|----------|---------------------|
| `a && b` | solo si `a` tuvo éxito (0) |
| `a \|\| b` | solo si `a` falló |
| `a ; b` | siempre |

`$(comando)` sustituye esa expresión por la salida del comando: `echo "Hoy es $(date +%A)"`.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-04 && cd ~/my-devops-journey/labs/clase-04
```

### 1. Separar stdout y stderr

```bash
ls /etc/hostname /no-existe
```

🔮 **Predice:** ¿qué verás en pantalla con cada una de estas líneas y qué acabará en los archivos?

```bash
ls /etc/hostname /no-existe > salida.txt
ls /etc/hostname /no-existe 2> errores.txt
ls /etc/hostname /no-existe > todo.txt 2>&1
ls /etc/hostname /no-existe 2> /dev/null
cat salida.txt; echo ---; cat errores.txt; echo ---; cat todo.txt
```

Verás errores en español (`ls`: *No existe el archivo o directorio*) y otros en inglés (`cat`: *No such file or directory*). Son las uutils de la clase 01, que aún no traducen todos sus mensajes. El idioma da igual: lo que importa es por qué flujo sale cada mensaje.

### 2. Códigos de salida

```bash
ls /etc/hostname ; echo "código: $?"
ls /no-existe    ; echo "código: $?"
grep root /etc/passwd ; echo "código: $?"
grep zzzz /etc/passwd ; echo "código: $?"
grep root /no-existe  ; echo "código: $?"
```

Fíjate: `grep` devuelve **1** si no encuentra nada y **2** si hay un error de verdad. Un script bien hecho distingue ambos casos.

```bash
mkdir prueba && echo "creado"
mkdir prueba && echo "creado"          # ahora falla: no imprime
mkdir prueba || echo "ya existía"
ping -c1 -W1 8.8.8.8 > /dev/null 2>&1 && echo "hay internet" || echo "sin internet"
```

### 3. Pipes

```bash
cat /etc/passwd | wc -l               # cuántas cuentas de usuario hay en el sistema
cut -d: -f1 /etc/passwd | head        # solo los nombres (campo 1, separado por :)
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

Lee el último pipeline de izquierda a derecha: toma el campo 7 (el shell de cada usuario), ordena, cuenta los repetidos (`uniq -c` solo agrupa líneas **contiguas**, por eso antes se ordena) y ordena por número de mayor a menor.

Gana `/usr/sbin/nologin` con diferencia: la mayoría de las cuentas no son personas, sino servicios que no pueden iniciar sesión (lo verás en la clase 09).

### 4. `tee`: ver y guardar a la vez

```bash
ls -l /etc | tee listado.txt | wc -l
head -3 listado.txt
```

Lo usarás desde la clase 10 para escribir archivos del sistema con `sudo`.

### 5. Sustitución de comandos

```bash
echo "Soy $(whoami) en $(hostname) y hay $(ls /etc | wc -l) cosas en /etc"
cp listado.txt "listado-$(date +%F).txt"
ls
```

`date +%F` produce la fecha como año-mes-día (`2026-10-14`): nombres con fecha que además se ordenan bien con `ls`, perfectos para backups.

## Rómpelo

**1. Destruir el archivo que estás leyendo:**
```bash
printf "c\na\nb\n" > letras.txt
sort letras.txt > letras.txt
cat letras.txt              # ¡vacío!
```
El shell aplica `>` (vacía `letras.txt`) **antes** de arrancar `sort`, así que `sort` lee un archivo vacío. Solución: escribir en otro archivo y luego `mv`, o `sort -o letras.txt letras.txt`.

**2. El orden de `2>&1`:**

🔮 **Predice:** ¿acabará el error dentro de `mal.txt`?

```bash
ls /etc/hostname /no-existe 2>&1 > mal.txt
cat mal.txt
```
El error salió por pantalla. El shell aplica las redirecciones **de izquierda a derecha**, como quien recoloca flechas una a una. Sigue las flechas de cada flujo en las dos versiones:

| Paso | `cmd > f 2>&1` (bien) | `cmd 2>&1 > f` (mal) |
|------|------------------------|-----------------------|
| Al empezar | 1 → pantalla · 2 → pantalla | 1 → pantalla · 2 → pantalla |
| 1.ª redirección | `> f`: 1 → **f** | `2>&1`: 2 → a donde apunta el 1 **ahora**: la pantalla |
| 2.ª redirección | `2>&1`: 2 → a donde apunta el 1 **ahora**: **f** | `> f`: 1 → **f** |
| Resultado | los dos flujos acaban en el archivo ✅ | los errores siguen en pantalla ❌ |

`2>&1` no crea un enlace permanente entre los dos flujos: copia **el destino que tiene el 1 en ese instante**. El orden correcto es `> archivo 2>&1`.

**3. Un pipe esconde fallos:**
```bash
cat /no-existe | wc -l ; echo "código: $?"
```
El código es 0 aunque `cat` falló: `$?` es el código del **último** comando del pipe (`wc`). En la clase 19 lo arreglarás con `set -o pipefail`. Por ahora, recuérdalo: un pipeline en verde no garantiza que todo haya ido bien.

## Reto

Con un solo pipeline por pregunta:
1. ¿Cuántos usuarios de `/etc/passwd` usan `/bin/bash` como shell?
2. Lista los 5 archivos más grandes de `/etc` (pista: `ls -lS`).
3. Guarda en `errores-find.txt` **solo** los errores de `find /etc -name "*.conf"` (los de permiso denegado) y descarta los resultados.
4. Escribe una línea que cree el directorio `backup-<fecha de hoy>` y, **solo si se creó**, copie dentro `/etc/hostname`.

## Cierre

Crea tu archivo de notas con las preguntas ya copiadas (lo hace un script; en la clase 19 podrás leerlo entero):
```bash
bash ~/my-devops-journey/recursos/nueva-nota.sh 04
```
Y responde en `notas/fase-1/clase-04.md`:

1. ¿Qué son stdout y stderr? ¿Por qué conviene que sean flujos separados?
2. Explica qué hace `comando > log.txt 2>&1` y por qué `comando 2>&1 > log.txt` no hace lo mismo.
3. ¿Qué significa un código de salida 0? ¿Por qué le importa a un pipeline de CI/CD?
4. **Repaso (clase 03, sin mirar):** ¿por qué `rm` es peligroso con comodines y qué haces antes de usarlo?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** stdout (1) es la salida normal del programa y stderr (2) la de errores y avisos. Separados, puedes guardar o encadenar los resultados limpios mientras ves los errores, o guardar los errores en un log aparte. Si se mezclaran, un error se colaría en los datos que procesa el siguiente comando del pipe.

**2.** Las redirecciones se aplican de izquierda a derecha. En `> log.txt 2>&1`, primero stdout apunta al archivo y después stderr se copia a donde apunta stdout (el archivo): todo acaba en el log. En `2>&1 > log.txt`, stderr se copia a donde apunta stdout *en ese momento* (la pantalla) y después solo stdout se mueve al archivo: los errores siguen saliendo por pantalla.

**3.** 0 = éxito; cualquier otro valor = fallo. En CI/CD, cada paso es un comando: si devuelve algo distinto de 0, el job se marca como fallido y el pipeline se detiene. Así un test que falla impide desplegar. Por eso un script que "falla pero devuelve 0" es peligroso: el pipeline sale en verde con algo roto.

**4.** El shell expande el comodín y `rm` borra todo lo que coincida, sin papelera y sin preguntar. Antes de usarlo se previsualiza con `echo patrón` o `ls patrón`, se comprueba con `pwd` dónde estás y, si hay duda, se usa `rm -i`.

**Reto (soluciones posibles):**
```bash
grep -c ':/bin/bash$' /etc/passwd                      # o: cut -d: -f7 /etc/passwd | grep -c '^/bin/bash$'
ls -lS /etc | grep '^-' | head -5                     # ls -lS también lista directorios: '^-' deja solo las líneas que empiezan por - (archivos)
find /etc -name "*.conf" 2> errores-find.txt > /dev/null
mkdir "backup-$(date +%F)" && cp /etc/hostname "backup-$(date +%F)/"
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| standard output / error | salida estándar / de errores |
| redirect | redirigir |
| pipe | tubería `\|` |
| exit code / exit status | código de salida |
| command substitution | sustitución de comandos `$(...)` |

🎙️ *"A pipeline only reports the exit code of the last command, so in scripts I use `set -o pipefail` to catch failures in the middle."*

## Siguiente

[Clase 05 — Buscar y filtrar](clase-05-buscar-y-filtrar.md)
