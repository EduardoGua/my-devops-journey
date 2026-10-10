# Clase 89 — Estrategias de despliegue y pruebas de humo

**Dónde:** GitHub + tu Ubuntu (AWS CLI) · **Tiempo:** 90 min · **Bloque:** B. Entrega y despliegue continuos

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

## Teoría

### Las estrategias

| Estrategia | Cómo funciona | Corte de servicio | Volver atrás | Coste |
|------------|---------------|-------------------|--------------|-------|
| **Recrear** (*in place*) | parar la versión vieja, arrancar la nueva, en el mismo sitio | **sí**, unos segundos | volver a desplegar la vieja | el mínimo: lo que haces aquí |
| ***Rolling*** | con varias instancias detrás de un balanceador, sustituirlas **una a una**; cada nueva entra solo si pasa su comprobación de salud | no | parar y deshacer las ya sustituidas | sin extra |
| ***Blue/green*** | levantar la versión nueva **entera** al lado (verde), probarla y cambiar el tráfico de golpe; la vieja (azul) sigue lista | no | **instantáneo**: devolver el tráfico al azul | el doble durante el cambio |
| ***Canary*** | mandar un poco del tráfico (5 %) a la versión nueva, mirar errores y latencia, y subir poco a poco | no | dejar el canario en 0 % | la mayor complejidad: necesita métricas (fase 10) |

En AWS, las hacen los balanceadores con Auto Scaling (*instance refresh*), ECS, CodeDeploy o Kubernetes: un *Deployment* hace *rolling* por defecto, como verás en la fase 9.

Un aviso que vale para todas: si la versión nueva **cambia la base de datos**, la vieja tiene que seguir funcionando con el esquema nuevo. Si no, volver atrás no es posible. Los cambios de esquema se hacen compatibles hacia atrás, en dos despliegues.

### La red de seguridad del laboratorio

Con una sola instancia, recrear es lo que hay. Pero se puede recrear con cuidado:

```
apunto la imagen que corre ahora (ANTERIOR)
descargo la NUEVA y la arranco
¿responde la prueba de humo?
   ├── sí → fin, en verde
   └── no → arranco otra vez ANTERIOR, compruebo que responde, y termino en ROJO
```

Termina en rojo **aunque** la vuelta atrás funcione. El pipeline tiene que decir que el despliegue falló: la versión nueva no está en producción y alguien tiene que mirar por qué.

### Las cuatro métricas DORA

Los equipos miden la calidad de su entrega con cuatro números, las métricas **DORA**:

| Métrica | Qué mide |
|---------|----------|
| **Frecuencia de despliegue** | cuántas veces despliegas |
| **Tiempo de entrega** | cuánto tarda un commit en llegar a producción |
| **Tasa de cambios fallidos** | qué porcentaje de despliegues provoca un fallo |
| **Tiempo de recuperación** | cuánto tardas en volver a estar bien tras un fallo |

Tu pipeline ya mejora las cuatro. Son un buen tema de conversación en una entrevista.

## Práctica guiada

Necesitas `lab-saludo` en marcha. Si la borraste, recréala con los pasos 1 y 2 de la clase 88.

```bash
cd ~/my-devops-journey/labs/clase-88
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO=$CUENTA.dkr.ecr.us-east-1.amazonaws.com
ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=lab-saludo Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl -s "http://$IP/info"; echo
```

### 1. El script con vuelta atrás (15 min)

En `lab-actions`, rama `vuelta-atras`, sustituye `scripts/desplegar.sh`:

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

### 2. Un workflow reutilizable (25 min)

Saca el job `desplegar` de `ci.yml` a su propio archivo, `.github/workflows/desplegar.yml`, que se puede **llamar** desde otro workflow y también **lanzar a mano**:

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

### 3. Volver atrás a mano (10 min)

Despliega una versión anterior, por ejemplo la del penúltimo commit de `main`:

```bash
cd ~/lab-actions && git pull
ANTERIOR=$(git rev-parse HEAD~1)
gh workflow run desplegar.yml -f etiqueta="$ANTERIOR"
sleep 15 && gh run watch
curl -s "http://$IP/info"; echo
```

🔮 **Predice:** ¿qué `version` devuelve ahora `/info`? El SHA de `HEAD~1`. La imagen ya existía en ECR, así que volver atrás no reconstruye nada: tarda lo que tarda arrancar un contenedor. Vuelve a la última:

```bash
gh workflow run desplegar.yml -f etiqueta="$(git rev-parse HEAD)"
```

Si el entorno `production` tiene un revisor obligatorio (clase 85), cada despliegue espera tu aprobación.

### 4. Un despliegue que falla, y se arregla solo (20 min)

Para que el pipeline despliegue una versión rota, primero tiene que existir una. Tu CI no dejaría pasar una imagen que no arranca (el job `imagen`), así que la subes tú, desde tu portátil, con una etiqueta inventada de 40 caracteres:

```bash
ROTA=0000000000000000000000000000000000000000
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRO"
printf 'FROM %s\nCMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]\n' \
  "$REGISTRO/lab-actions:$(git rev-parse HEAD)" | docker build -t "$REGISTRO/lab-actions:$ROTA" -
docker push "$REGISTRO/lab-actions:$ROTA" && docker logout "$REGISTRO"
```

La imagen escucha en el 8001 y no en el 8000, como en el Rómpelo 3 de la clase 83. En **otra terminal**, deja corriendo un vigilante que pregunte cada medio segundo:

```bash
while true; do printf '%s ' "$(curl -s -o /dev/null -m 1 -w '%{http_code}' "http://$IP/health")"; sleep 0.5; done
```

Y despliega la rota:

```bash
gh workflow run desplegar.yml -f etiqueta="$ROTA"
sleep 15 && gh run watch
gh run view --log-failed | grep -E "FALLO|VUELTA|Estado"
```

🔮 **Predice:**
- **El job:** termina en **rojo**, con `FALLO` y `VUELTA ATRÁS: restaurada …`.
- **El vigilante:** muestra `200 200 … 000 000 … 200 200`. Hubo un corte mientras se probaba la versión rota y se volvía a la buena: unos 30 segundos, lo que tarda la prueba de humo en rendirse.

Después, la versión buena vuelve a servir sin que hayas tocado nada.

Para el vigilante con `Ctrl+C` y borra la imagen rota:

```bash
aws ecr batch-delete-image --repository-name lab-actions --image-ids imageTag=$ROTA
```

## Rómpelo

**1. Una etiqueta que no es un SHA:**

```bash
gh workflow run desplegar.yml -f etiqueta='latest; echo pwned'
```

El primer step se niega: `no es un SHA de commit`. El job ni siquiera llega a AWS.

**2. Sin versión anterior.** Para el contenedor en la instancia (por Run Command: `docker rm -f saludo`) y despliega la rota otra vez. ¿Qué hace el script? No hay `ANTERIOR`, así que no puede volver: la aplicación queda **caída** y el job en rojo. La red de seguridad solo protege si había algo bueno corriendo. Vuelve a desplegar la última buena.

**3. El corte de un despliegue bueno.** Con el vigilante en marcha, despliega una versión **buena**. ¿Ves algún `000`? Un par, mientras el contenedor viejo se borra y el nuevo arranca. Es el precio de recrear en el mismo sitio. Con dos instancias detrás de un balanceador (*rolling*) o con *blue/green*, sería cero.

## Reto

1. **Blue/green en una sola máquina.** Escribe en tus notas, sin implementarlo, cómo harías *blue/green* en `lab-saludo` con dos contenedores (en los puertos 8001 y 8002) y un nginx delante que decide a cuál manda el tráfico. ¿Qué paso concreto haría el cambio "instantáneo"? Pista: `nginx -s reload` (clase 08).
2. **Tus métricas DORA.** Con `gh api "repos/{owner}/{repo}/deployments" --jq '.[].created_at'`, cuenta cuántos despliegues hiciste esta semana. ¿Cuál fue el tiempo de entrega de tu último cambio, del primer commit del PR a `/info` mostrando su SHA?
3. Mejora el script: que antes de declarar el éxito compruebe también que `/info` devuelve la `version` esperada. ¿Qué fallo detectaría que `/health` no ve?

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

1. Compara *rolling*, *blue/green* y *canary*: cómo funcionan y qué ventaja tiene cada uno.
2. ¿Por qué tu script termina en rojo aunque la vuelta atrás funcione?
3. ¿Por qué hay que validar `inputs.etiqueta` antes de usarla, y cómo lo haces?
4. **Repaso (clase 88, sin mirar):** ¿por qué viaja el script de despliegue en base64?

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

**Reto 3:** que la instancia siga corriendo **otra** versión aunque responda: por ejemplo, si el `docker run` falló sin que nadie lo notara, o si alguien desplegó a mano después. `/health` solo dice que algo responde; `/info` dice **qué** responde.
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
