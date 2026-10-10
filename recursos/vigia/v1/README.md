# Pruebas de aceptación de Vigía v1

Comprueban tu Vigía **desde fuera**, como lo usaría otra persona: lanzan `python -m vigia check` contra un servidor HTTP falso local, miran tu base de datos SQLite y preguntan a tu API. No dependen de cómo organices tu código por dentro: solo del contrato de las clases 54 y 55.

No contienen la solución, y no la necesitas: si todas pasan, tu Vigía cumple el contrato.

## Cómo se ejecutan

Desde la raíz de tu repo de Vigía, con tu entorno virtual activo y `pytest` instalado:

```bash
cd ~/vigia
source .venv/bin/activate
pytest ~/my-devops-journey/recursos/vigia/v1 -v -m "not api"   # clase 54: solo el chequeo
pytest ~/my-devops-journey/recursos/vigia/v1 -v                # clase 55: todo
```

Si tu proyecto está en otra carpeta: `VIGIA_DIR=/ruta/al/proyecto pytest …`

Cada prueba que falla dice qué esperaba y qué encontró. Empieza siempre por la **primera** que falle.
