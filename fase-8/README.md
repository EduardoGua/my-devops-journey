# Fase 8 — Terraform

**Horas (Ruta 2.0):** 35–45 h.
**Al terminar:** lo que en la fase 6 creaste a mano, comando a comando, vive en archivos versionados, revisables y repetibles:
- toda la infraestructura de Vigía se crea con `terraform apply` y se borra con `terraform destroy`;
- su estado está en S3, con versionado y bloqueo;
- la red es un módulo tuyo;
- cada PR que cambia la infraestructura muestra su `plan` en el pipeline antes de que nadie lo apruebe.

La **infraestructura como código** es lo que separa "sé hacerlo" de "lo puede repetir cualquiera, igual, cuantas veces haga falta". Hoy la piden casi todas las ofertas de DevOps y cloud, y Terraform es la herramienta más extendida.

## Qué necesitas

- Tu cuenta de AWS (fase 6) con `aws login`, y lo que dejaste vivo: el repositorio de ECR, el bucket de informes, los grupos de logs, el proveedor OIDC y el rol `vigia-github` (fase 7).
- En la clase 92 instalas **Terraform** desde el repositorio oficial de HashiCorp.
- El pipeline de Vigía v4 (fase 7), al que la clase 100 le añade el `plan`.

## Las reglas de la fase

1. **El estado no va a Git, nunca.** En el repositorio del curso, `*.tfstate` y `.terraform/` ya están en `.gitignore`; en el de Vigía los añades en la clase 97. El archivo `.terraform.lock.hcl`, en cambio, **sí** se sube.
2. **Siempre `plan` antes de `apply`,** y se lee entero. Una línea `-/+` significa que algo se destruye y se vuelve a crear.
3. **Lo que gestiona Terraform no se toca a mano.** Si hace falta, se cambia el código y se aplica (clase 99).
4. **Cada laboratorio termina con `terraform destroy`.** Los recursos de las clases son pequeños, pero la costumbre es la de siempre.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Terraform desde cero** | | |
| 92 | [Instalar Terraform y tu primer recurso](clase-92-primer-recurso.md) | Ubuntu + AWS | 75 min |
| 93 | [Providers, versiones, resources y data](clase-93-providers-y-data.md) | Ubuntu + AWS | 90 min |
| 94 | [Variables, outputs, locals y tipos](clase-94-variables-y-tipos.md) | Ubuntu + AWS | 90 min |
| 95 | [Dependencias y ciclo de vida](clase-95-dependencias-y-ciclo-de-vida.md) | Ubuntu + AWS | 90 min |
| 96 | [El estado: backend S3 con bloqueo](clase-96-estado.md) | Ubuntu + AWS | 90 min |
| | **B. Vigía en código** | | |
| 97 | [La infraestructura de Vigía en código](clase-97-vigia-en-codigo.md) | Ubuntu + AWS | 2 bloques |
| 98 | [Módulos](clase-98-modulos.md) | Ubuntu + AWS | 90 min |
| 99 | [Secretos, import y drift](clase-99-secretos-import-drift.md) | Ubuntu + AWS | 90 min |
| 100 | [Terraform en CI](clase-100-terraform-en-ci.md) | GitHub + AWS | 90 min |
| | **C. Proyecto** | | |
| 101 | [Vigía v5: toda la infraestructura en Terraform](clase-101-vigia-v5.md) | Ubuntu + AWS + GitHub | 2 bloques largos |

Las pruebas de aceptación de Vigía v5 están en [`recursos/vigia/v5/`](../recursos/vigia/v5/README.md).

## Cómo encajan

```
instalar y primer recurso (92) ─► providers y data (93) ─► variables y tipos (94) ─► dependencias (95)
                                                                                         │
       Terraform en CI (100) ◄── drift e import (99) ◄── módulos (98) ◄── Vigía en código (97) ◄── estado en S3 (96)
              │
              └─► Vigía v5: destruir y recrear desde cero (101)
```

Todo lo que creaste en la fase 6 reaparece como un bloque de código:
- la VPC de la clase 71;
- los security groups de la 73;
- el rol de la 70;
- el bucket de la 74;
- los logs de la 76;
- la EC2 con cloud-init de la 78.

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Recreas desde cero la infraestructura de Vigía con `terraform apply` y la borras con `terraform destroy` (clases 97 y 101)
- El estado está en S3, con versionado y `use_lockfile = true` (clase 96)
- Tienes al menos un módulo propio con variables y outputs (clase 98)
- Explicas qué pasa si alguien cambia a mano un recurso que maneja Terraform (clase 99)

## Datos que caducan

Antes de empezar la fase, pídeme `revisa la fase 8`.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| Terraform | 1.16.5 (2026-10-02), del repositorio apt de HashiCorp, que ya tiene Ubuntu 26.04 (`resolute`) | 2026-10-10 | releases.hashicorp.com, apt.releases.hashicorp.com |
| Provider de AWS | `hashicorp/aws` 6.68.0 (2026-10-07) | 2026-10-10 | registry.terraform.io |
| Bloqueo del estado en S3 | `use_lockfile = true`; el bloqueo con DynamoDB está **obsoleto** y desaparecerá | 2026-10-10 | developer.hashicorp.com/terraform/language/backend/s3 |
| OpenTofu | 1.13.1 (2026-10-01), la bifurcación libre de Terraform, compatible con casi todo el curso | 2026-10-10 | github.com/opentofu/opentofu |
| Terraform Associate (004) | prueba Terraform 1.12; examen de 1 hora, tipo test; incluye HCP Terraform | 2026-10-10 | developer.hashicorp.com/certifications |
| Imagen para pruebas | `hashicorp/terraform:1.16.5` | 2026-10-10 | hub.docker.com |

## Recursos de apoyo

Las clases son el recurso principal. Para ir más allá:
- Los tutoriales *Get Started – AWS* de HashiCorp (developer.hashicorp.com/terraform/tutorials).
- La documentación del provider de AWS en el Registry: cada recurso tiene ejemplos y la lista de argumentos. La consultarás en todas las clases.
- Los objetivos del **Terraform Associate (004)**, como lista de temas (apéndice de la clase 101).

## Siguiente fase

[Fase 9 — Kubernetes](../fase-9/README.md)
