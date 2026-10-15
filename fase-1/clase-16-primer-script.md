# Clase 16 — Tu primer script: variables, argumentos y comillas

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** C. Scripting con Bash

> 💡 **La idea de hoy:** un script es una **receta escrita**: los mismos comandos que escribirías a mano, guardados en un archivo para que se ejecuten igual cada vez. Recibe ingredientes (los **argumentos** `$1`, `$2`…), entrega el resultado por stdout, las quejas por stderr y, al terminar, un **código de salida** que dice si salió bien.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Crear un archivo con un *heredoc*: `cat > archivo <<'EOF'` … `EOF` (clase 07).
> - El permiso `x` para ejecutar (clase 06) y la nota de salida, `$?` (clase 04).
> - Las variables, `${VAR:-defecto}` y las comillas dobles (clase 07).

> 🔤 **Palabras nuevas de hoy:**
> - **script**: un archivo con comandos que se ejecutan en orden.
> - **shebang** (`#!`): la primera línea, que dice qué programa interpreta el archivo.
> - **argumento**: lo que escribes detrás del nombre del script (`$1`, `$2`…).
> - **expansión de parámetros**: las «tijeras» de bash para recortar el texto de una variable.
> - **código de salida propio**: la nota que tu script deja con `exit N`.

## Objetivo

- Escribir un script ejecutable: el *shebang*, el permiso `x` y las tres formas de lanzarlo.
- Usar variables, sustitución de comandos y **expansión de parámetros**: valores por defecto y recortes de texto.
- Recibir argumentos con `$1`, `$#` y `"$@"`, y entender por qué `"$@"` va entre comillas.
- Separar los datos (stdout) de los mensajes de error (stderr) y terminar con un código de salida propio.
- Ver qué hace tu script línea a línea con `bash -x`.

## Por qué importa

En DevOps, lo que haces a mano dos veces se escribe en un script: preparar un servidor, hacer un backup, comprobar que una web responde. Verás scripts de Bash en el *user-data* de las EC2, en los pasos de GitHub Actions y en los `entrypoint` de Docker. En las entrevistas junior es habitual que te pidan leer o escribir uno corto. Y tu proyecto de portafolio, **Vigía**, empieza siendo un script de Bash (clase 21).

Las clases 16 a 20 forman el bloque de scripting. Cada una añade una pieza: hoy, la estructura de un script; después, decisiones, bucles, robustez y tareas programadas.

## Teoría

Seis piezas, con la receta de *La idea de hoy*. La 5 (las tijeras) es la más nueva: tómatela con calma.

### 1. Cómo es una receta escrita

```bash
#!/bin/bash                       # shebang: qué programa interpreta el archivo
# Uso: ./hola.sh [nombre]         # comentario: qué hace y cómo se usa
NOMBRE="${1:-mundo}"              # variable con valor por defecto
echo "Hola, $NOMBRE"              # la lógica
exit 0                            # código de salida (0 = éxito)
```

El **shebang** (`#!`) tiene que ser la **primera línea**, desde el primer carácter. Cuando ejecutas `./hola.sh`, el kernel lee esos dos caracteres y lanza `/bin/bash ./hola.sh` por ti.

> 🔁 **Vuelve a la clase 01.** En el paso 4 de «Qué pasa cuando pulsas Enter», el kernel ejecuta un programa. Un programa compilado, como `ls`, sabe ejecutarlo directamente. Un script, en cambio, es solo texto: el `#!` es la nota que le dice al kernel a qué programa pasárselo. Y si el archivo no tiene `x` (clase 06), el kernel se niega justo en ese paso: `Permiso denegado`.

**En resumen:** un script es un archivo de texto con `#!/bin/bash` en la primera línea y permiso `x`.

### 2. Tres formas de lanzarlo

| Forma | ¿Necesita `x`? | ¿Usa el shebang? | ¿Dónde corre? |
|-------|----------------|------------------|---------------|
| `./hola.sh` | sí | sí | en un proceso hijo |
| `bash hola.sh` | no | no: eliges tú el intérprete | en un proceso hijo |
| `source hola.sh` | no | no | **en tu shell actual** (clase 07) |

Lo normal es `./hola.sh`. `source` solo se usa para cargar variables o funciones en tu propio shell, como viste en la clase 07.

**En resumen:** `./script` y `bash script` corren en un hijo; `source script`, en tu propio shell.

### 3. Los ingredientes: los argumentos

Lo que escribes detrás del nombre del script le llega numerado:

```
./copia.sh  informe.txt  /backups
   $0           $1          $2          $# = 2 (cuántos llegaron)
```

| Variable | Contiene |
|----------|----------|
| `$1`, `$2`… | cada argumento, por su posición |
| `$#` | cuántos argumentos llegaron |
| `"$@"` | todos, **cada uno por separado**, aunque tengan espacios. Siempre entre comillas |
| `$0` | el nombre con el que se llamó al script |

**En resumen:** `$1`, `$2`… son los argumentos; `$#`, cuántos llegaron; `"$@"`, todos.

### 4. Valores por defecto y argumentos obligatorios

Dos formas de escribir una variable que usarás en casi todos tus scripts:

```bash
NOMBRE="${1:-mundo}"              # si no me das $1, uso "mundo"
RUTA="${1:?Uso: $0 <ruta>}"       # si no me das $1, me quejo y termino con error
```

`:-` significa «**o, si no hay**»; `:?`, «**y si no hay, error**». La segunda es la forma más corta de declarar un argumento obligatorio: el script se para antes de hacer nada.

**En resumen:** `${1:-defecto}` pone un valor si falta; `${1:?mensaje}` para el script si falta.

### 5. Las tijeras: recortar texto sin otros programas

Bash puede recortar el texto de una variable por delante o por detrás. Con `URL="https://ejemplo.com/salud"`:

| Escribes | Corta… | Resultado |
|----------|--------|-----------|
| `${URL#*://}` | por **delante**, hasta el primer `://` | `ejemplo.com/salud` |
| `${URL%/*}` | por **detrás**, desde la última `/` | `https://ejemplo.com` |

Y con `ARCHIVO="backup-2026-10-12.tar.gz"`, la diferencia entre uno y dos símbolos:

| Escribes | Corta… | Resultado |
|----------|--------|-----------|
| `${ARCHIVO%.tar.gz}` | ese final exacto | `backup-2026-10-12` |
| `${ARCHIVO#*.}` | por delante, **lo mínimo** (hasta el primer punto) | `tar.gz` |
| `${ARCHIVO##*.}` | por delante, **lo máximo** (hasta el último punto) | `gz` |

Cómo recordarlo: en el teclado, `#` está a la **izquierda** de `$` (corta por delante) y `%` a la **derecha** (corta por detrás). **Un** símbolo corta lo mínimo; **dos**, lo máximo. Y `${#ARCHIVO}`, con el `#` delante del nombre, no recorta: cuenta las letras (`24`).

**En resumen:** `#` corta por delante y `%` por detrás; uno corta lo mínimo y dos, lo máximo.

### 6. Datos, mensajes y la nota de salida

Tu script tiene las mismas dos mangueras y la misma nota que cualquier programa (clase 04):

```bash
echo "resultado"                 # manguera 1: los datos que otro programa puede usar
echo "Error: falta X" >&2        # manguera 2: mensajes para humanos y errores
exit 2                           # la nota: 0 = bien, 1 = fallo, 2 = uso incorrecto
```

`>&2` significa «manda esto por la manguera 2». Así, si alguien hace `./script.sh > datos.txt`, los errores siguen saliendo en pantalla y no ensucian los datos.

**En resumen:** datos por la 1, mensajes por la 2 (`>&2`) y una nota al salir (`exit N`).

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Ejecutas `./saluda.sh Ana Luis`. ¿Qué valen `$1`, `$2` y `$#`?
2. ¿Qué hace `NOMBRE="${1:-mundo}"` si no le das ningún argumento?
3. Con `F=foto.png`, ¿qué da `${F%.png}`?

<details>
<summary>Comprueba</summary>

1. `$1` = `Ana`, `$2` = `Luis`, `$#` = `2`. 2. `NOMBRE` vale `mundo`. 3. `foto`: `%` corta ese final exacto.
</details>

### Tu chuleta de la clase

| Escribes | Qué es |
|----------|--------|
| `#!/bin/bash` | el shebang: primera línea, desde el primer carácter |
| `chmod +x s.sh` · `./s.sh` | darle permiso de ejecución · lanzarlo |
| `$1` `$2`… · `$#` · `"$@"` · `$0` | argumentos · cuántos · todos por separado · el nombre del script |
| `${VAR:-defecto}` · `${1:?mensaje}` | valor por defecto · obligatorio (si falta, error y salida) |
| `${V#…}` `${V##…}` · `${V%…}` `${V%%…}` | cortar por delante (mínimo · máximo) · por detrás (mínimo · máximo) |
| `${#V}` | la longitud |
| `echo "…" >&2` · `exit N` | mensaje por la manguera 2 · terminar con la nota N |
| `bash -x s.sh` | ejecutarlo enseñando cada línea ya expandida |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-16 && cd ~/my-devops-journey/labs/clase-16
```

### 1. El primer script

```bash
cat > hola.sh <<'EOF'
#!/bin/bash
# Uso: ./hola.sh [nombre]
NOMBRE="${1:-mundo}"
echo "Hola, $NOMBRE. Hoy es $(date +%F) y estás en $(hostname)."
EOF
```

🔮 **Predice:** ¿qué pasará con `./hola.sh` justo ahora?

```bash
./hola.sh
chmod +x hola.sh
./hola.sh
./hola.sh Eduardo
bash hola.sh Ana
```

<details>
<summary>Qué deberías ver</summary>

`Permiso denegado` en el primer intento; después del `chmod`, `Hola, mundo…`, `Hola, Eduardo…` y `Hola, Ana…`, con la fecha y el nombre de tu equipo.
</details>

El primer intento da `Permiso denegado`: el archivo aún no tenía `x` (clase 06).

### 2. Argumentos y `"$@"`

```bash
cat > args.sh <<'EOF'
#!/bin/bash
echo "Me llamaron como: $0"
echo "Recibí $# argumentos"
echo "El primero es: ${1:-<ninguno>}"
printf '  → [%s]\n' "$@"
EOF
chmod +x args.sh
```

`printf` repite su formato una vez por cada argumento, así que imprime cada uno entre corchetes en su propia línea.

🔮 **Predice:** ¿cuántos argumentos cuenta en cada caso?

```bash
./args.sh uno dos
./args.sh "mi informe.txt" otro
./args.sh
```

<details>
<summary>Qué deberías ver</summary>

2 argumentos; otra vez 2 (con `[mi informe.txt]` entero, en una sola línea); y 0 argumentos, con `<ninguno>` y `→ []`.
</details>

Las comillas al llamar al script deciden qué es **un** argumento: `"mi informe.txt"` llega como uno solo. Sin argumentos, `printf` usa su formato una vez con el hueco vacío, y por eso ves `→ []`.

### 3. Recortar texto con la expansión de parámetros

🔮 **Predice** cada resultado antes de ejecutarlo. Usa la tabla de la teoría.

```bash
URL="https://ejemplo.com/salud"
echo "${URL#*://}"
echo "${URL%/*}"
echo "${URL%%/*}"
HOST="${URL#*://}"; HOST="${HOST%%/*}"; echo "$HOST"
ARCHIVO="backup-2026-10-12.tar.gz"
echo "${ARCHIVO%.tar.gz}"
echo "${ARCHIVO#*.}"
echo "${ARCHIVO##*.}"
echo "${#ARCHIVO}"
```

<details>
<summary>Qué deberías ver</summary>

`ejemplo.com/salud`, `https://ejemplo.com`, `https:`, `ejemplo.com`, `backup-2026-10-12`, `tar.gz`, `gz` y `24`.
</details>

Sacar el host de una URL en dos pasos es justo lo que hará Vigía para medir el DNS (clase 35).

### 4. Un script con argumento obligatorio

```bash
cat > tamano.sh <<'EOF'
#!/bin/bash
# Uso: ./tamano.sh <ruta>
# Imprime cuánto ocupa una ruta.
RUTA="${1:?Uso: $0 <ruta>}"
TAMANO="$(du -sh "$RUTA" 2>/dev/null | cut -f1)"
echo "$RUTA ocupa ${TAMANO:-?}"
EOF
chmod +x tamano.sh
```

🔮 **Predice** el código de salida de cada llamada:

```bash
./tamano.sh ~/my-devops-journey ; echo "código: $?"
./tamano.sh ; echo "código: $?"
./tamano.sh /no-existe ; echo "código: $?"
```

- Sin argumento, `${1:?...}` imprime `./tamano.sh: línea 4: 1: Uso: ./tamano.sh <ruta>` y el script **sale con 1** antes de hacer nada. Así se declara un argumento obligatorio.
- Con `/no-existe`, el script dice `/no-existe ocupa ?` y **devuelve 0**. Miente: falló, pero informa de éxito. Un pipeline de CI lo daría por bueno. Lo arreglas en la clase 17 con `if`.

### 5. Separar datos y mensajes

```bash
cat > avisa.sh <<'EOF'
#!/bin/bash
echo "dato útil"
echo "aviso: esto es un mensaje para humanos" >&2
exit 3
EOF
chmod +x avisa.sh
```

🔮 **Predice:** ¿qué verás en pantalla en cada línea y qué quedará en `datos.txt`?

```bash
./avisa.sh > datos.txt ; echo "código: $?"
cat datos.txt
./avisa.sh 2>/dev/null
```

<details>
<summary>Qué deberías ver</summary>

En el primero, solo el aviso en pantalla y `código: 3`; en `datos.txt`, `dato útil`; y en el último, solo `dato útil`.
</details>

### 6. Ver el script por dentro con `bash -x`

```bash
bash -x tamano.sh ~/my-devops-journey/labs
```

Cada línea que empieza por `+` es un comando **ya expandido**, tal como lo ejecuta bash: ves el valor real de cada variable. Es la primera herramienta cuando un script "hace algo raro". Dentro de un script, `set -x` activa lo mismo a partir de esa línea y `set +x` lo desactiva.

## Rómpelo

**1. Espacios alrededor del `=`:**
```bash
NOMBRE = Eduardo
```
`NOMBRE: no se encontró la orden` (dentro de un script: `NOMBRE: orden no encontrada`). Bash entiende "ejecuta el programa `NOMBRE` con los argumentos `=` y `Eduardo`". En una asignación no puede haber espacios: `NOMBRE=Eduardo`.

**2. `$@` sin comillas:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
cat > sin-comillas.sh <<'EOF'
#!/bin/bash
printf '  → [%s]\n' $@
EOF
chmod +x sin-comillas.sh
./sin-comillas.sh "mi informe.txt" otro
./args.sh "mi informe.txt" otro
```
Sin comillas, bash vuelve a partir los argumentos por los espacios: `mi informe.txt` se convierte en dos. Con rutas reales, el script trabajaría sobre archivos que no existen… o sobre otros que sí existen.

**3. Un script con finales de línea de Windows:**
```bash
printf '#!/bin/bash\r\necho "hola"\r\n' > windows.sh
chmod +x windows.sh
./windows.sh
```
`/bin/bash^M: intérprete erróneo`. Windows termina las líneas con `\r\n` y Linux con `\n`, así que el shebang pide un programa llamado `/bin/bash\r`, que no existe. Pasa cuando un script se edita en Windows o se copia de ciertas webs. Diagnóstico y arreglo:
```bash
cat -A windows.sh            # los \r aparecen como ^M
sed -i 's/\r$//' windows.sh
./windows.sh
```

**4. Una variable mal escrita:**
```bash
cat > typo.sh <<'EOF'
#!/bin/bash
DIRECTORIO="/tmp/prueba-clase16"
mkdir -p "$DIRECTORIO"
touch "$DIRECTORIO/a.txt" "$DIRECTORIO/b.txt"
echo "Archivos en $DIRETORIO:"
ls "$DIRETORIO"
EOF
chmod +x typo.sh && ./typo.sh
```
`$DIRETORIO` (falta una C) no existe, así que vale vacío **sin ningún aviso**, y `ls` recibe `''`. Aquí solo falla un `ls`. Imagina `rm -rf "$DIRETORIO"/*`: se convertiría en `rm -rf /*`. En 2015, un script de Steam para Linux hizo exactamente eso y borró los archivos de algunos usuarios. En la clase 19 activarás `set -u`, que convierte este error en una parada inmediata, y `shellcheck` te avisará de la errata (`Possible misspelling: DIRETORIO`) antes de ejecutar nada.

## Reto

En `labs/clase-16/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Ejecuta `./tamano.sh /no-existe; echo $?` y explica en tus notas por qué ese resultado es un problema.

> 🧩 **Ejemplo resuelto:** ¿qué nota deja `ls` cuando le pides algo que no existe?
> ```bash
> ls /no-existe; echo $?
> ```
> Deja `2`: avisa de que falló, así que un script que use `ls` puede enterarse.

**Ahora tú, con huecos:** `./tamano.sh /no-existe deja la nota ____, que significa «todo fue ____», aunque la ruta no existe.`

<details>
<summary>Pista</summary>

¿Qué pensaría cron, o un pipeline de CI, al ver esa nota?
</details>

**2.** Escribe `extension.sh <archivo>`, que imprima el nombre sin extensión y la extensión, usando solo las tijeras (sin `cut`): `./extension.sh informe.final.pdf` → `nombre: informe.final · extensión: pdf`.

> 🧩 **Ejemplo resuelto:** solo la extensión de `foto.vacaciones.jpg`.
> ```bash
> F=foto.vacaciones.jpg
> echo "${F##*.}"
> ```
> `##*.` corta por delante lo máximo, hasta el **último** punto: queda `jpg`.

**Ahora tú, con huecos:**
```bash
cat > extension.sh <<'EOF'
#!/bin/bash
ARCHIVO="${1:?Uso: $0 <archivo>}"
echo "nombre: ${ARCHIVO____} · extensión: ${ARCHIVO##*.}"
EOF
chmod +x extension.sh
./extension.sh informe.final.pdf
```

<details>
<summary>Pista</summary>

Para el nombre, corta por **detrás** lo mínimo, desde el último punto: `%` y el patrón `.*`.
</details>

**3.** Haz que `tamano.sh` acepte un segundo argumento **opcional**: la etiqueta que se muestra. `./tamano.sh ~/Descargas "Mis descargas"` → `Mis descargas ocupa 1,2G`. Sin segundo argumento, muestra la ruta como hasta ahora.

> 🧩 **Ejemplo resuelto:** una variable que, si está vacía, toma el valor de otra.
> ```bash
> NOMBRE=""
> SALUDO="${NOMBRE:-$USER}"
> echo "$SALUDO"
> ```
> Como `NOMBRE` está vacía, `SALUDO` toma el valor de `$USER`: imprime `educo`.

**Ahora tú, con huecos:**
```bash
ETIQUETA="${2:-____}"
echo "$____ ocupa ${TAMANO:-?}"
```

<details>
<summary>Pista</summary>

Si no llega un segundo argumento, ¿qué querías mostrar hasta ahora? La variable que guarda la ruta. Y el `echo` tiene que usar la nueva variable.
</details>

**4.** Escribe `info.sh`, que imprima en cuatro líneas el nombre del equipo, la versión del kernel (`uname -r`), cuánto tiempo lleva encendido (`uptime -p`) y el porcentaje de uso del disco `/` (`df --output=pcent / | tail -1`). Guarda cada valor en una variable antes de imprimirlo.

> 🧩 **Ejemplo resuelto:** un script con dos datos.
> ```bash
> cat > mini-info.sh <<'EOF'
> #!/bin/bash
> HOST="$(hostname)"
> USUARIO="$(whoami)"
> echo "Equipo:  $HOST"
> echo "Usuario: $USUARIO"
> EOF
> chmod +x mini-info.sh && ./mini-info.sh
> ```
> Cada dato se guarda en su variable con `$( )` y después se imprime.

**Ahora tú, con huecos:**
```bash
cat > info.sh <<'EOF'
#!/bin/bash
HOST="$(hostname)"
KERNEL="$(____)"
ENCENDIDO="$(____)"
DISCO="$(df --output=pcent / | tail -1)"
echo "Equipo:    $HOST"
echo "Kernel:    $KERNEL"
echo "Encendido: $ENCENDIDO"
echo "Disco /:   $DISCO usado"
EOF
chmod +x info.sh && ./info.sh
```

<details>
<summary>Pista</summary>

Los dos comandos que faltan están en el enunciado.
</details>

## Cierre

En `notas/fase-1/clase-16.md`:

1. ¿Qué es el shebang? ¿Qué pasa si lo olvidas y el script lo lanza `cron`, que usa `/bin/sh`? *(2–3 líneas. Empieza así: «El shebang es la primera línea… Si lo olvido, cron lo ejecuta con `sh`, y falla en…»)*
2. ¿Qué diferencia hay entre `"$@"` y `$@`? ¿Cuándo se nota? *(2 líneas. Empieza así: «`"$@"` entrega cada argumento…; `$@` sin comillas… Se nota cuando un argumento tiene…»)*
3. ¿Por qué los mensajes de error van a stderr y los datos a stdout? *(2 líneas. Empieza así: «Para que los datos se puedan… sin que se cuele… Los errores siguen…»)*
4. **Repaso (clase 15, sin mirar):** ¿qué guardas en `~/.ssh/config` y qué te ahorra? *(2 líneas. Empieza así: «Guardo bloques `Host` con… Me ahorra escribir…»)*

Después, escríbeme `examíname clase-16`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Es la primera línea, `#!/bin/bash`: le dice al kernel con qué programa interpretar el archivo cuando lo ejecutas directamente. Sin ella, el resultado depende de quién lo lance: desde bash funciona por casualidad (bash lo ejecuta él mismo), pero cron lanza los comandos con `/bin/sh` (dash), que lo interpretaría como un script de `sh`, y fallaría en lo que es propio de bash, como `[[ ]]`. Un programa que no es un shell daría `Exec format error`. Con `bash script.sh` el shebang se ignora.

**2.** `"$@"` entrega cada argumento tal como llegó, aunque tenga espacios. `$@` sin comillas los vuelve a partir por los espacios (y además expande comodines). Se nota en cuanto un argumento tiene espacios, como una ruta `"mi informe.txt"`, que se convierte en dos argumentos.

**3.** Para que la salida normal contenga solo datos y se pueda redirigir, encadenar con `|` o capturar con `$(...)` sin que se cuele un mensaje. Los errores siguen viéndose en pantalla, o se guardan aparte (`2> errores.log`). En cron y en CI se pueden registrar por separado.

**4.** Alias de conexión: un bloque `Host` con `HostName` (IP o nombre), `User`, `IdentityFile` y, si hace falta, `Port`. Te permite escribir `ssh servidor-01` en lugar de `ssh -i ~/.ssh/lab_ed25519 ubuntu@10.x.x.x`, y lo usan también `scp`, `rsync` y `git`.

**Reto (soluciones posibles):**
```bash
cat > info.sh <<'EOF'
#!/bin/bash
# Uso: ./info.sh — resumen del equipo
HOST="$(hostname)"
KERNEL="$(uname -r)"
ENCENDIDO="$(uptime -p)"
DISCO="$(df --output=pcent / | tail -1)"
echo "Equipo:    $HOST"
echo "Kernel:    $KERNEL"
echo "Encendido: $ENCENDIDO"
echo "Disco /:   $DISCO usado"
EOF

cat > extension.sh <<'EOF'
#!/bin/bash
# Uso: ./extension.sh <archivo>
ARCHIVO="${1:?Uso: $0 <archivo>}"
echo "nombre: ${ARCHIVO%.*} · extensión: ${ARCHIVO##*.}"
EOF
```
En `tamano.sh`, añade `ETIQUETA="${2:-$RUTA}"` y cambia el `echo` por `echo "$ETIQUETA ocupa ${TAMANO:-?}"`. Fíjate en que tu Ubuntu está en español: `du` escribe `1,2G`, con coma.

**Reto 1:** devuelve 0 aunque la ruta no existe, así que quien lo use (otro script, cron, un pipeline) cree que todo fue bien. Un script debe devolver un código distinto de 0 cuando falla.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| shebang | la línea `#!` del principio |
| positional parameters | argumentos posicionales (`$1`, `$2`…) |
| parameter expansion | expansión de parámetros |
| exit status | código de salida |
| to trace a script | trazar un script (`bash -x`) |

🎙️ *"I keep my scripts readable: a usage line at the top, quoted variables, errors to stderr and a meaningful exit code."*

## Siguiente

[Clase 17 — Decisiones: if, test y case](clase-17-decisiones.md)
