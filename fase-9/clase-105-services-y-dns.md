# Clase 105 — Services y DNS del cluster

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

## Objetivo

- Explicar por qué nunca se apunta a la IP de un pod, y qué resuelve un Service.
- Distinguir los tipos de Service: ClusterIP, NodePort, LoadBalancer y *headless*.
- Seguir el camino de una petición: nombre DNS → IP del Service → EndpointSlice → pod.
- Instalar cloud-provider-kind para tener balanceadores en kind.
- Diagnosticar un Service que no responde: sin endpoints o con el puerto equivocado.

## Por qué importa

Los pods van y vienen con IPs nuevas: lo viste al borrar uno en la clase 104. Si la API de Vigía apuntara a la IP del pod de PostgreSQL, se rompería con el primer reinicio. Un **Service** da un nombre y una IP fijos a un grupo de pods y reparte el tráfico entre los que están listos.

Es el balanceador de la clase 77 y el DNS de la 31, dentro del cluster. Y "el Service no tiene endpoints" es una de las averías más comunes que vas a ver.

## Teoría

### El Service: un nombre y una IP fijos

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

### Los puertos

```yaml
ports:
  - name: http
    port: 80          # el puerto del Service: al que llaman los clientes
    targetPort: 9898  # el puerto del contenedor: donde escucha la aplicación
```

En un NodePort hay un tercero, `nodePort`, abierto en **cada nodo** (rango 30000–32767). `targetPort` puede ser también el **nombre** de un puerto del contenedor, y así un cambio de número no rompe el Service.

### Los tipos

| Tipo | Quién puede llegar | Para qué |
|------|--------------------|----------|
| `ClusterIP` (por defecto) | solo desde dentro del cluster | casi todo: la API llamando a la base de datos, un servicio a otro |
| `NodePort` | cualquiera que llegue a un nodo, en un puerto de 30000–32767 | pruebas; poco usado en producción |
| `LoadBalancer` | desde fuera, por un balanceador que crea la nube | exponer un servicio TCP. En AWS, un NLB: unos 16 USD al mes cada uno |
| *headless* (`clusterIP: None`) | sin IP propia: el DNS devuelve directamente las IPs de los pods | StatefulSets y bases de datos (clase 109) |

Para webs se usa sobre todo un único punto de entrada para muchos Services, el Ingress o el Gateway (clase 111).

### El DNS del pod

Cada pod lleva un `/etc/resolv.conf` así:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

Por eso, desde un pod de `default`, `web` basta: el *resolver* prueba `web.default.svc.cluster.local`. Desde otro namespace hace falta `web.default`. `ndots:5` hace que los nombres cortos prueben primero esos sufijos.

## Práctica guiada

Necesitas el Deployment `web` de la clase 104, con 3 réplicas de podinfo 6.15.0.

```bash
mkdir -p ~/my-devops-journey/labs/clase-105 && cd ~/my-devops-journey/labs/clase-105
kubectl get deployment web
```

### 1. Un ClusterIP (15 min)

`web-svc.yaml`:

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
```

`describe` muestra el selector y, en `Endpoints`, las tres IPs de los pods con el puerto 9898. Compáralas con `kubectl get pods -o wide`.

### 2. Un pod para mirar desde dentro (20 min)

La IP del Service solo existe dentro del cluster. Crea un pod de pruebas que se quede ahí:

```bash
kubectl run sonda --image=busybox:1.37 --restart=Never -- sleep 1d
kubectl exec sonda -- cat /etc/resolv.conf
kubectl exec sonda -- nslookup web.default.svc.cluster.local
```

🔮 **Predice:** ¿qué IP devolverá el DNS: la de un pod o la del Service?

La del Service, la misma de `kubectl get service web`. Ahora el nombre corto:

```bash
kubectl exec sonda -- nslookup web
```

Verás varios `NXDOMAIN` antes de la respuesta buena, y el comando termina con código 1. Es el `nslookup` de busybox enseñando los sufijos de `search` que probó y fallaron: la línea que importa es la de `Name: web.default.svc.cluster.local`.

¿Reparte de verdad? Pide la página seis veces y mira qué pod contesta:

```bash
for i in 1 2 3 4 5 6; do kubectl exec sonda -- wget -qO- http://web/ | grep hostname; done
```

Contestan pods distintos, sin un orden fijo: kube-proxy elige al azar.

Y `port-forward` también funciona con Services:

```bash
kubectl port-forward service/web 8080:80
```

En otra terminal, `curl -s localhost:8080/version`. `Ctrl+C` para cerrar.

### 3. Un NodePort (10 min)

`web-nodeport.yaml`:

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

Tu nodo es un contenedor de Docker en la red `kind`, y desde tu Ubuntu llegas a su IP. Si el primer `curl` no responde, repítelo a los pocos segundos: kube-proxy tarda un momento en programar el puerto.

### 4. Un LoadBalancer, y quién lo crea (25 min)

`web-lb.yaml`:

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

`<pending>`, para siempre. Kubernetes registra que quieres un balanceador, pero nadie lo crea: en la nube lo haría su *cloud-controller-manager* (clase 102), y en kind no hay nube. Sal con `Ctrl+C`.

**cloud-provider-kind** hace ese papel en kind: vigila los Services de tipo LoadBalancer y crea, por cada uno, un contenedor de Envoy (un proxy) en la red `kind`. Se ejecuta como un contenedor más:

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

En `docker ps` está el balanceador: un contenedor `kindccm-…` con la imagen `envoyproxy/envoy`. En AWS sería un NLB, con el mismo YAML.

`--restart unless-stopped` hace que cloud-provider-kind arranque solo con Docker. Las clases 111, 114 y 115 lo necesitan, así que déjalo instalado. Para apagarlo junto al cluster, `docker stop lab-control-plane cloud-provider-kind`. Al volver a arrancarlos, tarda un minuto en reconfigurar los balanceadores, y su IP puede cambiar: léela siempre con `kubectl get service`, como en un balanceador de la nube.

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

1. Escala `web` a 1 réplica y mira cómo cambian `Endpoints` y las respuestas del bucle de la práctica 2. Vuelve a 3 con `kubectl apply -f` de tu `web.yaml` de la clase 104.
2. Crea un Service *headless* (`clusterIP: None`) llamado `web-headless` con el mismo selector. ¿Qué devuelve `nslookup web-headless.default.svc.cluster.local` desde la sonda? ¿En qué se diferencia de `web`?
3. Crea un namespace `otro` (`kubectl create namespace otro`) y un pod sonda en él. ¿Funciona `wget -qO- http://web/` desde ahí? ¿Qué nombre necesitas? Borra el namespace al terminar.

## Destruir al terminar

```bash
kubectl delete -f web-nodeport.yaml -f web-lb.yaml
```

Deja `web`, el Service `web` y la `sonda`: la clase 106 empieza con ellos.

## Cierre

En `notas/fase-9/clase-105.md`:

1. ¿Por qué un cliente nunca debe usar la IP de un pod? ¿Qué le da un Service?
2. Un Service responde `Connection refused`. Escribe tus dos primeros comandos y qué buscas en cada uno.
3. ¿Por qué en kind el `EXTERNAL-IP` de un LoadBalancer se quedaba en `<pending>`, y quién lo resuelve en AWS?
4. **Repaso (clase 104, sin mirar):** ¿qué cambios en un Deployment disparan una actualización gradual y cuáles no?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Porque los pods son desechables: cada pod nuevo tiene otra IP. Un Service da un nombre DNS y una IP que no cambian, y reparte el tráfico entre los pods **listos** que cumplen su selector.
2. Primero, `kubectl describe service <nombre>` o `kubectl get endpointslices -l kubernetes.io/service-name=<nombre>`. Si no hay endpoints, el selector no casa con las etiquetas de ningún pod listo (compara con `kubectl get pods --show-labels`). Si los hay, compara `targetPort` con el puerto en el que escucha el contenedor.
3. El campo `EXTERNAL-IP` lo rellena quien crea el balanceador, que en la nube es el *cloud-controller-manager*. kind no tiene nube, y nadie lo creaba hasta que arrancaste cloud-provider-kind. En AWS lo hace la integración de EKS con Elastic Load Balancing (clase 115).
4. Los cambios en `spec.template` (la imagen, las variables, las sondas…) crean un ReplicaSet nuevo y una actualización gradual. Cambiar `replicas` solo escala.

**Reto 1:** con 1 réplica, `Endpoints` muestra una sola IP y siempre contesta el mismo pod. El Service sigue el estado real sin que lo toques.

**Reto 2:** devuelve **tres** direcciones, una por pod, en lugar de la IP del Service. Con un *headless* no hay balanceo de kube-proxy: el cliente recibe los pods y elige él. Lo usarás con el StatefulSet de la clase 109.

**Reto 3:** `http://web/` falla, porque la sonda de `otro` busca `web.otro.svc.cluster.local`. Necesitas `http://web.default/` (o el nombre completo).
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
