# Clase 69 — IAM I: usuarios, grupos y políticas

**Dónde:** navegador (consola y CloudShell) · **Tiempo:** 90 min · **Bloque:** A. Cuenta, costos e identidad

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

## Teoría

### Autenticación y autorización

- **Autenticación:** ¿quién eres? Contraseña y MFA en la consola, credenciales temporales en la CLI.
- **Autorización:** ¿puedes hacer **esto**? La deciden las **políticas**.

Una petición a AWS lleva siempre estas piezas:
- un **principal**: tu usuario, un rol o un servicio;
- una **acción**: `s3:GetObject`, `ec2:RunInstances`…
- un **recurso**: un ARN;
- un **contexto**: tu IP, la hora, si usaste MFA…

### Las piezas de IAM

| Pieza | Qué es | Equivalente en Linux |
|-------|--------|----------------------|
| **Usuario** | una persona (o, mal hecho, una aplicación) con credenciales permanentes | un usuario de `/etc/passwd` |
| **Grupo** | un conjunto de usuarios que comparten permisos | un grupo de `/etc/group` |
| **Rol** | una identidad **sin credenciales propias** que alguien o algo *asume* y recibe credenciales temporales (clase 70) | algo como `sudo -u`, pero con caducidad |
| **Política** | un documento JSON que permite o deniega acciones | los bits `rwx`, pero mucho más finos |

Todo en AWS se identifica con un **ARN** (*Amazon Resource Name*):

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

### Una política por dentro

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

### Cómo decide IAM

```
¿Hay algún Deny explícito que encaje?  ── sí ──►  DENEGADO (explicitDeny)
               │ no
               ▼
¿Hay algún Allow que encaje?           ── no ──►  DENEGADO (implicitDeny: lo que no se permite, se deniega)
               │ sí
               ▼
           PERMITIDO (allowed)
```

Tres reglas:
1. **Todo empieza denegado.**
2. Un **Allow** lo permite.
3. Un **Deny** explícito gana **siempre**, aunque haya cien Allow.

Por eso, para bloquear algo con seguridad, se usa un `Deny`.

Hay otros tipos de políticas, que en el examen basta con reconocer:
- **políticas de recurso**: las que se ponen en el propio recurso, como la *bucket policy* de S3 (clase 74);
- **límites de permisos** (*permission boundaries*): el máximo que puede tener un usuario o un rol;
- **SCP** de AWS Organizations: el máximo para cuentas enteras.

### Quién mantiene la política

| Tipo | Quién la mantiene | Cuándo usarla |
|------|-------------------|---------------|
| **Administrada por AWS** (`AdministratorAccess`, `ReadOnlyAccess`…) | AWS, que la actualiza cuando salen servicios nuevos | para empezar, o para roles muy generales |
| **Administrada por ti** (*customer managed*) | tú; tiene versiones (hasta 5) y se reutiliza | **lo normal**: permisos a medida |
| ***Inline*** | va incrustada en **un** usuario, grupo o rol, y se borra con él | casos de uno solo, como una excepción (Rómpelo 5) |

Los permisos se dan a **grupos** y los usuarios entran y salen de ellos. Cuando alguien cambia de equipo, lo cambias de grupo, no revisas sus veinte políticas.

### Mínimo privilegio

**Mínimo privilegio:** cada identidad tiene solo los permisos que necesita para su trabajo, y ninguno más. Se llega así:
1. empieza con menos de lo que crees necesario;
2. añade permisos cuando algo falle con `AccessDenied`;
3. revisa de vez en cuando qué servicios usa de verdad: en IAM, la pestaña *Last accessed* de cada usuario o rol.

Dos herramientas gratuitas para no aprender a base de errores en producción:
- el **simulador de políticas** dice qué decidiría IAM ante una petición, sin hacerla;
- **IAM Access Analyzer** revisa una política antes de crearla: gramática, acciones que no existen y malas prácticas.

## Práctica guiada

Todo en **CloudShell**, como `eduardo`. El escenario: "Ana", una compañera, solo debe poder **leer los informes** de Vigía en S3. El bucket todavía no existe, pero a IAM no le importa: las políticas hablan de ARN, no de recursos que existan.

```bash
mkdir -p ~/clase-69 && cd ~/clase-69
CUENTA=$(aws sts get-caller-identity --query Account --output text)
B=vigia-informes-$CUENTA
echo "$CUENTA $B"
```

### 1. Tú, visto por IAM (10 min)

```bash
aws iam get-user --query 'User.[UserName,Arn,CreateDate]' --output text
aws iam list-groups-for-user --user-name eduardo --query 'Groups[].GroupName' --output text
aws iam list-attached-group-policies --group-name administradores --output table
```

Lee la política que te hace administrador:

```bash
ARN=arn:aws:iam::aws:policy/AdministratorAccess
V=$(aws iam get-policy --policy-arn "$ARN" --query Policy.DefaultVersionId --output text)
aws iam get-policy-version --policy-arn "$ARN" --version-id "$V" --query PolicyVersion.Document
```

🔮 **Predice:** ¿cuántas declaraciones tiene la política más poderosa de AWS? Una: `Allow`, `Action: "*"`, `Resource: "*"`. Todo, sobre todo.

### 2. Una política a medida (15 min)

```bash
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
```

Antes de crearla, pásale Access Analyzer:

```bash
aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY \
  --policy-document file://leer-informes.json --query findings
```

`[]`: ningún hallazgo. Créala, con la etiqueta del curso:

```bash
aws iam create-policy --policy-name leer-informes-vigia \
  --policy-document file://leer-informes.json \
  --tags Key=Proyecto,Value=lab --query Policy.Arn --output text
```

### 3. Un grupo y un usuario sin credenciales (10 min)

```bash
aws iam create-group --group-name lectores-vigia
aws iam attach-group-policy --group-name lectores-vigia \
  --policy-arn "arn:aws:iam::$CUENTA:policy/leer-informes-vigia"
aws iam create-user --user-name ana-pruebas --tags Key=Proyecto,Value=lab
aws iam add-user-to-group --user-name ana-pruebas --group-name lectores-vigia
```

`ana-pruebas` no tiene contraseña ni llaves: nadie puede entrar con ella. Para probar permisos no hace falta: para eso está el simulador.

### 4. El simulador de políticas (15 min)

```bash
ANA=arn:aws:iam::$CUENTA:user/ana-pruebas
aws iam simulate-principal-policy --policy-source-arn "$ANA" \
  --action-names s3:GetObject s3:PutObject s3:DeleteObject \
  --resource-arns "arn:aws:s3:::$B/reports/2026-10-20.json" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table
```

🔮 **Predice** las tres decisiones antes de ejecutarlo. `GetObject` → `allowed`. `PutObject` y `DeleteObject` → `implicitDeny`: nadie las permitió.

Ahora otras peticiones:

```bash
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

🔮 **Predice:** ¿puede Ana leer `config.yaml` del mismo bucket? No: solo lo que está bajo `reports/`. Eso es mínimo privilegio. Y el permiso viene del **grupo**: el simulador evalúa todas las políticas que afectan al usuario, también las de sus grupos.

### 5. Una denegación explícita (10 min)

Los informes de `reports/privado/` no debe leerlos nadie del grupo. Una excepción para una sola persona es el caso de una política ***inline***:

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

`reports/*` también incluye `reports/privado/sueldos.json`, así que el `Allow` del grupo encaja. Aun así, el resultado es `explicitDeny`: el `Deny` gana siempre.

### 6. El informe de credenciales (10 min)

Es el "¿quién tiene qué?" de la cuenta, y lo primero que mira una auditoría:

```bash
until aws iam generate-credential-report --query State --output text | grep -q COMPLETE; do sleep 2; done
aws iam get-credential-report --query Content --output text | base64 -d | cut -d, -f1,4,8,9 | tr ',' '\t'
```

Las columnas son: usuario, contraseña activa, MFA activo y llave de acceso 1 activa.

🔮 **Predice** la fila de `<root_account>`:
- MFA activo: `true`;
- llave de acceso: `false`.

Y las otras:
- `eduardo`: contraseña y MFA;
- `ana-pruebas`: nada.

Si algún día ves `true` en la llave del raíz, es una alarma.

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

Ahora ese `Allow` de `GetObject` apunta al **bucket**, y la petición es sobre un **objeto**: `implicitDeny`. Es la trampa de la teoría, en vivo.

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

1. **Solo con MFA.** Escribe `con-mfa.json`: una política que permita `s3:GetObject` en `reports/*` solo si la sesión usó MFA (condición `Bool` sobre `aws:MultiFactorAuthPresent`). Pruébala con `simulate-custom-policy`, una vez sin contexto y otra con:

   ```bash
   --context-entries ContextKeyName=aws:MultiFactorAuthPresent,ContextKeyValues=true,ContextKeyType=boolean
   ```
2. En la consola, **IAM → Users → eduardo → Last accessed**: ¿qué servicios has usado hasta hoy? ¿Cómo usarías esta información para recortar permisos a alguien?
3. Lee la política administrada `ReadOnlyAccess`. ¿Por qué no sirve como mínimo privilegio para Ana, aunque "solo sea lectura"?

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

1. Hay un `Allow` en la política del grupo y un `Deny` en una *inline* del usuario, para la misma acción y el mismo recurso. ¿Qué decide IAM y por qué?
2. ¿Por qué `s3:GetObject` sobre `arn:aws:s3:::mi-bucket` no permite leer ningún archivo?
3. ¿Por qué se asignan los permisos a grupos y no directamente a los usuarios?
4. **Repaso (clase 68, sin mirar):** ¿qué diferencia hay entre el nombre de una zona de disponibilidad (`us-east-1a`) y su ID (`use1-az6`)?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Lo deniega (`explicitDeny`). Un `Deny` explícito gana siempre, venga de donde venga, aunque haya cualquier número de `Allow`.

**2.** Porque `GetObject` actúa sobre **objetos**, cuyo ARN es `arn:aws:s3:::mi-bucket/clave`. Con el ARN del bucket, el `Allow` no encaja con ninguna petición de lectura y todo queda en `implicitDeny`. Hace falta `arn:aws:s3:::mi-bucket/*` (o un prefijo, como `/reports/*`).

**3.** Porque las personas cambian de funciones y los permisos se quedan. Con grupos, los permisos de un puesto se definen una vez. Dar o quitar acceso es mover a la persona de grupo, y auditar es mirar unos pocos grupos en lugar de cada usuario.

**4.** El nombre se asigna al azar en cada cuenta, así que tu `us-east-1a` puede ser otra zona física que la `us-east-1a` de otra cuenta. El ID identifica la misma zona física para todas las cuentas.

**Reto 1:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::vigia-informes-123456789012/reports/*",
    "Condition": {"Bool": {"aws:MultiFactorAuthPresent": "true"}}
  }]
}
```
Sin contexto: `implicitDeny`. Con `aws:MultiFactorAuthPresent=true`: `allowed`.

**Reto 3:** `ReadOnlyAccess` deja leer **casi todo** en **todos** los servicios: otros buckets, la configuración de las instancias, los parámetros… "Solo lectura" no es "solo lo necesario". Leer los datos equivocados también es una fuga.
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
