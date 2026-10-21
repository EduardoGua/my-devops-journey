# Clase 02 — El sistema de archivos y las rutas

**Dónde:** tu Ubuntu · **Tiempo:** 60 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** Linux guarda todo en **un único árbol** que empieza en `/`, y cada cosa vive en su barrio: la configuración en `/etc`, los logs en `/var/log`, tus archivos en `/home`. Una ruta es una dirección: la **absoluta** funciona desde cualquier sitio, como una dirección postal completa; la **relativa** depende de dónde estás, como «la tercera puerta a la derecha».

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Escribir comandos con opciones y argumentos (clase 01).
> - `pwd` dice dónde estás (clase 01).
> - `man` y `--help` para pedir ayuda (clase 01).

> 🔤 **Palabras nuevas de hoy:**
> - **raíz** (`/`): el principio del único árbol de carpetas.
> - **ruta absoluta / relativa**: desde la raíz / desde donde estás.
> - **directorio padre** (`..`): la carpeta de un nivel más arriba.
> - **oculto**: un archivo cuyo nombre empieza por punto (`.bashrc`).
> - **enlace simbólico**: un acceso directo a otro archivo o carpeta.
> - **montar**: colgar un disco de una carpeta del árbol.

## Objetivo

- Conocer el árbol de directorios de Linux y **qué vive en cada sitio** de un servidor.
- Moverte con rutas absolutas y relativas sin perderte: `.`, `..`, `~` y `-`.
- Listar con criterio: archivos ocultos, tamaños, fechas.

## Por qué importa

Cuando algo falla en un servidor, la primera pregunta es "¿dónde está la configuración?" y la segunda "¿dónde están los logs?". La respuesta casi siempre es `/etc` y `/var/log`. Si conoces el árbol, en un servidor que nunca has visto sabrás dónde mirar en segundos.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida en la terminal; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

## Las piezas

### Pieza 1 — Un solo árbol

En Windows hay `C:\`, `D:\`… En Linux hay **un único árbol** que empieza en `/` (la **raíz**). Discos, USBs y discos de red se "cuelgan" (montan) en alguna rama de ese árbol.

```
/                      ← la raíz: todo cuelga de aquí
├── etc/               ← CONFIGURACIÓN del sistema y servicios (nginx, ssh, usuarios)
├── var/               ← datos que CAMBIAN
│   ├── log/           ←   logs ← aquí mirarás en cada incidente
│   └── lib/           ←   datos de programas (bases de datos, docker…)
├── home/              ← carpetas personales de los usuarios
│   └── educo/         ←   tu casa = ~
├── root/              ← la casa del usuario root (NO es lo mismo que /)
├── tmp/               ← temporales; se vacía al reiniciar
├── usr/               ← programas instalados
│   ├── bin/           ←   comandos (ls, grep, python3…)
│   └── share/         ←   documentación, man, etc.
├── opt/               ← software de terceros instalado "a mano"
├── bin, sbin, lib     ← en Ubuntu son enlaces a /usr/bin, /usr/sbin, /usr/lib
├── boot/              ← el kernel y el arranque
├── dev/               ← dispositivos como archivos (discos: /dev/sda, /dev/nvme0n1)
├── proc/  sys/        ← archivos VIRTUALES: ventanas al kernel (procesos, hardware)
└── mnt/  media/       ← puntos donde se montan otros discos o USBs
```

**Pruébalo:**

```bash
cd /
ls
cd /etc
ls | head -30
cat /etc/hostname
ls /var/log
ls -lh /var/log | head
```

👀 **Qué deberías ver:** en `/`, los directorios del árbol de arriba (`bin`, `boot`, `dev`, `etc`, `home`…). En `/etc`, decenas de nombres de configuración (`hostname`, `hosts`, `passwd`, `ssh`…), y `cat /etc/hostname` imprime el nombre de tu máquina, el mismo del prompt. En `/var/log`, los logs del sistema: `syslog`, `auth.log`, `apt/`…

✋ **Sin mirar:** ¿en qué carpeta buscarías la configuración de un programa? ¿Y sus logs?

<details>
<summary>Comprueba</summary>

La configuración en `/etc`; los logs en `/var/log`.
</details>

**En resumen:** un solo árbol desde `/`; la configuración en `/etc` y los logs en `/var/log`.

### Pieza 2 — "En Linux todo es un archivo"

Un disco es `/dev/nvme0n1`, la información de tu CPU se lee en `/proc/cpuinfo` y un proceso es un directorio en `/proc/<número>`. `/proc` y `/sys` no están en el disco: son **virtuales**, ventanas al kernel. Esta idea explica muchas cosas más adelante.

**Pruébalo:**

```bash
cat /proc/cpuinfo | head -20
cat /proc/meminfo | head -5
ls /dev | head
```

👀 **Qué deberías ver:** en `/proc/cpuinfo`, líneas como `processor : 0` y `model name : Intel(R) Core(TM) i5-10210U CPU @ 1.60GHz` (o tu procesador); en `/proc/meminfo`, `MemTotal:` y `MemFree:` en kB; y en `/dev`, nombres de dispositivos. `/proc/cpuinfo` no es un archivo guardado en disco: el kernel genera su contenido en el momento en que lo lees.

✋ **Sin mirar:** ¿dónde está guardado de verdad el contenido de `/proc/meminfo`?

<details>
<summary>Comprueba</summary>

En ningún sitio: el kernel lo genera cada vez que lo lees. Es una ventana al kernel con forma de archivo.
</details>

**En resumen:** dispositivos, procesos e información del sistema se leen como archivos.

### Pieza 3 — Rutas absolutas y relativas

| Ruta | Significado | Ejemplo |
|------|-------------|---------|
| **Absoluta** | Empieza por `/`. Funciona desde cualquier sitio | `/var/log/syslog` |
| **Relativa** | No empieza por `/`. Parte de donde estás (`pwd`) | `notas/fase-1` |
| `.` | El directorio actual | `./script.sh` |
| `..` | El directorio **padre**: un nivel arriba. **No es la raíz** | `cd ..` |
| `~` | Tu casa (`/home/educo`) | `cd ~/my-devops-journey` |
| `-` | (solo con `cd`) el directorio anterior | `cd -` |

> ⚠️ Error típico: confundir `..` (subir **un** nivel) con `/` (ir **arriba del todo**). Desde `/home/educo/a/b`, `cd ..` te deja en `/home/educo/a`, no en `/`.

**Pruébalo.** Tu laboratorio (`mkdir -p` crea toda la ruta de una vez; lo verás en la clase 03):

```bash
cd ~/my-devops-journey
mkdir -p labs/clase-02/casa/cocina/cajon labs/clase-02/casa/salon labs/clase-02/garaje
cd labs/clase-02
tree
```

Empieza en `~/my-devops-journey/labs/clase-02`. Para cada línea, 🔮 **predice** dónde acabarás y comprueba con `pwd`:

```bash
cd casa/cocina/cajon      # relativa
pwd
cd ..
pwd
cd ../..
pwd
cd casa/salon/../cocina   # .. también funciona en medio de una ruta
pwd
cd -
pwd
cd
pwd
cd ~/my-devops-journey/labs/clase-02/garaje   # absoluta (~ se convierte en /home/educo)
pwd
cd /
pwd
cd ..                     # ¿qué hay por encima de la raíz?
pwd
```

👀 **Qué deberías ver:** `tree` dibuja `casa` (con `cocina/cajon` y `salon`) y `garaje`. Los `pwd`, en orden: `…/casa/cocina/cajon`, `…/casa/cocina`, `…/labs/clase-02`, `…/casa/cocina`, otra vez `…/labs/clase-02` (`cd -` vuelve al anterior), `/home/educo`, `…/garaje`, `/` y `/`. El último `cd ..` deja `pwd` en `/`: el padre de la raíz es la propia raíz.

✋ **Sin mirar:** estás en `/home/educo/proyectos`. ¿A dónde te lleva `cd ..`?

<details>
<summary>Comprueba</summary>

A `/home/educo`: sube **un** nivel, no a la raíz.
</details>

**En resumen:** la absoluta empieza por `/`; la relativa, desde donde estás; `..` sube uno.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, `cd ~/my-devops-journey/labs/clase-02` y a la pieza 4.

### Pieza 4 — Listar con criterio, y los ocultos

Un archivo cuyo nombre empieza por `.` está **oculto**: `.bashrc`, `.ssh/`, `.git/`. No es seguridad, solo orden: `ls` no los muestra salvo que uses `-a`.

Cada línea de `ls -l` se lee así:

```
-rw-r--r-- 1 educo educo 3771 Sep 20 10:12 .bashrc
│└──┬────┘ │ └─┬─┘ └─┬─┘ └┬─┘ └────┬─────┘ └──┬──┘
│ permisos │ dueño grupo tamaño   fecha     nombre
│          └── nº de enlaces
└── tipo: - archivo, d directorio, l enlace simbólico
```

Los permisos se ven a fondo en la clase 06.

**Pruébalo:**

```bash
cd ~
ls
ls -a          # aparecen los ocultos (y . y ..)
ls -la
ls -lah        # tamaños legibles
ls -lt | head  # ordenado por fecha, lo más reciente arriba
ls -ld ~/.ssh  # -d: información del directorio, no de su contenido
```

👀 **Qué deberías ver:** `ls -a` añade `.`, `..`, `.bashrc`, `.ssh` y otros ocultos. Con `-h`, los tamaños salen como `3,1K` (con coma: tu sistema está en español). Y `ls -ld ~/.ssh` da **una** línea, la de la carpeta: `drwx------ … /home/educo/.ssh`, que empieza por `d`, de directorio.

✋ **Sin mirar:** ¿qué tiene de especial un archivo llamado `.bashrc`?

<details>
<summary>Comprueba</summary>

Empieza por punto: está **oculto**, y `ls` solo lo muestra con `-a`.
</details>

**En resumen:** `-a` para los ocultos, `-l` para los detalles, `-h` para tamaños legibles, `-t` por fecha y `-d` para la carpeta misma.

### Pieza 5 — Enlaces simbólicos

Un **enlace simbólico** es un acceso directo: un archivo que apunta a otro archivo o carpeta. En `ls -l`, su línea empieza por `l` y lleva una flecha `->` hacia su destino.

**Pruébalo:**

```bash
ls -l /bin
ls -l /usr/bin/python3
```

👀 **Qué deberías ver:** `lrwxrwxrwx 1 root root 7 … /bin -> usr/bin`: `/bin` es un **enlace simbólico**, un acceso directo a `usr/bin`. Y `/usr/bin/python3 -> python3.14`: el nombre genérico apunta a la versión instalada.

✋ **Sin mirar:** en `ls -l`, ¿cómo distingues un enlace de un archivo normal?

<details>
<summary>Comprueba</summary>

Por la primera letra de la línea (`l` en lugar de `-`) y por la flecha `->` hacia su destino.
</details>

**En resumen:** un enlace es un acceso directo: `l` al principio y `->` al final.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `pwd` | dónde estoy |
| `cd ruta` · `cd ..` · `cd -` · `cd` | ir a una ruta · subir un nivel · volver a la anterior · ir a tu casa |
| `ls -a` · `ls -l` · `ls -lh` · `ls -lt` | ver ocultos · detalles · tamaños legibles · por fecha |
| `ls -ld carpeta` | los detalles de la carpeta, no de lo que hay dentro |
| `tree` | el árbol de una carpeta |
| `cat archivo` | ver un archivo |

## Rómpelo

```bash
cd ~/my-devops-journey/labs/clase-02
cd garaje/coche              # no existe
touch nota.txt
cd nota.txt                  # no es un directorio
mkdir "mi carpeta"
cd mi carpeta                # los espacios separan argumentos
cd "mi carpeta" && pwd && cd ..
cd mi\ carpeta && pwd && cd ..
```

Los espacios en los nombres dan problemas: el shell usa el espacio para separar argumentos. Usa comillas o `\`, y mejor aún: **no pongas espacios en nombres de archivo**. En servidores se usan guiones: `mi-carpeta`.

Después de cualquier `cd` que falle, ejecuta `pwd` antes de seguir. Un `cd` fallido seguido de un comando destructivo es un incidente clásico: el comando se ejecuta en el directorio equivocado.

## Reto

En la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Desde `~/my-devops-journey/labs/clase-02/casa/cocina/cajon`, escribe una ruta **relativa** que te lleve a `garaje`. Escribe también la **absoluta**.

> 🧩 **Ejemplo resuelto:** desde `casa/cocina/cajon`, a `salon`.
> ```bash
> cd ../../salon
> ```
> Dos subidas (`cajon` → `cocina` → `casa`) y una bajada a `salon`. La absoluta: `cd ~/my-devops-journey/labs/clase-02/casa/salon`.

**Ahora tú, con huecos:** relativa `cd ____/garaje`; absoluta `cd ~/my-devops-journey/labs/clase-02/____`.

<details>
<summary>Pista</summary>

Cuenta cuántas carpetas tienes que subir desde `cajon` hasta llegar a `clase-02`: cada subida es un `..`, separados por `/`. Desde ahí, bajas a `garaje`.
</details>

**2.** ¿Qué tamaño tiene `/etc/passwd`? Muéstralo en formato legible.

> 🧩 **Ejemplo resuelto:** el tamaño de `/etc/hostname`, en bytes.
> ```bash
> ls -l /etc/hostname
> ```
> El número antes de la fecha: `41`, 41 bytes.

**Ahora tú, con huecos:** `ls -l____ /etc/passwd` → «ocupa ____».

<details>
<summary>Pista</summary>

¿Qué letra añadías en la pieza 4 para ver los tamaños en K, M o G?
</details>

**3.** ¿Cuál es el archivo más reciente de `/var/log`?

> 🧩 **Ejemplo resuelto:** el archivo más reciente de tu casa: `ls -lt ~ | head -2`. La primera línea es el total; la segunda, lo más reciente.

**Ahora tú, con huecos:** `ls -l____ /var/log | head -____` → «el más reciente es ____».

<details>
<summary>Pista</summary>

`ls -lt` ordena por fecha, con lo más reciente arriba, como en la pieza 4.
</details>

**4.** ¿A dónde apunta el enlace `/usr/bin/python3`?

> 🧩 **Ejemplo resuelto:** la pieza 5: `ls -l /bin` → `/bin -> usr/bin`.

**Ahora tú, con huecos:** `ls -l ____` → «apunta a ____».

<details>
<summary>Pista</summary>

`ls -l` de un enlace enseña una flecha `->` hacia su destino.
</details>

**5.** En `/etc` hay un archivo que dice qué servidores DNS usa la máquina. Su nombre empieza por `resolv`. Encuéntralo y averigua si es un archivo normal o un enlace.

> 🧩 **Ejemplo resuelto:** `/etc/os-release`, de la clase 01.
> ```bash
> ls -l /etc/os-release
> ```
> La línea empieza por `l` y termina en `-> ../usr/lib/os-release`: es un enlace.

**Ahora tú, con huecos:** `ls /etc | grep ____` para encontrar el nombre, y `ls -l /etc/____` → «es un ____, que apunta a ____».

<details>
<summary>Pista</summary>

`grep resolv` deja solo las líneas que contienen esa palabra (lo verás a fondo en la clase 05). Después, mira si la línea de `ls -l` empieza por `l` o por `-`.
</details>

## Cierre

En `notas/fase-1/clase-02.md`:

1. ¿Qué es `..` y en qué se diferencia de `/`? Da un ejemplo con rutas reales. *(2 líneas. Empieza así: «`..` es… y `/` es… Por ejemplo, desde `/home/educo/proyectos`…»)*
2. Llegas a un servidor desconocido con una web caída. ¿En qué dos directorios miras primero y por qué? *(2 líneas. Empieza así: «En `/etc`, porque ahí está…; y en `/var/log`, porque…»)*
3. ¿Qué tienen de especial `/proc` y `/dev`? ¿Qué significa "en Linux todo es un archivo"? *(2–3 líneas. Empieza así: «No están en el disco: los genera… `/proc`… `/dev`… «Todo es un archivo» significa…»)*
4. **Repaso (clase 01, sin mirar):** ¿Qué hace el shell y en qué se diferencia de la terminal? *(2 líneas. Empieza así: «El shell es el programa que… La terminal es…»)*

Después, escríbeme `examíname clase-02`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `..` es el directorio **padre**, un nivel por encima de donde estás. `/` es la **raíz**, el inicio absoluto del árbol. Desde `/home/educo/proyectos`, `cd ..` te deja en `/home/educo`, mientras que `cd /` te lleva a `/`. Solo coinciden cuando ya estás en `/`.

**2.** `/etc`, para ver la configuración del servicio (por ejemplo `/etc/nginx/`), y `/var/log`, para leer sus logs (por ejemplo `/var/log/nginx/error.log`). La configuración te dice cómo *debería* funcionar y el log te dice qué *pasó*.

**3.** Son sistemas de archivos **virtuales**: no están en el disco. `/proc` expone procesos e información del kernel (`/proc/cpuinfo`, `/proc/<PID>/`) y `/dev` representa dispositivos (discos, terminales). "Todo es un archivo" significa que Linux ofrece casi todo (dispositivos, procesos, información del sistema) con la misma interfaz que un archivo, así que con `cat`, `ls` o `echo` puedes inspeccionar y a veces controlar el sistema.

**4.** El shell es un programa (bash) que interpreta lo que escribes y lanza programas pidiéndoselo al kernel. La terminal es solo la ventana que muestra texto y recibe teclas.

**Reto:** 1) `cd ../../../garaje` · `cd ~/my-devops-journey/labs/clase-02/garaje` (o con `/home/educo/...`) · 2) `ls -lh /etc/passwd` → unos `3,1K` · 3) `ls -lt /var/log | head -2` · 4) `ls -l /usr/bin/python3` → `python3.14` · 5) `ls /etc | grep resolv` da `resolv.conf`, y `ls -l /etc/resolv.conf` muestra que es un **enlace** (a `../run/systemd/resolve/stub-resolv.conf`). Lo verás en la clase de DNS (31).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| root directory | el directorio raíz `/` |
| home directory | tu carpeta personal `~` |
| absolute / relative path | ruta absoluta / relativa |
| parent directory | directorio padre `..` |
| symlink (symbolic link) | enlace simbólico |
| mount point | punto de montaje |

🎙️ *"On a server I usually check `/etc` for the configuration and `/var/log` for what actually happened."*

## Siguiente

[Clase 03 — Archivos y directorios](clase-03-archivos-y-directorios.md)
