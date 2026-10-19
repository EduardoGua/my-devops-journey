# Clase 04 — Redirecciones, pipes y códigos de salida
Fecha: 2026-10-14
Tiempo: lo dejo en blanco ya que no estoy seguro pero fue bastante

## Cierre

> 1. ¿Qué son stdout y stderr? ¿Por qué conviene que sean flujos separados? *(2–3 líneas. Empieza así: «stdout es la salida de… y stderr es… Conviene separarlas porque…»)*
stdout es la salida de datos de una aplicacion, stderr es la salida de datos de errores de la aplicacion, conviene que sean flujos de datos separados para no mezclarlos y poder reconocer el error y su diagnostico. ejemplo el mal escrito de un directorio ls /esto-no-existe

> 2. Explica qué hace `comando > log.txt 2>&1` y por qué `comando 2>&1 > log.txt` no hace lo mismo. *(3–4 líneas. Empieza así: «En la primera, stdout va primero a… y después stderr… En la segunda, stderr copia el destino de stdout cuando todavía…»)*
ese comando hace que la salida dos stderr se diriga a la misma ubicacion que la salida 1 stdout sirve para guardar todo el flujo de datos de una aplicacion, el segundo no hace lo mismo debido al orden de escritura del enunciado exactamente no recuerdo pero tengo la idea. 

> 3. ¿Qué significa un código de salida 0? ¿Por qué le importa a un pipeline de CI/CD? *(2 líneas. Empieza así: «Un 0 significa… Si un paso de un pipeline deja otro código…»)*
un 0 significa un resultado exitodo en la aplicacion cualquier otro numero diferente a 0 es erroneo, en un pipeline es importante por que el pipeline divide los pasos y aunque la aplicacion funcione perfectamente en un paso anterior puede que se produjera error y termine que aunque diga que funciono no dio el resultado esperado

> 4. **Repaso (clase 03, sin mirar):** ¿por qué `rm` es peligroso con comodines y qué haces antes de usarlo? *(2 líneas. Empieza así: «Porque el shell convierte el comodín en… y rm… Antes uso… para…»)*
rm es la aplicacion para remover del shell es peligroso usarlo con comodines por que ejemplo "*.log" borra todos los archivos .log ubicados en el directorio lo adecuado seria primero usar ls o echo "*.log" para verificar que sea todo correcto lo que se va a remover ya que el rm no posee papelera y es un eliminado definitivo

## Reto
reto 1- usando el comando cut -d: -f7 /etc/passwd | grep "bin/bash" | wc -l me dijo solo dos usuarios usan el bin/bash como shell
reto 2- ls -lS /etc | grep "^-" | head -5 ese comando me dio el resultado que esperaba
reto 3- find /etc -name "*.conf" 2> errores-find.txt > /dev/null ese comando me guarda los strerr en errores-find.txt y los stdout los elimina enviandolos a /dev/null
reto 4- mkdir "backup-$(date +%F)" && cp /etc/hostname "backup-$(date +%F)/"
## Autocorrección

Califica cada respuesta: ✅ la idea clave con tus palabras · 🟡 a medias o sin el porqué · ❌ incorrecta

Cierre: 1 🟡 · 2 🟡 · 3 ✅ · 4 ✅
Reto: 1 ✅ · 2 ✅ · 3 ✅ · 4 ✅

Correcciones (las escribió Claude en el examen; reléelas y, si quieres, cámbialas a tus palabras):

Corrección 1 — faltaba el porqué de separarlas: stdout (1) lleva los datos y stderr (2) los errores. Separadas, puedo guardar o pasar al siguiente programa solo los datos limpios, mientras los errores siguen en pantalla o van a otro archivo. Si fueran una sola, en `ls /etc/hostname /no-existe | wc -l` el error se contaría como un dato y saldría 2 en vez de 1.

Corrección 2 — faltaba el mecanismo: el shell aplica las redirecciones de izquierda a derecha, y `2>&1` manda stderr a donde va stdout en ese momento. En `> log.txt 2>&1`, primero stdout va al archivo y después stderr copia ese destino: todo acaba en el log. En `2>&1 > log.txt`, stderr copia el destino de stdout cuando todavía es la pantalla, y después solo stdout pasa al archivo: los errores siguen saliendo por pantalla.

Nota sobre la 3 — no es una deuda: la pregunta usaba «pipeline de CI/CD», que la clase no explicaba (ya está añadido en la pieza 4), y lo que sí se había enseñado (0 = éxito) estaba bien. Para recordarlo: un 0 significa que el comando salió bien y cualquier otro número, que falló. En un pipeline de CI/CD cada paso es un comando: si deja un código de salida distinto de 0, el pipeline se para y se marca como fallido, así que si fallan los tests no se despliega nada roto. Por eso es peligroso un script que falla pero deja 0: el pipeline sale en verde con algo roto.

Detalle de la 4: para previsualizar se escribe `echo *.log` sin comillas. Con comillas (`echo "*.log"`), el shell no expande el comodín e imprime `*.log` tal cual.
