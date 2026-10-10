# Clase 66 — Proyecto: Vigía v2 (II): Compose con API, chequeo y base de datos

**Dónde:** tu Ubuntu + GitHub + Docker Hub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** B. Proyecto · **Proyecto de portafolio**

## Objetivo

Levantar Vigía entero con un solo comando: tres servicios en un `compose.yaml` (la base de datos, la API y el chequeo), con los datos en un volumen, la contraseña fuera de Git, la API publicada solo en tu máquina y todo sano según sus *healthchecks*. Después, publicar la imagen en Docker Hub, actualizar el README y cerrar la versión `v2`.

Criterio de salida de la fase: *levantas Vigía con `docker compose up` desde un clon limpio del repo*.

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R9 | `compose.yaml` con tres servicios: `db` (`postgres:18`), `api` (tu imagen, con `serve`) y `checker` (la misma imagen, con `check --interval 60`) | 62, 65 |
| R10 | `db`: volumen **con nombre** en `/var/lib/postgresql`, *healthcheck* con `pg_isready` y **ningún** puerto publicado | 60, 61, 62 |
| R11 | `api` y `checker` reciben la base de datos por `DATABASE_URL` (con el **nombre del servicio** `db`, no `localhost`), montan `config.yaml` en solo lectura y esperan a que `db` esté sana | 61, 62 |
| R12 | `api`: puerto publicado **solo** en `127.0.0.1:8000` y un *healthcheck* que pide `/health` | 61, 62 |
| R13 | Todos los servicios se reinician solos (`restart: unless-stopped`) | 62 |
| R14 | La contraseña de PostgreSQL llega de un `.env` que está en `.gitignore`; en Git hay un `.env.example`, y el `compose.yaml` usa `${POSTGRES_PASSWORD:?…}` | 62 |
| R15 | `bash ~/my-devops-journey/recursos/vigia/v2/verify.sh` termina con `Fallos: 0` | — |
| R16 | La imagen publicada en Docker Hub como `TU_USUARIO/vigia:2.0.0` | 64 |
| R17 | README en inglés: cómo levantarlo desde un clon limpio, la arquitectura, cómo ver los logs y los datos, *What broke and how I found it* y los límites. PR fusionado, etiqueta `v2` y release | 25 |

## La arquitectura

```
                     tu Ubuntu
  curl / navegador ──► 127.0.0.1:8000
                             │
  ┌────────────── red del proyecto (Compose) ──────────────┐
  │                          ▼                             │
  │   ┌─────────────┐   ┌──────────┐                       │
  │   │   checker   │   │   api    │                       │
  │   │ check       │   │ serve    │                       │
  │   │ --interval  │   │ :8000    │                       │
  │   └──────┬──────┘   └────┬─────┘                       │
  │          │ escribe       │ lee                         │
  │          └───────┬───────┘                             │
  │                  ▼                                     │
  │           ┌────────────┐                               │
  │           │     db     │──► volumen con nombre "datos" │
  │           │ postgres   │                               │
  │           │ :5432      │                               │
  │           └────────────┘                               │
  └────────────────────────────────────────────────────────┘
```

El chequeo y la API no hablan entre sí: los dos hablan con `db`. Solo la API sale fuera de Docker, y solo hacia tu máquina.

## Plan de trabajo

En la misma rama `docker` de la clase 65.

**Bloque 1: el Compose**
1. `compose.yaml` con los tres servicios. Parte del contador de la clase 62 y sigue la tabla del contrato.
2. `.env.example` (en Git) y `.env` (fuera de Git: compruébalo con `git status`).
3. `docker compose config -q` y después `docker compose up -d --build --wait`.
4. Comprueba a mano: `docker compose ps`, `curl -s 127.0.0.1:8000/status | jq` (espera un minuto a la primera ronda del chequeo) y `docker compose logs checker`.
5. Pasa `verify.sh` (abajo) y arregla lo que falle. Commit.

**Bloque 2: publicar y cerrar**

6. Publica la imagen en Docker Hub (clase 64).
7. Quita la línea de cron de la v1 (`crontab -e`): ahora el chequeo corre en Compose, y con `restart: unless-stopped` vuelve a arrancar cada vez que se inicia Docker.
8. README, prueba del clon limpio (Rómpelo 4), PR, *squash and merge*, etiqueta `v2` y release.

### Las pruebas de aceptación

```bash
cd ~/vigia
bash ~/my-devops-journey/recursos/vigia/v2/verify.sh
```

Construye tu imagen, levanta tu Compose y lo comprueba desde fuera: archivos, usuario sin privilegios, puertos, que el chequeo escribe en PostgreSQL y la API lo muestra, que los datos sobreviven a `down` y `up`, y que el chequeo se para en menos de 8 segundos. Tarda unos 2–3 minutos y deja Vigía corriendo (con `--limpiar`, lo para al terminar). Lee cada `❌`: dice qué esperaba.

## Pistas

<details><summary>Pista 1 — la API no conecta: "connection refused" a localhost</summary>

Es el Rómpelo 1 de la clase 61: dentro del contenedor de la API, `localhost` es la propia API. En `DATABASE_URL`, el servidor es el nombre del servicio: `postgresql://vigia:${POSTGRES_PASSWORD}@db:5432/vigia`.
</details>

<details><summary>Pista 2 — dos servicios con la misma imagen</summary>

Construye la imagen en un solo servicio y reutilízala en el otro por su nombre:

```yaml
  api:
    build: .
    image: vigia:dev
    command: ["serve", "--host", "0.0.0.0", "--port", "8000"]
  checker:
    image: vigia:dev
    command: ["check", "--interval", "60"]
```
`command` sustituye el `CMD` de la imagen; el `ENTRYPOINT` (`python -m vigia`) se mantiene.
</details>

<details><summary>Pista 3 — <code>/status</code> sigue vacío</summary>

¿Escribe el chequeo en la misma base de datos que lee la API? Si al `checker` le falta `DATABASE_URL`, usa el `vigia.db` de la configuración, dentro de su propio contenedor (y además sin permiso de escritura). Mira `docker compose logs checker`.
</details>

<details><summary>Pista 4 — "duplicate key value violates unique constraint" al arrancar</summary>

La API y el chequeo arrancan casi a la vez y los dos intentan `CREATE TABLE IF NOT EXISTS` en el mismo instante. PostgreSQL puede rechazar al segundo con ese error. Captura `psycopg.errors.UniqueViolation` (y `DuplicateTable`) al crear la tabla e ignóralo: si falló porque la otra la creó, ya existe. `restart: unless-stopped` también lo arreglaría, con un reinicio de por medio.
</details>

<details><summary>Pista 5 — la API sale "unhealthy"</summary>

La imagen `slim` no trae `curl`: el *healthcheck* debe usar Python, como en la clase 62. Y recuerda que el `healthcheck` se ejecuta **dentro** del contenedor: ahí la API escucha en `127.0.0.1:8000`.
</details>

## Rómpelo: antes de etiquetar

1. **La base de datos se cae.** `docker compose stop db`, mira `docker compose logs --tail 5 checker` y pide `/status` (código 500). `docker compose start db`: en la siguiente ronda, el chequeo vuelve a escribir sin que reinicies nada.
2. **Un reinicio del portátil.** Reinicia tu Ubuntu y, sin tocar nada, `docker compose ps` dentro de `~/vigia`: los tres servicios vuelven solos (`restart: unless-stopped`).
3. **Sin `.env`.** `mv .env /tmp/ && docker compose config -q ; mv /tmp/.env .`: Compose se niega y explica qué falta.
4. **El clon limpio**, el criterio de salida:
   ```bash
   docker compose down
   cd /tmp && rm -rf vigia-limpio && git clone https://github.com/TU_USUARIO/vigia.git vigia-limpio && cd vigia-limpio
   cp .env.example .env
   docker compose up -d --build --wait
   curl -s 127.0.0.1:8000/health ; echo
   docker compose down -v && cd ~/vigia && docker compose up -d --wait
   ```
   Solo con lo que hay en Git y los pasos del README. Si algo falla, falta algo en el repo o en el README. (Esta prueba usa la rama `main`: hazla después de fusionar el PR.)

## Entregable

- `compose.yaml`, `Dockerfile`, `.dockerignore`, `.env.example` y el código de la clase 65.
- La imagen `TU_USUARIO/vigia:2.0.0` en Docker Hub.
- README en inglés con estas secciones nuevas:

````markdown
## Run it with Docker Compose
```bash
git clone https://github.com/<you>/vigia.git && cd vigia
cp .env.example .env        # then set a real password
docker compose up -d --build --wait
curl -s 127.0.0.1:8000/status
```

## Architecture
(the three services, what each one does, and which port is published)

## Operations
(how to see the logs of each service, query the database, stop it and back up the volume)
````

- Etiqueta y release:

```bash
git switch main && git pull
git tag -a v2 -m "v2: Docker image and Compose stack with PostgreSQL"
git push origin v2
gh release create v2 --title "v2" --notes "Multi-stage non-root image, Compose with API, checker and PostgreSQL. Image: <you>/vigia:2.0.0"
```

## Cierre

En `notas/fase-5/clase-66.md`:

1. Explica la arquitectura de Vigía v2: qué hace cada servicio, cómo se encuentran y qué está publicado.
2. ¿Por qué el chequeo ya no necesita cron? ¿Qué hace que vuelva a arrancar tras reiniciar el portátil?
3. ¿Qué te enseñó `verify.sh` que no habrías comprobado a mano?
4. **Repaso (clase 65, sin mirar):** ¿qué pasaría con `docker stop` si tu chequeo no atendiera SIGTERM?

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify.sh</code> termine con <code>Fallos: 0</code></summary>

**Comprueba tu entrega:**
- [ ] `verify.sh` → `Fallos: 0`.
- [ ] `git status` limpio y `git ls-files | grep -c '^\.env$'` → `0`.
- [ ] El clon limpio funciona solo con el README.
- [ ] `docker pull TU_USUARIO/vigia:2.0.0` funciona en otra máquina (o tras borrar la imagen local).
- [ ] La línea de cron de la v1 ya no está (`crontab -l`).
- [ ] `git tag` muestra `v2`, con su release.

**Cierre:**
1. `db` es PostgreSQL, con sus datos en un volumen con nombre y sin puertos publicados. `checker` ejecuta `check --interval 60` y escribe cada ronda en `db`. `api` ejecuta `serve` y lee de `db` en cada petición. Se encuentran por nombre gracias al DNS de la red que Compose crea para el proyecto, con `DATABASE_URL` apuntando a `db:5432`. Solo la API está publicada, y solo en `127.0.0.1:8000`.
2. Porque el propio contenedor repite el chequeo con `--interval`, y Docker lo supervisa: con `restart: unless-stopped`, si muere lo relanza, y cuando arranca el demonio de Docker (al encender el portátil) vuelve a arrancar los servicios que no paraste a mano. Es el mismo papel que hacía systemd con los servicios de la clase 12.
3. Respuesta personal. Lo habitual: que los datos sobrevivan a `down` y `up`, que el chequeo se pare rápido (SIGTERM) o que la base de datos no tenga puertos publicados.
4. Python, como PID 1 sin manejador, ignoraría SIGTERM: `docker stop` esperaría 10 segundos y lo mataría con SIGKILL, quizá a mitad de una escritura en la base de datos.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| stack / service | conjunto de servicios / servicio |
| clean clone | clon limpio |
| to publish an image | publicar una imagen |
| supervision / restart policy | supervisión / política de reinicio |
| operations runbook | guía de operación |

🎙️ *"Vigía v2 runs as a Compose stack: a non-root API and a checker built from the same image, and PostgreSQL with a named volume. Only the API is published, on localhost, and everything comes up from a clean clone with one command."*

## Al terminar la fase 5

1. Marca las clases 65 y 66 y Vigía v2 en [`PROGRESO.md`](../PROGRESO.md).
2. Revisa los **criterios de salida de la fase 5**.
3. Anota tus horas en el registro mensual de la Ruta 2.0.
4. **Antes de empezar la fase 6** (AWS), pídeme `revisa la fase 6`: el plan gratuito de AWS y el examen CLF cambian, y lo compruebo todo de nuevo. Recuerda que la cuenta de AWS se abre ese día, no antes.

## Siguiente

[Fase 6 — Clase 67: La víspera: tu cuenta de AWS sin sorpresas](../fase-6/clase-67-la-vispera.md)
