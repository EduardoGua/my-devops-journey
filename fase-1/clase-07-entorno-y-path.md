# Clase 07 — Variables de entorno, PATH y el shell

**Dónde:** tu Ubuntu · **Tiempo:** 60 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** cada proceso nace con una **mochila de variables**, su *entorno*, que es una copia de la de su padre. Lo que exportas viaja en la mochila de tus hijos, pero un hijo nunca puede cambiar la tuya. El `PATH` es una de esas variables: la lista ordenada de carpetas donde el shell busca cada comando que escribes.

## Objetivo

- Crear variables y entender la diferencia entre **variable del shell** y **variable de entorno** (`export`).
- Saber cómo encuentra Linux un comando: el **`PATH`**.
- Personalizar tu shell con `~/.bashrc`, `alias` y `source`.
- Entender las comillas: `"..."` frente a `'...'`.

## Por qué importa

La configuración de las aplicaciones modernas llega por **variables de entorno**: `DATABASE_URL`, `AWS_REGION`, `PORT`. Así lo hacen Docker, Kubernetes, GitHub Actions y AWS. La AWS CLI lee tus credenciales de `AWS_ACCESS_KEY_ID`, por ejemplo. Y "command not found" en un script que funciona en tu terminal es casi siempre un problema de `PATH`.

## Teoría

Cinco piezas. La 2 (la mochila) es la idea que más usarás en todo el curso: en Docker, en Kubernetes y en GitHub Actions.

### 1. Una variable es una etiqueta con un valor

```bash
NOMBRE=valor        # crear: sin espacios alrededor del =
echo $NOMBRE        # usar: con $ delante
echo "${NOMBRE}s"   # las llaves marcan dónde acaba el nombre: imprime «valors»
```

### 2. La mochila: variables del shell y variables de entorno

Cada programa nace con una **mochila de variables**, su *entorno*, que es una **copia** de la mochila de quien lo lanzó (su padre).

```
  tu bash
  ├── COLOR=azul           ← en el bolsillo: solo la ve tu shell
  └── export REGION=eu     ← en la mochila: viaja con cada programa que lances
          │
          ▼  (copia de la mochila)
      programa hijo (un script, python, otro bash): ve REGION, no ve COLOR
```

- Una variable recién creada se queda **en tu bolsillo**: solo la ve tu shell.
- `export` la mete **en la mochila**: desde ese momento, cada programa que lances recibe una copia.
- El hijo recibe una **copia**: puede cambiar la suya, pero nunca la de su padre. Cuando termina, sus cambios desaparecen con él.

### 3. El `PATH`: la lista de cajones donde el shell busca

`PATH` es una variable de la mochila con una lista de carpetas separadas por `:`. Cuando escribes `python3`, el shell abre esas carpetas **en orden**, como cajones, y ejecuta el **primer** `python3` que encuentra.

```
PATH=/usr/local/bin:/usr/bin:/bin:...
       1.º cajón     2.º      3.º
```

Si no está en ningún cajón, ves `no se encontró la orden`, aunque el programa exista en otro sitio. Por eso tus propios scripts se ejecutan con `./script.sh`: la carpeta actual (`.`) **no** es uno de los cajones, a propósito, por seguridad.

> 🔁 **Vuelve a la clase 01.** En «Qué pasa cuando pulsas Enter», el paso 3 era «el shell busca el programa en las carpetas del PATH». Ahora conoces esa lista: el shell la recorre **en orden** y se queda con el **primer** programa que encuentra. Si dos carpetas tienen un programa con el mismo nombre, gana la que va antes. Lo comprobarás en el Rómpelo 2.

### 4. Comillas: tres formas de escribir un texto

| Escribes | El shell… | `USER` vale `educo` → resultado |
|----------|-----------|---------------------------------|
| `"Hola $USER"` | sustituye las variables | `Hola educo` |
| `'Hola $USER'` | no toca nada: lo deja tal cual | `Hola $USER` |
| `Hola $USER`, sin comillas | sustituye **y además parte** el resultado por los espacios | funciona aquí, pero rompe rutas con espacios |

Regla práctica: **pon siempre comillas dobles alrededor de las variables**: `"$ARCHIVO"`. Lo verás romperse en el Rómpelo 3.

### 5. Los archivos que preparan tu shell

| Archivo | Se lee cuando… |
|---------|----------------|
| `~/.bashrc` | abres una terminal nueva (un shell interactivo) |
| `~/.profile` | inicias sesión en el equipo (también al entrar por SSH) |

Si cambias `~/.bashrc`, las terminales que ya estaban abiertas no se enteran hasta que ejecutas `source ~/.bashrc`, que lo vuelve a leer en el shell actual.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Escribes `COLOR=azul` y lanzas un script que hace `echo $COLOR`. ¿Qué imprime? ¿Y si antes hubieras hecho `export COLOR`?
2. Instalas un programa en `/opt/app/bin`. Escribes su nombre y sale `no se encontró la orden`. ¿Por qué?
3. ¿Qué imprime `echo 'Soy $USER'`?

<details>
<summary>Comprueba</summary>

1. Una línea vacía: `COLOR` estaba en el bolsillo, no en la mochila. Con `export`, el script recibe la copia e imprime `azul`. 2. `/opt/app/bin` no es uno de los cajones del `PATH`. 3. `Soy $USER`, tal cual: las comillas simples no sustituyen nada.
</details>

### Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `VAR=valor` · `echo "$VAR"` | crear · usar |
| `export VAR=valor` | meterla en la mochila |
| `VAR=valor comando` | darle la variable solo a ese comando |
| `unset VAR` | borrarla |
| `env` · `printenv VAR` | ver la mochila entera · ver una variable |
| `echo "$PATH" \| tr ':' '\n'` | los cajones del PATH, uno por línea |
| `type -a cmd` · `which cmd` | en qué cajón está un comando |
| `source archivo` | ejecutar un archivo en tu shell, no en un hijo |
| `alias ll='ls -lah'` | crear un atajo |

Variables que ya existen: `HOME` (tu casa), `USER` (tu usuario), `PWD` (dónde estás), `SHELL` (tu shell), `PATH` (los cajones) y `?` (la nota del último comando, `$?`).

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-07 && cd ~/my-devops-journey/labs/clase-07
```

### 1. Variables y comillas

```bash
REGION=us-east-1
echo $REGION
echo "La región es $REGION"
echo 'La región es $REGION'
echo "Hoy: $(date +%F), usuario: $USER"
```

### 2. El bolsillo y la mochila

`bash -c '...'` lanza un shell **hijo** que ejecuta lo que hay entre comillas y termina. Es la forma más rápida de ver qué recibe un hijo en su mochila.

🔮 **Predice:** ¿qué imprimirá el `bash -c`?

```bash
COLOR=azul
export ENTORNO=produccion
bash -c 'echo "COLOR=$COLOR  ENTORNO=$ENTORNO"'
```

<details>
<summary>Compruébalo</summary>

`COLOR=  ENTORNO=produccion`. `COLOR` estaba en el bolsillo; `ENTORNO`, en la mochila.
</details>

```bash
env | grep ENTORNO
env | grep COLOR          # no aparece: no es de entorno
printenv HOME
```

Una variable solo para un comando, sin dejarla en tu shell:
```bash
ENTORNO=staging bash -c 'echo $ENTORNO'
echo $ENTORNO             # sigue siendo produccion
```

Así se pasan configuraciones en Docker y en CI: `PORT=8080 python3 app.py`.

### 3. El hijo no cambia al padre

Primero, un truco para crear archivos de varias líneas sin abrir un editor: el *heredoc*. `cat > archivo <<'EOF'` escribe en `archivo` todo lo que pongas debajo, hasta la línea que dice `EOF`. Crea un script pequeño:

```bash
cat > cambia.sh <<'EOF'
#!/bin/bash
export ENTORNO=modificado-por-el-script
echo "Dentro del script: $ENTORNO"
EOF
chmod +x cambia.sh
```

🔮 **Predice** qué imprime cada `echo` antes de ejecutar estas líneas. Recuerda: ahora mismo `ENTORNO` vale `produccion`.

```bash
./cambia.sh
echo "En mi shell: $ENTORNO"
source cambia.sh
echo "Tras source: $ENTORNO"
```

<details>
<summary>Compruébalo</summary>

`./cambia.sh` corre en un hijo: cambia **su copia** de la mochila, y el cambio desaparece con él. Tu shell sigue con `produccion`. `source` ejecuta el archivo **en tu propio shell**, así que ahí sí cambia: `modificado-por-el-script`.
</details>

### 4. El PATH

```bash
echo $PATH
echo $PATH | tr ':' '\n'      # uno por línea
which python3 ls
type -a python3
```

Crea tu propio comando:
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

Para hacerlo permanente **no tienes que tocar nada**: ahora que `~/bin` existe, `~/.profile` lo añadirá la próxima vez que inicies sesión. Compruébalo después de cerrar sesión y volver a entrar:
```bash
grep -A3 'private bin' ~/.profile     # el bloque que lo añade
echo $PATH | tr ':' '\n' | head -3
```

Evita la receta que verás en muchos tutoriales, `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc`. `~/.bashrc` se ejecuta en **cada** shell nuevo, también en los que abres dentro de otro, y cada vez añade otra copia al PATH. En el Reto 5 verás un caso real.

### 5. Alias

```bash
alias ll='ls -lah'
alias journey='cd ~/my-devops-journey'
ll
journey && pwd
alias                         # lista todos
```

Para que duren, añádelos a `~/.bashrc` con `nano ~/.bashrc` y después `source ~/.bashrc`.

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
Esto pasa de verdad: un `cron` o un servicio de `systemd` arrancan con un PATH mínimo, y un script que funciona en tu terminal falla allí con "command not found". La solución es usar rutas completas o fijar el PATH al principio del script.

**2. Suplantar un comando:**
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

En `labs/clase-07/`, en la terminal. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Escribe un script `entorno.sh` que imprima `Modo: <valor de APP_ENV>`, o `Modo: sin definir` si la variable está vacía.

<details>
<summary>Pista</summary>

Créalo con un *heredoc*, como en la práctica 3: el shebang y una línea `echo "Modo: ${APP_ENV:-sin definir}"`. `${APP_ENV:-sin definir}` significa «APP_ENV o, si está vacía, *sin definir*». No olvides `chmod +x`.
</details>

**2.** Ejecútalo tres veces: después de `export APP_ENV=desarrollo`, con `APP_ENV=produccion` solo para ese comando, y después de `unset APP_ENV`.

<details>
<summary>Pista</summary>

«Solo para ese comando» es la forma `VARIABLE=valor ./entorno.sh`, de la práctica 2.
</details>

**3.** Haz que el alias `journey` exista en todas tus terminales nuevas.

<details>
<summary>Pista</summary>

Abre `nano ~/.bashrc`, añade al final `alias journey='cd ~/my-devops-journey'`, guarda y abre una terminal **nueva** para probarlo.
</details>

**4.** ¿En qué carpeta del PATH está `git`? ¿Y `docker`?

<details>
<summary>Pista</summary>

`which git docker`.
</details>

**5.** **Tu PATH real.** Cuenta las carpetas repetidas de tu PATH y busca qué líneas de `~/.bashrc` y `~/.profile` las añaden. Explica con tus palabras por qué se repiten. **No edites** esos archivos todavía.

<details>
<summary>Pista</summary>

Para contar, pon una carpeta por línea con `echo "$PATH" | tr ':' '\n'` y añade la cadena top-N de la clase 05 (`| sort | uniq -c | sort -rn`). Para encontrar las líneas: `grep -n PATH ~/.bashrc ~/.profile`. La clave del porqué: ¿cuántas veces se lee `~/.bashrc`?
</details>

## Cierre

En `notas/fase-1/clase-07.md`:

1. ¿Qué diferencia hay entre `COLOR=azul` y `export COLOR=azul`? ¿Cuándo importa?
2. Un script funciona en tu terminal, pero desde `cron` falla con "command not found". ¿Cuál es la causa más probable y cómo lo arreglas?
3. ¿Por qué no está `.` en el PATH? ¿Qué podría pasar si estuviera al principio?
4. **Repaso (clase 06, sin mirar):** ¿qué hacen `r`, `w` y `x` en un **directorio**?

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
