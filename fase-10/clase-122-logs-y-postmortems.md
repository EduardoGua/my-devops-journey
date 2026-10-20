# Clase 122 — Logs estructurados y postmortems

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Avisar y entender

> 💡 **La idea de hoy:** un log de texto libre solo lo lee una persona, línea a línea; un log **estructurado** (una línea JSON por evento, con nivel, hora en UTC y campos) lo lee una máquina, y responde en un segundo "¿qué compras fallaron entre las 15:00 y las 15:10?". Un **`request_id`** une todas las líneas de una misma petición. Y cuando el incidente termina, el **postmortem sin culpables** explica qué pasó y qué cambiar, sin buscar a quién señalar.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La tienda instrumentada (clase 117) y sus incidentes provocados (clases 119 y 121).
> - El módulo `logging` (clase 48) y la hora en UTC (clase 45); `jq` (clase 47).
> - Que Docker, Kubernetes y CloudWatch recogen la salida estándar (clases 57, 103 y 76).
> - Las historias STAR (clase 91); el método de las averías (clases 63 y 112).

> 🔤 **Palabras nuevas de hoy:**
> - **log estructurado**: una línea por evento, con campos con nombre (JSON).
> - **nivel de log**: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.
> - **`request_id`** (identificador de petición): un id único que acompaña a una petición por todos los logs y servicios.
> - **`X-Request-ID`**: la cabecera HTTP en la que viaja ese id.
> - **postmortem sin culpables** (*blameless*): el análisis de un incidente que busca fallos del sistema, no de personas.
> - **5 porqués**: preguntar "¿por qué?" hasta llegar a algo que se pueda cambiar.
> - **acción** (*action item*): un cambio con responsable y fecha.

## Objetivo

- Escribir logs que se puedan consultar: una línea JSON por evento, con nivel, hora en UTC y campos.
- Seguir una petición de punta a punta con un **identificador de petición** (`request_id`).
- Filtrar y resumir logs con `jq`, como lo harías en CloudWatch Logs Insights o en Loki.
- Saber qué no debe aparecer nunca en un log.
- Escribir un **postmortem sin culpables** de un incidente: impacto, línea de tiempo, causa raíz y acciones.

## Por qué importa

Las métricas te dicen **que** algo va mal; los logs, **qué** pasó con cada petición. Pero un log de texto libre ("Error!!! no va el banco") solo lo lee una persona, línea a línea. Un log estructurado lo lee una máquina: "dame las compras que fallaron entre las 15:00 y las 15:10, con su tiempo", en un segundo.

Y cuando el incidente termina, empieza lo más valioso: entender por qué pasó y qué cambiar para que no se repita. El **postmortem** es la herramienta, y en los equipos buenos se escribe sin buscar culpables. En una entrevista, contar uno bien vale más que cualquier certificación.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 50 min), con los logs; el segundo, las **piezas 4 y 5**, con el postmortem, el Rómpelo, el reto y el cierre.

```bash
cp -r ~/my-devops-journey/labs/clase-117 ~/my-devops-journey/labs/clase-122
cd ~/my-devops-journey/labs/clase-122
```

## Las piezas

### Pieza 1 — Un log estructurado

```json
{"ts": "2026-10-10T16:57:31.745+00:00", "level": "INFO", "msg": "petición atendida",
 "request_id": "3be23e82ac0e49829c800a506250586b", "method": "GET", "path": "/comprar", "status": 500, "ms": 29.0}
```

- **Una línea, un evento**, en JSON: cada campo se puede filtrar sin expresiones regulares.
- **Hora en UTC**, con zona (clase 45).
- **Nivel:** `DEBUG` (detalle para depurar; apagado en producción), `INFO` (lo normal), `WARNING` (raro, pero se sigue), `ERROR` (algo falló), `CRITICAL` (el servicio no puede seguir).
- **Contexto:** qué petición (`request_id`), qué ruta, qué resultado y cuánto tardó.
- **A la salida estándar** (*stdout*), nunca a un archivo dentro del contenedor. Docker, Kubernetes y CloudWatch recogen la salida estándar.

Y lo que **nunca** va en un log: contraseñas, tokens, llaves, números de tarjeta, documentos de identidad… ni una cabecera `Authorization` completa. Los logs se copian, se envían a otros sistemas y los lee mucha gente: un secreto en un log es un secreto publicado.

**Pruébalo.** En `tienda.py`, añade a las importaciones `json`, `logging`, `sys`, `uuid` y `from datetime import datetime, timezone`. Después de `disable_created_metrics()`, el formato:

```python
class FormatoJSON(logging.Formatter):
    """Una línea JSON por evento: fácil de filtrar con jq, CloudWatch Logs Insights o Loki."""

    def format(self, registro):
        datos = {"ts": datetime.fromtimestamp(registro.created, timezone.utc).isoformat(timespec="milliseconds"),
                 "level": registro.levelname, "msg": registro.getMessage()}
        datos.update(getattr(registro, "campos", {}))
        if registro.exc_info:
            datos["exc"] = self.formatException(registro.exc_info)
        return json.dumps(datos, ensure_ascii=False)


salida = logging.StreamHandler(sys.stdout)
salida.setFormatter(FormatoJSON())
log = logging.getLogger("tienda")
log.addHandler(salida)
log.setLevel(logging.INFO)
log.propagate = False
```

- Los campos extra viajan en `extra={"campos": {…}}` y el formato los añade al JSON.
- `formatException` mete la traza de una excepción en **un** campo: la línea sigue siendo una línea.
- `propagate = False` evita que el mismo mensaje salga además por el log por defecto.

Y en `comprar()`, justo antes del `raise`:

```python
        log.error("el banco no responde", extra={"campos": {"evento": "pago_fallido"}})
```

Compruébalo sin servidor, desde la carpeta:

```bash
source .venv/bin/activate
python3 -c 'import tienda; tienda.log.info("hola", extra={"campos": {"prueba": 1}})'
```

👀 **Qué deberías ver:** una sola línea, `{"ts": "…+00:00", "level": "INFO", "msg": "hola", "prueba": 1}`, con la hora en UTC.

✋ **Sin mirar:** ¿por qué la tienda escribe sus logs en la salida estándar y no en un archivo?

<details>
<summary>Comprueba</summary>

Porque Docker, Kubernetes y CloudWatch recogen la salida estándar del contenedor. Un archivo dentro del contenedor se pierde con él y nadie lo envía a ninguna parte.
</details>

**En resumen:** una línea JSON por evento, en UTC, a la salida estándar, y nunca un secreto.

### Pieza 2 — El `request_id`: una petición de punta a punta

| Necesito… | Uso |
|-----------|-----|
| saber si va peor que hace una hora | una métrica |
| saber por qué falló **esta** petición | el log, buscando su `request_id` |
| contar algo con muchos valores posibles (por usuario, por producto) | el log, no una etiqueta de métrica (clase 117) |

El `request_id` une las piezas: el balanceador lo genera, cada servicio lo pasa en la cabecera `X-Request-ID` y lo escribe en cada línea. Es la versión casera de lo que hacen las trazas (clase 116).

**Pruébalo.** En el *middleware*, el `request_id` al principio:

```python
    # el id de la petición: el que traiga el cliente o el balanceador, o uno nuevo
    request.state.request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
```

y al final, en lugar del bloque `if plantilla != "/metrics":`:

```python
    if plantilla != "/metrics":
        segundos = time.perf_counter() - inicio
        DURACION.labels(path=plantilla).observe(segundos)
        PETICIONES.labels(path=plantilla, status=str(respuesta.status_code)).inc()
        log.info("petición atendida", extra={"campos": {
            "request_id": request.state.request_id, "method": request.method, "path": plantilla,
            "status": respuesta.status_code, "ms": round(segundos * 1000, 1)}})
    respuesta.headers["X-Request-ID"] = request.state.request_id
    return respuesta
```

En el `Dockerfile`, añade `"--no-access-log"` al final del `CMD`: el log de acceso de uvicorn es texto y repetiría lo que ya escribes tú. Construye la versión 2:

```bash
deactivate
docker build -t tienda:2 .
docker run -d --name tienda2 -p 127.0.0.1:8082:8000 tienda:2
for i in $(seq 1 40); do curl -s -o /dev/null localhost:8082/comprar; done
curl -s -D - -o /dev/null -H "X-Request-ID: prueba-123" localhost:8082/productos/7 | grep -i x-request-id
docker logs tienda2 | head -5
```

👀 **Qué deberías ver:** `x-request-id: prueba-123`: la tienda devuelve el id que le diste. En los logs, las primeras líneas son del arranque de uvicorn, en texto (`INFO:     Started server process…`); las demás, tu JSON, una por petición, cada una con su `request_id`.

✋ **Sin mirar:** un usuario dice "mi compra falló a las 15:04". ¿Qué buscas en los logs?

<details>
<summary>Comprueba</summary>

Las líneas de `/comprar` con `status` 500 hacia las 15:04 y, de ahí, su `request_id`: con él encuentras todas las líneas de esa petición, en este y en otros servicios.
</details>

**En resumen:** un id por petición, que viaja en `X-Request-ID` y aparece en cada línea.

### Pieza 3 — Preguntar a los logs

`jq -R 'fromjson? | …'` lee cada línea como texto, intenta convertirla en JSON y se salta las que no lo son. Con `-s`, `jq` lee todas las líneas a la vez y puede contar, sumar y agrupar: una pequeña métrica sacada de los logs.

**Pruébalo:**

```bash
docker logs tienda2 | jq -cR 'fromjson? | select(.status >= 500)'
docker logs tienda2 | jq -cR 'fromjson? | select(.level == "ERROR")'
docker logs tienda2 | jq -cR 'fromjson? | select(.request_id == "prueba-123")'
docker logs tienda2 | jq -sR '[split("\n")[] | fromjson? | select(.path == "/comprar") | .ms] | {n: length, max: max, media: (add / length)}'
```

🔮 **Predice:** ¿cuántas líneas de `ERROR` habrá, comparadas con las peticiones con `status` 500?

👀 **Qué deberías ver:** las mismas: una por cada compra fallida. Pero fíjate en que la línea de `ERROR` no lleva `request_id`: con mucho tráfico, no sabrías qué petición la causó. Lo arreglas en el reto 1. La última consulta, en mis pruebas: 40 compras con una media de 97 ms y un máximo de 387 ms. Es lo que hace CloudWatch Logs Insights (clase 123), a escala.

✋ **Sin mirar:** ¿para qué sirve el `?` de `fromjson?`?

<details>
<summary>Comprueba</summary>

Para que las líneas que no son JSON (el arranque de uvicorn) se salten en silencio, en lugar de parar `jq` con un error.
</details>

**En resumen:** con logs estructurados, `jq` filtra, cuenta y resume sin expresiones regulares.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Puedes dejar `tienda2` en marcha o borrarla (`docker rm -f tienda2`): el resto de la clase es escritura.

### Pieza 4 — El postmortem sin culpables

Se escribe después de cada incidente que importa, y responde: ¿qué pasó, a quién afectó, por qué, cómo nos enteramos y qué vamos a cambiar? **Sin culpables** (*blameless*) significa que se asume que todos actuaron bien con lo que sabían. Si una persona pudo romper producción con un comando, el problema es que el sistema lo permitía. Si se busca culpable, la gente esconde los errores, y el equipo deja de aprender.

Las piezas:
1. **Resumen**, en tres líneas.
2. **Impacto:** quién lo notó, cuánto duró, cuánto presupuesto de errores se gastó.
3. **Línea de tiempo**, en UTC: el primer síntoma, la alerta, quién hizo qué y la resolución.
4. **Causa raíz y factores que contribuyeron.** Los **5 porqués** ayudan: pregunta "¿por qué?" hasta llegar a algo que se pueda cambiar.
5. **Detección:** ¿lo vio antes una alerta o un usuario?
6. **Qué salió bien, qué salió mal y dónde tuvimos suerte.**
7. **Acciones**, con responsable y fecha: para que no vuelva a pasar, para detectarlo antes y para arreglarlo más rápido.

**Pruébalo, en papel.** Lee este modelo, ya relleno, de un incidente de la clase 79. Lo escribió Claude, para que veas el tono y la longitud: una línea por campo.

> **Modelo (lo escribió Claude): Vigía v3 — el informe diario no llegó a S3**
>
> - **Resumen:** el 12 de octubre, el informe diario de Vigía no se subió a S3 durante 2 días. Los contenedores no recibían credenciales del rol por el límite de saltos de IMDS. Se resolvió subiendo el límite a 2.
> - **Impacto:** 2 informes diarios sin publicar; la API y los chequeos siguieron funcionando; ningún usuario externo afectado.
> - **Línea de tiempo (UTC):** 12/10 06:00, primer informe fallido · 14/10 09:10, lo veo al abrir el bucket · 09:25, el log del servicio dice `NoCredentialsError` · 09:40, límite de saltos a 2 · 09:45, informe lanzado a mano: en S3.
> - **Causa raíz (5 porqués):** el informe falló → boto3 no tenía credenciales → el token de IMDS no llegaba al contenedor → la respuesta moría en el puente de Docker → la instancia se lanzaba con el límite de saltos en 1, el valor de la clase 78, pensado para una máquina sin contenedores.
> - **Detección:** tarde y a mano: ninguna alerta vigilaba que el informe llegara.
> - **Qué salió bien / mal / suerte:** bien, el log decía el error exacto; mal, 2 días sin enterarme; suerte, era un laboratorio.
> - **Acciones:** límite de saltos 2 en el comando de lanzamiento (prevenir, yo, 14/10) · alerta si no hay informe de hoy a las 07:00 (detectar, yo, 15/10) · comprobación de credenciales en `verify-aws.sh` (detectar, yo, 15/10).

¿Dónde está "sin culpables" en el modelo? Busca si alguna línea dice quién se equivocó.

<details>
<summary>Comprueba</summary>

Ninguna línea culpa a nadie: la causa raíz termina en una **configuración** ("se lanzaba con el límite en 1, pensado para otra cosa"), y las acciones cambian el sistema (el comando, una alerta, una comprobación), no a una persona.
</details>

✋ **Sin mirar:** ¿qué tres tipos de acción debería tener un postmortem?

<details>
<summary>Comprueba</summary>

Para **prevenir** (que no vuelva a pasar), para **detectar** antes y para **mitigar** (arreglarlo más rápido). Cada una con responsable y fecha.
</details>

**En resumen:** qué pasó, impacto, línea de tiempo, 5 porqués, detección y acciones; el sistema, nunca la persona.

### Pieza 5 — Tu postmortem, con la plantilla

El incidente que provocaste en las clases 119 y 121 (los errores al 50 % durante unos minutos) tiene una causa raíz obvia: "alguien cambió el porcentaje". Y eso es lo interesante: pregunta por qué el sistema permitía hacerlo sin control (un `POST` sin autenticación), por qué la alerta tardó más de 6 minutos y qué te habría ayudado a resolverlo antes.

**Pruébalo.** Saca los datos de lo que ya tienes:
- **cuántas compras fallaron:** en Prometheus, `sum(increase(tienda_requests_total{status=~"5.."}[30m]))` en el momento adecuado (busca el pico en la gráfica);
- **cuánto presupuesto se gastó:** con el consumo de la clase 121;
- **la línea de tiempo:** cuándo cambiaste el porcentaje, cuándo se puso *pending* la alerta, cuándo se disparó y cuándo llegó al receptor (sus logs llevan hora).

Y rellena los huecos en `notas/fase-10/postmortem-tienda.md`. Una línea por campo, como el modelo:

```markdown
# Postmortem: errores en las compras de la tienda — ____

- **Resumen:** el ____, las compras de la tienda fallaron un ____ % durante ____ minutos, porque ____. Se resolvió ____.
- **Impacto:** ____ compras fallidas; de ____ a ____ UTC; presupuesto gastado: ____.
- **Línea de tiempo (UTC):** ____, el porcentaje sube al 50 % · ____, `TiendaMuchosErrores` en pending · ____, firing · ____, aviso en el receptor · ____, vuelta al 5 %.
- **Causa raíz (5 porqués):** fallaban las compras → ____ → ____ → ____ → el endpoint `/errores` acepta cambios sin ____.
- **Detección:** la alerta tardó ____ minutos, porque ____.
- **Qué salió bien / mal / suerte:** bien, ____; mal, ____; suerte, ____.
- **Acciones:** ____ (prevenir, ____, ____) · ____ (detectar, ____, ____) · ____ (mitigar, ____, ____).
```

👀 **Qué deberías ver:** un documento de siete líneas, sin ninguna frase que señale a una persona, y con tres acciones que cambian el sistema.

✋ **Sin mirar:** en tu postmortem, ¿la causa raíz es "Eduardo cambió el porcentaje"?

<details>
<summary>Comprueba</summary>

No: esa es la primera respuesta, no la raíz. La raíz es lo que lo permitió: un endpoint que cambia el comportamiento en producción sin autenticación ni registro de quién lo usó.
</details>

**En resumen:** los datos salen de Prometheus y de los logs; la plantilla, una línea por campo.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `class FormatoJSON(logging.Formatter)` + `json.dumps(…)` | una línea JSON por evento |
| `log.info("msg", extra={"campos": {…}})` | un evento con campos |
| `datetime.fromtimestamp(t, timezone.utc).isoformat(timespec="milliseconds")` | la hora en UTC |
| `request.headers.get("X-Request-ID") or uuid.uuid4().hex` | el id de la petición |
| `respuesta.headers["X-Request-ID"] = …` | devolverlo al cliente |
| `jq -cR 'fromjson? \| select(.status >= 500)'` | filtrar logs mezclados con texto |
| `jq -sR '[split("\n")[] \| fromjson? \| …]'` | contar y resumir todas las líneas |
| resumen · impacto · línea de tiempo · 5 porqués · detección · acciones | las partes de un postmortem |

## Rómpelo

1. **Un secreto en un log.** Añade un `log.info` que escriba la cabecera `Authorization` de la petición, y haz `curl -H "Authorization: Bearer secreto-de-prueba" localhost:8082/health`. ¿Lo encuentras con `docker logs tienda2 | grep secreto`? Ahora imagina esos logs enviados a CloudWatch, guardados un año y leídos por todo el equipo. Quítalo.
2. **Una traza en texto.** Haz que `/health` lance una excepción (`1 / 0`) y mira el log de uvicorn: la traza ocupa varias líneas. ¿Qué haría con ella un `grep` o un `jq` línea a línea? Captúrala tú con `log.exception("…")` dentro de un `try`, y mira cómo queda en tu JSON.
3. **`DEBUG` en producción.** Cambia el nivel a `DEBUG` y añade un `log.debug` por cada paso de `comprar()`. Con 3 peticiones por segundo, ¿cuántas líneas al día? A 0,50 USD por GB en CloudWatch (clase 123), ¿cuánto costaría al mes si cada línea ocupa 200 bytes?

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Que la línea de `ERROR` de `comprar()` lleve también el `request_id`.

> 🧩 **Ejemplo resuelto:** la pieza 2: en el *middleware*, `request.state.request_id` guarda el id de la petición.

**Ahora tú, con huecos:**
```python
@app.get("/comprar")
def comprar(request: ____):
    …
        log.error("el banco no responde", extra={"campos": {
            "evento": "pago_fallido", "request_id": request.____.request_id}})
```

<details>
<summary>Pista</summary>

FastAPI le pasa a la ruta la petición si la pides como parámetro con el tipo `Request`. Reconstruye la imagen (`tienda:2`) y vuelve a mirar las líneas de `ERROR`.
</details>

**2.** Con `jq`, la proporción de errores por minuto a partir de los logs.

> 🧩 **Ejemplo resuelto:** la pieza 3: `jq -sR '[split("\n")[] | fromjson? | select(.path == "/comprar") | .ms] | {n: length, …}'` resumía todas las compras.

**Ahora tú, con huecos:**
```bash
docker logs tienda2 | jq -sR '[split("\n")[] | fromjson? | select(.path == "/comprar")]
  | group_by(.ts[:____]) | map({minuto: .[0].ts[:16], errores: (map(select(.status >= ____)) | length), total: ____})'
```

<details>
<summary>Pista</summary>

`.ts[:16]` son los 16 primeros caracteres de la hora: `2026-10-10T16:57`, el minuto. `group_by` junta las líneas con el mismo minuto.
</details>

**3.** El postmortem de un incidente **tuyo** del curso: la actualización rota de Vigía de la clase 115, una avería de la 112 o el límite de saltos de la 79 (el del modelo, con tus datos de verdad). Será una de tus historias STAR (clase 91).

> 🧩 **Ejemplo resuelto:** el modelo de la pieza 4.

**Ahora tú, con huecos:** la misma plantilla de la pieza 5, en `notas/fase-10/postmortem-<incidente>.md`, una línea por campo.

<details>
<summary>Pista</summary>

Si no apuntaste las horas, busca en el historial de Git (`git log --format='%ad %s' --date=iso`), en `kubectl rollout history` o en tus notas de la clase. Una línea de tiempo aproximada vale más que ninguna.
</details>

## Destruir al terminar

```bash
docker rm -f tienda2
```

## Cierre

En `notas/fase-10/clase-122.md`:

1. ¿Qué hace "estructurado" a un log, y qué ganas con ello? *(2 líneas. Empieza así: «Que cada evento es una línea con campos con nombre…»)*
2. ¿Para qué sirve el `request_id`? *(2 líneas. Empieza así: «Para seguir una petición por todas las líneas de log que genera…»)*
3. ¿Qué significa que un postmortem sea "sin culpables", y por qué funciona mejor? *(2 líneas. Empieza así: «Que se asume que cada persona hizo lo razonable con lo que sabía…»)*
4. **Repaso (clase 121, sin mirar):** ¿cuánto tiempo caído permite al mes un SLO del 99,5 %? *(1 línea, con la cuenta.)*

Después, escríbeme `examíname clase-122`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Que cada evento es una línea con campos con nombre (JSON), en lugar de una frase. Una máquina puede filtrar por cualquier campo (`status >= 500`), agrupar y contar sin expresiones regulares frágiles, y las herramientas (CloudWatch, Loki, jq) lo entienden directamente.
2. Para seguir **una** petición por todas las líneas de log que genera, en uno o en varios servicios: el que la recibe lo crea (o lo toma de la cabecera `X-Request-ID`), lo pasa a los demás y cada uno lo escribe. Ante una queja ("mi compra falló a las 15:04"), encuentras todo lo que le pasó a esa petición.
3. Que se asume que cada persona hizo lo razonable con lo que sabía, y se busca qué permitió el error en el sistema: falta de una prueba, de una alerta, de un control. Funciona porque la gente cuenta lo que pasó de verdad, sin miedo, y las acciones arreglan el sistema en lugar de castigar a alguien.
4. 3 horas y 36 minutos (el 0,5 % de 43 200 minutos).

**Rómpelo 3:** 3 peticiones por segundo × 86 400 segundos × las líneas de cada una (digamos 5) son 1,3 millones de líneas al día; a 200 bytes, unos 260 MB al día y casi 8 GB al mes: unos 4 USD al mes solo en ingesta, por una tienda de juguete. Con tráfico real, cientos.

**Reto 1:** `request: Request` y `request.state.request_id`:
```python
@app.get("/comprar")
def comprar(request: Request):
    …
        log.error("el banco no responde", extra={"campos": {
            "evento": "pago_fallido", "request_id": request.state.request_id}})
```

**Reto 2:** `.ts[:16]`, `>= 500` y `length`:
```bash
docker logs tienda2 | jq -sR '[split("\n")[] | fromjson? | select(.path == "/comprar")]
  | group_by(.ts[:16]) | map({minuto: .[0].ts[:16], errores: (map(select(.status >= 500)) | length), total: length})'
```

**Postmortem de la pieza 5, una forma de rellenarlo:** causa raíz, "fallaban las compras → la tienda devolvía 500 al 50 % → alguien subió el porcentaje con `POST /errores/50` → el endpoint estaba abierto a cualquiera que llegara a la tienda → `/errores` acepta cambios sin autenticación ni registro". Detección: "la alerta tardó unos 6 minutos y medio, porque mira 5 minutos de `rate()` más su `for: 5m`". Acciones: "proteger `/errores` o quitarlo fuera del laboratorio (prevenir)", "alerta de consumo rápido de la clase 121 (detectar)", "un *runbook* que empiece por mirar los cambios recientes (mitigar)".
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| structured logging | logs estructurados |
| log level | nivel de log |
| correlation / request ID | identificador de petición |
| blameless postmortem | postmortem sin culpables |
| root cause / contributing factors | causa raíz / factores que contribuyeron |
| action item | acción con responsable y fecha |

🎙️ *"Our services log one JSON line per request, in UTC, with a request ID that travels in the X-Request-ID header, and never any secrets. After an incident we write a blameless postmortem: impact, timeline, five whys, and action items with an owner and a date."*

## Siguiente

[Clase 123 — CloudWatch, la alternativa gestionada](clase-123-cloudwatch.md)
