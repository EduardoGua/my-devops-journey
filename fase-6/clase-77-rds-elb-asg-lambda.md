# Clase 77 — RDS, balanceadores, Auto Scaling y Lambda

**Dónde:** consola (solo mirar) + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** Vigía v3 corre en **una** EC2 con todo dentro: si cae, cae todo, y si llega el triple de tráfico, no crece. En producción se usan cuatro piezas: **RDS** (la base de datos gestionada, con copia en otra zona), un **balanceador** (un único punto de entrada que reparte entre instancias sanas), **Auto Scaling** (las instancias crecen y se reparan solas) y **Lambda** (código sin servidor, para tareas cortas). Hoy conoces las tres primeras mirando sin pagar, y pruebas Lambda de verdad, porque es casi gratis.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El modelo de capas (clase 26): capa 4 frente a capa 7.
> - Las subredes públicas y privadas en varias zonas (clase 71); un SG como origen de otro (clase 73).
> - EC2, *user-data*, roles y la espera de la propagación de IAM (clase 72).
> - La retención de los grupos de logs (clase 76); la biblioteca estándar de Python (clase 45).

> 🔤 **Palabras nuevas de hoy:**
> - **RDS** (y **Aurora**): bases de datos relacionales gestionadas por AWS.
> - **Multi-AZ / réplica de lectura**: copia en espera en otra zona, para la disponibilidad / copia que atiende lecturas, para el rendimiento.
> - **ALB / NLB**: balanceador de capa 7 (HTTP) / de capa 4 (TCP/UDP).
> - **grupo de Auto Scaling / plantilla de lanzamiento**: un conjunto de instancias iguales / la receta para crearlas.
> - **Lambda**: código que se ejecuta cuando ocurre un evento, sin servidor que gestionar.
> - **arranque en frío** (*cold start*): el tiempo de preparar el entorno de una Lambda la primera vez.

## Objetivo

- Saber qué resuelven **RDS**, los **balanceadores** (ELB), **Auto Scaling** y **Lambda**, y cuándo usar cada uno.
- Diferenciar una base de datos en EC2 de una **gestionada**, y **Multi-AZ** de las **réplicas de lectura**.
- Dibujar la arquitectura "de producción" de Vigía, con todas estas piezas en su subred.
- Crear, invocar y romper una función **Lambda** pequeña: Vigía en versión *serverless*.
- Situar en el mapa el resto de servicios de cómputo y de bases de datos que pide el examen.

## Por qué importa

Vigía v3 corre en **una** EC2 con todo dentro: API, chequeo y PostgreSQL en contenedores. Es barato y suficiente para aprender, pero no es como se monta en una empresa:
- si esa instancia cae, cae todo;
- si llega el triple de tráfico, no crece.

Estas cuatro piezas son la respuesta de AWS a esos problemas. En una entrevista te pedirán "¿cómo lo harías en producción?", y en el examen son preguntas seguras. Hoy las conoces sin pagar sus facturas: RDS y los balanceadores cobran por hora. Lambda, en cambio, la pruebas de verdad, porque es casi gratis.

## Costo esperado

> 💰 **0 USD.** La consola no cobra por mirar. Lambda tiene, **siempre gratis**, 1 millón de invocaciones y 400 000 GB-segundo al mes: hoy usarás unas pocas decenas de invocaciones.

## Cómo va esta clase

Seis piezas. Las cuatro primeras son de mirar y diseñar (en la consola, sin crear nada); las dos últimas, de crear una Lambda. En cada una lees **una** idea y la pruebas enseguida.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 40 min); el segundo, las **piezas 5 y 6**, el Rómpelo, el reto, la limpieza y el cierre.

## Las piezas

### Pieza 1 — RDS: la base de datos gestionada

**RDS** (*Relational Database Service*) te da PostgreSQL, MySQL, MariaDB, SQL Server, Oracle o Db2 **gestionados**. **Aurora** es la versión de AWS compatible con MySQL y PostgreSQL, más rápida y que escala mejor.

| Quién se encarga | PostgreSQL en tu EC2 (o en un contenedor) | RDS |
|------------------|-------------------------------------------|-----|
| instalar y parchear el sistema y el motor | tú | AWS (tú eliges la ventana de mantenimiento) |
| copias de seguridad y restaurar a un momento concreto | tú | AWS, automáticas |
| alta disponibilidad | tú, y es difícil | una casilla: **Multi-AZ** |
| escalar | tú | cambiar el tipo de instancia o añadir réplicas |
| el esquema, las consultas, los usuarios, los datos | tú | **tú** |

Para el examen, no confundas:
- **Multi-AZ:** una copia en **espera** en otra zona, replicada de forma **síncrona**. Si la principal falla, RDS cambia a la copia solo. Sirve para la **disponibilidad**; la copia no atiende consultas.
- **Réplicas de lectura:** copias **asíncronas** que sí atienden consultas de lectura. Sirven para el **rendimiento**, y pueden estar en otra región.

Una base de datos de RDS vive en un **grupo de subredes** (*DB subnet group*) con subredes **privadas** en al menos dos zonas, sin acceso público y con un security group que solo admite el 5432 **desde el SG de la aplicación** (clase 73). Es el criterio de salida de la clase 71 hecho servicio.

Otras bases de datos que pide el examen:

| Servicio | Tipo | Para qué |
|----------|------|----------|
| **DynamoDB** | NoSQL clave-valor, *serverless* | millones de lecturas por segundo con latencia de milisegundos; sin servidores que gestionar |
| **ElastiCache** | en memoria (Redis, Memcached) | caché delante de la base de datos, sesiones |
| **Redshift** | almacén de datos (*data warehouse*) | análisis sobre grandes volúmenes |
| **DocumentDB** · **Neptune** | documentos (compatible con MongoDB) · grafos | casos específicos |
| **DMS** + **SCT** | migración | mover una base de datos a AWS (DMS) y convertir su esquema a otro motor (SCT) |

**Pruébalo, sin crear nada.** En la consola, como `eduardo`: **RDS → Create database**, elige PostgreSQL y recorre la página. Busca qué plantillas ofrece (*Production*, *Dev/Test*, *Free tier*), dónde se activa Multi-AZ, qué valor trae *Public access* y qué pide en *Connectivity*. Anota tres ajustes que tendrías que decidir para la base de datos de Vigía. **Cancel**.

👀 **Qué deberías ver:** las tres plantillas; Multi-AZ en *Availability and durability*; *Public access* en **No**; y en *Connectivity*, la VPC, el grupo de subredes y el security group.

✋ **Sin mirar:** la base de datos principal falla. ¿Qué la sustituye en segundos, Multi-AZ o una réplica de lectura?

<details>
<summary>Comprueba</summary>

Multi-AZ: su copia en espera, síncrona, toma el relevo sola. Una réplica de lectura es para repartir lecturas.
</details>

**En resumen:** RDS te quita parches, copias y alta disponibilidad; Multi-AZ para disponibilidad, réplicas para rendimiento.

### Pieza 2 — Balanceadores: un solo punto de entrada

Un **balanceador de carga** (ELB, *Elastic Load Balancing*) recibe el tráfico y lo reparte entre varios destinos, sanos y en varias zonas, y hace **comprobaciones de salud**: si un destino no responde, deja de mandarle tráfico.

| Tipo | Capa | Para qué |
|------|------|----------|
| **ALB** (*Application*) | 7 (HTTP/HTTPS) | webs y APIs: reparte por ruta (`/api/*`) o por nombre (`api.ejemplo.com`), termina TLS con certificados gratuitos de ACM |
| **NLB** (*Network*) | 4 (TCP/UDP) | tráfico no HTTP, muchísimas conexiones, IP fija |
| **GWLB** (*Gateway*) | 3 | meter firewalls y otros dispositivos de terceros en el camino |

Recuerda el modelo de capas de la clase 26: un ALB entiende HTTP, un NLB solo ve paquetes y puertos.

**Pruébalo, sin crear nada:** **EC2 → Load Balancers → Create load balancer**. Compara las tres tarjetas (ALB, NLB, GWLB) y entra en el ALB para ver qué pide. **Cancel**.

👀 **Qué deberías ver:** al menos **dos zonas** (con una subred en cada una), los *listeners* (puerto y protocolo de entrada) y los *target groups* (a quién reparte, con su comprobación de salud).

✋ **Sin mirar:** quieres repartir por ruta, `/api/*` a un grupo y `/` a otro. ¿ALB o NLB?

<details>
<summary>Comprueba</summary>

ALB: es de capa 7 y entiende HTTP. Un NLB solo ve puertos y paquetes.
</details>

**En resumen:** el balanceador reparte entre destinos sanos de varias zonas; ALB para HTTP, NLB para TCP/UDP.

### Pieza 3 — Auto Scaling: elasticidad de verdad

Un **grupo de Auto Scaling** (ASG) mantiene un número de instancias iguales, creadas a partir de una **plantilla de lanzamiento** (*launch template*: AMI, tipo, *user-data*, SG y rol, todo lo de la clase 72):

- **mínimo / deseado / máximo:** por ejemplo, 2 / 2 / 6;
- **autorreparación:** si una instancia falla su comprobación de salud, la termina y lanza otra;
- **políticas de escalado:** por ejemplo, "mantén la CPU media al 50 %" (*target tracking*). Si sube el tráfico, añade instancias; si baja, las quita y deja de pagarlas.

Con un ALB delante, las instancias nuevas reciben tráfico solas. Esto es lo que el examen llama **elasticidad**: la capacidad sigue a la demanda.

**Pruébalo, sin crear nada:** **EC2 → Auto Scaling groups → Create Auto Scaling group**. El primer paso pide una *launch template*: pulsa *Create a launch template* y recorre sus campos. **Cancel** en las dos pestañas.

👀 **Qué deberías ver:** en la plantilla, los campos de tu `run-instances` de la clase 72: la AMI, el tipo de instancia, la red y los security groups, el perfil de IAM, las opciones de metadatos y, en *Advanced details*, el *user-data*.

✋ **Sin mirar:** una instancia de un ASG falla su comprobación de salud. ¿Qué hace el grupo?

<details>
<summary>Comprueba</summary>

La termina y lanza otra igual a partir de la plantilla: se repara solo.
</details>

**En resumen:** un ASG = instancias iguales desde una plantilla, entre un mínimo y un máximo, que se reparan y escalan solas.

### Pieza 4 — La arquitectura de producción de Vigía

Con las piezas 1 a 3 y la red de la clase 71, ya puedes colocar cada servicio en su sitio. Hay errores claros; el más típico, una base de datos en una subred pública.

**Pruébalo, en papel.** Copia esta plantilla en `notas/fase-6/clase-77.md` y rellena los huecos:

```
ALB                 en subredes ____ de las zonas A y B     SG: ____ desde internet
EC2 de la API       en subredes ____, dentro de un ____     SG: 8000 solo desde el SG del ____
RDS PostgreSQL ____ en subredes ____ de las zonas A y B     SG: 5432 solo desde el SG de ____
El chequeo:         ____ (no va en el grupo de la API, porque…)
Para salir a ECR, CloudWatch y S3 desde las privadas: ____ (o endpoints)
```

<details>
<summary>Compara con este modelo (ábrelo después de rellenar el tuyo)</summary>

```
                    Route 53 (vigia.ejemplo.com)
                               │
                ┌──────────────▼──────────────┐
                │ ALB  (subredes públicas A y B)│  SG: 443 desde internet
                └──────────────┬──────────────┘
          ┌────────────────────┴────────────────────┐
   zona A │ subred privada                   zona B │ subred privada
   ┌──────▼──────┐                           ┌──────▼──────┐
   │ EC2 API     │  ← grupo de Auto Scaling → │ EC2 API     │  SG: 8000 solo desde el SG del ALB
   └──────┬──────┘    (el chequeo, aparte)    └──────┬──────┘
          └────────────────────┬────────────────────┘
                ┌──────────────▼──────────────┐
                │ RDS PostgreSQL Multi-AZ      │  SG: 5432 solo desde el SG de la API
                │ (subredes privadas A y B)    │
                └──────────────────────────────┘
   + NAT Gateway (o endpoints) para que las privadas descarguen de ECR, logs a CloudWatch, informes a S3
```

El chequeo no debería escalar como la API: dos chequeos duplicarían los resultados. Iría aparte, como una sola tarea programada (EventBridge + Lambda, o una tarea de ECS). No hay un único dibujo correcto, pero este evita los errores claros.
</details>

✋ **Sin mirar:** ¿por qué el chequeo de Vigía no va en el mismo grupo de Auto Scaling que la API?

<details>
<summary>Comprueba</summary>

Porque si el grupo tiene dos o más instancias, habría dos o más chequeos revisando las mismas URLs y duplicando los resultados. El chequeo es una tarea única y programada.
</details>

**En resumen:** ALB en las públicas, API en un ASG en las privadas, RDS Multi-AZ en las privadas, SG encadenados, y el chequeo aparte.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 5 — Lambda: el rol y su grupo de logs

**Lambda** ejecuta una función cuando ocurre un **evento**: una petición HTTP (con API Gateway o una *function URL*), un archivo nuevo en S3, un mensaje en una cola SQS o un horario de EventBridge. No hay servidor que parchear ni que apagar. Se paga **por invocación** y por **GB-segundo** (memoria × duración). Si nadie la llama, cuesta 0.

Como una EC2, Lambda necesita un **rol**, con una política de confianza para `lambda.amazonaws.com` y permiso para escribir sus logs. Y escribe en `/aws/lambda/<nombre>`: si ese grupo no existe, lo crea él… sin retención (clase 76). Así que lo creas tú antes.

**Pruébalo:**

```bash
mkdir -p ~/my-devops-journey/labs/clase-77 && cd ~/my-devops-journey/labs/clase-77
CUENTA=$(aws sts get-caller-identity --query Account --output text)
cat > confianza-lambda.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role --role-name lab-lambda --assume-role-policy-document file://confianza-lambda.json \
  --tags Key=Proyecto,Value=lab --query Role.Arn --output text
aws iam attach-role-policy --role-name lab-lambda \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws logs create-log-group --log-group-name /aws/lambda/vigia-mini --tags Proyecto=lab
aws logs put-retention-policy --log-group-name /aws/lambda/vigia-mini --retention-in-days 1
```

👀 **Qué deberías ver:** el ARN del rol (`arn:aws:iam::<cuenta>:role/lab-lambda`) y nada más: las demás órdenes no imprimen nada cuando van bien.

✋ **Sin mirar:** ¿por qué creas tú el grupo de logs de la Lambda, si ella lo crearía sola?

<details>
<summary>Comprueba</summary>

Porque ella lo crearía sin retención, guardando los logs para siempre y cobrando cada mes.
</details>

**En resumen:** rol con confianza en `lambda.amazonaws.com` + `AWSLambdaBasicExecutionRole`, y su grupo de logs con retención antes de crearla.

### Pieza 6 — Lambda: el código, invocarla y el arranque en frío

| | EC2 | Contenedores (ECS, EKS, Fargate) | Lambda |
|---|---|---|---|
| Qué gestionas | el servidor entero | la imagen y el orquestador (con **Fargate**, sin servidores) | solo el código |
| Duración | indefinida | indefinida | **15 minutos** como máximo por invocación |
| Pagas | por hora encendida | por recursos asignados | por uso real |
| Ideal para | lo que necesita control total | servicios que corren siempre | tareas cortas y eventos |

Para el examen, cómputo y contenedores: **ECS** (el orquestador de contenedores de AWS), **EKS** (Kubernetes gestionado; lo verás en la fase 9), **Fargate** (contenedores sin gestionar servidores, para ECS y EKS) y **Elastic Beanstalk** (subes tu aplicación y AWS monta todo lo demás, PaaS).

**Pruébalo.** Crea `lambda_function.py`, una función que comprueba una URL, como `vigia check`, pero sin servidor:

```python
"""vigia-mini: comprueba una URL, como Vigía, pero dentro de Lambda."""
import json
import time
import urllib.error
import urllib.request


def lambda_handler(event, context):
    url = event.get("url", "https://example.com")
    peticion = urllib.request.Request(url, headers={"User-Agent": "Vigia-mini/1.0"})
    inicio = time.monotonic()
    try:
        with urllib.request.urlopen(peticion, timeout=5) as respuesta:
            codigo = respuesta.status
    except urllib.error.HTTPError as e:
        codigo = e.code
    except (urllib.error.URLError, TimeoutError) as e:
        resultado = {"url": url, "up": False, "status_code": 0, "error": str(e)}
        print(json.dumps(resultado))
        return resultado
    resultado = {"url": url, "up": 200 <= codigo < 400, "status_code": codigo,
                 "seconds": round(time.monotonic() - inicio, 3)}
    print(json.dumps(resultado))
    return resultado
```

Solo usa la biblioteca estándar (clase 45): `requests` no viene en Lambda, y añadirla obliga a empaquetar dependencias. Lambda llama a `lambda_handler(event, context)`: `event` es el JSON con el que la invocas. Lo que imprimes con `print` va a CloudWatch Logs.

Pruébala en local, empaquétala, créala e invócala:

```bash
python3 -c 'from lambda_function import lambda_handler; print(lambda_handler({"url": "https://example.com"}, None))'
python3 -m zipfile -c funcion.zip lambda_function.py
aws lambda create-function --function-name vigia-mini --runtime python3.14 \
  --handler lambda_function.lambda_handler --role "arn:aws:iam::$CUENTA:role/lab-lambda" \
  --zip-file fileb://funcion.zip --timeout 10 --memory-size 128 --tags Proyecto=lab \
  --query '[FunctionName,Runtime,State]' --output text
aws lambda wait function-active-v2 --function-name vigia-mini
aws lambda invoke --function-name vigia-mini --cli-binary-format raw-in-base64-out \
  --payload '{"url": "https://example.com"}' salida.json
cat salida.json; echo
aws lambda invoke --function-name vigia-mini --cli-binary-format raw-in-base64-out \
  --payload '{"url": "https://ejemplo.invalid"}' salida.json
cat salida.json; echo
aws logs tail /aws/lambda/vigia-mini --since 10m
```

Si `create-function` falla con *The role defined for the function cannot be assumed by Lambda*, es la propagación de IAM (clase 72): espera 10 segundos y repite.

🔮 **Predice:** en los logs, además de tu `print`, ¿qué líneas añade Lambda?

👀 **Qué deberías ver:** en local, `{'url': 'https://example.com', 'up': True, 'status_code': 200, 'seconds': …}`; `vigia-mini python3.14 Pending` al crearla; en `salida.json`, `"up": true` para `example.com` y `"up": false` con `"status_code": 0` y el error para `ejemplo.invalid`. En los logs, tus `print` y las líneas `START`, `END` y `REPORT`. La de `REPORT` dice la duración, la duración **facturada**, la memoria usada y, en la primera invocación, el *Init Duration*: el **arranque en frío**. Invoca otra vez y compara: la segunda no lo lleva.

✋ **Sin mirar:** ¿cuánto puede durar como máximo una invocación de Lambda?

<details>
<summary>Comprueba</summary>

15 minutos. Lo que tarde más no es para Lambda.
</details>

**En resumen:** `lambda_handler(event, context)` en un zip, `create-function` con su rol, `invoke` con un JSON; la primera invocación paga el arranque en frío.

## Tu chuleta de la clase

| Escribes o abres | Qué hace |
|------------------|----------|
| **RDS → Create database** · **EC2 → Load Balancers** · **Auto Scaling groups** | los asistentes, para mirar |
| Multi-AZ · réplica de lectura | disponibilidad · rendimiento |
| ALB (capa 7) · NLB (capa 4) | balanceadores |
| `python3 -m zipfile -c funcion.zip lambda_function.py` | empaquetar sin instalar nada |
| `aws lambda create-function --function-name … --runtime python3.14 --handler archivo.funcion --role … --zip-file fileb://…` | crear una Lambda |
| `aws lambda invoke --function-name … --cli-binary-format raw-in-base64-out --payload '{…}' salida.json` | invocarla |
| `aws lambda update-function-configuration --timeout …` | cambiar su configuración |
| `aws logs tail /aws/lambda/<nombre>` | sus logs: `START`, `END`, `REPORT` |
| `aws lambda delete-function` | borrarla |

## Rómpelo

**1. Se acabó el tiempo.** Baja el tiempo máximo a 1 segundo y pídele una IP que no responde:

```bash
aws lambda update-function-configuration --function-name vigia-mini --timeout 1 --query Timeout
aws lambda wait function-updated-v2 --function-name vigia-mini
aws lambda invoke --function-name vigia-mini --cli-binary-format raw-in-base64-out \
  --payload '{"url": "http://10.255.255.1"}' salida.json
cat salida.json; echo
```

`Task timed out after 1.00 seconds`: Lambda mata la función al llegar al límite, aunque tu código tuviera su propio *timeout* de 5 s. Devuélvelo a 10 (`--timeout 10`). El límite máximo es de 15 minutos: lo que tarde más no es para Lambda.

**2. El manejador que no existe:**

```bash
aws lambda update-function-configuration --function-name vigia-mini --handler lambda_function.handler --query Handler
aws lambda wait function-updated-v2 --function-name vigia-mini
aws lambda invoke --function-name vigia-mini --cli-binary-format raw-in-base64-out --payload '{}' salida.json
cat salida.json; echo
```

`Runtime.HandlerNotFound`: el manejador es `archivo.función`, y `handler` no existe en tu archivo. Devuélvelo a `lambda_function.lambda_handler`.

**3. El payload sin la opción mágica:**

```bash
aws lambda invoke --function-name vigia-mini --payload '{"url": "https://example.com"}' salida.json
```

La CLI v2 espera el *payload* en base64 y falla al intentar decodificar tu JSON. `--cli-binary-format raw-in-base64-out` le dice que lo mandas tal cual. Es un clásico de la CLI v2; puedes dejarlo fijo con `aws configure set cli_binary_format raw-in-base64-out`.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **¿Cuánto costaría de verdad?** `vigia-mini` se ejecuta **cada minuto** durante un mes, con 128 MB y unos 0,5 s por invocación. ¿Superarías lo gratuito (1 millón de invocaciones y 400 000 GB-segundo al mes)?

> 🧩 **Ejemplo resuelto:** en **una hora**: 60 invocaciones × 0,5 s × 0,125 GB = 3,75 GB-segundo.

**Ahora tú, con huecos:** «Invocaciones al mes: 60 × 24 × ____ = ____. GB-segundo: ____ × 0,5 × 0,125 = ____. ¿Supera lo gratuito? ____. La t3.small de Vigía, 24/7, cuesta unos ____ USD al mes».

<details>
<summary>Pista</summary>

128 MB son 0,125 GB. Un mes de 30 días. El precio de la t3.small está en la pieza 5 de la clase 68.
</details>

**2.** ¿Por qué Vigía v3 **no** es una Lambda?

> 🧩 **Ejemplo resuelto:** la tabla de la pieza 6: Lambda dura 15 minutos como máximo por invocación y es ideal para tareas cortas y eventos.

**Ahora tú, con huecos:** «La API tiene que ____, con latencia estable, y Lambda… La base de datos PostgreSQL necesita ____. La parte que sí encajaría en Lambda es ____, porque…».

<details>
<summary>Pista</summary>

Piensa en cuál de las tres piezas de Vigía (la API, el chequeo y la base de datos) es una tarea corta que se repite con un horario.
</details>

**3.** Lee en la documentación de **EventBridge Scheduler** cómo ejecutarías `vigia-mini` cada 5 minutos. ¿Qué necesitaría el *scheduler* para poder invocar tu función?

> 🧩 **Ejemplo resuelto:** la pieza 5: para escribir sus logs, la Lambda necesita un rol con confianza en `lambda.amazonaws.com` y una política con los permisos.

**Ahora tú, con huecos:** «El *scheduler* necesita un ____ con política de confianza para `____.amazonaws.com` y permiso `lambda:____` sobre el ARN de la función».

<details>
<summary>Pista</summary>

En AWS, todo servicio que actúa sobre otro lo hace con un rol. El permiso para ejecutar una función se llama *invoke*.
</details>

## Destruir al terminar

```bash
aws lambda delete-function --function-name vigia-mini
aws logs delete-log-group --log-group-name /aws/lambda/vigia-mini
aws iam detach-role-policy --role-name lab-lambda \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name lab-lambda
aws lambda list-functions --query 'Functions[].FunctionName' --output text
```

La última orden no debe mostrar `vigia-mini`. `funcion.zip` y `salida.json` puedes borrarlos; `lambda_function.py`, guárdalo.

## Cierre

En `notas/fase-6/clase-77.md`:

1. ¿Qué diferencia hay entre Multi-AZ y una réplica de lectura en RDS? ¿Qué problema resuelve cada una? *(2 líneas. Empieza así: «Multi-AZ es una copia en espera, síncrona, en otra zona, que… Una réplica de lectura…»)*
2. ¿Qué aporta un ALB delante de un grupo de Auto Scaling? *(2 líneas. Empieza así: «Un único punto de entrada que reparte entre instancias sanas de varias zonas, y cuando el grupo añade o sustituye instancias…»)*
3. ¿Cuándo elegirías Lambda en lugar de una EC2 o un contenedor? ¿Y cuándo no? *(2 líneas. Empieza así: «Lambda, para tareas cortas que se disparan por eventos o por horario… No, para servicios que…»)*
4. **Repaso (clase 76, sin mirar):** ¿qué hace `treat-missing-data notBreaching` en una alarma? *(1–2 líneas. Empieza así: «Que, si en un periodo no llegan datos, la alarma…»)*

Después, escríbeme `examíname clase-77`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Pieza 4:** ALB en las subredes **públicas**, con 443 (o 80) desde internet; la API en las **privadas**, dentro de un **grupo de Auto Scaling**, con el 8000 solo desde el SG del **ALB**; RDS PostgreSQL **Multi-AZ** en las **privadas**, con el 5432 solo desde el SG de la **API**; el chequeo, **aparte**, como una tarea programada única (no escala con la API, porque duplicaría los resultados); y un **NAT Gateway** o endpoints para salir desde las privadas. El dibujo completo está en el modelo de la pieza 4.

**1.** **Multi-AZ:** una copia en espera, síncrona, en otra zona; si la principal falla, RDS cambia a ella automáticamente. Resuelve la **disponibilidad** y no atiende consultas. **Réplica de lectura:** una copia asíncrona que sí atiende lecturas. Resuelve el **rendimiento**: reparte la carga de lectura, incluso en otra región.

**2.** Un único punto de entrada, reparto del tráfico entre instancias sanas de varias zonas y comprobaciones de salud. Cuando el ASG añade, quita o sustituye instancias, el ALB las incorpora o las saca solo. También termina TLS con certificados gratuitos de ACM.

**3.** Lambda: tareas cortas (menos de 15 min) que se disparan por eventos o por horario, con carga irregular o baja. No pagas cuando no se usa y no hay servidor que mantener. No: servicios que deben estar siempre escuchando con latencia estable, procesos largos o que necesitan control del sistema operativo. Con carga alta y constante, una EC2 o un contenedor sale más barato.

**4.** Que, si en un periodo no llegan datos, la alarma lo trate como "por debajo del umbral" y se quede en `OK` (o vuelva a `OK`). Es lo adecuado para una métrica de errores: sin líneas de error, no hay errores.

**Reto 1:**
- **Invocaciones:** 60 × 24 × 30 = 43 200 al mes.
- **GB-segundo:** 43 200 × 0,5 s × 0,125 GB = 2 700 al mes.
- **Gratis:** las dos cifras quedan muy por debajo de lo gratuito, así que costaría **0 USD**.
- **Comparación:** la t3.small de Vigía, 24/7, cuesta unos 15 USD al mes.

**Reto 2:** la API tiene que **responder en cualquier momento**, con latencia estable, y la base de datos PostgreSQL necesita **un servidor que corra siempre**. Con Lambda, la API iría detrás de API Gateway, y la base de datos tendría que ser otro servicio (RDS o DynamoDB): es posible, pero es otra arquitectura. El **chequeo**, en cambio, sí encaja muy bien en Lambda: es una tarea corta que se repite cada minuto.

**Reto 3:** un **rol** con política de confianza para `scheduler.amazonaws.com` y permiso `lambda:InvokeFunction` sobre tu función.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| managed database / Multi-AZ / read replica | base de datos gestionada / despliegue multizona / réplica de lectura |
| load balancer / target group / health check | balanceador / grupo de destinos / comprobación de salud |
| Auto Scaling group / launch template | grupo de Auto Scaling / plantilla de lanzamiento |
| serverless / cold start | sin servidores / arranque en frío |
| event-driven | dirigido por eventos |
| elasticity | elasticidad |

🎙️ *"For production I'd put an Application Load Balancer in public subnets, the app in an Auto Scaling group in private subnets across two AZs, and PostgreSQL on RDS Multi-AZ, reachable only from the app's security group. Short scheduled jobs, like the checker, fit well in Lambda."*

## Siguiente

[Clase 78 — Vigía v3 (I): en EC2 con un rol IAM](clase-78-vigia-v3-ec2.md)
