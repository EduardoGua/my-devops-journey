# Clase 90 — Proyecto: Vigía v4: el pipeline completo

**Dónde:** tu Ubuntu + GitHub + AWS · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto y hito · **Proyecto de portafolio**

## Objetivo

Que Vigía tenga un camino automático y seguro desde el commit hasta producción:
1. cada PR pasa el lint, las pruebas y un arranque del stack completo;
2. `main` no admite nada sin todo en verde;
3. al unir, el pipeline construye la imagen, la publica en ECR con OIDC y la despliega en la EC2 por Session Manager;
4. si la versión nueva no responde, vuelve sola a la anterior.

Todo lo aprendiste en las clases 82 a 89 con `lab-actions`; ahora lo montas sin chuleta, en tu proyecto.

Criterios de salida de la fase:
- *un PR con una prueba rota no se puede unir a `main`*;
- *al unir a `main`, la imagen se construye, se publica y se despliega sola*;
- *ninguna credencial de AWS en el repositorio ni en su historial*.

## Costo esperado

> 💰 **Unos 0,15 USD por sesión de 5 horas**, por la instancia de Vigía (clase 78). GitHub Actions, gratis. ECR, céntimos.
>
> Termina la instancia al acabar cada sesión: el pipeline omitirá el despliegue hasta que la vuelvas a lanzar.

## La arquitectura

```
 PR ──► lint · test · imagen (Compose arranca sano)  ──►  ✅ obligatorios (ruleset de main)
                                                            │ squash and merge
 main ──► lint · test · imagen ──► publicar ──────────────► desplegar (entorno production)
                                    │ OIDC → vigia-github      │ OIDC → vigia-github
                                    ▼                          ▼
                       ECR vigia:<SHA del commit>     ssm:SendCommand → EC2 Proyecto=vigia
                                                        └─ git pull + deploy/desplegar.sh <SHA>
                                                             ├─ prueba de humo OK → fin, en verde
                                                             └─ falla → vuelve a la anterior, en rojo
 gh workflow run … -f etiqueta=<SHA> ──► el mismo despliegue, con la versión que elijas
```

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | En cada PR y en cada `push` a `main`, tres jobs:<br>• `lint`: `ruff` y `shellcheck`;<br>• `test`: tus pruebas con `pytest`;<br>• `imagen`: el stack de Compose arranca sano con `docker compose up --build --wait` y `/health` responde | 83 |
| R2 | Todas las *actions* fijadas por su SHA de 40 caracteres. Cada workflow declara `permissions: contents: read`, e `id-token: write` solo lo tienen los jobs que asumen el rol | 82, 85 |
| R3 | `main` protegida con un ruleset, sin excepciones:<br>• pull request obligatorio;<br>• `lint`, `test` e `imagen` obligatorios;<br>• sin *force push* y sin borrado | 84 |
| R4 | El rol `vigia-github`, de OIDC, confía solo en tu repositorio (`repository_id` y `repository_owner_id`), en la rama `main` y en `aud` = `sts.amazonaws.com`. Sus permisos, los mínimos:<br>• subir al repositorio `vigia` de ECR;<br>• buscar la instancia;<br>• `ssm:SendCommand` solo a instancias con `Proyecto=vigia` y con `AWS-RunShellScript`;<br>• leer el resultado | 86, 87, 88 |
| R5 | `AWS_ROLE_ARN` y `AWS_REGION` como **variables**; ningún secreto con llaves de AWS, ni en GitHub ni en el historial de Git | 85, 86 |
| R6 | Al unir a `main`: la imagen `vigia:<SHA completo del commit>` en ECR, con las etiquetas OCI del commit y del repositorio. El job es idempotente | 87 |
| R7 | El despliegue, en el entorno `production`, por Session Manager, con un script `deploy/desplegar.sh` en el repositorio que:<br>1. cambia `VIGIA_IMAGE` en `/opt/vigia/.env`;<br>2. actualiza `api` y `checker` con Compose, sin tocar `db`;<br>3. pasa una prueba de humo: `/health` responde y `/status` devuelve `sites`;<br>4. si falla, vuelve a la imagen anterior y termina con error.<br>El job falla si el despliegue falla, y avisa (sin fallar) si no hay instancia | 88, 89 |
| R8 | Desplegar a mano cualquier versión: `workflow_dispatch` con una etiqueta que se valida como SHA de 40 caracteres | 89 |
| R9 | `verify.sh` → `Fallos: 0`, con la instancia en marcha y el último commit de `main` desplegado | — |
| R10 | En el README:<br>• una sección *CI/CD* con la insignia del pipeline, el camino de un cambio y cómo volver atrás;<br>• *What broke and how I found it*.<br>Etiqueta `v4` y su release | — |

## Plan de trabajo

**Bloque 1: la integración continua y la protección**

1. `git switch main && git pull && git switch -c pipeline`.
2. **R1 y R2:** el workflow con `lint`, `test` e `imagen`.
   - Pásalo por actionlint.
   - Ojo con lo que el runner **no** tiene: no hay `.env`, así que lo generas en el job con una contraseña aleatoria.
3. PR. Cuando los tres jobs estén en verde, une.
4. **R3:** el ruleset. Reutiliza el JSON de la clase 84 con `gh api --method POST "repos/{owner}/{repo}/rulesets" --input …`, o créalo en la web.
5. Comprueba el primer criterio de salida: un PR con una prueba rota **no** se puede unir. Ciérralo sin unir.

**Bloque 2: la entrega y el despliegue**

6. **R4 y R5:**
   - el proveedor OIDC ya existe (clase 86);
   - crea el rol `vigia-github` con su política de confianza y su política *inline*. Guárdalas en el repo como `deploy/confianza-github.json` y `deploy/politica-github.json`, con marcadores en lugar de tus ID;
   - define las dos variables.
7. **R6:** el job `publicar`. Une y comprueba la imagen en ECR.
8. Lanza la instancia de Vigía con tu guía de la v3.
9. **R7 y R8:** `deploy/desplegar.sh` y el workflow de despliegue.
   - El script tiene que estar en `main` **antes** del primer despliegue: la instancia lo trae con `git pull`.
   - Une y mira el despliegue.
10. Las pruebas de aceptación. Después, los Rómpelo.
11. **R10:** el README, el PR, la etiqueta `v4` y la release. Termina la instancia.

### Las pruebas de aceptación

```bash
cd ~/vigia
bash ~/my-devops-journey/recursos/vigia/v4/verify.sh
```

Lo comprueba desde tres sitios, sin cambiar nada:
- **tu repositorio:** actionlint, *actions* fijadas, permisos y que no haya llaves en el historial;
- **GitHub:** que es público, el ruleset, las variables, el entorno y que el pipeline del último commit esté en verde;
- **AWS:** el proveedor OIDC, que el rol confíe solo en tu repositorio y no sea administrador, la imagen del último commit en ECR y que la instancia la esté ejecutando.

Necesita `gh` con sesión, `aws login` y Docker (para actionlint).

## Pistas

<details><summary>Pista 1 — el job <code>imagen</code> de Vigía</summary>

Es el `docker compose up --build --wait` de la clase 66, en el runner:

```yaml
      - run: printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 16)" > .env
      - run: docker compose up -d --build --wait
      - run: curl -fsS 127.0.0.1:8000/health
      - if: failure()
        run: docker compose logs
```

Si alguna vez falla al descargar `postgres:18` con `toomanyrequests`, son los límites de Docker Hub (clase 64): la copia de ECR Public de la clase 78 te saca del apuro.
</details>

<details><summary>Pista 2 — la política de confianza, con los ID de Vigía</summary>

La de la clase 86, con los ID de **este** repositorio:

```bash
cd ~/vigia && gh api 'repos/{owner}/{repo}' --jq '"\(.id) \(.owner.id)"'
```

Recuerda: `aud`, `repository_owner_id`, `repository_id` y `ref` = `refs/heads/main`, todos en el mismo `StringEquals`. Antes de crear el rol, valídala: `aws accessanalyzer validate-policy --policy-type RESOURCE_POLICY --validate-policy-resource-type AWS::IAM::AssumeRolePolicyDocument --policy-document file://deploy/confianza-github.json` (con tus ID sustituidos). Una política de confianza es una política de **recurso**, la del propio rol.
</details>

<details><summary>Pista 3 — los permisos del rol</summary>

Junta lo de las clases 87 y 88, cambiando dos cosas:
- **el repositorio de ECR** es `vigia`;
- **la condición de la instancia** es la etiqueta de Vigía: `"ssm:resourceTag/Proyecto": "vigia"`.

Nada de `AdministratorAccess` ni de `PowerUserAccess`: `verify.sh` lo comprueba.
</details>

<details><summary>Pista 4 — <code>deploy/desplegar.sh</code> con Compose</summary>

La lógica es la de la clase 89, con tres diferencias:
- **La imagen no es un argumento de `docker run`:** está en `.env`. Lee la anterior (`sed -n 's/^VIGIA_IMAGE=//p' .env`), construye la nueva cambiando solo la etiqueta (`${ANTERIOR%:*}:$ETIQUETA`) y escríbela con `sed -i`.
- **Solo se actualizan `api` y `checker`:** `docker compose -f compose.yaml -f compose.aws.yaml pull api checker` y `… up -d --no-build --wait api checker`. La base de datos y sus datos no se tocan.
- **La prueba de humo pide dos cosas:** `/health` en `127.0.0.1:80`, y que `/status` contenga `"sites"`.

El job lo lanza así, por Run Command: `cd /opt/vigia && git pull --ff-only && bash deploy/desplegar.sh <SHA>`. Recuerda construir el JSON de los parámetros con `jq` (clase 88).
</details>

<details><summary>Pista 5 — el despliegue se omite aunque la instancia existe</summary>

El step que la busca filtra por la etiqueta `Proyecto=vigia` y por el estado `running`. Comprueba las dos cosas:

```bash
aws ec2 describe-instances --filters Name=tag:Proyecto,Values=vigia \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
```

Una instancia recién lanzada tarda unos minutos en tener su agente de SSM conectado. Si `send-command` falla con `InvalidInstanceId`, espera y relanza.
</details>

<details><summary>Pista 6 — la instancia nueva arranca con una versión vieja</summary>

Tu guía de la v3 lanza la instancia con la imagen que pusiste en el *user-data* (`3.0.0`), no con la del último commit. Dos arreglos:
- **Desplegar a mano en cuanto arranque:** `gh workflow run <tu workflow> -f etiqueta="$(git rev-parse origin/main)"`.
- **Lanzarla ya con el SHA de `main`:** actualiza la guía para que ponga ese SHA en `__IMAGE__` al lanzar.

Apunta en el README cuál elegiste.
</details>

## Rómpelo: antes de etiquetar

1. **Una prueba rota no entra.** Rompe una prueba en un PR e intenta unirlo con `gh pr merge`. Bloqueado. Ciérralo.
2. **Una versión rota en producción.** Sube a ECR una imagen que no arranca, con una etiqueta de 40 caracteres inventada (como en la clase 89), y despliégala a mano.
   - El job termina en rojo.
   - Vigía sigue respondiendo con la versión anterior.
   - `/status` sigue mostrando el historial: la base de datos no se tocó.
3. **El historial limpio.** Ejecuta tú lo que mira `verify.sh`: `git log --all -p | grep -E 'AKIA[0-9A-Z]{16}'`. Nada. Piensa qué harías si saliera algo: rotar la llave **ya**, porque borrarla del historial no basta (clase 22).
4. **Sin instancia.** Termina la instancia y une un cambio pequeño: `desplegar` avisa de que lo omite y el pipeline queda en verde. Vuelve a lanzarla y despliega `main` a mano.

## Entregable

- **En el repo:**
  - los workflows;
  - `deploy/desplegar.sh`;
  - `deploy/confianza-github.json` y `deploy/politica-github.json`, con marcadores;
  - el README.
- **En GitHub:** el ruleset de `main`, el entorno `production` y las dos variables.
- **En AWS:** el rol `vigia-github` y las imágenes de ECR con el SHA de cada commit.

README en inglés, sección nueva:

````markdown
## CI/CD

[![pipeline](https://github.com/<you>/vigia/actions/workflows/<file>.yml/badge.svg)](https://github.com/<you>/vigia/actions)

How a change reaches production:
1. A pull request runs lint (ruff, shellcheck), unit tests and a full Compose smoke test.
   Main is protected: all three checks are required.
2. On merge, the image is built once and pushed to ECR as `vigia:<commit SHA>`.
   GitHub assumes an IAM role through OIDC: there are no AWS keys anywhere.
3. The deploy job sends `deploy/desplegar.sh` to the instance with SSM Run Command.
   If the smoke test fails, the previous image is restored and the job fails.

Rolling back: `gh workflow run <file>.yml -f etiqueta=<previous commit SHA>`
````

Etiqueta y release:

```bash
git switch main && git pull
git tag -a v4 -m "v4: CI/CD with GitHub Actions, OIDC and SSM deployments"
git push origin v4
gh release create v4 --title "v4" --notes "Every PR is linted, tested and smoke-tested; merges to main publish the image to ECR and deploy it over SSM with automatic rollback. No AWS keys: OIDC."
```

## Destruir al terminar

Termina la instancia de Vigía, como en la clase 78. El rol `vigia-github`, el proveedor OIDC, el repositorio de ECR y el bucket se quedan: no cobran por hora y los usarás en la fase 8. Apúntalo en tu inventario.

## Cierre

En `notas/fase-7/clase-90.md`:

1. Cuenta, en orden, todo lo que pasa desde que abres un PR hasta que el cambio responde en la EC2.
2. ¿Qué tres cosas impiden que alguien despliegue en tu EC2 con tu pipeline sin pasar por un PR revisado y en verde?
3. ¿Qué pasa con los datos de PostgreSQL cuando el pipeline despliega una versión nueva? ¿Y si vuelve atrás?
4. **Repaso (clase 89, sin mirar):** ¿por qué el script termina en rojo aunque la vuelta atrás funcione?

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify.sh</code> termine con <code>Fallos: 0</code></summary>

**Comprueba tu entrega:**
- [ ] `verify.sh` → `Fallos: 0`.
- [ ] Un PR con una prueba rota no se puede unir (Rómpelo 1).
- [ ] Una versión rota desplegada a mano vuelve sola a la anterior (Rómpelo 2).
- [ ] `gh secret list` no muestra nada de AWS, y `deploy/*.json` no tiene tus ID reales.
- [ ] La insignia del README está en verde.
- [ ] `git tag` muestra `v4`, con su release.

**Cierre:**
1. Los pasos:
   1. El PR dispara `lint`, `test` e `imagen` en paralelo, y el ruleset no deja unir hasta que los tres estén en verde.
   2. Al unir, el `push` a `main` repite los tres jobs.
   3. `publicar` entra en AWS por OIDC y sube `vigia:<SHA>` a ECR, o no hace nada si ya existe.
   4. `desplegar`, en el entorno `production`, vuelve a entrar por OIDC y busca la instancia con `Proyecto=vigia`. Le envía por Run Command la orden de hacer `git pull` y ejecutar `deploy/desplegar.sh <SHA>`, y espera el resultado.
   5. En la instancia, el script cambia `VIGIA_IMAGE`, descarga la imagen, actualiza `api` y `checker` y pasa la prueba de humo. Si falla, vuelve a la anterior y termina con error.
2. Tres de estas:
   - **el ruleset de `main`:** PR obligatorio y comprobaciones obligatorias, sin excepciones ni *force push*;
   - **la política de confianza del rol:** solo tu `repository_id` y solo `refs/heads/main`, así que ni otras ramas, ni PR, ni *forks* consiguen credenciales;
   - **los permisos del rol:** solo ECR `vigia` y Run Command en instancias con `Proyecto=vigia`;
   - **el entorno `production`:** solo `main`, y con revisor si lo pusiste.
3. Nada. La base de datos corre en su propio contenedor con su volumen, y el despliegue solo sustituye `api` y `checker`; `db` sigue igual, con sus datos, al desplegar y al volver atrás. Por eso los cambios de esquema tienen que ser compatibles con la versión anterior: si la versión nueva cambiara las tablas, volver atrás podría no funcionar.
4. Porque la versión nueva no está en producción: el despliegue no cumplió su objetivo y alguien tiene que mirar por qué. Un verde ocultaría que `main` y producción ya no coinciden.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| pipeline badge | insignia del pipeline |
| path to production | camino a producción |
| automated rollback | vuelta atrás automática |
| deployment environment | entorno de despliegue |
| release notes | notas de la versión |

🎙️ *"Vigía's pipeline lints, tests and smoke-tests every pull request; main only accepts green changes. On merge it publishes an immutable image to ECR and deploys it over SSM with an automatic rollback, using OIDC instead of AWS keys and least-privilege roles."*

## Siguiente

[Clase 91 — ★ El hito: examen de las fases 4 a 7 y empezar a postular](clase-91-hito.md)
