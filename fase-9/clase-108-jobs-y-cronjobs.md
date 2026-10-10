# Clase 108 — Jobs y CronJobs

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Kubernetes desde cero

## Objetivo

- Ejecutar trabajos que **terminan** con un Job: reintentos, plazos, paralelismo y limpieza.
- Leer el estado de un Job que falla: `BackoffLimitExceeded` y los códigos de salida de sus pods.
- Programar trabajos con un CronJob: el horario, la zona horaria, qué hacer si se solapan y cómo lanzarlo a mano.
- Saber por qué un Job que "ha encontrado un problema" no es lo mismo que un Job que ha fallado.

## Por qué importa

No todo es un servidor que corre para siempre. Hay copias de seguridad, informes, migraciones de base de datos y limpiezas que deben ejecutarse, terminar y dejar constancia de si fueron bien. Un Deployment los reiniciaría sin fin; para eso están los Jobs.

Y Vigía ya tiene trabajos programados: en la clase 20 pusiste el chequeo en `cron`, y en la 79 el informe diario quedó en un *timer* de systemd. En la 115, el chequeo será un CronJob.

## Teoría

### Job: hasta terminar

Un Job crea pods hasta que el número de ellos que terminan con código 0 llega a `completions` (1 por defecto):

| Campo | Para qué |
|-------|----------|
| `backoffLimit` | cuántos reintentos antes de darlo por fallido (6 por defecto). Entre reintentos espera cada vez más: 10 s, 20 s, 40 s… |
| `activeDeadlineSeconds` | el tiempo máximo del Job entero; al pasarse, se mata con `DeadlineExceeded` |
| `completions` y `parallelism` | cuántos pods deben terminar bien, y cuántos a la vez |
| `completionMode: Indexed` | cada pod recibe un número en `JOB_COMPLETION_INDEX`: el trozo de trabajo que le toca |
| `ttlSecondsAfterFinished` | borrar el Job y sus pods un tiempo después de terminar |

La plantilla de un Job solo admite `restartPolicy: Never` (un pod nuevo por cada intento) u `OnFailure` (reiniciar el contenedor dentro del mismo pod). `Always` no tendría sentido: el trabajo nunca terminaría.

### CronJob: un Job según un horario

Un CronJob crea un Job cada vez que toca, con la sintaxis de `cron` de la clase 20:

```
┌───── minuto (0-59)
│ ┌─── hora (0-23)
│ │ ┌─ día del mes, mes, día de la semana
│ │ │
*/5 * * * *        cada 5 minutos
30 6 * * 1-5       a las 6:30, de lunes a viernes
```

| Campo | Para qué |
|-------|----------|
| `timeZone` | la zona del **horario**, por ejemplo `America/Bogota`. Sin ella, se usa la del *controller-manager*: UTC en kind y en EKS |
| `concurrencyPolicy` | si una ejecución sigue en marcha cuando toca la siguiente: `Allow` (las dos, el valor por defecto), `Forbid` (se salta la nueva) o `Replace` (mata la vieja) |
| `startingDeadlineSeconds` | si se perdió una ejecución (el cluster estaba apagado), hasta cuándo se puede recuperar |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | cuántos Jobs terminados conserva (3 y 1 por defecto) |
| `suspend` | pausar el CronJob sin borrarlo |

### Éxito, fallo y "he encontrado un problema"

Kubernetes solo entiende el **código de salida**: 0 es éxito y cualquier otro es fallo, y un fallo se reintenta. Piensa qué significan tus códigos.

`vigia check` sale con 1 si algún sitio está caído (clase 54). Eso no es que el chequeo haya fallado: el chequeo funcionó y **encontró** una caída. Si el Job lo tratara como un fallo, lo reintentaría y lo marcaría en rojo cada vez que caiga un sitio vigilado. Lo resolverás en la clase 115.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-108 && cd ~/my-devops-journey/labs/clase-108
```

### 1. Un Job que termina (10 min)

`copia.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: copia
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: copia
          image: busybox:1.37
          command: ["sh", "-c", "echo \"copia empezada: $(date)\"; sleep 5; echo 'copia terminada'"]
```

```bash
kubectl apply -f copia.yaml
kubectl wait --for=condition=complete job/copia --timeout=90s
kubectl get job copia
kubectl get pods -l job-name=copia
kubectl logs job/copia
```

`COMPLETIONS 1/1`, el pod en `Completed` (código 0) y su log. `kubectl wait` es la forma de esperar a un Job desde un script, por ejemplo en un pipeline. A los 10 minutos, `ttlSecondsAfterFinished` lo borrará.

### 2. Un Job que falla (15 min)

`falla.yaml`, igual pero con este contenedor:

```yaml
        - name: falla
          image: busybox:1.37
          command: ["sh", "-c", "echo 'no encuentro el servidor de copias' >&2; exit 3"]
```

(y `name: falla` en `metadata`).

🔮 **Predice:** con `backoffLimit: 2`, ¿cuántos pods verás, y cuánto tardará en rendirse?

```bash
kubectl apply -f falla.yaml
kubectl get pods -l job-name=falla -w
```

Tres pods (el intento y dos reintentos), cada uno en `Error`, con unos 10 y 20 segundos de espera entre ellos. Sal con `Ctrl+C` cuando aparezca el tercero:

```bash
kubectl get job falla
kubectl describe job falla | grep -E "Pods Statuses|BackoffLimitExceeded"
kubectl get pods -l job-name=falla -o jsonpath='{range .items[*]}{.metadata.name} código={.status.containerStatuses[0].state.terminated.exitCode}{"\n"}{end}'
kubectl logs job/falla
```

`STATUS Failed`, el evento `BackoffLimitExceeded` y el código 3 de cada intento. Con `restartPolicy: Never`, cada intento deja su pod, y puedes leer el log de todos.

### 3. Trabajo en paralelo (10 min)

`lote.yaml` reparte 6 trozos entre 2 pods a la vez:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: lote
spec:
  completions: 6
  parallelism: 2
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: trozo
          image: busybox:1.37
          command: ["sh", "-c", "echo \"proceso el trozo $JOB_COMPLETION_INDEX\"; sleep 3"]
```

```bash
kubectl apply -f lote.yaml
kubectl get pods -l job-name=lote -w
```

Nunca más de dos a la vez, y cada pod con su número en el nombre (`lote-0-…`, `lote-1-…`). Al terminar:

```bash
kubectl get job lote
kubectl logs -l job-name=lote --prefix | sort
```

### 4. Un CronJob (20 min)

`hora.yaml` se ejecuta cada minuto:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hora
spec:
  schedule: "* * * * *"
  timeZone: America/Bogota
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: hora
              image: busybox:1.37
              command: ["sh", "-c", "date"]
```

```bash
kubectl apply -f hora.yaml
kubectl get cronjob hora
```

Espera dos minutos y mira los Jobs que ha creado:

```bash
kubectl get cronjob hora
kubectl get jobs
kubectl logs job/<el-último-hora-…>
```

🔮 **Predice:** el CronJob dice `America/Bogota`. ¿Qué hora imprime `date`, la de Bogotá o la UTC?

La UTC. `timeZone` solo decide **cuándo** se lanza el Job; el contenedor tiene su propio reloj, y busybox no trae zonas horarias. Es lo de la clase 45: los servidores viven en UTC, y tu código también debería.

Los Jobs se llaman `hora-<número>`: el número son los minutos desde 1970 de la hora programada. No llevan etiqueta del CronJob; su dueño se ve en `kubectl get job <nombre> -o jsonpath='{.metadata.ownerReferences[0].name}'`.

Lanzarlo a mano, sin esperar al horario, es lo primero que harás para probar un CronJob:

```bash
kubectl create job --from=cronjob/hora hora-a-mano
kubectl logs job/hora-a-mano
```

Y pausarlo sin borrarlo:

```bash
kubectl patch cronjob hora -p '{"spec":{"suspend":true}}'
kubectl get cronjob hora
```

`SUSPEND True`, y deja de crear Jobs.

## Rómpelo

1. **Un horario mal escrito.** En una copia de `hora.yaml` con `name: hora-mal`, pon `schedule: "cada 5 minutos"`:

   ```
   The CronJob "hora-mal" is invalid: spec.schedule: Invalid value: "cada 5 minutos": expected exactly 5 fields, found 3: [cada 5 minutos]
   ```

2. **Un Job que no puede terminar.** En una copia de `copia.yaml` con `name: copia-mal`, pon `restartPolicy: Always`:

   ```
   The Job "copia-mal" is invalid: spec.template.spec.restartPolicy: Required value: valid values: "OnFailure", "Never"
   ```

3. **Ejecuciones que se pisan.** Crea un CronJob `pesado` cada minuto, con `concurrencyPolicy: Forbid` y un contenedor que tarda 150 segundos (`sleep 150`). A los 3 minutos y medio, ¿cuántos Jobs ha creado? ¿Y con `Allow`? Piensa qué pasaría con una copia de seguridad que tarda más que su intervalo.

## Reto

1. Un Job que nunca acaba: `sleep 3600` con `activeDeadlineSeconds: 30`. ¿Qué estado y qué motivo muestra a los 40 segundos?
2. Escribe el `schedule` y el `timeZone` de un CronJob que se ejecute a las 6:30 de Bogotá de lunes a viernes. ¿A qué hora UTC corre?
3. Repite la práctica 2 con `restartPolicy: OnFailure`. ¿Cuántos pods ves ahora? ¿Dónde se cuentan los reintentos?

## Destruir al terminar

```bash
kubectl delete cronjob hora
kubectl delete job --all
```

## Cierre

En `notas/fase-9/clase-108.md`:

1. ¿Por qué un trabajo que debe terminar va en un Job y no en un Deployment?
2. ¿Qué hacen `backoffLimit`, `activeDeadlineSeconds` y `concurrencyPolicy: Forbid`?
3. `vigia check` sale con 1 cuando un sitio está caído. ¿Por qué eso es un problema para un CronJob, y qué opciones se te ocurren?
4. **Repaso (clase 107, sin mirar):** ¿qué pasa cuando un contenedor supera su límite de memoria?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Un Deployment quiere sus pods vivos para siempre: si el proceso termina, aunque sea con 0, lo reinicia. Un Job quiere que terminen bien: cuenta los que salen con 0, reintenta los que fallan, y al final queda como `Complete` o `Failed`, con sus pods y sus logs para revisarlos.
2. `backoffLimit`: los reintentos antes de rendirse. `activeDeadlineSeconds`: el tiempo máximo del Job entero. `concurrencyPolicy: Forbid`: si la ejecución anterior sigue en marcha cuando toca la siguiente, la nueva se salta.
3. Kubernetes solo ve el código: con 1, el Job cuenta como fallido, se reintenta (y repite los chequeos) y queda en rojo, aunque el chequeo funcionó y lo que falla es un sitio vigilado. Opciones: que el comando del CronJob trate el 1 como éxito y solo el 2 o más como fallo; o una opción de Vigía que haga salir con 0 cuando el chequeo funcionó. En los dos casos, que un error de verdad (sin base de datos, configuración rota) siga saliendo con un código de fallo.
4. El kernel lo mata con SIGKILL: `OOMKilled` y código 137. Kubernetes lo reinicia, y si se repite, `CrashLoopBackOff`.

**Rómpelo 3:** con `Forbid`, solo 2: el primero dura 150 segundos, y las ejecuciones que tocaban mientras corría se saltaron. `kubectl describe cronjob pesado` lo cuenta en sus eventos: `JobAlreadyActive … Not starting job because prior execution is running and concurrency policy is Forbid`. Con `Allow` habría uno nuevo cada minuto, todos a la vez. Una copia que tarda más que su intervalo, con `Allow`, acaba con varias copias pisándose y el disco lleno.

**Reto 1:** `Failed`, con motivo `DeadlineExceeded`: Kubernetes mató el pod al pasar los 30 segundos.

**Reto 2:** `schedule: "30 6 * * 1-5"` con `timeZone: America/Bogota`. Bogotá está en UTC−5 todo el año, así que corre a las 11:30 UTC.

**Reto 3:** un solo pod, con `RESTARTS` subiendo: con `OnFailure`, los reintentos reinician el contenedor dentro del mismo pod. Y cuando el Job se rinde, Kubernetes **borra** ese pod: `kubectl logs job/…` ya no encuentra nada. Con `Never`, cada intento deja su pod y su log. Para trabajos que quieras poder depurar, `Never`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| batch job | trabajo por lotes |
| backoff limit | límite de reintentos |
| schedule / time zone | horario / zona horaria |
| concurrency policy | qué hacer si dos ejecuciones se solapan |
| exit code semantics | qué significa cada código de salida |

🎙️ *"Scheduled work runs as CronJobs with concurrencyPolicy Forbid, a backoff limit and a deadline, and I think about exit codes: a check that finds a site down did its job and shouldn't count as a failed Job."*

## Siguiente

[Clase 109 — Volúmenes persistentes y StatefulSets](clase-109-volumenes-y-statefulsets.md)
