# Clase 69 — IAM I: usuarios, grupos y políticas

**Dónde:** navegador (consola y CloudShell) · **Tiempo:** 90 min · **Bloque:** A. Cuenta, costos e identidad

> 💡 **La idea de hoy:** cada petición a AWS pasa por IAM, que mira **quién** la hace, **qué acción** pide, **sobre qué recurso** y **en qué condiciones**, y decide con tres reglas: todo empieza denegado, un `Allow` lo permite y un `Deny` explícito gana siempre. Los permisos se escriben en **políticas** JSON, se dan a **grupos**, se ajustan al **mínimo** necesario y se prueban con el simulador antes de que nadie los use.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los permisos `rwx`, los usuarios y los grupos de Linux (clases 06 y 09): IAM es la misma idea, a escala de una nube.
> - Tu usuario `eduardo` en el grupo `administradores` (clase 67); CloudShell y `--query` (clase 68).
> - JSON (clase 47) y los *heredoc* (clase 07): con `<<EOF`, sin comillas, Bash sustituye las variables de dentro.

> 🔤 **Palabras nuevas de hoy:**
> - **autenticación / autorización**: demostrar quién eres / decidir si puedes hacer algo.
> - **principal**: quien hace la petición: un usuario, un rol o un servicio.
> - **ARN** (*Amazon Resource Name*): el nombre único de cada cosa en AWS, como `arn:aws:iam::123456789012:user/eduardo`.
> - **política**: un documento JSON con `Effect`, `Action`, `Resource` y, a veces, `Condition`.
> - **`implicitDeny` / `explicitDeny`**: denegado porque nadie lo permitió / denegado por un `Deny` escrito.
> - **política administrada / *inline***: reutilizable y con versiones / incrustada en una sola identidad.
> - **mínimo privilegio**: solo los permisos necesarios, y ninguno más.

## Objetivo

- Entender cómo decide IAM si una petición se permite: **quién** la hace, **qué acción**, **sobre qué recurso** y **en qué condiciones**.
- Leer y escribir **políticas** en JSON: `Effect`, `Action`, `Resource` y `Condition`.
- Distinguir las políticas administradas por AWS, las tuyas y las *inline*, y por qué los permisos se dan a **grupos**, no a usuarios.
- Aplicar el **mínimo privilegio** y comprobarlo sin riesgo con el **simulador de políticas** y **Access Analyzer**.

## Por qué importa

IAM está en cada cosa que harás en AWS:
- cada orden de la CLI pasa por IAM;
- cada error `AccessDenied` es IAM diciendo que no;
- cada incidente grave de seguridad en la nube tiene detrás un permiso demasiado amplio.

En la fase 1 aprendiste los permisos de Linux (`rwx`, usuarios y grupos). IAM es la misma idea, a escala de una nube entera.

Es también el corazón del dominio 2 del examen, el 30 % de las preguntas. Y en las entrevistas es habitual pedir "escríbeme una política que permita solo…".

## Costo esperado

> 💰 **0 USD.** IAM es gratis.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida en CloudShell, como `eduardo`; no pases a la siguiente sin haber hecho la anterior.

El escenario: "Ana", una compañera, solo debe poder **leer los informes** de Vigía en S3. El bucket todavía no existe, pero a IAM no le importa: las políticas hablan de ARN, no de recursos que existan.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto, la limpieza y el cierre. CloudShell conserva tus archivos, pero no las variables: cada día, empieza por el bloque de abajo.

```bash
mkdir -p ~/clase-69 && cd ~/clase-69
CUENTA=$(aws sts get-caller-identity --query Account --output text)
B=vigia-informes-$CUENTA
ANA=arn:aws:iam::$CUENTA:user/ana-pruebas
echo "$CUENTA $B"
```

## Las piezas

### Pieza 1 — Quién eres y qué piezas tiene IAM

- **Autenticación:** ¿quién eres? Contraseña y MFA en la consola, credenciales temporales en la CLI.
- **Autorización:** ¿puedes hacer **esto**? La deciden las **políticas**.

Una petición a AWS lleva siempre estas piezas: un **principal** (tu usuario, un rol o un servicio); una **acción** (`s3:GetObject`, `ec2:RunInstances`…); un **recurso** (un ARN); y un **contexto** (tu IP, la hora, si usaste MFA…).

| Pieza | Qué es | Equivalente en Linux |
|-------|--------|----------------------|
| **Usuario** | una persona (o, mal hecho, una aplicación) con credenciales permanentes | un usuario de `/etc/passwd` |
| **Grupo** | un conjunto de usuarios que comparten permisos | un grupo de `/etc/group` |
| **Rol** | una identidad **sin credenciales propias** que alguien o algo *asume* y recibe credenciales temporales (clase 70) | algo como `sudo -u`, pero con caducidad |
| **Política** | un documento JSON que permite o deniega acciones | los bits `rwx`, pero mucho más finos |

Todo en AWS se identifica con un **ARN**:

```
arn:aws:iam::123456789012:user/eduardo
arn:aws:s3:::vigia-informes-123456789012              ← un bucket (S3 no lleva región ni cuenta)
arn:aws:s3:::vigia-informes-123456789012/reports/*    ← los objetos bajo reports/
arn:aws:ec2:us-east-1:123456789012:instance/i-0abc…
 └─┘ └──┘ └─┘ └───────┘ └──────────┘ └───────────┘
  │   │    │     │          │          └─ recurso
  │   │    │     │          └─ cuenta
  │   │    │     └─ región
  │   │    └─ servicio
  │   └─ partición
  └─ siempre "arn"
```

**Pruébalo:**

```bash
aws iam get-user --query 'User.[UserName,Arn,CreateDate]' --output text
aws iam list-groups-for-user --user-name eduardo --query 'Groups[].GroupName' --output text
aws iam list-attached-group-policies --group-name administradores --output table
```

👀 **Qué deberías ver:** `eduardo`, su ARN (`arn:aws:iam::<tu cuenta>:user/eduardo`, sin región: IAM es global) y la fecha de creación; el grupo `administradores`; y una tabla con la política `AdministratorAccess` y su ARN, `arn:aws:iam::aws:policy/AdministratorAccess` (con `aws` en lugar de un número de cuenta: es de AWS).

✋ **Sin mirar:** en `arn:aws:s3:::mi-bucket`, ¿por qué no hay región ni cuenta?

<details>
<summary>Comprueba</summary>

Porque el nombre de un bucket de S3 es único en todo el mundo: no hace falta la región ni la cuenta para identificarlo.
</details>

**En resumen:** IAM autoriza a un principal una acción sobre un recurso (un ARN); los permisos viven en políticas.

### Pieza 2 — Una política por dentro

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LeerInformes",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::vigia-informes-123456789012/reports/*"
    }
  ]
}
```

| Campo | Qué es |
|-------|--------|
| `Version` | la versión **del lenguaje de políticas**. Siempre `"2012-10-17"`: no es la fecha de hoy y no se cambia |
| `Statement` | una lista de declaraciones |
| `Sid` | un nombre opcional para la declaración |
| `Effect` | `Allow` o `Deny` |
| `Action` | una acción o una lista, con comodines: `s3:Get*`, `ec2:Describe*` |
| `Resource` | uno o varios ARN, con comodines |
| `Condition` | opcional: cuándo aplica. Por ejemplo, `{"Bool": {"aws:MultiFactorAuthPresent": "true"}}` o `{"IpAddress": {"aws:SourceIp": "203.0.113.7/32"}}` |

⚠️ **La trampa de S3 más común del mundo.** `s3:ListBucket` actúa sobre el **bucket** (`arn:aws:s3:::nombre`), y `s3:GetObject` sobre los **objetos** (`arn:aws:s3:::nombre/*`). Si te equivocas de ARN, la política "no funciona" y no da ningún error: simplemente no permite nada (Rómpelo 2).

**IAM Access Analyzer** revisa una política antes de crearla: gramática, acciones que no existen y malas prácticas. Es gratis.

🔮 **Predice:** ¿cuántas declaraciones tiene `AdministratorAccess`, la política más poderosa de AWS?

**Pruébalo.** Primero, lee esa política; después, escribe la de Ana y valídala:

```bash
ARN=arn:aws:iam::aws:policy/AdministratorAccess
V=$(aws iam get-policy --policy-arn "$ARN" --query Policy.DefaultVersionId --output text)
aws iam get-policy-version --policy-arn "$ARN" --version-id "$V" --query PolicyVersion.Document
cat > leer-informes.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListarElBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::$B"
    },
    {
      "Sid": "LeerInformes",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$B/reports/*"
    }
  ]
}
EOF
cat leer-informes.json
aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY \
  --policy-document file://leer-informes.json --query findings
```

👀 **Qué deberías ver:** `AdministratorAccess` tiene **una** sola declaración: `"Effect": "Allow"`, `"Action": "*"`, `"Resource": "*"`. Todo, sobre todo. Después, la política de Ana con el nombre real de tu bucket en los dos ARN (el *heredoc* sin comillas sustituyó `$B`), y `[]`: Access Analyzer no encuentra nada que corregir.

✋ **Sin mirar:** ¿qué ARN necesita `s3:ListBucket` y cuál `s3:GetObject`?

<details>
<summary>Comprueba</summary>

`ListBucket`, el del bucket (`arn:aws:s3:::nombre`); `GetObject`, el de los objetos (`arn:aws:s3:::nombre/*` o un prefijo como `/reports/*`).
</details>

**En resumen:** `Version` fija, y en cada declaración `Effect`, `Action`, `Resource` (y `Condition`); valida con Access Analyzer antes de crear.

### Pieza 3 — Quién mantiene la política, y los grupos

| Tipo | Quién la mantiene | Cuándo usarla |
|------|-------------------|---------------|
| **Administrada por AWS** (`AdministratorAccess`, `ReadOnlyAccess`…) | AWS, que la actualiza cuando salen servicios nuevos | para empezar, o para roles muy generales |
| **Administrada por ti** (*customer managed*) | tú; tiene versiones (hasta 5) y se reutiliza | **lo normal**: permisos a medida |
| ***Inline*** | va incrustada en **un** usuario, grupo o rol, y se borra con él | casos de uno solo, como una excepción (pieza 5) |

Los permisos se dan a **grupos** y los usuarios entran y salen de ellos. Cuando alguien cambia de equipo, lo cambias de grupo, no revisas sus veinte políticas.

**Pruébalo:**

```bash
aws iam create-policy --policy-name leer-informes-vigia \
  --policy-document file://leer-informes.json \
  --tags Key=Proyecto,Value=lab --query Policy.Arn --output text
aws iam create-group --group-name lectores-vigia
aws iam attach-group-policy --group-name lectores-vigia \
  --policy-arn "arn:aws:iam::$CUENTA:policy/leer-informes-vigia"
aws iam create-user --user-name ana-pruebas --tags Key=Proyecto,Value=lab
aws iam add-user-to-group --user-name ana-pruebas --group-name lectores-vigia
aws iam list-groups-for-user --user-name ana-pruebas --query 'Groups[].GroupName' --output text
```

👀 **Qué deberías ver:** el ARN de tu política (`arn:aws:iam::<tu cuenta>:policy/leer-informes-vigia`: tuya, con tu número de cuenta), un JSON con el grupo, otro con el usuario y, al final, `lectores-vigia`. `ana-pruebas` no tiene contraseña ni llaves: nadie puede entrar con ella. Para probar sus permisos no hace falta: para eso está el simulador.

✋ **Sin mirar:** Ana se cambia al equipo de bases de datos. ¿Qué haces con sus permisos?

<details>
<summary>Comprueba</summary>

Sacarla de `lectores-vigia` y meterla en el grupo de ese equipo. No tocas ninguna política.
</details>

**En resumen:** políticas tuyas, reutilizables, enganchadas a grupos; los usuarios entran y salen de los grupos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, en CloudShell, el bloque de variables de "Cómo va esta clase".

### Pieza 4 — Cómo decide IAM, y el simulador

```
¿Hay algún Deny explícito que encaje?  ── sí ──►  DENEGADO (explicitDeny)
               │ no
               ▼
¿Hay algún Allow que encaje?           ── no ──►  DENEGADO (implicitDeny: lo que no se permite, se deniega)
               │ sí
               ▼
           PERMITIDO (allowed)
```

Tres reglas: 1) **todo empieza denegado**; 2) un **Allow** lo permite; 3) un **Deny** explícito gana **siempre**, aunque haya cien Allow. Por eso, para bloquear algo con seguridad, se usa un `Deny`.

Hay otros tipos de políticas, que en el examen basta con reconocer: las **políticas de recurso**, que se ponen en el propio recurso, como la *bucket policy* de S3 (clase 74); los **límites de permisos** (*permission boundaries*), el máximo que puede tener un usuario o un rol; y las **SCP** de AWS Organizations, el máximo para cuentas enteras.

El **simulador de políticas** dice qué decidiría IAM ante una petición, sin hacerla. Evalúa todas las políticas que afectan al usuario, también las de sus grupos.

🔮 **Predice** las tres decisiones del primer comando, y si Ana puede leer `config.yaml` del mismo bucket.

**Pruébalo:**

```bash
aws iam simulate-principal-policy --policy-source-arn "$ANA" \
  --action-names s3:GetObject s3:PutObject s3:DeleteObject \
  --resource-arns "arn:aws:s3:::$B/reports/2026-10-20.json" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table
aws iam simulate-principal-policy --policy-source-arn "$ANA" \
  --action-names s3:ListBucket --resource-arns "arn:aws:s3:::$B" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output text
aws iam simulate-principal-policy --policy-source-arn "$ANA" \
  --action-names s3:GetObject --resource-arns "arn:aws:s3:::otro-bucket/informe.json" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output text
aws iam simulate-principal-policy --policy-source-arn "$ANA" \
  --action-names s3:GetObject --resource-arns "arn:aws:s3:::$B/config.yaml" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output text
```

👀 **Qué deberías ver:** en la tabla, `s3:GetObject allowed`, y `s3:PutObject` y `s3:DeleteObject` con `implicitDeny`: nadie las permitió. Después, `s3:ListBucket allowed` sobre el bucket; `implicitDeny` para `otro-bucket`; e `implicitDeny` para `config.yaml`: Ana solo lee lo que está bajo `reports/`. Eso es mínimo privilegio. Y el permiso viene del **grupo**.

✋ **Sin mirar:** ¿qué decide IAM ante una acción que ninguna política menciona?

<details>
<summary>Comprueba</summary>

`implicitDeny`: todo empieza denegado, y nadie la permitió.
</details>

**En resumen:** Deny explícito → denegado; si no, Allow → permitido; si no, denegado. El simulador lo comprueba sin hacer la petición.

### Pieza 5 — Una denegación explícita, con una política *inline*

Los informes de `reports/privado/` no debe leerlos nadie del grupo. Una excepción para una sola persona es el caso de una política ***inline***: va incrustada en ese usuario y se borra con él.

🔮 **Predice:** `reports/*` también incluye `reports/privado/sueldos.json`, así que el `Allow` del grupo encaja. ¿Qué decidirá IAM?

**Pruébalo:**

```bash
cat > denegar-privado.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$B/reports/privado/*"
    }
  ]
}
EOF
aws iam put-user-policy --user-name ana-pruebas --policy-name denegar-privado \
  --policy-document file://denegar-privado.json
aws iam simulate-principal-policy --policy-source-arn "$ANA" --action-names s3:GetObject \
  --resource-arns "arn:aws:s3:::$B/reports/privado/sueldos.json" "arn:aws:s3:::$B/reports/2026-10-20.json" \
  --query 'EvaluationResults[].[EvalResourceName,EvalDecision]' --output table
```

👀 **Qué deberías ver:** `explicitDeny` para `reports/privado/sueldos.json` y `allowed` para `reports/2026-10-20.json`. El `Deny` gana siempre, aunque el `Allow` del grupo también encaje.

✋ **Sin mirar:** ¿por qué aquí una *inline* y no una política administrada?

<details>
<summary>Comprueba</summary>

Porque es una excepción para una sola persona: no se va a reutilizar, y si borras a Ana, la excepción desaparece con ella.
</details>

**En resumen:** un `Deny` explícito corta lo que un `Allow` más amplio permitía; para excepciones de uno, *inline*.

### Pieza 6 — Mínimo privilegio y el informe de credenciales

**Mínimo privilegio:** cada identidad tiene solo los permisos que necesita para su trabajo, y ninguno más. Se llega así:
1. empieza con menos de lo que crees necesario;
2. añade permisos cuando algo falle con `AccessDenied`;
3. revisa de vez en cuando qué servicios usa de verdad: en IAM, la pestaña *Last accessed* de cada usuario o rol.

El **informe de credenciales** es el "¿quién tiene qué?" de la cuenta, y lo primero que mira una auditoría: cada usuario con su contraseña, su MFA y sus llaves.

🔮 **Predice** la fila de `<root_account>` (MFA y llave de acceso), la de `eduardo` y la de `ana-pruebas`.

**Pruébalo:**

```bash
until aws iam generate-credential-report --query State --output text | grep -q COMPLETE; do sleep 2; done
aws iam get-credential-report --query Content --output text | base64 -d | cut -d, -f1,4,8,9 | tr ',' '\t'
```

👀 **Qué deberías ver:** cuatro columnas (usuario, contraseña activa, MFA activo y llave de acceso 1 activa). `<root_account>`: MFA `true` y llave `false`. `eduardo`: contraseña y MFA `true`. `ana-pruebas`: todo `false`. Si algún día ves `true` en la llave del raíz, es una alarma.

✋ **Sin mirar:** ¿dónde miras qué servicios ha usado de verdad un usuario, para recortarle permisos?

<details>
<summary>Comprueba</summary>

En IAM, en la pestaña *Last accessed* del usuario (o del rol).
</details>

**En resumen:** empieza con poco, añade cuando haga falta, revisa *Last accessed*; el informe de credenciales dice quién tiene qué.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws iam get-user` · `list-groups-for-user` · `list-attached-group-policies` | quién eres y qué tienes |
| `aws iam get-policy-version --policy-arn … --version-id …` | leer una política |
| `aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY --policy-document file://p.json` | validar antes de crear |
| `aws iam create-policy` · `create-group` · `attach-group-policy` · `add-user-to-group` | crear y enganchar |
| `aws iam put-user-policy` | una política *inline* |
| `aws iam simulate-principal-policy --policy-source-arn … --action-names … --resource-arns …` | qué decidiría IAM para un usuario |
| `aws iam simulate-custom-policy --policy-input-list file://p.json …` | probar un JSON sin crearlo |
| `aws iam generate-credential-report` · `get-credential-report` | quién tiene contraseña, MFA y llaves |
| Deny explícito > Allow > denegado por defecto | cómo decide IAM |

## Rómpelo

**1. Una errata que no da error.** Prueba una política sin crearla con `simulate-custom-policy`, que recibe el JSON directamente:

```bash
sed 's/s3:GetObject/s3:GetObjects/' leer-informes.json > errata.json
aws iam simulate-custom-policy --policy-input-list file://errata.json \
  --action-names s3:GetObject --resource-arns "arn:aws:s3:::$B/reports/a.json" \
  --query 'EvaluationResults[].EvalDecision' --output text
aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY \
  --policy-document file://errata.json --query 'findings[].[findingType,issueCode]' --output text
```

¿Qué pasa con la errata?
- **El simulador:** `implicitDeny`, porque la acción con errata no encaja con ninguna real.
- **Access Analyzer:** `ERROR INVALID_ACTION`, y en `findingDetails` te sugiere la acción buena.

El JSON es correcto, así que nada se queja hasta que alguien no puede trabajar. Valida siempre antes de crear.

**2. El bucket sin `/*`:**

```bash
sed "s|$B/reports/\*|$B|" leer-informes.json > sin-barra.json
grep Resource sin-barra.json
aws iam simulate-custom-policy --policy-input-list file://sin-barra.json \
  --action-names s3:GetObject --resource-arns "arn:aws:s3:::$B/reports/a.json" \
  --query 'EvaluationResults[].EvalDecision' --output text
```

Ahora ese `Allow` de `GetObject` apunta al **bucket**, y la petición es sobre un **objeto**: `implicitDeny`. Es la trampa de la pieza 2, en vivo.

**3. Fuera del grupo:**

```bash
aws iam remove-user-from-group --user-name ana-pruebas --group-name lectores-vigia
aws iam simulate-principal-policy --policy-source-arn "$ANA" --action-names s3:GetObject \
  --resource-arns "arn:aws:s3:::$B/reports/a.json" --query 'EvaluationResults[].EvalDecision' --output text
aws iam add-user-to-group --user-name ana-pruebas --group-name lectores-vigia
```

Sin grupo, no tiene permisos. Así se quitan los accesos cuando alguien cambia de equipo.

**4. Borrar en el orden equivocado:**

```bash
aws iam delete-user --user-name ana-pruebas
```

`DeleteConflict`: IAM no borra un usuario que todavía tiene políticas o grupos. El orden correcto está en "Destruir al terminar".

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escribe `con-mfa.json`: una política que permita `s3:GetObject` en `reports/*` solo si la sesión usó MFA. Pruébala con el simulador, sin contexto y con él.

> 🧩 **Ejemplo resuelto:** la fila `Condition` de la tabla de la pieza 2 y el `simulate-custom-policy` del Rómpelo 1.

**Ahora tú, con huecos:**
```bash
cat > con-mfa.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$B/reports/*",
    "Condition": {"____": {"aws:MultiFactorAuthPresent": "____"}}
  }]
}
EOF
aws iam simulate-custom-policy --policy-input-list file://con-mfa.json \
  --action-names s3:GetObject --resource-arns "arn:aws:s3:::$B/reports/a.json" \
  --query 'EvaluationResults[].EvalDecision' --output text
aws iam simulate-custom-policy --policy-input-list file://con-mfa.json \
  --action-names s3:GetObject --resource-arns "arn:aws:s3:::$B/reports/a.json" \
  --context-entries ContextKeyName=aws:MultiFactorAuthPresent,ContextKeyValues=true,ContextKeyType=boolean \
  --query 'EvaluationResults[].EvalDecision' --output text
```
Completa: «Sin contexto: ____. Con MFA: ____».

<details>
<summary>Pista</summary>

El operador para comparar un verdadero o falso se llama `Bool`, y el valor va entre comillas, como texto.
</details>

**2.** Mira qué servicios has usado hasta hoy y cómo usarías esa información para recortar permisos a alguien.

> 🧩 **Ejemplo resuelto:** el paso 3 del mínimo privilegio, en la pieza 6: revisar *Last accessed*.

**Ahora tú, con huecos:** en la consola, **IAM → Users → eduardo → Last accessed**. Completa: «He usado ____, ____ y ____. A otra persona le quitaría los permisos de los servicios que ____».

<details>
<summary>Pista</summary>

Ordena la lista por la columna de último acceso: lo que dice *Not accessed* en mucho tiempo es candidato a desaparecer.
</details>

**3.** Lee la política administrada `ReadOnlyAccess`. ¿Por qué no sirve como mínimo privilegio para Ana, aunque "solo sea lectura"?

> 🧩 **Ejemplo resuelto:** la pieza 2: leíste `AdministratorAccess` con `get-policy` y `get-policy-version`.

**Ahora tú, con huecos:**
```bash
ARN=arn:aws:iam::aws:policy/____
V=$(aws iam get-policy --policy-arn "$ARN" --query Policy.DefaultVersionId --output text)
aws iam get-policy-version --policy-arn "$ARN" --version-id "$V" --query PolicyVersion.Document | head -30
```
Completa: «Permite acciones como ____ en ____ los servicios. Para Ana no es mínimo privilegio porque…».

<details>
<summary>Pista</summary>

Fíjate en el `Resource` de sus declaraciones y en cuántos servicios distintos aparecen en `Action`. Leer los datos equivocados también es una fuga.
</details>

## Destruir al terminar

En este orden: primero lo que cuelga del usuario, después el usuario, después el grupo y por último la política.

```bash
aws iam delete-user-policy --user-name ana-pruebas --policy-name denegar-privado
aws iam remove-user-from-group --user-name ana-pruebas --group-name lectores-vigia
aws iam delete-user --user-name ana-pruebas
aws iam detach-group-policy --group-name lectores-vigia --policy-arn "arn:aws:iam::$CUENTA:policy/leer-informes-vigia"
aws iam delete-group --group-name lectores-vigia
aws iam delete-policy --policy-arn "arn:aws:iam::$CUENTA:policy/leer-informes-vigia"
aws iam list-policies --scope Local --query 'Policies[].PolicyName' --output text
```

La última orden lista tus políticas propias: no debe quedar ninguna. Los JSON de `~/clase-69` puedes guardarlos: no son secretos.

## Cierre

En `notas/fase-6/clase-69.md`:

1. Hay un `Allow` en la política del grupo y un `Deny` en una *inline* del usuario, para la misma acción y el mismo recurso. ¿Qué decide IAM y por qué? *(1–2 líneas. Empieza así: «Lo deniega (`explicitDeny`), porque un Deny explícito…»)*
2. ¿Por qué `s3:GetObject` sobre `arn:aws:s3:::mi-bucket` no permite leer ningún archivo? *(2 líneas. Empieza así: «Porque `GetObject` actúa sobre objetos, cuyo ARN es… Hace falta…»)*
3. ¿Por qué se asignan los permisos a grupos y no directamente a los usuarios? *(2 líneas. Empieza así: «Porque las personas cambian de funciones… Con grupos, dar o quitar acceso es…»)*
4. **Repaso (clase 68, sin mirar):** ¿qué diferencia hay entre el nombre de una zona de disponibilidad (`us-east-1a`) y su ID (`use1-az6`)? *(1–2 líneas. Empieza así: «El nombre se asigna al azar en cada cuenta, así que…; el ID…»)*

Después, escríbeme `examíname clase-69`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Lo deniega (`explicitDeny`). Un `Deny` explícito gana siempre, venga de donde venga, aunque haya cualquier número de `Allow`.

**2.** Porque `GetObject` actúa sobre **objetos**, cuyo ARN es `arn:aws:s3:::mi-bucket/clave`. Con el ARN del bucket, el `Allow` no encaja con ninguna petición de lectura y todo queda en `implicitDeny`. Hace falta `arn:aws:s3:::mi-bucket/*` (o un prefijo, como `/reports/*`).

**3.** Porque las personas cambian de funciones y los permisos se quedan. Con grupos, los permisos de un puesto se definen una vez. Dar o quitar acceso es mover a la persona de grupo, y auditar es mirar unos pocos grupos en lugar de cada usuario.

**4.** El nombre se asigna al azar en cada cuenta, así que tu `us-east-1a` puede ser otra zona física que la `us-east-1a` de otra cuenta. El ID identifica la misma zona física para todas las cuentas.

**Reto 1:** `"Condition": {"Bool": {"aws:MultiFactorAuthPresent": "true"}}`. Sin contexto: `implicitDeny`. Con `aws:MultiFactorAuthPresent=true`: `allowed`.

**Reto 2:** respuesta personal; lo normal hasta hoy es IAM, Billing, Budgets, Cost Explorer, CloudShell, EC2 (las consultas de la clase 68) y CloudWatch Logs.

**Reto 3:** `ReadOnlyAccess`. Deja leer **casi todo** (`Describe*`, `Get*`, `List*`…) en **todos** los servicios y sobre todos los recursos (`"Resource": "*"`): otros buckets, la configuración de las instancias, los parámetros… "Solo lectura" no es "solo lo necesario". Leer los datos equivocados también es una fuga.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| principal | quien hace la petición (usuario, rol o servicio) |
| policy / statement | política / declaración |
| implicit deny / explicit deny | denegación implícita / explícita |
| least privilege | mínimo privilegio |
| managed policy / inline policy | política administrada / incrustada |
| policy simulator | simulador de políticas |

🎙️ *"In IAM everything starts denied, an Allow grants access, and an explicit Deny always wins. I write customer-managed policies scoped to exact ARNs, attach them to groups, and validate them with Access Analyzer and the policy simulator before anyone uses them."*

## Siguiente

[Clase 70 — IAM II: roles y la AWS CLI sin llaves](clase-70-iam-roles-y-cli.md)
