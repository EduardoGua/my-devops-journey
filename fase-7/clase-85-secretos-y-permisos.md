# Clase 85 — Secretos, variables y permisos

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Integración continua

> 💡 **La idea de hoy:** un pipeline tiene más poder que casi cualquier persona del equipo, así que se protege como una cuenta de administrador. El **`GITHUB_TOKEN`** de cada ejecución empieza en solo lectura y cada job pide lo que necesita; la configuración va en **variables** y lo delicado en **secretos**, mejor dentro de un **entorno** con reglas; y lo que escribe otra persona (el título de un PR) nunca entra directamente en un script.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los workflows, `workflow_dispatch`, actionlint y el ruleset de `main` (clases 82 y 84).
> - El mínimo privilegio y los roles de IAM (clases 69 y 70).
> - Que `${{ … }}` se sustituye antes de ejecutar (clase 82); las comillas y `$(…)` en Bash (clases 16 y 19).
> - La inyección SQL y la de órdenes con `shell=True` (clases 50 y 51): hoy, la de los workflows.

> 🔤 **Palabras nuevas de hoy:**
> - **`GITHUB_TOKEN`**: el token temporal que GitHub da a cada ejecución para usar su API sobre el repositorio.
> - **`permissions:`**: lo que puede hacer ese token, en el workflow o en cada job.
> - **secreto / variable**: un valor que se enmascara en los logs / un valor de configuración visible.
> - **entorno** (*environment*): un destino, como `production`, con sus reglas, secretos y variables.
> - **revisor obligatorio**: la persona que tiene que aprobar antes de que el job siga.
> - ***fork***: una copia de un repositorio en otra cuenta.
> - **inyección de órdenes** (*script injection*): cuando un texto ajeno acaba ejecutándose como parte de tu script.

## Objetivo

- Entender el **`GITHUB_TOKEN`** y limitarlo con `permissions:`, job a job.
- Distinguir **secretos** de **variables**, y de repositorio frente a **entorno**.
- Crear un **entorno** (`production`) con reglas: quién aprueba y desde qué rama se despliega.
- Conocer los dos ataques más comunes contra un pipeline, la **inyección de órdenes** y el uso de secretos con código ajeno, y cómo evitarlos.

## Por qué importa

Un pipeline tiene más poder que casi cualquier persona del equipo:
- escribe en el repositorio;
- publica imágenes;
- despliega en producción.

Por eso es un objetivo de ataque, y por eso se protege como se protege una cuenta de administrador: con permisos mínimos, secretos fuera del código y sin confiar en lo que llega de fuera.

En la clase 86 desaparecerán las llaves de AWS de GitHub. Antes tienes que saber qué son los secretos, cuándo **no** bastan y qué puede hacer el token que GitHub da a cada ejecución.

## Costo esperado

> 💰 **0 USD.**

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida en `lab-actions`; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 50 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto, la limpieza y el cierre.

```bash
cd ~/lab-actions && git switch main && git pull
```

## Las piezas

### Pieza 1 — El `GITHUB_TOKEN` y `permissions:`

En cada ejecución, GitHub crea un token **temporal** que caduca al terminar el job, para que el workflow pueda usar la API de GitHub sobre **su** repositorio. Está en `${{ github.token }}` (o `secrets.GITHUB_TOKEN`). Lo que puede hacer lo decide `permissions:`:

```yaml
permissions:            # para todo el workflow: lo mínimo
  contents: read

jobs:
  etiquetar:
    permissions:        # este job necesita más: solo él lo recibe
      contents: read
      issues: write
```

| Permiso | Para qué |
|---------|----------|
| `contents` | leer o escribir el código, etiquetas y *releases* |
| `pull-requests`, `issues` | comentar, etiquetar, abrir y cerrar |
| `packages` | publicar en GitHub Packages |
| `id-token: write` | pedir un token OIDC para entrar en AWS (clase 86) |

Si un job declara `permissions:`, **todo lo que no aparece queda en `none`**. Los repositorios nuevos tienen el token en **solo lectura** por defecto: déjalo así y da más permisos solo donde haga falta.

**Pruébalo:**

```bash
gh api "repos/{owner}/{repo}/actions/permissions/workflow"
```

Y en la web: **Settings → Actions → General → Workflow permissions**.

👀 **Qué deberías ver:** `{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}`, y en la web, marcado *Read repository contents and packages permissions*. Si no, márcalo y guarda.

✋ **Sin mirar:** un job declara `permissions: issues: write`. ¿Puede leer el código del repositorio?

<details>
<summary>Comprueba</summary>

No: al declarar `permissions:`, todo lo que no aparece queda en `none`. Tendría que añadir `contents: read`.
</details>

**En resumen:** el token caduca con el job, empieza en solo lectura y cada job pide lo justo con `permissions:`.

### Pieza 2 — Secretos, variables y entornos

| | Secretos (`secrets.X`) | Variables (`vars.X`) |
|---|---|---|
| Para | lo que no debe verse: contraseñas, tokens | configuración: la región, el nombre de un rol, un entorno |
| En los logs | **enmascarados** como `***` | visibles |
| Se leen después | nunca, ni desde la web: solo se sobrescriben | sí |
| Ámbito | repositorio, **entorno** u organización | igual |

Un **entorno** (*Settings → Environments*) representa un destino: `production`, `staging`… Puede tener:
- **revisores obligatorios:** el job espera a que alguien lo apruebe;
- **ramas permitidas:** por ejemplo, solo `main` puede desplegar en `production`;
- **secretos y variables propios**, que solo ven los jobs que declaran `environment: production`;
- un **historial de despliegues**, visible en la página principal del repositorio.

Con un revisor obligatorio, tu pipeline hace **entrega continua**: todo listo, alguien pulsa *Approve*. Sin revisor, **despliegue continuo** (clase 82).

**Pruébalo.**

1. **Settings → Environments → New environment** → `production`.
   - *Required reviewers*: tú.
   - *Deployment branches and tags*: *Selected branches and tags* → `main`.
2. Un secreto **de prueba**, con un valor inventado (nunca uno real en un laboratorio público), y una variable:

```bash
gh secret set SALUDO_SECRETO --env production --body "valor-de-prueba-123"
gh variable set APP_ENV --env production --body produccion
gh secret list --env production
gh variable list --env production
```

👀 **Qué deberías ver:** `SALUDO_SECRETO` con su fecha, **sin** el valor (no hay forma de leerlo después); y `APP_ENV` con su valor, `produccion`.

✋ **Sin mirar:** ¿qué jobs ven el secreto `SALUDO_SECRETO`?

<details>
<summary>Comprueba</summary>

Solo los que declaran `environment: production`, porque es un secreto del entorno, no del repositorio.
</details>

**En resumen:** secretos para lo delicado, variables para la configuración; dentro de un entorno, con revisor y rama permitida.

### Pieza 3 — Usarlos, con un permiso por job

En un `run:`, los secretos y las variables se pasan por `env:` (verás por qué en la pieza 5). Y cada job recibe solo los permisos que declara.

**Pruébalo.** Crea `.github/workflows/secretos.yml`:

```yaml
name: secretos

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  mirar:
    runs-on: ubuntu-24.04
    environment: production
    steps:
      - name: Un secreto y una variable
        env:
          SECRETO: ${{ secrets.SALUDO_SECRETO }}
          ENTORNO: ${{ vars.APP_ENV }}
        run: |
          echo "Entorno: $ENTORNO"
          echo "El secreto: $SECRETO"
          echo "Su longitud: ${#SECRETO}"

  crear-issue:
    runs-on: ubuntu-24.04
    permissions:
      issues: write
    steps:
      - env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
        run: gh issue create --title "Creada por el pipeline" --body "Ejecución $GITHUB_RUN_ID"
```

`workflow_dispatch` solo aparece cuando el archivo está en `main`, así que únelo con un PR (el ruleset de la clase 84 lo exige) y lánzalo:

```bash
git switch -c secretos && git add .github/workflows/secretos.yml && git commit -qm "Secretos y permisos"
git push -u origin secretos && gh pr create --fill && gh pr checks --watch && gh pr merge --squash --delete-branch
git switch main && git pull
gh workflow run secretos.yml
gh run watch
```

🔮 **Predice** qué hará cada job.

👀 **Qué deberías ver:** el job `mirar` se queda **esperando**: ve a la ejecución en la web, *Review deployments*, y apruébalo. Imprime `Entorno: produccion`, `El secreto: ***` y `Su longitud: 19`: la longitud sí sale, porque no es el secreto. El job `crear-issue` crea la *issue* (compruébalo con `gh issue list`): lo puede hacer porque **ese** job pidió `issues: write`. Ciérrala: `gh issue close <número>`.

✋ **Sin mirar:** ¿por qué se queda esperando el job `mirar`?

<details>
<summary>Comprueba</summary>

Porque declara `environment: production`, y ese entorno tiene un revisor obligatorio: hasta que lo apruebas, no corre.
</details>

**En resumen:** `environment:` aplica las reglas del entorno; `env:` pasa secretos y variables; cada job, sus permisos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Lo que no protege el enmascarado

Lo que no se ve tampoco es seguro del todo:
- **El enmascarado busca el texto exacto.** Si alguien imprime el secreto transformado (en base64, al revés, letra a letra), sale en el log en claro.
- **Un secreto en un workflow es un secreto en cada step:** una action de terceros que reciba el valor puede enviarlo a cualquier sitio.
- **Los PR desde un *fork*** no reciben secretos, y su `GITHUB_TOKEN` es de solo lectura. Es a propósito: el código de un desconocido no debe tocar tus secretos.

Por eso la mejor práctica con AWS no es guardar llaves como secreto, sino **no tener llaves**: OIDC (clase 86).

🔮 **Predice:** si imprimes el secreto en base64, ¿qué aparece en el log?

**Pruébalo.** En una rama, añade al step de `mirar` esta línea **solo para verlo**, únelo con un PR y lánzalo otra vez:

```yaml
          echo "$SECRETO" | base64
```

Después, quítala con otro PR, y borra también esa ejecución, que tiene el secreto en el log:

```bash
gh run list --workflow secretos.yml --limit 2
gh run delete <id>
```

👀 **Qué deberías ver:** en el log, `dmFsb3ItZGUtcHJ1ZWJhLTEyMwo=`, y cualquiera lo convierte en `valor-de-prueba-123` con `base64 -d`. El enmascarado es una ayuda contra los descuidos, no una barrera de seguridad: protegen los secretos los **permisos** (quién puede editar el workflow) y la **revisión** de los PR.

✋ **Sin mirar:** ¿por qué los PR que llegan desde un *fork* no reciben los secretos?

<details>
<summary>Comprueba</summary>

Porque ese código lo escribe otra persona: si recibiera los secretos, podría imprimirlos o enviarlos fuera.
</details>

**En resumen:** el enmascarado tapa el valor exacto, nada más; lo que protege son los permisos, la revisión y no tener llaves.

### Pieza 5 — La inyección de órdenes

`${{ … }}` se sustituye **antes** de que Bash lea el script. Si metes texto que controla otra persona (el título de un PR, el nombre de una rama, el cuerpo de un *issue*) directamente en un `run:`, esa persona escribe parte de tu script. El arreglo es pasarlo por una **variable de entorno**: Bash la trata como datos, no como código. actionlint lo detecta.

Hay un segundo ataque que debes reconocer: **`pull_request_target` con el código del PR**. Ese evento corre con los secretos y permisos del repositorio **destino**. Si además el workflow hace *checkout* del código del PR y lo ejecuta, estás ejecutando código ajeno con tus secretos. En este curso no lo usarás nunca.

🔮 **Predice** qué imprimirá cada job con el título `Hola $(whoami) desde mi PR`.

**Pruébalo.** Crea `.github/workflows/titulo.yml`:

```yaml
name: titulo

on:
  pull_request:

permissions:
  contents: read

jobs:
  peligroso:
    runs-on: ubuntu-24.04
    steps:
      - run: |
          echo "Título del PR: ${{ github.event.pull_request.title }}"

  seguro:
    runs-on: ubuntu-24.04
    steps:
      - env:
          TITULO: ${{ github.event.pull_request.title }}
        run: |
          echo "Título del PR: $TITULO"
```

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git switch -c inyeccion && git add .github/workflows/titulo.yml && git commit -qm "Prueba de inyección"
git push -u origin inyeccion
gh pr create --title 'Hola $(whoami) desde mi PR' --body "prueba"
gh pr checks --watch
gh run view --log | grep "Título del PR"
gh pr close inyeccion --delete-branch
```

👀 **Qué deberías ver:** actionlint marca `peligroso` (*"github.event.pull_request.title" is potentially untrusted*) y acepta `seguro`. En el log, `peligroso` imprime `Hola runner desde mi PR`: ejecutó el `$(whoami)` del título. Alguien con un título más malicioso podría haber hecho cualquier cosa con los permisos de ese job. `seguro` imprime el texto tal cual, `$(whoami)` incluido.

✋ **Sin mirar:** ¿cómo se usa el título de un PR en un `run:` sin riesgo de inyección?

<details>
<summary>Comprueba</summary>

Pasándolo por `env:` (por ejemplo, `TITULO: ${{ github.event.pull_request.title }}`) y usando `"$TITULO"` en el script.
</details>

**En resumen:** lo que escribe otra persona, siempre por `env:`; y nunca `pull_request_target` con el código del PR.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `permissions: contents: read` (workflow) · `permissions: issues: write` (job) | el mínimo, y más solo donde haga falta |
| `gh api "repos/{owner}/{repo}/actions/permissions/workflow"` | el permiso por defecto del token |
| `gh secret set X --env production --body "…"` · `gh secret list --env production` | secretos de un entorno |
| `gh variable set X --env production --body "…"` · `gh variable list` | variables |
| `environment: production` | aplicar las reglas del entorno a un job |
| `env: {SECRETO: ${{ secrets.X }}, ENTORNO: ${{ vars.Y }}}` | pasar secretos y variables a un `run:` |
| `GH_TOKEN: ${{ github.token }}` | usar `gh` dentro del workflow |
| `env: {TITULO: ${{ github.event.pull_request.title }}}` + `"$TITULO"` | texto ajeno sin inyección |
| `gh run delete <id>` | borrar una ejecución (y su log) |

## Rómpelo

**1. Un job sin el permiso que necesita.** En `crear-issue`, cambia `issues: write` por `contents: read`, une y lánzalo. `HTTP 403: Resource not accessible by integration`. Es el `AccessDenied` de GitHub: el token no tiene ese permiso. Devuélvelo.

**2. Un secreto que no existe.** Cambia `secrets.SALUDO_SECRETO` por `secrets.SALUDO_SECRET` (falta la O). El job **no falla**: un secreto que no existe es una cadena vacía, y la longitud sale `0`. Si tu despliegue depende de un secreto, compruébalo al principio del job: `test -n "$SECRETO" || { echo "falta el secreto"; exit 1; }`.

**3. Desplegar desde otra rama.** Lanza `secretos.yml` desde una rama que no sea `main` (`gh workflow run secretos.yml --ref <rama>`, con el archivo también en esa rama). El job `mirar` falla al instante: las reglas de `production` solo admiten `main`.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Quita el revisor obligatorio de `production` y deja solo la regla de la rama. ¿Qué tipo de CD tienes ahora?

> 🧩 **Ejemplo resuelto:** la pieza 2: "Con un revisor obligatorio, tu pipeline hace entrega continua: todo listo, alguien pulsa *Approve*".

**Ahora tú, con huecos:** **Settings → Environments → production**, quita ____ y guarda. Completa: «Ahora tengo ____, porque lo que llega a `main` y pasa todo…». Vuelve a ponerlo si prefieres aprobar a mano en tus laboratorios.

<details>
<summary>Pista</summary>

Repasa la tabla de la pieza 1 de la clase 82: la diferencia entre entrega y despliegue continuos es un paso humano.
</details>

**2.** Lee en la documentación de GitHub, en *Security hardening for GitHub Actions*, la parte sobre `pull_request_target`, y explica en qué caso concreto es peligroso.

> 🧩 **Ejemplo resuelto:** la pieza 5: `pull_request_target` corre con los secretos y permisos del repositorio destino.

**Ahora tú, con huecos:** «Es peligroso cuando el workflow, con el evento ____, hace *checkout* del código ____ y lo ____, porque ese código lo escribió otra persona y corre con ____ del repositorio destino».

<details>
<summary>Pista</summary>

Busca en `docs.github.com` *Keeping your GitHub Actions and workflows secure*; la sección se llama algo como *pwn requests*.
</details>

**3.** Busca en tu repositorio de Vigía si algún workflow o script imprime variables de entorno enteras. ¿Por qué serían un problema el día que haya secretos?

> 🧩 **Ejemplo resuelto:** `grep -rn printenv ~/vigia` lista las líneas que usan `printenv` en cualquier archivo de Vigía.

**Ahora tú, con huecos:**
```bash
grep -rnE '(^|[[:space:]])(env|printenv)([[:space:]]|$)|set -x' ~/vigia \
  --include='*.sh' --include='*.____' --include='*.yaml'
```
Completa: «Encontré ____. Serían un problema porque imprimirían en el log…».

<details>
<summary>Pista</summary>

Los workflows son `.yml`. `set -x` imprime cada orden con las variables ya sustituidas, secretos incluidos (clase 19).
</details>

## Destruir al terminar

```bash
gh secret delete SALUDO_SECRETO --env production
gh variable delete APP_ENV --env production
```

El entorno `production` puede quedarse: lo usarás en la clase 88 con su revisor o sin él. `titulo.yml` y `secretos.yml` puedes borrarlos de `main` con un PR.

## Cierre

En `notas/fase-7/clase-85.md`:

1. ¿Qué es el `GITHUB_TOKEN`, cuánto dura y quién decide lo que puede hacer? *(2 líneas. Empieza así: «Un token temporal que GitHub crea para cada ejecución, para… Caduca al terminar el job, y lo que puede hacer lo decide…»)*
2. ¿Por qué el enmascarado de los secretos no es una barrera de seguridad? *(2 líneas. Empieza así: «Porque solo tapa el valor exacto: cualquier transformación… Lo que protege de verdad es…»)*
3. Explica la inyección de órdenes en un workflow y cómo se evita. *(2 líneas. Empieza así: «`${{ … }}` se sustituye antes de que Bash lea el script, así que si contiene algo que controla otra persona… Se evita pasando el valor por…»)*
4. **Repaso (clase 84, sin mirar):** ¿qué impiden las reglas *Require status checks to pass* y *Block force pushes*? *(2 líneas, una por regla.)*

Después, escríbeme `examíname clase-85`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un token temporal que GitHub crea para cada ejecución, para que el workflow use la API sobre su propio repositorio. Caduca al terminar el job. Lo que puede hacer lo decide `permissions:` (en el workflow o en cada job), dentro del máximo que permita la configuración del repositorio, que por defecto es de solo lectura.

**2.** Porque solo tapa el valor **exacto**. Cualquier transformación (base64, otro orden, partes sueltas) lo deja ver, y una action de terceros que reciba el secreto puede enviarlo fuera sin imprimir nada. Lo que protege de verdad es controlar quién puede cambiar los workflows, revisar los PR, dar el mínimo de permisos y no tener secretos de larga duración (OIDC).

**3.** `${{ … }}` se sustituye en el texto del script antes de que Bash lo lea. Si contiene algo que controla otra persona (el título de un PR, el nombre de una rama), esa persona escribe parte de tu script, y sus `$(…)` o `;` se ejecutan con los permisos del job. Se evita pasando el valor por `env:` y usando `"$VARIABLE"` en el script, que Bash trata como datos. actionlint lo detecta.

**4.** *Require status checks* impide unir un PR hasta que las comprobaciones elegidas (`lint`, `test`, `imagen`) estén en verde. *Block force pushes* impide reescribir el historial de `main` con `push --force`.

**Reto 1:** el revisor (*Required reviewers*). Ahora tienes **despliegue continuo**: lo que llega a `main` y pasa todo se despliega sin que nadie apruebe. Con el revisor, era entrega continua.

**Reto 2:** con `pull_request_target`, el workflow hace *checkout* del código **del PR** (de un *fork*) y lo **ejecuta** (instala dependencias, corre sus scripts o sus pruebas). Ese código lo escribió otra persona y corre con los **secretos y permisos de escritura** del repositorio destino.

**Reto 3:** `--include='*.yml'`. Lo normal en Vigía es no encontrar nada; si aparece un `env`, un `printenv` o un `set -x` en un script que corre en el pipeline, el día que el job tenga secretos los imprimiría en el log (`printenv` y `env` los enseñan todos; `set -x`, los que aparezcan en las órdenes).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| secret / variable | secreto / variable (de configuración) |
| least-privilege token permissions | permisos mínimos del token |
| environment protection rules | reglas de protección del entorno |
| required reviewers | revisores obligatorios |
| script injection | inyección de órdenes |
| untrusted input | entrada no confiable |

🎙️ *"Every workflow starts with read-only permissions and each job asks only for what it needs. Configuration goes in variables, secrets in environment-scoped secrets, and untrusted input like a pull request title always goes through an environment variable, never straight into a script."*

## Siguiente

[Clase 86 — OIDC: AWS sin llaves](clase-86-oidc.md)
