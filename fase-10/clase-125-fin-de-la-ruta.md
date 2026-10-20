# Clase 125 — Fin de la ruta: desde cero, la defensa y el examen final

**Tiempo:** 1 sesión para el arranque desde cero · 1 o 2 para preparar la defensa · 3 h el examen · **Bloque:** C. Proyecto y cierre de la ruta · **Aprobado: ≥ 80 %**

> 💡 **La idea de hoy:** el final de la ruta son tres pruebas. Vigía se levanta **desde cero** con un comando, en un clon limpio, y se destruye igual. Lo **defiendes en 10 minutos**, como en una entrevista técnica. Y demuestras sin apuntes lo que sabes de Terraform, Kubernetes y observabilidad en el **examen final**. Después, el CV al día y el siguiente paso.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Vigía de la v0 a la v7 (clases 21 a 124), con sus README y sus *What broke*.
> - La recreación desde cero de la v5 (clase 101) y el pipeline de la v4 (clase 90).
> - Tus historias STAR, el CV y el ritmo de postulación (clase 91); el examen de las fases 4 a 7.

> 🔤 **Palabras nuevas de hoy:**
> - **clon limpio**: una copia recién clonada del repositorio, sin nada de tu máquina.
> - **defensa técnica**: explicar un proyecto, sus decisiones y sus fallos ante alguien que pregunta.
> - **rúbrica**: la tabla con la que se puntúa una defensa o un examen.

## Objetivo

- Levantar Vigía **desde cero** con un comando, desde un clon limpio, y destruirlo igual.
- Defenderlo en **10 minutos**, como en una entrevista técnica: qué hace, cómo está construido, qué decidiste y por qué, qué se rompió.
- Demostrar, sin apuntes ni IA, lo que sabes de Terraform, Kubernetes y observabilidad: el **examen final de las fases 8 a 10**.
- Cerrar la ruta: actualizar tu CV con las versiones v5 a v7 y decidir qué viene después.

Es el último criterio de salida de la Ruta: *Vigía se levanta desde cero con un comando o un pipeline, se destruye igual, y lo explicas y defiendes en 10 minutos*.

## Por qué importa

Un proyecto que solo funciona en tu portátil, después de meses de retoques, no demuestra mucho. Uno que cualquiera clona y levanta con un comando, y que tú explicas en diez minutos con sus decisiones y sus fallos, es exactamente lo que busca quien contrata. Es la prueba de que sabes construir, operar y contar.

## Parte 1 · Desde cero, con un comando (1 sesión)

### 1. Dos scripts (30 min)

En tu repo de Vigía, `scripts/levantar.sh`. Desde un clon recién hecho, tiene que:
1. crear `.env` a partir de `.env.example` si no existe, con contraseñas aleatorias (`openssl rand -hex 16`), sin pisar uno que ya exista;
2. construir y arrancar todo: `docker compose up -d --build --wait`;
3. imprimir las direcciones: la API, Prometheus, Alertmanager y Grafana (con su usuario).

Y `scripts/destruir.sh`, que lo borra todo, datos incluidos, pidiendo confirmación: `docker compose down -v`.

Las reglas de siempre: `set -euo pipefail`, mensajes claros y `shellcheck` sin avisos (clases 19 y 20).

<details><summary>Pista — <code>--wait</code> y los servicios sin <em>healthcheck</em></summary>

`docker compose up --wait` espera a que cada servicio esté `running` y, si tiene *healthcheck*, `healthy`. Si un servicio termina enseguida (uno que no es un servidor) o nunca pasa su *healthcheck*, `--wait` falla. Lee el mensaje: dice cuál.
</details>

### 2. La prueba de fuego (30 min)

```bash
cd /tmp && rm -rf vigia-desde-cero
time (git clone https://github.com/<tu-usuario>/vigia.git vigia-desde-cero && cd vigia-desde-cero && bash scripts/levantar.sh)
```

Apunta el tiempo. Pasa las pruebas de la v2 y de la v7 contra ese clon:

```bash
cd /tmp/vigia-desde-cero
bash ~/my-devops-journey/recursos/vigia/v2/verify.sh
bash ~/my-devops-journey/recursos/vigia/v7/verify.sh
bash scripts/destruir.sh
```

Si algo falla en el clon y no en tu carpeta de siempre, has encontrado algo que tu carpeta tenía y Git no: un archivo sin añadir, un `.env` a mano, una imagen construida a mano. Arréglalo en el repositorio, no en el clon.

### 3. El otro camino: un pipeline

Tu Vigía también se levanta desde cero en AWS: Terraform y el pipeline de la v5 (clase 101), en tres pasos y con un tiempo medido. Si te quedan créditos y quieres repetirlo para la defensa, hazlo **el mismo día**, y destrúyelo al terminar. Si no, cuéntalo con el tiempo que mediste entonces.

## Parte 2 · La defensa de 10 minutos (1 o 2 sesiones)

### Cómo se reparte

| Minutos | Qué cuentas | Qué enseñas |
|---------|-------------|-------------|
| 1 | El problema: qué es Vigía y para quién | el README |
| 2 | La arquitectura | un diagrama: API, checker, PostgreSQL, Prometheus, Alertmanager, Grafana; y dónde ha corrido (Compose, EC2, kind) |
| 3 | La demo | `levantar.sh` ya hecho; `/status`; el dashboard; un sitio caído que salta como alerta (tráelo grabado o preparado: 5 minutos no caben) |
| 2 | Las decisiones y sus porqués | dos o tres: métricas leídas de la base de datos, OIDC en lugar de llaves, kind y no EKS por costo, un SLO de Vigía y no de los sitios |
| 1 | Qué se rompió y qué aprendiste | una historia real, con su dato |
| 1 | Qué harías después | lo que pondrías en *Limitations* y cómo lo resolverías |

### Las preguntas que te harán

Prepara una respuesta de 30 segundos para cada una. Muchas están en el 🎙️ de las clases.

1. ¿Por qué PostgreSQL y no SQLite?
2. ¿Cómo llega el código desde un commit hasta producción?
3. ¿Dónde están las credenciales de AWS del pipeline? ¿Y las de la instancia?
4. ¿Qué pasa si alguien cambia a mano un recurso de Terraform?
5. ¿Cómo recreas toda la infraestructura? ¿Cuánto tardas?
6. ¿Qué diferencia hay entre una sonda liveness y una readiness? ¿Cuáles usas y por qué?
7. ¿Cómo haces una actualización sin cortar el servicio, y cómo vuelves atrás?
8. ¿Qué cambiaría si Vigía corriera en EKS? ¿Cuánto costaría?
9. ¿Qué mides y por qué? ¿Qué alertas tienes, y cómo sabes que funcionan?
10. ¿Cuál es tu SLO, y qué haces cuando se gasta el presupuesto?
11. ¿Qué pasa si se cae Prometheus? ¿Quién vigila al vigilante?
12. ¿Qué es lo que peor está hecho de Vigía, y cómo lo arreglarías?

### Grábala y corrígete

Grábate entera, en inglés si puedes. Si no, en español primero y en inglés después. Corrígete con esta rúbrica:

| Criterio | Puntos |
|----------|--------|
| Cabe en 10 minutos y sigue el reparto | 2 |
| Se entiende la arquitectura sin conocer el proyecto | 2 |
| La demo funciona, o el plan B (la grabación) está listo | 2 |
| Cada decisión lleva su porqué y su alternativa | 2 |
| Cuenta un fallo real con su diagnóstico y su arreglo | 1 |
| Sin leer, con términos correctos | 1 |

Con 8 o más, está lista. Si quieres un ensayo con preguntas de verdad, pídeme `haz de entrevistador para la defensa de Vigía`.

## Parte 3 · El examen final de las fases 8 a 10

### Reglas

- **Dónde:** responde en `notas/fase-10/examen-<fecha>.md`. Tienes 3 horas.
- **Sin ayuda:** ni apuntes, ni internet, ni IA en las partes A, B y C.
- **Parte D:** puedes usar `--help`, `kubectl explain` y la documentación oficial de Kubernetes y de Prometheus. Tus notas y tus repositorios, no.
- **Parte E:** se graba con el móvil.
- **Corrección:** con [`examen-respuestas.md`](examen-respuestas.md) y su rúbrica, con la exigencia de un entrevistador.
- **Si no llegas al 80 %:** anota qué clases fallaste, repásalas (la clase y su reto) y repite el examen **una semana después**.

Si quieres una segunda opinión, escríbeme `revisa examen fases 8 a 10`.

---

### Parte A — Conceptos (30 puntos, 2 por pregunta)

Respuestas de 2 a 4 frases, con un ejemplo cuando ayude.

**A1.** ¿Qué es el estado de Terraform? ¿Por qué no va a Git, y dónde y cómo lo guardaste?

**A2.** ¿Qué te dice `terraform plan` y por qué se lee entero? ¿Qué significa un `-/+`?

**A3.** Alguien cambia a mano una regla de un security group que gestiona Terraform. ¿Qué pasa en el siguiente `plan`, y qué tres salidas tienes?

**A4.** ¿Para qué sirve un módulo de Terraform, y qué es su "interfaz"?

**A5.** ¿Qué hace `prevent_destroy`, y en qué recurso de Vigía lo usaste?

**A6.** Nombra las piezas del *control plane* de Kubernetes y di qué hace cada una.

**A7.** ¿Qué diferencia hay entre un Deployment y un StatefulSet? ¿Qué usó Vigía para cada componente?

**A8.** ¿Qué diferencia hay entre una sonda liveness y una readiness? ¿Qué hace Kubernetes cuando falla cada una?

**A9.** ¿Por qué no se usa la IP de un pod? ¿Qué hace un Service, y qué tipos conoces?

**A10.** ¿Está cifrado un Secret de Kubernetes? ¿Qué lo protege de verdad?

**A11.** ¿Qué diferencia hay entre `requests` y `limits`? ¿Qué pasa al superar el límite de CPU y el de memoria?

**A12.** Métricas, logs y trazas: ¿qué pregunta responde cada uno?

**A13.** ¿Qué diferencia hay entre un counter y un gauge? ¿Por qué un counter se consulta con `rate()`?

**A14.** SLI, SLO, SLA y presupuesto de errores, con un ejemplo. ¿Cuánto tiempo caído permite al mes un SLO del 99,9 %?

**A15.** ¿Qué hace útil a una alerta? ¿Para qué sirve el `for`, y por qué se alerta por síntomas?

### Parte B — Revisión de código (20 puntos, 4 por bloque)

Cada bloque tiene **varios** problemas. Para cada uno, di qué está mal y cómo lo arreglarías.

**B1.** Terraform:

```hcl
terraform {
  backend "s3" {
    bucket         = "vigia-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

resource "aws_security_group" "web" {
  name = "web"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**B2.** Un Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: apy
    spec:
      containers:
        - name: api
          image: vigia:latest
          env:
            - name: DATABASE_URL
              value: postgresql://vigia:secreto123@db:5432/vigia
          livenessProbe:
            httpGet:
              path: /status
              port: 8000
```

**B3.** Dos reglas de alerta:

```yaml
groups:
  - name: vigia
    rules:
      - alert: CPUAlta
        expr: node_cpu_usage > 0.8
      - alert: ErroresAPI
        expr: rate(vigia_http_requests_total{status="500"}[30s]) > 0
        labels:
          severity: critical
```

(Prometheus lee cada 15 segundos.)

**B4.** Un Compose de observabilidad:

```yaml
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin123
    ports:
      - "3000:3000"
```

**B5.** Instrumentar una API:

```python
from prometheus_client import Counter

PETICIONES = Counter("peticiones", "Peticiones", ["usuario", "url"])


@app.middleware("http")
async def medir(request, call_next):
    respuesta = await call_next(request)
    PETICIONES.labels(usuario=request.headers.get("X-User"), url=str(request.url)).inc()
    return respuesta
```

### Parte C — Diagnóstico (25 puntos, 5 por escenario)

Para cada escenario: **tus 3 a 5 primeros comandos o pasos, en orden**, qué esperas ver en cada uno y tu hipótesis principal.

**C1.** En un PR que solo cambia el README, el `plan` del pipeline propone `-/+` en `aws_instance.vigia` (*forces replacement*).

**C2.** Después de un `kubectl apply`, los pods de la API están `Running` pero `0/1` en `READY`, y `RESTARTS` sube cada medio minuto. Sus logs no muestran ningún error.

**C3.** En kind, los pods de la API nuevos se quedan en `ImagePullBackOff` con la imagen `vigia:7.0.1`, que acabas de construir.

**C4.** El panel de disponibilidad del dashboard de Grafana dice *No data*, pero `curl localhost:8000/metrics` muestra `vigia_site_up` con valores.

**C5.** Ayer un sitio estuvo caído 20 minutos y `VigiaSitioCaido` no avisó. Hoy la regla aparece cargada en Prometheus, sin errores.

### Parte D — Práctica (15 puntos, 45 minutos)

En tu cluster de kind (con cloud-provider-kind en marcha), en una carpeta nueva `~/examen-fase10`.

**D1 (8 puntos).** Un namespace `examen` con podinfo (`ghcr.io/stefanprodan/podinfo:6.14.1`):
- un Deployment de 2 réplicas, con readiness en `/readyz` y liveness en `/healthz`, `requests` y límite de memoria, y sin root;
- un Service `podinfo` (ClusterIP, puerto 80 hacia el 9898);
- una entrada desde fuera: un Gateway y una HTTPRoute, o un Ingress, para el host `examen.lab.test`.

Comprueba con `curl` desde tu Ubuntu. Después actualiza a la `6.15.0` con un cambio en el archivo, comprueba la versión, y vuelve a la `6.14.1` con `kubectl rollout undo`. Deja escritos los comandos y sus salidas.

**D2 (7 puntos).** Para la tienda de la clase 117, una regla `TiendaLenta`: el p95 de `/comprar` por encima de 500 ms durante 10 minutos, con `severity: warning` y un `summary`. Y su prueba unitaria con `promtool test rules`: no salta a los 5 minutos de lentitud y sí a los 12. Tiene que pasar `promtool test rules`.

### Parte E — En voz alta, en inglés (10 puntos)

Graba con el móvil, sin leer:

**E1 (5 puntos).** Tres minutos: cómo se despliega y se observa Vigía hoy (Kubernetes o Compose, el pipeline, las métricas, la alerta y el SLO).

**E2 (5 puntos).** Una historia STAR de las fases 8 a 10: el `-target` de la recreación, la actualización rota de la clase 115, el conflicto de Helm de la 113, una alerta que tardó en saltar…

Escúchate y corrígete con la rúbrica.

## Parte 4 · El final de la ruta

### 1. Tu CV y tu LinkedIn, al día (1 h)

En la sección de Vigía del CV de la clase 91, añade, con tus números:

```
• Infrastructure as code with Terraform: S3 backend with native locking, a local network module,
  plan on every PR; destroyed and rebuilt from scratch in N minutes.
• Kubernetes (kind): Deployments with probes and limits, a PostgreSQL StatefulSet, a checker CronJob,
  Gateway API; rolling updates and rollbacks tested.
• Observability: Prometheus metrics, alerts with unit tests through Alertmanager, Grafana dashboards as code,
  and an SLO with its error budget.
```

En *Skills*, Terraform, Kubernetes, Helm, Prometheus y Grafana. Y en LinkedIn, una publicación corta contando que terminaste la ruta, con el enlace a Vigía y lo que más aprendiste. Las publicaciones de proyectos reales abren conversaciones.

Modelo para adaptar (lo escribió Claude). Cambia los huecos por tus datos, y quita lo que no sea verdad para ti:

```
I just finished a ____-month path from Linux basics to cloud and DevOps, and the result is Vigía,
a small uptime monitor that I built, broke and rebuilt many times: ____.

What it does today:
• Runs on AWS with Terraform (rebuilt from scratch in ____ minutes) and on Kubernetes with kind
• Ships through a GitHub Actions pipeline with OIDC, tests and automatic rollback
• Watches itself: Prometheus metrics, tested alerts, Grafana dashboards and an SLO

The lesson I didn't expect: ____.

I'm now looking for my first role in cloud / DevOps / NOC. Feedback and conversations welcome.
```

Lo más tuyo es la línea de la lección: una sola frase, concreta (un fallo que te enseñó algo), vale más que tres párrafos generales.

### 2. Qué viene después

- **Sigue postulando** con el ritmo de la clase 91: ahora con un proyecto completo.
- **Una certificación más**, cuando te la pida el mercado: la *AWS Solutions Architect – Associate* (SAA-C03) es la siguiente natural después del CLF; la *Terraform Associate* (apéndice de la clase 101) o la *CKAD*/*CKA* si las ofertas que te interesan piden Terraform o Kubernetes.
- **Mantén Vigía vivo:** actualiza versiones cada pocos meses (pídeme `revisa la fase N`), cierra algo de *Limitations*, escribe un postmortem de verdad cuando algo falle.
- **El siguiente tramo:** el camino de junior a arquitecto está en `~/Documentos/ruta-junior-a-arquitecto-nube.md`. Ábrelo cuando tengas tu primer trabajo, o cuando lleves tres meses postulando con el CV nuevo.

## Cierre

En `notas/fase-10/clase-125.md`:

1. El tiempo de tu arranque desde cero, y qué tuviste que arreglar en el repositorio para que funcionara en un clon limpio. *(2 líneas. Empieza así: «Tardó … minutos. En el clon limpio faltaba…»)*
2. Tu nota de la defensa con la rúbrica, y la pregunta que peor respondiste. *(2 líneas. Empieza así: «… de …. La que peor respondí fue … porque…»)*
3. Tu nota del examen, por partes, y las dos clases que más vas a repasar. *(2 líneas: «A …, B …, C …, D …, E …. Repasaré la … y la …»)*
4. Lo que más te costó de toda la ruta, y lo que harías distinto si empezaras hoy. *(2 líneas, una por pregunta.)*

## Al terminar la ruta

1. Marca en [`PROGRESO.md`](../PROGRESO.md):
   - las clases 124 y 125;
   - Vigía v7;
   - el examen final y la defensa;
   - los **criterios de salida de la fase 10**, solo si los cumples sin mirar.
2. Anota tus horas en el registro mensual de la Ruta 2.0, y la fecha en que terminaste.
3. Apaga lo que quede encendido: `docker compose down` en Vigía, `docker stop lab-control-plane cloud-provider-kind`, y en AWS comprueba con `aws resourcegroupstaggingapi get-resources --tag-filters Key=Proyecto,Values=vigia` que solo queda lo que quieres conservar.
4. Pídeme `cierra la ruta`: revisamos juntos tu PROGRESO, tu CV y tu plan de los próximos tres meses.

¡Enhorabuena! Empezaste abriendo una terminal en la clase 01. Hoy tienes un sistema real que construyes, despliegas, observas y defiendes.
