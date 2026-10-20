# Clase 110 — Namespaces y RBAC

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Kubernetes para operar

> 💡 **La idea de hoy:** un **namespace** separa los nombres, los permisos y las cuotas de cada aplicación o equipo (pero no la red). **RBAC** dice quién (*subject*) puede hacer qué (*Role*) y dónde (*binding*), y solo suma: lo que no está permitido está prohibido. Los pods tienen su propia identidad, una **ServiceAccount**, con un token montado que conviene no montar si la aplicación no habla con el API.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El mínimo privilegio, los roles y las políticas de IAM (clases 69 y 70).
> - Que un Secret solo está a salvo si pocos pueden leerlo (clase 106).
> - `requests` y `limits` (clase 107); el DNS `<servicio>.<namespace>` (clase 105).
> - `kubectl auth whoami` y el kubeconfig de administrador (clase 102).

> 🔤 **Palabras nuevas de hoy:**
> - **namespace**: un espacio de nombres dentro del cluster.
> - ***cluster-scoped***: un objeto que no vive en ningún namespace (nodos, PVs, StorageClasses).
> - **ResourceQuota** / **LimitRange**: el techo del namespace entero / los valores por defecto de cada contenedor.
> - **Role / ClusterRole**: permisos en un namespace / en todo el cluster.
> - **RoleBinding / ClusterRoleBinding**: dan un Role a alguien en un namespace / en todo el cluster.
> - **ServiceAccount**: la identidad de un programa que corre en el cluster.
> - **suplantar** (`--as`): preguntar en nombre de otro.

## Objetivo

- Separar aplicaciones y equipos con **namespaces**, y ponerles techo con **ResourceQuota** y valores por defecto con **LimitRange**.
- Entender RBAC: quién (*subjects*), qué puede hacer (*Roles*) y dónde (*bindings*).
- Dar a una ServiceAccount permisos mínimos y comprobarlos con `kubectl auth can-i`.
- Ver qué puede hacer un pod con el token que Kubernetes le monta, y por qué Vigía no lo monta.

## Por qué importa

En un cluster real conviven decenas de aplicaciones y varios equipos. Sin separación, cualquiera puede borrar lo de otro, y un pod comprometido puede leer todos los Secrets. Es el mínimo privilegio de IAM (clases 69 y 70) dentro de Kubernetes, y la segunda línea de defensa de la clase 106: un Secret solo está a salvo si pocos pueden leerlo.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior. Todas usan el namespace `equipo-a`.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 30 min); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-110 && cd ~/my-devops-journey/labs/clase-110
```

## Las piezas

### Pieza 1 — Namespaces

Un namespace es un espacio de nombres dentro del cluster: dos objetos pueden llamarse igual si están en namespaces distintos. Sirve de frontera para:
- **los nombres:** `web` en `equipo-a` y `web` en `equipo-b` son objetos distintos;
- **los permisos:** un Role vale dentro de su namespace;
- **las cuotas:** un techo de CPU, memoria o número de objetos por namespace;
- **el DNS:** `web.equipo-a.svc.cluster.local` (clase 105).

No es una frontera de **red**: por defecto, un pod de un namespace llega a cualquier pod de otro. Para cortar eso hacen falta *NetworkPolicies*, que quedan fuera de esta fase.

| Namespace | Qué hay |
|-----------|---------|
| `default` | lo que creas sin decir dónde |
| `kube-system` | las piezas del cluster: CoreDNS, kube-proxy, el *control plane* |
| `kube-public` y `kube-node-lease` | datos públicos del cluster y los latidos de los nodos |

Algunos objetos no viven en ningún namespace: los nodos, los PersistentVolumes, las StorageClasses y los propios namespaces. Son *cluster-scoped*.

**Pruébalo:**

```bash
kubectl get namespaces
kubectl api-resources --namespaced=false | head -8
```

👀 **Qué deberías ver:** `default`, `kube-node-lease`, `kube-public`, `kube-system` y `local-path-storage` (el aprovisionador de discos de kind). En `api-resources`, la columna `NAMESPACED` en `false`: `namespaces`, `nodes`, `persistentvolumes`…

✋ **Sin mirar:** un pod del namespace `equipo-a`, ¿puede conectarse por red a un pod de `equipo-b`?

<details>
<summary>Comprueba</summary>

Sí, por defecto: un namespace no separa la red. Para cortarlo hacen falta NetworkPolicies.
</details>

**En resumen:** el namespace separa nombres, permisos, cuotas y DNS; la red, no.

### Pieza 2 — Un namespace con techo

- **ResourceQuota:** el techo del namespace entero: "como mucho 3 pods, 1 CPU y 1 Gi de memoria reservados en total".
- **LimitRange:** los valores por defecto y los límites de **cada** contenedor: "si no dice nada, reserva 50m de CPU y 64 Mi".

Van juntos: con una cuota de CPU o de memoria, un pod sin `requests` se rechaza. El LimitRange le pone unos por defecto.

**Pruébalo.** `equipo-a.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: equipo-a
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cuota
  namespace: equipo-a
spec:
  hard:
    pods: "3"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.memory: 2Gi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: por-defecto
  namespace: equipo-a
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
        memory: 64Mi
      default:
        memory: 128Mi
```

```bash
kubectl apply -f equipo-a.yaml
for n in 1 2 3 4; do kubectl -n equipo-a run p$n --image=busybox:1.37 -- sleep 1d; done
```

🔮 **Predice:** ¿cuántos de los cuatro se crean?

👀 **Qué deberías ver:** tres. El cuarto:

```
Error from server (Forbidden): pods "p4" is forbidden: exceeded quota: cuota, requested: pods=1, used: pods=3, limited: pods=3
```

Lo rechaza el API: ni siquiera llega a `Pending`. Mira qué recursos recibieron los pods, aunque no pediste ninguno, y cuánto queda de la cuota:

```bash
kubectl -n equipo-a get pod p1 -o jsonpath='{.spec.containers[0].resources}{"\n"}'
kubectl -n equipo-a describe resourcequota cuota
```

Los valores del LimitRange (`{"limits":{"memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}`), y la cuota con `pods 3 3`. Para no escribir `-n equipo-a` en cada orden, cambia el namespace de tu contexto:

```bash
kubectl config set-context --current --namespace=equipo-a
kubectl get pods
kubectl config set-context --current --namespace=default
```

Vuelve siempre a `default` al terminar: un namespace olvidado en el contexto es la mejor forma de borrar algo en el sitio equivocado.

✋ **Sin mirar:** en un namespace con cuota de CPU y sin LimitRange, lanzas un pod sin `resources`. ¿Qué pasa?

<details>
<summary>Comprueba</summary>

El API lo rechaza: con una cuota de recursos, cada pod debe declarar los suyos (o un LimitRange ponérselos). Lo verás en el Rómpelo 2.
</details>

**En resumen:** la cuota pone el techo del namespace; el LimitRange, los valores de cada contenedor.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Comprueba que tu contexto vuelve a estar en `default` (`kubectl config get-contexts`) y apaga el cluster con `docker stop lab-control-plane cloud-provider-kind`.

### Pieza 3 — RBAC: quién, qué y dónde

```
Subject (quién)             Role / ClusterRole (qué)              RoleBinding / ClusterRoleBinding (une los dos)
─────────────────           ───────────────────────────           ──────────────────────────────────────────────
User: eduardo               verbos sobre recursos:                RoleBinding: dentro de un namespace
Group: equipo-a               get, list, watch → pods             ClusterRoleBinding: en todo el cluster
ServiceAccount: lector        create, delete   → deployments
```

- Un **Role** vive en un namespace y da permisos dentro de él. Un **ClusterRole** se define para todo el cluster: sirve para recursos *cluster-scoped*, o como plantilla reutilizable.
- Un **RoleBinding** da un Role (o un ClusterRole) a alguien **dentro de un namespace**. Un **ClusterRoleBinding** lo da en **todo** el cluster.
- RBAC solo suma: no hay reglas de "denegar". Lo que no está permitido está prohibido, como en IAM sin un `Deny` explícito.

Los verbos más comunes: `get`, `list`, `watch`, `create`, `update`, `patch` y `delete`. Y algunos subrecursos tienen permiso propio, como `pods/log` (leer logs) y `pods/exec` (entrar en un pod).

ClusterRoles que ya trae el cluster: `view` (leer casi todo, menos los Secrets), `edit`, `admin` y `cluster-admin` (todo).

**Pruébalo.** `lector.yaml`: una ServiceAccount, un Role que solo lee pods y sus logs, y el RoleBinding que los une:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lector
  namespace: equipo-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ver-pods
  namespace: equipo-a
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: lector-ver-pods
  namespace: equipo-a
subjects:
  - kind: ServiceAccount
    name: lector
    namespace: equipo-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ver-pods
```

`apiGroups: [""]` es el grupo principal de la API, el de los pods, los Services y los Secrets. Los Deployments están en `apps`.

```bash
kubectl apply -f lector.yaml
kubectl -n equipo-a get serviceaccount,role,rolebinding
kubectl -n equipo-a describe role ver-pods
```

👀 **Qué deberías ver:** las tres piezas creadas, y en `describe` una tabla con `pods` y `pods/log` y los verbos `[get list watch]`.

✋ **Sin mirar:** ¿qué diferencia hay entre un RoleBinding y un ClusterRoleBinding?

<details>
<summary>Comprueba</summary>

El RoleBinding da permisos dentro de **su** namespace; el ClusterRoleBinding, en **todo** el cluster.
</details>

**En resumen:** Role (qué), subject (quién) y binding (dónde); RBAC solo suma.

### Pieza 4 — Comprobar permisos con `auth can-i`

`kubectl auth can-i <verbo> <recurso>` pregunta al API si algo está permitido. Con `--as`, preguntas en nombre de otro: **suplantar**. Tú eres administrador y puedes preguntar en nombre de cualquiera. Es la forma de probar permisos sin crear credenciales. El nombre de una ServiceAccount, para RBAC, es `system:serviceaccount:<namespace>:<nombre>`.

**Pruébalo.**

🔮 **Predice:** antes de ejecutarlo, escribe sí o no para cada fila.

```bash
SA=system:serviceaccount:equipo-a:lector
for v in "list pods" "get pods --subresource=log" "delete pods" "list secrets" "create deployments"; do
  printf "%-28s %s\n" "$v" "$(kubectl auth can-i $v -n equipo-a --as=$SA)"
done
printf "%-28s %s\n" "list pods -n default" "$(kubectl auth can-i list pods -n default --as=$SA)"
```

👀 **Qué deberías ver:**

```
list pods                    yes
get pods --subresource=log   yes
delete pods                  no
list secrets                 no
create deployments           no
list pods -n default         no
```

Tú, en cambio:

```bash
kubectl auth can-i '*' '*'
kubectl auth whoami
```

`yes` a todo: el usuario de kind está en un grupo con `cluster-admin`.

✋ **Sin mirar:** ¿por qué `lector` no puede listar pods en `default`?

<details>
<summary>Comprueba</summary>

Porque su RoleBinding está en `equipo-a`, y un RoleBinding solo da permisos en su namespace.
</details>

**En resumen:** `kubectl auth can-i … --as=…` prueba permisos sin crear credenciales.

### Pieza 5 — ServiceAccounts: el token de un pod

Las personas son *Users* (en kind, tu certificado). Los programas que corren dentro del cluster usan **ServiceAccounts**. Cada namespace tiene una llamada `default`, y cada pod usa una.

Kubernetes monta en el pod un **token** de su ServiceAccount, en `/var/run/secrets/kubernetes.io/serviceaccount/`. Es un token de corta duración (alrededor de 1 hora) que el kubelet renueva solo. Con él, el pod habla con el API. Si la aplicación no necesita hablar con el API, como Vigía, `automountServiceAccountToken: false`: lo que no está, no se puede robar.

**Pruébalo.** Un pod que usa la ServiceAccount `lector` y ejecuta `kubectl get pods,secrets` desde dentro del cluster. `curioso.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: curioso
  namespace: equipo-a
spec:
  serviceAccountName: lector
  restartPolicy: Never
  containers:
    - name: kubectl
      image: registry.k8s.io/kubectl:v1.37.1
      args: ["get", "pods,secrets"]
```

La imagen oficial de kubectl no trae ni shell: solo kubectl. Dentro de un pod, kubectl encuentra solo el token montado y la dirección del API.

La cuota de `equipo-a` admite 3 pods, y ya tienes `p1`, `p2` y `p3`: borra dos para dejar sitio.

```bash
kubectl -n equipo-a delete pod p2 p3
kubectl apply -f curioso.yaml
kubectl -n equipo-a logs curioso
```

👀 **Qué deberías ver:**

```
NAME      READY   STATUS    RESTARTS   AGE
curioso   1/1     Running   0          0s
p1        1/1     Running   0          2m35s
Error from server (Forbidden): secrets is forbidden: User "system:serviceaccount:equipo-a:lector" cannot list resource "secrets" in API group "" in the namespace "equipo-a"
```

Los pods sí, los Secrets no: RBAC, desde dentro de un pod. Ahora el mismo pod con la ServiceAccount `default`: crea `curioso-default.yaml` sin la línea `serviceAccountName` y con `name: curioso-default`.

```bash
kubectl apply -f curioso-default.yaml
kubectl -n equipo-a logs curioso-default
kubectl -n equipo-a get pod curioso-default -o jsonpath='{.spec.volumes[0].projected.sources[0]}{"\n"}'
```

`Forbidden` para todo: la ServiceAccount `default` no tiene permisos. Pero su token **sí** estaba montado, con `expirationSeconds: 3607`: una hora, y el kubelet lo renueva.

✋ **Sin mirar:** si alguien entra en un pod por una vulnerabilidad de la aplicación, ¿qué puede hacer con su token?

<details>
<summary>Comprueba</summary>

Usarlo contra el API con todos los permisos de la ServiceAccount del pod. Por eso: permisos mínimos y, si no habla con el API, `automountServiceAccountToken: false`.
</details>

**En resumen:** cada pod tiene una identidad; si no la necesita, no se le monta.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `kubectl get namespaces` · `kubectl api-resources --namespaced=false` | namespaces y objetos *cluster-scoped* |
| `kind: ResourceQuota` + `spec.hard` | techo del namespace |
| `kind: LimitRange` + `defaultRequest` / `default` | valores por defecto de cada contenedor |
| `kubectl config set-context --current --namespace=equipo-a` | cambiar de namespace (¡y volver!) |
| `kind: Role` + `rules: [{apiGroups, resources, verbs}]` | permisos en un namespace |
| `kind: RoleBinding` + `subjects` + `roleRef` | dárselos a alguien |
| `kubectl auth can-i list pods -n equipo-a --as=system:serviceaccount:equipo-a:lector` | probar un permiso |
| `kubectl auth can-i --list -n … --as=…` | todos sus permisos |
| `serviceAccountName: lector` · `automountServiceAccountToken: false` | la identidad del pod; sin token |

## Rómpelo

1. **El binding en otro namespace.** Borra el RoleBinding de `equipo-a` (`kubectl -n equipo-a delete rolebinding lector-ver-pods`). Crea un namespace `otro` y aplica allí una copia del Role y del RoleBinding (cambia los dos `namespace: equipo-a` de `metadata` por `otro`; el del *subject* se queda, porque la ServiceAccount sigue viviendo en `equipo-a`). ¿Puede `lector` listar los pods de `equipo-a`? ¿Y los de `otro`? Al terminar, `kubectl apply -f lector.yaml` para devolverle su permiso.
2. **Una cuota sin valores por defecto.** En un namespace `sin-limites`, crea solo una cuota: `kubectl -n sin-limites create quota cuota --hard=requests.cpu=1,requests.memory=1Gi`. Lanza un pod sin `resources`:

   ```
   Error from server (Forbidden): pods "p" is forbidden: failed quota: cuota: must specify requests.cpu for: p; requests.memory for: p
   ```

   Con cuota de recursos, cada pod debe declarar los suyos, o un LimitRange debe ponérselos.
3. **Darle todo.** `kubectl create clusterrolebinding peligro --clusterrole=cluster-admin --serviceaccount=equipo-a:lector`. Pregunta: `kubectl auth can-i delete nodes --as=system:serviceaccount:equipo-a:lector`. `yes`: cualquier pod con esa ServiceAccount podría ahora borrar el cluster entero. Es lo que piden algunos tutoriales "para que funcione". Bórralo: `kubectl delete clusterrolebinding peligro`.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Reutiliza un ClusterRole: dale `view` a `lector` en el namespace `otro`. ¿Qué puede hacer allí: listar pods, listar Deployments, leer Secrets, borrar pods? ¿Por qué `view` no incluye los Secrets?

> 🧩 **Ejemplo resuelto:** la pieza 3: el RoleBinding `lector-ver-pods` daba el **Role** `ver-pods` a `lector` en `equipo-a`.

**Ahora tú, con huecos:** `kubectl -n otro create rolebinding lector-view --clusterrole=____ --serviceaccount=equipo-a:____`. Después, el bucle de la pieza 4 con `-n otro` y `list deployments`. Completa: «Puede ____ y ____; no puede ____ ni ____. `view` excluye los Secrets porque leerlos permitiría…».

<details>
<summary>Pista</summary>

Piensa qué hay dentro de un Secret: a veces, el token de **otra** ServiceAccount con más permisos.
</details>

**2.** `kubectl auth can-i --list -n equipo-a --as=system:serviceaccount:equipo-a:lector`. ¿Qué permisos tiene, además de los de tu Role? ¿De dónde salen?

> 🧩 **Ejemplo resuelto:** la pieza 4: `kubectl auth can-i list pods -n equipo-a --as=$SA` respondía una sola pregunta.

**Ahora tú, con huecos:** «Además de `pods` y `pods/log`, tiene ____ (con el verbo ____). Salen del ClusterRole ____, que se da a todo usuario autenticado para…».

<details>
<summary>Pista</summary>

Busca las filas `selfsubject…`. Y mira `kubectl get clusterrolebinding | grep basic`.
</details>

**3.** Crea `sin-token.yaml`: `curioso` con `automountServiceAccountToken: false` y otro nombre. ¿Qué dice su log? ¿Por qué?

> 🧩 **Ejemplo resuelto:** la pieza 5: `curioso-default` tenía el token montado, aunque su ServiceAccount no tuviera permisos.

**Ahora tú, con huecos:** en el `spec` del pod, `automountServiceAccountToken: ____` y `name: sin-token`. Completa: «El log dice ____. Sin token montado, kubectl no encuentra… y prueba…».

<details>
<summary>Pista</summary>

Si la cuota no te deja, borra antes `curioso` o `curioso-default`.
</details>

## Destruir al terminar

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace equipo-a otro sin-limites --ignore-not-found
kubectl delete clusterrolebinding peligro --ignore-not-found
```

Borrar un namespace borra **todo** lo que hay dentro. Es cómodo en un laboratorio y peligrosísimo en producción.

## Cierre

En `notas/fase-9/clase-110.md`:

1. ¿Para qué sirve un namespace? ¿Y qué **no** separa? *(2 líneas. Empieza así: «Agrupa objetos y es la frontera de… No separa…»)*
2. Explica Role, ClusterRole, RoleBinding y ClusterRoleBinding con el ejemplo de `lector`. *(4 líneas, una por pieza. Empieza así: «`ver-pods` es un Role:…»)*
3. ¿Qué es el token de una ServiceAccount, qué puede hacer quien lo robe y cómo lo evitas en un pod que no habla con el API? *(3 líneas. Empieza así: «Es la credencial de la ServiceAccount del pod, montada en…»)*
4. **Repaso (clase 109, sin mirar):** ¿por qué un StatefulSet no borra sus PVC al escalar hacia abajo? *(1–2 líneas.)*

Después, escríbeme `examíname clase-110`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Agrupa objetos y es la frontera de los nombres, los permisos (Roles y RoleBindings) y las cuotas. No separa la red: sin NetworkPolicies, un pod llega a cualquier otro pod del cluster. Tampoco los objetos *cluster-scoped*, como los nodos.
2. `ver-pods` es un **Role**: permisos (`get`, `list`, `watch` sobre `pods` y `pods/log`) dentro de `equipo-a`. El **RoleBinding** `lector-ver-pods` se los da a la ServiceAccount `lector`, solo en `equipo-a`. Un **ClusterRole**, como `view`, es lo mismo para todo el cluster: se puede dar en un namespace con un RoleBinding (reto 1) o en todos con un **ClusterRoleBinding** (Rómpelo 3).
3. Es la credencial de la ServiceAccount del pod, montada en `/var/run/secrets/kubernetes.io/serviceaccount/token`. Quien entre en el pod (por una vulnerabilidad de la aplicación, por ejemplo) puede usarla contra el API, con todos los permisos de esa ServiceAccount. Si el pod no necesita el API: `automountServiceAccountToken: false`, y además ningún permiso de más para su ServiceAccount.
4. Porque perder los datos debe ser una decisión explícita: si escalas por error o vuelves a subir, cada réplica recupera su disco.

**Rómpelo 1:** en `equipo-a`, no; en `otro`, sí. Un RoleBinding da permisos solo en **su** namespace, aunque la ServiceAccount viva en otro.

**Reto 1:** `--clusterrole=view --serviceaccount=equipo-a:lector`. Listar pods y Deployments en `otro`, sí; leer Secrets y borrar pods, no. `view` es de solo lectura, y excluye los Secrets a propósito: leerlos permitiría usar las credenciales de otras ServiceAccounts y, con ellas, escalar privilegios.

**Reto 2:** aparecen, además, `selfsubjectreviews`, `selfsubjectaccessreviews` y `selfsubjectrulesreviews` (`create`), y lecturas básicas como `/.well-known/openid-configuration/`. Las da el ClusterRole `system:basic-user` (y alguno más) a todo usuario autenticado: lo mínimo para preguntar "¿quién soy y qué puedo hacer?".

**Reto 3:** `automountServiceAccountToken: false`. El log dice `The connection to the server localhost:8080 was refused`. Sin token montado, kubectl no encuentra la configuración del cluster y prueba la dirección por defecto, donde no hay nada. Es lo que quieres para un pod que no debe hablar con el API.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| RBAC (role-based access control) | control de acceso basado en roles |
| subject / role / binding | quién / qué puede hacer / la unión de los dos |
| service account | cuenta de servicio: la identidad de un pod |
| impersonation (`--as`) | suplantación |
| least privilege | mínimo privilegio |

🎙️ *"Each application gets its own namespace, its own ServiceAccount and a Role with just the verbs it needs, and I verify it with kubectl auth can-i --as. Pods that don't call the Kubernetes API don't mount a token at all."*

## Siguiente

[Clase 111 — Ingress y Gateway API](clase-111-ingress-y-gateway-api.md)
