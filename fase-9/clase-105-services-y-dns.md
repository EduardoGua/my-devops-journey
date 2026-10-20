# Clase 105 — Services y DNS del cluster

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

> 💡 **La idea de hoy:** los pods cambian de IP cada vez que se recrean, así que nadie apunta a un pod: se apunta a un **Service**, que da un nombre DNS y una IP fijos a un grupo de pods (elegidos por etiquetas) y reparte el tráfico entre los que están listos. Según su tipo, se llega a él solo desde dentro (ClusterIP), por un puerto de cada nodo (NodePort) o por un balanceador (LoadBalancer).

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El Deployment `web` con 3 réplicas de podinfo, y que un pod nuevo tiene otra IP (clase 104).
> - Etiquetas, selectores, `exec` y `port-forward` (clase 103); el cloud-controller-manager (clase 102).
> - El DNS y `/etc/resolv.conf` (clase 31); los balanceadores de AWS (clase 77).
> - `Connection refused` cuando nadie escucha en un puerto (clase 63, avería 5).

> 🔤 **Palabras nuevas de hoy:**
> - **Service**: un nombre y una IP fijos para un grupo de pods.
> - **EndpointSlice**: la lista de pods **listos** que cumplen el selector de un Service.
> - **`port` / `targetPort` / `nodePort`**: el puerto del Service / el del contenedor / el de cada nodo.
> - **ClusterIP, NodePort, LoadBalancer**: los tipos de Service, de más cerrado a más abierto.
> - **headless** (`clusterIP: None`): un Service sin IP propia; el DNS devuelve las IPs de los pods.
> - **cloud-provider-kind**: el programa que crea balanceadores en kind, donde no hay nube.

## Objetivo

- Explicar por qué nunca se apunta a la IP de un pod, y qué resuelve un Service.
- Distinguir los tipos de Service: ClusterIP, NodePort, LoadBalancer y *headless*.
- Seguir el camino de una petición: nombre DNS → IP del Service → EndpointSlice → pod.
- Instalar cloud-provider-kind para tener balanceadores en kind.
- Diagnosticar un Service que no responde: sin endpoints o con el puerto equivocado.

## Por qué importa

Los pods van y vienen con IPs nuevas: lo viste al borrar uno en la clase 104. Si la API de Vigía apuntara a la IP del pod de PostgreSQL, se rompería con el primer reinicio. Un **Service** da un nombre y una IP fijos a un grupo de pods y reparte el tráfico entre los que están listos.

Es el balanceador de la clase 77 y el DNS de la 31, dentro del cluster. Y "el Service no tiene endpoints" es una de las averías más comunes que vas a ver.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan el Deployment `web`.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Necesitas el Deployment `web` de la clase 104, con 3 réplicas de podinfo 6.15.0:

```bash
mkdir -p ~/my-devops-journey/labs/clase-105 && cd ~/my-devops-journey/labs/clase-105
kubectl get deployment web
```

## Las piezas

### Pieza 1 — El Service: un nombre y una IP fijos

```
pod cliente ──► web.default.svc.cluster.local ──DNS──► 10.96.204.36 (IP del Service)
                                                            │ kube-proxy reparte
                                       ┌────────────────────┼────────────────────┐
                                    pod A :9898          pod B :9898          pod C :9898
```

- El Service elige sus pods con un **selector** de etiquetas (clase 103).
- Kubernetes mantiene la lista de pods **listos** que cumplen el selector en objetos **EndpointSlice**.
- **kube-proxy**, en cada nodo, programa reglas para que lo que llega a la IP del Service salga hacia uno de esos pods.
- **CoreDNS** da a cada Service un nombre: `<servicio>.<namespace>.svc.cluster.local`.

Los puertos:

```yaml
ports:
  - name: http
    port: 80          # el puerto del Service: al que llaman los clientes
    targetPort: 9898  # el puerto del contenedor: donde escucha la aplicación
```

`targetPort` puede ser también el **nombre** de un puerto del contenedor, y así un cambio de número no rompe el Service.

**Pruébalo.** `web-svc.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 9898
```

```bash
kubectl apply -f web-svc.yaml
kubectl get service web
kubectl describe service web
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl get pods -o wide
```

👀 **Qué deberías ver:** el Service `web` de tipo `ClusterIP`, con una IP `10.96.x.x` y el puerto `80/TCP`. `describe` muestra el selector `app=web` y, en `Endpoints`, las tres IPs de los pods con el puerto 9898: las mismas que da `get pods -o wide`.

✋ **Sin mirar:** ¿qué hay en un EndpointSlice, y quién lo mantiene al día?

<details>
<summary>Comprueba</summary>

Las IPs y puertos de los pods **listos** que cumplen el selector del Service. Lo mantiene Kubernetes, sin que lo toques: si un pod muere o deja de estar listo, sale de la lista.
</details>

**En resumen:** el Service elige pods por etiquetas; el EndpointSlice es la lista de los que están listos.

### Pieza 2 — El DNS del cluster

Cada pod lleva un `/etc/resolv.conf` así:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

Por eso, desde un pod de `default`, `web` basta: el *resolver* prueba `web.default.svc.cluster.local`. Desde otro namespace hace falta `web.default`. `ndots:5` hace que los nombres cortos prueben primero esos sufijos.

**Pruébalo.** La IP del Service solo existe dentro del cluster. Crea un pod de pruebas que se quede ahí:

```bash
kubectl run sonda --image=busybox:1.37 --restart=Never -- sleep 1d
kubectl exec sonda -- cat /etc/resolv.conf
kubectl exec sonda -- nslookup web.default.svc.cluster.local
```

🔮 **Predice:** ¿qué IP devolverá el DNS: la de un pod o la del Service?

👀 **Qué deberías ver:** el `resolv.conf` de arriba, y la IP del Service, la misma de `kubectl get service web`. Ahora el nombre corto:

```bash
kubectl exec sonda -- nslookup web
```

Verás varios `NXDOMAIN` antes de la respuesta buena, y el comando termina con código 1. Es el `nslookup` de busybox enseñando los sufijos de `search` que probó y fallaron: la línea que importa es la de `Name: web.default.svc.cluster.local`.

✋ **Sin mirar:** ¿qué nombre completo tiene el Service `db` del namespace `vigia`?

<details>
<summary>Comprueba</summary>

`db.vigia.svc.cluster.local`. Desde un pod de `vigia` basta `db`; desde otro namespace, `db.vigia`.
</details>

**En resumen:** `<servicio>.<namespace>.svc.cluster.local`; el `search` del pod completa los nombres cortos.

### Pieza 3 — El reparto

kube-proxy no sigue un orden fijo: elige un pod al azar entre los endpoints listos. Y `port-forward` también funciona con Services: elige uno de sus pods.

**Pruébalo.** Pide la página seis veces y mira qué pod contesta:

```bash
for i in 1 2 3 4 5 6; do kubectl exec sonda -- wget -qO- http://web/ | grep hostname; done
kubectl port-forward service/web 8080:80
```

En otra terminal, `curl -s localhost:8080/version`. `Ctrl+C` para cerrar.

👀 **Qué deberías ver:** seis líneas `"hostname": "web-775c4dfd56-…"` con pods distintos, sin un orden fijo. Y el `curl` devuelve la versión `6.15.0`.

✋ **Sin mirar:** si uno de los tres pods deja de estar listo, ¿seguirá recibiendo peticiones del Service?

<details>
<summary>Comprueba</summary>

No: sale del EndpointSlice, y kube-proxy solo reparte entre los que quedan.
</details>

**En resumen:** el Service reparte entre los pods listos, al azar.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Apaga el cluster con `docker stop lab-control-plane`; el Service y la `sonda` volverán con él.

### Pieza 4 — Los tipos de Service: NodePort

| Tipo | Quién puede llegar | Para qué |
|------|--------------------|----------|
| `ClusterIP` (por defecto) | solo desde dentro del cluster | casi todo: la API llamando a la base de datos, un servicio a otro |
| `NodePort` | cualquiera que llegue a un nodo, en un puerto de 30000–32767 | pruebas; poco usado en producción |
| `LoadBalancer` | desde fuera, por un balanceador que crea la nube | exponer un servicio TCP. En AWS, un NLB: unos 16 USD al mes cada uno |
| *headless* (`clusterIP: None`) | sin IP propia: el DNS devuelve directamente las IPs de los pods | StatefulSets y bases de datos (clase 109) |

En un NodePort hay un tercer puerto, `nodePort`, abierto en **cada nodo**. Para webs se usa sobre todo un único punto de entrada para muchos Services, el Ingress o el Gateway (clase 111).

**Pruébalo.** `web-nodeport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 9898
      nodePort: 30080
```

```bash
kubectl apply -f web-nodeport.yaml
NODO=$(kubectl get node lab-control-plane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "$NODO"
curl -s "http://$NODO:30080/version"
```

👀 **Qué deberías ver:** una IP como `172.18.0.2` y la versión de podinfo. Tu nodo es un contenedor de Docker en la red `kind`, y desde tu Ubuntu llegas a su IP. Si el primer `curl` no responde, repítelo a los pocos segundos: kube-proxy tarda un momento en programar el puerto.

✋ **Sin mirar:** en un NodePort, ¿qué es el 80, el 9898 y el 30080?

<details>
<summary>Comprueba</summary>

El 80 es el puerto del Service (dentro del cluster); el 9898, el del contenedor (`targetPort`); el 30080, el que se abre en cada nodo (`nodePort`).
</details>

**En resumen:** ClusterIP por dentro, NodePort por un puerto de cada nodo.

### Pieza 5 — LoadBalancer, y quién lo crea

Un Service de tipo `LoadBalancer` le pide a la nube un balanceador. Quien lo crea es el *cloud-controller-manager* (clase 102). En kind no hay nube: lo hace **cloud-provider-kind**, que vigila esos Services y crea, por cada uno, un contenedor de Envoy (un proxy) en la red `kind`.

**Pruébalo.** `web-lb.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 9898
```

```bash
kubectl apply -f web-lb.yaml
kubectl get service web-lb -w
```

🔮 **Predice:** ¿qué saldrá en `EXTERNAL-IP`, y cuánto tardará?

👀 **Qué deberías ver:** `<pending>`, para siempre. Kubernetes registra que quieres un balanceador, pero nadie lo crea. Sal con `Ctrl+C`.

Arranca cloud-provider-kind, como un contenedor más:

```bash
docker run -d --name cloud-provider-kind --restart unless-stopped --network kind \
  -v /var/run/docker.sock:/var/run/docker.sock \
  registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.12.0
```

> 🔐 Montar `/var/run/docker.sock` le da control total de tu Docker, que equivale a ser root en tu máquina: lo necesita para crear los contenedores de los balanceadores. Por eso usas la imagen oficial del proyecto Kubernetes (`registry.k8s.io`) con la versión fijada, y no cualquier imagen que lo pida.

```bash
kubectl get service web-lb -w
```

En unos segundos, `EXTERNAL-IP` muestra una IP de la red `kind`. Sal con `Ctrl+C`:

```bash
LB=$(kubectl get service web-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s "http://$LB/version"
docker ps --format '{{.Names}}  {{.Image}}'
```

👀 **Qué deberías ver:** la versión de podinfo y, en `docker ps`, el balanceador: un contenedor `kindccm-…` con la imagen `envoyproxy/envoy`. En AWS sería un NLB, con el mismo YAML.

`--restart unless-stopped` hace que cloud-provider-kind arranque solo con Docker. Las clases 111, 114 y 115 lo necesitan, así que déjalo instalado. Para apagarlo junto al cluster, `docker stop lab-control-plane cloud-provider-kind`. Al volver a arrancarlos, tarda un minuto en reconfigurar los balanceadores, y su IP puede cambiar: léela siempre con `kubectl get service`, como en un balanceador de la nube.

✋ **Sin mirar:** ¿por qué el `EXTERNAL-IP` se quedaba en `<pending>` antes de arrancar cloud-provider-kind?

<details>
<summary>Comprueba</summary>

Porque ese campo lo rellena quien crea el balanceador, el *cloud-controller-manager*, y en kind no había ninguno.
</details>

**En resumen:** LoadBalancer pide un balanceador a la nube; en kind lo crea cloud-provider-kind.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `kind: Service` + `selector` + `ports: [{port, targetPort}]` | un Service ClusterIP |
| `type: NodePort` + `nodePort: 30080` | un puerto en cada nodo |
| `type: LoadBalancer` | un balanceador de la nube (o de cloud-provider-kind) |
| `clusterIP: None` | un Service *headless* |
| `kubectl get endpointslices -l kubernetes.io/service-name=web` | los pods detrás del Service |
| `kubectl describe service web \| grep Endpoints` | lo mismo, más corto |
| `kubectl run sonda --image=busybox:1.37 --restart=Never -- sleep 1d` | un pod para probar desde dentro |
| `kubectl exec sonda -- nslookup web` · `wget -qO- http://web/` | probar el DNS y el Service |
| `kubectl port-forward service/web 8080:80` | un túnel a uno de sus pods |
| `docker stop lab-control-plane cloud-provider-kind` | apagarlo todo |

## Rómpelo

**1. Una errata en el selector.** Copia `web-svc.yaml` como `errata.yaml`, cambia `name: web` por `name: web-errata` y el selector a `app: wev`:

```bash
kubectl apply -f errata.yaml
kubectl get endpointslices -l kubernetes.io/service-name=web-errata
kubectl describe service web-errata | grep Endpoints
kubectl exec sonda -- wget -qO- -T 3 http://web-errata/
```

```
wget: can't connect to remote host (10.96.19.226): Connection refused
```

El Service existe y el DNS lo resuelve, pero no tiene endpoints: ningún pod cumple el selector. `Connection refused` desde un Service casi siempre significa eso. Lo primero que miras: `Endpoints`.

**2. El puerto equivocado.** Copia `web-svc.yaml` como `puerto.yaml`, con `name: web-puerto` y `targetPort: 8080`:

```bash
kubectl apply -f puerto.yaml
kubectl get endpointslices -l kubernetes.io/service-name=web-puerto
kubectl exec sonda -- wget -qO- -T 3 http://web-puerto/
```

Ahora **sí** hay endpoints, con el puerto 8080, y aun así `Connection refused`: los pods existen, pero nadie escucha en ese puerto. Es la avería 5 de la clase 63, en Kubernetes.

Borra los dos: `kubectl delete -f errata.yaml -f puerto.yaml`.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Escala `web` a 1 réplica y mira cómo cambian `Endpoints` y las respuestas del bucle de la pieza 3. Vuelve a 3 con `kubectl apply -f` de tu `web.yaml` de la clase 104.

> 🧩 **Ejemplo resuelto:** la pieza 3: con 3 réplicas, el bucle mostraba pods distintos.

**Ahora tú, con huecos:** `kubectl scale deployment web --replicas=____`, `kubectl describe service web | grep ____` y el bucle. Completa: «Con 1 réplica, `Endpoints` muestra ____ IP y siempre contesta ____. El Service sigue el estado real sin que…».

<details>
<summary>Pista</summary>

Dale unos segundos tras el `scale`: los pods que sobran tienen que terminar antes de salir de la lista.
</details>

**2.** Crea un Service *headless* llamado `web-headless` con el mismo selector. ¿Qué devuelve `nslookup web-headless.default.svc.cluster.local` desde la sonda? ¿En qué se diferencia de `web`?

> 🧩 **Ejemplo resuelto:** la pieza 2: `nslookup web.default.svc.cluster.local` devolvía **una** IP, la del Service.

**Ahora tú, con huecos:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: ____
  selector:
    app: ____
  ports:
    - port: 80
      targetPort: 9898
```
Completa: «Devuelve ____ direcciones, una por ____. No hay balanceo de kube-proxy: el cliente…».

<details>
<summary>Pista</summary>

Compara las IPs que devuelve con las de `kubectl get pods -o wide`.
</details>

**3.** Crea un namespace `otro` y un pod sonda en él. ¿Funciona `wget -qO- http://web/` desde ahí? ¿Qué nombre necesitas? Borra el namespace al terminar.

> 🧩 **Ejemplo resuelto:** la pieza 2: el `search` de la sonda de `default` empieza por `default.svc.cluster.local`, y por eso `web` basta.

**Ahora tú, con huecos:** `kubectl create namespace otro`, `kubectl -n otro run sonda --image=busybox:1.37 --restart=Never -- sleep 1d` y `kubectl -n otro exec sonda -- wget -qO- -T 3 http://web/`. Completa: «Falla porque la sonda de `otro` busca ____. Necesito ____».

<details>
<summary>Pista</summary>

Mira el `resolv.conf` de la sonda nueva: `kubectl -n otro exec sonda -- cat /etc/resolv.conf`. Al terminar, `kubectl delete namespace otro` borra también su sonda.
</details>

## Destruir al terminar

```bash
kubectl delete -f web-nodeport.yaml -f web-lb.yaml
```

Deja `web`, el Service `web` y la `sonda`: la clase 106 empieza con ellos.

## Cierre

En `notas/fase-9/clase-105.md`:

1. ¿Por qué un cliente nunca debe usar la IP de un pod? ¿Qué le da un Service? *(2 líneas. Empieza así: «Porque los pods son desechables: cada pod nuevo…»)*
2. Un Service responde `Connection refused`. Escribe tus dos primeros comandos y qué buscas en cada uno. *(2 líneas, una por comando. Empieza así: «`kubectl describe service <nombre>`: miro si hay endpoints…»)*
3. ¿Por qué en kind el `EXTERNAL-IP` de un LoadBalancer se quedaba en `<pending>`, y quién lo resuelve en AWS? *(2 líneas. Empieza así: «Porque ese campo lo rellena quien crea el balanceador…»)*
4. **Repaso (clase 104, sin mirar):** ¿qué cambios en un Deployment disparan una actualización gradual y cuáles no? *(1–2 líneas. Empieza así: «Los cambios en `spec.template`…»)*

Después, escríbeme `examíname clase-105`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Porque los pods son desechables: cada pod nuevo tiene otra IP. Un Service da un nombre DNS y una IP que no cambian, y reparte el tráfico entre los pods **listos** que cumplen su selector.
2. Primero, `kubectl describe service <nombre>` o `kubectl get endpointslices -l kubernetes.io/service-name=<nombre>`. Si no hay endpoints, el selector no casa con las etiquetas de ningún pod listo (compara con `kubectl get pods --show-labels`). Si los hay, compara `targetPort` con el puerto en el que escucha el contenedor.
3. El campo `EXTERNAL-IP` lo rellena quien crea el balanceador, que en la nube es el *cloud-controller-manager*. kind no tiene nube, y nadie lo creaba hasta que arrancaste cloud-provider-kind. En AWS lo hace la integración de EKS con Elastic Load Balancing (clase 115).
4. Los cambios en `spec.template` (la imagen, las variables, las sondas…) crean un ReplicaSet nuevo y una actualización gradual. Cambiar `replicas` solo escala.

**Reto 1:** `--replicas=1` y `grep Endpoints`. Con 1 réplica, `Endpoints` muestra una sola IP y siempre contesta el mismo pod. El Service sigue el estado real sin que lo toques.

**Reto 2:** `clusterIP: None` y `app: web`. Devuelve **tres** direcciones, una por pod, en lugar de la IP del Service. Con un *headless* no hay balanceo de kube-proxy: el cliente recibe los pods y elige él. Lo usarás con el StatefulSet de la clase 109.

**Reto 3:** `http://web/` falla, porque la sonda de `otro` busca `web.otro.svc.cluster.local`. Necesitas `http://web.default/` (o el nombre completo, `web.default.svc.cluster.local`).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| service discovery | descubrimiento de servicios |
| endpoints / EndpointSlice | los pods detrás de un Service |
| port / targetPort / nodePort | puerto del Service / del contenedor / del nodo |
| headless service | Service sin IP propia |
| external IP pending | IP externa pendiente: nadie ha creado el balanceador |

🎙️ *"When a Service returns connection refused, I check its endpoints first. No endpoints means the selector doesn't match any ready pod; endpoints but still refused means the targetPort doesn't match the port the container listens on."*

## Siguiente

[Clase 106 — ConfigMaps y Secrets](clase-106-configmaps-y-secrets.md)
