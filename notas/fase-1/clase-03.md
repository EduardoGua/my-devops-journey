1.- la diferencia entre > y >> es que > reemplaza todo el contenido del archivo y >> se agrega al final del archivo, ya me ah pasado que creanto estas notas reemplazo todo por su mal uso, puede pasar sobreescribiendo cualquier cosa supongamos que tienes una lista de empleados y vas a agregarla a empleados.txt si usas > en vez de >> pierdes toda la lista completa y tendrias que hacer el archivo de nuevo en caso no tengas backups
2.- el hacer echo antes de rm es para verificar que el archivo sea el correcto y evitar perdidas ya que rm no tiene papelera y su eliminacion es definitiva, el * es un comodin amplio que por ejemplo *.log buscaria todos los archivos con extension .log y el uso del comodin puede usarse con echo, ls, find entre otros donde tengas que nombrar
3.- tail -f se usa para hacer seguimiento de las ultimas entradas de un archivo se podria usar en un log para llevar lo que ocurre dentro, la situacion real podria ser viendo por ejemplo yo un log de una base de datos db.log y otras tres personas tuvieron acceso a ella con el comando tail -f podria ver en vivo el momento en que conectaron
4.- desde /var/log/nginx el comando cd ../.. me llevaria hasta var ya que el comando pide subir dos directorios padres y cd / me llevaria hasta el directorio raiz

Correccion 
1.- digamos un ejemplo del primer caso estoy editando el /etc/passwd para agregar un usuario nuevo y en vez de usar >> uso > se pierden todos los usuarios existentes y al destrozarla nadie puede iniciar luego y sudo deja de funcionar
2.- rm es una aplicacion que solo sabe borrar y el usar echo *.log es para ver una lista proporcionada por el shell y confirmar primero de si lo que vamos a borrar es lo correcto

