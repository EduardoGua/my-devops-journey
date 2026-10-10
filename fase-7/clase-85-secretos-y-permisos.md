# Clase 85 — Secretos, variables y permisos

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Integración continua

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

## Teoría

### El `GITHUB_TOKEN`

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

Permisos habituales:

| Permiso | Para qué |
|---------|----------|
| `contents` | leer o escribir el código, etiquetas y *releases* |
| `pull-requests`, `issues` | comentar, etiquetar, abrir y cerrar |
| `packages` | publicar en GitHub Packages |
| `id-token: write` | pedir un token OIDC para entrar en AWS (clase 86) |

Si un job declara `permissions:`, **todo lo que no aparece queda en `none`**.

Los repositorios nuevos tienen el token en **solo lectura** por defecto: *Settings → Actions → General → Workflow permissions*. Déjalo así y da más permisos solo donde haga falta.

### Secretos y variables

| | Secretos (`secrets.X`) | Variables (`vars.X`) |
|---|---|---|
| Para | lo que no debe verse: contraseñas, tokens | configuración: la región, el nombre de un rol, un entorno |
| En los logs | **enmascarados** como `***` | visibles |
| Se leen después | nunca, ni desde la web: solo se sobrescriben | sí |
| Ámbito | repositorio, **entorno** u organización | igual |

Lo que no se ve tampoco es seguro del todo:
- **El enmascarado busca el texto exacto.** Si alguien imprime el secreto transformado (en base64, al revés, letra a letra), sale en el log en claro.
- **Un secreto en un workflow es un secreto en cada step:** una action de terceros que reciba el valor puede enviarlo a cualquier sitio.
- **Los PR desde un *fork*** (una copia del repositorio en otra cuenta) **no reciben secretos**, y su `GITHUB_TOKEN` es de solo lectura. Es a propósito: el código de un desconocido no debe tocar tus secretos.

Por eso la mejor práctica con AWS no es guardar llaves como secreto, sino **no tener llaves**: OIDC (clase 86).

### Entornos

Un **entorno** (*Settings → Environments*) representa un destino: `production`, `staging`… Puede tener:
- **revisores obligatorios:** el job espera a que alguien lo apruebe;
- **ramas permitidas:** por ejemplo, solo `main` puede desplegar en `production`;
- **secretos y variables propios**, que solo ven los jobs que declaran `environment: production`;
- un **historial de despliegues**, visible en la página principal del repositorio.

Con un revisor obligatorio, tu pipeline hace **entrega continua**: todo listo, alguien pulsa *Approve*. Sin revisor, **despliegue continuo**.

### Dos ataques que debes reconocer

1. **Inyección de órdenes.** `${{ … }}` se sustituye **antes** de que Bash lea el script. Si metes texto que controla otra persona (el título de un PR, el nombre de una rama, el cuerpo de un *issue*) directamente en un `run:`, esa persona escribe parte de tu script.

   El arreglo es pasarlo por una **variable de entorno**: Bash la trata como datos, no como código. actionlint lo detecta (paso 4).
2. **`pull_request_target` con el código del PR.** Ese evento corre con los secretos y permisos del repositorio **destino**. Si además el workflow hace *checkout* del código del PR y lo ejecuta, estás ejecutando código ajeno con tus secretos. En este curso no lo usarás nunca.

## Práctica guiada

En `lab-actions`, en una rama `secretos`.

### 1. Mira el punto de partida (5 min)

En la web: **Settings → Actions → General → Workflow permissions**. Debe estar marcado *Read repository contents and packages permissions*. Si no, márcalo y guarda.

### 2. Un entorno, un secreto y una variable (15 min)

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

### 3. Usarlos, y los permisos del token (20 min)

Crea `.github/workflows/secretos.yml`:

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
gh workflow run secretos.yml
gh run watch
```

🔮 **Predice:**
- **El job `mirar`:** se queda **esperando**. Ve a la ejecución en la web, *Review deployments*, y apruébalo. Imprime el entorno y `El secreto: ***`; la longitud sí sale (19), porque no es el secreto.
- **El job `crear-issue`:** crea la *issue* (compruébalo con `gh issue list`). Lo puede hacer porque **ese** job pidió `issues: write`.

Ciérrala: `gh issue close <número>`.

### 4. Lo que no protege el enmascarado (10 min)

En una rama, añade al job `mirar` esta línea **solo para verlo**, y lánzalo otra vez:

```yaml
          echo "$SECRETO" | base64
```

El log muestra `dmFsb3ItZGUtcHJ1ZWJhLTEyMwo=`, y cualquiera lo convierte en `valor-de-prueba-123`. El enmascarado es una ayuda contra los descuidos, no una barrera de seguridad: protegen los secretos los **permisos** (quién puede editar el workflow) y la **revisión** de los PR.

Borra la línea, y borra también esa ejecución, que tiene el secreto en el log:

```bash
gh run list --workflow secretos.yml --limit 2
gh run delete <id>
```

### 5. La inyección, en vivo (15 min)

Crea `.github/workflows/titulo.yml`:

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

Pásale actionlint: marca `peligroso` (*"github.event.pull_request.title" is potentially untrusted*) y acepta `seguro`. Ahora compruébalo. Abre un PR **con este título**:

```bash
git switch -c inyeccion && git add .github/workflows/titulo.yml && git commit -qm "Prueba de inyección"
git push -u origin inyeccion
gh pr create --title 'Hola $(whoami) desde mi PR' --body "prueba"
gh pr checks --watch
gh run view --log | grep "Título del PR"
```

🔮 **Predice:**
- **`peligroso`:** imprime `Hola runner desde mi PR`. Ejecutó el `$(whoami)` del título. Alguien con un título más malicioso podría haber hecho cualquier cosa con los permisos de ese job.
- **`seguro`:** imprime el texto tal cual, `$(whoami)` incluido.

Cierra el PR sin unir y borra la rama.

## Rómpelo

**1. Un job sin el permiso que necesita.** En `crear-issue`, cambia `issues: write` por `contents: read`, une y lánzalo. `HTTP 403: Resource not accessible by integration`. Es el `AccessDenied` de GitHub: el token no tiene ese permiso. Devuélvelo.

**2. Un secreto que no existe.** Cambia `secrets.SALUDO_SECRETO` por `secrets.SALUDO_SECRET` (falta la O). El job **no falla**: un secreto que no existe es una cadena vacía, y la longitud sale `0`. Si tu despliegue depende de un secreto, compruébalo al principio del job: `test -n "$SECRETO" || { echo "falta el secreto"; exit 1; }`.

**3. Desplegar desde otra rama.** Lanza `secretos.yml` desde una rama que no sea `main` (`gh workflow run secretos.yml --ref <rama>`, con el archivo también en esa rama). El job `mirar` falla al instante: las reglas de `production` solo admiten `main`.

## Reto

1. Quita el revisor obligatorio de `production` y deja solo la regla de la rama. ¿Qué tipo de CD tienes ahora? Vuelve a ponerlo si prefieres aprobar a mano en tus laboratorios.
2. Lee en la documentación de GitHub *Security hardening for GitHub Actions* la sección sobre `pull_request_target` y escribe en tus notas, con tus palabras, en qué caso concreto es peligroso.
3. Busca en tu repositorio de Vigía si algún workflow o script imprime variables de entorno enteras (`env`, `printenv`, `set -x` cerca de un secreto). ¿Por qué serían un problema el día que haya secretos?

## Destruir al terminar

```bash
gh secret delete SALUDO_SECRETO --env production
gh variable delete APP_ENV --env production
```

El entorno `production` puede quedarse: lo usarás en la clase 88 con su revisor o sin él. `titulo.yml` y `secretos.yml` puedes borrarlos de `main` con un PR.

## Cierre

En `notas/fase-7/clase-85.md`:

1. ¿Qué es el `GITHUB_TOKEN`, cuánto dura y quién decide lo que puede hacer?
2. ¿Por qué el enmascarado de los secretos no es una barrera de seguridad?
3. Explica la inyección de órdenes en un workflow y cómo se evita.
4. **Repaso (clase 84, sin mirar):** ¿qué impiden las reglas *Require status checks to pass* y *Block force pushes*?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un token temporal que GitHub crea para cada ejecución, para que el workflow use la API sobre su propio repositorio. Caduca al terminar el job. Lo que puede hacer lo decide `permissions:` (en el workflow o en cada job), dentro del máximo que permita la configuración del repositorio, que por defecto es de solo lectura.

**2.** Porque solo tapa el valor **exacto**. Cualquier transformación (base64, otro orden, partes sueltas) lo deja ver, y una action de terceros que reciba el secreto puede enviarlo fuera sin imprimir nada. Lo que protege de verdad es controlar quién puede cambiar los workflows, revisar los PR, dar el mínimo de permisos y no tener secretos de larga duración (OIDC).

**3.** `${{ … }}` se sustituye en el texto del script antes de que Bash lo lea. Si contiene algo que controla otra persona (el título de un PR, el nombre de una rama), esa persona escribe parte de tu script, y sus `$(…)` o `;` se ejecutan con los permisos del job. Se evita pasando el valor por `env:` y usando `"$VARIABLE"` en el script, que Bash trata como datos. actionlint lo detecta.

**4.** *Require status checks* impide unir un PR hasta que las comprobaciones elegidas (`lint`, `test`, `imagen`) estén en verde. *Block force pushes* impide reescribir el historial de `main` con `push --force`.

**Reto 1:** despliegue continuo: lo que llega a `main` y pasa todo se despliega sin que nadie apruebe. Con el revisor, era entrega continua.
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
