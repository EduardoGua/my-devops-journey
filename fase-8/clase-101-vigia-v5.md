# Clase 101 — Proyecto: Vigía v5: toda la infraestructura en Terraform

**Dónde:** tu Ubuntu + AWS + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

## Objetivo

Cerrar Vigía v5. Toda su infraestructura vive en `infra/`, y la prueba de fuego es **destruirla entera y recrearla desde cero** sin tocar nada a mano:
- con el estado en S3, versionado y con bloqueo;
- con la red en un módulo propio;
- con cada PR de infraestructura planificado en el pipeline.

Si eso funciona, la infraestructura es de verdad código: reproducible, revisable y explicable. Al final, el apéndice te cuenta qué te falta para el **Terraform Associate (004)**, por si quieres certificarte.

Criterios de salida de la fase:
- *recrear desde cero la infraestructura de Vigía con `terraform apply` y borrarla con `terraform destroy`*;
- *estado en S3 con versionado y `use_lockfile = true`*;
- *al menos un módulo propio con variables y outputs*;
- *explicar qué pasa si alguien cambia a mano un recurso que maneja Terraform*.

## Costo esperado

> 💰 **Unos 0,15 USD por sesión de 5 horas**, por la instancia. Destruir y recrear no cuesta más que dejarlo encendido el mismo rato.

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | `infra/estado/` crea el bucket `vigia-tfstate-<cuenta>` con versionado, sin acceso público y con `prevent_destroy`. Su estado local se guarda fuera de Git | 96, 97 |
| R2 | En `infra/`:<br>• backend S3 con `use_lockfile = true` (sin DynamoDB) y el bucket por configuración parcial;<br>• versiones de Terraform y del provider fijadas;<br>• `.terraform.lock.hcl` en Git | 93, 96 |
| R3 | Toda la infraestructura en código, con `default_tags` (`Proyecto = "vigia"`):<br>• la red y el security group;<br>• ECR, el bucket de informes y los grupos de logs;<br>• los roles: la instancia, el pipeline y el `plan`;<br>• el proveedor OIDC;<br>• la instancia con su cloud-init | 97, 100 |
| R4 | La red es un módulo propio, en `infra/modules/red/`, con `variables.tf` y `outputs.tf` | 98 |
| R5 | Las variables llevan descripción y tipo. `mi_ip` está validada y es sensible. `terraform.tfvars` queda fuera de Git, y `terraform.tfvars.example`, dentro | 94, 99, 100 |
| R6 | Outputs, al menos: `url`, `bucket_informes`, `instancia_id`, `repositorio_ecr` y `rol_github` | 94 |
| R7 | Ningún secreto en el código ni en el estado: la contraseña de PostgreSQL sigue naciendo dentro de la instancia | 99 |
| R8 | `.github/workflows/terraform.yml`: `fmt`, `validate` y `plan` en los PR que tocan `infra/`, con el rol de solo lectura | 100 |
| R9 | **Destruir y recrear desde cero:** `terraform destroy` (todo menos el bucket del estado) y la recreación de abajo, sin tocar nada a mano en AWS. Apunta cuánto tarda | — |
| R10 | `verify.sh` → `Fallos: 0` | — |
| R11 | En el README:<br>• una sección *Infrastructure*: el arranque del estado, cómo recrearlo todo y cómo destruirlo;<br>• *What broke and how I found it*;<br>• *Limitations*.<br>Etiqueta `v5` y su release | — |

### Por qué hace falta una receta para recrear

La instancia, al arrancar, descarga **su imagen de ECR**. Pero después de un `destroy` completo:
- el repositorio de ECR ya no existe;
- tampoco el rol con el que el pipeline publica las imágenes.

Si aplicas todo de golpe, la instancia arranca antes de que haya ninguna imagen que descargar. Es otro huevo y otra gallina, y se resuelve en tres pasos:

```
1. terraform apply -target=…    → solo ECR y el rol del pipeline (con su proveedor OIDC)
2. gh workflow run <pipeline>   → el pipeline publica vigia:<SHA de main> (el despliegue se omite: no hay instancia)
3. terraform apply              → todo lo demás; la instancia arranca con esa imagen
```

Es el único sitio del curso donde `-target` está justificado: un arranque en orden, escrito en el README.

Y para que `destroy` pueda borrarlo **todo**:
- el repositorio de ECR necesita `force_delete = true`, o se negaría a borrarse con imágenes dentro;
- el bucket de informes necesita `force_destroy = true`, o se negaría a borrarse con informes dentro.

Es el precio de que `destroy` borre de verdad. En producción, los datos de larga vida irían en **otra configuración**, con su propio estado y su `prevent_destroy`, como el bucket del estado. Apúntalo en *Limitations*.

## Plan de trabajo

**Bloque 1: completar y revisar**

1. Repasa el contrato contra tu `infra/`. Lo que falte (outputs, descripciones, la validación de `mi_ip`, `force_delete` y `force_destroy`) en una rama `v5`.
2. `terraform fmt -recursive infra`, `validate` y `plan`: **`No changes`** antes de seguir (salvo lo que acabas de añadir).
3. Pasa las pruebas de aceptación una primera vez, con la infraestructura en marcha:

   ```bash
   cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v5/verify.sh
   ```
4. PR. El workflow de Terraform planifica tus cambios: revísalos en GitHub, une y aplica.

**Bloque 2: destruir y recrear desde cero**

5. Apunta la hora y destruye:

   ```bash
   cd ~/vigia/infra && terraform destroy
   ```

   Lee el plan de destrucción entero antes de escribir `yes`. Comprueba que **no** queda nada con `Proyecto=vigia` salvo el bucket del estado (pista 3).
6. Recrea con la receta de arriba. En el paso 3, pon en `terraform.tfvars` (y en la variable `TF_ETIQUETA_IMAGEN` de GitHub) el SHA que acaba de publicar el pipeline.
7. Espera a que la instancia arranque, lanza el informe a mano (clase 79) y pasa `verify.sh`: `Fallos: 0`. Apunta la hora: ¿cuánto tardó, de `destroy` a todo en verde?
8. README, PR, etiqueta `v5` y release. Termina la instancia si no vas a seguir (`terraform destroy -target=aws_instance.vigia`).

### Las pruebas de aceptación

`verify.sh` comprueba, sin aplicar nada:
- **el código:** `fmt`, las versiones fijadas, el backend con `use_lockfile`, el módulo propio, `default_tags` y que no haya secretos escritos;
- **Git:** el `.terraform.lock.hcl` dentro, y fuera los estados, `.terraform/` y `terraform.tfvars`;
- **el workflow** de `fmt` y `plan`;
- **el bucket del estado:** versionado, sin acceso público y con el estado dentro;
- **que AWS coincide con el código:** un `plan` **sin cambios**;
- **los outputs** `url` y `bucket_informes`;
- y, al final, el `verify-aws.sh` de la v3 entero.

Necesita `terraform init` hecho en `infra/` y `aws login`.

## Pistas

<details><summary>Pista 1 — el <code>-target</code> del paso 1</summary>

```bash
terraform apply -target=aws_ecr_repository.vigia -target=aws_iam_role_policy.github_pipeline
```

Con los nombres de **tu** código. Un `-target` incluye todo aquello de lo que depende el recurso: la política del rol arrastra el rol, y el rol, el proveedor OIDC. Terraform te avisa de que el resultado es parcial (*Resource targeting is in effect*): es lo esperado aquí.
</details>

<details><summary>Pista 2 — el pipeline no publica en el paso 2</summary>

Lanzas el workflow a mano (`workflow_dispatch`). El job `publicar` de tu v4, ¿corre también con ese evento, o solo con `push` a `main`? Revisa su `if:` (clase 87). Si la condición no admite `workflow_dispatch`, haz un commit pequeño a `main` por PR: el `push` lo disparará.
</details>

<details><summary>Pista 3 — ¿queda algo después del <code>destroy</code>?</summary>

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Proyecto,Values=vigia \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

Solo debería salir el bucket del estado. Si sale otra cosa, o la creaste a mano en algún momento (impórtala o bórrala) o Terraform no pudo borrarla (lee el error del `destroy`).
</details>

<details><summary>Pista 4 — <code>verify.sh</code> dice que el plan propone cambios</summary>

Mira qué recurso y qué atributo. Los casos típicos:
- `TF_ETIQUETA_IMAGEN` (o tu `terraform.tfvars`) no coincide con la imagen con la que aplicaste: el plan quiere recrear la instancia;
- alguien, o tú en un Rómpelo, cambió algo a mano (clase 99): revierte o acepta;
- añadiste algo al código y no lo aplicaste.
</details>

<details><summary>Pista 5 — la instancia nueva no responde</summary>

Es la clase 78 otra vez. Por Session Manager:
- `cloud-init status --long`;
- el log de `/var/log/cloud-init-output.log`.

El sospechoso número uno al recrear desde cero: la imagen de `etiqueta_imagen` no existía en ECR cuando arrancó. ¿Hiciste el paso 2 antes del 3?
</details>

## Rómpelo: antes de etiquetar

1. **Un cambio a mano.** Cambia la retención de `/vigia/checker` desde la consola y pasa `verify.sh`: falla en el `plan`, con el recurso y el atributo. Explícalo en voz alta como en una entrevista (es el criterio de salida) y revierte con `terraform apply`.
2. **El estado de otra persona.** En otra terminal, empieza un `terraform apply` sin contestar, y lanza `verify.sh` en la primera. Espera hasta 60 segundos al bloqueo y después falla. Contesta `no` en la otra terminal.
3. **El bucket del estado es intocable.** En `infra/estado`, `terraform destroy`: `prevent_destroy` lo impide. Así debe ser.

## Entregable

- **En el repo:**
  - `infra/` completo: el módulo, `estado/`, `.terraform.lock.hcl` y `terraform.tfvars.example`;
  - `.github/workflows/terraform.yml`;
  - el README.
- **En AWS:** la infraestructura recreada desde cero y en verde.
- **En GitHub:** la etiqueta `v5` y su release.

README en inglés, sección nueva:

````markdown
## Infrastructure (Terraform)

Everything Vigía runs on is defined in `infra/`: the network (a local module), the security group,
the EC2 instance with its cloud-init, ECR, the reports bucket, CloudWatch log groups and the IAM roles
for the instance, the CI pipeline and the CI plan, all federated through GitHub OIDC.

State lives in a versioned, private S3 bucket with native locking (`use_lockfile`), created once by
`infra/estado/` (local state, `prevent_destroy`).

### Recreate everything from scratch
1. `terraform -chdir=infra apply -target=aws_ecr_repository.vigia -target=aws_iam_role_policy.github_pipeline`
2. Run the pipeline once so it publishes `vigia:<main SHA>` to ECR
3. Set `etiqueta_imagen` to that SHA and run `terraform -chdir=infra apply`
Measured from `destroy` to everything green: N minutes.

### Pull requests
Every PR that touches `infra/` runs `fmt`, `validate` and `plan` with a read-only role; applies are manual.
````

Etiqueta y release:

```bash
git switch main && git pull
git tag -a v5 -m "v5: all infrastructure as code with Terraform"
git push origin v5
gh release create v5 --title "v5" --notes "All infrastructure in Terraform: S3 backend with native locking, a local network module, OIDC roles, plan on every PR. Destroyed and recreated from scratch in N minutes."
```

## Destruir al terminar

Termina la instancia (`terraform destroy -target=aws_instance.vigia`) o, si vas a estar semanas sin AWS, destrúyelo todo con `terraform destroy`: ahora sabes recrearlo en minutos. El bucket del estado se queda.

## Cierre

En `notas/fase-8/clase-101.md`:

1. Cuenta la recreación desde cero, paso a paso, y por qué necesita ese orden.
2. ¿Qué pasa si alguien cambia a mano un recurso que gestiona Terraform? (Respóndelo como en una entrevista.)
3. ¿Qué cambiarías en `infra/` para que un `destroy` no pudiera borrar las imágenes ni los informes?
4. **Repaso (clase 100, sin mirar):** ¿por qué el rol del `plan` acepta los PR y el del despliegue no?

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify.sh</code> termine con <code>Fallos: 0</code> después de recrear desde cero</summary>

**Comprueba tu entrega:**
- [ ] `verify.sh` → `Fallos: 0` **después** de destruir y recrear.
- [ ] `aws resourcegroupstaggingapi get-resources …` tras el `destroy` solo mostraba el bucket del estado.
- [ ] El README tiene la receta de recreación y el tiempo medido.
- [ ] El workflow de Terraform planifica en los PR.
- [ ] `git tag` muestra `v5`, con su release.

**Cierre:**
1. Primero, con `-target`, el repositorio de ECR y el rol del pipeline, que arrastra el proveedor OIDC. Después, el pipeline publica la imagen del último commit de `main`. Y al final, el `apply` completo, con `etiqueta_imagen` apuntando a esa imagen. El orden hace falta porque la instancia descarga su imagen **al arrancar**, y esa imagen solo puede existir cuando existen el repositorio y el rol con el que el pipeline la publica.
2. El siguiente `plan` refresca el estado contra AWS, detecta la diferencia (el *drift*) y propone volver a lo que dice el código. Hay tres salidas:
   - **revertir:** aplicar, lo normal si fue un error;
   - **aceptar:** llevar el cambio al código con un PR y aplicar;
   - **ignorarlo:** `ignore_changes`, si ese atributo lo gestiona otro.

   Mientras no se decida, el siguiente `apply` de cualquiera lo revertirá. Y Terraform no ve lo que no gestiona, como una regla de SG suelta creada a mano. Para eso hacen falta otras comprobaciones, como el `verify-aws.sh`.
3. Separar los datos de larga vida (ECR, el bucket de informes) en **otra configuración**, con su propio estado, `prevent_destroy` y sin `force_delete` ni `force_destroy`, como el bucket del estado. La configuración de la aplicación (red, instancia, roles) se podría destruir y recrear sin miedo, y leería el repositorio y el bucket con `data`.
4. Porque el rol del `plan` solo lee: un PR lo necesita para planificar lo que propone, y como mucho ve tu infraestructura. El del despliegue cambia cosas, así que solo lo usa código revisado y unido a `main`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to rebuild from scratch | reconstruir desde cero |
| bootstrap order | orden de arranque |
| resource targeting | limitar a recursos concretos |
| long-lived data / separate state | datos de larga vida / estado separado |
| reproducible infrastructure | infraestructura reproducible |

🎙️ *"Vigía's whole infrastructure is Terraform: I can destroy it and rebuild it from scratch in about N minutes with a three-step bootstrap. State is in S3 with native locking, the network is my own module, and every infrastructure pull request gets a plan from a read-only OIDC role."*

## Apéndice: Terraform Associate (004)

Es la certificación de HashiCorp para Terraform, **opcional** en la Ruta. Su versión actual, la 004, evalúa Terraform 1.12 en un examen de una hora, tipo test, que incluye HCP Terraform. El precio y la forma de reservar están en developer.hashicorp.com/certifications.

Sus objetivos, contra lo que ya hiciste:

| Objetivo | Dónde lo viste |
|----------|----------------|
| 1. Infraestructura como código: qué es, sus ventajas, multinube | 92 |
| 2. Fundamentos: providers, sus versiones, varios providers, el estado | 93, 96 |
| 3. El flujo: `init`, `validate`, `plan`, `apply`, `destroy`, `fmt` | 92 |
| 4. La configuración: `resource` y `data`, referencias, variables y outputs, tipos complejos, expresiones y funciones, dependencias, **condiciones propias** (`validation`, `precondition`), datos sensibles y **Vault** | 93, 94, 95, 99 (Vault y `precondition` no) |
| 5. Módulos: orígenes, ámbito de las variables, uso y versiones | 98 |
| 6. El estado: backend local, bloqueo, backend remoto, *drift* | 92, 96, 99 |
| 7. Mantenimiento: `import`, inspeccionar el estado con la CLI, *logs* detallados (`TF_LOG`) | 96, 97, 99 (`TF_LOG` no) |
| 8. **HCP Terraform**: crear infraestructura, colaboración y gobierno, *workspaces* y proyectos, integración | **no** |

Lo que te faltaría estudiar:
- **HCP Terraform** (la plataforma de HashiCorp en la nube; tiene un plan gratuito);
- **Vault** para secretos;
- `precondition` y `postcondition`;
- `TF_LOG`.

Los tutoriales oficiales *Prepare for Terraform Associate (004)* lo cubren. Si decides presentarte, pídeme `prepara el Terraform Associate` y armamos un plan de estudio como el del CLF.

## Al terminar la fase 8

1. Marca en [`PROGRESO.md`](../PROGRESO.md):
   - las clases 100 y 101;
   - Vigía v5;
   - la recreación desde cero, con su tiempo;
   - los **criterios de salida de la fase 8**, solo si los cumples sin mirar.
2. Anota tus horas en el registro mensual de la Ruta 2.0.
3. Mira en *Billing* los créditos que te quedan. Las fases 9 y 10 corren en tu portátil: si no vas a usar AWS en semanas, haz `terraform destroy` y apúntalo en tu inventario. Sabes recrearlo todo en minutos.
4. Antes de empezar la fase 9, pídeme `revisa la fase 9`: compruebo que las versiones y los comandos siguen al día.

## Siguiente

[Fase 9 — Kubernetes](../fase-9/README.md)
