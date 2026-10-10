# El mapa — de cero a Cloud & DevOps (AWS)

**Versión:** 5.0 · 2026-10-09 · alineada con la *Ruta Cloud & DevOps 2.0*
**Alumno:** Eduardo · Ubuntu 26.04 · unas 7 h por semana
**Meta:** un primer empleo en Cloud / DevOps, o en un puesto puente (soporte cloud, NOC, SysAdmin), con un proyecto de portafolio que lo respalde.

Este archivo es el **mapa**: qué se aprende, en qué orden, qué versión de Vigía cierra cada fase y cómo sabes que puedes pasar a la siguiente. Lo que haces cada día está en [`PROGRESO.md`](PROGRESO.md). El método, en [`COMO-ESTUDIAR.md`](COMO-ESTUDIAR.md).

## La Ruta 2.0 y este repo

| | Ruta Cloud & DevOps 2.0 | Este repo (`my-devops-journey`) |
|--|-------------------------|---------------------------------|
| Qué es | el mapa general: orden de las fases, horas, proyecto, certificaciones, inglés y empleo | el curso: clases, laboratorios, tus notas y tu progreso |
| Cuándo lo usas | una vez al mes: registrar horas y recalcular la fecha del hito | cada sesión: la clase que toca, tus cierres y `PROGRESO.md` |

Las fases, su orden, sus horas y sus criterios de salida son **los mismos** en los dos documentos. En las fases 1 a 3, **las clases de este repo son el recurso principal**: los libros y cursos que cita la Ruta (*The Linux Command Line*, LFS101, Pro Git, Networking Basics…) son consulta opcional, no trabajo extra. Si algún día el repo y la Ruta dicen cosas distintas, avísame y corregimos uno de los dos.

---

## 1. Las ideas que sostienen el plan

1. **Fundamentos antes que herramientas.** Docker, AWS y Kubernetes son Linux y redes con otra interfaz. Quien domina la base aprende cada herramienta nueva en semanas; quien no, memoriza comandos y se bloquea en la primera avería.
2. **Practicar más que leer.** Cada clase tiene más terminal que teoría.
3. **Romper a propósito.** En este trabajo te pagan por arreglar lo que falla. Cada clase provoca fallos para que aprendas a diagnosticarlos.
4. **Un solo proyecto que crece: Vigía.** Una pieza de portafolio completa vale más que diez ejercicios sueltos. Cada fase le añade una capa.
5. **Una sola nube: AWS.** Es la que más ofertas tiene. Lo aprendido se traslada a Azure o GCP en semanas.
6. **Horas reales, no promesas.** El plan se mide en horas. Cada mes registras las tuyas y recalculas, en lugar de perseguir un calendario que no se cumple.
7. **Sin gastos sorpresa.** La cuenta de AWS se abre al empezar la fase 6, y cada sesión termina destruyendo lo que creaste.

## 2. Las fases

```
 F1 Linux y Bash ─► F2 Git ─► F3 Redes ─► F4 Python ─► F5 Docker ─► F6 AWS + CLF ─► F7 CI/CD
                                                                                        │
                                                          ★ Hito: empezar a postular ◄──┘
                                                                                        │
                                               F8 Terraform ─► F9 Kubernetes ─► F10 Observabilidad
```

| Fase | Horas (Ruta 2.0) | En este repo | Vigía |
|------|------------------|--------------|-------|
| 1 · Linux y Bash | 35–45 h | [clases 01–21](fase-1/README.md) | v0 |
| 2 · Git y GitHub | 12–16 h | [clases 22–25](fase-2/README.md) | v0.1 |
| 3 · Redes | 30–40 h | [clases 26–38](fase-3/README.md), con P1, P2 y el examen de fundamentos | v0.2 |
| 4 · Python | 50–70 h | [clases 39–55](fase-4/README.md) | v1 |
| 5 · Docker | 30–40 h | [clases 56–66](fase-5/README.md) | v2 |
| 6 · AWS + Cloud Practitioner | 60–80 h | [clases 67–81](fase-6/README.md), con el CLF-C02 | v3 |
| 7 · CI/CD con GitHub Actions | 25–35 h | [clases 82–91](fase-7/README.md), con el examen de las fases 4 a 7 | v4 |
| ★ **Hito: empezar a postular** | 242–326 h acumuladas | | |
| 8 · Terraform | 35–45 h | [clases 92–101](fase-8/README.md) | v5 |
| 9 · Kubernetes | 55–75 h | [clases 102–115](fase-9/README.md) | v6 |
| 10 · Observabilidad | 25–35 h | [clases 116–125](fase-10/README.md), con el examen final y la defensa | v7 |

Las horas son estimaciones de la Ruta para alguien que empieza de cero, con práctica y proyecto incluidos. A 7 h por semana, desde el 12 de octubre de 2026, el hito llega entre junio y septiembre de 2027. La Ruta explica cómo recalcularlo cada mes con tus horas reales; la columna *Tiempo* del registro de `PROGRESO.md` te da el número.

Saltarse una fase hace que la siguiente parezca magia, y en una entrevista eso se nota.

## 3. Vigía, el proyecto que crece

Vigía es un monitor de disponibilidad de sitios web: revisa una lista de URLs cada pocos minutos, guarda si respondieron y cuánto tardaron, y avisa cuando algo se cae. Toca HTTP, DNS y TLS; se programa primero en Bash y luego en Python; se empaqueta en Docker, corre en AWS, se despliega con un pipeline, su infraestructura vive en Terraform, corre como CronJob en Kubernetes y termina exponiendo métricas. Es pequeño, pero es un sistema real. Vive en su propio repositorio (`~/vigia`, público en GitHub desde la v0.1).

| Fase | Versión | Qué agregas | Evidencia en el repo |
|------|---------|-------------|----------------------|
| 1 | v0 | `vigia.sh` lee `urls.txt`, prueba cada URL con `curl` (código y tiempo) y escribe un log; cron lo ejecuta cada 5 minutos | script con `set -euo pipefail`, tu `crontab -l` y un extracto del log en el README |
| 2 | v0.1 | repo en GitHub, `.gitignore`, una rama y un PR por cambio | commits claros y un README que explica cómo ejecutarlo |
| 3 | v0.2 | mide la resolución DNS con `dig` y el vencimiento del certificado TLS con `openssl` | sección del README: qué pasa desde que escribes una URL hasta que ves la página |
| 4 | v1 | reescritura en Python con `requests`, configuración en YAML, resultados en SQLite y una API mínima que devuelve el estado en JSON | pruebas con `pytest` que pasan |
| 5 | v2 | Dockerfile con usuario no root y `docker compose` con la API, el chequeo y una base de datos | `docker compose up` levanta todo desde cero |
| 6 | v3 | despliegue en EC2 con un rol IAM (sin llaves guardadas en el servidor), imagen en un registro (Docker Hub o ECR), reporte diario en S3 y logs en CloudWatch | diagrama y capturas en el README; todo destruido al cerrar cada sesión |
| 7 | v4 | GitHub Actions: pruebas en cada PR, imagen construida y publicada al unir a `main`, despliegue automático | insignia del pipeline en verde en el README |
| 8 | v5 | toda la infraestructura de AWS en código, con estado remoto en S3 y `use_lockfile = true` | `terraform plan` limpio y `terraform destroy` documentado |
| 9 | v6 | cluster local con kind: Deployment para la API, CronJob para el chequeo, Service, ConfigMap, Secret y sondas | manifiestos en `k8s/` y la salida de `kubectl get all` |
| 10 | v7 | endpoint `/metrics`, Prometheus y Grafana, una alerta si un sitio cae más de 5 minutos y un SLO de disponibilidad | captura del dashboard y la regla de alerta en el repo |

**La regla del proyecto:** cada versión se cierra con un commit etiquetado (`v0`, `v0.1`, `v1`…) y una nota corta en el README sobre **qué se rompió y cómo lo diagnosticaste**. Esa nota muestra cómo piensas cuando algo falla, y es material directo para entrevistas.

Si algún día prefieres un proyecto guiado y conocido, el *Cloud Resume Challenge* puede sustituir a Vigía v3–v5. Sustituir, no sumar: con tu tiempo, un proyecto terminado vale más que dos a medias.

---

## 4. Las fases, una a una

### Fase 1 — Linux y Bash · 35–45 h · clases 01–21 ✍️

Lo que más se usa en el trabajo diario: moverte por el sistema, administrar un servidor y automatizar con scripts. Clases completas en [`fase-1/`](fase-1/README.md).

| Bloque | Clases | Dónde |
|--------|--------|-------|
| A. Linux en tu equipo | 01–07 | tu Ubuntu |
| B. Administrar un servidor | 08–15 | VM `servidor-01` (Multipass) |
| C. Scripting con Bash | 16–20 | tu Ubuntu |
| D. Proyecto: Vigía v0 | 21 | tu Ubuntu |

**Práctica paralela:** OverTheWire Bandit, niveles 0–20, desde la clase 05.

**Criterios de salida:** script de backup con fecha y rotación escrito sin mirar · explicar `set -euo pipefail` y `$?` · encontrar con `journalctl` por qué no arrancó un servicio · entrar por SSH con llave a una VM · Vigía v0 corriendo con cron.

### Fase 2 — Git y GitHub · 12–16 h · clases 22–25 ✍️

Desde aquí, todo lo que hagas queda guardado y visible para quien revise tu perfil. Clases en [`fase-2/`](fase-2/README.md): Git por dentro, ramas y conflictos, GitHub y pull requests, y Vigía v0.1.

**Criterios de salida:** rama, dos commits, PR y merge · un conflicto provocado y resuelto · un archivo borrado recuperado con Git · Vigía visible en tu perfil con su README.

### Fase 3 — Redes · 30–40 h · clases 26–38 ✍️

Casi todo lo que falla en la nube es red. Nueve clases de redes (capas, IP y CIDR, subnetting, puertos, rutas y NAT, DNS, HTTP y HTTPS, firewall, dos servidores), Vigía v0.2 y el cierre de los fundamentos. Clases en [`fase-3/`](fase-3/README.md).

- **P1 — Runbook de incidentes:** siete averías reales provocadas en una VM, diagnosticadas a ciegas y documentadas en inglés.
- **P2 — Servidor reproducible:** un archivo `cloud-init` que crea desde cero un servidor endurecido con nginx y firewall. Es exactamente lo que harás en AWS con *user-data*.
- **Examen de fundamentos** (fases 1 a 3): ≥ 80 %, sin apuntes.

**Criterios de salida:** explicar en voz alta qué pasa desde que escribes una URL hasta que carga la página · dividir `10.0.0.0/16` en cuatro subredes con sus tamaños · diagnosticar con `dig`, `curl -v` y `ss` por qué un servicio no responde · explicar IP privada frente a pública y para qué sirve NAT · P1, P2 y examen.

Desde esta fase ya puedes postular a soporte técnico, mesa de ayuda o NOC (ver Empleo).

### Fase 4 — Python para automatizar · 50–70 h · clases 39–55 ✍️

Bash sirve para tareas cortas; Python, para automatizaciones que crecen, para consumir APIs y para manejar AWS desde código. Clases en [`fase-4/`](fase-4/README.md): el lenguaje desde cero (39–45), las herramientas de operaciones (46–53: entornos virtuales, JSON/YAML, `argparse`, `requests`, `subprocess`, SQLite, `pytest` y FastAPI) y Vigía v1 (54–55), con [pruebas de aceptación](recursos/vigia/v1/README.md).

**Criterios de salida:** un script que lee un JSON, filtra datos y escribe un CSV, con manejo de errores · una llamada a una API pública con `requests` que sobrevive a un error de red · `venv`, `requirements.txt` y al menos 5 pruebas con `pytest` · Vigía v1 devuelve el estado en JSON.

### Fase 5 — Docker · 30–40 h · clases 56–66 ✍️

Un contenedor empaqueta la aplicación con todo lo que necesita y corre igual en tu portátil, en la nube o en Kubernetes. Clases en [`fase-5/`](fase-5/README.md): qué es un contenedor por dentro, imágenes, Dockerfiles pequeños y seguros (multi-stage, sin root, `trivy`), volúmenes, redes, Compose, depuración con averías reales y Docker Hub (56–64), y Vigía v2 con PostgreSQL y Compose (65–66), con su [`verify.sh`](recursos/vigia/v2/README.md).

**Criterios de salida:** explicar imagen, contenedor y volumen · un Dockerfile multi-stage que corre como usuario no root · Vigía se levanta con `docker compose up` desde un clon limpio · encontrar con `docker logs` y `docker inspect` por qué un contenedor se reinicia en bucle.

### Fase 6 — AWS + Cloud Practitioner · 60–80 h · clases 67–81 ✍️

Llevas a la nube lo que ya sabes de Linux, redes y Docker, primero con la consola y la CLI, entendiendo cada pieza (escribir como código algo que nunca hiciste a mano produce archivos copiados sin entender). Clases en [`fase-6/`](fase-6/README.md):
- **La cuenta, los costos y la identidad (67–70):** la víspera, la factura, IAM, roles y `aws login`.
- **Los servicios básicos (71–77):** VPC, EC2 con Session Manager y NAT Gateway, security groups y NACLs, S3, ECR y CloudWatch; RDS, balanceadores, Auto Scaling y Lambda, como concepto.
- **Vigía v3 (78–79):** en EC2 con un rol IAM, informe diario en S3 y logs en CloudWatch, con su [`verify-aws.sh`](recursos/vigia/v3/README.md).
- **La preparación del CLF-C02 (80–81).**

> ⏳ **Cuándo crear la cuenta.** Una cuenta nueva de AWS empieza en el plan gratuito:
> - **Créditos:** 100 USD al registrarte y hasta 100 USD más con actividades.
> - **Duración:** 6 meses, o hasta que se acaben los créditos.
> - **Al terminar:** la cuenta se cierra, y hay 90 días para pasar al plan de pago y recuperarla.
>
> Las fases 6, 7 y 8 (AWS, CI/CD y Terraform) son las que usan AWS y suman 120–160 h: a 7 h por semana, unos 4 a 5,5 meses. **Ábrela en la clase 67 y haz esas tres fases seguidas**, y los créditos te cubrirán. Kubernetes (kind) y la observabilidad corren en tu portátil. Las condiciones cambian: la tabla "Datos que caducan" de la fase 6 dice cuándo se comprobaron.

**Criterios de salida:** una VPC con subred pública y privada, y explicar por qué la base de datos va en la privada · Vigía en EC2 con un rol IAM, sin llaves guardadas en el servidor · MFA en el raíz y trabajo diario con un usuario administrador · 80 % o más en las preguntas oficiales de práctica · **CLF-C02 aprobado**.

### Fase 7 — CI/CD con GitHub Actions · 25–35 h · clases 82–91 ✍️

Automatizar pruebas y despliegues es el centro del trabajo DevOps: cada cambio pasa por el mismo camino, sin pasos manuales. Clases en [`fase-7/`](fase-7/README.md):
- **Integración continua (82–85),** sobre una aplicación de prácticas: workflows, lint, pruebas y la imagen en cada PR; `main` protegida con un ruleset; secretos, variables y permisos mínimos.
- **Entrega y despliegue continuos (86–89):** OIDC con AWS, la imagen en ECR, el despliegue en EC2 con Session Manager y las estrategias de despliegue, con vuelta atrás automática.
- **Vigía v4 (90),** con su [`verify.sh`](recursos/vigia/v4/README.md).
- **El examen de las fases 4 a 7 y el plan para postular (91).**

**Criterios de salida:** un PR con una prueba rota no se puede unir a `main` · al unir a `main`, la imagen se construye, se publica y se despliega sola · ninguna credencial de AWS en el repo ni en su historial · explicar la diferencia entre integración, entrega y despliegue continuos.

Deja Vigía público: GitHub Actions es gratis en repositorios públicos con los runners estándar.

### ★ Hito: empezar a postular

Al cerrar la fase 7 tienes Linux, Git, redes, Python, Docker, AWS con el CLF y un pipeline real en un proyecto público. Desde aquí actualizas CV y LinkedIn y postulas a roles de entrada mientras sigues con las fases 8 a 10 (ver Empleo).

### Fase 8 — Terraform · 35–45 h · clases 92–101 ✍️

Lo que creaste a mano en AWS pasa a archivos versionados, revisables y repetibles: se crea y se destruye con un comando. Clases en [`fase-8/`](fase-8/README.md):
- **Terraform desde cero (92–96):** el ciclo `init`/`plan`/`apply`, providers y `data`, variables y tipos, dependencias y ciclo de vida, y el estado en S3 con `use_lockfile` (el bloqueo con DynamoDB está obsoleto).
- **Vigía en código (97–100):** importar lo que ya existía, un módulo propio para la red con bloques `moved`, secretos y *drift*, y el `plan` en cada PR.
- **Vigía v5 (101),** con su [`verify.sh`](recursos/vigia/v5/README.md) y la prueba de destruir y recrear desde cero.

**Criterios de salida:** recrear desde cero la infraestructura de Vigía con `terraform apply` y borrarla con `terraform destroy` · estado en S3 con versionado y `use_lockfile = true` · al menos un módulo propio con variables y outputs · explicar qué pasa si alguien cambia a mano un recurso que maneja Terraform.

**Recursos:** los tutoriales *Get Started* de HashiCorp para AWS y los objetivos del Terraform Associate (004), en el apéndice de la clase 101.

### Fase 9 — Kubernetes · 55–75 h · clases 102–115 ✍️

Kubernetes orquesta contenedores en varios servidores: los reinicia, los escala y los actualiza sin cortar el servicio. Es lo más pesado de la ruta, por eso llega después de Docker, AWS y CI/CD. Todo corre en tu portátil, con kind. Clases en [`fase-9/`](fase-9/README.md):
- **Kubernetes desde cero (102–108):** arquitectura, kind y kubectl; pods y etiquetas; Deployments con actualización y vuelta atrás; Services y DNS, con cloud-provider-kind para los balanceadores; ConfigMaps y Secrets; sondas, `requests` y `limits`; Jobs y CronJobs.
- **Kubernetes para operar (109–113):** volúmenes persistentes y StatefulSets; namespaces, cuotas y RBAC; Ingress y Gateway API (ingress-nginx se retiró en 2026); seis averías reales que diagnosticar; y Helm 4.
- **Vigía v6 (114–115):** API, PostgreSQL y el chequeo como CronJob en kind, una actualización rota y su vuelta atrás, y qué cambiaría en EKS, con su [`verify.sh`](recursos/vigia/v6/README.md).

**Criterios de salida:** Vigía en kind con Deployment, Service, ConfigMap, Secret y un CronJob · una actualización y un *rollback* con `kubectl rollout` · diagnosticar un pod en CrashLoopBackOff y otro en ImagePullBackOff con `describe` y `logs` · explicar la diferencia entre una sonda *liveness* y una *readiness*.

**Recursos:** *Learn Kubernetes Basics* (tutorial oficial) y la documentación de kind.

### Fase 10 — Observabilidad · 25–35 h · clases 116–125 ✍️

En producción no basta con que algo funcione: hay que saber cuándo deja de funcionar antes que los usuarios. Todo corre en tu portátil, con Compose. Clases en [`fase-10/`](fase-10/README.md):
- **Medir (116–118):** métricas, logs y trazas; instrumentar una aplicación de Python con `prometheus_client` y su `/metrics`; Prometheus y PromQL (RED, percentiles, reinicios de contadores), con una tienda de laboratorio que falla a propósito.
- **Avisar y entender (119–123):** alertas probadas con `promtool` y Alertmanager; Grafana con dashboards como código; SLI, SLO y presupuesto de errores con alertas de dos ventanas; logs JSON con `request_id` y postmortems sin culpables; y CloudWatch como alternativa gestionada.
- **Vigía v7 (124),** con su [`verify.sh`](recursos/vigia/v7/README.md) y una prueba de la alerta de punta a punta, y **el fin de la ruta (125):** Vigía desde cero con un comando, la defensa de 10 minutos y el examen final de las fases 8 a 10.

**Criterios de salida:** Vigía expone `/metrics` y Prometheus lo recoge · un dashboard con disponibilidad y latencia por sitio · una alerta que salta cuando un sitio cae más de 5 minutos, y probada · un SLO para Vigía y cuánto tiempo caído permite al mes · y, como cierre de la ruta: Vigía se levanta desde cero con un comando o un pipeline, se destruye igual, y lo explicas y defiendes en 10 minutos.

**Recursos:** la documentación de Prometheus y de Grafana, y los libros de SRE de Google (sre.google/books).

---

## 5. Certificaciones

| Certificación | Cuándo |
|---------------|--------|
| AWS Certified Cloud Practitioner (CLF-C02) | al cerrar la fase 6: es criterio de salida |
| AWS Solutions Architect – Associate (SAA-C03) | opcional, después de la fase 8 (unas 60–80 h más), con el 50 % de descuento que da aprobar la primera |
| Terraform Associate (004) | opcional, al cerrar la fase 8, si quieres reforzar el CV |
| CKA | cuando ya trabajes con Kubernetes |

Precios, idiomas, horarios de supervisión en español y políticas de cada examen: en la Ruta 2.0, revisados el 9 de octubre de 2026. Compruébalos de nuevo antes de pagar. Ninguna certificación sustituye a un proyecto.

## 6. Empleo (en paralelo)

La entrada más realista no siempre es un puesto llamado "DevOps". Empieza por soporte y operaciones, y sube desde ahí mientras terminas la ruta.

| Rol | Desde cuándo postular |
|-----|-----------------------|
| Soporte técnico, mesa de ayuda o NOC | desde la fase 3 |
| Soporte cloud | desde el hito, con el CLF |
| Junior Cloud, DevOps o SRE | desde el hito, con Vigía en v4 o más |

- **Portafolio:** Vigía público con README en inglés (qué hace, diagrama, cómo correrlo y qué se rompió en el camino), fijado en tu perfil de GitHub. Tu repo del curso, con P1 y P2, como prueba de constancia.
- **CV y LinkedIn:** una página, proyecto primero, sin inventar nada. Tu experiencia actual cuenta: turnos largos, atención a clientes y resolver problemas en el momento son lo que un puesto de soporte u operaciones usa a diario.
- **Preguntas técnicas típicas:** permisos y procesos, DNS y TCP, qué pasa al teclear una URL, imagen frente a contenedor, VPC y subredes, IAM, el estado de Terraform, CrashLoopBackOff y un incidente contado con el método STAR.
- **Simulacros:** pídeme que haga de entrevistador.
- **Inglés:** cada clase trae vocabulario y una frase de entrevista; las metas por fase están en la Ruta 2.0.

## 7. Reglas de dinero en AWS

| Regla | Detalle |
|-------|---------|
| Créditos a la vista | revisa el saldo y los días que quedan una vez por semana |
| Una región | siempre la misma, para no olvidar recursos encendidos en otra |
| NAT Gateway | cobra por hora: se crea, se prueba y se destruye el mismo día |
| Al terminar cada sesión | se borra lo creado: a mano hasta la fase 7, con `terraform destroy` desde la fase 8 |
| Llaves de acceso | nunca en Git. En EC2, roles IAM; en GitHub Actions, OIDC. Si una se filtra: desactivarla, rotarla y revisar CloudTrail |

## 8. Lo que este plan deja fuera a propósito

Una segunda nube, Jenkins, Ansible a fondo, *service mesh*, EKS en producción, las certificaciones Professional y coleccionar certificaciones en general. Son valiosos más adelante; antes del primer empleo diluyen el foco. El camino de junior a arquitecto está en `~/Documentos/ruta-junior-a-arquitecto-nube.md`, cerrado hasta terminar esta ruta.

## 9. Historial

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 3.x | 2026-09 | Plan por sesiones cortas. Archivado en `~/Documentos/my-devops-journey-v3-respaldo-2026-10-04.tar.gz` |
| 4.0 | 2026-10-04 | Reinicio. Fase 1 en 30 clases completas con autocorrección, servidor en VM, proyectos P1 y P2. Método en `COMO-ESTUDIAR.md` |
| 5.0 | 2026-10-09 | Alineado con la *Ruta Cloud & DevOps 2.0*: 10 fases medidas en horas a 7 h por semana; scripting con Bash y cron en la fase 1 (clases 16–20, nuevas); Git (22–24) antes de redes (26–34); Vigía como proyecto único que crece en cada fase (clases 21, 25 y 35, nuevas); AWS antes que CI/CD; Kubernetes casi al final; CLF como criterio de salida de AWS; P1 y P2 pasan a laboratorios integradores |
| 5.1 | 2026-10-10 | Las fases 4 a 10 escritas completas: clases 39–125, cada fase con su README, criterios de salida y "Datos que caducan"; Vigía v1 a v7 con pruebas de aceptación sin solución (`recursos/vigia/`), probadas contra una implementación de referencia privada; examen del hito (clase 91) y examen final con defensa (clase 125) |
