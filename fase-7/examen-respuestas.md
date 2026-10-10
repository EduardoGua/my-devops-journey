# Examen de las fases 4 a 7 — Respuestas

> ⛔ Ábrelo **solo** después de haber terminado el examen completo. Si lo lees antes, el examen deja de medir lo que sabes.

Puntúa como lo haría un entrevistador: una respuesta vale todos sus puntos si dice lo esencial **con tus palabras**, y la mitad si lo dice a medias o sin el porqué.

## Parte A

**A1.** Una **lista** es una secuencia ordenada a la que se accede por posición (`urls[0]`), y sirve para colecciones que recorres en orden. Un **diccionario** asocia claves con valores (`config["timeout"]`) y sirve para buscar por nombre o agrupar: por ejemplo, contar chequeos por URL. *(Clase 41)*

**A2.** `try` contiene el código que puede fallar; `except` atrapa los errores **esperados** y decide qué hacer; `finally` se ejecuta siempre, haya error o no, para limpiar (cerrar un archivo o una conexión). Capturar `Exception` sin más esconde errores que no esperabas, como una errata en tu código, y los convierte en fallos silenciosos: se capturan las excepciones concretas que sabes tratar. *(Clase 44)*

**A3.** El entorno virtual aísla las librerías de cada proyecto del Python del sistema y de los demás proyectos. `requirements.txt` con versiones exactas hace que tu portátil, el contenedor y el CI instalen **lo mismo**. Fuera de un entorno virtual, Ubuntu responde `externally-managed-environment` (PEP 668): su Python lo gestiona `apt`. *(Clase 46)*

**A4.** Una prueba **unitaria** comprueba una pieza por dentro (una función, un módulo), rápida y con datos controlados, y dice **dónde** está el fallo. Una de **aceptación** comprueba el programa entero desde fuera, como lo usaría alguien (la CLI, la base de datos, la API): dice si se cumple el contrato. Un *fixture* es una preparación que `pytest` inyecta en las pruebas que la piden por nombre: un `tmp_path`, una base de datos de prueba, un S3 falso con moto. *(Clases 52, 55 y 79)*

**A5.** Construir una consulta SQL pegando texto que viene de fuera, de modo que ese texto cambia la consulta. Por ejemplo, `' OR '1'='1` en un formulario. Se evita con **consultas parametrizadas**: `con.execute("SELECT … WHERE url = ?", (url,))`, nunca con f-strings. *(Clase 51)*

**A6.** Una **imagen** es la plantilla de solo lectura: el sistema de archivos y la configuración de arranque, por capas. Un **contenedor** es un proceso aislado que corre a partir de una imagen, con su propia capa de escritura que se pierde al borrarlo. Un **volumen** es almacenamiento gestionado por Docker que vive fuera del contenedor y sobrevive a que lo borres. *(Clases 56, 57 y 60)*

**A7.** **Multi-stage:** las herramientas de construcción y las cachés se quedan en la primera etapa, y la imagen final solo copia lo necesario para ejecutar. Es más pequeña y tiene menos que atacar. **No root:** si alguien compromete la aplicación, no es root dentro del contenedor, y le cuesta mucho más escapar o dañar el host. *(Clase 59)*

**A8.** Cada contenedor tiene su propio espacio de red: `localhost` es el propio contenedor. Los servicios de un Compose están en la misma red del proyecto y se encuentran **por el nombre del servicio**, gracias al DNS interno de Docker. Por ejemplo, `db:5432`. *(Clases 61 y 62)*

**A9.** Estos dos:
- **`docker logs <contenedor>`:** el error con el que muere el proceso.
- **`docker inspect <contenedor>`:** el estado. `State.ExitCode`, `State.OOMKilled` (si lo mató la memoria), `RestartCount`, y la configuración real (variables, montajes, comando).

*(Clase 63)*

**A10.** AWS se encarga de la seguridad **de** la nube (centros de datos, hardware, red, hipervisor) y el cliente, de la seguridad **en** la nube (datos, IAM, configuración). Con **EC2**, el cliente también parchea el sistema operativo y gestiona su firewall. Con **Lambda**, AWS gestiona el servidor, el sistema y el *runtime*, y el cliente solo su código, sus permisos y sus datos. *(Clase 68)*

**A11.** Un **usuario** representa a una persona o aplicación con credenciales **permanentes** (contraseña, llaves). Un **rol** no tiene credenciales propias: quien lo **asume** recibe credenciales **temporales** de STS. La **política de confianza** del rol dice **quién** puede asumirlo: un servicio como EC2, otra cuenta o un proveedor OIDC como GitHub. *(Clases 69 y 70)*

**A12.** Una subred es **pública** si su tabla de rutas tiene `0.0.0.0/0` hacia un Internet Gateway; si no, es **privada**. La base de datos va en la privada porque así no hay ningún camino desde internet hasta ella, aunque un security group quede mal configurado: es defensa en profundidad. Solo llega quien está dentro de la VPC, como el servidor de la aplicación. *(Clases 71 y 77)*

**A13.** Con IMDSv2, la respuesta que trae el token sale con un TTL igual al límite de saltos. La petición de un contenedor cruza el puente de red de Docker, que es un salto más. Con el límite en 1, la respuesta muere por el camino, y el SDK del contenedor se queda sin credenciales del rol. *(Clases 72 y 79)*

**A14.**
- **Integración continua:** cada cambio se integra pronto y se verifica solo (lint, pruebas, build).
- **Entrega continua:** cada cambio que pasa queda listo para desplegar, con el artefacto publicado, y desplegarlo es una decisión humana, un botón.
- **Despliegue continuo:** cada cambio que pasa todo se despliega solo en producción.

*(Clase 82)*

**A15.** Un mecanismo de federación: en cada ejecución, GitHub firma un token OIDC con los datos del repositorio y la rama, y STS lo cambia por credenciales temporales de un rol cuya política de confianza solo admite ese repositorio y esa rama. Resuelve el problema de guardar llaves de AWS permanentes como secretos de GitHub, que se filtran y no caducan. *(Clase 86)*

## Parte B

Cada bloque vale 4 puntos: 1 por cada problema bien explicado y arreglado, hasta 4.

**B1.** *(Clases 49 y 54)*
1. **Sin `timeout`:** si el servidor no responde, la llamada puede quedarse colgada para siempre. Arreglo: `requests.get(url, timeout=10)`.
2. **Sin manejo de errores de red:** un DNS que no existe o una conexión rechazada lanzan una excepción (`requests.exceptions.RequestException`), y el programa se cae en lugar de decir "caído". Arreglo: `try/except` y devolver `False` con el error.
3. **Sigue las redirecciones:** `requests` las sigue por defecto, así que se mide otra URL. Arreglo: `allow_redirects=False` y decidir qué es "arriba" (en Vigía, un 3xx también).
4. **Sin `User-Agent` propio:** algunos sitios (Wikipedia) responden 403 a `python-requests`. Arreglo: `headers={"User-Agent": "Vigia/1.0 (+url)"}`.
5. **Solo acepta 200** (vale como problema si lo justificas): un 204 o un 301 también son respuestas sanas.

**B2.** *(Clases 58 y 59)*
1. **Imagen completa:** `python:3.14` pesa cientos de MB de más. Arreglo: `python:3.14-slim` y, si hace falta compilar, *multi-stage*.
2. **`COPY . /app` antes de instalar:** cualquier cambio en el código invalida la caché del `pip install`. Arreglo: copiar `requirements.txt`, instalar y después copiar el código.
3. **Sin `.dockerignore`:** copia `.git`, `.venv` o un `.env` con secretos dentro de la imagen.
4. **Un secreto en `ENV`:** queda guardado en la imagen para quien la tenga (`docker inspect`). Arreglo: pasarlo al arrancar (variables de entorno de Compose, un gestor de secretos).
5. **Corre como root:** `useradd` y `USER`.
6. **`CMD` en forma *shell*:** el PID 1 es `/bin/sh`, que no reenvía `SIGTERM`, y `docker stop` tarda 10 s y mata el proceso. Arreglo: `CMD ["python", "app.py"]`.

**B3.** *(Clases 60, 61, 62 y 66)*
1. **La contraseña escrita en el archivo,** que va a Git. Arreglo: `${POSTGRES_PASSWORD:?…}` y un `.env` fuera de Git.
2. **El puerto 5432 publicado en todas las interfaces:** la base de datos accesible desde la red. Arreglo: quitar `ports` en `db`; la API la alcanza por la red interna.
3. **`localhost` en `DATABASE_URL`:** dentro del contenedor de la API, `localhost` es la API. Arreglo: `@db:5432`.
4. **Sin volumen con nombre:** los datos van a un volumen anónimo y se "pierden" al recrear el contenedor. Arreglo: `datos:/var/lib/postgresql`.
5. **Sin `healthcheck` ni `depends_on: condition: service_healthy`:** la API arranca antes de que PostgreSQL acepte conexiones.
6. **La API publicada en `0.0.0.0`** cuando solo la usas tú: `127.0.0.1:8000:8000`.

**B4.** *(Clases 69, 74 y 79)* La política permite **todas** las acciones de S3 sobre **todos** los buckets: leer, borrar, cambiar políticas, hacer público un bucket. Si alguien compromete la EC2, tiene todo S3. Arreglo, con mínimo privilegio:

```json
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::vigia-informes-123456789012/reports/*"}]}
```

4 puntos si la arreglas así y explicas el riesgo. 2 si solo dices "demasiados permisos".

**B5.** *(Clases 82 a 86)*
1. **`pull_request_target` con *checkout* del código del PR:** ejecuta código de cualquiera (incluso de un *fork*) con los secretos y permisos del repositorio. Arreglo: `pull_request` para probar, y desplegar solo desde `main`.
2. **`permissions: write-all`:** el token puede escribir en todo. Arreglo: `contents: read`, y solo lo necesario en cada job.
3. **El título del PR dentro de `run:`:** inyección de órdenes. Arreglo: pasarlo por `env:`.
4. **Llaves de AWS permanentes como secretos:** arreglo, OIDC con un rol limitado a tu repositorio y a `main`.
5. **Actions sin fijar** (`@v4`) y `ubuntu-latest`, que se mueve: fijar por SHA y una versión concreta del runner.
6. **Desplegar en cada PR, sin pruebas ni entorno:** desplegar solo tras unir a `main`, con las comprobaciones obligatorias y un entorno con reglas.

## Parte C

Cada escenario vale 5 puntos: 3 por un orden razonable de comprobaciones con lo que esperas ver, y 2 por la hipótesis correcta.

**C1.** Hipótesis: la API busca PostgreSQL en `127.0.0.1`, que dentro de su contenedor es ella misma (clase 61).
1. `docker compose config | grep -A3 DATABASE_URL`: ¿apunta a `localhost` o a `127.0.0.1`?
2. `docker compose ps`: ¿está `db` en marcha y *healthy*?
3. `docker compose exec api python -c "import socket; print(socket.gethostbyname('db'))"`: el nombre del servicio sí resuelve.

Arreglo: `@db:5432` en `DATABASE_URL` y `depends_on` con `condition: service_healthy`.

**C2.** Hipótesis principal: **tu IP pública ha cambiado** y el security group solo admite la de ayer (clase 73). El servicio funciona (responde dentro) y el síntoma es *timeout*, algo que descarta.
1. `curl -s https://checkip.amazonaws.com` y compárala con la regla del SG (`aws ec2 describe-security-groups … IpPermissions`).
2. Si coincide: ¿cambió la IP de la **instancia**? Lo hace si se paró y se arrancó (`describe-instances … PublicIpAddress`).
3. La tabla de rutas y la NACL de la subred.

Arreglo: actualizar la regla a tu IP actual, nunca abrir a `0.0.0.0/0`.

**C3.** Hipótesis: la política de confianza del rol exige `ref` = `refs/heads/main` (o un `sub` de `main`), y el token de la rama `prueba` lleva `refs/heads/prueba` (clase 86). Es lo esperado: una rama cualquiera no publica.
1. Mira en el log qué rama lanzó la ejecución.
2. `aws iam get-role --role-name vigia-github --query Role.AssumeRolePolicyDocument`: las condiciones.
3. Si quieres comprobar el token, imprime sus *claims* con el step de la clase 86.

Arreglo: publicar desde `main`, tras un PR.

**C4.** Hipótesis: el **límite de saltos de IMDS es 1** (clase 79). Los logs los envía el demonio de Docker, que corre en la instancia y llega al IMDS sin saltos; el informe lo sube boto3 **desde un contenedor**, y su petición cruza el puente de Docker.
1. `aws ec2 describe-instances --query '…MetadataOptions'`: ¿`HttpPutResponseHopLimit` = 1?
2. Dentro de la instancia, `sudo docker compose … run --rm checker python -c "import boto3; print(boto3.client('sts').get_caller_identity())"`: falla igual.
3. Comprueba que el rol tiene `s3:PutObject` (si no, el error sería `AccessDenied`, no `NoCredentialsError`).

Arreglo: `modify-instance-metadata-options --http-put-response-hop-limit 2`, y ponerlo en el comando de lanzamiento.

**C5.** Hipótesis: un recurso que cobra por hora sigue vivo. Lo típico: una instancia olvidada (unos 15 USD al mes una t3.small) o un NAT Gateway (unos 33 USD).
1. **Cost Explorer**, agrupado por *Service* y luego por *Usage type*: ¿`BoxUsage`, `NatGateway-Hours`, `PublicIPv4`?
2. Busca en **todas las regiones**, no solo en `us-east-1` (clase 68): instancias, NAT Gateways e IP elásticas.
3. Tu inventario (clase 67): ¿qué se quedó apuntado?
4. Destruye lo que sobra y pon (o revisa) el presupuesto con aviso.

## Parte D

**D1 (8 puntos):**

| Criterio | Puntos |
|----------|--------|
| Lee el JSON y agrupa por URL | 2 |
| Calcula bien la disponibilidad y la media, con el redondeo pedido y el caso "ninguno respondió" | 2 |
| Escribe el CSV con cabecera usando el módulo `csv` | 1 |
| `argparse` con el archivo y `--salida` | 1 |
| Archivo que no existe y JSON roto: mensaje en `stderr` y código 2, sin *traceback* | 2 |

Con `checks.json`, el CSV debe quedar así (en este orden o en otro):

```
url,checks,disponibilidad,segundos_medios
https://caido.invalid,20,0.0,
https://example.com,20,100.0,0.535
https://www.wikipedia.org,20,90.0,0.525
```

Una solución posible:

```python
"""resumen.py: disponibilidad y tiempo medio por URL, de un JSON de chequeos a un CSV."""
import argparse
import csv
import json
import sys
from collections import defaultdict


def resumir(chequeos):
    por_url = defaultdict(list)
    for c in chequeos:
        por_url[c["url"]].append(c)
    filas = []
    for url, lista in sorted(por_url.items()):
        arriba = [c for c in lista if c["up"]]
        media = round(sum(c["seconds"] for c in arriba) / len(arriba), 3) if arriba else None
        filas.append({"url": url, "checks": len(lista), "disponibilidad": round(100 * len(arriba) / len(lista), 2),
                      "segundos_medios": media})
    return filas


def main(argv=None):
    parser = argparse.ArgumentParser(description="Resume un JSON de chequeos en un CSV")
    parser.add_argument("archivo")
    parser.add_argument("--salida", default="resumen.csv")
    args = parser.parse_args(argv)
    try:
        with open(args.archivo, encoding="utf-8") as f:
            chequeos = json.load(f)
    except FileNotFoundError:
        print(f"error: no existe {args.archivo}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"error: {args.archivo} no es un JSON válido: {e}", file=sys.stderr)
        return 2
    filas = resumir(chequeos)
    with open(args.salida, "w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=["url", "checks", "disponibilidad", "segundos_medios"])
        escritor.writeheader()
        escritor.writerows(filas)
    print(f"{len(filas)} URL resumidas en {args.salida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

**D2 (7 puntos):**

| Criterio | Puntos |
|----------|--------|
| Una prueba de `resumir()` con datos propios: por ejemplo, dos chequeos de una URL, uno `up` y otro no → 50.0 | 2 |
| `on: pull_request` y `push` a `main`, y `permissions: contents: read` | 2 |
| `checkout` y `setup-python` fijadas por SHA de 40 caracteres, con la versión en un comentario | 2 |
| `ruff check .` y `pytest` en el job, y actionlint sin avisos | 1 |

## Parte E

Cada grabación vale 5 puntos:

| Criterio | Puntos |
|----------|--------|
| Estructura clara: de qué va, cómo funciona y el resultado (en E2: situación, tarea, acción y resultado) | 2 |
| Términos técnicos correctos y sin muletillas que tapen las ideas | 2 |
| Dentro del tiempo y sin leer | 1 |

Si te cuesta, no lo dejes para después: repite la grabación cada semana hasta que salga fluida. En las entrevistas en inglés, esto vale tanto como la parte técnica.

## Si no llegas al 80 %

Apunta en `notas/fase-7/examen-<fecha>.md` qué preguntas fallaste y de qué clase son (está entre paréntesis en cada respuesta). Repasa esas clases con su Rómpelo y su Reto, y repite el examen **una semana después**.
