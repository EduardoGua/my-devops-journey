# Clase 121 — SLI, SLO, SLA y presupuesto de errores

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** B. Avisar y entender

## Objetivo

- Distinguir SLI, SLO y SLA, y escribir uno de cada para un servicio.
- Calcular cuánto tiempo caído permite un SLO al mes: el **presupuesto de errores**.
- Medir los SLI de la tienda con reglas de registro (*recording rules*) de Prometheus.
- Alertar por la **velocidad** a la que se gasta el presupuesto, con dos ventanas, y probarlo con `promtool`.

## Por qué importa

"¿Está bien el servicio?" no se puede responder sin decir antes qué es "bien". Un SLO lo convierte en un número que todos aceptan: producto, desarrollo y operaciones. Y el presupuesto de errores lo vuelve una herramienta de decisión. Si sobra presupuesto, se puede arriesgar con despliegues; si se ha gastado, se congela lo nuevo y se trabaja en la fiabilidad.

Es el corazón de SRE (*Site Reliability Engineering*), tal como lo cuenta Google, y una de las preguntas que separan a quien "monitoriza" de quien opera un servicio. Es también un criterio de salida de esta fase.

## Teoría

### Tres siglas

| | Qué es | Ejemplo para la tienda |
|-|--------|------------------------|
| **SLI** (*indicator*) | una medida de lo que vive el usuario, casi siempre una proporción: eventos buenos entre eventos válidos | la parte de las compras que no terminan en 5xx; la parte que tarda 250 ms o menos |
| **SLO** (*objective*) | el objetivo para ese SLI, en una ventana de tiempo | el 95 % de las compras, sin error, en 30 días |
| **SLA** (*agreement*) | una promesa a un cliente, con consecuencias si se incumple (devoluciones, penalizaciones) | "si baja del 90 %, devolvemos el 10 % de la factura" |

El SLO es interno y más exigente que el SLA: te avisa antes de que incumplas lo que prometiste. Muchos servicios tienen SLO y ningún SLA.

Un buen SLI se mide **lo más cerca posible del usuario**. Un 500 que la API nunca llega a ver (porque el balanceador no encontró ninguna réplica) no aparece en las métricas de la API. Aquí medirás en la tienda, sabiendo que es una aproximación.

### El presupuesto de errores

Si el SLO es del 99 %, el 1 % restante es lo que **puedes** fallar: tu presupuesto. En 30 días:

| SLO | Presupuesto (30 días) |
|-----|-----------------------|
| 95 % | 36 horas |
| 99 % | 7 h 12 min |
| 99,5 % | 3 h 36 min |
| 99,9 % | 43 min 12 s |
| 99,95 % | 21 min 36 s |
| 99,99 % | 4 min 19 s |

Cada "nueve" más divide el presupuesto entre diez, y cuesta mucho más conseguirlo. Un 100 % no es un objetivo: es la ausencia de presupuesto, y significa no poder desplegar nunca nada.

### La velocidad de consumo (*burn rate*)

```
consumo = (1 − SLI en una ventana) / (1 − SLO)
```

- **1** significa que, a ese ritmo, el presupuesto se acaba justo al terminar la ventana del SLO (30 días).
- **10** significa que se acaba en 3 días.

Alertar sobre el consumo, y no sobre los errores a secas, avisa solo cuando el presupuesto **corre peligro**. Para no despertar a nadie por un pico de 5 minutos y, a la vez, enterarse pronto de lo grave, se miran **dos ventanas** a la vez: una larga, que confirma que el problema es serio, y una corta, que confirma que sigue pasando ahora. Los valores que propone Google en su *SRE Workbook*:

| Avisar si se gasta… | Ventana larga | Ventana corta | Consumo | Cómo |
|---------------------|---------------|---------------|---------|------|
| 2 % del presupuesto en 1 hora | 1 h | 5 min | > 14,4 | despertar a alguien |
| 5 % en 6 horas | 6 h | 30 min | > 6 | despertar a alguien |
| 10 % en 3 días | 3 días | 6 h | > 1 | un ticket |

### Reglas de registro

Las consultas de los SLI son largas y se usan en muchos sitios (paneles, alertas). Una **regla de registro** las calcula cada `evaluation_interval` y guarda el resultado como una serie nueva, con un nombre que sigue la convención `nivel:métrica:operación`:

```yaml
- record: tienda:sli_disponibilidad:ratio_rate5m
  expr: sum(rate(tienda_requests_total{status!~"5.."}[5m])) / sum(rate(tienda_requests_total[5m]))
```

## Práctica guiada

Sigue en `~/my-devops-journey/labs/clase-118`, con todo arrancado (`docker compose up -d`).

### 1. Elegir el SLO de la tienda (10 min)

La tienda falla, a propósito, el 5 % de las veces. Con un SLO del 99 % estaría siempre incumpliéndolo. Para el laboratorio, el SLO es:

> **El 95 % de las compras termina sin error 5xx, en una ventana de 30 días.**

🔮 **Predice:** ¿cuánto tiempo de fallo total permite al mes? ¿Y a qué ritmo se gastará el presupuesto con el 5 % de errores de siempre?

### 2. Los SLI como reglas de registro (20 min)

`slo.yml`:

```yaml
groups:
  - name: tienda-slo
    rules:
      # SLI de disponibilidad: la parte de las peticiones que NO terminan en 5xx
      - record: tienda:sli_disponibilidad:ratio_rate5m
        expr: sum(rate(tienda_requests_total{status!~"5.."}[5m])) / sum(rate(tienda_requests_total[5m]))
      - record: tienda:sli_disponibilidad:ratio_rate1h
        expr: sum(rate(tienda_requests_total{status!~"5.."}[1h])) / sum(rate(tienda_requests_total[1h]))
      # SLI de latencia: la parte de las compras que tardan 250 ms o menos
      - record: tienda:sli_latencia:ratio_rate5m
        expr: sum(rate(tienda_request_duration_seconds_bucket{path="/comprar", le="0.25"}[5m])) / sum(rate(tienda_request_duration_seconds_count{path="/comprar"}[5m]))
      # Velocidad de consumo con un SLO del 95 %: 1 = se gasta justo en 30 días
      - record: tienda:presupuesto_consumo:rate5m
        expr: (1 - tienda:sli_disponibilidad:ratio_rate5m) / (1 - 0.95)
      - record: tienda:presupuesto_consumo:rate1h
        expr: (1 - tienda:sli_disponibilidad:ratio_rate1h) / (1 - 0.95)
      - alert: TiendaQuemaPresupuesto
        expr: tienda:presupuesto_consumo:rate1h > 6 and tienda:presupuesto_consumo:rate5m > 6
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "La tienda gasta su presupuesto de errores {{ $value | printf \"%.1f\" }} veces más rápido de lo sostenible"
```

Añádelo a `rule_files` de `prometheus.yml` (debajo de `reglas.yml`) y móntalo en el servicio `prometheus` de `compose.yaml`, como `reglas.yml`:

```yaml
      - ./slo.yml:/etc/prometheus/slo.yml:ro
```

```bash
docker run --rm -v "$PWD:/r" -w /r --entrypoint promtool prom/prometheus:v3.15.0 check rules slo.yml
docker compose up -d
```

Espera cinco minutos y consulta las series nuevas: `tienda:sli_disponibilidad:ratio_rate5m`, `tienda:sli_latencia:ratio_rate5m` y `tienda:presupuesto_consumo:rate5m`. En mis pruebas: **disponibilidad 0,94, latencia 0,91 y consumo 1,3**. El consumo baila alrededor de 1, porque el 5 % de errores es, justo, todo el presupuesto.

### 3. Un incidente y su consumo (15 min)

```bash
curl -s -X POST localhost:8080/errores/50
```

Grafica `tienda:presupuesto_consumo:rate5m` y `tienda:presupuesto_consumo:rate1h` juntas durante cinco minutos.

🔮 **Predice:** ¿cuál sube antes? ¿Saltará `TiendaQuemaPresupuesto` en esos cinco minutos?

En mis pruebas, a los cinco minutos: **consumo en 5 minutos, 9,5; en 1 hora, 4,2**. La ventana corta ya grita, pero la larga aún no llega a 6: la alerta no salta. Si el problema siguiera unos minutos más, la ventana larga pasaría de 6 y saltaría. Y si lo arreglas antes, no habrá despertado a nadie por algo que se resolvió solo. Vuelve al 5 % (`curl -s -X POST localhost:8080/errores/5`).

### 4. Probar la alerta de consumo sin esperar una hora (15 min)

Nadie espera una hora a que salte una alerta para ver si funciona: se simula. `slo_test.yml` genera 180 compras por minuto, una hora al 5 % de errores y, desde el minuto 60, al 50 %:

```yaml
rule_files:
  - slo.yml
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'tienda_requests_total{path="/comprar", status="200"}'
        values: '0+171x60 10260+90x60'
      - series: 'tienda_requests_total{path="/comprar", status="500"}'
        values: '0+9x60 540+90x60'
    alert_rule_test:
      - eval_time: 70m
        alertname: TiendaQuemaPresupuesto
        exp_alerts: []
      - eval_time: 100m
        alertname: TiendaQuemaPresupuesto
        exp_alerts:
          - exp_labels:
              severity: critical
            exp_annotations:
              summary: "La tienda gasta su presupuesto de errores 7.1 veces más rápido de lo sostenible"
    promql_expr_test:
      - expr: round(tienda:presupuesto_consumo:rate5m, 0.1)
        eval_time: 50m
        exp_samples:
          - value: 1
      - expr: round(tienda:presupuesto_consumo:rate5m, 0.1)
        eval_time: 70m
        exp_samples:
          - value: 10
```

`'0+171x60 10260+90x60'` se lee: empieza en 0 y suma 171 cada minuto, 60 veces; después sigue desde 10 260 sumando 90.

```bash
docker run --rm -v "$PWD:/r" -w /r --entrypoint promtool prom/prometheus:v3.15.0 test rules slo_test.yml
```

`SUCCESS`. A los 10 minutos del incidente (minuto 70), el consumo de 5 minutos ya es 10, pero el de una hora no llega a 6: sin alerta. A los 40 minutos (minuto 100), el de una hora pasa de 7 y la alerta está disparada. `round(…, 0.1)` redondea a una décima, porque las cuentas con decimales no salen exactas y la prueba compara el valor tal cual.

## Rómpelo

1. **Un SLO del 100 %.** Cambia `0.95` por `1` en las dos reglas de consumo y aplica. ¿Qué valor sale? ¿Qué te dice eso de un objetivo del 100 %? Devuélvelo.
2. **Un umbral entre cubos.** Cambia el SLI de latencia a 300 ms (`le="0.3"`). ¿Qué devuelve? ¿Por qué? (Mira los `buckets` de la clase 117.)
3. **Una sola ventana.** Quita la condición de la ventana larga de `TiendaQuemaPresupuesto` (deja solo la de 5 minutos) y vuelve a pasar `slo_test.yml`. ¿Qué parte falla? ¿Qué significaría en una guardia real?

## Reto

1. Escribe el SLO de **latencia** de la tienda: "el 90 % de las compras, en 250 ms o menos, en 30 días". ¿Cuánto presupuesto da? Añade su regla de consumo.
2. Añade al dashboard de la clase 120 un panel **Stat** con el consumo de una hora, verde por debajo de 1, amarillo hasta 6 y rojo por encima.
3. Para Vigía (clase 124): ¿qué SLI medirías **de Vigía**, no de los sitios que vigila? Escribe un SLO con su ventana y su presupuesto en minutos al mes.

## Destruir al terminar

```bash
docker compose down
```

## Cierre

En `notas/fase-10/clase-121.md`:

1. Explica SLI, SLO y SLA con un ejemplo, como en una entrevista.
2. ¿Cuánto tiempo caído permite al mes un SLO del 99,9 %? ¿Y uno del 99,5 %? Haz la cuenta.
3. ¿Por qué se alerta sobre la velocidad de consumo con dos ventanas, y no sobre los errores a secas?
4. **Repaso (clase 120, sin mirar):** ¿por qué no se puede guardar desde la interfaz un dashboard aprovisionado?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Práctica 1:** 36 horas en 30 días (el 5 % de 720 horas). Con un 5 % de errores constante, el consumo es 1: el presupuesto se gasta justo al terminar la ventana.

**Cierre:**
1. El **SLI** es lo que mides: por ejemplo, la parte de las compras sin error. El **SLO**, el objetivo interno para ese SLI en una ventana: el 99,5 % en 30 días. El **SLA**, una promesa a un cliente con consecuencias si se incumple, más laxa que el SLO: el 99 %, o se devuelve parte de la factura. El SLO avisa antes de llegar a incumplir el SLA.
2. 30 días son 43 200 minutos. Con el 99,9 %, el 0,1 %: **43 min 12 s**. Con el 99,5 %, el 0,5 %: **216 minutos, 3 h 36 min**.
3. Porque lo que importa es si el presupuesto corre peligro. Un 20 % de errores durante dos minutos apenas gasta presupuesto, y un 2 % durante días lo agota. La ventana larga confirma que el gasto es serio (y no un pico); la corta, que sigue pasando ahora (y la alerta se apaga pronto cuando se arregla). Juntas, avisan de lo importante, a tiempo, y sin ruido.
4. Porque la verdad está en el archivo de Git. Lo que se guardara desde la interfaz viviría solo en esa instancia y se perdería en el siguiente despliegue.

**Rómpelo 1:** con `1 - 1 = 0` en el denominador, sale `+Inf`: cualquier error, por pequeño que sea, es un consumo infinito. Un SLO del 100 % no deja margen para nada, ni para desplegar, ni para que un disco falle.

**Rómpelo 2:** vacío (o `NaN`): no existe ningún cubo con `le="0.3"`, solo `0.25` y `0.5`. Por eso los cubos se eligen alrededor de los umbrales de tus SLO.

**Rómpelo 3:** fallan las dos comprobaciones de la alerta. La del minuto 70, porque con una sola ventana corta la alerta salta a los pocos minutos del incidente, y saltaría también con cada pico breve. La del minuto 100, porque `$value` es ahora el consumo de 5 minutos (10) y no el de una hora. En una guardia, eso son despertares por problemas que se arreglaban solos: fatiga por alertas.

**Reto 1:** el 10 % de 30 días: 72 horas de "compras lentas" permitidas. La regla: `(1 - tienda:sli_latencia:ratio_rate5m) / (1 - 0.90)`.

**Reto 3:** por ejemplo: "Vigía completa un chequeo de cada sitio al menos cada 5 minutos, el 99 % del tiempo, en 30 días" (7 h 12 min de presupuesto), o "la API de Vigía responde a Prometheus el 99,5 % de los *scrapes*, en 30 días" (3 h 36 min). Mide lo que Vigía promete hacer, no la disponibilidad de los sitios, que no controla.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| service level indicator / objective / agreement | indicador / objetivo / acuerdo de nivel de servicio |
| error budget | presupuesto de errores |
| burn rate | velocidad de consumo del presupuesto |
| multiwindow alert | alerta con varias ventanas |
| recording rule | regla de registro |

🎙️ *"Our SLO is 99.5% of checks completed in a 30-day window, which is a 3 hours 36 minutes error budget. We alert on the burn rate with a long and a short window, so we page only when the budget is actually at risk, and the alert clears quickly once it's fixed."*

## Siguiente

[Clase 122 — Logs estructurados y postmortems](clase-122-logs-y-postmortems.md)
