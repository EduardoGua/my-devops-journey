# Clase 124 — Proyecto: Vigía v7: métricas, alerta y SLO

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto y cierre de la ruta · **Proyecto de portafolio**

## Objetivo

Cerrar la última versión de Vigía: que **se vigile a sí mismo** y avise.
- La API publica `/metrics`: el estado de cada sitio y su propio RED.
- Prometheus lo recoge; una alerta salta cuando un sitio lleva más de 5 minutos caído, y está probada.
- Grafana muestra la disponibilidad y la latencia de cada sitio.
- Vigía tiene un SLO, con su presupuesto de errores.

Todo arranca con el mismo `docker compose up -d` que Vigía.

Criterios de salida de la fase que cumples aquí:
- *Vigía expone `/metrics` y Prometheus lo recoge*;
- *un dashboard con disponibilidad y latencia por sitio*;
- *una alerta que salta cuando un sitio cae más de 5 minutos, y probada*;
- *un SLO para Vigía y cuánto tiempo caído permite al mes*.

## Costo esperado

> 💰 **0 USD.** Todo corre en tu portátil, con Compose. Apaga el cluster de kind mientras trabajas: `docker stop lab-control-plane cloud-provider-kind`.

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | `/metrics` en la API, con estas métricas:<br>• `vigia_site_up{url}` (gauge: 1 o 0, del último chequeo);<br>• `vigia_site_response_seconds{url}` (gauge);<br>• `vigia_site_last_check_timestamp_seconds{url}` (gauge, hora Unix);<br>• `vigia_checks_total{url, result}` (counter, con `result` = `up` o `down`);<br>• `vigia_http_requests_total{path, status}` (counter) y `vigia_http_request_duration_seconds{path}` (histogram).<br>Las de los sitios salen de los **últimos resultados de la base de datos**, en cada *scrape* | 117 |
| R2 | La observabilidad en Git, en `observabilidad/`, y arrancada con el mismo `docker compose up -d` que Vigía: Prometheus 3.15, Alertmanager 0.34 y Grafana 13, con volúmenes y con los puertos 9090, 9093 y 3000 solo en `127.0.0.1` | 118–120 |
| R3 | Prometheus lee la API cada 15 segundos, en el job `vigia` | 118 |
| R4 | Alertas con `severity` y `summary`:<br>• `VigiaSitioCaido`: un sitio caído más de 5 minutos;<br>• `VigiaApiCaida`: Prometheus no puede leer la API;<br>• y las que tú añadas (el checker se ha parado, la base de datos no responde…) | 119 |
| R5 | Pruebas unitarias de las alertas con `promtool test rules`, en Git | 119 |
| R6 | Alertmanager con un receptor (el webhook de la clase 119 o un canal real), y la alerta **probada de punta a punta**: un sitio caído más de 5 minutos llega como `FIRING` y después como `RESOLVED` | 119 |
| R7 | Grafana aprovisionado desde archivos: la fuente de datos Prometheus y un dashboard **Vigía** con la disponibilidad y la latencia de cada sitio, y el RED de la API | 120 |
| R8 | El SLO **de Vigía**, en el README: SLI, objetivo, ventana y presupuesto en minutos al mes. Reglas de registro `vigia:…` para el SLI, y un panel que lo muestre | 121 |
| R9 | Ningún secreto en Git: `GRAFANA_ADMIN_PASSWORD` en `.env`, y en `.env.example` con un valor de ejemplo | 120 |
| R10 | `verify.sh` → `Fallos: 0`, y `verify.sh --alerta` también | — |
| R11 | En el README:<br>• una sección *Observability*: qué mide, qué alerta, el SLO y cómo se prueba;<br>• *What broke and how I found it*;<br>• *Limitations*.<br>Etiqueta `v7` y su release | — |

Los nombres son parte del contrato, porque `verify.sh` los busca así.

## Plan de trabajo

**Bloque 1: `/metrics` y Prometheus**

1. Rama `v7`. Añade `prometheus-client==0.26.0` a `requirements.txt` y sube la versión a 7.0.0.
2. **La pregunta de diseño:** ¿dónde viven las métricas de los sitios? El chequeo lo hace el checker, que es **otro proceso** (en Compose, un bucle; en Kubernetes, un CronJob que vive unos segundos). Lo que comparten la API y el checker es la base de datos. Por eso la API publica en `/metrics` lo que lee de PostgreSQL en cada *scrape*. Lee la pista 1 antes de escribir código.
3. Las métricas de la propia API, con un *middleware*, como en la clase 117 (pista 2).
4. Comprueba `/metrics` a mano, con `curl` y con Vigía arrancada.
5. `observabilidad/`: el Compose de Prometheus, Alertmanager, Grafana y el receptor, con su configuración. Inclúyelo desde tu `compose.yaml` (pista 3). Prometheus, en *Target health*: el job `vigia`, `UP`.

**Bloque 2: alertas, Grafana y SLO**

6. Las reglas de alerta (R4) y sus pruebas (R5). Escribe primero la prueba de `VigiaSitioCaido`: un sitio caído 4 minutos (no salta) y 6 minutos (salta) (pista 4).
7. Alertmanager y el receptor (R6). Pruébalo de punta a punta: añade a tu `config.yaml` `https://caido.invalid`, reinicia el checker y espera. Apunta las horas de *pending*, *firing* y la llegada al receptor; quítalo y espera la resolución. Es la evidencia del criterio de salida, y el material de tu sección *What broke*.
8. Grafana (R7): el dashboard, diseñado en la interfaz y exportado con su API, como en la clase 120.
9. El SLO (R8). Elige un SLI **de Vigía**, no de los sitios que vigila (pista 5), escribe sus reglas de registro y su panel.
10. Las pruebas de aceptación, y el README:

    ```bash
    cd ~/vigia
    bash ~/my-devops-journey/recursos/vigia/v7/verify.sh
    bash ~/my-devops-journey/recursos/vigia/v7/verify.sh --alerta
    ```

### Las pruebas de aceptación

`verify.sh` mira:
- **el repositorio:** `promtool check config` y tus `promtool test rules`, más una prueba suya sobre tus reglas (un sitio caído 7 minutos salta; 4 minutos o uno que parpadea, no), el SLO en el README y `.env` fuera de Git;
- **los servicios:** que todo arranca y que los puertos solo se publican en `127.0.0.1`;
- **`/metrics`:** las métricas del contrato, una serie por URL y ninguna URL tal cual en `path`;
- **Prometheus:** el job `vigia` arriba, las alertas cargadas, reglas `vigia:…`, ninguna regla con errores y Alertmanager conectado y con receptor;
- **Grafana:** la contraseña de `.env`, la fuente y el dashboard aprovisionados, con disponibilidad y latencia.

Con `--alerta`, la prueba de punta a punta: inserta en PostgreSQL un chequeo caído de `https://verify.invalid`, espera a que la alerta se dispare, llegue a Alertmanager y este avise a tu receptor, y lo borra. Los detalles, en [`recursos/vigia/v7/`](../recursos/vigia/v7/README.md).

## Pistas

<details><summary>Pista 1 — métricas que se calculan en cada <em>scrape</em></summary>

Los `Counter` y `Gauge` de la clase 117 guardan su valor en la memoria del proceso. Aquí el valor está en la base de datos, y lo que quieres es leerlo cuando Prometheus pregunta. Para eso, `prometheus_client` tiene los **colectores propios**: una clase con un método `collect()` que la librería llama en cada `generate_latest()`. Busca *Custom Collectors* en la documentación de `prometheus_client`.

El esqueleto:

```python
from prometheus_client.core import CounterMetricFamily, GaugeMetricFamily


class ColectorSitios:
    def __init__(self, almacen):
        self.almacen = almacen

    def collect(self):
        arriba = GaugeMetricFamily("vigia_site_up", "1 si el último chequeo salió bien", labels=["url"])
        # … por cada sitio de los últimos resultados: arriba.add_metric([url], 1 o 0)
        yield arriba
```

`CounterMetricFamily("vigia_checks", …)` publica `vigia_checks_total`: el número de filas de cada sitio y resultado es, justamente, un contador que solo crece. Para eso necesitarás una consulta nueva en tu módulo de almacenamiento, con `GROUP BY`.

Regístralo una vez, al crear la aplicación: `registro = CollectorRegistry()`, `registro.register(ColectorSitios(almacen))`, y en `/metrics`, `generate_latest(registro)`.
</details>

<details><summary>Pista 2 — el RED de la API sin contar <code>/metrics</code></summary>

Es el *middleware* de la clase 117. Dos detalles:
- con tu propio `CollectorRegistry`, pasa `registry=registro` al crear el `Counter` y el `Histogram`, o se registrarán en el global y no saldrán en tu `/metrics`;
- la etiqueta `path`, con `request.scope.get("route")` después de `call_next`: la plantilla, nunca la URL.
</details>

<details><summary>Pista 3 — un solo <code>docker compose up -d</code></summary>

Compose puede **incluir** otro archivo, y sus servicios entran en el mismo proyecto y en la misma red. Así Prometheus llega a `api:8000` por su nombre:

```yaml
include:
  - observabilidad/compose.yaml

services:
  db:
    …
```

Las rutas dentro de `observabilidad/compose.yaml` son relativas a su carpeta. Las variables, como `${GRAFANA_ADMIN_PASSWORD}`, salen del `.env` de la raíz.
</details>

<details><summary>Pista 4 — la prueba de <code>VigiaSitioCaido</code></summary>

Con `interval: 15s`, `values: '0x40'` son 41 muestras a 0: diez minutos caído. Pon `eval_time: 4m` (sin alerta) y `eval_time: 6m` (con alerta). En `exp_labels` van **todas** las etiquetas de la alerta: las de la serie (`url`, y las `job` e `instance` que pongas en `input_series`) más las de la regla (`severity`). Y en `exp_annotations`, el `summary` ya con la URL sustituida.
</details>

<details><summary>Pista 5 — un SLO de Vigía</summary>

Un SLO mide lo que **Vigía** promete, no lo que hacen los sitios: Vigía no controla si `example.com` se cae. Dos ideas:
- **la API responde:** `avg_over_time(up{job="vigia"}[30d])`, con un objetivo del 99,5 % (3 h 36 min de presupuesto al mes);
- **los chequeos llegan a tiempo:** la parte del tiempo en que el último chequeo tiene menos de 5 minutos.

Elige uno, escríbelo en el README con su cuenta, y añade sus reglas de registro (`vigia:…`) y un panel *Stat* con umbrales.
</details>

<details><summary>Pista 6 — <code>verify.sh --alerta</code> no ve la alerta</summary>

La prueba inserta una fila para `https://verify.invalid`, que **no** está en tu `config.yaml`. Si tu colector solo publica las URL de la configuración, esa no aparece. El contrato dice "los últimos resultados de la base de datos". Mira `curl -s localhost:8000/metrics | grep verify` mientras la prueba espera.
</details>

## Rómpelo: antes de etiquetar

1. **Para el checker:** `docker compose stop checker`. ¿Qué te avisa, y cuánto tarda? Si nada te avisa, te falta una alerta: un sistema de vigilancia que se para en silencio es peor que no tenerlo. Arráncalo.
2. **Para PostgreSQL:** `docker compose stop db`. ¿Qué devuelve `/metrics`? ¿Y qué alertas saltan? (Si `/metrics` falla entero, Prometheus marcará la API como caída; ¿es eso lo que quieres?) Arráncala.
3. **Para Prometheus:** `docker compose stop prometheus`. ¿Quién te avisa ahora? Busca el patrón *Watchdog* o *dead man's switch* (una alerta que está **siempre** disparada, y cuyo silencio es la alarma). Apúntalo en *Limitations*.

## Entregable

- **En el repo:** `/metrics`, `observabilidad/` completa (Compose, configuración, reglas y sus pruebas, el *provisioning* y el dashboard) y el README.
- **En GitHub:** la etiqueta `v7` y su release.

README en inglés, sección nueva:

````markdown
## Observability

The API exposes `/metrics`: the state, response time and last check of every monitored site (read from
PostgreSQL on each scrape, since the checker is a separate process) and the API's own request rate,
errors and latency. Prometheus scrapes it every 15 s; Alertmanager routes alerts to a webhook receiver;
Grafana is provisioned from files with a dashboard of availability and latency per site.
Everything starts with the same `docker compose up -d`.

### Alerts
- `VigiaSitioCaido` — a site has been down for more than 5 minutes (critical)
- `VigiaApiCaida` — Prometheus cannot scrape the API (critical)
- …your other alerts…

All alerts have promtool unit tests (`promtool test rules observabilidad/prometheus/reglas_test.yml`),
and the site-down alert was tested end to end: down at HH:MM, firing at HH:MM, notified at HH:MM.

### SLO
- SLI: …
- Objective: … over 30 days
- Error budget: … per month
````

Etiqueta y release:

```bash
git switch main && git pull
git tag -a v7 -m "v7: metrics, alerts, dashboards and an SLO"
git push origin v7
gh release create v7 --title "v7" --notes "Prometheus metrics, tested alerts through Alertmanager, a provisioned Grafana dashboard and an SLO with its error budget."
```

## Destruir al terminar

Nada que pague. `docker compose down` para pararlo todo, o déjalo en marcha si vas a seguir con la clase 125, que lo usa.

## Cierre

En `notas/fase-10/clase-124.md`:

1. ¿Por qué las métricas de los sitios las publica la API y no el checker?
2. Cuenta tu prueba de punta a punta de `VigiaSitioCaido`, con las horas.
3. ¿Cuál es el SLO de Vigía, cuánto presupuesto deja al mes y por qué mide Vigía y no los sitios?
4. **Repaso (clase 123, sin mirar):** ¿cómo sería `VigiaSitioCaido` como alarma de CloudWatch?

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify.sh</code> y <code>verify.sh --alerta</code> terminen con <code>Fallos: 0</code></summary>

**Comprueba tu entrega:**
- [ ] `verify.sh` → `Fallos: 0`, y con `--alerta` también.
- [ ] En el receptor, el `FIRING` y el `RESOLVED` de tu prueba con `caido.invalid`.
- [ ] El dashboard **Vigía** se ve con datos, y `docker compose down -v && docker compose up -d` lo trae de vuelta igual.
- [ ] El README tiene *Observability*, el SLO con su cuenta y *Limitations*.
- [ ] `git tag` muestra `v7`, con su release.

**Rómpelo 1:** si no añadiste ninguna alerta para el checker, nada te avisa: `vigia_site_up` sigue diciendo 1 con el último chequeo bueno, para siempre. Por eso existe `vigia_site_last_check_timestamp_seconds`: una alerta como `time() - max(vigia_site_last_check_timestamp_seconds) > 300` durante 5 minutos detecta que los chequeos han dejado de llegar.

**Rómpelo 2:** depende de tu código. Si `/metrics` lanza una excepción, devuelve un 500, Prometheus marca la API como caída (`up` = 0) y salta `VigiaApiCaida`, aunque la API esté viva: el aviso confunde la causa. Mejor que el colector capture el error y publique algo como `vigia_database_up 0`, con su propia alerta, y que `/metrics` siga respondiendo.

**Rómpelo 3:** nadie: con Prometheus parado no se evalúa ninguna regla, y Alertmanager no sabe que debería estar recibiendo algo. El patrón *Watchdog* es una alerta que siempre se cumple (`vector(1)`) y que se manda a un servicio externo que avisa cuando **deja** de recibirla. En tu portátil no tiene sentido montarlo, pero sí contarlo en *Limitations*.

**Cierre:**
1. Porque el checker es otro proceso, y en Kubernetes un CronJob que vive unos segundos: Prometheus no llegaría a leerlo (haría falta un *Pushgateway*). La base de datos es lo que comparten, y la API, que está siempre en marcha, la lee en cada *scrape*. Así las métricas sobreviven a reinicios del checker y valen igual en Compose y en Kubernetes.
2. Con tus horas: el cambio en `config.yaml`, el primer chequeo caído, *pending* (en el siguiente *scrape*), *firing* (5 minutos después), la llegada al receptor (tras el `group_wait`), y la resolución al quitar el sitio.
3. El tuyo. Por ejemplo, "la API responde a Prometheus el 99,5 % de los *scrapes* en 30 días": 3 h 36 min al mes. Mide Vigía porque es lo que Vigía controla y promete; la disponibilidad de los sitios es lo que **observa**, no su fiabilidad.
4. Una métrica propia (por ejemplo, `SitiosCaidos`, o una con la dimensión `Url`) publicada con cada chequeo, y una alarma con periodo de 60 segundos, 5 periodos evaluados y 5 que la incumplan, y `--alarm-actions` hacia un *topic* de SNS.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| custom collector | colector propio |
| scrape-time metrics | métricas calculadas al leerlas |
| end-to-end test | prueba de punta a punta |
| dead man's switch / watchdog | interruptor de hombre muerto: una alerta que siempre suena |
| meta-monitoring | vigilar al sistema de vigilancia |

🎙️ *"Vigía v7 monitors itself: the API exposes Prometheus metrics read from PostgreSQL at scrape time, alerts go through Alertmanager, Grafana is provisioned from Git, and the site-down alert has a promtool unit test and an end-to-end test. Our SLO is 99.5% of scrapes over 30 days, a 3 hour 36 minute monthly error budget."*

## Siguiente

[Clase 125 — Fin de la ruta: desde cero, la defensa y el examen final](clase-125-fin-de-la-ruta.md)
