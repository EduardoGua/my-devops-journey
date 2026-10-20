# Clase 113 — Helm

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Kubernetes para operar

> 💡 **La idea de hoy:** el software de terceros para Kubernetes se distribuye como **charts** de Helm: plantillas de manifiestos con sus valores por defecto. Tú eliges los **values**, Helm genera los manifiestos y los instala como un **release**, con historial: cada cambio es una revisión, y `helm rollback` devuelve el release entero. Antes de instalar un chart, se fija su versión y se lee lo que va a crear.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Instalar en `~/.local/bin` con la versión fijada y su suma SHA-256 (clase 102).
> - Deployments, revisiones y `rollout undo` (clase 104); Services y la `sonda` (clase 105).
> - Que los Secrets guardan datos sensibles (clase 106); los ClusterRoles (clase 110).
> - Los registros de imágenes, como ghcr.io y ECR (clases 64 y 75); el *drift* (clase 99).

> 🔤 **Palabras nuevas de hoy:**
> - **chart**: un paquete de plantillas de manifiestos, con `values.yaml` y `Chart.yaml`.
> - **values**: los parámetros que eliges al instalar (`-f archivo` o `--set clave=valor`).
> - **release**: una instalación de un chart, con nombre y en un namespace, con revisiones.
> - **registro OCI**: un registro de artefactos (imágenes y charts), como `ghcr.io`.
> - **`helm template`**: generar los manifiestos sin tocar el cluster, para revisarlos.
> - **plantilla Go**: el lenguaje de `{{ .Values.replicaCount }}`.
> - ***server-side apply***: el API registra quién gestiona cada campo de un objeto.

## Objetivo

- Explicar qué problema resuelve Helm: un *chart* (paquete), sus *values* (parámetros) y un *release* (una instalación con historial).
- Instalar Helm 4 y usar un chart publicado: `show values`, `install`, `upgrade`, `history`, `rollback` y `uninstall`.
- Leer lo que va a instalar un chart antes de instalarlo, con `helm template`.
- Escribir un chart sencillo con `helm create`, y validarlo con `helm lint`.

## Por qué importa

Hasta ahora escribías cada manifiesto a mano. Para tu aplicación está bien, y es lo que harás con Vigía. Pero el software de terceros que vas a instalar en un cluster (un Prometheus, un controlador de Ingress, cert-manager) son decenas de objetos con cientos de opciones, y se distribuyen como **charts de Helm**. En la fase 10 instalarás así los componentes de observabilidad, si los llevas al cluster.

En las ofertas, Helm aparece casi siempre junto a Kubernetes.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 25 min); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-113 && cd ~/my-devops-journey/labs/clase-113
```

## Las piezas

### Pieza 1 — Chart, values y release

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

Helm 4 salió a finales de 2025, y es la versión actual:
- en las instalaciones nuevas aplica los objetos con *server-side apply*, como `kubectl apply --server-side`;
- `--atomic` se llama ahora `--rollback-on-failure`, y `--force`, `--force-replace`; los nombres viejos aún funcionan, con un aviso;
- los charts de Helm 3 funcionan igual.

Muchos tutoriales en internet son de Helm 3: casi todo vale, salvo esos nombres.

**Pruébalo.** Como kubectl y kind, en `~/.local/bin`, con la versión fijada y su suma SHA-256:

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

👀 **Qué deberías ver:** `helm-v4.3.0-linux-amd64.tar.gz: OK` y `version.BuildInfo{Version:"v4.3.0", …}`. Helm usa el mismo `~/.kube/config` que kubectl: trabaja contra tu contexto actual, `kind-lab`.

✋ **Sin mirar:** ¿qué diferencia hay entre un chart y un release?

<details>
<summary>Comprueba</summary>

El chart es el paquete (las plantillas y sus valores por defecto); el release es **una** instalación concreta de ese chart, con nombre, namespace e historial. Un mismo chart puede tener muchos releases.
</details>

**En resumen:** chart + values = manifiestos; instalados, un release con revisiones.

### Pieza 2 — De quién te fías: mirar un chart antes de instalarlo

Un chart instala lo que quiera en tu cluster: Deployments, permisos RBAC, ClusterRoles… Antes de instalar uno:
- **léelo** con `helm template`;
- **fija la versión** (`--version`): si no, cada instalación puede traer otra cosa;
- usa charts de su proyecto oficial o de publicadores verificados en Artifact Hub (artifacthub.io).

Un aviso concreto: muchos tutoriales usan los charts de **Bitnami**. Desde el 28 de agosto de 2025, su catálogo gratuito solo publica la etiqueta `latest` de unas pocas imágenes, y muchos de esos charts apuntan a imágenes que ya no existen. Para aprender, usa los charts oficiales de cada proyecto.

**Pruébalo.** El chart de podinfo se publica en el registro OCI de GitHub:

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

👀 **Qué deberías ver:** un `Service` y un `Deployment`, y también tres `Pod`: son pruebas del chart (`helm test`), que solo se ejecutan si las pides. `helm template` dibuja los manifiestos sin tocar el cluster: es la forma de revisar un chart.

✋ **Sin mirar:** ¿qué tres cosas haces antes de instalar un chart que encuentras en un tutorial?

<details>
<summary>Comprueba</summary>

Fijar la versión, leer sus values con `helm show values` y revisar con `helm template` qué objetos crea (sobre todo RBAC). Y comprobar que viene del proyecto oficial o de un publicador verificado.
</details>

**En resumen:** versión fijada, `show values` y `helm template` antes de instalar.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Apaga el cluster con `docker stop lab-control-plane cloud-provider-kind`.

### Pieza 3 — Instalar, mirar y actualizar

`helm install` crea el release (revisión 1); `helm upgrade`, una revisión nueva con otros valores; `helm history`, la lista. Los objetos llevan la etiqueta `app.kubernetes.io/managed-by: Helm`: sirve para saber quién los gestiona y no tocarlos a mano.

**Pruébalo:**

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

👀 **Qué deberías ver:** el release `demo` en `deployed`, con dos pods. `get values` muestra solo lo que elegiste tú (`USER-SUPPLIED VALUES`). Y entre las etiquetas, `"app.kubernetes.io/managed-by":"Helm"`.

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

✋ **Sin mirar:** ¿por qué al hacer `helm upgrade` vuelves a pasar `-f valores-lab.yaml`?

<details>
<summary>Comprueba</summary>

Porque `helm upgrade` vuelve a los valores por defecto del chart en todo lo que no le pasas. Sin tu archivo, perderías tus valores (lo verás en el Rómpelo 1).
</details>

**En resumen:** `install`, `upgrade` con tus valores siempre, y `history` para ver las revisiones.

### Pieza 4 — Volver atrás

`helm rollback demo <revisión>` devuelve el release a una revisión anterior. Helm guarda el historial de cada release en Secrets del mismo namespace: por eso puede volver atrás aunque tu terminal no tenga los archivos.

**Pruébalo:**

```bash
helm rollback demo 1 -n helm-lab --wait
helm history demo -n helm-lab
kubectl -n helm-lab get deployment demo-podinfo
```

🔮 **Predice:** ¿qué número tendrá la revisión nueva?

👀 **Qué deberías ver:** la 3, con la descripción `Rollback to 1`, y otra vez 2 réplicas. Como `kubectl rollout undo` (clase 104), volver atrás es avanzar a una revisión nueva que copia una vieja. La diferencia: Helm vuelve atrás **todo el release** (Deployment, Service, ConfigMaps…), no solo un Deployment.

✋ **Sin mirar:** ¿qué devuelve `helm rollback` que `kubectl rollout undo` no puede?

<details>
<summary>Comprueba</summary>

Todos los objetos del release y sus valores, no solo la plantilla de pods de un Deployment.
</details>

**En resumen:** `helm rollback` crea una revisión nueva con el release entero de antes.

### Pieza 5 — Tu propio chart

`helm create` genera un chart de ejemplo completo, que despliega nginx. Trae plantillas para Deployment, Service, ServiceAccount, Ingress, HTTPRoute (Gateway API, clase 111) y escalado automático, casi todas apagadas en `values.yaml`. Dentro de las plantillas, `{{ .Values.x }}` lee un valor, y `| quote` lo pone entre comillas para que el YAML resultante sea válido aunque lleve caracteres especiales. `helm lint` lo valida antes de tocar el cluster.

**Pruébalo:**

```bash
helm create saludo
find saludo -type f | sort
```

Conviértelo en un podinfo:

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

Valida y mira el resultado antes de instalar:

```bash
helm lint saludo
helm template prueba saludo | grep -B2 -A2 PODINFO_UI_MESSAGE
helm install saludo ./saludo -n saludo --create-namespace --wait
kubectl exec sonda -- wget -qO- http://saludo.saludo:9898/ | grep message
```

👀 **Qué deberías ver:** `1 chart(s) linted, 0 chart(s) failed`; en el `template`, `value: "Hola desde mi chart"`; y la respuesta de podinfo con `"message": "Hola desde mi chart"`.

Cambia el mensaje sin tocar ningún archivo:

```bash
helm upgrade saludo ./saludo -n saludo --set mensaje="Versión 2 del chart" --wait
kubectl exec sonda -- wget -qO- http://saludo.saludo:9898/ | grep message
```

Si contesta aún el mensaje viejo, repite a los pocos segundos: el pod antiguo tarda un momento en terminar.

✋ **Sin mirar:** ¿qué hace `| quote` en `{{ .Values.mensaje | quote }}`?

<details>
<summary>Comprueba</summary>

Pone el valor entre comillas, para que el YAML generado sea válido aunque el mensaje lleve dos puntos, comillas u otros caracteres especiales.
</details>

**En resumen:** `helm create` da el esqueleto; `.Values` lo parametriza; `helm lint` y `helm template` lo revisan.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `helm show values oci://… --version X` | el manual del chart |
| `helm template demo oci://… --version X -f valores.yaml` | los manifiestos, sin tocar el cluster |
| `helm install demo oci://… --version X -n ns --create-namespace -f valores.yaml --wait` | instalar un release |
| `helm upgrade demo … -f valores.yaml [--set k=v] --wait` | una revisión nueva |
| `helm list -n ns` · `helm history demo -n ns` | releases y revisiones |
| `helm get values` · `helm get manifest` | lo que elegiste · lo que instaló |
| `helm rollback demo 1 -n ns --wait` | volver a una revisión |
| `helm create saludo` · `helm lint saludo` · `helm package saludo` | tu propio chart |
| `helm uninstall demo -n ns` | desinstalar |

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
3. **Tocar a mano lo que gestiona Helm.** Haz `kubectl -n helm-lab scale deployment demo-podinfo --replicas=5` y después el `helm upgrade` de la pieza 3, con tus valores (sin `--set replicaCount=3`). ¿Qué pasa? ¿Cuántas réplicas quedan? Prueba otra vez añadiendo `--force-conflicts`. Es el *drift* de las clases 99 y 104, con otra herramienta.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Compara `helm get manifest demo -n helm-lab` con `helm template` con los mismos valores: ¿son iguales? ¿Qué te da cada uno?

> 🧩 **Ejemplo resuelto:** la pieza 2: `helm template … | grep '^kind:'` mostraba un Service, un Deployment y tres Pods de prueba.

**Ahora tú, con huecos:** `helm get manifest demo -n helm-lab | grep '^kind:'` y el `template` de la pieza 2. Completa: «Se diferencian en ____: son *hooks*, que Helm guarda aparte (`helm get ____`). `helm template` sirve para… sin cluster; `helm get manifest`, para ver lo que…».

<details>
<summary>Pista</summary>

Compara el número de líneas `kind:` de cada uno, y prueba `helm get hooks demo -n helm-lab`.
</details>

**2.** Sube `version` en `saludo/Chart.yaml` a `0.2.0`, empaquétalo con `helm package saludo` e instálalo desde el `.tgz`. ¿Qué diferencia hay entre `version` y `appVersion`?

> 🧩 **Ejemplo resuelto:** la pieza 3: en `helm history`, la columna `CHART` decía `podinfo-6.15.0` y `APP VERSION`, `6.15.0`.

**Ahora tú, con huecos:**
```bash
helm package saludo
helm upgrade saludo ./saludo-____.tgz -n saludo --wait
helm history saludo -n saludo
```
Completa: «`version` es la versión del ____: la subo cada vez que cambio ____. `appVersion` es la de la ____ que despliega».

<details>
<summary>Pista</summary>

`helm package` crea un archivo `<nombre>-<version>.tgz` en la carpeta actual.
</details>

**3.** ¿Dónde guarda Helm el historial? ¿Por qué crees que en Secrets y no en ConfigMaps?

> 🧩 **Ejemplo resuelto:** la pieza 4: `helm rollback` funcionaba aunque tu terminal no tuviera los archivos de la revisión 1.

**Ahora tú, con huecos:** `kubectl -n helm-lab get secrets`. Completa: «Hay un Secret de tipo ____ por cada ____, con nombres como ____. Van en Secrets porque guardan ____, y esos a veces llevan…».

<details>
<summary>Pista</summary>

Piensa qué pondrías en los values de un chart de base de datos.
</details>

## Destruir al terminar

```bash
helm uninstall demo -n helm-lab
helm uninstall saludo -n saludo
kubectl delete namespace helm-lab saludo
```

## Cierre

En `notas/fase-9/clase-113.md`:

1. ¿Qué es un chart, qué son los values y qué es un release? *(3 líneas, una por pieza.)*
2. ¿Qué harías antes de instalar un chart que encuentras en un tutorial? *(2 líneas. Empieza así: «Fijar la versión, leer `helm show values` y…»)*
3. ¿En qué se parece y en qué se diferencia `helm rollback` de `kubectl rollout undo`? *(2 líneas. Empieza así: «Los dos vuelven atrás creando una revisión nueva, pero…»)*
4. **Repaso (clase 112, sin mirar):** un pod está en `ImagePullBackOff`. ¿Qué miras y qué tres causas distingue el evento? *(2 líneas.)*

Después, escríbeme `examíname clase-113`.

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

**Reto 2:** `./saludo-0.2.0.tgz`. `version` es la versión del **chart** (las plantillas): súbela cada vez que cambias el chart. `appVersion` es la versión de la **aplicación** que despliega, informativa (aquí, además, la etiqueta de la imagen por defecto).

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
