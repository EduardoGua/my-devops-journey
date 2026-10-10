# Clase 116 — Métricas, logs y trazas

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Medir

## Objetivo

- Distinguir las tres señales de la observabilidad (métricas, logs y trazas) por la pregunta que responde cada una.
- Entender el modelo de datos de Prometheus: nombre, etiquetas, series temporales y muestras.
- Reconocer los cuatro tipos de métrica (*counter*, *gauge*, *histogram* y *summary*) y saber cuál usar para cada cosa.
- Elegir qué medir en un servicio con los métodos RED y USE.
- Arrancar Prometheus y hacer tus primeras consultas.

## Por qué importa

Hasta ahora sabías que Vigía funcionaba porque lo mirabas: un `curl`, un `kubectl get pods`, un `verify.sh`. En producción nadie mira todo el rato. Hace falta que el sistema diga solo cuánto tráfico tiene, cuántos errores da y cuánto tarda, y que avise cuando algo se tuerce.

Lo que preguntan en una entrevista no es "¿sabes Prometheus?", sino "¿cómo sabrías que tu servicio va mal antes que tus usuarios?". Esta fase responde a eso.

## Teoría

### Tres señales, tres preguntas

| Señal | Qué es | Qué pregunta responde | Ejemplo en Vigía |
|-------|--------|-----------------------|------------------|
| **Métricas** | números en el tiempo, agregados y baratos de guardar | ¿cuánto?, ¿cuántos?, ¿desde cuándo?, ¿va peor que ayer? | cuántos sitios están caídos ahora; cuánto tarda cada uno |
| **Logs** | líneas de texto (o JSON) con lo que pasó, una por evento | ¿qué pasó exactamente en este momento, con este dato? | `DOWN 0 https://caido.invalid` y el error concreto |
| **Trazas** | el recorrido de **una** petición por todos los servicios que toca, con el tiempo de cada tramo | ¿dónde se fue el tiempo de esta petición lenta? | con un solo servicio, poco; con diez, imprescindibles |

Se complementan: la **métrica** te dice que algo va mal (la latencia se ha triplicado), el **log** te dice qué (un *timeout* contra la base de datos) y la **traza** te dice dónde (el tramo de la consulta SQL). En esta fase trabajarás a fondo las dos primeras. Las trazas, con OpenTelemetry, las verás en el trabajo cuando haya varios servicios encadenados.

### Prometheus en una imagen

```
tu aplicación ──► /metrics (texto)  ◄── Prometheus lo pide cada 15 s (scrape) ──► su base de datos de series
                                              │                                        │
                                              ├─► evalúa las reglas ──► Alertmanager ──► aviso (correo, chat, webhook)
                                              └─► responde consultas PromQL ◄── Grafana (dashboards)
```

Prometheus **va a buscar** las métricas (*pull*): cada aplicación publica un texto en `/metrics`, y Prometheus lo lee cada cierto tiempo. Si un día no puede leerlo, eso ya es información: la métrica `up` vale 0.

### El modelo de datos

```
http_requests_total{path="/comprar", status="500"}   →   37 @ 15:04:05
└──── nombre ─────┘└────────── etiquetas ──────────┘     └─ muestra: valor y momento ─┘
```

- Cada combinación de **nombre + etiquetas** es una **serie temporal** distinta.
- Prometheus guarda una **muestra** (un número y su hora) por serie en cada *scrape*.
- Las etiquetas permiten filtrar y agrupar (`sum by (status)`), pero cada valor distinto crea una serie nueva. Una etiqueta con miles de valores, como un id de usuario, multiplica las series hasta tumbar Prometheus. Es el problema de la **cardinalidad**: etiquetas con pocos valores posibles, siempre.

### Los tipos de métrica

| Tipo | Qué es | Ejemplos | Cómo se consulta |
|------|--------|----------|------------------|
| **counter** | un contador que solo sube (y vuelve a 0 si el proceso se reinicia) | peticiones atendidas, errores, bytes enviados | casi nunca el valor: su **ritmo**, con `rate()` |
| **gauge** | un valor que sube y baja | memoria usada, peticiones en curso, si un sitio está arriba (1 o 0) | tal cual, o su media o máximo en un rato |
| **histogram** | cuenta las observaciones en "cubos" por tramos (≤ 0,1 s, ≤ 0,25 s…) | tiempos de respuesta, tamaños | percentiles con `histogram_quantile()` |
| **summary** | como el histograma, pero calcula los percentiles en la propia aplicación | lo mismo | no se pueden sumar entre réplicas: prefiere histogramas |

Convenciones de nombres: en inglés, en minúsculas con guiones bajos, en unidades base (segundos, bytes) y con la unidad al final (`_seconds`, `_bytes`). Los contadores terminan en `_total`.

### Qué medir: RED y USE

- **RED**, para servicios que atienden peticiones: **R**ate (cuántas por segundo), **E**rrors (cuántas fallan) y **D**uration (cuánto tardan). Es lo que ve un usuario.
- **USE**, para recursos (CPU, disco, red, una cola): **U**tilization (cuánto se usa), **S**aturation (cuánto espera en cola) y **E**rrors.

Google lo resume en las cuatro **señales doradas**: latencia, tráfico, errores y saturación. Si solo pudieras medir cuatro cosas de un servicio, serían esas.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-116 && cd ~/my-devops-journey/labs/clase-116
```

### 1. Prometheus, solo (10 min)

Si el cluster de kind está encendido, apágalo para liberar memoria: `docker stop lab-control-plane cloud-provider-kind`.

```bash
docker run -d --name prom -p 127.0.0.1:9090:9090 prom/prometheus:v3.15.0
docker logs prom 2>&1 | tail -3
```

La configuración que trae la imagen hace que Prometheus se lea **a sí mismo**: es la forma más rápida de tener métricas de verdad.

### 2. Lo que publica una aplicación (20 min)

```bash
curl -s http://127.0.0.1:9090/metrics | head -20
curl -s http://127.0.0.1:9090/metrics | grep -c '^[a-z]'
```

Cientos de líneas. Cada métrica trae dos comentarios: `# HELP` (qué es) y `# TYPE` (su tipo).

🔮 **Predice:** antes de mirar su `# TYPE`, ¿de qué tipo crees que es cada una?

```bash
curl -s http://127.0.0.1:9090/metrics | grep -E '^# TYPE (prometheus_http_requests_total|go_goroutines|process_resident_memory_bytes|prometheus_http_request_duration_seconds) '
```

- `prometheus_http_requests_total`: un **counter** (peticiones que ha atendido su web);
- `go_goroutines` y `process_resident_memory_bytes`: **gauges** (suben y bajan);
- `prometheus_http_request_duration_seconds`: un **histogram**. Míralo entero:

```bash
curl -s http://127.0.0.1:9090/metrics | grep 'prometheus_http_request_duration_seconds' | grep 'handler="/metrics"'
```

Una línea `_bucket` por tramo (`le="0.1"` son las que tardaron como mucho 0,1 s, **acumuladas**), más `_sum` (la suma de todos los tiempos) y `_count` (cuántas hubo).

### 3. Las primeras consultas (20 min)

Abre http://127.0.0.1:9090 en el navegador. En la caja de consulta, prueba una a una y mira la pestaña **Table** y la **Graph**:

```promql
up
prometheus_http_requests_total
prometheus_http_requests_total{handler="/metrics"}
rate(prometheus_http_requests_total{handler="/metrics"}[1m])
go_goroutines
```

- `up` vale 1: Prometheus pudo leer su propio `/metrics` en el último *scrape*.
- Un counter, a secas, es un número que crece y no dice mucho. Su `rate()` sí: unas 0,07 peticiones por segundo, una cada 15 segundos, que son los *scrapes*.

En **Status → Target health** está la lista de lo que Prometheus vigila, con la hora del último *scrape* y el error, si lo hubo.

### 4. Desde la terminal (10 min)

Todo lo que hace la web pasa por un API HTTP:

```bash
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq '.data.result'
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health, lastError}'
```

Es lo que usará tu `verify.sh` de la v7.

## Rómpelo

1. **Una métrica que no existe.** Consulta `prometheus_http_request_total` (sin la `s`). ¿Error? No: `Empty query result`. Para PromQL, una métrica mal escrita es una métrica sin datos. Una alerta con una errata así no saltaría nunca, y nadie se enteraría: por eso las alertas se prueban (clase 119).
2. **Un objetivo que no responde.** Crea `prometheus.yml`:

   ```yaml
   global:
     scrape_interval: 15s
   scrape_configs:
     - job_name: prometheus
       static_configs:
         - targets: ["localhost:9090"]
     - job_name: fantasma
       static_configs:
         - targets: ["localhost:9999"]
   ```

   ```bash
   docker rm -fv prom
   docker run -d --name prom -p 127.0.0.1:9090:9090 -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" prom/prometheus:v3.15.0
   ```

   A los 30 segundos, consulta `up` y mira **Target health**. ¿Qué vale `up{job="fantasma"}`? ¿Qué dice su error?
3. **La memoria de Prometheus.** `docker restart prom` y vuelve a consultar `prometheus_http_requests_total`. ¿Qué pasó con el contador? ¿Y con las series de antes del reinicio en la pestaña Graph? ¿Dónde guarda los datos, si no le diste ningún volumen? (Pista: `docker inspect prom --format '{{json .Mounts}}'`.)

## Reto

1. Para Vigía, escribe en tus notas tres preguntas que responderías con métricas, tres con logs y una con trazas.
2. Aplica RED a la API de Vigía y USE a su PostgreSQL: ¿qué medirías en cada letra?
3. `prometheus_tsdb_head_series` dice cuántas series tiene Prometheus en memoria. ¿Cuántas hay? Si añadieras a una métrica una etiqueta con 10 000 valores distintos, ¿cuántas más habría?

## Destruir al terminar

```bash
docker rm -fv prom
```

`-v` borra también su volumen anónimo.

## Cierre

En `notas/fase-10/clase-116.md`:

1. ¿Qué pregunta responde cada señal: métricas, logs y trazas? Pon un ejemplo de Vigía para cada una.
2. ¿Qué diferencia hay entre un counter y un gauge? ¿Por qué un counter casi nunca se mira a secas?
3. ¿Qué es la cardinalidad, y por qué no se pone el id de un usuario como etiqueta?
4. **Repaso (clase 115, sin mirar):** ¿por qué el CronJob de Vigía trata el código 1 como éxito?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Las **métricas** responden "¿cuánto?" y "¿desde cuándo?": cuántos sitios están caídos, cuánto tarda cada uno, cuántas peticiones recibe la API. Los **logs**, "¿qué pasó exactamente?": el error concreto del chequeo de `caido.invalid` a las 15:04. Las **trazas**, "¿dónde se fue el tiempo de esta petición?": cuánto pasó una petición a `/status` en la API y cuánto en PostgreSQL.
2. Un counter solo sube (y vuelve a 0 al reiniciarse el proceso); un gauge sube y baja. El valor de un counter es un total acumulado desde que arrancó el proceso, que depende de cuándo arrancó: lo útil es su ritmo, `rate()`, que además sabe tratar los reinicios.
3. El número de series distintas de una métrica: una por cada combinación de valores de sus etiquetas. Un id de usuario crearía una serie por usuario, y cada una ocupa memoria en Prometheus, para siempre dentro de la retención. Eso, en logs; en métricas, etiquetas con pocos valores.
4. Porque un sitio caído es el **resultado** de un chequeo que funcionó. Si contara como fallo, el Job se reintentaría y quedaría en rojo cada vez que cae un sitio vigilado.

**Rómpelo 2:** `up{job="fantasma"}` vale 0, y el error dice algo como `Get "http://localhost:9999/metrics": dial tcp [::1]:9999: connect: connection refused`. `up` existe para **cada** objetivo, responda o no: es la primera alerta que se escribe (clase 119).

**Rómpelo 3:** el contador volvió a empezar, porque es del proceso que reiniciaste, y las series de antes siguen en Graph. `docker inspect` lo explica: la imagen declara un **volumen anónimo** en `/prometheus` (clase 60). Sobrevive a `docker restart`, pero un `docker run` nuevo crea otro vacío, y el viejo queda huérfano ocupando disco (`docker volume ls`). Por eso aquí se borra con `docker rm -fv`, y en la clase 118 le darás un volumen con nombre.

**Reto 3:** unos cientos o pocos miles, según la versión. Con una etiqueta de 10 000 valores, hasta 10 000 series más **por cada** combinación de las demás etiquetas de esa métrica.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| observability / monitoring | observabilidad / monitorización |
| metrics, logs, traces | métricas, logs, trazas: las tres señales |
| scrape / target | lectura periódica de `/metrics` / objetivo que se lee |
| time series / sample / label | serie temporal / muestra / etiqueta |
| cardinality | cardinalidad: cuántas series distintas hay |
| golden signals | latencia, tráfico, errores y saturación |

🎙️ *"Metrics tell me that something is wrong, logs tell me what happened, and traces tell me where the time went. For a service I start with the RED method: request rate, errors and duration, which is what users actually feel."*

## Siguiente

[Clase 117 — El endpoint `/metrics`](clase-117-endpoint-metrics.md)
