# Clase 74 — S3: buckets, versiones y acceso

**Dónde:** tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** S3 guarda **objetos** (archivos con sus metadatos) en **buckets** con un nombre único en todo el mundo, y es prácticamente imposible que pierda tus datos: los pierdes tú, borrándolos o sobrescribiéndolos. Hoy subes y sincronizas archivos, compruebas las protecciones que trae de serie, deshaces un borrado con el **versionado**, automatizas la limpieza con el **ciclo de vida** y compartes un archivo privado con una **URL que caduca**.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las políticas de IAM, los prefijos como `reports/*`, que un `Deny` gana siempre y la trampa del ARN del bucket frente al de los objetos (clase 69).
> - `rsync` y las copias de seguridad (clase 20).
> - HTTP frente a HTTPS y `curl` (clase 32); los *heredoc* sin comillas (clase 07).

> 🔤 **Palabras nuevas de hoy:**
> - **bucket**: el contenedor de objetos; vive en una región y su nombre es único en el mundo.
> - **objeto / clave**: un archivo con sus metadatos / su nombre completo, como `reports/2026-10-20.json`.
> - **prefijo**: el principio de una clave hasta una `/`; lo que la consola enseña como "carpeta".
> - **Block Public Access** (BPA): los interruptores que impiden hacer público un bucket.
> - **versionado / marca de borrado**: guardar todas las versiones de cada objeto / lo que añade un borrado con versionado.
> - **ciclo de vida**: reglas que expiran o mueven objetos solos.
> - **URL prefirmada**: un enlace a un objeto privado, firmado con tus credenciales, que caduca.

## Objetivo

- Entender el modelo de S3: **buckets**, **objetos** y **claves**, y por qué las "carpetas" no existen.
- Subir, bajar y sincronizar archivos con `aws s3`, e inspeccionar los objetos con `aws s3api`.
- Comprobar las protecciones que S3 trae por defecto: **bloqueo del acceso público**, cifrado y ACL desactivadas.
- Usar el **versionado** para recuperar un archivo sobrescrito o borrado.
- Automatizar la limpieza con reglas de **ciclo de vida**, y conocer las **clases de almacenamiento**.
- Compartir un archivo privado con una **URL prefirmada** y escribir una **política de bucket**.

## Por qué importa

S3 es el disco duro de internet:
- copias de seguridad;
- logs;
- el estado de Terraform (fase 8);
- artefactos de los pipelines (fase 7);
- los informes de Vigía v3 (clase 79).

También es la fuente de muchas filtraciones famosas: buckets que alguien dejó públicos. Hoy aprendes a usarlo y a no salir en las noticias. Y es de los servicios que más pesan en el examen (almacenamiento y clases de almacenamiento).

## Costo esperado

> 💰 **Prácticamente 0 USD.** Unos KB durante una hora y unas decenas de peticiones. S3 Standard cuesta unos 0,023 USD por GB al mes; tus archivos de hoy no llegan a una milésima de céntimo.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan el mismo bucket.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto, la limpieza y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-74 && cd ~/my-devops-journey/labs/clase-74
CUENTA=$(aws sts get-caller-identity --query Account --output text)
B=lab-s3-$CUENTA-$(date +%s)
echo "$B"
```

El nombre tiene que ser único en el mundo. Tu número de cuenta y la hora lo garantizan.

## Las piezas

### Pieza 1 — Un bucket y su seguridad por defecto

Un **bucket** vive en **una región**, pero su nombre es **único en todo el mundo**: ninguna otra cuenta de AWS puede tener otro igual. Nombre en minúsculas, con números y guiones, de 3 a 63 caracteres.

Desde 2023, un bucket nuevo trae tres protecciones activadas:

| Protección | Qué hace |
|------------|----------|
| **Bloqueo del acceso público** (*Block Public Access*, BPA) | cuatro interruptores que impiden que una ACL o una política de bucket hagan público algo. Existe por bucket y para toda la cuenta |
| **ACL desactivadas** (*Object Ownership: Bucket owner enforced*) | el acceso se controla solo con políticas, no con las viejas ACL por objeto |
| **Cifrado por defecto (SSE-S3)** | todo se guarda cifrado con claves que gestiona AWS. Con **SSE-KMS** gestionas tú las claves con KMS |

🔮 **Predice** qué dirá cada una de las tres comprobaciones.

**Pruébalo:**

```bash
aws s3api create-bucket --bucket "$B"
aws s3api put-bucket-tagging --bucket "$B" --tagging 'TagSet=[{Key=Proyecto,Value=lab}]'
aws s3api get-public-access-block --bucket "$B"
aws s3api get-bucket-encryption --bucket "$B" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault'
aws s3api get-bucket-ownership-controls --bucket "$B" --query 'OwnershipControls.Rules[0].ObjectOwnership'
```

👀 **Qué deberías ver:** `{"Location": "/lab-s3-…"}` al crearlo; los cuatro interruptores del bloqueo (`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`) a `true`; `"SSEAlgorithm": "AES256"`, es decir, SSE-S3; y `"BucketOwnerEnforced"`, sin ACL. No has configurado nada de eso: viene así.

✋ **Sin mirar:** ¿qué tres protecciones trae un bucket nuevo sin que hagas nada?

<details>
<summary>Comprueba</summary>

El bloqueo del acceso público, las ACL desactivadas (el dueño del bucket es dueño de todo) y el cifrado por defecto con SSE-S3.
</details>

**En resumen:** nombre único en el mundo, región propia, y de serie: privado, sin ACL y cifrado.

### Pieza 2 — Objetos, claves y prefijos

- **Objeto:** un archivo (hasta 5 TB) más sus metadatos (tipo, fecha, etiquetas, versión…).
- **Clave:** el nombre completo del objeto, por ejemplo `reports/2026-10-20.json`.

S3 **no tiene carpetas**: es una lista plana de claves. La consola y `aws s3 ls` *muestran* carpetas cortando las claves en cada `/`, y a esos trozos los llaman **prefijos**. Por eso las políticas de IAM (clase 69) y las reglas de ciclo de vida hablan de prefijos (`reports/*`).

**Durabilidad:** S3 guarda cada objeto en varias zonas de disponibilidad y promete un 99,999999999 % (*once nueves*). En la práctica, S3 no pierde tus datos; los pierdes tú, borrándolos o sobrescribiéndolos. Para eso está el versionado (pieza 3).

🔮 **Predice:** ¿qué muestra el primer `ls` del bucket?

**Pruébalo:**

```bash
mkdir -p datos/reports
for d in 01 02 03; do
  echo "{\"dia\": \"2026-10-$d\", \"disponibilidad\": 99.$d}" > "datos/reports/2026-10-$d.json"
done
echo "versión 1" > datos/notas.txt
aws s3 sync datos/ "s3://$B/"
aws s3 ls "s3://$B/"
aws s3 ls "s3://$B/" --recursive --human-readable --summarize
aws s3api head-object --bucket "$B" --key reports/2026-10-01.json \
  --query '[ContentLength,ContentType,ServerSideEncryption]' --output text
aws s3 sync datos/ "s3://$B/"
echo '{"dia": "2026-10-03", "disponibilidad": 97.5}' > datos/reports/2026-10-03.json
aws s3 sync datos/ "s3://$B/"
```

👀 **Qué deberías ver:**
- el primer `sync`, cuatro líneas `upload: …`;
- el `ls`, `PRE reports/` y `notas.txt`: `PRE` significa prefijo, una "carpeta" que solo existe porque hay claves que empiezan así;
- el `ls --recursive`, las cuatro claves completas y, al final, `Total Objects: 4`;
- `head-object`, los metadatos sin descargar el archivo: el tamaño, `application/json` (la CLI lo dedujo de la extensión) y `AES256`;
- el segundo `sync`, nada: no ha cambiado nada;
- el tercero, una sola subida, la del archivo cambiado.

`sync` sube solo lo que ha cambiado, como `rsync` (clase 20). Es la forma habitual de publicar una web estática o de hacer copias de seguridad.

✋ **Sin mirar:** ¿qué es `reports/` para S3?

<details>
<summary>Comprueba</summary>

Un prefijo: el principio de varias claves. No existe como carpeta; si borras todos los objetos que empiezan así, desaparece.
</details>

**En resumen:** objetos con claves en una lista plana; las "carpetas" son prefijos; `sync` sube solo lo que cambió.

### Pieza 3 — El versionado: deshacer un error

Con el **versionado** activado:
- **Sobrescribir** crea una versión nueva; la anterior se conserva.
- **Borrar** solo añade una **marca de borrado** (*delete marker*). El objeto "desaparece", pero sus versiones siguen ahí y se puede recuperar.

Una vez activado, el versionado solo se puede **suspender**, no desactivar. Y cada versión ocupa (y cobra) su espacio.

🔮 **Predice:** ¿cuántas versiones tendrá `notas.txt`, y qué `VersionId` tendrá la primera?

**Pruébalo:**

```bash
aws s3api put-bucket-versioning --bucket "$B" --versioning-configuration Status=Enabled
echo "versión 2" > datos/notas.txt && aws s3 cp datos/notas.txt "s3://$B/notas.txt"
echo "versión 3" > datos/notas.txt && aws s3 cp datos/notas.txt "s3://$B/notas.txt"
aws s3api list-object-versions --bucket "$B" --prefix notas.txt \
  --query 'Versions[].[VersionId,IsLatest,LastModified]' --output table
```

👀 **Qué deberías ver:** tres versiones; la más reciente con `IsLatest` `True`, y la primera con `VersionId` **`null`**: se subió antes de activar el versionado.

Ahora "bórralo" y recupéralo:

```bash
aws s3 rm "s3://$B/notas.txt"
aws s3 ls "s3://$B/"
aws s3api list-object-versions --bucket "$B" --prefix notas.txt \
  --query '{versiones: length(Versions), marcas: DeleteMarkers[].[VersionId,IsLatest]}'
MARCA=$(aws s3api list-object-versions --bucket "$B" --prefix notas.txt \
  --query 'DeleteMarkers[?IsLatest].VersionId' --output text)
aws s3api delete-object --bucket "$B" --key notas.txt --version-id "$MARCA"
aws s3 cp "s3://$B/notas.txt" -
V1=$(aws s3api list-object-versions --bucket "$B" --prefix notas.txt --query 'Versions[-1].VersionId' --output text)
aws s3api get-object --bucket "$B" --key notas.txt --version-id "$V1" /tmp/notas-v1.txt
cat /tmp/notas-v1.txt
```

👀 **Qué deberías ver:** tras el `rm`, `notas.txt` ya no aparece en `ls`, pero hay `3` versiones y una marca de borrado con `IsLatest` `true`. Al borrar la marca, `aws s3 cp … -` imprime `versión 3`. Y la versión más antigua (las versiones salen de la más nueva a la más antigua, así que es la última de la lista, `[-1]`) dice `versión 1`. En Vigía (clase 79), el versionado protege los informes de un `report` con errores que los sobrescriba.

✋ **Sin mirar:** con versionado, ¿qué hace realmente `aws s3 rm`?

<details>
<summary>Comprueba</summary>

Añade una marca de borrado encima de las versiones. Las versiones siguen ahí; borrando la marca, el objeto vuelve.
</details>

**En resumen:** con versionado, sobrescribir crea versiones y borrar pone una marca; las dos cosas se deshacen.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, recupera el nombre del bucket: `cd ~/my-devops-journey/labs/clase-74 && B=$(aws s3 ls | awk '/lab-s3-/{print $3; exit}') && echo "$B"`.

### Pieza 4 — El ciclo de vida y las clases de almacenamiento

Las reglas de **ciclo de vida** automatizan lo que harías a mano: **expirar** objetos (los temporales, al día), **borrar** versiones antiguas y **mover** objetos a clases más baratas cuando ya no se leen.

| Clase | Para qué | Detalle |
|-------|----------|---------|
| **S3 Standard** | datos que se leen a menudo | la de por defecto |
| **S3 Intelligent-Tiering** | patrones de acceso desconocidos | mueve cada objeto de nivel según su uso, por una pequeña cuota |
| **S3 Standard-IA** (*Infrequent Access*) | se lee poco, pero hay que tenerlo al momento | más barata de guardar y más cara de leer; mínimo 30 días |
| **S3 One Zone-IA** | como la anterior, en una sola zona | más barata; si cae esa zona, se pierden los datos. Solo para lo que puedas regenerar |
| **S3 Glacier Instant Retrieval** | archivo que se lee pocas veces, pero al instante | |
| **S3 Glacier Flexible Retrieval** | archivo | recuperar tarda de minutos a horas |
| **S3 Glacier Deep Archive** | archivo de años (normativas, cumplimiento) | la más barata (unos 0,001 USD/GB-mes); recuperar tarda hasta 12 h o más |

Para el examen, conviene conocer también: **MFA Delete** (exige MFA para borrar versiones; solo lo activa el raíz), **Object Lock** (objetos que nadie puede borrar durante un plazo, *WORM*) y la **replicación** (copia automática a otro bucket, en la misma región o en otra). Y otros servicios de almacenamiento:

| Servicio | Qué es |
|----------|--------|
| **EBS** | disco de bloque de una EC2 (clase 72) |
| **EFS** | sistema de archivos NFS compartido entre muchas instancias Linux |
| **FSx** | sistemas de archivos gestionados: Windows File Server, Lustre… |
| **Storage Gateway** | conecta el almacenamiento de tu centro de datos con S3, con una caché local |
| **AWS Backup** | copias de seguridad centralizadas de varios servicios |

**Pruébalo.** Crea `ciclo.json`:

```json
{
  "Rules": [
    {"ID": "borrar-temporales", "Status": "Enabled",
     "Filter": {"Prefix": "tmp/"}, "Expiration": {"Days": 1}},
    {"ID": "informes-a-acceso-infrecuente", "Status": "Enabled",
     "Filter": {"Prefix": "reports/"}, "Transitions": [{"Days": 30, "StorageClass": "STANDARD_IA"}]},
    {"ID": "versiones-viejas", "Status": "Enabled",
     "Filter": {"Prefix": ""}, "NoncurrentVersionExpiration": {"NoncurrentDays": 7}}
  ]
}
```

```bash
aws s3api put-bucket-lifecycle-configuration --bucket "$B" --lifecycle-configuration file://ciclo.json
aws s3api get-bucket-lifecycle-configuration --bucket "$B" --query 'Rules[].[ID,Status]' --output text
```

👀 **Qué deberías ver:** las tres reglas con `Enabled`. **`borrar-temporales`**: lo que esté en `tmp/` se borra al día. **`informes-a-acceso-infrecuente`**: los informes pasan a Standard-IA a los 30 días. **`versiones-viejas`**: las versiones antiguas desaparecen a los 7 días de dejar de ser las actuales. S3 aplica las reglas una vez al día, en segundo plano: no verás el efecto hoy. Lo que importa es saber escribirlas, porque sin ellas el versionado acumula versiones (y coste) para siempre.

✋ **Sin mirar:** tienes que guardar 7 años unos registros que casi nadie leerá. ¿Qué clase usas?

<details>
<summary>Comprueba</summary>

S3 Glacier Deep Archive: la más barata, con recuperación de hasta 12 horas o más.
</details>

**En resumen:** reglas por prefijo que expiran, mueven y limpian versiones; la clase depende de cuánto y con qué prisa se lee.

### Pieza 5 — Compartir sin hacer público: URLs prefirmadas

Para compartir un objeto privado durante un rato, sin hacerlo público, hay **URLs prefirmadas**: una URL firmada con tus credenciales que caduca sola. Quien la tenga puede descargar ese objeto, y nada más, hasta que caduque.

🔮 **Predice:** ¿qué pasa con la URL prefirmada pasado el minuto?

**Pruébalo:**

```bash
URL=$(aws s3 presign "s3://$B/reports/2026-10-01.json" --expires-in 60)
echo "$URL"
curl -s "$URL"; echo
curl -s "https://$B.s3.amazonaws.com/reports/2026-10-01.json" | head -c 300; echo
```

Espera un minuto y repite el primer `curl`.

👀 **Qué deberías ver:** la URL, con `X-Amz-Signature` (tu firma) y `X-Amz-Expires=60` (su caducidad); con ella, el JSON del informe. La URL normal da `<Code>AccessDenied</Code>`: el objeto es privado. Pasado el minuto, la prefirmada también: `AccessDenied` con el mensaje *Request has expired*. Es la forma correcta de que alguien descargue un informe concreto sin tocar los permisos del bucket.

✋ **Sin mirar:** ¿qué permisos tiene quien recibe una URL prefirmada?

<details>
<summary>Comprueba</summary>

Solo descargar ese objeto, hasta que caduque la URL, y solo si tú (quien la firmó) tienes permiso para descargarlo.
</details>

**En resumen:** `aws s3 presign … --expires-in N` comparte un objeto privado durante N segundos.

### Pieza 6 — Una política de bucket útil

Quién puede acceder a un bucket se decide con dos tipos de política:
- **Política de IAM** (clase 69): va en el usuario o el rol y dice qué buckets puede tocar.
- **Política de bucket**: una política de **recurso**, pegada al bucket, que dice quién puede tocarlo. Lleva un campo `Principal`. Sirve para dar acceso a otras cuentas o a servicios, o para **imponer condiciones a todos**, como "solo por HTTPS".

🔮 **Predice:** con una política que deniega todo lo que no va por HTTPS, ¿funcionará la misma URL firmada por HTTP?

**Pruébalo.** Crea `solo-https.json` (con el nombre real de tu bucket gracias al *heredoc* sin comillas):

```bash
cat > solo-https.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SoloHTTPS",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::$B", "arn:aws:s3:::$B/*"],
      "Condition": {"Bool": {"aws:SecureTransport": "false"}}
    }
  ]
}
EOF
aws s3api put-bucket-policy --bucket "$B" --policy file://solo-https.json
URL=$(aws s3 presign "s3://$B/reports/2026-10-01.json" --expires-in 300)
curl -s "$URL"; echo
curl -s "${URL/https:/http:}" | head -c 300; echo
```

👀 **Qué deberías ver:** por HTTPS, el JSON; por HTTP, `AccessDenied`. La firma es válida, pero la política de bucket deniega todo lo que no va cifrado, y un `Deny` explícito gana siempre (clase 69). Fíjate en el `Principal: "*"`: una política de bucket dice **a quién** se aplica, porque está pegada al recurso. Conviene ponerla en casi todos los buckets.

✋ **Sin mirar:** ¿por qué una política de bucket lleva `Principal` y una de IAM no?

<details>
<summary>Comprueba</summary>

Porque la de bucket va pegada al recurso y tiene que decir a quién se aplica; la de IAM va pegada a la identidad, que ya es el principal.
</details>

**En resumen:** la política de bucket va en el recurso, con `Principal`; "solo HTTPS" es la que se pone casi siempre.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws s3api create-bucket --bucket …` (sin región en `us-east-1`) | crear un bucket |
| `aws s3 sync carpeta/ s3://bucket/` · `aws s3 cp` · `aws s3 ls --recursive` | subir, copiar, listar |
| `aws s3api head-object --bucket … --key …` | los metadatos de un objeto |
| `aws s3api put-bucket-versioning --versioning-configuration Status=Enabled` | activar el versionado |
| `aws s3api list-object-versions` · `delete-object --version-id` · `get-object --version-id` | versiones y marcas |
| `aws s3api put-bucket-lifecycle-configuration --lifecycle-configuration file://ciclo.json` | ciclo de vida |
| `aws s3 presign s3://bucket/clave --expires-in 60` | una URL prefirmada |
| `aws s3api put-bucket-policy --policy file://…` | política de bucket |
| `aws s3 rb s3://bucket` (vacío, versiones incluidas) | borrar el bucket |

## Rómpelo

**1. Un nombre que ya existe:**

```bash
aws s3api create-bucket --bucket test
```

`BucketAlreadyExists`: alguien, en algún lugar del mundo, ya tiene `test`. Los nombres son globales.

**2. La región que no se dice.**

```bash
aws s3api create-bucket --bucket "otro-$B" --create-bucket-configuration LocationConstraint=us-east-1
```

`InvalidLocationConstraint`. Es una rareza histórica: en `us-east-1` **no** se indica la región, y en cualquier otra es **obligatorio** (`LocationConstraint=eu-west-1`). Le pasa a todo el mundo una vez.

**3. Hacerlo público, a propósito:**

```bash
cat > publica.json <<EOF
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": "*",
  "Action": "s3:GetObject", "Resource": "arn:aws:s3:::$B/*"}]}
EOF
aws s3api put-bucket-policy --bucket "$B" --policy file://publica.json
```

`AccessDenied … because public policies are blocked by the BlockPublicPolicy block public access setting`. El bloqueo del acceso público te protege incluso de ti. Para servir una web estática se usa CloudFront delante del bucket, sin hacerlo público.

**4. Un bucket que no se deja borrar:**

```bash
aws s3 rm "s3://$B" --recursive
aws s3 rb "s3://$B"
```

`BucketNotEmpty`, aunque `aws s3 ls` no muestra nada. El `rm` solo añadió marcas de borrado: las versiones siguen ahí. Así se resuelve en "Destruir al terminar".

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Activa el bloqueo del acceso público **para toda la cuenta**, no solo para el bucket, y déjalo así: es una de las primeras cosas que se hacen en una cuenta seria.

> 🧩 **Ejemplo resuelto:** en la pieza 1, `get-public-access-block` mostró los cuatro interruptores del bucket.

**Ahora tú, con huecos:**
```bash
aws s3control put-public-access-block --account-id "$CUENTA" \
  --public-access-block-configuration BlockPublicAcls=____,IgnorePublicAcls=____,BlockPublicPolicy=____,RestrictPublicBuckets=____
aws s3control get-public-access-block --account-id "$CUENTA"
```

<details>
<summary>Pista</summary>

Los cuatro, igual que en el bucket. `s3control` es la parte de la CLI para los ajustes de S3 de la cuenta entera.
</details>

**2.** Sube un archivo directamente a otra clase de almacenamiento y compruébalo. ¿Por qué no conviene hacerlo con archivos que se leen a diario?

> 🧩 **Ejemplo resuelto:** el `head-object` de la pieza 2, con `--query '[ContentLength,ContentType,ServerSideEncryption]'`.

**Ahora tú, con huecos:**
```bash
aws s3 cp datos/notas.txt "s3://$B/archivo/notas.txt" --storage-class ____
aws s3api head-object --bucket "$B" --key archivo/notas.txt --query ____ --output text
```
Completa: «Dice ____. No conviene para lo que se lee a diario porque…».

<details>
<summary>Pista</summary>

Glacier Instant Retrieval se escribe `GLACIER_IR`, y el campo de la respuesta es `StorageClass`. Mira en la tabla de la pieza 4 para qué sirve cada clase: guardar barato suele significar leer caro.
</details>

**3.** Escribe la política de IAM que necesitará la EC2 de Vigía v3 para **subir** informes al bucket `vigia-informes-<cuenta>`, solo bajo `reports/`, y nada más. La usarás en la clase 79.

> 🧩 **Ejemplo resuelto:** `leer-informes.json` de la clase 69, con `s3:GetObject` sobre `arn:aws:s3:::$B/reports/*`.

**Ahora tú, con huecos:** guárdala como `subir-informes.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:____",
    "Resource": "arn:aws:s3:::vigia-informes-____/reports/*"
  }]
}
```

<details>
<summary>Pista</summary>

Subir un objeto es `PutObject`. No hace falta `ListBucket`: Vigía no necesita listar, solo escribir. El hueco del bucket es tu número de cuenta.
</details>

## Destruir al terminar

Un bucket con versionado hay que vaciarlo **versión a versión**:

```bash
aws s3api delete-bucket-policy --bucket "$B"
aws s3api list-object-versions --bucket "$B" --output json \
  --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}, Quiet: `true`}' > borrar.json
aws s3api delete-objects --bucket "$B" --delete file://borrar.json
aws s3 rb "s3://$B"
aws s3 ls | grep lab-s3
rm borrar.json
```

La consulta junta versiones y marcas de borrado en el formato que pide `delete-objects`; con `Quiet`, solo informa de los errores. El último `ls` no debe mostrar nada. Una llamada borra hasta 1000 objetos: para buckets más grandes, la consola tiene un botón *Empty*.

## Cierre

En `notas/fase-6/clase-74.md`:

1. ¿Por qué decimos que en S3 las carpetas no existen? ¿Qué consecuencias tiene para las políticas? *(2 líneas. Empieza así: «Porque S3 guarda una lista plana de claves:… Por eso las políticas se escriben con prefijos y…»)*
2. Borraste por error un archivo de un bucket con versionado. ¿Cómo lo recuperas? *(2 líneas. Empieza así: «El borrado solo añadió una marca de borrado… La busco con… y la borro con…»)*
3. ¿Qué diferencia hay entre una política de IAM y una política de bucket? Pon un caso para cada una. *(2–3 líneas. Empieza así: «La de IAM va en la identidad y dice qué puede hacer: por ejemplo,… La de bucket va en el recurso y…»)*
4. **Repaso (clase 73, sin mirar):** ¿qué significa un *connection refused* y qué un *timeout*? *(2 líneas. Empieza así: «Refused: el paquete llegó y nadie escucha… Timeout:…»)*

Después, escríbeme `examíname clase-74`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque S3 guarda una lista plana de claves. `reports/2026-10-20.json` es un solo nombre que contiene una barra. Las "carpetas" son prefijos que la consola y la CLI muestran cortando por `/`. Por eso las políticas y las reglas de ciclo de vida se escriben con prefijos y comodines (`arn:aws:s3:::bucket/reports/*`), no con "carpetas".

**2.** El borrado solo añadió una marca de borrado encima de las versiones. Se busca la marca con `list-object-versions` y se borra con `delete-object --version-id <marca>`: la última versión vuelve a ser la actual. Si quieres otra versión, la descargas con `get-object --version-id` y la vuelves a subir.

**3.** La de **IAM** va en la identidad y dice qué puede hacer: por ejemplo, la EC2 de Vigía puede subir a `reports/*`. La de **bucket** va en el recurso y dice quién puede usarlo y en qué condiciones; por eso lleva `Principal`. Casos: dar acceso a **otra cuenta** o a un servicio, o imponer una condición a **todos**, como "solo HTTPS".

**4.** *Refused*: el paquete llegó a la máquina y nadie escucha en ese puerto, así que la red está bien y falla el servicio. *Timeout*: algo descartó el paquete por el camino (un SG, una NACL o una ruta) o no hay camino.

**Reto 1:** los cuatro a `true`; `get-public-access-block` de la cuenta los muestra así.

**Reto 2:** `--storage-class GLACIER_IR` y `--query StorageClass`, que dice `GLACIER_IR`. No conviene para lo que se lee a diario porque cada lectura se cobra más cara que en Standard: guardas barato a cambio de leer caro.

**Reto 3:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::vigia-informes-123456789012/reports/*"
  }]
}
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| bucket / object / key / prefix | bucket / objeto / clave / prefijo |
| Block Public Access | bloqueo del acceso público |
| versioning / delete marker | versionado / marca de borrado |
| lifecycle rule / storage class | regla de ciclo de vida / clase de almacenamiento |
| presigned URL | URL prefirmada |
| bucket policy / resource-based policy | política de bucket / política basada en recursos |

🎙️ *"My buckets keep Block Public Access on, encryption by default, versioning to recover from mistakes and lifecycle rules to expire old versions. When someone needs a single file, I give them a presigned URL that expires instead of making anything public."*

## Siguiente

[Clase 75 — ECR: tu registro de imágenes](clase-75-ecr.md)
