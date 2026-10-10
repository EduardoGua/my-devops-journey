# Clase 57 — Imágenes y contenedores: run, ps, logs, exec, inspect

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

## Objetivo

- Distinguir **imagen** (la plantilla) de **contenedor** (una ejecución de esa plantilla).
- Arrancar contenedores con las opciones de cada día: `-d`, `--name`, `-p`, `-e`, `--rm`, `-it`.
- Seguir el ciclo de vida de un contenedor: crear, arrancar, parar, borrar.
- Mirar dentro: `logs`, `exec` e `inspect`.
- Hacer limpieza: imágenes, contenedores parados y espacio en disco.

## Por qué importa

Estos cinco comandos son el 90 % de tu trabajo diario con contenedores, en tu portátil y en un servidor. Cuando algo falle en producción (clase 63), los primeros 30 segundos son `docker ps`, `docker logs` y `docker inspect`, igual que con un servicio eran `systemctl status` y `journalctl` (clases 12 y 13).

## Teoría

### Imagen y contenedor

| | Imagen | Contenedor |
|--|--------|------------|
| Qué es | una plantilla de solo lectura: sistema de archivos + configuración | un proceso en marcha (o parado) creado desde una imagen |
| Se parece a | una clase, o una AMI de AWS | un objeto, o una instancia EC2 |
| Comandos | `pull`, `images`, `rmi`, `build` (clase 58) | `run`, `ps`, `stop`, `rm`, `logs`, `exec` |

De una imagen salen tantos contenedores como quieras, cada uno con su propia capa escribible encima (lo que cambie dentro de un contenedor no afecta a la imagen ni a los demás).

Una imagen se nombra `repositorio:etiqueta`: `nginx:1.29`, `python:3.14-slim`, `postgres:18`. Sin etiqueta, Docker usa `latest` (Rómpelo 3 de la clase 56).

### `docker run`

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

### El ciclo de vida

```
            run (= create + start)
 imagen ─────────────────────────► Up ──stop──► Exited ──rm──► (no existe)
                                    ▲              │
                                    └────start─────┘
```

`docker stop` envía SIGTERM y, si el proceso no termina en 10 segundos, SIGKILL (clase 11). `docker rm -f` hace las dos cosas de golpe.

### Mirar dentro

| Comando | Para qué |
|---------|----------|
| `docker ps` / `docker ps -a` | contenedores en marcha / todos, también los parados |
| `docker logs [-f] [--tail 20] web` | lo que el proceso escribe en stdout y stderr |
| `docker exec -it web sh` | abrir un shell **dentro** de un contenedor en marcha |
| `docker inspect web` | toda la configuración y el estado, en JSON |
| `docker inspect web --format '{{.State.Status}}'` | un dato concreto, con una plantilla |

En un contenedor, los logs **no** van a un archivo: el proceso escribe en stdout y stderr, y Docker los guarda. Por eso Vigía escribe su log en stderr (clase 48).

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-57 && cd ~/my-devops-journey/labs/clase-57
```

### 1. Un servidor web en un segundo

```bash
docker run -d --name web -p 8080:80 nginx:1.29
docker ps
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080
```

Abre `http://localhost:8080` en el navegador. Acabas de desplegar nginx sin instalar nada en tu Ubuntu.

### 2. Logs y exec

```bash
curl -s localhost:8080 > /dev/null
docker logs --tail 3 web
docker exec web nginx -v
docker exec web sh -c 'head -1 /etc/os-release; ls /usr/share/nginx/html'
docker exec -it web sh
```

Dentro del shell: `ps aux` (¿cuántos procesos?), `cat /etc/nginx/conf.d/default.conf | head -12` y `exit`. Al salir, el contenedor sigue: `exec` abre un proceso **adicional** dentro, no el principal.

🔮 **Predice:** la imagen de nginx, ¿está basada en Ubuntu, en Debian o en Alpine? `head -1 /etc/os-release` te lo dice.

### 3. Cambiar algo dentro… y perderlo

```bash
docker exec web sh -c 'echo "<h1>Hola desde el contenedor</h1>" > /usr/share/nginx/html/index.html'
curl -s localhost:8080
docker rm -f web
docker run -d --name web -p 8080:80 nginx:1.29
curl -s localhost:8080 | head -4
```

🔮 **Predice:** ¿verás tu "Hola" en el contenedor nuevo? No: el cambio vivía en la capa escribible de **aquel** contenedor, que borraste. Los contenedores son desechables; lo que deba durar va en un volumen (clase 60) o en la imagen (clase 58).

### 4. Inspeccionar

```bash
docker inspect web --format '{{.State.Status}} desde {{.State.StartedAt}}'
docker inspect web --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
docker inspect web --format '{{json .NetworkSettings.Ports}}'
docker inspect web --format 'imagen {{.Config.Image}} · entrypoint {{.Config.Entrypoint}} · cmd {{.Config.Cmd}}'
```

El contenedor tiene su propia IP en una red interna de Docker (`172.17.x.x`, clase 61). `Entrypoint` y `Cmd` son lo que ejecuta al arrancar (clase 58).

### 5. Parar, arrancar y limpiar

```bash
docker stop web
docker ps -a --filter name=web
docker start web && docker ps
docker rm -f web
docker images
docker system df
docker container prune -f
```

`docker system df` dice cuánto disco ocupan imágenes, contenedores y volúmenes. `prune` borra lo que no se usa: `container prune` los contenedores parados e `image prune` las imágenes sin contenedor.

### 6. Variables de entorno y códigos de salida

```bash
docker run --rm -e SALUDO=hola alpine:3.22 sh -c 'echo $SALUDO'
docker run --rm alpine:3.22 sh -c 'exit 3' ; echo "código: $?"
```

`docker run` devuelve el código de salida del proceso del contenedor: tus scripts y tu CI pueden usarlo como el de cualquier comando (clase 04).

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

1. Arranca `postgres:18` en segundo plano con `-e POSTGRES_PASSWORD=prueba` y nombre `pg`. Sigue sus logs con `docker logs -f pg` hasta ver `database system is ready to accept connections` (`Ctrl+C` para dejar de seguirlos), y conéctate con `docker exec -it pg psql -U postgres` para ejecutar `SELECT version();`.
2. Con una sola plantilla de `docker inspect`, imprime el nombre, el estado y la IP de `pg`.
3. Arranca tres nginx en los puertos 8081, 8082 y 8083 con un bucle de Bash (clase 18), compruébalos con `curl` y bórralos con un solo comando (pista: `docker rm -f $(docker ps -q --filter ancestor=nginx:1.29)`).

## Cierre

En `notas/fase-5/clase-57.md`:

1. ¿Qué diferencia hay entre una imagen y un contenedor? Usa una comparación con AWS.
2. Explica `-p 8080:80`. ¿Qué pasa si no lo pones?
3. ¿Por qué se perdió el `index.html` que cambiaste al recrear el contenedor? ¿Dónde guardarías algo que deba durar?
4. **Repaso (clase 56, sin mirar):** ¿por qué `uname -r` dentro de un contenedor muestra el kernel de tu Ubuntu?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La imagen es la plantilla de solo lectura (sistema de archivos y configuración); el contenedor es un proceso creado a partir de ella, con su capa escribible. En AWS, la imagen sería una AMI y el contenedor una instancia EC2 lanzada desde esa AMI: de una AMI salen muchas instancias.

**2.** Publica el puerto 80 del contenedor en el 8080 de tu máquina: lo que llegue a `localhost:8080` se reenvía al 80 del contenedor. Sin `-p`, el servicio escucha solo en la red interna de Docker y desde tu navegador no llegas (sí desde otro contenedor de esa red, clase 61).

**3.** Porque el cambio estaba en la capa escribible de aquel contenedor, y al borrarlo se fue con él; el nuevo arranca limpio desde la imagen. Lo que deba durar va en un **volumen** (datos, clase 60) o dentro de la **imagen** (el código y los archivos de la aplicación, clase 58).

**4.** Porque el contenedor no tiene kernel propio: es un proceso del host aislado con *namespaces*, y usa el kernel de tu Ubuntu.

**Reto 2:** `docker inspect pg --format '{{.Name}} {{.State.Status}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`

**Reto 3:**
```bash
for p in 8081 8082 8083; do docker run -d --name "web-$p" -p "$p:80" nginx:1.29; done
for p in 8081 8082 8083; do curl -s -o /dev/null -w "$p → %{http_code}\n" "localhost:$p"; done
docker rm -f $(docker ps -q --filter ancestor=nginx:1.29)
```
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
