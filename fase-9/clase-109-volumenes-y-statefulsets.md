# Clase 109 — Volúmenes persistentes y StatefulSets

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Kubernetes para operar

## Objetivo

- Distinguir el disco efímero de un contenedor, un `emptyDir` y un volumen persistente.
- Pedir disco con un **PersistentVolumeClaim** y entender quién lo crea: StorageClass, aprovisionamiento dinámico y PersistentVolume.
- Comprobar que los datos sobreviven al pod, y saber cuándo se borran.
- Usar un **StatefulSet**: nombres fijos, un volumen por réplica y DNS estable con un Service *headless*.

## Por qué importa

Hasta ahora todo era desechable, y está bien para la API: si un pod muere, otro idéntico ocupa su lugar. Pero PostgreSQL guarda los datos de Vigía: si su pod se recrea con un disco vacío, pierdes el historial entero. Es la lección de los volúmenes de la clase 60, con más piezas.

Y es la frontera de qué conviene meter en Kubernetes. En la clase 115 verás por qué muchas empresas ponen la base de datos fuera, en RDS (clase 77).

## Teoría

### Tres tipos de disco

| Disco | Vive lo que vive… | Para qué |
|-------|-------------------|----------|
| la capa del contenedor | el **contenedor**: se pierde en cada reinicio | nada que importe |
| `emptyDir` | el **pod**: sobrevive a reinicios del contenedor, no a que se borre el pod | compartir archivos entre contenedores (clase 103), cachés |
| volumen persistente (PVC) | **independiente** del pod: hasta que borras el PVC | bases de datos, archivos subidos, todo lo que no puedes perder |

### Las piezas del disco persistente

```
pod ──usa──► PersistentVolumeClaim «quiero 1 Gi, RWO»       (lo escribes tú)
                     │ lo atiende
             StorageClass «standard» ──► aprovisionador ──► PersistentVolume (el disco real)
```

- **PersistentVolumeClaim** (PVC): la petición de disco, con su tamaño y su modo de acceso.
- **StorageClass:** el tipo de disco y quién lo crea. En kind, `standard`, con el aprovisionador `local-path`, que crea una carpeta dentro del nodo. En EKS, `gp3`: un volumen EBS de verdad (clase 72).
- **PersistentVolume** (PV): el disco concreto, que el aprovisionador crea al vuelo (*aprovisionamiento dinámico*).

| Modo de acceso | Significa |
|----------------|-----------|
| `ReadWriteOnce` (RWO) | lectura y escritura desde **un nodo** a la vez. Es lo que dan los discos de bloque, como EBS |
| `ReadWriteOncePod` (RWOP) | lectura y escritura desde **un único pod** |
| `ReadWriteMany` (RWX) | desde muchos nodos a la vez: necesita un sistema de archivos en red, como EFS |
| `ReadOnlyMany` (ROX) | solo lectura, desde muchos |

Dos ajustes de la StorageClass que cambian el comportamiento:
- `volumeBindingMode: WaitForFirstConsumer`: el disco no se crea hasta que un pod lo usa. Así se crea en el nodo (o la zona de AWS) donde cae ese pod.
- `reclaimPolicy: Delete`: al borrar el PVC se borra también el disco. Con `Retain`, el disco se queda.

### StatefulSet: pods con nombre propio

Un Deployment trata a sus pods como intercambiables: nombres al azar, todos compartiendo el mismo volumen (si tuvieran uno). Una base de datos necesita lo contrario:

| | Deployment | StatefulSet |
|-|------------|-------------|
| Nombres | `web-775c4dfd56-9h8qm`, al azar | `db-0`, `db-1`… fijos, y el mismo nombre al recrearse |
| Orden | todos a la vez | de uno en uno: `-0`, luego `-1`… |
| Disco | el mismo PVC para todos, o ninguno | uno **propio** por réplica, con `volumeClaimTemplates` |
| DNS | el del Service | además, uno por pod: `db-0.db.<ns>.svc.cluster.local` |

El StatefulSet necesita un Service *headless* (clase 105) con el nombre de su `serviceName`, que da esos nombres por pod. Y sus PVC **no** se borran al escalar hacia abajo ni al borrar el StatefulSet: perder los datos tiene que ser una decisión explícita.

Que un StatefulSet dé nombres y discos estables no convierte una base de datos en algo fácil de operar: copias de seguridad, réplicas y actualizaciones de versión siguen siendo trabajo tuyo, o de un *operador* como CloudNativePG.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-109 && cd ~/my-devops-journey/labs/clase-109
kubectl get storageclass
```

```
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  …
```

### 1. Pedir disco (15 min)

`datos.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: datos
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 100Mi
```

No dice `storageClassName`: usa la que está marcada `(default)`.

```bash
kubectl apply -f datos.yaml
kubectl get pvc datos
```

🔮 **Predice:** ¿en qué estado está el PVC? ¿Existe ya algún PersistentVolume (`kubectl get pv`)?

`Pending`, y ningún PV. No es un error: `kubectl describe pvc datos` lo explica con el evento `waiting for first consumer to be created before binding`.

### 2. Un pod que lo usa, y los datos que sobreviven (20 min)

`escritor.yaml` añade una línea con la fecha cada vez que arranca, y muestra el archivo:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: escritor
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "date >> /datos/visitas.txt; cat /datos/visitas.txt; sleep 1d"]
      volumeMounts:
        - name: datos
          mountPath: /datos
  volumes:
    - name: datos
      persistentVolumeClaim:
        claimName: datos
```

```bash
kubectl apply -f escritor.yaml
kubectl wait --for=condition=Ready pod/escritor --timeout=90s
kubectl get pvc datos
kubectl get pv
kubectl logs escritor
```

Ahora el PVC está `Bound`, y hay un PV con un nombre `pvc-…` creado al vuelo. Borra el pod y créalo otra vez:

```bash
kubectl delete pod escritor
kubectl apply -f escritor.yaml
kubectl wait --for=condition=Ready pod/escritor --timeout=90s
kubectl logs escritor
```

Dos líneas: los datos sobrevivieron al pod. ¿Dónde están de verdad?

```bash
PV=$(kubectl get pvc datos -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o jsonpath='{.spec.hostPath.path}{"\n"}'
docker exec lab-control-plane ls /var/local-path-provisioner/
```

Una carpeta **dentro del contenedor del nodo**. Por eso `kind delete cluster` se lleva todos tus datos, y por eso en la nube se usan discos de red (EBS) que sobreviven a la máquina.

### 3. Cuándo se borran (10 min)

```bash
kubectl delete pvc datos --wait=false
kubectl get pvc datos
```

🔮 **Predice:** el pod sigue usándolo. ¿Se borra?

Se queda en `Terminating`. Mira su *finalizer*:

```bash
kubectl get pvc datos -o jsonpath='{.metadata.finalizers}{"\n"}'
```

`kubernetes.io/pvc-protection`: Kubernetes no borra un disco que un pod está usando. Borra el pod, y el PVC desaparecerá, y con él el PV (`reclaimPolicy: Delete`):

```bash
kubectl delete pod escritor
kubectl get pvc,pv
```

### 4. Un StatefulSet (30 min)

`tienda.yaml`: un Service *headless* y un StatefulSet de dos réplicas. Cada pod escribe en **su** disco quién es y cuándo arrancó, y nginx lo sirve:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tienda
spec:
  clusterIP: None
  selector:
    app: tienda
  ports:
    - name: http
      port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tienda
spec:
  serviceName: tienda
  replicas: 2
  selector:
    matchLabels:
      app: tienda
  template:
    metadata:
      labels:
        app: tienda
    spec:
      initContainers:
        - name: presentarse
          image: busybox:1.37
          command: ["sh", "-c", "echo \"soy $(hostname), arranqué: $(date)\" >> /html/index.html"]
          volumeMounts:
            - name: html
              mountPath: /html
      containers:
        - name: nginx
          image: nginx:1.29
          ports:
            - name: http
              containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: html
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Mi
```

```bash
kubectl apply -f tienda.yaml
kubectl get pods -l app=tienda -w
```

🔮 **Predice:** ¿arrancan los dos a la vez?

No: `tienda-0` pasa por `Pending`, `Init:0/1` y `Running`, y solo entonces empieza `tienda-1`. Sal con `Ctrl+C`:

```bash
kubectl get pods,pvc -l app=tienda
kubectl exec sonda -- nslookup tienda.default.svc.cluster.local
kubectl exec sonda -- wget -qO- http://tienda-1.tienda
```

- Un PVC por pod: `html-tienda-0` y `html-tienda-1`. El nombre es `<plantilla>-<pod>`.
- El *headless* devuelve las IPs de los dos pods, y `tienda-1.tienda` llega a uno concreto.

Ahora, la identidad estable:

```bash
kubectl delete pod tienda-1
kubectl get pods -l app=tienda
kubectl exec sonda -- wget -qO- http://tienda-1.tienda
```

Vuelve un `tienda-1`, con el mismo nombre, y su página tiene **dos** líneas: es su disco de antes.

Y escalar:

```bash
kubectl scale statefulset tienda --replicas=1
kubectl get pods,pvc -l app=tienda
kubectl scale statefulset tienda --replicas=2
kubectl exec sonda -- wget -qO- http://tienda-1.tienda
```

Al bajar a 1 se va el **último** (`tienda-1`), pero su PVC se queda. Al subir, el nuevo `tienda-1` recupera su disco: tres líneas.

## Rómpelo

1. **Una StorageClass que no existe.** Un PVC `rapido` con `storageClassName: rapido`. ¿Estado? ¿Evento?

   `Pending`, con `ProvisioningFailed … storageclass.storage.k8s.io "rapido" not found`. Un pod que lo use se queda también en `Pending`.
2. **Un modo de acceso imposible.** Un PVC `compartido` con `accessModes: ["ReadWriteMany"]` y un pod que lo use. ¿Qué dice `kubectl describe pvc compartido`?

   `failed to provision volume with StorageClass "standard": NodePath only supports ReadWriteOnce and ReadWriteOncePod (1.22+) access modes`. Un disco de un solo nodo no se puede compartir entre nodos; en AWS pasaría lo mismo con EBS, y harías falta EFS.
3. **Borrar el StatefulSet.** `kubectl delete statefulset tienda`. ¿Qué queda en `kubectl get pvc`? Créalo otra vez con `kubectl apply -f tienda.yaml`: ¿qué muestra `tienda-0`?

## Reto

1. Cambia `storage: 50Mi` por `100Mi` en `tienda.yaml` y aplica. ¿Qué dice el API? (Pista: los `volumeClaimTemplates` de un StatefulSet son inmutables. ¿Y si la StorageClass tuviera `allowVolumeExpansion: true`, podrías agrandar directamente el PVC?)
2. Un `emptyDir` para comparar: crea un pod `efimero` como `escritor`, pero con `emptyDir: {}` en lugar del PVC y `sleep 20` en lugar de `sleep 1d`. El contenedor terminará cada 20 segundos y el kubelet lo volverá a arrancar. A los 2 minutos, ¿cuántas líneas muestra `kubectl logs efimero`? Ahora borra el pod y créalo otra vez: ¿cuántas?
3. Para Vigía (clase 114): ¿qué nombre tendrá el PVC de PostgreSQL si el StatefulSet se llama `db` y la plantilla, `datos`? ¿Qué comando borrarías **a propósito** para empezar con la base de datos vacía?

## Destruir al terminar

```bash
kubectl delete -f tienda.yaml
kubectl delete pvc -l app=tienda
kubectl delete pvc rapido compartido --ignore-not-found
kubectl delete pod usa-compartido efimero --ignore-not-found
```

Los PVC del StatefulSet hay que borrarlos aparte: lo has visto en el Rómpelo 3.

## Cierre

En `notas/fase-9/clase-109.md`:

1. ¿Qué diferencia hay entre un `emptyDir` y un PersistentVolumeClaim? ¿Cuándo usarías cada uno?
2. Cuenta qué pasa desde que aplicas un PVC hasta que un pod escribe en él: PVC, StorageClass, aprovisionador, PV.
3. ¿Qué te da un StatefulSet que no te da un Deployment? ¿Por qué no borra sus PVC?
4. **Repaso (clase 108, sin mirar):** ¿qué hace `concurrencyPolicy: Forbid`?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. El `emptyDir` vive lo que vive el pod: sobrevive a un reinicio del contenedor, pero se borra con el pod. Sirve para compartir archivos entre los contenedores de un pod o para cachés. El PVC es independiente del pod y dura hasta que lo borras: para datos que no puedes perder.
2. El PVC pide disco. Con `WaitForFirstConsumer`, espera a que un pod lo use; entonces la StorageClass (`standard`) dice qué aprovisionador lo atiende (`local-path`). Este crea el disco (una carpeta en el nodo, o un EBS en AWS) y un PV que lo representa. El PVC queda `Bound` a ese PV, y el kubelet lo monta en el pod.
3. Nombres fijos (`db-0`), arranque en orden, un PVC propio por réplica que sigue a su pod cuando se recrea, y un DNS por pod con el Service *headless*. No borra sus PVC porque perder los datos de una base de datos debe ser una decisión explícita: si te equivocas al escalar o al borrar el StatefulSet, los datos siguen ahí.
4. Si la ejecución anterior de un CronJob sigue en marcha cuando toca la siguiente, la nueva se salta.

**Rómpelo 3:** los dos PVC (`html-tienda-0` y `html-tienda-1`) siguen ahí. Al recrear el StatefulSet, cada pod vuelve a su disco, y `tienda-0` muestra todas sus líneas anteriores más una nueva.

**Reto 1:** `The StatefulSet "tienda" is invalid: spec.volumeClaimTemplates: Invalid value: […]: field is immutable`: la plantilla de los PVC no se puede cambiar. Con `allowVolumeExpansion: true` sí podrías editar el tamaño de cada PVC. La StorageClass `gp3` de EKS lo permite; la `standard` de kind, no.

**Reto 2:** a los 2 minutos, unas cuatro líneas, con `RESTARTS 3`: el contenedor muere y renace, pero el `emptyDir` es del **pod** y sigue ahí. Entre arranques verás `Completed` y `CrashLoopBackOff`: es la espera creciente del kubelet entre reinicios (clase 112). Al borrar y recrear el pod, **una** línea: el directorio nace vacío con cada pod.

**Reto 3:** `datos-db-0`. Para empezar de cero, a propósito: borrar el StatefulSet y después `kubectl -n vigia delete pvc datos-db-0`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| persistent volume claim (PVC) | petición de volumen persistente |
| storage class / provisioner | tipo de almacenamiento / quien crea los discos |
| dynamic provisioning | aprovisionamiento dinámico |
| access mode (RWO, RWX) | modo de acceso |
| stable network identity | identidad de red estable |

🎙️ *"Stateless apps run as Deployments; anything that owns data runs as a StatefulSet with a volume claim template, so each replica keeps its own disk and name across restarts. PVCs outlive the StatefulSet on purpose: deleting data has to be an explicit decision."*

## Siguiente

[Clase 110 — Namespaces y RBAC](clase-110-namespaces-y-rbac.md)
