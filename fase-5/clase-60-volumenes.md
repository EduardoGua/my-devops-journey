# Clase 60 — Volúmenes y persistencia

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** lo que un contenedor escribe se pierde al borrarlo (clase 57). Para que algo dure, se **monta** desde fuera: un **volumen con nombre** para los datos (lo gestiona Docker) o un ***bind mount*** para compartir archivos de tu máquina, como una configuración. Separar el proceso, que es desechable, de los datos, que no lo son, es el principio que verás en los discos EBS de AWS y en Kubernetes.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La capa escribible y por qué los contenedores son desechables (clase 57); `postgres:18` y `psql` (clase 57, reto 1).
> - `docker inspect --format` con `{{range …}}` (clase 57).
> - El usuario 10001 sin privilegios de tu imagen (clase 59).
> - Los permisos, el dueño y el UID (clases 06 y 09); `tar -czf` y las copias de seguridad (clase 20).

> 🔤 **Palabras nuevas de hoy:**
> - **volumen con nombre**: una carpeta que gestiona Docker, con un nombre tuyo, que sobrevive a los contenedores.
> - ***bind mount***: montar una ruta concreta de tu máquina dentro del contenedor.
> - **`:ro`**: montar en solo lectura (*read-only*).
> - **volumen anónimo**: el que Docker crea solo, con un nombre de 64 caracteres, si la imagen lo pide y tú no montas nada.
> - **volumen huérfano** (*dangling*): un volumen que ya no usa ningún contenedor.

## Objetivo

- Entender por qué lo que se escribe dentro de un contenedor se pierde, y qué opciones hay para que dure.
- Usar **volúmenes con nombre** para los datos y **bind mounts** para compartir archivos con tu máquina.
- Montar archivos en solo lectura, como una configuración.
- Resolver el choque de permisos entre el usuario del contenedor y el de tu Ubuntu.
- Hacer y restaurar una copia de seguridad de un volumen.

## Por qué importa

Los contenedores son desechables (clase 57): se borran y se recrean en cada despliegue. Una base de datos, en cambio, no puede perder sus datos cada vez que actualizas la imagen. Separar **el proceso** (desechable) de **los datos** (permanentes) es el principio que verás en todas partes: los volúmenes de Docker, los discos EBS de una EC2 (fase 6) y los *PersistentVolumes* de Kubernetes (fase 9). En Vigía v2, la base de datos PostgreSQL vivirá en un volumen.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 30 min); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre. No borres el volumen `pgdatos` entre un día y otro: la pieza 4 lo usa.

```bash
mkdir -p ~/my-devops-journey/labs/clase-60 && cd ~/my-devops-journey/labs/clase-60
```

## Las piezas

### Pieza 1 — Un volumen con nombre: datos que sobreviven

| Tipo | Ejemplo | Para qué |
|------|---------|----------|
| **Volumen con nombre** | `-v datos:/var/lib/postgresql` | datos que deben durar. Docker los guarda en `/var/lib/docker/volumes/` |
| **Bind mount** | `-v ./config.yaml:/app/config.yaml:ro` | compartir un archivo o carpeta **de tu máquina**: configuración, código en desarrollo |
| `tmpfs` | `--tmpfs /tmp` | en memoria: datos temporales que no deben tocar el disco |

En `-v origen:destino`, si el origen es una ruta (`./algo` o `/ruta`), es un *bind mount*; si es un nombre, un volumen. Añadir `:ro` lo monta en **solo lectura**.

**PostgreSQL 18 cambió dónde van los datos.** Hasta PostgreSQL 17, el volumen se montaba en `/var/lib/postgresql/data`. Desde la imagen `postgres:18` se monta en **`/var/lib/postgresql`** (los datos van en una subcarpeta por versión, `18/docker`, para facilitar las actualizaciones). Si montas en la ruta vieja, el contenedor se niega a arrancar y explica por qué (Rómpelo 2). Casi todos los tutoriales de internet usan la ruta vieja: comprueba siempre la documentación de la imagen.

🔮 **Predice:** ¿encontrará `pg2` la tabla que creó `pg1`, un contenedor que ya no existe?

**Pruébalo:**

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
docker volume ls
docker volume inspect pgdatos --format '{{.Mountpoint}}'
sudo ls /var/lib/docker/volumes/pgdatos/_data
```

👀 **Qué deberías ver:** `CREATE TABLE` e `INSERT 0 1`, y después `sobrevivo`: los datos estaban en el volumen, no en el contenedor. Si `psql` dice que no puede conectar, espera unos segundos más: PostgreSQL tarda en arrancar. `docker volume ls` muestra `pgdatos`; su `Mountpoint` es `/var/lib/docker/volumes/pgdatos/_data`, y dentro está la carpeta `18`. Los volúmenes son carpetas normales en el disco del host, gestionadas por Docker. No las toques a mano: usa los comandos de Docker.

✋ **Sin mirar:** ¿dónde se monta el volumen de datos en `postgres:18`, y qué pasa si usas la ruta de las versiones anteriores?

<details>
<summary>Comprueba</summary>

En `/var/lib/postgresql`. Con la ruta vieja, `/var/lib/postgresql/data`, el contenedor se niega a arrancar y su log explica el cambio.
</details>

**En resumen:** `-v nombre:/ruta` monta un volumen con nombre; los datos sobreviven a los contenedores.

### Pieza 2 — El volumen anónimo que "pierde" los datos

Muchas imágenes, como `postgres`, declaran en su Dockerfile un `VOLUME` para su carpeta de datos. Si no le das un volumen tuyo, Docker crea uno **anónimo** (con un nombre de 64 caracteres) para ese contenedor. Al borrar el contenedor y crear otro, el nuevo recibe **otro** volumen anónimo vacío: los datos no se borraron, pero quedaron en un volumen huérfano que nadie usa. La regla: datos importantes, siempre en un volumen **con nombre**.

**Pruébalo:**

```bash
docker run -d --name pg3 -e POSTGRES_PASSWORD=prueba postgres:18
docker inspect pg3 --format '{{range .Mounts}}{{.Type}} {{.Name}} → {{.Destination}}{{end}}'
docker rm -f pg3
docker volume ls --filter dangling=true
```

👀 **Qué deberías ver:** `volume 9a1d30bb5fc7…(64 caracteres) → /var/lib/postgresql`: el contenedor recibió un volumen **anónimo**. Al borrarlo, ese volumen aparece en la lista de huérfanos (*dangling*): ocupa disco y ningún contenedor nuevo lo usará. `docker volume prune` los borra (pregunta antes). `docker run --rm` borra también los volúmenes anónimos del contenedor al terminar.

✋ **Sin mirar:** recreas un contenedor de PostgreSQL que usaba un volumen anónimo. ¿Se borraron los datos?

<details>
<summary>Comprueba</summary>

No: siguen en el volumen anónimo viejo, ahora huérfano. Pero el contenedor nuevo recibe otro volumen vacío y no los ve.
</details>

**En resumen:** sin volumen tuyo, Docker crea uno anónimo por contenedor; al recrear, los datos quedan huérfanos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-60`.

### Pieza 3 — Un *bind mount*: tu carpeta dentro del contenedor

Con un *bind mount*, el contenedor ve una carpeta o un archivo **de tu máquina**: los cambios de un lado se ven al instante en el otro. Con `:ro`, el contenedor solo puede leerlo.

**Pruébalo:**

```bash
mkdir -p sitio && echo "<h1>Versión 1</h1>" > sitio/index.html
docker run -d --name web -p 8080:80 -v ./sitio:/usr/share/nginx/html:ro nginx:1.29
curl -s localhost:8080
echo "<h1>Versión 2, sin reconstruir nada</h1>" > sitio/index.html
curl -s localhost:8080
docker exec web sh -c 'echo hackeado > /usr/share/nginx/html/index.html'
docker rm -f web
```

👀 **Qué deberías ver:** `<h1>Versión 1</h1>` y, sin reiniciar nada, `<h1>Versión 2, sin reconstruir nada</h1>`: es la forma cómoda de desarrollar. Y el intento de escribir desde dentro falla con `cannot create /usr/share/nginx/html/index.html: Read-only file system`, por el `:ro`. Así montarás el `config.yaml` de Vigía en Compose.

✋ **Sin mirar:** en `-v ./sitio:/usr/share/nginx/html:ro`, ¿cómo sabe Docker que es un *bind mount* y no un volumen?

<details>
<summary>Comprueba</summary>

Porque el origen es una ruta (`./sitio`); si fuera un nombre a secas, sería un volumen.
</details>

**En resumen:** `-v ./ruta:/destino[:ro]` comparte una carpeta tuya; `:ro` impide que el contenedor la cambie.

### Pieza 4 — Copia de seguridad y restauración de un volumen

Un contenedor de usar y tirar monta el volumen y empaqueta su contenido con `tar` (clase 20). Para PostgreSQL en producción se usa `pg_dump` (una copia consistente aunque la base esté escribiendo); copiar los archivos así es seguro solo con la base de datos **parada**, como aquí.

**Pruébalo:**

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

👀 **Qué deberías ver:** un `pgdatos.tar.gz` de unos pocos MB; tras borrar el volumen original y restaurar la copia en uno nuevo, `sobrevivo` otra vez. Una copia de seguridad solo vale si has probado a restaurarla.

✋ **Sin mirar:** ¿por qué esta copia por archivos solo es segura con PostgreSQL parado?

<details>
<summary>Comprueba</summary>

Porque con la base de datos escribiendo, los archivos pueden copiarse a medio cambiar y la copia quedaría inconsistente. En producción se usa `pg_dump`.
</details>

**En resumen:** un contenedor auxiliar con el volumen montado y `tar` hace la copia y la restauración.

### Pieza 5 — Permisos: el número es lo que cuenta

Dentro y fuera del contenedor, los permisos se deciden por el **UID numérico**, no por el nombre. Tu usuario de Ubuntu es el 1000; el usuario `app` de tu imagen, el 10001. En un *bind mount* de una carpeta tuya, ese usuario no puede escribir (Rómpelo 3). Soluciones: usar un volumen con nombre (Docker lo prepara para el usuario de la imagen), ajustar los permisos de la carpeta, o arrancar con `--user $(id -u):$(id -g)`.

**Pruébalo:**

```bash
docker run --rm --user 10001 -v ./sitio:/sitio alpine:3.22 sh -c 'id; ls -ln /sitio'
ls -ln sitio
```

👀 **Qué deberías ver:** dentro, `uid=10001 gid=0(root)` (Alpine no tiene ningún usuario con ese número, así que no le pone nombre) y el `index.html` con dueño `1000 1000`; fuera, el mismo `1000 1000`. Para el proceso 10001, ese archivo es de "otros".

✋ **Sin mirar:** dentro del contenedor no existe ningún usuario llamado `educo`. ¿Cómo sabe el kernel que el archivo es tuyo?

<details>
<summary>Comprueba</summary>

Por el número: el archivo es del UID 1000, el tuyo. Los nombres son solo una traducción de cada sistema; el kernel compara números.
</details>

**En resumen:** los permisos van por UID; el 10001 del contenedor no es el 1000 de tu carpeta.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker volume create datos` · `docker volume ls` · `docker volume rm datos` | crear, listar, borrar volúmenes |
| `-v datos:/ruta` | montar un volumen con nombre |
| `-v ./carpeta:/ruta:ro` | *bind mount* de solo lectura |
| `--tmpfs /tmp` | en memoria |
| `docker volume inspect datos --format '{{.Mountpoint}}'` | dónde vive en el host |
| `docker volume ls --filter dangling=true` · `docker volume prune` | huérfanos · borrarlos |
| `docker run --rm -v datos:/origen:ro -v ./:/destino alpine:3.22 tar -czf …` | copia de seguridad de un volumen |
| `--user "$(id -u):$(id -g)"` | correr con tu UID |
| `-v pg:/var/lib/postgresql` | los datos de `postgres:18` |

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
`Exited (1)`, y su log explica el cambio: *"The suggested container configuration for 18+ is to place a single mount at /var/lib/postgresql"*. Leer el log antes de buscar en internet te ahorra la mitad de las búsquedas.

**3. El usuario del contenedor no puede escribir en tu carpeta:**
```bash
mkdir -p salida
docker run --rm --user 10001 -v ./salida:/salida alpine:3.22 touch /salida/archivo
docker run --rm --user "$(id -u):$(id -g)" -v ./salida:/salida alpine:3.22 touch /salida/archivo
ls -ln salida
```
Con el UID 10001, `Permission denied`: la carpeta es del 1000 (tú). Con tu propio UID, funciona, y el archivo queda a tu nombre. Esto pasa al montar código o datos tuyos en imágenes que no corren como root, como la tuya de la clase 59.

## Reto

En `labs/clase-60/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Arranca la API de la clase 53 en un contenedor, con la base de datos en un **volumen con nombre** montado en `/datos` y la variable `HISTORIAL_DB=/datos/historial.db`.

> 🧩 **Ejemplo resuelto:** la restauración de la pieza 4: un contenedor auxiliar monta el volumen y una carpeta tuya, y copia de una a otro.

**Ahora tú, con huecos:**
```bash
mkdir -p api && cd api
cp ../../clase-53/api.py ../../clase-51/historial.db ../../clase-59/Dockerfile ../../clase-59/requirements.txt .
sed -i 's/app\.py/api.py/; s/"app:app"/"api:app"/' Dockerfile
docker build -q -t historial-api .
docker volume create historial
docker run --rm -v historial:/datos -v ./:/origen:ro alpine:3.22 \
  sh -c 'cp /origen/historial.db /datos/ && chown -R ____ /datos'
docker run -d --name hapi -p 8000:8000 -e HISTORIAL_DB=____ -v ____:/datos historial-api
sleep 2; curl -s localhost:8000/stats
```

<details>
<summary>Pista</summary>

La API corre con el usuario 10001 (clase 59): dale a ese UID la carpeta del volumen. `HISTORIAL_DB` es la ruta **dentro** del contenedor. El volumen se llama `historial`.
</details>

**2.** Mide cuánto ocupan los volúmenes y limpia los huérfanos.

> 🧩 **Ejemplo resuelto:** `docker system df` de la clase 57, pieza 5, que resume el espacio por tipo.

**Ahora tú, con huecos:**
```bash
docker system df -v | grep -A 10 "Local ____"
docker volume ls --filter dangling=____
docker volume ____
```

<details>
<summary>Pista</summary>

Con `-v`, `docker system df` da el detalle de cada imagen, contenedor y volumen, en secciones con título. `prune` pregunta antes de borrar.
</details>

**3.** ¿Qué pasa si montas un *bind mount* sobre una carpeta de la imagen que ya tenía archivos? Pruébalo y explica lo que ves.

> 🧩 **Ejemplo resuelto:** la pieza 3: `-v ./sitio:/usr/share/nginx/html:ro` hizo que nginx sirviera **tu** `index.html` en lugar del suyo.

**Ahora tú, con huecos:**
```bash
mkdir -p vacia
docker run -d --name tapado -p 8082:80 -v ./vacia:/usr/share/nginx/html nginx:1.29
curl -s -o /dev/null -w "%{http_code}\n" localhost:8082
docker exec tapado ls /usr/share/nginx/html
docker rm -f tapado
```
Completa: «Responde ____ y la carpeta se ve ____, porque el *bind mount* ____ el contenido de la imagen en esa ruta».

<details>
<summary>Pista</summary>

nginx responde 403 (*Forbidden*) cuando la carpeta no tiene `index.html`. Los archivos de la imagen no se borran: siguen debajo, ocultos mientras dure el montaje.
</details>

## Cierre

En `notas/fase-5/clase-60.md`:

1. ¿Qué diferencia hay entre un volumen con nombre y un *bind mount*? ¿Cuándo usas cada uno? *(2 líneas. Empieza así: «Un volumen con nombre lo gestiona Docker y sirve para los datos, como… Un bind mount monta una ruta de mi máquina y sirve para…»)*
2. ¿Qué es un volumen anónimo y por qué "pierde" los datos al recrear el contenedor? *(2 líneas. Empieza así: «Es un volumen que Docker crea solo cuando la imagen declara un `VOLUME` y… Al recrear el contenedor, el nuevo recibe…»)*
3. ¿Por qué el usuario 10001 del contenedor no puede escribir en una carpeta tuya, y cómo lo resuelves? *(2 líneas. Empieza así: «Porque los permisos se deciden por el UID numérico: la carpeta es del 1000 y… Lo resuelvo con…»)*
4. **Repaso (clase 59, sin mirar):** ¿por qué no sirven `ENV` ni `ARG` para pasar un secreto? *(1–2 líneas. Empieza así: «Porque quedan guardados en la imagen:…»)*

Después, escríbeme `examíname clase-60`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un volumen con nombre lo gestiona Docker (vive en `/var/lib/docker/volumes/`) y es la opción para los **datos** de una aplicación, como una base de datos. Un *bind mount* monta una ruta concreta de **tu máquina**: sirve para compartir archivos que gestionas tú, como una configuración (`:ro`) o el código mientras desarrollas.

**2.** Un volumen sin nombre que Docker crea solo cuando la imagen declara un `VOLUME` y tú no montas nada ahí. Pertenece a ese contenedor: al recrearlo, el nuevo recibe otro volumen anónimo vacío, y los datos quedan en el viejo, huérfano. Por eso los datos importantes van en un volumen con nombre.

**3.** Porque los permisos se deciden por el UID numérico: la carpeta es del UID 1000 y el proceso corre con el 10001, que para ella es "otros". Se resuelve con un volumen con nombre en lugar de una carpeta tuya, arrancando con tu UID (`--user "$(id -u):$(id -g)"`) o dando permisos a ese UID en la carpeta.

**4.** Porque quedan guardados en la imagen (`docker inspect` muestra los `ENV` y `docker history` los `ARG`), y la imagen se comparte. Los secretos llegan al ejecutar, como variables de entorno o archivos de secretos.

**Reto 1:** `chown -R 10001 /datos`, `HISTORIAL_DB=/datos/historial.db` y `-v historial:/datos`. `/stats` devuelve las tres disponibilidades de la clase 51. Al terminar: `docker rm -f hapi`.

**Reto 2:** `"Local Volumes"`, `dangling=true` y `docker volume prune`.

**Reto 3:** responde `403` y la carpeta se ve vacía: el *bind mount* **tapa** el contenido de la imagen en esa ruta. Los archivos de la imagen siguen ahí debajo, pero ocultos mientras dure el montaje.
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
