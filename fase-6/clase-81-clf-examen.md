# Clase 81 — CLF-C02 (II): simulacros, logística y el día del examen

**Dónde:** navegador (Skill Builder, tu cuenta de AWS Certification y Pearson VUE) · **Tiempo:** 2 bloques, el estudio que te falte y el examen (90 min) · **Bloque:** D. Certificación

> 💡 **La idea de hoy:** saber no basta: hay que saber **en las condiciones del examen**, con reloj, preguntas ambiguas a propósito y opciones que parecen correctas. Hoy haces un simulacro de 30 preguntas con tiempo, conviertes cada fallo en una tarjeta, aprendes la estrategia de los 90 minutos y reservas el examen sin errores de logística, que también suspenden.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Tu lista de control, tu libreta de errores y tu primera medición (clase 80).
> - El formato del examen: 65 preguntas, 50 puntúan, 700 para aprobar, sin penalización (clase 80).
> - Las parejas de servicios que el examen confunde (clase 80, Rómpelo).

> 🔤 **Palabras nuevas de hoy:**
> - **simulacro**: un examen de práctica en las mismas condiciones que el real.
> - **marcar una pregunta** (*flag*): dejarla señalada para volver a ella al final.
> - **ESL +30**: la adaptación que da 30 minutos más en los exámenes en inglés a quien no lo tiene como lengua materna.
> - **OnVUE**: el examen en línea de Pearson VUE, con supervisión por cámara.
> - **insignia digital** (Credly): la prueba de la certificación que se enseña en LinkedIn.

## Objetivo

- Llegar al **80 %** en las preguntas oficiales de práctica: el criterio de salida.
- Hacer un simulacro completo con tiempo, corregirlo y convertir cada fallo en una tarjeta.
- Reservar el examen sabiendo elegir idioma, modalidad y fecha, y qué pasa si hay que cambiarla.
- Tener una estrategia para los 90 minutos del examen.
- Saber qué hacer después: la insignia, LinkedIn, el descuento del siguiente examen o, si hace falta, la repetición.
- Cerrar la fase 6.

## Por qué importa

Saber no basta: hay que saber **en las condiciones del examen**, con el reloj, preguntas ambiguas a propósito y opciones que parecen correctas. Un simulacro con tiempo y una libreta de errores te dan más puntos que otra vuelta al temario.

La logística también suspende a gente: un ordenador que no admite la supervisión en línea, un documento que no vale o una fecha que no se puede cambiar.

## Costo esperado

> 💰 **100 USD** el examen, que se paga al reservarlo con tarjeta: tu banco puede cobrar el cambio de moneda. En AWS, 0: hoy no creas nada.

## Los pasos

### 1. Las preguntas oficiales (en los días previos)

**Cómo saber que estás listo:**

| Señal | Objetivo |
|-------|----------|
| Las preguntas oficiales de práctica de Skill Builder | **80 % o más**, el criterio de salida de la fase |
| Tu lista de control (clase 80) | todo ✅ |
| Tu libreta de errores | los últimos fallos ya no se repiten |
| El simulacro de esta clase | 24 de 30 o más, en menos de 45 minutos |

Si en la primera medición sacaste menos del 70 %, dedica una semana más a tus dominios débiles antes de reservar.

En Skill Builder, haz el ***Official Practice Question Set*** (y el *Official Practice Exam*, si tienes acceso).
- Repite hasta superar el **80 %** sin haber memorizado las respuestas: si reconoces la pregunta, explícate en voz alta por qué es esa.
- Apunta las puntuaciones en `PROGRESO.md`.

### 2. El simulacro de 30 preguntas (45 min, con reloj)

Antes de empezar, **la estrategia del examen**; aplícala en el simulacro:

- **El ritmo:** 90 minutos para 65 preguntas es algo menos de 1,5 minutos por pregunta. Haz una primera pasada respondiendo todo, **marca** (*flag*) las dudosas y vuelve a ellas al final.
- **Las palabras que deciden**, en el enunciado:

  | Palabra | Qué busca |
  |---------|-----------|
  | *most cost-effective* | lo más barato que **cumpla** |
  | *least operational overhead* | lo **más gestionado** |
  | *highly available* | **varias zonas** |
  | *serverless* | Lambda, Fargate, DynamoDB… |
- **Descartar:** casi siempre hay dos opciones claramente malas. Entre las dos que quedan, vuelve a leer qué piden exactamente.
- **Respuesta múltiple:** el enunciado dice cuántas elegir ("*Choose two*"). Si eliges menos o más, la pregunta cuenta como fallo.
- **Nunca en blanco:** no hay penalización.
- **No te asustes** si una pregunta trata un servicio que no conoces: puede ser de las 15 que no puntúan.

Ahora, el simulacro. Pon un temporizador de 45 minutos. Escribe tus respuestas en `notas/fase-6/clase-81.md` y no abras la autocorrección hasta terminar. Las preguntas siguen los pesos de los dominios.

1. Una empresa compra servidores para el pico de ventas de diciembre, y el resto del año los tiene casi parados. ¿Qué ventaja de la nube resuelve mejor su problema?
   A) Ir global en minutos · B) Dejar de adivinar la capacidad · C) Economías de escala · D) La durabilidad de los datos
2. ¿Qué pilar del Well-Architected Framework trata de que una carga de trabajo se recupere de los fallos y cumpla lo que promete?
   A) Excelencia operativa · B) Fiabilidad · C) Eficiencia del rendimiento · D) Sostenibilidad
3. Una tienda pasa de 2 a 20 servidores en el Black Friday y vuelve a 2 al día siguiente, sin que nadie intervenga. ¿Cómo se llama esta capacidad?
   A) Elasticidad · B) Durabilidad · C) Tolerancia a fallos · D) Portabilidad
4. Una empresa quiere llevar su aplicación a EC2 cuanto antes, sin cambiar el código. ¿Qué estrategia de migración es?
   A) Refactorizar · B) Recomprar · C) Realojar (*rehost*) · D) Retirar
5. ¿Qué perspectiva del AWS CAF se ocupa de la formación del personal y de la gestión del cambio?
   A) Plataforma · B) Personas · C) Operaciones · D) Seguridad
6. Una empresa tiene licencias de un software por servidor físico y quiere usarlas en AWS. ¿Qué encaja?
   A) BYOL con Dedicated Hosts · B) Instancias Spot · C) Savings Plans · D) Lambda
7. Revisar el uso real de las instancias y pasarlas a un tamaño menor cuando les sobran recursos se llama:
   A) Escalado horizontal · B) *Rightsizing* · C) Reserva de capacidad · D) Facturación consolidada
8. ¿Qué **dos** tareas son responsabilidad del cliente cuando usa EC2? (Elige dos)
   A) Parchear el sistema operativo de la instancia · B) La seguridad física de los centros de datos · C) Configurar los security groups · D) Mantener el hipervisor · E) Sustituir los discos físicos averiados
9. Un auditor pide los informes de cumplimiento PCI DSS e ISO 27001 de AWS. ¿Dónde se descargan?
   A) AWS Config · B) AWS Artifact · C) AWS Trusted Advisor · D) Amazon Inspector
10. ¿Qué servicio detecta actividad maliciosa analizando CloudTrail, VPC Flow Logs y las consultas DNS?
    A) Amazon Macie · B) Amazon Inspector · C) Amazon GuardDuty · D) AWS Shield
11. Hay que saber quién terminó ayer una instancia de EC2 y desde qué IP. ¿Qué servicio lo registra?
    A) Amazon CloudWatch · B) AWS CloudTrail · C) AWS X-Ray · D) AWS Trusted Advisor
12. ¿Cuál de estas tareas solo puede hacerla el usuario raíz?
    A) Crear un usuario de IAM · B) Cerrar la cuenta de AWS · C) Lanzar una instancia de EC2 · D) Crear un bucket de S3
13. ¿Qué protección contra DDoS tienen todos los clientes de AWS sin pagar nada más?
    A) AWS Shield Standard · B) AWS Shield Advanced · C) AWS WAF · D) AWS Firewall Manager
14. Una aplicación debe guardar la contraseña de su base de datos y rotarla automáticamente cada 30 días. ¿Qué servicio usa?
    A) AWS KMS · B) AWS Secrets Manager · C) Amazon Cognito · D) AWS Artifact
15. ¿Cuál es la forma recomendada de dar permisos a una aplicación que corre en EC2?
    A) Guardar llaves de acceso en un archivo de la instancia · B) Asignarle un rol de IAM con un perfil de instancia · C) Usar las credenciales del raíz · D) Poner las llaves en el *user-data*
16. ¿Qué **dos** acciones protegen el usuario raíz? (Elige dos)
    A) Activar MFA · B) Crear llaves de acceso para el raíz y guardarlas en un gestor · C) Usar el raíz solo para las tareas que lo requieren · D) Compartir su contraseña con el equipo de operaciones · E) Desactivar CloudTrail
17. Una aplicación necesita una base de datos NoSQL de clave-valor, con latencia de milisegundos a cualquier escala y sin servidores que gestionar.
    A) Amazon RDS · B) Amazon DynamoDB · C) Amazon Redshift · D) Amazon Aurora
18. ¿Qué servicio sirve contenido estático y vídeo desde ubicaciones de borde, cerca de los usuarios?
    A) Amazon Route 53 · B) Amazon CloudFront · C) AWS Direct Connect · D) AWS Transit Gateway
19. Una empresa necesita una conexión privada y dedicada entre su centro de datos y AWS, que no pase por internet.
    A) AWS Site-to-Site VPN · B) AWS Direct Connect · C) VPC peering · D) Amazon API Gateway
20. ¿Qué servicio ejecuta contenedores sin que el cliente gestione servidores ni clústeres de EC2?
    A) Amazon EC2 · B) AWS Fargate · C) Amazon Lightsail · D) AWS Outposts
21. Varias instancias Linux necesitan leer y escribir a la vez en el mismo sistema de archivos.
    A) Amazon EBS · B) Amazon EFS · C) Amazon S3 Glacier Deep Archive · D) *Instance store*
22. ¿Cómo se consigue alta disponibilidad para una aplicación dentro de una región?
    A) Con un tipo de instancia más grande · B) Desplegándola en varias zonas de disponibilidad · C) Con instancias reservadas · D) Activando el monitoreo detallado
23. Un analista quiere consultar con SQL archivos CSV guardados en S3, sin cargarlos en una base de datos.
    A) Amazon Athena · B) AWS Glue · C) Amazon Kinesis · D) Amazon Quick Sight
24. ¿Qué servicio permite que un componente deje mensajes en una cola para que otro los procese a su ritmo?
    A) Amazon SNS · B) Amazon SQS · C) Amazon SES · D) AWS Step Functions
25. Una empresa quiere convertir textos en audio con voz natural.
    A) Amazon Transcribe · B) Amazon Polly · C) Amazon Comprehend · D) Amazon Lex
26. ¿Qué servicio de AWS describe la infraestructura como código en plantillas YAML o JSON?
    A) AWS CloudFormation · B) AWS Config · C) AWS Systems Manager · D) AWS Service Catalog
27. Trabajos por lotes que pueden interrumpirse y reanudarse, y que deben costar lo mínimo:
    A) Instancias bajo demanda · B) Instancias Spot · C) Dedicated Hosts · D) Instancias reservadas
28. Una empresa quiere recibir un correo cuando el gasto **previsto** del mes vaya a superar 500 USD.
    A) AWS Cost Explorer · B) AWS Budgets · C) AWS Pricing Calculator · D) AWS Cost and Usage Report
29. ¿Qué plan de soporte está incluido sin coste en todas las cuentas?
    A) Basic · B) Business Support+ · C) Enterprise Support · D) Unified Operations
30. Una empresa con 10 cuentas de AWS quiere una sola factura y que los descuentos por volumen se sumen.
    A) AWS Control Tower · B) AWS Organizations con facturación consolidada · C) AWS Cost Explorer · D) AWS Service Catalog

### 3. La corrección (30 min)

Corrige con la autocorrección. Para **cada fallo** y cada acierto por suerte:
1. Escribe en la libreta de errores por qué la buena es la buena.
2. Haz una tarjeta de Anki con la necesidad delante y el servicio detrás.
3. Marca en tu lista de control la tarea de la guía a la que pertenece.

### 4. Reservar (20 min)

Lo que debes saber de la reserva:

- Se reserva desde tu **cuenta de AWS Certification**: la encuentras en la página del examen, *Schedule an exam*. Pearson VUE hace la cita.
- **Idioma:** está en **español (Latinoamérica)**.
  - Si tu inglés técnico aún no es fluido, elige español: la certificación es la misma.
  - Si prefieres inglés, por práctica, pide antes la adaptación **ESL +30**: 30 minutos más para quienes no tienen el inglés como lengua materna. Se solicita una vez, en tu cuenta de AWS Certification, **antes** de reservar, y solo vale para exámenes en inglés.
- **Modalidad:**
  - **En un centro Pearson VUE:** en Colombia los hay en las ciudades principales, y los verás al reservar. Es la opción sin sorpresas técnicas.
  - **En línea (OnVUE):** desde casa, con supervisión por cámara.
    - **No funciona en Linux** ni en máquinas virtuales: necesitas un ordenador con Windows o macOS, cámara, micrófono, buena conexión y una habitación cerrada, con la mesa despejada y sin nadie más.
    - Pearson exige pasar su prueba del sistema antes.

  Con tu Ubuntu como único equipo, la opción es el **centro**.
- **Cambios:** puedes cambiar la cita o cancelarla hasta **24 horas antes**, y cambiarla como mucho **dos veces**. Dentro de las 24 horas, no hay cambios ni reembolso.
- **Documentos:** un documento oficial con foto en vigor, como tu cédula, a nombre **exactamente** igual que en tu cuenta de AWS Certification. Revisa al reservar la política de identificación de Pearson VUE: puede pedir un segundo documento.

Y los pasos:

1. En la página del examen, *Schedule an exam*: inicia sesión o crea tu cuenta de AWS Certification.
2. Si vas a hacerlo en inglés, pide primero la adaptación ESL +30 (*Request Exam Accommodations*).
3. Elige idioma, modalidad (en Colombia, con Ubuntu, un centro) y una fecha **dentro de 1 a 3 semanas**: lo bastante cerca para que estudies con urgencia, y con margen para cambiarla (24 h antes, máximo dos veces).
4. Comprueba el nombre de tu cuenta contra tu cédula, letra por letra.
5. Apunta en tu calendario la fecha, la dirección del centro y "llegar con 30 minutos de margen".

## Después del examen

- **El resultado:** te llega un correo cuando está en tu cuenta de AWS Certification, normalmente en pocas horas (como mucho, 5 días hábiles). El informe muestra, además del total, tu nivel en cada dominio.
- **Si apruebas:**
  - recibes una **insignia digital** (Credly) para LinkedIn y tu CV;
  - recibes un **descuento del 50 %** para tu siguiente examen de AWS, en tu cuenta de AWS Certification;
  - la certificación vale 3 años.
- **Si no apruebas:** tienes que esperar **14 días** para repetir, y se paga de nuevo. Usa el informe por dominios para repartir el estudio. Es habitual, y no es el final de nada.

## Rómpelo: errores que suspenden fuera del examen

1. **"Lo haré en línea con mi Ubuntu."** OnVUE no admite Linux ni máquinas virtuales. Si no tienes otro ordenador, ve a un centro.
2. **El nombre no coincide.** Un segundo apellido que falta o una tilde distinta pueden dejarte sin entrar. Corrígelo en tu cuenta **antes** de reservar.
3. **Cambiar la cita la víspera.** Dentro de las 24 horas ya no se puede: pierdes el examen y los 100 USD.
4. **Estudiar solo con preguntas.** Memorizar respuestas sube la nota de práctica, no la del examen, donde las preguntas son otras. Si aciertas, explica el porqué; si no puedes, cuenta como fallo.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escribe **2 preguntas de respuesta múltiple** ("Elige dos") para tu peor dominio, y guárdalas para dentro de una semana.

> 🧩 **Ejemplo resuelto:**
> *¿Qué dos servicios ayudan a proteger una aplicación web pública de ataques? (Elige dos.)*
> A) AWS WAF · B) Amazon Macie · C) AWS Shield · D) AWS Artifact · E) Amazon Athena
> **Correctas: A y C.** WAF filtra ataques de capa 7, como la inyección SQL; Shield protege contra DDoS.

**Ahora tú, con huecos** (dos veces):
```markdown
¿Qué dos ____? (Elige dos.)
A) ____ · B) ____ · C) ____ · D) ____ · E) ____
Correctas: ____ y ____, porque ____.
```

<details>
<summary>Pista</summary>

Tu peor dominio está en tu lista de control y en tu primera medición (clase 80). Saca las opciones de la tabla del paso 3 de la clase 80.
</details>

**2.** Repite el simulacro de esta clase dentro de una semana, sin mirar tus respuestas anteriores. ¿Mejoran tu nota y tu tiempo?

> 🧩 **Ejemplo resuelto:** «Primera vez: 22/30 en 44 min. Segunda: 26/30 en 35 min. Mejoré en seguridad; sigo fallando en facturación.»

**Ahora tú, con huecos:** «Primera vez: ____/30 en ____ min. Segunda: ____/30 en ____ min. Mejoré en ____; sigo fallando en ____».

<details>
<summary>Pista</summary>

Si reconoces una pregunta, explícate en voz alta por qué es esa respuesta antes de marcarla: así no cuenta la memoria.
</details>

**3.** Cuando tengas la insignia, añádela a LinkedIn (sección *Licencias y certificaciones*) y publica un texto corto en inglés. Te servirá en la fase 7, cuando empieces a postular.

> 🧩 **Ejemplo resuelto** (lo escribió Claude; adáptalo):
> *I just passed the AWS Certified Cloud Practitioner (CLF-C02). To prepare, I deployed my own uptime monitor, Vigía, on EC2 with an IAM role and no stored credentials, with daily reports in S3 and logs in CloudWatch. Next step: CI/CD with GitHub Actions.*

**Ahora tú, con huecos:** *I just passed the AWS Certified Cloud Practitioner (CLF-C02). To prepare, I ____. The most useful thing I learned was ____. Next step: ____.*

<details>
<summary>Pista</summary>

Tres frases cortas bastan. Añade el enlace a tu repositorio de Vigía y la insignia de Credly.
</details>

## Destruir al terminar

Nada en AWS. Solo una comprobación de costumbre antes del examen: en *Billing*, créditos restantes y días del plan gratuito. Las fases 7 y 8 también usan la cuenta.

## Cierre

En `notas/fase-6/clase-81.md`, además del simulacro:

1. ¿Qué modalidad y qué idioma elegiste, y por qué? *(1–2 líneas. Empieza así: «Elegí un centro de Pearson VUE / en línea, en español / inglés, porque…»)*
2. ¿Qué palabras del enunciado te dicen que buscan "lo más gestionado" o "lo más barato"? *(2 líneas. Empieza así: «Lo más gestionado: least operational overhead,… Lo más barato:…, siempre que…»)*
3. ¿Qué tres servicios confundías antes de esta clase, y cómo los distingues ahora? *(3 líneas, una por pareja. Empieza así: «CloudTrail frente a CloudWatch: CloudTrail dice quién hizo qué; CloudWatch…»)*
4. **Repaso (clase 80, sin mirar):** ¿cuántas preguntas puntúan en el examen y por qué no se deja ninguna en blanco? *(1–2 líneas. Empieza así: «Puntúan 50 de las 65… No se deja ninguna en blanco porque…»)*

Después, escríbeme `examíname clase-81`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas terminado el simulacro</summary>

**Simulacro** (24 de 30 = 80 %):

| # | Respuesta | Por qué |
|---|-----------|---------|
| 1 | B | escalas con la demanda en lugar de comprar para el pico |
| 2 | B | fiabilidad |
| 3 | A | elasticidad |
| 4 | C | *rehost*: tal cual a EC2 |
| 5 | B | personas |
| 6 | A | licencias por servidor físico: un servidor físico solo para ti |
| 7 | B | *rightsizing* |
| 8 | A y C | B, D y E son de AWS |
| 9 | B | Artifact |
| 10 | C | GuardDuty |
| 11 | B | CloudTrail registra cada llamada a la API: quién, cuándo y desde dónde |
| 12 | B | crear usuarios, instancias o buckets lo hace cualquier identidad con permisos |
| 13 | A | Shield Standard; *Advanced* es de pago |
| 14 | B | Secrets Manager rota secretos; KMS gestiona claves de cifrado |
| 15 | B | credenciales temporales, sin nada guardado |
| 16 | A y C | |
| 17 | B | DynamoDB |
| 18 | B | CloudFront |
| 19 | B | Direct Connect; la VPN va cifrada **por internet** |
| 20 | B | Fargate |
| 21 | B | EFS; un EBS normal se conecta a una sola instancia |
| 22 | B | varias zonas de disponibilidad |
| 23 | A | Athena |
| 24 | B | SQS |
| 25 | B | Polly; Transcribe hace lo contrario |
| 26 | A | CloudFormation |
| 27 | B | Spot |
| 28 | B | Budgets, con un aviso sobre el gasto **previsto** |
| 29 | A | Basic |
| 30 | B | Organizations con facturación consolidada |

**Cierre:**
1. Respuesta personal. Con Ubuntu como único ordenador, lo razonable es un centro de Pearson VUE. El idioma, el que te deje demostrar lo que sabes: español (Latinoamérica), o inglés con ESL +30 si quieres practicarlo.
2. **Lo más gestionado:** *least operational overhead*, *fully managed* o *serverless*. **Lo más barato:** *most cost-effective* o *lowest cost*, siempre **cumpliendo** los demás requisitos del enunciado (por ejemplo, "y que no se pueda interrumpir" descarta Spot).
3. Respuesta personal. Las confusiones más habituales: CloudTrail/CloudWatch/Config, Shield/WAF, Inspector/GuardDuty, SNS/SQS y CloudFront/Global Accelerator.
4. Puntúan 50 de las 65; las otras 15 se están probando y no sabes cuáles son. No se deja ninguna en blanco porque no hay penalización: una en blanco es un fallo seguro, y una respuesta descartando tiene alguna posibilidad.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to schedule / reschedule an exam | reservar / cambiar la fecha del examen |
| testing center / online proctoring | centro de examen / supervisión en línea |
| exam accommodation | adaptación del examen (como ESL +30) |
| to flag a question for review | marcar una pregunta para revisarla |
| digital badge | insignia digital |
| retake policy | política de repetición |

🎙️ *"I passed the AWS Certified Cloud Practitioner. Before the exam I had built and deployed a small monitoring service on EC2 with IAM roles, S3 and CloudWatch, so most questions described things I had already done."*

## Al terminar la fase 6

1. Marca en [`PROGRESO.md`](../PROGRESO.md):
   - las clases 80 y 81;
   - Vigía v3;
   - los **criterios de salida de la fase 6**, solo si los cumples sin mirar. El último es el examen aprobado.
2. Anota tus horas en el registro mensual de la Ruta 2.0.
3. Mira en *Billing* los créditos y los días que te quedan: la fase 7 sigue usando AWS.
4. Antes de empezar la fase 7, pídeme `revisa la fase 7`: compruebo que las versiones y los comandos siguen al día.

## Siguiente

[Fase 7 — CI/CD con GitHub Actions](../fase-7/README.md)
