# Clase 118 — Prometheus y PromQL

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Medir

## Objetivo

- Configurar Prometheus para que recoja tu aplicación: `prometheus.yml`, objetivos, intervalo y retención.
- Escribir consultas PromQL: selectores, `rate`, `increase`, agregaciones con `by`, proporciones y percentiles con `histogram_quantile`.
- Responder con PromQL las tres preguntas de RED: cuántas peticiones, cuántas fallan y cuánto tardan.
- Saber por qué `rate()` aguanta los reinicios de un contador y por qué un rango demasiado corto no devuelve nada.

## Por qué importa

Una métrica sin consultas es un número que nadie mira. PromQL es el idioma con el que preguntas a Prometheus. Con él se escriben los paneles de Grafana (clase 120), las alertas (119) y los SLO (121). Lo usan Prometheus, Grafana, Thanos, Mimir, el servicio gestionado de AWS (clase 123)… Se aprende una vez y sirve en todas partes.

## Teoría

### La configuración

```yaml
global:
  scrape_interval: 15s          # cada cuánto lee cada objetivo
scrape_configs:
  - job_name: tienda            # un "trabajo": un grupo de objetivos iguales
    static_configs:
      - targets: ["tienda:8000"]   # host:puerto; la ruta /metrics es la de por defecto
```

Prometheus añade a cada serie dos etiquetas: `job` (el nombre del trabajo) e `instance` (el objetivo). Y por cada objetivo crea la serie `up`: 1 si el último *scrape* funcionó, 0 si no.

En producción los objetivos no se escriben a mano: se **descubren** (en Kubernetes, en EC2, en Consul…). Aquí, con Compose, basta con el nombre del servicio.

### Vectores

| Tipo | Ejemplo | Qué devuelve |
|------|---------|--------------|
| vector instantáneo | `tienda_requests_total` | el último valor de cada serie |
| vector de rango | `tienda_requests_total[5m]` | todas las muestras de cada serie en los últimos 5 minutos |
| escalar | `0.95` | un número |

Las funciones como `rate()` reciben un **rango** y devuelven un **instantáneo**: "el ritmo medio de los últimos 5 minutos, en cada momento".

### Selectores

```promql
tienda_requests_total{path="/comprar"}             # igual
tienda_requests_total{status!="200"}               # distinto
tienda_requests_total{status=~"5.."}               # cumple la expresión regular: 500, 502, 503…
tienda_requests_total{path!~"/health|/metrics"}    # no la cumple
```

### Las funciones que más vas a usar

| Función | Qué hace | Para |
|---------|----------|------|
| `rate(c[5m])` | ritmo medio por segundo de un counter en el rango | peticiones por segundo, errores por segundo |
| `increase(c[1h])` | cuánto creció el counter en el rango | "pedidos en la última hora" |
| `sum by (status) (…)` | suma las series, conservando solo esas etiquetas | agrupar; `sum` sin `by` lo junta todo |
| `a / b` | divide serie a serie (las que tienen las mismas etiquetas) | proporciones: errores entre total |
| `histogram_quantile(0.95, sum by (le) (rate(h_bucket[5m])))` | el percentil 95 a partir de los cubos | latencia "que no supera el 95 %" |
| `avg_over_time(g[1h])`, `max_over_time` | media o máximo de un gauge en el rango | la memoria media de la última hora |
| `topk(3, …)` | las 3 series con más valor | las rutas más lentas |

Dos reglas de oro:
- `rate()` e `increase()`, **solo con counters**: detectan los reinicios (cuando el valor baja) y los descuentan.
- El rango debe abarcar **al menos 4 *scrapes*** (con 15 s, `[1m]` o más). Con menos muestras, el resultado sale a saltos o vacío.

### ¿Por qué percentiles y no la media?

La media mezcla a todos los usuarios en un número que no describe a ninguno. Si 99 peticiones tardan 50 ms y una tarda 5 segundos, la media es de 100 ms, y nadie ha tenido 100 ms. El **p95** (95 de cada 100 tardaron eso o menos) y el **p99** cuentan cómo lo viven los usuarios peor tratados, que son los que se quejan.

## Práctica guiada

Copia la tienda de la clase 117 y prepara la carpeta de Compose:

```bash
mkdir -p ~/my-devops-journey/labs/clase-118 && cd ~/my-devops-journey/labs/clase-118
```

### 1. La tienda, su tráfico y Prometheus (20 min)

`compose.yaml`:

```yaml
services:
  tienda:
    build: ../clase-117
    image: tienda:1
    ports:
      - "127.0.0.1:8080:8000"
  trafico:
    image: busybox:1.37
    command: ["sh", "-c", "while true; do wget -q -O /dev/null http://tienda:8000/comprar 2>/dev/null; sleep 0.2; done"]
  prometheus:
    image: prom/prometheus:v3.15.0
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=15d
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus:/prometheus
    ports:
      - "127.0.0.1:9090:9090"
volumes:
  prometheus:
```

- `trafico` hace de clientes: una compra cada fracción de segundo, para siempre.
- `--storage.tsdb.retention.time=15d` guarda 15 días (es el valor por defecto; escríbelo para que se vea). En `prometheus`, un volumen con nombre: los datos sobreviven a `docker compose down` (clase 116).
- Al poner `command`, sustituyes los argumentos de la imagen: hay que repetir `--config.file`.

`prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: tienda
    static_configs:
      - targets: ["tienda:8000"]
```

Antes de arrancar, valida la configuración con `promtool`, que viene en la imagen:

```bash
docker run --rm -v "$PWD:/r" -w /r --entrypoint promtool prom/prometheus:v3.15.0 check config prometheus.yml
docker compose up -d --build
```

Abre http://127.0.0.1:9090 → **Status → Target health**: `prometheus` y `tienda`, los dos `UP`. Deja pasar tres o cuatro minutos para tener datos.

### 2. RED con PromQL (35 min)

Escribe cada consulta en http://127.0.0.1:9090, primero en **Table** y luego en **Graph**.

**R: cuántas peticiones.**

```promql
tienda_requests_total
rate(tienda_requests_total[1m])
sum(rate(tienda_requests_total[1m]))
sum by (status) (rate(tienda_requests_total[1m]))
```

🔮 **Predice:** con una compra cada 0,2 s más lo que tarda cada una, ¿cuántas peticiones por segundo esperas?

Unas 3. Fíjate en cómo `sum` sin `by` lo junta todo en una serie sin etiquetas, y `by (status)` deja una por código.

**E: cuántas fallan.**

```promql
sum(rate(tienda_requests_total{status=~"5.."}[2m])) / sum(rate(tienda_requests_total[2m]))
```

Alrededor de 0,05: el 5 %. Sube los errores al 50 % y mira la gráfica de esa consulta durante dos minutos:

```bash
curl -s -X POST localhost:8080/errores/50
```

El cambio no es instantáneo: `rate()` mira dos minutos hacia atrás, y la línea sube poco a poco. Vuelve al 5 % (`curl -s -X POST localhost:8080/errores/5`).

**D: cuánto tardan.**

```promql
histogram_quantile(0.5, sum by (le) (rate(tienda_request_duration_seconds_bucket{path="/comprar"}[2m])))
histogram_quantile(0.99, sum by (le) (rate(tienda_request_duration_seconds_bucket{path="/comprar"}[2m])))
sum(rate(tienda_request_duration_seconds_sum{path="/comprar"}[2m])) / sum(rate(tienda_request_duration_seconds_count{path="/comprar"}[2m]))
```

En mis pruebas: **p50 de 84 ms, p99 de 477 ms y una media de 109 ms**. La media queda por encima de la mediana porque la arrastran las compras lentas, y aun así no cuenta lo que vive el 1 % peor tratado.

`sum by (le)` hace falta: `histogram_quantile` necesita los cubos (`le`) de todas las instancias juntos. Con varias réplicas de la tienda, así se calcula el percentil del servicio entero, algo que un *summary* no permite.

### 3. Desde la terminal (10 min)

```bash
q() { curl -s --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query | jq -c '.data.result[] | {etiquetas: .metric, valor: .value[1]}'; }
q 'sum by (status) (rate(tienda_requests_total[1m]))'
q 'topk(1, sum by (path, status) (rate(tienda_requests_total[2m])))'
```

`--data-urlencode` codifica las llaves, comillas y espacios de la consulta por ti.

## Rómpelo

1. **Un rango demasiado corto.** `rate(tienda_requests_total[15s])`. ¿Qué devuelve? ¿Por qué, si hay datos?
2. **`rate()` de un gauge.** `rate(tienda_requests_in_progress[1m])`. Mira encima del resultado: Prometheus avisa `PromQL info: metric might not be a counter, name does not end in _total/_sum/_count/_bucket`. El número que devuelve no significa nada.
3. **Un reinicio.** Apunta `sum(tienda_requests_total)` y `sum(increase(tienda_requests_total[2m]))`. Reinicia la tienda (`docker compose restart tienda`), espera un minuto y repite las dos. ¿Qué pasó con cada una? Prueba también `resets(tienda_requests_total[5m])`.
4. **Un objetivo caído.** `docker compose stop tienda`. ¿Qué valen `up{job="tienda"}` y `rate(tienda_requests_total[1m])` al minuto? ¿Qué dice **Target health**? Vuelve con `docker compose start tienda`.

## Reto

1. ¿Qué parte de las peticiones de `/comprar` tarda menos de 250 ms? Escríbelo solo con los cubos, sin `histogram_quantile`. (Pista: `…_bucket{le="0.25"}` entre `…_count`.)
2. Compara la gráfica de `rate(tienda_requests_total[1m])` con la de `irate(tienda_requests_total[1m])`. ¿Qué diferencia ves? ¿Cuál pondrías en una alerta?
3. `sum(rate(tienda_requests_total[5m] offset 10m))` devuelve el ritmo de hace 10 minutos. Escribe una consulta que diga cuánto ha cambiado el ritmo respecto a entonces, en porcentaje.

## Destruir al terminar

```bash
docker compose down
```

Sin `-v`: la clase 119 sigue con esta carpeta y este volumen.

## Cierre

En `notas/fase-10/clase-118.md`:

1. Escribe las tres consultas de RED para la tienda: peticiones por segundo, proporción de errores y p95 de latencia.
2. ¿Por qué `rate()` y no la diferencia entre dos valores del counter? ¿Qué hace con los reinicios?
3. ¿Por qué el p95 dice más que la media sobre cómo lo viven los usuarios?
4. **Repaso (clase 117, sin mirar):** ¿por qué la etiqueta `path` lleva la plantilla de la ruta?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Estas tres:
   ```promql
   sum(rate(tienda_requests_total[5m]))
   sum(rate(tienda_requests_total{status=~"5.."}[5m])) / sum(rate(tienda_requests_total[5m]))
   histogram_quantile(0.95, sum by (le) (rate(tienda_request_duration_seconds_bucket[5m])))
   ```
2. Porque `rate()` calcula el ritmo con todas las muestras del rango, tiene en cuenta el tiempo real entre ellas y detecta los reinicios: cuando el valor baja, entiende que el proceso empezó de 0 y lo suma en lugar de restarlo. Una resta a mano daría un número negativo después de cada reinicio.
3. Porque la media mezcla a todos: unas pocas peticiones muy lentas la mueven poco, y un valor medio puede no haberlo vivido nadie. El p95 dice el tiempo que **no** superó el 95 % de las peticiones: lo que vive casi todo el mundo, incluidos los que más esperan.
4. Porque cada valor de una etiqueta es una serie nueva. Con la URL, cada id de producto crearía su propia serie y Prometheus crecería sin límite.

**Rómpelo 1:** un resultado vacío. Con un *scrape* cada 15 s, un rango de 15 s contiene como mucho una muestra, y `rate()` necesita al menos dos. Regla: el rango, al menos 4 veces el intervalo de *scrape*.

**Rómpelo 3:** `sum(tienda_requests_total)` cae de golpe (el contador volvió a 0 con el proceso), pero `increase()` sigue dando un valor normal: detecta la bajada y la descuenta. `resets()` dice cuántas veces se reinició cada serie en el rango: 1.

**Rómpelo 4:** `up{job="tienda"}` vale 0, y **Target health** muestra el error (`dial tcp: lookup tienda … no such host`, o `connection refused`). `rate(tienda_requests_total[1m])` deja de devolver datos al minuto: sin muestras nuevas, no hay ritmo. Por eso las alertas de "servicio caído" se escriben sobre `up`, que existe siempre (clase 119).

**Reto 1:**
```promql
sum(rate(tienda_request_duration_seconds_bucket{path="/comprar", le="0.25"}[5m]))
/
sum(rate(tienda_request_duration_seconds_count{path="/comprar"}[5m]))
```
Alrededor del 90 %. Es la base de un SLI de latencia (clase 121), y es exacto, porque `0.25` es un límite de cubo: por eso los cubos se eligen alrededor de tus objetivos.

**Reto 2:** `irate` usa solo las **dos últimas** muestras del rango: reacciona al instante pero sale a picos. `rate` promedia todo el rango y sale más suave. Para alertas, `rate`: no quieres que un pico de 15 segundos despierte a nadie.

**Reto 3:**
```promql
100 * (sum(rate(tienda_requests_total[5m])) / sum(rate(tienda_requests_total[5m] offset 10m)) - 1)
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| scrape config / job / instance | configuración de lectura / grupo de objetivos / objetivo |
| instant vector / range vector | vector instantáneo / vector de rango |
| per-second rate | ritmo por segundo |
| percentile (p95, p99) | percentil |
| retention | retención: cuánto tiempo se guardan los datos |

🎙️ *"For any service I start with three PromQL queries: the request rate, the error ratio and the 95th percentile latency from the histogram buckets. Rate handles counter resets, and I never alert on averages: the tail is what users complain about."*

## Siguiente

[Clase 119 — Reglas de alerta y Alertmanager](clase-119-alertas-y-alertmanager.md)
