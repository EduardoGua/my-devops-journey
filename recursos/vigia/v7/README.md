# Pruebas de aceptación de Vigía v7

`verify.sh` comprueba tu Vigía v7 **desde fuera**, contra el contrato de la clase 124:
- **el repositorio:**
  - `.env` fuera de Git y `GRAFANA_ADMIN_PASSWORD` en `.env.example`;
  - la configuración de Prometheus validada con `promtool check config`;
  - tus pruebas de las reglas con `promtool test rules`;
  - una prueba propia: `VigiaSitioCaido` debe saltar con un sitio caído más de 5 minutos, no antes, y no con uno que parpadea;
  - el SLO y su presupuesto de errores en el README;
- **al arrancar** tu Compose: la API, Prometheus, Alertmanager y Grafana responden, y estos tres solo en `127.0.0.1`;
- **`/metrics`:** las seis métricas del contrato con su tipo, una serie de `vigia_site_up` por URL de `config.yaml`, y ninguna URL tal cual en la etiqueta `path`;
- **Prometheus:** lee la API (`up{job="vigia"}`), carga `VigiaSitioCaido` (con `severity` y `summary`) y `VigiaApiCaida`, tiene reglas de registro `vigia:…`, ninguna regla con errores, y manda las alertas a Alertmanager, que tiene un receptor;
- **Grafana:** la contraseña de `.env` es de verdad y es la que recibe Grafana (sin probar `admin`/`admin`: Grafana bloquea al usuario tras varios intentos fallidos), la fuente de datos y un dashboard «Vigía» están aprovisionados desde archivos, y el dashboard muestra disponibilidad y latencia por sitio.

Con `--alerta`, además, la prueba de punta a punta del criterio de salida: inserta en PostgreSQL un chequeo caído de `https://verify.invalid`, espera a que `VigiaSitioCaido` se dispare, llegue a Alertmanager y este avise a tu receptor (unos 6 minutos), y lo borra al terminar.

No contiene la solución. Si termina con `Fallos: 0`, tu Vigía cumple el contrato.

## Cómo se ejecuta

Desde la raíz de tu repo de Vigía, con tu `.env` creado:

```bash
cd ~/vigia
bash ~/my-devops-journey/recursos/vigia/v7/verify.sh            # unos 3 minutos
bash ~/my-devops-journey/recursos/vigia/v7/verify.sh --alerta   # unos 8 minutos más
```

Necesita Docker con el plugin Compose, `curl`, `git` y `python3`, y deja todo arrancado. Usa la imagen `prom/prometheus:v3.15.0` para `promtool`. Las pruebas de la v2 siguen valiendo para la parte de Vigía: `bash ~/my-devops-journey/recursos/vigia/v2/verify.sh`.

Los nombres son parte del contrato: el job `vigia` en Prometheus, las alertas `VigiaSitioCaido` y `VigiaApiCaida`, las métricas `vigia_…` de la clase 124 y los puertos 9090, 9093 y 3000 en `127.0.0.1`.
