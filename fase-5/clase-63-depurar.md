# Clase 63 — Depurar contenedores

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Contenedores

## Objetivo

- Seguir un método para diagnosticar un contenedor que no arranca, se reinicia o no responde.
- Leer los códigos de salida de los contenedores: 0, 1, 125, 126, 127, 137 y 143.
- Sacar de `docker inspect` el dato decisivo: `ExitCode`, `OOMKilled`, `RestartCount`, `Error` y el log del *healthcheck*.
- Explorar una imagen que no arranca y comparar lo que publicas con lo que escucha la aplicación.
- Resolver cinco averías reales sin saber de antemano qué se rompió. Una es un criterio de salida de esta fase.

## Por qué importa

En producción nadie te dice "el problema es la variable de entorno". Te dicen "el contenedor se reinicia sin parar" o "la API no responde", y tienes que encontrar la causa en minutos. Es la misma habilidad del P1 (clase 36) con otras herramientas. Y vale tal cual en Kubernetes (fase 9): un pod en `CrashLoopBackOff` es un contenedor que se reinicia en bucle, y lo diagnosticarás igual.

## Teoría

### El método

```
1. ¿En qué estado está?          docker ps -a            (Up, Restarting, Exited (código), Created, unhealthy)
2. ¿Qué dijo antes de morir?     docker logs --tail 50   (la traza, el error, el último mensaje)
3. ¿Qué sabe Docker que no sé?   docker inspect          (ExitCode, OOMKilled, RestartCount, Error, Health)
4. ¿Cómo es por dentro?          docker exec / docker run --rm -it --entrypoint sh imagen
5. Hipótesis → arreglo → comprobar desde fuera (curl), como en la clase 34
```

### Los códigos de salida

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

### Lo que guarda `docker inspect`

```bash
docker inspect nombre --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.RestartCount}} {{.State.Error}}'
docker inspect nombre --format '{{json .State.Health}}'
docker inspect nombre --format '{{.Config.Cmd}} {{json .Config.Env}}'
```

- `OOMKilled: true`: el kernel lo mató por superar su límite de memoria (clase 14). La aplicación **no** deja nada en el log, porque SIGKILL no avisa.
- `RestartCount`: cuántas veces lo ha relanzado su política de reinicio.
- `State.Error`: el error de Docker, por ejemplo "executable file not found".
- `State.Health.Log`: la salida de las últimas comprobaciones del *healthcheck*.

### Herramientas para mirar dentro

| Comando | Para qué |
|---------|----------|
| `docker exec -it nombre sh` | entrar en un contenedor en marcha |
| `docker run --rm -it --entrypoint sh imagen` | explorar una imagen cuyo `CMD` falla |
| `docker cp nombre:/ruta/archivo .` | sacar un archivo (un log, una configuración) |
| `docker diff nombre` | qué archivos cambió el contenedor respecto a su imagen |
| `docker stats` | CPU y memoria en vivo |
| `docker events` | lo que hace Docker en tiempo real: arranques, muertes, *health* |

## Práctica guiada: cinco averías

```bash
mkdir -p ~/my-devops-journey/labs/clase-63 && cd ~/my-devops-journey/labs/clase-63
bash ~/my-devops-journey/recursos/clase-63/averias.sh
```

> 🙈 **Regla de honor:** no leas `averias.sh` más allá de su cabecera hasta haber resuelto las cinco. Lo que te entrena es diagnosticar, no leer la solución.

El script arranca cinco contenedores averiados y te da el aviso de cada uno, tal como lo reportaría un usuario. Para cada avería:

1. Aplica el método, paso a paso, y anota **cada comando** y lo que te dijo.
2. Escribe la causa raíz en una frase.
3. Escribe cómo la arreglarías: el `docker run` corregido o lo que cambiarías en la imagen.
4. Compruébalo: arranca tu versión corregida con otro nombre (`arreglo-1`…) y verifica que funciona.

Plantilla para `notas/fase-5/clase-63.md`, una por avería:

```markdown
## averia-N
Síntoma: …
Comandos y lo que vi:
1. `docker ps -a` → …
2. …
Causa raíz: …
Arreglo: `docker run …` → comprobado con …
```

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

1. Escribe en tus notas un *runbook* de una página: "un contenedor se reinicia en bucle", con los comandos en orden y qué buscar en cada uno. Te servirá tal cual en la fase 9.
2. Provoca tú una avería más: un `CMD` que apunta a un script sin permiso de ejecución (`chmod 644`). ¿Qué código de salida da? Compruébalo con la tabla.
3. Lanza `docker run -d --name ocupado --memory 128m python:3.14-slim python -c 'x = bytearray(100 * 1024 * 1024); import time; time.sleep(300)'` y mira con `docker stats --no-stream` qué porcentaje de su límite usa. ¿Qué pasaría con `--memory 64m`?

## Cierre

En `notas/fase-5/clase-63.md`, además de las cinco averías:

1. ¿Qué te dice un código de salida 137? ¿Cómo distingues un OOM de un `docker stop` que agotó el tiempo?
2. Un contenedor se reinicia en bucle. Escribe tus tres primeros comandos y qué buscas en cada uno.
3. ¿Por qué un contenedor que muere por falta de memoria no deja nada en su log?
4. **Repaso (clase 62, sin mirar):** ¿qué diferencia hay entre `docker compose down` y `docker compose down -v`?

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

**Reto 2:** código **126**: el archivo existe pero no tiene permiso de ejecución (`permission denied` en `State.Error`).
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
