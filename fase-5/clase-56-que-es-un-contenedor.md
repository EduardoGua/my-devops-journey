# Clase 56 — Qué es un contenedor de verdad

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** un contenedor no es una máquina pequeña: es **un proceso normal de Linux** al que el kernel le cambia lo que ve (*namespaces*) y le limita lo que gasta (*cgroups*), y que arranca con el sistema de archivos de una **imagen**. Comparte el kernel de tu Ubuntu: por eso arranca en milisegundos, y por eso aísla menos que una máquina virtual.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Qué hace el kernel (clase 01) y qué es `/etc/os-release` (clase 02).
> - Los procesos, su PID y `ps` (clase 11); el consumo de memoria y CPU (clase 14).
> - La máquina virtual con Multipass sobre el hipervisor KVM (clase 08).
> - Usuarios, grupos, `id` y por qué root lo puede todo (clase 09).

> 🔤 **Palabras nuevas de hoy:**
> - **contenedor**: un proceso aislado que arranca desde una imagen.
> - **imagen**: el sistema de archivos (programas y librerías) con el que arranca un contenedor, en capas de solo lectura.
> - ***namespace*** (espacio de nombres): lo que cambia lo que un proceso **ve**: sus procesos, su hostname, su red, sus archivos.
> - ***cgroup*** (grupo de control): lo que limita lo que un proceso **gasta**: memoria, CPU, número de procesos.
> - **demonio** (`dockerd`): el servicio, que corre como root, que crea y gestiona los contenedores.
> - **socket**: el archivo especial por el que el cliente `docker` habla con el demonio.

## Objetivo

- Entender que un contenedor es **un proceso normal de Linux**, aislado con *namespaces* y limitado con *cgroups*, que arranca desde el sistema de archivos de una imagen.
- Distinguir un contenedor de una máquina virtual (clase 08).
- Conocer las piezas de Docker: cliente, demonio, `containerd` y `runc`.
- Instalar Docker Compose y `buildx`, que te faltan, y comprobar tu instalación.
- Saber por qué estar en el grupo `docker` equivale a ser root.

## Por qué importa

Docker parece magia hasta que ves que no lo es: un contenedor es Linux con otra interfaz, como prometía el plan (idea 1). Quien entiende esto diagnostica en minutos lo que a otros les lleva horas: por qué un contenedor no ve un archivo, por qué no conecta con otro o por qué lo mató el kernel. Y en la nube todo se despliega en contenedores: ECS, EKS, Kubernetes (fase 9), los runners de GitHub Actions (fase 7). En esta fase empaquetas Vigía para que funcione igual en tu portátil, en AWS y en Kubernetes.

## Cómo va esta clase

Cuatro piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, la preparación y las **piezas 1 y 2** (unos 40 min); el segundo, las **piezas 3 y 4**, el Rómpelo, el reto y el cierre.

**Preparación: completa tu instalación.** Docker ya está en tu Ubuntu desde la fase 0, pero le faltan dos complementos que usarás en esta fase: Compose (varios contenedores a la vez, clase 62) y `buildx` (el constructor moderno de imágenes).

```bash
mkdir -p ~/my-devops-journey/labs/clase-56 && cd ~/my-devops-journey/labs/clase-56
docker version --format 'cliente {{.Client.Version}} · servidor {{.Server.Version}}'
docker compose version
sudo apt install -y docker-compose-v2 docker-buildx
docker compose version
docker buildx version
docker info --format 'almacenamiento: {{.Driver}} · cgroups v{{.CgroupVersion}}'
```

👀 **Qué deberías ver:** las versiones del cliente y del servidor (29.x); el primer `docker compose version` falla con `unknown command`: es lo que acabas de instalar. Después, las versiones de Compose y `buildx`, y `almacenamiento: overlayfs · cgroups v2`.

## Las piezas

### Pieza 1 — Una VM frente a un contenedor

```
        Máquina virtual (clase 08)                     Contenedor
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│ app                              │   │ app        app        app        │
│ librerías                        │   │ libs       libs       libs       │
│ SU PROPIO kernel                 │   │ (cada uno ve su propio "sistema")│
├──────────────────────────────────┤   ├──────────────────────────────────┤
│ hipervisor (KVM)                 │   │ kernel del host, COMPARTIDO      │
├──────────────────────────────────┤   ├──────────────────────────────────┤
│ hardware                         │   │ hardware                         │
└──────────────────────────────────┘   └──────────────────────────────────┘
```

Una VM arranca un sistema operativo entero: segundos o minutos y cientos de MB de RAM. Un contenedor es un proceso más del host: arranca en milisegundos y gasta lo que gaste la aplicación. El precio: comparte el kernel del host, así que aísla menos que una VM. Lo que sí trae el contenedor es su **imagen**: el sistema de archivos (Alpine, Debian, Python 3.14…) con el que arranca.

🔮 **Predice** antes de ejecutar: ¿qué PID tendrá el shell dentro del contenedor? ¿Qué versión de kernel dirá: la de Alpine o la de tu Ubuntu?

**Pruébalo:**

```bash
docker run --rm alpine:3.22 sh -c 'hostname; ps; uname -r; head -2 /etc/os-release'
uname -r
```

👀 **Qué deberías ver:**
- El hostname es un número raro, como `eeff79c1cfa7`: el ID del contenedor.
- `ps` solo ve dos procesos (el `sh` y el propio `ps`), y el shell es el **PID 1**.
- `uname -r` dice `7.0.0-38-generic`, **el kernel de tu Ubuntu**, igual que el `uname -r` de fuera: el contenedor no tiene kernel propio.
- Y aun así, `/etc/os-release` dice `NAME="Alpine Linux"`: el sistema de archivos viene de la imagen.

`--rm` borra el contenedor al terminar, para no ir acumulando.

✋ **Sin mirar:** dentro de un contenedor de Alpine, ¿de dónde sale `/etc/os-release` y de dónde sale el kernel?

<details>
<summary>Comprueba</summary>

`/etc/os-release` sale de la imagen de Alpine; el kernel es el de tu Ubuntu, compartido.
</details>

**En resumen:** un contenedor comparte el kernel del host y trae su propio sistema de archivos en la imagen; una VM trae su propio kernel.

### Pieza 2 — *Namespaces*: lo que el proceso ve

| Pieza | Qué hace | Ejemplo |
|-------|----------|---------|
| **Namespaces** | cambian lo que el proceso **ve** | su propio árbol de procesos (es el PID 1), su propio hostname, su propia red y su propio sistema de archivos |

En la pieza 1, el hostname raro venía del *namespace* UTS y el PID 1, del *namespace* de PID. Desde fuera, en cambio, el contenedor es un proceso más con un PID normal del host.

**Pruébalo:**

```bash
docker run -d --name dormilon alpine:3.22 sleep 300
docker top dormilon
ps -ef | grep "sleep 300" | grep -v grep
docker rm -f dormilon
```

👀 **Qué deberías ver:** `docker top` y el `ps` de tu Ubuntu muestran **el mismo proceso** `sleep 300`, con el mismo PID normal del host (un número de miles). Dentro del contenedor, ese mismo proceso cree ser el PID 1. Un contenedor no es una caja: es una forma de mirar. `-d` lo arranca en segundo plano y `docker rm -f` lo para y lo borra.

Ahora crea un "contenedor" a mano, sin Docker, con la herramienta `unshare` del propio Linux:

```bash
sudo unshare --pid --fork --mount-proc --uts bash
```

Dentro de ese shell nuevo:

```bash
hostname contenedor-casero
hostname
ps aux
exit
hostname
```

👀 **Qué deberías ver:** `ps aux` ve solo dos procesos y tu `bash` es el PID 1, y el hostname cambió solo **ahí dentro**: al salir, tu Ubuntu conserva el suyo. Docker hace esto mismo (y bastante más) por ti.

✋ **Sin mirar:** un proceso de un contenedor es el PID 1 dentro. ¿Qué PID tiene visto desde tu Ubuntu?

<details>
<summary>Comprueba</summary>

Uno normal del host, como cualquier otro proceso: el *namespace* de PID solo cambia lo que ve el proceso, no lo que ve el host.
</details>

**En resumen:** los *namespaces* dan a un proceso su propia vista (PID, hostname, red, archivos); desde fuera sigue siendo un proceso normal.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-56`.

### Pieza 3 — *cgroups*: lo que el proceso gasta

| Pieza | Qué hace | Ejemplo |
|-------|----------|---------|
| **cgroups** | limitan lo que el proceso **gasta** | como mucho 256 MB de RAM o media CPU |

Los límites se escriben en archivos de `/sys/fs/cgroup/`, que el kernel lee. Con `docker run --memory 64m --cpus 0.5`, Docker los escribe por ti. Todo esto lo hace el kernel de Linux (lo viste en la clase 01); Docker solo lo organiza.

🔮 **Predice:** ¿qué número saldrá con `--memory 64m`, y qué sin límite?

**Pruébalo:**

```bash
docker run --rm --memory 64m alpine:3.22 cat /sys/fs/cgroup/memory.max
docker run --rm alpine:3.22 cat /sys/fs/cgroup/memory.max
docker run -d --name limitado --memory 128m --cpus 0.5 alpine:3.22 sleep 60
docker stats --no-stream limitado
docker rm -f limitado
```

👀 **Qué deberías ver:** `67108864`, que son 64 MB en bytes (64 × 1024 × 1024); `max`, que significa sin límite; y en `docker stats`, el consumo del contenedor con su límite al lado (`… / 128MiB`). `docker stats` sin `--no-stream` lo muestra en vivo. En la clase 63 verás qué pasa cuando un contenedor se pasa de su límite.

✋ **Sin mirar:** ¿qué parte del kernel limita la memoria de un contenedor, y en qué carpeta lo ves?

<details>
<summary>Comprueba</summary>

Los *cgroups*; el límite está en `/sys/fs/cgroup/memory.max`.
</details>

**En resumen:** los *cgroups* limitan memoria y CPU; `--memory` y `--cpus` los configuran y `docker stats` muestra el consumo.

### Pieza 4 — Las piezas de Docker y el socket

```
docker (cliente) ──► dockerd (demonio) ──► containerd ──► runc ──► tu proceso aislado
   lo que escribes      gestiona imágenes,     gestiona el ciclo   crea los namespaces
                        redes y volúmenes      de vida             y los cgroups
```

El cliente habla con el demonio por el **socket** `/var/run/docker.sock`. Quien puede escribir en ese socket puede pedirle al demonio, que corre como root, cualquier cosa: por ejemplo, un contenedor con todo tu disco montado (Rómpelo 2).

**Pruébalo:**

```bash
ls -l /var/run/docker.sock
id
ps -eo pid,user,comm | grep -E 'dockerd|containerd'
```

👀 **Qué deberías ver:** `srw-rw---- 1 root docker … /var/run/docker.sock`: la `s` del principio indica un socket, y pueden escribir en él root y el grupo `docker`. En `id`, `docker` entre tus grupos: por eso usas `docker` sin `sudo`. Y `dockerd` y `containerd` corriendo como `root`.

✋ **Sin mirar:** ¿quién puede usar el socket de Docker, y con qué usuario corre el demonio?

<details>
<summary>Comprueba</summary>

Root y los miembros del grupo `docker`; el demonio `dockerd` corre como root.
</details>

**En resumen:** `docker` → socket → `dockerd` (root) → `containerd` → `runc` → tu proceso; quien usa el socket manda en el demonio.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker run --rm imagen comando` | un contenedor que se borra al terminar |
| `docker run -d --name nombre imagen comando` | en segundo plano, con nombre |
| `docker ps` · `docker ps -a` | los que corren · todos, también los parados |
| `docker top nombre` | sus procesos, con PID del host |
| `docker rm -f nombre` | pararlo y borrarlo |
| `--memory 128m` · `--cpus 0.5` | límites de *cgroups* |
| `docker stats [--no-stream]` | consumo y límites |
| `sudo unshare --pid --fork --mount-proc --uts bash` | *namespaces* a mano, sin Docker |
| `docker system df` · `docker image prune -a` | espacio usado · borrar imágenes sin uso |

## Rómpelo

**1. Un contenedor que termina en cuanto arranca:**
```bash
docker run --name corto alpine:3.22
docker ps
docker ps -a
docker rm corto
```
`docker ps` no lo muestra, y `docker ps -a` dice `Exited (0)`. Un contenedor vive lo que vive su proceso principal: la imagen de Alpine arranca `sh`, que sin terminal termina enseguida. Un contenedor no es una VM que se queda encendida: si quieres que siga, su proceso tiene que seguir.

**2. El grupo `docker` es root:**
```bash
ls -l /var/run/docker.sock
id
ls /root
docker run --rm -v /:/host alpine:3.22 ls /host/root
```
Tu usuario no puede ver `/root` (Permiso denegado)… pero, como estás en el grupo `docker`, le pides al demonio un contenedor con tu disco entero montado en `/host`, y dentro eres root. Por eso, en un servidor, añadir a alguien al grupo `docker` es darle root. En tu portátil es una comodidad razonable; en un servidor compartido, no.

**3. Ver la imagen equivocada por no fijar la versión:**
```bash
docker run --rm alpine cat /etc/alpine-release
docker run --rm alpine:3.22 cat /etc/alpine-release
```
Sin etiqueta, Docker usa `alpine:latest`, que cambia cuando sale una versión nueva. Hoy pueden coincidir; dentro de unos meses, no. En todo lo que vayas a repetir (Dockerfiles, Compose, CI), fija la versión.

## Reto

En `labs/clase-56/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Arranca `ubuntu:26.04`, `debian:13` y `alpine:3.22` con `cat /etc/os-release && uname -r`. ¿Qué cambia entre ellos y qué no cambia nunca? ¿Por qué?

> 🧩 **Ejemplo resuelto:** la pieza 1, con Alpine: `os-release` de Alpine y `uname -r` de tu Ubuntu.

**Ahora tú, con huecos:**
```bash
for img in ubuntu:26.04 debian:13 alpine:3.22; do
  echo "== $img"; docker run --rm "$img" sh -c 'head -2 /etc/____ && uname ____'
done
```
Completa: «Cambia ____, porque viene de la imagen. No cambia nunca ____, porque los tres…».

<details>
<summary>Pista</summary>

Son los mismos comandos de la pieza 1. Fíjate en la última línea de cada uno.
</details>

**2.** Con `docker run -d --name web nginx:1.29`, encuentra en tu Ubuntu el PID del proceso `nginx: master process` y mira su `/proc/<PID>/status`. ¿Con qué usuario corre en el host?

> 🧩 **Ejemplo resuelto:** la pieza 2: `docker top dormilon` y `ps -ef | grep "sleep 300"` dan el PID del host.

**Ahora tú, con huecos:**
```bash
docker run -d --name web nginx:1.29
docker top web
PID=$(pgrep -f "nginx: master")
grep -E '^(Uid|Gid)' /proc/$PID/____
docker rm -f web
```
Completa: «El proceso maestro corre en el host como ____ (Uid ____)».

<details>
<summary>Pista</summary>

En `/proc/<PID>/status`, la línea `Uid:` tiene cuatro números (real, efectivo, guardado y de sistema de archivos); el UID 0 es root (clase 09).
</details>

**3.** Ejecuta `docker system df`. ¿Cuánto espacio ocupan ya las imágenes de esta clase? Cuando termines, bórralas con `docker image prune -a` (te preguntará antes).

> 🧩 **Ejemplo resuelto:** `df -h /` te dice cuánto disco ocupa tu sistema (clase 14); `docker system df` hace lo mismo con lo de Docker: imágenes, contenedores, volúmenes y caché.

**Ahora tú, con huecos:** completa «Las imágenes ocupan ____; la más grande es ____ (mírala con `docker images`)».

<details>
<summary>Pista</summary>

`docker images` lista cada imagen con su tamaño. `prune -a` solo borra las que no usa ningún contenedor.
</details>

## Cierre

En `notas/fase-5/clase-56.md`:

1. Explica con tus palabras qué es un contenedor: qué hacen los *namespaces*, los *cgroups* y la imagen. *(3 líneas, una por pieza. Empieza así: «Un contenedor es un proceso normal de Linux. Los namespaces cambian lo que ve:… Los cgroups… La imagen…»)*
2. ¿Por qué `uname -r` dentro de un contenedor de Alpine muestra el kernel de tu Ubuntu? ¿Qué diferencia eso a un contenedor de una VM? *(2 líneas. Empieza así: «Porque el contenedor no tiene kernel propio:… Una VM, en cambio,…»)*
3. ¿Por qué estar en el grupo `docker` equivale a tener root? *(2 líneas. Empieza así: «Porque el grupo `docker` puede escribir en el socket del demonio, que corre como root, y…»)*
4. **Repaso (clase 55, sin mirar):** ¿por qué `/status` de Vigía lee la base de datos en cada petición? *(1–2 líneas. Empieza así: «Porque `check` y `serve` son procesos distintos:…»)*

Después, escríbeme `examíname clase-56`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un contenedor es un proceso normal de Linux. Los *namespaces* cambian lo que ve: sus propios procesos (es el PID 1), su hostname, su red y su sistema de archivos. Los *cgroups* limitan lo que gasta: memoria, CPU y procesos. Y la imagen le da el sistema de archivos con el que arranca (las librerías y los programas). Todo lo hace el kernel; Docker lo organiza.

**2.** Porque el contenedor no tiene kernel propio: es un proceso más del host y usa su kernel. Lo que viene de Alpine es solo el sistema de archivos. Una VM, en cambio, arranca su propio kernel sobre un hipervisor: aísla más, pero tarda más en arrancar y gasta más memoria.

**3.** Porque el grupo `docker` puede escribir en el socket del demonio, que corre como root, y el demonio hace lo que le pidas: por ejemplo, arrancar un contenedor con todo el disco del host montado, dentro del cual eres root. Quien controla el demonio controla la máquina.

**4.** Porque el chequeo (`check`, lanzado por cron) y la API (`serve`) son procesos distintos: si la API guardara los datos al arrancar, mostraría siempre ese momento. Leyendo en cada petición, enseña lo último que se guardó.

**Reto 1:** `os-release` y `uname -r`. Cambian `/etc/os-release` y todo lo que hay en el sistema de archivos (programas, librerías, gestor de paquetes); no cambia nunca `uname -r`, porque los tres usan el kernel de tu Ubuntu.

**Reto 2:** `status`. El proceso maestro de nginx corre como **root** en el host (Uid 0); los *workers*, como `nginx`, con un UID propio. Si alguien escapara del contenedor, sería root en tu máquina. Por eso, en la clase 59, tus imágenes correrán con un usuario sin privilegios.

**Reto 3:** depende de lo que hayas descargado; `ubuntu:26.04` y `nginx:1.29` suelen ser las más grandes, y `alpine:3.22`, la más pequeña (unos MB).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| container / image | contenedor / imagen |
| namespace / cgroup | espacio de nombres / grupo de control |
| container runtime | motor de contenedores |
| host / daemon | máquina anfitriona / demonio |
| isolation | aislamiento |

🎙️ *"A container is just a Linux process isolated with namespaces and limited with cgroups, started from an image's filesystem. It shares the host kernel, which is why it starts in milliseconds."*

## Siguiente

[Clase 57 — Imágenes y contenedores: run, ps, logs, exec, inspect](clase-57-imagenes-y-contenedores.md)
