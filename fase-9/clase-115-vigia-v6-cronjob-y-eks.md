# Clase 115 — Proyecto: Vigía v6 (II): CronJob, rollout y qué cambia en EKS

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 2 bloques largos (unas 5 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

> 💡 **La idea de hoy:** cierras Vigía v6. El chequeo corre como **CronJob** y distingue "un sitio está caído" (el chequeo funcionó) de "no he podido trabajar" (un fallo de verdad); publicas una versión con una actualización gradual, provocas una rota y vuelves atrás dejando Git igual que el cluster; y sabes explicar qué cambiaría en **EKS** y cuánto costaría.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Todo lo de la clase 114: `k8s/`, el Secret, el ConfigMap, la API y PostgreSQL en kind.
> - Los códigos de salida de `vigia check` (clase 54); Jobs, CronJobs y `concurrencyPolicy` (clase 108).
> - `rollout status`, `undo`, `history`, `change-cause` y `kubectl diff` (clase 104).
> - ECR, RDS, los balanceadores y EBS (fase 6); OIDC y los roles sin llaves (clase 86).

> 🔤 **Palabras nuevas de hoy:**
> - **plano de control gestionado**: el *control plane* que mantiene el proveedor (EKS en AWS).
> - **grupo de nodos** (*node group*): las EC2 que hacen de nodos, con su escalado.
> - **EKS Pod Identity**: dar permisos de IAM a un pod sin llaves.
> - **External Secrets**: un controlador que copia secretos de AWS Secrets Manager al cluster.

## Objetivo

Cerrar Vigía v6:
- el chequeo corre como **CronJob**, y distingue "un sitio está caído" de "no he podido trabajar";
- publicas una versión nueva con una actualización gradual, provocas una rota, vuelves atrás con `kubectl rollout undo` y dejas Git igual que el cluster;
- sabes explicar qué cambiaría si Vigía corriera en **EKS**, y cuánto costaría.

Criterios de salida de la fase que cierras aquí:
- *Vigía en kind con Deployment, Service, ConfigMap, Secret y un CronJob*;
- *una actualización y un rollback con `kubectl rollout`*.

## Costo esperado

> 💰 **0 USD.** EKS se estudia en papel: la tabla de costos de abajo explica por qué no se deja encendido.

## Recuerda el contrato

Está en la [clase 114](clase-114-vigia-v6-api-y-base-de-datos.md#el-contrato). Hoy tocan R9 (el CronJob), R10 (actualizar y volver atrás), R11 (`verify.sh` en verde) y R12 (README, etiqueta y release).

## Plan de trabajo

**Bloque 1: el chequeo como CronJob**

1. Repasa qué códigos de salida devuelve tu `vigia check` (clase 54): 0 si todo está arriba, 1 si algún sitio está caído, 2 si la configuración está mal. ¿Y si no puede abrir la base de datos? Pruébalo:

   ```bash
   kubectl -n vigia exec deploy/api -- sh -c 'DATABASE_URL=postgresql://vigia:mal@db:5432/vigia python -m vigia check; echo "código: $?"'
   ```

   Apunta el código. Lo necesitarás en el paso 3.
2. El CronJob `checker` (R9), en `k8s/`:
   - cada 5 minutos, con `concurrencyPolicy: Forbid`;
   - `restartPolicy: Never`, un `backoffLimit` bajo y un `activeDeadlineSeconds` (clase 108);
   - el mismo `securityContext`, `automountServiceAccountToken: false`, `resources`, Secret y ConfigMap que la API;
   - y `vigia check` **una vez**: sin `--interval`, que lo haría correr para siempre.
3. Decide cómo trata el CronJob el código 1 (pista 1). Si en el paso 1 un fallo de la base de datos también daba 1, cámbialo en tu código para que dé 2: entrará en la versión 6.0.1.
4. Aplica y prueba sin esperar al horario:

   ```bash
   kubectl apply -f k8s/
   kubectl -n vigia create job --from=cronjob/checker prueba-1
   kubectl -n vigia wait --for=condition=complete job/prueba-1 --timeout=120s
   kubectl -n vigia logs job/prueba-1
   ```

   Y espera a que el propio CronJob lance uno: `kubectl -n vigia get cronjob checker` debe mostrar un `LAST SCHEDULE`.

**Bloque 2: actualizar y volver atrás**

5. **La 6.0.1.** Un cambio pequeño y visible: que `/health` devuelva también la versión (`{"status": "ok", "version": "6.0.1"}`), más el código 2 del paso 3 si te hizo falta. Sube la versión en tu código, construye y carga:

   ```bash
   docker build -t vigia:6.0.1 .
   kind load docker-image vigia:6.0.1 --name lab
   ```

6. En `k8s/`, cambia la imagen de la API y del checker a `vigia:6.0.1`, y pon la anotación con el motivo en el Deployment:

   ```yaml
   metadata:
     name: api
     namespace: vigia
     annotations:
       kubernetes.io/change-cause: "vigia 6.0.1: /health devuelve la versión"
   ```

   Antes de aplicar, `kubectl diff -f k8s/`: ¿cambia solo lo que esperas? Aplica y sigue la actualización. En otra terminal, deja un bucle contra `/health` por el Gateway (pista 2): como mucho, verás algún fallo suelto.

   ```bash
   kubectl apply -f k8s/
   kubectl -n vigia rollout status deployment/api
   kubectl -n vigia rollout history deployment/api
   ```

   Commit.
7. **La 6.0.2 que nadie cargó.** Cambia la etiqueta de la API a `vigia:6.0.2` (y la anotación), **sin** construirla ni cargarla, y aplica. Es el error real más típico: el manifiesto apunta a una imagen que no está.
   - `kubectl -n vigia rollout status deployment/api --timeout=60s`: se atasca;
   - `kubectl -n vigia get pods`: un pod nuevo en `ImagePullBackOff` y los dos viejos sirviendo. Tu bucle sigue sin fallar: ¿por qué?;
   - `kubectl -n vigia describe pod <el-nuevo>`: el evento dice qué imagen buscó y dónde.
8. Vuelve atrás y deja Git en orden:

   ```bash
   kubectl -n vigia rollout undo deployment/api
   kubectl -n vigia rollout status deployment/api
   git restore k8s/
   kubectl apply -f k8s/
   kubectl diff -f k8s/
   ```

   El `diff` debe salir vacío. Apunta en *What broke* qué viste en cada paso.
9. `verify.sh` → `Fallos: 0` (R11).

**Bloque 3: EKS en papel, y la entrega**

10. Lee la sección siguiente y completa en tus notas la columna "Para Vigía" (pista 3).
11. README (R12), PR, etiqueta `v6` y release (abajo).

## Qué cambia en EKS

EKS es el Kubernetes gestionado de AWS: AWS opera el *control plane* (el API, etcd, el *scheduler*) en varias zonas, y tú pones los nodos. Tus manifiestos valen casi enteros. Cambia lo que hay alrededor:

| En kind | En EKS |
|---------|--------|
| `kind create cluster`: gratis, en tu portátil | `eksctl create cluster` o Terraform (fase 8), con el *control plane* gestionado. **0,10 USD por hora** solo por existir |
| `kind load docker-image` | la imagen en **ECR** (fase 6), y los nodos la descargan con su rol de IAM |
| cloud-provider-kind: LoadBalancer, Ingress y Gateway | el **AWS Load Balancer Controller**, o EKS Auto Mode: un Ingress crea un **ALB** y un Service LoadBalancer, un **NLB** |
| la StorageClass `standard`: una carpeta en el nodo | el driver **EBS CSI** con una StorageClass `gp3`: un volumen EBS por PVC, atado a una zona. Para varios nodos a la vez, EFS |
| PostgreSQL en un StatefulSet | a menudo, **RDS** (clase 77): copias, Multi-AZ y parches gestionados. La API solo cambia de `DATABASE_URL` |
| el Secret creado a mano | **AWS Secrets Manager** + External Secrets Operator, que lo sincroniza al cluster. Y etcd cifrado con KMS por defecto |
| los pods no tienen permisos en AWS | **EKS Pod Identity:** un rol de IAM por ServiceAccount, sin llaves, como el rol de la EC2 de la v3. Así, un CronJob de informes subiría a S3 |
| un solo nodo | nodos en varias zonas: *managed node groups*, Karpenter o EKS Auto Mode, que crean y retiran EC2 según los pods pendientes |
| tu kubeconfig de kind | `aws eks update-kubeconfig`, y permisos con IAM (*access entries*) |
| siempre la versión de kind que instales | una versión de Kubernetes con **14 meses** de soporte estándar; después, el extendido cuesta 0,60 USD/h por cluster. Actualizar es parte del trabajo |

**Lo que costaría tenerlo encendido** (us-east-1, aproximado, sin capa gratuita para EKS):

| Pieza | Por hora | Al mes |
|-------|----------|--------|
| *control plane* de EKS | 0,10 USD | ~73 USD |
| 2 nodos `t3.medium` | ~0,08 USD | ~61 USD |
| 1 NAT Gateway (nodos en subred privada, clase 71) | ~0,045 USD + tráfico | ~33 USD |
| 1 ALB para la entrada | ~0,0225 USD + uso | ~16 USD |
| **Total** | **~0,25 USD** | **~180 USD** |

En kind, 0. Por eso la Ruta dice "EKS en concepto, sin dejarlo encendido". Si algún día quieres verlo de verdad, hazlo en una tarde, con Terraform, y destrúyelo al terminar: unas horas cuestan menos de 1 USD. Los créditos y los precios cambian: compruébalos en la tabla "Datos que caducan" de la fase.

## Pistas

<details><summary>Pista 1 — el código 1 no es un fallo del Job</summary>

Kubernetes solo distingue 0 (éxito) de cualquier otro número (fallo, y reintento). Tu chequeo devuelve 1 cuando encuentra un sitio caído, que es justo para lo que existe: el Job **funcionó**. Dos formas de decírselo:
- en el CronJob, envolver el comando para que el 1 cuente como éxito y el resto no:

  ```yaml
  command: ["sh", "-c", "python -m vigia check; c=$?; [ $c -le 1 ] || exit $c"]
  ```

  (`command` sustituye al `ENTRYPOINT` de la imagen; sin `exec`, la shell espera y devuelve el código que decidas);
- o una opción en tu CLI que haga salir con 0 cuando el chequeo se completó, aunque haya caídas.

En las dos, un error de verdad (sin base de datos, configuración rota) debe seguir siendo un código ≥ 2 y un Job fallido. Por eso importa el paso 1.
</details>

<details><summary>Pista 2 — un bucle para vigilar la actualización</summary>

```bash
GW=$(kubectl -n vigia get gateway -o jsonpath='{.items[0].status.addresses[0].value}')
while true; do curl -s -m 2 "http://$GW/health" || echo " FALLO"; echo; sleep 0.5; done
```

Verás `"version":"6.0.0"` y, durante la actualización, cada vez más `"6.0.1"`. Si ves muchos `FALLO`, mira tu readiness (clase 107) y el `maxUnavailable` de tu estrategia (clase 104). Uno o dos sueltos son normales aquí: en mis pruebas, de 0 a 3 por cada 230 peticiones. El proxy del Gateway de kind se entera de cada cambio de pods con un pequeño retraso; dentro del cluster, por el Service, salían cero (clase 107). En producción se afina, por ejemplo con un `preStop` que retrasa unos segundos la parada de cada pod para que el balanceador lo retire antes.
</details>

<details><summary>Pista 3 — la columna "Para Vigía"</summary>

Para cada fila de la tabla de EKS, escribe qué cambiaría en tu `k8s/` o en tu `infra/` de Terraform. Por ejemplo:
- la imagen: `image: <cuenta>.dkr.ecr.us-east-1.amazonaws.com/vigia:6.0.1`, la que ya publica tu pipeline (fase 7);
- la base de datos: un `aws_db_instance` en `infra/` y un `DATABASE_URL` que apunte a él; el StatefulSet `db` desaparece;
- la entrada: una IngressClass `alb` (o la GatewayClass del controlador) en lugar de `cloud-provider-kind`.

Es exactamente lo que te preguntarán en una entrevista: "¿y cómo lo llevarías a producción?".
</details>

<details><summary>Pista 4 — el CronJob no ha lanzado ningún Job</summary>

- `kubectl -n vigia get cronjob checker`: ¿`SUSPEND True`? ¿Un horario que aún no ha llegado?
- `kubectl -n vigia describe cronjob checker`: los eventos dicen si se saltó alguna ejecución, y por qué.
- Si el Job se crea pero falla: `kubectl -n vigia logs job/<nombre>` y la clase 112.
</details>

<details><summary>Pista 5 — <code>verify.sh</code> sigue diciendo que el cluster no coincide</summary>

Después de un `kubectl rollout undo`, el cluster tiene la plantilla vieja, pero la anotación `last-applied-configuration` sigue siendo la de tu último `apply`. Por eso, aunque `git restore` deje los archivos como estaban, hace falta un `kubectl apply -f k8s/` para que `kubectl diff` salga vacío.
</details>

## Rómpelo: antes de etiquetar

1. **Un sitio que no existe.** Añade `https://caido.invalid` a tu ConfigMap, aplica y lanza un Job a mano. ¿Termina como `Complete` o como `Failed`? Debe ser `Complete`, y `/status` debe mostrar ese sitio caído. Quítalo después (o déjalo, si quieres un sitio caído de muestra en tu portafolio).
2. **Un Job que no termina.** Pon `activeDeadlineSeconds: 5` en el CronJob y lanza uno a mano. ¿Qué dice `kubectl -n vigia describe job …`? Devuelve tu valor.
3. **El chequeo y la API, a la vez.** Lanza tres Jobs a mano seguidos. ¿Se pisan? (`concurrencyPolicy` solo vale para lo que lanza el CronJob, no para tus `create job`.) ¿Le pasa algo a la tabla `checks`?

## Entregable

- **En el repo:** `k8s/` completo (sin Secret), los cambios de la 6.0.1 y el README.
- **En tu cluster:** Vigía v6 en verde, con `verify.sh` → `Fallos: 0`.
- **En GitHub:** la etiqueta `v6` y su release.

README en inglés, sección nueva:

````markdown
## Kubernetes (kind)

Vigía runs on a local kind cluster: the API is a two-replica Deployment with readiness/liveness probes,
resource limits, non-root and no service-account token; PostgreSQL 18 is a StatefulSet with its own
PersistentVolumeClaim; the checker is a CronJob every 5 minutes; traffic enters through Gateway API.
Configuration is a ConfigMap and the database password is a Secret that is never committed.

### Run it
```bash
kind create cluster --name lab
docker build -t vigia:6.0.1 . && kind load docker-image vigia:6.0.1 --name lab
kubectl apply -f k8s/00-namespace.yaml
kubectl -n vigia create secret generic vigia-db --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 16)"
kubectl apply -f k8s/
```

### Update and roll back
Bump the image tag and the `kubernetes.io/change-cause` annotation, `kubectl diff -f k8s/`, `kubectl apply -f k8s/`.
If a rollout gets stuck, `kubectl -n vigia rollout undo deployment/api`, then restore the manifests and apply
again so Git matches the cluster.

### On EKS
Images from ECR, RDS instead of the StatefulSet, the AWS Load Balancer Controller for ingress, EBS gp3 volumes,
Secrets Manager with External Secrets, and EKS Pod Identity for AWS access. Not kept running: about USD 180/month.
````

Ajusta los nombres de archivo a los tuyos. Y en *Limitations*, al menos: un solo nodo, el Secret sin copia fuera del cluster y PostgreSQL sin copias de seguridad.

Y para *What broke and how I found it*, una línea por campo:

```markdown
## What broke and how I found it (v6)

- **Symptom:** ____
- **What I checked:** ____
- **Cause:** ____
- **Fix:** ____
```

Un ejemplo, ya relleno (del Rómpelo 1 de la clase 114): *Symptom:* after a `rollout restart`, the new API pods stayed in `CreateContainerConfigError`. *What I checked:* `kubectl -n vigia describe pod`, whose events said `secret "vigia-db" not found`. *Cause:* the Secret had been deleted; the old pods kept working because they had read their variables at startup. *Fix:* recreated the Secret with the same password, recovered from a running pod; lesson: keep the password in a secrets manager too.

Etiqueta y release:

```bash
git switch main && git pull
git tag -a v6 -m "v6: Vigía on Kubernetes (kind)"
git push origin v6
gh release create v6 --title "v6" --notes "Kubernetes: API Deployment with probes and limits, PostgreSQL StatefulSet with a PVC, checker CronJob, Gateway API ingress, ConfigMap and Secret. Rolling update and rollback tested."
```

## Destruir al terminar

Nada que pague: deja Vigía en tu cluster si vas a seguir con la fase 10, o apágalo con `docker stop lab-control-plane cloud-provider-kind`. Si quieres liberar todo el espacio, `kind delete cluster --name lab` (pierdes los datos de PostgreSQL; el README dice cómo recrearlo).

## Cierre

En `notas/fase-9/clase-115.md`:

1. Cuenta la actualización rota, paso a paso: qué viste, por qué el servicio no se cortó y cómo dejaste Git y el cluster iguales. *(4 líneas. Empieza así: «Con la 6.0.2, el Deployment creó un ReplicaSet nuevo con un pod que…»)*
2. ¿Por qué el CronJob trata el código 1 como éxito? ¿Qué código debe devolver un chequeo que no pudo trabajar? *(2 líneas. Empieza así: «Porque un sitio caído es el resultado de un chequeo que funcionó:…»)*
3. "¿Cómo llevarías Vigía a producción en AWS?": responde en un minuto, en voz alta, con la tabla de EKS. *(En voz alta; si quieres apuntarlo, 5 puntos. Empieza así: «The manifests stay almost the same. Images come from ECR,…»)*
4. **Repaso (clase 114, sin mirar):** ¿por qué PostgreSQL va en un StatefulSet? *(1–2 líneas.)*

Después, escríbeme `examíname clase-115`.

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify.sh</code> termine con <code>Fallos: 0</code></summary>

**Comprueba tu entrega:**
- [ ] `verify.sh` → `Fallos: 0`.
- [ ] `kubectl -n vigia rollout history deployment/api` muestra la 6.0.1 con su motivo.
- [ ] `kubectl diff -f k8s/` sale vacío.
- [ ] `git grep -n "kind: Secret"` no encuentra nada.
- [ ] El README tiene la sección *Kubernetes* y la etiqueta `v6` tiene su release.

**Cierre:**
1. Con la 6.0.2, el Deployment creó un ReplicaSet nuevo con un pod que nunca pudo descargar su imagen (`ImagePullBackOff`: `pull access denied, repository does not exist…`, porque el kubelet la buscó en Docker Hub). Como ese pod nunca estuvo listo y `maxUnavailable` era 0, los dos pods de la 6.0.1 siguieron sirviendo: el bucle no falló. `kubectl rollout undo` volvió a la plantilla de la 6.0.1; después, `git restore k8s/` y `kubectl apply -f k8s/` dejaron el archivo, la anotación y el cluster iguales, y `kubectl diff` salió vacío.
2. Porque un sitio caído es el **resultado** de un chequeo que funcionó: si contara como fallo, el Job se reintentaría y quedaría en rojo cada vez que caiga un sitio vigilado, y los fallos de verdad se perderían entre los falsos. Un chequeo que no pudo trabajar (sin base de datos, configuración rota) debe devolver 2 o más: ese sí es un Job fallido.
3. Algo como: "the manifests stay almost the same. Images come from ECR, pushed by the pipeline; the database moves to RDS, so the StatefulSet goes away; ingress goes through the AWS Load Balancer Controller as an ALB; volumes are EBS gp3; the password lives in Secrets Manager and External Secrets syncs it; pods get AWS permissions through EKS Pod Identity, without keys; nodes span several availability zones. I'd build it with Terraform and not leave it running for practice, because it's around 180 dollars a month".
4. Porque guarda datos: necesita un disco propio que siga a su pod cuando se recrea, y un nombre estable. El StatefulSet se lo da con `volumeClaimTemplates` y su Service *headless*.

**Rómpelo 1:** `Complete`, si trataste bien el código 1: el chequeo funcionó y encontró un sitio caído (en el log, `DOWN 0 https://caido.invalid`). `/status` lo muestra con `up: false` y su `error`.

**Rómpelo 2:** `DeadlineExceeded: Job was active longer than specified deadline`. Un chequeo con *timeouts* de 10 segundos por sitio necesita bastante más de 5.

**Rómpelo 3:** corren a la vez: `concurrencyPolicy` solo controla las ejecuciones que lanza el propio CronJob. La tabla no sufre, porque cada chequeo inserta sus filas en su propia transacción, pero tendrás resultados duplicados en el mismo minuto.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| managed control plane | plano de control gestionado |
| node group / autoscaling | grupo de nodos / escalado automático |
| pod identity | identidad de IAM para los pods |
| production readiness | estar listo para producción |
| cost estimate | estimación de costos |

🎙️ *"Vigía v6 runs on Kubernetes with a CronJob for the checks and a two-replica API. I shipped an update, broke one on purpose with an image that was never loaded, watched the old pods keep serving, rolled back with kubectl rollout undo and brought Git back in line. On EKS the manifests barely change: ECR, RDS, the AWS Load Balancer Controller and Pod Identity."*

## Al terminar la fase 9

1. Marca en [`PROGRESO.md`](../PROGRESO.md):
   - las clases 114 y 115;
   - Vigía v6;
   - los **criterios de salida de la fase 9**, solo si los cumples sin mirar.
2. Anota tus horas en el registro mensual de la Ruta 2.0.
3. La fase 10 usa Vigía en tu portátil, con Prometheus y Grafana en Compose, para no cargar más el cluster. Puedes apagarlo: `docker stop lab-control-plane cloud-provider-kind`.
4. Antes de empezar la fase 10, pídeme `revisa la fase 10`: compruebo que las versiones y los comandos siguen al día.

## Siguiente

[Fase 10 — Observabilidad](../fase-10/README.md)
