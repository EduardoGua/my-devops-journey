# Pruebas de aceptación de Vigía v5

`verify.sh` comprueba que toda la infraestructura de Vigía está en Terraform y que AWS coincide con el código. Solo lee: no aplica nada.

## Uso

En la raíz de tu repositorio, con `aws login` hecho y `terraform init` hecho en `infra/`:

```bash
cd ~/vigia && bash ~/my-devops-journey/recursos/vigia/v5/verify.sh
```

Sale con 0 si todo pasa y con 1 si algo falla. Al final ejecuta el [`verify-aws.sh` de la v3](../v3/README.md), así que necesita la instancia en marcha y el informe de hoy en S3.

## Qué comprueba

- **El código:**
  - `terraform fmt` no cambiaría nada;
  - las versiones de Terraform y del provider están fijadas;
  - el backend es S3 con `use_lockfile = true`, sin DynamoDB;
  - hay un módulo propio en `infra/modules/`;
  - `default_tags` lleva `Proyecto = vigia`;
  - no hay secretos escritos.
- **Git:**
  - `.terraform.lock.hcl` está dentro;
  - los estados, `.terraform/` y `terraform.tfvars`, fuera;
  - un workflow hace `fmt` y `plan`.
- **El estado:** el bucket tiene versionado y bloquea el acceso público, y el estado está en él.
- **AWS coincide con el código:**
  - `terraform validate` pasa;
  - `terraform plan` no propone cambios;
  - existen los outputs `url` y `bucket_informes`.
- **El contrato de la v3:** `verify-aws.sh` pasa entero.
