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
| 4 · Python | 50–70 h | se escribe al aprobar el examen de fundamentos |
| 5 · Docker | 30–40 h | — |
| 6 · AWS + Cloud Practitioner | 60–80 h | — (la cuenta de AWS se abre al empezar esta fase) |
| 7 · CI/CD | 25–35 h | — · **hito: empezar a postular** |
| 8 · Terraform | 35–45 h | — |
| 9 · Kubernetes | 55–75 h | — |
| 10 · Observabilidad | 25–35 h | — |

Cuando una fase se abra, me pides: `escribe la fase N`. El temario de cada fase ya está en [`PLAN.md`](PLAN.md).

---

## Registro

La columna *Tiempo* es tiempo enfocado (clase, proyecto, Anki). Súmala cada mes para el registro de horas de la Ruta 2.0.

| Fecha | Clase | Tiempo | Notas |
|-------|-------|--------|-------|
| 2026-10-04 | — | — | Curso v4 creado. Empieza la clase 01. |
| 2026-10-08 | 01 | 40 min | Cierre: preguntas 2 y 4 en 🟡, corregidas. |
| 2026-10-09 | — | — | Curso v5: alineado con la Ruta 2.0. Scripting y Vigía v0 en la fase 1 (clases 16–21), Git antes de redes, Vigía como proyecto único. |
