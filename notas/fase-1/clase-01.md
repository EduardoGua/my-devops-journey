# Clase 01 — La terminal, el shell y el kernel
Fecha: 2026-10-08
Tiempo: aproximadamente 40 minutos

## Cierre
1. terminal es solo la ventana que podemos usar para comunicarnos, shell es quien procesa la comunicacion y la lleva al kernel quien es el encargado de administrar los permisos y recursos del hardware
2. el shell lee los comandos o instrucciones, busca en los directorios la aplicacion a usar, solicita al kernel la creacion de dicho programa
3. lsss falla por que el nombre o comando de la aplicacion a usar en este caso ls esta mal escrito y obvio el shell no lo reconoce y ls /esto no existe en este caso el comando o aplicacion ls si funciona pero falla al no poder encontrar el archivo solicitado
4. cloud & devops debe dominar la terminal ya que la mayoria de los servidores usan linux, y nos permite la mayoria de las tareas con mayor libertad

## Reto
1. `nproc`: mi maquina tiene 8 nucleos
2. `which ls`: el programa esta en el directorio /bin/ls
3. `man ls`: ls -t para que nos de la lista ordenada por tiempo
4. `type pwd`: pwd es un builtin

## Autocorrección
Cierre: 1 ✅ · 2 🟡 · 3 ✅ · 4 🟡
Reto: 1 ✅ · 2 ✅ · 3 ✅ · 4 ✅

## Correcciones

Corrección cierre 2: el shell busca el programa en el PATH, el kernel comprueba si tienes permiso para ejecutarlo y leer lo que pides, y la terminal muestra el resultado.
Corrección cierre 4: un servidor no tiene escritorio, solo entras por SSH. La consola web no sirve para automatizar ni repetir tareas.
