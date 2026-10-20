# Clase 103 — Pods, YAML y etiquetas

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Kubernetes desde cero

> 💡 **La idea de hoy:** todo lo que corre en Kubernetes corre en **pods**, y cada objeto se describe en un YAML con cuatro partes: qué tipo es (`apiVersion`, `kind`), quién es (`metadata`), qué quieres (`spec`) y qué hay (`status`, que escribe Kubernetes). Las **etiquetas** son el pegamento: los selectores las usan para encontrar objetos.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Tu cluster `lab`, `describe`, `logs`, `explain` y por qué un pod suelto no vuelve (clase 102).
> - YAML (clase 47); `docker exec` y `docker logs` (clase 57).
> - Que dos procesos no pueden escuchar en el mismo puerto (clase 29); las señales y la parada ordenada (clase 11).
> - `jq` y los caminos dentro de un JSON (clase 47).

> 🔤 **Palabras nuevas de hoy:**
> - **manifiesto**: el archivo YAML que describe un objeto.
> - **`spec` / `status`**: el estado deseado, que escribes tú / el estado real, que escribe Kubernetes.
> - **fase del pod**: `Pending`, `Running`, `Succeeded`, `Failed` o `Unknown`.
> - **etiqueta** (*label*) y **selector**: pares clave-valor para agrupar, y el filtro que los elige.
> - **anotación**: un par clave-valor que no sirve para seleccionar; información para personas o herramientas.
> - ***init container*** y **ayudante** (*sidecar*): un contenedor que prepara antes / uno que acompaña al principal.
> - **`jsonpath`**: sacar un solo dato de un objeto con `kubectl get -o jsonpath=…`.

## Objetivo

- Leer y escribir el YAML de un objeto de Kubernetes: `apiVersion`, `kind`, `metadata`, `spec` y `status`.
- Crear pods de forma declarativa con `kubectl apply -f`, e inspeccionarlos con `get -o`, `describe`, `logs`, `exec` y `port-forward`.
- Usar etiquetas y selectores para agrupar y encontrar objetos.
- Entender por qué un pod puede tener varios contenedores: los *init containers* y los ayudantes que comparten red y disco.

## Por qué importa

El pod es la pieza mínima de Kubernetes: todo lo que corre en un cluster corre dentro de pods. Los Deployments, los Jobs y los StatefulSets son, en el fondo, fábricas de pods.

Y las etiquetas son el pegamento de todo el sistema. Un Service encuentra sus pods por etiquetas, y un Deployment también. La mitad de las averías de la clase 112 son una etiqueta mal escrita.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Con el cluster de la clase 102 encendido (`docker start lab-control-plane` si lo apagaste):

```bash
mkdir -p ~/my-devops-journey/labs/clase-103 && cd ~/my-devops-journey/labs/clase-103
```

## Las piezas

### Pieza 1 — El pod y su YAML

Un **pod** es uno o varios contenedores que comparten:
- **la red:** una sola IP, y entre ellos se hablan por `localhost`;
- **los volúmenes** que declare el pod.

Siempre corren juntos en el mismo nodo. Los pods son **desechables**: si uno muere, no se repara, se crea otro con otra IP. Por eso nunca apuntas a la IP de un pod (clase 105).

Cada objeto tiene la misma anatomía:

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

**Pruébalo:**

```bash
kubectl run web --image=nginx:1.29 --port=80 --dry-run=client -o yaml
```

👀 **Qué deberías ver:**

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

✋ **Sin mirar:** ¿por qué nunca escribes la sección `status`?

<details>
<summary>Comprueba</summary>

Porque es el estado **real**, y lo escriben el kubelet y los controladores. Tú solo escribes lo que quieres, en `spec`.
</details>

**En resumen:** `apiVersion`, `kind`, `metadata` y `spec` los escribes tú; `--dry-run=client -o yaml` te da el esqueleto.

### Pieza 2 — Aplicar e inspeccionar: la fase del pod

| Fase del pod | Qué significa |
|--------------|---------------|
| `Pending` | aceptado, pero aún sin todos sus contenedores corriendo: esperando nodo, descargando la imagen o ejecutando los *init containers* |
| `Running` | asignado a un nodo y con al menos un contenedor en marcha |
| `Succeeded` | todos sus contenedores terminaron con código 0 y no se reiniciarán |
| `Failed` | todos terminaron, y alguno con error |
| `Unknown` | el nodo no responde |

Cada contenedor tiene además su **estado**: `Waiting`, `Running` o `Terminated`, con una razón (`ContainerCreating`, `CrashLoopBackOff`, `Completed`, `OOMKilled`…). La columna `STATUS` de `kubectl get pods` muestra lo más informativo de los dos.

**Pruébalo:**

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

👀 **Qué deberías ver:** `pod/web created`; en `-o yaml`, `phase: Running` y, en `containerStatuses`, `ready: true` y `state: running`. El `jsonpath` imprime una línea como `10.244.0.7 Running lab-control-plane`.

✋ **Sin mirar:** un pod está descargando su imagen. ¿En qué fase está?

<details>
<summary>Comprueba</summary>

`Pending`: aceptado, pero sus contenedores aún no corren. El contenedor está en `Waiting`, con la razón `ContainerCreating`.
</details>

**En resumen:** la fase dice cómo va el pod; el estado de cada contenedor dice por qué.

### Pieza 3 — Entrar y hablar con el pod

`kubectl exec` y `kubectl logs` son `docker exec` y `docker logs` (clase 57), con el pod en lugar del contenedor. Para hablar con el pod desde tu Ubuntu, `kubectl port-forward` abre un túnel por el API. Sirve para depurar; para exponer algo de verdad usarás Services (105) y Gateways (111).

**Pruébalo:**

```bash
kubectl exec web -- nginx -v
kubectl exec -it web -- bash        # dentro: ls /usr/share/nginx/html, exit
kubectl logs web --tail=5
kubectl port-forward pod/web 8080:80
```

En **otra terminal**, `curl -s localhost:8080 | grep title`. Vuelve a la primera y sal con `Ctrl+C`.

👀 **Qué deberías ver:** `nginx version: nginx/1.29.…`; dentro, `index.html` y `50x.html`; en los logs, las líneas de arranque de nginx. `port-forward` dice `Forwarding from 127.0.0.1:8080 -> 80`, y el `curl` devuelve `<title>Welcome to nginx!</title>`. Si vuelves a mirar los logs, aparece tu petición.

✋ **Sin mirar:** ¿por qué `port-forward` no sirve para exponer una aplicación de verdad?

<details>
<summary>Comprueba</summary>

Porque es un túnel desde tu terminal hacia **un** pod: se corta al cerrar la terminal, y si el pod muere, el túnel apunta a algo que ya no existe.
</details>

**En resumen:** `exec` para entrar, `logs` para leer, `port-forward` para probar desde tu máquina.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Apaga el cluster con `docker stop lab-control-plane`; el pod `web` volverá con él.

### Pieza 4 — Etiquetas, selectores y anotaciones

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

**Pruébalo:**

```bash
kubectl get pods --show-labels
kubectl label pod web version=1
kubectl get pods -L entorno,version
kubectl get pods -l app=web
kubectl get pods -l 'entorno in (lab,prod)'
kubectl get pods -l app!=web
```

🔮 **Predice:** ¿qué imprime el último?

👀 **Qué deberías ver:** `--show-labels` lista `app=web,entorno=lab`; tras `label`, `-L` muestra las columnas `ENTORNO` y `VERSION` con `lab` y `1`. Los dos filtros siguientes devuelven `web`, y el último, `No resources found in default namespace.`: el único pod tiene `app=web`.

`-L` muestra etiquetas como columnas, y `-l` filtra. Recuerda las dos: las usarás a diario.

✋ **Sin mirar:** ¿puede un Service elegir sus pods por una anotación?

<details>
<summary>Comprueba</summary>

No: los selectores solo usan etiquetas. Las anotaciones son información, no se seleccionan.
</details>

**En resumen:** etiquetas para agrupar y seleccionar; anotaciones para informar.

### Pieza 5 — Varios contenedores en un pod

- **Init containers:** corren **antes** que los demás, uno tras otro, y cada uno debe terminar bien. Sirven para preparar: esperar a una base de datos, generar un archivo, aplicar una migración.
- **Ayudantes** (*sidecars*): corren **junto** al principal, compartiendo red y volúmenes. Por ejemplo, uno que recoge logs o refresca un archivo.

La regla: un pod = **una** aplicación. Dos aplicaciones distintas, como la API y la base de datos, van en pods distintos, para poder escalarlas y actualizarlas por separado.

**Pruébalo.** `con-ayudante.yaml`: un *init container* escribe una página antes de arrancar, nginx la sirve, y un ayudante la reescribe con la hora cada 5 segundos. Los tres comparten un volumen `emptyDir`, una carpeta vacía que vive lo que vive el pod (clase 109).

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

👀 **Qué deberías ver:** primero `Init:0/1` (falta uno de un *init container*), luego `PodInitializing` y al final `Running` con `READY 2/2`: dos contenedores, los dos listos. El *init* ya terminó y no cuenta. Sal con `Ctrl+C`.

```bash
kubectl exec con-ayudante -c nginx -- cat /usr/share/nginx/html/index.html
kubectl exec con-ayudante -c reloj -- wget -qO- http://localhost:80
kubectl logs con-ayudante
```

- La primera orden muestra la hora: el ayudante escribe en el mismo volumen que sirve nginx.
- La segunda llega a nginx desde **otro** contenedor por `localhost`: comparten red.
- La tercera avisa `Defaulted container "nginx" out of: nginx, reloj, preparar (init)`: con varios contenedores, `-c` elige cuál.

✋ **Sin mirar:** ¿por qué la API de Vigía y su PostgreSQL no van en el mismo pod?

<details>
<summary>Comprueba</summary>

Porque son dos aplicaciones: cada una necesita escalar, actualizarse y fallar por su cuenta. En el mismo pod, escalar la API duplicaría también la base de datos.
</details>

**En resumen:** varios contenedores en un pod comparten red y volúmenes; un pod, una aplicación.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `kubectl run web --image=… --dry-run=client -o yaml` | el esqueleto de un objeto, sin crearlo |
| `kubectl apply -f web.yaml` | crear o actualizar desde un archivo |
| `kubectl get pod web -o yaml` | el objeto entero, con su `status` |
| `kubectl get pod web -o jsonpath='{.status.podIP}'` | un solo dato |
| `kubectl exec -it web -- bash` · `kubectl exec … -c nombre -- …` | entrar; elegir contenedor |
| `kubectl logs web --tail=5` | las últimas líneas |
| `kubectl port-forward pod/web 8080:80` | un túnel desde tu Ubuntu |
| `kubectl label pod web version=1` | poner una etiqueta |
| `kubectl get pods -l app=web` · `-L entorno` · `--show-labels` | filtrar y mostrar etiquetas |
| `kubectl apply --dry-run=server -f …` | validar en el API sin crear |

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

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Dos contenedores en el mismo puerto.** Crea un pod `choque` con dos contenedores `nginx:1.29` (nombres `uno` y `dos`). ¿Qué estado tiene a los 30 segundos? ¿Qué dice `kubectl logs choque -c dos`?

> 🧩 **Ejemplo resuelto:** la pieza 5: `con-ayudante` tiene dos contenedores, `nginx` y `reloj`, y el segundo llega al primero por `localhost`.

**Ahora tú, con huecos:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: choque
spec:
  containers:
    - name: ____
      image: nginx:1.29
    - name: ____
      image: nginx:1.29
```
Completa: «A los 30 segundos, `STATUS` dice ____ y `READY`, ____. El log de `dos` dice ____, porque los dos contenedores comparten…».

<details>
<summary>Pista</summary>

Los dos nginx intentan escuchar en el 80. Piensa qué pasaba en tu Ubuntu cuando dos programas querían el mismo puerto (clase 29).
</details>

**2.** Con `kubectl explain`, averigua qué hace `spec.terminationGracePeriodSeconds` y cuál es su valor por defecto. ¿Con qué clase de la fase 1 y con qué Rómpelo de la fase 5 lo relacionas?

> 🧩 **Ejemplo resuelto:** el reto 3 de la clase 102: `kubectl explain pod.spec.restartPolicy` decía sus valores y el de por defecto.

**Ahora tú, con huecos:** `kubectl explain pod.spec.____`. Completa: «Son los segundos que Kubernetes espera entre ____ y ____ al parar el pod: ____ por defecto. Lo relaciono con la clase ____ y con el Rómpelo 2 de la clase 63, donde `docker stop`…».

<details>
<summary>Pista</summary>

Busca en la descripción las palabras *SIGTERM* y *kill*. Las señales de parada son de la clase 11.
</details>

**3.** Saca con `jsonpath` el nombre y la imagen de cada contenedor de `con-ayudante`, uno por línea.

> 🧩 **Ejemplo resuelto:** la pieza 2: `-o jsonpath='{.status.podIP} {.status.phase}{"\n"}'` imprime dos datos de un pod.

**Ahora tú, con huecos:** `kubectl get pod con-ayudante -o jsonpath='{range .spec.____[*]}{.____} {.____}{"\n"}{end}'`.

<details>
<summary>Pista</summary>

`{range …}…{end}` repite lo de dentro para cada elemento de la lista; dentro, `.name` y `.image` son los campos de cada contenedor.
</details>

Al terminar: `kubectl delete pod --all`.

## Cierre

En `notas/fase-9/clase-103.md`:

1. ¿Qué comparten los contenedores de un pod? ¿Y qué **no** debería compartir nunca un pod? *(2 líneas. Empieza así: «Comparten la red, una IP con `localhost` entre ellos, y… No debería juntar…»)*
2. ¿Quién escribe `spec` y quién escribe `status`? *(1 línea. Empieza así: «`spec`, yo: …»)*
3. ¿Para qué sirven las etiquetas, y en qué se diferencian de las anotaciones? *(2 líneas. Empieza así: «Las etiquetas identifican y agrupan, y los selectores…»)*
4. **Repaso (clase 102, sin mirar):** ¿qué pieza eligió el nodo de tu pod y cuál descargó su imagen? *(1 línea.)*

Después, escríbeme `examíname clase-103`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. La red (una IP, `localhost` entre ellos) y los volúmenes que declara el pod, y siempre corren en el mismo nodo. No debería juntar dos **aplicaciones** distintas, como la API y su base de datos: cada una necesita escalar, actualizarse y fallar por su cuenta.
2. `spec`, tú: el estado deseado. `status`, Kubernetes: el estado real, que actualizan el kubelet y los controladores.
3. Las etiquetas identifican y agrupan, y los selectores las usan para elegir objetos. Así un Service encuentra sus pods y un Deployment los suyos. Las anotaciones guardan información que no se usa para seleccionar: motivos, autores, configuración de herramientas.
4. El *scheduler* (`default-scheduler` en los eventos) eligió el nodo, y el kubelet de ese nodo descargó la imagen y arrancó el contenedor.

**Reto 1:** `name: uno` y `name: dos`. A los pocos segundos, `Error` y después `CrashLoopBackOff`, con `READY 1/2`. El log de `dos` dice `bind() to 0.0.0.0:80 failed (98: Address already in use)`. Los dos contenedores comparten **una** red: dos procesos no pueden escuchar en el mismo puerto de la misma IP, igual que en tu Ubuntu (clase 29).

**Reto 2:** `kubectl explain pod.spec.terminationGracePeriodSeconds`. Los segundos que Kubernetes espera entre el SIGTERM y el SIGKILL al parar el pod: 30 por defecto. Es la parada ordenada de la clase 11 y el `docker stop` del Rómpelo 2 de la clase 63, que mataba con SIGKILL a los 10 segundos.

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
