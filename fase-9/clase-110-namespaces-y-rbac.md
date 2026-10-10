# Clase 110 — Namespaces y RBAC

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Kubernetes para operar

## Objetivo

- Separar aplicaciones y equipos con **namespaces**, y ponerles techo con **ResourceQuota** y valores por defecto con **LimitRange**.
- Entender RBAC: quién (*subjects*), qué puede hacer (*Roles*) y dónde (*bindings*).
- Dar a una ServiceAccount permisos mínimos y comprobarlos con `kubectl auth can-i`.
- Ver qué puede hacer un pod con el token que Kubernetes le monta, y por qué Vigía no lo monta.

## Por qué importa

En un cluster real conviven decenas de aplicaciones y varios equipos. Sin separación, cualquiera puede borrar lo de otro, y un pod comprometido puede leer todos los Secrets. Es el mínimo privilegio de IAM (clases 69 y 70) dentro de Kubernetes, y la segunda línea de defensa de la clase 106: un Secret solo está a salvo si pocos pueden leerlo.

## Teoría

### Namespaces

Un namespace es un espacio de nombres dentro del cluster: dos objetos pueden llamarse igual si están en namespaces distintos. Sirve de frontera para:
- **los nombres:** `web` en `equipo-a` y `web` en `equipo-b` son objetos distintos;
- **los permisos:** un Role vale dentro de su namespace;
- **las cuotas:** un techo de CPU, memoria o número de objetos por namespace;
- **el DNS:** `web.equipo-a.svc.cluster.local` (clase 105).

No es una frontera de **red**: por defecto, un pod de un namespace llega a cualquier pod de otro. Para cortar eso hacen falta *NetworkPolicies*, que quedan fuera de esta fase.

Los que trae el cluster:

| Namespace | Qué hay |
|-----------|---------|
| `default` | lo que creas sin decir dónde |
| `kube-system` | las piezas del cluster: CoreDNS, kube-proxy, el *control plane* |
| `kube-public` y `kube-node-lease` | datos públicos del cluster y los latidos de los nodos |

Algunos objetos no viven en ningún namespace: los nodos, los PersistentVolumes, las StorageClasses y los propios namespaces. Son *cluster-scoped*.

### ResourceQuota y LimitRange

- **ResourceQuota:** el techo del namespace entero: "como mucho 3 pods, 1 CPU y 1 Gi de memoria reservados en total".
- **LimitRange:** los valores por defecto y los límites de **cada** contenedor: "si no dice nada, reserva 50m de CPU y 64 Mi".

Van juntos: con una cuota de CPU o de memoria, un pod sin `requests` se rechaza. El LimitRange le pone unos por defecto.

### RBAC: quién, qué y dónde

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

### ServiceAccounts: la identidad de los pods

Las personas son *Users* (en kind, tu certificado). Los programas que corren dentro del cluster usan **ServiceAccounts**. Cada namespace tiene una llamada `default`, y cada pod usa una.

Kubernetes monta en el pod un **token** de su ServiceAccount, en `/var/run/secrets/kubernetes.io/serviceaccount/`. Es un token de corta duración (alrededor de 1 hora) que el kubelet renueva solo. Con él, el pod habla con el API. Si la aplicación no necesita hablar con el API, como Vigía, `automountServiceAccountToken: false`: lo que no está, no se puede robar.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-110 && cd ~/my-devops-journey/labs/clase-110
kubectl get namespaces
kubectl api-resources --namespaced=false | head -8
```

### 1. Un namespace con techo (20 min)

`equipo-a.yaml`:

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

Tres. El cuarto:

```
Error from server (Forbidden): pods "p4" is forbidden: exceeded quota: cuota, requested: pods=1, used: pods=3, limited: pods=3
```

Lo rechaza el API: ni siquiera llega a `Pending`. Mira qué recursos recibieron los pods, aunque no pediste ninguno, y cuánto queda de la cuota:

```bash
kubectl -n equipo-a get pod p1 -o jsonpath='{.spec.containers[0].resources}{"\n"}'
kubectl -n equipo-a describe resourcequota cuota
```

Los valores del LimitRange. Para no escribir `-n equipo-a` en cada orden, cambia el namespace de tu contexto:

```bash
kubectl config set-context --current --namespace=equipo-a
kubectl get pods
kubectl config set-context --current --namespace=default
```

Vuelve siempre a `default` al terminar: un namespace olvidado en el contexto es la mejor forma de borrar algo en el sitio equivocado.

### 2. Una ServiceAccount de solo lectura (20 min)

`lector.yaml`: una ServiceAccount, un Role que solo lee pods y sus logs, y el RoleBinding que los une:

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
```

🔮 **Predice:** antes de ejecutarlo, escribe sí o no para cada fila.

```bash
SA=system:serviceaccount:equipo-a:lector
for v in "list pods" "get pods --subresource=log" "delete pods" "list secrets" "create deployments"; do
  printf "%-28s %s\n" "$v" "$(kubectl auth can-i $v -n equipo-a --as=$SA)"
done
printf "%-28s %s\n" "list pods -n default" "$(kubectl auth can-i list pods -n default --as=$SA)"
```

```
list pods                    yes
get pods --subresource=log   yes
delete pods                  no
list secrets                 no
create deployments           no
list pods -n default         no
```

`--as` es **suplantar** a otro: tú eres administrador y puedes preguntar en nombre de cualquiera. Es la forma de probar permisos sin crear credenciales. Tú, en cambio:

```bash
kubectl auth can-i '*' '*'
kubectl auth whoami
```

`yes` a todo: el usuario de kind está en un grupo con `cluster-admin`.

### 3. Lo que hace un pod con su token (20 min)

Un pod que usa la ServiceAccount `lector` y ejecuta `kubectl get pods,secrets` desde dentro del cluster. `curioso.yaml`:

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

```bash
kubectl apply -f curioso.yaml
kubectl -n equipo-a logs curioso
```

```
NAME      READY   STATUS    RESTARTS   AGE
curioso   1/1     Running   0          0s
p1        1/1     Running   0          2m35s
…
Error from server (Forbidden): secrets is forbidden: User "system:serviceaccount:equipo-a:lector" cannot list resource "secrets" in API group "" in the namespace "equipo-a"
```

Los pods sí, los Secrets no: RBAC, desde dentro de un pod. Ahora el mismo pod con la ServiceAccount `default`: crea `curioso-default.yaml` sin la línea `serviceAccountName` y con `name: curioso-default`.

```bash
kubectl apply -f curioso-default.yaml
kubectl -n equipo-a logs curioso-default
```

`Forbidden` para todo: la ServiceAccount `default` no tiene permisos. Pero su token **sí** estaba montado. Mira cuánto dura:

```bash
kubectl -n equipo-a get pod curioso-default -o jsonpath='{.spec.volumes[0].projected.sources[0]}{"\n"}'
```

`expirationSeconds: 3607`: una hora, y el kubelet lo renueva.

## Rómpelo

1. **El binding en otro namespace.** Borra el RoleBinding de `equipo-a` (`kubectl -n equipo-a delete rolebinding lector-ver-pods`). Crea un namespace `otro` y aplica allí una copia del Role y del RoleBinding (cambia los dos `namespace: equipo-a` de `metadata` por `otro`; el del *subject* se queda, porque la ServiceAccount sigue viviendo en `equipo-a`). ¿Puede `lector` listar los pods de `equipo-a`? ¿Y los de `otro`? Al terminar, `kubectl apply -f lector.yaml` para devolverle su permiso.
2. **Una cuota sin valores por defecto.** En un namespace `sin-limites`, crea solo una cuota: `kubectl -n sin-limites create quota cuota --hard=requests.cpu=1,requests.memory=1Gi`. Lanza un pod sin `resources`:

   ```
   Error from server (Forbidden): pods "p" is forbidden: failed quota: cuota: must specify requests.cpu for: p; requests.memory for: p
   ```

   Con cuota de recursos, cada pod debe declarar los suyos, o un LimitRange debe ponérselos.
3. **Darle todo.** `kubectl create clusterrolebinding peligro --clusterrole=cluster-admin --serviceaccount=equipo-a:lector`. Pregunta: `kubectl auth can-i delete nodes --as=system:serviceaccount:equipo-a:lector`. `yes`: cualquier pod con esa ServiceAccount podría ahora borrar el cluster entero. Es lo que piden algunos tutoriales "para que funcione". Bórralo: `kubectl delete clusterrolebinding peligro`.

## Reto

1. Reutiliza un ClusterRole: `kubectl -n otro create rolebinding lector-view --clusterrole=view --serviceaccount=equipo-a:lector`. ¿Qué puede hacer `lector` en `otro`: listar pods, listar Deployments, leer Secrets, borrar pods? ¿Por qué `view` no incluye los Secrets?
2. `kubectl auth can-i --list -n equipo-a --as=system:serviceaccount:equipo-a:lector`. ¿Qué permisos tiene, además de los de tu Role? ¿De dónde salen?
3. Crea `sin-token.yaml`: `curioso` con `automountServiceAccountToken: false` y otro nombre. ¿Qué dice su log? ¿Por qué?

## Destruir al terminar

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace equipo-a otro sin-limites --ignore-not-found
kubectl delete clusterrolebinding peligro --ignore-not-found
```

Borrar un namespace borra **todo** lo que hay dentro. Es cómodo en un laboratorio y peligrosísimo en producción.

## Cierre

En `notas/fase-9/clase-110.md`:

1. ¿Para qué sirve un namespace? ¿Y qué **no** separa?
2. Explica Role, ClusterRole, RoleBinding y ClusterRoleBinding con el ejemplo de `lector`.
3. ¿Qué es el token de una ServiceAccount, qué puede hacer quien lo robe y cómo lo evitas en un pod que no habla con el API?
4. **Repaso (clase 109, sin mirar):** ¿por qué un StatefulSet no borra sus PVC al escalar hacia abajo?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Agrupa objetos y es la frontera de los nombres, los permisos (Roles y RoleBindings) y las cuotas. No separa la red: sin NetworkPolicies, un pod llega a cualquier otro pod del cluster. Tampoco los objetos *cluster-scoped*, como los nodos.
2. `ver-pods` es un **Role**: permisos (`get`, `list`, `watch` sobre `pods` y `pods/log`) dentro de `equipo-a`. El **RoleBinding** `lector-ver-pods` se los da a la ServiceAccount `lector`, solo en `equipo-a`. Un **ClusterRole**, como `view`, es lo mismo para todo el cluster: se puede dar en un namespace con un RoleBinding (Reto 1) o en todos con un **ClusterRoleBinding** (Rómpelo 3).
3. Es la credencial de la ServiceAccount del pod, montada en `/var/run/secrets/kubernetes.io/serviceaccount/token`. Quien entre en el pod (por una vulnerabilidad de la aplicación, por ejemplo) puede usarla contra el API, con todos los permisos de esa ServiceAccount. Si el pod no necesita el API: `automountServiceAccountToken: false`, y además ningún permiso de más para su ServiceAccount.
4. Porque perder los datos debe ser una decisión explícita: si escalas por error o vuelves a subir, cada réplica recupera su disco.

**Rómpelo 1:** en `equipo-a`, no; en `otro`, sí. Un RoleBinding da permisos solo en **su** namespace, aunque la ServiceAccount viva en otro.

**Reto 1:** listar pods y Deployments en `otro`, sí; leer Secrets y borrar pods, no. `view` es de solo lectura, y excluye los Secrets a propósito: leerlos permitiría usar las credenciales de otras ServiceAccounts y, con ellas, escalar privilegios.

**Reto 2:** aparecen, además, `selfsubjectreviews`, `selfsubjectaccessreviews` y `selfsubjectrulesreviews` (`create`), y lecturas básicas como `/.well-known/openid-configuration/`. Las da el ClusterRole `system:basic-user` (y alguno más) a todo usuario autenticado: lo mínimo para preguntar "¿quién soy y qué puedo hacer?".

**Reto 3:** `The connection to the server localhost:8080 was refused`. Sin token montado, kubectl no encuentra la configuración del cluster y prueba la dirección por defecto, donde no hay nada. Es lo que quieres para un pod que no debe hablar con el API.
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
