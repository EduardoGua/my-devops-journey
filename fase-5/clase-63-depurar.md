# Clase 63 — Depurar contenedores

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** en producción nadie te dice "falta la variable de entorno"; te dicen "el contenedor se reinicia sin parar". Para encontrar la causa en minutos hay un método de cinco pasos: el **estado** (`docker ps -a`), lo que **dijo** antes de morir (`docker logs`), lo que **sabe Docker** y tú no (`docker inspect`: el código de salida, si lo mató la falta de memoria, cuántas veces se reinició), cómo es **por dentro**, y comprobar el arreglo **desde fuera**. Hoy lo aprendes y lo aplicas a cinco averías reales.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los códigos de salida de la shell (clase 04) y las señales SIGTERM y SIGKILL (clase 11).
> - El OOM killer y `journalctl -k` (clase 14).
> - El método por capas y comprobar desde fuera (clase 34); las fichas de incidentes del P1 (clase 36).
> - `docker ps -a`, `logs`, `exec` e `inspect --format` (clase 57); `HEALTHCHECK` (clase 58); `--memory` y `docker stats` (clase 56).

> 🔤 **Palabras nuevas de hoy:**
> - **bucle de reinicios** (*crash loop*): un contenedor que muere y su política de reinicio relanza una y otra vez.
> - **`OOMKilled`**: el campo de `docker inspect` que dice si el kernel lo mató por pasarse de su límite de memoria.
> - **`RestartCount`**: cuántas veces lo ha relanzado su política de reinicio.
> - ***unhealthy***: el estado de un contenedor cuyo *healthcheck* falla, aunque el proceso siga vivo.
> - **causa raíz** (*root cause*): el motivo de fondo, no el síntoma.

## Objetivo

- Seguir un método para diagnosticar un contenedor que no arranca, se reinicia o no responde.
- Leer los códigos de salida de los contenedores: 0, 1, 125, 126, 127, 137 y 143.
- Sacar de `docker inspect` el dato decisivo: `ExitCode`, `OOMKilled`, `RestartCount`, `Error` y el log del *healthcheck*.
- Explorar una imagen que no arranca y comparar lo que publicas con lo que escucha la aplicación.
- Resolver cinco averías reales sin saber de antemano qué se rompió. Una es un criterio de salida de esta fase.

## Por qué importa

En producción nadie te dice "el problema es la variable de entorno". Te dicen "el contenedor se reinicia sin parar" o "la API no responde", y tienes que encontrar la causa en minutos. Es la misma habilidad del P1 (clase 36) con otras herramientas. Y vale tal cual en Kubernetes (fase 9): un pod en `CrashLoopBackOff` es un contenedor que se reinicia en bucle, y lo diagnosticarás igual.

## Cómo va esta clase

Cuatro piezas cortas con las herramientas y, después, **las cinco averías**, que son el centro de la clase. En cada pieza lees **una** idea y la pruebas enseguida.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 30 min); el segundo, las cinco averías, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-63 && cd ~/my-devops-journey/labs/clase-63
```

## Las piezas

### Pieza 1 — El método

```
1. ¿En qué estado está?          docker ps -a            (Up, Restarting, Exited (código), Created, unhealthy)
2. ¿Qué dijo antes de morir?     docker logs --tail 50   (la traza, el error, el último mensaje)
3. ¿Qué sabe Docker que no sé?   docker inspect          (ExitCode, OOMKilled, RestartCount, Error, Health)
4. ¿Cómo es por dentro?          docker exec / docker run --rm -it --entrypoint sh imagen
5. Hipótesis → arreglo → comprobar desde fuera (curl), como en la clase 34
```

**Pruébalo** con un contenedor que falla a propósito:

```bash
docker run --name prueba alpine:3.22 sh -c 'echo "no encuentro config.yaml" >&2; exit 3'
docker ps -a --filter name=prueba
docker logs prueba
docker inspect prueba --format '{{.State.ExitCode}} {{.Config.Cmd}}'
docker rm prueba
```

👀 **Qué deberías ver:** el mensaje de error al momento; en `docker ps -a`, `Exited (3) … seconds ago`; `docker logs` repite `no encuentro config.yaml`, porque Docker guarda stderr aunque el contenedor ya no corra; y `3 [sh -c echo "no encuentro config.yaml" >&2; exit 3]`: el código y el comando que ejecutaba. Pasos 1, 2 y 3 en 30 segundos.

✋ **Sin mirar:** ¿cuáles son los tres primeros comandos del método, en orden?

<details>
<summary>Comprueba</summary>

`docker ps -a` (el estado), `docker logs --tail 50` (lo que dijo) y `docker inspect` (lo que sabe Docker).
</details>

**En resumen:** estado → logs → inspect → por dentro → arreglo comprobado desde fuera.

### Pieza 2 — Los códigos de salida

| Código | Qué significa | Ejemplo típico |
|--------|---------------|----------------|
| 0 | el proceso terminó bien | un trabajo que acabó, o un contenedor sin nada que hacer |
| 1 (u otro pequeño) | la aplicación falló | una excepción de Python, una configuración que falta |
| 125 | falló el propio `docker run` | una opción mal escrita |
| 126 | el comando existe pero no se puede ejecutar | un archivo sin permiso `x` |
| 127 | el comando no existe | una errata en el `CMD`, un programa que la imagen no trae |
| 137 | 128 + 9: lo mató un **SIGKILL** | sin memoria (OOM) o un `docker stop` que agotó los 10 s |
| 143 | 128 + 15: terminó por **SIGTERM** | un `docker stop` normal |

Son los mismos códigos de la shell (clase 04) y de las señales (clase 11).

🔮 **Predice** el código de cada línea.

**Pruébalo:**

```bash
docker run --rm --opcion-inventada alpine:3.22 >/dev/null 2>&1 ; echo "código: $?"
docker run --rm alpine:3.22 /etc/hostname >/dev/null 2>&1 ; echo "código: $?"
docker run --rm alpine:3.22 no-existe >/dev/null 2>&1 ; echo "código: $?"
```

👀 **Qué deberías ver:** `125` (Docker no entiende la opción y ni siquiera crea el contenedor), `126` (`/etc/hostname` existe, pero no es ejecutable: `permission denied`) y `127` (`executable file not found in $PATH`). Quita el `>/dev/null 2>&1` de cualquiera para leer el mensaje completo.

✋ **Sin mirar:** un contenedor termina con 137. ¿Qué señal lo mató, y quién pudo enviarla?

<details>
<summary>Comprueba</summary>

SIGKILL (137 = 128 + 9). Pudo ser el kernel por falta de memoria, un `docker kill` o un `docker stop` que agotó sus 10 segundos.
</details>

**En resumen:** 125, 126 y 127, el arranque falló; 1, la aplicación; 137, SIGKILL; 143, SIGTERM.

### Pieza 3 — Lo que guarda `docker inspect`

```bash
docker inspect nombre --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.RestartCount}} {{.State.Error}}'
docker inspect nombre --format '{{json .State.Health}}'
docker inspect nombre --format '{{.Config.Cmd}} {{json .Config.Env}}'
```

- `OOMKilled: true`: el kernel lo mató por superar su límite de memoria (clase 14). La aplicación **no** deja nada en el log, porque SIGKILL no avisa.
- `RestartCount`: cuántas veces lo ha relanzado su política de reinicio.
- `State.Error`: el error de Docker, por ejemplo "executable file not found".
- `State.Health.Log`: la salida de las últimas comprobaciones del *healthcheck*.

**Pruébalo** con un bucle de reinicios corto: `--restart on-failure:3` lo relanza como mucho 3 veces.

```bash
docker run -d --name bucle --restart on-failure:3 alpine:3.22 sh -c 'echo "no encuentro la configuración" >&2; exit 1'
sleep 8
docker ps -a --filter name=bucle --format '{{.Status}}'
docker inspect bucle --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.RestartCount}}'
docker logs bucle
docker rm -f bucle
```

👀 **Qué deberías ver:** `Exited (1) …`; `1 false 3`: salió con 1, no fue la memoria y se reinició 3 veces; y el mensaje **cuatro** veces en los logs, uno por cada arranque. Con `--restart unless-stopped`, el contador seguiría subiendo sin fin: verías `Restarting (1)` en `docker ps -a`.

✋ **Sin mirar:** ¿por qué un contenedor que muere por falta de memoria suele tener el log vacío?

<details>
<summary>Comprueba</summary>

Porque SIGKILL no se puede capturar: el proceso muere al instante, sin ocasión de escribir nada. La pista está en `docker inspect` (`OOMKilled: true`).
</details>

**En resumen:** `docker inspect` da el código, `OOMKilled`, `RestartCount`, `Error` y la salud: los datos que el log no tiene.

### Pieza 4 — Herramientas para mirar dentro

| Comando | Para qué |
|---------|----------|
| `docker exec -it nombre sh` | entrar en un contenedor en marcha |
| `docker run --rm -it --entrypoint sh imagen` | explorar una imagen cuyo `CMD` falla |
| `docker cp nombre:/ruta/archivo .` | sacar un archivo (un log, una configuración) |
| `docker diff nombre` | qué archivos cambió el contenedor respecto a su imagen |
| `docker stats` | CPU y memoria en vivo |
| `docker events` | lo que hace Docker en tiempo real: arranques, muertes, *health* |

**Pruébalo:**

```bash
docker run -d --name mira nginx:1.29 && sleep 1
docker diff mira | head -8
docker cp mira:/etc/nginx/nginx.conf . && head -3 nginx.conf
docker run --rm --entrypoint sh nginx:1.29 -c 'ls /docker-entrypoint.d'
docker rm -f mira
```

👀 **Qué deberías ver:** en `docker diff`, líneas con `C` (cambiado) y `A` (añadido), como `C /etc/nginx/conf.d/default.conf` y `A /run/nginx.pid`: lo que el arranque escribió en la capa escribible. Después, el principio de la configuración de nginx ya en tu carpeta (`user  nginx;`, `worker_processes  auto;`). Y con `--entrypoint sh` sustituyes el programa de arranque de la imagen por un shell: los scripts que nginx ejecuta al arrancar (`10-listen-on-ipv6-by-default.sh`…). Así se explora una imagen que no llega a arrancar.

✋ **Sin mirar:** una imagen muere nada más arrancar y no puedes hacer `exec`. ¿Cómo miras dentro?

<details>
<summary>Comprueba</summary>

Con otro contenedor de la misma imagen en el que sustituyes el arranque por un shell: `docker run --rm -it --entrypoint sh imagen`.
</details>

**En resumen:** `exec` para lo que corre, `--entrypoint sh` para lo que no arranca, `cp` y `diff` para los archivos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-63` y las cinco averías.

## Las cinco averías

```bash
bash ~/my-devops-journey/recursos/clase-63/averias.sh
```

> 🙈 **Regla de honor:** no leas `averias.sh` más allá de su cabecera hasta haber resuelto las cinco. Lo que te entrena es diagnosticar, no leer la solución.

El script arranca cinco contenedores averiados y te da el aviso de cada uno, tal como lo reportaría un usuario. Para cada avería:

1. Aplica el método, paso a paso, y apunta cada comando y lo que te dijo.
2. Escribe la causa raíz en una frase.
3. Escribe el arreglo: el `docker run` corregido o lo que cambiarías en la imagen.
4. Compruébalo: arranca tu versión corregida con otro nombre (`arreglo-1`…) y verifica que funciona.

Plantilla para `notas/fase-5/clase-63.md`, una por avería. Este ejemplo, ya relleno, es el bucle de la pieza 3:

```markdown
## averia-0 (ejemplo)
Síntoma: el contenedor `bucle` no se queda en marcha.
Comandos y lo que vi:
1. `docker ps -a` → Exited (1)
2. `docker logs bucle` → "no encuentro la configuración", 4 veces
3. `docker inspect` → ExitCode 1, OOMKilled false, RestartCount 3
Causa raíz: la aplicación no encuentra su configuración y sale con 1; on-failure:3 la relanzó 3 veces.
Arreglo: montarle la configuración con `-v ./config.yaml:/app/config.yaml:ro` → comprobado con `docker ps` (Up).
```

Copia la estructura y rellena lo tuyo; una línea por campo basta.

Si llevas más de 20 minutos con una, abre **una** pista.

<details><summary>Pista — averia-1</summary>

El estado es `Created`: nunca llegó a correr. ¿Qué dice `{{.State.Error}}` en `docker inspect`? ¿Y qué comando intentó ejecutar (`{{.Config.Cmd}}`)?
</details>

<details><summary>Pista — averia-2</summary>

`docker ps -a` muestra `Restarting`, y `RestartCount` sube. La política `--restart` lo relanza cada vez que muere. ¿Por qué muere? `docker logs averia-2` lo dice en su última línea. ¿Qué falta en su entorno (`{{json .Config.Env}}`)?
</details>

<details><summary>Pista — averia-3</summary>

`Exited (137)` es 128 + 9: SIGKILL. Nadie hizo `docker kill`… ¿Qué dice `{{.State.OOMKilled}}`? ¿Qué límite de memoria tiene (`{{.HostConfig.Memory}}`, en bytes)?
</details>

<details><summary>Pista — averia-4</summary>

nginx responde (`docker exec averia-4 wget -qO- http://127.0.0.1:80` funciona), pero el estado es `unhealthy`. Mira el log del *healthcheck*: `docker inspect averia-4 --format '{{json .State.Health}}'`. ¿A qué puerto pregunta?
</details>

<details><summary>Pista — averia-5</summary>

`docker port averia-5` dice a qué puerto **del contenedor** llega tu `curl`. ¿Y en qué puerto escucha la aplicación? Mira su comando (`{{.Config.Cmd}}`). ¿Por qué `docker logs averia-5` está vacío, si `http.server` anuncia en qué puerto escucha?
</details>

Al terminar: `bash ~/my-devops-journey/recursos/clase-63/averias.sh limpiar`, y borra también tus `arreglo-N`.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker ps -a` | el estado y el último código de salida |
| `docker logs --tail 50 nombre` | lo último que escribió, aunque ya no corra |
| `docker inspect nombre --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.RestartCount}} {{.State.Error}}'` | lo que sabe Docker |
| `docker inspect nombre --format '{{json .State.Health}}'` | el log del *healthcheck* |
| `docker inspect nombre --format '{{.Config.Cmd}} {{json .Config.Env}}'` | qué ejecuta y con qué entorno |
| `docker port nombre` | qué puerto del contenedor está publicado |
| `docker run --rm -it --entrypoint sh imagen` | explorar una imagen que no arranca |
| `docker cp` · `docker diff` · `docker events` | sacar archivos · ver cambios · ver lo que pasa en vivo |
| 125 · 126 · 127 · 137 · 143 | docker run · sin permiso · no existe · SIGKILL · SIGTERM |

## Rómpelo

Las cinco averías ya son el Rómpelo de esta clase. Dos experimentos más:

**1. `docker events` en vivo.** En una terminal, `docker events --filter type=container`. En otra, vuelve a lanzar `averias.sh`. Verás pasar cada `create`, `start`, `die`, `oom`, `restart` y `health_status`: es el registro de lo que hace Docker, y la forma de ver un bucle de reinicios en tiempo real. `Ctrl+C` para salir.

**2. Un contenedor que tarda en pararse:**
```bash
docker run -d --name terco python:3.14-slim sh -c 'trap "" TERM; sleep 300'
time docker stop terco
docker inspect terco --format '{{.State.ExitCode}}'
docker rm terco
```
El shell ignora SIGTERM a propósito (`trap "" TERM`): `docker stop` espera 10 segundos, lo mata con SIGKILL y el código es **137**. Un 137 no siempre es falta de memoria: mira `OOMKilled` antes de concluir.

## Reto

En `labs/clase-63/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Prepara en tus notas un *runbook* para "un contenedor se reinicia en bucle", con los comandos en orden y qué buscar en cada uno. Te servirá tal cual en la fase 9.

> 🧩 **Ejemplo resuelto:** el método de la pieza 1 y el `averia-0` de las averías.

**Ahora tú, con huecos** (cópialo en tus notas y rellena; no hace falta escribir más):
```markdown
# Runbook: un contenedor se reinicia en bucle
1. `docker ps -a` → busco el estado ____ y el código entre paréntesis.
2. `docker logs --tail 50 nombre` → busco ____.
3. `docker inspect nombre --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.RestartCount}}'` → busco ____.
4. Si es 137 y OOMKilled es true → ____.
5. Si es 127 → ____.
6. Si es 1 → miro en `{{json .Config.Env}}` si falta ____.
7. Arreglo y compruebo desde fuera con ____.
```

<details>
<summary>Pista</summary>

Repasa la tabla de códigos de la pieza 2 y las pistas de las averías 1, 2 y 3: cada una corresponde a un caso del *runbook*.
</details>

**2.** Provoca tú una avería: un `CMD` que apunta a un script sin permiso de ejecución. ¿Qué código de salida da?

> 🧩 **Ejemplo resuelto:** la segunda línea de la pieza 2: `/etc/hostname` existe pero no es ejecutable → 126.

**Ahora tú, con huecos:**
```bash
printf '#!/bin/sh\necho hola\n' > arranque.sh
printf 'FROM alpine:3.22\nCOPY arranque.sh /arranque.sh\nRUN chmod ____ /arranque.sh\nCMD ["/arranque.sh"]\n' > Dockerfile
docker build -q -t sinpermiso .
docker run --name sp sinpermiso
docker inspect sp --format '{{.State.Status}} {{.State.ExitCode}}'
docker rm sp && docker rmi sinpermiso
```
Completa: «Da el código ____ y el estado ____, porque…».

<details>
<summary>Pista</summary>

`644` es lectura y escritura para el dueño y solo lectura para los demás: nadie lo puede ejecutar (clase 06).
</details>

**3.** Mira cuánta memoria de su límite usa un proceso que reserva 100 MB, y qué pasa si el límite es menor.

> 🧩 **Ejemplo resuelto:** `docker stats --no-stream limitado` de la clase 56, pieza 3: el consumo y el límite de un contenedor.

**Ahora tú, con huecos:**
```bash
docker run -d --name ocupado --memory 128m python:3.14-slim \
  python -c 'x = bytearray(100 * 1024 * 1024); import time; time.sleep(300)'
sleep 4; docker stats --no-stream ocupado
docker rm -f ocupado
docker run -d --name ocupado64 --memory 64m --memory-swap ____ python:3.14-slim \
  python -c 'x = bytearray(100 * 1024 * 1024); import time; time.sleep(300)'
sleep 4; docker inspect ocupado64 --format '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}'
docker rm -f ocupado64
```
Completa: «Con 128 MB usa el ____ % de su límite. Con 64 MB y sin swap, el contenedor ____ con el código ____».

<details>
<summary>Pista</summary>

Sin `--memory-swap`, Docker deja usar tanta swap como memoria, y un proceso de 100 MB cabe en 64 MB + 64 MB de swap (va más lento, pero vive). Con `--memory-swap` igual a `--memory`, no hay swap.
</details>

## Cierre

En `notas/fase-5/clase-63.md`, además de las cinco averías:

1. ¿Qué te dice un código de salida 137? ¿Cómo distingues un OOM de un `docker stop` que agotó el tiempo? *(2 líneas. Empieza así: «137 = 128 + 9: el proceso terminó por SIGKILL. Si `docker inspect` dice `OOMKilled: true`,… si es `false`,…»)*
2. Un contenedor se reinicia en bucle. Escribe tus tres primeros comandos y qué buscas en cada uno. *(3 líneas, una por comando. Empieza así: «`docker ps -a` → el estado `Restarting` y…»)*
3. ¿Por qué un contenedor que muere por falta de memoria no deja nada en su log? *(1–2 líneas. Empieza así: «Porque SIGKILL no se puede capturar:…»)*
4. **Repaso (clase 62, sin mirar):** ¿qué diferencia hay entre `docker compose down` y `docker compose down -v`? *(1–2 líneas. Empieza así: «`down` borra los contenedores y la red pero conserva…»)*

Después, escríbeme `examíname clase-63`.

## Autocorrección

<details>
<summary>Ábrelo solo cuando hayas resuelto las cinco averías</summary>

| Avería | Causa raíz | Dato decisivo | Arreglo |
|--------|------------|---------------|---------|
| 1 | errata en el comando: `pyhton` no existe en la imagen | `Created`, código 127 y `State.Error`: `exec: "pyhton": executable file not found in $PATH` | `docker run -d --name arreglo-1 python:3.14-slim python -m http.server 8000` |
| 2 | falta la variable `DATABASE_URL`: Python lanza `KeyError`, el proceso sale con 1 y `--restart` lo relanza sin fin | `Restarting (1)`, `RestartCount` creciente y `KeyError: 'DATABASE_URL'` en el log | añadir `-e DATABASE_URL=…` |
| 3 | la aplicación usa más memoria que su límite de 64 MB y el kernel la mata | `Exited (137)`, `OOMKilled: true` y el log vacío | darle más memoria (`--memory 512m`) o arreglar el consumo de la aplicación |
| 4 | el *healthcheck* pregunta al puerto 8080, pero nginx escucha en el 80 | `unhealthy`; el log del *health* dice `wget: can't connect … Connection refused` | `--health-cmd 'wget -q -O /dev/null http://127.0.0.1:80/ || exit 1'` |
| 5 | se publicó el puerto 80 del contenedor, pero la aplicación escucha en el 8000 | `docker port` → `80/tcp`, y el `Cmd` dice `http.server 8000`. El `curl` da `Connection reset by peer` | `-p 127.0.0.1:8085:8000` |

**El log vacío de averia-5:** Python guarda en un búfer lo que escribe en stdout cuando no es una terminal, y el mensaje de `http.server` no llegó a salir. Por eso las imágenes de las clases 59 y 62 llevan `PYTHONUNBUFFERED=1` (o se ejecuta `python -u`). En una avería de verdad, un log vacío puede ser solo eso.

**Cierre:**
1. 137 = 128 + 9: el proceso terminó por SIGKILL. Si `docker inspect` dice `OOMKilled: true`, fue el kernel por falta de memoria; si es `false`, alguien lo mató (un `docker kill`, o un `docker stop` que agotó sus 10 segundos porque el proceso ignoraba SIGTERM).
2. `docker ps -a` (confirma `Restarting` y el último código de salida), `docker logs --tail 50` (la traza o el error que lo hace morir) y `docker inspect` (`RestartCount`, `ExitCode`, `OOMKilled`, y la configuración: `Cmd` y `Env`).
3. Porque SIGKILL no se puede capturar: el kernel termina el proceso al instante, sin darle ocasión de escribir nada ni de limpiar. La pista está fuera del contenedor: `OOMKilled` en `docker inspect` y el log del kernel del host (`journalctl -k | grep -i oom`, clase 14).
4. `down` borra los contenedores y la red pero conserva los volúmenes; `down -v` borra también los volúmenes, y con ellos los datos.

**Reto 1:** `Restarting`; la traza o el último error; el código, si fue la memoria y cuántos reinicios; más memoria o menos consumo; una errata en el comando o un programa que la imagen no trae; una variable de entorno; `curl` (o `docker ps`, si no tiene puertos).

**Reto 2:** `chmod 644`. Código **126** y estado `created`: el archivo existe pero no tiene permiso de ejecución (`permission denied` en `State.Error`), así que el contenedor nunca llegó a correr.

**Reto 3:** con 128 MB usa más o menos el **82 %** de su límite (unos 105 MiB de 128 MiB). Con `--memory-swap 64m`, el contenedor muere: `exited 137 true`, matado por falta de memoria. Sin `--memory-swap`, en cambio, seguiría vivo usando swap.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| crash loop / restart loop | bucle de reinicios |
| exit code / exit status | código de salida |
| OOM killed (out of memory) | matado por falta de memoria |
| unhealthy | no sano (falla su comprobación de salud) |
| root cause | causa raíz |

🎙️ *"When a container is crash-looping, I check docker ps for the exit code, docker logs for the last error, and docker inspect for OOMKilled and the restart count, before touching anything."*

## Siguiente

[Clase 64 — Registros: publicar en Docker Hub](clase-64-registros.md)
