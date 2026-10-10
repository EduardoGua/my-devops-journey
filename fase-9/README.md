# Fase 9 — Kubernetes

**Horas (Ruta 2.0):** 55–75 h.
**Al terminar:**
- describes una aplicación en archivos YAML y Kubernetes la mantiene viva: la reinicia, la escala y la actualiza sin cortar el servicio;
- la expones dentro y fuera del cluster, le das configuración, secretos y disco;
- diagnosticas un pod roto leyendo lo que el cluster ya te está diciendo;
- Vigía v6 corre en tu cluster de kind: la API con dos réplicas, PostgreSQL con su volumen y el chequeo como CronJob, con actualización y vuelta atrás probadas.

Kubernetes orquesta contenedores en varios servidores. Es lo más pesado de la ruta, y por eso llega después de Docker, AWS y CI/CD: aquí reaparece casi todo lo anterior con otra interfaz.

## Qué necesitas

- Docker (fase 5) y unos **2 GB de RAM libres**: el cluster con Vigía usa alrededor de 1 GB. Si el portátil va justo, cierra pestañas del navegador antes de empezar.
- Nada de AWS: la fase entera corre en tu portátil y cuesta 0 USD. EKS, el Kubernetes de AWS, se estudia en concepto en la clase 115.
- Las herramientas se instalan por el camino:
  - **kubectl** y **kind** en la clase 102, en `~/.local/bin`, sin `sudo`;
  - **cloud-provider-kind** en la 105, como contenedor;
  - **metrics-server** en la 107, dentro del cluster;
  - **Helm** en la 113.

## Las reglas de la fase

1. **Lo que se queda sale de un archivo.** `kubectl run`, `create`, `scale` y `edit` sirven para explorar. Lo que debe seguir ahí mañana vive en YAML, en Git, y se aplica con `kubectl apply -f`. Antes de aplicar, `kubectl diff`: es el `terraform plan` de Kubernetes.
2. **Ningún Secret en Git**, ni en YAML ni en base64: base64 no cifra nada (clase 106).
3. **Antes de cambiar nada, `describe` y `logs`.** Los eventos de un objeto casi siempre dicen qué le pasa (clase 112).
4. **El cluster se apaga cuando no estudias.** Con `docker stop lab-control-plane cloud-provider-kind` recuperas cerca de 1 GB de RAM. Al volver, `docker start lab-control-plane cloud-provider-kind`, y dale un minuto: los pods se reinician y los balanceadores pueden cambiar de IP. Lee siempre la IP con `kubectl get`, nunca la copies de una sesión anterior.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Kubernetes desde cero** | | |
| 102 | [Por qué orquestar: arquitectura, kind y kubectl](clase-102-por-que-orquestar.md) | Ubuntu | 90 min |
| 103 | [Pods, YAML y etiquetas](clase-103-pods-yaml-y-etiquetas.md) | Ubuntu | 90 min |
| 104 | [Deployments: escalar, actualizar y volver atrás](clase-104-deployments.md) | Ubuntu | 90 min |
| 105 | [Services y DNS del cluster](clase-105-services-y-dns.md) | Ubuntu | 90 min |
| 106 | [ConfigMaps y Secrets](clase-106-configmaps-y-secrets.md) | Ubuntu | 75 min |
| 107 | [Sondas, requests y limits](clase-107-sondas-requests-y-limits.md) | Ubuntu | 90 min |
| 108 | [Jobs y CronJobs](clase-108-jobs-y-cronjobs.md) | Ubuntu | 75 min |
| | **B. Kubernetes para operar** | | |
| 109 | [Volúmenes persistentes y StatefulSets](clase-109-volumenes-y-statefulsets.md) | Ubuntu | 90 min |
| 110 | [Namespaces y RBAC](clase-110-namespaces-y-rbac.md) | Ubuntu | 90 min |
| 111 | [Ingress y Gateway API](clase-111-ingress-y-gateway-api.md) | Ubuntu | 90 min |
| 112 | [Depurar: CrashLoopBackOff, ImagePullBackOff y Pending](clase-112-depurar.md) | Ubuntu | 2 bloques |
| 113 | [Helm](clase-113-helm.md) | Ubuntu | 90 min |
| | **C. Proyecto** | | |
| 114 | [Vigía v6 (I): API y base de datos en kind](clase-114-vigia-v6-api-y-base-de-datos.md) | Ubuntu + GitHub | 2 bloques largos |
| 115 | [Vigía v6 (II): CronJob, rollout y qué cambia en EKS](clase-115-vigia-v6-cronjob-y-eks.md) | Ubuntu + GitHub | 2 bloques largos |

Las pruebas de aceptación de Vigía v6 están en [`recursos/vigia/v6/`](../recursos/vigia/v6/README.md); las averías de la clase 112, en [`recursos/clase-112/`](../recursos/clase-112/averias.sh).

## Cómo encajan

```
por qué y kind (102) ─► pods (103) ─► deployments (104) ─► services (105) ─► config y secretos (106) ─► sondas y recursos (107)
                                                                                                                │
        helm (113) ◄── depurar (112) ◄── ingress y gateway (111) ◄── namespaces y rbac (110) ◄── volúmenes (109) ◄── jobs (108)
           │
           └─► Vigía v6: API y PostgreSQL en kind (114) ─► CronJob, rollout y EKS (115)
```

Casi todo lo anterior reaparece con otro nombre:
- los contenedores, sus códigos de salida y la depuración de la fase 5 son ahora pods;
- `cron` (clase 20) es un CronJob;
- el DNS (31) y el balanceo (77) son los Services;
- el mínimo privilegio de IAM (69 y 70) es RBAC;
- las estrategias de despliegue (89) son los *rollouts*;
- el modelo declarativo de Terraform (92) es el de `kubectl apply`, y `kubectl diff` hace de `plan`.

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Vigía en kind con Deployment, Service, ConfigMap, Secret y un CronJob (clases 114 y 115)
- Una actualización y un *rollback* con `kubectl rollout` (clases 104 y 115)
- Diagnosticas un pod en CrashLoopBackOff y otro en ImagePullBackOff con `describe` y `logs` (clase 112)
- Explicas la diferencia entre una sonda *liveness* y una *readiness* (clase 107)

## Datos que caducan

Antes de empezar la fase, pídeme `revisa la fase 9`.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| kind | v0.33.0 (2026-08-26); nodo por defecto `kindest/node:v1.37.0` | 2026-10-10 | github.com/kubernetes-sigs/kind/releases |
| Kubernetes y kubectl | 1.37 (2026-08-26) · kubectl v1.37.1, que admite una versión menor de diferencia con el cluster | 2026-10-10 | kubernetes.io/releases, kubernetes.io/docs/tasks/tools |
| cloud-provider-kind | v0.12.0: LoadBalancer, Ingress (clase `cloud-provider-kind`) y Gateway API (instala sus CRD, v1.6.1 *standard*); no implementa el filtro `URLRewrite` | 2026-10-10 | github.com/kubernetes-sigs/cloud-provider-kind |
| ingress-nginx | **retirado**: su última versión fue la controller-v1.15.1 (2026-03-19) y ya no recibe parches | 2026-10-10 | github.com/kubernetes/ingress-nginx |
| Gateway API | v1.6.3 | 2026-10-10 | gateway-api.sigs.k8s.io |
| metrics-server | v0.9.0; en kind necesita `--kubelet-insecure-tls` | 2026-10-10 | github.com/kubernetes-sigs/metrics-server |
| Helm | v4.3.0. Helm 4 usa *server-side apply* en las instalaciones nuevas; `--atomic` pasa a llamarse `--rollback-on-failure` | 2026-10-10 | helm.sh/docs |
| podinfo | 6.15.0: imagen `ghcr.io/stefanprodan/podinfo` y chart `oci://ghcr.io/stefanprodan/charts/podinfo` | 2026-10-10 | github.com/stefanprodan/podinfo |
| Bitnami | desde el 28 de agosto de 2025, su catálogo gratuito solo publica `latest` de unas pocas imágenes: muchos charts y tutoriales antiguos apuntan a imágenes que ya no existen | 2026-10-10 | github.com/bitnami/containers/issues/83267 |
| Amazon EKS | 0,10 USD/h por cluster en soporte estándar (14 meses por versión) y 0,60 USD/h en el extendido; versiones estándar 1.34–1.37; sin capa gratuita | 2026-10-10 | aws.amazon.com/eks/pricing, docs.aws.amazon.com/eks |

## Recursos de apoyo

Las clases son el recurso principal. Para repasar o ir más allá:
- *Learn Kubernetes Basics*, el tutorial oficial (kubernetes.io). Tiene versión en español, pero está marcada como desactualizada: sirve para el vocabulario; los comandos, de la inglesa.
- La documentación de kind (kind.sigs.k8s.io): *Quick Start*, *LoadBalancer* e *Ingress*.
- `kubectl explain <recurso>.<campo>`: la referencia de la API, en tu terminal. La usarás en cada clase.
- Pelado Nerd (YouTube, en español): Kubernetes explicado con ejemplos.

## Siguiente fase

[Fase 10 — Observabilidad](../fase-10/README.md)
