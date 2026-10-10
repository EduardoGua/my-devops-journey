# Examen final de las fases 8 a 10 — Respuestas

> ⛔ Ábrelo **solo** después de haber terminado el examen completo. Si lo lees antes, el examen deja de medir lo que sabes.

Puntúa como lo haría un entrevistador: una respuesta vale todos sus puntos si dice lo esencial **con tus palabras**, y la mitad si lo dice a medias o sin el porqué.

## Parte A

**A1.** Es el archivo en el que Terraform guarda qué recursos reales corresponden a cada bloque de tu código, con sus atributos. Así sabe qué crear, cambiar o borrar en el siguiente `plan`. No va a Git porque contiene datos sensibles (a veces en claro) y porque dos personas con copias distintas se pisarían. Vigía lo guarda en un bucket de S3 con versionado, sin acceso público y con bloqueo nativo (`use_lockfile = true`). El bucket lo crea `infra/estado/`, con `prevent_destroy`. *(Clases 96 y 101)*

**A2.** El `plan` compara tu código con el estado y con lo que hay de verdad en AWS, y dice qué haría: crear (`+`), cambiar en el sitio (`~`), destruir (`-`) o reemplazar (`-/+`). Se lee entero porque una línea cambia mucho las cosas: `-/+` significa que el recurso se **destruye y se crea de nuevo**, con su IP, sus datos y su tiempo de corte; suele pasar al cambiar un atributo que AWS no permite modificar (*forces replacement*). *(Clases 92 y 95)*

**A3.** El siguiente `plan` refresca el estado contra AWS, ve la diferencia (*drift*) y propone volver a lo que dice el código. Las tres salidas: **revertir** (aplicar, lo normal si fue un error), **aceptar** (llevar el cambio al código con un PR y aplicar) o **ignorarlo** (`lifecycle { ignore_changes = […] }`, si ese atributo lo gestiona otro). Mientras no se decida, el siguiente `apply` de cualquiera lo deshará. Ojo: una regla creada como recurso suelto, que Terraform no gestiona, no la ve. *(Clase 99)*

**A4.** Agrupa recursos que van juntos (la red de Vigía: VPC, subredes, tablas de rutas) para reutilizarlos y para que el código de arriba se lea en términos de "una red" y no de veinte recursos. Su interfaz son sus **variables** (lo que recibe) y sus **outputs** (lo que devuelve): quien lo usa no necesita conocer su interior. *(Clase 98)*

**A5.** Hace que Terraform se niegue a destruir ese recurso: cualquier `plan` que lo destruya, también un reemplazo, falla. En Vigía, el bucket del estado: si se borrara, se perdería el registro de toda la infraestructura. *(Clases 95, 96 y 101)*

**A6.**
- **kube-apiserver:** la puerta de todo; cada orden y cada controlador pasan por su API.
- **etcd:** la base de datos con el estado del cluster.
- **kube-scheduler:** elige el nodo de cada pod nuevo.
- **kube-controller-manager:** los bucles de control (Deployments, ReplicaSets, Jobs…) que llevan el estado real hacia el deseado.
- Y, en la nube, el **cloud-controller-manager**: balanceadores y discos.

*(Clase 102)*

**A7.** Un Deployment gestiona réplicas **intercambiables**: nombres al azar, todas iguales, actualizadas poco a poco. Un StatefulSet da a cada réplica una **identidad estable** (`db-0`), un arranque en orden, un DNS propio con un Service *headless* y un disco propio con `volumeClaimTemplates`, que no se borra al escalar ni al borrarlo. En Vigía: la API, un Deployment de 2 réplicas; PostgreSQL, un StatefulSet; el chequeo, un CronJob. *(Clases 104, 109 y 114)*

**A8.** La **readiness** pregunta si el pod puede atender tráfico ahora; si falla, sale de los endpoints del Service y no recibe peticiones, pero no se reinicia. La **liveness** pregunta si el proceso está vivo o colgado; si falla, el kubelet reinicia el contenedor. La liveness nunca debe depender de la base de datos: una caída de PostgreSQL reiniciaría en bucle todas las réplicas. *(Clase 107)*

**A9.** Porque los pods son desechables: cada pod nuevo tiene otra IP. Un Service da un nombre DNS y una IP estables, y reparte el tráfico entre los pods **listos** que cumplen su selector. Tipos: ClusterIP (solo dentro del cluster), NodePort (un puerto en cada nodo), LoadBalancer (un balanceador de la nube) y *headless* (sin IP: el DNS devuelve los pods). *(Clase 105)*

**A10.** No: `data` es base64, que se deshace con `base64 -d`. Lo protegen RBAC (quién puede leerlo), el cifrado de etcd (que kind no tiene y EKS hace por defecto con KMS) y no subirlo nunca a Git. *(Clases 106 y 110)*

**A11.** `requests` es lo que el pod reserva: el *scheduler* solo lo pone en un nodo con eso libre. `limits` es el tope. Al superar el de CPU, el kernel lo **frena**; al superar el de memoria, lo **mata**: `OOMKilled`, código 137, y Kubernetes lo reinicia. *(Clase 107)*

**A12.** Las **métricas**, "¿cuánto?, ¿cuántos?, ¿desde cuándo?": números agregados en el tiempo, para ver tendencias y alertar. Los **logs**, "¿qué pasó exactamente con esta petición?": un evento por línea, con su detalle. Las **trazas**, "¿dónde se fue el tiempo de esta petición?": su recorrido por cada servicio. *(Clase 116)*

**A13.** Un counter solo sube (y vuelve a 0 si el proceso se reinicia); un gauge sube y baja. El valor de un counter es un total acumulado desde que arrancó el proceso: lo útil es su ritmo, y `rate()` lo calcula con todas las muestras del rango y detecta los reinicios para no dar valores negativos. *(Clases 116 y 118)*

**A14.** El **SLI** es lo que mides: la parte de las peticiones sin error. El **SLO**, el objetivo interno: el 99,9 % en 30 días. El **SLA**, una promesa a un cliente con penalizaciones, más laxa. El **presupuesto de errores** es lo que el SLO deja fallar: con el 99,9 %, el 0,1 % de 43 200 minutos, **43 min 12 s** al mes. Si se gasta, se congelan los cambios arriesgados y se trabaja en la fiabilidad. *(Clase 121)*

**A15.** Que avisa de algo que notan los usuarios, solo cuando hay que actuar, con una acción clara, y que está probada. El `for` exige que la condición dure un tiempo antes de avisar: un pico de un minuto no despierta a nadie. Se alerta por **síntomas** (errores, latencia, "no responde") porque son lo que importa; una causa como la CPU alta puede no afectar a nadie, y alertar por ella produce ruido y fatiga. *(Clase 119)*

## Parte B

**B1 (4 puntos, 1 por problema, hasta 4):**
- **Llaves de AWS escritas en el código:** quien lea el repositorio tiene la cuenta. Fuera; credenciales por `aws login`, un perfil o, en el pipeline, OIDC (clases 70, 86 y 99). Y estas, ya publicadas, se desactivan y se rotan.
- **`dynamodb_table`:** el bloqueo con DynamoDB está obsoleto. `use_lockfile = true` (clase 96).
- **El puerto 22 abierto a todo internet:** SSH no hace falta con Session Manager (clase 72); si hiciera falta, a tu IP.
- **Sin versiones fijadas:** ni `required_version` ni `required_providers` con su versión (clase 93). Y el estado, mejor en un bucket con nombre único (`vigia-tfstate-<cuenta>`), con versionado.

**B2 (4 puntos):**
- **El selector no casa con las etiquetas** (`app: api` frente a `app: apy`): el API rechaza el Deployment (`selector does not match template labels`).
- **`vigia:latest`:** `imagePullPolicy` pasa a `Always` (en kind, `ImagePullBackOff`) y no se sabe qué versión corre; una etiqueta fija (clase 114).
- **La contraseña en claro en el manifiesto:** a un Secret, con `secretKeyRef` (clase 106).
- **La liveness en `/status`**, que consulta la base de datos: si PostgreSQL cae, se reinician todas las réplicas. Liveness en `/health`, y además una **readiness**. Y **1 réplica**: sin margen para actualizar ni para que caiga un nodo. Faltan también `resources` y `runAsNonRoot`.

**B3 (4 puntos):**
- **`CPUAlta` alerta por una causa**, no por un síntoma, y sin `for`, sin `severity` y sin `summary`: ruido.
- **`[30s]` con *scrapes* de 15 s:** como mucho dos muestras; el resultado sale a saltos o vacío. Al menos `[1m]`, mejor `[5m]`.
- **`> 0`:** un solo error en cualquier momento dispara una alerta crítica. Una **proporción** de errores sobre el total con un umbral (`> 0.05`), o el consumo del presupuesto (clase 121), y con `for`.
- **`status="500"`** deja fuera el 502 y el 503: `status=~"5.."`. Y le falta `annotations.summary` con un enlace al *runbook*.

**B4 (4 puntos):**
- **Imágenes sin versión fija** (`prom/prometheus` sin etiqueta, `grafana/grafana:latest`): cada arranque puede traer otra versión.
- **La contraseña de Grafana escrita en el compose:** a `.env`, con `${GRAFANA_ADMIN_PASSWORD:?…}` (clase 120).
- **Puertos en todas las interfaces:** `127.0.0.1:9090:9090` y `127.0.0.1:3000:3000`. Prometheus no tiene autenticación.
- **Sin volúmenes ni configuración:** los datos se pierden al recrear los contenedores, Prometheus solo se lee a sí mismo y Grafana no tiene ni fuente de datos ni dashboards aprovisionados.

**B5 (4 puntos):**
- **Cardinalidad:** `usuario` y la URL completa crean una serie por usuario y por URL distinta. Nunca ids ni URLs en etiquetas (clase 117).
- **Falta `status`:** no se pueden calcular los errores. Y no hay histograma: no hay latencia.
- **El nombre:** sin el prefijo del servicio ni la convención (`vigia_http_requests`, que se publica como `_total`).
- **Detalles:** si falta la cabecera, la etiqueta vale `None`; y mide también las peticiones a `/metrics`.

## Parte C

Para cada escenario, 1 punto por cada paso razonable en buen orden (hasta 4) y 1 por una hipótesis acertada.

**C1.**
1. Leer el `plan` entero: qué atributo de `aws_instance.vigia` lleva `# forces replacement`.
2. Si es `ami`: la AMI sale de un `data`, como el parámetro de SSM de Canonical (`…/stable/current/…`) de tu v5, que apunta siempre a la más reciente, y Canonical ha publicado una nueva. Si es `user_data`: algo cambió la plantilla del cloud-init (una variable, la etiqueta de la imagen).
3. `git log -p` de `infra/` y de lo que lea la plantilla.
4. Decidir: fijar la AMI (o `lifecycle { ignore_changes = [ami] }`) si no quieres reemplazos sorpresa, o planificar el reemplazo a propósito.

**Hipótesis:** el PR no tocó la infraestructura, pero el `plan` de Terraform se calcula contra el mundo **de hoy**. Una AMI nueva o un `user_data` que depende de algo externo fuerzan el reemplazo de la instancia. *(Clases 93, 95 y 97)*

**C2.**
1. `kubectl describe pod`: en los eventos, `Liveness probe failed` y `Readiness probe failed`, con el código o el error (`404`, `connection refused`).
2. Comparar la ruta y el puerto de las sondas con lo que sirve la aplicación (`kubectl get deployment api -o yaml`).
3. Ver cuánto tarda en arrancar: `kubectl logs --previous` y la hora de "Application startup complete".
4. Si es un arranque lento, una `startupProbe`; si es la ruta o el puerto, corregirlos en el YAML.

**Hipótesis:** la liveness mata a un contenedor sano porque pregunta a una ruta o un puerto equivocados, o antes de que termine de arrancar (sin `startupProbe` o con un `initialDelaySeconds` corto). *(Clases 107 y 112)*

**C3.**
1. `kubectl describe pod`: el evento `Failed to pull image "vigia:7.0.1"… pull access denied` (o `not found`) contra `docker.io`.
2. `docker exec lab-control-plane crictl images | grep vigia`: ¿está la 7.0.1 en el nodo?
3. Si no: `kind load docker-image vigia:7.0.1 --name lab`.
4. Comprobar que el manifiesto dice exactamente `vigia:7.0.1` y no `latest`, y `kubectl rollout status`.

**Hipótesis:** se construyó la imagen pero no se cargó en kind, y el kubelet la buscó en Docker Hub. *(Clases 112, 114 y 115)*

**C4.**
1. En Prometheus, `up{job="vigia"}` y **Target health**: ¿lo está leyendo?
2. En Prometheus, la consulta exacta del panel: ¿devuelve algo? Si usa una regla de registro (`vigia:…`), ¿existe y está sana (**Status → Rule health**)?
3. En Grafana, **Inspect → Query** del panel: el error, y el `uid` de la fuente de datos (`Data source not found`).
4. El rango de tiempo del dashboard: con `increase(…[1h])` y menos de una hora de datos, o un rango futuro, sale vacío.

**Hipótesis:** el dato existe en `/metrics`, así que el fallo está entre Prometheus y el panel: el *scrape*, una regla de registro con errores o una errata, o la fuente de datos del panel. *(Clases 118, 120 y 121)*

**C5.**
1. **Status → Rule health** y **Alerts**: ¿la regla tiene `health: ok` y se ha evaluado? ¿Qué `for` tiene?
2. Ejecutar su `expr` en Prometheus sobre el rango de ayer: ¿devolvía algo? Una errata en el nombre de la métrica o de una etiqueta devuelve vacío, sin error.
3. Si devolvía algo: Alertmanager. ¿Le llegó (su web, `alertmanager_notifications_total`)? ¿Había un silencio o una inhibición? ¿Falló el receptor (`docker compose logs alertmanager`)?
4. Si no devolvía nada: ¿publicaba la API `vigia_site_up` de ese sitio, o el checker se había parado y la métrica seguía en 1?

**Hipótesis:** una regla que "funciona" pero no se ha probado: una errata que nunca devuelve nada, un `for` más largo que la caída, o un aviso que no salió de Alertmanager. La lección: pruebas unitarias con `promtool` y una prueba de punta a punta (clase 124). *(Clases 119 y 124)*

## Parte D

**D1 (8 puntos):**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: examen
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: examen
  annotations:
    kubernetes.io/change-cause: "podinfo 6.14.1"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.14.1
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
            limits:
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: podinfo
  namespace: examen
spec:
  selector:
    app: podinfo
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: examen
  namespace: examen
spec:
  gatewayClassName: cloud-provider-kind
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: podinfo
  namespace: examen
spec:
  parentRefs:
    - name: examen
  hostnames:
    - examen.lab.test
  rules:
    - backendRefs:
        - name: podinfo
          port: 80
```

```bash
kubectl apply -f examen.yaml
kubectl -n examen rollout status deployment/podinfo
GW=$(kubectl -n examen get gateway examen -o jsonpath='{.status.addresses[0].value}')
curl -s -H "Host: examen.lab.test" "http://$GW/version"
# cambiar la imagen y la anotación a 6.15.0 en examen.yaml
kubectl apply -f examen.yaml && kubectl -n examen rollout status deployment/podinfo
curl -s -H "Host: examen.lab.test" "http://$GW/version"
kubectl -n examen rollout undo deployment/podinfo && kubectl -n examen rollout status deployment/podinfo
curl -s -H "Host: examen.lab.test" "http://$GW/version"
```

| Criterio | Puntos |
|----------|--------|
| Deployment de 2 réplicas con readiness y liveness en las rutas correctas, `requests`, límite de memoria y `runAsNonRoot` | 3 |
| Service con el selector y los puertos correctos, y la entrada para `examen.lab.test` | 2 |
| `curl` desde Ubuntu con la versión, antes y después de actualizar | 1 |
| La actualización con un cambio en el archivo y el `rollout undo`, comprobados | 2 |

(La imagen de podinfo corre como el usuario 100; con `runAsUser: 10001` también funciona, o puedes no fijarlo y dejar solo `runAsNonRoot: true`.)

**D2 (7 puntos):**

```yaml
groups:
  - name: tienda-latencia
    rules:
      - alert: TiendaLenta
        expr: histogram_quantile(0.95, sum by (le) (rate(tienda_request_duration_seconds_bucket{path="/comprar"}[5m]))) > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "El p95 de /comprar pasa de 500 ms"
```

```yaml
rule_files:
  - lenta.yml
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      # 60 compras por minuto, todas entre 0,5 y 1 segundo
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="0.25"}'
        values: '0+0x20'
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="0.5"}'
        values: '0+0x20'
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="1"}'
        values: '0+60x20'
      - series: 'tienda_request_duration_seconds_bucket{path="/comprar", le="+Inf"}'
        values: '0+60x20'
    alert_rule_test:
      - eval_time: 5m
        alertname: TiendaLenta
        exp_alerts: []
      - eval_time: 12m
        alertname: TiendaLenta
        exp_alerts:
          - exp_labels:
              severity: warning
            exp_annotations:
              summary: "El p95 de /comprar pasa de 500 ms"
```

| Criterio | Puntos |
|----------|--------|
| `histogram_quantile(0.95, sum by (le) (rate(…_bucket{path="/comprar"}[5m])))` y `> 0.5` | 3 |
| `for: 10m`, `severity` y `summary` | 1 |
| Una prueba con cubos acumulados coherentes (cada `le` mayor o igual que el anterior) | 2 |
| `promtool test rules` → `SUCCESS` | 1 |

## Parte E

Cada grabación vale 5 puntos:

| Criterio | Puntos |
|----------|--------|
| Estructura clara: de qué va, cómo funciona y el resultado (en E2: situación, tarea, acción y resultado) | 2 |
| Términos técnicos correctos y sin muletillas que tapen las ideas | 2 |
| Dentro del tiempo y sin leer | 1 |

## Si no llegas al 80 %

Apunta en `notas/fase-10/examen-<fecha>.md` qué preguntas fallaste y de qué clase son (está entre paréntesis en cada respuesta). Repasa esas clases con su Rómpelo y su Reto, y repite el examen **una semana después**.
