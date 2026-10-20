# Clase 123 — CloudWatch, la alternativa gestionada

**Dónde:** tu Ubuntu (+ AWS, opcional) · **Tiempo:** 75 min · **Bloque:** B. Avisar y entender

> 💡 **La idea de hoy:** todo lo que has hecho con Prometheus, Alertmanager y Grafana tiene su equivalente en **CloudWatch**: métricas con **dimensiones**, **alarmas** que avisan por **SNS**, logs que se consultan con **Logs Insights** y dashboards. La gran diferencia: en CloudWatch tú **envías** las métricas y pagas por cada una, y a cambio no hay nada que mantener. Saber traducir de uno a otro demuestra que entiendes los conceptos, no solo una herramienta.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los logs de Vigía v3 en CloudWatch, las alarmas y SNS (clase 76).
> - Las reglas con `for`, Alertmanager y sus receptores (clase 119); la cardinalidad (clase 116).
> - Los logs JSON y `jq` (clase 122); `aws login` (clase 70).

> 🔤 **Palabras nuevas de hoy:**
> - ***namespace*** y **dimensión**: el grupo de una métrica y sus "etiquetas" en CloudWatch.
> - ***push***: la aplicación envía sus métricas (con `PutMetricData`, el agente o EMF).
> - **estados de una alarma**: `OK`, `ALARM` e `INSUFFICIENT_DATA`.
> - **`datapoints-to-alarm`**: cuántos periodos deben incumplir para que salte (el `for` de CloudWatch).
> - ***metric math***: combinar métricas con operaciones, por ejemplo dividir errores entre total.
> - **EMF** (*embedded metric format*): una línea de log JSON de la que CloudWatch saca métricas.
> - **Logs Insights**: el lenguaje de consultas de CloudWatch Logs.

## Objetivo

- Traducir lo que has hecho con Prometheus, Alertmanager y Grafana a CloudWatch: métricas, alarmas, SNS, logs y dashboards.
- Saber cuánto cuesta cada pieza, qué entra en la capa gratuita y cuándo conviene lo gestionado.
- Conocer las opciones intermedias: Amazon Managed Service for Prometheus y Amazon Managed Grafana.
- Opcional, en tu cuenta: publicar una métrica propia, crear una alarma con aviso por correo, probarla y consultar logs JSON con Logs Insights.

## Por qué importa

Muchas empresas en AWS no montan Prometheus: usan CloudWatch, que ya está ahí, sin servidores que mantener. Otras usan los dos: CloudWatch para lo de AWS (EC2, RDS, los balanceadores) y Prometheus para sus aplicaciones. En una entrevista para un puesto en AWS te preguntarán por CloudWatch, y saber traducir de uno a otro demuestra que entiendes los conceptos y no solo una herramienta.

Ya lo usaste en la fase 6: los logs de Vigía v3 iban a CloudWatch (clase 76).

## Cómo va esta clase

Cinco piezas. Las tres primeras son en papel; las dos últimas, **opcionales**, en tu cuenta de AWS, dentro de la capa gratuita.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 30 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre. Si haces las opcionales, termina el mismo día con "Destruir al terminar".

## Las piezas

### Pieza 1 — De Prometheus a CloudWatch

| Lo que hiciste | En CloudWatch |
|----------------|---------------|
| una métrica con etiquetas: `tienda_requests_total{path="/comprar"}` | una métrica en un *namespace*, con **dimensiones**: `Laboratorio` / `ComprasFallidas`, `Path=/comprar` |
| Prometheus va a buscar `/metrics` cada 15 s (*pull*) | tú las **envías** (*push*): con `PutMetricData`, el agente de CloudWatch o el formato EMF en los logs. Los servicios de AWS publican las suyas solas |
| PromQL: `rate`, `sum by`, `histogram_quantile` | estadísticas por periodo (`Sum`, `Average`, `p95`…) y *metric math* para combinarlas |
| una regla de alerta con `for: 5m` | una **alarma**: periodo de 60 s, 5 periodos evaluados, 5 que la incumplan |
| *pending* / *firing* / *resolved* | `INSUFFICIENT_DATA` / `ALARM` / `OK` |
| Alertmanager y sus receptores | **SNS**: un *topic* con suscripciones (correo, SMS, Lambda, Slack vía Amazon Q Developer en chat) |
| tus logs JSON con `jq` | **CloudWatch Logs** y **Logs Insights**, que entiende los campos de tus JSON |
| Grafana | dashboards de CloudWatch, o Amazon Managed Grafana |

**Pruébalo, en papel.** Para las dos alertas de la clase 119, escribe en tus notas la alarma equivalente: de qué métrica y con qué estadística (`Sum`, `Average`, `Maximum`), con qué periodo y cuántos periodos evaluados, y qué haces con los datos que faltan (`treat-missing-data`). Para `TiendaMuchosErrores` necesitas dividir dos métricas con *metric math*.

<details>
<summary>Comprueba</summary>

- **`TiendaCaida`:** como en CloudWatch la aplicación envía sus métricas, "caída" es que **dejen de llegar**. Una alarma sobre las peticiones (`Sum`, periodo 60 s) con 1 periodo evaluado y `treat-missing-data breaching`: si no llegan datos, cuenta como incumplido.
- **`TiendaMuchosErrores`:** *metric math* con dos métricas, `m1` (las compras fallidas, `Sum`) y `m2` (todas las compras, `Sum`), y la expresión `m1 / m2`. Periodo de 60 s, 5 periodos evaluados, 5 que superen `0.10`, y `treat-missing-data notBreaching`.
</details>

✋ **Sin mirar:** ¿cómo se dice `for: 5m` en una alarma de CloudWatch?

<details>
<summary>Comprueba</summary>

Periodo de 60 segundos, `evaluation-periods 5` y `datapoints-to-alarm 5`: los cinco minutos tienen que incumplir.
</details>

**En resumen:** etiquetas → dimensiones; reglas → alarmas; Alertmanager → SNS; *pull* → *push*.

### Pieza 2 — El formato EMF: un log que es también una métrica

Si una línea de log JSON lleva un bloque `_aws` con la descripción de sus métricas, CloudWatch crea las métricas solo, sin llamar a `PutMetricData`:

```json
{"_aws": {"Timestamp": 1791650000000,
          "CloudWatchMetrics": [{"Namespace": "Laboratorio", "Dimensions": [["path"]],
                                 "Metrics": [{"Name": "ms", "Unit": "Milliseconds"}]}]},
 "path": "/comprar", "status": 200, "ms": 81.2}
```

Es lo que hace la librería de Powertools para Lambda. Encaja con los logs estructurados de la clase 122: un evento, y del mismo evento sale la métrica.

**Pruébalo, en papel.** En la línea de arriba: ¿cómo se llama la métrica, en qué *namespace* está, qué dimensión tiene y qué valor recibe? ¿Y `status`, qué es?

<details>
<summary>Comprueba</summary>

La métrica `ms`, en el *namespace* `Laboratorio`, con la dimensión `path=/comprar`, recibe 81,2 milisegundos. `status` no aparece en `CloudWatchMetrics`: es un campo normal del log, que se puede consultar con Logs Insights pero no crea ninguna métrica.
</details>

✋ **Sin mirar:** ¿qué ventaja tiene EMF frente a llamar a `PutMetricData` en cada petición?

<details>
<summary>Comprueba</summary>

Que no hace falta otra llamada al API: el log que ya escribes lleva la métrica dentro, y CloudWatch la saca solo. Un evento, dos usos.
</details>

**En resumen:** con EMF, el log estructurado lleva su métrica dentro.

### Pieza 3 — Lo que cuesta, y lo gestionado frente a lo tuyo

Precios de us-east-1, verificados el 2026-10-10 (están en la tabla "Datos que caducan" de la fase):

| Pieza | Gratis cada mes | Después |
|-------|-----------------|---------|
| métricas propias | 10 | 0,30 USD por métrica al mes |
| alarmas estándar | 10 | 0,10 USD por alarma al mes |
| logs | 5 GB, entre ingesta, almacenamiento y consultas de Logs Insights | 0,50 USD por GB ingerido |
| dashboards | 3, de hasta 50 métricas | precio por dashboard |

Cuidado con las **dimensiones**: cada combinación distinta es una métrica facturada aparte. Una dimensión con el id de usuario es la cardinalidad de la clase 116 convertida en factura.

| | Prometheus + Grafana tuyos | CloudWatch |
|-|----------------------------|------------|
| Costo | el servidor donde corren | por métrica, alarma y GB: barato al principio, caro a escala |
| Trabajo | lo instalas, actualizas, guardas y escalas tú | nada que mantener |
| Métricas de AWS | hay que traerlas (exportadores) | vienen solas: EC2, RDS, ELB, Lambda… |
| Portabilidad | igual en cualquier nube o en tu portátil | solo AWS |
| Consultas | PromQL, muy potente | más limitado, aunque mejora cada año |

En medio están **Amazon Managed Service for Prometheus** (Prometheus gestionado, que se consulta con PromQL) y **Amazon Managed Grafana**: tu forma de trabajar, sin servidores que mantener. Lo normal en una empresa mediana: CloudWatch para la infraestructura de AWS, y Prometheus (propio o gestionado) con Grafana para las aplicaciones.

**Pruébalo, en papel.** La tienda publica en CloudWatch una métrica de compras con la dimensión `Path` (3 rutas) y otra de latencia con `Path` y `Status` (3 rutas × 4 códigos). ¿Cuántas métricas facturas, y cuánto al mes después de la capa gratuita?

<details>
<summary>Comprueba</summary>

3 + 12 = 15 métricas. Menos las 10 gratuitas, 5 × 0,30 = **1,50 USD al mes**. Con una dimensión `Usuario`, serían miles.
</details>

✋ **Sin mirar:** ¿qué tiene CloudWatch que tu Prometheus no trae de serie?

<details>
<summary>Comprueba</summary>

Las métricas de los servicios de AWS (EC2, RDS, los balanceadores, Lambda), que llegan solas, y no hay nada que instalar ni mantener.
</details>

**En resumen:** CloudWatch cobra por métrica, alarma y GB; lo gestionado ahorra trabajo, lo tuyo ahorra a escala.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, las piezas opcionales en tu cuenta, de un tirón y destruyendo al final.

### Pieza 4 — Opcional, en tu cuenta: una métrica, una alarma y su aviso

> 💰 **0 USD:** una métrica propia, una alarma, un *topic* de SNS y unos pocos KB de logs, todo dentro de la capa gratuita de CloudWatch, que no caduca. Borra todo al terminar.

Una alarma tiene dos caminos que probar: que **evalúa** bien (con datos de verdad) y que el **aviso llega** (forzando su estado). Es el `amtool` de la clase 119 al revés: aquí provocas el aviso para comprobar que llega.

**Pruébalo.** Con tu sesión de `aws login` (clase 70):

```bash
export AWS_PAGER=""
for v in 2 4 9 7 8; do
  aws cloudwatch put-metric-data --namespace Laboratorio --metric-name ComprasFallidas --value $v --unit Count
  sleep 20
done
```

El aviso, por correo. Usa tu dirección real: AWS te mandará un correo para confirmar la suscripción, y hasta que no la confirmes no llega nada.

```bash
TOPIC=$(aws sns create-topic --name lab-avisos --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC" --protocol email --notification-endpoint <tu-correo>
```

Confirma el correo. Ahora la alarma, el equivalente de una regla con `for: 5m`:

```bash
aws cloudwatch put-metric-alarm --alarm-name lab-compras-fallidas \
  --alarm-description "Más de 5 compras fallidas por minuto, 5 minutos seguidos" \
  --namespace Laboratorio --metric-name ComprasFallidas --statistic Sum \
  --period 60 --evaluation-periods 5 --datapoints-to-alarm 5 \
  --threshold 5 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching --alarm-actions "$TOPIC" --ok-actions "$TOPIC"
aws cloudwatch describe-alarms --alarm-names lab-compras-fallidas \
  --query 'MetricAlarms[].[AlarmName,StateValue,Threshold]' --output text
```

🔮 **Predice:** ¿saltará la alarma con tus cinco valores? Haz la cuenta antes de seguir.

👀 **Qué deberías ver:** `lab-compras-fallidas` en `INSUFFICIENT_DATA` al principio y después `OK`: no salta, porque necesita 5 periodos seguidos por encima de 5, y el primer valor es 2.

Para probar el **camino del aviso** sin esperar a un incidente, fuerza el estado:

```bash
aws cloudwatch set-alarm-state --alarm-name lab-compras-fallidas --state-value ALARM --state-reason "Prueba del aviso"
```

En un minuto te llega un correo con el asunto `ALARM: "lab-compras-fallidas"…`. En la siguiente evaluación la alarma vuelve a su estado real, y como pusiste `--ok-actions`, llega también el `OK`.

```bash
aws cloudwatch describe-alarm-history --alarm-name lab-compras-fallidas \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output text
```

✋ **Sin mirar:** ¿por qué hay que confirmar la suscripción de correo de SNS?

<details>
<summary>Comprueba</summary>

Para que nadie pueda suscribir el correo de otra persona y llenarle el buzón de avisos: hasta que el dueño confirma, la suscripción está en `PendingConfirmation` y no llega nada (Rómpelo 1).
</details>

**En resumen:** una alarma se prueba dos veces: que evalúa bien y que el aviso llega.

### Pieza 5 — Opcional: logs JSON con Logs Insights

CloudWatch Logs entiende los campos de tus logs JSON: los **filtros** (`{ $.status >= 500 }`) son el `select` de `jq`, y **Logs Insights** cuenta, agrupa y ordena como el `jq -s` de la clase 122, sobre gigas de logs.

**Pruébalo.** Un grupo de logs con un día de retención y tres eventos como los de tu tienda:

```bash
aws logs create-log-group --log-group-name /laboratorio/tienda
aws logs put-retention-policy --log-group-name /laboratorio/tienda --retention-in-days 1
aws logs create-log-stream --log-group-name /laboratorio/tienda --log-stream-name prueba
AHORA=$(( $(date +%s) * 1000 ))
cat > /tmp/eventos.json <<EOF
[{"timestamp": $AHORA, "message": "{\"level\":\"INFO\",\"path\":\"/comprar\",\"status\":200,\"ms\":81.2}"},
 {"timestamp": $((AHORA + 1)), "message": "{\"level\":\"INFO\",\"path\":\"/comprar\",\"status\":500,\"ms\":29.0}"},
 {"timestamp": $((AHORA + 2)), "message": "{\"level\":\"INFO\",\"path\":\"/comprar\",\"status\":200,\"ms\":120.5}"}]
EOF
aws logs put-log-events --log-group-name /laboratorio/tienda --log-stream-name prueba --log-events file:///tmp/eventos.json
```

Un filtro sobre un campo JSON, como el `select(.status >= 500)` de `jq`:

```bash
aws logs filter-log-events --log-group-name /laboratorio/tienda \
  --filter-pattern '{ $.status >= 500 }' --query 'events[].message' --output text
```

Y Logs Insights, que reconoce solo los campos del JSON:

```bash
Q=$(aws logs start-query --log-group-name /laboratorio/tienda \
  --start-time $(( $(date +%s) - 3600 )) --end-time $(( $(date +%s) + 60 )) \
  --query-string 'stats count() as peticiones, avg(ms) as ms_medio by status' \
  --query queryId --output text)
sleep 5
aws logs get-query-results --query-id "$Q"
```

👀 **Qué deberías ver:** el filtro devuelve solo la línea con `"status":500`. Logs Insights, dos filas: `status` 200 con 2 peticiones y una media de unos 100,9 ms, y `status` 500 con 1 y 29 ms. Pruébalo también en la consola: **CloudWatch → Logs Insights**, el grupo `/laboratorio/tienda` y la consulta `fields @timestamp, path, status, ms | sort @timestamp desc`.

Estas dos últimas partes las probé con un emulador, que no reproduce bien los filtros JSON ni Logs Insights. Si en tu cuenta algo no sale como aquí, tráemelo.

✋ **Sin mirar:** ¿qué hace la retención de un día en este grupo de logs, y por qué la pones?

<details>
<summary>Comprueba</summary>

Borra los eventos de más de un día. Sin retención, un grupo de logs guarda todo para siempre, y se paga cada mes (clase 76).
</details>

**En resumen:** filtros para buscar, Logs Insights para contar y agrupar; siempre con retención.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `aws cloudwatch put-metric-data --namespace … --metric-name … --value …` | enviar un valor de una métrica |
| `aws cloudwatch put-metric-alarm … --period 60 --evaluation-periods 5 --datapoints-to-alarm 5` | una alarma con "for: 5m" |
| `--treat-missing-data notBreaching` · `breaching` | qué hacer cuando faltan datos |
| `--alarm-actions "$TOPIC" --ok-actions "$TOPIC"` | avisar al saltar y al resolverse |
| `aws cloudwatch set-alarm-state --state-value ALARM` | probar el camino del aviso |
| `aws sns create-topic` · `aws sns subscribe --protocol email` | el receptor |
| `aws logs filter-log-events --filter-pattern '{ $.status >= 500 }'` | filtrar logs JSON |
| `stats count(), avg(ms) by status` | una consulta de Logs Insights |

## Destruir al terminar

```bash
aws cloudwatch delete-alarms --alarm-names lab-compras-fallidas
aws sns delete-topic --topic-arn "$TOPIC"
aws logs delete-log-group --log-group-name /laboratorio/tienda
```

La métrica `ComprasFallidas` no se puede borrar: desaparece sola cuando lleva 15 meses sin datos, y no cobra nada si no recibe valores nuevos.

## Rómpelo

1. **Sin confirmar la suscripción.** Fuerza el estado `ALARM` antes de confirmar el correo de SNS. ¿Llega algo? Comprueba la suscripción con `aws sns list-subscriptions-by-topic --topic-arn "$TOPIC"`: `PendingConfirmation`.
2. **Los datos que faltan.** Cambia `--treat-missing-data notBreaching` por `breaching` y deja de enviar valores. ¿Qué hará la alarma? ¿Cuándo querrías eso? (Pista: piensa en un servicio que deja de enviar métricas porque se ha caído.)
3. **Una dimensión peligrosa.** Si cada compra enviara una métrica con la dimensión `Usuario=<id>`, ¿cuántas métricas pagarías con 5 000 usuarios al mes?

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Busca en la documentación de CloudWatch la diferencia entre una alarma estándar y una *composite alarm*. ¿Con cuál harías el `inhibit_rules` de la clase 119?

> 🧩 **Ejemplo resuelto:** el reto 1 de la clase 119: si `TiendaCaida` está disparada, Alertmanager no avisa de `TiendaMuchosErrores`.

**Ahora tú, con huecos:** «Una *composite alarm* combina ____ de otras alarmas con ____, ____ y ____. El `inhibit_rules` sería: `ALARM(errores) AND ____ ALARM(caida)`».

<details>
<summary>Pista</summary>

Busca *Combining alarms* en la guía de usuario de CloudWatch. La regla de una *composite alarm* se escribe con funciones como `ALARM("nombre")`.
</details>

**2.** Las métricas de tu EC2 de la fase 6: ¿cada cuánto las publica AWS por defecto (*basic monitoring*)? ¿Y el *detailed monitoring*?

> 🧩 **Ejemplo resuelto:** la pieza 1: Prometheus lee cada 15 segundos, porque tú lo configuras así.

**Ahora tú, con huecos:** «Con *basic monitoring*, cada ____ minutos, gratis. Con *detailed monitoring*, cada ____ minuto, y se paga como ____».

<details>
<summary>Pista</summary>

Busca *Enable or turn off detailed monitoring for your instances* en la documentación de EC2, y mira en la página de precios de CloudWatch cómo se cobran esas métricas.
</details>

**3.** Si Vigía corriera en EKS (clase 115), ¿qué usarías para sus métricas: CloudWatch Container Insights, Amazon Managed Service for Prometheus o tu propio Prometheus? Defiende tu elección en tres frases.

> 🧩 **Ejemplo resuelto:** la pieza 3: "CloudWatch para la infraestructura de AWS, y Prometheus (propio o gestionado) con Grafana para las aplicaciones".

**Ahora tú, con huecos:** «Elegiría ____, porque ____. Me ahorra ____. A cambio, ____».

<details>
<summary>Pista</summary>

Piensa en quién mantendría el Prometheus propio, en si quieres seguir usando tus consultas y alertas de PromQL, y en el costo por métrica.
</details>

## Cierre

En `notas/fase-10/clase-123.md`:

1. Traduce a CloudWatch: una métrica con etiquetas, una regla de alerta con `for: 5m` y un receptor de Alertmanager. *(3 líneas, una por pieza.)*
2. ¿Qué cobra CloudWatch, y qué entra gratis cada mes? *(2 líneas.)*
3. ¿Cuándo elegirías CloudWatch y cuándo Prometheus con Grafana? *(2 líneas, una por herramienta.)*
4. **Repaso (clase 122, sin mirar):** ¿qué cinco piezas tiene un postmortem? *(1 línea.)*

Después, escríbeme `examíname clase-123`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Una métrica con etiquetas es una métrica con **dimensiones** en un *namespace*. Una regla con `for: 5m` es una **alarma** con periodo de 60 segundos, 5 periodos evaluados y 5 que deben incumplirla. Un receptor de Alertmanager es un ***topic* de SNS** con sus suscripciones, en `--alarm-actions`.
2. Cobra por métrica propia al mes (la primera tarifa, 0,30 USD), por alarma (0,10 USD), por GB de logs ingerido (0,50 USD) y almacenado, por consultas y por dashboards. Gratis cada mes: 10 métricas propias, 10 alarmas, 5 GB de logs y 3 dashboards.
3. CloudWatch, para la infraestructura de AWS (viene sola) y para equipos pequeños que no quieren mantener nada. Prometheus con Grafana, para las aplicaciones, cuando quieres PromQL, portabilidad entre nubes o un costo que no crezca con cada métrica. Lo habitual es combinarlos, y Amazon Managed Service for Prometheus da lo segundo sin servidores.
4. Resumen, impacto, línea de tiempo, causa raíz (con sus factores) y acciones con responsable y fecha. Y, a menudo, cómo se detectó y qué salió bien y mal.

**Rómpelo 2:** con `breaching`, los periodos sin datos cuentan como incumplidos: a los 5 minutos sin valores, `ALARM`. Lo quieres cuando la ausencia de datos **es** el problema: un servicio caído deja de mandar métricas, y con `notBreaching` la alarma se quedaría en `OK` mientras todo está roto. Es el papel de `up == 0` en Prometheus.

**Rómpelo 3:** 5 000 métricas, unos 1 500 USD al mes (sin la capa gratuita), solo por esa dimensión.

**Reto 1:** una *composite alarm* combina el **estado** de otras alarmas con `AND`, `OR` y `NOT`. Con ella: `ALARM("lab-errores") AND NOT ALARM("lab-caida")`, "avisa de los errores **solo si** la alarma de servicio caído no está en `ALARM`".

**Reto 2:** con *basic monitoring*, cada **5 minutos**, gratis. Con *detailed monitoring*, cada **1 minuto**, y esas métricas se cobran como métricas propias (por métrica al mes).

**Reto 3:** por ejemplo: "Amazon Managed Service for Prometheus, porque Vigía ya tiene sus métricas, alertas y SLO en PromQL. Me ahorra instalar, actualizar y guardar un Prometheus dentro del cluster. A cambio, pago por muestras ingeridas y sigo necesitando Grafana para los dashboards". Container Insights también vale si lo justificas: viene integrado con EKS y no hay nada que mantener, pero sus consultas son más limitadas y cada métrica cuenta en la factura.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| namespace / dimension | espacio de nombres / dimensión |
| alarm state (OK, ALARM, INSUFFICIENT_DATA) | estado de una alarma |
| datapoints to alarm | puntos que deben incumplir para que salte |
| topic / subscription | tema / suscripción de SNS |
| embedded metric format (EMF) | métricas dentro de los logs |
| managed service | servicio gestionado |

🎙️ *"In AWS I'd use CloudWatch for the infrastructure metrics that come for free, like EC2, RDS and the load balancers, with alarms sending to SNS. For application metrics I prefer Prometheus with Grafana, self-hosted or as Amazon Managed Service for Prometheus, because PromQL is more powerful and the cost doesn't grow with every custom metric."*

## Siguiente

[Clase 124 — Vigía v7: métricas, alerta y SLO](clase-124-vigia-v7.md)
