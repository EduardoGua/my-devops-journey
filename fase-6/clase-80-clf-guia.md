# Clase 80 — CLF-C02 (I): la guía del examen como lista de control

**Dónde:** navegador (la guía oficial y AWS Skill Builder) + Anki · **Tiempo:** 2 bloques en clase y unas 15–20 h de estudio durante 2 o 3 semanas · **Bloque:** D. Certificación

## Objetivo

- Conocer el examen **AWS Certified Cloud Practitioner (CLF-C02)**: formato, puntuación, dominios y lo que no entra.
- Convertir la **guía oficial del examen** en tu lista de control, y marcar qué sabes ya y qué te falta.
- Cubrir los huecos de **amplitud**: los servicios que no tocaste en las clases 67 a 79, con una frase cada uno.
- Reconocer las parejas de servicios que el examen confunde a propósito.
- Hacer tu primera medición con las preguntas oficiales de práctica.

## Por qué importa

El CLF-C02 es tu primera certificación. Para quien empieza:
- pasa los filtros de recursos humanos, que buscan esas siglas;
- demuestra que hablas el idioma de AWS;
- su preparación te da el vocabulario de las entrevistas: "¿qué usarías para…?".

Ya hiciste más práctica de la que pide el examen. Lo que falta es **amplitud**: reconocer un centenar de servicios por su nombre y su propósito, y no confundir los que se parecen.

## Costo esperado

> 💰 **0 USD en AWS:** hoy no creas nada en tu cuenta. El examen cuesta **100 USD** y se paga al reservarlo (clase 81).

## Teoría: el examen

| | CLF-C02 |
|---|---|
| Preguntas | **65**: 50 puntúan y **15 no puntúan** (AWS las está probando, y no sabes cuáles son) |
| Tipos | **opción múltiple** (una correcta de cuatro) y **respuesta múltiple** (dos o más correctas de cinco o más) |
| Tiempo | 90 minutos |
| Puntuación | escalada de 100 a 1000; **apruebas con 700** |
| Modelo | **compensatorio**: no hace falta aprobar cada dominio, solo el total |
| Penalización | **ninguna**: una pregunta en blanco cuenta como fallo, así que responde todas |
| Precio | 100 USD |
| Idiomas | entre otros, **español (Latinoamérica)**, español (España) e inglés |
| Dónde | en un centro de Pearson VUE o en línea, con supervisión remota |
| Validez | 3 años |

Los cuatro dominios, y lo que pesan en las 50 preguntas que cuentan:

| Dominio | Peso | ≈ preguntas |
|---------|------|-------------|
| 1. Conceptos de la nube | 24 % | 12 |
| 2. Seguridad y cumplimiento | **30 %** | 15 |
| 3. Tecnología y servicios | **34 %** | 17 |
| 4. Facturación, precios y soporte | 12 % | 6 |

**Lo que no entra**, según la propia guía: programar, diseñar arquitecturas, resolver averías, implementar y hacer pruebas de carga. El examen pregunta **qué** servicio o concepto encaja, no **cómo** se configura. Tus horas de terminal te dan ventaja para entender las preguntas, pero la amplitud hay que estudiarla.

## Práctica guiada

### 1. Lee la guía oficial (25 min)

Abre la [guía del examen CLF-C02](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02.html) (está en inglés; los nombres de los servicios no se traducen en el examen). Lee la introducción y los cuatro dominios, y echa un vistazo a las listas de servicios dentro y fuera del examen (*In-scope* y *Out-of-scope*).

### 2. Tu lista de control (60 min)

Copia esta tabla en `notas/fase-6/clf-lista.md`. Son las **tareas** (*task statements*) de la guía, con la clase donde las viste. Marca cada fila sin mirar tus notas:
- ✅ sé explicarlo;
- 🟡 me suena;
- ❌ no lo sé.

| Tarea de la guía | Dónde | Estado |
|------------------|-------|--------|
| **1.1** Beneficios de la nube: alcance global, alta disponibilidad, elasticidad, agilidad | 68 | |
| **1.2** Well-Architected: los seis pilares y en qué se diferencian | 68 (Reto 3) | |
| **1.3** Migración: el AWS **CAF** (beneficios y perspectivas) y las estrategias (las **7 R**) | 80 (abajo) | |
| **1.4** Economía: costes fijos frente a variables, costes de un centro de datos propio, licencias (**BYOL**), *rightsizing*, automatización, economías de escala | 68, 80 | |
| **2.1** Responsabilidad compartida, y cómo cambia con el servicio (EC2, RDS, Lambda) | 68, 77 | |
| **2.2** Cumplimiento (**Artifact**), cifrado en tránsito y en reposo, Inspector, Security Hub, GuardDuty, Shield; vigilar y auditar con CloudWatch, CloudTrail y Config | 70, 74, 76, 80 | |
| **2.3** IAM, el raíz y sus tareas, mínimo privilegio, Identity Center, llaves y políticas de contraseñas, Secrets Manager y Systems Manager, MFA, roles entre cuentas, federación | 67, 69, 70 | |
| **2.4** WAF, Firewall Manager, Shield, GuardDuty, el Marketplace, Knowledge Center, Security Center, Security Blog y Trusted Advisor | 80 | |
| **3.1** Formas de usar AWS: consola, CLI, SDK y API, infraestructura como código; tareas puntuales frente a repetibles; modelos de despliegue | 68, 70, 71 | |
| **3.2** Regiones, zonas y ubicaciones de borde; alta disponibilidad con varias zonas; cuándo usar varias regiones | 68 | |
| **3.3** Tipos de EC2, ECS y EKS, Fargate y Lambda, Auto Scaling, balanceadores | 72, 77 | |
| **3.4** Base de datos en EC2 o gestionada; RDS y Aurora, DynamoDB, ElastiCache; DMS y SCT | 77 | |
| **3.5** Piezas de la VPC, security groups y NACL, Inspector, Route 53, VPN y Direct Connect | 71, 73 | |
| **3.6** S3 y sus clases, EBS e *instance store*, EFS y FSx, Storage Gateway, ciclo de vida, AWS Backup | 72, 74 | |
| **3.7** IA y aprendizaje automático (SageMaker AI, Lex…) y analítica (Athena, Kinesis, Glue, Quick Sight) | 80 | |
| **3.8** EventBridge, SNS y SQS; Connect y SES; Support; CodeBuild, CodePipeline y X-Ray; AppStream 2.0, WorkSpaces y WorkSpaces Secure Browser; Amplify; IoT Core | 76, 80 | |
| **4.1** Bajo demanda, reservadas, Spot, Savings Plans, Dedicated Hosts e Instances, Capacity Reservations; flexibilidad de las reservadas y su efecto en Organizations; transferencia de datos; precios del almacenamiento | 68, 74 | |
| **4.2** Budgets, Cost Explorer, Pricing Calculator, Organizations y facturación consolidada, etiquetas de costos y el Cost and Usage Report | 67, 68 | |
| **4.3** Documentación, *whitepapers*, Prescriptive Guidance, Knowledge Center, re:Post; los planes de soporte; Trusted Advisor, Health Dashboard y Health API; el equipo de Trust & Safety; la red de partners, el Marketplace y Professional Services | 80 | |

Cuenta tus ❌ y 🟡: es tu plan de estudio. Repite la lista cada semana hasta que todo sea ✅.

### 3. Lo que el curso no tocó (60 min)

Estas son las piezas del examen que no usaste en tus laboratorios. Haz una tarjeta de Anki por línea: delante, la necesidad ("analizar con SQL archivos de S3"); detrás, el servicio (**Athena**). Así es como pregunta el examen.

**Migración y economía (dominio 1)**
- **AWS CAF:** el marco de adopción de la nube, con seis **perspectivas**: negocio, personas, gobierno, plataforma, seguridad y operaciones. Promete menos riesgo, mejor desempeño ESG, más ingresos y más eficiencia operativa.
- **Las 7 R de la migración:**
  - **retirar:** apagar lo que ya no sirve;
  - **retener:** dejarlo donde está;
  - **realojar** (*rehost*, *lift and shift*): moverlo tal cual a EC2;
  - **reubicar** (*relocate*): mover una plataforma entera, como VMware;
  - **recomprar** (*repurchase*): pasarse a un SaaS;
  - **replataformar:** pequeños cambios para aprovechar un servicio gestionado, como pasar a RDS;
  - **refactorizar:** rediseñar la aplicación para la nube.
- **Herramientas de migración:**
  - **Migration Evaluator:** el caso de negocio, cuánto ahorrarías;
  - **Application Discovery Service:** el inventario de tu centro de datos;
  - **Migration Hub:** seguir todas las migraciones en un sitio;
  - **Application Migration Service:** realojar servidores en EC2;
  - **DMS** y **SCT:** mover y convertir bases de datos.

**Seguridad (dominio 2)**
- **Artifact:** descargar los informes de cumplimiento de AWS (SOC, ISO, PCI) y sus acuerdos.
- **Inspector:** buscar vulnerabilidades en EC2, imágenes de ECR y Lambda.
- **GuardDuty:** detectar amenazas analizando CloudTrail, VPC Flow Logs y DNS.
- **Detective:** investigar el origen de un hallazgo de seguridad.
- **Security Hub:** el panel central de hallazgos y de comprobaciones de buenas prácticas.
- **Macie:** encontrar datos personales y sensibles en S3.
- **Shield:** protección contra DDoS. *Standard* es gratis y automática; *Advanced* es de pago y trae un equipo de respuesta.
- **WAF:** firewall de aplicaciones web (capa 7): bloquea inyección SQL, XSS o IPs, delante de CloudFront, un ALB o API Gateway.
- **Firewall Manager:** gestionar reglas de WAF, Shield y security groups en muchas cuentas a la vez.
- **Claves y secretos:**
  - **KMS:** claves de cifrado gestionadas;
  - **CloudHSM:** un módulo de seguridad hardware dedicado solo a ti;
  - **ACM:** certificados TLS gratuitos para los servicios de AWS;
  - **Secrets Manager:** secretos con **rotación automática**. Parameter Store, de **Systems Manager**, guarda parámetros y secretos sencillos.
- **Identidades:**
  - **Cognito:** el inicio de sesión de los usuarios de **tus** aplicaciones;
  - **Directory Service:** Active Directory gestionado;
  - **RAM:** compartir recursos entre cuentas.
- **Trust & Safety:** el equipo al que se denuncian abusos hechos desde recursos de AWS.
- **Security Center** y **Security Blog:** donde AWS publica su información de seguridad.

**Gestión y gobierno (dominios 2, 3 y 4)**
- **Cuentas:**
  - **Organizations:** varias cuentas con facturación consolidada y políticas de control de servicios (**SCP**);
  - **Control Tower:** montar un entorno multicuenta con buenas prácticas, una *landing zone*.
- **Config:** el inventario y el historial de la configuración de cada recurso, con reglas de cumplimiento.
- **Infraestructura como código y catálogo:**
  - **CloudFormation:** la infraestructura como código propia de AWS. Terraform hace lo mismo, en la fase 8;
  - **Service Catalog:** un catálogo de productos aprobados que los equipos pueden lanzar.
- **Recomendaciones:**
  - **Trusted Advisor:** recomendaciones de costos, seguridad, tolerancia a fallos, rendimiento y límites de servicio;
  - **Compute Optimizer:** propone el tamaño correcto de tus instancias (*rightsizing*).
- **Health Dashboard** (y su API): el estado de AWS y los eventos que afectan a **tu** cuenta.
- **Límites y licencias:**
  - **License Manager:** controlar las licencias de software, por ejemplo con BYOL;
  - **Service Quotas:** ver tus límites y pedir que los suban.
- **Well-Architected Tool:** revisar una carga de trabajo contra los seis pilares.

**Cómputo, red y almacenamiento (dominio 3)**
- **Cómputo:**
  - **Lightsail:** servidores sencillos con precio fijo al mes;
  - **Batch:** trabajos por lotes gestionados;
  - **Outposts:** hardware de AWS instalado en **tu** centro de datos.
- **Entrega de contenido:**
  - **Route 53:** DNS, registro de dominios, comprobaciones de salud y enrutamiento por latencia o por país;
  - **CloudFront:** CDN, con caché en las ubicaciones de borde;
  - **Global Accelerator:** lleva tu tráfico por la red global de AWS con dos IP fijas *anycast*, **sin** caché.
- **APIs:** **API Gateway** publica APIs, por ejemplo delante de Lambda.
- **Conectar redes:**
  - **Transit Gateway:** un concentrador de muchas VPC y redes;
  - **PrivateLink:** llegar a un servicio por IP privada;
  - **Site-to-Site VPN:** tu oficina con la VPC;
  - **Client VPN:** cada persona con la VPC;
  - **Direct Connect:** una línea física dedicada.
- **Almacenamiento:**
  - **FSx:** sistemas de archivos gestionados, como Windows File Server o Lustre;
  - **Storage Gateway:** tu centro de datos usa S3 con una caché local;
  - **AWS Backup:** copias de seguridad centralizadas;
  - **Elastic Disaster Recovery:** replica servidores para recuperarlos en AWS.

**Analítica e IA (dominio 3)**
- **Analítica:**
  - **Athena:** SQL directamente sobre archivos de S3;
  - **Glue:** preparar y catalogar datos (ETL);
  - **Kinesis:** datos en tiempo real (*streaming*);
  - **EMR:** Hadoop y Spark gestionados;
  - **Redshift:** almacén de datos para análisis;
  - **OpenSearch Service:** búsqueda y análisis de logs;
  - **Quick Sight:** paneles de inteligencia de negocio.
- **IA:**
  - **SageMaker AI:** crear, entrenar y desplegar modelos propios;
  - **Lex:** asistentes conversacionales (*chatbots*) de voz y texto;
  - **Polly:** texto a voz;
  - **Transcribe:** voz a texto;
  - **Translate:** traducir;
  - **Comprehend:** entender textos (sentimiento, entidades, temas);
  - **Rekognition:** analizar imágenes y vídeo;
  - **Textract:** extraer texto y datos de documentos escaneados;
  - **Amazon Q:** el asistente de IA generativa de AWS, para el trabajo y para programar.

**Otros servicios (dominio 3)**
- **Integración:**
  - **SQS:** colas, para desacoplar;
  - **SNS:** publicar y notificar a muchos;
  - **EventBridge:** un bus de eventos y un programador;
  - **Step Functions:** orquestar flujos de varios pasos.
- **Aplicaciones de negocio:**
  - **Connect:** un centro de llamadas en la nube;
  - **SES:** enviar correos.
- **Escritorio y frontend:**
  - **WorkSpaces:** escritorios virtuales;
  - **AppStream 2.0:** transmitir aplicaciones al navegador;
  - **WorkSpaces Secure Browser:** un navegador gestionado para webs internas;
  - **Amplify:** construir y alojar frontends web y móviles.
- **IoT Core:** conectar dispositivos IoT.
- **Herramientas de desarrollo:**
  - **CodeBuild:** compilar y probar;
  - **CodePipeline:** pipelines de CI/CD;
  - **X-Ray:** trazas distribuidas.

**Soporte y recursos (dominio 4)**

| Plan | Lo esencial |
|------|-------------|
| **Basic** | incluido en todas las cuentas: atención 24/7 de cuenta y facturación, documentación, re:Post y las comprobaciones básicas de Trusted Advisor |
| **Business Support+** | soporte técnico 24/7 por teléfono, web y chat, respuesta en **menos de 30 min** si un sistema crítico cae y Trusted Advisor completo |
| **Enterprise Support** | menos de **15 min**, un **TAM** (*Technical Account Manager*) asignado y Trusted Advisor Priority |
| **Unified Operations** | menos de **5 min**, con ingenieros de gestión de incidentes y especialistas asignados |

Y los recursos sin plan:
- **re:Post:** la comunidad de preguntas y respuestas;
- **Knowledge Center:** respuestas a las preguntas más frecuentes;
- **Prescriptive Guidance:** guías y patrones probados;
- los ***whitepapers***;
- la **red de partners** (consultoras e ISV, los fabricantes de software);
- el **Marketplace:** software de terceros, que se paga en tu factura de AWS;
- **Professional Services:** consultores de AWS.

### 4. AWS Skill Builder y tu primera medición (a lo largo de la semana)

1. Crea tu cuenta en **AWS Skill Builder** (`skillbuilder.aws`). Es independiente de tu cuenta de AWS: usa tu correo.
2. Busca el **plan de preparación del CLF-C02** (*Exam Prep Plan*).
   - Haz el curso **AWS Cloud Practitioner Essentials**: unas 6 h, gratis y con subtítulos en español.
   - Haz el ***Official Pretest*** y, al terminar el curso, el ***Official Practice Question Set***. Si aparecen como de pago, haz solo los gratuitos.
3. Apunta la puntuación de cada intento **por dominio** en `notas/fase-6/clf-lista.md`. El criterio de salida es un **80 %** en las preguntas oficiales de práctica (clase 81).

Cada pregunta que falles, a una **libreta de errores**:
- la pregunta en tus palabras;
- por qué la buena es la buena;
- por qué la tuya no lo era.

Es lo que más sube la nota.

## Rómpelo: las parejas que el examen confunde

El examen pone juntos servicios que se parecen. Responde sin mirar y comprueba en la autocorrección.

1. "¿Quién borró este bucket?" ¿CloudWatch, CloudTrail o Config?
2. "Este security group tenía el 22 cerrado el lunes; ¿cuándo cambió?" ¿CloudTrail o Config?
3. Protección contra inyección SQL en una web: ¿Shield o WAF?
4. Vulnerabilidades conocidas en tus instancias: ¿Inspector o GuardDuty?
5. Datos personales expuestos en S3: ¿Macie o Detective?
6. Una contraseña de base de datos que debe rotar sola: ¿KMS o Secrets Manager?
7. Llevar una web estática cerca de los usuarios con caché: ¿CloudFront o Global Accelerator?
8. Línea privada dedicada entre tu centro de datos y AWS: ¿Site-to-Site VPN o Direct Connect?
9. Desacoplar un productor y un consumidor que trabajan a ritmos distintos: ¿SNS o SQS?
10. Contenedores sin gestionar servidores: ¿ECS en EC2, EKS o Fargate?
11. "¿Cuánto me costará?" antes de crear nada, y "¿en qué me lo gasté?" después: ¿Pricing Calculator o Cost Explorer?
12. Recomendaciones de ahorro, seguridad y límites de servicio en tu cuenta: ¿Trusted Advisor o Security Hub?

## Reto

1. Escribe **10 preguntas tuyas** al estilo del examen, con cuatro opciones, sobre lo que hiciste con Vigía. Por ejemplo: "Vigía debe guardar sus informes 7 años por normativa y casi nunca se leerán. ¿Qué clase de S3 es la más barata?". Intercámbialas con alguien que también estudie, o guárdalas para repasar en la clase 81.
2. Lee la página del **Well-Architected Framework** y escribe, para cada pilar, una cosa que Vigía v3 ya hace bien y otra que no.
3. Elige tres servicios de la lista del paso 3 que no conocías y busca un caso real de uso de cada uno en el blog de AWS.

## Destruir al terminar

Nada que destruir: hoy no has creado recursos. Si dejaste instancias de Vigía de la clase 79, compruébalo ahora:

```bash
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`]|[0].Value]' --output text
```

## Cierre

En `notas/fase-6/clase-80.md`:

1. ¿Cuántas preguntas tiene el examen, cuántas puntúan y qué nota necesitas? ¿Conviene dejar preguntas en blanco?
2. ¿Qué dominio pesa más? ¿Y cuál es tu peor dominio según tu lista de control y tu primera medición?
3. Explica en una frase cada una: *rehost*, *replatform* y *refactor*.
4. **Repaso (clase 79, sin mirar):** ¿por qué hay que subir el límite de saltos de IMDS a 2 cuando el código que llama a AWS corre en un contenedor?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Rómpelo:**

| # | Respuesta | Por qué |
|---|-----------|---------|
| 1 | CloudTrail | registra quién hizo cada llamada a la API |
| 2 | Config | guarda la historia de la configuración de cada recurso |
| 3 | WAF | capa 7; Shield es contra DDoS |
| 4 | Inspector | vulnerabilidades; GuardDuty detecta amenazas en curso |
| 5 | Macie | datos sensibles; Detective investiga incidentes |
| 6 | Secrets Manager | rota secretos; KMS gestiona claves de cifrado |
| 7 | CloudFront | CDN con caché; Global Accelerator mejora la ruta, sin caché |
| 8 | Direct Connect | la VPN va cifrada por internet |
| 9 | SQS | una cola; SNS reparte a muchos suscriptores a la vez |
| 10 | Fargate | |
| 11 | Pricing Calculator, después Cost Explorer | |
| 12 | Trusted Advisor | Security Hub reúne hallazgos de seguridad |

**Cierre:**
1. 65 preguntas, de las que puntúan 50; necesitas 700 de 1000. No hay penalización por fallar, así que nunca dejes ninguna en blanco: responde todas, aunque sea descartando.
2. El 3, tecnología y servicios, con el 34 %; le sigue seguridad, con el 30 %. Tu peor dominio es respuesta personal: es donde más horas debes poner.
3. **Rehost:** mover tal cual a EC2 (*lift and shift*). **Replatform:** cambios pequeños para aprovechar un servicio gestionado, como pasar la base de datos a RDS. **Refactor:** rediseñar la aplicación para la nube, por ejemplo con contenedores o Lambda.
4. Porque la petición del contenedor al IMDS cruza el puente de red de Docker: un salto más. Con IMDSv2, la respuesta con el token sale con un TTL igual al límite de saltos; con 1, no llega al contenedor, y el SDK se queda sin credenciales.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| exam guide / task statement | guía del examen / tarea evaluada |
| scaled score / passing score | puntuación escalada / nota de aprobado |
| unscored questions | preguntas que no puntúan |
| multiple choice / multiple response | opción múltiple / respuesta múltiple |
| in scope / out of scope | dentro / fuera del temario |
| lift and shift | migrar tal cual (realojar) |

🎙️ *"I'm preparing for the AWS Certified Cloud Practitioner. I turned the official exam guide into a checklist, and I track my weak domains with the official practice questions and an error notebook."*

## Siguiente

[Clase 81 — CLF-C02 (II): simulacros, logística y el día del examen](clase-81-clf-examen.md)
