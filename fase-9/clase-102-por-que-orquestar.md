# Clase 102 — Por qué orquestar: arquitectura, kind y kubectl

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

## Objetivo

- Explicar qué resuelve un orquestador que Docker Compose no resuelve.
- Nombrar las piezas del *control plane* y de un nodo, y decir qué hace cada una.
- Entender el modelo declarativo: estado deseado, bucles de control y reconciliación.
- Instalar kubectl y kind, crear tu primer cluster y moverte por él con `get`, `describe`, `logs` y `explain`.

## Por qué importa

Con Compose (clase 62), Vigía se levanta en una máquina. Si esa máquina se apaga, Vigía se apaga con ella. Y para actualizarla hay que pararla.

En producción, las aplicaciones corren en muchas máquinas y tienen que sobrevivir a que una se caiga, actualizarse sin cortar el servicio y crecer cuando llega más tráfico. Kubernetes hace todo eso, y aparece en casi todas las ofertas de DevOps, junto a AWS y Terraform.

kind te da un cluster de verdad en tu portátil y gratis. Es el mismo Kubernetes que corre en EKS, el servicio de AWS.

## Teoría

### De Compose a Kubernetes

| Necesidad | Compose: una máquina | Kubernetes: un cluster |
|-----------|----------------------|------------------------|
| Reiniciar lo que muere | `restart: unless-stopped` | el kubelet reinicia el contenedor; si muere el **nodo** entero, los pods se recrean en otro |
| Elegir dónde corre | siempre en la misma máquina | el *scheduler* elige un nodo con recursos libres |
| Escalar | `--scale`, en la misma máquina | `replicas: 5`, repartidas entre nodos |
| Actualizar sin cortar | parar y arrancar | actualización gradual con vuelta atrás (clase 104) |
| Encontrar otro servicio | el nombre del servicio en la red de Compose | un Service con IP fija y nombre DNS (105) |
| Configuración y secretos | `.env` y volúmenes | ConfigMaps y Secrets (106) |

### Declarativo: dices qué quieres, no qué hacer

No le dices a Kubernetes "arranca tres contenedores". Le dices "quiero que haya tres réplicas de esto", y él se encarga de que así sea **siempre**:

```
tú: «quiero 3 réplicas» ──► API ──► etcd (estado deseado)
                                        │
controlador: ¿cuántas hay? 2 ──► crea 1 ──► vuelve a mirar ──► … (para siempre)
```

Cada tipo de objeto tiene su **controlador**: un bucle que compara el estado deseado con el real y corrige la diferencia. Es la idea de Terraform (clase 92), con una diferencia: Terraform reconcilia cuando tú ejecutas `apply`, y Kubernetes lo hace sin parar.

### Las piezas

```
                           CONTROL PLANE
   kubectl ──HTTPS──► kube-apiserver ◄────► etcd
                          ▲         ▲
             kube-scheduler         kube-controller-manager
   ──────────────────────────────────────────────────────────
                           CADA NODO
   kubelet ──► containerd ──► contenedores de los pods
   kube-proxy: las reglas de red de los Services
```

| Pieza | Qué hace |
|-------|----------|
| **kube-apiserver** | la única puerta: kubectl, los controladores y los kubelets hablan con el cluster a través de su API REST, siempre autenticados |
| **etcd** | la base de datos clave-valor con todo el estado del cluster. Perder etcd es perder el cluster |
| **kube-scheduler** | decide en qué nodo va cada pod nuevo, según los recursos libres y las reglas |
| **kube-controller-manager** | los bucles de control: Deployments, ReplicaSets, Jobs, nodos… |
| **cloud-controller-manager** | habla con la nube para crear balanceadores y discos. En kind no hay nube: lo suplirá cloud-provider-kind (clase 105) |
| **kubelet** | el agente de cada nodo: arranca los contenedores de los pods que le asignan y vigila sus sondas |
| **containerd** | el motor que ejecuta los contenedores. Los nodos no usan Docker, pero las imágenes son las mismas (formato OCI) |
| **kube-proxy** | programa en cada nodo las reglas que hacen funcionar los Services |
| **CoreDNS** y la **red de pods** (CNI) | el DNS interno y la red por la que cada pod tiene su propia IP. En kind, la red se llama *kindnet* |

### kind: Kubernetes dentro de Docker

**kind** (*Kubernetes IN Docker*) crea cada nodo como un contenedor de Docker con systemd, kubelet y containerd dentro. Es Kubernetes completo (el propio proyecto Kubernetes lo usa para probarse), pensado para aprender, para probar y para CI. No es para producción.

Hay alternativas parecidas: minikube, k3d y Docker Desktop. En la nube, el *control plane* lo gestiona el proveedor: EKS en AWS, GKE en Google, AKS en Azure.

### kubeconfig y contextos

kubectl lee `~/.kube/config`. Ahí hay tres listas:
- **clusters:** la URL del API y su certificado;
- **users:** tus credenciales;
- **contexts:** qué usuario usas con qué cluster.

kind añade el contexto `kind-<nombre>` y lo deja activo.

> 🔐 El usuario que te da kind es **administrador** del cluster: quien tenga ese archivo, lo controla entero. Nunca va a Git ni a una captura de pantalla. Es la misma regla que con las llaves de AWS.

## Práctica guiada

### 1. Instalar kubectl (10 min)

Igual que la AWS CLI (clase 70), en tu usuario, sin `sudo`. Fijas la versión y compruebas la suma SHA-256 que publica Kubernetes:

```bash
cd /tmp
curl -fsSLO https://dl.k8s.io/release/v1.37.1/bin/linux/amd64/kubectl
curl -fsSLO https://dl.k8s.io/release/v1.37.1/bin/linux/amd64/kubectl.sha256
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
```

🔮 **Predice:** ¿qué imprime la última línea si la descarga está bien? ¿Y si alguien la hubiera manipulado?

```bash
install -m 0755 kubectl ~/.local/bin/kubectl
kubectl version --client
```

Debe decir `Client Version: v1.37.1`. kubectl funciona con clusters de **una versión menor** de diferencia, arriba o abajo: el v1.37 habla con clusters 1.36, 1.37 y 1.38.

Completado con el tabulador y un alias corto:

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

En las clases escribiré `kubectl` entero; tú usa `k` si quieres. Prueba el tabulador: `kubectl get po<Tab>`.

### 2. Instalar kind (5 min)

```bash
cd /tmp
curl -fsSLO https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-amd64
curl -fsSLO https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-amd64.sha256sum
sha256sum --check kind-linux-amd64.sha256sum
install -m 0755 kind-linux-amd64 ~/.local/bin/kind
kind version
```

### 3. Tu primer cluster (15 min)

```bash
kind create cluster --name lab
```

La primera vez descarga la imagen del nodo (`kindest/node:v1.37.0`, que ocupa más de 1 GB en disco) y tarda unos minutos. Después, menos de un minuto:

```
Creating cluster "lab" ...
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-lab"
```

🔮 **Predice:** ¿cuántos contenedores nuevos verás en `docker ps`? ¿Qué puerto publicarán?

```bash
docker ps
kubectl cluster-info
kubectl get nodes -o wide
```

Un contenedor, `lab-control-plane`, que publica en `127.0.0.1` un puerto al azar hacia el 6443: el puerto del API, al que habla kubectl. Si el nodo sale `NotReady`, espera unos segundos y repite: está arrancando la red de pods. En la columna `CONTAINER-RUNTIME` verás `containerd`.

### 4. Mirar dentro (20 min)

```bash
kubectl get pods -A
```

`-A` son todos los *namespaces* (clase 110). Verás algo así:

```
NAMESPACE            NAME                                        READY   STATUS    RESTARTS   AGE
kube-system          coredns-559f6c778d-48j7j                    1/1     Running   0          2m
kube-system          coredns-559f6c778d-xgzc8                    1/1     Running   0          2m
kube-system          etcd-lab-control-plane                      1/1     Running   0          2m
kube-system          kindnet-fbnvq                               1/1     Running   0          2m
kube-system          kube-apiserver-lab-control-plane            1/1     Running   0          2m
kube-system          kube-controller-manager-lab-control-plane   1/1     Running   0          2m
kube-system          kube-proxy-66w7n                            1/1     Running   0          2m
kube-system          kube-scheduler-lab-control-plane            1/1     Running   0          2m
local-path-storage   local-path-provisioner-75f7fc7dc5-v7mbb     1/1     Running   0          2m
```

Busca en la lista cada pieza de la tabla de la teoría.

🔮 **Predice:** ¿está el kubelet en esa lista?

No está: el kubelet no es un pod, es un servicio de systemd dentro del nodo. Entra en el contenedor del nodo y míralo:

```bash
docker exec lab-control-plane systemctl is-active kubelet containerd
docker exec lab-control-plane ls /etc/kubernetes/manifests
docker exec lab-control-plane crictl ps
```

En `/etc/kubernetes/manifests` están el API, etcd, el *scheduler* y el *controller-manager*. Son **pods estáticos**: el kubelet los arranca directamente desde esos archivos, sin pasar por el API. Así se resuelve otro huevo y gallina: el API no puede pedirse a sí mismo que arranque. `crictl` es el `docker ps` de containerd.

Dos herramientas para el resto de la fase:

```bash
kubectl api-resources | head -15
kubectl explain pod.spec.containers.image
```

`api-resources` lista todos los tipos de objeto que entiende el cluster. `explain` es la documentación de cada campo, en tu terminal.

### 5. Tu primer pod, y quién hace qué (15 min)

```bash
kubectl run hola --image=nginx:1.29
kubectl get pods -w
```

`-w` sigue mirando: verás `ContainerCreating` y después `Running`. Sal con `Ctrl+C`.

```bash
kubectl describe pod hola
```

Baja hasta `Events`:

```
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  14s   default-scheduler  Successfully assigned default/hola to lab-control-plane
  Normal  Pulling    14s   kubelet            spec.containers{hola}: Pulling image "nginx:1.29"
  Normal  Pulled     1s    kubelet            spec.containers{hola}: Successfully pulled image "nginx:1.29" in 13.494s …
  Normal  Created    1s    kubelet            spec.containers{hola}: Container created
  Normal  Started    1s    kubelet            spec.containers{hola}: Container started
```

🔮 **Predice:** antes de mirar la columna `From`, ¿qué pieza escribió cada línea?

La arquitectura, en acción: el *scheduler* eligió nodo, y el kubelet de ese nodo descargó la imagen y arrancó el contenedor. `describe` y sus eventos serán tu primera herramienta de diagnóstico (clase 112).

```bash
kubectl get pod hola -o wide
kubectl logs hola
```

El pod tiene su propia IP, de la red de pods (`10.244.x.x`).

### 6. Quién eres en el cluster (5 min)

```bash
kubectl config get-contexts
kubectl config view --minify
kubectl auth whoami
```

`config view` oculta los certificados (`DATA+OMITTED`). `whoami` dice que eres `kubernetes-admin`, del grupo `kubeadm:cluster-admins`: administrador. Lo verás con lupa en la clase 110.

## Rómpelo

**1. Borra un pod de CoreDNS:**

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system delete pod <uno-de-los-dos>
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

En segundos hay otro, con otro nombre. Pregunta quién lo recreó:

```bash
kubectl -n kube-system get replicasets -l k8s-app=kube-dns
```

Un ReplicaSet que quiere 2 (`DESIRED`) y su controlador, que vio 1 y creó otro. Es el bucle de reconciliación.

**2. Borra tu pod:**

```bash
kubectl delete pod hola
kubectl get pods
```

🔮 **Predice:** ¿vuelve?

No vuelve. Lo creaste suelto, sin ningún controlador que lo vigile. Por eso en la práctica nadie crea pods sueltos: se crean Deployments (clase 104).

**3. Apaga el nodo:**

```bash
docker stop lab-control-plane
kubectl get nodes
```

```
The connection to the server 127.0.0.1:35461 was refused - did you specify the right host or port?
```

El API vivía en ese contenedor. Vuelve a encenderlo:

```bash
docker start lab-control-plane
kubectl get nodes
kubectl get pods -A
```

En unos segundos responde, y los pods del sistema vuelven con `RESTARTS` 1. Todo el estado sobrevivió, porque etcd guarda sus datos en el disco del contenedor del nodo.

Así apagarás el cluster cuando no estudies: `docker stop lab-control-plane` libera la memoria y `docker start` lo trae de vuelta. Si después de reiniciar el portátil `kubectl` no responde, es lo primero que pruebas.

## Reto

1. **Un cluster de tres nodos.** Guarda esto como `/tmp/kind-multi.yaml`:

   ```yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   nodes:
     - role: control-plane
     - role: worker
     - role: worker
   ```

   ```bash
   kind create cluster --name multi --config /tmp/kind-multi.yaml
   kubectl get nodes -w
   ```

   Espera a que los tres digan `Ready` y sal con `Ctrl+C`. Si creas los pods antes, el *scheduler* solo ve un nodo listo y los pone todos ahí.

   ```bash
   kubectl create deployment reparto --image=nginx:1.29 --replicas=6
   kubectl get pods -o wide
   ```

   ¿En qué nodos caen los pods? ¿Por qué ninguno cae en el *control plane*? (Pista: `kubectl describe node multi-control-plane | grep Taints`.) Usa cerca de 1 GB más de RAM mientras existe. Al terminar, `kind delete cluster --name multi` y vuelve a tu cluster con `kubectl config use-context kind-lab`.
2. En `kubectl get pods -A -o wide`, unos pods tienen la IP del nodo y otros una `10.244.x.x`. ¿Cuáles son unos y otros? ¿Por qué crees que etcd y el API no usan la red de pods? (Pista: `kubectl explain pod.spec.hostNetwork`.)
3. Con `kubectl explain`, busca qué significa `spec.restartPolicy` de un pod y qué valores admite.

## Destruir al terminar

El cluster `lab` te acompaña toda la fase: **no** lo borres. Apágalo cuando termines la sesión:

```bash
docker stop lab-control-plane
```

Si alguna vez quieres empezar de cero, `kind delete cluster --name lab` y `kind create cluster --name lab`.

## Cierre

En `notas/fase-9/clase-102.md`:

1. Tres cosas que hace un orquestador y Compose no.
2. Nombra las piezas del *control plane* y qué hace cada una.
3. ¿Por qué volvió el pod de CoreDNS y no volvió `hola`?
4. **Repaso (clase 101, sin mirar):** ¿por qué la recreación desde cero de Vigía v5 necesita tres pasos y en ese orden?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Práctica:** con la descarga intacta, `sha256sum --check` imprime `kubectl: OK`. Si alguien la hubiera cambiado, `kubectl: FAILED` y un código de salida distinto de 0: la instalación no debe seguir.

**Cierre:**
1. Cualquier tres de estas:
   - reparte los contenedores entre varias máquinas y, si una muere, los recrea en otra;
   - mantiene el número de réplicas que pides;
   - actualiza poco a poco, sin cortar, y deja volver atrás;
   - da a cada servicio un nombre DNS y una IP estables que reparten el tráfico;
   - elige el nodo según los recursos libres.
2. **kube-apiserver**, la puerta por la que pasa todo; **etcd**, la base de datos del estado; **kube-scheduler**, que elige nodo para cada pod; **kube-controller-manager**, con los bucles de control. Y, en la nube, el **cloud-controller-manager**, que pide balanceadores y discos.
3. El de CoreDNS pertenece a un ReplicaSet. Su controlador vio 1 réplica donde quería 2 y creó otra. `hola` era un pod suelto: nadie quería que existiera, así que nadie lo recreó.
4. La instancia descarga su imagen de ECR al arrancar. Esa imagen solo puede existir después de crear el repositorio y el rol con el que el pipeline publica. Primero, con `-target`, el repositorio y el rol; luego, el pipeline publica la imagen; y al final, el `apply` completo.

**Reto 1:** los pods se reparten entre los dos *workers*, y ninguno cae en el *control plane*. El *control plane* tiene el *taint* `node-role.kubernetes.io/control-plane:NoSchedule`, que aparta los pods normales. En tu cluster `lab`, el único nodo es el *control plane* y no lleva ese *taint*: si no, nada podría correr.

**Reto 2:** etcd, el API, el *scheduler*, el *controller-manager*, kube-proxy y kindnet usan `hostNetwork: true`: la red del nodo. Tienen que funcionar **antes** de que exista la red de pods, que la crea precisamente kindnet.

**Reto 3:** `Always` (el valor por defecto), `OnFailure` y `Never`. Decide si el kubelet reinicia el contenedor cuando termina.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| control plane | plano de control: las piezas que gobiernan el cluster |
| worker node | nodo de trabajo: donde corren tus pods |
| desired state / actual state | estado deseado / estado real |
| reconciliation loop | bucle de reconciliación |
| static pod | pod estático, arrancado por el kubelet desde un archivo |

🎙️ *"Kubernetes is declarative: I describe the desired state in YAML, the API server stores it in etcd, and controllers keep reconciling the actual state towards it. That's why a pod owned by a ReplicaSet comes back when you delete it, and a bare pod doesn't."*

## Siguiente

[Clase 103 — Pods, YAML y etiquetas](clase-103-pods-yaml-y-etiquetas.md)
