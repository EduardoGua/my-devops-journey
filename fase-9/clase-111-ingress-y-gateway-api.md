# Clase 111 — Ingress y Gateway API

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Kubernetes para operar

> 💡 **La idea de hoy:** en lugar de un balanceador por cada Service, **uno solo** recibe todo el HTTP y reparte según el host, la ruta o una cabecera. Las reglas se escriben en objetos del cluster (**Ingress**, el clásico, o **Gateway API**, su sucesor), y un **controlador** las lee y configura el proxy. Sin controlador, las reglas no hacen nada; y el `status` de cada objeto dice si alguien lo ha leído.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los Services, el LoadBalancer de cloud-provider-kind y la `sonda` (clase 105).
> - HTTP y la cabecera `Host` (clase 32); el DNS y los dominios reservados (clase 31).
> - El ALB de AWS, que reparte por host y ruta (clase 77).
> - El despliegue *canary* (clase 89); las variables de entorno de un contenedor (clase 106).

> 🔤 **Palabras nuevas de hoy:**
> - **Ingress**: reglas por host y ruta hacia Services; el estándar clásico.
> - **controlador de Ingress**: el programa que lee esas reglas y configura un proxy.
> - **`ingressClassName`**: qué controlador atiende un Ingress.
> - **Gateway API**: el sucesor de Ingress, con `GatewayClass`, `Gateway` y `HTTPRoute`.
> - **`backendRefs` con `weight`**: repartir el tráfico entre Services por pesos.
> - **`PathPrefix`**: una regla que casa con una ruta y todo lo que cuelga de ella.
> - **`Accepted` / `ResolvedRefs`**: las condiciones del `status` de una ruta: el Gateway la admite / sus Services existen.

## Objetivo

- Explicar por qué no se pone un LoadBalancer por cada Service, y qué resuelve un punto de entrada HTTP único.
- Enrutar por nombre de host con un **Ingress**, y entender que el objeto no hace nada sin su controlador.
- Usar **Gateway API**, el sucesor de Ingress: Gateway, HTTPRoute, rutas por ruta y por cabecera, y reparto por pesos para un *canary*.
- Leer el `status` de una ruta para saber si funciona, antes de culpar a la aplicación.

## Por qué importa

En la clase 105 cada LoadBalancer creaba un balanceador propio: en AWS, unos 16 USD al mes cada uno. Con diez servicios web, diez balanceadores. Lo normal es **uno** que reciba todo el HTTP y reparta según el host y la ruta. Es el ALB de la clase 77, configurado desde YAML.

Además, el panorama cambió hace poco: ingress-nginx, el controlador de Ingress más usado durante años, se retiró en marzo de 2026. Gateway API es lo que viene, y en las entrevistas te pueden preguntar por los dos.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan las mismas dos aplicaciones.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 35 min), con Ingress; el segundo, las **piezas 3 a 5**, con Gateway API, el Rómpelo, el reto y el cierre.

Necesitas cloud-provider-kind en marcha (`docker ps | grep cloud-provider-kind`) y la `sonda`:

```bash
mkdir -p ~/my-devops-journey/labs/clase-111 && cd ~/my-devops-journey/labs/clase-111
```

## Las piezas

### Pieza 1 — Del Service al punto de entrada

```
                         ┌──► Service azul ──► pods azul      (azul.lab.test)
cliente ──► balanceador ─┤
            (uno solo)   └──► Service verde ──► pods verde    (verde.lab.test, o /api)
```

Las reglas (este host va aquí, esta ruta va allá) se escriben en objetos del cluster. Un **controlador** las lee y configura el proxy que recibe el tráfico: nginx, Envoy, HAProxy, un ALB de AWS…

**Pruébalo.** Dos podinfo que se identifican con un mensaje distinto. `azul.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azul
  template:
    metadata:
      labels:
        app: azul
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          env:
            - name: PODINFO_UI_MESSAGE
              value: "soy azul"
          ports:
            - name: http
              containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: azul
spec:
  selector:
    app: azul
  ports:
    - name: http
      port: 80
      targetPort: http
```

`verde.yaml` es igual, cambiando `azul` por `verde` en todas partes.

```bash
kubectl apply -f azul.yaml -f verde.yaml
kubectl exec sonda -- wget -qO- http://azul/ | grep message
kubectl exec sonda -- wget -qO- http://verde/ | grep message
```

👀 **Qué deberías ver:** `"message": "soy azul"` y `"message": "soy verde"`. Son dos Services ClusterIP: desde dentro funcionan, desde fuera todavía no se llega.

✋ **Sin mirar:** con diez servicios web en AWS, ¿cuánto costarían diez Services de tipo LoadBalancer, más o menos, al mes?

<details>
<summary>Comprueba</summary>

Unos 160 USD (16 cada uno), más el tráfico. Con un único punto de entrada, uno.
</details>

**En resumen:** un balanceador para todos; las reglas, en objetos del cluster; un controlador que las cumple.

### Pieza 2 — Ingress: el clásico

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: colores
spec:
  rules:
    - host: azul.lab.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: azul
                port:
                  name: http
```

- Reglas por **host** y por **ruta** (`pathType: Prefix` o `Exact`), y TLS con un Secret de tipo `kubernetes.io/tls`.
- Sin controlador no hace **nada**: el objeto se crea, pero no recibe ni una petición. Cada controlador se instala aparte, y se elige con `ingressClassName` (o la clase marcada por defecto).
- Para todo lo que no sea host y ruta (redirecciones, reescrituras, pesos…), cada controlador inventó sus propias anotaciones. Un Ingress escrito para nginx no funciona igual en otro.

En kind, cloud-provider-kind (clase 105) trae su propio controlador de Ingress, con la clase `cloud-provider-kind`, marcada por defecto.

**Pruébalo.** `ingress.yaml`, con la regla de arriba para `azul.lab.test` y otra igual para `verde.lab.test` hacia el Service `verde`. Los dominios `.test` están reservados para pruebas y nunca existirán en internet, como los `.invalid` de la fase 3.

```bash
kubectl get ingressclass
kubectl apply -f ingress.yaml
kubectl get ingress colores -w
```

En unos segundos aparece una IP en `ADDRESS`. Sal con `Ctrl+C`.

🔮 **Predice:** si haces `curl` a esa IP sin más, ¿quién contesta, azul o verde?

```bash
IP=$(kubectl get ingress colores -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s -o /dev/null -w '%{http_code}\n' "http://$IP/"
curl -s -H "Host: azul.lab.test" "http://$IP/" | grep message
curl -s --resolve verde.lab.test:80:$IP http://verde.lab.test/ | grep message
curl -s -i -H "Host: otro.lab.test" "http://$IP/" | head -3
```

👀 **Qué deberías ver:**
- Sin host, **404**: ninguna regla casa, y contesta el propio proxy (`server: envoy`).
- Con la cabecera `Host`, cada uno el suyo. Es HTTP de la clase 32: el proxy decide por esa cabecera.
- `--resolve` hace lo mismo de forma más realista: `curl` resuelve el nombre a esa IP y manda el `Host` correcto, como si existiera un registro DNS (clase 31).

¿Cómo lo implementa cloud-provider-kind?

```bash
kubectl get gateway,httproute
```

Ha traducido tu Ingress a Gateway API: un Gateway `kind-ingress-gateway` y una HTTPRoute por cada host. En cloud-provider-kind, el Ingress se implementa con Gateway API por dentro.

✋ **Sin mirar:** ¿qué pasa con un Ingress en un cluster sin ningún controlador de Ingress?

<details>
<summary>Comprueba</summary>

Nada: el objeto se guarda, pero nadie lo lee ni configura ningún proxy, y su `ADDRESS` se queda vacío.
</details>

**En resumen:** el Ingress enruta por host y ruta; sin controlador, es solo texto.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Apaga el cluster con `docker stop lab-control-plane cloud-provider-kind`. Al volver, la IP del Ingress puede cambiar: léela otra vez con `kubectl get ingress`.

### Pieza 3 — Gateway API: tres objetos y un *canary*

Separa el trabajo en tres objetos, uno por cada papel:

| Objeto | Lo escribe | Dice |
|--------|------------|------|
| `GatewayClass` | el proveedor de infraestructura | qué controlador implementa los Gateways (en kind, `cloud-provider-kind`) |
| `Gateway` | quien opera el cluster | un punto de entrada: qué puertos y protocolos escucha |
| `HTTPRoute` | el equipo de la aplicación | qué hosts, rutas y cabeceras van a qué Services, y con qué **peso** |

Lo que en Ingress eran anotaciones distintas para cada controlador, aquí es parte del estándar: rutas por cabecera, pesos para repartir el tráfico entre dos versiones (el *canary* de la clase 89), redirecciones y reescrituras.

**Pruébalo.** `gateway.yaml`: un Gateway propio y una HTTPRoute que reparte 90 a 10 (en la pieza 4 le añadirás otra):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: lab
spec:
  gatewayClassName: cloud-provider-kind
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canario
spec:
  parentRefs:
    - name: lab
  hostnames:
    - tienda.lab.test
  rules:
    - backendRefs:
        - name: azul
          port: 80
          weight: 90
        - name: verde
          port: 80
          weight: 10
```

```bash
kubectl apply -f gateway.yaml
kubectl get gateway lab
kubectl get httproute
```

Espera a que el Gateway tenga dirección y `PROGRAMMED True`.

🔮 **Predice:** de 100 peticiones a `tienda.lab.test`, ¿cuántas contestará verde?

```bash
GW=$(kubectl get gateway lab -o jsonpath='{.status.addresses[0].value}')
for i in $(seq 1 100); do curl -s -H "Host: tienda.lab.test" "http://$GW/" | grep -o 'soy [a-z]*'; done | sort | uniq -c
```

👀 **Qué deberías ver:** alrededor de 10: en mis pruebas, 91 y 9. Es el despliegue *canary* de la clase 89, sin tocar los Deployments. Para seguir avanzando, cambias los pesos (75/25, 50/50…) y aplicas.

✋ **Sin mirar:** en Gateway API, ¿quién escribe el `Gateway` y quién la `HTTPRoute`?

<details>
<summary>Comprueba</summary>

El `Gateway`, quien opera el cluster (el punto de entrada y sus puertos); la `HTTPRoute`, el equipo de la aplicación (sus hosts, rutas y pesos).
</details>

**En resumen:** GatewayClass, Gateway y HTTPRoute, un objeto por papel; los pesos hacen un *canary*.

### Pieza 4 — Rutas por ruta y por cabecera

Una HTTPRoute puede tener varias reglas, cada una con sus `matches`: por ruta (`PathPrefix`, `Exact`), por cabecera, por método… Las reglas más específicas ganan, y una regla sin `matches` recoge todo lo demás.

**Pruébalo.** Añade a `gateway.yaml` esta segunda ruta:

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rutas
spec:
  parentRefs:
    - name: lab
  hostnames:
    - colores.lab.test
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: verde
          port: 80
    - matches:
        - headers:
            - name: x-version
              value: nueva
      backendRefs:
        - name: verde
          port: 80
    - backendRefs:
        - name: azul
          port: 80
```

En `colores.lab.test`, `/api` va a verde, la cabecera `x-version: nueva` también, y el resto, a azul.

🔮 **Predice:** ¿quién contesta a `/apis`?

```bash
kubectl apply -f gateway.yaml
curl -s -H "Host: colores.lab.test" "http://$GW/" | grep message
curl -s -H "Host: colores.lab.test" "http://$GW/api/info" | grep message
curl -s -H "Host: colores.lab.test" -H "x-version: nueva" "http://$GW/" | grep message
curl -s -H "Host: colores.lab.test" "http://$GW/apis"; echo
```

👀 **Qué deberías ver:** azul, verde, verde. El último va a azul, y podinfo contesta `404 page not found`: `PathPrefix` compara **trozos** de ruta completos, y `/apis` no empieza por el trozo `/api`.

✋ **Sin mirar:** con `PathPrefix: /api`, ¿casa `/api/v1/estado`? ¿Y `/apisito`?

<details>
<summary>Comprueba</summary>

`/api/v1/estado`, sí: empieza por el trozo `/api`. `/apisito`, no: su primer trozo es `apisito`.
</details>

**En resumen:** reglas por ruta y por cabecera; `PathPrefix` compara trozos enteros.

### Pieza 5 — El estado de una ruta, y en AWS

Cada objeto de Gateway API tiene un `status` que dice si el controlador lo aceptó y por qué no. Ante una ruta que no funciona, es lo primero que miras, antes de culpar a la aplicación:
- **`Accepted=True`:** el Gateway la admite.
- **`ResolvedRefs=True`:** sus Services existen.

Cada controlador implementa más o menos partes del estándar. cloud-provider-kind, por ejemplo, no implementa el filtro `URLRewrite` (Rómpelo 3).

**¿Y en AWS?** El **AWS Load Balancer Controller** (o EKS Auto Mode, clase 115) convierte un Ingress en un ALB y un Service LoadBalancer en un NLB. El certificado TLS lo pone ACM. Fuera de AWS, **cert-manager** pide certificados gratis a Let's Encrypt y los guarda en Secrets.

**Pruébalo:**

```bash
kubectl get httproute rutas -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
kubectl get gateway lab -o jsonpath='{range .status.listeners[*]}{.name}: {.attachedRoutes} rutas{"\n"}{end}'
```

👀 **Qué deberías ver:** `Accepted=True` y `ResolvedRefs=True` en la ruta, y `http: 2 rutas` en el Gateway: `canario` y `rutas`.

✋ **Sin mirar:** una HTTPRoute tiene el `status` vacío. ¿Qué significa?

<details>
<summary>Comprueba</summary>

Que ningún controlador la ha reclamado: normalmente, su `parentRefs` apunta a un Gateway que no existe (Rómpelo 2).
</details>

**En resumen:** antes de culpar a la aplicación, el `status` de la ruta.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `kubectl get ingressclass` · `kubectl get gatewayclass` | qué controladores hay |
| `kind: Ingress` + `rules: [{host, http.paths}]` | enrutar por host y ruta |
| `curl -H "Host: azul.lab.test" http://$IP/` · `--resolve host:80:$IP` | probar un host sin DNS |
| `kind: Gateway` + `gatewayClassName` + `listeners` | un punto de entrada |
| `kind: HTTPRoute` + `parentRefs` + `hostnames` + `rules` | las reglas de una aplicación |
| `backendRefs: [{name, port, weight}]` | repartir por pesos (*canary*) |
| `matches: [{path: {type: PathPrefix, value: /api}}]` · `headers` | reglas por ruta o por cabecera |
| `kubectl get httproute … -o jsonpath='{…status.parents[*].conditions[*]…}'` | si la ruta funciona |

## Rómpelo

1. **Un Service que no existe.** Crea una HTTPRoute `sin-backend` para el host `roto.lab.test` que apunte a un Service `amarillo`. ¿Qué devuelve `curl`? ¿Qué dice su `status`?

   `HTTP/1.1 500 Internal Server Error`, con `ResolvedRefs=False BackendNotFound: backend not found`. Que un Gateway devuelva 500 suele ser eso: la regla existe y el destino no.
2. **Un Gateway mal escrito.** Otra ruta, `sin-gateway`, para `perdido.lab.test`, con `parentRefs: - name: lav`. ¿Qué devuelve `curl`? ¿Y su `status`?

   404, y el `status` está **vacío**: ningún controlador la ha reclamado, porque no existe ningún Gateway `lav`. Un `status` vacío significa que nadie ha leído tu objeto.
3. **Algo que este controlador no sabe hacer.** Quieres que `/verde` llegue a verde como si fuera `/`. Añade a `rutas` esta regla, la primera:

   ```yaml
       - matches:
           - path:
               type: PathPrefix
               value: /verde
         filters:
           - type: URLRewrite
             urlRewrite:
               path:
                 type: ReplacePrefixMatch
                 replacePrefixMatch: /
         backendRefs:
           - name: verde
             port: 80
   ```

   Aplica y mira el `status` de `rutas`: `PartiallyInvalid=True … Dropped Rule(s): rule[0] has unsupported filter type "URLRewrite"`. La ruta es válida según el estándar, pero cloud-provider-kind no implementa ese filtro y descarta esa regla. Con otro controlador (Envoy Gateway, Traefik, NGINX Gateway Fabric) funcionaría. Por eso, antes de elegir uno, se comprueba qué partes de Gateway API soporta. Quita la regla.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Mueve el *canary* a 50/50 y después a 0/100, y compruébalo con el bucle. ¿Qué tendrías que hacer después en los Deployments para terminar la migración?

> 🧩 **Ejemplo resuelto:** la pieza 3: con `weight: 90` y `weight: 10`, de 100 peticiones, unas 10 iban a verde.

**Ahora tú, con huecos:** en `canario`, `weight: ____` para azul y `weight: ____` para verde; aplica y repite el bucle. Completa: «Con 0/100, todo va a ____. Para terminar, tendría que… y retirar…».

<details>
<summary>Pista</summary>

Piensa en qué pasa si mañana alguien borra la HTTPRoute `canario`: ¿qué versión quieres que quede detrás del Service estable?
</details>

**2.** Escribe con Gateway API (HTTPRoutes colgadas de `lab`) lo mismo que hace tu `ingress.yaml`, y pruébalo con `curl`. ¿Qué te da Gateway API que el Ingress no te da sin anotaciones?

> 🧩 **Ejemplo resuelto:** la pieza 3: la HTTPRoute `canario` tenía `parentRefs`, `hostnames: [tienda.lab.test]` y sus `backendRefs`.

**Ahora tú, con huecos:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: azul
spec:
  parentRefs:
    - name: ____
  hostnames:
    - ____
  rules:
    - backendRefs:
        - name: ____
          port: 80
```
Y otra igual para verde. Completa: «Hacen falta ____ HTTPRoutes, porque `hostnames` va en ____. Gateway API me da, sin anotaciones,…».

<details>
<summary>Pista</summary>

Prueba con `curl -s -H "Host: azul.lab.test" "http://$GW/" | grep message`: la IP es la del Gateway `lab`, no la del Ingress.
</details>

**3.** Investiga en la documentación de Gateway API (gateway-api.sigs.k8s.io) qué es una `ReferenceGrant` y para qué sirve con una ruta que apunta a un Service de **otro** namespace.

> 🧩 **Ejemplo resuelto:** la clase 110: un RoleBinding solo da permisos en su namespace; para salir de él, hace falta algo explícito.

**Ahora tú, con huecos:** «Una HTTPRoute solo puede apuntar a Services de ____, salvo que el namespace ____ lo permita con una `ReferenceGrant`. Sirve para que un equipo no pueda…».

<details>
<summary>Pista</summary>

Busca *ReferenceGrant* en la sección *API Types* de la documentación. Fíjate en **qué** namespace se crea: el del que pide o el del que da.
</details>

## Destruir al terminar

```bash
kubectl delete -f gateway.yaml -f ingress.yaml -f azul.yaml -f verde.yaml
kubectl delete httproute sin-backend sin-gateway azul verde --ignore-not-found
kubectl get gateway
```

Si queda el Gateway `kind-ingress-gateway`, que creó cloud-provider-kind para tu Ingress, bórralo también: `kubectl delete gateway kind-ingress-gateway`.

## Cierre

En `notas/fase-9/clase-111.md`:

1. ¿Por qué no se pone un LoadBalancer por cada Service web? *(2 líneas. Empieza así: «Por coste y por gestión: en AWS cada balanceador…»)*
2. ¿Qué pasa con un Ingress si no hay ningún controlador de Ingress instalado? *(1–2 líneas. Empieza así: «Nada: el objeto se guarda, pero…»)*
3. ¿Qué tres objetos usa Gateway API, quién escribe cada uno y qué te da que el Ingress no? *(4 líneas: una por objeto y una con lo que gana.)*
4. **Repaso (clase 110, sin mirar):** ¿qué diferencia hay entre un RoleBinding y un ClusterRoleBinding? *(1 línea.)*

Después, escríbeme `examíname clase-111`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Por coste y por gestión: en AWS cada balanceador cuesta unos 16 USD al mes, más el tráfico, y cada uno es una IP y un certificado más que mantener. Un único punto de entrada recibe todo el HTTP y reparte por host y ruta.
2. Nada: el objeto se guarda, pero nadie lo lee ni configura ningún proxy, y su `ADDRESS` se queda vacío. El Ingress es solo la regla; el controlador es quien la cumple.
3. `GatewayClass` (el proveedor: qué controlador), `Gateway` (quien opera el cluster: el punto de entrada, con sus puertos) y `HTTPRoute` (el equipo de la aplicación: hosts, rutas, cabeceras, pesos). Además de separar papeles, trae en el estándar lo que en Ingress dependía de anotaciones de cada controlador (pesos, cabeceras, redirecciones, reescrituras), y un `status` en cada objeto que dice si se aceptó y por qué no.
4. Un RoleBinding da un Role (o un ClusterRole) dentro de **un** namespace. Un ClusterRoleBinding lo da en **todo** el cluster.

**Reto 1:** `weight: 50` y `50`, y después `0` y `100`. Con 0/100, todo el tráfico va a verde. Para terminar: que el Service estable apunte a la versión nueva (o actualizar el Deployment de azul a la versión de verde), y retirar el Deployment que ya no recibe tráfico.

**Reto 2:** `name: lab`, `azul.lab.test` y `name: azul` (y lo mismo para verde). Dos HTTPRoutes, una por host, porque `hostnames` va en la ruta y no en cada regla. En líneas, más o menos lo mismo. Lo que gana es lo que el Ingress no hace sin anotaciones: pesos, cabeceras, el `status` detallado y la separación entre quien opera el Gateway y quien escribe las rutas.

**Reto 3:** una HTTPRoute solo puede apuntar a Services de su namespace, salvo que el namespace **del Service** lo permita con una `ReferenceGrant`, creada allí. Es una medida de seguridad: un equipo no puede mandar tráfico a los Services de otro sin su permiso.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| ingress controller | controlador de Ingress |
| gateway / route | punto de entrada / regla de enrutamiento |
| host-based / path-based routing | enrutar por host / por ruta |
| traffic splitting / weights | reparto del tráfico / pesos |
| retired (project) | proyecto retirado, sin mantenimiento |

🎙️ *"Instead of one cloud load balancer per Service, I run a single entry point: an Ingress or, preferably now that ingress-nginx is retired, a Gateway with HTTPRoutes. Routes can split traffic by weight, which gives me canary releases without touching the Deployments."*

## Siguiente

[Clase 112 — Depurar: CrashLoopBackOff, ImagePullBackOff y Pending](clase-112-depurar.md)
