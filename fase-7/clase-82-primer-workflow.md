# Clase 82 — CI/CD y tu primer workflow

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Integración continua

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

## Teoría

### CI, CD y CD

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

### Las piezas de GitHub Actions

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
- **Los jobs no comparten nada:** cada uno arranca en una máquina limpia. Para pasar datos de uno a otro se usan *outputs* o artefactos.
- **Primero el checkout:** el runner empieza vacío. Sin `actions/checkout`, tu código no está ahí.
- **`ubuntu-latest` se mueve,** como `latest` en Docker (clase 64): hoy es `ubuntu-24.04`, mañana será otra. Pon la versión.

### Las actions, fijadas por su commit

Una *action* es código de otra persona que se ejecuta **con acceso a tu repositorio y a tus secretos**. Si escribes `uses: actions/checkout@v7`, ejecutas lo que la etiqueta `v7` señale **hoy**, y una etiqueta se puede mover.

En marzo de 2025 alguien comprometió la action `tj-actions/changed-files`, movió sus etiquetas a un commit malicioso, y miles de repositorios imprimieron sus secretos en los logs. En 2026 le pasó a Trivy (clase 59).

La defensa es fijar el **commit**, que no se puede mover, y dejar la versión en un comentario:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Para encontrar el commit de una versión:

```bash
git ls-remote https://github.com/actions/checkout 'refs/tags/v7.0.1*'
```

Si la etiqueta es anotada, salen dos líneas: la buena es la que termina en `^{}`.

## Práctica guiada

### 1. Un repositorio de prácticas (5 min)

```bash
cd ~ && gh repo create lab-actions --public --clone --add-readme
cd lab-actions && mkdir -p .github/workflows
```

Público, para que Actions sea gratis. Lo usarás hasta la clase 86.

### 2. Tu primer workflow (15 min)

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

### 3. Revisarlo antes de subirlo (5 min)

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
echo $?
```

Sin salida y con código 0: el workflow es válido. actionlint encuentra errores de YAML, claves mal escritas, expresiones imposibles y fallos de `shellcheck` dentro de los `run:`. Pasarlo antes de cada `push` te ahorra ciclos de "sube, falla, corrige".

### 4. Verlo correr (15 min)

```bash
git add .github && git commit -m "Primer workflow" && git push
gh run list --limit 3
gh run watch
gh run view --log | head -40
```

🔮 **Predice:**
- **Sistema operativo:** Ubuntu 24.04, el del runner, no el tuyo.
- **`ls -la`:** tu repositorio, gracias al checkout.
- **El tiempo:** unos segundos de arranque de la máquina, y menos aún para tus pasos.

Abre también la ejecución en la web (pestaña **Actions** del repositorio): cada step se despliega con su log, y arriba está tu resumen.

Lánzalo a mano, gracias a `workflow_dispatch`:

```bash
gh workflow run hola.yml
sleep 5 && gh run list --limit 2
```

### 5. Dos jobs que se pasan un dato (20 min)

Añade estos dos jobs debajo de `saludo`, al mismo nivel:

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

Pásale actionlint, súbelo y mira el gráfico de la ejecución en la web.

🔮 **Predice:** ¿en qué orden corren los tres jobs? `saludo` y `fecha` a la vez, en paralelo; `usa-la-fecha` espera a `fecha` por el `needs:`.

El dato viaja así:
1. Un step escribe `clave=valor` en `$GITHUB_OUTPUT`.
2. El job lo publica en `outputs:`.
3. El job siguiente lo lee con `needs.<job>.outputs.<clave>`.

Es el mismo mecanismo que usará Vigía v4 para pasar la versión de la imagen del job que la construye al que la despliega.

### 6. Otros disparadores (10 min)

Mira, sin aplicarlos todavía, cómo se escriben los eventos más comunes:

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

`schedule` tiene sus manías:
- corre solo en la rama principal;
- se puede retrasar en horas de mucha carga;
- en los repositorios públicos se desactiva solo tras 60 días sin actividad.

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

Pásale actionlint: `could not parse as YAML`. Si lo subes sin revisar, GitHub marca la ejecución como *Invalid workflow file* y no corre nada. Bórralo.

**2. Un step que falla:**

```yaml
      - run: exit 1
      - run: echo "esto no se ve"
      - if: failure()
        run: echo "esto sí: solo corre cuando algo falló"
```

Añádelo al final de `saludo` y súbelo. El job se pone en rojo en el `exit 1`, el step siguiente se salta y el de `if: failure()` corre: así se recogen los logs cuando algo se rompe (lo usarás en la clase 83). Quita esas líneas después.

**3. Los jobs no comparten disco.** En `fecha`, añade un step `run: echo secreto > dato.txt`; en `usa-la-fecha`, `run: cat dato.txt`. `No such file or directory`: cada job arranca en una máquina nueva. Para pasar datos: *outputs*, como en el paso 5, o artefactos (`actions/upload-artifact` y `download-artifact`). Deshazlo.

## Reto

1. **Detecta las actions sin fijar.** Escribe una línea de `grep` que liste los `uses:` de tus workflows que **no** acaben en un SHA de 40 caracteres hexadecimales. Pruébala cambiando un `uses:` a `@v7`. La versión de `verify.sh` de la v4 hace exactamente esto.
2. **Una matriz.** Haz que `saludo` corra en `ubuntu-24.04` y en `ubuntu-26.04` con `strategy: matrix: os: [...]` y `runs-on: ${{ matrix.os }}`.
   - ¿Qué dice actionlint de `ubuntu-26.04`? Que no conoce la etiqueta: es más nueva que esta versión de actionlint.
   - Busca en su documentación cómo declararla en `.github/actionlint.yaml`.
3. ¿A qué hora de Colombia correría `cron: "0 6 * * 1"`? (Colombia está en UTC−5, todo el año.)

## Destruir al terminar

Nada que destruir: el repositorio `lab-actions` es gratis y lo usarás en las próximas clases. Los registros de las ejecuciones se borran solos (GitHub los guarda 90 días por defecto).

## Cierre

En `notas/fase-7/clase-82.md`:

1. Explica con Vigía la diferencia entre integración continua, entrega continua y despliegue continuo.
2. ¿Qué es un runner? ¿Por qué dos jobs no comparten archivos?
3. ¿Por qué se fija una action por su commit y no por su etiqueta?
4. **Repaso (clase 81, sin mirar):** si suspendes el CLF-C02, ¿cuánto tienes que esperar para repetirlo?

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

**Reto 1:**

```bash
grep -hE '^[[:space:]]*(-[[:space:]]*)?uses:' .github/workflows/*.yml | grep -vE 'uses:[[:space:]]*\./' | grep -vE '@[0-9a-f]{40}([[:space:]]|$)'
```

**Reto 3:** a la 01:00 de la madrugada del lunes en Colombia (06:00 UTC − 5 h).
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
