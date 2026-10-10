# Clase 106 — ConfigMaps y Secrets

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Kubernetes desde cero

## Objetivo

- Sacar la configuración de la imagen con un **ConfigMap**, como variables de entorno y como archivos.
- Saber qué pasa cuando cambias un ConfigMap: qué se actualiza solo y qué necesita reiniciar.
- Crear un **Secret** sin dejarlo escrito en ningún archivo, usarlo en un pod y entender qué protege y qué no.
- Reconocer `CreateContainerConfigError` y un volumen que no se puede montar.

## Por qué importa

Es la regla de la clase 50 y del `.env` de la 65: la imagen es la misma en todos los entornos, y lo que cambia (URLs, credenciales, ajustes) llega desde fuera. En Kubernetes, ese "desde fuera" son los ConfigMaps y los Secrets. Vigía v6 lee su `config.yaml` de un ConfigMap y la contraseña de PostgreSQL de un Secret (clase 114).

Y un error de concepto muy común: creer que un Secret está cifrado. Hoy vas a leer uno en claro, directamente de la base de datos del cluster.

## Teoría

### ConfigMap

Un objeto con pares clave-valor. El valor puede ser una palabra o un archivo entero:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  mensaje: "Hola desde un ConfigMap"
  index.html: |
    <h1>Versión 1</h1>
```

Un pod lo consume de dos formas:

| Forma | Cómo | Si cambias el ConfigMap… |
|-------|------|--------------------------|
| Variable de entorno | `env[].valueFrom.configMapKeyRef`, o `envFrom` para todas las claves | **no** cambia: las variables se leen al arrancar el contenedor |
| Archivos en un volumen | `volumes[].configMap` y un `volumeMount` | el archivo se actualiza solo, en un minuto o dos |
| Un archivo con `subPath` | montar una sola clave sobre un archivo concreto | **no** cambia nunca |

Aunque el archivo cambie, la aplicación tiene que releerlo, y muchas solo leen su configuración al arrancar. Para esas, `kubectl rollout restart` (clase 104).

Límites: 1 MiB por ConfigMap. Con `immutable: true` ya no se puede modificar, y el kubelet deja de vigilarlo.

### Secret

Casi igual que un ConfigMap, pero:
- los valores van en **base64** en el campo `data` (o en claro en `stringData`, al crearlo);
- montado como volumen, vive en un **tmpfs**: en memoria, nunca en el disco del nodo;
- kubectl lo trata con más cuidado: `describe` no enseña los valores.

Y lo más importante: **base64 no es cifrado**, es una forma de escribir bytes con letras. Lo que protege un Secret es:

| Protección | En tu kind | En EKS |
|------------|------------|--------|
| Cifrado en etcd | **no**: está en claro | sí, desde 2025: EKS cifra todos los datos del API con KMS por defecto |
| Quién puede leerlo | RBAC (clase 110): en kind, tú eres administrador | RBAC + IAM |
| Que no llegue a Git | tú | tú |

Por eso un Secret nunca se escribe en un YAML de tu repositorio, ni en base64. Se crea con `kubectl create secret` desde la terminal, o lo trae una herramienta desde un almacén de secretos: External Secrets Operator con AWS Secrets Manager, Sealed Secrets o SOPS. Las verás en el trabajo; aquí basta con la regla.

## Práctica guiada

Necesitas la `sonda` y el Deployment `web` de la clase 105.

```bash
mkdir -p ~/my-devops-journey/labs/clase-106 && cd ~/my-devops-journey/labs/clase-106
```

### 1. Un ConfigMap, como variable y como archivo (15 min)

Guarda el ConfigMap de la teoría como `config.yaml` y este pod como `pagina.yaml`. nginx sirve el `index.html` del ConfigMap y además recibe `mensaje` como variable. El mismo archivo se monta otra vez con `subPath`, para comparar:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pagina
spec:
  containers:
    - name: nginx
      image: nginx:1.29
      env:
        - name: MENSAJE
          valueFrom:
            configMapKeyRef:
              name: web-config
              key: mensaje
      volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: html
          mountPath: /tmp/subpath/index.html
          subPath: index.html
  volumes:
    - name: html
      configMap:
        name: web-config
        items:
          - key: index.html
            path: index.html
```

```bash
kubectl apply -f config.yaml -f pagina.yaml
kubectl exec pagina -- sh -c 'echo "$MENSAJE"; cat /usr/share/nginx/html/index.html'
kubectl exec pagina -- ls -la /usr/share/nginx/html
```

El `ls` enseña cómo lo hace el kubelet: `index.html` es un enlace a `..data/index.html`, y `..data`, otro enlace a una carpeta con fecha. Para actualizar, el kubelet escribe una carpeta nueva y cambia `..data` de golpe: la aplicación nunca lee un archivo a medio escribir.

### 2. Cambiar el ConfigMap (15 min)

En `config.yaml`, cambia `Versión 1` por `Versión 2` y el mensaje por `Adiós`. Aplica:

```bash
kubectl apply -f config.yaml
```

🔮 **Predice:** de las tres formas de consumirlo (la variable, el volumen y el `subPath`), ¿cuál verá el cambio, y cuánto tardará?

```bash
watch -n 5 "kubectl exec pagina -- cat /usr/share/nginx/html/index.html"
```

En un minuto o dos aparece `Versión 2`. Sal con `Ctrl+C` y mira las otras dos:

```bash
kubectl exec pagina -- sh -c 'echo "variable: $MENSAJE"; echo "subPath: $(cat /tmp/subpath/index.html)"'
```

La variable sigue diciendo `Hola desde un ConfigMap` y el `subPath`, `Versión 1`. Solo un contenedor nuevo las vería.

### 3. Configuración para un Deployment (10 min)

podinfo enseña en su respuesta el valor de la variable `PODINFO_UI_MESSAGE`. Dásela desde el ConfigMap: en el `web.yaml` de la clase 104, dentro del contenedor, añade:

```yaml
          env:
            - name: PODINFO_UI_MESSAGE
              valueFrom:
                configMapKeyRef:
                  name: web-config
                  key: mensaje
```

```bash
kubectl apply -f ~/my-devops-journey/labs/clase-104/web.yaml
kubectl rollout status deployment/web
kubectl exec sonda -- wget -qO- http://web/ | grep message
```

Cambia otra vez el mensaje en `config.yaml` y aplica. Los pods de `web` no se enteran: es una variable. Para que lo lean, `kubectl rollout restart deployment/web`, y repite el `wget`.

### 4. Un Secret que no toca ningún archivo (15 min)

```bash
kubectl create secret generic db \
  --from-literal=usuario=vigia \
  --from-literal=password="$(openssl rand -hex 12)"
kubectl get secret db -o yaml
```

🔮 **Predice:** ¿está cifrada la contraseña que ves en `data.password`?

```bash
kubectl get secret db -o jsonpath='{.data.usuario}' | base64 -d; echo
```

`vigia`: cualquiera que pueda leer el objeto tiene el valor. Fíjate también en que la contraseña nunca apareció en tu pantalla ni quedó en un archivo: `openssl rand` la generó dentro del comando. Lo malo sería esto:

```bash
kubectl create secret generic db --from-literal=password=x --dry-run=client -o yaml
```

Ese YAML, con su base64, es exactamente lo que **no** debe acabar en Git.

Úsalo en un pod, como variable y como archivos. `con-secreto.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: con-secreto
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "sleep 1d"]
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db
              key: password
      volumeMounts:
        - name: credenciales
          mountPath: /etc/credenciales
          readOnly: true
  volumes:
    - name: credenciales
      secret:
        secretName: db
        defaultMode: 0400
```

```bash
kubectl apply -f con-secreto.yaml
kubectl exec con-secreto -- sh -c 'echo "${#DB_PASSWORD} caracteres"; ls -la /etc/credenciales/..data/; mount | grep credenciales'
```

`${#VAR}` cuenta los caracteres sin enseñarlos. Los archivos tienen permisos `-r--------` (el `0400`) y el `mount` dice `tmpfs`: el secreto está en memoria, no en el disco del nodo.

## Rómpelo

**1. Una clave que no existe.** En una copia de `pagina.yaml`, con `name: clave-mala`, cambia `key: mensaje` por `key: mensage`:

```bash
kubectl apply -f clave-mala.yaml
kubectl get pod clave-mala
kubectl describe pod clave-mala | tail -3
```

`CreateContainerConfigError`, y el evento lo dice con todas las letras: `couldn't find key mensage in ConfigMap default/web-config`. El contenedor ni siquiera se crea. Pasa igual con un Secret que no existe en una variable.

**2. Un Secret que no existe, como volumen.** En una copia de `con-secreto.yaml`, con `name: sin-secreto`, cambia **solo** `secretName: db` por `secretName: dbx`. El pod se queda en `ContainerCreating`, y `describe` muestra el evento `FailedMount: … secret "dbx" not found`. Son dos síntomas distintos para el mismo error de fondo: apúntalos para la clase 112.

**3. Lee un Secret en la base de datos del cluster.** Esto es lo que vería quien robara el disco de etcd o una copia de seguridad suya:

```bash
kubectl -n kube-system exec etcd-lab-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/db | tr -cs '[:print:]' '\n' | grep -A1 password
```

etcd guarda los objetos en binario: `tr` cambia los bytes que no son texto por saltos de línea. La contraseña sale en claro. En tu kind nadie configuró el cifrado de etcd. EKS sí lo hace por defecto, con KMS (fase 6), y por eso no saldría así.

**4. Un ConfigMap inmutable:**

```bash
kubectl create configmap fija --from-literal=modo=lab --dry-run=client -o yaml | sed '/^data:/i immutable: true' | kubectl apply -f -
kubectl create configmap fija --from-literal=modo=prod --dry-run=client -o yaml | sed '/^data:/i immutable: true' | kubectl apply -f -
```

`field is immutable when 'immutable' is set`. Para cambiarlo hay que borrarlo y crearlo otra vez, y por eso se suele poner la versión en el nombre (`config-v2`).

## Reto

1. Usa `envFrom` para cargar **todas** las claves de `web-config` como variables en un pod de prueba. ¿Qué pasa con la clave `index.html`? ¿Aparece en `env`? ¿Podrías usarla desde la shell como `$index.html`?
2. Crea un Secret a partir de un archivo `.env` con `kubectl create secret generic app --from-env-file=archivo.env` y compruébalo con `kubectl get secret app -o jsonpath='{.data}'`. Borra el archivo después.
3. ¿Por qué `kubectl describe secret db` no muestra los valores, pero `kubectl get secret db -o yaml` sí? ¿Qué te dice eso sobre quién debería tener permiso para `get` sobre Secrets?

## Destruir al terminar

```bash
kubectl delete pod pagina con-secreto clave-mala sin-secreto --ignore-not-found
kubectl delete configmap fija
kubectl delete secret db
```

Deja `web-config`: `web` lo usa ahora.

## Cierre

En `notas/fase-9/clase-106.md`:

1. Cambias un ConfigMap. ¿Qué ve un pod que lo usa como variable, uno que lo monta como volumen y uno que lo monta con `subPath`?
2. ¿Está cifrado un Secret? ¿Qué lo protege de verdad, en kind y en EKS?
3. ¿Por qué nunca va a Git el YAML de un Secret, ni siquiera en base64? ¿Cómo lo creas entonces?
4. **Repaso (clase 105, sin mirar):** un Service responde `Connection refused` y tiene endpoints. ¿Qué miras?

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Como variable, nada: las variables se leen al arrancar el contenedor. Como volumen, el archivo cambia solo en un minuto o dos (la aplicación aún tiene que releerlo). Con `subPath`, nada, nunca. Para las dos primeras basta un `kubectl rollout restart`.
2. No: `data` es base64, que se deshace con `base64 -d`. Lo protege RBAC, que controla quién puede leerlo; el cifrado en etcd, que kind no tiene y EKS activa por defecto con KMS; y no publicarlo nunca.
3. Porque base64 se lee tal cual: subirlo es publicar la contraseña, y Git no olvida (clase 22). Se crea con `kubectl create secret generic … --from-literal` (o `--from-env-file`) desde la terminal, o lo sincroniza una herramienta desde un almacén como AWS Secrets Manager.
4. Que el `targetPort` del Service sea el puerto en el que de verdad escucha el contenedor.

**Reto 1:** las versiones recientes de Kubernetes aceptan casi cualquier nombre de variable, así que `index.html=<h1>…` aparece en `env`. Pero la shell no puede usarla: `$index.html` se lee como `$index` seguido de `.html`. Solo la vería un programa que lea su entorno directamente. Para archivos, mejor un volumen; para variables, claves con nombres de variable de verdad (`MENSAJE`).

**Reto 3:** `describe` está hecho para personas y oculta los valores para que no salgan en una pantalla compartida. `get -o yaml` devuelve el objeto entero, con `data`. Quien puede hacer `get` sobre Secrets tiene las contraseñas: ese permiso se da con mucho cuidado (clase 110).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| ConfigMap / Secret | configuración / datos sensibles, como objetos del cluster |
| base64 encoding (is not encryption) | codificación base64 (no es cifrado) |
| encryption at rest | cifrado de los datos guardados |
| to mount as a volume | montar como volumen |
| secrets manager | almacén de secretos |

🎙️ *"Kubernetes Secrets are only base64-encoded, so what protects them is RBAC, encryption at rest in etcd and keeping them out of Git. I create them from the command line or sync them from a secrets manager, and I never commit the manifest."*

## Siguiente

[Clase 107 — Sondas, requests y limits](clase-107-sondas-requests-y-limits.md)
