# Pruebas de aceptación de Vigía v3

`verify-aws.sh` comprueba, desde tu Ubuntu y con la AWS CLI, que tu despliegue de Vigía v3 cumple el contrato de las clases 78 y 79. Solo lee: no crea ni borra nada en tu cuenta.

## Uso

Con la sesión de `aws login` abierta:

```bash
VIGIA_BUCKET=vigia-informes-<tu cuenta> bash ~/my-devops-journey/recursos/vigia/v3/verify-aws.sh
```

Sale con 0 si todo pasa y con 1 si algo falla.

## Qué comprueba

- **La instancia:** una sola en marcha con `Proyecto=vigia`, con rol IAM, IMDSv2 obligatorio y límite de saltos de 2 o más.
- **El firewall:** sin puerto 22 y sin reglas abiertas a todo internet.
- **Vigía responde:** `/health` y `/status` desde tu IP.
- **Dentro de la instancia, por Session Manager:**
  - sin llaves de AWS guardadas;
  - la API y el chequeo con la imagen de ECR;
  - el timer del informe activo.
- **CloudWatch Logs:** `/vigia/api` y `/vigia/checker` con retención, y logs recientes del chequeo.
- **S3:** bloqueo del acceso público, versionado y el informe de hoy.

Al terminar la clase 78 aún fallarán el límite de saltos, el timer, CloudWatch y S3. Al terminar la 79: `Fallos: 0`.
