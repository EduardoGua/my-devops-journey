# Pruebas de aceptación de Vigía v4

`verify.sh` comprueba el pipeline de Vigía desde tres sitios, sin cambiar nada:
- tu repositorio, con los workflows y el historial;
- GitHub, con la protección de `main` y las ejecuciones;
- AWS, con OIDC, ECR y la instancia.

## Uso

Dentro de tu repositorio, con `gh auth login` y `aws login` hechos, Docker en marcha (para actionlint) y la instancia de Vigía desplegada con el último commit de `main`:

```bash
cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v4/verify.sh
```

Sale con 0 si todo pasa y con 1 si algo falla.

## Qué comprueba

- **Los workflows:**
  - actionlint sin avisos;
  - todas las *actions* fijadas por un SHA de 40 caracteres;
  - `permissions:` en cada workflow, sin `id-token: write` para todo el workflow;
  - sin `pull_request_target` y sin llaves de AWS.
- **El historial de Git:** ninguna llave de AWS en ningún commit.
- **GitHub:**
  - el repositorio es público;
  - `main` exige PR y comprobaciones en verde, incluidas las pruebas;
  - ningún secreto con llaves de AWS;
  - las variables `AWS_ROLE_ARN` y `AWS_REGION`;
  - el entorno `production`;
  - el pipeline del último commit de `main`, en verde.
- **AWS:**
  - el proveedor OIDC de GitHub con la audiencia `sts.amazonaws.com`;
  - un rol que solo puede asumir tu repositorio (por `repository_id` o por un `sub` exacto) y que no es administrador;
  - la imagen `vigia:<SHA>` del último commit en ECR.
- **El despliegue:** la instancia ejecuta esa imagen y `/health` responde desde tu IP.
