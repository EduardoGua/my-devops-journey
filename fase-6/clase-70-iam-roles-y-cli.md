# Clase 70 — IAM II: roles y la AWS CLI sin llaves

**Dónde:** tu Ubuntu + navegador · **Tiempo:** 90 min · **Bloque:** A. Cuenta, costos e identidad

## Objetivo

- Entender qué es un **rol**: una identidad sin credenciales propias que alguien *asume* para recibir credenciales **temporales**.
- Leer las dos políticas de un rol: la de **confianza** (quién puede asumirlo) y la de **permisos** (qué puede hacer).
- Instalar la **AWS CLI v2** en tu Ubuntu con el instalador oficial y entrar con **`aws login`**, sin ninguna llave guardada.
- Asumir un rol desde la CLI, usar sus credenciales y ver que caducan.
- Conocer el orden en que la CLI busca credenciales, y qué es **IAM Identity Center**.

## Por qué importa

Las llaves de acceso permanentes son la causa más común de incidentes en AWS. La alternativa son las credenciales temporales, y su mecanismo, los roles, aparecerá en todo lo que viene:
- la EC2 de Vigía leerá ECR y escribirá en S3 con un rol (clases 72 y 78);
- GitHub Actions desplegará con un rol y OIDC, sin secretos guardados (clase 86);
- en Kubernetes, los pods de EKS reciben roles igual (fase 9).

Hoy entiendes el modelo que se repite en las fases 7 a 9, y dejas tu portátil sin un solo secreto de AWS en disco.

## Costo esperado

> 💰 **0 USD.** IAM y STS son gratis.

## Teoría

### Un rol: dos políticas

Un usuario tiene credenciales permanentes. Un rol no tiene ninguna: quien lo **asume** recibe del servicio **STS** (*Security Token Service*) unas credenciales temporales, que caducan solas.

```
quien asume ──► sts:AssumeRole ──► ¿la política de CONFIANZA del rol lo permite?
(usuario, EC2,                              │ sí
 GitHub Actions…)                           ▼
                        credenciales temporales: AccessKeyId (ASIA…), SecretAccessKey,
                        SessionToken y Expiration (de 15 min a 12 h)
                                            │
                                            ▼
                        cada petición se evalúa con la política de PERMISOS del rol
```

| Política | Pregunta que responde | Ejemplo de `Principal` |
|----------|----------------------|------------------------|
| **De confianza** (*trust policy*) | ¿quién puede asumir este rol? | `{"Service": "ec2.amazonaws.com"}` para una EC2 · `{"AWS": "arn:aws:iam::123456789012:root"}` para identidades de tu cuenta · `{"Federated": "token.actions.githubusercontent.com"}` para GitHub Actions |
| **De permisos** | ¿qué puede hacer quien lo asume? | las de la clase 69 |

Detalle que confunde a todos: en una política de confianza, `arn:aws:iam::123456789012:root` **no** es el usuario raíz. Significa "la cuenta 123456789012": cualquier identidad de esa cuenta a la que **su propia** política de IAM le permita `sts:AssumeRole` sobre este rol.

Para reconocer credenciales a simple vista: las llaves que empiezan por `AKIA` son **permanentes** (de un usuario); las que empiezan por `ASIA` son **temporales** (de STS). Si encuentras un `AKIA…` en un repositorio, es una emergencia. Un `ASIA…` caducado ya no sirve para nada.

Los usos típicos de un rol:
- **roles de servicio**: una EC2 o una Lambda que actúa en tu nombre;
- **roles entre cuentas**: de la cuenta de desarrollo a la de producción;
- **federación**: identidades de fuera (la empresa, GitHub) que reciben un rol.

Para que una EC2 use un rol, el rol va dentro de un **perfil de instancia** (*instance profile*): lo verás en la clase 72.

### Cómo entra tu CLI

| Forma | Credenciales | Cuándo |
|-------|--------------|--------|
| `aws configure` con llaves de acceso | **permanentes**, en `~/.aws/credentials` | evítalas. Si alguna vez no queda otra, que sean de un usuario con permisos mínimos y se roten |
| **`aws login`** (CLI 2.32.0 o posterior) | temporales: se renuevan solas cada 15 min durante 12 h como máximo, con tu usuario de consola y su MFA | **tu caso**: una cuenta personal |
| `aws sso login` (IAM Identity Center) | temporales, con tu usuario de la empresa | en tu trabajo |
| roles de máquina (perfil de instancia, OIDC) | temporales, sin nadie delante | EC2, contenedores, GitHub Actions |

`aws login` abre el navegador, te autentica como en la consola (con MFA) y guarda las credenciales temporales en `~/.aws/login/cache/`. Los usuarios de IAM necesitan la política administrada `SignInLocalDevelopmentAccess`; `AdministratorAccess` ya la incluye.

### Dónde busca credenciales la CLI

La CLI y los SDK (boto3 incluido) prueban fuentes **en orden** y se quedan con la primera que encuentran. Simplificado:

1. Las **opciones** de la orden (`--profile`).
2. Las **variables de entorno** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`.
3. El **perfil** activo en `~/.aws/config`: con `login_session` (tu caso), `sso_session`, `role_arn` o `credential_process`. También `~/.aws/credentials`, que tú no tendrás.
4. Las credenciales del **contenedor** (ECS, EKS).
5. Los **metadatos de la instancia** (IMDS): el rol de la EC2 donde corre el programa.

Dos consecuencias:
- Una variable de entorno olvidada pasa por delante de tu perfil sin avisar (Rómpelo 1).
- El mismo código de boto3 funciona en tu portátil (con `aws login`) y en una EC2 (con su rol) **sin cambiar una línea**. Es lo que hará Vigía v3.

### IAM Identity Center (concepto)

En una empresa con muchas cuentas de AWS, nadie crea usuarios de IAM en cada una. Se usa **IAM Identity Center**:
- las personas existen una vez, normalmente sincronizadas con el directorio de la empresa (Entra ID, Okta, Google Workspace);
- se les asignan **conjuntos de permisos** (*permission sets*) en las cuentas que necesitan;
- entran por un portal único, y en la CLI con `aws sso login`.

Es la respuesta correcta en una entrevista a "¿cómo gestionarías el acceso de 50 personas a 10 cuentas?".

En tu cuenta personal **no lo actives**: su forma normal necesita AWS Organizations, y unirte a Organizations pasa tu cuenta al plan de pago (clase 67). Para una persona y una cuenta, un usuario de IAM con MFA y `aws login` es lo adecuado.

## Práctica guiada

### 1. Instalar la AWS CLI v2 (15 min)

AWS publica un instalador oficial que instala en **tu usuario**, sin `sudo`, y comprueba la firma PGP de lo que descarga:

```bash
cd /tmp
curl -fsSLo aws-install.sh https://awscli.amazonaws.com/v2/install.sh
less aws-install.sh
bash aws-install.sh
```

Lee el script antes de ejecutarlo. Hazlo siempre con cualquier script de internet, y por eso aquí lo descargas primero en lugar del típico `curl … | bash`. Busca dónde instala y qué comprueba.

🔮 **Predice:** ¿dónde quedará el programa? En `~/.local/share/aws-cli/`, con enlaces en `~/.local/bin/`. Esa carpeta ya está en tu `PATH` desde que instalaste `ruff` con `pipx` (clase 46).

```bash
which aws
aws --version
```

Necesitas la **2.32.0 o posterior** para `aws login`. El paquete `awscli` de `apt` va por detrás (en Ubuntu 26.04 es la 2.31): por eso usas el instalador oficial. Para actualizar más adelante:

```bash
aws update
```

Y para completar con el tabulador, añade a tu `~/.bashrc`:

```bash
complete -C aws_completer aws
```

### 2. `aws login` (15 min)

```bash
aws login
```

1. Te pide una región: escribe `us-east-1`.
2. Se abre el navegador. Entra como `eduardo` con tu MFA, o elige la sesión de consola que ya tengas abierta.
3. Vuelve a la terminal.

Ahora mira qué ha dejado en tu disco:

```bash
ls -la ~/.aws/
cat ~/.aws/config
ls ~/.aws/login/cache/
aws sts get-caller-identity
aws configure list
```

🔮 **Predice:** ¿existe `~/.aws/credentials`? **No.** `~/.aws/config` solo tiene tu perfil `default` con `login_session = arn:aws:iam::<cuenta>:user/eduardo` y la región. Lo único "secreto" está en la caché de `login`: credenciales que caducan solas.

`aws configure list` te dice **de dónde** salen las credenciales: es la primera orden cuando "la CLI no funciona".

Si alguna vez trabajas en una máquina sin navegador (por SSH, por ejemplo), usa `aws login --remote`: te da una URL para abrir en otro dispositivo y un código que pegas de vuelta. Para cerrar la sesión: `aws logout`.

### 3. Un rol que puedes asumir (20 min)

Crea un rol de **solo lectura de S3** que puedan asumir las identidades de tu cuenta:

```bash
mkdir -p ~/my-devops-journey/labs/clase-70 && cd ~/my-devops-journey/labs/clase-70
CUENTA=$(aws sts get-caller-identity --query Account --output text)
cat > confianza.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::$CUENTA:root"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role --role-name lector-lab --assume-role-policy-document file://confianza.json \
  --max-session-duration 3600 --tags Key=Proyecto,Value=lab --query Role.Arn --output text
aws iam attach-role-policy --role-name lector-lab \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

Asúmelo durante 15 minutos (el mínimo). Guarda la respuesta en una **variable**, no en un archivo: son credenciales válidas, y esta carpeta está dentro de tu repositorio.

```bash
SESION=$(aws sts assume-role --role-arn "arn:aws:iam::$CUENTA:role/lector-lab" \
  --role-session-name prueba-eduardo --duration-seconds 900 --output json)
jq '.Credentials | {AccessKeyId, Expiration}' <<< "$SESION"
```

🔮 **Predice:** ¿por qué letras empieza el `AccessKeyId`? `ASIA`: temporal. Y `Expiration` está 15 minutos en el futuro (en UTC).

Úsalas en una **subshell**, entre paréntesis: las variables que exportes ahí mueren al cerrarla (clase 07).

```bash
(
  export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId <<< "$SESION")
  export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey <<< "$SESION")
  export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken <<< "$SESION")
  aws sts get-caller-identity --query Arn --output text
  aws s3 ls && echo "listar: permitido"
  aws s3 mb "s3://prueba-rol-$CUENTA"
)
aws sts get-caller-identity --query Arn --output text
```

🔮 **Predice** las tres salidas de dentro y la de fuera:
- **Dentro:**
  - eres `arn:aws:sts::<cuenta>:assumed-role/lector-lab/prueba-eduardo`;
  - listar funciona (aunque no tengas buckets);
  - crear un bucket da `AccessDenied`: el rol solo lee.
- **Fuera:** vuelves a ser `eduardo`.

Así funcionará la EC2 de Vigía: el rol le da exactamente los permisos que necesita, con credenciales que caducan solas.

### 4. Identity Center, sin activarlo (5 min)

En la consola, busca **IAM Identity Center** y lee la página de inicio. Verás el botón para activarlo y la mención a AWS Organizations. **No lo pulses.** Basta con que sepas dónde está y qué resuelve.

## Rómpelo

**1. Una variable que manda más que tu perfil:**

```bash
AWS_ACCESS_KEY_ID=AKIAEJEMPLOFALSO AWS_SECRET_ACCESS_KEY=falso aws sts get-caller-identity
AWS_ACCESS_KEY_ID=AKIAEJEMPLOFALSO AWS_SECRET_ACCESS_KEY=falso aws configure list
```

`InvalidClientTokenId`, aunque tu `aws login` está activo: las variables de entorno van antes que el perfil. `aws configure list` lo delata con `env` en la columna *TYPE*.

En la vida real pasa con un `export` olvidado en `~/.bashrc` de un tutorial antiguo. Diagnóstico:

```bash
env | grep ^AWS_
aws configure list
```

**2. Un rol que no confía en ti.** Crea un rol que solo pueda asumir EC2 e intenta asumirlo tú:

```bash
cat > confianza-ec2.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role --role-name solo-ec2-lab --assume-role-policy-document file://confianza-ec2.json \
  --tags Key=Proyecto,Value=lab --query Role.Arn --output text
aws sts assume-role --role-arn "arn:aws:iam::$CUENTA:role/solo-ec2-lab" --role-session-name intento
aws iam delete-role --role-name solo-ec2-lab
```

¿Qué pasa al asumirlo? `AccessDenied … is not authorized to perform: sts:AssumeRole`, aunque seas administrador: la política de confianza del rol también tiene que dejarte, y esta solo admite el servicio EC2. Las dos partes deben estar de acuerdo.

**3. Credenciales caducadas.** Al **final** de la clase, cuando hayan pasado los 15 minutos, repite la subshell del paso 3 con la misma `$SESION`. `ExpiredToken`: esas credenciales ya no sirven para nada, ni a ti ni a quien las hubiera robado.

**4. Sin sesión:**

```bash
aws logout
aws s3 ls
aws login
```

Sin sesión, la CLI no tiene credenciales y te lo dice. `aws login` y vuelves a estar dentro.

## Reto

1. Cambia la política de confianza de `lector-lab` para que solo lo pueda asumir **tu usuario** (`arn:aws:iam::<cuenta>:user/eduardo`) en lugar de toda la cuenta. Usa `aws iam update-assume-role-policy` y comprueba que sigues pudiendo asumirlo.
2. Busca tu `AssumeRole` en **CloudTrail**. En la consola: CloudTrail → *Event history* → filtra por *Event name* = `AssumeRole`. ¿Qué datos registra: quién, cuándo, desde qué IP? CloudTrail guarda 90 días de eventos de gestión gratis. Es la auditoría de "quién hizo qué" de la cuenta, y entra en el examen.
3. Configura la terminación con el tabulador y prueba `aws s3 <TAB><TAB>` y `aws ec2 describe-<TAB><TAB>`.

## Destruir al terminar

```bash
aws iam detach-role-policy --role-name lector-lab --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam delete-role --role-name lector-lab
aws iam list-roles --query "Roles[?starts_with(RoleName, 'lector') || starts_with(RoleName, 'solo-ec2')].RoleName" --output text
```

La última orden no debe mostrar nada. Los JSON de `labs/clase-70/` puedes subirlos a Git: no contienen secretos (el ID de cuenta no es un secreto, aunque tampoco hace falta publicarlo).

## Cierre

En `notas/fase-6/clase-70.md`:

1. ¿Qué diferencia hay entre la política de confianza y la de permisos de un rol? Pon un ejemplo de cada una para la EC2 de Vigía.
2. ¿Por qué es más seguro que tu CLI use `aws login` en lugar de una llave de acceso?
3. Tu `aws login` está activo, pero `aws s3 ls` falla con `InvalidClientTokenId`. ¿Qué miras primero y por qué?
4. **Repaso (clase 69, sin mirar):** ¿qué decide IAM si hay un `Allow` y un `Deny` para la misma acción y el mismo recurso?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La de **confianza** dice quién puede asumir el rol. Para Vigía: `Principal: {"Service": "ec2.amazonaws.com"}`, es decir, solo las instancias EC2. La de **permisos** dice qué puede hacer quien lo asume. Para Vigía: descargar imágenes de ECR, escribir en sus grupos de logs y subir informes a `s3://<bucket>/reports/*`, nada más.

**2.** Porque `aws login` no guarda nada permanente:
- las credenciales se renuevan cada 15 minutos y mueren como mucho a las 12 h;
- para conseguirlas hace falta tu contraseña y tu MFA;
- si alguien copia tu caché, le sirve poco tiempo.

Una llave de acceso vale hasta que alguien la desactive, no pide MFA y suele acabar donde no debe.

**3.** Las variables de entorno: `env | grep ^AWS_` y `aws configure list`. Van **antes** que el perfil en la cadena de credenciales, así que un `AWS_ACCESS_KEY_ID` viejo anula tu sesión sin avisar.

**4.** Lo deniega: un `Deny` explícito gana siempre.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| role / to assume a role | rol / asumir un rol |
| trust policy / permissions policy | política de confianza / de permisos |
| temporary credentials / session token | credenciales temporales / token de sesión |
| credential provider chain | cadena de proveedores de credenciales |
| instance profile | perfil de instancia |
| identity federation / single sign-on | federación de identidades / inicio de sesión único |

🎙️ *"I don't keep long-lived access keys on my laptop. I sign in to the CLI with aws login, which gives me short-lived credentials behind MFA, and machines get their permissions from IAM roles. In a company I'd use IAM Identity Center with permission sets."*

## Siguiente

[Clase 71 — VPC desde cero](clase-71-vpc.md)
