# Pruebas de aceptación de Vigía v2

`verify.sh` comprueba tu Vigía v2 **desde fuera**: construye tu imagen, levanta tu `compose.yaml` y revisa lo que pide el contrato de las clases 65 y 66 (archivos, usuario sin privilegios, puertos, que el chequeo escribe en PostgreSQL y la API lo muestra, que los datos sobreviven a `docker compose down` y `up`, y que el chequeo se para enseguida con SIGTERM).

No contiene la solución. Si termina con `Fallos: 0`, tu Vigía cumple el contrato.

## Cómo se ejecuta

Desde la raíz de tu repo de Vigía, con tu `.env` creado:

```bash
cd ~/vigia
bash ~/my-devops-journey/recursos/vigia/v2/verify.sh            # lo deja corriendo
bash ~/my-devops-journey/recursos/vigia/v2/verify.sh --limpiar  # lo para al terminar
```

Necesita Docker con el plugin Compose, `curl` y `python3`, y acceso a internet (el chequeo revisa las URLs de tu `config.yaml`). Tarda unos 2–3 minutos.

Las pruebas de la v1 siguen valiendo para el modo SQLite: `pytest ~/my-devops-journey/recursos/vigia/v1`.
