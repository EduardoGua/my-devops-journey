# Clase 30 — Examen de la fase 1

**Tiempo:** 2 h (teoría y cálculo) + 1 h (práctica en VM) · **Sin apuntes, sin internet, sin IA** · **Aprobado: ≥ 80 %**

## Reglas

- Responde en `notas/fase-1/examen-<fecha>.md`.
- Puedes usar `man` y `--help` **solo** en la parte D (práctica). En la vida real también los tienes.
- Cronometra. Si te pasas de tiempo, anótalo: es información, no un suspenso.
- Corrígete al terminar con [`examen-respuestas.md`](examen-respuestas.md) y la rúbrica. Sé exigente: puntúa como lo haría un entrevistador.
- Si no llegas al 80 %: anota qué clases fallaste, repásalas (clase + reto) y repite el examen **una semana después**. No antes: así compruebas lo que recuerdas, no lo que acabas de leer.

Si quieres una segunda opinión, escríbeme `revisa examen F1`.

---

## Parte A — Conceptos (30 puntos, 2 por pregunta)

Respuestas de 2–4 frases, con un ejemplo cuando sea posible.

**A1.** ¿Qué diferencia hay entre la terminal, el shell y el kernel?

**A2.** ¿Qué hace `2>&1` y por qué `cmd > f 2>&1` no equivale a `cmd 2>&1 > f`?

**A3.** Explica `rwxr-x---` sobre un **directorio**.

**A4.** Un compañero propone `chmod -R 777` para arreglar un "Permission denied" de nginx. ¿Qué le respondes y qué harías?

**A5.** ¿Por qué un script funciona en tu terminal y falla en un cron o un servicio con "command not found"?

**A6.** Diferencia entre `SIGTERM` y `SIGKILL`. ¿Qué pasa al parar un contenedor en Kubernetes?

**A7.** Diferencia entre `systemctl start` y `systemctl enable`. Cuenta el incidente típico.

**A8.** Una app se reinicia sola y no hay ningún error en su log. ¿Qué miras?

**A9.** `df` dice 100 %, pero `du` solo encuentra la mitad. Da dos causas posibles y cómo comprobarlas.

**A10.** ¿Por qué la llave privada SSH no se comparte nunca? Si se filtra, ¿qué haces?

**A11.** Explica el handshake TCP y qué significa "connection refused" frente a "timeout".

**A12.** ¿Qué hace "pública" a una subred en AWS? ¿Para qué sirve un NAT Gateway?

**A13.** ¿Qué es el TTL de un registro DNS y por qué se baja antes de una migración?

**A14.** ¿Qué significan 502, 503 y 504 en un balanceador?

**A15.** Security groups frente a NACLs: dos diferencias.

## Parte B — Cálculo de redes (20 puntos, 4 por pregunta)

Sin calculadora.

**B1.** `172.16.77.130/26`: dirección de red, broadcast y número de hosts útiles (en una red normal y en AWS).

**B2.** ¿Están `10.0.1.20/23` y `10.0.0.200/23` en la misma subred? Justifícalo.

**B3.** Divide `10.20.0.0/16` en 4 subredes iguales. Escríbelas con su prefijo.

**B4.** Necesitas una subred de AWS para 1.000 instancias. ¿Qué prefijo mínimo usas? ¿Cuántas IPs útiles tendrá?

**B5.** Una regla de entrada permite `5432/tcp` desde `0.0.0.0/0` en una base de datos. ¿Qué significa y cómo la reescribirías bien en AWS?

## Parte C — Diagnóstico (25 puntos, 5 por escenario)

Para cada escenario: **tus 3–5 primeros comandos en orden**, qué esperas ver en cada uno y tu hipótesis principal.

**C1.** Tras reiniciar una EC2 por mantenimiento, la web no responde. Antes del reinicio funcionaba.

**C2.** Desde tu PC, `curl http://IP:8080` tarda 30 segundos y falla. Dentro de la instancia, `curl localhost:8080` responde bien.

**C3.** Desde tu PC, `curl http://IP:8080` falla **al instante**. Dentro de la instancia, `curl localhost:8080` responde bien.

**C4.** La API de una tienda devuelve `502 Bad Gateway` desde esta mañana. nginx está activo.

**C5.** `apt install` falla con "No space left on device".

## Parte D — Práctica en una VM nueva (15 puntos)

Lanza una VM limpia: `multipass launch lts --name examen`. Tienes **60 minutos**. Puedes usar `man`. Al terminar, guarda el historial (`history > ~/examen-history.txt`) y cópialo a tus notas.

**D1 (5 pts).** Crea el grupo `ops` y los usuarios `maria` y `pedro` en él. Crea `/srv/ops` donde los miembros de `ops` lean y escriban, los archivos nuevos hereden el grupo `ops` y nadie más pueda entrar. Da a `maria` permiso de `sudo` **solo** para `systemctl restart nginx`.

**D2 (5 pts).** Instala nginx. Crea un servicio de systemd `hora.service` que ejecute, como un usuario de sistema `horasvc`, un servidor en el puerto 8090 que sirva un `index.html` con la fecha de creación. Debe reiniciarse si muere y arrancar en el boot. Haz que nginx publique ese servicio en la ruta `/hora/`. Demuéstralo con `curl` desde tu PC.

**D3 (5 pts).** Configura el firewall para que solo entren el 22 y el 80. Demuestra **desde tu PC** que el 8090 no es accesible directamente, pero `/hora/` sí lo es a través de nginx. Explica en tus notas por qué esto es una buena arquitectura.

## Parte E — Inglés de entrevista (10 puntos)

Responde **en inglés**, en voz alta (grábate si puedes) y por escrito, en 4–6 frases cada una:

**E1.** *Walk me through what happens when you type `https://example.com` in your browser.*

**E2.** *A website is down. How do you troubleshoot it?*

**E3.** *Tell me about a time you fixed a problem on a Linux system.* (Usa un incidente de tu P1, con el formato STAR.)

---

## Rúbrica

| Nota por pregunta | Criterio |
|-------------------|----------|
| 100 % | Correcta, con el **porqué** y un ejemplo o un comando |
| 50 % | Idea correcta pero incompleta, o sin el porqué |
| 0 % | Incorrecta, confunde conceptos o recomienda algo peligroso |

**Penalización de seguridad:** cualquier respuesta que proponga `chmod 777`, `0.0.0.0/0` en un puerto administrativo o de base de datos, desactivar la verificación TLS en producción o `push --force` a una rama compartida **suma 0** en esa pregunta, aunque el resto sea correcto. En el trabajo, esos errores cuestan más que un fallo de conocimiento.

| Total | Resultado |
|-------|-----------|
| ≥ 80 | ✅ Fase 1 superada: abre la fase 2 (`escribe la fase 2`) |
| 65–79 | Repasa las clases de las preguntas falladas y repite en una semana |
| < 65 | Repite los retos de los bloques flojos antes de volver a intentarlo |

## Al aprobar

1. Marca la clase 30 en `PROGRESO.md` y escribe la fecha.
2. Revisa la **puerta** de la fase 1 en [`../PLAN.md`](../PLAN.md): P1 y P2 en GitHub, CIDR a mano, explicar `curl https://…` de memoria.
3. Actualiza el `README.md` del repo (en inglés) con lo que ya sabes hacer: tu portfolio empieza a hablar por ti.
4. Celébralo. Has hecho la parte más larga y más difícil del camino.
5. Pídeme: `escribe la fase 2`.
