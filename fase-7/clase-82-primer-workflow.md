# Clase 82 — CI/CD y tu primer workflow

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Integración continua

> 💡 **La idea de hoy:** hasta ahora, cada cambio de Vigía pedía los mismos pasos a mano: lint, pruebas, construir, subir, desplegar. Un **pipeline** los hace igual cada vez, para cada cambio. En GitHub Actions, un **workflow** (un YAML en `.github/workflows/`) reacciona a un **evento** y ejecuta **jobs** en máquinas nuevas, los *runners*. Hoy escribes el primero, pasas un dato de un job a otro y fijas cada *action* por su commit, porque una action es código ajeno con acceso a tus secretos.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - YAML (clase 47) y el formato de cron, en UTC (clase 20).
> - Los commits, las etiquetas y `gh` (clases 22 y 24); `shellcheck` (clase 19).
> - Una etiqueta se mueve y un *digest* no (clase 64); el ataque a Trivy (clase 59).
> - `docker run --rm -v` (clases 57 y 60).

> 🔤 **Palabras nuevas de hoy:**
> - **integración continua** (CI): cada cambio se verifica solo, en minutos.
> - **entrega continua / despliegue continuo**: cada cambio queda listo para desplegar / se despliega solo.
> - **workflow / job / step**: el archivo YAML / un conjunto de pasos en una máquina / un paso.
> - **runner**: la máquina virtual, nueva para cada job, que ejecuta los pasos.
> - **action**: un paso reutilizable que alguien publicó, como `actions/checkout`.
> - **expresión** `${{ … }}`: un valor que GitHub sustituye antes de ejecutar.
> - **`$GITHUB_OUTPUT`**: el archivo donde un step escribe los datos que pasa a otros.

## Objetivo

- Distinguir **integración continua**, **entrega continua** y **despliegue continuo**, y qué problema resuelve cada una.
- Entender las piezas de **GitHub Actions**: eventos, *workflows*, *jobs*, *steps*, *runners* y *actions*.
- Escribir tu primer workflow en un repositorio de prácticas y seguirlo desde la web y desde `gh`.
- Pasar datos entre *steps* y entre *jobs*.
- Revisar un workflow con **actionlint** antes de subirlo, y fijar las *actions* por su **commit**.

## Por qué importa

Hasta ahora, cada vez que cambiabas Vigía hacías a mano lo mismo:
- `ruff`, `pytest`, `docker build`;
- subir la imagen;
- entrar en la instancia;
- `docker compose up`.

Cualquier paso olvidado o hecho en otro orden es un fallo esperando a ocurrir. Un pipeline lo hace igual, cada vez, para cada cambio y para cada persona del equipo.

En las ofertas de empleo, "CI/CD" aparece casi siempre. Y la pregunta de entrevista "¿qué diferencia hay entre entrega y despliegue continuos?" es uno de los criterios de salida de la fase.

## Costo esperado

> 💰 **0 USD.** GitHub Actions es gratis en los repositorios públicos con los runners estándar. En los privados, el plan Free incluye 2000 minutos al mes.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida (en tu Ubuntu, en GitHub o, en dos de ellas, en papel); no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 50 min, con tu primer workflow en verde); el segundo, las **piezas 5 y 6**, el Rómpelo, el reto y el cierre.

## Las piezas

### Pieza 1 — CI, entrega continua y despliegue continuo

| Práctica | Qué significa | Qué resuelve |
|----------|---------------|--------------|
| **Integración continua (CI)** | cada cambio se integra pronto en la rama principal y se **verifica solo**: lint, pruebas, que construye | encontrar los errores en minutos, cuando aún sabes qué tocaste, y no semanas después |
| **Entrega continua** (*continuous delivery*) | cada cambio que pasa la CI queda **listo para desplegar**: por ejemplo, la imagen publicada en ECR. El paso a producción es una decisión humana, un botón | desplegar deja de ser un evento arriesgado y raro |
| **Despliegue continuo** (*continuous deployment*) | además, cada cambio que pasa todas las comprobaciones **se despliega solo** en producción | cero pasos manuales entre el *merge* y los usuarios |

```
commit ─► CI: lint + pruebas + build ─► artefacto publicado ─► [¿botón?] ─► producción
          └──── integración continua ┘└──── entrega continua ──┘
          └────────────────────── despliegue continuo (sin botón) ─────────────────────┘
```

Vigía v4 hará **despliegue continuo**: al unir a `main`, se despliega solo. Las protecciones son las pruebas obligatorias (clase 84), la prueba de humo y la vuelta atrás automática (clase 89).

**Pruébalo, en papel.** ¿Integración continua, entrega continua o despliegue continuo? Escríbelo antes de abrir la respuesta:

1. Cada PR pasa `ruff` y `pytest` solo, y GitHub marca el PR en rojo si fallan.
2. Al unir a `main`, la imagen queda en ECR; para desplegarla, alguien pulsa un botón.
3. Al unir a `main`, la nueva versión ya está en la EC2 a los cinco minutos, sin que nadie haga nada.

<details>
<summary>Comprueba</summary>

1, integración continua. 2, entrega continua. 3, despliegue continuo.
</details>

✋ **Sin mirar:** ¿qué tiene la entrega continua que no tiene el despliegue continuo?

<details>
<summary>Comprueba</summary>

Un paso humano: alguien decide cuándo pasar a producción. En el despliegue continuo, ese paso no existe.
</details>

**En resumen:** CI verifica cada cambio; entrega continua lo deja listo; despliegue continuo lo despliega solo.

### Pieza 2 — Las actions, fijadas por su commit

Una *action* es código de otra persona que se ejecuta **con acceso a tu repositorio y a tus secretos**. Si escribes `uses: actions/checkout@v7`, ejecutas lo que la etiqueta `v7` señale **hoy**, y una etiqueta se puede mover.

En marzo de 2025 alguien comprometió la action `tj-actions/changed-files`, movió sus etiquetas a un commit malicioso, y miles de repositorios imprimieron sus secretos en los logs. En 2026 le pasó a Trivy (clase 59).

La defensa es fijar el **commit**, que no se puede mover, y dejar la versión en un comentario:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

**Pruébalo:** busca tú el commit de esa versión.

```bash
git ls-remote https://github.com/actions/checkout 'refs/tags/v7.0.1*'
```

👀 **Qué deberías ver:** `3d3c42e5aac5ba805825da76410c181273ba90b1	refs/tags/v7.0.1`: el mismo SHA de 40 caracteres de la línea de arriba. Si la etiqueta es anotada, salen dos líneas: la buena es la que termina en `^{}`.

✋ **Sin mirar:** ¿por qué `@v7` es más peligroso que `@3d3c42e…`?

<details>
<summary>Comprueba</summary>

Porque la etiqueta `v7` la puede mover su autor, o quien le robe la cuenta, a otro código; un SHA es la huella del contenido y no se puede cambiar.
</details>

**En resumen:** cada `uses:` de terceros, con el SHA completo del commit y la versión en un comentario.

### Pieza 3 — Las piezas de GitHub Actions, y tu primer workflow

```
evento (push, pull_request, workflow_dispatch, schedule…)
  └── workflow: un archivo YAML en .github/workflows/
        ├── job "lint" ── en un runner (una máquina virtual nueva) ── steps: uses: … / run: …
        └── job "test" ── en OTRO runner, en paralelo (con needs: se ordenan)
```

| Pieza | Qué es |
|-------|--------|
| **Workflow** | el archivo YAML con todo |
| **Evento** | lo que lo dispara: `push`, `pull_request`, `workflow_dispatch` (un botón), `schedule` (cron en UTC, como en la clase 20) |
| **Job** | un conjunto de pasos que corre en **un** runner |
| **Step** | un paso: un comando (`run:`) o una *action* (`uses:`) |
| **Runner** | la máquina que ejecuta el job. Las de GitHub son máquinas virtuales **nuevas** para cada job (`ubuntu-24.04` trae Docker, Compose, la AWS CLI, `jq` y `shellcheck`) y se destruyen al terminar |
| **Action** | un paso reutilizable que alguien publicó: `actions/checkout` descarga tu repositorio en el runner |
| **Expresión** | `${{ … }}`: GitHub la sustituye **antes** de ejecutar. Por ejemplo, `${{ github.sha }}` |

Consecuencias que conviene tener claras:
- **Los steps de un job comparten** disco y variables de entorno del runner.
- **Los jobs no comparten nada:** cada uno arranca en una máquina limpia. Para pasar datos de uno a otro se usan *outputs* o artefactos (pieza 5).
- **Primero el checkout:** el runner empieza vacío. Sin `actions/checkout`, tu código no está ahí.
- **`ubuntu-latest` se mueve,** como `latest` en Docker (clase 64): hoy es `ubuntu-24.04`, mañana será otra. Pon la versión.

**Pruébalo.** Un repositorio de prácticas, público para que Actions sea gratis (lo usarás hasta la clase 86):

```bash
cd ~ && gh repo create lab-actions --public --clone --add-readme
cd lab-actions && mkdir -p .github/workflows
```

Crea `.github/workflows/hola.yml`:

```yaml
name: hola

on:
  push:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  saludo:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: ¿Dónde estoy?
        run: |
          echo "Evento: ${{ github.event_name }} · commit: $GITHUB_SHA · rama: $GITHUB_REF_NAME"
          grep PRETTY_NAME /etc/os-release
          python3 --version
          ls -la
      - name: Un resumen en la página de la ejecución
        run: echo "### Hola desde el runner de $GITHUB_REPOSITORY" >> "$GITHUB_STEP_SUMMARY"
```

- **`permissions: contents: read`:** el token que GitHub da al workflow solo puede leer el código. Lo verás a fondo en la clase 85; desde hoy, todos tus workflows lo llevan.
- **`$GITHUB_SHA` y `$GITHUB_REF_NAME`:** son variables de entorno que GitHub pone en el runner.
- **`${{ github.event_name }}`:** es una expresión; el resultado es el mismo dato.
- **`$GITHUB_STEP_SUMMARY`:** un archivo especial; lo que escribas ahí aparece en la página de la ejecución, en Markdown.

👀 **Qué deberías ver:** `gh repo create` te deja dentro de `lab-actions`, con un `README.md`; y en `ls .github/workflows`, tu `hola.yml`. Todavía no corre nada: falta subirlo (pieza 4).

✋ **Sin mirar:** ¿por qué el primer paso de casi todos los jobs es `actions/checkout`?

<details>
<summary>Comprueba</summary>

Porque el runner es una máquina nueva y vacía: sin el checkout, tu código no está ahí.
</details>

**En resumen:** evento → workflow → jobs en runners nuevos → steps con `run:` o `uses:`; empieza por el checkout.

### Pieza 4 — Revisarlo con actionlint, y verlo correr

**actionlint** encuentra errores de YAML, claves mal escritas, expresiones imposibles y fallos de `shellcheck` dentro de los `run:`. Pasarlo antes de cada `push` te ahorra ciclos de "sube, falla, corrige". Necesita estar dentro de un repositorio de Git, porque busca `.github/workflows/` desde su raíz.

🔮 **Predice** el sistema operativo y la versión de Python que dirá el runner, y qué mostrará `ls -la`.

**Pruébalo:**

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
echo $?
git add .github && git commit -m "Primer workflow" && git push
gh run list --limit 3
gh run watch
gh run view --log | head -40
```

👀 **Qué deberías ver:** actionlint sin salida y `0`: el workflow es válido. Después, la ejecución en `gh run list`, `gh run watch` siguiéndola hasta `✓`, y en el log: `Evento: push · commit: … · rama: main`, `PRETTY_NAME="Ubuntu 24.04… LTS"` (el del runner, no el tuyo), su Python 3.12 y, en `ls -la`, tu `README.md` y `.github`, gracias al checkout. Todo en unos segundos. Abre también la ejecución en la web (pestaña **Actions** del repositorio): cada step se despliega con su log, y arriba está tu resumen.

Lánzalo a mano, gracias a `workflow_dispatch`:

```bash
gh workflow run hola.yml
sleep 5 && gh run list --limit 2
```

👀 **Qué deberías ver:** una ejecución nueva con el evento `workflow_dispatch`.

✋ **Sin mirar:** ¿qué evento permite lanzar un workflow con un botón o con `gh workflow run`?

<details>
<summary>Comprueba</summary>

`workflow_dispatch`.
</details>

**En resumen:** actionlint antes de subir; `gh run list`, `gh run watch` y `gh run view --log` para seguir la ejecución.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/lab-actions`.

### Pieza 5 — Dos jobs que se pasan un dato

Los jobs no comparten disco, pero sí pueden pasarse datos pequeños:
1. Un step escribe `clave=valor` en `$GITHUB_OUTPUT`.
2. El job lo publica en `outputs:`.
3. El job siguiente lo lee con `needs.<job>.outputs.<clave>`.

`needs:` hace además que un job espere a otro. Es el mismo mecanismo que usará Vigía v4 para pasar la versión de la imagen del job que la construye al que la despliega.

🔮 **Predice:** ¿en qué orden corren los tres jobs?

**Pruébalo.** Añade estos dos jobs debajo de `saludo`, al mismo nivel, pásale actionlint y súbelo:

```yaml
  fecha:
    runs-on: ubuntu-24.04
    outputs:
      hoy: ${{ steps.calcular.outputs.hoy }}
    steps:
      - id: calcular
        run: echo "hoy=$(date -u +%F)" >> "$GITHUB_OUTPUT"

  usa-la-fecha:
    needs: fecha
    runs-on: ubuntu-24.04
    steps:
      - run: echo "El job anterior dice que hoy es ${{ needs.fecha.outputs.hoy }}"
```

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git commit -am "Dos jobs que se pasan la fecha" && git push
gh run watch
```

👀 **Qué deberías ver:** en el gráfico de la ejecución, en la web, `saludo` y `fecha` a la vez, en paralelo, y `usa-la-fecha` después, unido a `fecha` por una línea: el `needs:`. En su log, `El job anterior dice que hoy es 2026-…`, con la fecha de hoy.

✋ **Sin mirar:** ¿dónde escribe un step el dato que quiere pasar a otro job?

<details>
<summary>Comprueba</summary>

En `$GITHUB_OUTPUT`, como `clave=valor`; el job lo publica en `outputs:` y el otro lo lee con `needs.<job>.outputs.<clave>`.
</details>

**En resumen:** `$GITHUB_OUTPUT` → `outputs:` del job → `needs.<job>.outputs.<clave>`; `needs:` ordena los jobs.

### Pieza 6 — Otros disparadores

Así se escriben los eventos más comunes (no los apliques todavía):

```yaml
on:
  pull_request:                 # cada PR (lo usarás en la clase 83)
  push:
    branches: [main]            # solo los push a main
    paths: ["**.py"]            # …y solo si cambió algún .py
  schedule:
    - cron: "0 6 * * 1"         # los lunes a las 06:00 UTC
  workflow_dispatch:            # un botón en la web y `gh workflow run`
```

`schedule` tiene sus manías: corre solo en la rama principal; se puede retrasar en horas de mucha carga; y en los repositorios públicos se desactiva solo tras 60 días sin actividad.

**Pruébalo, en papel.** Con ese `on:`, ¿se dispara el workflow? Escríbelo antes de abrir la respuesta:

1. Un `push` a `main` que solo cambia el `README.md`.
2. Un `push` a la rama `prueba` que cambia `app.py`.
3. Abrir un PR desde `prueba` hacia `main`.

<details>
<summary>Comprueba</summary>

1, no: es en `main`, pero no cambia ningún `.py`. 2, no: el `push` solo cuenta en `main`. 3, sí: `pull_request` no tiene filtros.
</details>

✋ **Sin mirar:** ¿en qué zona horaria se escribe el `cron` de un `schedule`?

<details>
<summary>Comprueba</summary>

En UTC.
</details>

**En resumen:** `push` y `pull_request` con filtros de rama y ruta, `schedule` en UTC y `workflow_dispatch` para lanzarlo a mano.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `on: push / pull_request / workflow_dispatch / schedule` | los eventos |
| `permissions: contents: read` | el token del workflow, solo lectura |
| `runs-on: ubuntu-24.04` | el runner, con versión |
| `- uses: owner/action@<SHA de 40> # vX.Y.Z` · `- run: …` | un step con una action fijada · con un comando |
| `${{ github.event_name }}` · `$GITHUB_SHA` · `$GITHUB_REF_NAME` | datos del evento |
| `echo "clave=valor" >> "$GITHUB_OUTPUT"` · `outputs:` · `needs:` | pasar datos entre jobs |
| `echo "…" >> "$GITHUB_STEP_SUMMARY"` | un resumen en la página de la ejecución |
| `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12` | revisar antes de subir |
| `gh run list` · `gh run watch` · `gh run view --log` · `gh workflow run` | seguir y lanzar ejecuciones |
| `git ls-remote https://github.com/<owner>/<action> 'refs/tags/vX.Y.Z*'` | el SHA de una versión |

## Rómpelo

**1. YAML mal indentado.** Crea `.github/workflows/roto.yml`:

```yaml
name: roto
on: push
jobs:
  mal:
    runs-on: ubuntu-24.04
    steps:
     - run: echo hola
      - run: echo adiós
```

Pásale actionlint: `could not parse as YAML: did not find expected '-' indicator`. Si lo subes sin revisar, GitHub marca la ejecución como *Invalid workflow file* y no corre nada. Bórralo.

**2. Un step que falla:**

```yaml
      - run: exit 1
      - run: echo "esto no se ve"
      - if: failure()
        run: echo "esto sí: solo corre cuando algo falló"
```

Añádelo al final de `saludo` y súbelo. El job se pone en rojo en el `exit 1`, el step siguiente se salta y el de `if: failure()` corre: así se recogen los logs cuando algo se rompe (lo usarás en la clase 83). Quita esas líneas después.

**3. Los jobs no comparten disco.** En `fecha`, añade un step `run: echo secreto > dato.txt`; en `usa-la-fecha`, `run: cat dato.txt`. `No such file or directory`: cada job arranca en una máquina nueva. Para pasar datos: *outputs*, como en la pieza 5, o artefactos (`actions/upload-artifact` y `download-artifact`). Deshazlo.

## Reto

En `~/lab-actions`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Detecta las actions sin fijar.** Una línea de `grep` que liste los `uses:` de tus workflows que **no** acaben en un SHA de 40 caracteres hexadecimales. La versión de `verify.sh` de la v4 hace exactamente esto.

> 🧩 **Ejemplo resuelto:** `grep -hE 'uses:' .github/workflows/*.yml` lista **todos** los `uses:` de tus workflows, sin el nombre del archivo (`-h`).

**Ahora tú, con huecos:**
```bash
grep -hE '^[[:space:]]*(-[[:space:]]*)?uses:' .github/workflows/*.yml \
  | grep -vE 'uses:[[:space:]]*\./' \
  | grep -vE '@[0-9a-f]{____}([[:space:]]|$)'
```
Pruébala cambiando un `uses:` a `@v7`: debe mostrar esa línea, y solo esa. Deshaz el cambio.

<details>
<summary>Pista</summary>

`-v` invierte el `grep`: deja pasar lo que **no** encaja. La segunda línea quita las actions locales (`./…`), que están en tu propio repositorio y no hace falta fijar. Un SHA completo tiene 40 caracteres.
</details>

**2.** **Una matriz.** Haz que `saludo` corra en `ubuntu-24.04` y en `ubuntu-26.04`. ¿Qué dice actionlint, y cómo se lo arreglas?

> 🧩 **Ejemplo resuelto:** una matriz que repite un job con dos versiones de Python:
> ```yaml
> strategy:
>   matrix:
>     python: ["3.13", "3.14"]
> ```
> y en los steps se usa `${{ matrix.python }}`.

**Ahora tú, con huecos:**
```yaml
  saludo:
    strategy:
      matrix:
        os: [ubuntu-24.04, ____]
    runs-on: ${{ matrix.____ }}
```
Pásale actionlint. Después crea `.github/actionlint.yaml`:
```yaml
self-hosted-runner:
  labels:
    - ____
```
y vuelve a pasarlo. Completa: «Sin el archivo, actionlint dice ____».

<details>
<summary>Pista</summary>

actionlint conoce las etiquetas de runner que existían al publicarse; `ubuntu-26.04` es más nueva. Su configuración permite declarar etiquetas que no conoce.
</details>

**3.** ¿A qué hora de Colombia correría `cron: "0 6 * * 1"`? (Colombia está en UTC−5, todo el año.)

> 🧩 **Ejemplo resuelto:** `cron: "0 12 * * *"` corre cada día a las 12:00 UTC, que en Colombia son las 07:00.

**Ahora tú, con huecos:** «`0 6 * * 1` corre el ____ a las ____ UTC, que en Colombia son las ____ del ____».

<details>
<summary>Pista</summary>

Los cinco campos son minuto, hora, día del mes, mes y día de la semana (clase 20); el 1 es el lunes. Resta 5 horas.
</details>

## Destruir al terminar

Nada que destruir: el repositorio `lab-actions` es gratis y lo usarás en las próximas clases. Los registros de las ejecuciones se borran solos (GitHub los guarda 90 días por defecto).

## Cierre

En `notas/fase-7/clase-82.md`:

1. Explica con Vigía la diferencia entre integración continua, entrega continua y despliegue continuo. *(3 líneas, una por práctica. Empieza así: «Integración continua: cada PR de Vigía pasa solo…»)*
2. ¿Qué es un runner? ¿Por qué dos jobs no comparten archivos? *(2 líneas. Empieza así: «La máquina que ejecuta un job; en GitHub, una máquina virtual nueva que… Dos jobs corren en máquinas distintas, y…»)*
3. ¿Por qué se fija una action por su commit y no por su etiqueta? *(2 líneas. Empieza así: «Porque una etiqueta es un puntero que su autor, o quien le robe la cuenta, puede mover… Un commit…»)*
4. **Repaso (clase 81, sin mirar):** si suspendes el CLF-C02, ¿cuánto tienes que esperar para repetirlo? *(1 línea.)*

Después, escríbeme `examíname clase-82`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.**
- **Integración continua:** cada PR de Vigía pasa solo `ruff`, `pytest` y la construcción de la imagen, y se ve en minutos si algo se rompió.
- **Entrega continua:** al unir a `main`, la imagen queda publicada en ECR, lista para desplegar; desplegarla sería pulsar un botón.
- **Despliegue continuo:** además, el pipeline la despliega solo en la EC2, sin nadie en medio.

**2.** La máquina que ejecuta un job. En GitHub es una máquina virtual nueva para cada job, que se destruye al terminar. Dos jobs corren en máquinas distintas, y lo que uno escribe en su disco desaparece con su máquina. Los datos se pasan con *outputs* o con artefactos.

**3.** Porque una etiqueta (`v7`) es un puntero que su autor, o quien le robe la cuenta, puede mover a otro código, y ese código corre con acceso a tu repositorio y a tus secretos (el caso de `tj-actions/changed-files`). Un commit es la huella del contenido: no se puede cambiar sin que cambie el SHA. Además, el pipeline se vuelve reproducible: hoy corre lo mismo que ayer.

**4.** 14 días, y se paga el examen otra vez.

**Reto 1:** `{40}`. Con un `uses:` cambiado a `@v7`, la orden muestra `- uses: actions/checkout@v7`, y nada más.

```bash
grep -hE '^[[:space:]]*(-[[:space:]]*)?uses:' .github/workflows/*.yml | grep -vE 'uses:[[:space:]]*\./' | grep -vE '@[0-9a-f]{40}([[:space:]]|$)'
```

**Reto 2:** `ubuntu-26.04` y `${{ matrix.os }}`; en `actionlint.yaml`, la etiqueta `ubuntu-26.04`. Sin el archivo, actionlint dice `label "ubuntu-26.04" is unknown`, con la lista de las que conoce.

**Reto 3:** el lunes a las 06:00 UTC, que en Colombia son la **01:00 de la madrugada del lunes**.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| continuous integration / delivery / deployment | integración / entrega / despliegue continuos |
| workflow / job / step / runner | flujo de trabajo / trabajo / paso / ejecutor |
| trigger / event | disparador / evento |
| to pin an action to a commit SHA | fijar una action a un commit |
| supply chain attack | ataque a la cadena de suministro |

🎙️ *"Continuous integration verifies every change automatically; continuous delivery keeps every passing change ready to release; continuous deployment releases it with no manual step. In my pipelines I pin every third-party action to a full commit SHA."*

## Siguiente

[Clase 83 — Lint y pruebas en cada PR](clase-83-lint-y-pruebas.md)
