# Clase 106 — ConfigMaps y Secrets

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Kubernetes desde cero

> 💡 **La idea de hoy:** la imagen es la misma en todos los entornos; lo que cambia llega desde fuera. Un **ConfigMap** guarda configuración y un **Secret**, datos sensibles; el pod los recibe como variables de entorno (que solo se leen al arrancar) o como archivos (que se actualizan solos). Y un Secret **no está cifrado**: base64 se deshace con un comando, así que lo que lo protege es quién puede leerlo y que nunca llegue a Git.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La configuración fuera del código (clase 50) y el `.env` de Compose (clase 65).
> - Que un secreto en Git queda para siempre (clase 22); `openssl rand` para generar contraseñas.
> - El Deployment `web`, `kubectl rollout restart` y la `sonda` (clases 104 y 105).
> - Los volúmenes de un pod y el `emptyDir` (clase 103); KMS (fase 6).

> 🔤 **Palabras nuevas de hoy:**
> - **ConfigMap**: un objeto con pares clave-valor de configuración; un valor puede ser un archivo entero.
> - **Secret**: casi igual, para datos sensibles, con los valores en base64.
> - **`configMapKeyRef` / `secretKeyRef`**: una variable de entorno que sale de una clave.
> - **`subPath`**: montar una sola clave sobre un archivo concreto.
> - **tmpfs**: un sistema de archivos en memoria; ahí se montan los Secrets.
> - **cifrado en reposo** (*encryption at rest*): que etcd guarde los datos cifrados en disco.
> - **`CreateContainerConfigError`**: el contenedor no se crea porque falta una clave o un objeto de configuración.

## Objetivo

- Sacar la configuración de la imagen con un **ConfigMap**, como variables de entorno y como archivos.
- Saber qué pasa cuando cambias un ConfigMap: qué se actualiza solo y qué necesita reiniciar.
- Crear un **Secret** sin dejarlo escrito en ningún archivo, usarlo en un pod y entender qué protege y qué no.
- Reconocer `CreateContainerConfigError` y un volumen que no se puede montar.

## Por qué importa

Es la regla de la clase 50 y del `.env` de la 65: la imagen es la misma en todos los entornos, y lo que cambia (URLs, credenciales, ajustes) llega desde fuera. En Kubernetes, ese "desde fuera" son los ConfigMaps y los Secrets. Vigía v6 lee su `config.yaml` de un ConfigMap y la contraseña de PostgreSQL de un Secret (clase 114).

Y un error de concepto muy común: creer que un Secret está cifrado. Hoy vas a leer uno en claro, directamente de la base de datos del cluster.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min), con los ConfigMaps; el segundo, las **piezas 4 y 5**, con los Secrets, el Rómpelo, el reto y el cierre.

Necesitas la `sonda` y el Deployment `web` de la clase 105:

```bash
mkdir -p ~/my-devops-journey/labs/clase-106 && cd ~/my-devops-journey/labs/clase-106
```

## Las piezas

### Pieza 1 — ConfigMap: como variable y como archivo

Un ConfigMap es un objeto con pares clave-valor. El valor puede ser una palabra o un archivo entero:

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

Un pod lo consume como **variable de entorno** (`env[].valueFrom.configMapKeyRef`, o `envFrom` para todas las claves) o como **archivos en un volumen** (`volumes[].configMap` y un `volumeMount`). Una variante: montar una sola clave sobre un archivo concreto, con `subPath`.

Límites: 1 MiB por ConfigMap.

**Pruébalo.** Guarda el ConfigMap de arriba como `config.yaml` y este pod como `pagina.yaml`. nginx sirve el `index.html` del ConfigMap y además recibe `mensaje` como variable. El mismo archivo se monta otra vez con `subPath`, para comparar en la pieza 2:

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

👀 **Qué deberías ver:** `Hola desde un ConfigMap` y `<h1>Versión 1</h1>`. El `ls` enseña cómo lo hace el kubelet: `index.html` es un enlace a `..data/index.html`, y `..data`, otro enlace a una carpeta con fecha. Para actualizar, el kubelet escribe una carpeta nueva y cambia `..data` de golpe: la aplicación nunca lee un archivo a medio escribir.

✋ **Sin mirar:** ¿cómo recibe un pod **todas** las claves de un ConfigMap como variables, sin escribirlas una a una?

<details>
<summary>Comprueba</summary>

Con `envFrom` y un `configMapRef` con el nombre del ConfigMap (lo probarás en el reto 1).
</details>

**En resumen:** un ConfigMap llega al pod como variable o como archivo.

### Pieza 2 — Cambiar el ConfigMap

| Forma | Si cambias el ConfigMap… |
|-------|--------------------------|
| Variable de entorno | **no** cambia: las variables se leen al arrancar el contenedor |
| Archivos en un volumen | el archivo se actualiza solo, en un minuto o dos |
| Un archivo con `subPath` | **no** cambia nunca |

Aunque el archivo cambie, la aplicación tiene que releerlo, y muchas solo leen su configuración al arrancar. Para esas, `kubectl rollout restart` (clase 104).

**Pruébalo.** En `config.yaml`, cambia `Versión 1` por `Versión 2` y el mensaje por `Adiós`. Aplica:

```bash
kubectl apply -f config.yaml
```

🔮 **Predice:** de las tres formas de consumirlo (la variable, el volumen y el `subPath`), ¿cuál verá el cambio, y cuánto tardará?

```bash
watch -n 5 "kubectl exec pagina -- cat /usr/share/nginx/html/index.html"
```

👀 **Qué deberías ver:** en un minuto o dos aparece `Versión 2`. Sal con `Ctrl+C` y mira las otras dos:

```bash
kubectl exec pagina -- sh -c 'echo "variable: $MENSAJE"; echo "subPath: $(cat /tmp/subpath/index.html)"'
```

La variable sigue diciendo `Hola desde un ConfigMap` y el `subPath`, `Versión 1`. Solo un contenedor nuevo las vería.

✋ **Sin mirar:** ¿por qué un `subPath` nunca ve los cambios?

<details>
<summary>Comprueba</summary>

Porque monta el archivo concreto, no la carpeta con el enlace `..data`: cuando el kubelet cambia el enlace, el `subPath` sigue apuntando al archivo viejo.
</details>

**En resumen:** el volumen se actualiza solo; la variable y el `subPath`, solo con un contenedor nuevo.

### Pieza 3 — Configuración para un Deployment

En un Deployment, la configuración va en la plantilla de los pods. Si llega como variable, cambiar el ConfigMap no basta: hay que crear pods nuevos con `kubectl rollout restart`.

**Pruébalo.** podinfo enseña en su respuesta el valor de la variable `PODINFO_UI_MESSAGE`. Dásela desde el ConfigMap: en el `web.yaml` de la clase 104, dentro del contenedor, añade:

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

👀 **Qué deberías ver:** una actualización gradual (la plantilla cambió) y `"message": "Adiós"`.

Cambia otra vez el mensaje en `config.yaml` y aplica. Los pods de `web` no se enteran: es una variable. Para que lo lean, `kubectl rollout restart deployment/web`, y repite el `wget`: ahora sale el mensaje nuevo.

✋ **Sin mirar:** cambias el ConfigMap que un Deployment usa como variable. ¿Qué comando hace que los pods lo vean?

<details>
<summary>Comprueba</summary>

`kubectl rollout restart deployment/web`: crea pods nuevos, que leen las variables al arrancar.
</details>

**En resumen:** configuración como variable en un Deployment: cambiar el ConfigMap y `rollout restart`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Apaga el cluster con `docker stop lab-control-plane cloud-provider-kind`.

### Pieza 4 — Secret: base64 no es cifrado

Un Secret es casi igual que un ConfigMap, pero:
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

**Pruébalo:**

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

👀 **Qué deberías ver:** `data` con dos valores en base64 (`usuario: dmlnaWE=`) y, al decodificarlo, `vigia`: cualquiera que pueda leer el objeto tiene el valor. Fíjate también en que la contraseña nunca apareció en tu pantalla ni quedó en un archivo: `openssl rand` la generó dentro del comando.

Lo malo sería esto:

```bash
kubectl create secret generic db --from-literal=password=x --dry-run=client -o yaml
```

Ese YAML, con su base64, es exactamente lo que **no** debe acabar en Git.

✋ **Sin mirar:** ¿qué protege de verdad un Secret en tu kind?

<details>
<summary>Comprueba</summary>

Solo quién puede leerlo, y en kind eres administrador. etcd no lo cifra. Así que la protección real es no publicarlo.
</details>

**En resumen:** base64 se lee con un comando; un Secret se crea desde la terminal y nunca va a Git.

### Pieza 5 — Usar un Secret en un pod

Como un ConfigMap: como variable (`secretKeyRef`) o como archivos (`volumes[].secret`). Como volumen, puedes fijar los permisos de los archivos con `defaultMode`, y viven en un tmpfs.

**Pruébalo.** `con-secreto.yaml`:

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

`${#VAR}` cuenta los caracteres sin enseñarlos.

👀 **Qué deberías ver:** `24 caracteres` (12 bytes en hexadecimal); los archivos `password` y `usuario` con permisos `-r--------` (el `0400`); y el `mount`, con `tmpfs`: el secreto está en memoria, no en el disco del nodo.

✋ **Sin mirar:** ¿por qué se cuenta la longitud de la contraseña en lugar de imprimirla?

<details>
<summary>Comprueba</summary>

Para comprobar que llegó sin que aparezca en la pantalla, en el historial ni en una captura.
</details>

**En resumen:** un Secret como variable o como archivos de solo lectura, en memoria.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `kind: ConfigMap` + `data:` | configuración como objeto |
| `env[].valueFrom.configMapKeyRef` · `secretKeyRef` | una variable desde una clave |
| `envFrom: [{configMapRef: {name: …}}]` | todas las claves como variables |
| `volumes[].configMap` · `volumes[].secret` + `volumeMounts` | claves como archivos |
| `subPath: index.html` | una sola clave sobre un archivo (no se actualiza) |
| `kubectl create secret generic db --from-literal=k=v` · `--from-env-file=…` | un Secret sin archivo en Git |
| `kubectl get secret db -o jsonpath='{.data.k}' \| base64 -d` | leer un valor (y ver que no está cifrado) |
| `defaultMode: 0400` | permisos de los archivos del Secret |
| `immutable: true` | un ConfigMap o Secret que no se puede cambiar |

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

`field is immutable when 'immutable' is set`. Para cambiarlo hay que borrarlo y crearlo otra vez, y por eso se suele poner la versión en el nombre (`config-v2`). Con `immutable: true`, además, el kubelet deja de vigilarlo.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Usa `envFrom` para cargar **todas** las claves de `web-config` como variables en un pod de prueba. ¿Qué pasa con la clave `index.html`? ¿Podrías usarla desde la shell como `$index.html`?

> 🧩 **Ejemplo resuelto:** la pieza 1: `env[].valueFrom.configMapKeyRef` cargaba **una** clave, `mensaje`, como `MENSAJE`.

**Ahora tú, con huecos:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: todas
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "sleep 1d"]
      envFrom:
        - ____:
            name: ____
```
Y `kubectl exec todas -- env`. Completa: «La clave `index.html` ____ en `env`. Desde la shell, `$index.html` se lee como ____».

<details>
<summary>Pista</summary>

En la shell, un nombre de variable solo puede tener letras, números y `_`. Prueba `kubectl exec todas -- sh -c 'echo $index.html'`.
</details>

**2.** Crea un Secret a partir de un archivo `.env` y compruébalo. Borra el archivo después.

> 🧩 **Ejemplo resuelto:** la pieza 4: `kubectl create secret generic db --from-literal=usuario=vigia --from-literal=password=…`.

**Ahora tú, con huecos:**
```bash
printf 'API_TOKEN=%s\nMODO=lab\n' "$(openssl rand -hex 8)" > archivo.env
kubectl create secret generic app --from-____=archivo.env
kubectl get secret app -o jsonpath='{.____}'; echo
rm ____
```
Completa: «El Secret tiene ____ claves, una por ____ del archivo».

<details>
<summary>Pista</summary>

`--from-env-file` lee líneas `CLAVE=valor`. En el `jsonpath`, `{.data}` muestra todas las claves con su base64.
</details>

**3.** ¿Por qué `kubectl describe secret db` no muestra los valores, pero `kubectl get secret db -o yaml` sí? ¿Qué te dice eso sobre quién debería tener permiso para `get` sobre Secrets?

> 🧩 **Ejemplo resuelto:** la pieza 4: `get -o yaml` mostraba `data` con los valores en base64, y `base64 -d` los leía.

**Ahora tú, con huecos:** compara `kubectl describe secret db` y `kubectl get secret db -o yaml`. Completa: «`describe` está hecho para ____ y oculta los valores. `get -o yaml` devuelve ____. Quien puede hacer `get` sobre Secrets tiene ____, así que ese permiso…».

<details>
<summary>Pista</summary>

En `describe`, mira qué aparece en lugar de cada valor.
</details>

## Destruir al terminar

```bash
kubectl delete pod pagina con-secreto clave-mala sin-secreto todas --ignore-not-found
kubectl delete configmap fija
kubectl delete secret db app --ignore-not-found
```

Deja `web-config`: `web` lo usa ahora.

## Cierre

En `notas/fase-9/clase-106.md`:

1. Cambias un ConfigMap. ¿Qué ve un pod que lo usa como variable, uno que lo monta como volumen y uno que lo monta con `subPath`? *(3 líneas, una por caso.)*
2. ¿Está cifrado un Secret? ¿Qué lo protege de verdad, en kind y en EKS? *(2 líneas. Empieza así: «No: `data` es base64, que se deshace con… Lo protege…»)*
3. ¿Por qué nunca va a Git el YAML de un Secret, ni siquiera en base64? ¿Cómo lo creas entonces? *(2 líneas. Empieza así: «Porque base64 se lee tal cual:…»)*
4. **Repaso (clase 105, sin mirar):** un Service responde `Connection refused` y tiene endpoints. ¿Qué miras? *(1 línea.)*

Después, escríbeme `examíname clase-106`.

## Autocorrección

<details>
<summary>Ábrelo cuando hayas respondido el cierre</summary>

**Cierre:**
1. Como variable, nada: las variables se leen al arrancar el contenedor. Como volumen, el archivo cambia solo en un minuto o dos (la aplicación aún tiene que releerlo). Con `subPath`, nada, nunca. Para las dos primeras basta un `kubectl rollout restart`.
2. No: `data` es base64, que se deshace con `base64 -d`. Lo protege RBAC, que controla quién puede leerlo; el cifrado en etcd, que kind no tiene y EKS activa por defecto con KMS; y no publicarlo nunca.
3. Porque base64 se lee tal cual: subirlo es publicar la contraseña, y Git no olvida (clase 22). Se crea con `kubectl create secret generic … --from-literal` (o `--from-env-file`) desde la terminal, o lo sincroniza una herramienta desde un almacén como AWS Secrets Manager.
4. Que el `targetPort` del Service sea el puerto en el que de verdad escucha el contenedor.

**Reto 1:** `configMapRef` y `name: web-config`. Las versiones recientes de Kubernetes aceptan casi cualquier nombre de variable, así que `index.html=<h1>…` aparece en `env`. Pero la shell no puede usarla: `$index.html` se lee como `$index` seguido de `.html`. Solo la vería un programa que lea su entorno directamente. Para archivos, mejor un volumen; para variables, claves con nombres de variable de verdad (`MENSAJE`).

**Reto 2:** `--from-env-file=archivo.env`, `{.data}` y `rm archivo.env`. El Secret tiene **dos** claves, `API_TOKEN` y `MODO`, una por línea del archivo, cada una en base64. El archivo se borra porque tiene el valor en claro.

**Reto 3:** `describe` está hecho para personas y oculta los valores (solo enseña cuántos bytes tiene cada uno) para que no salgan en una pantalla compartida. `get -o yaml` devuelve el objeto entero, con `data`. Quien puede hacer `get` sobre Secrets tiene las contraseñas: ese permiso se da con mucho cuidado (clase 110).
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
