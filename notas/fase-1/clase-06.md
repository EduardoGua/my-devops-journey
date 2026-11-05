# Clase 06 — Permisos: usuarios, grupos y rwx
Fecha: 2026-11-05
Tiempo: 60 min

## Cierre

> 1. Explica `rwxr-x---` **en un directorio**: qué puede hacer cada categoría. *(3 líneas. Empieza: «El dueño puede… El grupo puede… El resto…»)*
en un directorio el dueño puede leer "r" se refiere a poder usar ls o listar lo que hay dentro, escribir "w" puede modificar lo que hay dentro mover o eliminar y ejecutar "x" permite acceder dentro del directorio en este caso el duelo puede listar, modificar y entrar al directorio, el grupo puede listar y entrar al directorio pero no puede modificar nada y otros usuarios no pueden hacer nada.

> 2. Con el directorio en `000`, ¿qué pasó con `ls caja`, con `cat caja/dato.txt` y con `ls -ld caja`? ¿Por qué el último sí funcionó? *(3 líneas. Empieza: «`ls caja` falló porque… `ls -ld` funcionó porque…»)*
en los primeros dos ls caja y cat caja/dato.txt la falta de permisos evita toda accion y con ls -ld caja te muestra la informacion del directorio al haber agregado el -d y directamente no entra al directorio

> 3. Un compañero propone `chmod -R 777 /var/www` porque nginx da "Permission denied". ¿Qué le respondes y qué harías tú? *(3 líneas. Empieza: «No, porque 777… Yo miraría…»)*
el usar chmod no es la solucion ya que viola el minimo privilegio el cual es una regla de la carrera para mantener un margen de seguridad, si ocurrio un error al respecto primero seria buscar los log para identificar el fallo el estandar general para archivos es 644 y para directorios es 755

> 4. **Repaso (clase 05, sin mirar):** ¿con qué pipeline sacarías las 5 IPs que más peticiones hacen en un log de nginx? *(una línea. Empieza: `awk '{print $…}' access.log | …`)*
awk '{print $1}' access.log | sort | uniq -c | sort -nr | head -n 5

## Autocorrección

Lo más dinámico: escríbeme «examíname clase-06». O califica tú con la autocorrección de la clase:
✅ la idea clave con tus palabras · 🟡 a medias o sin el porqué · ❌ incorrecta

Cierre: 1 ✅ · 2 ✅ · 3 ✅ · 4 ✅
Reto: 1 ✅ · 2 ✅ · 3 ✅

Correcciones (una por cada 🟡 o ❌, con tus palabras, sin copiar la clase):

