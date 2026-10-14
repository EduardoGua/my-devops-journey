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

### Variables

```bash
NOMBRE=valor        # sin espacios alrededor del =
echo $NOMBRE
echo "${NOMBRE}s"   # las llaves delimitan el nombre
```

### Shell frente a entorno

```
  bash (tu shell)
  ├── variable del shell:  COLOR=azul         ← solo existe en este shell
  └── variable de entorno: export REGION=eu   ← se HEREDA a cada programa que lanzas
          │
          ▼
      programa hijo (python, otro bash, un script): ve REGION, no ve COLOR
```

Cada proceso recibe una **copia** del entorno de su padre. Un hijo nunca puede cambiar el entorno del padre.

### Variables que ya existen

| Variable | Contiene |
|----------|----------|
| `HOME` | tu casa (`/home/educo`) |
| `USER` | tu usuario |
| `PWD` | directorio actual |
| `SHELL` | tu shell por defecto |
| `PATH` | dónde se buscan los comandos |
| `?` | código de salida del último comando (`$?`) |

### El PATH

`PATH` es una lista de directorios separados por `:`. Cuando escribes `python3`, bash lo busca **en orden** en esos directorios y ejecuta el primero que encuentra.

```
PATH=/usr/local/bin:/usr/bin:/bin:...
       1.º           2.º      3.º
```

Si no está en ninguno, ves `command not found` (en tu Ubuntu, `no se encontró la orden`), aunque el programa exista en otro sitio. Por eso un script propio se ejecuta con `./script.sh`: `.` (el directorio actual) **no** está en el PATH, a propósito, por seguridad.

> 🔁 **Vuelve a la clase 01.** En «Qué pasa cuando pulsas Enter», el paso 3 era «el shell busca el programa en las carpetas del PATH». Ahora conoces esa lista: el shell la recorre **en orden** y se queda con el **primer** programa que encuentra. Si dos carpetas tienen un programa con el mismo nombre, gana la que va antes. Lo comprobarás en el Rómpelo 2.

### Comillas

| Forma | Efecto | Ejemplo |
|-------|--------|---------|
| `"..."` | expande variables y `$(...)` | `"Hola $USER"` → `Hola educo` |
| `'...'` | literal, no expande nada | `'Hola $USER'` → `Hola $USER` |
| sin comillas | expande y además **parte por espacios** | peligroso con rutas que tengan espacios |

Regla práctica: **usa siempre comillas dobles alrededor de las variables**: `"$ARCHIVO"`.

### Archivos de arranque

| Archivo | Se lee cuando… |
|---------|----------------|
| `~/.bashrc` | abres un shell interactivo (cada terminal nueva) |
| `~/.profile` | inicias sesión (login, también por SSH) |

Cambiar `~/.bashrc` no afecta a las terminales ya abiertas hasta que ejecutas `source ~/.bashrc`, que lo lee de nuevo en el shell actual.

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

### 2. Shell frente a entorno

🔮 **Predice:** ¿qué imprimirá cada `bash -c`?

```bash
COLOR=azul
export ENTORNO=produccion
bash -c 'echo "COLOR=$COLOR  ENTORNO=$ENTORNO"'
```

`bash -c '...'` lanza un shell **hijo**: solo ve lo exportado.

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

```bash
cat > cambia.sh <<'EOF'
#!/bin/bash
export ENTORNO=modificado-por-el-script
echo "Dentro del script: $ENTORNO"
EOF
chmod +x cambia.sh
./cambia.sh
echo "En mi shell: $ENTORNO"
source cambia.sh
echo "Tras source: $ENTORNO"
```

`./cambia.sh` corre en un proceso hijo: su cambio muere con él. `source` ejecuta el archivo **en tu shell actual**. (El `<<'EOF' ... EOF` se llama *heredoc*: escribe varias líneas en un archivo de una vez.)

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

1. Exporta `APP_ENV=desarrollo` y escribe un script `entorno.sh` que imprima `Modo: <valor>`, o `Modo: sin definir` si la variable está vacía. Pista: `${APP_ENV:-sin definir}`.
2. Ejecútalo tres veces: normal, con `APP_ENV=produccion` solo para ese comando y después de `unset APP_ENV`.
3. Añade a tu `~/.bashrc` el alias `journey` y comprueba que existe en una terminal **nueva**.
4. ¿En qué directorio del PATH está `git`? ¿Y `docker`?
5. **Tu PATH real.** Los instaladores de herramientas suelen añadir líneas a `~/.bashrc` y `~/.profile`. Cuenta las entradas repetidas de tu PATH con el patrón top-N de la clase 05 y busca qué líneas las añaden (`grep -n PATH ~/.bashrc ~/.profile`). Explica por qué se repiten y escribe cómo lo arreglarías. **No edites aún** esos archivos: primero entiende el problema.

## Cierre

En `notas/fase-1/clase-07.md`:

1. ¿Qué diferencia hay entre `COLOR=azul` y `export COLOR=azul`? ¿Cuándo importa?
2. Un script funciona en tu terminal, pero desde `cron` falla con "command not found". ¿Cuál es la causa más probable y cómo lo arreglas?
3. ¿Por qué no está `.` en el PATH? ¿Qué podría pasar si estuviera al principio?
4. **Repaso (clase 06, sin mirar):** ¿qué hacen `r`, `w` y `x` en un **directorio**?

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
**Reto 5:** cada `export PATH="algo:$PATH"` de `~/.bashrc` se ejecuta en cada shell nuevo y añade otra copia, aunque ya esté. Un shell dentro de otro (`bash`, la terminal de VS Code, un `source ~/.bashrc`) hereda el PATH con las copias y añade más. Además, si la misma carpeta se añade en `~/.profile` y en `~/.bashrc`, se suma dos veces desde el principio. El arreglo: añadir cada carpeta **en un solo sitio** y solo si no está ya:
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
