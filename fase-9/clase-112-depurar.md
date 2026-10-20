# Clase 112 — Depurar: CrashLoopBackOff, ImagePullBackOff y Pending

**Dónde:** tu Ubuntu · **Tiempo:** 2 bloques (unas 3 h) · **Bloque:** B. Kubernetes para operar

> 💡 **La idea de hoy:** ante un pod roto, nada de cambiar cosas a ciegas: un método fijo. El **estado** (`get`), lo que dice el **cluster** (`describe` y sus eventos), lo que dijo la **aplicación** (`logs`, también del contenedor que murió), los **alrededores** (Service, nodo) y, solo después, una hipótesis y el arreglo en el YAML. Kubernetes casi siempre te está diciendo ya qué pasa: hoy aprendes dónde mirar, y lo aplicas a seis averías reales.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El método de cinco pasos y los códigos de salida de la clase 63, ahora en Kubernetes.
> - `ImagePullBackOff` y `rollout undo` (clase 104); endpoints y selectores (clase 105).
> - `CreateContainerConfigError` y `FailedMount` (clase 106); sondas, `OOMKilled` y `Pending` por recursos (clase 107).
> - El *finalizer* de un PVC (clase 109); el *taint* del *control plane* (clase 102).

> 🔤 **Palabras nuevas de hoy:**
> - **`CrashLoopBackOff`**: el contenedor arranca y muere una y otra vez, con una espera creciente entre intentos.
> - **`ImagePullBackOff`**: no puede descargar la imagen, y reintenta cada vez más despacio.
> - **`FailedScheduling`**: el evento de un pod `Pending` que ningún nodo acepta.
> - **`kubectl logs --previous`**: el log del contenedor anterior, el que murió.
> - **contenedor efímero**: un contenedor de depuración que se añade a un pod en marcha con `kubectl debug`.
> - **distroless**: una imagen sin shell ni herramientas, solo con la aplicación.
> - **runbook**: una guía de actuación ante una avería.

## Objetivo

- Seguir un método fijo ante un pod roto: estado, eventos, logs, alrededores y, solo después, hipótesis.
- Reconocer cada estado de avería y saber dónde está su causa: `ImagePullBackOff`, `CrashLoopBackOff`, `OOMKilled`, `Pending`, `CreateContainerConfigError`, `Running` sin estar listo…
- Leer los logs del contenedor que **murió**, y entrar con `kubectl debug` en una imagen que no trae shell.
- Resolver seis averías reales sin saber de antemano qué se rompió. Dos de ellas son un criterio de salida de la fase.

## Por qué importa

Es la clase 63 en Kubernetes, y la habilidad que más se nota en una entrevista técnica y en la primera guardia. Nadie te dirá "falta una variable de entorno". Te dirán "pagos se reinicia sin parar" o "la web de clientes no carga", y la causa estará en algún punto entre el YAML, la imagen, los recursos del nodo y las etiquetas.

La buena noticia: Kubernetes casi siempre te lo está diciendo ya, en los eventos y en el estado. Hay que saber dónde mirar, y mirar **antes** de cambiar nada.

## Cómo va esta clase

Cuatro piezas cortas con las herramientas y, después, **las seis averías**, que son el centro de la clase. En cada pieza lees **una** idea y la pruebas enseguida.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** y las dos primeras averías (unos 90 min); el segundo, las otras cuatro, el Rómpelo, el reto y el cierre.

Necesitas la `sonda` de la clase 105:

```bash
mkdir -p ~/my-devops-journey/labs/clase-112 && cd ~/my-devops-journey/labs/clase-112
```

## Las piezas

### Pieza 1 — El método

```
1. ¿En qué estado está?        kubectl get pods            STATUS, READY, RESTARTS (y -o wide: en qué nodo)
2. ¿Qué dice el cluster?        kubectl describe pod        al final, Events; en el contenedor, State y Last State
3. ¿Qué dijo la aplicación?     kubectl logs                y --previous: el contenedor anterior
4. ¿Y alrededor?                kubectl get events --sort-by=.lastTimestamp · Service y EndpointSlices · el nodo
5. ¿Cómo es por dentro?         kubectl exec · kubectl debug
6. Hipótesis → arreglo en el YAML → kubectl apply → comprobar desde fuera, como un usuario
```

Los códigos de salida son los de la clase 63: 1 (la aplicación falló), 126 y 127 (el comando no se puede ejecutar o no existe), 137 (SIGKILL: memoria, casi siempre) y 143 (SIGTERM).

**Pruébalo** con una avería de la que ya sabes la causa: un programa que no encuentra su configuración y sale con 1.

```bash
kubectl run roto --image=busybox:1.37 -- sh -c 'echo "no encuentro config.yaml" >&2; exit 1'
sleep 30
kubectl get pod roto
kubectl describe pod roto | grep -A5 "Last State"
kubectl describe pod roto | tail -5
kubectl logs roto
```

👀 **Qué deberías ver:** `STATUS CrashLoopBackOff` (o `Error`, según el momento) con `RESTARTS` 2 o 3; `Last State: Terminated, Reason: Error, Exit Code: 1`; en los eventos, `Back-off restarting failed container`; y en el log, `no encuentro config.yaml`. Cuatro comandos, y ya sabes la causa sin haber tocado nada.

Déjalo en marcha: lo usarás en la pieza 3.

✋ **Sin mirar:** ¿qué tres comandos usas siempre, en este orden, antes de pensar ninguna hipótesis?

<details>
<summary>Comprueba</summary>

`kubectl get pods` (el estado), `kubectl describe pod` (los eventos y el `Last State`) y `kubectl logs` (lo que dijo la aplicación).
</details>

**En resumen:** estado, eventos, logs, alrededores; la hipótesis va al final.

### Pieza 2 — Qué significa cada estado

| Lo que ves | Qué pasa | Dónde está la causa |
|------------|----------|---------------------|
| `ErrImagePull` y luego `ImagePullBackOff` | no puede descargar la imagen, y reintenta cada vez más despacio | `describe` → `Failed to pull image …`: `not found` (nombre o etiqueta), `unauthorized` (registro privado sin credenciales) o un error de red |
| `CrashLoopBackOff` | el contenedor arranca y muere una y otra vez. El kubelet espera entre intentos 10 s, 20 s, 40 s… hasta 5 minutos | `logs` y `logs --previous`: la traza. `describe` → `Last State`: el código de salida |
| `OOMKilled` (y luego `CrashLoopBackOff`) | superó su límite de memoria | `describe` → `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`. El log suele estar vacío |
| `Error` | terminó con un código distinto de 0 | `logs` y el código en `describe` |
| `CreateContainerConfigError` | falta un ConfigMap, un Secret o una de sus claves | `describe` → `Error: couldn't find key …` (clase 106) |
| `ContainerCreating` mucho rato | no puede montar un volumen, o la imagen es enorme | `describe` → `FailedMount` |
| `Pending` | ningún nodo lo acepta: faltan recursos, un PVC sin enlazar, un `nodeSelector` imposible… | `describe` → `FailedScheduling: 0/1 nodes are available: …` |
| `Running`, pero `READY 0/1` | falla la sonda readiness: está fuera del Service (clase 107) | `describe` → `Readiness probe failed` |
| `Running` y `READY 1/1`, pero el Service no responde | el Service no tiene endpoints, o apunta a otro puerto (clase 105) | `kubectl get endpointslices -l kubernetes.io/service-name=…` |
| `Terminating` para siempre | un *finalizer* espera algo (clase 109) | `kubectl get … -o yaml` → `finalizers` |

**Pruébalo, en papel.** Para cada línea de `kubectl get pods`, ¿qué comando ejecutas primero y qué buscas?

```
NAME       READY   STATUS              RESTARTS   AGE
a-7d9f…    0/1     ImagePullBackOff    0          3m
b-5c2e…    0/1     Running             0          3m
c-9a1b…    0/1     Pending             0          3m
```

<details>
<summary>Comprueba</summary>

- **a:** `kubectl describe pod`, el evento `Failed to pull image`: qué imagen exacta y qué dijo el registro.
- **b:** `kubectl describe pod`, el evento `Readiness probe failed`: qué sonda, qué ruta y qué código.
- **c:** `kubectl describe pod`, el evento `FailedScheduling`: por qué ningún nodo lo acepta.

En los tres, `describe` primero: los `logs` solo sirven si el contenedor llegó a arrancar.
</details>

✋ **Sin mirar:** un pod en `OOMKilled` tiene el log vacío. ¿Por qué, y dónde está la prueba?

<details>
<summary>Comprueba</summary>

Porque SIGKILL no avisa: el proceso muere sin escribir nada. La prueba está en `describe`: `Reason: OOMKilled, Exit Code: 137`.
</details>

**En resumen:** cada estado apunta a un sitio: `describe` para lo que no arrancó, `logs` para lo que arrancó y murió.

### Pieza 3 — Los logs del que murió

`kubectl logs` muestra el contenedor **actual**. Pero en `CrashLoopBackOff` el actual puede ser el que acaba de morir, esperando su siguiente intento; y el kubelet solo guarda el anterior a ese. En la práctica:
- `kubectl logs <pod>`: si el contenedor está esperando para reiniciarse, ya muestra el log del que murió;
- `kubectl logs <pod> --previous`: el log del contenedor anterior, útil cuando el nuevo ya arrancó;
- si una de las dos dice `unable to retrieve container logs`, prueba la otra.

**Pruébalo** con `roto`:

```bash
kubectl logs roto
kubectl logs roto --previous
kubectl get events --sort-by=.lastTimestamp | tail -5
```

👀 **Qué deberías ver:** las dos primeras, `no encuentro config.yaml`: el actual y el anterior murieron igual. Los eventos, ordenados por hora, con los `BackOff` de `roto` al final.

```bash
kubectl delete pod roto
```

✋ **Sin mirar:** un pod se reinició hace un momento y el contenedor nuevo ya está `Running`. ¿Cómo lees por qué murió el anterior?

<details>
<summary>Comprueba</summary>

`kubectl logs <pod> --previous`.
</details>

**En resumen:** `logs` para el actual, `--previous` para el que murió.

### Pieza 4 — `kubectl debug`: un shell donde no lo hay

Muchas imágenes de producción no traen shell ni herramientas: las imágenes *distroless*, o las que se construyen `FROM scratch`. `kubectl exec … -- sh` falla con `executable file not found`. `kubectl debug` añade al pod un **contenedor efímero** con la imagen que elijas, que comparte la red del pod y, con `--target`, ve sus procesos:

```bash
kubectl debug -it <pod> --image=busybox:1.37 --target=<contenedor> -- sh
```

Dentro, `ps` muestra los procesos del contenedor objetivo, y `/proc/1/root/` es su sistema de archivos.

**Pruébalo.** `registry.k8s.io/pause` es una imagen mínima que solo duerme, sin shell ni ninguna otra herramienta:

```bash
kubectl run sin-shell --image=registry.k8s.io/pause:3.10
kubectl exec sin-shell -- sh
```

```
… exec: "sh": executable file not found in $PATH
```

```bash
kubectl debug -it sin-shell --image=busybox:1.37 --target=sin-shell -- sh
```

Dentro, `ps` (el proceso 1 es `/pause`, de otro usuario) y `ls /proc/1/root/`: el disco del otro contenedor. Sal con `exit`.

```bash
kubectl get pod sin-shell -o jsonpath='{.spec.ephemeralContainers[*].name}{"\n"}'
kubectl delete pod sin-shell
```

👀 **Qué deberías ver:** en el `ps`, `1 65535 0:00 /pause` y tu `sh`; en `/proc/1/root/`, apenas un par de archivos; y el nombre del contenedor efímero, algo como `debugger-x7k2p`. El contenedor efímero queda registrado en el pod, y no se puede quitar: el pod hay que recrearlo. Por eso `kubectl debug` es para diagnosticar, nunca para arreglar.

✋ **Sin mirar:** ¿por qué `kubectl debug` sirve para diagnosticar y no para arreglar?

<details>
<summary>Comprueba</summary>

Porque el contenedor efímero queda en el pod para siempre, y lo que cambies dentro no está en ningún YAML: el siguiente pod nacerá sin tu arreglo. El arreglo va en el manifiesto.
</details>

**En resumen:** sin shell en la imagen, `kubectl debug --target`; se diagnostica dentro, se arregla en el YAML.

## Las seis averías

```bash
bash ~/my-devops-journey/recursos/clase-112/averias.sh
```

> 🙈 **Regla de honor:** no leas `averias.sh` más allá de su cabecera hasta haber resuelto las seis. Lo que te entrena es diagnosticar con lo que te da el cluster. Sí puedes, y debes, leer los objetos con `kubectl get … -o yaml`: es lo que harías en el trabajo.

El script crea el namespace `averias` con seis aplicaciones rotas y te da el aviso de cada una, como lo daría un usuario. Para no escribir `-n averias` en cada orden:

```bash
kubectl config set-context --current --namespace=averias
```

Para cada avería:
1. Aplica el método de la pieza 1, paso a paso, y apunta **cada comando** y lo que te dijo.
2. Escribe la causa raíz en una frase.
3. Arréglala. Con un archivo: `kubectl get deployment <nombre> -o yaml > <nombre>.yaml`, edítalo y `kubectl apply -f`. O con un comando: `kubectl set image`, `kubectl set env`, `kubectl set resources`, `kubectl patch`.
4. Compruébalo como un usuario: el pod `Running` y `READY`, y para las dos últimas, la sonda:

   ```bash
   kubectl exec sonda -- wget -qO- -T 3 http://tienda/version
   ```

Plantilla para `notas/fase-9/clase-112.md`, una por avería. Este ejemplo, ya relleno, es `roto`, de la pieza 1:

```markdown
## roto (ejemplo)
Síntoma: el pod `roto` se reinicia sin parar.
Comandos y lo que vi:
1. `kubectl get pod roto` → CrashLoopBackOff, RESTARTS 3
2. `kubectl describe pod roto` → Last State: Terminated, Reason: Error, Exit Code: 1
3. `kubectl logs roto` → "no encuentro config.yaml"
Causa raíz: la aplicación no encuentra su configuración y sale con 1.
Arreglo: montarle un ConfigMap con `config.yaml` → comprobado con `kubectl get pod` (Running, RESTARTS quieto).
```

Copia la estructura y rellena lo tuyo; una línea por campo basta.

Si llevas más de 20 minutos con una, abre **una** pista.

<details><summary>Pista — catalogo</summary>

El estado es de imagen. En `kubectl describe pod`, el último evento `Failed to pull image` dice qué imagen intentó descargar y qué le contestó el registro. Compárala, carácter a carácter, con la que usaste en las clases 104–111.
</details>

<details><summary>Pista — pagos</summary>

`RESTARTS` sube. ¿Qué dijo antes de morir? `kubectl logs` (o con `--previous`). La traza dice qué variable busca. Ahora mira qué variables **tiene** el contenedor: `kubectl describe pod`, sección `Environment`.
</details>

<details><summary>Pista — informes</summary>

`Pending`: no tiene nodo. ¿Qué dice el evento `FailedScheduling`? Compara lo que pide (`kubectl get deployment informes -o jsonpath='{.spec.template.spec.containers[0].resources}'`) con lo que tiene el nodo (`kubectl describe node lab-control-plane`, sección `Allocatable`).
</details>

<details><summary>Pista — buscador</summary>

Su log no dice nada, y eso ya es una pista (clase 63). ¿Qué dice `Last State` en `describe`: `Reason` y `Exit Code`? Mira su límite de memoria y lo que hace el programa (`kubectl get deployment buscador -o yaml`, en `args`). ¿Lo arreglaría subir el límite?
</details>

<details><summary>Pista — tienda</summary>

Los pods están bien: el problema está entre el cliente y ellos. ¿Qué devuelve el `wget` de la sonda? ¿Tiene endpoints el Service (`kubectl describe service tienda`)? Compara su `Selector` con las etiquetas de los pods (`kubectl get pods --show-labels`).
</details>

<details><summary>Pista — clientes</summary>

`Running`, pero `READY 0/1`. ¿Qué sonda está fallando y con qué código (`describe`)? ¿A qué ruta pregunta? ¿Cuál es la ruta de readiness de podinfo (clase 107)?
</details>

> ⏸️ Si partes la clase en dos mañanas, el primer día termina después de `catalogo` y `pagos`. Vuelve al namespace `default` (`kubectl config set-context --current --namespace=default`) y apaga el cluster; las averías que faltan seguirán ahí mañana.

Al terminar las seis:

```bash
kubectl config set-context --current --namespace=default
bash ~/my-devops-journey/recursos/clase-112/averias.sh limpiar
```

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `kubectl get pods -o wide` | estado, reinicios y nodo |
| `kubectl describe pod <pod> \| grep -A5 "Last State"` | cómo murió la última vez |
| `kubectl describe pod <pod> \| tail -10` | los últimos eventos |
| `kubectl logs <pod>` · `--previous` | el log actual · el del que murió |
| `kubectl get events --sort-by=.lastTimestamp` | los eventos del namespace, por hora |
| `kubectl get events -A --field-selector type=Warning` | los avisos de todo el cluster |
| `kubectl debug -it <pod> --image=busybox:1.37 --target=<c> -- sh` | un shell en una imagen sin shell |
| `kubectl set image` · `set env` · `set resources` · `patch` | arreglos rápidos (y luego, al YAML) |

## Rómpelo

1. **Un comando que termina.** Un Deployment `breve` con `busybox:1.37` y `command: ["sh", "-c", "echo hecho"]`. ¿Qué estados ves? ¿Por qué un proceso que termina **bien** acaba en `CrashLoopBackOff` en un Deployment? ¿Qué objeto debería ser?
2. **Una imagen privada.** Un pod con `image: ghcr.io/<tu-usuario-de-github>/no-existe:1.0`. ¿Qué dice exactamente el evento de `Failed to pull image`? ¿En qué se diferencia del de `catalogo`?
3. **Un nodo imposible.** Un pod con `nodeSelector: {disco: ssd}`. ¿Qué estado y qué evento? ¿Qué harías para que pudiera arrancar? (Pista: `kubectl label node`.)

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Un *runbook* para "un pod no está bien": los comandos en orden y qué buscar en cada uno. Te servirá en la clase 114 y en tu primera guardia.

> 🧩 **Ejemplo resuelto:** la primera fila.
> | Paso | Comando | Qué busco |
> |------|---------|-----------|
> | 1 | `kubectl get pods -o wide` | `STATUS`, `READY`, `RESTARTS` que sube, y en qué nodo |

**Ahora tú, con huecos:** copia la tabla en tus notas y rellena las otras cinco filas, una línea cada una:

| Paso | Comando | Qué busco |
|------|---------|-----------|
| 2 | `kubectl describe pod <pod>` | ____ y ____ |
| 3 | `kubectl logs <pod>` (y ____) | ____ |
| 4 | `kubectl get ____ --sort-by=.lastTimestamp` | ____ |
| 5 | `kubectl describe service <svc>` | ____ |
| 6 | arreglo en ____ → `kubectl apply` → ____ | ____ |

<details>
<summary>Pista</summary>

Es el método de la pieza 1, una fila por paso. Para el 5, piensa en `tienda`.
</details>

**2.** `kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp`: ¿qué te dice sobre el cluster entero? ¿Cuánto tiempo guarda Kubernetes los eventos?

> 🧩 **Ejemplo resuelto:** la pieza 3: `kubectl get events --sort-by=.lastTimestamp` mostraba los eventos de **un** namespace.

**Ahora tú, con huecos:** «Con `-A` y `type=Warning`, veo ____ de todo el cluster. Kubernetes guarda los eventos ____ por defecto (la opción ____ de kube-apiserver), así que en producción se envían a…».

<details>
<summary>Pista</summary>

Busca `event-ttl` en la documentación de kube-apiserver (kubernetes.io, *Command line tools reference*).
</details>

**3.** Vuelve a lanzar las averías y resuélvelas **cronometrando**: apunta cuánto tardas en cada una. Repite en una semana.

> 🧩 **Ejemplo resuelto:** una línea de tus notas: «catalogo: 6 min (primera vez) → ____ min (una semana después)».

**Ahora tú, con huecos:** «catalogo: ____ · pagos: ____ · informes: ____ · buscador: ____ · tienda: ____ · clientes: ____. La que más me costó: ____, porque…».

<details>
<summary>Pista</summary>

`bash ~/my-devops-journey/recursos/clase-112/averias.sh limpiar` y vuelve a lanzarlo: las averías son las mismas, pero lo que entrenas es la rapidez del método.
</details>

## Cierre

En `notas/fase-9/clase-112.md`, además de las seis averías:

1. Diagnostica en voz alta, como en una entrevista, un pod en `CrashLoopBackOff`: qué comandos y qué buscas en cada uno. *(3–4 líneas. Empieza así: «`kubectl get pods` confirma que `RESTARTS` sube. `kubectl logs`, y `--previous`,…»)*
2. Lo mismo para un pod en `ImagePullBackOff`. *(2–3 líneas. Empieza así: «`kubectl describe pod`, y en los eventos `Failed to pull image`:…»)*
3. Un pod está en `Pending`. Escribe tres causas posibles y cómo distinguirlas. *(3 líneas, una por causa.)*
4. **Repaso (clase 111, sin mirar):** una HTTPRoute devuelve 500. ¿Qué miras primero? *(1 línea.)*

Después, escríbeme `examíname clase-112`.

## Autocorrección

<details>
<summary>Ábrelo solo cuando hayas resuelto las seis averías</summary>

| Avería | Causa raíz | Dato decisivo | Arreglo |
|--------|------------|---------------|---------|
| catalogo | la etiqueta de la imagen lleva una `v` que no existe: `v6.15.0` en lugar de `6.15.0` | `ImagePullBackOff`, y el evento `… podinfo:v6.15.0: not found` | `kubectl set image deployment/catalogo catalogo=ghcr.io/stefanprodan/podinfo:6.15.0` |
| pagos | la variable se llama `PASARELA_ULR` en el manifiesto, y el programa busca `PASARELA_URL` | `CrashLoopBackOff`, el log con `KeyError: 'PASARELA_URL'`, y `Environment: PASARELA_ULR` en `describe` | `kubectl set env deployment/pagos PASARELA_ULR- PASARELA_URL=https://pasarela.lab.test` |
| informes | reserva 64 Gi de memoria, más de lo que tiene el nodo | `Pending`, con `FailedScheduling: 0/1 nodes are available: 1 Insufficient memory` | `kubectl set resources deployment/informes --requests=memory=64Mi` |
| buscador | el programa acumula memoria sin parar: es una fuga, y el límite de 128 Mi lo frena | `OOMKilled`, `Exit Code: 137` y un log vacío. En `args`, un bucle que añade 16 MiB en cada vuelta | ninguno en el YAML: subir el límite solo retrasaría la muerte. Se arregla el código; mientras, el límite protege al nodo y a los vecinos |
| tienda | el selector del Service dice `app: tiendas`, y los pods tienen `app: tienda` | `wget: … Connection refused`, y `Endpoints:` vacío en `describe service` | `kubectl patch service tienda -p '{"spec":{"selector":{"app":"tienda"}}}'` |
| clientes | la sonda readiness pregunta a `/ready`, que en podinfo da 404; la buena es `/readyz` | `READY 0/1`, `Readiness probe failed: HTTP probe failed with statuscode: 404`, y el Service con los endpoints `ready=false` | cambiar el `path` a `/readyz` (con `kubectl edit` o un `patch`) |

`catalogo` y `pagos` son los dos casos del criterio de salida: `ImagePullBackOff` y `CrashLoopBackOff`, diagnosticados con `describe` y `logs`.

**Cierre:**
1. `kubectl get pods` confirma `CrashLoopBackOff` y que `RESTARTS` sube. `kubectl logs` (y `--previous`) da la traza o el último error antes de morir. `kubectl describe pod` muestra `Last State` con el código de salida y la razón (`Error`, `OOMKilled`), y los eventos. Con el código: 1 es un fallo de la aplicación (mira la traza y la configuración que recibe: variables, ConfigMaps, Secrets), 137 con `OOMKilled` es memoria, y 127 es un comando que no existe. Arreglo en el YAML y comprobación.
2. `kubectl describe pod`, y en los eventos `Failed to pull image`: el nombre exacto de la imagen y la respuesta del registro. `not found` es una errata en el nombre o la etiqueta, o una imagen que nunca se subió (o no se cargó en kind: clase 114). `unauthorized` es un registro privado sin credenciales (`imagePullSecrets`). Un error de DNS o un *timeout* es la red del nodo.
3. Cualquier tres: **faltan recursos** (`Insufficient cpu/memory` en `FailedScheduling`: compara `requests` con `Allocatable`); un **PVC sin enlazar** (`unbound immediate PersistentVolumeClaims`, o el PVC en `Pending`: su StorageClass o su modo de acceso, clase 109); un **`nodeSelector` o afinidad** que ningún nodo cumple (`didn't match Pod's node affinity/selector`); un **taint** sin tolerancia (`untolerated taint`, el reto 1 de la clase 102); una **cuota** (en ese caso el pod ni se crea: lo rechaza el API, clase 110).
4. El `status` de la ruta: `ResolvedRefs=False` con `BackendNotFound` significa que el Service al que apunta no existe (o se llama distinto).

**Rómpelo 1:** `Completed`, luego `CrashLoopBackOff`, con `RESTARTS` subiendo. Un Deployment quiere sus contenedores vivos para siempre (`restartPolicy: Always`), así que reinicia incluso uno que termina bien. Un trabajo que termina es un Job (clase 108).

**Rómpelo 2:** algo como `failed to authorize` o `denied`/`unauthorized`, en lugar del `not found` de `catalogo`: el registro no te deja ver si existe sin credenciales. Para imágenes privadas, el pod necesita un `imagePullSecret`; en EKS, los nodos descargan de ECR con su rol de IAM (clase 115).

**Rómpelo 3:** `Pending`, con `0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector`. Para que arranque: `kubectl label node lab-control-plane disco=ssd`, o quitar el `nodeSelector`.

**Reto 1:** por ejemplo:

| Paso | Comando | Qué busco |
|------|---------|-----------|
| 2 | `kubectl describe pod <pod>` | los eventos del final y el `Last State` (razón y código de salida) |
| 3 | `kubectl logs <pod>` (y `--previous`) | la traza o el último error antes de morir |
| 4 | `kubectl get events --sort-by=.lastTimestamp` | qué más ha pasado alrededor, en orden |
| 5 | `kubectl describe service <svc>` | que tenga endpoints y que el `targetPort` sea el del contenedor |
| 6 | arreglo en el YAML → `kubectl apply` → comprobar desde fuera | el pod `Running` y `READY`, y la respuesta como la vería un usuario |

**Reto 2:** los avisos de todo el cluster, ordenados por hora. Kubernetes guarda los eventos poco tiempo: una hora por defecto (`--event-ttl`). Por eso, en producción, se envían a un sistema de logs (fase 10).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| crash loop back-off | bucle de reinicios con espera creciente |
| image pull back-off | reintentos de descarga de la imagen |
| unschedulable / pending | sin nodo donde ejecutarse / pendiente |
| ephemeral debug container | contenedor de depuración efímero |
| runbook | guía de actuación ante una avería |

🎙️ *"For a pod in CrashLoopBackOff I read the logs, including the previous container, and the last state and exit code in describe. For ImagePullBackOff, the pull error in the events tells me whether it's a typo, a missing image or missing registry credentials. I fix the manifest, not the live object."*

## Siguiente

[Clase 113 — Helm](clase-113-helm.md)
