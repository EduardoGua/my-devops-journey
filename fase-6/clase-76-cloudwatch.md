# Clase 76 — CloudWatch: métricas, logs y alarmas

**Dónde:** tu Ubuntu (AWS CLI) + tu correo · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

## Objetivo

- Entender las **métricas** de CloudWatch (espacio de nombres, dimensiones, estadísticas y periodos), y qué no mide AWS por ti.
- Guardar y consultar **logs**: grupos, flujos, **retención**, `aws logs tail` y **Logs Insights**.
- Convertir líneas de log en una métrica con un **filtro de métricas**.
- Crear una **alarma** que te avise por correo a través de **SNS**, y probarla sin esperar a que algo se rompa.
- Distinguir CloudWatch, CloudTrail y AWS Config, que el examen mezcla a propósito.

## Por qué importa

Un servicio que nadie vigila está caído hasta que un cliente se queja. En la clase 13 leías logs en una máquina; en la nube, los logs de cien máquinas y contenedores llegan a un mismo sitio, se consultan con un lenguaje y disparan alarmas.

Los logs de Vigía v3 irán a CloudWatch (clase 79), y la fase 10 entera trata de esto mismo (métricas, alertas, SLO) con Prometheus y Grafana. Lo que aprendes hoy es la versión gestionada de AWS.

## Costo esperado

> 💰 **0 USD**, dentro de lo gratuito de cada mes:
> - 5 GB de logs;
> - 10 métricas personalizadas;
> - 10 alarmas;
> - 1000 correos de SNS.
>
> Fuera de lo gratuito, una alarma cuesta 0,10 USD al mes y los logs, unos 0,50 USD por GB que entra.

## Teoría

### Métricas

Una **métrica** es una serie de números en el tiempo: la CPU de una instancia, las peticiones a un bucket, la latencia de Vigía.

| Concepto | Qué es | Ejemplo |
|----------|--------|---------|
| **Espacio de nombres** | de quién es la métrica | `AWS/EC2`, `AWS/Logs`, o uno tuyo: `Lab`, `Vigia` |
| **Dimensión** | a qué recurso concreto se refiere | `InstanceId=i-0abc…`, `Sitio=example.com` |
| **Periodo** | cada cuánto se agrega | 60 s, 300 s |
| **Estadística** | cómo se resume el periodo | `Average`, `Sum`, `Maximum`, `SampleCount`, percentiles (`p95`) |

Los servicios de AWS publican sus métricas solos. Las de EC2 llegan **cada 5 minutos** gratis; cada minuto (*detailed monitoring*) se paga.

Ojo: AWS ve la instancia **desde fuera**:
- sí mide CPU, red, disco a nivel de volumen y las comprobaciones de estado;
- **no** mide la memoria ni el espacio libre del sistema de archivos. Para eso se instala el **agente de CloudWatch** dentro de la instancia.

También puedes enviar métricas propias, las **personalizadas**: `put-metric-data` (paso 7).

### Logs

```
grupo de logs  /vigia/checker          ← una aplicación o un servicio; aquí se pone la RETENCIÓN
└── flujo      3f2a…  (un contenedor)  ← una fuente: una instancia, un contenedor
    └── eventos: marca de tiempo + mensaje
```

⚠️ **Un grupo de logs nuevo guarda los logs para siempre** (*Never expire*). Es una de las trampas de coste clásicas: logs de hace años que nadie mira y que se pagan cada mes. Pon **siempre** una retención (1, 7, 30 días…).

Para consultar:
- `aws logs tail` (como `tail -f`);
- `filter-log-events` (como `grep`);
- **Logs Insights**, un lenguaje de consultas con `fields`, `filter`, `stats` y `sort`, que cobra por GB analizado (céntimos).

### De logs a alarmas

```
línea de log "ERROR …" ──► filtro de métricas ──► métrica Lab/Errores (+1)
                                                         │
                          alarma: Sum ≥ 3 en 1 min ◄─────┘
                                 │ pasa a ALARM
                                 ▼
                          tema de SNS ──► correo (y Slack, SMS, Lambda…)
```

Una **alarma** vigila una métrica y tiene tres estados:

| Estado | Significado |
|--------|-------------|
| `OK` | por debajo del umbral |
| `ALARM` | ha superado el umbral durante los periodos indicados |
| `INSUFFICIENT_DATA` | no hay datos suficientes para decidir |

¿Qué hacer cuando **no llegan datos**? Lo decides tú con `treat-missing-data`:
- `notBreaching`: "sin errores, todo bien";
- `breaching`: "si no llegan latidos, algo va mal";
- `missing`: el valor por defecto, que deja la alarma en `INSUFFICIENT_DATA`.

**SNS** (*Simple Notification Service*) reparte mensajes: un **tema** recibe un aviso y lo envía a todos sus **suscriptores** (correo, SMS, Lambda, colas SQS…). Las suscripciones por correo hay que **confirmarlas** desde el propio correo.

### CloudWatch, CloudTrail y Config

| Servicio | Responde a… | Ejemplo |
|----------|-------------|---------|
| **CloudWatch** | ¿cómo **funciona** mi sistema? | la CPU al 90 %, los errores de la aplicación, alarmas |
| **CloudTrail** | ¿**quién hizo qué**, cuándo y desde dónde? | "eduardo borró el bucket X a las 10:32 desde la IP Y" (lo viste en la clase 70) |
| **AWS Config** | ¿cómo está **configurado** cada recurso y cómo ha cambiado? ¿Cumple mis reglas? | "este security group abrió el 22 a todo internet el martes" |

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-76 && cd ~/my-devops-journey/labs/clase-76
```

### 1. Un grupo de logs con retención (5 min)

```bash
aws logs create-log-group --log-group-name /lab/app --tags Proyecto=lab
aws logs put-retention-policy --log-group-name /lab/app --retention-in-days 1
aws logs create-log-stream --log-group-name /lab/app --log-stream-name portatil
aws logs describe-log-groups --log-group-name-prefix /lab/ \
  --query 'logGroups[].[logGroupName,retentionInDays]' --output text
```

### 2. Enviar logs desde la terminal (10 min)

Una función que envía una línea al grupo. `jq` construye el JSON del evento, con la hora en milisegundos y el mensaje bien escapado aunque lleve comas o comillas:

```bash
registrar() {
  aws logs put-log-events --log-group-name /lab/app --log-stream-name portatil \
    --log-events "$(jq -nc --arg m "$1" '[{timestamp: (now*1000|floor), message: $m}]')" >/dev/null
}
registrar "INFO arranque correcto"
registrar "UP 200 https://example.com 0.21 s"
registrar "ERROR DOWN 0 https://ejemplo.invalid: no se pudo resolver el nombre, reintentando"
aws logs tail /lab/app --since 10m
```

En Vigía v3 no escribirás esto: el **driver `awslogs` de Docker** enviará la salida de cada contenedor a su grupo (clase 79). Por debajo, es exactamente esta llamada.

### 3. Buscar (15 min)

Como `grep`:

```bash
aws logs filter-log-events --log-group-name /lab/app --filter-pattern ERROR \
  --query 'events[].message' --output text
```

Con **Logs Insights**, que es asíncrono: lanzas la consulta y luego pides el resultado:

```bash
QID=$(aws logs start-query --log-group-name /lab/app \
  --start-time $(( $(date +%s) - 3600 )) --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20' \
  --query queryId --output text)
sleep 5
aws logs get-query-results --query-id "$QID" --query '[status, results[][?field==`@message`].value[]]' --output text
```

Prueba otra consulta en la consola (**CloudWatch → Logs Insights**, grupo `/lab/app`), que es más cómoda para explorar:

```
fields @message
| parse @message "* * *" as nivel, codigo, resto
| stats count(*) by nivel
```

### 4. Un filtro de métricas (10 min)

Cada línea con `ERROR` sumará 1 a la métrica `Lab/Errores`:

```bash
aws logs put-metric-filter --log-group-name /lab/app --filter-name errores \
  --filter-pattern ERROR \
  --metric-transformations metricName=Errores,metricNamespace=Lab,metricValue=1,defaultValue=0
```

El filtro solo cuenta los eventos que lleguen **a partir de ahora**: no revisa los anteriores.

### 5. El aviso por correo (10 min)

```bash
TEMA=$(aws sns create-topic --name lab-alertas --tags Key=Proyecto,Value=lab --query TopicArn --output text)
aws sns subscribe --topic-arn "$TEMA" --protocol email --notification-endpoint TU_CORREO
aws sns list-subscriptions-by-topic --topic-arn "$TEMA" --query 'Subscriptions[].[Endpoint,SubscriptionArn]' --output text
```

🔮 **Predice:** ¿qué `SubscriptionArn` verás? `PendingConfirmation`. Abre el correo de *AWS Notifications* y pulsa **Confirm subscription**. Repite el `list`: ahora sale un ARN completo.

### 6. La alarma (20 min)

```bash
aws cloudwatch put-metric-alarm --alarm-name lab-muchos-errores \
  --alarm-description "3 o más errores en un minuto en /lab/app" \
  --namespace Lab --metric-name Errores --statistic Sum --period 60 \
  --evaluation-periods 1 --threshold 3 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TEMA" --ok-actions "$TEMA"
aws cloudwatch describe-alarms --alarm-names lab-muchos-errores --query 'MetricAlarms[0].[StateValue,StateReason]' --output text
```

Primero, **prueba el aviso sin romper nada**. Así se comprueba una cadena de alertas, y es lo primero que harás con las de Vigía:

```bash
aws cloudwatch set-alarm-state --alarm-name lab-muchos-errores --state-value ALARM --state-reason "Prueba del aviso"
```

¿Llega el correo? La alarma volverá sola a su estado real en la siguiente evaluación.

Ahora, de verdad. Genera cinco errores en menos de un minuto:

```bash
for i in 1 2 3 4 5; do registrar "ERROR intento $i: tiempo agotado"; done
```

🔮 **Predice:** ¿cuánto tardará en llegar el correo de `ALARM`? Entre 1 y 3 minutos: la métrica se agrega por minutos y la alarma se evalúa después de cerrarse cada periodo. Comprueba el estado:

```bash
aws cloudwatch describe-alarms --alarm-names lab-muchos-errores --query 'MetricAlarms[0].[StateValue,StateReason]' --output text
aws cloudwatch describe-alarm-history --alarm-name lab-muchos-errores --history-item-type StateUpdate \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output text
```

Sin más errores, en un par de minutos vuelve a `OK` (gracias a `notBreaching`) y te llega el correo de recuperación (`--ok-actions`).

### 7. Una métrica tuya (10 min)

Así podría publicar Vigía la latencia de cada sitio:

```bash
aws cloudwatch put-metric-data --namespace Lab --metric-name LatenciaVigia \
  --unit Seconds --value 0.42 --dimensions Sitio=example.com
aws cloudwatch put-metric-data --namespace Lab --metric-name LatenciaVigia \
  --unit Seconds --value 0.87 --dimensions Sitio=example.com
sleep 60
aws cloudwatch get-metric-statistics --namespace Lab --metric-name LatenciaVigia \
  --dimensions Name=Sitio,Value=example.com \
  --start-time "$(date -u -d '-1 hour' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
  --period 300 --statistics Average Maximum --query 'Datapoints[].[Timestamp,Average,Maximum]' --output text
```

Media y máximo de los dos valores en el mismo periodo. En la fase 10 harás lo mismo con Prometheus, donde la aplicación **expone** sus métricas y alguien las recoge, en lugar de enviarlas.

## Rómpelo

**1. El grupo que nunca olvida:**

```bash
aws logs create-log-group --log-group-name /lab/para-siempre
aws logs describe-log-groups --log-group-name-prefix /lab/para-siempre --query 'logGroups[0].retentionInDays'
aws logs delete-log-group --log-group-name /lab/para-siempre
```

`null`: sin retención, guarda para siempre. Muchos servicios crean sus grupos así (Lambda, por ejemplo, en la clase 77). Por eso, en Vigía, **tú** creas los grupos con retención antes de que Docker escriba en ellos.

**2. Mayúsculas y minúsculas:**

```bash
aws logs test-metric-filter --filter-pattern ERROR \
  --log-event-messages "error en minúsculas" "ERROR en mayúsculas" "Error: mezcla" \
  --query 'matches[].eventMessage' --output text
```

Solo encaja `ERROR en mayúsculas`: los patrones distinguen mayúsculas. Si tu aplicación escribe `error` o `[ERROR]`, el filtro tiene que coincidir con lo que escribe **de verdad**. Prueba siempre los filtros con `test-metric-filter` antes de confiar en ellos.

**3. Una alarma que no sabe qué pensar:**

```bash
aws cloudwatch put-metric-alarm --alarm-name lab-sin-datos --namespace Lab --metric-name NoExiste \
  --statistic Sum --period 60 --evaluation-periods 1 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold
sleep 90
aws cloudwatch describe-alarms --alarm-names lab-sin-datos --query 'MetricAlarms[0].StateValue' --output text
aws cloudwatch delete-alarms --alarm-names lab-sin-datos
```

`INSUFFICIENT_DATA`: sin `treat-missing-data`, la falta de datos no es ni bueno ni malo. Para un chequeo que debería informar cada minuto, la falta de datos **es** una mala noticia (`breaching`). Elegirlo bien es parte de diseñar la alarma.

## Reto

1. **Un panel.** En la consola, **CloudWatch → Dashboards → Create dashboard** `lab`, con un gráfico de `Lab/Errores` y otro de `Lab/LatenciaVigia`. Los 3 primeros paneles son gratis. Después, en *Actions → View/edit source*, mira el JSON: los paneles también se pueden guardar como código (lo harás en la fase 10 con Grafana).
2. **La consulta de Vigía.** Escribe una consulta de Logs Insights que cuente, por URL, cuántas líneas `DOWN` hubo en la última hora, con el formato de log de tu Vigía (`… DOWN 0 https://… 10.000 s`). La usarás en la clase 79.
3. **CPU de una EC2** (opcional, céntimos). Lanza una t3.micro como en la clase 72, crea una alarma sobre `AWS/EC2` `CPUUtilization` con la dimensión `InstanceId` y súbele la CPU por Session Manager durante 10 minutos (`timeout 600 sha256sum /dev/zero`). ¿Por qué tarda más en reaccionar que la alarma de errores? Pista: el periodo de las métricas básicas de EC2. Termina la instancia al acabar.

## Destruir al terminar

```bash
aws cloudwatch delete-alarms --alarm-names lab-muchos-errores
aws logs delete-metric-filter --log-group-name /lab/app --filter-name errores
aws logs delete-log-group --log-group-name /lab/app
aws sns delete-topic --topic-arn "$TEMA"
aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' --output text
aws logs describe-log-groups --log-group-name-prefix /lab/ --query 'logGroups[].logGroupName' --output text
```

Borrar el tema borra también sus suscripciones. Las dos últimas órdenes no deben mostrar nada de `lab`. Si hiciste el Reto 1, borra el panel (*Delete dashboard*).

Las métricas personalizadas no se pueden borrar: desaparecen solas cuando dejan de recibir datos (tras 15 meses), y sin datos no cobran.

## Cierre

En `notas/fase-6/clase-76.md`:

1. ¿Qué no mide CloudWatch de una EC2 sin instalar nada dentro, y por qué?
2. ¿Por qué hay que poner retención a cada grupo de logs?
3. Describe el camino completo desde una línea `ERROR` en un log hasta un correo en tu bandeja.
4. **Repaso (clase 75, sin mirar):** ¿qué ganas con las etiquetas inmutables en ECR?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La **memoria** y el **espacio libre del disco** (y nada de lo que pasa dentro de tus procesos). AWS ve la instancia desde el hipervisor: sabe cuánta CPU, red y E/S de disco consume, pero no cómo reparte el sistema operativo su memoria ni qué ocupa su sistema de archivos. Para eso se instala el agente de CloudWatch, que lo mide desde dentro y lo publica como métricas personalizadas.

**2.** Porque, por defecto, un grupo guarda los logs **para siempre**, y el almacenamiento se cobra cada mes. Con retención, CloudWatch borra solo lo antiguo. Además, guardar logs más tiempo del necesario puede chocar con normas de protección de datos.

**3.** La aplicación escribe la línea → el driver `awslogs` (o el agente) la envía a un **grupo de logs** → un **filtro de métricas** que busca `ERROR` suma 1 a una **métrica** → una **alarma** evalúa la métrica cada periodo y, al superar el umbral, pasa a `ALARM` → su acción publica en un **tema de SNS** → SNS envía el correo a la suscripción confirmada.

**4.** Que una etiqueta, como `3.0.0`, identifique siempre la misma imagen: reproducibilidad (lo que probaste es lo que despliegas) y seguridad (nadie puede sustituirla en silencio). A cambio, cada cambio necesita una versión nueva.

**Reto 2** (con el formato `HORA [INFO] DOWN 0 https://… 10.000 s`):
```
fields @message
| filter @message like /DOWN/
| parse @message "DOWN * * *" as codigo, url, resto
| stats count(*) as caidas by url
| sort caidas desc
```

**Reto 3:** las métricas básicas de EC2 llegan cada **5 minutos**, así que la alarma necesita un periodo de 300 s y tarda más en ver el cambio. Con *detailed monitoring* (de pago) llegarían cada minuto.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| metric / namespace / dimension | métrica / espacio de nombres / dimensión |
| log group / log stream / retention | grupo de logs / flujo de logs / retención |
| metric filter | filtro de métricas |
| alarm state / treat missing data | estado de la alarma / tratamiento de datos que faltan |
| topic / subscription | tema / suscripción (SNS) |
| audit trail | registro de auditoría |

🎙️ *"Every log group I create gets a retention policy. Errors become a metric through a metric filter, an alarm watches that metric and notifies an SNS topic, and I test the whole chain with set-alarm-state before trusting it."*

## Siguiente

[Clase 77 — RDS, balanceadores, Auto Scaling y Lambda](clase-77-rds-elb-asg-lambda.md)
