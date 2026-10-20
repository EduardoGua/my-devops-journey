# Clase 100 — Terraform en CI

**Dónde:** GitHub + tu Ubuntu (AWS) · **Tiempo:** 90 min · **Bloque:** B. Vigía en código

> 💡 **La idea de hoy:** cada PR que toca la infraestructura pasa por `fmt -check`, `validate` y `plan` en GitHub Actions, con un rol de **solo lectura** por OIDC, y el plan queda a la vista de quien revisa. El pipeline **planifica**; el `apply` lo sigues haciendo tú. Y nada privado, como tu IP, aparece en los logs públicos.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Workflows, rulesets y filtros por ruta (clases 83 y 84); secretos, variables, entornos y permisos del `GITHUB_TOKEN` (clase 85).
> - OIDC, la política de confianza con `repository_id` y `ref`, y por qué un *fork* no recibe tokens (clase 86).
> - `set -e`, `set +e` y `case` (clases 17 y 19); actionlint (clase 83).
> - `TF_VAR_`, `sensitive` y la validación de `mi_ip` (clases 94, 97 y 99); el bloqueo del estado (clase 96).

> 🔤 **Palabras nuevas de hoy:**
> - **`-detailed-exitcode`**: el `plan` devuelve 0 (sin cambios), 1 (error) o 2 (hay cambios).
> - **`ReadOnlyAccess`**: la política administrada de AWS que permite leer casi todo y no cambiar nada.
> - **`StringLike`**: una condición de IAM que acepta comodines (`*`).
> - **`TF_IN_AUTOMATION`**: le dice a Terraform que no hay nadie delante, para que no sugiera comandos interactivos.
> - **`$GITHUB_STEP_SUMMARY`**: el archivo cuyo contenido aparece en el resumen de la ejecución.

## Objetivo

- Que cada PR que toca la infraestructura de Vigía pase por el pipeline:
  - `terraform fmt -check`;
  - `validate`;
  - un `plan`, visible en la página de la ejecución.
- Darle al pipeline un rol de **solo lectura** con OIDC, capaz de planificar, incluidos los PR, sin poder cambiar nada.
- Pasar las variables de Terraform desde GitHub sin exponer nada en logs **públicos**.
- Entender `-detailed-exitcode`, por qué el `apply` sigue siendo una decisión humana y cómo se automatizaría.

## Por qué importa

Un cambio de infraestructura revisado solo como código es medio revisado: el `plan` es lo que dice **qué va a pasar**. En los equipos, cada PR de Terraform lleva su plan adjunto. Quien revisa busca los `-/+` y los `destroy` antes de aprobar, igual que tú en la clase 97.

Es el último punto del temario de la Ruta para esta fase: *fmt, validate y plan en cada PR*.

## Costo esperado

> 💰 **0 USD.** GitHub Actions, gratis en el repositorio público. IAM y la lectura del estado, gratis.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la aplicas enseguida a Vigía; no pases a la siguiente sin haber terminado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre. Entre los dos días no queda nada que cobre.

```bash
cd ~/vigia && git switch main && git pull && git switch -c terraform-ci
```

## Las piezas

### Pieza 1 — El flujo: el pipeline planifica, tú aplicas

```
PR que cambia infra/  ──►  fmt -check ─► init (backend S3) ─► validate ─► plan
                                              │ OIDC: vigia-terraform-plan (solo lectura)
                                              ▼
                          el plan, en el resumen de la ejecución  ──►  revisión  ──►  merge
                                                                                        │
                          tú, en tu Ubuntu: terraform plan + apply  ◄───────────────────┘
```

El pipeline **planifica**; el `apply` lo sigues haciendo tú, en tu máquina, después de unir. Un `apply` automático en `main` es posible (reto 1), pero entonces el pipeline necesitaría permisos para cambiar **toda** tu infraestructura. Para empezar, que tenga permisos de lectura y la decisión siga siendo humana.

**Pruébalo, en papel.** Un compañero abre un PR que cambia el `cidr_block` de la subred pública de Vigía. ¿Qué buscarías en el plan del pipeline antes de aprobar, y quién aplica después?

<details>
<summary>Comprueba</summary>

Un `-/+` en la subred (cambiar su rango obliga a reemplazarla) y, con ella, el reemplazo de la instancia que vive dentro: Vigía se quedaría sin servicio un rato y cambiaría de IP. Si se aprueba, después de unir aplicas **tú**, en tu Ubuntu, tras volver a planificar.
</details>

✋ **Sin mirar:** ¿por qué el pipeline no aplica?

<details>
<summary>Comprueba</summary>

Porque para aplicar necesitaría permisos para cambiar toda la infraestructura. Con un rol de solo lectura, lo peor que puede hacer un workflow es leer.
</details>

**En resumen:** el plan en el PR, para quien revisa; el `apply`, una decisión humana.

### Pieza 2 — Un rol de solo lectura que acepta los PR

El rol `vigia-github` de la fase 7 solo confía en `refs/heads/main`. Para planificar en los PR, otro rol, `vigia-terraform-plan`:
- **confianza:** tu `repository_id`, tu `repository_owner_id` y `aud`, como siempre. Y el `ref` puede ser `main` **o un PR**, con `StringLike` y un comodín:

  ```hcl
  StringLike = {
    "token.actions.githubusercontent.com:ref" = ["refs/heads/main", "refs/pull/*/merge"]
  }
  ```

  Los PR que vienen de un *fork* no pueden pedir tokens OIDC (clase 86), así que solo entran los PR de tu propio repositorio.
- **permisos:** la política administrada `ReadOnlyAccess`, para leer todo lo que el `plan` refresca. Más **lo justo para el bloqueo** del estado: `s3:PutObject` y `s3:DeleteObject` solo sobre `vigia/terraform.tfstate.tflock`, porque el `plan` también bloquea (clase 96).

  `ReadOnlyAccess` es amplia: lee cualquier cosa de tu cuenta, incluido el estado y sus secretos. Es un compromiso habitual para un rol de `plan`, aceptable en tu cuenta personal y con un repositorio tuyo. En una empresa se acota más.

**Pruébalo.** En `infra/github.tf`, añade el rol `vigia-terraform-plan`, con estos tres recursos:
- un `aws_iam_role` con la política de confianza de arriba, escrita con `jsonencode` como la del rol del pipeline;
- un `aws_iam_role_policy_attachment` con `arn:aws:iam::aws:policy/ReadOnlyAccess`;
- un `aws_iam_role_policy` con `s3:PutObject` y `s3:DeleteObject` sobre `arn:aws:s3:::vigia-tfstate-${local.cuenta}/vigia/terraform.tfstate.tflock`.

Y un output, `rol_terraform_plan`, con su ARN. En `infra/variables.tf`, marca `mi_ip` como `sensitive = true` (lo entenderás en la pieza 3).

```bash
cd ~/vigia/infra && terraform fmt && terraform validate && terraform plan
```

🔮 **Predice:** ¿cuántos recursos añade el plan?

👀 **Qué deberías ver:** `Plan: 3 to add`: el rol, el *attachment* y la política *inline*. Y `mi_ip` sale ahora como `(sensitive value)` en la regla del SG. Aplica:

```bash
terraform apply
terraform output -raw rol_terraform_plan
```

El output es el ARN: `arn:aws:iam::<tu cuenta>:role/vigia-terraform-plan`.

✋ **Sin mirar:** si el `plan` solo lee, ¿por qué el rol necesita `s3:PutObject` y `s3:DeleteObject`?

<details>
<summary>Comprueba</summary>

Por el bloqueo: el `plan` también crea el `.tflock` al empezar y lo borra al terminar. Solo sobre ese objeto; el estado en sí, lo lee.
</details>

**En resumen:** un rol aparte para el plan: confía en `main` y en los PR, lee todo y solo escribe el `.tflock`.

### Pieza 3 — Las variables, sin enseñar nada

El plan de un repositorio público lo puede leer **cualquiera**. Cada variable de Terraform llega como `TF_VAR_<nombre>` (clase 94):

| Variable | De dónde, en el pipeline |
|----------|--------------------------|
| `mi_ip` | un **secreto** (`secrets.MI_IP`), y en `variables.tf`, `sensitive = true`: en el plan sale como `(sensitive value)` |
| `github_user` | `github.repository_owner`, del contexto |
| `github_repository_id` y `github_owner_id` | `github.repository_id` y `github.repository_owner_id`, del contexto: los mismos ID que viste en la clase 86 |
| `etiqueta_imagen` | una **variable** de GitHub, `TF_ETIQUETA_IMAGEN`, con el **mismo** valor que tu `terraform.tfvars`. Si no coincidieran, el plan propondría recrear la instancia |

**Pruébalo:**

```bash
cd ~/vigia
gh variable set AWS_TERRAFORM_PLAN_ROLE_ARN --body "$(terraform -chdir=infra output -raw rol_terraform_plan)"
gh variable set TF_ETIQUETA_IMAGEN --body "$(grep etiqueta_imagen infra/terraform.tfvars | cut -d'"' -f2)"
gh secret set MI_IP --body "$(grep mi_ip infra/terraform.tfvars | cut -d'"' -f2)"
gh variable list && gh secret list
```

`AWS_REGION` ya existe desde la fase 7. Tu IP, como **secreto**: GitHub la enmascara en los logs.

👀 **Qué deberías ver:** en `gh variable list`, `AWS_REGION`, `AWS_TERRAFORM_PLAN_ROLE_ARN` y `TF_ETIQUETA_IMAGEN` con sus valores; en `gh secret list`, `MI_IP` con su fecha, pero **sin** valor: un secreto no se puede volver a leer.

✋ **Sin mirar:** ¿por qué tu IP va como secreto **y** con `sensitive = true`?

<details>
<summary>Comprueba</summary>

Como secreto, GitHub la enmascara en los logs; con `sensitive`, Terraform no la escribe en el plan. Hace falta lo uno y lo otro: el plan se guarda en el resumen, que no siempre pasa por el enmascarado.
</details>

**En resumen:** lo privado, como secreto y `sensitive`; lo público, del contexto de GitHub o de una variable.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — El workflow y `-detailed-exitcode`

| Código | Significado |
|--------|-------------|
| 0 | sin cambios |
| 1 | error |
| 2 | **hay cambios** |

Con él, un script sabe si la infraestructura coincide con el código. Es la base de la detección de *drift* programada (reto 3 de la clase 99). En el workflow, el 2 no es un fallo: es lo esperado en un PR que cambia algo.

**Pruébalo.** `.github/workflows/terraform.yml`:

```yaml
# El plan de Terraform en cada PR que toca la infraestructura (y en main, para ver el drift).
name: terraform

on:
  pull_request:
    paths: ["infra/**", "deploy/cloud-init.yaml"]
  push:
    branches: [main]
    paths: ["infra/**", "deploy/cloud-init.yaml"]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: true

jobs:
  plan:
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      id-token: write
    env:
      TF_IN_AUTOMATION: "1"
      TF_VAR_mi_ip: ${{ secrets.MI_IP }}
      TF_VAR_github_user: ${{ github.repository_owner }}
      TF_VAR_etiqueta_imagen: ${{ vars.TF_ETIQUETA_IMAGEN }}
      TF_VAR_github_repository_id: ${{ github.repository_id }}
      TF_VAR_github_owner_id: ${{ github.repository_owner_id }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1
        with:
          terraform_version: 1.16.5
          terraform_wrapper: false
      - name: Formato
        run: terraform fmt -check -recursive -diff infra
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_TERRAFORM_PLAN_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - name: init
        run: |
          CUENTA=$(aws sts get-caller-identity --query Account --output text)
          terraform -chdir=infra init -input=false -backend-config="bucket=vigia-tfstate-$CUENTA"
      - name: validate
        run: terraform -chdir=infra validate
      - name: plan
        run: |
          set +e
          terraform -chdir=infra plan -input=false -no-color -lock-timeout=2m -detailed-exitcode -out=plan.tfplan > plan.txt
          CODIGO=$?
          set -e
          cat plan.txt
          {
            echo "### terraform plan"
            echo '```'
            grep -E '^\s*# |^Plan:|^No changes' plan.txt | head -60
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
          case $CODIGO in
            0) echo "Sin cambios: la infraestructura coincide con el código." ;;
            2) echo "::notice::El plan tiene cambios: revísalos antes de aplicar." ;;
            *) exit "$CODIGO" ;;
          esac
```

- **`hashicorp/setup-terraform`** instala la versión **exacta** (la misma que tu Ubuntu). `terraform_wrapper: false` deja que los códigos de salida lleguen tal cual a tu script.
- **`fmt -check`** va antes de entrar en AWS: si el formato falla, no merece la pena gastar un `init`.
- **El step `plan`:**
  - desactiva `set -e` (clase 19), porque `-detailed-exitcode` devuelve 2 cuando hay cambios y eso no es un error;
  - copia al resumen las líneas que importan (los recursos y la línea `Plan:`);
  - decide con un `case` qué es un fallo de verdad.
- **`-lock-timeout=2m`:** si estás aplicando en tu Ubuntu, el pipeline espera al bloqueo en lugar de fallar al instante.

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
```

👀 **Qué deberías ver:** actionlint no imprime nada y termina con código 0: el workflow está bien escrito.

✋ **Sin mirar:** ¿qué pasaría en el step `plan` si no desactivaras `set -e`?

<details>
<summary>Comprueba</summary>

Que un plan **con cambios** (código 2) pararía el step como si fuera un error: el job saldría en rojo en todos los PR que cambian algo, y el resumen no se escribiría.
</details>

**En resumen:** `fmt -check`, `init`, `validate` y `plan` con `-detailed-exitcode`; el 2 es un aviso, no un fallo.

### Pieza 5 — Un PR con cambios

El workflow solo corre si el PR toca `infra/**` o `deploy/cloud-init.yaml`. Por eso **no** lo hagas obligatorio en el ruleset (clase 84): en los PR que no tocan esos archivos, la comprobación no aparecería nunca y GitHub esperaría por ella para siempre.

**Pruébalo.** Haz commit del rol, de `sensitive` y del workflow. En la misma rama, cambia también la retención de `/vigia/checker` a 14 días, sube el PR y espera:

```bash
gh pr create --fill && gh pr checks --watch
gh run view --log | grep -E "retention_in_days|Plan:"
```

🔮 **Predice:** ¿qué muestra el resumen de la ejecución, y de qué color sale el job?

👀 **Qué deberías ver:** `# aws_cloudwatch_log_group.vigia["checker"] will be updated in-place` y `Plan: 0 to add, 1 to change, 0 to destroy.` El job está en verde, con un aviso: el 2 de `-detailed-exitcode` es lo esperado.

Lee el plan **en GitHub**, como lo haría quien revisa. Une el PR y aplica tú:

```bash
git switch main && git pull && cd infra && terraform apply
```

El `push` a `main` lanza el workflow otra vez. Si lo lanzas a mano después de tu `apply` (`gh workflow run terraform.yml`), dirá `Sin cambios`: código y realidad coinciden.

✋ **Sin mirar:** ¿por qué este workflow no se hace obligatorio en el ruleset?

<details>
<summary>Comprueba</summary>

Porque, por el filtro de rutas, no corre en los PR que no tocan la infraestructura. La comprobación obligatoria no aparecería nunca, y esos PR no se podrían unir.
</details>

**En resumen:** el plan en el resumen del PR, la revisión en GitHub y el `apply` en tu Ubuntu después de unir.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `StringLike = { "…:ref" = ["refs/heads/main", "refs/pull/*/merge"] }` | un rol que acepta `main` y los PR |
| `arn:aws:iam::aws:policy/ReadOnlyAccess` | leerlo todo, no cambiar nada |
| `TF_VAR_mi_ip: ${{ secrets.MI_IP }}` | una variable de Terraform desde un secreto |
| `terraform fmt -check -recursive -diff infra` | fallar si el formato no es el correcto |
| `terraform plan -input=false -detailed-exitcode -lock-timeout=2m` | un plan para CI |
| `set +e` … `CODIGO=$?` … `set -e` | capturar un código de salida sin que pare el script |
| `>> "$GITHUB_STEP_SUMMARY"` | escribir en el resumen de la ejecución |
| `gh workflow run terraform.yml` | lanzar el workflow a mano |

## Rómpelo

1. **El formato.** Desalinea un `=` en `main.tf` y sube el PR: el step `Formato` falla con el `diff` que habría que aplicar. `terraform fmt` en tu máquina y otro commit.
2. **Una variable que falta.** Borra un momento el secreto (`gh secret delete MI_IP`) y relanza: `TF_VAR_mi_ip` llega vacía y tu **validación** de la clase 97 la para, con tu mensaje. Una buena validación también es documentación para el pipeline. Vuelve a crear el secreto.
3. **Un rol que no acepta PR.** En la política de confianza del rol del plan, quita `"refs/pull/*/merge"`, aplica y relanza el PR. `configure-aws-credentials` no puede asumir el rol: es la clase 86 otra vez. Devuélvelo y aplica.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Apply con aprobación.** Diseña (sin implementarlo) un job `apply` que corra en `push` a `main`, en el entorno `production` con revisor obligatorio (clase 85), y que aplique el `plan.tfplan` guardado como artefacto. ¿Qué rol necesitaría y con qué permisos? ¿Por qué el plan debería ser el del mismo commit?

> 🧩 **Ejemplo resuelto:** el reto 1 de la clase 86: un job con `environment: production`, y un rol que solo confía en ese entorno.

**Ahora tú, con huecos:** «Un rol `vigia-terraform-apply` que solo confía en `environment:____`, con permisos para ____. El plan debe ser el del mismo commit porque ____, y Terraform rechaza un plan guardado si ____ (clase 97)».

<details>
<summary>Pista</summary>

Piensa en todo lo que crea tu `infra/`: red, instancias, IAM, S3, ECR, logs. Y en el Rómpelo 3 de la clase 97: qué pasa con un plan guardado cuando el estado cambia.
</details>

**2.** **Drift cada noche.** Añade `schedule: - cron: "0 7 * * *"` y un step que, si el código de salida es 2 en `main`, abra una *issue* con `gh issue create`. ¿Qué permiso necesita el job?

> 🧩 **Ejemplo resuelto:** en la clase 85, la tabla de permisos del `GITHUB_TOKEN`: `contents`, `id-token`, `pull-requests`, `issues`…

**Ahora tú, con huecos:**
```yaml
    permissions:
      contents: read
      id-token: write
      ____: write
```
Y en el `case`, en la rama del 2: `gh issue create --title "Drift en Vigía" --body-file ____`, con `GH_TOKEN: ${{ github.token }}` en el `env` del step.

<details>
<summary>Pista</summary>

El `cron` de GitHub va en UTC. Para que solo abra la issue en la ejecución nocturna, mira `github.event_name == 'schedule'`.
</details>

**3.** **El plan en el PR.** Busca cómo publicar el resumen del plan como un **comentario** del PR con `gh pr comment`. ¿Qué permiso del `GITHUB_TOKEN` hace falta (clase 85)?

> 🧩 **Ejemplo resuelto:** el reto 2: `issues: write` para abrir una issue.

**Ahora tú, con huecos:** `gh pr comment ${{ github.event.pull_request.number }} --body-file ____`, con el permiso `____: write` y `GH_TOKEN` en el `env`.

<details>
<summary>Pista</summary>

Escribe el resumen en un archivo (`resumen.md`) además de en `$GITHUB_STEP_SUMMARY`. Y el step solo tiene sentido en los PR: `if: github.event_name == 'pull_request'`.
</details>

## Destruir al terminar

Nada que destruir. Si cambiaste la retención para el PR, déjala en 7 días o en 14, pero que el código y la realidad coincidan (`terraform plan` → `No changes`).

## Cierre

En `notas/fase-8/clase-100.md`:

1. ¿Qué hace el workflow de Terraform y qué no hace? ¿Por qué el `apply` sigue siendo tuyo? *(2–3 líneas. Empieza así: «Comprueba el formato, inicializa, valida y planifica… No aplica nada, porque…»)*
2. ¿Por qué el rol del plan acepta `refs/pull/*/merge` y el del despliegue no? *(2 líneas. Empieza así: «Porque el rol del plan solo lee…»)*
3. ¿Cómo evitas que el plan, en un repositorio público, enseñe tu IP? *(1–2 líneas. Empieza así: «Marcando `mi_ip` como… y pasándola como…»)*
4. **Repaso (clase 99, sin mirar):** ¿qué opciones tienes cuando el plan muestra un *drift*? *(3 líneas, una por opción.)*

Después, escríbeme `examíname clase-100`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Comprueba el formato, inicializa el backend, valida y planifica cada cambio de infraestructura, y deja el plan a la vista de quien revisa el PR. No aplica nada: su rol solo lee. El `apply` sigue siendo tuyo porque cambiar la infraestructura es más arriesgado que desplegar una imagen. Automatizarlo exigiría darle al pipeline permisos para cambiarlo todo, y una aprobación humana para cada cambio (reto 1).

**2.** Porque el rol del plan **solo lee**: si un PR lo usa, como mucho ve tu infraestructura, y necesita hacerlo para planificar el cambio que propone. El rol del despliegue **cambia** cosas (publica imágenes, ordena despliegues) y solo debe usarse con código ya revisado y unido a `main`.

**3.** Marcando la variable `mi_ip` como `sensitive = true` en Terraform, para que el plan la muestre como `(sensitive value)`, y pasándola como **secreto** de GitHub (`secrets.MI_IP`), que además se enmascara en los logs.

**4.**
- **Revertir:** aplicar, para que la realidad vuelva a lo que dice el código.
- **Aceptar:** cambiar el código para que diga lo mismo que la realidad, con un PR, y aplicar.
- **Ignorar ese atributo** con `ignore_changes`, si de verdad lo gestiona otro.

Con `plan -refresh-only` se ve el cambio sin decidir nada.

**Reto 1:** un rol `vigia-terraform-apply` que solo confía en `environment:production` (el `sub` termina en `:environment:production`), con permisos para crear, cambiar y borrar todo lo que gestiona `infra/`: EC2 y la red, IAM (roles y políticas), S3, ECR, CloudWatch Logs y el estado. Es casi administrador, y por eso el revisor obligatorio es imprescindible. El plan debe ser el del mismo commit porque es **el que revisó** quien aprobó: aplicar otro sería aplicar algo que nadie ha visto. Y Terraform rechaza un plan guardado si el estado cambió desde que se generó.

**Reto 2:** `issues: write`, además de lo que ya tiene el job, y `--body-file plan.txt` (o un resumen). Con `if: github.event_name == 'schedule'` en el step, solo abre la issue en la ejecución de la noche.

**Reto 3:** `gh pr comment ${{ github.event.pull_request.number }} --body-file resumen.md`, con `pull-requests: write` y `GH_TOKEN: ${{ github.token }}`. Si el workflow se lanza varias veces en el mismo PR, `gh pr comment --edit-last` cambia el último comentario en lugar de añadir otro.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| plan on pull request | plan en cada pull request |
| read-only role | rol de solo lectura |
| detailed exit code | código de salida detallado |
| path filter | filtro por ruta |
| drift detection | detección de deriva |

🎙️ *"Every pull request that touches the infrastructure runs fmt, validate and plan with a read-only OIDC role, and the plan is published for the reviewer. Applies still need a human; sensitive inputs like my IP are secrets and marked sensitive, so the public logs never show them."*

## Siguiente

[Clase 101 — Vigía v5: toda la infraestructura en Terraform](clase-101-vigia-v5.md)
