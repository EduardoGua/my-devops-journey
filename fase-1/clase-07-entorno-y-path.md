# Clase 07 — Variables de entorno, PATH y el shell

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** cada proceso nace con un conjunto de variables, su **entorno**, que es una **copia** del entorno de su padre. Lo que exportas con `export` lo reciben tus procesos hijos, pero un hijo nunca puede cambiar tus variables. El `PATH` es una de esas variables: la lista ordenada de carpetas donde el shell busca cada comando que escribes.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El paso 3 de «Qué pasa cuando pulsas Enter»: el shell busca el programa (clase 01, pieza 4).
> - `bash` abre un shell dentro de otro, y `exit` vuelve al primero (clase 01).
> - `$(comando)` mete lo que imprime un comando dentro de otro (clase 04).

> 🔤 **Palabras nuevas de hoy:**
> - **variable**: una etiqueta con un valor (`REGION=us-east-1`).
> - **proceso padre / hijo**: el programa que lanza otro / el programa lanzado.
> - **entorno**: las variables que recibe cada programa al arrancar, copiadas de su padre.
> - **export**: convertir una variable del shell en variable de entorno.
> - **unset**: borrar una variable.
> - **heredoc**: una forma de escribir varias líneas en un archivo desde la terminal, sin abrir un editor.
> - **PATH**: la lista de carpetas donde el shell busca los comandos.
> - **alias**: un atajo para un comando largo.
> - **source**: ejecutar un archivo en tu propio shell, no en un hijo.

## Objetivo

- Crear variables y entender la diferencia entre **variable del shell** y **variable de entorno** (`export`).
- Saber cómo encuentra Linux un comando: el **`PATH`**.
- Personalizar tu shell con `~/.bashrc`, `alias` y `source`.
- Entender las comillas: `"..."` frente a `'...'`.

## Por qué importa

La configuración de las aplicaciones modernas llega por **variables de entorno**: `DATABASE_URL`, `AWS_REGION`, `PORT`. Así lo hacen Docker, Kubernetes, GitHub Actions y AWS. La AWS CLI lee tus credenciales de `AWS_ACCESS_KEY_ID`, por ejemplo. Y "command not found" en un script que funciona en tu terminal es casi siempre un problema de `PATH`.

## Cómo va esta clase

Seis piezas. En cada una lees **un** concepto y lo pruebas enseguida en la terminal; no pases a la siguiente sin haber ejecutado la anterior. La pieza 3 (las variables de entorno) es la idea que más usarás en todo el curso: en Docker, en Kubernetes y en GitHub Actions.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 25 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

Primero, la carpeta de hoy:

```bash
mkdir -p ~/my-devops-journey/labs/clase-07 && cd ~/my-devops-journey/labs/clase-07
```

## Las piezas

### Pieza 1 — Una variable es una etiqueta con un valor

```bash
NOMBRE=valor        # crear: sin espacios alrededor del =
echo $NOMBRE        # usar: con $ delante
echo "${NOMBRE}s"   # las llaves marcan dónde acaba el nombre: imprime «valors»
```

**Pruébalo:**

```bash
REGION=us-east-1
echo $REGION
echo "${REGION}-a"
REGION = us-east-1
```

👀 **Qué deberías ver:** `us-east-1` y `us-east-1-a`. La última línea falla (`REGION: no se encontró la orden`): con espacios alrededor del `=`, el shell cree que `REGION` es un comando y que `=` y `us-east-1` son sus argumentos.

**En resumen:** `NOMBRE=valor` crea la variable (sin espacios) y `$NOMBRE` la usa.

### Pieza 2 — Comillas: tres formas de escribir un texto

| Escribes | El shell… | `USER` vale `educo` → resultado |
|----------|-----------|---------------------------------|
| `"Hola $USER"` | sustituye las variables | `Hola educo` |
| `'Hola $USER'` | no toca nada: lo deja tal cual | `Hola $USER` |
| `Hola $USER`, sin comillas | sustituye **y además parte** el resultado por los espacios | funciona aquí, pero rompe rutas con espacios |

Regla práctica: **pon siempre comillas dobles alrededor de las variables**: `"$ARCHIVO"`. Lo verás romperse en el Rómpelo 3.

**Pruébalo:**

```bash
echo "La región es $REGION"
echo 'La región es $REGION'
echo "Hoy: $(date +%F), usuario: $USER"
```

👀 **Qué deberías ver:** `La región es us-east-1`; después `La región es $REGION` tal cual, por las comillas simples; y la fecha de hoy con tu usuario: dentro de las dobles también funciona `$(…)`.

✋ **Sin mirar:** ¿qué imprime `echo 'Soy $USER'`?

<details>
<summary>Comprueba</summary>

`Soy $USER`, tal cual: las comillas simples no sustituyen nada.
</details>

**En resumen:** las dobles sustituyen las variables; las simples lo dejan tal cual. Y siempre comillas alrededor de una variable.

### Pieza 3 — Variables del shell y variables de entorno

Cada programa nace con un conjunto de variables, su *entorno*, que es una **copia** del entorno de quien lo lanzó (su padre).

```
  tu bash
  ├── COLOR=azul           ← variable del shell: solo la ve tu shell
  └── export REGION=eu     ← variable de entorno: la recibe cada programa que lances
          │
          ▼  (copia del entorno)
      programa hijo (un script, python, otro bash): ve REGION, no ve COLOR
```

- Una variable recién creada es una **variable del shell**: solo la ve tu shell.
- `export` la convierte en **variable de entorno**: desde ese momento, cada programa que lances recibe una copia.

**Pruébalo:** `bash -c '...'` lanza un shell **hijo** que ejecuta lo que hay entre comillas y termina. Es la forma más rápida de ver qué variables recibe un hijo.

🔮 **Predice:** ¿qué imprimirá el `bash -c`?

```bash
COLOR=azul
export ENTORNO=produccion
bash -c 'echo "COLOR=$COLOR  ENTORNO=$ENTORNO"'
```

<details>
<summary>Compruébalo</summary>

`COLOR=  ENTORNO=produccion`. `COLOR` era solo del shell; `ENTORNO` estaba exportada, así que el hijo la recibió.
</details>

```bash
env | grep ENTORNO
env | grep '^COLOR='      # no aparece: no es de entorno
printenv HOME
```

👀 **Qué deberías ver:** `ENTORNO=produccion`; nada para `COLOR`; y tu carpeta personal, `/home/educo`. El `^` (clase 05) pide que la línea **empiece** por `COLOR=`: sin él podría salir `COLORTERM`, otra variable que crea tu terminal.

Una variable solo para un comando, sin dejarla en tu shell (*staging* es el entorno de pruebas antes de producción):

```bash
ENTORNO=staging bash -c 'echo $ENTORNO'
echo $ENTORNO             # sigue siendo produccion
```

Así se pasan configuraciones en Docker y en CI: `PORT=8080 python3 app.py`.

Y para borrar una variable, `unset`:

```bash
unset COLOR
echo "[$COLOR]"           # []: COLOR ya no existe
```

✋ **Sin mirar:** escribes `COLOR=azul` y lanzas un script que hace `echo $COLOR`. ¿Qué imprime? ¿Y si antes hubieras hecho `export COLOR`?

<details>
<summary>Comprueba</summary>

Una línea vacía: `COLOR` era una variable del shell, no de entorno. Con `export`, el script recibe la copia e imprime `azul`.
</details>

**En resumen:** una variable sin `export` solo la ve tu shell; con `export` la heredan tus procesos hijos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, `cd ~/my-devops-journey/labs/clase-07` y a la pieza 4.

### Pieza 4 — El hijo recibe una copia: no cambia al padre

El hijo recibe una **copia** del entorno: puede cambiar la suya, pero nunca la de su padre. Cuando termina, sus cambios desaparecen con él. La excepción es `source archivo`: ejecuta el archivo **en tu propio shell**, no en un hijo.

**Pruébalo.** Primero, un truco para crear archivos de varias líneas sin abrir un editor: el *heredoc*. `cat > archivo <<'EOF'` escribe en `archivo` todo lo que pongas debajo, hasta la línea que dice `EOF`. Las comillas de `'EOF'` funcionan como las simples de la pieza 2: el `$ENTORNO` se copia tal cual al archivo, sin sustituirlo. Crea un script pequeño:

```bash
cat > cambia.sh <<'EOF'
#!/bin/bash
export ENTORNO=modificado-por-el-script
echo "Dentro del script: $ENTORNO"
EOF
chmod +x cambia.sh       # sin letra delante: x para dueño, grupo y otros
```

`#!/bin/bash` dice qué programa lee el script, como en el `hola.sh` de la clase 06 (lo verás a fondo en la clase 16).

🔮 **Predice** qué imprime cada `echo` antes de ejecutar estas líneas. La primera vuelve a dejar `ENTORNO` en `produccion`, como en la pieza 3: si la hiciste ayer, esta terminal es nueva y ya no la tenía (las variables se pierden al cerrar la terminal).

```bash
export ENTORNO=produccion
./cambia.sh
echo "En mi shell: $ENTORNO"
source cambia.sh
echo "Tras source: $ENTORNO"
```

<details>
<summary>Compruébalo</summary>

```
Dentro del script: modificado-por-el-script
En mi shell: produccion
Dentro del script: modificado-por-el-script
Tras source: modificado-por-el-script
```

`./cambia.sh` corre en un hijo: cambia **su copia** de la variable, y el cambio desaparece con él. Tu shell sigue con `produccion`. `source` ejecuta el archivo **en tu propio shell**, así que ahí sí cambia: `modificado-por-el-script`.
</details>

**En resumen:** un script cambia su copia del entorno, no el tuyo; `source` lo ejecuta en tu shell.

### Pieza 5 — El `PATH`: las carpetas donde el shell busca los comandos

`PATH` es una variable de entorno con una lista de carpetas separadas por `:`. Cuando escribes `python3`, el shell mira esas carpetas **en orden** y ejecuta el **primer** `python3` que encuentra.

```
PATH=/usr/local/bin:/usr/bin:/bin:...
       1.ª carpeta   2.ª      3.ª
```

Si no está en ninguna de esas carpetas, ves `no se encontró la orden`, aunque el programa exista en otro sitio. Por eso tus propios scripts se ejecutan con `./script.sh`: la carpeta actual (`.`) **no** está en el `PATH`, a propósito, por seguridad.

> 🔁 **Vuelve a la clase 01.** En «Qué pasa cuando pulsas Enter», el paso 3 era «el shell busca el programa en las carpetas del PATH». Ahora conoces esa lista: el shell la recorre **en orden** y se queda con el **primer** programa que encuentra. Si dos carpetas tienen un programa con el mismo nombre, gana la que va antes. Lo comprobarás en el Rómpelo 2.

**Pruébalo:**

```bash
echo $PATH
echo $PATH | tr ':' '\n'      # tr cambia cada : por un salto de línea (\n)
which python3 ls
type -a python3
```

👀 **Qué deberías ver:** tu PATH entero (largo y con repeticiones: lo verás en el Reto 5); después, una carpeta por línea; y dónde están `python3` y `ls`.

**Ahora crea tu propio comando:**

```bash
mkdir -p ~/bin
cat > ~/bin/saludo <<'EOF'
#!/bin/bash
echo "Hola, $USER. Son las $(date +%H:%M)."
EOF
chmod +x ~/bin/saludo
saludo
```

🔮 **Predice:** ¿funcionó? Si no, ¿por qué?

En Ubuntu, `~/.profile` añade `~/bin` al PATH **al iniciar sesión**, pero solo si la carpeta ya existía en ese momento. Así que aún no está:

```bash
export PATH="$HOME/bin:$PATH"
saludo
which saludo
```

👀 **Qué deberías ver:** `Hola, educo. Son las …` con la hora, y la ruta `/home/educo/bin/saludo`.

✋ **Sin mirar:** instalas un programa en `/opt/app/bin`. Escribes su nombre y sale `no se encontró la orden`. ¿Por qué?

<details>
<summary>Comprueba</summary>

`/opt/app/bin` no está en el `PATH`: el shell solo busca en esas carpetas.
</details>

**En resumen:** el shell busca cada comando en las carpetas del PATH, en orden, y usa el primero que encuentra.

### Pieza 6 — Los archivos que preparan tu shell, y los alias

| Archivo | Se lee cuando… |
|---------|----------------|
| `~/.bashrc` | abres una terminal nueva (un shell interactivo) |
| `~/.profile` | inicias sesión en el equipo (también al entrar por SSH) |

Si cambias `~/.bashrc`, las terminales que ya estaban abiertas no se enteran hasta que ejecutas `source ~/.bashrc`, que lo vuelve a leer en el shell actual. Un **alias** es un atajo para un comando largo, y su sitio para que dure es `~/.bashrc`.

**Pruébalo.** Lo de `~/bin` de la pieza 5 ya es permanente **sin tocar nada**: ahora que la carpeta existe, `~/.profile` la añadirá la próxima vez que inicies sesión. Mira el bloque que lo hace (y, cuando vuelvas a iniciar sesión, comprueba el PATH):

```bash
grep -A3 'private bin' ~/.profile     # el bloque que lo añade
echo $PATH | tr ':' '\n' | head -3
```

👀 **Qué deberías ver:** dos bloques, separados por `--`: el primero añade `~/bin` al PATH y el segundo, `~/.local/bin`. Después, las tres primeras carpetas de tu PATH.

Evita la receta que verás en muchos tutoriales, `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc`. `~/.bashrc` se ejecuta en **cada** shell nuevo, también en los que abres dentro de otro, y cada vez añade otra copia al PATH. En el Reto 5 verás un caso real.

Ahora, dos alias:

```bash
alias ll='ls -lah'
alias journey='cd ~/my-devops-journey'
ll
journey && pwd
alias                         # lista todos
```

👀 **Qué deberías ver:** la lista de `ls -lah`; después, `/home/educo/my-devops-journey`; y todos tus alias. `journey` es nuevo; `ll` ya existía en Ubuntu (`ls -alF`), y el tuyo lo sustituye en esta terminal.

Para que duren, añádelos a `~/.bashrc` con `nano ~/.bashrc` y después `source ~/.bashrc`.

**En resumen:** `~/.bashrc` se lee en cada terminal nueva; `~/.profile`, al iniciar sesión. Los alias duran si los pones en `~/.bashrc`.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `VAR=valor` · `echo "$VAR"` | crear · usar |
| `export VAR=valor` | crearla como variable de entorno |
| `VAR=valor comando` | darle la variable solo a ese comando |
| `unset VAR` | borrarla |
| `env` · `printenv VAR` | ver todas las variables de entorno · ver una |
| `echo "$PATH" \| tr ':' '\n'` | las carpetas del PATH, una por línea |
| `type -a cmd` · `which cmd` | en qué carpeta del PATH está un comando |
| `source archivo` | ejecutar un archivo en tu shell, no en un hijo |
| `alias ll='ls -lah'` | crear un atajo |

Variables que ya existen: `HOME` (tu carpeta personal), `USER` (tu usuario), `PWD` (dónde estás), `SHELL` (tu shell), `PATH` (dónde se buscan los comandos) y `?` (el código de salida del último comando, `$?`).

## Rómpelo

**1. Romper el PATH (solo en este shell):**
```bash
bash                          # un shell hijo, para poder salir sin daño
export PATH=""
ls
/usr/bin/ls                   # con la ruta completa sí funciona
exit                          # vuelves al shell padre, con el PATH intacto
ls
```
Esto pasa de verdad: una tarea de `cron` (el programa que lanza tareas a una hora fija; clase 20) o un servicio de `systemd` (clase 12) arrancan con un PATH mínimo, y un script que funciona en tu terminal falla allí con "command not found". La solución es usar rutas completas o fijar el PATH al principio del script.

**2. Suplantar un comando:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
cat > ~/bin/ls <<'EOF'
#!/bin/bash
echo "¡Este no es el ls de verdad!"
EOF
chmod +x ~/bin/ls
hash -r                        # olvida los comandos que bash recuerda
ls
type -a ls
rm ~/bin/ls && hash -r
```
Como `~/bin` va **antes** en el PATH, gana tu falso `ls`. Por eso añadir `.` o directorios con permisos de escritura para otros al principio del PATH es un riesgo de seguridad: cualquiera podría colocar un `ls` malicioso.

**3. Variables sin comillas:**
```bash
ARCHIVO="mi informe.txt"
touch "$ARCHIVO"
ls -l $ARCHIVO
ls -l "$ARCHIVO"
```
Sin comillas, el shell parte el valor en dos argumentos: `mi` e `informe.txt`.

## Reto

En `labs/clase-07/`, en la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escribe un script `entorno.sh` que imprima `Modo: <valor de APP_ENV>`, o `Modo: sin definir` si la variable está vacía.

> 🧩 **Ejemplo resuelto:** un script `saluda.sh` que imprime `Hola, <NOMBRE>`, o `Hola, desconocido` si `NOMBRE` está vacía.
> ```bash
> cat > saluda.sh <<'EOF'
> #!/bin/bash
> echo "Hola, ${NOMBRE:-desconocido}"
> EOF
> chmod +x saluda.sh
> NOMBRE=Ana ./saluda.sh
> ./saluda.sh
> ```
> `${NOMBRE:-desconocido}` significa «NOMBRE o, si está vacía, *desconocido*». Imprime `Hola, Ana` y después `Hola, desconocido`.

**Ahora tú, con huecos:**
```bash
cat > entorno.sh <<'EOF'
#!/bin/bash
echo "Modo: ${____:-sin definir}"
EOF
chmod +x entorno.sh
```

<details>
<summary>Pista</summary>

Es el ejemplo con otra variable y otro texto por defecto.
</details>

**2.** Ejecútalo tres veces: después de `export APP_ENV=desarrollo`, con `APP_ENV=produccion` solo para ese comando, y después de `unset APP_ENV`.

> 🧩 **Ejemplo resuelto:** lo mismo con `saluda.sh`.
> ```bash
> export NOMBRE=Luis; ./saluda.sh
> NOMBRE=Ana ./saluda.sh
> unset NOMBRE; ./saluda.sh
> ```
> `Hola, Luis` (está exportada), `Hola, Ana` (solo para ese comando) y `Hola, desconocido` (ya no existe).

**Ahora tú, con huecos:**
```bash
export APP_ENV=desarrollo; ./entorno.sh
APP_ENV=____ ./entorno.sh
____ APP_ENV; ./entorno.sh
```

<details>
<summary>Pista</summary>

«Solo para ese comando» es la forma `VARIABLE=valor ./script`. Y para borrar una variable, el comando del ejemplo.
</details>

**3.** Haz que el alias `journey` exista en todas tus terminales nuevas.

> 🧩 **Ejemplo resuelto:** hacer permanente el alias `ll`.
> ```bash
> nano ~/.bashrc          # al final, añade la línea:  alias ll='ls -lah'
> source ~/.bashrc
> ll
> ```
> Lo que está en `~/.bashrc` se lee en cada terminal nueva. `source` lo vuelve a leer en la que tienes abierta.

**Ahora tú, con huecos:** `alias journey='____ ~/my-devops-journey'`

<details>
<summary>Pista</summary>

Es el alias de la pieza 6. Añádelo con `nano` al final de `~/.bashrc` y pruébalo en una terminal **nueva**.
</details>

**4.** ¿En qué carpeta del PATH está `git`? ¿Y `docker`?

> 🧩 **Ejemplo resuelto:** ¿dónde está `python3`?
> ```bash
> which python3
> ```
> En tu equipo sale `/bin/python3` (en Ubuntu, `/bin` es un enlace a `/usr/bin`).

**Ahora tú, con huecos:** `which ____ ____`

<details>
<summary>Pista</summary>

`which` acepta varios nombres a la vez.
</details>

**5.** ➕ **Opcional: tu PATH real.** Cuenta las carpetas repetidas de tu PATH y busca qué líneas de `~/.bashrc` y `~/.profile` las añaden. Explica con tus palabras por qué se repiten. **No edites** esos archivos todavía.

> 🧩 **Ejemplo resuelto:** contar las palabras repetidas de una lista separada por `:`.
> ```bash
> echo "a:b:a:c:a" | tr ':' '\n' | sort | uniq -c | sort -rn
> ```
> `tr ':' '\n'` pone una palabra por línea; el resto es la cadena top-N de la clase 05. Sale `3 a` arriba.

**Ahora tú, con huecos:**
```bash
echo "$PATH" | tr ':' '\n' | ____ | uniq -c | sort -rn
grep -n ____ ~/.bashrc ~/.profile
```

<details>
<summary>Pista</summary>

El primer hueco es el que junta las líneas iguales. El segundo, la palabra que buscas en esos archivos. Para el porqué: ¿cuántas veces se lee `~/.bashrc`?
</details>

## Cierre

En `notas/fase-1/clase-07.md`:

1. ¿Qué diferencia hay entre `COLOR=azul` y `export COLOR=azul`? ¿Cuándo importa? *(2–3 líneas. Empieza así: «Sin `export`, la variable se queda en… Con `export`… Importa cuando…»)*
2. Un script funciona en tu terminal, pero desde `cron` falla con "command not found". ¿Cuál es la causa más probable y cómo lo arreglas? *(2 líneas. Empieza así: «Lo más probable es que cron tenga otro PATH… Lo arreglo usando…»)*
3. ¿Por qué no está `.` en el PATH? ¿Qué podría pasar si estuviera al principio? *(2 líneas. Empieza así: «Por seguridad: si `.` estuviera al principio, al escribir `ls` en una carpeta con un archivo llamado `ls`…»)*
4. **Repaso (clase 06, sin mirar):** ¿qué hacen `r`, `w` y `x` en un **directorio**? *(3 líneas, una por permiso. Empieza así: «`r` deja… `w` deja… `x` deja…»)*

Después, escríbeme `examíname clase-07`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Sin `export`, la variable solo existe en el shell actual. Con `export` pasa al entorno y la heredan todos los programas que lances desde ese shell. Importa cuando un programa (Python, la AWS CLI, un script) necesita leerla: si no está exportada, no la ve.

**2.** `cron` arranca los trabajos con un **entorno mínimo**: un PATH corto, sin tu `~/.bashrc` y sin tus alias. Si el comando está en un directorio que no está en ese PATH, no lo encuentra. Arreglo: rutas completas (`/usr/bin/python3`) o fijar `PATH=...` al inicio del script o del crontab.

**3.** Por seguridad: si `.` estuviera al principio, al escribir `ls` dentro de un directorio con un archivo malicioso llamado `ls` ejecutarías ese archivo con tus permisos. Sin `.`, para ejecutar algo del directorio actual tienes que escribir `./` a propósito.

**4.** `r` = listar los nombres, `w` = crear, borrar y renombrar dentro (junto con `x`), `x` = entrar y acceder a lo de dentro.

**Reto:**
```bash
cat > entorno.sh <<'EOF'
#!/bin/bash
echo "Modo: ${APP_ENV:-sin definir}"
EOF
chmod +x entorno.sh
export APP_ENV=desarrollo; ./entorno.sh
APP_ENV=produccion ./entorno.sh
unset APP_ENV; ./entorno.sh
which git docker        # /usr/bin/git, /usr/bin/docker (o /bin/…: en Ubuntu, /bin es un enlace a /usr/bin)
echo $PATH | tr ':' '\n' | sort | uniq -c | sort -rn | head
grep -n PATH ~/.bashrc ~/.profile
```
**Reto 5:** cada `export PATH="algo:$PATH"` de `~/.bashrc` se ejecuta en cada shell nuevo y añade otra copia, aunque ya esté. Un shell dentro de otro (`bash`, la terminal de VS Code, un `source ~/.bashrc`) hereda el PATH con las copias y añade más. Además, si la misma carpeta se añade en `~/.profile` y en `~/.bashrc`, se suma dos veces desde el principio. El arreglo (usa `case`, que verás en la clase 17): añadir cada carpeta **en un solo sitio** y solo si no está ya:
```bash
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;                 # ya está: no hagas nada
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
```
Las repeticiones no rompen nada (bash usa la primera que encuentra), pero ensucian el PATH y esconden el orden real de búsqueda: justo lo que necesitas ver cuando un comando "no es el que crees".
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| environment variable | variable de entorno |
| to export | exportar (pasar al entorno) |
| to source a file | ejecutar un archivo en el shell actual |
| child process | proceso hijo |
| quoting | uso de comillas |

🎙️ *"Applications should read their configuration from environment variables, not hard-coded values. That way the same code runs in dev, staging and production."*

## Fin del bloque A

Ya sabes moverte, manipular archivos, filtrar texto, leer permisos y entender tu shell. En el bloque B pasas a **administrar un servidor**. Antes, una sesión de repaso que mezcla las siete clases: es la que más fija de todo el bloque.

## Siguiente

[Repaso del bloque A](repaso-bloque-a.md)
