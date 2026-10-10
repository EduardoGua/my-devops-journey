# Fase 5 — Docker

**Horas (Ruta 2.0):** 30–40 h.
**Al terminar:** entiendes qué es un contenedor por dentro, escribes Dockerfiles pequeños y seguros, conectas contenedores con redes y volúmenes, describes una aplicación entera con Docker Compose, diagnosticas un contenedor averiado y publicas tus imágenes en un registro. Vigía v2 se levanta con un solo comando: API, chequeo y PostgreSQL.

Un contenedor empaqueta la aplicación con todo lo que necesita y corre igual en tu portátil, en la nube o en Kubernetes.

## Qué necesitas

Docker ya está en tu Ubuntu (fase 0) y tu usuario está en el grupo `docker`. En la clase 56 instalarás los dos complementos que faltan: `sudo apt install docker-compose-v2 docker-buildx`. En la 64, una cuenta gratis de Docker Hub.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Contenedores** | | |
| 56 | [Qué es un contenedor de verdad](clase-56-que-es-un-contenedor.md) | Ubuntu | 75 min |
| 57 | [Imágenes y contenedores: run, ps, logs, exec, inspect](clase-57-imagenes-y-contenedores.md) | Ubuntu | 75 min |
| 58 | [Tu primer Dockerfile: capas, caché y .dockerignore](clase-58-primer-dockerfile.md) | Ubuntu | 90 min |
| 59 | [Imágenes pequeñas y seguras](clase-59-imagenes-seguras.md) | Ubuntu | 90 min |
| 60 | [Volúmenes y persistencia](clase-60-volumenes.md) | Ubuntu | 75 min |
| 61 | [Redes de Docker](clase-61-redes.md) | Ubuntu | 75 min |
| 62 | [Docker Compose](clase-62-compose.md) | Ubuntu | 90 min |
| 63 | [Depurar contenedores](clase-63-depurar.md) | Ubuntu | 90 min |
| 64 | [Registros: publicar en Docker Hub](clase-64-registros.md) | Ubuntu + Docker Hub | 75 min |
| | **B. Proyecto** | | |
| 65 | [Vigía v2 (I): PostgreSQL y el Dockerfile](clase-65-vigia-v2-imagen.md) | Ubuntu + GitHub | 2 bloques largos |
| 66 | [Vigía v2 (II): Compose con API, chequeo y base de datos](clase-66-vigia-v2-compose.md) | Ubuntu + GitHub + Docker Hub | 2 bloques largos |

Las pruebas de aceptación de Vigía v2 están en [`recursos/vigia/v2/`](../recursos/vigia/v2/README.md); las averías de la clase 63, en [`recursos/clase-63/`](../recursos/clase-63/averias.sh).

## Cómo encajan

```
qué es (56) ─► usarlo (57) ─► construirlo (58-59) ─► datos y red (60-61) ─► todo junto (62) ─► repararlo (63) ─► publicarlo (64)
                                                                                                                      │
                                                    Vigía v2: imagen + PostgreSQL (65) ─► Compose + Docker Hub (66) ◄─┘
```

Todo lo de las fases anteriores reaparece aquí: procesos y señales (clase 11), permisos (06), puertos y `0.0.0.0` (29), DNS (31), firewall (33) y variables de entorno (07 y 50).

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Explicas la diferencia entre imagen, contenedor y volumen (clases 56, 57 y 60)
- Escribes un Dockerfile multi-stage que corre como usuario no root (clase 59)
- Levantas Vigía con `docker compose up` desde un clon limpio del repo (clase 66)
- Encuentras con `docker logs` y `docker inspect` por qué un contenedor se reinicia en bucle (clase 63)

## Datos que caducan

Antes de empezar la fase, pídeme `revisa la fase 5`.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| Docker de Ubuntu 26.04 | `docker.io` 29.1.3 · `docker-compose-v2` 2.40.3 · `docker-buildx` 0.30.1 | 2026-10-09 | `apt-cache policy` |
| Imágenes base | `python:3.14-slim` (Debian 13), `postgres:18` (18.6), `nginx:1.29`, `alpine:3.22` | 2026-10-09 | hub.docker.com |
| PostgreSQL 18: dónde va el volumen | `/var/lib/postgresql` (ya no `/var/lib/postgresql/data`) | 2026-10-09 | página de la imagen `postgres` en Docker Hub |
| psycopg | 3.3.6 (`psycopg[binary]`) | 2026-10-09 | pypi.org/project/psycopg |
| Trivy | 0.75.0 (no uses la 0.69.4: CVE-2026-33634) | 2026-10-09 | github.com/aquasecurity/trivy/releases |
| Límites de descarga de Docker Hub | 100 cada 6 h sin cuenta · 200 cada 6 h con cuenta gratis | 2026-10-09 | docs.docker.com/docker-hub/usage |
| Tokens de Docker Hub | *Account settings → Personal access tokens*; 4 niveles de permiso | 2026-10-09 | docs.docker.com/security/access-tokens |

## Recursos de apoyo

Las clases son el recurso principal. Para repasar o ir más allá:
- [*Get started*](https://docs.docker.com/get-started/) de Docker, la documentación oficial: conceptos, imágenes, multi-stage y aplicaciones de varios contenedores.
- Pelado Nerd (YouTube, en español): Docker y Kubernetes explicados con ejemplos.

## Siguiente fase

[Fase 6 — AWS y Cloud Practitioner](../fase-6/README.md)
