# Clase 120 — Grafana: dashboards como código

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Avisar y entender

> 💡 **La idea de hoy:** Grafana convierte las consultas de Prometheus en paneles que se entienden de un vistazo. Pero un dashboard hecho con clics vive en la base de datos de Grafana y se pierde con ella. Por eso la fuente de datos y los dashboards se **aprovisionan** desde archivos en Git: un Grafana nuevo arranca ya configurado, y lo aprovisionado no se puede guardar desde la interfaz. Es la idea de Terraform, aplicada a lo que miras.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La tienda, Prometheus y Alertmanager en Compose (clases 118 y 119); las consultas RED en PromQL (clase 118).
> - `.env` fuera de Git y `${VAR:?mensaje}` en Compose (clase 62); `openssl rand` (clase 78).
> - La infraestructura como código y el *drift* (fase 8).
> - `curl` y `jq` contra el API de Prometheus (clases 47 y 116).

> 🔤 **Palabras nuevas de hoy:**
> - **data source**: de dónde saca Grafana los datos (Prometheus, CloudWatch…).
> - **dashboard** y **panel**: una página de paneles / una consulta con su forma de dibujarla.
> - **Explore**: consultar sin dashboard, mientras investigas.
> - ***provisioning***: archivos YAML que Grafana lee al arrancar para crear fuentes de datos y dashboards.
> - **`uid`**: el identificador fijo que une un panel con su fuente de datos, o que da a un dashboard una URL estable.
> - **`gridPos`**: la posición y el tamaño de un panel en una rejilla de 24 columnas.
> - **umbral** (*threshold*): el valor a partir del cual un panel cambia de color.

## Objetivo

- Añadir Grafana a tu Compose, con la contraseña de administración fuera del código.
- Conectar Prometheus como fuente de datos **desde un archivo** (*provisioning*), no con clics.
- Construir un dashboard RED para la tienda: peticiones, errores, latencia y saturación.
- Llevarlo a código: sacar su JSON, guardarlo en Git y que Grafana lo cargue solo, y saber por qué ya no se puede editar desde la interfaz.

## Por qué importa

Prometheus responde preguntas; Grafana las convierte en algo que se entiende de un vistazo, en una pantalla de guardia o en una reunión. Es lo primero que se abre cuando salta una alerta.

Pero un dashboard hecho a mano vive en la base de datos de Grafana, y se pierde con ella, sin historial ni revisión. "Dashboards como código" es la misma idea que Terraform (fase 8) aplicada a lo que miras: el dashboard se recrea igual en cualquier entorno, y cada cambio pasa por un PR.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 55 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre. Entre los dos días, `docker compose down` **sin** `-v`: tu dashboard de borrador vive en el volumen de Grafana.

Sigue en la carpeta de las clases 118 y 119:

```bash
cd ~/my-devops-journey/labs/clase-118
```

## Las piezas

### Pieza 1 — Grafana en el Compose, con la contraseña fuera

| Pieza | Qué es |
|-------|--------|
| **data source** | de dónde saca los datos: Prometheus, CloudWatch, PostgreSQL, Loki… |
| **dashboard** | una página de paneles, guardada como un JSON |
| **panel** | una consulta (PromQL, aquí) y su forma de dibujarla: serie temporal, número (*stat*), indicador (*gauge*), tabla… |
| **Explore** | para consultar sin dashboard, mientras investigas |
| **provisioning** | archivos YAML que Grafana lee al arrancar, y vigila, para crear fuentes de datos y dashboards |

Grafana trae un usuario `admin` con la contraseña `admin` de fábrica. Se cambia desde el primer arranque con una variable de entorno, y esa contraseña va en `.env`, nunca en el `compose.yaml`.

**Pruébalo.** El `.gitignore` del repositorio del curso ya ignora cualquier `.env`; en Vigía, también.

```bash
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 12)" > .env
```

En `compose.yaml`, el servicio nuevo, y su volumen junto al de Prometheus:

```yaml
  grafana:
    image: grafana/grafana:13.2.3
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?falta GRAFANA_ADMIN_PASSWORD en .env}
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/etc/grafana/dashboards:ro
      - grafana:/var/lib/grafana
    ports:
      - "127.0.0.1:3000:3000"
```

```yaml
volumes:
  prometheus:
  grafana:
```

`${…:?…}` hace que Compose se niegue a arrancar si falta la variable, en lugar de arrancar con una contraseña vacía (clase 62).

```bash
mkdir -p grafana/provisioning/datasources grafana/provisioning/dashboards grafana/dashboards
docker compose up -d
```

La imagen de Grafana ocupa casi 2 GB: la primera vez tarda. Abre http://127.0.0.1:3000 y entra como `admin`, con la contraseña de tu `.env` (`grep GRAFANA .env`).

🔮 **Predice:** ¿podrás entrar con `admin`/`admin`, la contraseña de fábrica?

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u admin:admin http://127.0.0.1:3000/api/datasources
```

👀 **Qué deberías ver:** `401`. No lo repitas muchas veces: tras unos pocos intentos fallidos seguidos, Grafana bloquea al usuario unos minutos, incluso con la contraseña buena. Es su protección contra quien prueba contraseñas a ciegas.

✋ **Sin mirar:** ¿qué pasa si alguien clona el repositorio sin crear el `.env` y lanza `docker compose up`?

<details>
<summary>Comprueba</summary>

Compose se niega a arrancar, con el mensaje de `${…:?…}`. Mejor eso que un Grafana con una contraseña vacía o la de fábrica (lo verás en el Rómpelo 3).
</details>

**En resumen:** Grafana en Compose, con la contraseña en `.env` y obligatoria.

### Pieza 2 — La fuente de datos, desde un archivo

```
grafana/
├── provisioning/
│   ├── datasources/prometheus.yml   ← "hay un Prometheus en http://prometheus:9090, con uid prometheus"
│   └── dashboards/tienda.yml        ← "carga los JSON de /etc/grafana/dashboards en la carpeta Laboratorio"
└── dashboards/
    └── tienda.json                  ← el dashboard
```

El `uid` de la fuente de datos es lo que une los paneles con ella: si el JSON de un panel dice `"uid": "prometheus"`, tiene que existir una fuente con ese `uid`. Hoy creas primero la fuente; el dashboard, en las piezas 4 y 5.

**Pruébalo.** `grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

`access: proxy` significa que Grafana, desde su contenedor, hace las consultas a `prometheus:9090`. Tu navegador solo habla con Grafana.

```bash
docker compose restart grafana
P=$(sed -n 's/^GRAFANA_ADMIN_PASSWORD=//p' .env)
curl -s -u "admin:$P" http://127.0.0.1:3000/api/datasources | jq '.[] | {name, uid, url, readOnly}'
```

👀 **Qué deberías ver:** `{"name": "Prometheus", "uid": "prometheus", "url": "http://prometheus:9090", "readOnly": true}`. En **Connections → Data sources** está Prometheus, sin que lo hayas añadido a mano, y con el aviso de que se gestiona por *provisioning*.

✋ **Sin mirar:** ¿por qué la `url` es `http://prometheus:9090` y no `http://127.0.0.1:9090`?

<details>
<summary>Comprueba</summary>

Porque la consulta la hace Grafana desde su contenedor (`access: proxy`), y dentro de la red de Compose Prometheus se llama `prometheus`. `127.0.0.1` sería el propio contenedor de Grafana.
</details>

**En resumen:** la fuente de datos, en un YAML con un `uid` fijo; nada de clics.

### Pieza 3 — Explorar y dibujar a mano

Qué va en un dashboard: arriba, lo que responde "¿está bien?" en dos segundos, un número de errores en rojo o en verde. Debajo, las series RED en el tiempo. Más abajo, el detalle para investigar. Pocas cosas y con unidades: un dashboard con 40 paneles no lo lee nadie a las tres de la mañana.

Para diseñar, la interfaz es cómoda: se dibuja a mano y después se lleva a código.

**Pruébalo.** En **Explore**, con la fuente Prometheus, escribe las consultas RED de la clase 118 y cambia entre las vistas. Después, un dashboard nuevo (**Dashboards → New → New dashboard → Add visualization**) con cuatro paneles:

| Panel | Visualización | Consulta | Unidad |
|-------|---------------|----------|--------|
| Peticiones por segundo | Time series | `sum by (status) (rate(tienda_requests_total[1m]))`, leyenda `{{status}}` | requests/sec |
| Errores (5 min) | Stat | `sum(rate(tienda_requests_total{status=~"5.."}[5m])) / sum(rate(tienda_requests_total[5m]))` | Percent (0.0-1.0), con umbral rojo en 0.1 |
| Peticiones en curso | Gauge | `sum(tienda_requests_in_progress)` | — |
| Latencia de /comprar | Time series | p95 y p50 con `histogram_quantile` (dos consultas, A y B) | seconds |

Guárdalo como **Tienda (borrador)**. Provoca un incidente (`curl -s -X POST localhost:8080/errores/50`) y míralo en directo. Vuelve al 5 %.

👀 **Qué deberías ver:** en un par de minutos, la serie `500` del primer panel sube hasta igualar a la de `200`, y el número de errores pasa del verde a rojo al cruzar el 10 %. La latencia apenas cambia: los errores de la tienda son rápidos.

✋ **Sin mirar:** ¿qué panel pondrías arriba del todo, y por qué?

<details>
<summary>Comprueba</summary>

El de errores, como un número grande con umbral: responde "¿está bien?" en dos segundos, que es lo primero que necesitas cuando salta una alerta.
</details>

**En resumen:** se diseña en la interfaz; arriba, lo que dice si está bien.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. `docker compose down` **sin** `-v`: el borrador está en el volumen de Grafana. Mañana, `docker compose up -d`.

### Pieza 4 — Del clic al código: exportar el JSON

El dashboard que acabas de hacer vive en la base de datos de Grafana. Su API lo devuelve como JSON. Antes de guardarlo en Git se limpia:
- `.dashboard` es el JSON del dashboard, sin los metadatos de Grafana;
- `id` y `version` son de la base de datos de esta instancia: fuera;
- un `uid` fijo y legible, para que los enlaces no cambien.

Grafana 13 guarda los dashboards nuevos en un formato propio más reciente (v2). Este API clásico te los devuelve convertidos al formato de siempre, el JSON con `panels`, que es el que se aprovisiona aquí. Si exportas desde la interfaz, elige ese formato clásico.

**Pruébalo:**

```bash
P=$(sed -n 's/^GRAFANA_ADMIN_PASSWORD=//p' .env)
curl -s -u "admin:$P" 'http://127.0.0.1:3000/api/search?type=dash-db' | jq '.[] | {uid, title}'
```

Copia el `uid` de **Tienda (borrador)** y:

```bash
curl -s -u "admin:$P" http://127.0.0.1:3000/api/dashboards/uid/<uid> \
  | jq '.dashboard | del(.id, .version) | .uid = "tienda" | .title = "Tienda"' > grafana/dashboards/tienda.json
jq '.panels[] | {type, title, gridPos}' grafana/dashboards/tienda.json
```

👀 **Qué deberías ver:** tus cuatro paneles, cada uno con su `type` (`timeseries`, `stat`, `gauge`), su `title` y su `gridPos`. Ábrelo y busca en `targets` tu PromQL, con `"datasource": {"type": "prometheus", "uid": "prometheus"}`. Así se ve cada panel:

```json
{
  "id": 1,
  "type": "timeseries",
  "title": "Peticiones por segundo",
  "datasource": { "type": "prometheus", "uid": "prometheus" },
  "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
  "targets": [
    {
      "refId": "A",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "expr": "sum by (status) (rate(tienda_requests_total[1m]))",
      "legendFormat": "{{status}}"
    }
  ],
  "fieldConfig": { "defaults": { "unit": "reqps" }, "overrides": [] },
  "options": {}
}
```

✋ **Sin mirar:** ¿por qué se borran `id` y `version` del JSON exportado?

<details>
<summary>Comprueba</summary>

Porque son de la base de datos de **esta** instancia de Grafana: en otra, chocarían o no significarían nada. Lo que identifica al dashboard en todas partes es su `uid`.
</details>

**En resumen:** exportar por el API, limpiar con `jq` y un `uid` fijo.

### Pieza 5 — Aprovisionar el dashboard: bloqueado en la interfaz

Lo que se aprovisiona desde archivos queda **bloqueado** en la interfaz: puedes cambiarlo para probar, pero no guardarlo. Así nadie arregla algo con clics que se pierde en el siguiente despliegue. El camino para cambiarlo es editar el archivo (o diseñar en la interfaz y exportar), y hacer un commit. Grafana vigila la carpeta y recarga los cambios solo.

**Pruébalo.** `grafana/provisioning/dashboards/tienda.yml`:

```yaml
apiVersion: 1
providers:
  - name: tienda
    folder: Laboratorio
    type: file
    disableDeletion: true
    allowUiUpdates: false
    options:
      path: /etc/grafana/dashboards
```

```bash
docker compose restart grafana
```

En **Dashboards** aparece la carpeta **Laboratorio** con **Tienda**. Borra el borrador: ya no lo necesitas.

🔮 **Predice:** cambia el título de un panel de **Tienda** en la interfaz y pulsa **Save**. ¿Qué pasa?

👀 **Qué deberías ver:** Grafana no deja guardarlo: es un dashboard aprovisionado. Por el API, el mismo intento devuelve `Cannot save provisioned dashboard`. Para cambiarlo, el archivo: cambia el `title` del dashboard en `tienda.json` y espera unos 10 segundos. Grafana lo recarga solo, sin reiniciar.

✋ **Sin mirar:** un compañero quiere añadir un panel a **Tienda**. ¿Qué pasos sigue?

<details>
<summary>Comprueba</summary>

Lo diseña en la interfaz (en una copia o sin guardar), exporta el JSON, lo copia a `grafana/dashboards/tienda.json` y abre un PR. Al unirlo, Grafana lo recarga.
</details>

**En resumen:** el dashboard vive en Git; la interfaz es para diseñar, no para guardar.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?…}` | la contraseña, obligatoria y fuera de Git |
| `provisioning/datasources/*.yml` con `uid`, `url`, `editable: false` | la fuente de datos desde un archivo |
| `provisioning/dashboards/*.yml` con `path` y `allowUiUpdates: false` | cargar los JSON de una carpeta |
| `curl -u "admin:$P" …/api/search?type=dash-db` | los dashboards y su `uid` |
| `curl -u "admin:$P" …/api/dashboards/uid/<uid> \| jq '.dashboard \| del(.id, .version)'` | exportar un dashboard |
| `"datasource": {"type": "prometheus", "uid": "prometheus"}` | unir un panel con su fuente |
| `gridPos: {x, y, w, h}` | dónde va el panel (24 columnas) |
| `label_values(metrica, etiqueta)` | los valores de una etiqueta, para una variable |

## Rómpelo

1. **El `uid` equivocado.** En `tienda.json`, cambia en **un** panel `"uid": "prometheus"` por `"uid": "prometeo"` (en el panel y en su `target`). ¿Qué muestra el panel? Pregúntalo también por el API:

   ```bash
   curl -s -u "admin:$P" -H 'Content-Type: application/json' -X POST http://127.0.0.1:3000/api/ds/query \
     -d '{"queries":[{"refId":"A","datasource":{"uid":"prometeo"},"expr":"up"}],"from":"now-5m","to":"now"}'
   ```

   `{"message":"Data source not found"}`. Devuélvelo.
2. **Perder la base de datos de Grafana.** `docker compose down -v` y `docker compose up -d`. ¿Qué queda: la fuente de datos, el dashboard **Tienda**, un dashboard que hubieras hecho solo a mano? ¿Y tus datos de Prometheus? (Has borrado también su volumen.)
3. **Sin contraseña.** Comenta la línea `GRAFANA_ADMIN_PASSWORD` en `.env` y lanza `docker compose up -d`. ¿Qué dice Compose? Devuélvela.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Una variable: añade al dashboard (desde la interfaz, y luego exporta) una variable `path` con los valores de esa etiqueta, y úsala en los paneles. ¿Qué cambia en el JSON?

> 🧩 **Ejemplo resuelto:** la pieza 3: la leyenda `{{status}}` usaba el valor de una etiqueta en el panel.

**Ahora tú, con huecos:** en **Dashboard settings → Variables → New variable**: tipo *Query*, nombre `____`, consulta `label_values(tienda_requests_total, ____)`. En los paneles, `tienda_requests_total{path="____"}`. Exporta como en la pieza 4 y completa: «En el JSON aparece ____, con…».

<details>
<summary>Pista</summary>

Busca en el JSON exportado la clave `templating`: `jq '.templating' grafana/dashboards/tienda.json`.
</details>

**2.** Añade un panel de tipo **Stat** con el p95 de los últimos 5 minutos y umbrales: verde por debajo de 0,3 s, amarillo hasta 0,5 s, rojo por encima.

> 🧩 **Ejemplo resuelto:** la pieza 3: el panel **Errores (5 min)** era un *Stat* con un umbral rojo en 0.1.

**Ahora tú, con huecos:** consulta `histogram_quantile(____, sum by (le) (rate(tienda_request_duration_seconds_bucket{path="/comprar"}[____])))`, unidad `____`, y en *Thresholds*: base verde, amarillo en `____`, rojo en `____`.

<details>
<summary>Pista</summary>

Los umbrales de un *Stat* se leen de abajo arriba: la base es el color por debajo del primer valor.
</details>

**3.** Grafana también sabe hacer alertas. ¿Por qué en este curso las dejas en Prometheus? Escribe dos ventajas y una desventaja.

> 🧩 **Ejemplo resuelto:** la pieza 2 de la clase 119: las reglas de Prometheus tienen pruebas unitarias con `promtool`.

**Ahora tú, con huecos:** «Ventajas de dejarlas en Prometheus: ____ y ____. Desventaja: Grafana puede alertar sobre ____ a la vez…».

<details>
<summary>Pista</summary>

Piensa qué pasa con las alertas si Grafana se cae, y en qué otras fuentes de datos puede leer Grafana.
</details>

## Destruir al terminar

```bash
docker compose down
```

Sin `-v` si quieres seguir con estos datos en la clase 121, que usa esta misma carpeta.

## Cierre

En `notas/fase-10/clase-120.md`:

1. ¿Qué es el *provisioning* de Grafana, y qué dos cosas aprovisionas? *(2 líneas. Empieza así: «Archivos YAML que Grafana lee al arrancar para… Aquí, la fuente de datos y…»)*
2. ¿Por qué un dashboard aprovisionado no se puede guardar desde la interfaz? ¿Cómo lo cambias entonces? *(2 líneas. Empieza así: «Para que la verdad esté en un solo sitio:…»)*
3. ¿Qué pondrías arriba de todo en el dashboard de un servicio, y por qué? *(1–2 líneas.)*
4. **Repaso (clase 119, sin mirar):** ¿qué es una alerta *pending*? *(1 línea.)*

Después, escríbeme `examíname clase-120`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Archivos YAML que Grafana lee al arrancar (y vigila después) para crear lo que necesita sin clics. Aquí, la **fuente de datos** Prometheus, con un `uid` fijo, y un **proveedor de dashboards** que carga los JSON de una carpeta. Todo vive en Git: un Grafana nuevo arranca ya configurado.
2. Para que la verdad esté en un solo sitio, el archivo en Git. Si se pudiera guardar desde la interfaz, el cambio viviría solo en esa instancia y se perdería en el siguiente despliegue. Se cambia editando el JSON, o diseñando en la interfaz y exportándolo, y con un commit; Grafana lo recarga solo.
3. Lo que responde "¿está bien?" sin pensar: la proporción de errores y, si acaso, la latencia, como números grandes con umbrales en verde o rojo. Es lo primero que miras cuando salta una alerta; el detalle, debajo.
4. Una alerta cuya condición se cumple, pero todavía no durante todo su `for`: activa, pero sin avisar.

**Rómpelo 2:** la fuente de datos y **Tienda** vuelven, porque salen de los archivos. Un dashboard hecho solo a mano se pierde con la base de datos de Grafana. Y los datos de Prometheus, también: `-v` borró su volumen, y las gráficas empiezan de cero.

**Rómpelo 3:** `error while interpolating services.grafana.environment.GF_SECURITY_ADMIN_PASSWORD: required variable GRAFANA_ADMIN_PASSWORD is missing a value: falta GRAFANA_ADMIN_PASSWORD en .env`, y no arranca nada. Mejor no arrancar que arrancar con una contraseña vacía o la de fábrica.

**Reto 1:** nombre `path`, `label_values(tienda_requests_total, path)` y `{path="$path"}`. En el JSON aparece `templating.list`, con la variable y su consulta, y los paneles usan `$path`. Al aprovisionarlo, la variable viene incluida.

**Reto 2:** `0.95`, `[5m]`, unidad `seconds (s)`, amarillo en `0.3` y rojo en `0.5`.

**Reto 3:** en Prometheus, las alertas viven junto a las métricas, se prueban con `promtool` (clase 119), funcionan aunque Grafana esté caído y siguen el mismo flujo de Git. La desventaja: Grafana puede alertar sobre varias fuentes a la vez (Prometheus, CloudWatch, una base de datos) y tiene una interfaz más cómoda para quien no escribe YAML.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| data source | fuente de datos |
| dashboard / panel | tablero / panel |
| provisioning | aprovisionamiento desde archivos |
| dashboards as code | dashboards como código |
| threshold | umbral |

🎙️ *"Our Grafana is fully provisioned from Git: the Prometheus data source and every dashboard are files, so a new instance comes up identical and changes go through pull requests. Provisioned dashboards can't be saved from the UI; you design, export the JSON and commit it."*

## Siguiente

[Clase 121 — SLI, SLO, SLA y presupuesto de errores](clase-121-slo.md)
