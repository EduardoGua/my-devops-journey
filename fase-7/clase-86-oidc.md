# Clase 86 — OIDC: AWS sin llaves

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Entrega y despliegue continuos

## Objetivo

- Entender cómo entra un workflow de GitHub en AWS **sin llaves guardadas**:
  - un token **OIDC** firmado por GitHub;
  - un **proveedor de identidad** en IAM;
  - un **rol** que confía en él.
- Ver con tus ojos lo que lleva ese token: el repositorio, la rama, los ID.
- Escribir una política de confianza que solo admite **tu** repositorio y **tu** rama `main`, usando identificadores que no se pueden suplantar.
- Romperla de las tres formas típicas y leer el error.

## Por qué importa

La forma antigua de desplegar en AWS desde un pipeline era crear un usuario de IAM, generar sus llaves de acceso y guardarlas como secreto en GitHub. Esas llaves:
- son **permanentes**;
- las ve cualquier workflow del repositorio;
- se olvidan de rotar;
- un día acaban filtradas.

Con OIDC, GitHub presenta en cada ejecución una credencial **firmada y de un solo uso**, y AWS la cambia por credenciales temporales de un rol. Si alguien la roba, le sirve unos minutos.

Es el segundo pilar de "ninguna credencial de AWS en el repositorio", un criterio de salida de la fase, y lo que se espera hoy de cualquier pipeline serio.

## Costo esperado

> 💰 **0 USD.** IAM, STS y los proveedores de identidad son gratis.

## Teoría

### El intercambio

```
job con permissions: id-token: write
  │ 1. pide un token a GitHub (un JWT firmado, válido unos minutos)
  ▼
aws-actions/configure-aws-credentials
  │ 2. sts:AssumeRoleWithWebIdentity(rol, token)
  ▼
AWS STS ── 3. ¿la firma es de token.actions.githubusercontent.com?  (el proveedor OIDC de IAM)
       └─ 4. ¿cumple las condiciones de la política de confianza del rol? (aud, repositorio, rama…)
  │ 5. credenciales temporales del rol (1 h por defecto)
  ▼
el resto del job usa la AWS CLI como siempre
```

Nada se guarda en GitHub. Lo único que el workflow necesita saber es el **ARN del rol**, que no es secreto: va en una **variable**.

### Qué dice el token

Un JWT tiene tres partes en base64 separadas por puntos. La del medio son los **claims**, los datos de quién pide:

| Claim | Ejemplo | Qué es |
|-------|---------|--------|
| `iss` | `https://token.actions.githubusercontent.com` | quién firma |
| `aud` | `sts.amazonaws.com` | para quién es |
| `sub` | ver abajo | el "sujeto": repositorio + rama, o + entorno |
| `repository` / `repository_id` | `EduardoGua/lab-actions` / `987654321` | el repositorio, por nombre y por ID |
| `repository_owner_id` | `1234567` | el ID numérico del dueño |
| `ref` | `refs/heads/main` | la rama o etiqueta que lanzó el workflow |
| `environment` | `production` | solo si el job declara un entorno |

⚠️ **El `sub` cambió en 2026.** En los repositorios creados **después del 15 de julio de 2026**, lleva los ID numéricos:

```
antes:   repo:EduardoGua/vigia:ref:refs/heads/main
ahora:   repo:EduardoGua@1234567/vigia@987654321:ref:refs/heads/main
```

Y si el job declara `environment:`, el `sub` termina en `:environment:production` en lugar de en la rama. Las guías antiguas de internet usan el formato viejo: copiar su política tal cual te dará `AccessDenied`.

### Una política de confianza que no se puede suplantar

Los **nombres** de usuario y de repositorio se pueden cambiar, y un nombre liberado lo puede coger otra persona. Si la política confía en `EduardoGua/vigia` por nombre, quien se quede ese nombre podría asumir tu rol. AWS recomienda condicionar por los **ID**, que nunca cambian:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:repository_owner_id": "1234567",
    "token.actions.githubusercontent.com:repository_id": "987654321",
    "token.actions.githubusercontent.com:ref": "refs/heads/main"
  }
}
```

Las cuatro condiciones se cumplen a la vez:
- el token es para STS;
- viene de **ese** dueño y **ese** repositorio;
- viene de la rama `main`.

Funciona con los dos formatos del `sub`, porque no lo usa.

## Práctica guiada

### 1. Mira tu token (15 min)

En `lab-actions`, una rama `oidc`, y `.github/workflows/oidc.yml`:

```yaml
name: oidc

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  quien-soy:
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Los claims del token OIDC (sin mostrar el token)
        run: |
          TOKEN=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | jq -r .value)
          echo "::add-mask::$TOKEN"
          python3 - "$TOKEN" <<'PY'
          import base64, json, sys
          carga = sys.argv[1].split(".")[1]
          carga += "=" * (-len(carga) % 4)
          claims = json.loads(base64.urlsafe_b64decode(carga))
          for clave in ("iss", "aud", "sub", "repository", "repository_id", "repository_owner_id", "ref", "actor"):
              print(f"{clave:20} {claims.get(clave)}")
          PY
```

- **`id-token: write`:** solo este job puede pedir el token. Las dos variables `ACTIONS_ID_TOKEN_REQUEST_*` solo existen con ese permiso.
- **El token no se imprime:** `::add-mask::` lo tapa por si acaso. Solo se decodifica y se muestran los claims.

Pásale actionlint, únelo a `main` con un PR y lánzalo:

```bash
gh workflow run oidc.yml && sleep 15 && gh run view --log | grep -E "iss |aud |sub |repository|ref |actor"
```

🔮 **Predice:** ¿en qué formato sale tu `sub`? `lab-actions` lo creaste en la clase 82, después del 15 de julio de 2026, así que con los ID (`repo:TU_USUARIO@…/lab-actions@…:ref:refs/heads/main`). Comprueba que `repository_id` y `repository_owner_id` coinciden con lo que da la API:

```bash
gh api "repos/{owner}/{repo}" --jq '"repositorio \(.id) · dueño \(.owner.id)"'
```

### 2. El proveedor de identidad (5 min)

Una vez por cuenta, IAM tiene que conocer a GitHub como proveedor:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --tags Key=Proyecto,Value=vigia
aws iam list-open-id-connect-providers
```

- La **audiencia** (`sts.amazonaws.com`) es la que pide `configure-aws-credentials`.
- **La huella del certificado** (`--thumbprint-list`) ya no hace falta: AWS verifica a GitHub con sus propias autoridades de certificación.

Este proveedor lo usarán también Vigía v4 y la fase 8: por eso la etiqueta `vigia`.

### 3. Un rol que solo confía en tu repositorio (20 min)

```bash
mkdir -p ~/my-devops-journey/labs/clase-86 && cd ~/my-devops-journey/labs/clase-86
CUENTA=$(aws sts get-caller-identity --query Account --output text)
read -r REPO_ID DUENO_ID <<< "$(cd ~/lab-actions && gh api 'repos/{owner}/{repo}' --jq '"\(.id) \(.owner.id)"')"
echo "$CUENTA $REPO_ID $DUENO_ID"
cat > confianza-github.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Federated": "arn:aws:iam::$CUENTA:oidc-provider/token.actions.githubusercontent.com"},
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:repository_owner_id": "$DUENO_ID",
          "token.actions.githubusercontent.com:repository_id": "$REPO_ID",
          "token.actions.githubusercontent.com:ref": "refs/heads/main"
        }
      }
    }
  ]
}
EOF
aws iam create-role --role-name lab-github --assume-role-policy-document file://confianza-github.json \
  --max-session-duration 3600 --tags Key=Proyecto,Value=lab --query Role.Arn --output text
```

El rol no tiene **ningún** permiso: para `sts:get-caller-identity` no hace falta. Hoy solo pruebas que GitHub puede entrar. En la clase 87 le darás lo justo para subir a ECR.

Guarda su ARN como **variable** del repositorio:

```bash
cd ~/lab-actions
gh variable set AWS_ROLE_ARN --body "arn:aws:iam::$CUENTA:role/lab-github"
```

### 4. Entrar en AWS desde el pipeline (15 min)

Añade estos dos steps al final del job `quien-soy`:

```yaml
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - run: aws sts get-caller-identity
```

Únelo con un PR y lánzalo desde `main`:

```bash
gh workflow run oidc.yml && sleep 20 && gh run view --log | grep -A4 '"Arn"\|get-caller-identity'
```

🔮 **Predice:** ¿quién eres para AWS dentro del job? `arn:aws:sts::<cuenta>:assumed-role/lab-github/GitHubActions`: el rol, con una sesión temporal. Ningún secreto en GitHub. Compruébalo: `gh secret list` está vacío.

### 5. El rastro en CloudTrail (10 min)

En la consola: **CloudTrail → Event history**, filtra por *Event name* = `AssumeRoleWithWebIdentity`. Abre el evento:
- en `userIdentity` verás el proveedor de GitHub;
- en `requestParameters`, el rol y el nombre de la sesión.

Cada entrada del pipeline en tu cuenta queda registrada, con su origen.

## Rómpelo

**1. Sin el permiso del token.** Quita `id-token: write` del job, une y lanza. La action falla porque no puede pedir el token a GitHub: el error te sugiere que revises el permiso `id-token`. Devuélvelo.

**2. Desde otra rama.** Lanza el workflow desde una rama distinta de `main`, con el archivo también en ella: `gh workflow run oidc.yml --ref oidc`. `Not authorized to perform sts:AssumeRoleWithWebIdentity`: el `ref` del token es `refs/heads/oidc`, y la política exige `main`. Es lo que quieres: una rama cualquiera no despliega.

**3. El formato viejo del `sub`.** Cambia la condición de `repository_id` por la que traen las guías antiguas y vuelve a aplicar la política:

```bash
sed 's|"token.actions.githubusercontent.com:repository_id": "[0-9]*"|"token.actions.githubusercontent.com:sub": "repo:TU_USUARIO/lab-actions:ref:refs/heads/main"|' \
  confianza-github.json > vieja.json
aws iam update-assume-role-policy --role-name lab-github --policy-document file://vieja.json
```

Lanza el workflow desde `main`: `Not authorized`. Tu `sub` real lleva los ID y ya no coincide. Vuelve a la buena:

```bash
aws iam update-assume-role-policy --role-name lab-github --policy-document file://confianza-github.json
```

## Reto

1. Haz que `quien-soy` use el entorno `production` (clase 85) y cambia la condición `ref` por `token.actions.githubusercontent.com:environment` = `production`. ¿Cómo cambia el `sub` que imprime el paso 1? ¿Qué ventaja tiene condicionar por entorno y no por rama?
2. Añade `role-duration-seconds: 900` a `configure-aws-credentials`. ¿Qué gana la seguridad con sesiones más cortas, y qué riesgo tiene si el job tarda más?
3. ¿Por qué el ARN del rol puede ir en una variable y no hace falta un secreto? Piensa qué podría hacer con él alguien que no es tu repositorio.

## Destruir al terminar

Hoy no hay nada que cobre. **Deja** el rol `lab-github`, la variable `AWS_ROLE_ARN` y el proveedor OIDC: los usarás en las clases 87 a 89, y el rol se borra al final de la 89. El proveedor se queda también después, para Vigía. Apúntalos en tu inventario.

Si vas a dejar pasar semanas antes de la clase 87, bórralo:

```bash
aws iam delete-role --role-name lab-github
cd ~/lab-actions && gh variable delete AWS_ROLE_ARN
```

Si el rol tuviera políticas, primero habría que quitarlas (clase 69); hoy no tiene ninguna.

## Cierre

En `notas/fase-7/clase-86.md`:

1. Explica, paso a paso, cómo consigue un job credenciales de AWS sin que haya llaves en GitHub.
2. ¿Por qué tu política de confianza condiciona por `repository_id` y `repository_owner_id` en lugar de por el nombre del repositorio?
3. ¿Qué impide que una rama cualquiera, o un *fork*, despliegue con tu rol?
4. **Repaso (clase 85, sin mirar):** ¿cómo se evita la inyección de órdenes en un `run:`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.**
1. El job tiene `id-token: write` y pide a GitHub un token OIDC: un JWT firmado, de pocos minutos, con claims como el repositorio, la rama y la audiencia.
2. `configure-aws-credentials` lo envía a STS con `AssumeRoleWithWebIdentity` y el ARN del rol.
3. STS comprueba la firma con el proveedor OIDC registrado en IAM.
4. STS comprueba que el token cumple las condiciones de la política de confianza del rol.
5. STS devuelve credenciales temporales del rol, válidas una hora, que la action deja en el entorno del job.

Nada permanente existe en ningún sitio.

**2.** Porque los nombres cambian y se pueden reutilizar: si renombras o borras tu cuenta o el repositorio, otra persona podría crear uno con el mismo nombre y su token cumpliría una condición por nombre. Los ID numéricos son únicos y no cambian nunca, ni siquiera si renombras. Además, no dependen del formato del `sub`, que cambió en 2026.

**3.** Las condiciones de la política de confianza:
- **`ref = refs/heads/main`** deja fuera cualquier otra rama.
- **`repository_id`** deja fuera cualquier otro repositorio, incluidos los *forks*, que tienen su propio ID.

Además, los workflows de PR que vienen de *forks* no pueden pedir tokens OIDC con permisos de escritura.

**4.** Pasando el valor no confiable por `env:` y usándolo como `"$VARIABLE"` en el script, en lugar de meter `${{ … }}` dentro del `run:`.

**Reto 1:** el `sub` termina en `:environment:production`. Condicionar por entorno significa que el rol solo se usa en jobs que pasan por las reglas de `production`: sus ramas permitidas y su revisor.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| OpenID Connect (OIDC) / identity provider | OpenID Connect / proveedor de identidad |
| JSON Web Token (JWT) / claims | token web JSON / afirmaciones (datos del token) |
| web identity federation | federación de identidades web |
| trust policy condition | condición de la política de confianza |
| long-lived credentials | credenciales de larga duración |

🎙️ *"My pipeline has no AWS keys. GitHub Actions requests a short-lived OIDC token, and STS exchanges it for temporary role credentials. The role's trust policy only accepts my repository and the main branch, using the immutable repository and owner IDs rather than names."*

## Siguiente

[Clase 87 — Construir y publicar la imagen en ECR](clase-87-publicar-en-ecr.md)
