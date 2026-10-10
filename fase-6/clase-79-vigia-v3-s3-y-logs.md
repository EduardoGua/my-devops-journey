# Clase 79 — Proyecto: Vigía v3 (II): informe en S3, logs en CloudWatch y destrucción

**Dónde:** tu Ubuntu + AWS + GitHub · **Tiempo:** 2 bloques largos (unas 5–6 h) · **Bloque:** C. Proyecto · **Proyecto de portafolio**

## Objetivo

Terminar Vigía v3:
- un subcomando nuevo, `report`, que calcula la disponibilidad de cada sitio y la sube a **S3** una vez al día, con un timer de systemd;
- los logs de la API y del chequeo en **CloudWatch**, con retención;
- el rol con permisos mínimos para todo eso;
- pruebas que no tocan AWS (con **moto**).

Por el camino descubrirás por qué un contenedor puede no ver el rol de su instancia. Cierras con la guía para **destruirlo todo**, la sección de costos en el README y la etiqueta `v3`.

Criterio de salida de la fase: *Vigía corre en EC2 con un rol IAM, sin llaves guardadas en el servidor*.

## Costo esperado

> 💰 **Unos 0,15 USD por sesión de 5 horas**, como en la clase 78. Lo demás cuesta céntimos al mes:
> - el bucket (unos KB al día);
> - los logs, con 7 días de retención;
> - la imagen de ECR.
>
> Termina la instancia al acabar cada sesión.

## La arquitectura

```
                         ┌──────────── EC2 "vigia" (rol vigia-ec2) ─────────────┐
 tu IP ──HTTP 80──────►  │ api ──────────┐                                      │
                         │ checker ──────┼── driver awslogs (el demonio Docker) ─┼──► CloudWatch Logs
                         │ db (volumen)  │                                      │    /vigia/api · /vigia/checker (7 días)
                         │                                                      │
                         │ timer 06:00 UTC ─► docker compose run checker report ─┼──► S3 vigia-informes-<cuenta>
                         │                    (boto3 dentro del contenedor)     │    reports/AAAA-MM-DD.json
                         └──────────────────────────────────────────────────────┘
```

Fíjate en **quién** habla con AWS:
- los **logs** los envía el **demonio de Docker**, que corre en la propia instancia;
- el **informe** lo sube **boto3 desde dentro de un contenedor**.

Esa diferencia es la lección de la clase (R15).

## El contrato

| # | Requisito | Clases |
|---|-----------|--------|
| R10 | `python -m vigia report --bucket B [--hours 24]` sube a `s3://B/reports/AAAA-MM-DD.json` (fecha en UTC) un informe con el formato de abajo. Sale con 0 si lo sube; si no puede (el bucket no existe, no hay credenciales, la base de datos no responde), sale con 1 y un mensaje claro, sin *traceback* | 44, 47, 74 |
| R11 | Al menos **3 pruebas tuyas** de `report` con **moto**, sin tocar AWS: la clave y el contenido del objeto, la disponibilidad bien calculada y el código 1 con un bucket que no existe | 52 |
| R12 | Bucket `vigia-informes-<cuenta>`, con:<br>• bloqueo del acceso público (los cuatro interruptores);<br>• versionado;<br>• una política que deniega todo lo que no va por HTTPS;<br>• ciclo de vida: los informes caducan a los 90 días y las versiones antiguas, a los 7 | 74 |
| R13 | Los grupos `/vigia/api` y `/vigia/checker`, creados **por ti** y con 7 días de retención. `compose.aws.yaml` envía la salida de `api` y `checker` con el driver `awslogs` | 76 |
| R14 | Una política *inline* `vigia-logs-y-s3` en el rol, con dos permisos y nada más:<br>• escribir en esos dos grupos de logs;<br>• `s3:PutObject` solo en `reports/*` de tu bucket | 69 |
| R15 | Los contenedores llegan al rol: límite de saltos de IMDS en **2**. Tienes que saber explicar por qué | 72 |
| R16 | Un timer de systemd, creado por cloud-init, lanza cada día a las 06:00 UTC `docker compose … run --rm checker report --bucket <tu bucket>` | 12, 20 |
| R17 | La imagen `vigia:3.0.0` en ECR, y la instancia **recreada** con ella, no parcheada | 75, 78 |
| R18 | `verify-aws.sh` → `Fallos: 0` | — |
| R19 | En el README:<br>• *Deploy to AWS* al día;<br>• secciones nuevas: *Daily report*, *Logs*, *Costs*, *Destroy*, *What broke and how I found it* y *Limitations*.<br>PR fusionado, etiqueta `v3` y su release | — |

### El formato del informe (R10)

```json
{
  "generated_at": "2026-10-20T06:00:01+00:00",
  "hours": 24,
  "sites": [
    {"url": "https://example.com", "checks": 1440, "up_checks": 1438,
     "availability": 99.86, "avg_seconds": 0.231}
  ]
}
```

| Campo | Qué es |
|-------|--------|
| `generated_at` | cuándo se generó, en UTC con zona horaria |
| `hours` | cuántas horas hacia atrás abarca |
| `checks` · `up_checks` | chequeos de esa URL en la ventana · cuántos dieron *up* |
| `availability` | el porcentaje de *up*, con 2 decimales |
| `avg_seconds` | la media de los chequeos que respondieron, con 3 decimales (`null` si no respondió ninguno) |

## Plan de trabajo

**Bloque 1: el informe y sus pruebas (en tu Ubuntu)**

1. `git switch main && git pull && git switch -c informes`.
2. **R10:**
   - una consulta en `storage.py` que resuma la ventana de horas;
   - un módulo `report.py` que construya el informe y lo suba con boto3;
   - el subcomando `report` en `cli.py`.

   Añade `boto3` a `requirements.txt` con la versión fijada.
3. **R11:** `moto[s3]` en `requirements-dev.txt` y tus pruebas en `tests/test_report.py`.
4. **R12:** crea el bucket con todas sus protecciones (clase 74).
5. Pruébalo contra el S3 de verdad desde tu portátil:
   - `python -m vigia report --bucket <tu bucket>`;
   - `aws s3 cp s3://<tu bucket>/reports/<hoy>.json -`.
6. Commit.

**Bloque 2: CloudWatch, el rol y la instancia**

7. **R13:** los grupos de logs con retención, y el driver `awslogs` en `compose.aws.yaml`.
8. **R14:** la política *inline* del rol. Guárdala en el repo como `deploy/politica-vigia.json`, con marcadores para la región, la cuenta y el bucket.
9. **R16:** el servicio y el timer en `deploy/cloud-init.yaml`, con un marcador nuevo, `__BUCKET__`.
10. **R17:** construye y sube `vigia:3.0.0`. PR, *squash and merge*.
11. **La lección de R15.** Lanza la instancia con el **mismo** límite de saltos de la clase 78 (1). Por Session Manager:
    - `sudo systemctl start vigia-report.service`;
    - `sudo journalctl -u vigia-report -n 30`.

    Lee el error, piensa por qué los logs sí llegan a CloudWatch y el informe no, y arréglalo **en caliente** con `aws ec2 modify-instance-metadata-options`. Vuelve a lanzar el informe.
12. Ahora, **recrea** la instancia con el límite correcto en el comando de lanzamiento. Lanza el informe una vez a mano (el timer solo lo haría a las 06:00) y pasa las pruebas de aceptación.
13. **R19:** el README, el PR, la etiqueta `v3` y la release.
14. **Destruir al terminar.**

### Las pruebas de aceptación

```bash
VIGIA_BUCKET=vigia-informes-<tu cuenta> bash ~/my-devops-journey/recursos/vigia/v3/verify-aws.sh
```

Ahora sí, todo en verde: `Fallos: 0`. Si falla "el informe de hoy", recuerda que el timer solo corre a las 06:00 UTC: lánzalo a mano con `sudo systemctl start vigia-report.service`.

## Pistas

<details><summary>Pista 1 — la consulta del resumen</summary>

Una sola consulta agrupada por URL, sobre las filas de la ventana:

```sql
SELECT url, COUNT(*) AS checks, SUM(up) AS up_checks, AVG(up) * 100 AS availability,
       AVG(CASE WHEN up = 1 THEN seconds END) AS avg_seconds
FROM checks WHERE checked_at >= ? GROUP BY url ORDER BY url
```

`checked_at` es texto ISO en UTC (clase 54), así que compararlo con otro texto ISO en UTC funciona: el orden alfabético es el cronológico. El "desde" es `datetime.now(timezone.utc) - timedelta(hours=horas)` con `isoformat()`.

Ojo con PostgreSQL: el marcador es `%s`, no `?` (clase 65), y `AVG` devuelve un `Decimal`. Redondea con `round(float(x), 2)` antes de convertir el informe a JSON.
</details>

<details><summary>Pista 2 — errores de AWS sin <i>traceback</i></summary>

Casi todo lo que puede fallar al llamar a AWS es una de dos excepciones de `botocore.exceptions`:
- **`ClientError`:** AWS respondió con un error, como `NoSuchBucket` o `AccessDenied`. El código está en `e.response["Error"]["Code"]`.
- **`BotoCoreError`:** ni siquiera se pudo preguntar. Por ejemplo, `NoCredentialsError` o un fallo de red.

Captura las dos, escribe un mensaje con `log.error` y devuelve 1. Y baja el ruido de las librerías: `logging.getLogger("botocore").setLevel(logging.WARNING)`.
</details>

<details><summary>Pista 3 — pruebas con moto</summary>

moto sustituye a AWS dentro de tu proceso: boto3 cree que habla con S3 y habla con un S3 falso en memoria.

```python
import boto3
import pytest
from moto import mock_aws


@pytest.fixture
def s3(monkeypatch):
    # Credenciales falsas: si algo se escapara a AWS de verdad, fallaría
    for var, valor in {"AWS_ACCESS_KEY_ID": "test", "AWS_SECRET_ACCESS_KEY": "test",
                       "AWS_DEFAULT_REGION": "us-east-1"}.items():
        monkeypatch.setenv(var, valor)
    with mock_aws():
        cliente = boto3.client("s3")
        cliente.create_bucket(Bucket="informes-prueba")
        yield cliente


def test_sube_el_informe_con_la_fecha_de_hoy(s3, tmp_path):
    ...  # una base de datos de prueba con un par de filas (clase 55), tu función de subir,
         # y después s3.get_object(Bucket="informes-prueba", Key=f"reports/{hoy}.json")
```

`monkeypatch` también protege de tus credenciales reales: dentro de la prueba, las únicas que existen son las falsas.
</details>

<details><summary>Pista 4 — boto3 no encuentra credenciales en tu portátil</summary>

Las versiones recientes de boto3 entienden las sesiones de `aws login`. Si la tuya no, usa el perfil con `credential_process` del Reto 1 de la clase 75:

```bash
AWS_PROFILE=ecr python -m vigia report --bucket <tu bucket>
```
</details>

<details><summary>Pista 5 — el informe falla en la instancia, pero los logs sí llegan</summary>

Ese es el aprendizaje de R15.
- **Los logs:** los envía el demonio de Docker, un proceso **de la instancia**. Pide sus credenciales al IMDS directamente.
- **El informe:** lo sube boto3 **desde un contenedor**. Su petición al IMDS cruza el puente de red de Docker, que es **un salto más**.

Con `HttpPutResponseHopLimit=1`, la respuesta del IMDS sale con un TTL de 1 y muere en ese salto: el contenedor no consigue el token y se queda sin credenciales. Por eso el error del informe es de credenciales, aunque el rol esté bien.

```bash
aws ec2 modify-instance-metadata-options --instance-id <ID> \
  --http-tokens required --http-put-response-hop-limit 2
```

2 es el valor que AWS recomienda cuando hay contenedores. Pon también `HttpPutResponseHopLimit=2` en tu comando de lanzamiento, para que la próxima instancia ya nazca bien.
</details>

<details><summary>Pista 6 — "failed to initialize logging driver"</summary>

El contenedor no arranca si el driver `awslogs` no puede escribir. Las causas típicas:
- **el grupo no existe:** créalo tú, con retención, **antes** de arrancar. No uses `awslogs-create-group`, que lo crearía sin retención y pediría otro permiso;
- **el rol no tiene permiso** en ese grupo: el ARN de tu política, ¿termina en `log-group:/vigia/*`?
- **la región:** `awslogs-region`.

Los mensajes están en `sudo journalctl -u docker -n 50`.
</details>

<details><summary>Pista 7 — el timer</summary>

Dos unidades en `write_files`:
- un **servicio** `Type=oneshot` con `WorkingDirectory=/opt/vigia` y el `docker compose … run --rm checker report --bucket __BUCKET__`;
- un **timer** con `OnCalendar=*-*-* 06:00:00 UTC` y `Persistent=true`.

Al final de tu script de arranque: `systemctl daemon-reload && systemctl enable --now vigia-report.timer`. Para comprobarlo:
- `systemctl list-timers vigia-report.timer` dice cuándo será la próxima vez;
- `journalctl -u vigia-report` muestra lo que pasó en cada ejecución (clase 12).
</details>

## Rómpelo: antes de etiquetar

1. **Un permiso de menos.**
   - Quita `s3:PutObject` de la política *inline* (vuelve a hacer `put-role-policy` sin esa declaración).
   - Lanza el informe a mano y lee el error: `AccessDenied`.
   - Busca el evento en CloudTrail (*Event history*, filtra por *Event source* `s3.amazonaws.com`)… y descubre que no aparece. CloudTrail registra por defecto los eventos de **gestión**, no los de **datos** como `PutObject`.
   - Devuelve el permiso.
2. **Un bucket que no existe:** `--bucket no-existe-$RANDOM` desde tu portátil. Código 1, un mensaje legible y ninguna línea de *traceback*.
3. **Dos informes el mismo día.** Lanza el informe dos veces y mira `aws s3api list-object-versions --bucket <tu bucket> --prefix reports/`. El segundo no borró el primero: el versionado lo guarda. La regla del ciclo de vida lo limpiará a los 7 días.
4. **La instancia olvidada.** Al día siguiente, abre Cost Explorer: agrupa por *Usage type* y busca `BoxUsage:t3.small` y `PublicIPv4:InUseAddress`. Así se ve en la factura una instancia encendida, y así detectarás una que se te olvide.

## Entregable

- **En el repo:**
  - el subcomando `report` y sus pruebas;
  - `requirements.txt` y `requirements-dev.txt` al día;
  - `compose.aws.yaml` con `awslogs`;
  - `deploy/cloud-init.yaml` con el timer;
  - `deploy/politica-vigia.json`, con marcadores;
  - el README.
- **En AWS:**
  - `vigia:3.0.0` en ECR;
  - un informe en S3;
  - logs en CloudWatch.
- **En GitHub:** la etiqueta `v3` y su release.

README en inglés, secciones nuevas:

````markdown
## Daily report
(what `vigia report` computes, the JSON format, where it lands in S3, the systemd timer)

## Logs
(the two log groups, their retention, and `aws logs tail /vigia/checker --since 1h`)

## Costs
| Resource | While running | Left running for a month |
| t3.small + public IPv4 | ~$0.026/h | ~$19.50 |
| ECR image, S3 reports, logs (7 days) | — | a few cents |

## Destroy
(two runbooks: "pause" = terminate the instance; "full teardown" = everything, in order)

## What broke and how I found it
## Limitations
````

**La guía de destrucción** es parte del entregable. Escríbela con los comandos reales, en dos niveles:
- **Pausa**, al final de cada sesión: terminar la instancia. Lo demás cuesta céntimos al mes.
- **Destrucción completa**, cuando termines con AWS. En este orden:
  1. la instancia;
  2. el SG `vigia-web`;
  3. el rol: sácalo del perfil de instancia, borra el perfil, quita sus políticas y bórralo;
  4. el repositorio de ECR (`--force`);
  5. el bucket: primero todas sus versiones (clase 74), después el bucket;
  6. los dos grupos de logs;
  7. la `lab-vpc` (`borrar-vpc.sh`).

  Termina con una comprobación de que no queda nada con `Proyecto=vigia`.

Etiqueta y release:

```bash
git switch main && git pull
git tag -a v3 -m "v3: AWS deployment with IAM role, S3 daily report and CloudWatch logs"
git push origin v3
gh release create v3 --title "v3" --notes "Runs on EC2 with an IAM role and no stored credentials. Daily availability report in S3, logs in CloudWatch. Image: vigia:3.0.0 in ECR."
```

## Destruir al terminar

**Pausa:** termina la instancia, como en la clase 78. Las fases 7 y 8 volverán a usar el repositorio de ECR, el bucket, los grupos de logs y la VPC: déjalos (céntimos al mes) y apúntalos en tu inventario, con su coste.

Si vas a estar semanas sin tocar AWS, aplica tu propia guía de **destrucción completa**: es la mejor prueba de que la escribiste bien.

## Cierre

En `notas/fase-6/clase-79.md`:

1. Con el límite de saltos en 1, ¿por qué los logs de los contenedores llegaban a CloudWatch, pero el informe no podía subir a S3?
2. ¿Qué permisos tiene el rol al final? Justifica cada uno.
3. ¿Qué haces al terminar cada sesión? ¿Y si quieres dejar la cuenta a cero?
4. **Repaso (clase 78, sin mirar):** ¿por qué se genera la contraseña de PostgreSQL dentro de la instancia?

## Autocorrección

<details>
<summary>Ábrelo cuando <code>verify-aws.sh</code> termine con <code>Fallos: 0</code></summary>

**Comprueba tu entrega:**
- [ ] `verify-aws.sh` → `Fallos: 0`.
- [ ] `pytest tests/` en verde, con al menos 3 pruebas de `report`, sin conexión a AWS (prueba a desconectar la red).
- [ ] `python -m vigia report --bucket no-existe-$RANDOM; echo $?` → un mensaje legible y `1`.
- [ ] `aws iam list-attached-role-policies` y `list-role-policies` de `vigia-ec2`:
  - las dos administradas: SSM y la de ECR para descargar;
  - una *inline*: `vigia-logs-y-s3`.
- [ ] `systemctl list-timers` en la instancia muestra `vigia-report.timer` con su próxima ejecución.
- [ ] La guía de destrucción del README, ejecutada en una cuenta de prueba mental: ¿falta algún recurso de tu inventario?
- [ ] `git tag` muestra `v3`, con su release.

**Cierre:**
1. Porque cada uno pide credenciales desde un sitio distinto.
   - **Los logs:** los envía el demonio de Docker, un proceso de la propia instancia. Su petición al IMDS no cruza ningún salto de red.
   - **El informe:** lo sube boto3 dentro del contenedor, y su petición cruza el puente de Docker. Con IMDSv2, la respuesta al `PUT` del token sale con TTL igual al límite de saltos; con 1, muere en el puente. Sin token no hay credenciales, y boto3 acaba en `NoCredentialsError`. Con 2, el token llega al contenedor.
2. Cuatro permisos:
   - **`AmazonSSMManagedInstanceCore`:** Session Manager y Run Command, porque no hay SSH.
   - **`AmazonEC2ContainerRegistryPullOnly`:** descargar la imagen de ECR, sin poder subir ni borrar.
   - **`logs:CreateLogStream` y `logs:PutLogEvents` en `/vigia/*`:** que el driver `awslogs` escriba en sus dos grupos, sin crear grupos ni leer otros.
   - **`s3:PutObject` en `reports/*` de su bucket:** subir el informe, sin leer, sin borrar y sin tocar otros buckets.
3. Al terminar cada sesión, la **pausa**: terminar la instancia, que es lo que cobra por hora (cómputo e IPv4). Para dejar la cuenta a cero, la **destrucción completa**, en el orden de las dependencias: instancia, SG, rol y perfil, ECR, bucket (con sus versiones), grupos de logs y VPC. Al final, comprobar que no queda nada con `Proyecto=vigia`.
4. Porque el *user-data* lo puede leer cualquiera con permiso de lectura sobre la instancia, y además saldría de tu portátil. Generada con `openssl rand` en el primer arranque, solo existe en `/opt/vigia/.env`, con permisos 600.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| daily report / availability | informe diario / disponibilidad |
| log driver | controlador de logs (de Docker) |
| hop limit | límite de saltos |
| least-privilege policy | política de mínimo privilegio |
| teardown runbook | guía de destrucción |
| management events / data events | eventos de gestión / de datos (CloudTrail) |

🎙️ *"The daily report runs from a systemd timer in a container and uploads to S3 with boto3; logs go to CloudWatch through Docker's awslogs driver. I had to raise the IMDS hop limit to 2, because the container's metadata request crosses the Docker bridge. Everything is least privilege, and the README has a teardown runbook."*

## Siguiente

[Clase 80 — CLF-C02 (I): la guía del examen como lista de control](clase-80-clf-guia.md)
