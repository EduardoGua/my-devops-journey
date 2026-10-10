# Clase 104 — Deployments: escalar, actualizar y volver atrás

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

## Objetivo

- Crear un Deployment y entender la cadena Deployment → ReplicaSet → pods.
- Escalar, y ver cómo se cura solo cuando muere un pod.
- Hacer una actualización gradual (*rolling update*), seguirla con `kubectl rollout` y leer su historial.
- Provocar una actualización rota, comprobar que el servicio no se corta y volver atrás con `kubectl rollout undo`. Es uno de los criterios de salida de la fase.

## Por qué importa

El Deployment es el objeto que más vas a escribir: así corre casi toda aplicación sin estado en Kubernetes, como la API de Vigía (clase 114).

Lo que resuelve es lo que en la fase 7 te costó un script entero (clase 88): actualizar sin cortar el servicio y, si algo sale mal, volver a la versión anterior en segundos. En la clase 89 lo llamaste *rolling deployment*; aquí viene de serie.

## Teoría

### La cadena

```
Deployment web          «quiero 3 réplicas de esta plantilla, y así se actualizan»
   └── ReplicaSet web-5999c4b8      «mantengo 3 pods idénticos»   (uno por cada versión de la plantilla)
          ├── pod web-5999c4b8-ddzt9
          ├── pod web-5999c4b8-rfbcx
          └── pod web-5999c4b8-tg42n
```

- El **ReplicaSet** mantiene un número de pods idénticos. Es el que recreó CoreDNS en la clase 102.
- El **Deployment** gestiona ReplicaSets. Cada vez que cambias la plantilla de sus pods (`spec.template`), crea un ReplicaSet nuevo y traspasa las réplicas del viejo al nuevo, poco a poco.
- Los ReplicaSets viejos se quedan, con 0 réplicas: son el historial para volver atrás.

El sufijo del nombre (`5999c4b8`) es el `pod-template-hash`, un resumen de la plantilla: misma plantilla, mismo sufijo.

Nunca creas ReplicaSets a mano: creas Deployments.

### La actualización gradual

Dos números controlan el ritmo:

| Campo | Por defecto | Significa |
|-------|-------------|-----------|
| `maxSurge` | 25 % | cuántos pods **de más** puede haber durante la actualización (se redondea hacia arriba) |
| `maxUnavailable` | 25 % | cuántos pods **de menos** se toleran (se redondea hacia abajo) |

Con 3 réplicas salen 1 de más y 0 de menos. Kubernetes crea un pod nuevo, espera a que esté **listo**, borra uno viejo, y repite. Si el nuevo nunca llega a estar listo, la actualización se queda ahí y los viejos siguen sirviendo. Lo verás en la práctica.

La otra estrategia, `Recreate`, borra todos los pods viejos antes de crear los nuevos: hay corte. Es para aplicaciones que no pueden convivir en dos versiones a la vez.

### Qué dispara una actualización

Solo los cambios en `spec.template`: la imagen, las variables de entorno, las sondas… Cambiar `replicas` escala, pero no crea un ReplicaSet nuevo ni una revisión.

### Imperativo contra declarativo, otra vez

`kubectl scale` y `kubectl set image` cambian el cluster, pero no tu archivo. Al siguiente `kubectl apply`, tu archivo gana. Es el *drift* de la clase 99 con otro nombre, y `kubectl diff -f` lo muestra igual que `terraform plan`.

## Práctica guiada

La aplicación de las próximas clases es **podinfo**, una pequeña web hecha para practicar Kubernetes. Responde en JSON con su versión y el nombre del pod que contesta. Su imagen está en el registro de GitHub (`ghcr.io`), sin los límites de descarga de Docker Hub.

```bash
mkdir -p ~/my-devops-journey/labs/clase-104 && cd ~/my-devops-journey/labs/clase-104
```

### 1. Tu primer Deployment (15 min)

```bash
kubectl create deployment web --image=ghcr.io/stefanprodan/podinfo:6.14.1 \
  --replicas=3 --port=9898 --dry-run=client -o yaml > web.yaml
```

Ábrelo y déjalo así: quita `strategy: {}`, `resources: {}` y `status: {}`, y añade la anotación con el motivo del cambio:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
  annotations:
    kubernetes.io/change-cause: "podinfo 6.14.1: primera versión"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.14.1
          ports:
            - containerPort: 9898
```

Fíjate en las dos etiquetas `app: web`: el **selector** dice qué pods son de este Deployment, y la **plantilla** se los pone. Tienen que coincidir.

```bash
kubectl apply -f web.yaml
kubectl rollout status deployment/web
kubectl get deployments,replicasets,pods
```

🔮 **Predice:** ¿qué sufijo comparten el ReplicaSet y los tres pods? ¿Quién es el dueño de cada pod?

```bash
kubectl get pods -l app=web -o jsonpath='{range .items[*]}{.metadata.name} → {.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}{end}'
```

Cada pod lleva una `ownerReference` hacia su ReplicaSet, y el ReplicaSet otra hacia el Deployment. Así funciona el borrado en cascada: borrar el Deployment borra todo lo que cuelga de él.

### 2. Se cura solo (10 min)

```bash
kubectl delete pod <uno-de-los-tres>
kubectl get pods -l app=web
```

En segundos vuelve a haber tres. ¿Y qué versión sirven? podinfo trae `curl` dentro, y `kubectl exec deploy/web` entra en uno de sus pods:

```bash
kubectl exec deploy/web -- curl -s localhost:9898/version
```

### 3. Escalar, y el drift (10 min)

```bash
kubectl scale deployment web --replicas=5
kubectl get deployment web
kubectl diff -f web.yaml
```

🔮 **Predice:** ¿qué línea marcará el `diff`?

```
-  replicas: 5
+  replicas: 3
```

El cluster tiene 5 y tu archivo dice 3. El `-` es lo que hay y el `+`, lo que dejaría tu archivo. Decide quién manda:

```bash
kubectl apply -f web.yaml
kubectl get deployment web
```

Tu archivo. Si de verdad quisieras 5, se cambia el YAML.

### 4. Una actualización gradual (20 min)

En una **segunda terminal**, deja mirando los ReplicaSets:

```bash
kubectl get replicasets -l app=web -w
```

En la primera, cambia la imagen a `6.15.0` y la anotación a `"podinfo 6.15.0"` en `web.yaml`, y aplica:

```bash
kubectl apply -f web.yaml
kubectl rollout status deployment/web
```

En la segunda terminal verás aparecer un ReplicaSet nuevo que sube de 0 a 3 mientras el viejo baja de 3 a 0, de uno en uno:

```
web-5999c4b8     3    3    3    …
web-775c4dfd56   1    1    0    …
web-775c4dfd56   1    1    1    …
web-5999c4b8     2    3    3    …
…
web-5999c4b8     0    0    0    …
```

```bash
kubectl exec deploy/web -- curl -s localhost:9898/version
kubectl rollout history deployment/web
```

```
REVISION  CHANGE-CAUSE
1         podinfo 6.14.1: primera versión
2         podinfo 6.15.0
```

El `CHANGE-CAUSE` sale de tu anotación. Sin ella, el historial es una lista de números.

### 5. Una actualización rota y la vuelta atrás (20 min)

La versión `6.99.0` no existe. Cámbiala en `web.yaml` (y la anotación), aplica y espera, como mucho, 45 segundos:

```bash
kubectl apply -f web.yaml
kubectl rollout status deployment/web --timeout=45s
```

```
Waiting for deployment "web" rollout to finish: 1 out of 3 new replicas have been updated...
error: timed out waiting for the condition
```

🔮 **Predice:** ¿cuántos pods de la versión 6.15.0 siguen sirviendo? ¿Está caído el servicio?

```bash
kubectl get pods -l app=web
```

```
NAME                   READY   STATUS             RESTARTS   AGE
web-5d5b46768d-htqqj   0/1     ImagePullBackOff   0          45s
web-775c4dfd56-9h8qm   1/1     Running            0          52s
web-775c4dfd56-gjpnn   1/1     Running            0          53s
web-775c4dfd56-sl96b   1/1     Running            0          59s
```

Los tres viejos siguen en pie: `maxUnavailable` es 0 y el nuevo nunca llegó a estar listo. El servicio no se ha cortado; solo está atascado. Mira por qué:

```bash
kubectl describe pod web-5d5b46768d-htqqj | tail -5
```

`Failed to pull image "ghcr.io/stefanprodan/podinfo:6.99.0" … not found`. Vuelve atrás:

```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl rollout history deployment/web
```

Fíjate en dos cosas:
- **El aviso de `undo`:** `resource deployments/web was previously managed with 'kubectl apply'…`. El cluster volvió a la 6.15.0, pero tu `web.yaml` sigue diciendo `6.99.0`. Compruébalo con `kubectl diff -f web.yaml`. El arreglo de verdad es corregir el archivo y aplicarlo: `undo` es el botón de emergencia, y Git debe quedar igual que el cluster.
- **El historial se renumera:** la revisión 2 pasa a ser la 4. Volver atrás crea una revisión nueva con la plantilla vieja.

Corrige `web.yaml` a `6.15.0`, aplica y comprueba que `kubectl diff -f web.yaml` ya no imprime nada.

## Rómpelo

1. **Cambiar el selector.** En una copia de `web.yaml`, cambia todas las `app: web` por `app: web2` y aplícala:

   ```
   The Deployment "web" is invalid: spec.selector: Invalid value: {"matchLabels":{"app":"web2"}}: field is immutable
   ```

   El selector de un Deployment no se puede cambiar: dejaría huérfanos a sus pods. Si de verdad hace falta, se crea un Deployment nuevo.
2. **Borra el ReplicaSet activo**: `kubectl delete replicaset <el que tiene 3>`. ¿Qué pasa? Mira `kubectl get rs,pods -l app=web`: el Deployment crea otro **con el mismo nombre**, porque la plantilla no ha cambiado y el sufijo es su resumen. Durante unos segundos hubo pods de menos: ¿qué crees que vería un usuario?
3. **El cambio a mano que se pierde.** `kubectl set image deployment/web podinfo=ghcr.io/stefanprodan/podinfo:6.14.1`, mira `kubectl rollout history deployment/web`, y después `kubectl apply -f web.yaml`. ¿Qué versión queda? ¿Cuántas revisiones y cuántos ReplicaSets nuevos aparecieron? ¿Qué dice el `CHANGE-CAUSE` de la revisión que creó `set image`?

## Reto

1. **Otro ritmo.** Añade al `spec` del Deployment:

   ```yaml
     strategy:
       type: RollingUpdate
       rollingUpdate:
         maxSurge: 0
         maxUnavailable: 1
   ```

   Vuelve a pasar de 6.15.0 a 6.14.1 mirando los ReplicaSets. ¿Qué cambia en el orden? ¿Cuándo usarías esto en lugar de lo de por defecto? (Pista: piensa en un cluster sin memoria libre.)
2. `kubectl rollout restart deployment/web` no cambia la imagen, pero crea pods nuevos. ¿Qué cambió en la plantilla para que eso ocurra? (Pista: `kubectl get deployment web -o jsonpath='{.spec.template.metadata.annotations}'`.) ¿Para qué te serviría en la clase 106?
3. `kubectl rollout undo deployment/web --to-revision=1`. ¿Qué versión queda?

Al terminar, deja el Deployment `web` en la 6.15.0: la clase 105 lo usa.

## Cierre

En `notas/fase-9/clase-104.md`:

1. Dibuja la cadena Deployment → ReplicaSet → pods y explica qué hace cada eslabón.
2. Con 3 réplicas y los valores por defecto, cuenta paso a paso una actualización gradual.
3. Una actualización se queda atascada con `ImagePullBackOff`. ¿Está caído el servicio? ¿Qué comandos usas para entenderlo y para arreglarlo, y qué haces después con Git?
4. **Repaso (clase 103, sin mirar):** ¿qué comparten dos contenedores del mismo pod?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. El Deployment guarda la plantilla y la estrategia; por cada versión de la plantilla tiene un ReplicaSet. El ReplicaSet mantiene N pods idénticos. Los pods ejecutan los contenedores. Cada uno tiene una `ownerReference` hacia el de arriba.
2. `maxSurge` = 1 (25 % de 3, hacia arriba) y `maxUnavailable` = 0 (hacia abajo). El Deployment crea un ReplicaSet nuevo con 1 pod (hay 4), espera a que esté listo, baja el viejo a 2, sube el nuevo a 2… hasta 3 nuevos y 0 viejos. Nunca hay menos de 3 pods listos.
3. No: los pods viejos siguen sirviendo, porque el nuevo nunca se puso listo y `maxUnavailable` es 0. Para entenderlo: `kubectl rollout status`, `kubectl get pods` y `kubectl describe pod` del pod nuevo (el evento `Failed to pull image`). Para arreglarlo, `kubectl rollout undo`. Después, corregir el YAML en Git y aplicarlo, hasta que `kubectl diff` salga vacío.
4. La red (una sola IP: se hablan por `localhost`) y los volúmenes del pod.

**Rómpelo 2:** el ReplicaSet nuevo se llama igual porque el sufijo es el resumen de la plantilla, que no cambió. Los pods viejos se borraron en cascada mientras arrancaban los nuevos: durante unos segundos hubo menos de 3 listos, y algunas peticiones podrían fallar. Borrar a mano lo que gestiona un controlador no es una forma de "reiniciar".

**Rómpelo 3:** queda la 6.15.0, porque gana el archivo. Aparecieron dos números de revisión nuevos, uno con `set image` y otro con `apply`, pero ningún ReplicaSet nuevo: cada plantilla ya tenía el suyo, y se reutiliza. Y la revisión de `set image` (la 6.14.1) dice `CHANGE-CAUSE: podinfo 6.15.0`, porque `set image` no tocó la anotación. El historial solo es tan fiable como tus anotaciones: otro motivo para cambiar siempre el archivo.

**Reto 1:** con `maxSurge: 0` y `maxUnavailable: 1`, primero se borra un pod viejo y después se crea el nuevo: nunca hay pods de más. Sirve cuando el cluster no tiene sitio para un pod extra, a cambio de tener una réplica menos durante la actualización.

**Reto 2:** `kubectl rollout restart` añade a la plantilla la anotación `kubectl.kubernetes.io/restartedAt` con la hora. La plantilla cambia, así que hay ReplicaSet nuevo y pods nuevos con la misma imagen. En la clase 106 te servirá para que los pods relean un ConfigMap que solo se carga al arrancar.

**Reto 3:** la 6.14.1, la de la revisión 1.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| rolling update | actualización gradual |
| rollout / rollback | despliegue de una versión / vuelta atrás |
| surge / unavailable | pods de más / pods de menos durante la actualización |
| change cause | motivo del cambio |
| self-healing | autocuración |

🎙️ *"When a rollout got stuck on ImagePullBackOff, the old pods kept serving because maxUnavailable was zero. I rolled back with kubectl rollout undo, then fixed the manifest in Git so the cluster and the repo matched again, and kubectl diff came back empty."*

## Siguiente

[Clase 105 — Services y DNS del cluster](clase-105-services-y-dns.md)
