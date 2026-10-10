# Progreso

## 👉 Hoy

**Clase 02: El sistema de archivos y las rutas:** [`fase-1/clase-02-sistema-de-archivos.md`](fase-1/clase-02-sistema-de-archivos.md)

**Fase actual:** 1 · Linux y Bash (35–45 h según la Ruta 2.0)
**Deudas abiertas:** ninguna (máximo 2)

El curso cambió el 2026-10-09 para seguir la Ruta 2.0: lee el último apartado del [`PLAN.md`](PLAN.md#9-historial) y la sección "Tu semana" de [`COMO-ESTUDIAR.md`](COMO-ESTUDIAR.md) (10 min).

---

Marca `[x]` y escribe la fecha al cerrar cada clase. Una clase se cierra cuando el cierre está escrito y autocorregido. Anota el tiempo en el registro de abajo.

## Fase 1 — Linux y Bash

### A. Linux en tu equipo
- [x] 01 · La terminal, el shell y el kernel · 2026-10-08
- [ ] 02 · El sistema de archivos y las rutas ·
- [ ] 03 · Archivos y directorios ·
- [ ] 04 · Redirecciones, pipes y códigos de salida ·
- [ ] 05 · Buscar y filtrar: find, grep y compañía ·
- [ ] 06 · Permisos: usuarios, grupos y rwx ·
- [ ] 07 · Variables de entorno, PATH y el shell ·

### B. Administrar un servidor
- [ ] 08 · Tu primer servidor (Multipass) ·
- [ ] 09 · Usuarios, grupos y sudo ·
- [ ] 10 · Paquetes con apt ·
- [ ] 11 · Procesos y señales ·
- [ ] 12 · systemd: servicios ·
- [ ] 13 · Logs y journalctl ·
- [ ] 14 · Recursos: CPU, memoria y disco ·
- [ ] 15 · SSH a fondo ·

### C. Scripting con Bash
- [ ] 16 · Tu primer script: variables, argumentos y comillas ·
- [ ] 17 · Decisiones: if, test y case ·
- [ ] 18 · Bucles: for, while y leer archivos ·
- [ ] 19 · Funciones y scripts robustos ·
- [ ] 20 · Tareas programadas: cron y un backup con rotación ·

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

## Fases siguientes

| Fase | Horas (Ruta 2.0) | Estado |
|------|------------------|--------|
| 7 · CI/CD | 25–35 h | se escribe a continuación · **hito: empezar a postular** |
| 8 · Terraform | 35–45 h | — |
| 9 · Kubernetes | 55–75 h | — |
| 10 · Observabilidad | 25–35 h | — |

El temario de cada fase está en [`PLAN.md`](PLAN.md). Antes de empezar cada fase, pídeme `revisa la fase N`.

---

## Registro

La columna *Tiempo* es tiempo enfocado (clase, proyecto, Anki). Súmala cada mes para el registro de horas de la Ruta 2.0.

| Fecha | Clase | Tiempo | Notas |
|-------|-------|--------|-------|
| 2026-10-04 | — | — | Curso v4 creado. Empieza la clase 01. |
| 2026-10-08 | 01 | 40 min | Cierre: preguntas 2 y 4 en 🟡, corregidas. |
| 2026-10-09 | — | — | Curso v5: alineado con la Ruta 2.0. Scripting y Vigía v0 en la fase 1 (clases 16–21), Git antes de redes, Vigía como proyecto único. |
