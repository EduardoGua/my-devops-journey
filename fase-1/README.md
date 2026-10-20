# Fase 1 — Linux y Bash

**Horas (Ruta 2.0):** 35–45 h · unas 5–7 semanas a 7 h por semana.
**Al terminar:** administras un servidor Linux por SSH, automatizas tareas con scripts de Bash que se ejecutan solos con cron, y Vigía v0 vigila tus sitios web desde tu equipo.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Linux en tu equipo** | | |
| 01 | [La terminal, el shell y el kernel](clase-01-terminal-shell-kernel.md) | Ubuntu | 60 min |
| 02 | [El sistema de archivos y las rutas](clase-02-sistema-de-archivos.md) | Ubuntu | 60 min |
| 03 | [Archivos y directorios](clase-03-archivos-y-directorios.md) | Ubuntu | 60 min |
| 04 | [Redirecciones, pipes y códigos de salida](clase-04-redirecciones-y-pipes.md) | Ubuntu | 90 min |
| 05 | [Buscar y filtrar: find, grep y compañía](clase-05-buscar-y-filtrar.md) | Ubuntu | 75 min |
| 06 | [Permisos: usuarios, grupos y rwx](clase-06-permisos.md) | Ubuntu | 75 min |
| 07 | [Variables de entorno, PATH y el shell](clase-07-entorno-y-path.md) | Ubuntu | 60 min |
| ↺ | [Repaso del bloque A](repaso-bloque-a.md) | notas | 45 min |
| | **B. Administrar un servidor** | | |
| 08 | [Tu primer servidor (Multipass)](clase-08-primer-servidor.md) | VM | 60 min |
| 09 | [Usuarios, grupos y sudo](clase-09-usuarios-y-sudo.md) | VM | 75 min |
| 10 | [Paquetes con apt](clase-10-paquetes-apt.md) | VM | 60 min |
| 11 | [Procesos y señales](clase-11-procesos-y-senales.md) | VM | 75 min |
| 12 | [systemd: servicios](clase-12-systemd.md) | VM | 90 min |
| 13 | [Logs y journalctl](clase-13-logs.md) | VM | 75 min |
| 14 | [Recursos: CPU, memoria y disco](clase-14-recursos.md) | VM | 120 min |
| 15 | [SSH a fondo](clase-15-ssh.md) | Ubuntu + VM | 90 min |
| ↺ | [Repaso del bloque B](repaso-bloque-b.md) | notas | 50 min |
| | **C. Scripting con Bash** | | |
| 16 | [Tu primer script: variables, argumentos y comillas](clase-16-primer-script.md) | Ubuntu | 75 min |
| 17 | [Decisiones: if, test y case](clase-17-decisiones.md) | Ubuntu | 75 min |
| 18 | [Bucles: for, while y leer archivos](clase-18-bucles.md) | Ubuntu | 75 min |
| 19 | [Funciones y scripts robustos: set -euo pipefail, trap y logs](clase-19-scripts-robustos.md) | Ubuntu | 90 min |
| 20 | [Tareas programadas: cron y un backup con rotación](clase-20-cron-y-backups.md) | Ubuntu | 90 min |
| ↺ | [Repaso del bloque C](repaso-bloque-c.md) | notas + Ubuntu | 50 min |
| | **D. Proyecto** | | |
| 21 | [Vigía v0: Bash + cron](clase-21-vigia-v0.md) | Ubuntu | 2 bloques largos |

**Al terminar la fase, como prueba:** [Bandit](bandit.md), un juego de seguridad por SSH en el que usas todo lo de las 21 clases.

Las clases de 90 o 120 minutos y las de VM rinden más en tu bloque largo de la semana. Las demás caben en dos sesiones cortas (ver [`COMO-ESTUDIAR.md`](../COMO-ESTUDIAR.md)).

## Cómo encajan los bloques

```
A. Linux en tu PC ──► B. Un servidor de verdad ──► C. Automatizar con Bash ──► D. Vigía v0
   (comandos)            (administrar)                (scripts y cron)           (tu proyecto)
```

Cada bloque usa el anterior: los scripts automatizan lo que ya sabes hacer a mano, y Vigía junta todo el bloque C en tu primera pieza de portafolio.

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), y solo cuando los cumples **sin mirar**:

- Escribes sin mirar un script que reciba una carpeta como argumento, la comprima con la fecha en el nombre y borre las copias de más de 7 días (clase 20)
- Explicas qué hace `set -euo pipefail` y qué guarda `$?` (clases 04 y 19)
- Encuentras con `journalctl` por qué no arrancó un servicio (clases 12 y 13)
- Entras por SSH con llave, sin contraseña, a otra máquina o VM (clase 15)
- Vigía v0 corre con cron y deja log (clase 21)

Y, como en todo el curso: clases cerradas y ninguna deuda abierta.

## Siguiente fase

[Fase 2 — Git y GitHub](../fase-2/README.md)
