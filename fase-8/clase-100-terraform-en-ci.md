# Clase 100 — Terraform en CI

**Dónde:** GitHub + tu Ubuntu (AWS) · **Tiempo:** 90 min · **Bloque:** B. Vigía en código

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

## Teoría

### El flujo

```
PR que cambia infra/  ──►  fmt -check ─► init (backend S3) ─► validate ─► plan
                                              │ OIDC: vigia-terraform-plan (solo lectura)
                                              ▼
                          el plan, en el resumen de la ejecución  ──►  revisión  ──►  merge
                                                                                        │
                          tú, en tu Ubuntu: terraform plan + apply  ◄───────────────────┘
```

El pipeline **planifica**; el `apply` lo sigues haciendo tú, en tu máquina, después de unir. Un `apply` automático en `main` es posible (Reto 1), pero entonces el pipeline necesitaría permisos para cambiar **toda** tu infraestructura. Para empezar, que tenga permisos de lectura y la decisión siga siendo humana.

### Un rol de solo lectura que acepta los PR

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

### Las variables, sin enseñar nada

El plan de un repositorio público lo puede leer **cualquiera**. Cada variable de Terraform llega como `TF_VAR_<nombre>` (clase 94):

| Variable | De dónde, en el pipeline |
|----------|--------------------------|
| `mi_ip` | un **secreto** (`secrets.MI_IP`), y en `variables.tf`, `sensitive = true`: en el plan sale como `(sensitive value)` |
| `github_user` | `github.repository_owner`, del contexto |
| `github_repository_id` y `github_owner_id` | `github.repository_id` y `github.repository_owner_id`, del contexto: los mismos ID que viste en la clase 86 |
| `etiqueta_imagen` | una **variable** de GitHub, `TF_ETIQUETA_IMAGEN`, con el **mismo** valor que tu `terraform.tfvars`. Si no coincidieran, el plan propondría recrear la instancia |

### `-detailed-exitcode`

| Código | Significado |
|--------|-------------|
| 0 | sin cambios |
| 1 | error |
| 2 | **hay cambios** |

Con él, un script sabe si la infraestructura coincide con el código. Es la base de la detección de *drift* programada (Reto 2 de la clase 99). En el workflow, el 2 no es un fallo: es lo esperado en un PR que cambia algo.

### Un detalle de los filtros por ruta

El workflow solo corre si el PR toca `infra/**` o `deploy/cloud-init.yaml`. Por eso **no** lo hagas obligatorio en el ruleset (clase 84): en los PR que no tocan esos archivos, la comprobación no aparecería nunca y GitHub esperaría por ella para siempre.

## Práctica guiada

### 1. El rol del plan, en Terraform (20 min)

En `infra/github.tf`, añade el rol `vigia-terraform-plan`, con estos tres recursos:
- un `aws_iam_role` con la política de confianza de la teoría, escrita con `jsonencode` como la del rol del pipeline;
- un `aws_iam_role_policy_attachment` con `arn:aws:iam::aws:policy/ReadOnlyAccess`;
- un `aws_iam_role_policy` con `s3:PutObject` y `s3:DeleteObject` sobre `arn:aws:s3:::vigia-tfstate-${local.cuenta}/vigia/terraform.tfstate.tflock`.

Y un output con su ARN.

En `infra/variables.tf`, marca `mi_ip` como `sensitive = true`.

```bash
cd ~/vigia/infra && terraform fmt && terraform validate && terraform plan
```

🔮 **Predice:** ¿cuántos recursos añade el plan? Tres: el rol, el *attachment* y la política *inline*. Y `mi_ip` sale ahora como `(sensitive value)` en la regla del SG. Aplica:

```bash
terraform apply
terraform output -raw rol_terraform_plan
```

### 2. Lo que necesita GitHub (10 min)

```bash
cd ~/vigia
gh variable set AWS_TERRAFORM_PLAN_ROLE_ARN --body "$(terraform -chdir=infra output -raw rol_terraform_plan)"
gh variable set TF_ETIQUETA_IMAGEN --body "$(grep etiqueta_imagen infra/terraform.tfvars | cut -d'"' -f2)"
gh secret set MI_IP --body "$(grep mi_ip infra/terraform.tfvars | cut -d'"' -f2)"
gh variable list && gh secret list
```

`AWS_REGION` ya existe desde la fase 7. Tu IP, como **secreto**: GitHub la enmascara en los logs.

### 3. El workflow (25 min)

`.github/workflows/terraform.yml`:

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

### 4. Un PR con cambios (15 min)

En una rama, cambia la retención de `/vigia/checker` a 14 días, sube el PR y espera:

```bash
gh pr create --fill && gh pr checks --watch
gh run view --log | grep -E "retention_in_days|Plan:"
```

🔮 **Predice:** ¿qué muestra el resumen de la ejecución? `# aws_cloudwatch_log_group.vigia["checker"] will be updated in-place` y `Plan: 0 to add, 1 to change, 0 to destroy.` Y el job está en verde, con un aviso: el 2 de `-detailed-exitcode` es lo esperado.

Lee el plan **en GitHub**, como lo haría quien revisa. Une el PR y aplica tú:

```bash
git switch main && git pull && cd infra && terraform apply
```

El `push` a `main` lanza el workflow otra vez. Si lo lanzas a mano después de tu `apply` (`gh workflow run terraform.yml`), dirá `Sin cambios`: código y realidad coinciden.

## Rómpelo

1. **El formato.** Desalinea un `=` en `main.tf` y sube el PR: el step `Formato` falla con el `diff` que habría que aplicar. `terraform fmt` en tu máquina y otro commit.
2. **Una variable que falta.** Borra un momento el secreto (`gh secret delete MI_IP`) y relanza: `TF_VAR_mi_ip` llega vacía y tu **validación** de la clase 97 la para, con tu mensaje. Una buena validación también es documentación para el pipeline. Vuelve a crear el secreto.
3. **Un rol que no acepta PR.** En la política de confianza del rol del plan, quita `"refs/pull/*/merge"`, aplica y relanza el PR. `configure-aws-credentials` no puede asumir el rol: es la clase 86 otra vez. Devuélvelo y aplica.

## Reto

1. **Apply con aprobación.** Diseña (sin implementarlo) un job `apply` que corra en `push` a `main`, en el entorno `production` con revisor obligatorio (clase 85), y que aplique el `plan.tfplan` guardado como artefacto. ¿Qué rol necesitaría y con qué permisos? ¿Por qué el plan debería ser el del mismo commit?
2. **Drift cada noche.** Añade `schedule: - cron: "0 7 * * *"` y un step que, si el código de salida es 2 en `main`, abra una *issue* con `gh issue create`. ¿Qué permiso necesita el job?
3. **El plan en el PR.** Busca cómo publicar el resumen del plan como un **comentario** del PR con `gh pr comment`. ¿Qué permiso del `GITHUB_TOKEN` hace falta (clase 85)?

## Destruir al terminar

Nada que destruir. Si cambiaste la retención para el PR, déjala en 7 días o en 14, pero que el código y la realidad coincidan (`terraform plan` → `No changes`).

## Cierre

En `notas/fase-8/clase-100.md`:

1. ¿Qué hace el workflow de Terraform y qué no hace? ¿Por qué el `apply` sigue siendo tuyo?
2. ¿Por qué el rol del plan acepta `refs/pull/*/merge` y el del despliegue no?
3. ¿Cómo evitas que el plan, en un repositorio público, enseñe tu IP?
4. **Repaso (clase 99, sin mirar):** ¿qué opciones tienes cuando el plan muestra un *drift*?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Comprueba el formato, inicializa el backend, valida y planifica cada cambio de infraestructura, y deja el plan a la vista de quien revisa el PR. No aplica nada: su rol solo lee. El `apply` sigue siendo tuyo porque cambiar la infraestructura es más arriesgado que desplegar una imagen. Automatizarlo exigiría darle al pipeline permisos para cambiarlo todo, y una aprobación humana para cada cambio (Reto 1).

**2.** Porque el rol del plan **solo lee**: si un PR lo usa, como mucho ve tu infraestructura, y necesita hacerlo para planificar el cambio que propone. El rol del despliegue **cambia** cosas (publica imágenes, ordena despliegues) y solo debe usarse con código ya revisado y unido a `main`.

**3.** Marcando la variable `mi_ip` como `sensitive = true` en Terraform, para que el plan la muestre como `(sensitive value)`, y pasándola como **secreto** de GitHub (`secrets.MI_IP`), que además se enmascara en los logs.

**4.**
- **Revertir:** aplicar, para que la realidad vuelva a lo que dice el código.
- **Aceptar:** cambiar el código para que diga lo mismo que la realidad, con un PR, y aplicar.
- **Ignorar ese atributo** con `ignore_changes`, si de verdad lo gestiona otro.

Con `plan -refresh-only` se ve el cambio sin decidir nada.

**Reto 2:** `issues: write`, además de lo que ya tiene el job.
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
