# Clase 04 — Redirecciones, pipes y códigos de salida

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** todo programa tiene **una entrada y dos salidas**. Por **stdout** salen los datos que pediste; por **stderr**, los errores. Las dos van a la pantalla, pero tú puedes **mandarlas a otro sitio**, como un archivo (eso es *redirigir*), o pasar el stdout de un programa a la entrada del siguiente (eso es un *pipe*, `|`). Y al terminar, cada programa deja un **código de salida**: 0 si todo fue bien.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `>` y `>>` para escribir en un archivo (clase 03: lo explicaste en tu cierre).
> - El shell prepara las cosas **antes** de lanzar el programa, como con los comodines (clase 03).
> - Mirar quién se queja en un error: `lsss` frente a `ls /esto-no-existe` (clase 01).

> 🔤 **Palabras nuevas de hoy:**
> - **stdout** (salida estándar, número 1): por donde salen los datos.
> - **stderr** (salida de errores, número 2): por donde salen los errores.
> - **redirigir**: mandar stdout o stderr a otro sitio que no sea la pantalla, como un archivo.
> - **pipe** (`|`): pasar el stdout de un programa a la entrada del siguiente.
> - **código de salida**: el número que deja un programa al terminar (0 = todo bien).
> - **`/dev/null`**: un archivo especial que descarta todo lo que le mandas.
> - **pipeline de CI/CD**: la cadena de pasos automáticos que prueba y publica el código (pieza 3). No es el pipe `|`.

## Objetivo

- Entender las tres conexiones de todo programa: la entrada (stdin), stdout y stderr.
- Mandar stdout o stderr a un archivo o descartarlos: `>`, `>>`, `2>`, `/dev/null` y `2>&1`.
- Conectar programas con `|` y guardar una copia por el camino con `tee`.
- Leer el código de salida de cada programa (`$?`) y usarlo para decidir qué se ejecuta después: `&&` y `||`.

## Por qué importa

Esta clase es **la filosofía Unix**: programas pequeños que hacen una cosa bien y se conectan entre sí. Con `|` analizarás logs de millones de líneas en un segundo. Y el código de salida de cada programa es el idioma con el que se entienden los scripts, los pipelines de CI/CD y los *health checks*: un job de GitHub Actions falla porque un comando dejó un código de salida distinto de 0.

## Cómo va esta clase

Seis piezas pequeñas. En cada una lees **una** idea y la pruebas enseguida en la terminal; no pases a la siguiente sin haber hecho la anterior: cada una se apoya en las de antes.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-04 && cd ~/my-devops-journey/labs/clase-04
```

## Las piezas

### Pieza 1 — Una entrada y dos salidas, y cómo leer un error

```
                     ┌────────────┐
 stdin (0)    ─────► │  programa  │ ─────► stdout (1): los DATOS
 (el teclado)        │            │ ─────► stderr (2): los ERRORES
                     └────────────┘
```

Los números (0, 1 y 2) importan: son los que escribirás en los comandos (`2>` significa «stderr a…»). Los nombres (*stdin*, *stdout*, *stderr*) son los que verás en la documentación y en las entrevistas.

Por defecto, **stdout y stderr van a la pantalla**. Por eso los datos y los errores **parecen lo mismo**, aunque salgan por sitios distintos.

Lo que sale por stderr casi siempre sigue el mismo molde: **quién se queja: sobre qué: por qué**.

```
ls: no se puede acceder a '/no-existe': No existe el archivo o directorio
└┬┘                       └─────┬────┘  └───────────────┬───────────────┘
quién                       sobre qué                por qué
```

El mensaje te dice **dónde buscar**:
- Si quien se queja es el programa (`ls`, `cp`, `grep`…), es que llegó a ejecutarse: el problema está en **lo que le pediste**.
- Si quien se queja es `bash`, o el mensaje es `Orden «nombre» no encontrada`, el programa ni siquiera arrancó: el problema está en **cómo escribiste la orden** (el nombre, las comillas o el permiso para ejecutarla).

Es lo que viste en la clase 01 con `ls /esto-no-existe` frente a `lsss`.

**Pruébalo.** Un comando que da una cosa de cada:

```bash
ls /etc/hostname /no-existe
```

👀 **Qué deberías ver:**

```
ls: no se puede acceder a '/no-existe': No existe el archivo o directorio     ← stderr (2)
/etc/hostname                                                                 ← stdout (1)
```

Las dos líneas en la misma pantalla, como si fueran lo mismo: una es un dato y la otra un error.

✋ **Sin mirar:** el mensaje `No existe el archivo o directorio`, ¿sale por stdout o por stderr?

<details>
<summary>Comprueba</summary>

Por **stderr** (la 2): es un error.
</details>

**En resumen:** los datos salen por stdout (1), los errores por stderr (2), y los dos van a la pantalla salvo que digas otra cosa; en un error, lee primero **quién** se queja.

### Pieza 2 — Redirigir: mandar stdout o stderr a otro sitio

Cada símbolo redirige **una** de las dos salidas. Uno a uno:

| Escribes | Qué salida redirige | A dónde |
|----------|---------------------|---------|
| `> archivo` | stdout (datos) | al archivo, **vaciándolo antes** |
| `>> archivo` | stdout (datos) | al **final** del archivo, sin borrar lo que había (lo viste en la clase 03) |
| `2> archivo` | stderr (errores) | al archivo |
| `> /dev/null` | stdout | a `/dev/null`, que lo **descarta**: no se guarda en ningún sitio |
| `2> /dev/null` | stderr | a `/dev/null`: «no quiero ver los errores» |

Y una más, la única con truco:

| Escribes | Qué hace |
|----------|----------|
| `2>&1` | manda stderr **al mismo sitio al que va stdout en ese momento** |

`2>&1` no une las dos salidas para siempre: copia el destino que tiene stdout **en ese instante**. Si después cambias stdout, stderr se queda donde estaba. Por eso importa el orden, y lo verás con tus ojos en el Rómpelo 2. La forma correcta de mandar **todo** a un archivo es:

```bash
comando > archivo 2>&1        # primero stdout va al archivo; después stderr copia ese destino
comando &> archivo            # atajo de bash que hace lo mismo
```

**Pruébalo.** Ejecuta las líneas **de una en una**. Antes de cada una, 🔮 **predice**: ¿qué verás en pantalla? ¿Qué acabará en el archivo?

```bash
ls /etc/hostname /no-existe > salida.txt
```
```bash
ls /etc/hostname /no-existe 2> errores.txt
```
```bash
ls /etc/hostname /no-existe > todo.txt 2>&1
```
```bash
ls /etc/hostname /no-existe 2> /dev/null
```

Ahora mira qué hay en cada archivo:
```bash
cat salida.txt; echo ---; cat errores.txt; echo ---; cat todo.txt
```

👀 **Qué deberías ver:**

<details>
<summary>Compruébalo después de predecir</summary>

| Línea | En pantalla | En el archivo |
|-------|-------------|---------------|
| `> salida.txt` | el error (stderr sigue en pantalla) | `/etc/hostname` |
| `2> errores.txt` | `/etc/hostname` (stdout sigue en pantalla) | el error |
| `> todo.txt 2>&1` | nada | las dos líneas |
| `2> /dev/null` | `/etc/hostname` | (el error desapareció) |
</details>

Verás errores en español (`ls`: *No existe el archivo o directorio*) y otros en inglés (`cat`: *No such file or directory*). Son las uutils de la clase 01, que aún no traducen todos sus mensajes. El idioma da igual: lo que importa es si cada mensaje sale por stdout o por stderr.

✋ **Sin mirar:** ¿qué diferencia hay entre `> notas.txt` y `>> notas.txt`?

<details>
<summary>Comprueba</summary>

`>` vacía el archivo antes de escribir; `>>` añade al final.
</details>

**En resumen:** `>` redirige stdout, `2>` redirige stderr, y `> archivo 2>&1` manda los dos al archivo.

### Pieza 3 — El código de salida

Al terminar, todo programa deja un número:
- **0**: todo fue bien.
- **Cualquier otro**: algo falló. Qué número exacto lo decide cada programa: `grep`, por ejemplo, deja 1 si no encontró nada y 2 si hubo un error de verdad.

`$?` guarda el código de salida del **último** comando: `echo $?` te lo enseña.

Con ese código puedes decidir qué se ejecuta después:

| Escribes | Se lee como… |
|----------|--------------|
| `a && b` | «haz `a` y, **si salió bien**, haz `b`» |
| `a \|\| b` | «haz `a` y, **si falló**, haz `b`» |
| `a ; b` | «haz `a` y después `b`, pase lo que pase» |

> 🏭 **El código de salida en el trabajo: el pipeline de CI/CD.** Piensa en el control de calidad de una fábrica: cada pieza pasa por varias estaciones y, si una detecta un defecto, la cinta se para y esa pieza no llega a la tienda. Un **pipeline de CI/CD** hace lo mismo con el código: cada vez que alguien lo cambia, una máquina ejecuta sola una lista de pasos, como **probar** (los tests), **construir** (empaquetar la app) y **desplegar** (publicarla para los clientes). Cada paso es un comando, y el pipeline mira su **código de salida**: si un paso deja algo distinto de 0, se para y no se publica nada roto. Lo construirás tú en la fase 7. (No lo confundas con el pipe `|`: solo comparten el nombre).

**Pruébalo:**

```bash
ls /etc/hostname ; echo "código: $?"
ls /no-existe    ; echo "código: $?"
grep root /etc/passwd ; echo "código: $?"
grep zzzz /etc/passwd ; echo "código: $?"
grep root /no-existe  ; echo "código: $?"
```

👀 **Qué deberías ver:** los códigos, en orden: `0`, `2`, `0`, `1` y `2`. Fíjate en `grep`: deja **1** si no encontró nada y **2** si hubo un error de verdad (el archivo no existe). Un script bien hecho distingue los dos casos.

Ahora usa el código de salida para decidir:
```bash
mkdir prueba && echo "creado"
mkdir prueba && echo "creado"          # ahora mkdir falla: el echo no se ejecuta
mkdir prueba || echo "ya existía"      # falla, así que se ejecuta lo de después de ||
```

👀 **Qué deberías ver:** `creado`; después, solo el error de `mkdir` (sin «creado»); y después, el error y `ya existía`.

Y una línea que junta todo lo de hoy. Léela por partes antes de ejecutarla:
```bash
ping -c1 -W1 8.8.8.8 > /dev/null 2>&1 && echo "hay internet" || echo "sin internet"
```
- `ping -c1 -W1 8.8.8.8`: envía **una** prueba a un servidor de internet y espera como mucho un segundo.
- `> /dev/null 2>&1`: descarta stdout **y** stderr. No nos interesa lo que imprime, solo su código de salida.
- `&& echo … || echo …`: si el código es 0, «hay internet»; si no, «sin internet».

✋ **Sin mirar:** acabas de ejecutar un comando que salió bien. ¿Qué muestra `echo $?`?

<details>
<summary>Comprueba</summary>

`0`.
</details>

**En resumen:** 0 = bien; `&&` significa «si salió bien» y `||`, «si falló».

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, `cd ~/my-devops-journey/labs/clase-04` y a la pieza 4.

### Pieza 4 — Pipes: conectar programas

```
 ┌──────┐    stdout     ┌──────┐
 │  ls  │ ─────────────►│  wc  │ ────► pantalla
 └──────┘     ( | )     └──────┘
```

`a | b` conecta el stdout de `a` con la entrada de `b`: lo que `a` iba a escribir en pantalla, `b` lo recibe para trabajar con ello. Por ejemplo, `ls /etc | wc -l` cuenta cuántas cosas hay en `/etc` (`wc -l` cuenta líneas).

Ojo: el pipe **solo pasa stdout**. stderr sigue yendo a la pantalla, así que los errores no pasan al siguiente programa: los ves tú.

**Pruébalo.** Empieza por uno sencillo:

```bash
cat /etc/passwd | wc -l               # cuántas cuentas de usuario hay en el sistema
```

Ahora construye un pipeline más largo **añadiendo una pieza cada vez** y mirando el resultado antes de añadir la siguiente. Es la forma profesional de escribirlos, y la de no perderse. La pregunta: ¿qué *shell* usan las cuentas del sistema?

```bash
cut -d: -f7 /etc/passwd | head -5                         # paso 1: el 7.º campo de cada línea
cut -d: -f7 /etc/passwd | sort | head -5                  # paso 2: ordenado: los iguales quedan juntos
cut -d: -f7 /etc/passwd | sort | uniq -c                  # paso 3: cuenta cuántos hay de cada uno
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn       # paso 4: de más a menos
```

👀 **Qué deberías ver:** arriba del todo, `/usr/sbin/nologin` con un número grande (en tu equipo, 42), y más abajo `/bin/bash` con 2.

- `cut -d: -f7`: «corta cada línea por los dos puntos (`:`) y quédate con el trozo 7», que en `/etc/passwd` es el shell de cada cuenta.
- `uniq -c`: junta las líneas iguales **que están seguidas** y las cuenta. Por eso antes hace falta `sort`.
- `sort -rn`: ordena por número (`n`) de mayor a menor (`r`, *reverse*).

Gana `/usr/sbin/nologin` con diferencia: la mayoría de las cuentas no son personas, sino servicios que no pueden iniciar sesión (lo verás en la clase 09). Estas herramientas las verás a fondo en la clase 05; hoy basta con entender cómo se conectan con `|`.

Y comprueba que el pipe solo pasa stdout:

🔮 **Predice:** ¿qué número saldrá? ¿Y el error?

```bash
ls /etc/hostname /no-existe | wc -l
```

👀 **Qué deberías ver:** `wc` cuenta **1** línea, la de `/etc/hostname`. El error no entró en el pipe: salió directo a tu pantalla por stderr.

✋ **Sin mirar:** ¿por qué `uniq -c` necesita un `sort` antes?

<details>
<summary>Comprueba</summary>

Porque `uniq` solo junta las líneas iguales que están **seguidas**; `sort` pone juntas todas las iguales.
</details>

**En resumen:** `|` pasa los datos de un programa al siguiente; los errores no pasan. Los pipelines se construyen pieza a pieza.

### Pieza 5 — `tee`: guardar una copia sin cortar el pipe

`tee` deja pasar los datos al siguiente programa y, además, guarda una copia en un archivo (el nombre viene de la pieza en forma de T de las tuberías). Lo usarás desde la clase 10 para escribir archivos del sistema con `sudo`.

**Pruébalo:**

```bash
ls -l /etc | tee listado.txt | wc -l
head -3 listado.txt
```

👀 **Qué deberías ver:** un número (en tu equipo, unas 240 líneas) y después las tres primeras líneas de `listado.txt`, empezando por `total`. El número de líneas sale en pantalla **y** la lista completa quedó guardada en `listado.txt`.

✋ **Sin mirar:** ¿qué diferencia hay entre `ls -l /etc > listado.txt` y `ls -l /etc | tee listado.txt`?

<details>
<summary>Comprueba</summary>

Los dos guardan la lista en el archivo, pero con `>` la pantalla se queda vacía; con `tee`, la lista sigue además hacia la pantalla (o hacia el siguiente programa del pipe).
</details>

**En resumen:** `tee` guarda una copia y deja pasar los datos.

### Pieza 6 — `$( )`: «pon aquí lo que imprima este comando»

```bash
echo "Hoy es $(date +%A)"
```

Antes de ejecutar `echo`, el shell ejecuta `date +%A`, coge lo que imprime (el día de la semana) y lo pone en su lugar.

**Pruébalo:**

```bash
echo "Soy $(whoami) en $(hostname) y hay $(ls /etc | wc -l) cosas en /etc"
cp listado.txt "listado-$(date +%F).txt"
ls
```

👀 **Qué deberías ver:** una frase con tu usuario, el nombre de tu equipo y un número; y, en el `ls`, un archivo nuevo `listado-` con la fecha de hoy. `date +%F` produce la fecha como año-mes-día (`2026-10-14`): nombres con fecha que además se ordenan bien con `ls`, perfectos para backups.

✋ **Sin mirar:** ¿qué hace el shell con `$(date +%F)` antes de ejecutar el `cp`?

<details>
<summary>Comprueba</summary>

Ejecuta `date +%F` y pone en su lugar lo que imprime, la fecha de hoy. El `cp` recibe ya `listado-2026-…txt`.
</details>

**En resumen:** `$(comando)` se sustituye por lo que imprime ese comando.

## Tu chuleta de la clase

Para consultar mientras practicas (no para memorizar de golpe):

| Sintaxis | Efecto |
|----------|--------|
| `cmd > f` | datos a `f` (lo vacía antes) |
| `cmd >> f` | datos al final de `f` |
| `cmd 2> f` | errores a `f` |
| `cmd > f 2>&1` / `cmd &> f` | datos y errores a `f` |
| `cmd 2> /dev/null` | descarta los errores |
| `cmd < f` | la entrada viene de `f` en lugar del teclado |
| `a \| b` | los datos de `a` entran en `b` |
| `a \| tee f \| b` | además, guarda una copia en `f` |
| `a && b` · `a \|\| b` | `b` solo si `a` salió bien · solo si falló |
| `$?` · `$(cmd)` | el código de salida del último comando · lo que imprime `cmd` |

## Rómpelo

**1. Destruir el archivo que estás leyendo:**
```bash
printf "c\na\nb\n" > letras.txt
sort letras.txt > letras.txt
cat letras.txt              # ¡vacío!
```
El shell prepara las redirecciones **antes** de lanzar el programa, y `>` significa «vacía este archivo». El orden real es: (1) el shell vacía `letras.txt`; (2) lanza `sort letras.txt`; (3) `sort` lee un archivo que ya está vacío. Es la misma idea que el comodín de la clase 03: **el shell trabaja antes que el programa**.

Bien hecho: escribe en otro archivo y después `mv`, o deja que lo haga `sort` con `sort -o letras.txt letras.txt`.

🔮 Y con `>>` en lugar de `>`, ¿qué quedaría? `>>` no vacía nada: `sort` lee `c a b` y añade `a b c` al final. El archivo acaba con seis líneas.

**2. El orden de `2>&1`:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.

🔮 **Predice:** ¿acabará el error dentro de `mal.txt`?

```bash
ls /etc/hostname /no-existe 2>&1 > mal.txt
cat mal.txt
```

El error salió por pantalla. El shell aplica las redirecciones **de izquierda a derecha**, una a una. Sigue a dónde va stdout y a dónde va stderr en cada versión.

**Versión buena:** `ls … > todo.txt 2>&1`

| Paso | Qué hace | stdout (1) | stderr (2) |
|------|----------|------------|------------|
| Al empezar | | pantalla | pantalla |
| `> todo.txt` | stdout va al archivo | **todo.txt** | pantalla |
| `2>&1` | stderr copia el destino que tiene stdout **ahora** | todo.txt | **todo.txt** |

Los dos acaban en el archivo. ✅

**Versión mala:** `ls … 2>&1 > mal.txt`

| Paso | Qué hace | stdout (1) | stderr (2) |
|------|----------|------------|------------|
| Al empezar | | pantalla | pantalla |
| `2>&1` | stderr copia el destino que tiene stdout **ahora**… que es la pantalla | pantalla | pantalla |
| `> mal.txt` | stdout va al archivo | **mal.txt** | pantalla |

stderr copió el destino que stdout tenía en ese momento (la pantalla) y no cambia cuando stdout pasa después al archivo. ❌

**Regla para recordarlo:** primero mandas stdout al archivo y después le dices a stderr que vaya al mismo sitio: `comando > archivo 2>&1`. El `2>&1` va **al final**.

**3. Un pipe esconde fallos:**
```bash
cat /no-existe | wc -l ; echo "código: $?"
```
El código es 0 aunque `cat` falló. En un pipe, `$?` solo guarda el código de salida del **último** programa (`wc`, que contó 0 líneas sin problema). El de `cat` se pierde. En la clase 19 lo arreglarás con `set -o pipefail`. Por ahora, recuérdalo: un pipeline en verde no garantiza que todo haya ido bien.

## Reto

Cada respuesta en **una sola línea**, conectando con `|` tantos programas como necesites (eso es un *pipeline*). En la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Cuántos usuarios de `/etc/passwd` usan `/bin/bash` como shell?

> 🧩 **Ejemplo resuelto:** ¿cuántas cuentas usan `/usr/sbin/nologin`?
> ```bash
> cut -d: -f7 /etc/passwd | grep "nologin" | wc -l
> ```
> `cut` saca el shell de cada cuenta, `grep` deja pasar solo los que contienen `nologin` y `wc -l` cuenta las líneas que quedan. En tu equipo sale 42.

**Ahora tú, con huecos:** `cut -d: -f7 /etc/passwd | grep "____" | wc -l`

<details>
<summary>Pista</summary>

Cambia solo lo que buscas: en lugar de `nologin`, el shell que pide el reto.
</details>

**2.** Lista las 5 cosas más grandes de `/etc`, sean archivos o carpetas.

> 🧩 **Ejemplo resuelto:** las 3 cosas más grandes de `/var/log`.
> ```bash
> ls -lS /var/log | head -4
> ```
> `ls -lS` ordena por tamaño, de mayor a menor. `head -4` y no `-3`, porque la primera línea es `total`, que no es ninguna de las cosas de la carpeta.

**Ahora tú, con huecos:** `ls -lS /etc | head -____`

<details>
<summary>Pista</summary>

Si quieres 5 cosas y la primera línea es `total`, ¿cuántas líneas necesitas?
</details>

**3.** Guarda en `errores-find.txt` **solo** los errores de `find /etc -name "*.conf"` (los de permiso denegado) y descarta los resultados en `/dev/null`.

> 🧩 **Ejemplo resuelto:** lo contrario: guardar **solo los resultados** en `resultados.txt` y descartar los errores.
> ```bash
> find /etc -name "*.conf" > resultados.txt 2> /dev/null
> ```
> `>` manda stdout (los resultados) al archivo, y `2>` manda stderr (los errores) a `/dev/null`.

**Ahora tú, con huecos:** `find /etc -name "*.conf" ____ errores-find.txt ____ /dev/null`

<details>
<summary>Pista</summary>

Es el ejemplo al revés: ahora los errores (stderr, `2>`) van al archivo, y los resultados (stdout, `>`) a `/dev/null`.
</details>

**4.** Escribe una línea que cree el directorio `backup-<fecha de hoy>` y, **solo si se creó**, copie dentro `/etc/hostname`.

> 🧩 **Ejemplo resuelto:** crear la carpeta `prueba-<fecha de hoy>` y, solo si se creó, escribir «creada».
> ```bash
> mkdir "prueba-$(date +%F)" && echo "creada"
> ```
> `$(date +%F)` mete la fecha en el nombre, y `&&` hace que el `echo` solo se ejecute si `mkdir` salió bien. Ejecútalo dos veces: la segunda, `mkdir` falla (la carpeta ya existe) y no sale «creada».

**Ahora tú, con huecos:** `mkdir "backup-$(date +%F)" ____ cp /etc/hostname "backup-____/"`

<details>
<summary>Pista</summary>

El primer hueco es el «si salió bien» de la pieza 3. El segundo, la misma fecha que pusiste en el nombre de la carpeta.
</details>

## Cierre

Crea tu archivo de notas con las preguntas ya copiadas (lo hace un script; en la clase 19 podrás leerlo entero):
```bash
bash ~/my-devops-journey/recursos/nueva-nota.sh 04
```
Y responde en `notas/fase-1/clase-04.md`:

1. ¿Qué son stdout y stderr? ¿Por qué conviene que sean flujos separados? *(2–3 líneas. Empieza así: «stdout es la salida de… y stderr es… Conviene separarlas porque…»)*
2. Explica qué hace `comando > log.txt 2>&1` y por qué `comando 2>&1 > log.txt` no hace lo mismo. *(3–4 líneas. Empieza así: «En la primera, stdout va primero a… y después stderr… En la segunda, stderr copia el destino de stdout cuando todavía…»)*
3. ¿Qué significa un código de salida 0? ¿Por qué le importa a un pipeline de CI/CD? *(2 líneas. Empieza así: «Un 0 significa… Si un paso de un pipeline deja otro código…»)*
4. **Repaso (clase 03, sin mirar):** ¿por qué `rm` es peligroso con comodines y qué haces antes de usarlo? *(2 líneas. Empieza así: «Porque el shell convierte el comodín en… y rm… Antes uso… para…»)*

Después, escríbeme `examíname clase-04`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** stdout (1) es la salida normal del programa, los datos; stderr (2) es la de errores y avisos. Separados, puedes guardar los datos limpios o pasarlos a otro programa mientras ves los errores, o guardar los errores en un log aparte. Si se mezclaran, un error se colaría en los datos que procesa el siguiente programa del pipe.

**2.** Las redirecciones se aplican de izquierda a derecha, y `2>&1` manda stderr **a donde va stdout en ese momento**. En `> log.txt 2>&1`, primero stdout va al archivo y después stderr copia ese destino: todo acaba en el log. En `2>&1 > log.txt`, stderr copia el destino de stdout cuando todavía era la pantalla, y después solo stdout pasa al archivo: los errores siguen saliendo por pantalla.

**3.** 0 = éxito; cualquier otro valor = fallo. En CI/CD, cada paso es un comando: si deja un código distinto de 0, el job se marca como fallido y el pipeline se detiene. Así un test que falla impide desplegar. Por eso un script que «falla pero deja 0» es peligroso: el pipeline sale en verde con algo roto.

**4.** El shell expande el comodín y `rm` borra todo lo que coincida, sin papelera y sin preguntar. Antes de usarlo se previsualiza con `echo patrón` o `ls patrón`, se comprueba con `pwd` dónde estás y, si hay duda, se usa `rm -i`.

**Reto (soluciones posibles):**
```bash
grep -c ':/bin/bash$' /etc/passwd                      # o: cut -d: -f7 /etc/passwd | grep -c '^/bin/bash$'
ls -lS /etc | head -6                                 # 6 y no 5: la primera línea es «total», que no es una entrada
find /etc -name "*.conf" 2> errores-find.txt > /dev/null
mkdir "backup-$(date +%F)" && cp /etc/hostname "backup-$(date +%F)/"
```
➕ **Para cuando hagas la clase 05:** en la lista del reto 2 puede colarse una carpeta (su línea empieza por `d`). Para quedarte solo con archivos: `ls -lS /etc | grep '^-' | head -5`. El `^-` significa «líneas que **empiezan** por guion», y así también desaparece la línea `total`.
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
