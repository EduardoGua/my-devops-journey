# Progreso

## 👉 Hoy

**Tu clase de hoy es la primera sin marcar** de la lista de abajo. Así no hay que actualizar este apartado.

**Fase actual:** 1 · Linux y Bash (35–45 h según la Ruta 2.0)
**Deudas abiertas:** ninguna (máximo 2)

**Novedades del 2026-10-14** (5 min): cada clase de la fase 1 empieza con **La idea de hoy**; para cerrar una clase, `bash ~/my-devops-journey/recursos/nueva-nota.sh 04` te crea las notas con las preguntas ya copiadas; y al final de cada bloque hay un **repaso** que mezcla temas. Lo explica [`COMO-ESTUDIAR.md`](COMO-ESTUDIAR.md#repaso).

---

Marca `[x]` y escribe la fecha al cerrar cada clase. Una clase se cierra cuando el cierre está escrito y **calificado** (✅ 🟡 ❌, con la corrección de cada 🟡 y ❌). Anota el tiempo en el registro de abajo.

## Fase 1 — Linux y Bash

### A. Linux en tu equipo
- [x] 01 · La terminal, el shell y el kernel · 2026-10-08
- [x] 02 · El sistema de archivos y las rutas · 2026-10-11
- [x] 03 · Archivos y directorios · 2026-10-13
- [x] 04 · Redirecciones, pipes y códigos de salida · 2026-10-15
- [x] 05 · Buscar y filtrar: find, grep y compañía · 2026-10-18
- [ ] 06 · Permisos: usuarios, grupos y rwx ·
- [ ] 07 · Variables de entorno, PATH y el shell ·
- [ ] Repaso del bloque A ·

### B. Administrar un servidor
- [ ] 08 · Tu primer servidor (Multipass) ·
- [ ] 09 · Usuarios, grupos y sudo ·
- [ ] 10 · Paquetes con apt ·
- [ ] 11 · Procesos y señales ·
- [ ] 12 · systemd: servicios ·
- [ ] 13 · Logs y journalctl ·
- [ ] 14 · Recursos: CPU, memoria y disco ·
- [ ] 15 · SSH a fondo ·
- [ ] Repaso del bloque B ·

### C. Scripting con Bash
- [ ] 16 · Tu primer script: variables, argumentos y comillas ·
- [ ] 17 · Decisiones: if, test y case ·
- [ ] 18 · Bucles: for, while y leer archivos ·
- [ ] 19 · Funciones y scripts robustos ·
- [ ] 20 · Tareas programadas: cron y un backup con rotación ·
- [ ] Repaso del bloque C ·

### D. Proyecto
- [ ] 21 · Vigía v0: Bash + cron ·

### Criterios de salida de la fase 1 (sin mirar)
- [ ] Escribo un script que recibe una carpeta, la comprime con la fecha en el nombre y borra las copias de más de 7 días
- [ ] Explico qué hace `set -euo pipefail` y qué guarda `$?`
- [ ] Encuentro con `journalctl` por qué no arrancó un servicio
- [ ] Entro por SSH con llave, sin contraseña, a una VM
- [ ] Vigía v0 corre con cron y deja log

### En paralelo (desde la clase 05)
- Bandit, niveles 0–20: [`fase-1/bandit.md`](fase-1/bandit.md) · Nivel actual: 0

---

## Fase 2 — Git y GitHub

- [ ] 22 · Git por dentro ·
- [ ] 23 · Ramas, merge y conflictos ·
- [ ] 24 · GitHub y pull requests ·
- [ ] 25 · Vigía v0.1: publicado en GitHub ·

### Criterios de salida de la fase 2
- [ ] Creo una rama, hago dos commits, abro un pull request y lo uno
- [ ] Provoco un conflicto a propósito y lo resuelvo
- [ ] Recupero con Git un archivo que borré por error
- [ ] Mi perfil de GitHub muestra el repo de Vigía con su README

---

## Fase 3 — Redes

### A. Redes
- [ ] 26 · Cómo viaja una petición: el modelo de capas ·
- [ ] 27 · Direcciones IP y CIDR ·
- [ ] 28 · Subnetting: diseñar redes como en una VPC ·
- [ ] 29 · Puertos, TCP y UDP ·
- [ ] 30 · Rutas, gateway y NAT ·
- [ ] 31 · DNS ·
- [ ] 32 · HTTP y HTTPS ·
- [ ] 33 · Firewall ·
- [ ] 34 · Dos servidores: tu primera red ·

### B. Proyectos y examen
- [ ] 35 · Vigía v0.2: DNS y certificados ·
- [ ] 36 · P1 — Runbook de incidentes ·
- [ ] 37 · P2 — Servidor reproducible con cloud-init ·
- [ ] 38 · Examen de fundamentos (fases 1 a 3) ·

### Criterios de salida de la fase 3 (sin mirar)
- [ ] Explico en voz alta, sin notas, qué pasa desde que escribo una URL hasta que carga la página
- [ ] Divido `10.0.0.0/16` en cuatro subredes y digo cuántas direcciones tiene cada una
- [ ] Diagnostico con `dig`, `curl -v` y `ss` por qué un servicio no responde
- [ ] Explico la diferencia entre IP privada y pública, y para qué sirve NAT
- [ ] P1 y P2 terminados, y el examen de fundamentos aprobado (≥ 80 %)

---

## Fase 4 — Python para automatizar

### A. Python desde cero
- [ ] 39 · Tu primer programa: el intérprete, tipos y f-strings ·
- [ ] 40 · Decisiones y bucles ·
- [ ] 41 · Listas, diccionarios y compañía ·
- [ ] 42 · Funciones ·
- [ ] 43 · Texto, archivos y rutas ·
- [ ] 44 · Errores y excepciones ·
- [ ] 45 · Módulos, paquetes y la biblioteca estándar ·

### B. Python para operaciones
- [ ] 46 · Entornos virtuales y dependencias ·
- [ ] 47 · JSON, CSV y YAML ·
- [ ] 48 · Programas de línea de comandos: argparse y logging ·
- [ ] 49 · Consumir APIs con requests ·
- [ ] 50 · Automatizar el sistema: subprocess, shutil y variables de entorno ·
- [ ] 51 · SQLite desde Python ·
- [ ] 52 · Pruebas con pytest ·
- [ ] 53 · Una API mínima con FastAPI ·

### C. Proyecto
- [ ] 54 · Vigía v1 (I): el chequeo en Python ·
- [ ] 55 · Vigía v1 (II): la API, tus pruebas y la versión ·

### Criterios de salida de la fase 4 (sin mirar)
- [ ] Escribo un script que lee un JSON, filtra datos y escribe un CSV, con manejo de errores
- [ ] Llamo a una API pública con `requests` y manejo un error de red sin que el script se caiga
- [ ] Mi proyecto tiene `venv`, `requirements.txt` y al menos 5 pruebas con `pytest`
- [ ] Vigía v1 devuelve el estado en JSON

---

## Fase 5 — Docker

### A. Contenedores
- [ ] 56 · Qué es un contenedor de verdad ·
- [ ] 57 · Imágenes y contenedores: run, ps, logs, exec, inspect ·
- [ ] 58 · Tu primer Dockerfile: capas, caché y .dockerignore ·
- [ ] 59 · Imágenes pequeñas y seguras ·
- [ ] 60 · Volúmenes y persistencia ·
- [ ] 61 · Redes de Docker ·
- [ ] 62 · Docker Compose ·
- [ ] 63 · Depurar contenedores ·
- [ ] 64 · Registros: publicar en Docker Hub ·

### B. Proyecto
- [ ] 65 · Vigía v2 (I): PostgreSQL y el Dockerfile ·
- [ ] 66 · Vigía v2 (II): Compose con API, chequeo y base de datos ·

### Criterios de salida de la fase 5 (sin mirar)
- [ ] Explico la diferencia entre imagen, contenedor y volumen
- [ ] Escribo un Dockerfile multi-stage que corre como usuario no root
- [ ] Levanto Vigía con `docker compose up` desde un clon limpio del repo
- [ ] Encuentro con `docker logs` y `docker inspect` por qué un contenedor se reinicia en bucle

---

## Fase 6 — AWS y Cloud Practitioner

### La víspera (clases 67 y 70)
- [ ] Cuenta creada, MFA en el usuario raíz y contraseña en un gestor
- [ ] Ninguna llave de acceso para el usuario raíz
- [ ] Usuario administrador para el día a día, con MFA
- [ ] Fecha de fin del plan gratuito anotada, y el saldo de créditos a la vista
- [ ] Región única escrita en el README: `us-east-1`
- [ ] AWS CLI configurada con un perfil (`aws login`)

### A. Cuenta, costos e identidad
- [ ] 67 · La víspera: tu cuenta sin sorpresas ·
- [ ] 68 · La nube y su factura: regiones, zonas, precios y créditos ·
- [ ] 69 · IAM I: usuarios, grupos y políticas ·
- [ ] 70 · IAM II: roles y la AWS CLI sin llaves ·

### B. Los servicios básicos
- [ ] 71 · VPC desde cero ·
- [ ] 72 · EC2, user-data y Session Manager ·
- [ ] 73 · Security groups y NACLs ·
- [ ] 74 · S3: buckets, versiones y acceso ·
- [ ] 75 · ECR: tu registro de imágenes ·
- [ ] 76 · CloudWatch: métricas, logs y alarmas ·
- [ ] 77 · RDS, balanceadores, Auto Scaling y Lambda ·

### C. Proyecto
- [ ] 78 · Vigía v3 (I): en EC2 con un rol IAM ·
- [ ] 79 · Vigía v3 (II): informe en S3, logs en CloudWatch y destrucción ·

### D. Certificación
- [ ] 80 · CLF-C02 (I): la guía del examen como lista de control ·
- [ ] 81 · CLF-C02 (II): simulacros, logística y el día del examen ·

Puntuaciones en las preguntas oficiales de práctica (fecha · %):

### Criterios de salida de la fase 6 (sin mirar)
- [ ] Creo una VPC con una subred pública y otra privada, y explico por qué la base de datos va en la privada
- [ ] Vigía corre en EC2 con un rol IAM, sin llaves guardadas en el servidor
- [ ] El usuario raíz tiene MFA y trabajo a diario con un usuario administrador
- [ ] Saco un 80 % o más en las preguntas oficiales de práctica
- [ ] **CLF-C02 aprobado** (fecha y puntuación: )

---

## Fase 7 — CI/CD con GitHub Actions

### A. Integración continua
- [ ] 82 · CI/CD y tu primer workflow ·
- [ ] 83 · Lint y pruebas en cada PR ·
- [ ] 84 · Comprobaciones obligatorias y leer un job fallido ·
- [ ] 85 · Secretos, variables y permisos ·

### B. Entrega y despliegue continuos
- [ ] 86 · OIDC: AWS sin llaves ·
- [ ] 87 · Construir y publicar la imagen en ECR ·
- [ ] 88 · Desplegar en EC2 con Session Manager ·
- [ ] 89 · Estrategias de despliegue y pruebas de humo ·

### C. Proyecto y hito
- [ ] 90 · Vigía v4: el pipeline completo ·
- [ ] 91 · ★ El hito: examen de las fases 4 a 7 y empezar a postular ·

Examen de las fases 4 a 7 (fecha · %):

### Criterios de salida de la fase 7 (sin mirar)
- [ ] Un PR con una prueba rota no se puede unir a `main`
- [ ] Al unir a `main`, la imagen se construye, se publica y se despliega sola
- [ ] Ninguna credencial de AWS en el repositorio ni en su historial
- [ ] Explico la diferencia entre integración, entrega y despliegue continuos

### ★ Hito: empezar a postular
- [ ] CV de una página, en inglés y en español
- [ ] LinkedIn y GitHub al día, con Vigía fijado
- [ ] Tres historias STAR escritas y grabadas
- [ ] Primeras postulaciones registradas en `notas/empleo/postulaciones.md`

---

## Fase 8 — Terraform

### A. Terraform desde cero
- [ ] 92 · Instalar Terraform y tu primer recurso ·
- [ ] 93 · Providers, versiones, resources y data ·
- [ ] 94 · Variables, outputs, locals y tipos ·
- [ ] 95 · Dependencias y ciclo de vida ·
- [ ] 96 · El estado: backend S3 con bloqueo ·

### B. Vigía en código
- [ ] 97 · La infraestructura de Vigía en código ·
- [ ] 98 · Módulos ·
- [ ] 99 · Secretos, import y drift ·
- [ ] 100 · Terraform en CI ·

### C. Proyecto
- [ ] 101 · Vigía v5: toda la infraestructura en Terraform ·

Recreación desde cero (fecha · minutos):

### Criterios de salida de la fase 8 (sin mirar)
- [ ] Recreo desde cero la infraestructura de Vigía con `terraform apply` y la borro con `terraform destroy`
- [ ] El estado está en S3, con versionado y `use_lockfile = true`
- [ ] Tengo al menos un módulo propio con variables y outputs
- [ ] Explico qué pasa si alguien cambia a mano un recurso que maneja Terraform

---

## Fase 9 — Kubernetes

### A. Kubernetes desde cero
- [ ] 102 · Por qué orquestar: arquitectura, kind y kubectl ·
- [ ] 103 · Pods, YAML y etiquetas ·
- [ ] 104 · Deployments: escalar, actualizar y volver atrás ·
- [ ] 105 · Services y DNS del cluster ·
- [ ] 106 · ConfigMaps y Secrets ·
- [ ] 107 · Sondas, requests y limits ·
- [ ] 108 · Jobs y CronJobs ·

### B. Kubernetes para operar
- [ ] 109 · Volúmenes persistentes y StatefulSets ·
- [ ] 110 · Namespaces y RBAC ·
- [ ] 111 · Ingress y Gateway API ·
- [ ] 112 · Depurar: CrashLoopBackOff, ImagePullBackOff y Pending ·
- [ ] 113 · Helm ·

### C. Proyecto
- [ ] 114 · Vigía v6 (I): API y base de datos en kind ·
- [ ] 115 · Vigía v6 (II): CronJob, rollout y qué cambia en EKS ·

Averías de la clase 112, cronometradas (fecha · minutos):

### Criterios de salida de la fase 9 (sin mirar)
- [ ] Vigía corre en kind con Deployment, Service, ConfigMap, Secret y un CronJob
- [ ] Hago una actualización y un *rollback* con `kubectl rollout`
- [ ] Diagnostico un pod en CrashLoopBackOff y otro en ImagePullBackOff con `describe` y `logs`
- [ ] Explico la diferencia entre una sonda *liveness* y una *readiness*

---

## Fase 10 — Observabilidad

### A. Medir
- [ ] 116 · Métricas, logs y trazas ·
- [ ] 117 · El endpoint `/metrics` ·
- [ ] 118 · Prometheus y PromQL ·

### B. Avisar y entender
- [ ] 119 · Reglas de alerta y Alertmanager ·
- [ ] 120 · Grafana: dashboards como código ·
- [ ] 121 · SLI, SLO, SLA y presupuesto de errores ·
- [ ] 122 · Logs estructurados y postmortems ·
- [ ] 123 · CloudWatch, la alternativa gestionada ·

### C. Proyecto y cierre de la ruta
- [ ] 124 · Vigía v7: métricas, alerta y SLO ·
- [ ] 125 · Fin de la ruta: desde cero, la defensa y el examen final ·

Arranque desde cero (fecha · minutos):
Defensa de 10 minutos (fecha · nota con la rúbrica):
Examen final de las fases 8 a 10 (fecha · nota):

### Criterios de salida de la fase 10 (sin mirar)
- [ ] Vigía expone `/metrics` y Prometheus lo recoge
- [ ] Un dashboard con disponibilidad y latencia por sitio
- [ ] Una alerta que salta cuando un sitio cae más de 5 minutos, y probada
- [ ] Un SLO para Vigía y cuánto tiempo caído permite al mes
- [ ] Vigía se levanta desde cero con un comando o un pipeline, se destruye igual, y lo explico y defiendo en 10 minutos

---

## Vigía

| Versión | Fase | Estado | Etiqueta |
|---------|------|--------|----------|
| v0 · Bash + cron | 1 | ⬜ | |
| v0.1 · GitHub y PRs | 2 | ⬜ | |
| v0.2 · DNS y TLS | 3 | ⬜ | |
| v1 · Python | 4 | ⬜ | |
| v2 · Docker | 5 | ⬜ | |
| v3 · AWS | 6 | ⬜ | |
| v4 · CI/CD | 7 | ⬜ | |
| v5 · Terraform | 8 | ⬜ | |
| v6 · Kubernetes | 9 | ⬜ | |
| v7 · Observabilidad | 10 | ⬜ | |

---

## Antes de cada fase

Las diez fases están escritas. Antes de empezar cada una, pídeme `revisa la fase N`: compruebo que sus versiones, precios y comandos siguen al día. El temario completo y las horas de cada fase están en [`PLAN.md`](PLAN.md).

---

## Registro

La columna *Tiempo* es tiempo enfocado (clase, proyecto, Anki). Súmala cada mes para el registro de horas de la Ruta 2.0.

| Fecha | Clase | Tiempo | Notas |
|-------|-------|--------|-------|
| 2026-10-04 | — | — | Curso v4 creado. Empieza la clase 01. |
| 2026-10-08 | 01 | 40 min | Cierre: preguntas 2 y 4 en 🟡, corregidas. |
| 2026-10-09 | — | — | Curso v5: alineado con la Ruta 2.0. Scripting y Vigía v0 en la fase 1 (clases 16–21), Git antes de redes, Vigía como proyecto único. |
| 2026-10-14 | — | — | Fase 1 revisada y probada en Ubuntu 26.04: *La idea de hoy* en cada clase, `nueva-nota.sh`, repasos de bloque A, B y C. |
|2026-10-15|04|3 horas en dos dias| la encontre confusa pero considero que es solo falta de practica. |
|2026-10-18|05|fueron como 3 dias con 15 a media hora en cada dia | la clase la lei en 3 veces para poder tanto comprender todo lo posible con respecto a los comandos find y grep del resto considero lo mismo no es tanto memorizacion sino practica para dominarlos
