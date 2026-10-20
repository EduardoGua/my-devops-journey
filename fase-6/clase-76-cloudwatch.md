# Clase 76 — CloudWatch: métricas, logs y alarmas

**Dónde:** tu Ubuntu (AWS CLI) + tu correo · **Tiempo:** 90 min · **Bloque:** B. Los servicios básicos

> 💡 **La idea de hoy:** un servicio que nadie vigila está caído hasta que un cliente se queja. **CloudWatch** junta en un sitio los **logs** de todas tus máquinas y contenedores (con una **retención**, o los guarda para siempre), las **métricas** (números en el tiempo) y las **alarmas** que te avisan por correo a través de **SNS**. Hoy montas la cadena completa: una línea `ERROR` en un log acaba siendo un correo en tu bandeja.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Leer logs con `journalctl`, `tail -f` y `grep` (clase 13).
> - Que Vigía escribe su log en stderr y Docker lo recoge (clases 48 y 57).
> - `jq` para construir JSON (clase 47); CloudTrail (clase 70, reto 2).
> - Una EC2 con Session Manager (clase 72), para el reto 3.

> 🔤 **Palabras nuevas de hoy:**
> - **métrica**: una serie de números en el tiempo, con su espacio de nombres y sus dimensiones.
> - **grupo de logs / flujo de logs**: los logs de una aplicación / los de una fuente concreta dentro de ella.
> - **retención**: cuántos días se guardan los logs antes de borrarse solos.
> - **Logs Insights**: el lenguaje de consultas de los logs (`fields`, `filter`, `stats`, `sort`).
> - **filtro de métricas**: convierte las líneas de log que encajan en un número.
> - **alarma**: vigila una métrica y cambia entre `OK`, `ALARM` e `INSUFFICIENT_DATA`.
> - **SNS**: el servicio que reparte avisos de un **tema** a sus **suscriptores** (correo, SMS…).

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

## Cómo va esta clase

Siete piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Las piezas 4 a 6 encadenan log → métrica → aviso → alarma.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 a 7**, el Rómpelo, el reto, la limpieza y el cierre. Al volver, define otra vez la función `registrar` de la pieza 1.

```bash
mkdir -p ~/my-devops-journey/labs/clase-76 && cd ~/my-devops-journey/labs/clase-76
```

## Las piezas

### Pieza 1 — Logs: grupos, flujos y retención

```
grupo de logs  /vigia/checker          ← una aplicación o un servicio; aquí se pone la RETENCIÓN
└── flujo      3f2a…  (un contenedor)  ← una fuente: una instancia, un contenedor
    └── eventos: marca de tiempo + mensaje
```

⚠️ **Un grupo de logs nuevo guarda los logs para siempre** (*Never expire*). Es una de las trampas de coste clásicas: logs de hace años que nadie mira y que se pagan cada mes. Pon **siempre** una retención (1, 7, 30 días…).

La función `registrar` envía una línea al grupo. `jq` construye el JSON del evento, con la hora en milisegundos y el mensaje bien escapado aunque lleve comas o comillas. En Vigía v3 no escribirás esto: el **driver `awslogs` de Docker** enviará la salida de cada contenedor a su grupo (clase 79). Por debajo, es exactamente esta llamada.

**Pruébalo:**

```bash
aws logs create-log-group --log-group-name /lab/app --tags Proyecto=lab
aws logs put-retention-policy --log-group-name /lab/app --retention-in-days 1
aws logs create-log-stream --log-group-name /lab/app --log-stream-name portatil
aws logs describe-log-groups --log-group-name-prefix /lab/ \
  --query 'logGroups[].[logGroupName,retentionInDays]' --output text
registrar() {
  aws logs put-log-events --log-group-name /lab/app --log-stream-name portatil \
    --log-events "$(jq -nc --arg m "$1" '[{timestamp: (now*1000|floor), message: $m}]')" >/dev/null
}
registrar "INFO arranque correcto"
registrar "UP 200 https://example.com 0.21 s"
registrar "ERROR DOWN 0 https://ejemplo.invalid: no se pudo resolver el nombre, reintentando"
aws logs tail /lab/app --since 10m
```

👀 **Qué deberías ver:** `/lab/app	1` (un día de retención) y, en el `tail`, tus tres líneas, cada una con su fecha y el flujo `portatil`.

✋ **Sin mirar:** ¿cuánto tiempo guarda los logs un grupo recién creado, si no haces nada?

<details>
<summary>Comprueba</summary>

Para siempre (*Never expire*), y cobrando cada mes. Por eso se pone una retención al crearlo.
</details>

**En resumen:** grupo (con retención) → flujos → eventos; `aws logs tail` los muestra como `tail -f`.

### Pieza 2 — Buscar en los logs

Para consultar hay tres herramientas: `aws logs tail` (como `tail -f`), `filter-log-events` (como `grep`) y **Logs Insights**, un lenguaje de consultas con `fields`, `filter`, `stats` y `sort`, que cobra por GB analizado (céntimos). Logs Insights es asíncrono: lanzas la consulta y luego pides el resultado.

**Pruébalo:**

```bash
aws logs filter-log-events --log-group-name /lab/app --filter-pattern ERROR \
  --query 'events[].message' --output text
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

👀 **Qué deberías ver:** la línea del `ERROR` con `filter-log-events`; `Complete` y la misma línea con Logs Insights; y en la consola, una tabla con un recuento por la primera palabra de cada línea (`INFO`, `UP`, `ERROR`: 1 cada una). `parse` corta el mensaje por los espacios y pone nombre a cada trozo.

✋ **Sin mirar:** ¿qué hace `stats count(*) by nivel` en Logs Insights?

<details>
<summary>Comprueba</summary>

Cuenta las líneas agrupadas por el campo `nivel`, como el `GROUP BY` de SQL (clase 51).
</details>

**En resumen:** `filter-log-events` para buscar; Logs Insights para cortar, contar y ordenar.

### Pieza 3 — Las métricas

Una **métrica** es una serie de números en el tiempo: la CPU de una instancia, las peticiones a un bucket, la latencia de Vigía.

| Concepto | Qué es | Ejemplo |
|----------|--------|---------|
| **Espacio de nombres** | de quién es la métrica | `AWS/EC2`, `AWS/Logs`, o uno tuyo: `Lab`, `Vigia` |
| **Dimensión** | a qué recurso concreto se refiere | `InstanceId=i-0abc…`, `Sitio=example.com` |
| **Periodo** | cada cuánto se agrega | 60 s, 300 s |
| **Estadística** | cómo se resume el periodo | `Average`, `Sum`, `Maximum`, `SampleCount`, percentiles (`p95`) |

Los servicios de AWS publican sus métricas solos. Las de EC2 llegan **cada 5 minutos** gratis; cada minuto (*detailed monitoring*) se paga.

Ojo: AWS ve la instancia **desde fuera**. Sí mide CPU, red, disco a nivel de volumen y las comprobaciones de estado; **no** mide la memoria ni el espacio libre del sistema de archivos. Para eso se instala el **agente de CloudWatch** dentro de la instancia. También puedes enviar métricas propias, las **personalizadas**, con `put-metric-data`.

**Pruébalo.** Así podría publicar Vigía la latencia de cada sitio:

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

👀 **Qué deberías ver:** una línea con la hora del periodo, la media (`0.645`) y el máximo (`0.87`) de los dos valores. Si no sale nada, espera otro minuto: las métricas nuevas tardan un poco en aparecer. En la fase 10 harás lo mismo con Prometheus, donde la aplicación **expone** sus métricas y alguien las recoge, en lugar de enviarlas.

✋ **Sin mirar:** ¿por qué CloudWatch no sabe cuánta memoria usa tu EC2, si no instalas nada?

<details>
<summary>Comprueba</summary>

Porque la ve desde fuera, desde el hipervisor: sabe la CPU, la red y el disco que consume, pero no cómo reparte la memoria el sistema operativo. Hace falta el agente de CloudWatch dentro.
</details>

**En resumen:** espacio de nombres + dimensión + periodo + estadística; AWS mide desde fuera, y lo de dentro lo publicas tú o el agente.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — De logs a métrica: el filtro de métricas

```
línea de log "ERROR …" ──► filtro de métricas ──► métrica Lab/Errores (+1)
                                                         │
                          alarma: Sum ≥ 3 en 1 min ◄─────┘
                                 │ pasa a ALARM
                                 ▼
                          tema de SNS ──► correo (y Slack, SMS, Lambda…)
```

Un **filtro de métricas** busca un patrón en cada línea que llega al grupo y, si encaja, suma un valor a una métrica. Solo cuenta los eventos que lleguen **a partir de ahora**: no revisa los anteriores. Los patrones distinguen mayúsculas (Rómpelo 2).

**Pruébalo:**

```bash
aws logs put-metric-filter --log-group-name /lab/app --filter-name errores \
  --filter-pattern ERROR \
  --metric-transformations metricName=Errores,metricNamespace=Lab,metricValue=1,defaultValue=0
aws logs test-metric-filter --filter-pattern ERROR \
  --log-event-messages "INFO todo bien" "ERROR tiempo agotado" \
  --query 'matches[].eventMessage' --output text
```

👀 **Qué deberías ver:** el primer comando no imprime nada (todo bien); `test-metric-filter` devuelve solo `ERROR tiempo agotado`: la línea que contaría.

✋ **Sin mirar:** creas el filtro hoy. ¿Cuenta los `ERROR` que llegaron ayer?

<details>
<summary>Comprueba</summary>

No: solo los eventos que llegan después de crearlo.
</details>

**En resumen:** `put-metric-filter` convierte las líneas que encajan en una métrica; pruébalo antes con `test-metric-filter`.

### Pieza 5 — El aviso por correo: SNS

**SNS** (*Simple Notification Service*) reparte mensajes: un **tema** recibe un aviso y lo envía a todos sus **suscriptores** (correo, SMS, Lambda, colas SQS…). Las suscripciones por correo hay que **confirmarlas** desde el propio correo.

🔮 **Predice:** nada más suscribirte, ¿qué `SubscriptionArn` verás?

**Pruébalo** (cambia `TU_CORREO` por el tuyo):

```bash
TEMA=$(aws sns create-topic --name lab-alertas --tags Key=Proyecto,Value=lab --query TopicArn --output text)
aws sns subscribe --topic-arn "$TEMA" --protocol email --notification-endpoint TU_CORREO
aws sns list-subscriptions-by-topic --topic-arn "$TEMA" --query 'Subscriptions[].[Endpoint,SubscriptionArn]' --output text
```

👀 **Qué deberías ver:** tu correo y `PendingConfirmation`. Abre el correo de *AWS Notifications* y pulsa **Confirm subscription**. Repite el `list`: ahora sale un ARN completo (`arn:aws:sns:us-east-1:<cuenta>:lab-alertas:…`).

✋ **Sin mirar:** ¿qué pasa con los avisos de una suscripción por correo que no has confirmado?

<details>
<summary>Comprueba</summary>

No te llegan: SNS no envía nada a una suscripción en `PendingConfirmation`.
</details>

**En resumen:** un tema de SNS y una suscripción confirmada = el destino de tus alarmas.

### Pieza 6 — La alarma

Una **alarma** vigila una métrica y tiene tres estados:

| Estado | Significado |
|--------|-------------|
| `OK` | por debajo del umbral |
| `ALARM` | ha superado el umbral durante los periodos indicados |
| `INSUFFICIENT_DATA` | no hay datos suficientes para decidir |

¿Qué hacer cuando **no llegan datos**? Lo decides tú con `treat-missing-data`: `notBreaching` ("sin errores, todo bien"), `breaching` ("si no llegan latidos, algo va mal") o `missing`, el valor por defecto, que deja la alarma en `INSUFFICIENT_DATA`.

**Pruébalo.** Crea la alarma y, primero, **prueba el aviso sin romper nada**: así se comprueba una cadena de alertas, y es lo primero que harás con las de Vigía.

```bash
aws cloudwatch put-metric-alarm --alarm-name lab-muchos-errores \
  --alarm-description "3 o más errores en un minuto en /lab/app" \
  --namespace Lab --metric-name Errores --statistic Sum --period 60 \
  --evaluation-periods 1 --threshold 3 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TEMA" --ok-actions "$TEMA"
aws cloudwatch describe-alarms --alarm-names lab-muchos-errores --query 'MetricAlarms[0].[StateValue,StateReason]' --output text
aws cloudwatch set-alarm-state --alarm-name lab-muchos-errores --state-value ALARM --state-reason "Prueba del aviso"
```

👀 **Qué deberías ver:** la alarma en `INSUFFICIENT_DATA` o `OK` al principio, y un correo `ALARM: "lab-muchos-errores"` con el motivo `Prueba del aviso`. La alarma volverá sola a su estado real en la siguiente evaluación.

Ahora, de verdad. Genera cinco errores en menos de un minuto:

```bash
for i in 1 2 3 4 5; do registrar "ERROR intento $i: tiempo agotado"; done
```

🔮 **Predice:** ¿cuánto tardará en llegar el correo de `ALARM`?

```bash
aws cloudwatch describe-alarms --alarm-names lab-muchos-errores --query 'MetricAlarms[0].[StateValue,StateReason]' --output text
aws cloudwatch describe-alarm-history --alarm-name lab-muchos-errores --history-item-type StateUpdate \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output text
```

👀 **Qué deberías ver:** entre 1 y 3 minutos después, `ALARM` con un motivo del tipo `Threshold Crossed: 1 datapoint [5.0 …] was greater than or equal to the threshold (3.0)`, y el correo. La métrica se agrega por minutos y la alarma se evalúa después de cerrarse cada periodo. Sin más errores, en un par de minutos vuelve a `OK` (gracias a `notBreaching`) y te llega el correo de recuperación (`--ok-actions`). El historial enseña cada cambio de estado.

✋ **Sin mirar:** ¿cómo compruebas que una alarma avisa sin esperar a que algo se rompa?

<details>
<summary>Comprueba</summary>

Con `aws cloudwatch set-alarm-state --state-value ALARM`: fuerza el estado y dispara sus acciones.
</details>

**En resumen:** métrica + umbral + periodos + qué hacer sin datos + acciones a SNS; y se prueba con `set-alarm-state`.

### Pieza 7 — CloudWatch, CloudTrail y Config

| Servicio | Responde a… | Ejemplo |
|----------|-------------|---------|
| **CloudWatch** | ¿cómo **funciona** mi sistema? | la CPU al 90 %, los errores de la aplicación, alarmas |
| **CloudTrail** | ¿**quién hizo qué**, cuándo y desde dónde? | "eduardo borró el bucket X a las 10:32 desde la IP Y" (lo viste en la clase 70) |
| **AWS Config** | ¿cómo está **configurado** cada recurso y cómo ha cambiado? ¿Cumple mis reglas? | "este security group abrió el 22 a todo internet el martes" |

**Pruébalo, en papel.** ¿Qué servicio responde a cada pregunta? Escríbelo antes de abrir la respuesta:

1. ¿Quién paró la instancia de producción anoche?
2. ¿Cuántos errores 500 dio la API en la última hora?
3. ¿Qué buckets de la cuenta no tienen el cifrado activado?
4. ¿Cuándo cambió alguien las reglas del security group `lab-web`, y qué había antes?

<details>
<summary>Comprueba</summary>

1, CloudTrail (quién hizo qué). 2, CloudWatch (cómo funciona). 3, Config (cómo está configurado y si cumple una regla). 4, Config, para el antes y el después de la configuración; CloudTrail te diría quién hizo la llamada.
</details>

✋ **Sin mirar:** ¿qué servicio registra cada llamada a la API de AWS de la cuenta?

<details>
<summary>Comprueba</summary>

CloudTrail.
</details>

**En resumen:** CloudWatch, cómo funciona; CloudTrail, quién hizo qué; Config, cómo está configurado.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws logs create-log-group` · `put-retention-policy --retention-in-days 7` | un grupo con retención |
| `aws logs tail /grupo --since 10m [--follow]` | ver los logs |
| `aws logs filter-log-events --filter-pattern ERROR` | buscar |
| `aws logs start-query` · `get-query-results` | Logs Insights desde la CLI |
| `aws logs put-metric-filter` · `test-metric-filter` | de logs a métrica, y probarlo |
| `aws cloudwatch put-metric-data` · `get-metric-statistics` | métricas propias |
| `aws sns create-topic` · `subscribe --protocol email` | el destino de los avisos |
| `aws cloudwatch put-metric-alarm … --treat-missing-data … --alarm-actions "$TEMA"` | una alarma |
| `aws cloudwatch set-alarm-state --state-value ALARM` | probar el aviso |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Un panel.** Crea en la consola un panel con un gráfico de `Lab/Errores` y otro de `Lab/LatenciaVigia`, y mira su JSON.

> 🧩 **Ejemplo resuelto:** el `get-metric-statistics` de la pieza 3 pedía `--namespace Lab --metric-name LatenciaVigia`.

**Ahora tú, con huecos:** **CloudWatch → Dashboards → Create dashboard** `____` → *Add widget* → *Line* → *Metrics* → espacio de nombres `____` → marca ____ y ____ → *Create widget*. Después, *Actions → View/edit source*. Completa: «El JSON tiene una lista `widgets`, y cada uno lleva `"metrics": [[ "Lab", "____", … ]]`».

<details>
<summary>Pista</summary>

Llama al panel `lab`. Los 3 primeros paneles son gratis. Los paneles también se pueden guardar como código: lo harás en la fase 10 con Grafana.
</details>

**2.** **La consulta de Vigía.** Escribe una consulta de Logs Insights que cuente, por URL, cuántas líneas `DOWN` hubo en la última hora, con el formato de log de tu Vigía (`… DOWN 0 https://… 10.000 s`). La usarás en la clase 79.

> 🧩 **Ejemplo resuelto:** la consulta de la pieza 2: `parse @message "* * *" as nivel, codigo, resto | stats count(*) by nivel`.

**Ahora tú, con huecos:**
```
fields @message
| filter @message like /____/
| parse @message "DOWN * * *" as codigo, ____, resto
| stats count(*) as caidas by ____
| sort caidas ____
```

<details>
<summary>Pista</summary>

Después de `DOWN` vienen el código y la URL. Ordena de más caídas a menos.
</details>

**3.** **CPU de una EC2** (opcional, céntimos). Lanza una t3.micro como en la clase 72, crea una alarma sobre su CPU y súbela por Session Manager durante 10 minutos (`timeout 600 sha256sum /dev/zero`). ¿Por qué tarda más en reaccionar que la alarma de errores?

> 🧩 **Ejemplo resuelto:** la alarma `lab-muchos-errores` de la pieza 6.

**Ahora tú, con huecos:**
```bash
aws cloudwatch put-metric-alarm --alarm-name lab-cpu --namespace ____ --metric-name CPUUtilization \
  --dimensions Name=____,Value="$ID" --statistic Average --period ____ \
  --evaluation-periods 1 --threshold 50 --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "$TEMA"
```
Completa: «Tarda más porque las métricas básicas de EC2 llegan cada ____». Termina la instancia y borra la alarma al acabar.

<details>
<summary>Pista</summary>

Las métricas de EC2 están en el espacio de nombres `AWS/EC2`, con la dimensión `InstanceId`. Repasa la pieza 3: ¿cada cuánto llegan gratis?
</details>

## Destruir al terminar

```bash
TEMA=${TEMA:-$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':lab-alertas')].TopicArn" --output text)}
aws cloudwatch delete-alarms --alarm-names lab-muchos-errores
aws logs delete-metric-filter --log-group-name /lab/app --filter-name errores
aws logs delete-log-group --log-group-name /lab/app
aws sns delete-topic --topic-arn "$TEMA"
aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' --output text
aws logs describe-log-groups --log-group-name-prefix /lab/ --query 'logGroups[].logGroupName' --output text
```

La primera línea recupera el ARN del tema si cerraste la terminal. Borrar el tema borra también sus suscripciones. Las dos últimas órdenes no deben mostrar nada de `lab`. Si hiciste el reto 1, borra el panel (*Delete dashboard*).

Las métricas personalizadas no se pueden borrar: desaparecen solas cuando dejan de recibir datos (tras 15 meses), y sin datos no cobran.

## Cierre

En `notas/fase-6/clase-76.md`:

1. ¿Qué no mide CloudWatch de una EC2 sin instalar nada dentro, y por qué? *(2 líneas. Empieza así: «La memoria y el espacio libre del disco, porque AWS ve la instancia desde…»)*
2. ¿Por qué hay que poner retención a cada grupo de logs? *(1–2 líneas. Empieza así: «Porque, por defecto, un grupo guarda los logs para siempre y…»)*
3. Describe el camino completo desde una línea `ERROR` en un log hasta un correo en tu bandeja. *(Una línea con flechas. Empieza así: «La aplicación escribe la línea → el driver `awslogs` la envía a un grupo de logs → …»)*
4. **Repaso (clase 75, sin mirar):** ¿qué ganas con las etiquetas inmutables en ECR? *(1–2 líneas. Empieza así: «Que una etiqueta identifique siempre la misma imagen:…»)*

Después, escríbeme `examíname clase-76`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La **memoria** y el **espacio libre del disco** (y nada de lo que pasa dentro de tus procesos). AWS ve la instancia desde el hipervisor: sabe cuánta CPU, red y E/S de disco consume, pero no cómo reparte el sistema operativo su memoria ni qué ocupa su sistema de archivos. Para eso se instala el agente de CloudWatch, que lo mide desde dentro y lo publica como métricas personalizadas.

**2.** Porque, por defecto, un grupo guarda los logs **para siempre**, y el almacenamiento se cobra cada mes. Con retención, CloudWatch borra solo lo antiguo. Además, guardar logs más tiempo del necesario puede chocar con normas de protección de datos.

**3.** La aplicación escribe la línea → el driver `awslogs` (o el agente) la envía a un **grupo de logs** → un **filtro de métricas** que busca `ERROR` suma 1 a una **métrica** → una **alarma** evalúa la métrica cada periodo y, al superar el umbral, pasa a `ALARM` → su acción publica en un **tema de SNS** → SNS envía el correo a la suscripción confirmada.

**4.** Que una etiqueta, como `3.0.0`, identifique siempre la misma imagen: reproducibilidad (lo que probaste es lo que despliegas) y seguridad (nadie puede sustituirla en silencio). A cambio, cada cambio necesita una versión nueva.

**Reto 1:** el panel `lab`, el espacio de nombres `Lab` y las métricas `Errores` y `LatenciaVigia`. En el JSON, cada *widget* lleva `"metrics": [[ "Lab", "Errores" ]]` o `[[ "Lab", "LatenciaVigia", "Sitio", "example.com" ]]`.

**Reto 2** (con el formato `HORA [INFO] DOWN 0 https://… 10.000 s`):
```
fields @message
| filter @message like /DOWN/
| parse @message "DOWN * * *" as codigo, url, resto
| stats count(*) as caidas by url
| sort caidas desc
```

**Reto 3:** `--namespace AWS/EC2`, `Name=InstanceId` y `--period 300`. Las métricas básicas de EC2 llegan cada **5 minutos**, así que la alarma necesita un periodo de 300 s y tarda más en ver el cambio. Con *detailed monitoring* (de pago) llegarían cada minuto.
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
