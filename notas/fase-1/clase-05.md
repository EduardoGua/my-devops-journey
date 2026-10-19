# Clase 05 — Buscar y filtrar: find, grep y compañía
Fecha: 2026-10-18
Tiempo: al menos 2 horas la clase la lei 3 veces en varios tiempos.

## Cierre

> 1. Explica el patrón `sort | uniq -c | sort -rn | head` paso a paso. ¿Por qué hace falta el primer `sort`? *(3–4 líneas, una por pieza. Empieza así: «`sort` junta… `uniq -c`… `sort -rn`… y `head`… El primer `sort` hace falta porque…»)*
Primero sort ordena los datos que se repiten ejemplo las direcciones ip que se repitan iguales, uniq -c las junta y coloca la cantidad total al frente de la informacion, sort -rn las vuelve a ordenar de mayor a menor y head muestra los primeros 10 asi se optienen los primeros 10 datos que mas se repitan de algun documento, el primer sort es el mas importante por que sin ordenarlos por iguales antes de uniq -c los datos quedan desordenados

> 2. Con los datos del log, redacta en 3–4 líneas un **resumen del incidente**, como si se lo contaras a tu jefe: qué pasó, cuándo, qué afectó y qué harías. *(3–4 líneas. Empieza así: «Hubo dos problemas. Primero, hacia las 14:00… Segundo, desde la IP…»)*
Omitida. Ejemplo para leer (lo escribió Claude):
«Hubo dos problemas. Primero, hacia las 14:00 se triplicaron los errores 5xx (21 en esa hora, frente a unos 8 en las demás), sobre todo en `/api/orders`: los pedidos fallaban. Revisaría los logs de la aplicación de pedidos a esa hora y si hubo algún cambio o despliegue. Segundo, desde la IP 198.51.100.7 hubo un ataque de fuerza bruta: unos 120 `POST /login` con 401 entre las 19:25 y las 19:27, con `python-requests`. La bloquearía en el firewall, limitaría los intentos de login y comprobaría que ninguna cuenta llegó a entrar.»

> 3. ¿Por qué `grep " 401 "` y `awk '$9 == 401'` dieron números distintos? ¿Qué lección sacas? *(2 líneas. Empieza así: «`grep` encontró también una línea en la que 401 era…, mientras que `awk` mira solo… Lección: …»)*
la diferencia esta en los comandos grep te busca en toda la linea mientras que awk te busca en el noveno trozo, al mirar mas informacion en otro trozo que no es el 9 hay un 401

> 4. **Repaso (clase 04, sin mirar):** ¿qué hace `2>/dev/null` y por qué lo usaste con `find`? *(2 líneas. Empieza así: «Manda stderr a… Con `find` hacía falta porque…»)*
usar 2>/dev/null con find es para enviar los reportes stderr o posible mensajes de errores o fallos a /dev/null singulamente se estan eliminando y evitando en la pantalla, los errores con find pueden llegar a aparecer mientras busca y pueda toparse con archivos o carpetas sin permisos suficiente

## Autocorrección

Lo más dinámico: escríbele a Claude «examíname clase-05». O califica tú con la autocorrección de la clase:
✅ la idea clave con tus palabras · 🟡 a medias o sin el porqué · ❌ incorrecta

Cierre: 1 ✅ · 2 — (omitida) · 3 ✅ · 4 ✅
Reto: 1 ✅ · 2 ✅ · 3 ✅ · 4 ✅ · 5 ✅

Correcciones (una por cada 🟡 o ❌, con tus palabras, sin copiar la clase): ninguna pendiente.

Nota sobre la 3 (la escribió Claude): ese 401 de más era el tamaño de la respuesta (401 bytes, trozo 10). Lección: si el log tiene columnas, filtra por columna con `awk` y no por texto suelto con `grep`.


