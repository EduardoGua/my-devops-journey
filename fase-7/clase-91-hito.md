# Clase 91 — ★ El hito: examen de las fases 4 a 7 y empezar a postular

**Tiempo:** 3 h el examen + 2 o 3 sesiones para el CV, LinkedIn y tus historias · **Bloque:** C. Proyecto y hito · **Aprobado: ≥ 80 %**

> 💡 **La idea de hoy:** has llegado al ★ hito de la Ruta: Linux, Git, redes, Python, Docker, AWS con el CLF y un pipeline real, en un proyecto público que puedes enseñar. Hoy demuestras, sin apuntes, que lo sabes (el examen de las fases 4 a 7) y preparas lo necesario para **empezar a postular**: un CV de una página con el proyecto primero, LinkedIn y GitHub al día, y tres historias STAR en puntos.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Todo lo de las fases 4 a 7: Python, Docker, AWS y CI/CD, y Vigía v1 a v4.
> - Tus averías e incidentes: el runbook del P1 (clase 36), las averías de la clase 63, el límite de saltos de la clase 79 y los jobs rojos de la fase 7.
> - La tabla de *Empleo* de `PLAN.md` y tu certificación CLF (clase 81).

> 🔤 **Palabras nuevas de hoy:**
> - **historia STAR**: una respuesta de entrevista en cuatro partes: Situación, Tarea, Acción y Resultado.
> - ***Open to work***: la marca de LinkedIn que dice a los reclutadores que buscas trabajo.
> - **README de perfil**: un repositorio con tu mismo nombre de usuario, cuyo README aparece en tu perfil de GitHub.

## Objetivo

- Demostrar, sin apuntes ni IA, lo que sabes de Python, Docker, AWS y CI/CD: el **examen de las fases 4 a 7**.
- Preparar lo que necesitas para postular:
  - un **CV** de una página, con el proyecto primero;
  - **LinkedIn** y tu perfil de **GitHub** al día;
  - tres **historias STAR** para las entrevistas.
- Empezar a **postular** con un ritmo semanal y un registro, mientras sigues con las fases 8 a 10.

## Por qué importa

Has llegado al **★ hito** de la Ruta: Linux, Git, redes, Python, Docker, AWS con el CLF y un pipeline real, en un proyecto público que puedes enseñar. Muchos esperan a "saberlo todo" para postular, y ese día no llega.

Los puestos de entrada (soporte cloud, NOC, junior DevOps o SRE) piden justo lo que ya tienes. Y las entrevistas, además de ser la meta, te enseñan qué estudiar después.

El examen sirve para que llegues a ellas **sabiendo** que lo sabes.

## Parte 1 · El examen

### Reglas

- **Dónde:** responde en `notas/fase-7/examen-<fecha>.md`. Tienes 3 horas.
- **Sin ayuda:** ni apuntes, ni internet, ni IA en las partes A, B y C.
- **Parte D:** puedes usar `man`, `--help`, la documentación oficial de Python, Docker y GitHub, y `git ls-remote` para los SHA. Tus notas y tus repositorios, no.
- **Parte E:** se graba con el móvil.
- **Corrección:** con [`examen-respuestas.md`](examen-respuestas.md) y su rúbrica, con la exigencia de un entrevistador.
- **Si no llegas al 80 %:** anota qué clases fallaste, repásalas (la clase y su reto) y repite el examen **una semana después**.

Si quieres una segunda opinión, escríbeme `revisa examen fases 4 a 7`.

---

### Parte A — Conceptos (30 puntos, 2 por pregunta)

Respuestas de 2 a 4 frases, con un ejemplo cuando ayude.

**A1.** ¿Qué diferencia hay entre una lista y un diccionario de Python? ¿Cuándo usas cada uno?

**A2.** ¿Qué hacen `try`, `except` y `finally`? ¿Por qué capturar `Exception` sin más es mala idea?

**A3.** ¿Para qué sirven un entorno virtual y un `requirements.txt` con las versiones fijadas? ¿Qué te dice Ubuntu si haces `pip install` fuera de un entorno virtual?

**A4.** ¿Qué diferencia hay entre una prueba unitaria y una de aceptación? ¿Qué es un *fixture* de `pytest`?

**A5.** ¿Qué es una inyección SQL y cómo la evitas en Python?

**A6.** Imagen, contenedor y volumen: ¿qué es cada uno?

**A7.** ¿Por qué pesa menos una imagen *multi-stage*? ¿Por qué el contenedor no debe correr como root?

**A8.** ¿Por qué `localhost` dentro de un contenedor no es tu máquina? ¿Cómo se encuentran dos servicios de un mismo Compose?

**A9.** Un contenedor se reinicia en bucle. ¿Qué dos comandos usas primero y qué buscas en cada uno?

**A10.** Explica el modelo de responsabilidad compartida con EC2 y con Lambda.

**A11.** ¿Qué diferencia hay entre un usuario y un rol de IAM? ¿Qué es la política de confianza de un rol?

**A12.** ¿Qué diferencia hay entre una subred pública y una privada? ¿Por qué la base de datos va en la privada?

**A13.** ¿Por qué, cuando el código que llama a AWS corre en un contenedor de una EC2, el límite de saltos de IMDS tiene que ser 2?

**A14.** ¿Qué diferencia hay entre integración continua, entrega continua y despliegue continuo?

**A15.** ¿Qué es OIDC entre GitHub Actions y AWS, y qué problema resuelve?

### Parte B — Revisión de código (20 puntos, 4 por bloque)

Cada bloque tiene **varios** problemas. Para cada uno, di qué está mal y cómo lo arreglarías.

**B1.** Una función de Python que comprueba si una web está arriba:

```python
import requests

def estado(url):
    r = requests.get(url)
    return r.status_code == 200
```

**B2.** Un Dockerfile:

```dockerfile
FROM python:3.14
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
ENV API_TOKEN=tok_abc123
CMD python app.py
```

**B3.** Un `compose.yaml`:

```yaml
services:
  db:
    image: postgres:18
    environment:
      POSTGRES_PASSWORD: secreto123
    ports:
      - "5432:5432"
  api:
    build: .
    environment:
      DATABASE_URL: postgresql://postgres:secreto123@localhost:5432/postgres
    ports:
      - "8000:8000"
```

**B4.** La política de IAM del rol de una EC2 que solo tiene que subir informes a `s3://vigia-informes-123456789012/reports/`:

```json
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "s3:*", "Resource": "*"}]}
```

**B5.** Un workflow que "despliega cada PR para probarlo":

```yaml
on: pull_request_target
permissions: write-all
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: |
          echo "Desplegando ${{ github.event.pull_request.title }}"
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET }}
          aws-region: us-east-1
      - run: ./deploy.sh
```

### Parte C — Diagnóstico (25 puntos, 5 por escenario)

Para cada escenario: **tus 3 a 5 primeros comandos o pasos, en orden**, qué esperas ver en cada uno y tu hipótesis principal.

**C1.** `docker compose up -d` y la API sale *unhealthy*. `docker compose logs api` muestra:
`psycopg.OperationalError: connection to server at "127.0.0.1", port 5432 failed: Connection refused`.

**C2.** Tras desplegar Vigía v3, `curl http://<IP>/health` da *timeout* desde tu casa, aunque ayer funcionaba. Dentro de la instancia, por Session Manager, `curl localhost/health` responde.

**C3.** El job `publicar` falla con `Not authorized to perform sts:AssumeRoleWithWebIdentity`. Lo lanzaste desde la rama `prueba`.

**C4.** El informe diario no aparece en S3. `journalctl -u vigia-report` muestra `NoCredentialsError: Unable to locate credentials`. Los logs de los contenedores llegan bien a CloudWatch.

**C5.** La factura del mes dice 18 USD y no recuerdas haber dejado nada encendido.

### Parte D — Práctica (15 puntos, 45 minutos)

En tu Ubuntu, en una carpeta nueva `~/examen-fase7`, con un repositorio de Git y un entorno virtual.

**D1 (8 puntos).** Escribe `resumen.py`, que lee un JSON con una lista de chequeos (cada uno con `url`, `up` y `seconds`) y escribe un CSV con una fila por URL y estas columnas:

| Columna | Qué es |
|---------|--------|
| `url` | la URL |
| `checks` | cuántos chequeos hay |
| `disponibilidad` | % de chequeos con `up`, con 2 decimales |
| `segundos_medios` | la media de `seconds` de los que dieron `up`, con 3 decimales; vacío si ninguno respondió |

Se usa así: `python3 resumen.py ARCHIVO [--salida resumen.csv]`. Si el archivo no existe o no es un JSON válido, escribe un mensaje claro en la salida de errores y termina con código **2**, sin *traceback*.

Para probarlo: [`recursos/clase-91/checks.json`](../recursos/clase-91/checks.json) y [`recursos/clase-91/roto.json`](../recursos/clase-91/roto.json).

**D2 (7 puntos).** Una prueba con `pytest` para la función que calcula el resumen, y un workflow `.github/workflows/ci.yml` que:
- se dispara en los PR y en los `push` a `main`;
- declara `permissions: contents: read`;
- fija `actions/checkout` y `actions/setup-python` por su SHA;
- ejecuta `ruff check .` y `pytest`.

Tiene que pasar actionlint. No hace falta subirlo a GitHub.

### Parte E — En voz alta, en inglés (10 puntos)

Graba con el móvil, sin leer:

**E1 (5 puntos).** Dos minutos: la arquitectura de Vigía v4 y el camino de un cambio desde el PR hasta producción.

**E2 (5 puntos).** Una historia STAR, de un problema real que resolviste en el curso (una avería de la clase 63, el límite de saltos de la 79, un job rojo de la fase 7…).

Escúchate y corrígete con la rúbrica.

---

## Parte 2 · Empezar a postular

### 1. A qué puestos (15 min)

Repasa la tabla de *Empleo* de [`PLAN.md`](../PLAN.md). **Si ya trabajas en un NOC o una mesa de ayuda** (el hito NOC), pregunta primero por las vacantes internas de N2, cloud o SRE: el cambio interno es el más fácil, porque ya conocen tu trabajo. Con lo que tienes hoy, postula a:
- **soporte cloud** y **soporte técnico de AWS** (o de proveedores que trabajan con AWS);
- **NOC** y operaciones;
- **junior DevOps**, **junior cloud** y **SRE junior**, sobre todo si piden Linux, Docker, AWS, CI/CD y Python o Bash.

No descartes una oferta porque pide "2 años de experiencia" o una herramienta que no conoces: si cumples la mayor parte, postula.

### 2. El CV: una página, el proyecto primero (2 h)

Escríbelo en **inglés**, y una versión en español para las ofertas locales. Usa esta estructura:

```
EDUARDO …  ·  Cloud & DevOps (junior)  ·  Colombia (remoto o presencial)
email · LinkedIn · github.com/<tu usuario>

SUMMARY (2 líneas)
Junior cloud/DevOps engineer. I built and run Vigía, an uptime monitor deployed on AWS
with Docker, a CI/CD pipeline (GitHub Actions + OIDC) and least-privilege IAM. AWS Certified Cloud Practitioner.

PROJECTS
Vigía — github.com/<tu usuario>/vigia                                       2026–2027
• Python service (CLI + FastAPI + PostgreSQL) with N unit tests and black-box acceptance tests.
• Containerized with multi-stage, non-root images; full stack with Docker Compose.
• Runs on EC2 with an IAM role and no stored credentials; daily report to S3, logs in CloudWatch.
• CI/CD with GitHub Actions: lint, tests and smoke tests on every PR; images to ECR and
  deployments over SSM with automatic rollback; OIDC instead of AWS keys.
my-devops-journey — runbook of N incidents, a reproducible cloud-init server, a Zabbix NOC lab, 125 lessons.

CERTIFICATIONS
AWS Certified Cloud Practitioner (CLF-C02) — mes y año
Cisco Certified Support Technician (CCST) Networking — mes y año

SKILLS
Linux & Bash · Git & GitHub · Networking (TCP/IP, DNS, HTTP, VLANs, firewalls) · Python ·
Docker & Compose · AWS (IAM, VPC, EC2, S3, ECR, CloudWatch, SSM) · GitHub Actions ·
Monitoring (Zabbix) · ITIL basics (tickets, SLA)

EXPERIENCE
<tu trabajo actual> — lo transferible: turnos, atención a clientes, resolver problemas en el momento
EDUCATION · LANGUAGES (Spanish: native · English: tu nivel real)
```

Reglas:
- **Nada inventado:** cada línea la puedes defender en una entrevista.
- **Números reales:** cuenta tus pruebas, mide tu pipeline (`gh run list` dice cuánto tarda), calcula el costo por hora de tu despliegue.
- **El trabajo actual cuenta:** turnos largos, atención a clientes y resolver problemas en el momento son lo que un puesto de soporte u operaciones usa cada día. Si ya trabajas en un NOC o una mesa de ayuda, ese puesto va primero en *Experience*, con datos: herramientas, tickets por turno, incidentes que escalaste.
- **En PDF**, con nombre de archivo profesional: `Eduardo-<apellido>-CV.pdf`.

### 3. LinkedIn y GitHub (1 h)

**LinkedIn:**
- **Titular:** "Junior Cloud & DevOps · AWS Certified Cloud Practitioner · Linux, Docker, AWS, CI/CD".
- **Acerca de:** tres frases sobre lo que haces y un enlace a Vigía. Un modelo, para adaptar:
  > *Junior cloud & DevOps engineer from Colombia. I built and run Vigía, an uptime monitor on AWS with Docker, a GitHub Actions pipeline with OIDC and least-privilege IAM: github.com/<tu usuario>/vigia. AWS Certified Cloud Practitioner, now learning Terraform and Kubernetes.*
- **Destacados:** el repositorio de Vigía y la insignia del CLF.
- ***Open to work*:** marca "solo visible para reclutadores" si no quieres que lo vea tu empresa actual.

**GitHub:**
- Fija (*pin*) Vigía y `my-devops-journey` en tu perfil.
- Crea el README de perfil (un repositorio con tu nombre de usuario) con dos líneas y tus proyectos.
- Repasa el README de Vigía como si fueras quien te va a contratar: ¿se entiende en un minuto qué hace y cómo está construido?

### 4. Tres historias STAR (1 h)

**STAR** = Situación, Tarea, Acción, Resultado. Escríbelas **en puntos**, no en párrafos, en `notas/empleo/historias.md`: los puntos te guían cuando la cuentas en voz alta, en unos 2 minutos.

| Historia | De dónde sale |
|----------|---------------|
| un incidente que diagnosticaste | un incidente real de tu turno NOC, si ya trabajas en uno; si no, tu runbook del P1 (clase 36), el incidente simulado del P3 o las averías de la clase 63 |
| algo que fallaba en la nube y por qué | el límite de saltos de IMDS de la clase 79, o un despliegue que volvió atrás solo |
| una decisión de seguridad o de costos | OIDC en lugar de llaves, Session Manager en lugar de SSH, destruir al terminar |

Que la **acción** sea lo más largo (qué comprobaste, en qué orden y por qué) y que el **resultado** tenga un dato.

**Un modelo, ya escrito** (lo escribió Claude, con la historia de la clase 79):

```markdown
## El informe que no llegaba a S3 (algo que fallaba en la nube)
- **Situación:** Vigía v3 en una EC2. Los logs llegaban a CloudWatch, pero el informe diario fallaba con `NoCredentialsError`.
- **Tarea:** averiguar por qué el contenedor no conseguía las credenciales del rol de la instancia.
- **Acción:**
  - comprobé que el rol tenía `s3:PutObject` en `reports/*`: sí;
  - dentro del contenedor, pedí el token de IMDSv2 con `curl`: *timeout*; desde la instancia, sí respondía;
  - leí cómo funciona IMDSv2: la respuesta sale con un límite de saltos de 1, y el puente de Docker es un salto más;
  - subí el límite a 2 con `modify-instance-metadata-options` y recreé la instancia con ese valor.
- **Resultado:** el informe se sube cada mañana; lo resolví en unos 40 minutos y lo documenté en el README.
```

Y en inglés, para contarla en voz alta (la parte E del examen):

```markdown
- **Situation:** Vigía v3 ran on EC2. Logs reached CloudWatch, but the daily report failed with NoCredentialsError.
- **Task:** find out why the container could not get the instance role's credentials.
- **Action:** I checked the role's S3 permission; I requested the IMDSv2 token from inside the container and it timed out,
  while it worked from the host; I learned that the hop limit of 1 stops the response at the Docker bridge;
  I raised it to 2 and recreated the instance.
- **Result:** the report uploads every morning; it took me about 40 minutes, and I documented it in the README.
```

**Ahora tú, con huecos** (una plantilla por historia; en español, y en inglés al menos la primera):

```markdown
## ____ (título corto)
- **Situación:** ____
- **Tarea:** ____
- **Acción:**
  - comprobé ____: ____;
  - después, ____;
  - la causa era ____, así que ____.
- **Resultado:** ____ (con un dato: minutos, número, coste).
```

### 5. El ritmo (cada semana, a partir de hoy)

- **Postulaciones:** de 3 a 5 por semana, cada una con el CV ajustado a la oferta. Más vale pocas y cuidadas que cincuenta iguales.
- **Dónde:** LinkedIn Empleos, Computrabajo y elempleo.com para Colombia; Get on Board y Torre para puestos remotos en Latinoamérica.
- **La red:** las comunidades cuentan. Los grupos de usuarios de AWS y de DevOps de tu ciudad (Meetup, LinkedIn) y los eventos *AWS Community Day* abren más puertas que muchas solicitudes.
- **El registro:** apunta cada postulación en `notas/empleo/postulaciones.md` (fecha, empresa, puesto, enlace, estado, próximo paso). Revísalo cada semana.
- **Las entrevistas:** antes de cada una, pídeme `haz de entrevistador para <puesto>` y hacemos un simulacro con preguntas técnicas y de comportamiento. Después, apunta qué te preguntaron y qué no supiste: es tu lista de estudio.
- **El tiempo:** las 7 h semanales siguen siendo para el curso. Las postulaciones van aparte, una o dos horas por semana.

## Cierre

En `notas/fase-7/clase-91.md`:

1. Tu nota del examen, por partes, y las dos clases que más vas a repasar. *(2 líneas. Empieza así: «A: __/__, B: __/__, C: __/__, D: __/__, E: __/__. Repasaré las clases __ y __, porque…»)*
2. Las tres primeras ofertas a las que vas a postular, con el motivo. *(3 líneas, una por oferta. Empieza así: «Empresa · puesto · porque piden… y yo tengo…»)*
3. Qué te falta para sentirte listo para una entrevista técnica, y cuándo vas a pedirme el primer simulacro. *(1–2 líneas. Empieza así: «Me falta… El primer simulacro, el día…»)*

## Al terminar la fase 7

1. Marca en [`PROGRESO.md`](../PROGRESO.md):
   - las clases 90 y 91;
   - Vigía v4;
   - el examen;
   - los **criterios de salida de la fase 7**, solo si los cumples sin mirar.
2. Anota tus horas en el registro mensual de la Ruta 2.0, y la fecha del hito.
3. Antes de empezar la fase 8, pídeme `revisa la fase 8`: compruebo que las versiones y los comandos siguen al día.

## Siguiente

[Fase 8 — Terraform](../fase-8/README.md)
