# Clase 107 — Sondas, requests y limits

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

> 💡 **La idea de hoy:** sin sondas, Kubernetes solo sabe si el **proceso** está vivo. La **readiness** pregunta si el pod puede atender tráfico (si falla, sale del Service sin reiniciarse); la **liveness**, si se ha colgado (si falla, se reinicia); la **startup**, si ya terminó de arrancar. Y con **requests** y **limits** cada pod reserva lo que necesita y no se come el nodo: pasarse de CPU lo frena, pasarse de memoria lo mata.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La actualización gradual, que espera a que cada pod nuevo esté listo (clase 104).
> - Los EndpointSlices, la `sonda` y el bucle que reparte peticiones (clase 105).
> - Los *cgroups* que limitan un contenedor (clase 56); `OOMKilled` y el código 137 (clase 63).
> - El `/health` de Vigía, que no toca PostgreSQL (clase 53).

> 🔤 **Palabras nuevas de hoy:**
> - **sonda** (*probe*): una comprobación periódica que hace el kubelet.
> - **readiness / liveness / startup**: ¿puede atender tráfico? / ¿está colgado? / ¿ya arrancó?
> - **`failureThreshold`**: cuántos fallos seguidos hacen falta para dar la sonda por fallida.
> - **requests**: lo que un pod reserva; el *scheduler* lo usa para elegir nodo.
> - **limits**: el tope; de CPU frena (*throttling*), de memoria mata (`OOMKilled`).
> - **milinúcleos** (`100m`) y **`Mi`**: las unidades de CPU y de memoria.
> - **QoS** (`Guaranteed`, `Burstable`, `BestEffort`): a quién echa primero el nodo si se queda sin memoria.
> - **metrics-server** y **`kubectl top`**: el consumo real de nodos y pods.

## Objetivo

- Explicar la diferencia entre una sonda **liveness**, una **readiness** y una **startup**, y qué hace Kubernetes cuando falla cada una. Es un criterio de salida de la fase.
- Ver en vivo cómo un pod que no está listo sale del Service sin reiniciarse, y cómo una sonda liveness mal hecha reinicia un pod sano.
- Poner `requests` y `limits` de CPU y memoria, y reconocer lo que pasa al superarlos: CPU frenada y `OOMKilled`.
- Instalar metrics-server para ver el consumo con `kubectl top`.

## Por qué importa

Sin sondas, Kubernetes solo sabe si el **proceso** está vivo, no si la aplicación funciona. Mandará tráfico a un pod que aún está arrancando, y dejará en pie uno que se ha colgado. Con sondas, la actualización gradual de la clase 104 espera a que cada pod nuevo esté listo de verdad, y un pod colgado se reinicia solo.

Sin `requests` y `limits`, un solo pod con una fuga de memoria se come el nodo entero y tumba a sus vecinos. Es la pregunta de entrevista más típica de Kubernetes, junto a la de las sondas.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min), con las sondas; el segundo, las **piezas 4 y 5**, con los recursos, el Rómpelo, el reto y el cierre.

Necesitas `web`, su Service y la `sonda` de las clases 104 a 106:

```bash
mkdir -p ~/my-devops-journey/labs/clase-107 && cd ~/my-devops-journey/labs/clase-107
cp ~/my-devops-journey/labs/clase-104/web.yaml .
```

## Las piezas

### Pieza 1 — Tres sondas, tres preguntas

| Sonda | La pregunta | Si falla |
|-------|-------------|----------|
| **readiness** | ¿puedo atender tráfico **ahora**? | el pod sale de los endpoints del Service: no recibe tráfico, pero **no se reinicia**. Cuando vuelve a pasar, vuelve a entrar |
| **liveness** | ¿estoy vivo, o colgado sin remedio? | el kubelet **reinicia** el contenedor |
| **startup** | ¿he terminado de arrancar? | hasta que pasa, las otras dos no se ejecutan; si no pasa a tiempo, se reinicia |

Cómo se comprueba:

```yaml
readinessProbe:
  httpGet:            # o tcpSocket, exec (un comando) o grpc
    path: /readyz
    port: http        # el nombre del puerto del contenedor
  periodSeconds: 5    # cada cuánto
  timeoutSeconds: 1   # cuánto espera la respuesta (por defecto)
  failureThreshold: 3 # cuántos fallos seguidos para darla por fallida (por defecto)
```

Un `httpGet` pasa con cualquier código entre 200 y 399. Con estos valores, un pod tarda unos 15 segundos (3 fallos × 5 s) en salir del Service.

**Pruébalo.** podinfo tiene dos rutas pensadas para sondas: `/readyz` y `/healthz`. En tu copia de `web.yaml`, deja el contenedor así (con el `env` de la 106, si lo añadiste). Los `resources` los entenderás en la pieza 4:

```yaml
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 128Mi
```

```bash
kubectl apply -f web.yaml
kubectl rollout status deployment/web
kubectl describe pod -l app=web | grep -E "Liveness|Readiness"
```

👀 **Qué deberías ver:** una actualización gradual (la plantilla cambió) y, por cada pod, dos líneas como `Liveness: http-get http://:http/healthz delay=5s timeout=1s period=10s #success=1 #failure=3`.

✋ **Sin mirar:** si falla la readiness, ¿se reinicia el pod?

<details>
<summary>Comprueba</summary>

No: sale de los endpoints del Service y deja de recibir tráfico, pero sigue corriendo. Vuelve a entrar en cuanto la sonda pasa.
</details>

**En resumen:** readiness decide el tráfico; liveness, los reinicios; startup, cuándo empiezan las otras dos.

### Pieza 2 — Un pod que deja de estar listo

podinfo permite apagar su readiness a propósito, con un `POST` a `/readyz/disable`. Así se ve lo que pasa con un pod que, por ejemplo, está recargando una caché: sigue vivo, pero no debe recibir peticiones.

**Pruébalo.** Elige un pod:

```bash
P=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}'); echo "$P"
kubectl exec "$P" -- curl -s -X POST localhost:9898/readyz/disable
```

🔮 **Predice:** a los 20 segundos, ¿qué dirán las columnas `READY` y `RESTARTS` de ese pod? ¿Le seguirá llegando tráfico?

```bash
kubectl get pods -l app=web
kubectl get endpointslices -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name} ready={.conditions.ready}{"\n"}{end}'
for i in $(seq 1 6); do kubectl exec sonda -- wget -qO- http://web/ | grep hostname; done | sort | uniq -c
kubectl describe pod "$P" | grep "Readiness probe failed" | tail -1
```

👀 **Qué deberías ver:**
- `READY 0/1` y `RESTARTS 0`: está vivo, pero fuera de servicio.
- En el EndpointSlice, `ready=false`, y en el bucle **no** aparece su nombre: el Service ya no le manda nada.
- El evento lo explica: `Readiness probe failed: HTTP probe failed with statuscode: 503`.

Devuélvelo:

```bash
kubectl exec "$P" -- curl -s -X POST localhost:9898/readyz/enable
kubectl get pods -l app=web
```

En unos segundos vuelve a `READY 1/1`.

✋ **Sin mirar:** con `periodSeconds: 5` y `failureThreshold: 3`, ¿cuánto tarda un pod en salir del Service?

<details>
<summary>Comprueba</summary>

Unos 15 segundos: tres fallos seguidos, uno cada 5.
</details>

**En resumen:** un pod que no está listo sale del Service sin reiniciarse, y vuelve solo.

### Pieza 3 — Una liveness mal escrita

Una aplicación que arranca despacio necesita `startupProbe` (o un `initialDelaySeconds` generoso en la liveness): si no, la liveness la mata antes de que termine de arrancar.

**La trampa clásica:** una liveness que comprueba la base de datos. Si la base de datos cae, **todas** las réplicas fallan la liveness y se reinician en bucle, y eso no arregla nada: solo empeora el incidente. La liveness pregunta por el propio proceso; las dependencias, como mucho, en la readiness. Por eso el `/health` de Vigía no toca PostgreSQL.

**Pruébalo.** En `web.yaml`, cambia el `path` de la liveness a `/no-existe` y aplica:

```bash
kubectl apply -f web.yaml
kubectl get pods -l app=web -w
```

🔮 **Predice:** la aplicación está perfecta. ¿Qué le pasará?

👀 **Qué deberías ver:** cada 30 segundos más o menos (3 fallos × 10 s), `RESTARTS` sube en todos los pods. Sal con `Ctrl+C`:

```bash
kubectl describe pod -l app=web | grep -E "Liveness probe failed|failed liveness" | head -2
```

```
Warning  Unhealthy  …  Liveness probe failed: HTTP probe failed with statuscode: 404
Normal   Killing    …  Container podinfo failed liveness probe, will be restarted
```

Una liveness mal hecha reinicia pods sanos para siempre. Y si los reinicios se acumulan, aparece `CrashLoopBackOff` (clase 112), aunque la aplicación no tenga ningún fallo. Devuelve `/healthz` y aplica.

✋ **Sin mirar:** ¿por qué la liveness de la API de Vigía no debe comprobar PostgreSQL?

<details>
<summary>Comprueba</summary>

Porque si cae PostgreSQL, todas las réplicas fallarían a la vez y se reiniciarían en bucle, sin arreglar nada. La liveness solo pregunta por el propio proceso.
</details>

**En resumen:** una liveness pregunta por el proceso, nunca por sus dependencias.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Comprueba que `web` está otra vez con `/healthz` y `RESTARTS` quieto, y apaga el cluster con `docker stop lab-control-plane cloud-provider-kind`.

### Pieza 4 — requests y limits

| | Para qué | Si se supera |
|-|----------|--------------|
| `requests` | lo que el pod **reserva**. El *scheduler* solo lo pone en un nodo con esa cantidad libre | no es un tope: puede usar más si sobra |
| `limits` de CPU | el tope de CPU | el kernel lo **frena** (*throttling*): va más lento, pero no muere |
| `limits` de memoria | el tope de memoria | el kernel lo **mata**: `OOMKilled`, código 137 (clase 63) |

Las unidades:
- **CPU**, en milinúcleos: `100m` es una décima de núcleo, y `1` es un núcleo entero.
- **Memoria**, en bytes con sufijo: `128Mi` son 128 × 1024 × 1024. Ojo, `128M` es otra cosa (128 × 1000 × 1000).

Debajo están los *cgroups* de la clase 56.

Una receta sensata para empezar: `requests` de CPU y memoria cerca del consumo normal, `limit` de memoria con margen, y sin límite de CPU o uno holgado. Un límite de CPU muy justo frena la aplicación en los picos, aunque el nodo esté libre. Es lo que tiene `web` desde la pieza 1.

**Pruébalo.** `kubectl top` necesita metrics-server, que recoge el consumo de cada kubelet:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deployment/metrics-server
```

El *patch* hace falta solo en kind: los certificados de su kubelet no están firmados para la IP del nodo, y metrics-server los rechazaría. En un cluster real no se desactiva esa comprobación.

Espera un minuto a que reúna datos:

```bash
kubectl top nodes
kubectl top pods
kubectl describe node lab-control-plane | sed -n '/Allocated resources/,/Events/p'
```

👀 **Qué deberías ver:** el nodo con su CPU en milinúcleos y su memoria en `Mi`, con porcentajes; cada pod de `web` con unos pocos milinúcleos y unos 15–20 `Mi`, muy por debajo de sus 64 `Mi` reservados. En `Allocated resources`, la suma de los `requests` y `limits` de todos los pods del nodo.

✋ **Sin mirar:** un pod con `requests.memory: 64Mi` usa 100 `Mi` y su `limit` es 128 `Mi`. ¿Qué le pasa?

<details>
<summary>Comprueba</summary>

Nada: `requests` no es un tope, solo una reserva. Mientras no pase de 128 `Mi`, sigue vivo.
</details>

**En resumen:** `requests` reserva y decide el nodo; `limits` pone el tope.

### Pieza 5 — Pasarse de memoria y de CPU

Con los `requests` y `limits`, Kubernetes da a cada pod una **clase de calidad de servicio** (QoS), que decide a quién echa primero si el nodo se queda sin memoria:

| QoS | Cuándo | Se le echa |
|-----|--------|------------|
| `Guaranteed` | `requests` = `limits`, de CPU y memoria, en todos los contenedores | el último |
| `Burstable` | algún `request` o `limit`, sin cumplir lo anterior | en medio |
| `BestEffort` | ni `requests` ni `limits` | el primero |

**Pruébalo.** `memoria.yaml` reserva 200 MiB con un límite de 128 Mi:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memoria
spec:
  containers:
    - name: app
      image: python:3.14-slim
      command: ["python", "-c", "x = bytearray(200 * 1024 * 1024); print('reservé 200 MiB', flush=True); import time; time.sleep(3600)"]
      resources:
        requests:
          memory: 64Mi
        limits:
          memory: 128Mi
```

```bash
kubectl apply -f memoria.yaml
kubectl get pod memoria -w
```

🔮 **Predice:** ¿qué estado verás? ¿Llegará a imprimir `reservé 200 MiB`?

👀 **Qué deberías ver:** `OOMKilled`, con `RESTARTS` subiendo, y después `CrashLoopBackOff`. Sal con `Ctrl+C`:

```bash
kubectl describe pod memoria | grep -A4 "Last State"
kubectl logs memoria
```

```
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
```

El log está vacío: murió dentro de `bytearray`, antes del `print`, y SIGKILL no avisa (clase 63).

Ahora la CPU. `cpu.yaml` es un bucle infinito con un límite de 200m:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "while true; do :; done"]
      resources:
        requests:
          cpu: 100m
          memory: 16Mi
        limits:
          cpu: 200m
          memory: 16Mi
```

```bash
kubectl apply -f cpu.yaml
```

Espera un minuto y:

```bash
kubectl top pod cpu
kubectl get pod cpu -o jsonpath='{.status.qosClass}{"\n"}'
```

👀 **Qué deberías ver:** unos `200m`, ni uno más: querría un núcleo entero, y el kernel lo frena. No muere: la CPU se frena, la memoria mata. Su clase es `Burstable`: tiene `requests` y `limits`, pero la CPU no coincide.

✋ **Sin mirar:** ¿qué clase de QoS tiene un pod sin `requests` ni `limits`, y qué le pasa si el nodo se queda sin memoria?

<details>
<summary>Comprueba</summary>

`BestEffort`: es el primero al que echa el nodo.
</details>

**En resumen:** la CPU se frena, la memoria mata; la QoS decide a quién se echa primero.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `readinessProbe: {httpGet: {path, port}, periodSeconds}` | ¿puede atender tráfico? |
| `livenessProbe: {…, initialDelaySeconds, failureThreshold}` | ¿está colgado? |
| `startupProbe: {…, periodSeconds: 2, failureThreshold: 30}` | dar hasta 60 s para arrancar |
| `resources: {requests: {cpu: 50m, memory: 64Mi}, limits: {memory: 128Mi}}` | reservar y poner topes |
| `kubectl describe pod … \| grep -E "Liveness\|Readiness"` | las sondas de un pod |
| `kubectl top nodes` · `kubectl top pods` | el consumo real |
| `kubectl get pod … -o jsonpath='{.status.qosClass}'` | su clase de QoS |
| `kubectl describe pod … \| grep -A4 "Last State"` | por qué murió la última vez |
| `kubectl describe node … \| sed -n '/Allocated resources/,/Events/p'` | lo reservado en el nodo |

## Rómpelo

**1. Una actualización sin readiness.** podinfo arranca en menos de un segundo; las aplicaciones reales suelen tardar más. Simula una lenta: copia `web.yaml` como `web-lento.yaml` y, en el contenedor, añade debajo de `image:`

```yaml
          command: ["sh", "-c", "sleep 10; exec ./podinfo"]
```

sube el `initialDelaySeconds` de la liveness a `20` y **quita** la `readinessProbe`. Aplica y espera a que termine (`kubectl rollout status deployment/web`).

En una segunda terminal, deja contando peticiones fallidas:

```bash
for i in $(seq 1 200); do kubectl exec sonda -- wget -qO- -T 1 http://web/version >/dev/null 2>&1 || echo FALLO; sleep 0.2; done | grep -c FALLO
```

En la primera, cambia la versión a la 6.14.1 en `web-lento.yaml` y aplica. Cuando el bucle termine (algo más de un minuto), apunta el número. Después devuelve la `readinessProbe` a `web-lento.yaml`, aplica, espera, y repite: bucle en una terminal, y vuelta a la 6.15.0 en la otra.

En mis pruebas salieron **28 fallos de 200** sin readiness, y **0** con ella. Sin readiness, Kubernetes da por listo cada pod nuevo en cuanto arranca su contenedor, retira uno viejo y manda tráfico a uno que aún no escucha. Termina con `kubectl apply -f web.yaml`.

**2. Una petición imposible.** Crea un pod `enorme` con `requests.memory: 64Gi`. ¿En qué estado se queda y qué dice `describe`? Lo diagnosticarás a fondo en la clase 112.

**3. Un arranque más largo que la paciencia de la liveness.** `lento.yaml` tarda 40 segundos en arrancar y solo tiene liveness:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lento
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lento
  template:
    metadata:
      labels:
        app: lento
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          command: ["sh", "-c", "echo arrancando despacio; sleep 40; exec ./podinfo"]
          ports:
            - name: http
              containerPort: 9898
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
```

Aplícalo y míralo dos minutos con `kubectl get pods -l app=lento -w`. 🔮 **Predice:** ¿llegará a arrancar alguna vez?

Después, añade una `startupProbe` antes de la liveness y aplica otra vez:

```yaml
          startupProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 2
            failureThreshold: 30
```

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Haz `Guaranteed` el pod `cpu`: ¿qué tienes que cambiar en sus `resources`? Compruébalo con `qosClass`.

> 🧩 **Ejemplo resuelto:** la pieza 5: `cpu` era `Burstable` porque su `request` de CPU (100m) no coincidía con su `limit` (200m).

**Ahora tú, con huecos:**
```yaml
      resources:
        requests:
          cpu: ____
          memory: 16Mi
        limits:
          cpu: ____
          memory: 16Mi
```
Completa: «Para aplicarlo tengo que ____, porque `kubectl apply` ____».

<details>
<summary>Pista</summary>

Prueba primero `kubectl apply -f cpu.yaml` y lee el error: casi todo el `spec` de un pod es inmutable (clase 103). Con un Deployment no pasaría: ¿por qué?
</details>

**2.** En `lento`, ¿cuánto tiempo como máximo le da la `startupProbe` para arrancar? ¿Qué pasaría con `failureThreshold: 10`? Calcúlalo y compruébalo.

> 🧩 **Ejemplo resuelto:** la pieza 1: con `periodSeconds: 5` y `failureThreshold: 3`, un pod tarda unos 15 segundos en salir del Service.

**Ahora tú, con huecos:** «Con `periodSeconds: 2` y `failureThreshold: 30`: ____ × ____ = ____ segundos. Con `failureThreshold: 10`, ____ segundos, que es ____ que los 40 que tarda, así que…».

<details>
<summary>Pista</summary>

Mientras la `startupProbe` no pasa, ni la liveness ni la readiness se ejecutan. Si se agota, el kubelet reinicia el contenedor.
</details>

**3.** Para Vigía (clase 114): ¿qué sondas usarías para la API, con qué ruta, y por qué **no** comprobarías PostgreSQL en la liveness?

> 🧩 **Ejemplo resuelto:** la pieza 1: podinfo usa `/readyz` para la readiness y `/healthz` para la liveness.

**Ahora tú, con huecos:** «Readiness: `httpGet` a ____. Liveness: `httpGet` a ____, que responde si… y no toca ____. No compruebo PostgreSQL en la liveness porque, si cae, ____».

<details>
<summary>Pista</summary>

Mira qué rutas tiene la API de Vigía desde la clase 53.
</details>

## Destruir al terminar

```bash
kubectl delete pod memoria cpu enorme --ignore-not-found
kubectl delete deployment lento
```

Deja `web` (con sus sondas correctas), la `sonda` y metrics-server.

## Cierre

En `notas/fase-9/clase-107.md`:

1. Explica la diferencia entre una sonda liveness y una readiness como en una entrevista: qué pregunta cada una y qué hace Kubernetes cuando falla. *(3 líneas. Empieza así: «La readiness pregunta si el pod puede atender tráfico ahora; si falla,… La liveness…»)*
2. ¿Por qué una liveness que comprueba la base de datos es mala idea? *(2 líneas. Empieza así: «Porque cuando cae la base de datos fallan todas las réplicas a la vez…»)*
3. ¿Qué pasa cuando un contenedor supera su límite de CPU? ¿Y el de memoria? *(2 líneas, una por recurso.)*
4. **Repaso (clase 106, sin mirar):** cambias un ConfigMap que un pod usa como variable de entorno. ¿Cuándo ve el pod el valor nuevo? *(1 línea.)*

Después, escríbeme `examíname clase-107`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. La **readiness** pregunta si el pod puede atender tráfico ahora. Si falla, sale de los endpoints del Service y deja de recibir peticiones, pero no se reinicia, y vuelve en cuanto pasa. La **liveness** pregunta si el proceso sigue vivo o se ha colgado. Si falla, el kubelet reinicia el contenedor. En la práctica: la readiness protege a los usuarios de un pod que no está listo (arrancando, sobrecargado), y la liveness recupera un pod atascado sin remedio.
2. Porque cuando cae la base de datos fallan **todas** las réplicas a la vez, y el kubelet las reinicia en bucle. Reiniciar la API no arregla la base de datos, y además corta lo que sí funcionaba. La liveness debe preguntar solo por el propio proceso.
3. La CPU se **frena** (*throttling*): va más lenta, pero sigue viva. La memoria **mata**: el kernel lo termina con SIGKILL, `OOMKilled` y código 137, y Kubernetes lo reinicia.
4. Nunca, mientras siga vivo ese contenedor: hay que reiniciarlo, por ejemplo con `kubectl rollout restart`.

**Rómpelo 2:** `Pending` para siempre. El evento dice `0/1 nodes are available: 1 Insufficient memory`: ningún nodo tiene 64 Gi libres para reservar.

**Rómpelo 3:** nunca arranca. La liveness empieza a los 5 segundos, falla tres veces seguidas (`connection refused`: aún no escucha nadie) y el kubelet mata el contenedor hacia los 25–35 segundos, antes de los 40 que necesita. Vuelve a empezar, y `RESTARTS` sube sin fin. Con la `startupProbe`, la liveness no se ejecuta hasta que la aplicación responde, y el pod arranca con `RESTARTS 0`.

**Reto 1:** `requests` igual a `limits`, de CPU y de memoria, por ejemplo `cpu: 200m` en los dos. La clase pasa a `Guaranteed`. Para aplicarlo tienes que borrar el pod y crearlo de nuevo: `kubectl apply` lo rechaza (`pod updates may not change fields…`). Kubernetes permite cambiar los recursos de un pod en marcha con el subrecurso `resize`, pero nunca su clase de QoS (`Pod QOS Class may not change as a result of resizing`). Con un Deployment no hay problema: cambias la plantilla y crea pods nuevos.

**Reto 2:** 30 × 2 = 60 segundos; mientras la startup no pasa, ni la liveness ni la readiness se ejecutan. Con `failureThreshold: 10` serían 20 segundos, menos de los 40 que tarda: el kubelet lo reiniciaría en bucle, igual que sin `startupProbe`.

**Reto 3:** readiness y liveness por HTTP contra `/health`, que responde si el proceso está vivo y no toca PostgreSQL. Si la liveness comprobara la base de datos, una caída de PostgreSQL reiniciaría en bucle las dos réplicas de la API sin arreglar nada.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| liveness / readiness / startup probe | sonda de vida / de disponibilidad / de arranque |
| requests / limits | reservas / topes de recursos |
| CPU throttling | CPU frenada por el límite |
| OOMKilled | matado por falta de memoria |
| quality of service (QoS) class | clase de calidad de servicio |

🎙️ *"Readiness asks whether the pod can take traffic right now: if it fails, the pod leaves the Service endpoints but keeps running. Liveness asks whether the process is stuck: if it fails, the kubelet restarts the container. I never check the database in a liveness probe, or a database outage turns into a restart storm."*

## Siguiente

[Clase 108 — Jobs y CronJobs](clase-108-jobs-y-cronjobs.md)
