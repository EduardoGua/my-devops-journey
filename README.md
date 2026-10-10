# my-devops-journey

My self-taught path to a **Cloud & DevOps** role on **AWS**, documented in public.
Every concept is practised hands-on, broken on purpose, fixed and written up.

> 🇪🇸 El curso está en español. Empieza por [`COMO-ESTUDIAR.md`](COMO-ESTUDIAR.md) y [`PROGRESO.md`](PROGRESO.md).

## Roadmap

Ten phases, measured in hours of focused practice (about 7 hours a week).

| Phase | Topic | Status |
|-------|-------|--------|
| 1 | Linux and Bash scripting | 🟡 in progress |
| 2 | Git and GitHub | ⬜ |
| 3 | Networking for DevOps | ⬜ |
| 4 | Python for automation | ⬜ |
| 5 | Containers: Docker | ⬜ |
| 6 | AWS + Cloud Practitioner (CLF-C02) | ⬜ |
| 7 | CI/CD: GitHub Actions | ⬜ |
| 8 | Infrastructure as Code: Terraform | ⬜ |
| 9 | Kubernetes | ⬜ |
| 10 | Observability: Prometheus and Grafana | ⬜ |

Full roadmap with exit criteria: [`PLAN.md`](PLAN.md).

## Flagship project: Vigía

**Vigía** is a small uptime monitor that grows with every phase: a Bash script with cron (v0), then Python with tests, Docker, a deployment on AWS, a CI/CD pipeline, Terraform, Kubernetes and, finally, metrics and alerts (v7). It lives in its own repository (published from v0.1).

## Course labs

| Lab | What it shows | Status |
|-----|---------------|--------|
| [P1 — Incident runbook](projects/) | Diagnosing 7 production-style Linux/network incidents, documented as an on-call runbook | ⬜ |
| [P2 — Reproducible hardened server](projects/) | One cloud-init file builds a hardened nginx server; automated external verification | ⬜ |

## Repository layout

```
PLAN.md            roadmap: phases, Vigía versions, exit criteria
COMO-ESTUDIAR.md   study method
PROGRESO.md        progress tracker and log
fase-1/ … fase-3/  lessons (Spanish); later phases are written as I reach them
notas/             my notes and answers for each lesson
labs/              practice output
projects/          course labs P1 and P2 (English)
recursos/          lesson resources (sample logs, lab scripts)
```

## Stack

Ubuntu · Bash · Git/GitHub · Python · Docker · AWS · GitHub Actions · Terraform · Kubernetes · Prometheus/Grafana
