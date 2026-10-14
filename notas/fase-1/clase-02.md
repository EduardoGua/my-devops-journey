primero los retos, reto 1 la ruta relativa que lleva a garaje desde cajon es cd ../../../garaje y la absoluta vendira siendo cd ~/my-devops-journey/labs/clase-02/garaje.
en el segundo reto use ls -lh y me dio que /etc/passwd tiene un peso de 3.1k
en el reto 3 usando el comando ls -lt /var/log | head me muestra como archivo mas reciente syslog
en el reto 4 con el comando ls -l /usr/bin/python3 muestrra que es un enlance l y apunta a python3.14
en el reto 5 el archivo mencionado es resolv.conf es un archivo enlance
 el .. se usa para el directorio padre o de donde presede y / se refiere a la ruta raiz del sistema de donde parte todo, cd .. me mueve a la carpeta padre por ejemplo si me encuentro en /home/educo/documentos me mueve de documentos a educo
 cierre 2 primero revisariamos los direcctorios /etc que si recuerdo bien tiene la configuracion del sistema y /var/log la cual se trata de un historial del sistema los dos son importantes a la hora de ver si hay un caso de fallo o error
 Cierre 3 /proc es un directorio donde puedes observar informacion del sistema proporcionada por el kernel y /dev es la carpeta donde puedes ver los dispositivos conectados ya que linux aplica el todo es un archivo incluyendo mouse, teclado, disco, entre otros...
el shell es quien procesa los comandos que le demos en la terminal, es diferente ya que la terminal es solo la ventana. una ventana puedes abrirla y cerrarla mientras la shell es quien te recibe lo que en ella escribas, incluso podrias abrir una shell dentro de otra shell siendo la misma ventana.
Correccion al cierre 2 en un servidor desconocido con una web caida primero revisamos la configuracion /etc y los log /var/log para empezar a ubicar el o los posibles problemas que lo causen
## Autocorrección
Cierre: 1 ✅ · 2 🟡 · 3 🟡 · 4 ✅
Reto: 1 ✅ · 2 ✅ · 3 ✅ · 4 ✅ · 5 ✅

Corrección 2: el directorio /etc es donde se guarda la configuracion del sistema, ejemplo muestra el como deberia funcionar y en directorio var/log es donde se guarda los log y historial del sistema muestran lo que de verdad esta ocurriendo ambos se pueden usar ubicar y diagnosticar posibles fallas en servidores
Corrección 3: el directorio /proc es un directorio sin peso en kb ya que al ejemplo pedir la informacion esa la proporciona el kernel al momento

