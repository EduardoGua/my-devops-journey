# Fase 1 — Fundamentos: Linux, Redes y Git

**Duración estimada:** 9–11 semanas a 10–15 h por semana.
**Al terminar:** administras un servidor Linux por SSH, entiendes una red lo bastante para diseñar una VPC y diagnosticar por qué "no conecta", y trabajas con Git como en un equipo real.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Linux en tu equipo** | | |
| 01 | [La terminal, el shell y el kernel](clase-01-terminal-shell-kernel.md) | Ubuntu | 60 min |
| 02 | [El sistema de archivos y las rutas](clase-02-sistema-de-archivos.md) | Ubuntu | 60 min |
| 03 | [Archivos y directorios](clase-03-archivos-y-directorios.md) | Ubuntu | 60 min |
| 04 | [Redirecciones, pipes y códigos de salida](clase-04-redirecciones-y-pipes.md) | Ubuntu | 75 min |
| 05 | [Buscar y filtrar: find, grep y compañía](clase-05-buscar-y-filtrar.md) | Ubuntu | 75 min |
| 06 | [Permisos: usuarios, grupos y rwx](clase-06-permisos.md) | Ubuntu | 75 min |
| 07 | [Variables de entorno, PATH y el shell](clase-07-entorno-y-path.md) | Ubuntu | 60 min |
| | **B. Administrar un servidor** | | |
| 08 | [Tu primer servidor (Multipass)](clase-08-primer-servidor.md) | VM | 60 min |
| 09 | [Usuarios, grupos y sudo](clase-09-usuarios-y-sudo.md) | VM | 75 min |
| 10 | [Paquetes con apt](clase-10-paquetes-apt.md) | VM | 60 min |
| 11 | [Procesos y señales](clase-11-procesos-y-senales.md) | VM | 75 min |
| 12 | [systemd: servicios](clase-12-systemd.md) | VM | 90 min |
| 13 | [Logs y journalctl](clase-13-logs.md) | VM | 75 min |
| 14 | [Recursos: CPU, memoria y disco](clase-14-recursos.md) | VM | 120 min |
| 15 | [SSH a fondo](clase-15-ssh.md) | Ubuntu + VM | 90 min |
| | **C. Redes** | | |
| 16 | [Cómo viaja una petición: el modelo de capas](clase-16-modelo-de-capas.md) | VM | 75 min |
| 17 | [Direcciones IP y CIDR](clase-17-ip-y-cidr.md) | papel + VM | 90 min |
| 18 | [Subnetting: diseñar redes como en una VPC](clase-18-subnetting.md) | papel | 90 min |
| 19 | [Puertos, TCP y UDP](clase-19-puertos-tcp-udp.md) | Ubuntu + VM | 90 min |
| 20 | [Rutas, gateway y NAT](clase-20-rutas-y-nat.md) | VM | 75 min |
| 21 | [DNS](clase-21-dns.md) | Ubuntu + VM | 90 min |
| 22 | [HTTP y HTTPS](clase-22-http-https.md) | Ubuntu + VM | 90 min |
| 23 | [Firewall](clase-23-firewall.md) | VM | 90 min |
| 24 | [Dos servidores: tu primera red](clase-24-dos-servidores.md) | 2 VMs | 120 min |
| | **D. Git y GitHub** | | |
| 25 | [Git por dentro](clase-25-git-por-dentro.md) | Ubuntu | 90 min |
| 26 | [Ramas, merge y conflictos](clase-26-ramas-y-conflictos.md) | Ubuntu | 90 min |
| 27 | [GitHub y pull requests](clase-27-github-y-pull-requests.md) | Ubuntu + GitHub | 75 min |
| | **E. Proyectos y examen** | | |
| 28 | [P1 — Runbook de incidentes](clase-28-p1-incidentes.md) | VM | 3–4 sesiones |
| 29 | [P2 — Servidor reproducible con cloud-init](clase-29-p2-cloud-init.md) | VM | 3–4 sesiones |
| 30 | [Examen de la fase 1](clase-30-examen.md) | sin apuntes | 2 h |

**En paralelo desde la clase 05:** [Bandit](bandit.md), un juego de seguridad por SSH. 20–30 minutos los días que te sobre tiempo.

## Cómo encajan los bloques

```
A. Linux en tu PC ──► B. Un servidor de verdad ──► C. Redes entre servidores ──► D. Git ──► E. Proyectos
   (comandos)            (administrar)                (conectar)                    (colaborar)  (demostrarlo)
```

Cada bloque usa el anterior. Las redes no se entienden sin procesos y puertos, y el proyecto P2 junta todo lo de la fase.
