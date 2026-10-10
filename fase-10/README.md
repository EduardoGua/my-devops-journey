# Fase 10 — Observabilidad

**Horas (Ruta 2.0):** 25–35 h.
**Al terminar:**
- sabes qué pregunta responde cada señal (métricas, logs y trazas) y la usas para responderla;
- instrumentas una aplicación de Python con `/metrics`, la recoge Prometheus y la consultas con PromQL;
- escribes alertas que saltan por lo que notan los usuarios, las pruebas antes de confiar en ellas y llegan a alguien;
- dibujas dashboards en Grafana que viven en Git;
- defines un SLO y sabes cuánto tiempo caído permite al mes;
- escribes logs que se pueden consultar y un postmortem sin culpables;
- Vigía v7 avisa cuando un sitio lleva más de 5 minutos caído, y cierras la ruta defendiéndolo en 10 minutos.

En producción no basta con que algo funcione: hay que saber cuándo deja de funcionar, y por qué, antes que los usuarios.

## Qué necesitas

- Docker con Compose (fase 5) y tu Vigía en Compose (v2, que ya llevas al día hasta la v6).
- Unos **1,5 GB de RAM libres** para Prometheus, Alertmanager y Grafana. Apaga el cluster de kind mientras tanto: `docker stop lab-control-plane cloud-provider-kind`.
- Unos **2,5 GB de disco** para las imágenes: la de Grafana, sola, ocupa casi 2 GB.
- Tu cuenta de AWS solo para la parte opcional de la clase 123, dentro de la capa gratuita.

## Las reglas de la fase

1. **Todo como código.** `prometheus.yml`, las reglas, `alertmanager.yml`, las fuentes de datos y los dashboards de Grafana viven en archivos, en Git. Lo que se hace con clics en una interfaz se pierde con el contenedor.
2. **Cada alerta tiene una prueba y una acción.** Si no sabes qué harías cuando salta, no es una alerta: es ruido. Si no la has visto saltar, no sabes si salta.
3. **Se alerta por síntomas, no por causas.** "Los usuarios no pueden comprar" despierta a alguien; "la CPU está al 80 %", casi nunca.
4. **Ningún secreto en las configuraciones.** La contraseña de Grafana va en `.env`; los tokens de los canales de aviso, en archivos fuera de Git.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Medir** | | |
| 116 | [Métricas, logs y trazas](clase-116-metricas-logs-y-trazas.md) | Ubuntu | 75 min |
| 117 | [El endpoint `/metrics`](clase-117-endpoint-metrics.md) | Ubuntu | 90 min |
| 118 | [Prometheus y PromQL](clase-118-prometheus-y-promql.md) | Ubuntu | 90 min |
| | **B. Avisar y entender** | | |
| 119 | [Reglas de alerta y Alertmanager](clase-119-alertas-y-alertmanager.md) | Ubuntu | 90 min |
| 120 | [Grafana: dashboards como código](clase-120-grafana.md) | Ubuntu | 90 min |
| 121 | [SLI, SLO, SLA y presupuesto de errores](clase-121-slo.md) | Ubuntu | 75 min |
| 122 | [Logs estructurados y postmortems](clase-122-logs-y-postmortems.md) | Ubuntu | 90 min |
| 123 | [CloudWatch, la alternativa gestionada](clase-123-cloudwatch.md) | Ubuntu (+ AWS, opcional) | 75 min |
| | **C. Proyecto y cierre de la ruta** | | |
| 124 | [Vigía v7: métricas, alerta y SLO](clase-124-vigia-v7.md) | Ubuntu + GitHub | 2 bloques largos |
| 125 | [Fin de la ruta: desde cero, la defensa y el examen final](clase-125-fin-de-la-ruta.md) | Ubuntu + GitHub | 3 h el examen + 2 sesiones |

Las pruebas de aceptación de Vigía v7 están en [`recursos/vigia/v7/`](../recursos/vigia/v7/README.md); las respuestas del examen final, en [`examen-respuestas.md`](examen-respuestas.md).

## Cómo encajan

```
qué medir (116) ─► exponer /metrics (117) ─► recoger y consultar (118) ─► avisar (119) ─► ver (120)
                                                                                           │
             CloudWatch (123) ◄── logs y postmortems (122) ◄── SLO y presupuesto (121) ◄────┘
                   │
                   └─► Vigía v7 (124) ─► fin de la ruta: desde cero, defensa y examen (125)
```

Las clases 117 a 121 usan una tienda de mentira que escribes tú, a propósito lenta y con fallos, para tener algo que medir. La 124 aplica lo mismo a Vigía.

Reaparecen:
- los códigos HTTP (clase 32) y los de salida (54);
- FastAPI (53) y Compose (62);
- los logs de CloudWatch (76);
- las sondas (107) y los CronJobs (108);
- las averías de las clases 63 y 112, ahora como material de postmortem.

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Vigía expone `/metrics` y Prometheus lo recoge (clases 117, 118 y 124)
- Un dashboard con disponibilidad y latencia por sitio (clases 120 y 124)
- Una alerta que salta cuando un sitio cae más de 5 minutos, y probada (clases 119 y 124)
- Un SLO para Vigía y cuánto tiempo caído permite al mes (clases 121 y 124)
- Y el cierre de la ruta: Vigía se levanta desde cero con un comando o un pipeline, se destruye igual, y lo explicas y defiendes en 10 minutos (clase 125)

## Datos que caducan

Antes de empezar la fase, pídeme `revisa la fase 10`.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| Prometheus | 3.15.0 (2026-09-24); la rama 3.13 es la de soporte largo (LTS) | 2026-10-10 | github.com/prometheus/prometheus/releases |
| Alertmanager | 0.34.1 (2026-09-17) | 2026-10-10 | github.com/prometheus/alertmanager/releases |
| Grafana | 13.2.3 (2026-09-29), imagen `grafana/grafana`, casi 2 GB en disco | 2026-10-10 | github.com/grafana/grafana/releases |
| Cliente de Python | `prometheus-client` 0.26.0 (2026-07-24), compatible con Python 3.14 | 2026-10-10 | pypi.org/project/prometheus-client |
| CloudWatch, capa gratuita | al mes: 10 métricas propias, 10 alarmas, 3 dashboards y 5 GB de logs | 2026-10-10 | aws.amazon.com/cloudwatch/pricing |
| CloudWatch, precios | métrica propia 0,30 USD/mes · alarma 0,10 USD/mes · ingesta de logs 0,50 USD/GB | 2026-10-10 | aws.amazon.com/cloudwatch/pricing |

## Recursos de apoyo

Las clases son el recurso principal. Para ir más allá:
- La documentación de Prometheus: *Getting started*, *Querying basics* y *Alerting rules* (prometheus.io/docs).
- Los libros de SRE de Google, gratis en sre.google/books: los capítulos *Service Level Objectives*, *Monitoring Distributed Systems* y *Postmortem Culture*.
- La documentación de Grafana sobre *provisioning* (grafana.com/docs).

## Siguiente

Es la última fase de la ruta: la clase 125 te dice qué viene después.
