# Clase 116 — Métricas, logs y trazas

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Medir

> 💡 **La idea de hoy:** en producción nadie mira todo el rato: el sistema tiene que decir solo cómo va. Las **métricas** dicen *cuánto* (y avisan de que algo va mal), los **logs** dicen *qué pasó* y las **trazas**, *dónde se fue el tiempo*. Prometheus va a buscar las métricas de cada aplicación a su `/metrics` y guarda **series temporales**: un nombre, unas etiquetas y un número en cada momento.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Comprobar a mano que Vigía funciona: `curl`, `kubectl get pods`, `verify.sh` (fases 4 a 9).
> - Los logs con `journalctl` y CloudWatch (clases 13 y 76).
> - Contenedores, puertos en `127.0.0.1` y volúmenes anónimos (clases 58 y 60).
> - `curl` y `jq` contra un API HTTP (clases 32 y 47).

> 🔤 **Palabras nuevas de hoy:**
> - **métrica, log, traza**: las tres señales de la observabilidad.
> - ***scrape***: Prometheus leyendo el `/metrics` de un objetivo (*target*) cada cierto tiempo.
> - **serie temporal**: un nombre + unas etiquetas, con una **muestra** (valor y momento) en cada *scrape*.
> - **cardinalidad**: cuántas series distintas hay; crece con cada valor nuevo de una etiqueta.
> - **counter, gauge, histogram, summary**: los cuatro tipos de métrica.
> - **`rate()`**: el ritmo por segundo de un counter.
> - **RED y USE**: qué medir en un servicio (ritmo, errores, duración) y en un recurso (uso, saturación, errores).
> - **PromQL**: el lenguaje de consultas de Prometheus.

## Objetivo

- Distinguir las tres señales de la observabilidad (métricas, logs y trazas) por la pregunta que responde cada una.
- Entender el modelo de datos de Prometheus: nombre, etiquetas, series temporales y muestras.
- Reconocer los cuatro tipos de métrica (*counter*, *gauge*, *histogram* y *summary*) y saber cuál usar para cada cosa.
- Elegir qué medir en un servicio con los métodos RED y USE.
- Arrancar Prometheus y hacer tus primeras consultas.

## Por qué importa

Hasta ahora sabías que Vigía funcionaba porque lo mirabas: un `curl`, un `kubectl get pods`, un `verify.sh`. En producción nadie mira todo el rato. Hace falta que el sistema diga solo cuánto tráfico tiene, cuántos errores da y cuánto tarda, y que avise cuando algo se tuerce.

Lo que preguntan en una entrevista no es "¿sabes Prometheus?", sino "¿cómo sabrías que tu servicio va mal antes que tus usuarios?". Esta fase responde a eso.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 30 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre. Entre los dos días puedes dejar Prometheus en marcha o borrarlo: lo arrancas otra vez en un segundo.

Si el cluster de kind está encendido, apágalo para liberar memoria:

```bash
docker stop lab-control-plane cloud-provider-kind
mkdir -p ~/my-devops-journey/labs/clase-116 && cd ~/my-devops-journey/labs/clase-116
```

## Las piezas

### Pieza 1 — Tres señales, tres preguntas

| Señal | Qué es | Qué pregunta responde | Ejemplo en Vigía |
|-------|--------|-----------------------|------------------|
| **Métricas** | números en el tiempo, agregados y baratos de guardar | ¿cuánto?, ¿cuántos?, ¿desde cuándo?, ¿va peor que ayer? | cuántos sitios están caídos ahora; cuánto tarda cada uno |
| **Logs** | líneas de texto (o JSON) con lo que pasó, una por evento | ¿qué pasó exactamente en este momento, con este dato? | `DOWN 0 https://caido.invalid` y el error concreto |
| **Trazas** | el recorrido de **una** petición por todos los servicios que toca, con el tiempo de cada tramo | ¿dónde se fue el tiempo de esta petición lenta? | con un solo servicio, poco; con diez, imprescindibles |

Se complementan: la **métrica** te dice que algo va mal (la latencia se ha triplicado), el **log** te dice qué (un *timeout* contra la base de datos) y la **traza** te dice dónde (el tramo de la consulta SQL). En esta fase trabajarás a fondo las dos primeras. Las trazas, con OpenTelemetry, las verás en el trabajo cuando haya varios servicios encadenados.

**Pruébalo, en papel.** ¿Qué señal usarías para cada pregunta?
1. ¿Cuántas peticiones por segundo recibe la API desde el lunes?
2. ¿Qué error exacto dio el chequeo de `caido.invalid` a las 15:04?
3. Una petición a `/status` tardó 4 segundos: ¿fue la API o PostgreSQL?

<details>
<summary>Comprueba</summary>

1. Una **métrica**: un número en el tiempo.
2. Un **log**: el evento concreto, con su dato.
3. Una **traza**: el tiempo de cada tramo de **esa** petición.
</details>

✋ **Sin mirar:** ¿qué señal te avisa **de que** algo va mal, y cuál te dice **qué** pasó?

<details>
<summary>Comprueba</summary>

La métrica avisa (un número que cruza un umbral); el log cuenta qué pasó.
</details>

**En resumen:** métricas para *cuánto*, logs para *qué*, trazas para *dónde*.

### Pieza 2 — Prometheus en una imagen

```
tu aplicación ──► /metrics (texto)  ◄── Prometheus lo pide cada 15 s (scrape) ──► su base de datos de series
                                              │                                        │
                                              ├─► evalúa las reglas ──► Alertmanager ──► aviso (correo, chat, webhook)
                                              └─► responde consultas PromQL ◄── Grafana (dashboards)
```

Prometheus **va a buscar** las métricas (*pull*): cada aplicación publica un texto en `/metrics`, y Prometheus lo lee cada cierto tiempo. Si un día no puede leerlo, eso ya es información: la métrica `up` vale 0.

**Pruébalo:**

```bash
docker run -d --name prom -p 127.0.0.1:9090:9090 prom/prometheus:v3.15.0
docker logs prom 2>&1 | tail -3
```

👀 **Qué deberías ver:** entre las últimas líneas, `msg="Server is ready to receive web requests."`. La configuración que trae la imagen hace que Prometheus se lea **a sí mismo**: es la forma más rápida de tener métricas de verdad.

✋ **Sin mirar:** ¿quién inicia la conexión, Prometheus o la aplicación?

<details>
<summary>Comprueba</summary>

Prometheus: va a buscar el `/metrics` de cada aplicación (*pull*). Por eso, si no puede leerlo, lo sabe: `up` vale 0.
</details>

**En resumen:** cada aplicación publica `/metrics`; Prometheus lo lee cada 15 s.

### Pieza 3 — El modelo de datos

```
http_requests_total{path="/comprar", status="500"}   →   37 @ 15:04:05
└──── nombre ─────┘└────────── etiquetas ──────────┘     └─ muestra: valor y momento ─┘
```

- Cada combinación de **nombre + etiquetas** es una **serie temporal** distinta.
- Prometheus guarda una **muestra** (un número y su hora) por serie en cada *scrape*.
- Las etiquetas permiten filtrar y agrupar (`sum by (status)`), pero cada valor distinto crea una serie nueva. Una etiqueta con miles de valores, como un id de usuario, multiplica las series hasta tumbar Prometheus. Es el problema de la **cardinalidad**: etiquetas con pocos valores posibles, siempre.

Convenciones de nombres: en inglés, en minúsculas con guiones bajos, en unidades base (segundos, bytes) y con la unidad al final (`_seconds`, `_bytes`). Los contadores terminan en `_total`.

**Pruébalo:**

```bash
curl -s http://127.0.0.1:9090/metrics | head -20
curl -s http://127.0.0.1:9090/metrics | grep -c '^[a-z]'
```

👀 **Qué deberías ver:** cientos de líneas (unas 640 en la 3.15). Cada métrica trae dos comentarios: `# HELP` (qué es) y `# TYPE` (su tipo), y después una línea por serie: el nombre, sus etiquetas entre llaves y el valor.

✋ **Sin mirar:** `http_requests_total{status="200"}` y `http_requests_total{status="500"}`, ¿son una serie o dos?

<details>
<summary>Comprueba</summary>

Dos: cada combinación de nombre y etiquetas es una serie distinta.
</details>

**En resumen:** nombre + etiquetas = una serie; cada valor nuevo de una etiqueta, otra serie.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Puedes borrar Prometheus (`docker rm -fv prom`) y arrancarlo mañana con el mismo `docker run`.

### Pieza 4 — Los cuatro tipos de métrica

| Tipo | Qué es | Ejemplos | Cómo se consulta |
|------|--------|----------|------------------|
| **counter** | un contador que solo sube (y vuelve a 0 si el proceso se reinicia) | peticiones atendidas, errores, bytes enviados | casi nunca el valor: su **ritmo**, con `rate()` |
| **gauge** | un valor que sube y baja | memoria usada, peticiones en curso, si un sitio está arriba (1 o 0) | tal cual, o su media o máximo en un rato |
| **histogram** | cuenta las observaciones en "cubos" por tramos (≤ 0,1 s, ≤ 0,25 s…) | tiempos de respuesta, tamaños | percentiles con `histogram_quantile()` |
| **summary** | como el histograma, pero calcula los percentiles en la propia aplicación | lo mismo | no se pueden sumar entre réplicas: prefiere histogramas |

🔮 **Predice:** antes de mirar su `# TYPE`, ¿de qué tipo crees que es cada una: `prometheus_http_requests_total`, `go_goroutines`, `process_resident_memory_bytes` y `prometheus_http_request_duration_seconds`?

**Pruébalo:**

```bash
curl -s http://127.0.0.1:9090/metrics | grep -E '^# TYPE (prometheus_http_requests_total|go_goroutines|process_resident_memory_bytes|prometheus_http_request_duration_seconds) '
curl -s http://127.0.0.1:9090/metrics | grep 'prometheus_http_request_duration_seconds' | grep 'handler="/metrics"'
```

👀 **Qué deberías ver:**
- `prometheus_http_requests_total`: un **counter** (peticiones que ha atendido su web);
- `go_goroutines` y `process_resident_memory_bytes`: **gauges** (suben y bajan);
- `prometheus_http_request_duration_seconds`: un **histogram**.

Del histograma, una línea `_bucket` por tramo (`le="0.1"` son las que tardaron como mucho 0,1 s, **acumuladas**: cada cubo incluye a los anteriores), más `_sum` (la suma de todos los tiempos) y `_count` (cuántas hubo).

✋ **Sin mirar:** ¿qué tipo usarías para "cuántos sitios están caídos ahora"? ¿Y para "cuántos chequeos se han hecho"?

<details>
<summary>Comprueba</summary>

Un **gauge** para los caídos ahora (sube y baja); un **counter** para los chequeos hechos (solo sube).
</details>

**En resumen:** counter sube, gauge sube y baja, histogram reparte en cubos.

### Pieza 5 — Las primeras consultas

Un counter, a secas, es un total acumulado desde que arrancó el proceso: no dice mucho. Su `rate()` sí: el ritmo por segundo en una ventana, por ejemplo `[1m]`. Todo lo que hace la web de Prometheus pasa por un API HTTP, que también puedes usar desde la terminal.

**Pruébalo.** Abre http://127.0.0.1:9090 en el navegador. En la caja de consulta, prueba una a una y mira la pestaña **Table** y la **Graph**:

```promql
up
prometheus_http_requests_total
prometheus_http_requests_total{handler="/metrics"}
rate(prometheus_http_requests_total{handler="/metrics"}[1m])
go_goroutines
```

👀 **Qué deberías ver:**
- `up{app="prometheus", instance="localhost:9090", job="prometheus"}` vale 1: Prometheus pudo leer su propio `/metrics` en el último *scrape*.
- El `rate()`, unas 0,07 peticiones por segundo, una cada 15 segundos, que son los *scrapes*. En los primeros minutos sale menos: a la ventana de 1 minuto todavía le faltan datos.

En **Status → Target health** está la lista de lo que Prometheus vigila, con la hora del último *scrape* y el error, si lo hubo.

Y desde la terminal:

```bash
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq '.data.result'
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health, lastError}'
```

El segundo devuelve `{"job": "prometheus", "health": "up", "lastError": ""}`. Es lo que usará tu `verify.sh` de la v7.

✋ **Sin mirar:** ¿por qué consultas `rate(…_total[1m])` y no el counter a secas?

<details>
<summary>Comprueba</summary>

Porque el total depende de cuándo arrancó el proceso; el ritmo dice cuánto está pasando **ahora**, y `rate()` sabe tratar los reinicios del contador.
</details>

**En resumen:** `up` para saber si lee; `rate()` para los counters; el API, para scripts.

### Pieza 6 — Qué medir: RED y USE

- **RED**, para servicios que atienden peticiones: **R**ate (cuántas por segundo), **E**rrors (cuántas fallan) y **D**uration (cuánto tardan). Es lo que ve un usuario.
- **USE**, para recursos (CPU, disco, red, una cola): **U**tilization (cuánto se usa), **S**aturation (cuánto espera en cola) y **E**rrors.

Google lo resume en las cuatro **señales doradas**: latencia, tráfico, errores y saturación. Si solo pudieras medir cuatro cosas de un servicio, serían esas.

**Pruébalo, en papel.** Para la web de Prometheus que tienes en marcha, ¿qué métrica de las que has visto usarías para cada letra de RED?

<details>
<summary>Comprueba</summary>

- **Rate:** `rate(prometheus_http_requests_total[1m])`.
- **Errors:** la misma, filtrando los códigos 5xx (`code=~"5.."`).
- **Duration:** el histograma `prometheus_http_request_duration_seconds`.
</details>

✋ **Sin mirar:** ¿qué método aplicas a la API de Vigía y cuál a su disco?

<details>
<summary>Comprueba</summary>

RED a la API (atiende peticiones); USE al disco (es un recurso).
</details>

**En resumen:** RED para servicios, USE para recursos; las cuatro señales doradas, para empezar.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker run -d --name prom -p 127.0.0.1:9090:9090 prom/prometheus:v3.15.0` | Prometheus en local |
| `curl -s http://127.0.0.1:9090/metrics` | las métricas que publica |
| `grep '^# TYPE'` | el tipo de cada métrica |
| `up` | si el último *scrape* funcionó (1) o no (0) |
| `metrica{etiqueta="valor"}` | filtrar por etiqueta |
| `rate(contador_total[1m])` | el ritmo por segundo de un counter |
| `curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' \| jq` | consultar desde un script |
| `curl -s http://127.0.0.1:9090/api/v1/targets \| jq` | qué vigila y si responde |
| `docker rm -fv prom` | borrarlo, con su volumen |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Para Vigía, apunta tres preguntas que responderías con métricas, tres con logs y una con trazas.

> 🧩 **Ejemplo resuelto:** una de cada, de la pieza 1. Métrica: «¿cuántos sitios están caídos ahora?». Log: «¿qué error dio `caido.invalid` a las 15:04?». Traza: «¿dónde se fueron los 4 segundos de esta petición a `/status`?».

**Ahora tú, con huecos:** «Métricas: ¿cuánto tarda ____?; ¿cuántas peticiones ____?; ¿desde cuándo ____? Logs: ¿qué ____?; ¿quién ____?; ¿por qué ____? Traza: ¿cuánto de ____ fue ____?».

<details>
<summary>Pista</summary>

Las preguntas de métricas llevan "cuánto", "cuántos" o "desde cuándo"; las de logs, un momento o un dato concreto.
</details>

**2.** Aplica RED a la API de Vigía y USE a su PostgreSQL: ¿qué medirías en cada letra?

> 🧩 **Ejemplo resuelto:** la pieza 6: RED para la web de Prometheus: el ritmo de `prometheus_http_requests_total`, los 5xx y el histograma de duración.

**Ahora tú, con huecos:**

| | API (RED) | | PostgreSQL (USE) |
|-|-----------|-|------------------|
| R | peticiones por segundo a ____ | U | ____ usado del disco, conexiones usadas de ____ |
| E | respuestas con código ____ | S | consultas ____ |
| D | ____ de las peticiones | E | ____ de conexión o de consulta |

<details>
<summary>Pista</summary>

La saturación es lo que **espera**: consultas que no pueden empezar porque no hay conexiones libres, o bloqueos.
</details>

**3.** `prometheus_tsdb_head_series` dice cuántas series tiene Prometheus en memoria. ¿Cuántas hay? Si añadieras a una métrica una etiqueta con 10 000 valores distintos, ¿cuántas más habría?

> 🧩 **Ejemplo resuelto:** la pieza 3: `status="200"` y `status="500"` son dos series de la misma métrica.

**Ahora tú, con huecos:** consulta `prometheus_tsdb_head_series`. Completa: «Hay unas ____ series. Con una etiqueta de 10 000 valores, hasta ____ series más **por cada** ____ de las demás etiquetas».

<details>
<summary>Pista</summary>

Si una métrica ya tiene 3 valores de `status`, cada uno se multiplica por los 10 000 de la etiqueta nueva.
</details>

## Destruir al terminar

```bash
docker rm -fv prom
```

`-v` borra también su volumen anónimo.

## Cierre

En `notas/fase-10/clase-116.md`:

1. ¿Qué pregunta responde cada señal: métricas, logs y trazas? Pon un ejemplo de Vigía para cada una. *(3 líneas, una por señal.)*
2. ¿Qué diferencia hay entre un counter y un gauge? ¿Por qué un counter casi nunca se mira a secas? *(2 líneas. Empieza así: «Un counter solo sube…; un gauge… El valor de un counter es…»)*
3. ¿Qué es la cardinalidad, y por qué no se pone el id de un usuario como etiqueta? *(2 líneas. Empieza así: «El número de series distintas de una métrica:…»)*
4. **Repaso (clase 115, sin mirar):** ¿por qué el CronJob de Vigía trata el código 1 como éxito? *(1–2 líneas.)*

Después, escríbeme `examíname clase-116`.

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

**Reto 1:** por ejemplo. Métricas: ¿cuánto tarda cada sitio en responder?; ¿cuántas peticiones por segundo recibe la API?; ¿desde cuándo está caído un sitio? Logs: ¿qué error dio un chequeo concreto?; ¿quién llamó a la API con un parámetro inválido?; ¿por qué falló el arranque de la API? Traza: ¿cuánto de una petición lenta a `/status` fue la consulta a PostgreSQL?

**Reto 2:** API: **R**, peticiones por segundo a cada ruta; **E**, respuestas 5xx; **D**, la duración (sus percentiles). PostgreSQL: **U**, el disco usado y las conexiones usadas de las disponibles; **S**, consultas esperando conexión o bloqueadas; **E**, errores de conexión o de consulta.

**Reto 3:** unos cientos (565 en una prueba recién arrancada). Con una etiqueta de 10 000 valores, hasta 10 000 series más **por cada** combinación de las demás etiquetas de esa métrica.
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
