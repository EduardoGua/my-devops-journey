# Clase 119 — Reglas de alerta y Alertmanager

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Avisar y entender

> 💡 **La idea de hoy:** una **regla de alerta** es una consulta PromQL con un `for`: si se cumple ese tiempo seguido, la alerta pasa de *pending* a *firing*. Prometheus decide **qué** está mal; **Alertmanager** decide a quién avisar, agrupa los avisos y los silencia en un mantenimiento. Y una alerta se **prueba** antes de que haga falta, con `promtool`, como cualquier otro código.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La tienda, su tráfico y Prometheus en Compose (clase 118); `/errores/{porcentaje}` (clase 117).
> - `up`, `rate()`, las proporciones y los percentiles en PromQL (clases 116 y 118).
> - Un servidor HTTP con la librería estándar de Python (clase 52); los *runbooks* (clase 112).
> - Las pruebas que se pasan en el CI (clase 83).

> 🔤 **Palabras nuevas de hoy:**
> - **regla de alerta**: `expr` (la condición), `for` (cuánto tiempo seguido), `labels` y `annotations`.
> - ***pending* / *firing* / *resolved***: activa sin avisar / disparada / resuelta.
> - **prueba unitaria de una regla**: series simuladas y las alertas que se esperan en cada momento.
> - **Alertmanager**: el que enruta, agrupa, silencia e inhibe los avisos.
> - **receptor** (*receiver*): el destino de un aviso (correo, chat, webhook…).
> - **silencio**: callar unas alertas un tiempo.
> - **inhibición**: si salta una alerta, callar otras que son su consecuencia.
> - **fatiga por alertas**: tantas alertas que se acaban ignorando.

## Objetivo

- Escribir reglas de alerta en Prometheus: la condición, el `for`, las etiquetas y las anotaciones.
- Seguir los estados de una alerta: inactiva, pendiente (*pending*) y disparada (*firing*), hasta su resolución.
- Probar una alerta **antes** de que haga falta, con una prueba unitaria de `promtool`.
- Configurar Alertmanager para que los avisos lleguen a algún sitio, agrupados, y silenciarlos durante un mantenimiento.
- Distinguir una alerta útil de una ruidosa.

## Por qué importa

Un dashboard solo sirve si alguien lo está mirando. Las alertas te miran a ti: te avisan cuando algo se tuerce, aunque estés durmiendo. Por eso tienen que ser **pocas, ciertas y accionables**. Una alerta que salta cada noche sin motivo se acaba ignorando, y el día que el problema es real, nadie la mira. Es el fallo más común de la monitorización, y una pregunta habitual en las entrevistas de SRE.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 30 min, sin arrancar nada: solo `promtool`); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre. La pieza 4 necesita unos 15 minutos de espera: aprovéchalos para leer la pieza 5.

Sigue en la carpeta de la clase 118:

```bash
cd ~/my-devops-journey/labs/clase-118
```

## Las piezas

### Pieza 1 — Una regla de alerta

```yaml
groups:
  - name: tienda
    rules:
      - alert: TiendaMuchosErrores          # el nombre: en CamelCase, dice qué pasa
        expr: sum(rate(tienda_requests_total{status=~"5.."}[5m])) / sum(rate(tienda_requests_total[5m])) > 0.10
        for: 5m                             # tiene que cumplirse 5 minutos seguidos
        labels:
          severity: warning                 # para decidir a quién y cómo se avisa
        annotations:
          summary: "Fallan el {{ $value | humanizePercentage }} de las compras"
```

- `expr` es PromQL: la alerta está activa mientras devuelve algún resultado. Cada serie del resultado es una alerta distinta, con sus etiquetas.
- `for` evita avisos por un pico de un minuto. Mientras no se cumple, la alerta está **pending**; cuando se cumple, pasa a **firing** y Prometheus se la manda a Alertmanager.
- Las `annotations` son el mensaje para quien la recibe: qué pasa, con el valor (`$value`) y las etiquetas (`$labels.url`). Una buena anotación incluye un enlace al *runbook*: qué hacer.

**Pruébalo.** `reglas.yml`:

```yaml
groups:
  - name: tienda
    rules:
      - alert: TiendaCaida
        expr: up{job="tienda"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "La tienda no responde a Prometheus"
      - alert: TiendaMuchosErrores
        expr: sum(rate(tienda_requests_total{status=~"5.."}[5m])) / sum(rate(tienda_requests_total[5m])) > 0.10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Fallan el {{ $value | humanizePercentage }} de las compras"
```

```bash
docker run --rm -v "$PWD:/r" -w /r --entrypoint promtool prom/prometheus:v3.15.0 check rules reglas.yml
```

👀 **Qué deberías ver:** `SUCCESS: 2 rules found`. `check rules` solo mira que se puedan leer. Que **funcionen** es otra cosa (pieza 2).

✋ **Sin mirar:** una regla con `for: 5m` cumple su condición durante 3 minutos y deja de cumplirla. ¿Llega algún aviso?

<details>
<summary>Comprueba</summary>

No: estuvo *pending* 3 minutos y volvió a inactiva sin pasar a *firing*. Nadie se entera.
</details>

**En resumen:** `expr` dice qué, `for` cuánto tiempo, `labels` a quién, `annotations` qué decir.

### Pieza 2 — Probar una alerta sin esperar a que pase

`promtool` simula series a lo largo del tiempo y comprueba qué alertas estarían disparadas en cada momento. En `input_series`, cada serie lleva una lista de valores, uno por intervalo; `'0+50x10'` es una forma corta de "empieza en 0 y suma 50, diez veces".

**Pruébalo.** `reglas_test.yml`:

```yaml
rule_files:
  - reglas.yml
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'up{job="tienda", instance="tienda:8000"}'
        values: '1 1 0 0 0 0'
    alert_rule_test:
      - eval_time: 2m
        alertname: TiendaCaida
        exp_alerts: []
      - eval_time: 4m
        alertname: TiendaCaida
        exp_alerts:
          - exp_labels:
              severity: critical
              job: tienda
              instance: tienda:8000
            exp_annotations:
              summary: "La tienda no responde a Prometheus"
```

`values: '1 1 0 0 0 0'` son seis muestras, una por minuto: arriba dos minutos y caída a partir del minuto 2.

🔮 **Predice:** con `for: 1m`, ¿por qué no debe haber alerta en el minuto 2 y sí en el 4?

```bash
docker run --rm -v "$PWD:/r" -w /r --entrypoint promtool prom/prometheus:v3.15.0 test rules reglas_test.yml
```

👀 **Qué deberías ver:** `SUCCESS`. En el minuto 2 acaba de caer: la alerta está *pending*. En el 4 lleva dos minutos caída, más que su `for`, y está disparada.

Cambia `for: 1m` por `for: 5m` en `TiendaCaida` y repite: la prueba falla y te dice qué esperaba y qué obtuvo:

```
  FAILED:
    alertname: TiendaCaida, time: 4m,
        exp:[ … severity="critical" … ],
        got:[]
```

Devuélvelo a `1m`. Esto es lo que significa "una alerta probada": una prueba que demuestra cuándo salta y cuándo no, y que se pasa en el CI como cualquier otra.

✋ **Sin mirar:** `promtool check rules` dice `SUCCESS`. ¿Sabes ya que la alerta saltará cuando debe?

<details>
<summary>Comprueba</summary>

No: solo sabes que el archivo se puede leer. Que salte cuando debe lo demuestra una prueba unitaria con `promtool test rules`.
</details>

**En resumen:** `check rules` para la sintaxis; `test rules` para el comportamiento.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. No has arrancado nada: mañana empiezas con la pieza 3.

### Pieza 3 — Alertmanager y un receptor

Prometheus decide **qué** está mal; Alertmanager decide **a quién avisar y cómo**:

| Pieza | Para qué |
|-------|----------|
| `route` | por dónde va cada alerta según sus etiquetas: `severity: critical` al móvil, `warning` al chat… |
| `group_by` | junta las alertas parecidas en un solo aviso: diez sitios caídos, un mensaje |
| `group_wait`, `group_interval`, `repeat_interval` | cuánto espera antes del primer aviso, entre avisos de un grupo y para repetir uno que sigue activo |
| `receivers` | los destinos: correo, Slack, Telegram, PagerDuty, un webhook… |
| *silences* | callar unas alertas un tiempo, durante un mantenimiento |
| *inhibit rules* | si salta una, callar otras: si la tienda está caída, no avises además de sus errores |

Cuando la alerta deja de cumplirse, Alertmanager manda el aviso de **resuelta** (*resolved*), salvo que se lo prohíbas.

**Pruébalo.** Para ver los avisos sin configurar correo ni chat, un receptor mínimo: un servidor HTTP que escribe en su log lo que le manda Alertmanager. `receptor.py`:

```python
"""Recibe los avisos de Alertmanager por webhook y los escribe en su log."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Receptor(BaseHTTPRequestHandler):
    def do_POST(self):
        aviso = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        for alerta in aviso["alerts"]:
            nombre = alerta["labels"]["alertname"]
            resumen = alerta["annotations"].get("summary", "")
            print(f"{alerta['status'].upper():9} {nombre}: {resumen}", flush=True)
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass   # sin el log de cada petición


HTTPServer(("0.0.0.0", 8000), Receptor).serve_forever()
```

`alertmanager.yml`:

```yaml
route:
  receiver: receptor
  group_by: ["alertname"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
receivers:
  - name: receptor
    webhook_configs:
      - url: http://receptor:8000/
```

```bash
docker run --rm -v "$PWD:/r" -w /r --entrypoint amtool prom/alertmanager:v0.34.1 check-config alertmanager.yml
```

En `prometheus.yml`, debajo de `global`, carga las reglas y di dónde está Alertmanager:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - reglas.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]
```

`reglas.yml` se busca en la carpeta de `prometheus.yml`. En `compose.yaml`, monta las reglas en el servicio `prometheus`:

```yaml
      - ./reglas.yml:/etc/prometheus/reglas.yml:ro
```

y añade los dos servicios nuevos:

```yaml
  alertmanager:
    image: prom/alertmanager:v0.34.1
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    ports:
      - "127.0.0.1:9093:9093"
  receptor:
    image: python:3.14-slim
    command: ["python", "-u", "/receptor.py"]
    volumes:
      - ./receptor.py:/receptor.py:ro
```

```bash
docker compose up -d --build
```

👀 **Qué deberías ver:** `amtool` dice `Checking 'alertmanager.yml'  SUCCESS` y lista `1 receivers`. En http://127.0.0.1:9090 → **Alerts**: las dos reglas, inactivas. En http://127.0.0.1:9093, la web de Alertmanager, vacía.

✋ **Sin mirar:** diez réplicas de la tienda caen a la vez. Con `group_by: ["alertname"]`, ¿cuántos avisos recibes?

<details>
<summary>Comprueba</summary>

Uno, con las diez alertas dentro: todas se llaman `TiendaCaida`.
</details>

**En resumen:** Prometheus dispara; Alertmanager agrupa, espera y avisa.

### Pieza 4 — Provocar un incidente

Una alerta pasa por tres momentos: *pending* (la condición se cumple), *firing* (se cumplió durante todo el `for`) y *resolved* (dejó de cumplirse). Entre el *firing* y el aviso, Alertmanager espera el `group_wait`.

**Pruébalo:**

```bash
curl -s -X POST localhost:8080/errores/50
```

Abre la pestaña **Alerts** de Prometheus y recárgala cada minuto.

🔮 **Predice:** ¿cuándo pasará `TiendaMuchosErrores` a *pending*, cuándo a *firing* y cuándo llegará al receptor?

👀 **Qué deberías ver:** en mis pruebas:
- a los **90 segundos**, *pending*: la proporción de errores en 5 minutos superó el 10 %;
- a los **6 minutos y medio**, *firing*: 5 minutos más;
- unos 30 segundos después (el `group_wait`), en el receptor:

```bash
docker compose logs receptor --no-log-prefix
```

```
FIRING    TiendaMuchosErrores: Fallan el 50.77% de las compras
```

Ahora el otro: para la tienda y espera un par de minutos.

```bash
curl -s -X POST localhost:8080/errores/5
docker compose stop tienda
```

`TiendaCaida` salta en algo más de un minuto. Vuelve a arrancarla (`docker compose start tienda`) y espera unos 7 minutos: llegan los dos avisos de resuelta.

```
FIRING    TiendaCaida: La tienda no responde a Prometheus
RESOLVED  TiendaCaida: La tienda no responde a Prometheus
RESOLVED  TiendaMuchosErrores: Fallan el 12.57% de las compras
```

El aviso de resuelta lleva el **último** valor con el que la alerta estaba activa (12,57 %), no el actual. No lo leas como "aún falla el 12 %".

✋ **Sin mirar:** ¿por qué `TiendaMuchosErrores` tardó unos 90 segundos en pasar a *pending*, si los errores subieron al 50 % al instante?

<details>
<summary>Comprueba</summary>

Porque la expresión usa `rate(…[5m])`: la proporción en 5 minutos sube poco a poco, y tardó ese rato en superar el 10 %.
</details>

**En resumen:** *pending*, *firing* tras el `for`, aviso tras el `group_wait`, y *resolved* con el último valor.

### Pieza 5 — Silenciar un mantenimiento, y alertas útiles

Un silencio calla en Alertmanager las alertas que casan con sus etiquetas, durante un tiempo. Prometheus las sigue evaluando: solo deja de avisarse.

Y la diferencia entre una alerta que ayuda y una que molesta:

| Útil | Ruidosa |
|------|---------|
| por un **síntoma** que nota el usuario: errores, latencia, "no responde" | por una causa que puede no importar: CPU al 80 %, un disco al 70 % |
| con `for`: unos minutos seguidos | sin `for`: salta y se apaga con cada pico |
| con una acción clara: qué miro, qué hago | "investigar" |
| probada: la has visto saltar y resolverse | "debería funcionar" |
| en un canal que alguien mira, según su urgencia | todo al mismo correo, que nadie abre |

**Pruébalo.** Vas a parar la tienda a propósito durante una hora. Silencia su alerta antes:

```bash
docker run --rm --network host --entrypoint amtool prom/alertmanager:v0.34.1 \
  --alertmanager.url=http://127.0.0.1:9093 silence add alertname=TiendaCaida \
  --duration=1h --comment="mantenimiento de la tienda" --author=eduardo
docker run --rm --network host --entrypoint amtool prom/alertmanager:v0.34.1 \
  --alertmanager.url=http://127.0.0.1:9093 silence query
```

👀 **Qué deberías ver:** el primero imprime el ID del silencio; el segundo, una tabla con ese ID, `alertname="TiendaCaida"`, la hora de fin, tu nombre y el comentario. El silencio aparece también en la web de Alertmanager. Quítalo con `silence expire <ID>`.

✋ **Sin mirar:** "la CPU de la tienda pasa del 80 %": ¿es una buena alerta para despertar a alguien?

<details>
<summary>Comprueba</summary>

No: es una causa que puede no importar (la tienda puede ir perfecta al 80 %). Se avisa por síntomas que nota el usuario: errores, latencia, "no responde".
</details>

**En resumen:** silencios para lo previsto; alertas por síntomas, con `for`, acción y prueba.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `- alert: X` + `expr` + `for` + `labels` + `annotations` | una regla de alerta |
| `{{ $value \| humanizePercentage }}` · `{{ $labels.instance }}` | el valor y las etiquetas en el mensaje |
| `promtool check rules reglas.yml` | ¿se puede leer? |
| `promtool test rules reglas_test.yml` | ¿salta cuando debe? |
| `values: '1 1 0 0'` · `'0+50x10'` | series simuladas |
| `rule_files` + `alerting.alertmanagers` en `prometheus.yml` | cargar reglas y avisar |
| `route` + `group_by` + `group_wait` + `receivers` | cómo y a quién avisa Alertmanager |
| `amtool check-config` · `amtool silence add …` · `silence query` · `silence expire` | validar y silenciar |
| `inhibit_rules: [{source_matchers, target_matchers}]` | callar las consecuencias |

## Rómpelo

1. **Sin `for`.** Quita el `for` de `TiendaMuchosErrores` y baja el umbral a `> 0.06`. Con los errores normales del 5 %, ¿cuántas veces salta y se apaga en 15 minutos? (Mira la pestaña **Alerts** y el receptor.) Es una alerta ruidosa de manual. Devuélvela.
2. **Una errata en la métrica.** Cambia `tienda_requests_total` por `tienda_request_total` en la expresión de `TiendaMuchosErrores`. `promtool check rules` dice `SUCCESS`. ¿Saltaría alguna vez? Escribe una prueba unitaria que lo habría pillado.
3. **Avisos duplicados.** Cambia `group_by: ["alertname"]` por `group_by: ["..."]` (agrupar por **todas** las etiquetas). Con un servicio de diez réplicas caído, ¿cuántos avisos recibirías?

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Una inhibición:** si `TiendaCaida` está disparada, que Alertmanager no avise de `TiendaMuchosErrores`.

> 🧩 **Ejemplo resuelto:** la pieza 5: un silencio calla `alertname=TiendaCaida` durante una hora, a mano.

**Ahora tú, con huecos.** Añade a `alertmanager.yml`:
```yaml
inhibit_rules:
  - source_matchers: ['alertname="____"']
    target_matchers: ['alertname="____"']
```
Valídalo con `amtool check-config` y pruébalo parando la tienda con los errores al 50 %.

<details>
<summary>Pista</summary>

`source` es la alerta que, si está disparada, calla; `target`, la que se calla. `amtool check-config` debe decir `1 inhibit rules`.
</details>

**2.** Escribe `TiendaLenta`: el p95 de `/comprar` por encima de 500 ms durante 10 minutos, y su prueba unitaria.

> 🧩 **Ejemplo resuelto:** el p95 de la clase 118: `histogram_quantile(0.95, sum by (le) (rate(tienda_request_duration_seconds_bucket{path="/comprar"}[5m])))`.

**Ahora tú, con huecos.** La regla:
```yaml
      - alert: TiendaLenta
        expr: histogram_quantile(0.95, sum by (le) (rate(tienda_request_duration_seconds_bucket{path="/comprar"}[5m]))) > ____
        for: ____
        labels:
          severity: warning
        annotations:
          summary: "El p95 de las compras es de {{ $value | humanizeDuration }}"
```
Y en la prueba, cubos acumulados que crecen cada minuto: 50 por debajo de `0.25`, 80 por debajo de `0.5` y 100 en `1` y en `+Inf`:
```yaml
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="0.25"}'
        values: '0+50x20'
      # … le="0.5" con '0+____x20', le="1" y le="+Inf" con '0+____x20'
```
Con `exp_alerts: []` en el minuto 5 y la alerta en el 15.

<details>
<summary>Pista</summary>

Si el 80 % tarda 0,5 s o menos, el p95 está por encima: Prometheus lo interpola entre 0,5 y 1. Si la prueba falla porque "faltan" anotaciones, copia en `exp_annotations` el `summary` que te enseña en `got`.
</details>

**3.** Un canal de verdad: Alertmanager admite `telegram_configs` y `discord_configs`. Configura uno con el token en un archivo **fuera de Git** (`bot_token_file`). ¿Te llega el aviso al móvil?

> 🧩 **Ejemplo resuelto:** la pieza 3: el receptor `receptor` con `webhook_configs` y una `url`.

**Ahora tú, con huecos:**
```yaml
receivers:
  - name: movil
    telegram_configs:
      - bot_token_file: /etc/alertmanager/____
        chat_id: ____
```
Y el archivo montado en el servicio `alertmanager`, con su ruta en `.gitignore`.

<details>
<summary>Pista</summary>

El token se lo pide a `@BotFather` en Telegram; el `chat_id`, escribiendo a tu bot y leyendo `https://api.telegram.org/bot<token>/getUpdates`. Nunca pegues el token en `alertmanager.yml`.
</details>

## Destruir al terminar

```bash
docker compose down
```

Sin `-v`: la clase 120 añade Grafana a esta misma carpeta.

## Cierre

En `notas/fase-10/clase-119.md`:

1. ¿Qué hace el `for` de una regla? ¿Qué es una alerta *pending*? *(2 líneas. Empieza así: «Exige que la condición se cumpla de forma continua…»)*
2. ¿Qué hace Prometheus y qué hace Alertmanager? *(2 líneas, una por pieza.)*
3. Tres rasgos de una alerta útil y tres de una ruidosa. *(2 líneas: «Útil: …, … y …. Ruidosa: …»)*
4. **Repaso (clase 118, sin mirar):** ¿por qué el rango de un `rate()` debe abarcar al menos cuatro *scrapes*? *(1–2 líneas.)*

Después, escríbeme `examíname clase-119`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Exige que la condición se cumpla de forma continua durante ese tiempo antes de avisar. Mientras se cumple pero aún no ha pasado el `for`, la alerta está *pending*: activa, pero sin avisar. Si en ese rato la condición deja de cumplirse, vuelve a inactiva sin que nadie se entere.
2. Prometheus evalúa las reglas cada `evaluation_interval` y decide qué alertas están activas. Alertmanager recibe las disparadas y decide a quién, cuándo y cómo avisar: las enruta, las agrupa, las silencia, las inhibe y avisa de cuando se resuelven.
3. **Útil:** por un síntoma que notan los usuarios, con un `for` razonable, con una acción clara (un *runbook*), probada. **Ruidosa:** por una causa que puede no importar, sin `for`, sin acción ("investigar"), que salta tanto que se ignora.
4. Porque `rate()` necesita al menos dos muestras, y con cuatro o más el resultado es estable: si falla un *scrape* o una muestra llega tarde, sigue habiendo suficientes.

**Rómpelo 1:** varias veces: con un 5 % de media, la proporción en 5 minutos sube y baja alrededor del 6 %, y cada cruce es una alerta y su resolución. Un `for` y un umbral con margen sobre lo normal la convierten en útil.

**Rómpelo 2:** nunca: la métrica mal escrita no existe, la expresión no devuelve nada y la alerta se queda inactiva para siempre. Esta prueba lo habría pillado (con la errata, `FAILED … TiendaMuchosErrores, time: 8m`):
```yaml
  - interval: 1m
    input_series:
      - series: 'tienda_requests_total{path="/comprar", status="200"}'
        values: '0+50x10'
      - series: 'tienda_requests_total{path="/comprar", status="500"}'
        values: '0+50x10'
    alert_rule_test:
      - eval_time: 8m
        alertname: TiendaMuchosErrores
        exp_alerts:
          - exp_labels:
              severity: warning
            exp_annotations:
              summary: "Fallan el 50% de las compras"
```

**Rómpelo 3:** diez, uno por réplica, porque cada una tiene un `instance` distinto. Agrupando por `alertname` (y, si acaso, `job`), uno solo con las diez dentro.

**Reto 1:**
```yaml
inhibit_rules:
  - source_matchers: ['alertname="TiendaCaida"']
    target_matchers: ['alertname="TiendaMuchosErrores"']
```

**Reto 2:** `> 0.5` y `for: 10m`; los cubos, `'0+80x20'` para `le="0.5"` y `'0+100x20'` para `le="1"` y `le="+Inf"`. La prueba completa:
```yaml
  - interval: 1m
    input_series:
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="0.25"}'
        values: '0+50x20'
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="0.5"}'
        values: '0+80x20'
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="1"}'
        values: '0+100x20'
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="+Inf"}'
        values: '0+100x20'
    alert_rule_test:
      - eval_time: 5m
        alertname: TiendaLenta
        exp_alerts: []
      - eval_time: 15m
        alertname: TiendaLenta
        exp_alerts:
          - exp_labels:
              severity: warning
            exp_annotations:
              summary: "El p95 de las compras es de 875ms"
```
875 ms: el 95 % cae entre el 80 % (0,5 s) y el 100 % (1 s), y Prometheus interpola: 0,5 + 0,15 / 0,20 × 0,5.

**Reto 3:** `bot_token_file: /etc/alertmanager/telegram_token` (o el nombre que elijas) y tu `chat_id` numérico. El archivo se monta en el servicio y su ruta va a `.gitignore`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| alerting rule | regla de alerta |
| pending / firing / resolved | pendiente / disparada / resuelta |
| routing / grouping / inhibition / silence | enrutar / agrupar / inhibir / silenciar |
| alert fatigue | fatiga por alertas: tantas que se ignoran |
| runbook | guía de qué hacer cuando salta una alerta |
| on-call | guardia |

🎙️ *"I alert on symptoms users feel, like the error ratio or the service being down, always with a for clause and a runbook link. Every alert has a promtool unit test that shows when it fires and when it doesn't, and Alertmanager groups, routes and silences the notifications."*

## Siguiente

[Clase 120 — Grafana: dashboards como código](clase-120-grafana.md)
