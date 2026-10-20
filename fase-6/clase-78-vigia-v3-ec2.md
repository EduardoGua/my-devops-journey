# Clase 78 — Proyecto: Vigía v3 (I): en EC2 con un rol IAM

**Dónde:** tu Ubuntu + AWS + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

> 💡 **La idea de hoy:** Vigía v2 llega a AWS tal como está: la misma imagen, ahora en ECR, y el mismo Compose, en una EC2 que se monta sola en el primer arranque con cloud-init. Sin una sola llave guardada (los permisos los da un **rol**), sin SSH (entras con Session Manager) y con el puerto 80 abierto solo a tu IP. Al terminar, destruyes la instancia y la recreas idéntica con un comando.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Tu Vigía v2: `compose.yaml`, el `.env` y la imagen `2.0.0` (clases 65 y 66).
> - cloud-init con `write_files` y los marcadores `__…__` que se sustituyen con `sed` (clase 37).
> - La `lab-vpc` y `crear-vpc.sh` (clase 71); el rol, el perfil de instancia, IMDSv2 y Session Manager (clase 72).
> - El SG abierto solo a tu IP y *timeout* frente a *refused* (clase 73).
> - ECR, las etiquetas inmutables y el *credential helper* con `credHelpers` (clase 75).

> 🔤 **Palabras nuevas de hoy:**
> - ***override* de Compose**: un segundo archivo que cambia partes del primero sin tocarlo (`-f compose.yaml -f compose.aws.yaml`).
> - **ECR Public**: el registro público de AWS, con copias de las imágenes oficiales de Docker Hub.
> - **marcador**: un texto como `__IMAGE__` que se sustituye por el valor real antes de usar el archivo.
> - **infraestructura desechable**: recrear un servidor desde su receta en lugar de repararlo a mano.

## Objetivo

Llevar Vigía v2 tal como está (API, chequeo y PostgreSQL en Compose) a una EC2:
- la imagen en ECR;
- los permisos con un rol IAM, sin una sola llave guardada en el servidor;
- ningún puerto abierto salvo el 80, y solo para tu IP;
- sin SSH;
- todo levantado solo en el primer arranque, con cloud-init.

Al terminar, puedes destruir la instancia y recrearla idéntica en unos minutos. En la clase 79 le añadirás el informe en S3, los logs en CloudWatch y la versión `v3`.

Criterio de salida de la fase (se completa en la 79): *Vigía corre en EC2 con un rol IAM, sin llaves guardadas en el servidor*.

## Costo esperado

> 💰 **Unos 0,15 USD por sesión de 5 horas:** t3.small (0,0208 USD/h) + su IPv4 pública (0,005 USD/h) + el disco. ECR guarda tu imagen por céntimos al mes.
>
> ⚠️ **Olvidada un mes entero, la instancia gasta unos 20 USD de créditos.** Termínala al acabar cada sesión: recrearla es un comando.

## La arquitectura

```
 tu Ubuntu (tu IP) ──HTTP 80──► security group vigia-web: TCP 80 solo desde tu IP/32 (sin 22)
                                         │
 lab-vpc · lab-publica  ┌────────────────▼─────────── EC2 "vigia" · t3.small · Ubuntu 26.04 ──┐
                        │ rol vigia-ec2 (perfil de instancia) · IMDSv2 obligatorio            │
                        │ Docker + Compose:  api (80→8000) · checker · db (volumen "datos")   │
                        │ /opt/vigia: tu repo  +  .env generado aquí (permisos 600)           │
                        └───────┬─────────────────────┬─────────────────────────┬───────────┘
                                │ descarga su imagen  │ descarga postgres:18    │ el agente de SSM sale
                                ▼                     ▼                         ▼
                       ECR: vigia:2.0.0     ECR Public (copia oficial)   tú: aws ssm start-session
```

Nadie entra en la instancia por la red salvo tu navegador al puerto 80. Tú la administras con Session Manager, que **sale** de ella.

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Repositorio ECR `vigia` con etiquetas inmutables, escaneo al subir y política de ciclo de vida. Dentro, tu imagen de la v2 como `vigia:2.0.0` | 75 |
| R2 | Rol `vigia-ec2` con su perfil de instancia. Confianza solo para `ec2.amazonaws.com`. Permisos: `AmazonSSMManagedInstanceCore` y `AmazonEC2ContainerRegistryPullOnly`, nada más | 70, 72 |
| R3 | Security group `vigia-web` en la `lab-vpc`: entra el TCP 80 solo desde tu IP `/32`. Ni el 22 ni nada abierto a `0.0.0.0/0` | 73 |
| R4 | Una instancia `t3.small` con Ubuntu 26.04 en `lab-publica`, con las etiquetas `Name=vigia` y `Proyecto=vigia` y el rol de R2. IMDSv2 obligatorio: `HttpTokens=required` y `HttpPutResponseHopLimit=1` por ahora (la clase 79 explica cuándo subirlo) | 72 |
| R5 | `deploy/cloud-init.yaml`, con marcadores `__…__` en lugar de tus datos. Debe:<br>1. instalar `docker.io`, `docker-compose-v2`, `amazon-ecr-credential-helper` y `git`;<br>2. configurar Docker para que use el helper con tu registro de ECR, sin `docker login`;<br>3. clonar tu repositorio en `/opt/vigia`;<br>4. generar ahí un `.env` con una `POSTGRES_PASSWORD` aleatoria y permisos 600;<br>5. arrancar con `docker compose -f compose.yaml -f compose.aws.yaml up -d --no-build --wait`.<br>**Ningún secreto en el *user-data*** | 37, 66, 72, 75 |
| R6 | `compose.aws.yaml`: un *override* que no toca `compose.yaml`.<br>• `api` y `checker` usan la imagen de `VIGIA_IMAGE`, que llega del `.env`.<br>• `api` se publica también en el puerto 80.<br>• `db` descarga `postgres:18` de su copia oficial en ECR Public: `public.ecr.aws/docker/library/postgres:18` | 62, 64, 66 |
| R7 | En la instancia no hay llaves de AWS (ni `~/.aws/credentials` ni variables en el `.env`), y nadie entra por SSH: solo con Session Manager | 70, 72 |
| R8 | `http://<IP>/health` y `http://<IP>/status` responden desde tu IP, y no desde CloudShell | 73 |
| R9 | El README, en inglés, explica en *Deploy to AWS* cómo crearlo todo desde cero con la CLI | — |

**¿Por qué ECR Public para PostgreSQL (R6)?** Docker Hub limita las descargas anónimas por IP (clase 64), y las IP públicas de EC2 se reutilizan entre clientes de AWS: tu instancia podría heredar una IP que ya agotó su cupo. AWS mantiene en ECR Public una copia de las imágenes oficiales de Docker Hub, con el mismo contenido.

## Plan de trabajo

**Bloque 1: el repositorio (en tu Ubuntu)**

1. En `~/vigia`, una rama nueva: `git switch -c aws`.
2. **R1:**
   - crea el repositorio de ECR con su política de ciclo de vida (clase 75);
   - descarga tu imagen de Docker Hub (`docker pull TU_USUARIO/vigia:2.0.0`), etiquétala con el nombre de ECR y súbela;
   - mira el escaneo: si hay hallazgos críticos, anótalos para el README.
3. **R6:** escribe `compose.aws.yaml` y pruébalo **en tu portátil**:
   - añade a tu `.env` local la línea `VIGIA_IMAGE=<tu registro>/vigia:2.0.0`;
   - inicia sesión en ECR;
   - ejecuta `docker compose -f compose.yaml -f compose.aws.yaml config`, después `up -d --no-build --wait` y `curl -s localhost/health`;
   - para con `down` (sin `-v`: los datos locales se quedan).
4. **R5:** escribe `deploy/cloud-init.yaml` y valídalo con `cloud-init schema -c deploy/cloud-init.yaml`. Guarda también la política de confianza en `deploy/confianza-ec2.json`.
5. Commit, PR, *squash and merge*. **Tiene que estar en `main`**: cloud-init clona `main`.

**Bloque 2: AWS**

6. La red: `bash ~/my-devops-journey/labs/clase-71/crear-vpc.sh` (si no la tienes creada).
7. **R2:** el rol y su perfil de instancia.
8. **R3:** el security group.
9. **El *user-data* con tus datos:** sustituye los marcadores con `sed` en una copia fuera del repo (`/tmp/user-data.yaml`) y comprueba que no queda ninguno.
10. **R4:** lanza la instancia y espera a `instance-status-ok`.
11. Sigue el arranque desde dentro: `aws ssm start-session --target <ID>` y `sudo cloud-init status --wait --long`.
12. **R8:** prueba desde tu Ubuntu y desde CloudShell.
13. Las pruebas de aceptación (abajo).
14. **R9:** escribe *Deploy to AWS* en el README con los comandos que has usado, y haz otro PR.
15. **Destruir al terminar** (al final de la clase).

### Las pruebas de aceptación

```bash
VIGIA_BUCKET=pendiente bash ~/my-devops-journey/recursos/vigia/v3/verify-aws.sh
```

Lee tu cuenta con la CLI y comprueba la instancia, el firewall, que Vigía responde desde tu IP y, por Session Manager, lo que hay dentro. Al terminar **esta** clase, lo normal es:
- ✅ en todo lo de R1 a R8;
- ❌ en el **límite de saltos** (1), el **timer**, **CloudWatch** y **S3**: son el trabajo de la clase 79.

## Pistas

<details><summary>Pista 1 — el rol: dos órdenes que se olvidan</summary>

Un rol solo no basta para una EC2. Hay que crear el **perfil de instancia** y meter el rol dentro:
- `aws iam create-instance-profile`;
- `aws iam add-role-to-instance-profile`.

Si al lanzar sale `Invalid IAM Instance Profile name`, es la propagación de IAM: espera 10 segundos y repite (clase 72).
</details>

<details><summary>Pista 2 — cómo escribir el <code>cloud-init.yaml</code> sin pelearte con YAML</summary>

Un `runcmd` con comillas, llaves y `: ` dentro acaba siendo un diccionario de YAML (clase 72). Mete todo el arranque en un script con `write_files` (por ejemplo `/usr/local/sbin/vigia-arrancar.sh`, con `permissions: "0700"` y `set -euo pipefail`) y deja en `runcmd` una sola línea: `- [bash, /usr/local/sbin/vigia-arrancar.sh]`.

Así, además, puedes probar el script con `bash -n`.
</details>

<details><summary>Pista 3 — la contraseña, sin que pase por el <i>user-data</i></summary>

Se genera **en la instancia**, en el primer arranque:

```bash
umask 077
printf 'POSTGRES_PASSWORD=%s\nVIGIA_IMAGE=%s\n' "$(openssl rand -hex 16)" "$IMAGEN" > /opt/vigia/.env
```

Con `umask 077`, el archivo nace con permisos 600. La contraseña nunca sale de la máquina: ni en el *user-data*, ni en Git, ni en tu portátil.
</details>

<details><summary>Pista 4 — Docker y ECR sin <code>docker login</code></summary>

El helper se configura en el `config.json` del usuario que ejecuta Docker: en cloud-init es root, así que va en `/root/.docker/config.json`. Usa **`credHelpers`** solo para tu registro, no `credsStore`: con `credsStore`, Docker le preguntaría al helper por **todos** los registros, y con ECR Public el helper intenta autenticarse y falla. El registro es la parte de `VIGIA_IMAGE` antes de la primera `/`:

```bash
printf '{"credHelpers": {"%s": "ecr-login"}}\n' "${IMAGEN%%/*}" > /root/.docker/config.json
```

Para comprobarlo dentro de la instancia: `echo "<tu registro>" | sudo docker-credential-ecr-login get`. Si devuelve un JSON con `Username: AWS`, el rol y el helper funcionan.
</details>

<details><summary>Pista 5 — la instancia arrancó, pero Vigía no</summary>

Por Session Manager:
1. `sudo cloud-init status --long`: ¿terminó con error?
2. `sudo tail -60 /var/log/cloud-init-output.log`: la salida de tu script. Busca el primer error, no el último.
3. `cd /opt/vigia && sudo docker compose -f compose.yaml -f compose.aws.yaml ps -a`, y sus `logs`.

Los culpables más comunes:
- un marcador sin sustituir (`__IMAGE__`);
- el PR sin fusionar (el clon no trae `compose.aws.yaml`);
- el rol sin la política de ECR (`no basic auth credentials`).

Arregla el repo o el comando de lanzamiento y **recrea la instancia**, en lugar de parchearla a mano: así compruebas que la receta funciona.
</details>

<details><summary>Pista 6 — funciona dentro, pero no desde tu navegador</summary>

1. Dentro: `curl -s localhost/health` y `sudo ss -tlnp | grep ':80 '`.
2. Si eso responde, el problema es el camino:
   - ¿cambió tu IP (`curl -s https://checkip.amazonaws.com`)?
   - ¿el SG admite el 80 desde esa IP?
   - ¿`compose.aws.yaml` publica `80:8000`?

Recuerda: *timeout* = algo descarta; *refused* = no escucha nadie (clase 73).
</details>

## Rómpelo: antes de dar la clase por terminada

1. **Recrear en lugar de reparar.**
   - Termina la instancia y lánzala de nuevo con el **mismo** comando.
   - Cronometra desde `run-instances` hasta que `/health` responde. ¿Cuánto tarda?
   - ¿Qué pasó con el historial de `/status`?

   Se perdió: PostgreSQL guardaba sus datos en el disco de la instancia, que se borró con ella. Anótalo en *Limitations*. En producción, la base de datos iría en RDS (clase 77).
2. **Sin permiso para ECR.**
   - Quita al rol `AmazonEC2ContainerRegistryPullOnly` (`aws iam detach-role-policy`).
   - Dentro de la instancia: `sudo docker image rm <tu imagen>` y `sudo docker pull <tu imagen>`.
   - Lee el error. Vuelve a poner la política, espera un minuto y repite el `pull`.

   Los permisos de un rol se evalúan en cada petición: el cambio se nota sin reiniciar nada.
3. **Lo que ve cualquiera con permisos de lectura.** `aws ec2 describe-instance-attribute --instance-id <ID> --attribute userData --query UserData.Value --output text | base64 -d`. ¿Aparece alguna contraseña? No debe. Compáralo con `sudo cat /opt/vigia/.env` dentro de la instancia: el secreto solo vive ahí.
4. **Desde otra IP:** `curl -m 5 http://<IP>/health` en CloudShell. *Timeout*: el SG solo te admite a ti.

## Entregable

- En el repo:
  - `compose.aws.yaml`;
  - `deploy/cloud-init.yaml`, con marcadores y sin datos tuyos;
  - `deploy/confianza-ec2.json`;
  - el README con la nueva sección.
- En ECR: `vigia:2.0.0`.
- Aún sin etiqueta de Git: la `v3` se cierra en la clase 79.

README en inglés, sección nueva:

````markdown
## Deploy to AWS

Vigía runs on a single EC2 instance with Docker Compose. The instance has an IAM role
(no access keys), IMDSv2 enforced, no SSH: admin access is through SSM Session Manager.

Prerequisites: AWS CLI v2 signed in with `aws login`, Docker, and a VPC with a public subnet.

1. Push the image to ECR
2. Create the IAM role and instance profile
3. Create the security group (port 80 from your IP only)
4. Render `deploy/cloud-init.yaml` and launch the instance
5. Verify: `curl http://<public-ip>/health`
(each step with its exact commands)
````

### Modelo para adaptar (lo escribió Claude)

Cópialo en tu README y rellena los huecos (`____`); cambia los marcadores por los que use tu `deploy/cloud-init.yaml`. `VPC`, `SUBNET` y `AMI` se obtienen como en las clases 71 y 72.

````markdown
## Deploy to AWS

Vigía runs on a single EC2 instance with Docker Compose. The instance has an IAM role
(no access keys), IMDSv2 enforced, no SSH: admin access is through SSM Session Manager.

Prerequisites: AWS CLI v2 signed in with `aws login`, Docker, and a VPC with a public subnet.

### 1. Push the image to ECR
```bash
REGISTRY=____.dkr.ecr.us-east-1.amazonaws.com
aws ecr create-repository --repository-name vigia --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
docker tag ____/vigia:2.0.0 "$REGISTRY/vigia:2.0.0" && docker push "$REGISTRY/vigia:2.0.0"
```

### 2. Create the IAM role and instance profile
```bash
aws iam create-role --role-name vigia-ec2 --assume-role-policy-document file://deploy/confianza-ec2.json
aws iam attach-role-policy --role-name vigia-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam attach-role-policy --role-name vigia-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly
aws iam create-instance-profile --instance-profile-name vigia-ec2
aws iam add-role-to-instance-profile --instance-profile-name vigia-ec2 --role-name vigia-ec2
```

### 3. Create the security group (port 80 from your IP only)
```bash
SG=$(aws ec2 create-security-group --group-name vigia-web --vpc-id "$VPC" \
  --description "Vigia: HTTP from my IP" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 \
  --cidr "$(curl -s https://checkip.amazonaws.com)/32"
```

### 4. Render the cloud-init file and launch the instance
```bash
sed -e "s|__IMAGE__|$REGISTRY/vigia:2.0.0|" -e "s|__REPO__|https://github.com/____/vigia.git|" \
  deploy/cloud-init.yaml > /tmp/user-data.yaml
grep -c '__' /tmp/user-data.yaml        # must print 0
aws ec2 run-instances --image-id "$AMI" --instance-type t3.small --subnet-id "$SUBNET" \
  --security-group-ids "$SG" --iam-instance-profile Name=vigia-ec2 \
  --metadata-options HttpTokens=required,HttpPutResponseHopLimit=1 \
  --user-data file:///tmp/user-data.yaml \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vigia},{Key=Proyecto,Value=vigia}]'
```

### 5. Verify
```bash
curl http://<public-ip>/health
```
````

## Destruir al terminar

Al final de **cada** sesión, termina la instancia:

```bash
ID=$(aws ec2 describe-instances --filters Name=tag:Proyecto,Values=vigia Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 terminate-instances --instance-ids $ID
aws ec2 wait instance-terminated --instance-ids $ID
```

Lo demás no cobra por hora (o casi nada) y lo usarás en la clase 79, así que se queda. Apúntalo en tu inventario:
- el repositorio `vigia` de ECR (céntimos al mes por la imagen);
- el rol y el perfil `vigia-ec2`;
- el SG `vigia-web`;
- la `lab-vpc`.

## Cierre

En `notas/fase-6/clase-78.md`:

1. ¿Por qué la contraseña de PostgreSQL se genera dentro de la instancia y no viaja en el *user-data*? *(2 líneas. Empieza así: «Porque el user-data lo puede leer cualquiera con permiso para… Generada dentro con `openssl rand`, la contraseña…»)*
2. Explica cómo descarga la EC2 su imagen de ECR sin `docker login` y sin llaves. *(2 líneas. Empieza así: «Docker pide las credenciales al credential helper configurado en `/root/.docker/config.json`, y el helper…»)*
3. Si terminas la instancia y la lanzas otra vez, ¿qué se conserva y qué se pierde? ¿Por qué eso es una ventaja y también un límite? *(2–3 líneas. Empieza así: «Se conserva todo lo que está en el repo y en AWS (…); se pierde… Es una ventaja porque… y un límite porque…»)*
4. **Repaso (clase 77, sin mirar):** ¿qué diferencia hay entre Multi-AZ y una réplica de lectura? *(1–2 líneas. Empieza así: «Multi-AZ es una copia en espera, síncrona, en otra zona…; una réplica de lectura…»)*

Después, escríbeme `examíname clase-78`.

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify-aws.sh</code> solo falle en lo que corresponde a la clase 79</summary>

**Comprueba tu entrega:**
- [ ] `verify-aws.sh`: ✅ en la sesión, la instancia (salvo el límite de saltos), el firewall, "Vigía responde" y, por Session Manager, "no hay llaves" y "la imagen de ECR".
- [ ] `grep -E '__[A-Z_]+__' deploy/cloud-init.yaml` muestra los marcadores en el repo, y el mismo `grep` sobre `/tmp/user-data.yaml` no muestra ninguno.
- [ ] `git grep -n -i -E "AKIA|ASIA|aws_secret|password=" ` en tu repo solo muestra `${POSTGRES_PASSWORD…}` y textos de ejemplo.
- [ ] Recrear la instancia lleva menos de 10 minutos, sin tocar nada a mano.
- [ ] El inventario tiene apuntado lo que queda vivo.

**Cierre:**
1. Porque el *user-data* lo puede leer cualquiera con permiso para describir la instancia (Rómpelo 3), y además lo escribes desde tu portátil, que lo dejaría en tu historial o en tus archivos. Generada dentro con `openssl rand`, la contraseña nace y vive solo en `/opt/vigia/.env`, con permisos 600.
2. La instancia tiene un rol (`vigia-ec2`) con `AmazonEC2ContainerRegistryPullOnly`. El *credential helper* de ECR está configurado en `/root/.docker/config.json` para tu registro. Cuando Compose descarga la imagen, Docker le pide credenciales al helper, el helper consigue las credenciales temporales del rol en el IMDS, pide a ECR un token y se lo devuelve a Docker. Nada guardado, nada que caduque a mano.
3. **Se conserva** todo lo que está **fuera**: el código en GitHub, la imagen en ECR, el rol, el SG y la receta (`cloud-init.yaml`), así que la instancia nueva es idéntica. **Se pierde** lo que estaba **dentro**: la contraseña generada (sale otra) y los datos de PostgreSQL. Es una ventaja porque cualquier avería se arregla recreando; es un límite porque el historial no sobrevive. La solución es sacar los datos de la instancia: RDS, o un volumen EBS aparte.
4. **Multi-AZ:** copia síncrona en espera en otra zona, para la **disponibilidad**; no atiende consultas. **Réplica de lectura:** copia asíncrona que atiende lecturas, para el **rendimiento**.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| bootstrap script | script de arranque (del primer arranque) |
| override file | archivo que sobrescribe una configuración base |
| immutable infrastructure | infraestructura inmutable (se recrea, no se parchea) |
| cattle, not pets | infraestructura desechable: se recrea, no se repara |
| deployment runbook | guía de despliegue |

🎙️ *"Version 3 runs on EC2 with an IAM role and no stored credentials. The instance bootstraps itself with cloud-init, generates its own database password, pulls the image from ECR through the credential helper, and I manage it with Session Manager instead of SSH."*

## Siguiente

[Clase 79 — Vigía v3 (II): informe en S3, logs en CloudWatch y destrucción](clase-79-vigia-v3-s3-y-logs.md)
