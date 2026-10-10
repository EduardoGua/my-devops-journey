# Clase 77 — RDS, balanceadores, Auto Scaling y Lambda

**Dónde:** consola (solo mirar) + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

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

## Teoría

### RDS: la base de datos gestionada

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

### Balanceadores: un solo punto de entrada

Un **balanceador de carga** (ELB, *Elastic Load Balancing*):
- recibe el tráfico y lo reparte entre varios destinos, sanos y en varias zonas;
- hace **comprobaciones de salud**: si un destino no responde, deja de mandarle tráfico.

| Tipo | Capa | Para qué |
|------|------|----------|
| **ALB** (*Application*) | 7 (HTTP/HTTPS) | webs y APIs: reparte por ruta (`/api/*`) o por nombre (`api.ejemplo.com`), termina TLS con certificados gratuitos de ACM |
| **NLB** (*Network*) | 4 (TCP/UDP) | tráfico no HTTP, muchísimas conexiones, IP fija |
| **GWLB** (*Gateway*) | 3 | meter firewalls y otros dispositivos de terceros en el camino |

Recuerda el modelo de capas de la clase 26: un ALB entiende HTTP, un NLB solo ve paquetes y puertos.

### Auto Scaling: elasticidad de verdad

Un **grupo de Auto Scaling** (ASG) mantiene un número de instancias iguales, creadas a partir de una **plantilla de lanzamiento** (*launch template*: AMI, tipo, *user-data*, SG y rol, todo lo de la clase 72):

- **mínimo / deseado / máximo:** por ejemplo, 2 / 2 / 6;
- **autorreparación:** si una instancia falla su comprobación de salud, la termina y lanza otra;
- **políticas de escalado:** por ejemplo, "mantén la CPU media al 50 %" (*target tracking*). Si sube el tráfico, añade instancias; si baja, las quita y deja de pagarlas.

Con un ALB delante, las instancias nuevas reciben tráfico solas. Esto es lo que el examen llama **elasticidad**: la capacidad sigue a la demanda.

### Lambda: código sin servidores

**Lambda** ejecuta una función cuando ocurre un **evento**:
- una petición HTTP (con API Gateway o una *function URL*);
- un archivo nuevo en S3;
- un mensaje en una cola SQS;
- un horario de EventBridge.

No hay servidor que parchear ni que apagar. Se paga **por invocación** y por **GB-segundo** (memoria × duración). Si nadie la llama, cuesta 0.

| | EC2 | Contenedores (ECS, EKS, Fargate) | Lambda |
|---|---|---|---|
| Qué gestionas | el servidor entero | la imagen y el orquestador (con **Fargate**, sin servidores) | solo el código |
| Duración | indefinida | indefinida | **15 minutos** como máximo por invocación |
| Pagas | por hora encendida | por recursos asignados | por uso real |
| Ideal para | lo que necesita control total | servicios que corren siempre | tareas cortas y eventos |

Para el examen, cómputo y contenedores:
- **ECS:** el orquestador de contenedores de AWS.
- **EKS:** Kubernetes gestionado; lo verás en la fase 9.
- **Fargate:** contenedores sin gestionar servidores, para ECS y EKS.
- **Elastic Beanstalk:** subes tu aplicación y AWS monta todo lo demás (PaaS).

## Práctica guiada

### 1. Mirar sin comprar (20 min)

En la consola, como `eduardo`, abre estos asistentes y **no crees nada**:

1. **RDS → Create database:** elige PostgreSQL y recorre la página.
   - ¿Qué plantillas ofrece (*Production*, *Dev/Test*, *Free tier*)?
   - ¿Dónde se activa Multi-AZ?
   - ¿Qué valor trae *Public access*? Debe ser **No**.
   - ¿Qué pide en *Connectivity*: VPC, grupo de subredes y security group?

   Anota tres ajustes que tendrías que decidir para la base de datos de Vigía. **Cancel**.
2. **EC2 → Load Balancers → Create load balancer:** compara las tres tarjetas (ALB, NLB, GWLB). Entra en el ALB y mira qué pide: al menos **dos zonas**, *listeners*, *target groups*. **Cancel**.
3. **EC2 → Auto Scaling groups → Create:** el primer paso pide una *launch template*. ¿Qué campos de la clase 72 reconoces en una plantilla? **Cancel**.

### 2. La arquitectura de producción de Vigía (15 min)

En `notas/fase-6/clase-77.md`, dibuja (en texto, como los diagramas del curso) cómo montarías Vigía para una empresa. Coloca cada pieza en su subred y en sus zonas:
- un ALB;
- las instancias de la API y del chequeo en un ASG;
- PostgreSQL en RDS Multi-AZ;
- los security groups entre cada pareja.

Después compara con la autocorrección. No hay un único dibujo correcto, pero hay errores claros. El más típico: una base de datos en una subred pública.

### 3. Vigía en Lambda (40 min)

Una función que comprueba una URL, como `vigia check`, pero sin servidor:

```bash
mkdir -p ~/my-devops-journey/labs/clase-77 && cd ~/my-devops-journey/labs/clase-77
CUENTA=$(aws sts get-caller-identity --query Account --output text)
```

**El rol.** Lambda también necesita un rol, con una política de confianza para `lambda.amazonaws.com` y permiso para escribir sus logs:

```bash
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
```

**Su grupo de logs, con retención.** Lambda escribe en `/aws/lambda/<nombre>`. Si no existe, lo crea él… sin retención (clase 76). Así que lo creas tú antes:

```bash
aws logs create-log-group --log-group-name /aws/lambda/vigia-mini --tags Proyecto=lab
aws logs put-retention-policy --log-group-name /aws/lambda/vigia-mini --retention-in-days 1
```

**El código.** Crea `lambda_function.py`:

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

Pruébala en local antes de subirla:

```bash
python3 -c 'from lambda_function import lambda_handler; print(lambda_handler({"url": "https://example.com"}, None))'
```

**Empaquetar y crear.** Python puede crear el zip sin instalar nada:

```bash
python3 -m zipfile -c funcion.zip lambda_function.py
aws lambda create-function --function-name vigia-mini --runtime python3.14 \
  --handler lambda_function.lambda_handler --role "arn:aws:iam::$CUENTA:role/lab-lambda" \
  --zip-file fileb://funcion.zip --timeout 10 --memory-size 128 --tags Proyecto=lab \
  --query '[FunctionName,Runtime,State]' --output text
aws lambda wait function-active-v2 --function-name vigia-mini
```

Si falla con *The role defined for the function cannot be assumed by Lambda*, es la propagación de IAM (clase 72): espera 10 segundos y repite.

**Invocar:**

```bash
aws lambda invoke --function-name vigia-mini --cli-binary-format raw-in-base64-out \
  --payload '{"url": "https://example.com"}' salida.json
cat salida.json; echo
aws lambda invoke --function-name vigia-mini --cli-binary-format raw-in-base64-out \
  --payload '{"url": "https://ejemplo.invalid"}' salida.json
cat salida.json; echo
aws logs tail /aws/lambda/vigia-mini --since 10m
```

🔮 **Predice:** en los logs, además de tu `print`, ¿qué líneas añade Lambda? `START`, `END` y `REPORT`. La de `REPORT` dice la duración, la duración **facturada**, la memoria usada y, en la primera invocación, el *Init Duration*: el **arranque en frío**, el tiempo de preparar el entorno la primera vez. Invoca otra vez y compara: la segunda no lo lleva.

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

1. **¿Cuánto costaría de verdad?** Si `vigia-mini` se ejecutara **cada minuto** durante un mes, con 128 MB y unos 0,5 s por invocación:
   - ¿cuántas invocaciones y cuántos GB-segundo serían?
   - ¿Superarías lo gratuito (1 millón de invocaciones y 400 000 GB-segundo al mes)?
   - Compáralo con la t3.small de Vigía.
2. ¿Por qué Vigía v3 **no** es una Lambda? Piensa en la API, que tiene que responder siempre, y en la base de datos.
3. Lee en la documentación de **EventBridge Scheduler** cómo ejecutarías `vigia-mini` cada 5 minutos. ¿Qué necesitaría el *scheduler* para poder invocar tu función? Pista: lo mismo que todo lo demás en AWS.

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

1. ¿Qué diferencia hay entre Multi-AZ y una réplica de lectura en RDS? ¿Qué problema resuelve cada una?
2. ¿Qué aporta un ALB delante de un grupo de Auto Scaling?
3. ¿Cuándo elegirías Lambda en lugar de una EC2 o un contenedor? ¿Y cuándo no?
4. **Repaso (clase 76, sin mirar):** ¿qué hace `treat-missing-data notBreaching` en una alarma?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Paso 2, una arquitectura razonable:**
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
El chequeo no debería escalar como la API: dos chequeos duplicarían los resultados. Iría aparte, como una sola tarea programada (EventBridge + Lambda, o una tarea de ECS).

**1.** **Multi-AZ:** una copia en espera, síncrona, en otra zona; si la principal falla, RDS cambia a ella automáticamente. Resuelve la **disponibilidad** y no atiende consultas. **Réplica de lectura:** una copia asíncrona que sí atiende lecturas. Resuelve el **rendimiento**: reparte la carga de lectura, incluso en otra región.

**2.** Un único punto de entrada, reparto del tráfico entre instancias sanas de varias zonas y comprobaciones de salud. Cuando el ASG añade, quita o sustituye instancias, el ALB las incorpora o las saca solo. También termina TLS con certificados gratuitos de ACM.

**3.** Lambda: tareas cortas (menos de 15 min) que se disparan por eventos o por horario, con carga irregular o baja. No pagas cuando no se usa y no hay servidor que mantener. No: servicios que deben estar siempre escuchando con latencia estable, procesos largos o que necesitan control del sistema operativo. Con carga alta y constante, una EC2 o un contenedor sale más barato.

**4.** Que, si en un periodo no llegan datos, la alarma lo trate como "por debajo del umbral" y se quede en `OK` (o vuelva a `OK`). Es lo adecuado para una métrica de errores: sin líneas de error, no hay errores.

**Reto 1:**
- **Invocaciones:** 60 × 24 × 30 = 43 200 al mes.
- **GB-segundo:** 43 200 × 0,5 s × 0,125 GB = 2 700 al mes.
- **Gratis:** las dos cifras quedan muy por debajo de lo gratuito (1 millón de invocaciones y 400 000 GB-segundo), así que costaría **0 USD**.
- **Comparación:** la t3.small de Vigía, 24/7, cuesta unos 15 USD al mes.

**Reto 2:** la API tiene que responder en cualquier momento con latencia estable, y la base de datos PostgreSQL necesita un servidor que corra siempre. Con Lambda, la API iría detrás de API Gateway, y la base de datos tendría que ser otro servicio (RDS o DynamoDB): es posible, pero es otra arquitectura. El chequeo, en cambio, sí encaja muy bien en Lambda.

**Reto 3:** un **rol** que EventBridge Scheduler pueda asumir, con permiso `lambda:InvokeFunction` sobre tu función.
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
