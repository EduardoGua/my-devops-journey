# Clase 57 — Imágenes y contenedores: run, ps, logs, exec, inspect

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** una **imagen** es la plantilla de solo lectura y un **contenedor** es una ejecución de esa plantilla, con su propia capa escribible encima. Con cinco comandos (`run`, `ps`, `logs`, `exec` e `inspect`) haces el 90 % del trabajo diario: arrancar, ver qué corre, leer lo que escribe, entrar dentro y consultar su configuración. Y una regla: los contenedores son desechables; lo que cambies dentro se pierde al borrarlo.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Qué es un contenedor y `docker run --rm`, `-d`, `--name`, `ps` y `rm -f` (clase 56).
> - Las variables de entorno con `-e` (clase 07); el código de salida `$?` (clase 04).
> - SIGTERM y SIGKILL (clase 11); `systemctl status` y `journalctl` (clases 12 y 13).
> - Un puerto solo lo puede usar un proceso (clase 29); `curl -w '%{http_code}'` (clase 32).

> 🔤 **Palabras nuevas de hoy:**
> - **etiqueta** (*tag*): la versión de una imagen, detrás de los dos puntos: `nginx:1.29`.
> - **publicar un puerto** (`-p 8080:80`): reenviar un puerto de tu máquina a uno del contenedor.
> - **capa escribible**: lo que un contenedor cambia, encima de la imagen; se borra con el contenedor.
> - **`exec`**: ejecutar un proceso adicional dentro de un contenedor en marcha.
> - **`inspect`**: toda la configuración y el estado de un contenedor, en JSON.

## Objetivo

- Distinguir **imagen** (la plantilla) de **contenedor** (una ejecución de esa plantilla).
- Arrancar contenedores con las opciones de cada día: `-d`, `--name`, `-p`, `-e`, `--rm`, `-it`.
- Seguir el ciclo de vida de un contenedor: crear, arrancar, parar, borrar.
- Mirar dentro: `logs`, `exec` e `inspect`.
- Hacer limpieza: imágenes, contenedores parados y espacio en disco.

## Por qué importa

Estos cinco comandos son el 90 % de tu trabajo diario con contenedores, en tu portátil y en un servidor. Cuando algo falle en producción (clase 63), los primeros 30 segundos son `docker ps`, `docker logs` y `docker inspect`, igual que con un servicio eran `systemctl status` y `journalctl` (clases 12 y 13).

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Todas usan el mismo nginx.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-57 && cd ~/my-devops-journey/labs/clase-57
```

## Las piezas

### Pieza 1 — Imagen, contenedor y `docker run`

| | Imagen | Contenedor |
|--|--------|------------|
| Qué es | una plantilla de solo lectura: sistema de archivos + configuración | un proceso en marcha (o parado) creado desde una imagen |
| Se parece a | una clase, o una AMI de AWS | un objeto, o una instancia EC2 |
| Comandos | `pull`, `images`, `rmi`, `build` (clase 58) | `run`, `ps`, `stop`, `rm`, `logs`, `exec` |

Una imagen se nombra `repositorio:etiqueta`: `nginx:1.29`, `python:3.14-slim`, `postgres:18`. Sin etiqueta, Docker usa `latest` (Rómpelo 3 de la clase 56).

```bash
docker run -d --name web -p 8080:80 -e TZ=America/Bogota nginx:1.29
```

| Opción | Qué hace |
|--------|----------|
| `-d` | en segundo plano (*detached*) |
| `--name web` | un nombre para referirte a él (si no, Docker inventa uno) |
| `-p 8080:80` | publica el puerto 80 **del contenedor** en el 8080 **de tu máquina** |
| `-e CLAVE=valor` | una variable de entorno (clase 07) |
| `--rm` | bórralo al terminar |
| `-it` | interactivo con terminal (para un shell) |

`-p` se lee "host:contenedor". Lo que escucha dentro del contenedor no es accesible desde fuera hasta que lo publicas.

**Pruébalo:**

```bash
docker run -d --name web -p 8080:80 nginx:1.29
docker ps
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080
```

👀 **Qué deberías ver:** la primera vez, Docker descarga la imagen (`Pulling from library/nginx`); después, un ID largo. En `docker ps`, una fila con `nginx:1.29`, `Up …` y `0.0.0.0:8080->80/tcp`; y `200`. Abre `http://localhost:8080` en el navegador: acabas de desplegar nginx sin instalar nada en tu Ubuntu.

✋ **Sin mirar:** en `-p 8080:80`, ¿cuál es el puerto de tu máquina y cuál el del contenedor?

<details>
<summary>Comprueba</summary>

8080 es el de tu máquina (host) y 80 el del contenedor: "host:contenedor".
</details>

**En resumen:** de una imagen salen contenedores; `docker run -d --name … -p host:contenedor imagen:etiqueta` arranca uno y publica su puerto.

### Pieza 2 — Mirar dentro: `logs` y `exec`

| Comando | Para qué |
|---------|----------|
| `docker logs [-f] [--tail 20] web` | lo que el proceso escribe en stdout y stderr |
| `docker exec web comando` | ejecutar un comando **dentro** de un contenedor en marcha |
| `docker exec -it web sh` | abrir un shell dentro |

En un contenedor, los logs **no** van a un archivo: el proceso escribe en stdout y stderr, y Docker los guarda. Por eso Vigía escribe su log en stderr (clase 48).

🔮 **Predice:** la imagen de nginx, ¿está basada en Ubuntu, en Debian o en Alpine? `head -1 /etc/os-release` te lo dice.

**Pruébalo:**

```bash
curl -s localhost:8080 > /dev/null
docker logs --tail 3 web
docker exec web nginx -v
docker exec web sh -c 'head -1 /etc/os-release; ls /usr/share/nginx/html'
docker exec -it web sh
```

Dentro del shell:

```bash
ps aux
ls -d /proc/[0-9]*
cat /proc/1/cmdline | tr '\0' ' '; echo
head -12 /etc/nginx/conf.d/default.conf
exit
```

👀 **Qué deberías ver:** en los logs, tus peticiones con el formato de nginx (`172.17.0.1 - - [fecha] "GET / HTTP/1.1" 200 896 "-" "curl/…"`); `nginx version: nginx/1.29.x`; `PRETTY_NAME="Debian GNU/Linux 13 (trixie)"` y los archivos `50x.html` e `index.html`. Dentro del shell, `ps aux` falla con `sh: 1: ps: not found`: la imagen solo trae lo imprescindible. Pero `/proc` sí está: un directorio por proceso, el **1** es `nginx: master process nginx -g daemon off;` y los demás son sus *workers* (uno por CPU). Al salir, el contenedor sigue: `exec` abre un proceso **adicional** dentro, no el principal.

✋ **Sin mirar:** al hacer `exit` del shell que abriste con `exec`, ¿se para el contenedor?

<details>
<summary>Comprueba</summary>

No: el shell era un proceso adicional. El contenedor vive mientras viva su proceso principal, el PID 1 (nginx).
</details>

**En resumen:** `docker logs` lee stdout y stderr del contenedor; `docker exec` ejecuta comandos dentro sin tocar el proceso principal.

### Pieza 3 — La capa escribible: cambiar algo dentro… y perderlo

De una imagen salen tantos contenedores como quieras, cada uno con su propia **capa escribible** encima: lo que cambie dentro de un contenedor no afecta a la imagen ni a los demás, y se borra con él.

🔮 **Predice:** si cambias el `index.html` dentro del contenedor, lo borras y arrancas otro, ¿verás tu cambio?

**Pruébalo:**

```bash
docker exec web sh -c 'echo "<h1>Hola desde el contenedor</h1>" > /usr/share/nginx/html/index.html'
curl -s localhost:8080
docker rm -f web
docker run -d --name web -p 8080:80 nginx:1.29
curl -s localhost:8080 | head -4
```

👀 **Qué deberías ver:** `<h1>Hola desde el contenedor</h1>` y, tras recrearlo, otra vez la página de bienvenida de nginx (`<!DOCTYPE html>`, `<title>Welcome to nginx!</title>`…). El cambio vivía en la capa escribible de **aquel** contenedor, que borraste. Los contenedores son desechables; lo que deba durar va en un volumen (clase 60) o en la imagen (clase 58).

✋ **Sin mirar:** ¿dónde guardarías los datos de una base de datos en contenedor para que no se pierdan al recrearlo?

<details>
<summary>Comprueba</summary>

En un volumen (clase 60). El código y los archivos de la aplicación, en cambio, van dentro de la imagen (clase 58).
</details>

**En resumen:** cada contenedor tiene su capa escribible, que muere con él; lo que dure, en un volumen o en la imagen.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Deja `web` corriendo o vuelve a crearlo mañana con `docker run -d --name web -p 8080:80 nginx:1.29`.

### Pieza 4 — `inspect`: la configuración y el estado

`docker inspect web` devuelve todo en un JSON enorme; con `--format` y una plantilla te quedas con un dato concreto. `{{.State.Status}}` lee el campo `Status` dentro de `State`, y `{{range …}}…{{end}}` recorre una lista.

**Pruébalo:**

```bash
docker inspect web --format '{{.State.Status}} desde {{.State.StartedAt}}'
docker inspect web --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
docker inspect web --format '{{json .NetworkSettings.Ports}}'
docker inspect web --format 'imagen {{.Config.Image}} · entrypoint {{.Config.Entrypoint}} · cmd {{.Config.Cmd}}'
```

👀 **Qué deberías ver:** `running desde 2026-…Z`; una IP como `172.17.0.2`: el contenedor tiene su propia IP en una red interna de Docker (clase 61); `{"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"8080"},…]}`, el `-p` que pusiste; e `imagen nginx:1.29 · entrypoint [/docker-entrypoint.sh] · cmd [nginx -g daemon off;]`: lo que ejecuta al arrancar (lo verás en la clase 58).

✋ **Sin mirar:** ¿con qué opción de `docker inspect` sacas un solo dato en lugar de todo el JSON?

<details>
<summary>Comprueba</summary>

`--format` con una plantilla, por ejemplo `--format '{{.State.Status}}'`.
</details>

**En resumen:** `docker inspect` lo sabe todo del contenedor; `--format '{{…}}'` saca justo el dato que buscas.

### Pieza 5 — El ciclo de vida: parar, arrancar y limpiar

```
            run (= create + start)
 imagen ─────────────────────────► Up ──stop──► Exited ──rm──► (no existe)
                                    ▲              │
                                    └────start─────┘
```

`docker stop` envía SIGTERM y, si el proceso no termina en 10 segundos, SIGKILL (clase 11). `docker rm -f` hace las dos cosas de golpe. `docker system df` dice cuánto disco ocupan imágenes, contenedores y volúmenes, y `prune` borra lo que no se usa: `container prune`, los contenedores parados; `image prune`, las imágenes sin contenedor.

**Pruébalo:**

```bash
docker stop web
docker ps -a --filter name=web
docker start web && docker ps
docker rm -f web
docker images
docker system df
docker container prune -f
```

👀 **Qué deberías ver:** tras `stop`, el contenedor sigue existiendo como `Exited (0)`; `start` lo vuelve a poner `Up` (con los mismos cambios de su capa escribible, porque no lo borraste); después de `rm -f` ya no existe. `docker images` lista `nginx:1.29` y `alpine:3.22` con su tamaño, y `docker system df` resume el espacio por tipo.

✋ **Sin mirar:** ¿qué diferencia hay entre `docker stop` y `docker rm`?

<details>
<summary>Comprueba</summary>

`stop` para el proceso (SIGTERM y, a los 10 s, SIGKILL), pero el contenedor sigue existiendo y se puede volver a arrancar. `rm` lo borra, con su capa escribible.
</details>

**En resumen:** `run` → Up → `stop` → Exited → `start` o `rm`; `system df` y `prune` para limpiar.

### Pieza 6 — Variables de entorno y códigos de salida

`-e CLAVE=valor` pasa una variable de entorno al proceso del contenedor, como `export` en tu shell (clase 07). Y `docker run` devuelve el código de salida del proceso del contenedor: tus scripts y tu CI pueden usarlo como el de cualquier comando (clase 04).

🔮 **Predice** el código de salida de la segunda línea.

**Pruébalo:**

```bash
docker run --rm -e SALUDO=hola alpine:3.22 sh -c 'echo $SALUDO'
docker run --rm alpine:3.22 sh -c 'exit 3' ; echo "código: $?"
```

👀 **Qué deberías ver:** `hola` y `código: 3`. Las comillas simples hacen que `$SALUDO` lo expanda el `sh` del contenedor, no tu shell.

✋ **Sin mirar:** un contenedor de pruebas termina con código 1. ¿Qué código devuelve `docker run`?

<details>
<summary>Comprueba</summary>

1: `docker run` devuelve el código de salida del proceso del contenedor.
</details>

**En resumen:** `-e` configura el contenedor por el entorno; su código de salida es el de `docker run`.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker run -d --name web -p 8080:80 -e X=1 nginx:1.29` | arrancar con nombre, puerto y variable |
| `docker ps` · `docker ps -a --filter name=web` | en marcha · todos, filtrados |
| `docker logs --tail 20 -f web` | los últimos logs, y seguirlos |
| `docker exec web cmd` · `docker exec -it web sh` | un comando dentro · un shell dentro |
| `docker inspect web --format '{{.State.Status}}'` | un dato de la configuración o el estado |
| `docker stop` · `start` · `rm [-f]` | el ciclo de vida |
| `docker images` · `docker pull imagen:etiqueta` · `docker rmi` | imágenes |
| `docker system df` · `docker container prune -f` · `docker image prune` | espacio y limpieza |

## Rómpelo

**1. El puerto ocupado:**
```bash
docker run -d --name web -p 8080:80 nginx:1.29
docker run -d --name web2 -p 8080:80 nginx:1.29
```
`Bind for 0.0.0.0:8080 failed: port is already allocated`. Solo un proceso puede escuchar en un puerto del host (clase 29). El segundo contenedor llegó a **crearse**, pero no arrancó: `docker ps -a` lo muestra como `Created`. Bórralo (`docker rm web2`) y publícalo en otro puerto: `-p 8081:80`.

**2. Borrar un contenedor en marcha:**
```bash
docker rm web
```
`cannot remove container "web": container is running`. Primero `docker stop web` (parada ordenada) o `docker rm -f web` (a la fuerza).

**3. Una etiqueta que no existe:**
```bash
docker pull nginx:no-existe-esta-etiqueta
```
`not found`. Las etiquetas disponibles de cada imagen oficial están en su página de Docker Hub (`hub.docker.com/_/nginx`).

**4. Un contenedor parado no recibe `exec`:**
```bash
docker stop web
docker exec web nginx -v
docker rm web
```
`container … is not running`. `exec` necesita el proceso principal vivo. Para explorar una imagen que no arranca, se lanza otro contenedor con un shell: `docker run --rm -it nginx:1.29 sh` (lo usarás en la clase 63).

## Reto

En `labs/clase-57/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Arranca `postgres:18` en segundo plano con nombre `pg`, sigue sus logs hasta que esté listo y conéctate con `psql` para ejecutar `SELECT version();`.

> 🧩 **Ejemplo resuelto:** el nginx de la pieza 1 (`-d --name web`) y el `docker exec -it web sh` de la pieza 2.

**Ahora tú, con huecos:**
```bash
docker run -d --name pg -e POSTGRES_PASSWORD=____ postgres:18
docker logs ____ pg          # hasta ver "database system is ready to accept connections"; Ctrl+C
docker exec -it pg psql -U ____
```
Dentro de `psql`: `SELECT version();` y `\q` para salir.

<details>
<summary>Pista</summary>

La imagen de PostgreSQL no arranca sin `POSTGRES_PASSWORD` (pon `prueba`). `-f` sigue los logs en vivo. El usuario administrador por defecto se llama `postgres`.
</details>

**2.** Con una sola plantilla de `docker inspect`, imprime el nombre, el estado y la IP de `pg`.

> 🧩 **Ejemplo resuelto:** las plantillas de la pieza 4: `{{.State.Status}}` y `{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`.

**Ahora tú, con huecos:** `docker inspect pg --format '{{.____}} {{.State.____}} {{range .NetworkSettings.Networks}}{{.____}}{{end}}'`

<details>
<summary>Pista</summary>

El nombre está en el campo `Name`, en la raíz del JSON (sale con una `/` delante).
</details>

**3.** Arranca tres nginx en los puertos 8081, 8082 y 8083 con un bucle de Bash (clase 18), compruébalos con `curl` y bórralos con un solo comando.

> 🧩 **Ejemplo resuelto:** `docker run -d --name web -p 8080:80 nginx:1.29` de la pieza 1 y el `curl -s -o /dev/null -w "%{http_code}\n"`.

**Ahora tú, con huecos:**
```bash
for p in 8081 8082 8083; do docker run -d --name "web-$p" -p "____:80" nginx:1.29; done
for p in 8081 8082 8083; do curl -s -o /dev/null -w "$p → %{http_code}\n" "localhost:____"; done
docker rm -f $(docker ps -q --filter ancestor=____)
```

<details>
<summary>Pista</summary>

`docker ps -q` imprime solo los IDs, y `--filter ancestor=imagen` se queda con los contenedores creados desde esa imagen. `$( … )` mete esa lista como argumentos de `docker rm -f` (clase 16).
</details>

## Cierre

En `notas/fase-5/clase-57.md`:

1. ¿Qué diferencia hay entre una imagen y un contenedor? Usa una comparación con AWS. *(2 líneas. Empieza así: «La imagen es la plantilla de solo lectura…; el contenedor es… En AWS, la imagen sería una AMI y…»)*
2. Explica `-p 8080:80`. ¿Qué pasa si no lo pones? *(2 líneas. Empieza así: «Publica el puerto 80 del contenedor en el 8080 de mi máquina:… Sin `-p`,…»)*
3. ¿Por qué se perdió el `index.html` que cambiaste al recrear el contenedor? ¿Dónde guardarías algo que deba durar? *(2 líneas. Empieza así: «Porque el cambio estaba en la capa escribible de aquel contenedor… Lo que deba durar va en…»)*
4. **Repaso (clase 56, sin mirar):** ¿por qué `uname -r` dentro de un contenedor muestra el kernel de tu Ubuntu? *(1–2 líneas. Empieza así: «Porque el contenedor no tiene kernel propio:…»)*

Después, escríbeme `examíname clase-57`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La imagen es la plantilla de solo lectura (sistema de archivos y configuración); el contenedor es un proceso creado a partir de ella, con su capa escribible. En AWS, la imagen sería una AMI y el contenedor una instancia EC2 lanzada desde esa AMI: de una AMI salen muchas instancias.

**2.** Publica el puerto 80 del contenedor en el 8080 de tu máquina: lo que llegue a `localhost:8080` se reenvía al 80 del contenedor. Sin `-p`, el servicio escucha solo en la red interna de Docker y desde tu navegador no llegas (sí desde otro contenedor de esa red, clase 61).

**3.** Porque el cambio estaba en la capa escribible de aquel contenedor, y al borrarlo se fue con él; el nuevo arranca limpio desde la imagen. Lo que deba durar va en un **volumen** (datos, clase 60) o dentro de la **imagen** (el código y los archivos de la aplicación, clase 58).

**4.** Porque el contenedor no tiene kernel propio: es un proceso del host aislado con *namespaces*, y usa el kernel de tu Ubuntu.

**Reto 1:** `POSTGRES_PASSWORD=prueba`, `docker logs -f pg` y `psql -U postgres`. `SELECT version();` devuelve `PostgreSQL 18.x on x86_64-pc-linux-gnu…`.

**Reto 2:** `docker inspect pg --format '{{.Name}} {{.State.Status}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`

**Reto 3:** `"$p:80"`, `"localhost:$p"` y `ancestor=nginx:1.29`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to pull / to run an image | descargar / ejecutar una imagen |
| detached mode | en segundo plano |
| to publish a port | publicar un puerto |
| writable layer | capa escribible |
| ephemeral / disposable | efímero / desechable |

🎙️ *"Containers are disposable: anything written inside is lost when the container is removed, so data goes in volumes and code goes in the image."*

## Siguiente

[Clase 58 — Tu primer Dockerfile](clase-58-primer-dockerfile.md)
