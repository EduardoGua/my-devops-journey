# Clase 70 — IAM II: roles y la AWS CLI sin llaves

**Dónde:** tu Ubuntu + navegador · **Tiempo:** 90 min · **Bloque:** A. Cuenta, costos e identidad

> 💡 **La idea de hoy:** un **rol** es una identidad sin contraseña ni llaves: quien lo **asume** recibe credenciales **temporales** que caducan solas. Tiene dos políticas: la de **confianza** (quién puede asumirlo) y la de **permisos** (qué puede hacer). Hoy instalas la AWS CLI en tu Ubuntu, entras con `aws login` sin guardar ninguna llave y pruebas un rol desde la terminal. Es el mismo modelo que usarán la EC2 de Vigía, GitHub Actions y Kubernetes.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las políticas, los ARN, el simulador y que un `Deny` gana siempre (clase 69).
> - Por qué no quieres llaves de acceso permanentes (clase 67).
> - `export`, las variables de entorno y que un proceso hijo recibe una copia (clase 07).
> - `~/.local/bin` en tu `PATH`, desde `pipx` (clase 46); `jq` (clase 47) y el *here-string* `<<<` (clase 21).

> 🔤 **Palabras nuevas de hoy:**
> - **rol**: una identidad sin credenciales propias que alguien o algo asume.
> - **STS** (*Security Token Service*): el servicio que entrega las credenciales temporales.
> - **`AKIA…` / `ASIA…`**: el principio de una llave permanente / de una temporal.
> - **política de confianza** (*trust policy*): la que dice quién puede asumir un rol.
> - **`aws login`**: la forma de entrar en la CLI con tu usuario de consola y su MFA, con credenciales que caducan.
> - **cadena de credenciales**: el orden en que la CLI busca credenciales.
> - **IAM Identity Center**: el acceso centralizado de las empresas a muchas cuentas.

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

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida en tu Ubuntu; no pases a la siguiente sin haber hecho la anterior. Las tres primeras dejan tu CLI lista; las tres últimas son los roles.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto, la limpieza y el cierre.

## Las piezas

### Pieza 1 — Instalar la AWS CLI v2

AWS publica un instalador oficial que instala en **tu usuario**, sin `sudo`, y comprueba la firma PGP de lo que descarga. Necesitas la **2.32.0 o posterior** para `aws login`, y el paquete `awscli` de `apt` va por detrás (en Ubuntu 26.04 es la 2.31): por eso usas el instalador oficial.

🔮 **Predice:** ¿dónde quedará el programa, si no usas `sudo`?

**Pruébalo:**

```bash
cd /tmp
curl -fsSLo aws-install.sh https://awscli.amazonaws.com/v2/install.sh
less aws-install.sh
bash aws-install.sh
which aws
aws --version
```

Lee el script antes de ejecutarlo. Hazlo siempre con cualquier script de internet, y por eso aquí lo descargas primero en lugar del típico `curl … | bash`. Busca dónde instala y qué comprueba.

👀 **Qué deberías ver:** el instalador descarga, verifica la firma e instala; `which aws` dice `/home/educo/.local/bin/aws` (el programa está en `~/.local/share/aws-cli/`, con enlaces en `~/.local/bin/`, que ya está en tu `PATH` desde la clase 46); y `aws-cli/2.3x.x Python/3.x Linux/7.0.0-38-generic…`, con una versión 2.32.0 o posterior.

Para actualizar más adelante: `aws update`. Y para completar con el tabulador, añade a tu `~/.bashrc` la línea `complete -C aws_completer aws` (reto 3).

✋ **Sin mirar:** ¿por qué no instalas la CLI con `apt`?

<details>
<summary>Comprueba</summary>

Porque la versión de `apt` (2.31) es anterior a la 2.32.0, y `aws login` necesita la 2.32.0 o posterior.
</details>

**En resumen:** el instalador oficial, leído antes de ejecutarlo, deja `aws` en `~/.local/bin` sin `sudo`.

### Pieza 2 — Cómo entra tu CLI: `aws login`

| Forma | Credenciales | Cuándo |
|-------|--------------|--------|
| `aws configure` con llaves de acceso | **permanentes**, en `~/.aws/credentials` | evítalas. Si alguna vez no queda otra, que sean de un usuario con permisos mínimos y se roten |
| **`aws login`** (CLI 2.32.0 o posterior) | temporales: se renuevan solas cada 15 min durante 12 h como máximo, con tu usuario de consola y su MFA | **tu caso**: una cuenta personal |
| `aws sso login` (IAM Identity Center) | temporales, con tu usuario de la empresa | en tu trabajo |
| roles de máquina (perfil de instancia, OIDC) | temporales, sin nadie delante | EC2, contenedores, GitHub Actions |

`aws login` abre el navegador, te autentica como en la consola (con MFA) y guarda las credenciales temporales en `~/.aws/login/cache/`. Los usuarios de IAM necesitan la política administrada `SignInLocalDevelopmentAccess`; `AdministratorAccess` ya la incluye.

**Pruébalo:**

```bash
aws login
```

1. Te pide una región: escribe `us-east-1`.
2. Se abre el navegador. Entra como `eduardo` con tu MFA, o elige la sesión de consola que ya tengas abierta.
3. Vuelve a la terminal.

🔮 **Predice:** ¿existirá `~/.aws/credentials`?

```bash
ls -la ~/.aws/
cat ~/.aws/config
ls ~/.aws/login/cache/
aws sts get-caller-identity
```

👀 **Qué deberías ver:** en `~/.aws/` hay `config` y la carpeta `login`, pero **no** `credentials`. `config` solo tiene tu perfil `default` con `login_session = arn:aws:iam::<cuenta>:user/eduardo` y la región. Lo único "secreto" está en la caché de `login`: credenciales que caducan solas. Y `get-caller-identity` dice que eres `user/eduardo`.

Si alguna vez trabajas en una máquina sin navegador (por SSH, por ejemplo), usa `aws login --remote`: te da una URL para abrir en otro dispositivo y un código que pegas de vuelta. Para cerrar la sesión: `aws logout`.

✋ **Sin mirar:** ¿cuánto dura como máximo una sesión de `aws login`, y qué te pide para empezarla?

<details>
<summary>Comprueba</summary>

12 horas, renovándose cada 15 minutos. Para empezarla, tu contraseña de consola y tu MFA.
</details>

**En resumen:** `aws login` = tu usuario de consola con MFA en la terminal, sin llaves en disco.

### Pieza 3 — Dónde busca credenciales la CLI

La CLI y los SDK (boto3 incluido) prueban fuentes **en orden** y se quedan con la primera que encuentran. Simplificado:

1. Las **opciones** de la orden (`--profile`).
2. Las **variables de entorno** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`.
3. El **perfil** activo en `~/.aws/config`: con `login_session` (tu caso), `sso_session`, `role_arn` o `credential_process`. También `~/.aws/credentials`, que tú no tendrás.
4. Las credenciales del **contenedor** (ECS, EKS).
5. Los **metadatos de la instancia** (IMDS): el rol de la EC2 donde corre el programa.

Dos consecuencias:
- Una variable de entorno olvidada pasa por delante de tu perfil sin avisar (Rómpelo 1).
- El mismo código de boto3 funciona en tu portátil (con `aws login`) y en una EC2 (con su rol) **sin cambiar una línea**. Es lo que hará Vigía v3.

**Pruébalo:**

```bash
aws configure list
env | grep ^AWS_ || echo "ninguna variable AWS_ en tu entorno"
```

👀 **Qué deberías ver:** una tabla con `profile`, `access_key`, `secret_key` y `region`; las claves salen tapadas con asteriscos y la columna *TYPE* dice de dónde viene cada una (aquí, la sesión de `login`; la región, de `config-file`). Y `ninguna variable AWS_ en tu entorno`. `aws configure list` es la primera orden cuando "la CLI no funciona".

✋ **Sin mirar:** tienes `aws login` activo y, además, un `AWS_ACCESS_KEY_ID` exportado. ¿Cuál usa la CLI?

<details>
<summary>Comprueba</summary>

La variable de entorno: va antes que el perfil en la cadena.
</details>

**En resumen:** opciones → variables de entorno → perfil → contenedor → metadatos de la instancia; `aws configure list` dice cuál ganó.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `aws login` (si la sesión caducó).

### Pieza 4 — Un rol: dos políticas

Un usuario tiene credenciales permanentes. Un rol no tiene ninguna: quien lo **asume** recibe de **STS** unas credenciales temporales, que caducan solas.

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

Los usos típicos de un rol: **roles de servicio** (una EC2 o una Lambda que actúa en tu nombre), **roles entre cuentas** (de la cuenta de desarrollo a la de producción) y **federación** (identidades de fuera, como la empresa o GitHub, que reciben un rol). Para que una EC2 use un rol, el rol va dentro de un **perfil de instancia** (*instance profile*): lo verás en la clase 72.

🔮 **Predice:** ¿por qué letras empezará el `AccessKeyId` que te dé STS?

**Pruébalo.** Crea un rol de **solo lectura de S3** que puedan asumir las identidades de tu cuenta, y asúmelo durante 15 minutos (el mínimo):

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
SESION=$(aws sts assume-role --role-arn "arn:aws:iam::$CUENTA:role/lector-lab" \
  --role-session-name prueba-eduardo --duration-seconds 900 --output json)
jq '.Credentials | {AccessKeyId, Expiration}' <<< "$SESION"
```

Guarda la respuesta en una **variable**, no en un archivo: son credenciales válidas, y esta carpeta está dentro de tu repositorio.

👀 **Qué deberías ver:** el ARN del rol (`arn:aws:iam::<cuenta>:role/lector-lab`) y un JSON con `"AccessKeyId": "ASIA…"` (temporal) y una `Expiration` 15 minutos en el futuro, en UTC. Si el `assume-role` falla nada más crear el rol, espera unos segundos y repítelo: IAM tarda un poco en propagar los cambios.

✋ **Sin mirar:** en una política de confianza, ¿qué significa `"AWS": "arn:aws:iam::123456789012:root"`?

<details>
<summary>Comprueba</summary>

"La cuenta 123456789012": cualquier identidad de esa cuenta cuya propia política le permita `sts:AssumeRole` sobre el rol. No es el usuario raíz.
</details>

**En resumen:** confianza = quién lo asume; permisos = qué puede hacer; `sts assume-role` da credenciales `ASIA…` que caducan.

### Pieza 5 — Usar las credenciales temporales

Las credenciales se usan exportándolas como variables de entorno, que van antes que tu perfil en la cadena (pieza 3). Hazlo en una **subshell**, entre paréntesis: las variables que exportes ahí mueren al cerrarla, igual que la copia del entorno de un proceso hijo (clase 07).

🔮 **Predice** las tres salidas de dentro de los paréntesis y la de fuera.

**Pruébalo:**

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

👀 **Qué deberías ver:** dentro, eres `arn:aws:sts::<cuenta>:assumed-role/lector-lab/prueba-eduardo`; listar funciona (`listar: permitido`, aunque no tengas buckets); y crear un bucket da `AccessDenied`: el rol solo lee. Fuera, vuelves a ser `user/eduardo`. Así funcionará la EC2 de Vigía: el rol le da exactamente los permisos que necesita, con credenciales que caducan solas.

✋ **Sin mirar:** ¿qué tres variables necesita la CLI para usar credenciales temporales?

<details>
<summary>Comprueba</summary>

`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`. Sin el token, una llave `ASIA…` no vale.
</details>

**En resumen:** con las tres variables exportadas en una subshell, eres el rol; al cerrarla, vuelves a ser tú.

### Pieza 6 — IAM Identity Center (concepto)

En una empresa con muchas cuentas de AWS, nadie crea usuarios de IAM en cada una. Se usa **IAM Identity Center**:
- las personas existen una vez, normalmente sincronizadas con el directorio de la empresa (Entra ID, Okta, Google Workspace);
- se les asignan **conjuntos de permisos** (*permission sets*) en las cuentas que necesitan;
- entran por un portal único, y en la CLI con `aws sso login`.

Es la respuesta correcta en una entrevista a "¿cómo gestionarías el acceso de 50 personas a 10 cuentas?".

En tu cuenta personal **no lo actives**: su forma normal necesita AWS Organizations, y unirte a Organizations pasa tu cuenta al plan de pago (clase 67). Para una persona y una cuenta, un usuario de IAM con MFA y `aws login` es lo adecuado.

**Pruébalo (5 min):** en la consola, busca **IAM Identity Center** y lee la página de inicio. **No pulses** el botón de activarlo.

👀 **Qué deberías ver:** el botón para activarlo y la mención a AWS Organizations. Basta con que sepas dónde está y qué resuelve.

✋ **Sin mirar:** ¿por qué no activas Identity Center en tu cuenta?

<details>
<summary>Comprueba</summary>

Porque necesita AWS Organizations, y unirte a Organizations pasaría tu cuenta al plan de pago.
</details>

**En resumen:** Identity Center para empresas con muchas personas y cuentas; para ti, un usuario de IAM con MFA y `aws login`.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `bash aws-install.sh` · `aws update` · `aws --version` | instalar, actualizar, ver la versión |
| `aws login` · `aws login --remote` · `aws logout` | entrar, entrar sin navegador, salir |
| `aws configure list` · `env \| grep ^AWS_` | de dónde salen las credenciales |
| `aws iam create-role --assume-role-policy-document file://confianza.json` | crear un rol con su política de confianza |
| `aws iam attach-role-policy --role-name … --policy-arn …` | darle permisos |
| `aws sts assume-role --role-arn … --role-session-name … --duration-seconds 900` | asumirlo |
| `( export AWS_ACCESS_KEY_ID=… ; … )` | usar credenciales temporales en una subshell |
| `AKIA…` · `ASIA…` | llave permanente · temporal |
| `complete -C aws_completer aws` | completar con el tabulador |

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

**3. Credenciales caducadas.** Al **final** de la clase, cuando hayan pasado los 15 minutos, repite la subshell de la pieza 5 con la misma `$SESION`. `ExpiredToken`: esas credenciales ya no sirven para nada, ni a ti ni a quien las hubiera robado.

**4. Sin sesión:**

```bash
aws logout
aws s3 ls
aws login
```

Sin sesión, la CLI no tiene credenciales y te lo dice. `aws login` y vuelves a estar dentro.

## Reto

Haz los retos antes de "Destruir al terminar": el primero usa el rol `lector-lab`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Cambia la política de confianza de `lector-lab` para que solo lo pueda asumir **tu usuario**, y no toda la cuenta. Comprueba que sigues pudiendo asumirlo.

> 🧩 **Ejemplo resuelto:** `confianza.json` de la pieza 4, con `"Principal": {"AWS": "arn:aws:iam::$CUENTA:root"}`.

**Ahora tú, con huecos:**
```bash
sed "s|:root\"|:____/eduardo\"|" confianza.json > confianza-eduardo.json
grep Principal confianza-eduardo.json
aws iam ____ --role-name lector-lab --policy-document file://confianza-eduardo.json
aws sts assume-role --role-arn "arn:aws:iam::$CUENTA:role/lector-lab" \
  --role-session-name prueba-2 --duration-seconds 900 --query Credentials.Expiration --output text
```

<details>
<summary>Pista</summary>

El ARN de tu usuario es `arn:aws:iam::<cuenta>:user/eduardo` (pieza 1 de la clase 69). La orden para cambiar la política de confianza es `update-assume-role-policy`.
</details>

**2.** Busca tu `AssumeRole` en **CloudTrail**: la auditoría de "quién hizo qué" de la cuenta, que guarda 90 días de eventos de gestión gratis y entra en el examen.

> 🧩 **Ejemplo resuelto:** en la consola, CloudTrail → *Event history* → filtra por *Event name* = `AssumeRole`.

**Ahora tú, con huecos:** abre uno de tus eventos y completa: «Quién: ____. Cuándo: ____. Desde qué IP: ____. Sobre qué rol: ____».

<details>
<summary>Pista</summary>

Pulsa el evento y mira su registro JSON: `userIdentity`, `eventTime`, `sourceIPAddress` y, dentro de `requestParameters`, `roleArn`.
</details>

**3.** Configura la terminación con el tabulador.

> 🧩 **Ejemplo resuelto:** la línea `complete -C aws_completer aws` de la pieza 1.

**Ahora tú, con huecos:**
```bash
echo 'complete -C ____ aws' >> ~/.bashrc && source ~/.bashrc
```
Después escribe `aws s3 ` y pulsa el tabulador dos veces. Completa: «Me ofrece ____, ____, ____…».

<details>
<summary>Pista</summary>

`aws_completer` se instaló junto a `aws` en `~/.local/bin`. Prueba también `aws ec2 describe-` y el tabulador.
</details>

## Destruir al terminar

```bash
aws iam detach-role-policy --role-name lector-lab --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam delete-role --role-name lector-lab
aws iam list-roles --query "Roles[?starts_with(RoleName, 'lector') || starts_with(RoleName, 'solo-ec2')].RoleName" --output text
```

La última orden no debe mostrar nada. Los JSON de `labs/clase-70/` puedes subirlos a Git: no contienen secretos (el ID de cuenta no es un secreto, aunque tampoco hace falta publicarlo).

## Cierre

En `notas/fase-6/clase-70.md`:

1. ¿Qué diferencia hay entre la política de confianza y la de permisos de un rol? Pon un ejemplo de cada una para la EC2 de Vigía. *(2 líneas. Empieza así: «La de confianza dice quién puede asumir el rol; para Vigía,… La de permisos dice…; para Vigía,…»)*
2. ¿Por qué es más seguro que tu CLI use `aws login` en lugar de una llave de acceso? *(2 líneas. Empieza así: «Porque `aws login` no guarda nada permanente: las credenciales… Una llave de acceso…»)*
3. Tu `aws login` está activo, pero `aws s3 ls` falla con `InvalidClientTokenId`. ¿Qué miras primero y por qué? *(1–2 líneas. Empieza así: «Las variables de entorno, con…, porque van antes que…»)*
4. **Repaso (clase 69, sin mirar):** ¿qué decide IAM si hay un `Allow` y un `Deny` para la misma acción y el mismo recurso? *(1 línea. Empieza así: «Lo deniega, porque…»)*

Después, escríbeme `examíname clase-70`.

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

**Reto 1:** `:user/eduardo` y `update-assume-role-policy`. El `assume-role` sigue funcionando y devuelve la nueva `Expiration`.

**Reto 2:** quién, tu usuario `eduardo` (en `userIdentity`); cuándo, la hora en UTC (`eventTime`); desde qué IP, la pública de tu casa (`sourceIPAddress`); y el rol, `arn:aws:iam::<cuenta>:role/lector-lab`.

**Reto 3:** `complete -C aws_completer aws`. Con `aws s3 ` te ofrece `cp`, `ls`, `mb`, `mv`, `presign`, `rb`, `rm`, `sync` y `website`.
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
