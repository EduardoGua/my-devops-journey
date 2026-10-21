# my-devops-journey

My self-taught path to a **Cloud & DevOps** role on **AWS**, documented in public.
Every concept is practised hands-on, broken on purpose, fixed and written up.

> 🇪🇸 El curso está en español. Empieza por [`COMO-ESTUDIAR.md`](COMO-ESTUDIAR.md) y [`PROGRESO.md`](PROGRESO.md).

## Roadmap

Ten phases plus a NOC phase, measured in hours of focused practice (about 7 hours a week). The NOC phase prepares my first IT job as a NOC analyst while I continue towards Cloud & DevOps.

| Phase | Topic | Status |
|-------|-------|--------|
| 1 | Linux and Bash scripting | 🟡 in progress |
| 2 | Git and GitHub | ⬜ |
| 3 | Networking for DevOps | ⬜ |
| NOC | NOC operations: Cisco CCST Networking, Zabbix monitoring, ITIL basics | ⬜ |
| 4 | Python for automation | ⬜ |
| 5 | Containers: Docker | ⬜ |
| 6 | AWS + Cloud Practitioner (CLF-C02) | ⬜ |
| 7 | CI/CD: GitHub Actions | ⬜ |
| 8 | Infrastructure as Code: Terraform | ⬜ |
| 9 | Kubernetes | ⬜ |
| 10 | Observability: Prometheus and Grafana | ⬜ |

Full roadmap with exit criteria: [`PLAN.md`](PLAN.md).

## Flagship project: Vigía

**Vigía** is a small uptime monitor that grows with every phase: a Bash script with cron (v0), then Python with tests, Docker Compose with PostgreSQL, a deployment on AWS, a CI/CD pipeline with OIDC, Terraform, Kubernetes and, finally, Prometheus metrics, tested alerts and an SLO (v7). It lives in its own repository (published from v0.1); every version has black-box acceptance tests in [`recursos/vigia/`](recursos/vigia/).

## Course labs

| Lab | What it shows | Status |
|-----|---------------|--------|
| [P1 — Incident runbook](projects/) | Diagnosing 7 production-style Linux/network incidents, documented as an on-call runbook | ⬜ |
| [P2 — Reproducible hardened server](projects/) | One cloud-init file builds a hardened nginx server; automated external verification | ⬜ |
| [P3 — NOC lab](projects/) | A Packet Tracer network with VLANs and DHCP, Zabbix monitoring with a tested alert, and a simulated incident from alert to ticket closure | ⬜ |

## Repository layout

```
PLAN.md            roadmap: phases, Vigía versions, exit criteria
CARRERA.md         career strategy (optional): work experience, education, English, networking
COMO-ESTUDIAR.md   study method
PROGRESO.md        progress tracker and log
fase-1/ … fase-10/ 125 lessons (Spanish), each phase with its exit criteria
fase-noc/          NOC phase (Spanish): CCST, Zabbix, ITIL and the NOC job search
notas/             my notes and answers for each lesson
labs/              practice output
projects/          course labs P1, P2 and P3 (English)
recursos/          lesson resources (sample logs, lab scripts) and Vigía acceptance tests
```

## Stack

Ubuntu · Bash · Git/GitHub · Networking (Cisco Packet Tracer) · Zabbix · Python · Docker · AWS · GitHub Actions · Terraform · Kubernetes · Prometheus/Grafana
