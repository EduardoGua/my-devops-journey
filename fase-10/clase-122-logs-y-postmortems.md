# Clase 122 — Logs estructurados y postmortems

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Avisar y entender

## Objetivo

- Escribir logs que se puedan consultar: una línea JSON por evento, con nivel, hora en UTC y campos.
- Seguir una petición de punta a punta con un **identificador de petición** (`request_id`).
- Filtrar y resumir logs con `jq`, como lo harías en CloudWatch Logs Insights o en Loki.
- Saber qué no debe aparecer nunca en un log.
- Escribir un **postmortem sin culpables** de un incidente: impacto, línea de tiempo, causa raíz y acciones.

## Por qué importa

Las métricas te dicen **que** algo va mal; los logs, **qué** pasó con cada petición. Pero un log de texto libre ("Error!!! no va el banco") solo lo lee una persona, línea a línea. Un log estructurado lo lee una máquina: "dame las compras que fallaron entre las 15:00 y las 15:10, con su tiempo", en un segundo.

Y cuando el incidente termina, empieza lo más valioso: entender por qué pasó y qué cambiar para que no se repita. El **postmortem** es la herramienta, y en los equipos buenos se escribe sin buscar culpables. En una entrevista, contar uno bien vale más que cualquier certificación.

## Teoría

### Un buen log

```json
{"ts": "2026-10-10T16:57:31.745+00:00", "level": "INFO", "msg": "petición atendida",
 "request_id": "3be23e82ac0e49829c800a506250586b", "method": "GET", "path": "/comprar", "status": 500, "ms": 29.0}
```

- **Una línea, un evento**, en JSON: cada campo se puede filtrar sin expresiones regulares.
- **Hora en UTC**, con zona (clase 45).
- **Nivel:** `DEBUG` (detalle para depurar; apagado en producción), `INFO` (lo normal), `WARNING` (raro, pero se sigue), `ERROR` (algo falló), `CRITICAL` (el servicio no puede seguir).
- **Contexto:** qué petición (`request_id`), qué ruta, qué resultado y cuánto tardó.
- **A la salida estándar** (*stdout*), nunca a un archivo dentro del contenedor. Docker, Kubernetes y CloudWatch recogen la salida estándar (clases 57, 103 y 76).

### Lo que nunca va en un log

Contraseñas, tokens, llaves, números de tarjeta, documentos de identidad… ni una cabecera `Authorization` completa. Los logs se copian, se envían a otros sistemas y los lee mucha gente: un secreto en un log es un secreto publicado.

### Logs y métricas, juntos

| Necesito… | Uso |
|-----------|-----|
| saber si va peor que hace una hora | una métrica |
| saber por qué falló **esta** petición | el log, buscando su `request_id` |
| contar algo con muchos valores posibles (por usuario, por producto) | el log, no una etiqueta de métrica (clase 117) |

El `request_id` une las piezas: el balanceador lo genera, cada servicio lo pasa en la cabecera `X-Request-ID` y lo escribe en cada línea. Es la versión casera de lo que hacen las trazas (clase 116).

### El postmortem sin culpables

Se escribe después de cada incidente que importa, y responde: ¿qué pasó, a quién afectó, por qué, cómo nos enteramos y qué vamos a cambiar? **Sin culpables** (*blameless*) significa que se asume que todos actuaron bien con lo que sabían. Si una persona pudo romper producción con un comando, el problema es que el sistema lo permitía. Si se busca culpable, la gente esconde los errores, y el equipo deja de aprender.

Las piezas:
1. **Resumen**, en tres líneas.
2. **Impacto:** quién lo notó, cuánto duró, cuánto presupuesto de errores se gastó.
3. **Línea de tiempo**, en UTC: el primer síntoma, la alerta, quién hizo qué y la resolución.
4. **Causa raíz y factores que contribuyeron.** Los **5 porqués** ayudan: pregunta "¿por qué?" hasta llegar a algo que se pueda cambiar.
5. **Detección:** ¿lo vio antes una alerta o un usuario?
6. **Qué salió bien, qué salió mal y dónde tuvimos suerte.**
7. **Acciones**, con responsable y fecha: para que no vuelva a pasar, para detectarlo antes y para arreglarlo más rápido.

## Práctica guiada

### 1. Logs en JSON en la tienda (30 min)

Copia la tienda a una carpeta nueva:

```bash
cp -r ~/my-devops-journey/labs/clase-117 ~/my-devops-journey/labs/clase-122
cd ~/my-devops-journey/labs/clase-122
```

En `tienda.py`, añade a las importaciones `json`, `logging`, `sys`, `uuid` y `from datetime import datetime, timezone`. Después de `disable_created_metrics()`, el formato:

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

En el *middleware*, el `request_id` al principio:

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

Y en `comprar()`, justo antes del `raise`:

```python
        log.error("el banco no responde", extra={"campos": {"evento": "pago_fallido"}})
```

En el `Dockerfile`, añade `"--no-access-log"` al final del `CMD`: el log de acceso de uvicorn es texto y repetiría lo que ya escribes tú. Construye la versión 2:

```bash
docker build -t tienda:2 .
docker run -d --name tienda2 -p 127.0.0.1:8082:8000 tienda:2
for i in $(seq 1 40); do curl -s -o /dev/null localhost:8082/comprar; done
curl -s -D - -o /dev/null -H "X-Request-ID: prueba-123" localhost:8082/productos/7 | grep -i x-request-id
docker logs tienda2 | head -5
```

Las primeras líneas son del arranque de uvicorn, en texto. Las demás, tu JSON.

### 2. Preguntar a los logs (15 min)

`jq -R 'fromjson? | …'` lee cada línea como texto, intenta convertirla en JSON y se salta las que no lo son:

```bash
docker logs tienda2 | jq -cR 'fromjson? | select(.status >= 500)'
docker logs tienda2 | jq -cR 'fromjson? | select(.level == "ERROR")'
docker logs tienda2 | jq -cR 'fromjson? | select(.request_id == "prueba-123")'
docker logs tienda2 | jq -sR '[split("\n")[] | fromjson? | select(.path == "/comprar") | .ms] | {n: length, max: max, media: (add / length)}'
```

🔮 **Predice:** ¿cuántas líneas de `ERROR` habrá, comparadas con las peticiones con `status` 500?

Las mismas: una por cada compra fallida. Pero fíjate en que la línea de `ERROR` no lleva `request_id`: con mucho tráfico, no sabrías qué petición la causó. Lo arreglas en el Reto 1.

La última consulta es una pequeña métrica sacada de los logs: en mis pruebas, 40 compras con una media de 97 ms y un máximo de 387 ms. Es lo que hace CloudWatch Logs Insights (clase 123), a escala.

### 3. Un postmortem (25 min)

Escribe en `notas/fase-10/postmortem-tienda.md` el postmortem del incidente que provocaste en las clases 119 y 121: los errores al 50 % durante unos minutos. Saca los datos de lo que ya tienes:
- **cuántas compras fallaron:** en Prometheus, `sum(increase(tienda_requests_total{status=~"5.."}[30m]))` en el momento adecuado (busca el pico en la gráfica);
- **cuánto presupuesto se gastó:** con el consumo de la clase 121;
- **la línea de tiempo:** cuándo cambiaste el porcentaje, cuándo se puso *pending* la alerta, cuándo se disparó y cuándo llegó al receptor (sus logs llevan hora).

Usa esta plantilla:

```markdown
# Postmortem: errores en las compras de la tienda — AAAA-MM-DD

**Estado:** borrador · **Autor:** Eduardo · **Gravedad:** alta

## Resumen
(tres líneas: qué pasó, cuánto duró, cómo se resolvió)

## Impacto
- Compras fallidas: …
- Duración: de HH:MM a HH:MM UTC (N minutos)
- Presupuesto de errores gastado: …

## Línea de tiempo (UTC)
- HH:MM — …
- HH:MM — la alerta TiendaMuchosErrores pasa a pending
- HH:MM — …

## Causa raíz
(los 5 porqués)

## Detección
¿Quién se enteró primero: la alerta, un usuario o tú mirando? ¿Cuánto tardó la alerta y por qué?

## Qué salió bien / qué salió mal / dónde tuvimos suerte

## Acciones
| Acción | Tipo (prevenir / detectar / mitigar) | Responsable | Fecha |
|--------|---------------------------------------|-------------|-------|
```

Un incidente provocado tiene una causa raíz obvia ("alguien cambió el porcentaje"), y eso es lo interesante: pregunta por qué el sistema permitía hacerlo sin control (un `POST` sin autenticación), por qué la alerta tardó más de 6 minutos y qué te habría ayudado a resolverlo antes.

## Rómpelo

1. **Un secreto en un log.** Añade un `log.info` que escriba la cabecera `Authorization` de la petición, y haz `curl -H "Authorization: Bearer secreto-de-prueba" localhost:8082/health`. ¿Lo encuentras con `docker logs tienda2 | grep secreto`? Ahora imagina esos logs enviados a CloudWatch, guardados un año y leídos por todo el equipo. Quítalo.
2. **Una traza en texto.** Haz que `/health` lance una excepción (`1 / 0`) y mira el log de uvicorn: la traza ocupa varias líneas. ¿Qué haría con ella un `grep` o un `jq` línea a línea? Captúrala tú con `log.exception("…")` dentro de un `try`, y mira cómo queda en tu JSON.
3. **`DEBUG` en producción.** Cambia el nivel a `DEBUG` y añade un `log.debug` por cada paso de `comprar()`. Con 3 peticiones por segundo, ¿cuántas líneas al día? A 0,50 USD por GB en CloudWatch (clase 123), ¿cuánto costaría al mes si cada línea ocupa 200 bytes?

## Reto

1. Que la línea de `ERROR` de `comprar()` lleve también el `request_id`. (Pista: la ruta puede recibir `request: Request` como parámetro, y el id está en `request.state.request_id`.)
2. Con `jq`, la proporción de errores por minuto a partir de los logs. (Pista: `.ts[:16]` es el minuto; `group_by`.)
3. Escribe el postmortem de un incidente **tuyo** del curso: la actualización rota de Vigía de la clase 115, una avería de la 112 o el límite de saltos de la 79. Será una de tus historias STAR (clase 91).

## Destruir al terminar

```bash
docker rm -f tienda2
```

## Cierre

En `notas/fase-10/clase-122.md`:

1. ¿Qué hace "estructurado" a un log, y qué ganas con ello?
2. ¿Para qué sirve el `request_id`?
3. ¿Qué significa que un postmortem sea "sin culpables", y por qué funciona mejor?
4. **Repaso (clase 121, sin mirar):** ¿cuánto tiempo caído permite al mes un SLO del 99,5 %?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Que cada evento es una línea con campos con nombre (JSON), en lugar de una frase. Una máquina puede filtrar por cualquier campo (`status >= 500`), agrupar y contar sin expresiones regulares frágiles, y las herramientas (CloudWatch, Loki, jq) lo entienden directamente.
2. Para seguir **una** petición por todas las líneas de log que genera, en uno o en varios servicios: el que la recibe lo crea (o lo toma de la cabecera `X-Request-ID`), lo pasa a los demás y cada uno lo escribe. Ante una queja ("mi compra falló a las 15:04"), encuentras todo lo que le pasó a esa petición.
3. Que se asume que cada persona hizo lo razonable con lo que sabía, y se busca qué permitió el error en el sistema: falta de una prueba, de una alerta, de un control. Funciona porque la gente cuenta lo que pasó de verdad, sin miedo, y las acciones arreglan el sistema en lugar de castigar a alguien.
4. 3 horas y 36 minutos (el 0,5 % de 43 200 minutos).

**Rómpelo 3:** 3 peticiones por segundo × 86 400 segundos × las líneas de cada una (digamos 5) son 1,3 millones de líneas al día; a 200 bytes, unos 260 MB al día y casi 8 GB al mes: unos 4 USD al mes solo en ingesta, por una tienda de juguete. Con tráfico real, cientos.

**Reto 1:**
```python
@app.get("/comprar")
def comprar(request: Request):
    …
        log.error("el banco no responde", extra={"campos": {
            "evento": "pago_fallido", "request_id": request.state.request_id}})
```

**Reto 2:**
```bash
docker logs tienda2 | jq -sR '[split("\n")[] | fromjson? | select(.path == "/comprar")]
  | group_by(.ts[:16]) | map({minuto: .[0].ts[:16], errores: (map(select(.status >= 500)) | length), total: length})'
```
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
