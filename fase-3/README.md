# Fase 3 — Redes para DevOps

**Horas (Ruta 2.0):** 30–40 h.
**Al terminar:** entiendes una red lo bastante para diseñar una VPC y diagnosticar por qué "no conecta". Vigía mide el DNS y el certificado de tus sitios, has resuelto siete incidentes a ciegas, construyes un servidor reproducible con un solo archivo y apruebas el examen de fundamentos de las fases 1 a 3.

Casi todo lo que falla en la nube es red: un puerto cerrado, un DNS mal configurado o una subred sin salida a internet. Por eso esta fase tiene nueve clases.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Redes** | | |
| 26 | [Cómo viaja una petición: el modelo de capas](clase-26-modelo-de-capas.md) | VM | 75 min |
| 27 | [Direcciones IP y CIDR](clase-27-ip-y-cidr.md) | papel + VM | 90 min |
| 28 | [Subnetting: diseñar redes como en una VPC](clase-28-subnetting.md) | papel | 90 min |
| 29 | [Puertos, TCP y UDP](clase-29-puertos-tcp-udp.md) | Ubuntu + VM | 90 min |
| 30 | [Rutas, gateway y NAT](clase-30-rutas-y-nat.md) | VM | 75 min |
| 31 | [DNS](clase-31-dns.md) | Ubuntu + VM | 90 min |
| 32 | [HTTP y HTTPS](clase-32-http-https.md) | Ubuntu + VM | 120 min |
| 33 | [Firewall](clase-33-firewall.md) | VM | 90 min |
| 34 | [Dos servidores: tu primera red](clase-34-dos-servidores.md) | 2 VMs | 120 min |
| | **B. Proyectos y examen** | | |
| 35 | [Vigía v0.2: DNS y certificados](clase-35-vigia-v0.2.md) | Ubuntu + GitHub | 1 bloque largo |
| 36 | [P1 — Runbook de incidentes](clase-36-p1-incidentes.md) | VM | 2 bloques largos |
| 37 | [P2 — Servidor reproducible con cloud-init](clase-37-p2-cloud-init.md) | VMs | 2 bloques largos |
| 38 | [Examen de fundamentos (fases 1 a 3)](clase-38-examen.md) | sin apuntes | 3 h |

**Vigía** es tu proyecto de portafolio. **P1** y **P2** son laboratorios integradores: juntan todo lo de las tres primeras fases y quedan publicados en tu repo del curso. El P1 te da, además, historias reales para las entrevistas.

## Cómo encajan

```
A. Redes: capas ─► direcciones ─► subredes ─► puertos ─► rutas ─► DNS ─► HTTP ─► firewall ─► dos servidores
                                                                                                │
B. Demostrarlo:              Vigía v0.2 ─► P1 (diagnosticar) ─► P2 (construir) ─► examen ◄──────┘
```

## Criterios de salida

Los cuatro primeros son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md):

- Explicas en voz alta, sin notas, qué pasa desde que escribes una URL hasta que carga la página (clases 26 a 32 y Vigía v0.2)
- Divides `10.0.0.0/16` en cuatro subredes y dices cuántas direcciones tiene cada una (clases 27 y 28)
- Diagnosticas con `dig`, `curl -v` y `ss` por qué un servicio no responde (clases 29, 31, 32 y 34)
- Explicas la diferencia entre IP privada y pública, y para qué sirve NAT (clases 27 y 30)
- P1 y P2 terminados, y el examen de fundamentos aprobado con un 80 % o más (clases 36 a 38)

## Siguiente fase

Con el examen aprobado, pídeme `escribe la fase 4`: Python para automatizar. Su temario está en [`PLAN.md`](../PLAN.md).
