# Projects

My portfolio project, **Vigía**, lives in its own repository. Each version adds a layer of the DevOps stack:

| Version | Phase | What it adds | Status |
|---------|-------|--------------|--------|
| v0 | 1 | Bash script + cron | — |
| v0.1 | 2 | GitHub, branches and pull requests | — |
| v0.2 | 3 | DNS lookup time and TLS certificate expiry | — |
| v1 | 4 | Python rewrite, SQLite, minimal JSON API, pytest | — |
| v2 | 5 | Multi-stage Dockerfile and Docker Compose with PostgreSQL | — |
| v3 | 6 | Deployment on AWS (EC2, IAM role, S3, CloudWatch) | — |
| v4 | 7 | CI/CD with GitHub Actions: OIDC, images in ECR, deployments over SSM with rollback | — |
| v5 | 8 | All infrastructure in Terraform: S3 state with locking, a network module, plan on every PR | — |
| v6 | 9 | Kubernetes (kind): Deployment, PostgreSQL StatefulSet, CronJob, Gateway API, rollouts | — |
| v7 | 10 | Prometheus metrics, tested alerts, Grafana dashboards as code and an SLO | — |

## Course labs

Integration labs that live in this repository. Each one has its own README in English.

| Lab | Phase | Folder | Status |
|-----|-------|--------|--------|
| P1 — Incident runbook | 3 | `p1-incident-runbook/` | — |
| P2 — Reproducible hardened server (cloud-init) | 3 | `p2-cloud-init-server/` | — |
| P3 — NOC lab: Packet Tracer network, Zabbix monitoring, simulated incident, troubleshooting sheet | NOC | `p3-noc-lab/` | — |
