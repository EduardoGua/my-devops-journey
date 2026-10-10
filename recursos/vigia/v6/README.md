# Pruebas de aceptación de Vigía v6

`verify.sh` comprueba tu Vigía v6 **desde fuera**, en tu cluster de kind, contra el contrato de las clases 114 y 115:
- **el repositorio:** los manifiestos de `k8s/` en Git, ningún Secret ni `.env` dentro, imágenes con etiqueta fija, y que el cluster coincide con Git (`kubectl diff` vacío);
- **lo que corre en el namespace `vigia`:**
  - la API (`deployment/api`) con al menos 2 réplicas listas, sondas readiness y liveness, `requests` y límite de memoria, sin root y sin token de ServiceAccount, con la configuración de un ConfigMap y la contraseña de un Secret;
  - el CronJob `checker`, igual de seguro, sin solaparse y con un Job bueno en la última media hora;
  - PostgreSQL (`statefulset/db`) con su PVC, y sin publicarse fuera del cluster;
  - al menos una actualización en el historial de `kubectl rollout`;
- **desde fuera:** `/health` y `/status` a través de tu Gateway (o tu Ingress);
- **que se cura sola:** borra un pod de la API y espera a que el Deployment se recupere;
- **que los datos sobreviven:** borra el pod `db-0` y comprueba que las filas de `checks` siguen ahí, y que la API vuelve a servir `/status`.

No contiene la solución. Si termina con `Fallos: 0`, tu Vigía cumple el contrato.

## Cómo se ejecuta

Desde la raíz de tu repo de Vigía, con el cluster en marcha y el contexto `kind-lab`:

```bash
cd ~/vigia
bash ~/my-devops-journey/recursos/vigia/v6/verify.sh
```

Necesita kubectl, curl, git y python3, y cloud-provider-kind en marcha para la entrada desde fuera. Tarda unos 2–3 minutos. Se niega a ejecutarse si tu contexto no es de kind: borra pods, y no debe hacerlo en otro cluster.

Los nombres son parte del contrato: el namespace `vigia`, `deployment/api` con su `service/api`, `statefulset/db` con su `service/db` y `cronjob/checker`.
