# Clase 114 — Proyecto: Vigía v6 (I): API y base de datos en kind

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 2 bloques largos (unas 5 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

## Objetivo

Llevar Vigía a Kubernetes, en tu cluster de kind, con manifiestos tuyos en `k8s/`:
- PostgreSQL como StatefulSet, con su disco;
- la contraseña en un Secret que nunca toca Git;
- la configuración en un ConfigMap;
- la API con dos réplicas, sondas, recursos, sin root y sin token;
- y una entrada desde fuera por el Gateway.

En la clase 115 añadirás el chequeo como CronJob, la actualización con vuelta atrás y lo que cambiaría en EKS, y cerrarás la v6.

Criterio de salida de la fase que empiezas aquí y terminas en la 115: *Vigía en kind con Deployment, Service, ConfigMap, Secret y un CronJob*.

## Costo esperado

> 💰 **0 USD.** Todo corre en tu portátil. Lo único que gastas es memoria: con Vigía, el cluster usa alrededor de 1 GB.

## El contrato

Es el de las dos clases. Las filas R9 y R10 son de la clase 115.

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Los manifiestos, en `k8s/` de tu repositorio: `kubectl apply -f k8s/` crea todo menos el Secret | 103 |
| R2 | El namespace `vigia`, en su propio manifiesto | 110 |
| R3 | El Secret `vigia-db`, con la clave `POSTGRES_PASSWORD`: se crea con `kubectl create secret` y una contraseña aleatoria, y **nunca** está en Git. El comando, en el README | 106 |
| R4 | Un ConfigMap con el `config.yaml` de Vigía, montado como archivo en la API (y en el checker) | 106 |
| R5 | PostgreSQL 18: StatefulSet `db` con un PVC de `volumeClaimTemplates` en `/var/lib/postgresql`, un Service *headless* `db`, readiness con `pg_isready`, y `requests` y límite de memoria | 107, 109 |
| R6 | La imagen `vigia:6.0.0`, construida con tu Dockerfile y cargada en kind con `kind load docker-image`. Nunca `latest` | 104, 114 |
| R7 | El Deployment `api`, con:<br>• 2 réplicas;<br>• readiness y liveness contra `/health`;<br>• `requests` de CPU y memoria y límite de memoria;<br>• `runAsNonRoot: true` y `automountServiceAccountToken: false`;<br>• `DATABASE_URL` construida con la contraseña del Secret | 104, 107, 110 |
| R8 | El Service `api` (ClusterIP) y una entrada desde fuera: un Gateway con su HTTPRoute, o un Ingress. `curl http://<IP>/status` funciona desde tu Ubuntu | 105, 111 |
| R9 | El CronJob `checker`: cada 5 minutos, `vigia check` una vez, `concurrencyPolicy: Forbid`, sin root ni token, y un sitio caído no cuenta como fallo | 108, 115 |
| R10 | Una actualización y una vuelta atrás con `kubectl rollout`, con `kubernetes.io/change-cause`. Al terminar, Git y el cluster coinciden | 104, 115 |
| R11 | `verify.sh` → `Fallos: 0` | — |
| R12 | En el README:<br>• una sección *Kubernetes*: cómo arrancarlo en kind, el Secret, cómo actualizar y volver atrás, y qué cambia en EKS;<br>• *What broke and how I found it*;<br>• *Limitations*.<br>Etiqueta `v6` y su release | — |

Los nombres son parte del contrato, porque `verify.sh` los busca así: el namespace `vigia`, `deployment/api` y `service/api`, `statefulset/db` y `service/db`, y `cronjob/checker`.

## Plan de trabajo

**Bloque 1: la base de datos**

1. Rama `v6` y carpeta `k8s/`. Antes de escribir nada, repasa tu `compose.yaml` de la v2 (clase 66): cada servicio, variable, volumen y *healthcheck* tiene su equivalente en Kubernetes. Apunta la tabla de equivalencias en tus notas.
2. El namespace (R2), aplicado.
3. El Secret (R3). Genera la contraseña dentro del comando, como en la clase 106:

   ```bash
   kubectl -n vigia create secret generic vigia-db --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 16)"
   ```

   Hexadecimal a propósito: va dentro de una URL (`postgresql://vigia:<contraseña>@db:5432/vigia`), y caracteres como `@` o `/` la romperían.
4. PostgreSQL (R5): el StatefulSet y su Service *headless*. Compruébalo antes de seguir:

   ```bash
   kubectl -n vigia rollout status statefulset/db
   kubectl -n vigia get pvc
   kubectl -n vigia exec db-0 -- psql -U vigia -d vigia -c 'SELECT version();'
   ```

**Bloque 2: la API**

5. La imagen (R6):

   ```bash
   cd ~/vigia
   docker build -t vigia:6.0.0 .
   kind load docker-image vigia:6.0.0 --name lab
   ```

   `kind load` copia la imagen de tu Docker al containerd del nodo. Sin ese paso, el kubelet intentaría descargar `vigia:6.0.0` de Docker Hub.
6. El ConfigMap (R4), el Deployment y el Service de la API (R7, R8). Aplica y sigue el arranque:

   ```bash
   kubectl apply -f k8s/
   kubectl -n vigia get pods -w
   ```

   Si algo no arranca, es la clase 112: `describe` y `logs` antes de tocar nada.
7. La entrada desde fuera (R8): un Gateway y una HTTPRoute hacia `api`, como en la clase 111.

   ```bash
   GW=$(kubectl -n vigia get gateway -o jsonpath='{.items[0].status.addresses[0].value}')
   curl -s "http://$GW/health"
   curl -s "http://$GW/status"
   ```

   (Si tu HTTPRoute tiene `hostnames`, añade `-H "Host: …"`.)
8. `/status` aún no tiene sitios: el chequeo llegará en la clase 115. Para ver datos ya, lanza uno a mano **dentro** de un pod de la API, que tiene la misma imagen, la configuración y `DATABASE_URL`:

   ```bash
   kubectl -n vigia exec deploy/api -- python -m vigia check
   curl -s "http://$GW/status"
   ```

9. Commit y pasa las pruebas:

   ```bash
   cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v6/verify.sh
   ```

   Al terminar esta clase, todo debe estar en verde **salvo** lo del CronJob `checker` y el historial de `kubectl rollout`, que son de la 115.

### Las pruebas de aceptación

`verify.sh` mira:
- **tu repositorio:** los manifiestos en Git, ningún Secret ni `.env`, imágenes con etiqueta fija, y que el cluster coincide con `k8s/` (`kubectl diff`);
- **cada objeto del contrato:** réplicas, sondas, recursos, seguridad, ConfigMap y Secret, el PVC, y que PostgreSQL no se publica fuera;
- **desde fuera:** `/health` y `/status` por tu Gateway o tu Ingress;
- **la autocuración y los datos:** borra un pod de la API y el de PostgreSQL, y comprueba que todo vuelve y que las filas siguen ahí.

Se niega a ejecutarse fuera de un contexto de kind, porque borra pods. Los detalles, en [`recursos/vigia/v6/`](../recursos/vigia/v6/README.md).

## Pistas

<details><summary>Pista 1 — la tabla de equivalencias con Compose</summary>

| Compose (v2) | Kubernetes (v6) |
|--------------|-----------------|
| un servicio | un Deployment (sin estado) o un StatefulSet (con datos) |
| el nombre del servicio en la red | un Service con ese nombre |
| `environment:` | `env:`, con valores, o `valueFrom` desde un ConfigMap o un Secret |
| `.env` con la contraseña | un Secret creado con `kubectl` |
| `volumes: - ./config.yaml:/app/config.yaml:ro` | un ConfigMap montado como volumen |
| un volumen con nombre | un PVC (en un StatefulSet, de `volumeClaimTemplates`) |
| `healthcheck:` | `readinessProbe` y `livenessProbe` |
| `depends_on: condition: service_healthy` | no existe: cada pod debe tolerar que el otro aún no esté (pista 4) |
| `ports: "127.0.0.1:8000:8000"` | un Service ClusterIP y un Gateway |
| `restart: unless-stopped` | lo hace el kubelet siempre (`restartPolicy: Always`) |
</details>

<details><summary>Pista 2 — <code>DATABASE_URL</code> con la contraseña del Secret</summary>

Kubernetes puede usar una variable dentro de otra con `$(NOMBRE)`, siempre que `NOMBRE` esté definida **antes** en la misma lista `env`:

```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: vigia-db
        key: POSTGRES_PASSWORD
  - name: DATABASE_URL
    value: postgresql://vigia:$(POSTGRES_PASSWORD)@db:5432/vigia
```

Fíjate en que es `$(…)` con paréntesis, la sintaxis de Kubernetes, no `${…}` de la shell. Y en el StatefulSet de PostgreSQL, `POSTGRES_PASSWORD` viene del mismo Secret.
</details>

<details><summary>Pista 3 — dónde montar el <code>config.yaml</code></summary>

Tu imagen trabaja en `/app` y busca `config.yaml` ahí por defecto (clases 58 y 65). Dos opciones:
- montar la clave del ConfigMap justo en `/app/config.yaml`, con `subPath: config.yaml`. No se actualiza sola (clase 106), pero tu API solo lee la configuración al arrancar, así que da igual: tras cambiar el ConfigMap, `kubectl rollout restart`;
- montar el ConfigMap entero en otra carpeta (`/etc/vigia`) y pasar `--config /etc/vigia/config.yaml` en `args`.

Las dos valen. Lo que no vale es construir una imagen nueva para cambiar una URL.
</details>

<details><summary>Pista 4 — la API se reinicia unas cuantas veces al principio</summary>

Mira `kubectl -n vigia logs deploy/api --previous`: algo como `failed to resolve host 'db'` o `connection refused`. Tu API abre la base de datos **al arrancar**, y PostgreSQL aún no estaba listo. El nombre `db` tampoco existe hasta entonces: un Service *headless* solo publica en el DNS los pods listos.

No es grave (el kubelet la reinicia hasta que funciona), pero queda feo y retrasa el arranque. La solución de Kubernetes es un *init container* (clase 103) que espere a PostgreSQL. La imagen de `postgres:18` ya está en el nodo y trae `pg_isready`:

```yaml
initContainers:
  - name: esperar-db
    image: postgres:18
    command: ["sh", "-c", "until pg_isready -h db -U vigia -d vigia; do sleep 2; done"]
```

Ponle también `resources`, como a todo contenedor.
</details>

<details><summary>Pista 5 — <code>ImagePullBackOff</code> con tu propia imagen</summary>

El evento dice `pull access denied, repository does not exist or may require authorization` para `docker.io/library/vigia:…`. El kubelet está intentando descargarla de Docker Hub. O no hiciste `kind load docker-image` con **esa** etiqueta, o la etiqueta del manifiesto no coincide con la que cargaste. Compara `docker exec lab-control-plane crictl images | grep vigia` con el `image:` del manifiesto. Y si es `latest`, la política por defecto es `Always`: Kubernetes siempre intentará descargarla.
</details>

<details><summary>Pista 6 — PostgreSQL no arranca o pierde los datos</summary>

- Con PostgreSQL 18, el volumen va en `/var/lib/postgresql`, no en `/var/lib/postgresql/data` (clase 65).
- `kubectl -n vigia logs db-0`: si dice que falta la contraseña, el `env` no lee bien el Secret.
- Si después de borrar `db-0` la tabla está vacía, el volumen no es un PVC del StatefulSet: `kubectl -n vigia get pvc` debe mostrar `datos-db-0` (o el nombre de tu plantilla) en `Bound`.
</details>

<details><summary>Pista 7 — <code>verify.sh</code> dice que el cluster no coincide con <code>k8s/</code></summary>

Muestra las líneas que difieren. Las causas típicas:
- cambiaste algo con `kubectl scale`, `edit` o `set`: llévalo al YAML o vuelve a aplicar;
- cambiaste el YAML y no aplicaste;
- un objeto existe en el cluster y no en `k8s/` (o al revés).

`kubectl diff -f k8s/` tiene que salir vacío.
</details>

## Rómpelo: antes de seguir

1. **Sin Secret.** `kubectl -n vigia delete secret vigia-db` y `kubectl -n vigia rollout restart deployment/api`. ¿Qué estado tienen los pods nuevos? ¿Por qué los viejos siguen funcionando? Vuelve a crearlo **con la misma contraseña**, o PostgreSQL ya no te dejará entrar: su contraseña se fijó la primera vez que arrancó con el volumen vacío. ¿Dónde la puedes recuperar? (Pista: en el `env` de un pod viejo que siga vivo… o no la recuperas, y entonces, ¿qué tendrías que borrar?)
2. **`latest`.** Cambia la imagen de la API a `vigia:latest` (cárgala antes con ese nombre: `docker tag vigia:6.0.0 vigia:latest` y `kind load`). ¿Arranca? Mira `imagePullPolicy` en `kubectl -n vigia get deployment api -o yaml`. Deshazlo.
3. **Borra el pod de PostgreSQL** mientras la API responde. ¿Cuánto tarda en volver `db-0`? ¿Qué devuelve `/status` mientras tanto? ¿Siguen los datos?

## Cierre

En `notas/fase-9/clase-114.md`:

1. Tu tabla de equivalencias Compose → Kubernetes (pista 1, con tus palabras).
2. ¿Por qué PostgreSQL va en un StatefulSet y la API en un Deployment?
3. ¿Por qué el Secret no está en `k8s/`? ¿Cómo lo recrearía otra persona que clone tu repositorio?
4. **Repaso (clase 113, sin mirar):** ¿qué diferencia hay entre `helm rollback` y `kubectl rollout undo`?

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify.sh</code> solo falle en el CronJob y en el historial de rollout</summary>

**Comprueba tu entrega de hoy:**
- [ ] `kubectl -n vigia get pods`: `api` 2/2 réplicas `Running` y `READY`, `db-0` `Running`.
- [ ] `kubectl -n vigia get pvc`: el PVC de `db-0` en `Bound`.
- [ ] `curl http://<IP del Gateway>/health` desde tu Ubuntu.
- [ ] `git grep -n POSTGRES_PASSWORD k8s/` solo encuentra referencias al Secret, nunca un valor.
- [ ] `kubectl diff -f k8s/` sale vacío.

**Rómpelo 1:** los pods nuevos se quedan en `CreateContainerConfigError` (`secret "vigia-db" not found`). Los viejos siguen, porque sus variables se leyeron al arrancar. La contraseña está en el `env` de un pod viejo vivo (`kubectl -n vigia exec <pod-viejo> -- printenv POSTGRES_PASSWORD`). Si ya no queda ninguno, la única salida es empezar con la base de datos vacía: borrar el StatefulSet y su PVC, y crearlos otra vez con el Secret nuevo. Apúntalo en *What broke*: es la razón de que, en producción, los secretos vivan en un almacén con copia (AWS Secrets Manager) y no solo en el cluster.

**Rómpelo 2:** se queda en `ImagePullBackOff`: con la etiqueta `latest`, `imagePullPolicy` es `Always`, y el kubelet intenta descargarla de Docker Hub aunque esté en el nodo. Con una etiqueta fija es `IfNotPresent` y usa la que cargaste. Además, `latest` no dice qué versión corre: con etiquetas fijas, `kubectl rollout history` tiene sentido.

**Rómpelo 3:** unos segundos. Mientras, `/status` falla (la API no tiene base de datos) y `/health` sigue respondiendo, porque no toca PostgreSQL. Las sondas de la API **no** fallan, y eso es lo correcto (clase 107). Al volver, `db-0` monta el mismo PVC y los datos siguen ahí.

**Cierre:**
2. PostgreSQL guarda datos: necesita un disco que siga a su pod y un nombre estable (`db-0`, `db`). Eso lo da un StatefulSet con `volumeClaimTemplates`. La API no guarda nada: sus réplicas son intercambiables, y un Deployment las reparte, las actualiza poco a poco y las recrea con cualquier nombre.
3. Porque base64 no es cifrado: subirlo sería publicar la contraseña, y Git no olvida. Otra persona lo crea con el comando del README (`kubectl -n vigia create secret generic vigia-db --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 16)"`) **antes** de aplicar `k8s/`.
4. `kubectl rollout undo` devuelve **un** Deployment a una plantilla anterior. `helm rollback` devuelve el release entero, todos sus objetos y valores, a una revisión anterior. Los dos crean una revisión nueva.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to side-load an image | cargar una imagen directamente en los nodos |
| dependent environment variable | variable que usa el valor de otra |
| init container that waits for a dependency | contenedor de inicio que espera a una dependencia |
| bootstrap secret | el secreto que hay que crear antes de desplegar |
| parity with Compose | equivalencia con Compose |

🎙️ *"I moved Vigía from Docker Compose to Kubernetes: PostgreSQL is a StatefulSet with its own volume, the API is a two-replica Deployment with probes, resource limits, no root and no service account token, configuration comes from a ConfigMap and the password from a Secret that never touches Git."*

## Siguiente

[Clase 115 — Vigía v6 (II): CronJob, rollout y qué cambia en EKS](clase-115-vigia-v6-cronjob-y-eks.md)
