# Clase 117 — El endpoint `/metrics`

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Medir

> 💡 **La idea de hoy:** Prometheus solo sabe lo que tu aplicación publica. Con la librería oficial, `prometheus_client`, creas un **counter** de peticiones, un **histogram** de tiempos y un **gauge** de peticiones en curso, y los actualizas en un único ***middleware*** que envuelve todas las rutas: el método RED en una función. Y las etiquetas llevan la **plantilla** de la ruta, nunca la URL.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Una API con FastAPI, uvicorn y el `TestClient` (clase 53); entornos virtuales (clase 46).
> - `try`/`finally` (clase 44); el Dockerfile con usuario sin privilegios (clase 59).
> - Los tipos de métrica, la cardinalidad y el método RED (clase 116).

> 🔤 **Palabras nuevas de hoy:**
> - **instrumentar**: añadir mediciones al código.
> - **`prometheus_client`**: la librería oficial de Prometheus para Python.
> - **`.inc()`, `.dec()`, `.observe()`**: sumar, restar y registrar una observación (por ejemplo, un tiempo).
> - **`.labels(...)`**: elegir la serie, por sus etiquetas, antes de actualizarla.
> - ***middleware***: código que envuelve cada petición: hace algo antes y algo después de la ruta.
> - **`generate_latest()`**: el texto que lee Prometheus.
> - **plantilla de la ruta**: `/productos/{id}`, frente a la URL concreta `/productos/42`.

## Objetivo

- Instrumentar una aplicación de Python con `prometheus_client`: un counter, un histogram y un gauge.
- Medir todas las peticiones en un solo sitio con un *middleware*, siguiendo el método RED.
- Elegir bien las etiquetas: la plantilla de la ruta, nunca la URL tal cual.
- Empaquetarlo en una imagen, que usarás en las clases 118 a 121.

## Por qué importa

Prometheus no adivina nada: solo sabe lo que tu aplicación publica en `/metrics`. Instrumentar tu código es el primer paso de la observabilidad, y es trabajo de quien escribe la aplicación, no de quien la opera. En un equipo DevOps, a menudo eres tú quien lo propone y quien enseña a hacerlo bien.

Lo que construyes hoy es lo mismo que pondrás en la API de Vigía en la clase 124.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas construyen la misma `tienda.py`.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 50 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Necesitarás **dos terminales**: una con uvicorn y otra para las peticiones.

```bash
mkdir -p ~/my-devops-journey/labs/clase-117 && cd ~/my-devops-journey/labs/clase-117
python3 -m venv .venv && source .venv/bin/activate
```

## Las piezas

### Pieza 1 — La tienda, sin métricas

Para medir hace falta algo que medir: una tienda de mentira con lo que ya sabes de la clase 53. `/comprar` tarda un tiempo al azar (casi siempre unos 80 ms; a veces, cerca de un segundo) y falla el 5 % de las veces. Y `/errores/{porcentaje}` cambia ese porcentaje, para provocar incidentes en las próximas clases.

**Pruébalo.** `requirements.txt`:

```
fastapi==0.143.0
uvicorn==0.54.0
prometheus-client==0.26.0
```

```bash
pip install -r requirements.txt
```

`tienda.py`:

```python
"""Una tienda de mentira para practicar métricas: casi siempre rápida, a veces lenta, a veces falla."""
import random
import time

from fastapi import FastAPI, HTTPException

app = FastAPI(title="Tienda")
errores = {"porcentaje": 5}


@app.get("/comprar")
def comprar():
    time.sleep(random.lognormvariate(-2.5, 0.8))   # mediana de unos 80 ms, y a veces casi un segundo
    if random.uniform(0, 100) < errores["porcentaje"]:
        raise HTTPException(status_code=500, detail="sin conexión con el banco")
    return {"compra": "ok"}


@app.get("/productos/{id}")
def producto(id: int):
    return {"id": id, "nombre": f"producto {id}"}


@app.post("/errores/{porcentaje}")
def cambiar_errores(porcentaje: int):
    errores["porcentaje"] = max(0, min(100, porcentaje))
    return errores


@app.get("/health")
def health():
    return {"status": "ok"}
```

```bash
uvicorn tienda:app --port 8080
```

En otra terminal:

```bash
for i in $(seq 1 40); do curl -s -o /dev/null -w '%{http_code} ' localhost:8080/comprar; done; echo
```

👀 **Qué deberías ver:** casi todo `200`, y con suerte algún `500` (uno de cada veinte, de media). Notarás que algunas peticiones tardan más.

✋ **Sin mirar:** ahora mismo, ¿cómo sabría Prometheus cuántas compras fallan?

<details>
<summary>Comprueba</summary>

No podría: la tienda no publica nada. Prometheus solo sabe lo que la aplicación expone en `/metrics`.
</details>

**En resumen:** una tienda que a veces tarda y a veces falla: lo que vas a medir.

### Pieza 2 — Las métricas y `/metrics`

`prometheus_client` se usa así:

```python
from prometheus_client import Counter, Gauge, Histogram

PETICIONES = Counter("tienda_requests", "Peticiones HTTP atendidas", ["path", "status"])
PETICIONES.labels(path="/comprar", status="200").inc()        # +1

EN_CURSO = Gauge("tienda_requests_in_progress", "Peticiones atendiéndose ahora mismo")
EN_CURSO.inc(); EN_CURSO.dec()                                 # sube y baja

DURACION = Histogram("tienda_request_duration_seconds", "Tiempo de respuesta", ["path"],
                     buckets=(0.05, 0.1, 0.25, 0.5, 1, 2.5))
DURACION.labels(path="/comprar").observe(0.083)                # una observación de 83 ms
```

- Las métricas se crean **una vez**, al cargar el módulo, y se actualizan en cada petición.
- El nombre del counter no lleva `_total`: la librería se lo añade al publicarlo.
- `generate_latest()` produce el texto que lee Prometheus. Lo sirves en `/metrics`.

**Pruébalo.** En `tienda.py`, cambia las importaciones y el principio por esto:

```python
from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import (CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, disable_created_metrics,
                               generate_latest)

disable_created_metrics()   # sin las series *_created: aquí no aportan nada
app = FastAPI(title="Tienda")
errores = {"porcentaje": 5}

PETICIONES = Counter("tienda_requests", "Peticiones HTTP atendidas", ["path", "status"])
DURACION = Histogram("tienda_request_duration_seconds", "Tiempo de respuesta", ["path"],
                     buckets=(0.05, 0.1, 0.25, 0.5, 1, 2.5))
EN_CURSO = Gauge("tienda_requests_in_progress", "Peticiones atendiéndose ahora mismo")
```

(deja `import random` e `import time` arriba). Y añade el endpoint, junto a las demás rutas:

```python
@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

Reinicia uvicorn (`Ctrl+C` y otra vez) y, en la otra terminal:

```bash
curl -s localhost:8080/metrics | grep tienda_
```

🔮 **Predice:** si nadie actualiza todavía las métricas, ¿qué series aparecerán?

👀 **Qué deberías ver:** las líneas `# HELP` y `# TYPE` de las tres, pero una sola serie: `tienda_requests_in_progress 0.0`. Una métrica **con** etiquetas no tiene ninguna serie hasta que se usa una combinación; un gauge sin etiquetas existe desde el principio, con 0.

✋ **Sin mirar:** ¿cómo se llamará en `/metrics` el counter que creaste como `tienda_requests`?

<details>
<summary>Comprueba</summary>

`tienda_requests_total`: la librería añade `_total` a los counters.
</details>

**En resumen:** las métricas se crean una vez; `generate_latest()` en `/metrics` las publica.

### Pieza 3 — Un *middleware* para todas las rutas, y sus etiquetas

Poner `.inc()` en cada ruta sería repetir lo mismo en todas y olvidarlo en alguna. Un *middleware* envuelve **todas** las peticiones: mide antes y después de la ruta, en un solo sitio.

Y la regla de las etiquetas, de la clase 116:
- `path` debe ser la **plantilla** de la ruta (`/productos/{id}`), no la URL (`/productos/42`). Si no, cada id es una serie nueva;
- `status`, el código HTTP: unos pocos valores;
- nunca ids de usuario, correos, URLs completas o mensajes de error.

**Pruébalo.** Añade el *middleware* justo después de las métricas:

```python
@app.middleware("http")
async def medir(request: Request, call_next):
    EN_CURSO.inc()
    inicio = time.perf_counter()
    try:
        respuesta = await call_next(request)
    finally:
        EN_CURSO.dec()
    ruta = request.scope.get("route")
    plantilla = ruta.path if ruta else "otra"   # /productos/{id}, nunca /productos/42
    if plantilla != "/metrics":
        DURACION.labels(path=plantilla).observe(time.perf_counter() - inicio)
        PETICIONES.labels(path=plantilla, status=str(respuesta.status_code)).inc()
    return respuesta
```

- `call_next` ejecuta la ruta; lo de antes y lo de después es tu medición.
- `try`/`finally` garantiza que `EN_CURSO` baje aunque la ruta falle (clase 44).
- Después de `call_next`, FastAPI ha dejado en `request.scope["route"]` la ruta que atendió la petición, con su plantilla. Si no casó ninguna (un 404), no hay ruta: `"otra"`.
- No mide `/metrics`: Prometheus la llamará cada 15 segundos y ensuciaría tus números.

Reinicia uvicorn y genera tráfico:

```bash
for i in $(seq 1 30); do curl -s -o /dev/null localhost:8080/comprar; curl -s -o /dev/null localhost:8080/productos/$i; done
curl -s localhost:8080/metrics | grep '^tienda_requests'
```

🔮 **Predice:** ¿cuántas series de `tienda_requests_total` habrá? ¿Y qué valdrá `tienda_requests_in_progress` en el momento de leerlo?

👀 **Qué deberías ver:** algo así:

```
tienda_requests_total{path="/comprar",status="200"} 28.0
tienda_requests_total{path="/comprar",status="500"} 2.0
tienda_requests_total{path="/productos/{id}",status="200"} 30.0
tienda_requests_in_progress 1.0
```

- Dos o tres series: una por combinación de `path` y `status` que ha ocurrido. Si no salió ningún 500, esa serie todavía no existe.
- `in_progress` vale **1**: la propia petición a `/metrics`, que el gauge cuenta antes de saber qué ruta era.

✋ **Sin mirar:** pides `/productos/1` y `/productos/2`. ¿Cuántas series de `/productos` crea tu *middleware*?

<details>
<summary>Comprueba</summary>

Una: `path="/productos/{id}"`, la plantilla. Con la URL serían dos, y una más por cada producto.
</details>

**En resumen:** un *middleware* mide todas las rutas; las etiquetas, con la plantilla.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Para uvicorn con `Ctrl+C` y sal del entorno con `deactivate`; mañana, `source .venv/bin/activate` en la misma carpeta.

### Pieza 4 — Los cubos del histograma

Los `buckets` son los límites de los tramos, en segundos. Elígelos alrededor de lo que te importa: si tu objetivo es responder en menos de 250 ms, que haya un cubo en `0.25`. Con cubos mal puestos (todos por debajo de 10 ms, por ejemplo), los percentiles salen inventados. Cada cubo es una serie más: entre 5 y 10 suelen bastar.

**Pruébalo.** Con uvicorn en marcha y el tráfico de la pieza 3:

```bash
curl -s localhost:8080/metrics | grep 'tienda_request_duration_seconds' | grep '/comprar'
```

👀 **Qué deberías ver:** algo así:

```
tienda_request_duration_seconds_bucket{le="0.05",path="/comprar"} 9.0
tienda_request_duration_seconds_bucket{le="0.1",path="/comprar"} 21.0
tienda_request_duration_seconds_bucket{le="0.25",path="/comprar"} 29.0
tienda_request_duration_seconds_bucket{le="0.5",path="/comprar"} 30.0
…
tienda_request_duration_seconds_bucket{le="+Inf",path="/comprar"} 30.0
tienda_request_duration_seconds_count{path="/comprar"} 30.0
tienda_request_duration_seconds_sum{path="/comprar"} 2.767
```

Los `_bucket` son acumulados: `le="0.1"` cuenta las que tardaron 0,1 s **o menos**, y `le="+Inf"`, todas. `_sum / _count` es la media (aquí, unos 92 ms), pero la media esconde la cola: lo verás con los percentiles en la clase 118.

✋ **Sin mirar:** con estos datos, ¿cuántas compras tardaron entre 0,1 y 0,25 segundos?

<details>
<summary>Comprueba</summary>

Las de `le="0.25"` menos las de `le="0.1"`: 29 − 21 = 8. Los cubos son acumulados.
</details>

**En resumen:** cubos acumulados alrededor de tu objetivo; `_sum` y `_count` dan la media.

### Pieza 5 — A una imagen

La tienda va a correr en Compose junto a Prometheus en las próximas clases, así que se empaqueta como cualquier aplicación de la fase 5: imagen pequeña, usuario sin privilegios y dependencias fijadas.

**Pruébalo.** Para uvicorn, sal del entorno virtual (`deactivate`) y crea el `Dockerfile`, como en la clase 59:

```dockerfile
FROM python:3.14-slim
RUN useradd --system --uid 10001 --no-create-home tienda
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY tienda.py .
USER tienda
EXPOSE 8000
CMD ["uvicorn", "tienda:app", "--host", "0.0.0.0", "--port", "8000"]
```

Y un `.dockerignore` con `.venv`.

```bash
docker build -t tienda:1 .
docker run -d --name tienda -p 127.0.0.1:8080:8000 tienda:1
curl -s localhost:8080/health
curl -s localhost:8080/metrics | grep -c '^tienda_'
docker rm -f tienda
```

👀 **Qué deberías ver:** `{"status":"ok"}` y unas 11 líneas `tienda_`: la petición a `/health` ya creó sus series (un counter y los cubos de su histograma).

✋ **Sin mirar:** ¿por qué `.venv` va en `.dockerignore`?

<details>
<summary>Comprueba</summary>

Porque la imagen instala sus propias dependencias con `pip install`: copiar tu entorno virtual solo haría la imagen más grande, y con binarios de tu máquina.
</details>

**En resumen:** la tienda instrumentada, en la imagen `tienda:1`, para las clases 118 a 121.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `Counter("app_requests", "…", ["path", "status"])` | un counter con etiquetas (se publica con `_total`) |
| `Histogram("app_request_duration_seconds", "…", ["path"], buckets=(…))` | un histograma de tiempos |
| `Gauge("app_requests_in_progress", "…")` | un gauge |
| `.labels(path=…, status=…).inc()` · `.observe(segundos)` · `.inc()`/`.dec()` | actualizar |
| `Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)` | servir `/metrics` |
| `@app.middleware("http")` + `call_next` | medir todas las rutas en un sitio |
| `request.scope.get("route").path` | la plantilla de la ruta |
| `time.perf_counter()` | medir tiempo transcurrido |
| `disable_created_metrics()` | sin las series `_created` |

## Rómpelo

1. **La URL como etiqueta.** Cambia `plantilla` por `request.url.path` en el *middleware*, reinicia y pide 50 productos distintos. ¿Cuántas series de `tienda_requests_total` hay ahora (`curl -s localhost:8080/metrics | grep -c '^tienda_requests_total'`)? Imagina un millón de productos y diez réplicas. Deshazlo.
2. **Un gauge donde iba un counter.** Si contaras las peticiones con un `Gauge` y `.inc()`, el valor publicado sería el mismo. ¿Qué perderías? (Pista: lee el `# TYPE` que publicaría. ¿Qué hará `rate()` en la clase 118 cuando el proceso se reinicie?)
3. **Un reinicio.** Con la imagen en marcha, mira `tienda_requests_total`, reinicia el contenedor y míralo otra vez. ¿Qué pasa con los contadores? Prometheus está preparado para esto: lo comprobarás en la clase 118.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade `tienda_purchases_total`, un counter de compras **correctas** (sin etiquetas). ¿En qué se diferencia de `tienda_requests_total{path="/comprar",status="200"}`? ¿Te sobra alguno de los dos?

> 🧩 **Ejemplo resuelto:** la pieza 2: `PETICIONES = Counter("tienda_requests", "Peticiones HTTP atendidas", ["path", "status"])`.

**Ahora tú, con huecos:**
```python
COMPRAS = Counter("tienda_____", "Compras correctas")
# … en comprar(), justo antes de return:
    COMPRAS.____()
```
Completa: «Cuentan lo mismo si… Un counter de negocio sigue valiendo aunque cambien ____, y se entiende mejor en…».

<details>
<summary>Pista</summary>

Sin etiquetas no hace falta `.labels()`. Piensa qué pasaría con `tienda_requests_total{path="/comprar"…}` si mañana la ruta pasa a llamarse `/pedido`.
</details>

**2.** `prometheus_client` publica también métricas del propio proceso y de Python. Encuéntralas en `/metrics`. ¿Cuánta memoria usa tu tienda?

> 🧩 **Ejemplo resuelto:** la pieza 4 de la clase 116: `process_resident_memory_bytes` era un gauge con la memoria de Prometheus.

**Ahora tú, con huecos:** `curl -s localhost:8080/metrics | grep -E '^(process|python)_'`. Completa: «Hay unas ____ líneas. `process_resident_memory_bytes` vale ____, unos ____ MB».

<details>
<summary>Pista</summary>

El valor sale en notación científica: `5.6e+07` son 56 000 000 bytes. Divide entre 1 000 000 para los MB.
</details>

**3.** Escribe una prueba de `pytest` con el `TestClient` de FastAPI que haga una compra y compruebe que `/metrics` contiene `tienda_requests_total{path="/comprar"`.

> 🧩 **Ejemplo resuelto:** en la clase 53, una prueba con `TestClient(app)` que pedía `/health` y comprobaba el código 200.

**Ahora tú, con huecos:**
```python
from fastapi.testclient import TestClient

import tienda


def test_una_compra_queda_en_las_metricas():
    tienda.errores["porcentaje"] = ____
    cliente = TestClient(tienda.app)
    assert cliente.get("/comprar").status_code == ____
    assert 'tienda_requests_total{path="/comprar",status="200"}' in cliente.get("____").text
```

<details>
<summary>Pista</summary>

Fija los errores a 0 para que la prueba no falle al azar. `TestClient` necesita `httpx2`, como en la clase 53: `pip install httpx2 pytest` en tu entorno virtual.
</details>

## Destruir al terminar

```bash
docker rm -f tienda 2>/dev/null; deactivate 2>/dev/null; true
```

Guarda la carpeta y la imagen `tienda:1`: la clase 118 empieza con ellas.

## Cierre

En `notas/fase-10/clase-117.md`:

1. ¿Qué tres métricas tiene tu tienda, de qué tipo es cada una y qué letra de RED cubre? *(3 líneas, una por métrica.)*
2. ¿Por qué la etiqueta `path` usa la plantilla de la ruta y no la URL? *(2 líneas. Empieza así: «Porque cada valor distinto de una etiqueta es una serie nueva…»)*
3. ¿Por qué el *middleware* no mide `/metrics`? *(1–2 líneas.)*
4. **Repaso (clase 116, sin mirar):** ¿qué diferencia hay entre un histogram y un summary, y cuál se prefiere? *(2 líneas.)*

Después, escríbeme `examíname clase-117`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. `tienda_requests_total` (counter, con `path` y `status`) da la **R** (su ritmo) y la **E** (las de `status` 5xx). `tienda_request_duration_seconds` (histogram) da la **D**. `tienda_requests_in_progress` (gauge) no es de RED: mide la **saturación**, de las señales doradas.
2. Porque cada valor distinto de una etiqueta es una serie nueva. Con la URL, `/productos/1`, `/productos/2`… crearían una serie por producto, y la memoria de Prometheus crecería sin límite. Con la plantilla hay una por ruta, que es lo que quieres comparar.
3. Porque la llama Prometheus cada 15 segundos, y esas peticiones no son de usuarios: mezclarlas falsearía el ritmo, los errores y la latencia de la tienda.
4. Los dos reparten las observaciones para calcular percentiles. El histogram publica los cubos y el percentil se calcula en Prometheus, así que se puede **sumar** entre réplicas. El summary calcula los percentiles dentro de cada proceso, y no se pueden combinar. Se prefiere el histogram.

**Rómpelo 1:** 50 series de `/productos/…`, más las de `/comprar`. Con un millón de productos, un millón de series por réplica: Prometheus se quedaría sin memoria.

**Rómpelo 2:** publicaría `# TYPE … gauge`. Prometheus y Grafana tratarían el número como algo que sube y baja: no sabrían que es un total, `rate()` no detectaría los reinicios (para él, una bajada es un valor normal) y la intención de la métrica se perdería.

**Rómpelo 3:** los contadores vuelven a 0: viven en la memoria del proceso. `rate()` e `increase()` detectan esa bajada como un reinicio y la descuentan, así que la tasa no se rompe.

**Reto 1:** `Counter("tienda_purchases", "Compras correctas")` y `COMPRAS.inc()`. Cuentan lo mismo si `/comprar` solo da 200 cuando la compra sale bien. Un counter de negocio (`purchases`) sigue valiendo aunque cambien las rutas o los códigos, y se entiende mejor en un dashboard para no técnicos. Si no lo vas a usar, sobra: cada métrica es algo más que mantener.

**Reto 2:** unas 16 líneas de `process_` y `python_`. `process_resident_memory_bytes` ronda los `5.6e+07`: unos 56 MB.

**Reto 3:** `0`, `200` y `"/metrics"`:
```python
from fastapi.testclient import TestClient

import tienda


def test_una_compra_queda_en_las_metricas():
    tienda.errores["porcentaje"] = 0
    cliente = TestClient(tienda.app)
    assert cliente.get("/comprar").status_code == 200
    assert 'tienda_requests_total{path="/comprar",status="200"}' in cliente.get("/metrics").text
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to instrument (code) | instrumentar: añadir mediciones al código |
| client library | librería cliente |
| middleware | código que envuelve cada petición |
| bucket | cubo, tramo de un histograma |
| high cardinality | cardinalidad alta: demasiadas series |

🎙️ *"I instrumented the service with the official Python client: a request counter labelled by route template and status code, a latency histogram with buckets around our target, and an in-progress gauge, all recorded in a single middleware. Labels never contain IDs or raw URLs."*

## Siguiente

[Clase 118 — Prometheus y PromQL](clase-118-prometheus-y-promql.md)
