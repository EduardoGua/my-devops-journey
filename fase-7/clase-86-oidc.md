# Clase 86 — OIDC: AWS sin llaves

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Entrega y despliegue continuos

> 💡 **La idea de hoy:** la forma antigua de desplegar en AWS desde un pipeline era guardar llaves permanentes como secreto. Con **OIDC**, GitHub firma en cada ejecución un token de pocos minutos que dice quién pide (el repositorio, la rama), y AWS lo cambia por credenciales temporales de un **rol** que solo confía en tu repositorio y en tu rama `main`. Nada que guardar, nada que rotar, nada que filtrar.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los roles, la política de confianza, `AssumeRole`, las credenciales `ASIA…` y CloudTrail (clase 70).
> - Las variables, los secretos, `permissions:` por job y el entorno `production` (clase 85).
> - JSON y base64 (clases 47 y 85); `gh api` (clase 24).
> - Las etiquetas `Proyecto` y el inventario de tu cuenta (clase 67).

> 🔤 **Palabras nuevas de hoy:**
> - **OIDC** (*OpenID Connect*): un estándar para que un servicio demuestre su identidad a otro con un token firmado.
> - **JWT** (*JSON Web Token*): ese token: tres partes en base64 separadas por puntos.
> - ***claims***: los datos de dentro del token: quién firma, para quién, qué repositorio, qué rama.
> - **proveedor de identidad** (*identity provider*): en IAM, el registro que dice "confío en las firmas de GitHub".
> - **`AssumeRoleWithWebIdentity`**: la llamada de STS que cambia un token OIDC por credenciales de un rol.
> - **`sub`** (*subject*): el claim que resume quién pide: repositorio más rama, o más entorno.

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

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Primero miras el token por dentro; después, AWS aprende a confiar en él.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

## Las piezas

### Pieza 1 — El intercambio, y lo que dice el token

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

Un JWT tiene tres partes en base64 separadas por puntos. La del medio son los **claims**:

| Claim | Ejemplo | Qué es |
|-------|---------|--------|
| `iss` | `https://token.actions.githubusercontent.com` | quién firma |
| `aud` | `sts.amazonaws.com` | para quién es |
| `sub` | ver la pieza 2 | el "sujeto": repositorio + rama, o + entorno |
| `repository` / `repository_id` | `EduardoGua/lab-actions` / `987654321` | el repositorio, por nombre y por ID |
| `repository_owner_id` | `1234567` | el ID numérico del dueño |
| `ref` | `refs/heads/main` | la rama o etiqueta que lanzó el workflow |
| `environment` | `production` | solo si el job declara un entorno |

**Pruébalo.** En `lab-actions`, una rama `oidc`, y `.github/workflows/oidc.yml`:

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
cd ~/lab-actions && git switch main && git pull && git switch -c oidc
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git add .github/workflows/oidc.yml && git commit -qm "Ver el token OIDC"
git push -u origin oidc && gh pr create --fill && gh pr checks --watch && gh pr merge --squash --delete-branch
git switch main && git pull
gh workflow run oidc.yml && sleep 15 && gh run view --log | grep -E "iss |aud |sub |repository|ref |actor"
```

👀 **Qué deberías ver:** `iss` con la URL de GitHub, `aud` `sts.amazonaws.com`, tu `sub`, `repository` `TU_USUARIO/lab-actions` con sus dos ID numéricos, `ref` `refs/heads/main` y `actor` tu usuario.

✋ **Sin mirar:** ¿qué permiso necesita un job para pedir el token OIDC?

<details>
<summary>Comprueba</summary>

`id-token: write`. Sin él, ni siquiera existen las variables para pedirlo.
</details>

**En resumen:** token OIDC firmado por GitHub → STS lo comprueba → credenciales temporales del rol; los claims dicen quién pide.

### Pieza 2 — El `sub` cambió, y los ID que no se pueden suplantar

⚠️ **El `sub` cambió en 2026.** En los repositorios creados **después del 15 de julio de 2026**, lleva los ID numéricos:

```
antes:   repo:EduardoGua/vigia:ref:refs/heads/main
ahora:   repo:EduardoGua@1234567/vigia@987654321:ref:refs/heads/main
```

Y si el job declara `environment:`, el `sub` termina en `:environment:production` en lugar de en la rama. Las guías antiguas de internet usan el formato viejo: copiar su política tal cual te dará `AccessDenied` (Rómpelo 3).

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

Las cuatro condiciones se cumplen a la vez: el token es para STS; viene de **ese** dueño y **ese** repositorio; y viene de la rama `main`. Funciona con los dos formatos del `sub`, porque no lo usa.

🔮 **Predice:** ¿en qué formato salió tu `sub` en la pieza 1?

**Pruébalo:** compara los ID de los claims con los que da la API:

```bash
gh api "repos/{owner}/{repo}" --jq '"repositorio \(.id) · dueño \(.owner.id)"'
```

👀 **Qué deberías ver:** los mismos dos números que `repository_id` y `repository_owner_id` en el log. Y tu `sub` con los ID (`repo:TU_USUARIO@…/lab-actions@…:ref:refs/heads/main`): `lab-actions` lo creaste en la clase 82, después del 15 de julio de 2026.

✋ **Sin mirar:** ¿por qué es más seguro condicionar por `repository_id` que por el nombre del repositorio?

<details>
<summary>Comprueba</summary>

Porque un nombre se puede cambiar y reutilizar, y otra persona podría crear un repositorio con el tuyo; el ID numérico es único y no cambia nunca.
</details>

**En resumen:** condiciones por `aud`, `repository_owner_id`, `repository_id` y `ref`: no dependen de nombres ni del formato del `sub`.

### Pieza 3 — El proveedor de identidad

Una vez por cuenta, IAM tiene que conocer a GitHub como proveedor. La **audiencia** (`sts.amazonaws.com`) es la que pide `configure-aws-credentials`, y **la huella del certificado** (`--thumbprint-list`) ya no hace falta: AWS verifica a GitHub con sus propias autoridades de certificación. Este proveedor lo usarán también Vigía v4 y la fase 8: por eso la etiqueta `vigia`.

**Pruébalo:**

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --tags Key=Proyecto,Value=vigia
aws iam list-open-id-connect-providers
```

👀 **Qué deberías ver:** un `OpenIDConnectProviderArn` como `arn:aws:iam::<cuenta>:oidc-provider/token.actions.githubusercontent.com`, y el mismo ARN en la lista.

✋ **Sin mirar:** ¿cuántas veces creas el proveedor de GitHub en una cuenta?

<details>
<summary>Comprueba</summary>

Una sola: lo comparten todos los roles que confíen en GitHub.
</details>

**En resumen:** el proveedor OIDC de GitHub, una vez por cuenta, con la audiencia `sts.amazonaws.com`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Un rol que solo confía en tu repositorio

La política de confianza tiene el **proveedor** como `Principal` (`Federated`), la acción `sts:AssumeRoleWithWebIdentity` y las cuatro condiciones de la pieza 2. El rol no tendrá **ningún** permiso: para `sts get-caller-identity` no hace falta. Hoy solo pruebas que GitHub puede entrar; en la clase 87 le darás lo justo para subir a ECR.

**Pruébalo:**

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
cd ~/lab-actions
gh variable set AWS_ROLE_ARN --body "arn:aws:iam::$CUENTA:role/lab-github"
gh variable list
```

👀 **Qué deberías ver:** tu cuenta y los dos ID (los mismos de la pieza 2), el ARN del rol `arn:aws:iam::<cuenta>:role/lab-github` y, en `gh variable list`, `AWS_ROLE_ARN` con ese valor: es una **variable**, no un secreto.

✋ **Sin mirar:** en esta política de confianza, ¿qué va en `Principal`?

<details>
<summary>Comprueba</summary>

El proveedor OIDC de GitHub, como `Federated`: `arn:aws:iam::<cuenta>:oidc-provider/token.actions.githubusercontent.com`.
</details>

**En resumen:** `Principal` federado + `AssumeRoleWithWebIdentity` + las cuatro condiciones; el ARN del rol, en una variable.

### Pieza 5 — Entrar en AWS desde el pipeline

`aws-actions/configure-aws-credentials` hace los pasos 1 a 5 de la pieza 1: pide el token, llama a STS y deja las credenciales temporales en el entorno del job.

🔮 **Predice:** ¿quién eres para AWS dentro del job?

**Pruébalo.** En una rama, añade estos dos steps al final del job `quien-soy`, únelo con un PR y lánzalo desde `main`:

```yaml
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - run: aws sts get-caller-identity
```

```bash
gh workflow run oidc.yml && sleep 20 && gh run view --log | grep -A4 '"Arn"\|get-caller-identity'
gh secret list
```

👀 **Qué deberías ver:** `"Arn": "arn:aws:sts::<cuenta>:assumed-role/lab-github/GitHubActions"`: el rol, con una sesión temporal. Y `gh secret list` vacío: ningún secreto en GitHub.

✋ **Sin mirar:** ¿qué tiene que saber el workflow para entrar en AWS con OIDC?

<details>
<summary>Comprueba</summary>

Solo el ARN del rol (y la región). Nada secreto.
</details>

**En resumen:** `configure-aws-credentials` con `role-to-assume` y `id-token: write`: AWS sin llaves.

### Pieza 6 — El rastro en CloudTrail

Cada entrada del pipeline en tu cuenta queda registrada en CloudTrail (clase 70), con su origen: el evento es `AssumeRoleWithWebIdentity`.

**Pruébalo:** en la consola, **CloudTrail → Event history**, filtra por *Event name* = `AssumeRoleWithWebIdentity` y abre el evento.

👀 **Qué deberías ver:** en `userIdentity`, el tipo `WebIdentityUser` y el proveedor `token.actions.githubusercontent.com`; en `requestParameters`, el ARN del rol `lab-github` y el nombre de la sesión, `GitHubActions`.

✋ **Sin mirar:** ¿cómo averiguas cuándo entró tu pipeline en la cuenta por última vez?

<details>
<summary>Comprueba</summary>

En CloudTrail, buscando el evento `AssumeRoleWithWebIdentity`.
</details>

**En resumen:** cada `AssumeRoleWithWebIdentity` queda en CloudTrail, con el proveedor, el rol y la sesión.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `permissions: id-token: write` (en el job) | poder pedir el token OIDC |
| `aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com` | el proveedor, una vez por cuenta |
| `"Principal": {"Federated": "arn:aws:iam::<cuenta>:oidc-provider/token.actions.githubusercontent.com"}` | confiar en GitHub |
| `"Action": "sts:AssumeRoleWithWebIdentity"` | la acción del intercambio |
| condiciones `aud`, `repository_owner_id`, `repository_id`, `ref` (o `environment`) | solo tu repositorio y tu rama |
| `gh api "repos/{owner}/{repo}" --jq '.id, .owner.id'` | los ID de tu repositorio |
| `gh variable set AWS_ROLE_ARN --body "arn:…"` | el ARN del rol, como variable |
| `aws-actions/configure-aws-credentials@<SHA> # v6.3.0` con `role-to-assume` y `aws-region` | entrar en AWS desde el job |
| CloudTrail → `AssumeRoleWithWebIdentity` | el rastro de cada entrada |

## Rómpelo

**1. Sin el permiso del token.** Quita `id-token: write` del job, une y lanza. La action falla porque no puede pedir el token a GitHub: el error te sugiere que revises el permiso `id-token`. Devuélvelo.

**2. Desde otra rama.** Lanza el workflow desde una rama distinta de `main`, con el archivo también en ella: `gh workflow run oidc.yml --ref oidc`. `Not authorized to perform sts:AssumeRoleWithWebIdentity`: el `ref` del token es `refs/heads/oidc`, y la política exige `main`. Es lo que quieres: una rama cualquiera no despliega.

**3. El formato viejo del `sub`.** Cambia la condición de `repository_id` por la que traen las guías antiguas y vuelve a aplicar la política:

```bash
cd ~/my-devops-journey/labs/clase-86
sed 's|"token.actions.githubusercontent.com:repository_id": "[0-9]*"|"token.actions.githubusercontent.com:sub": "repo:TU_USUARIO/lab-actions:ref:refs/heads/main"|' \
  confianza-github.json > vieja.json
aws iam update-assume-role-policy --role-name lab-github --policy-document file://vieja.json
```

Lanza el workflow desde `main`: `Not authorized`. Tu `sub` real lleva los ID y ya no coincide. Vuelve a la buena:

```bash
aws iam update-assume-role-policy --role-name lab-github --policy-document file://confianza-github.json
```

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Haz que `quien-soy` use el entorno `production` (clase 85) y que el rol confíe en el entorno en lugar de en la rama. ¿Cómo cambia el `sub`, y qué ventaja tiene?

> 🧩 **Ejemplo resuelto:** la condición de la pieza 2: `"token.actions.githubusercontent.com:ref": "refs/heads/main"`.

**Ahora tú, con huecos:** en el job, `environment: ____`; en la política:
```bash
sed 's|"token.actions.githubusercontent.com:ref": "refs/heads/main"|"token.actions.githubusercontent.com:____": "production"|' \
  confianza-github.json > confianza-entorno.json
aws iam update-assume-role-policy --role-name lab-github --policy-document file://confianza-entorno.json
```
Completa: «El `sub` termina ahora en ____. La ventaja es que el rol solo se usa en jobs que pasan por…».

<details>
<summary>Pista</summary>

El claim se llama igual que la clave del job. Recuerda que `production` tiene un revisor y solo admite `main` (clase 85). Al terminar, vuelve a la política buena, como en el Rómpelo 3.
</details>

**2.** Haz las sesiones del pipeline más cortas. ¿Qué gana la seguridad, y qué riesgo tiene?

> 🧩 **Ejemplo resuelto:** en la clase 70, `aws sts assume-role … --duration-seconds 900` pedía credenciales de 15 minutos.

**Ahora tú, con huecos:** añade a `configure-aws-credentials` la línea `role-duration-seconds: ____`. Completa: «Si alguien roba las credenciales del job, le sirven ____ como mucho. El riesgo: si el job tarda más de ____, …».

<details>
<summary>Pista</summary>

900 segundos es el mínimo que admite STS. Piensa en un despliegue que tarda 20 minutos.
</details>

**3.** ¿Por qué el ARN del rol puede ir en una variable y no hace falta un secreto?

> 🧩 **Ejemplo resuelto:** el Rómpelo 2 de la clase 70: aunque eras administrador, no pudiste asumir un rol cuya política de confianza solo admitía a EC2.

**Ahora tú, con huecos:** «Con el ARN, alguien de fuera ____, porque la política de confianza exige un token firmado por ____ y que venga de mi ____ y de mi rama ____».

<details>
<summary>Pista</summary>

Saber el nombre de un rol no da ningún permiso: hay que cumplir su política de confianza.
</details>

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

1. Explica, paso a paso, cómo consigue un job credenciales de AWS sin que haya llaves en GitHub. *(5 líneas, una por paso. Empieza así: «1. El job, con `id-token: write`, pide a GitHub un token OIDC…»)*
2. ¿Por qué tu política de confianza condiciona por `repository_id` y `repository_owner_id` en lugar de por el nombre del repositorio? *(2 líneas. Empieza así: «Porque los nombres cambian y se pueden reutilizar:… Los ID…»)*
3. ¿Qué impide que una rama cualquiera, o un *fork*, despliegue con tu rol? *(2 líneas. Empieza así: «Las condiciones de la política de confianza: `ref = refs/heads/main` deja fuera… y `repository_id`…»)*
4. **Repaso (clase 85, sin mirar):** ¿cómo se evita la inyección de órdenes en un `run:`? *(1 línea. Empieza así: «Pasando el valor no confiable por…»)*

Después, escríbeme `examíname clase-86`.

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

**Reto 1:** `environment: production` y la condición `token.actions.githubusercontent.com:environment`. El `sub` termina en `:environment:production`. Condicionar por entorno significa que el rol solo se usa en jobs que pasan por las reglas de `production`: sus ramas permitidas y su revisor.

**Reto 2:** `role-duration-seconds: 900`. Si alguien roba las credenciales del job, le sirven **15 minutos** como mucho. El riesgo: si el job tarda más de **15 minutos**, las credenciales caducan a mitad y los últimos pasos fallan con `ExpiredToken`.

**Reto 3:** con el ARN, alguien de fuera **no puede asumir el rol**, porque la política de confianza exige un token firmado por **GitHub** (el proveedor OIDC de tu cuenta) y que venga de mi **repositorio** (por su ID) y de mi rama **`main`**. El ARN solo dice cómo se llama el rol.
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
