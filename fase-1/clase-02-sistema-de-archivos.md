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

## Teoría

### Un solo árbol

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

**"En Linux todo es un archivo."** Un disco es `/dev/nvme0n1`, la información de tu CPU se lee en `/proc/cpuinfo` y un proceso es un directorio en `/proc/<número>`. Esta idea explica muchas cosas más adelante.

### Rutas

| Ruta | Significado | Ejemplo |
|------|-------------|---------|
| **Absoluta** | Empieza por `/`. Funciona desde cualquier sitio | `/var/log/syslog` |
| **Relativa** | No empieza por `/`. Parte de donde estás (`pwd`) | `notas/fase-1` |
| `.` | El directorio actual | `./script.sh` |
| `..` | El directorio **padre**: un nivel arriba. **No es la raíz** | `cd ..` |
| `~` | Tu casa (`/home/educo`) | `cd ~/my-devops-journey` |
| `-` | (solo con `cd`) el directorio anterior | `cd -` |

> ⚠️ Error típico: confundir `..` (subir **un** nivel) con `/` (ir **arriba del todo**). Desde `/home/educo/a/b`, `cd ..` te deja en `/home/educo/a`, no en `/`.

### Archivos ocultos

Un archivo cuyo nombre empieza por `.` está oculto: `.bashrc`, `.ssh/`, `.git/`. No es seguridad, solo orden: `ls` no los muestra salvo que uses `-a`.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. ¿En qué carpeta buscarías la configuración de un programa? ¿Y sus logs?
2. Estás en `/home/educo/proyectos`. ¿A dónde te lleva `cd ..`?
3. ¿Qué tiene de especial un archivo llamado `.bashrc`?

<details>
<summary>Comprueba</summary>

1. La configuración en `/etc`; los logs en `/var/log`. 2. A `/home/educo`: sube **un** nivel, no a la raíz. 3. Empieza por punto: está **oculto**, y `ls` solo lo muestra con `-a`.
</details>

### Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `pwd` | dónde estoy |
| `cd ruta` · `cd ..` · `cd -` · `cd` | ir a una ruta · subir un nivel · volver a la anterior · ir a tu casa |
| `ls -a` · `ls -l` · `ls -lh` · `ls -lt` | ver ocultos · detalles · tamaños legibles · por fecha |
| `ls -ld carpeta` | los detalles de la carpeta, no de lo que hay dentro |
| `tree` | el árbol de una carpeta |
| `cat archivo` | ver un archivo |

## Práctica guiada

### 1. Recorre el árbol

```bash
cd /
ls
ls -l
cd /etc
ls | head -30
ls -l /etc/hostname /etc/os-release
cat /etc/hostname
```

```bash
ls /var/log
ls -lh /var/log | head
cat /proc/cpuinfo | head -20
cat /proc/meminfo | head -5
```

`/proc/cpuinfo` no es un archivo guardado en disco: el kernel genera su contenido en el momento en que lo lees.

### 2. Tu laboratorio

```bash
cd ~/my-devops-journey
mkdir -p labs/clase-02/casa/cocina/cajon labs/clase-02/casa/salon labs/clase-02/garaje
cd labs/clase-02
tree
```

(`mkdir -p` crea toda la ruta de una vez; lo verás en la clase 03.)

### 3. Navega prediciendo

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

El último `cd ..` deja `pwd` en `/`: el padre de la raíz es la propia raíz.

### 4. Listar con criterio

```bash
cd ~
ls
ls -a          # aparecen los ocultos (y . y ..)
ls -la
ls -lah        # tamaños legibles
ls -lt | head  # ordenado por fecha, lo más reciente arriba
ls -ld ~/.ssh  # -d: información del directorio, no de su contenido
```

Lee una línea de `ls -l`:

```
-rw-r--r-- 1 educo educo 3771 Sep 20 10:12 .bashrc
│└──┬────┘ │ └─┬─┘ └─┬─┘ └┬─┘ └────┬─────┘ └──┬──┘
│ permisos │ dueño grupo tamaño   fecha     nombre
│          └── nº de enlaces
└── tipo: - archivo, d directorio, l enlace simbólico
```

Los permisos se ven a fondo en la clase 06.

### 5. Enlaces simbólicos

```bash
ls -l /bin
ls -l /usr/bin/python3
```

`/bin -> usr/bin` significa que `/bin` es un **enlace simbólico**, un acceso directo a `usr/bin`.

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

En la terminal. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Desde `~/my-devops-journey/labs/clase-02/casa/cocina/cajon`, escribe una ruta **relativa** que te lleve a `garaje`. Escribe también la **absoluta**.

<details>
<summary>Pista</summary>

Cuenta cuántas carpetas tienes que subir desde `cajon` hasta llegar a `clase-02`: cada subida es un `..`, separados por `/`. Desde ahí, bajas a `garaje`. La absoluta empieza por `~/my-devops-journey/…`.
</details>

**2.** ¿Qué tamaño tiene `/etc/passwd`? Muéstralo en formato legible.

<details>
<summary>Pista</summary>

`ls -l` da el tamaño en bytes. ¿Qué letra añadías en la práctica 4 para verlo en K, M o G?
</details>

**3.** ¿Cuál es el archivo más reciente de `/var/log`?

<details>
<summary>Pista</summary>

`ls -lt` ordena por fecha, con lo más reciente arriba. Con `| head` ves solo el principio, como en la práctica 4.
</details>

**4.** ¿A dónde apunta el enlace `/usr/bin/python3`?

<details>
<summary>Pista</summary>

`ls -l` de un enlace enseña una flecha `->` hacia su destino.
</details>

**5.** En `/etc` hay un archivo que dice qué servidores DNS usa la máquina. Su nombre empieza por `resolv`. Encuéntralo y averigua si es un archivo normal o un enlace.

<details>
<summary>Pista</summary>

`ls /etc` y busca con la vista un nombre que empiece por `resolv`. Después, `ls -l` de ese archivo: ¿la línea empieza por `l` (enlace) o por `-` (archivo)?
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

**Reto:** 1) `cd ../../../garaje` · `cd ~/my-devops-journey/labs/clase-02/garaje` (o con `/home/educo/...`) · 2) `ls -lh /etc/passwd` · 3) `ls -lt /var/log | head -2` · 4) `ls -l /usr/bin/python3` → `python3.x` · 5) `ls -l /etc/resolv.conf`: es un **enlace** (a `../run/systemd/resolve/stub-resolv.conf`). Lo verás en la clase de DNS.
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
