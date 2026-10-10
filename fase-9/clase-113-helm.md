# Clase 113 — Helm

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Kubernetes para operar

## Objetivo

- Explicar qué problema resuelve Helm: un *chart* (paquete), sus *values* (parámetros) y un *release* (una instalación con historial).
- Instalar Helm 4 y usar un chart publicado: `show values`, `install`, `upgrade`, `history`, `rollback` y `uninstall`.
- Leer lo que va a instalar un chart antes de instalarlo, con `helm template`.
- Escribir un chart sencillo con `helm create`, y validarlo con `helm lint`.

## Por qué importa

Hasta ahora escribías cada manifiesto a mano. Para tu aplicación está bien, y es lo que harás con Vigía. Pero el software de terceros que vas a instalar en un cluster (un Prometheus, un controlador de Ingress, cert-manager) son decenas de objetos con cientos de opciones, y se distribuyen como **charts de Helm**. En la fase 10 instalarás así los componentes de observabilidad, si los llevas al cluster.

En las ofertas, Helm aparece casi siempre junto a Kubernetes.

## Teoría

### Las piezas

| Pieza | Qué es |
|-------|--------|
| **chart** | un paquete: plantillas de manifiestos + `values.yaml` con los valores por defecto + `Chart.yaml` con el nombre y la versión |
| **values** | los parámetros que eliges al instalar (`-f valores.yaml` o `--set clave=valor`): réplicas, imagen, recursos… |
| **release** | una instalación de un chart, con nombre propio, en un namespace. Cada cambio es una **revisión** numerada, y se puede volver a cualquiera |
| **repositorio** | donde se publican los charts: hoy, sobre todo **registros OCI** (los mismos que guardan imágenes, como `ghcr.io` o ECR), o un servidor web con un `index.yaml` |

```
values.yaml ─┐
-f / --set ──┼──► plantillas ──► manifiestos ──► el cluster (release «demo», revisión 3)
Chart.yaml ──┘     (Go templates: {{ .Values.replicaCount }})
```

Helm guarda el historial de cada release en Secrets del mismo namespace. Por eso `helm rollback` puede volver a una revisión aunque tu terminal no tenga los archivos.

### Helm 4

Helm 4 salió a finales de 2025, y es la versión actual:
- en las instalaciones nuevas aplica los objetos con *server-side apply*, como `kubectl apply --server-side`;
- `--atomic` se llama ahora `--rollback-on-failure`, y `--force`, `--force-replace`; los nombres viejos aún funcionan, con un aviso;
- los charts de Helm 3 funcionan igual.

Muchos tutoriales en internet son de Helm 3: casi todo vale, salvo esos nombres.

### De quién te fías

Un chart instala lo que quiera en tu cluster: Deployments, permisos RBAC, ClusterRoles… Antes de instalar uno:
- **léelo** con `helm template`;
- **fija la versión** (`--version`): si no, cada instalación puede traer otra cosa;
- usa charts de su proyecto oficial o de publicadores verificados en Artifact Hub (artifacthub.io).

Un aviso concreto: muchos tutoriales usan los charts de **Bitnami**. Desde el 28 de agosto de 2025, su catálogo gratuito solo publica la etiqueta `latest` de unas pocas imágenes, y muchos de esos charts apuntan a imágenes que ya no existen. Para aprender, usa los charts oficiales de cada proyecto.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-113 && cd ~/my-devops-journey/labs/clase-113
```

### 1. Instalar Helm (10 min)

Como kubectl y kind, en `~/.local/bin`, con la versión fijada y su suma SHA-256:

```bash
cd /tmp
curl -fsSLO https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz
curl -fsSLO https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz.sha256sum
sha256sum --check helm-v4.3.0-linux-amd64.tar.gz.sha256sum
tar -xzf helm-v4.3.0-linux-amd64.tar.gz
install -m 0755 linux-amd64/helm ~/.local/bin/helm
helm version
cd ~/my-devops-journey/labs/clase-113
```

Helm usa el mismo `~/.kube/config` que kubectl: trabaja contra tu contexto actual, `kind-lab`.

### 2. Mirar un chart antes de instalarlo (15 min)

El chart de podinfo se publica en el registro OCI de GitHub:

```bash
helm show chart oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0
helm show values oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 | less
```

`show values` es el manual del chart: cada opción, con su valor por defecto. Busca `replicaCount`, `ui:` (y su `message`), `service:` y `resources:`.

Elige tus valores en `valores-lab.yaml`:

```yaml
replicaCount: 2
ui:
  message: "Hola desde Helm"
resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    memory: 128Mi
```

🔮 **Predice:** ¿qué objetos de Kubernetes creará este chart?

```bash
helm template demo oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 -f valores-lab.yaml | grep '^kind:'
```

`helm template` dibuja los manifiestos sin tocar el cluster: es la forma de revisar un chart. Verás un Deployment y un Service, y también tres `Pod`: son pruebas del chart (`helm test`), que solo se ejecutan si las pides.

### 3. Instalar, mirar y actualizar (20 min)

```bash
helm install demo oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 \
  -n helm-lab --create-namespace -f valores-lab.yaml --wait
helm list -n helm-lab
kubectl -n helm-lab get deployment,service,pods
```

`--wait` espera a que todo esté listo, como `kubectl rollout status`. Mira qué recuerda Helm:

```bash
helm get values demo -n helm-lab
helm get manifest demo -n helm-lab | grep '^kind:'
kubectl -n helm-lab get deployment demo-podinfo -o jsonpath='{.metadata.labels}{"\n"}'
```

`get values` muestra solo lo que elegiste tú (`USER-SUPPLIED VALUES`). Los objetos llevan la etiqueta `app.kubernetes.io/managed-by: Helm`: sirve para saber quién los gestiona y no tocarlos a mano.

Actualiza a 3 réplicas:

```bash
helm upgrade demo oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 \
  -n helm-lab -f valores-lab.yaml --set replicaCount=3 --wait
helm history demo -n helm-lab
```

```
REVISION  UPDATED                   STATUS      CHART           APP VERSION  DESCRIPTION
1         Sat Oct 10 14:16:51 2026  superseded  podinfo-6.15.0  6.15.0       Install complete
2         Sat Oct 10 14:16:56 2026  deployed    podinfo-6.15.0  6.15.0       Upgrade complete
```

### 4. Volver atrás (10 min)

```bash
helm rollback demo 1 -n helm-lab --wait
helm history demo -n helm-lab
kubectl -n helm-lab get deployment demo-podinfo
```

🔮 **Predice:** ¿qué número tendrá la revisión nueva?

La 3, con la descripción `Rollback to 1`, y otra vez 2 réplicas. Como `kubectl rollout undo` (clase 104), volver atrás es avanzar a una revisión nueva que copia una vieja. La diferencia: Helm vuelve atrás **todo el release** (Deployment, Service, ConfigMaps…), no solo un Deployment.

### 5. Tu propio chart (25 min)

```bash
helm create saludo
find saludo -type f | sort
```

`helm create` genera un chart de ejemplo completo, que despliega nginx. Trae plantillas para Deployment, Service, ServiceAccount, Ingress, HTTPRoute (Gateway API, clase 111) y escalado automático, casi todas apagadas en `values.yaml`. Conviértelo en un podinfo:

1. En `saludo/values.yaml`:
   - en `image:`, `repository: ghcr.io/stefanprodan/podinfo`;
   - en `service:`, `port: 9898` (la plantilla usa ese número también como puerto del contenedor);
   - en `livenessProbe` y `readinessProbe`, las rutas `/healthz` y `/readyz`;
   - añade arriba del todo `mensaje: "Hola desde mi chart"`.
2. En `saludo/Chart.yaml`, `appVersion: "6.15.0"`. La plantilla usa `appVersion` como etiqueta de la imagen si `image.tag` está vacío.
3. En `saludo/templates/deployment.yaml`, debajo de la línea de `imagePullPolicy`, con la **misma** sangría:

   ```yaml
             env:
               - name: PODINFO_UI_MESSAGE
                 value: {{ .Values.mensaje | quote }}
   ```

   `{{ .Values.mensaje }}` lee tu valor, y `| quote` lo pone entre comillas para que el YAML resultante sea válido aunque lleve caracteres especiales.

Valida y mira el resultado antes de instalar:

```bash
helm lint saludo
helm template prueba saludo | grep -B2 -A2 PODINFO_UI_MESSAGE
helm install saludo ./saludo -n saludo --create-namespace --wait
kubectl exec sonda -- wget -qO- http://saludo.saludo:9898/ | grep message
```

Cambia el mensaje sin tocar ningún archivo:

```bash
helm upgrade saludo ./saludo -n saludo --set mensaje="Versión 2 del chart" --wait
kubectl exec sonda -- wget -qO- http://saludo.saludo:9898/ | grep message
```

Si contesta aún el mensaje viejo, repite a los pocos segundos: el pod antiguo tarda un momento en terminar.

## Rómpelo

1. **Los valores que olvidas.** Actualiza `demo` sin tu archivo de valores, y con una versión que no existe, pidiendo que vuelva atrás si falla:

   ```bash
   helm upgrade demo oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 \
     -n helm-lab --set image.tag=6.99.0 --rollback-on-failure --timeout 60s
   helm history demo -n helm-lab
   ```

   Falla (`UPGRADE FAILED: release demo failed, and has been rolled back due to rollback-on-failure being set`), y el historial muestra una revisión `failed` y una `Rollback to …`. Pero fíjate en el mensaje de error: `Available: 0/1`. **Una** réplica, no dos: sin `-f valores-lab.yaml`, `helm upgrade` vuelve a los valores por defecto del chart en todo lo que no le pasas. Pásale siempre tus valores.
2. **Una plantilla mal sangrada.** En `saludo/templates/deployment.yaml`, quita dos espacios a la línea `value: {{ .Values.mensaje | quote }}`:

   ```
   [ERROR] templates/deployment.yaml: unable to parse YAML: error converting YAML to JSON: yaml: line 32: did not find expected '-' indicator
   ```

   `helm lint` lo encuentra antes de tocar el cluster. Las plantillas generan YAML, y en YAML la sangría es sintaxis. Devuelve los dos espacios.
3. **Tocar a mano lo que gestiona Helm.** Haz `kubectl -n helm-lab scale deployment demo-podinfo --replicas=5` y después el `helm upgrade` de la práctica 3, con tus valores (sin `--set replicaCount=3`). ¿Qué pasa? ¿Cuántas réplicas quedan? Prueba otra vez añadiendo `--force-conflicts`. Es el *drift* de las clases 99 y 104, con otra herramienta.

## Reto

1. `helm get manifest demo -n helm-lab` contra `helm template` con los mismos valores: ¿son iguales? ¿Qué te da cada uno?
2. Sube `version` en `saludo/Chart.yaml` a `0.2.0`, empaquétalo con `helm package saludo` e instálalo desde el `.tgz`. ¿Qué diferencia hay entre `version` y `appVersion`?
3. ¿Dónde guarda Helm el historial? `kubectl -n helm-lab get secrets`. ¿Por qué crees que en Secrets y no en ConfigMaps? (Pista: ¿qué contienen tus valores, a veces?)

## Destruir al terminar

```bash
helm uninstall demo -n helm-lab
helm uninstall saludo -n saludo
kubectl delete namespace helm-lab saludo
```

## Cierre

En `notas/fase-9/clase-113.md`:

1. ¿Qué es un chart, qué son los values y qué es un release?
2. ¿Qué harías antes de instalar un chart que encuentras en un tutorial?
3. ¿En qué se parece y en qué se diferencia `helm rollback` de `kubectl rollout undo`?
4. **Repaso (clase 112, sin mirar):** un pod está en `ImagePullBackOff`. ¿Qué miras y qué tres causas distingue el evento?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Un **chart** es un paquete de plantillas de manifiestos con sus valores por defecto. Los **values** son los parámetros que eliges al instalarlo. Un **release** es una instalación concreta de un chart, con nombre, en un namespace, y con un historial de revisiones.
2. Fijar la versión (`--version`), leer `helm show values` para entender sus opciones, y revisar con `helm template` qué objetos va a crear, sobre todo permisos RBAC y ClusterRoles. Comprobar que viene del proyecto oficial o de un publicador verificado, y que sus imágenes existen y se mantienen (el caso Bitnami).
3. Los dos vuelven a una versión anterior creando una revisión nueva. `kubectl rollout undo` actúa sobre **un** Deployment, y solo sobre su plantilla de pods. `helm rollback` devuelve el **release entero** (todos sus objetos y sus valores) a una revisión anterior.
4. `kubectl describe pod` y el evento `Failed to pull image`: `not found` (una errata en el nombre o la etiqueta, o una imagen que no existe), `unauthorized` o `failed to authorize` (registro privado sin credenciales) y un error de red o DNS del nodo.

**Rómpelo 3:** Helm 4 se niega: `UPGRADE FAILED: conflict occurred while applying object helm-lab/demo-podinfo … conflict with "kubectl" with subresource "scale" using apps/v1: .spec.replicas`. Quedan 5 réplicas, y el historial apunta una revisión `failed`. Con *server-side apply*, el API registra quién gestiona cada campo, y Helm no pisa en silencio el cambio de otro. Decides tú: `--force-conflicts` para que gane el chart (vuelven las 2 réplicas), o llevar el 5 a tus valores. Helm 3, que no usaba *server-side apply*, lo habría deshecho sin avisar.

**Reto 1:** casi: el Deployment y el Service son iguales, pero `helm template` incluye también los tres Pods de prueba, que son *hooks* y Helm guarda aparte (`helm get hooks`). `helm template` genera los manifiestos en tu máquina, sin cluster, para revisar antes de instalar; `helm get manifest` enseña lo que Helm **instaló** de verdad en esa revisión.

**Reto 2:** `version` es la versión del **chart** (las plantillas): súbela cada vez que cambias el chart. `appVersion` es la versión de la **aplicación** que despliega, informativa (aquí, además, la etiqueta de la imagen por defecto).

**Reto 3:** en Secrets de tipo `helm.sh/release.v1`, uno por revisión (`sh.helm.release.v1.demo.v1`…). Van en Secrets porque guardan los valores del release, y los valores a menudo llevan contraseñas.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| chart / release / revision | paquete / instalación / versión de una instalación |
| values file | archivo de valores |
| to template / to render | generar los manifiestos a partir de las plantillas |
| OCI registry | registro de artefactos OCI (imágenes y charts) |
| pinned version | versión fijada |

🎙️ *"I install third-party software with Helm: I pin the chart version, read the default values, render it with helm template to review what it creates, and keep my values file in Git. Rollbacks restore the whole release, not just a Deployment."*

## Siguiente

[Clase 114 — Vigía v6 (I): API y base de datos en kind](clase-114-vigia-v6-api-y-base-de-datos.md)
