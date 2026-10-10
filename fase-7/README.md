# Fase 7 — CI/CD con GitHub Actions

**Horas (Ruta 2.0):** 25–35 h.
**Al terminar:** cada pull request de Vigía pasa solo el lint, las pruebas y un arranque del stack completo, y `main` está protegida: nada se une sin todo en verde. Al unir a `main`, el pipeline:
- construye la imagen y la publica en ECR;
- la despliega en tu EC2 con Session Manager;
- comprueba que responde y, si no, vuelve sola a la versión anterior.

Todo sin una sola llave de AWS en GitHub, gracias a **OIDC**. Y con eso llegas al **★ hito**: empiezas a postular.

Automatizar las pruebas y los despliegues es el centro del trabajo DevOps: cada cambio recorre el mismo camino, sin pasos manuales ni "en mi máquina funciona".

## Qué necesitas

- Tu cuenta de GitHub con `gh` (fase 2) y tu repositorio `vigia`, **público**: Actions es gratis en los repositorios públicos.
- Tu cuenta de AWS (fase 6) y la guía de despliegue de Vigía v3, para lanzar la instancia cuando la necesites.
- Docker, para pasar **actionlint**, el revisor de workflows, sin instalar nada: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12`.
- En la clase 82 crearás un repositorio de prácticas, `lab-actions`.

## Las reglas de la fase

1. **Ninguna llave de AWS en GitHub:** ni en secretos ni en variables ni en el código. GitHub entra en AWS con OIDC (clase 86).
2. **Las *actions* se fijan por su commit** (SHA de 40 caracteres), no por su etiqueta: las etiquetas se pueden mover (clase 59).
3. **Permisos mínimos:** cada workflow declara `permissions:` y solo los jobs que lo necesitan reciben más.
4. **La instancia de Vigía no vive entre sesiones.** El pipeline omite el despliegue si no la encuentra; lánzala con tu guía de la v3 cuando vayas a probar un despliegue y termínala al acabar.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Integración continua** | | |
| 82 | [CI/CD y tu primer workflow](clase-82-primer-workflow.md) | GitHub + Ubuntu | 90 min |
| 83 | [Lint y pruebas en cada PR](clase-83-lint-y-pruebas.md) | GitHub + Ubuntu | 90 min |
| 84 | [Comprobaciones obligatorias y leer un job fallido](clase-84-proteger-main.md) | GitHub | 75 min |
| 85 | [Secretos, variables y permisos](clase-85-secretos-y-permisos.md) | GitHub | 90 min |
| | **B. Entrega y despliegue continuos** | | |
| 86 | [OIDC: AWS sin llaves](clase-86-oidc.md) | GitHub + AWS | 90 min |
| 87 | [Construir y publicar la imagen en ECR](clase-87-publicar-en-ecr.md) | GitHub + AWS | 90 min |
| 88 | [Desplegar en EC2 con Session Manager](clase-88-desplegar-con-ssm.md) | GitHub + AWS | 2 bloques |
| 89 | [Estrategias de despliegue y pruebas de humo](clase-89-estrategias-de-despliegue.md) | GitHub + AWS | 90 min |
| | **C. Proyecto y hito** | | |
| 90 | [Vigía v4: el pipeline completo](clase-90-vigia-v4.md) | GitHub + AWS | 2 bloques largos |
| 91 | [★ El hito: examen de las fases 4 a 7 y empezar a postular](clase-91-hito.md) | — | 3 h + el CV |

Las pruebas de aceptación de Vigía v4 están en [`recursos/vigia/v4/`](../recursos/vigia/v4/README.md).

## Cómo encajan

```
primer workflow (82) ─► lint y pruebas (83) ─► main protegida (84) ─► secretos y permisos (85)
                                                                              │
     despliegue seguro (89) ◄── desplegar con SSM (88) ◄── imagen en ECR (87) ◄── OIDC (86)
              │
              └─► Vigía v4 (90) ─► ★ examen y empezar a postular (91)
```

Lo de las fases anteriores reaparece entero:
- **Git y los PR** (fase 2): el disparador de todo.
- **Las pruebas** (fase 4): lo que el pipeline ejecuta.
- **El Dockerfile y Compose** (fase 5): lo que construye.
- **Los roles, ECR y Session Manager** (fase 6): por donde despliega.

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Un PR con una prueba rota no se puede unir a `main` (clases 84 y 90)
- Al unir a `main`, la imagen se construye, se publica y se despliega sola (clases 87 a 90)
- Ninguna credencial de AWS en el repositorio ni en su historial (clases 85, 86 y 90)
- Explicas la diferencia entre integración, entrega y despliegue continuos (clase 82)

## Datos que caducan

Antes de empezar la fase, pídeme `revisa la fase 7`.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| `actions/checkout` | v7.0.1 · `3d3c42e5aac5ba805825da76410c181273ba90b1` (2026-07-20) | 2026-10-10 | github.com/actions/checkout |
| `actions/setup-python` | v7.0.0 · `5fda3b95a4ea91299a34e894583c3862153e4b97` (2026-07-20) | 2026-10-10 | github.com/actions/setup-python |
| `aws-actions/configure-aws-credentials` | v6.3.0 · `e1253824e5c10ff9df46874f81ed3ec929e19cfd` (2026-09-15) | 2026-10-10 | github.com/aws-actions |
| `aws-actions/amazon-ecr-login` | v2.1.7 · `03f1aad4c6c7ffd436567f42f9384779290529bd` (2026-08-19) | 2026-10-10 | github.com/aws-actions |
| `docker/setup-buildx-action` | v4.4.1 · `f87e5991a6d7451dcb8d9637bfbc97413f497069` (2026-09-16) | 2026-10-10 | github.com/docker |
| `docker/build-push-action` | v7.4.0 · `c3c9e263c25d99ce0380d002d59b67737d91b0dc` (2026-09-15) | 2026-10-10 | github.com/docker |
| actionlint | 1.7.12, en la imagen `rhysd/actionlint:1.7.12` (aún no reconoce la etiqueta `ubuntu-26.04`) | 2026-10-10 | github.com/rhysd/actionlint |
| Runners | `ubuntu-latest` = `ubuntu-24.04` (trae Docker, Compose, la AWS CLI, `jq` y `shellcheck`); `ubuntu-26.04` ya existe | 2026-10-10 | github.com/actions/runner-images |
| Precio de Actions | gratis en repositorios públicos con los runners estándar; en privados, 2000 min/mes en el plan Free | 2026-10-10 | docs.github.com (billing de Actions) |
| El `sub` del token OIDC | los repositorios creados después del 2026-07-15 usan `repo:DUEÑO@ID/REPO@ID:…`, con los ID numéricos | 2026-10-10 | docs.github.com (referencia de OIDC) |
| Condiciones de AWS para GitHub | además de `aud` y `sub`: `repository_id`, `repository_owner_id`, `ref`, `environment`, `actor_id`… | 2026-10-10 | docs.aws.amazon.com/IAM (claves de condición de OIDC) |

## Recursos de apoyo

Las clases son el recurso principal. Para ir más allá:
- La [documentación de GitHub Actions](https://docs.github.com/es/actions), en español: sintaxis de los workflows, contextos y seguridad.
- La guía de AWS *Configuring a role for GitHub OIDC identity provider*, en la documentación de IAM.

## Siguiente fase

[Fase 8 — Terraform](../fase-8/README.md)
