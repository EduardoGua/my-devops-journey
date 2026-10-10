# Clase 56 — Qué es un contenedor de verdad

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

## Objetivo

- Entender que un contenedor es **un proceso normal de Linux**, aislado con *namespaces* y limitado con *cgroups*, que arranca desde el sistema de archivos de una imagen.
- Distinguir un contenedor de una máquina virtual (clase 08).
- Conocer las piezas de Docker: cliente, demonio, `containerd` y `runc`.
- Instalar Docker Compose y `buildx`, que te faltan, y comprobar tu instalación.
- Saber por qué estar en el grupo `docker` equivale a ser root.

## Por qué importa

Docker parece magia hasta que ves que no lo es: un contenedor es Linux con otra interfaz, como prometía el plan (idea 1). Quien entiende esto diagnostica en minutos lo que a otros les lleva horas: por qué un contenedor no ve un archivo, por qué no conecta con otro o por qué lo mató el kernel. Y en la nube todo se despliega en contenedores: ECS, EKS, Kubernetes (fase 9), los runners de GitHub Actions (fase 7). En esta fase empaquetas Vigía para que funcione igual en tu portátil, en AWS y en Kubernetes.

## Teoría

### Una VM frente a un contenedor

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

Una VM arranca un sistema operativo entero: segundos o minutos y cientos de MB de RAM. Un contenedor es un proceso más del host: arranca en milisegundos y gasta lo que gaste la aplicación. El precio: comparte el kernel del host, así que aísla menos que una VM.

### Las tres piezas que hacen un contenedor

| Pieza | Qué hace | Ejemplo |
|-------|----------|---------|
| **Namespaces** | cambian lo que el proceso **ve** | su propio árbol de procesos (es el PID 1), su propio hostname, su propia red y su propio sistema de archivos |
| **cgroups** | limitan lo que el proceso **gasta** | como mucho 256 MB de RAM o media CPU |
| **Imagen** | el sistema de archivos con el que arranca | Alpine, Debian, Python 3.14… en capas de solo lectura (clase 58) |

Todo esto lo hace el kernel de Linux (lo viste en la clase 01). Docker solo lo organiza.

### Las piezas de Docker

```
docker (cliente) ──► dockerd (demonio) ──► containerd ──► runc ──► tu proceso aislado
   lo que escribes      gestiona imágenes,     gestiona el ciclo   crea los namespaces
                        redes y volúmenes      de vida             y los cgroups
```

El cliente habla con el demonio por el **socket** `/var/run/docker.sock`. Quien puede escribir en ese socket puede pedirle al demonio, que corre como root, cualquier cosa: por ejemplo, un contenedor con todo tu disco montado (Rómpelo 2).

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-56 && cd ~/my-devops-journey/labs/clase-56
```

### 1. Completar tu instalación

Docker ya está en tu Ubuntu desde la fase 0, pero le faltan dos complementos que usarás en esta fase: Compose (varios contenedores a la vez, clase 62) y `buildx` (el constructor moderno de imágenes).

```bash
docker version --format 'cliente {{.Client.Version}} · servidor {{.Server.Version}}'
docker compose version
sudo apt install -y docker-compose-v2 docker-buildx
docker compose version
docker buildx version
docker info --format 'almacenamiento: {{.Driver}} · cgroups v{{.CgroupVersion}}'
```

El primer `docker compose version` falla con `unknown command`: es lo que acabas de instalar.

### 2. Un contenedor por dentro

```bash
docker run --rm alpine:3.22 sh -c 'hostname; ps; uname -r; head -2 /etc/os-release'
uname -r
```

🔮 **Predice** antes de ejecutar: ¿qué PID tendrá el shell dentro del contenedor? ¿Qué versión de kernel dirá: la de Alpine o la de tu Ubuntu?

- El hostname es un número raro: el ID del contenedor (*namespace* UTS).
- `ps` solo ve dos procesos y el shell es el **PID 1** (*namespace* de PID).
- `uname -r` dice **el kernel de tu Ubuntu**: el contenedor no tiene kernel propio.
- Y aun así, `/etc/os-release` dice Alpine: el sistema de archivos viene de la imagen.

### 3. Desde fuera, es un proceso más

```bash
docker run -d --name dormilon alpine:3.22 sleep 300
docker top dormilon
ps -ef | grep "sleep 300" | grep -v grep
docker rm -f dormilon
```

`docker top` y el `ps` de tu Ubuntu muestran **el mismo proceso**, con un PID normal del host. Dentro del contenedor, ese mismo proceso cree ser el PID 1. Un contenedor no es una caja: es una forma de mirar.

### 4. Namespaces sin Docker

Para terminar de convencerte, crea un "contenedor" a mano con la herramienta `unshare` del propio Linux:

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

`ps aux` ve solo dos procesos y tu `bash` es el PID 1, y el hostname cambió solo **ahí dentro**: al salir, tu Ubuntu conserva el suyo. Docker hace esto mismo (y bastante más) por ti.

### 5. cgroups: limitar lo que gasta

```bash
docker run --rm --memory 64m alpine:3.22 cat /sys/fs/cgroup/memory.max
docker run --rm alpine:3.22 cat /sys/fs/cgroup/memory.max
docker run -d --name limitado --memory 128m --cpus 0.5 alpine:3.22 sleep 60
docker stats --no-stream limitado
docker rm -f limitado
```

`67108864` son 64 MB en bytes; `max` significa sin límite. `docker stats` muestra el consumo y el límite de cada contenedor en vivo. En la clase 63 verás qué pasa cuando un contenedor se pasa de su límite.

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

1. Arranca `ubuntu:26.04`, `debian:13` y `alpine:3.22` con `cat /etc/os-release && uname -r`. ¿Qué cambia entre ellos y qué no cambia nunca? Explica por qué.
2. Con `docker run -d --name web nginx:1.29`, encuentra en tu Ubuntu el PID del proceso `nginx: master process` (`docker top` o `ps`) y mira su `/proc/<PID>/status`. ¿Con qué usuario corre en el host?
3. Ejecuta `docker system df`. ¿Cuánto espacio ocupan ya las imágenes de esta clase? Bórralas con `docker image prune -a` cuando termines (te preguntará antes).

## Cierre

En `notas/fase-5/clase-56.md`:

1. Explica con tus palabras qué es un contenedor: qué hacen los *namespaces*, los *cgroups* y la imagen.
2. ¿Por qué `uname -r` dentro de un contenedor de Alpine muestra el kernel de tu Ubuntu? ¿Qué diferencia eso a un contenedor de una VM?
3. ¿Por qué estar en el grupo `docker` equivale a tener root?
4. **Repaso (clase 55, sin mirar):** ¿por qué `/status` de Vigía lee la base de datos en cada petición?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un contenedor es un proceso normal de Linux. Los *namespaces* cambian lo que ve: sus propios procesos (es el PID 1), su hostname, su red y su sistema de archivos. Los *cgroups* limitan lo que gasta: memoria, CPU y procesos. Y la imagen le da el sistema de archivos con el que arranca (las librerías y los programas). Todo lo hace el kernel; Docker lo organiza.

**2.** Porque el contenedor no tiene kernel propio: es un proceso más del host y usa su kernel. Lo que viene de Alpine es solo el sistema de archivos. Una VM, en cambio, arranca su propio kernel sobre un hipervisor: aísla más, pero tarda más en arrancar y gasta más memoria.

**3.** Porque el grupo `docker` puede escribir en el socket del demonio, que corre como root, y el demonio hace lo que le pidas: por ejemplo, arrancar un contenedor con todo el disco del host montado, dentro del cual eres root. Quien controla el demonio controla la máquina.

**4.** Porque el chequeo (`check`, lanzado por cron) y la API (`serve`) son procesos distintos: si la API guardara los datos al arrancar, mostraría siempre ese momento. Leyendo en cada petición, enseña lo último que se guardó.

**Reto 1:** cambian `/etc/os-release` y todo lo que hay en el sistema de archivos (programas, librerías, gestor de paquetes); no cambia nunca `uname -r`, porque los tres usan el kernel de tu Ubuntu.

**Reto 2:** el proceso maestro de nginx corre como **root** en el host (los *workers*, como `nginx`, con un UID propio). Si alguien escapara del contenedor, sería root en tu máquina. Por eso, en la clase 59, tus imágenes correrán con un usuario sin privilegios.
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
