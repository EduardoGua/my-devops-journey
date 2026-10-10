# Clase 120 — Grafana: dashboards como código

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Avisar y entender

## Objetivo

- Añadir Grafana a tu Compose, con la contraseña de administración fuera del código.
- Conectar Prometheus como fuente de datos **desde un archivo** (*provisioning*), no con clics.
- Construir un dashboard RED para la tienda: peticiones, errores, latencia y saturación.
- Llevarlo a código: sacar su JSON, guardarlo en Git y que Grafana lo cargue solo, y saber por qué ya no se puede editar desde la interfaz.

## Por qué importa

Prometheus responde preguntas; Grafana las convierte en algo que se entiende de un vistazo, en una pantalla de guardia o en una reunión. Es lo primero que se abre cuando salta una alerta.

Pero un dashboard hecho a mano vive en la base de datos de Grafana, y se pierde con ella, sin historial ni revisión. "Dashboards como código" es la misma idea que Terraform (fase 8) aplicada a lo que miras: el dashboard se recrea igual en cualquier entorno, y cada cambio pasa por un PR.

## Teoría

### Las piezas de Grafana

| Pieza | Qué es |
|-------|--------|
| **data source** | de dónde saca los datos: Prometheus, CloudWatch, PostgreSQL, Loki… |
| **dashboard** | una página de paneles, guardada como un JSON |
| **panel** | una consulta (PromQL, aquí) y su forma de dibujarla: serie temporal, número (*stat*), indicador (*gauge*), tabla… |
| **Explore** | para consultar sin dashboard, mientras investigas |
| **provisioning** | archivos YAML que Grafana lee al arrancar, y vigila, para crear fuentes de datos y dashboards |

### Provisioning

```
grafana/
├── provisioning/
│   ├── datasources/prometheus.yml   ← "hay un Prometheus en http://prometheus:9090, con uid prometheus"
│   └── dashboards/tienda.yml        ← "carga los JSON de /etc/grafana/dashboards en la carpeta Laboratorio"
└── dashboards/
    └── tienda.json                  ← el dashboard
```

Lo que se aprovisiona desde archivos queda **bloqueado** en la interfaz: puedes cambiarlo para probar, pero no guardarlo. Así nadie arregla algo con clics que se pierde en el siguiente despliegue. El camino para cambiarlo es editar el archivo (o diseñar en la interfaz y exportar), y hacer un commit.

El `uid` de la fuente de datos es lo que une los paneles con ella: si el JSON dice `"uid": "prometheus"`, tiene que existir una fuente con ese `uid`.

### Qué va en un dashboard

Arriba, lo que responde "¿está bien?" en dos segundos: un número de errores, en rojo o en verde. Debajo, las series RED en el tiempo. Más abajo, el detalle para investigar. Pocas cosas y con unidades: un dashboard con 40 paneles no lo lee nadie a las tres de la mañana.

## Práctica guiada

Sigue en `~/my-devops-journey/labs/clase-118`.

### 1. Grafana en el Compose (15 min)

La contraseña del administrador, en `.env`. El `.gitignore` del repositorio del curso ya ignora cualquier `.env`; en Vigía, también.

```bash
cd ~/my-devops-journey/labs/clase-118
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

`${…:?…}` hace que Compose se niegue a arrancar si falta la variable, en lugar de arrancar con una contraseña vacía (clase 65).

Las carpetas del *provisioning*:

```bash
mkdir -p grafana/provisioning/datasources grafana/provisioning/dashboards grafana/dashboards
```

La fuente de datos, `grafana/provisioning/datasources/prometheus.yml`:

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
docker compose up -d
```

La imagen de Grafana ocupa casi 2 GB: la primera vez tarda. Abre http://127.0.0.1:3000 y entra como `admin`, con la contraseña de tu `.env` (`grep GRAFANA .env`).

🔮 **Predice:** ¿podrás entrar con `admin`/`admin`, la contraseña de fábrica?

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u admin:admin http://127.0.0.1:3000/api/datasources
```

`401`. No lo repitas muchas veces: tras unos pocos intentos fallidos seguidos, Grafana bloquea al usuario unos minutos, incluso con la contraseña buena. Es su protección contra quien prueba contraseñas a ciegas.

En **Connections → Data sources** está Prometheus, sin que lo hayas añadido a mano, y con el aviso de que se gestiona por *provisioning*.

### 2. Explorar y dibujar a mano (25 min)

En **Explore**, con la fuente Prometheus, escribe las consultas RED de la clase 118 y cambia entre las vistas. Después, un dashboard nuevo (**Dashboards → New → New dashboard → Add visualization**) con cuatro paneles:

| Panel | Visualización | Consulta | Unidad |
|-------|---------------|----------|--------|
| Peticiones por segundo | Time series | `sum by (status) (rate(tienda_requests_total[1m]))`, leyenda `{{status}}` | requests/sec |
| Errores (5 min) | Stat | `sum(rate(tienda_requests_total{status=~"5.."}[5m])) / sum(rate(tienda_requests_total[5m]))` | Percent (0.0-1.0), con umbral rojo en 0.1 |
| Peticiones en curso | Gauge | `sum(tienda_requests_in_progress)` | — |
| Latencia de /comprar | Time series | p95 y p50 con `histogram_quantile` (dos consultas, A y B) | seconds |

Guárdalo como **Tienda (borrador)**. Provoca un incidente (`curl -s -X POST localhost:8080/errores/50`) y míralo en directo. Vuelve al 5 %.

### 3. Del clic al código (25 min)

El dashboard que acabas de hacer vive en la base de datos de Grafana. Sácalo como JSON con su API:

```bash
P=$(sed -n 's/^GRAFANA_ADMIN_PASSWORD=//p' .env)
curl -s -u "admin:$P" 'http://127.0.0.1:3000/api/search?type=dash-db' | jq '.[] | {uid, title}'
```

Copia el `uid` de **Tienda (borrador)** y:

```bash
curl -s -u "admin:$P" http://127.0.0.1:3000/api/dashboards/uid/<uid> \
  | jq '.dashboard | del(.id, .version) | .uid = "tienda" | .title = "Tienda"' > grafana/dashboards/tienda.json
```

- `.dashboard` es el JSON del dashboard, sin los metadatos de Grafana;
- `id` y `version` son de la base de datos de esta instancia: fuera;
- un `uid` fijo y legible, para que los enlaces no cambien.

Grafana 13 guarda los dashboards nuevos en un formato propio más reciente (v2). Este API clásico te los devuelve convertidos al formato de siempre, el JSON con `panels`, que es el que se aprovisiona aquí. Si exportas desde la interfaz, elige ese formato clásico.

Ábrelo y busca un panel: su `type`, su `title`, su `gridPos` (posición y tamaño en una rejilla de 24 columnas) y, en `targets`, tu PromQL, con `"datasource": {"type": "prometheus", "uid": "prometheus"}`. Así se ve cada uno:

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

Ahora el *provisioning* de dashboards, `grafana/provisioning/dashboards/tienda.yml`:

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

Grafana no deja guardarlo: es un dashboard aprovisionado. Por el API, el mismo intento devuelve `Cannot save provisioned dashboard`. Para cambiarlo, el archivo: cambia el `title` del dashboard en `tienda.json` y espera unos 10 segundos. Grafana vigila la carpeta y lo recarga solo, sin reiniciar.

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

1. Una variable: añade al dashboard (desde la interfaz, y luego exporta) una variable `path` con la consulta `label_values(tienda_requests_total, path)` y úsala en los paneles: `{path="$path"}`. ¿Qué cambia en el JSON?
2. Añade un panel de tipo **Stat** con el p95 de los últimos 5 minutos y umbrales: verde por debajo de 0,3 s, amarillo hasta 0,5 s, rojo por encima.
3. Grafana también sabe hacer alertas. ¿Por qué en este curso las dejas en Prometheus? Escribe dos ventajas y una desventaja.

## Destruir al terminar

```bash
docker compose down
```

Sin `-v` si quieres seguir con estos datos en la clase 121, que usa esta misma carpeta.

## Cierre

En `notas/fase-10/clase-120.md`:

1. ¿Qué es el *provisioning* de Grafana, y qué dos cosas aprovisionas?
2. ¿Por qué un dashboard aprovisionado no se puede guardar desde la interfaz? ¿Cómo lo cambias entonces?
3. ¿Qué pondrías arriba de todo en el dashboard de un servicio, y por qué?
4. **Repaso (clase 119, sin mirar):** ¿qué es una alerta *pending*?

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

**Reto 1:** en el JSON aparece `templating.list`, con la variable y su consulta, y los paneles usan `$path`. Al aprovisionarlo, la variable viene incluida.

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
