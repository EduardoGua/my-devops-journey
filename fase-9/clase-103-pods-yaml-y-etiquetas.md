# Clase 103 — Pods, YAML y etiquetas

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

## Objetivo

- Leer y escribir el YAML de un objeto de Kubernetes: `apiVersion`, `kind`, `metadata`, `spec` y `status`.
- Crear pods de forma declarativa con `kubectl apply -f`, e inspeccionarlos con `get -o`, `describe`, `logs`, `exec` y `port-forward`.
- Usar etiquetas y selectores para agrupar y encontrar objetos.
- Entender por qué un pod puede tener varios contenedores: los *init containers* y los ayudantes que comparten red y disco.

## Por qué importa

El pod es la pieza mínima de Kubernetes: todo lo que corre en un cluster corre dentro de pods. Los Deployments, los Jobs y los StatefulSets son, en el fondo, fábricas de pods.

Y las etiquetas son el pegamento de todo el sistema. Un Service encuentra sus pods por etiquetas, y un Deployment también. La mitad de las averías de la clase 112 son una etiqueta mal escrita.

## Teoría

### El pod

Un **pod** es uno o varios contenedores que comparten:
- **la red:** una sola IP, y entre ellos se hablan por `localhost`;
- **los volúmenes** que declare el pod.

Siempre corren juntos en el mismo nodo. Los pods son **desechables**: si uno muere, no se repara, se crea otro con otra IP. Por eso nunca apuntas a la IP de un pod (clase 105).

### La anatomía de un objeto

```yaml
apiVersion: v1          # qué versión de la API define este tipo
kind: Pod               # el tipo de objeto
metadata:               # quién es: nombre, namespace, etiquetas, anotaciones
  name: web
  labels:
    app: web
spec:                   # lo que TÚ quieres (el estado deseado)
  containers:
    - name: nginx
      image: nginx:1.29
status: {}              # lo que HAY: lo escribe Kubernetes, nunca tú
```

`spec` contra `status` es el modelo declarativo de la clase 102, campo a campo. Y no tienes que memorizar los campos: `kubectl explain pod.spec`, o `kubectl run … --dry-run=client -o yaml` para que kubectl te escriba el esqueleto.

### Fases del pod y estados del contenedor

| Fase del pod | Qué significa |
|--------------|---------------|
| `Pending` | aceptado, pero aún sin todos sus contenedores corriendo: esperando nodo, descargando la imagen o ejecutando los *init containers* |
| `Running` | asignado a un nodo y con al menos un contenedor en marcha |
| `Succeeded` | todos sus contenedores terminaron con código 0 y no se reiniciarán |
| `Failed` | todos terminaron, y alguno con error |
| `Unknown` | el nodo no responde |

Cada contenedor tiene además su **estado**: `Waiting`, `Running` o `Terminated`, con una razón (`ContainerCreating`, `CrashLoopBackOff`, `Completed`, `OOMKilled`…). La columna `STATUS` de `kubectl get pods` muestra lo más informativo de los dos.

### Etiquetas, selectores y anotaciones

Las **etiquetas** (*labels*) son pares clave-valor para **identificar y agrupar**:
- `app: web`, `entorno: lab`;
- las recomendadas por Kubernetes: `app.kubernetes.io/name: vigia`, `app.kubernetes.io/part-of: vigia`.

Los **selectores** filtran por etiquetas:

| Selector | Elige |
|----------|-------|
| `app=web` | los que tienen `app` igual a `web` |
| `app!=web` | los que no |
| `entorno in (lab,prod)` | `entorno` vale `lab` o `prod` |
| `app,entorno` | tienen las dos claves, con cualquier valor |

Las **anotaciones** también son clave-valor, pero no sirven para seleccionar. Guardan información para personas o herramientas: quién lo creó, el motivo de un cambio (clase 104), la configuración de un controlador.

### Varios contenedores en un pod

- **Init containers:** corren **antes** que los demás, uno tras otro, y cada uno debe terminar bien. Sirven para preparar: esperar a una base de datos, generar un archivo, aplicar una migración.
- **Ayudantes** (*sidecars*): corren **junto** al principal, compartiendo red y volúmenes. Por ejemplo, uno que recoge logs o refresca un archivo.

La regla: un pod = **una** aplicación. Dos aplicaciones distintas, como la API y la base de datos, van en pods distintos, para poder escalarlas y actualizarlas por separado.

## Práctica guiada

Trabaja en `~/my-devops-journey/labs/clase-103` con el cluster de la clase 102 encendido (`docker start lab-control-plane` si lo apagaste).

```bash
mkdir -p ~/my-devops-journey/labs/clase-103 && cd ~/my-devops-journey/labs/clase-103
```

### 1. Que kubectl escriba el esqueleto (10 min)

```bash
kubectl run web --image=nginx:1.29 --port=80 --dry-run=client -o yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: web
  name: web
spec:
  containers:
  - image: nginx:1.29
    name: web
    ports:
    - containerPort: 80
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

`--dry-run=client` no crea nada: solo imprime el objeto. Es el truco para no escribir YAML de memoria. Ahora escribe tu versión, más limpia, en `web.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
    entorno: lab
spec:
  containers:
    - name: nginx
      image: nginx:1.29
      ports:
        - containerPort: 80
```

### 2. Aplicar e inspeccionar (20 min)

```bash
kubectl apply -f web.yaml
kubectl get pods -o wide
kubectl get pod web -o yaml | less
```

En `-o yaml` aparece todo lo que **añadió Kubernetes**: valores por defecto en `spec` y la sección `status` entera. Busca `podIP`, `phase` y `containerStatuses`.

Para sacar un solo dato, `jsonpath`:

```bash
kubectl get pod web -o jsonpath='{.status.podIP} {.status.phase} {.spec.nodeName}{"\n"}'
```

Entra, mira y sal:

```bash
kubectl exec web -- nginx -v
kubectl exec -it web -- bash        # dentro: ls /usr/share/nginx/html, exit
kubectl logs web --tail=5
```

Es `docker exec` y `docker logs` (clase 57), con el pod en lugar del contenedor.

Para hablar con el pod desde tu Ubuntu, `port-forward` abre un túnel por el API:

```bash
kubectl port-forward pod/web 8080:80
```

En **otra terminal**, `curl -s localhost:8080 | grep title`. Vuelve a la primera y sal con `Ctrl+C`. Sirve para depurar; para exponer algo de verdad usarás Services (105) y Gateways (111).

### 3. Etiquetas y selectores (15 min)

```bash
kubectl get pods --show-labels
kubectl label pod web version=1
kubectl get pods -L entorno,version
kubectl get pods -l app=web
kubectl get pods -l 'entorno in (lab,prod)'
kubectl get pods -l app!=web
```

🔮 **Predice:** ¿qué imprime el último?

`No resources found in default namespace.`: el único pod tiene `app=web`. `-L` muestra etiquetas como columnas, y `-l` filtra. Recuerda las dos: las usarás a diario.

### 4. Un pod con ayudante y preparación (20 min)

`con-ayudante.yaml`: un *init container* escribe una página antes de arrancar, nginx la sirve, y un ayudante la reescribe con la hora cada 5 segundos. Los tres comparten un volumen `emptyDir`, una carpeta vacía que vive lo que vive el pod (clase 109).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: con-ayudante
  labels:
    app: reloj
spec:
  initContainers:
    - name: preparar
      image: busybox:1.37
      command: ["sh", "-c", "echo '<h1>Arrancando…</h1>' > /html/index.html; sleep 5"]
      volumeMounts:
        - name: html
          mountPath: /html
  containers:
    - name: nginx
      image: nginx:1.29
      volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
    - name: reloj
      image: busybox:1.37
      command: ["sh", "-c", "while true; do date > /html/index.html; sleep 5; done"]
      volumeMounts:
        - name: html
          mountPath: /html
  volumes:
    - name: html
      emptyDir: {}
```

🔮 **Predice:** ¿qué dirá la columna `STATUS` durante los primeros 5 segundos? ¿Y la columna `READY` cuando todo arranque?

```bash
kubectl apply -f con-ayudante.yaml
kubectl get pod con-ayudante -w
```

Primero `Init:0/1` (falta uno de un *init container*), luego `PodInitializing` y al final `Running` con `READY 2/2`: dos contenedores, los dos listos. El *init* ya terminó y no cuenta.

```bash
kubectl exec con-ayudante -c nginx -- cat /usr/share/nginx/html/index.html
kubectl exec con-ayudante -c reloj -- wget -qO- http://localhost:80
kubectl logs con-ayudante
```

- La primera orden muestra la hora: el ayudante escribe en el mismo volumen que sirve nginx.
- La segunda llega a nginx desde **otro** contenedor por `localhost`: comparten red.
- La tercera avisa `Defaulted container "nginx" out of: nginx, reloj, preparar (init)`: con varios contenedores, `-c` elige cuál.

## Rómpelo

**1. Un campo mal escrito.** Cambia `image:` por `imagen:` en una copia de `web.yaml` (con otro `name:`) y aplícala:

```
Error from server (BadRequest): error when creating "web-mal.yaml": Pod in version "v1" cannot be handled as a Pod: strict decoding error: unknown field "spec.containers[0].imagen"
```

El API valida cada campo y rechaza los que no conoce. Lee siempre el mensaje entero: dice el campo exacto. `kubectl apply --dry-run=server -f archivo.yaml` hace la misma validación sin crear nada.

**2. Cambiar un pod que ya existe.** En `web.yaml`, cambia `containerPort: 80` por `8080` y aplica:

```
The Pod "web" is invalid: spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`, `spec.initContainers[*].image`, `spec.activeDeadlineSeconds`, …
```

Casi todo el `spec` de un pod es **inmutable**. Vuelve a `80`, y ahora cambia la imagen a `nginx:1.30`:

```bash
kubectl apply -f web.yaml
kubectl get pod web
kubectl describe pod web | grep -A10 Events
```

Esto sí lo deja: el contenedor se reinicia con la imagen nueva (`RESTARTS 1`, y el evento `Container nginx definition changed, will be restarted`). Pero mientras tanto el pod no da servicio. Actualizar sin cortar es trabajo del Deployment (clase 104).

**3. Borra `web`.** No vuelve, como `hola` en la clase 102.

## Reto

1. **Dos contenedores en el mismo puerto.** Crea un pod `choque` con dos contenedores `nginx:1.29` (nombres `uno` y `dos`). ¿Qué estado tiene a los 30 segundos? ¿Qué dice `kubectl logs choque -c dos`? Explica la causa con lo que sabes de la red de un pod.
2. Con `kubectl explain`, averigua qué hace `spec.terminationGracePeriodSeconds` y cuál es su valor por defecto. ¿Con qué clase de la fase 1 y con qué Rómpelo de la fase 5 lo relacionas?
3. Saca con `jsonpath` el nombre y la imagen de cada contenedor de `con-ayudante`, uno por línea. (Pista: `{range .spec.containers[*]}…{end}`.)

Al terminar: `kubectl delete pod --all`.

## Cierre

En `notas/fase-9/clase-103.md`:

1. ¿Qué comparten los contenedores de un pod? ¿Y qué **no** debería compartir nunca un pod?
2. ¿Quién escribe `spec` y quién escribe `status`?
3. ¿Para qué sirven las etiquetas, y en qué se diferencian de las anotaciones?
4. **Repaso (clase 102, sin mirar):** ¿qué pieza eligió el nodo de tu pod y cuál descargó su imagen?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. La red (una IP, `localhost` entre ellos) y los volúmenes que declara el pod, y siempre corren en el mismo nodo. No debería juntar dos **aplicaciones** distintas, como la API y su base de datos: cada una necesita escalar, actualizarse y fallar por su cuenta.
2. `spec`, tú: el estado deseado. `status`, Kubernetes: el estado real, que actualizan el kubelet y los controladores.
3. Las etiquetas identifican y agrupan, y los selectores las usan para elegir objetos. Así un Service encuentra sus pods y un Deployment los suyos. Las anotaciones guardan información que no se usa para seleccionar: motivos, autores, configuración de herramientas.
4. El *scheduler* (`default-scheduler` en los eventos) eligió el nodo, y el kubelet de ese nodo descargó la imagen y arrancó el contenedor.

**Reto 1:** a los pocos segundos, `Error` y después `CrashLoopBackOff`, con `READY 1/2`. El log de `dos` dice `bind() to 0.0.0.0:80 failed (98: Address already in use)`. Los dos contenedores comparten **una** red: dos procesos no pueden escuchar en el mismo puerto de la misma IP, igual que en tu Ubuntu (clase 29).

**Reto 2:** los segundos que Kubernetes espera entre el SIGTERM y el SIGKILL al parar el pod: 30 por defecto. Es la parada ordenada de la clase 11 y el `docker stop` del Rómpelo 2 de la clase 63, que mataba con SIGKILL a los 10 segundos.

**Reto 3:**
```bash
kubectl get pod con-ayudante -o jsonpath='{range .spec.containers[*]}{.name} {.image}{"\n"}{end}'
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| manifest | manifiesto: el archivo YAML que describe un objeto |
| label / selector | etiqueta / selector |
| annotation | anotación |
| init container / sidecar | contenedor de inicio / contenedor ayudante |
| immutable field | campo inmutable |

🎙️ *"A pod is one or more containers that share a network namespace and volumes. I never create bare pods in production: I write the manifest, apply it, and let a controller own it. Labels are what tie Services and Deployments to their pods."*

## Siguiente

[Clase 104 — Deployments: escalar, actualizar y volver atrás](clase-104-deployments.md)
