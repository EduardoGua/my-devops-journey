# Clase 60 — Volúmenes y persistencia

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

## Objetivo

- Entender por qué lo que se escribe dentro de un contenedor se pierde, y qué opciones hay para que dure.
- Usar **volúmenes con nombre** para los datos y **bind mounts** para compartir archivos con tu máquina.
- Montar archivos en solo lectura, como una configuración.
- Resolver el choque de permisos entre el usuario del contenedor y el de tu Ubuntu.
- Hacer y restaurar una copia de seguridad de un volumen.

## Por qué importa

Los contenedores son desechables (clase 57): se borran y se recrean en cada despliegue. Una base de datos, en cambio, no puede perder sus datos cada vez que actualizas la imagen. Separar **el proceso** (desechable) de **los datos** (permanentes) es el principio que verás en todas partes: los volúmenes de Docker, los discos EBS de una EC2 (fase 6) y los *PersistentVolumes* de Kubernetes (fase 9). En Vigía v2, la base de datos PostgreSQL vivirá en un volumen.

## Teoría

### Tres formas de montar algo en un contenedor

| Tipo | Ejemplo | Para qué |
|------|---------|----------|
| **Volumen con nombre** | `-v datos:/var/lib/postgresql` | datos que deben durar. Docker los guarda en `/var/lib/docker/volumes/` |
| **Bind mount** | `-v ./config.yaml:/app/config.yaml:ro` | compartir un archivo o carpeta **de tu máquina**: configuración, código en desarrollo |
| `tmpfs` | `--tmpfs /tmp` | en memoria: datos temporales que no deben tocar el disco |

En `-v origen:destino`, si el origen es una ruta (`./algo` o `/ruta`), es un *bind mount*; si es un nombre, un volumen. Añadir `:ro` lo monta en **solo lectura**.

### El volumen anónimo que "pierde" los datos

Muchas imágenes, como `postgres`, declaran en su Dockerfile un `VOLUME` para su carpeta de datos. Si no le das un volumen tuyo, Docker crea uno **anónimo** (con un nombre de 64 caracteres) para ese contenedor. Al borrar el contenedor y crear otro, el nuevo recibe **otro** volumen anónimo vacío: los datos no se borraron, pero quedaron en un volumen huérfano que nadie usa. La regla: datos importantes, siempre en un volumen **con nombre**.

### PostgreSQL 18 cambió dónde van los datos

Hasta PostgreSQL 17, el volumen se montaba en `/var/lib/postgresql/data`. Desde la imagen `postgres:18` se monta en **`/var/lib/postgresql`** (los datos van en una subcarpeta por versión, `18/docker`, para facilitar las actualizaciones). Si montas en la ruta vieja, el contenedor se niega a arrancar y explica por qué (Rómpelo 2). Casi todos los tutoriales de internet usan la ruta vieja: comprueba siempre la documentación de la imagen.

### Permisos: el número es lo que cuenta

Dentro y fuera del contenedor, los permisos se deciden por el **UID numérico**, no por el nombre. Tu usuario de Ubuntu es el 1000; el usuario `app` de tu imagen, el 10001. En un *bind mount* de una carpeta tuya, ese usuario no puede escribir (Rómpelo 3). Soluciones: usar un volumen con nombre (Docker lo prepara para el usuario de la imagen), ajustar los permisos de la carpeta, o arrancar con `--user $(id -u):$(id -g)`.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-60 && cd ~/my-devops-journey/labs/clase-60
```

### 1. Una base de datos que sobrevive

```bash
docker volume create pgdatos
docker run -d --name pg1 -e POSTGRES_PASSWORD=prueba -v pgdatos:/var/lib/postgresql postgres:18
sleep 5
docker exec pg1 psql -U postgres -c "CREATE TABLE notas (texto TEXT); INSERT INTO notas VALUES ('sobrevivo');"
docker rm -f pg1
docker run -d --name pg2 -e POSTGRES_PASSWORD=prueba -v pgdatos:/var/lib/postgresql postgres:18
sleep 5
docker exec pg2 psql -U postgres -tAc "SELECT texto FROM notas"
docker rm -f pg2
```

🔮 **Predice:** ¿encontrará `pg2` la tabla que creó `pg1`, un contenedor que ya no existe? Sí: los datos estaban en el volumen, no en el contenedor. Si `psql` dice que no puede conectar, espera unos segundos más: PostgreSQL tarda en arrancar.

```bash
docker volume ls
docker volume inspect pgdatos --format '{{.Mountpoint}}'
sudo ls /var/lib/docker/volumes/pgdatos/_data
```

Los volúmenes son carpetas normales en el disco del host, gestionadas por Docker. No las toques a mano: usa los comandos de Docker.

### 2. Sin volumen

```bash
docker run -d --name pg3 -e POSTGRES_PASSWORD=prueba postgres:18
docker inspect pg3 --format '{{range .Mounts}}{{.Type}} {{.Name}} → {{.Destination}}{{end}}'
docker rm -f pg3
docker volume ls --filter dangling=true
```

El contenedor recibió un volumen **anónimo**. Al borrarlo, el volumen queda huérfano (*dangling*): ocupa disco y ningún contenedor nuevo lo usará. `docker volume prune` los borra (pregunta antes). `docker run --rm` borra también los volúmenes anónimos del contenedor al terminar.

### 3. Un *bind mount*: tu carpeta dentro del contenedor

```bash
mkdir -p sitio && echo "<h1>Versión 1</h1>" > sitio/index.html
docker run -d --name web -p 8080:80 -v ./sitio:/usr/share/nginx/html:ro nginx:1.29
curl -s localhost:8080
echo "<h1>Versión 2, sin reconstruir nada</h1>" > sitio/index.html
curl -s localhost:8080
docker exec web sh -c 'echo hackeado > /usr/share/nginx/html/index.html'
docker rm -f web
```

Los cambios en tu carpeta se ven al instante dentro del contenedor: es la forma cómoda de desarrollar. Y con `:ro`, el contenedor no puede modificarla (`Read-only file system`). Así montarás el `config.yaml` de Vigía en Compose.

### 4. Copia de seguridad y restauración de un volumen

Un contenedor de usar y tirar monta el volumen y empaqueta su contenido con `tar` (clase 20):

```bash
docker run --rm -v pgdatos:/origen:ro -v ./:/destino alpine:3.22 tar -czf /destino/pgdatos.tar.gz -C /origen .
ls -lh pgdatos.tar.gz
docker volume rm pgdatos
docker volume create pgrestaurado
docker run --rm -v pgrestaurado:/destino -v ./:/origen:ro alpine:3.22 tar -xzf /origen/pgdatos.tar.gz -C /destino
docker run -d --name pg4 -e POSTGRES_PASSWORD=prueba -v pgrestaurado:/var/lib/postgresql postgres:18
sleep 5 && docker exec pg4 psql -U postgres -tAc "SELECT texto FROM notas"
docker rm -f pg4 && docker volume rm pgrestaurado
```

Para PostgreSQL en producción se usa `pg_dump` (una copia consistente aunque la base esté escribiendo); copiar los archivos así es seguro solo con la base de datos **parada**, como aquí.

## Rómpelo

**1. Borrar un volumen en uso:**
```bash
docker volume create usado
docker run -d --name ocupa -v usado:/datos alpine:3.22 sleep 300
docker volume rm usado
docker rm -f ocupa && docker volume rm usado
```
`volume is in use`. Docker protege los volúmenes que usa algún contenedor (aunque esté parado). Primero el contenedor, luego el volumen.

**2. La ruta de antes en PostgreSQL 18:**
```bash
docker run -d --name pgviejo -e POSTGRES_PASSWORD=prueba -v pgviejo:/var/lib/postgresql/data postgres:18
sleep 5
docker ps -a --filter name=pgviejo --format '{{.Status}}'
docker logs pgviejo 2>&1 | tail -12
docker rm pgviejo && docker volume rm pgviejo
```
El contenedor sale con error y su log explica el cambio: desde la versión 18, el volumen va en `/var/lib/postgresql`. Leer el log antes de buscar en internet te ahorra la mitad de las búsquedas.

**3. El usuario del contenedor no puede escribir en tu carpeta:**
```bash
mkdir -p salida
docker run --rm --user 10001 -v ./salida:/salida alpine:3.22 touch /salida/archivo
docker run --rm --user "$(id -u):$(id -g)" -v ./salida:/salida alpine:3.22 touch /salida/archivo
ls -ln salida
```
Con el UID 10001, `Permission denied`: la carpeta es del 1000 (tú). Con tu propio UID, funciona, y el archivo queda a tu nombre. Esto pasa al montar código o datos tuyos en imágenes que no corren como root, como la tuya de la clase 59.

## Reto

1. Arranca la API de la clase 53 (copia `api.py` e `historial.db` a una carpeta y escribe un Dockerfile como el de la clase 59) con la base de datos en un **volumen con nombre** montado en `/datos`, y la variable `HISTORIAL_DB=/datos/historial.db`. Pista: copia la base de datos al volumen con un contenedor auxiliar, como en la copia de seguridad, y recuerda los permisos del usuario 10001 (`chown` dentro de ese contenedor auxiliar).
2. Mide cuánto ocupan los volúmenes con `docker system df -v`, y limpia los huérfanos con `docker volume prune`.
3. ¿Qué pasa si montas un *bind mount* sobre una carpeta de la imagen que ya tenía archivos (por ejemplo, `-v ./vacia:/usr/share/nginx/html`)? Pruébalo y explica lo que ves.

## Cierre

En `notas/fase-5/clase-60.md`:

1. ¿Qué diferencia hay entre un volumen con nombre y un *bind mount*? ¿Cuándo usas cada uno?
2. ¿Qué es un volumen anónimo y por qué "pierde" los datos al recrear el contenedor?
3. ¿Por qué el usuario 10001 del contenedor no puede escribir en una carpeta tuya, y cómo lo resuelves?
4. **Repaso (clase 59, sin mirar):** ¿por qué no sirven `ENV` ni `ARG` para pasar un secreto?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un volumen con nombre lo gestiona Docker (vive en `/var/lib/docker/volumes/`) y es la opción para los **datos** de una aplicación, como una base de datos. Un *bind mount* monta una ruta concreta de **tu máquina**: sirve para compartir archivos que gestionas tú, como una configuración (`:ro`) o el código mientras desarrollas.

**2.** Un volumen sin nombre que Docker crea solo cuando la imagen declara un `VOLUME` y tú no montas nada ahí. Pertenece a ese contenedor: al recrearlo, el nuevo recibe otro volumen anónimo vacío, y los datos quedan en el viejo, huérfano. Por eso los datos importantes van en un volumen con nombre.

**3.** Porque los permisos se deciden por el UID numérico: la carpeta es del UID 1000 y el proceso corre con el 10001, que para ella es "otros". Se resuelve con un volumen con nombre en lugar de una carpeta tuya, arrancando con tu UID (`--user "$(id -u):$(id -g)"`) o dando permisos a ese UID en la carpeta.

**4.** Porque quedan guardados en la imagen (`docker inspect` muestra los `ENV` y `docker history` los `ARG`), y la imagen se comparte. Los secretos llegan al ejecutar, como variables de entorno o archivos de secretos.

**Reto 3:** el *bind mount* **tapa** el contenido de la imagen en esa ruta: el contenedor ve tu carpeta vacía y nginx responde 403. Los archivos de la imagen siguen ahí debajo, pero ocultos mientras dure el montaje.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| volume / bind mount | volumen / montaje de una ruta del host |
| persistent data | datos persistentes |
| read-only mount | montaje de solo lectura |
| dangling volume | volumen huérfano |
| backup / restore | copia de seguridad / restauración |

🎙️ *"Containers are disposable, data is not: databases always get a named volume, configuration comes in as a read-only bind mount, and I test restoring from a backup, not just making one."*

## Siguiente

[Clase 61 — Redes de Docker](clase-61-redes.md)
