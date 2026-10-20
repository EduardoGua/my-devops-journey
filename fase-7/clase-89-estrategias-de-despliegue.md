# Clase 89 — Estrategias de despliegue y pruebas de humo

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Entrega y despliegue continuos

> 💡 **La idea de hoy:** en la clase 88, un despliegue que fallaba a mitad dejaba la aplicación **caída**. Hoy conoces las estrategias que evitan el corte (*rolling*, *blue/green*, *canary*) y le das a tu script una **red de seguridad**: si la versión nueva no pasa la prueba de humo, vuelve **sola** a la anterior y el pipeline termina en rojo. Y con un **workflow reutilizable**, volver atrás a mano es un botón.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `desplegar.sh`, el job `desplegar` y el viaje en base64 (clase 88); la prueba de humo (clase 83).
> - `workflow_dispatch` y `needs:` (clase 82); validar la entrada no confiable y pasarla por `env:` (clase 85).
> - El balanceador, sus comprobaciones de salud y Auto Scaling (clase 77); el repositorio inmutable de ECR (clase 75).
> - nginx como proxy delante de otro servicio (clase 61, reto 1).

> 🔤 **Palabras nuevas de hoy:**
> - **estrategia de despliegue**: cómo se sustituye la versión vieja por la nueva.
> - ***rolling*** / ***blue/green*** / ***canary***: sustituir instancias una a una / levantar la nueva entera al lado y cambiar el tráfico de golpe / mandar a la nueva solo un poco del tráfico.
> - **vuelta atrás** (*rollback*): volver a la versión anterior.
> - **workflow reutilizable**: un workflow que otros llaman con `workflow_call`, con sus `inputs`.
> - **métricas DORA**: cuatro números para medir la entrega: frecuencia, tiempo de entrega, tasa de cambios fallidos y tiempo de recuperación.

## Objetivo

- Conocer las estrategias de despliegue: **recrear**, ***rolling***, ***blue/green*** y ***canary***, y qué riesgo reduce cada una.
- Convertir la prueba de humo en una **red de seguridad**: si la versión nueva no responde, el script vuelve **solo** a la anterior.
- Sacar el despliegue a un **workflow reutilizable**, que el pipeline llama y que tú puedes lanzar a mano con cualquier versión: la **vuelta atrás manual**.
- Medir el corte de servicio de tu despliegue y saber qué lo eliminaría.

## Por qué importa

En la clase 88 viste el peor caso: un despliegue que falla a mitad deja la aplicación **caída**. En la vida real, el pipeline ya no está en verde, alguien se entera por los usuarios, y la primera pregunta en el incidente es "¿cómo volvemos a la versión de antes?".

Si la respuesta es "un botón" o, mejor, "volvió sola", el incidente dura minutos.

En una entrevista te preguntarán por *blue/green* y *canary*. Y la métrica que más miran los equipos es el **tiempo de recuperación**: cuánto tardas en volver a estar bien.

## Costo esperado

> 💰 **Unos 0,05 USD:** la t3.micro `lab-saludo` durante una o dos horas. Al final destruyes todo el laboratorio de la fase.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto, la limpieza de la fase y el cierre.

**Preparación:** necesitas `lab-saludo` en marcha. Si la borraste, recréala con la preparación y las piezas 1 y 2 de la clase 88.

```bash
cd ~/my-devops-journey/labs/clase-88
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=lab-saludo Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl -s "http://$IP/info"; echo
```

## Las piezas

### Pieza 1 — Las estrategias de despliegue

| Estrategia | Cómo funciona | Corte de servicio | Volver atrás | Coste |
|------------|---------------|-------------------|--------------|-------|
| **Recrear** (*in place*) | parar la versión vieja, arrancar la nueva, en el mismo sitio | **sí**, unos segundos | volver a desplegar la vieja | el mínimo: lo que haces aquí |
| ***Rolling*** | con varias instancias detrás de un balanceador, sustituirlas **una a una**; cada nueva entra solo si pasa su comprobación de salud | no | parar y deshacer las ya sustituidas | sin extra |
| ***Blue/green*** | levantar la versión nueva **entera** al lado (verde), probarla y cambiar el tráfico de golpe; la vieja (azul) sigue lista | no | **instantáneo**: devolver el tráfico al azul | el doble durante el cambio |
| ***Canary*** | mandar un poco del tráfico (5 %) a la versión nueva, mirar errores y latencia, y subir poco a poco | no | dejar el canario en 0 % | la mayor complejidad: necesita métricas (fase 10) |

En AWS, las hacen los balanceadores con Auto Scaling (*instance refresh*), ECS, CodeDeploy o Kubernetes: un *Deployment* hace *rolling* por defecto, como verás en la fase 9.

Un aviso que vale para todas: si la versión nueva **cambia la base de datos**, la vieja tiene que seguir funcionando con el esquema nuevo. Si no, volver atrás no es posible. Los cambios de esquema se hacen compatibles hacia atrás, en dos despliegues.

**Pruébalo, en papel.** ¿Qué estrategia elegirías? Escríbelo antes de abrir la respuesta:

1. Una tienda en línea que no puede tener ni un segundo de corte y necesita poder volver atrás al instante.
2. Un cambio arriesgado en el algoritmo de recomendaciones: quieres probarlo con pocos usuarios reales primero.
3. Diez instancias iguales detrás de un balanceador, y no quieres pagar el doble.
4. Tu laboratorio, con una sola instancia.

<details>
<summary>Comprueba</summary>

1, *blue/green*. 2, *canary*. 3, *rolling*. 4, recrear: con una sola instancia no hay otra.
</details>

✋ **Sin mirar:** ¿qué estrategia tiene la vuelta atrás instantánea, y qué cuesta?

<details>
<summary>Comprueba</summary>

*Blue/green*: basta con devolver el tráfico al azul. Cuesta el doble de infraestructura durante el cambio.
</details>

**En resumen:** recrear corta; *rolling* sustituye de una en una; *blue/green* cambia de golpe y vuelve al instante; *canary* prueba con poco tráfico.

### Pieza 2 — La red de seguridad: el script con vuelta atrás

Con una sola instancia, recrear es lo que hay. Pero se puede recrear con cuidado:

```
apunto la imagen que corre ahora (ANTERIOR)
descargo la NUEVA y la arranco
¿responde la prueba de humo?
   ├── sí → fin, en verde
   └── no → arranco otra vez ANTERIOR, compruebo que responde, y termino en ROJO
```

Termina en rojo **aunque** la vuelta atrás funcione. El pipeline tiene que decir que el despliegue falló: la versión nueva no está en producción y alguien tiene que mirar por qué.

**Pruébalo.** En `lab-actions`, rama `vuelta-atras`, sustituye `scripts/desplegar.sh`:

```bash
#!/bin/bash
# desplegar.sh IMAGEN — corre IMAGEN como el contenedor "saludo" en el puerto 80.
# Si no responde, vuelve a la imagen que estaba corriendo antes y termina con error.
set -euo pipefail
IMAGEN="${1:?Uso: desplegar.sh IMAGEN}"
ANTERIOR=$(docker inspect --format '{{.Config.Image}}' saludo 2>/dev/null || true)

arrancar() {
  docker rm -f saludo >/dev/null 2>&1 || true
  docker run -d --name saludo --restart unless-stopped -p 80:8000 "$1" >/dev/null
}

responde() {
  for _ in $(seq 1 15); do
    curl -fsS -m 2 http://127.0.0.1/health >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

docker pull --quiet "$IMAGEN"
arrancar "$IMAGEN"
if responde; then
  echo "OK: $IMAGEN responde (antes: ${ANTERIOR:-ninguna})"
  exit 0
fi
echo "FALLO: $IMAGEN no responde. Sus últimas líneas de log:" >&2
docker logs --tail 10 saludo >&2 || true
if [[ -n $ANTERIOR ]] && arrancar "$ANTERIOR" && responde; then
  echo "VUELTA ATRÁS: restaurada $ANTERIOR" >&2
fi
exit 1
```

- **`docker inspect --format '{{.Config.Image}}'`:** la imagen exacta del contenedor actual, antes de tocar nada.
- **El `docker pull` va antes de parar nada:** si la imagen nueva no existe o no se puede descargar, la aplicación sigue en pie con la vieja.
- Ese `{{…}}` es uno de los motivos por los que el script viaja en base64 (clase 88).

```bash
cd ~/lab-actions && git switch main && git pull && git switch -c vuelta-atras
# (sustituye scripts/desplegar.sh por el de arriba)
bash -n scripts/desplegar.sh && echo "sintaxis correcta"
```

👀 **Qué deberías ver:** `sintaxis correcta`. Lo probarás de verdad en la pieza 5, con una versión rota.

✋ **Sin mirar:** ¿por qué el `docker pull` de la imagen nueva va antes de borrar el contenedor que corre?

<details>
<summary>Comprueba</summary>

Para que, si la imagen nueva no existe o no se puede descargar, el script falle con la versión vieja todavía en pie.
</details>

**En resumen:** apuntar la anterior → descargar y arrancar la nueva → prueba de humo → si falla, volver a la anterior y terminar en rojo.

### Pieza 3 — Un workflow reutilizable

Un workflow con **`workflow_call`** se puede **llamar** desde otro, y con `workflow_dispatch`, **lanzar a mano**. Los dos reciben el mismo parámetro, `inputs.etiqueta`. Así, el pipeline y el botón despliegan con exactamente el mismo código.

**Pruébalo.** Saca el job `desplegar` de `ci.yml` a su propio archivo, `.github/workflows/desplegar.yml`:

```yaml
name: desplegar

on:
  workflow_call:
    inputs:
      etiqueta:
        type: string
        required: true
  workflow_dispatch:
    inputs:
      etiqueta:
        description: "Etiqueta de la imagen que quieres desplegar (el SHA completo de un commit)"
        type: string
        required: true

permissions:
  contents: read

jobs:
  desplegar:
    runs-on: ubuntu-24.04
    environment: production
    permissions:
      contents: read
      id-token: write
    steps:
      - name: La etiqueta es un SHA de 40 caracteres
        env:
          ETIQUETA: ${{ inputs.etiqueta }}
        run: |
          [[ $ETIQUETA =~ ^[0-9a-f]{40}$ ]] || { echo "::error::'$ETIQUETA' no es un SHA de commit"; exit 1; }
      # … los steps de la clase 88, iguales, salvo dos líneas:
      #     en el step "Desplegar", añade a su env:  ETIQUETA: ${{ inputs.etiqueta }}
      #     y la imagen pasa a ser:  IMAGEN="$CUENTA.dkr.ecr.us-east-1.amazonaws.com/lab-actions:$ETIQUETA"
```

Completa los steps a partir de los de la clase 88. Después, en `ci.yml`, el job `desplegar` queda así:

```yaml
  desplegar:
    needs: publicar
    permissions:
      contents: read
      id-token: write
    uses: ./.github/workflows/desplegar.yml
    with:
      etiqueta: ${{ github.sha }}
```

Tres cosas nuevas:
- **`uses:` en el nivel del job** llama a otro workflow del repositorio, que se fija por su ruta (`./`) y no por SHA: es tu propio código. Un job así no lleva `runs-on` ni `steps`.
- **`inputs.etiqueta`:** el parámetro. Llega igual desde el pipeline (`with:`) y desde el botón (`workflow_dispatch`).
- **La primera comprobación:** un dato que escribe una persona es entrada no confiable (clase 85). Va por `env:` y se valida con una expresión regular antes de usarlo: solo un SHA de 40 caracteres hexadecimales. Si no, el job se para antes de tocar AWS.

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
git add -A && git commit -m "Despliegue reutilizable con vuelta atrás" && git push -u origin vuelta-atras
gh pr create --fill && gh pr checks --watch && gh pr merge --squash --delete-branch
sleep 10 && gh run watch
```

👀 **Qué deberías ver:** actionlint sin salida; en `main`, el job `desplegar` con el nombre `desplegar / desplegar` (el job que llama y el job llamado), y `/info` con el SHA del commit nuevo.

✋ **Sin mirar:** ¿por qué se valida `inputs.etiqueta` antes de hacer nada?

<details>
<summary>Comprueba</summary>

Porque en `workflow_dispatch` la escribe una persona: es entrada no confiable. Solo se acepta un SHA de 40 caracteres hexadecimales.
</details>

**En resumen:** `workflow_call` + `workflow_dispatch` con el mismo `input`; el pipeline lo llama con `uses: ./…` y `with:`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: el bloque de preparación.

### Pieza 4 — Volver atrás a mano

Las imágenes de cada commit ya están en ECR (clase 87). Volver atrás no reconstruye nada: es desplegar una etiqueta anterior, y tarda lo que tarda arrancar un contenedor.

🔮 **Predice:** ¿qué `version` devolverá `/info` después de desplegar `HEAD~1`?

**Pruébalo:**

```bash
cd ~/lab-actions && git switch main && git pull
ANTERIOR=$(git rev-parse HEAD~1)
gh workflow run desplegar.yml -f etiqueta="$ANTERIOR"
sleep 15 && gh run watch
curl -s "http://$IP/info"; echo
gh workflow run desplegar.yml -f etiqueta="$(git rev-parse HEAD)"
```

👀 **Qué deberías ver:** `/info` con el SHA de `HEAD~1`, y después de la última orden, otra vez el de `HEAD`. Si el entorno `production` tiene un revisor obligatorio (clase 85), cada despliegue espera tu aprobación.

✋ **Sin mirar:** ¿por qué volver atrás tarda tan poco?

<details>
<summary>Comprueba</summary>

Porque la imagen de esa versión ya existe en ECR: solo hay que descargarla y arrancarla, sin construir nada.
</details>

**En resumen:** `gh workflow run desplegar.yml -f etiqueta=<SHA>`: cualquier versión publicada, a un botón.

### Pieza 5 — Un despliegue que falla, y se arregla solo

Para que el pipeline despliegue una versión rota, primero tiene que existir una. Tu CI no dejaría pasar una imagen que no arranca (el job `imagen`), así que la subes tú, desde tu portátil, con una etiqueta inventada de 40 caracteres. La imagen escucha en el 8001 y no en el 8000, como en el Rómpelo 3 de la clase 83.

**Pruébalo:**

```bash
ROTA=0000000000000000000000000000000000000000
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRO"
printf 'FROM %s\nCMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]\n' \
  "$REGISTRO/lab-actions:$(git rev-parse HEAD)" | docker build -t "$REGISTRO/lab-actions:$ROTA" -
docker push "$REGISTRO/lab-actions:$ROTA" && docker logout "$REGISTRO"
```

En **otra terminal**, deja corriendo un vigilante que pregunte cada medio segundo:

```bash
while true; do printf '%s ' "$(curl -s -o /dev/null -m 1 -w '%{http_code}' "http://$IP/health")"; sleep 0.5; done
```

🔮 **Predice:** ¿cómo terminará el job, y qué verá el vigilante?

Despliega la rota:

```bash
gh workflow run desplegar.yml -f etiqueta="$ROTA"
sleep 15 && gh run watch
gh run view --log-failed | grep -E "FALLO|VUELTA|Estado"
```

👀 **Qué deberías ver:** el job en **rojo**, con `FALLO: … no responde` y `VUELTA ATRÁS: restaurada …`. El vigilante muestra `200 200 … 000 000 … 200 200`: hubo un corte mientras se probaba la versión rota y se volvía a la buena, unos 30 segundos, lo que tarda la prueba de humo en rendirse. Después, la versión buena vuelve a servir sin que hayas tocado nada.

Para el vigilante con `Ctrl+C` y borra la imagen rota:

```bash
aws ecr batch-delete-image --repository-name lab-actions --image-ids imageTag=$ROTA
```

✋ **Sin mirar:** la vuelta atrás funcionó. ¿Por qué el job termina en rojo de todos modos?

<details>
<summary>Comprueba</summary>

Porque la versión nueva no llegó a producción: alguien tiene que saberlo y mirar por qué. En verde, el pipeline mentiría.
</details>

**En resumen:** versión rota → prueba de humo falla → vuelta atrás sola → job rojo; el corte, lo que tarda la prueba en rendirse.

### Pieza 6 — Las métricas DORA

Los equipos miden la calidad de su entrega con cuatro números, las métricas **DORA**:

| Métrica | Qué mide |
|---------|----------|
| **Frecuencia de despliegue** | cuántas veces despliegas |
| **Tiempo de entrega** | cuánto tarda un commit en llegar a producción |
| **Tasa de cambios fallidos** | qué porcentaje de despliegues provoca un fallo |
| **Tiempo de recuperación** | cuánto tardas en volver a estar bien tras un fallo |

Tu pipeline ya mejora las cuatro. Son un buen tema de conversación en una entrevista.

**Pruébalo:** GitHub guarda cada despliegue en `production` (clase 85).

```bash
gh api "repos/{owner}/{repo}/deployments" --jq 'length'
gh api "repos/{owner}/{repo}/deployments" --jq '.[] | .created_at' | head -5
```

👀 **Qué deberías ver:** el número de despliegues (los de las clases 88 y 89) y las fechas de los cinco últimos, en UTC. Es tu **frecuencia de despliegue**; el despliegue roto de la pieza 5, con su vuelta atrás en unos 30 segundos, es un dato de tu **tiempo de recuperación**.

✋ **Sin mirar:** ¿qué métrica DORA mide cuánto tarda un commit en llegar a producción?

<details>
<summary>Comprueba</summary>

El tiempo de entrega (*lead time*).
</details>

**En resumen:** frecuencia, tiempo de entrega, tasa de cambios fallidos y tiempo de recuperación: tu pipeline las mueve todas a mejor.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker inspect --format '{{.Config.Image}}' saludo` | la imagen que corre ahora |
| `docker pull` antes de `docker rm -f` | no tumbar nada si la nueva no se descarga |
| `on: workflow_call: inputs: …` + `workflow_dispatch: inputs: …` | un workflow reutilizable y a mano |
| `uses: ./.github/workflows/desplegar.yml` + `with: etiqueta: …` | llamarlo desde otro workflow |
| `[[ $ETIQUETA =~ ^[0-9a-f]{40}$ ]]` | validar que es un SHA |
| `gh workflow run desplegar.yml -f etiqueta=<SHA>` | volver atrás (o adelante) a mano |
| `aws ecr batch-delete-image --image-ids imageTag=…` | borrar una imagen concreta |
| `gh api "repos/{owner}/{repo}/deployments"` | el historial de despliegues |
| recrear · *rolling* · *blue/green* · *canary* | las estrategias |

## Rómpelo

**1. Una etiqueta que no es un SHA:**

```bash
gh workflow run desplegar.yml -f etiqueta='latest; echo pwned'
```

El primer step se niega: `no es un SHA de commit`. El job ni siquiera llega a AWS.

**2. Sin versión anterior.** Para el contenedor en la instancia (por Run Command: `docker rm -f saludo`) y despliega la rota otra vez. ¿Qué hace el script? No hay `ANTERIOR`, así que no puede volver: la aplicación queda **caída** y el job en rojo. La red de seguridad solo protege si había algo bueno corriendo. Vuelve a desplegar la última buena.

**3. El corte de un despliegue bueno.** Con el vigilante en marcha, despliega una versión **buena**. ¿Ves algún `000`? Un par, mientras el contenedor viejo se borra y el nuevo arranca. Es el precio de recrear en el mismo sitio. Con dos instancias detrás de un balanceador (*rolling*) o con *blue/green*, sería cero.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** **Blue/green en una sola máquina.** Describe, sin implementarlo, cómo harías *blue/green* en `lab-saludo` con dos contenedores y un nginx delante.

> 🧩 **Ejemplo resuelto:** el reto 1 de la clase 61: un nginx con `location / { proxy_pass http://api:8000; }` que manda el tráfico a otro contenedor.

**Ahora tú, con huecos** (cópialo en tus notas y rellena):
```markdown
- Contenedor azul en el puerto ____ y verde en el ____; nginx en el 80 con `proxy_pass http://127.0.0.1:____;`.
- Desplegar: arranco la versión nueva en el puerto que está ____, pruebo su `/health` en ese puerto,
  cambio el `proxy_pass` a ese puerto y hago `nginx -s ____`: el cambio es instantáneo.
- Volver atrás: ____.
```

<details>
<summary>Pista</summary>

Usa 8001 y 8002. `nginx -s reload` (dentro de un contenedor) o `systemctl reload nginx` (clase 12) relee la configuración sin cortar las conexiones que ya existen. Para volver, el contenedor viejo sigue arrancado.
</details>

**2.** **Tu tiempo de entrega.** ¿Cuánto tardó tu último cambio desde que abriste su PR hasta que `/info` mostró su SHA?

> 🧩 **Ejemplo resuelto:** la pieza 6: `gh api "repos/{owner}/{repo}/deployments" --jq '.[] | .created_at'` da la hora de cada despliegue.

**Ahora tú, con huecos:**
```bash
gh pr list --state merged --limit 1 --json number,createdAt,mergedAt
gh api "repos/{owner}/{repo}/deployments" --jq '.[0].created_at'
```
Completa: «PR abierto a las ____, unido a las ____, desplegado a las ____: tiempo de entrega, unos ____ minutos».

<details>
<summary>Pista</summary>

Las tres horas salen en UTC, así que se pueden restar directamente. El despliegue más reciente es el primero de la lista.
</details>

**3.** Mejora el script: que antes de declarar el éxito compruebe también que `/info` devuelve la `version` esperada. ¿Qué fallo detectaría que `/health` no ve?

> 🧩 **Ejemplo resuelto:** la función `responde()` del script, que pregunta a `/health` hasta 15 veces.

**Ahora tú, con huecos:**
```bash
version_ok() {
  curl -fsS -m 2 http://127.0.0.1/info | grep -q "\"version\":\"$____\""
}
# … y en lugar de `if responde; then`:
if responde && version_ok "${IMAGEN##*____}"; then
```
Completa: «Detectaría que…».

<details>
<summary>Pista</summary>

`${IMAGEN##*:}` quita todo hasta el último `:` y deja la etiqueta, es decir, el SHA (clase 16). Dentro de la función, el primer argumento es `$1`.
</details>

## Destruir al terminar

Aquí termina el laboratorio de la fase 7. Destrúyelo entero, menos el proveedor OIDC:

```bash
cd ~/my-devops-journey/labs/clase-71 && bash borrar-vpc.sh
aws iam remove-role-from-instance-profile --instance-profile-name lab-saludo --role-name lab-saludo
aws iam delete-instance-profile --instance-profile-name lab-saludo
aws iam detach-role-policy --role-name lab-saludo --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam detach-role-policy --role-name lab-saludo --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly
aws iam delete-role --role-name lab-saludo
aws iam delete-role-policy --role-name lab-github --policy-name subir-a-ecr
aws iam delete-role-policy --role-name lab-github --policy-name desplegar
aws iam delete-role --role-name lab-github
aws ecr delete-repository --repository-name lab-actions --force --query repository.repositoryName --output text
cd ~/lab-actions && gh variable delete AWS_ROLE_ARN
```

El repositorio `lab-actions` de GitHub puede quedarse como ejemplo, o archivarlo con `gh repo archive`. El pipeline omitirá el despliegue porque ya no hay instancia, y fallará al publicar porque ya no hay rol: si lo vas a dejar, quita los jobs `publicar` y `desplegar`. Actualiza tu inventario: solo debe quedar el proveedor OIDC, que usará Vigía.

## Cierre

En `notas/fase-7/clase-89.md`:

1. Compara *rolling*, *blue/green* y *canary*: cómo funcionan y qué ventaja tiene cada uno. *(3 líneas, una por estrategia. Empieza así: «Rolling: sustituye las instancias una a una detrás de un balanceador;…»)*
2. ¿Por qué tu script termina en rojo aunque la vuelta atrás funcione? *(1–2 líneas. Empieza así: «Porque la versión nueva no llegó a producción:…»)*
3. ¿Por qué hay que validar `inputs.etiqueta` antes de usarla, y cómo lo haces? *(2 líneas. Empieza así: «Porque la escribe una persona en un formulario: es entrada no confiable… La paso por `env:` y…»)*
4. **Repaso (clase 88, sin mirar):** ¿por qué viaja el script de despliegue en base64? *(1–2 líneas. Empieza así: «Para que sus comillas, sus `$` y sus saltos de línea…»)*

Después, escríbeme `examíname clase-89`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.**
- **Rolling:** sustituye las instancias una a una detrás de un balanceador, y cada nueva entra solo si pasa su comprobación de salud. Sin corte y sin coste extra, pero durante un rato conviven las dos versiones.
- **Blue/green:** levanta la versión nueva completa al lado, la prueba y cambia todo el tráfico de golpe. Volver atrás es instantáneo (devolver el tráfico al azul), a cambio de pagar el doble durante el cambio.
- **Canary:** manda una parte pequeña del tráfico a la versión nueva y la aumenta si las métricas van bien. Es el que menos usuarios expone a un fallo, pero necesita buenas métricas para decidir.

**2.** Porque el objetivo del despliegue, la versión nueva en producción, no se cumplió: alguien tiene que saber que falló y arreglarlo. Si terminara en verde, el pipeline mentiría: `main` diría una versión y producción correría otra.

**3.** Porque la escribe una persona en un formulario: es entrada no confiable. Usada tal cual podría inyectar órdenes (clase 85) o desplegar algo que no es una imagen del pipeline. Se pasa por `env:` y se valida con `[[ $ETIQUETA =~ ^[0-9a-f]{40}$ ]]` antes de hacer nada.

**4.** Para que sus comillas, sus `$` y sus saltos de línea no se mezclen con el JSON de los parámetros de `send-command`, y para que SSM no interprete sus `{{ … }}` como referencias propias. En base64, el script es una cadena de letras y números que la instancia decodifica tal cual.

**Reto 1:** azul en el 8001 y verde en el 8002 (o al revés); nginx con `proxy_pass` al que está activo. Desplegar: la nueva en el puerto que está **libre**, prueba de su `/health` en ese puerto, cambiar el `proxy_pass` y `nginx -s reload`. Volver atrás: cambiar el `proxy_pass` al puerto del contenedor viejo, que sigue arrancado, y otro `reload`.

**Reto 2:** respuesta personal; con un pipeline como el tuyo, lo normal es que el despliegue llegue entre 5 y 10 minutos después de unir el PR.

**Reto 3:** `$1` y `${IMAGEN##*:}`. Detectaría que la instancia sigue corriendo **otra** versión aunque responda: por ejemplo, si el `docker run` falló sin que nadie lo notara, o si alguien desplegó a mano después. `/health` solo dice que algo responde; `/info` dice **qué** responde.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| rolling update / blue-green / canary deployment | actualización gradual / despliegue azul-verde / canario |
| rollback | vuelta atrás |
| downtime | tiempo sin servicio |
| reusable workflow | workflow reutilizable |
| DORA metrics: deployment frequency, lead time, change failure rate, time to restore | frecuencia de despliegue, tiempo de entrega, tasa de cambios fallidos, tiempo de recuperación |

🎙️ *"My deploy script records the running version, deploys the new one and runs a smoke test; if it fails, it restores the previous version automatically and fails the pipeline so someone investigates. In production I'd use rolling or blue/green behind a load balancer to avoid the few seconds of downtime."*

## Siguiente

[Clase 90 — Vigía v4: el pipeline completo](clase-90-vigia-v4.md)
