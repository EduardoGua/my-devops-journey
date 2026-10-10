# Fase 6 — AWS y Cloud Practitioner

**Horas (Ruta 2.0):** 60–80 h. Unas 40 h son las clases; el resto, el estudio del examen CLF-C02 (clases 80 y 81).
**Al terminar:** tu cuenta de AWS está protegida y no te da sustos en la factura. Manejas con la consola y con la CLI las piezas básicas: IAM, VPC, EC2, security groups, S3, ECR y CloudWatch. Vigía v3 corre en una EC2 con un rol IAM, sin llaves guardadas en el servidor; sube un informe diario a S3 y manda sus logs a CloudWatch. Y tienes tu primera certificación: **AWS Certified Cloud Practitioner**.

Llevas a la nube lo que ya sabes de Linux, redes y Docker. Primero lo haces a mano, con la consola y la CLI, para entender cada pieza. En la fase 8 lo escribirás como código con Terraform: escribir como código algo que nunca hiciste a mano produce archivos copiados sin entender.

## Antes de empezar: la cuenta

> ⏳ **La cuenta de AWS se abre en la clase 67, no antes.** Una cuenta nueva empieza en el **plan gratuito**:
> - **Créditos:** 100 USD al registrarte, y hasta 100 USD más completando actividades.
> - **Duración:** 6 meses, o hasta que gastes los créditos, lo que llegue antes.
> - **Al terminar:** la cuenta **se cierra sola**. Tienes 90 días para pasar al plan de pago y recuperarla; después, AWS borra todo.
>
> Mientras estés en el plan gratuito, AWS no te cobra nada. Las fases 6, 7 y 8 (AWS, CI/CD y Terraform) son las que usan AWS y suman 120–160 h: a 7 h por semana, de 4 a 5,5 meses. **Hazlas seguidas** y los créditos te cubrirán. Kubernetes (kind) y la observabilidad corren en tu portátil.

## Qué necesitas

- **Para abrir la cuenta:** una tarjeta de crédito o débito (AWS hace una pequeña retención para verificarla), tu móvil y un **gestor de contraseñas** (Bitwarden o KeePassXC, por ejemplo).
- **Para el MFA:** una app autenticadora en el móvil (Google Authenticator, Aegis o la del gestor) o una llave de seguridad (passkey).
- **En tu Ubuntu:**
  - en la clase 70, la AWS CLI v2 (2.32 o posterior, para `aws login`);
  - en la 72, el plugin de Session Manager;
  - Docker, de la fase 5.

## Las reglas de la fase

Son las de "AWS sin sorpresas" de la Ruta 2.0:

1. **Una sola región:** `us-east-1` (Norte de Virginia). Si un recurso "desaparece", lo primero es mirar la región.
2. **Todo lleva etiqueta:** `Proyecto=lab` en las clases y `Proyecto=vigia` en el proyecto. Las etiquetas te dejan encontrar (y borrar) lo que creaste.
3. **Cada clase de AWS** empieza con un recuadro **Costo esperado** y termina con **Destruir al terminar**. No cierres la sesión sin destruir.
4. **Ninguna llave de acceso permanente** (*access key*), ni del usuario raíz ni del tuyo:
   - tú entras en la CLI con `aws login`;
   - las máquinas usan roles.
5. **Antes de crear algo que no está en una clase**, mira su precio.
6. **Una vez por semana:** créditos restantes, días restantes y gasto del mes en *Billing and Cost Management*. Te lleva un minuto.

## Clases

| # | Clase | Dónde | Tiempo |
|---|-------|-------|--------|
| | **A. Cuenta, costos e identidad** | | |
| 67 | [La víspera: tu cuenta sin sorpresas](clase-67-la-vispera.md) | navegador + móvil | 90 min |
| 68 | [La nube y su factura: regiones, zonas, precios y créditos](clase-68-la-nube-y-su-factura.md) | navegador + CloudShell | 90 min |
| 69 | [IAM I: usuarios, grupos y políticas](clase-69-iam-usuarios-y-politicas.md) | navegador + CloudShell | 90 min |
| 70 | [IAM II: roles y la AWS CLI sin llaves](clase-70-iam-roles-y-cli.md) | Ubuntu + navegador | 90 min |
| | **B. Los servicios básicos** | | |
| 71 | [VPC desde cero](clase-71-vpc.md) | Ubuntu | 2 bloques |
| 72 | [EC2, user-data y Session Manager](clase-72-ec2.md) | Ubuntu | 2 bloques |
| 73 | [Security groups y NACLs](clase-73-security-groups-y-nacls.md) | Ubuntu | 90 min |
| 74 | [S3: buckets, versiones y acceso](clase-74-s3.md) | Ubuntu | 90 min |
| 75 | [ECR: tu registro de imágenes](clase-75-ecr.md) | Ubuntu | 75 min |
| 76 | [CloudWatch: métricas, logs y alarmas](clase-76-cloudwatch.md) | Ubuntu + correo | 90 min |
| 77 | [RDS, balanceadores, Auto Scaling y Lambda](clase-77-rds-elb-asg-lambda.md) | navegador + Ubuntu | 90 min |
| | **C. Proyecto** | | |
| 78 | [Vigía v3 (I): en EC2 con un rol IAM](clase-78-vigia-v3-ec2.md) | Ubuntu + AWS + GitHub | 2 bloques largos |
| 79 | [Vigía v3 (II): informe en S3, logs en CloudWatch y destrucción](clase-79-vigia-v3-s3-y-logs.md) | Ubuntu + AWS + GitHub | 2 bloques largos |
| | **D. Certificación** | | |
| 80 | [CLF-C02 (I): la guía del examen como lista de control](clase-80-clf-guia.md) | navegador | 2 bloques + estudio |
| 81 | [CLF-C02 (II): simulacros, logística y el día del examen](clase-81-clf-examen.md) | navegador | 2 bloques + el examen |

Las pruebas de aceptación de Vigía v3 están en [`recursos/vigia/v3/`](../recursos/vigia/v3/README.md).

## Cómo encajan

```
cuenta (67) ─► costos (68) ─► identidad (69-70) ─► red (71) ─► servidor (72) ─► firewall (73)
                                                                                     │
           datos (74) ◄─ imágenes (75) ◄─ observar (76) ◄─ el resto del mapa (77) ◄──┘
               │
               └─► Vigía v3: EC2 + rol (78) ─► S3 + CloudWatch + destrucción (79) ─► CLF-C02 (80-81)
```

Cada pieza reaparece en Vigía v3, y lo que ya sabes reaparece en AWS:

| Lo que ya sabes | Dónde reaparece en AWS |
|-----------------|------------------------|
| subredes, CIDR y rutas (fase 3) | la VPC |
| firewall (clase 33) | security groups y NACLs |
| cloud-init (P2) | el *user-data* de EC2 |
| permisos y mínimo privilegio (clase 06) | IAM |
| logs (clase 13) | CloudWatch |
| imágenes y registros (fase 5) | ECR |
| boto3 y pruebas (fase 4) | el informe en S3 |

## Criterios de salida

Son los de la Ruta 2.0. Se marcan en [`PROGRESO.md`](../PROGRESO.md), solo cuando los cumples **sin mirar**:

- Creas una VPC con una subred pública y otra privada, y explicas por qué la base de datos va en la privada (clases 71 y 77)
- Vigía corre en EC2 con un rol IAM, sin llaves guardadas en el servidor (clases 78 y 79)
- El usuario raíz tiene MFA y trabajas a diario con un usuario administrador (clase 67)
- Sacas un 80 % o más en las preguntas oficiales de práctica (clases 80 y 81)
- **CLF-C02 aprobado** (clase 81)

## Datos que caducan

AWS cambia precios, condiciones y versiones. Antes de empezar la fase, pídeme `revisa la fase 6` y lo compruebo de nuevo.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| Plan gratuito | 100 USD al registrarte + hasta 100 USD con actividades; 6 meses o hasta gastar los créditos; después la cuenta se cierra (90 días para pasar a pago) | 2026-10-09 | docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html |
| Lo que pasa la cuenta a plan de pago sin preguntar | unirte a AWS Organizations, crear una *landing zone* de Control Tower, entre otros | 2026-10-09 | misma página |
| Instancias admitidas en el plan gratuito | t3.micro, t3.small, t4g.micro, t4g.small, c7i-flex.large, m7i-flex.large | 2026-10-09 | aws.amazon.com/free |
| Precios en `us-east-1` | t3.micro 0,0104 USD/h · t3.small 0,0208 USD/h · IPv4 pública 0,005 USD/h · NAT Gateway 0,045 USD/h + 0,045 USD/GB · disco gp3 0,08 USD/GB-mes | 2026-10-09 | lista pública de precios de AWS; aws.amazon.com/vpc/pricing |
| CloudWatch | gratis cada mes: 5 GB de logs, 10 métricas personalizadas, 10 alarmas, 3 paneles; después, 0,50 USD/GB de logs y 0,10 USD por alarma y mes | 2026-10-09 | aws.amazon.com/cloudwatch/pricing |
| AWS Budgets | los presupuestos de seguimiento y sus avisos son gratis | 2026-10-09 | aws.amazon.com/aws-cost-management/aws-budgets/pricing |
| AWS CLI v2 | instalador oficial `install.sh` en tu usuario; `aws login` desde la 2.32.0 | 2026-10-09 | docs.aws.amazon.com/cli |
| Ubuntu 26.04 en AWS | parámetro SSM `/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id` (Canonical, cuenta 099720109477) | 2026-10-09 | ubuntu.com/aws/docs |
| Plugin de Session Manager | `session-manager-plugin.deb`, desde `s3.amazonaws.com/session-manager-downloads` | 2026-10-09 | docs.aws.amazon.com/systems-manager |
| `amazon-ecr-credential-helper` (apt) · boto3 · moto | 0.7.1 · 1.43.111 · 5.2.3 | 2026-10-09 | `apt-cache policy`, pypi.org |
| Lambda | runtime `python3.14` (Amazon Linux 2023) | 2026-10-09 | docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html |
| Examen CLF-C02 | 65 preguntas (50 puntúan), 90 min, 100 USD, aprobado con 700 de 1000, en español (Latinoamérica), en un centro Pearson VUE u online; válido 3 años | 2026-10-09 | aws.amazon.com/certification/certified-cloud-practitioner y la guía oficial del examen |
| Dominios del CLF-C02 | conceptos 24 % · seguridad y cumplimiento 30 % · tecnología y servicios 34 % · facturación, precios y soporte 12 % | 2026-10-09 | guía oficial del examen |
| Planes de soporte | Basic, Business Support+, Enterprise Support, Unified Operations | 2026-10-09 | guía oficial del examen (dominio 4) |

## Recursos de apoyo

Las clases son el recurso principal. Para el examen y para ir más allá:
- **AWS Skill Builder** (gratis, con subtítulos en español): el curso *AWS Cloud Practitioner Essentials* y las preguntas oficiales de práctica del CLF-C02 (clases 80 y 81).
- La [guía oficial del examen CLF-C02](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02.html): la usarás como lista de control.
- La documentación de AWS, muchas páginas en español. Cuando el español y el inglés no coinciden, manda el inglés: es el que se actualiza primero.

## Siguiente fase

Fase 7 — CI/CD con GitHub Actions (se escribe a continuación).
