# El mapa — de cero a Cloud & DevOps (AWS)

**Versión:** 4.0 · 2026-10-04
**Alumno:** Eduardo · Ubuntu 26.04 · estudio autodidacta
**Meta:** conseguir un primer empleo en Cloud / DevOps (o en un puesto puente: Cloud Support, SysAdmin, SRE junior) y tener la base para crecer después hacia arquitectura.

Este archivo es el **mapa**: qué se aprende, en qué orden, qué proyecto cierra cada fase y cómo sabes que puedes pasar a la siguiente.
Lo que haces cada día está en [`PROGRESO.md`](PROGRESO.md). El método está en [`COMO-ESTUDIAR.md`](COMO-ESTUDIAR.md).

---

## 1. Las ideas que sostienen el plan

1. **Fundamentos antes que herramientas.** Docker, AWS y Kubernetes son Linux y redes con otra interfaz. Quien domina la base aprende cada herramienta nueva en semanas. Quien no la domina memoriza comandos y se bloquea en la primera avería.
2. **Practicar más que leer.** Cada clase tiene más terminal que teoría. La teoría está para entender lo que acabas de ver, no para memorizarla antes.
3. **Romper a propósito.** En este trabajo te pagan por arreglar lo que falla. Cada clase incluye fallos provocados para que aprendas a diagnosticarlos.
4. **Cada fase termina en un proyecto que puedas defender** en una entrevista técnica de diez minutos.
5. **Una sola nube: AWS.** Es la que más ofertas tiene. Lo aprendido se traslada a Azure o GCP en semanas.
6. **Sin gastos sorpresa.** No se crea nada de pago en AWS antes de tener alarmas de costo y la costumbre de destruir los recursos.

## 2. Orden de las fases

```
 F0 Preparación
  └─ F1 Fundamentos: Linux · Redes · Git ........ la base de todo
      └─ F2 Scripting: Bash · Python ............ automatizar lo que ya entiendes
          └─ F3 Contenedores: Docker ............ empaquetar aplicaciones
              └─ F4 CI/CD: GitHub Actions ........ automatizar build y despliegue
                  └─ F5 AWS ...................... la nube, a mano y entendida
                      └─ F6 Terraform ............ la nube como código
                          └─ F7 Kubernetes ....... orquestar contenedores
                              └─ F8 Observabilidad + Capstone
                                  └─ F9 Búsqueda de empleo
```

Saltarse una fase hace que la siguiente parezca magia, y en una entrevista eso se nota.

## 3. Tiempo realista

| Ritmo semanal | Duración total aproximada |
|---------------|---------------------------|
| 15–20 h | 9–11 meses |
| 10–12 h | 12–15 meses |
| 5–6 h | 20 meses o más. Funciona, pero cuesta mantener el hilo |

| Fase | Semanas (a 10–15 h/sem) |
|------|-------------------------|
| F1 Fundamentos | 9–11 |
| F2 Scripting | 4–5 |
| F3 Docker | 4 |
| F4 CI/CD | 3 |
| F5 AWS | 9–10 |
| F6 Terraform | 4 |
| F7 Kubernetes | 4 |
| F8 Observabilidad + Capstone | 5–6 |
| F9 Empleo | en paralelo desde el final de F7 |

Honestamente: casi nadie entra como "DevOps" sin experiencia previa. La puerta más habitual son los **puestos puente**: Cloud Support Associate, soporte técnico con Linux, NOC, SysAdmin junior. Este plan te prepara para ellos desde la mitad de la F5, y para Junior Cloud/DevOps al terminar el capstone.

---

## F0 — Preparación ✅

Ya hecho en este equipo: Ubuntu, Git, llave SSH, GitHub (`EduardoGua`) con `gh`, Docker instalado.
Pendiente y planificado: la cuenta de AWS se crea la semana antes de la F5, no ahora.

---

## F1 — Fundamentos: Linux, Redes y Git

Es la fase más larga y la más importante. Clases completas en [`fase-1/`](fase-1/README.md).

| Bloque | Clases | Dónde se practica |
|--------|--------|-------------------|
| A. Linux en tu equipo | 01–07 | Tu Ubuntu |
| B. Administrar un servidor | 08–15 | VM `servidor-01` (Multipass) |
| C. Redes | 16–24 | VMs `servidor-01` y `servidor-02` |
| D. Git y GitHub | 25–27 | Tu Ubuntu + GitHub |
| E. Proyectos y examen | 28–30 | VMs + repo |

**Proyectos**
- **P1 — Runbook de incidentes:** seis averías reales provocadas en la VM, diagnosticadas y documentadas.
- **P2 — Servidor reproducible:** un archivo `cloud-init` que crea desde cero un servidor endurecido con nginx y firewall. Es exactamente lo que harás en AWS con *user-data*.

**Práctica paralela:** OverTheWire Bandit, niveles 0–20.

**Puerta**
- [ ] Clases 01–27 cerradas, sin deudas abiertas
- [ ] P1 y P2 en GitHub
- [ ] Calculas una subred CIDR a mano sin dudar
- [ ] Explicas en voz alta qué pasa desde que escribes `curl https://ejemplo.com` hasta que ves la respuesta
- [ ] Examen de la fase 1 aprobado (≥ 80 %), sin apuntes

---

## F2 — Scripting: Bash y Python

Automatizar lo que ya sabes hacer a mano.

**Temario**
1. Variables, comillas y expansión
2. Condiciones, `test` y códigos de salida
3. Bucles y lectura de archivos línea a línea
4. Funciones, argumentos y `getopts`
5. Scripts robustos: `set -euo pipefail`, `trap` y logs
6. `shellcheck` y estilo
7. `cron` y *timers* de systemd
8. Python para operaciones: entorno virtual y `pathlib`
9. Python: `argparse`, `json` y `subprocess`
10. Python: consumir una API HTTP (`requests`)
11. Pruebas mínimas: `pytest` y `bats`

**Proyecto P3 — Monitor de servidor:** un script Bash que revisa disco, memoria, servicios y puertos, con salida en texto o JSON y ejecución periódica por *timer*. Un script Python resume su historial. El README permite que cualquiera lo instale y lo desinstale.

**Puerta:** P3 en GitHub con `shellcheck` limpio · explicas cada flag de `set -euo pipefail` · examen F2.

**Recursos:** *The Linux Command Line* (William Shotts, gratis en linuxcommand.org) · Google Shell Style Guide · documentación oficial de Python.

---

## F3 — Contenedores: Docker

**Temario**
1. Qué es un contenedor de verdad: namespaces y cgroups (enlaza con la F1)
2. Imágenes, capas y registros
3. `docker run`, `ps`, `logs`, `exec`, `inspect`
4. Dockerfile: instrucciones y caché
5. Multi-stage builds e imágenes pequeñas
6. Seguridad: usuario no root, sin secretos en la imagen, escaneo con `trivy`
7. Volúmenes y persistencia
8. Redes de Docker: bridge, puertos publicados, DNS interno
9. Docker Compose: varios servicios, healthchecks, variables
10. Depurar un contenedor que no arranca o no escucha
11. Publicar en GHCR

**Proyecto P4 — App en contenedores:** una API sencilla con Postgres y un proxy nginx en Compose. Imagen multi-stage sin root, publicada, y un README con la arquitectura y la guía de depuración.

**Puerta:** P4 publicado · explicas imagen, contenedor y capa · arreglas un "el puerto no responde" · examen F3.

**Recursos:** docs.docker.com (Get started y referencia de Dockerfile).

---

## F4 — CI/CD con GitHub Actions

**Temario**
1. CI y CD: qué problema resuelven
2. Anatomía de un workflow: eventos, jobs, steps y runners
3. Lint y pruebas automáticas en cada pull request
4. Build y push de imágenes al registro
5. Secretos y variables de entorno; permisos mínimos (`permissions:`)
6. Ramas protegidas y flujo de pull request
7. Caché, matrices y artefactos
8. Leer un job fallido y arreglarlo

**Proyecto P5:** pipeline completo para P4: lint, tests, build, escaneo y publicación solo desde `main`. Diagrama en el README y un postmortem de un fallo provocado.

**Puerta:** P5 en verde · ningún secreto en el repo · explicas un job rojo leyendo su log · examen F4.

---

## F5 — AWS

Primero consola y CLI, entendiendo cada pieza. Terraform viene después: escribir como código algo que nunca hiciste a mano produce archivos copiados sin entender.

**Víspera (sesión única antes de empezar)**
- [ ] Cuenta creada, MFA en root, root guardado bajo llave
- [ ] Usuario de trabajo con IAM Identity Center o IAM, con MFA
- [ ] Budgets con aviso en 5, 10 y 20 USD y el correo comprobado
- [ ] Región única escrita en el README (sugerida: `us-east-1`)
- [ ] AWS CLI configurado

**Temario**
1. Modelo de responsabilidad compartida, regiones y zonas de disponibilidad, free tier, cómo se factura
2. IAM: usuarios, grupos, roles, políticas, mínimo privilegio, evaluación de políticas
3. VPC: CIDR, subredes públicas y privadas, tablas de rutas, Internet Gateway y NAT (aplica lo de la F1)
4. Security Groups frente a NACLs
5. EC2: AMIs, tipos de instancia, user-data, key pairs y Session Manager
6. EBS, snapshots y AMIs propias
7. S3: buckets, políticas, bloqueo de acceso público, versionado, ciclo de vida
8. Load balancers (ALB), target groups y health checks
9. Auto Scaling Groups
10. RDS: motores, subredes privadas, backups y Multi-AZ (concepto)
11. Route 53 y ACM (certificados)
12. CloudFront delante de S3
13. CloudWatch: métricas, logs, alarmas y SNS
14. ECR y ECS Fargate (introducción)
15. Arquitectura de tres capas completa a mano y destrucción completa

**Proyectos**
- **P6:** la app de P4 en AWS: VPC propia, ALB, EC2 en Auto Scaling y RDS en subred privada, con un rol IAM en la instancia. Diagrama, costo estimado y runbook de destrucción.
- **P6b:** sitio estático en S3 + CloudFront + HTTPS.

**Puerta:** dibujas de memoria una VPC con subredes, rutas, SG, ALB y EC2 · explicas rol, política y usuario con un ejemplo propio · encuentras un error 5xx en logs y métricas · P6 y P6b documentados y destruidos · examen F5.

**Opcional al terminar: AWS Certified Cloud Practitioner** (barata y rápida), y más adelante **Solutions Architect – Associate** (la que más pesa en los filtros de RR. HH.). Ninguna sustituye a un proyecto.

**Recursos:** documentación oficial de AWS · AWS Skill Builder (cursos gratuitos) · AWS Well-Architected Framework (pilares).

---

## F6 — Terraform

**Temario**
1. Infraestructura como código: por qué existe
2. Providers, resources, `plan`, `apply`, `destroy`
3. Variables, outputs, locals y tipos
4. El *state*: qué es, por qué no va a git, estado remoto en S3 con bloqueo
5. Data sources e importar recursos existentes
6. Módulos: escribirlos y usar los públicos con criterio
7. Entornos (dev/prod) con workspaces o directorios
8. Terraform en CI: `fmt`, `validate`, `plan` en el PR y `tflint`
9. Seguridad: secretos fuera del código, `checkov` o `tfsec`

**Proyecto P7:** P6 completo en Terraform y modular, con estado remoto, plan automático en cada PR y destroy verificado.

**Puerta:** explicas el state y el *drift* · un cambio se ve en el plan antes del apply · destroy comprobado · examen F6.

**Recursos:** developer.hashicorp.com/terraform/tutorials.

---

## F7 — Kubernetes

**Temario**
1. Por qué orquestar: lo que Docker solo no resuelve
2. Arquitectura: control plane, nodos, etcd, kubelet
3. Clúster local con `kind`; `kubectl` (`get`, `describe`, `logs`, `exec`)
4. Pods, ReplicaSets y Deployments; rolling updates y rollback
5. Services: ClusterIP, NodePort, LoadBalancer
6. ConfigMaps y Secrets
7. Probes: liveness y readiness; requests y limits
8. Ingress
9. Namespaces y RBAC básico
10. Helm: usar charts y escribir uno simple
11. Depurar: CrashLoopBackOff, ImagePullBackOff, Pending
12. EKS: qué cambia en la nube (concepto, sin dejarlo encendido)

**Proyecto P8:** la app de P4 en kind con manifiestos o un chart de Helm, probes, límites, Ingress y un README para levantarla, probarla y borrarla.

**Puerta:** explicas Pod, Deployment y Service en tres minutos · depuras un CrashLoopBackOff con un método repetible · examen F7.

---

## F8 — Observabilidad y Capstone

**Observabilidad (2 semanas):** métricas, logs y trazas · Prometheus y Grafana en kind · alertas útiles frente a alertas ruidosas · SLI, SLO y presupuesto de errores · cómo escribir un postmortem sin culpables.

**Capstone (3–4 semanas):** un único proyecto profesional que lo une todo:
- App con frontend sencillo, API y base de datos
- Docker multi-stage
- Infraestructura en Terraform sobre AWS
- Pipeline de CI/CD que prueba, construye, escanea y despliega
- Monitoreo con alarmas y un runbook
- README que se defiende solo: propósito, diagrama, despliegue, costo, límites y siguientes pasos

**Puerta:** el capstone se despliega desde cero con un comando o un pipeline, y se destruye igual · lo explicas y defiendes en 10 minutos.

---

## F9 — Búsqueda de empleo (en paralelo desde el final de F7)

- **Portfolio:** 4–5 repos cuidados (P2, P3, P5, P7 y el capstone), no veinte repos vacíos. Cada README en inglés.
- **CV y LinkedIn:** una página, con proyectos medibles y sin inventar nada. Título honesto: *Junior Cloud / DevOps Engineer — Linux, AWS, Terraform, Docker, CI/CD*.
- **Preguntas técnicas típicas:** permisos y procesos, DNS y TCP, qué pasa al teclear una URL, imagen frente a contenedor, VPC y subredes, IAM, el state de Terraform, CrashLoopBackOff, un incidente contado con el método STAR.
- **Simulacros de entrevista:** pídeme que haga de entrevistador.
- **Dónde aplicar:** Cloud Support, DevOps junior, SRE junior, Platform junior, SysAdmin con cloud, NOC. Empieza a aplicar con P6 y P7 hechos.
- **Inglés:** casi todas las ofertas remotas lo piden. Cada clase incluye vocabulario y una frase de entrevista en inglés.

---

## 4. Reglas de dinero en AWS

| Regla | Detalle |
|-------|---------|
| Alarmas antes de todo | Budgets en 5, 10 y 20 USD |
| Una región | La misma siempre |
| NAT Gateway | Cuesta cada hora: se crea, se prueba y se destruye el mismo día |
| Al terminar cada sesión | Lista de recursos y destroy. Al día siguiente, un vistazo a Billing |
| Llaves de acceso | Nunca en git. Si una se filtra: desactivarla, rotarla y revisar CloudTrail |

## 5. Lo que este plan deja fuera a propósito

Una segunda nube, Jenkins, Ansible a fondo, service mesh, EKS en producción y coleccionar certificaciones. Son valiosos más adelante. Antes del primer empleo diluyen el foco.

## 6. Historial

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 3.x | 2026-09 | Plan por sesiones cortas. Archivado en `~/Documentos/my-devops-journey-v3-respaldo-2026-10-04.tar.gz` |
| 4.0 | 2026-10-04 | Reinicio. F1 rehecha en clases completas con autocorrección: bloque de redes de 9 clases, servidor en VM, proyectos P1 y P2 orientados a AWS. Temario detallado de todas las fases. Observabilidad añadida. Método en `COMO-ESTUDIAR.md` |
