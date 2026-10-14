# Repaso del bloque B — Administrar un servidor

**Dónde:** tus notas, sin terminal · **Tiempo:** 50 min · **Cuándo:** después de la clase 15 y antes de la 16

> 💡 **Por qué este repaso:** el bloque B es lo que te preguntarán en una entrevista de soporte o de DevOps junior: servicios, logs, permisos, memoria, disco y SSH. Aquí las preguntas mezclan clases, y algunas vuelven al bloque A, porque en un incidente real nadie te dice qué tema toca.

## Cómo hacerlo

1. Crea tu archivo: `bash ~/my-devops-journey/recursos/nueva-nota.sh repaso-b`.
2. Responde **sin mirar** clases ni notas, en 35 minutos como máximo. Si no sabes algo, escribe «no lo sé» y sigue.
3. Corrige con la autocorrección y califica cada una (✅ 🟡 ❌).
4. Cada 🟡 o ❌ es una tarjeta de Anki y 10 minutos de vuelta a la clase que indica la respuesta.
5. Termina con tu chuleta (abajo).

## Preguntas

1. ¿Qué diferencia hay entre `multipass stop`, `multipass delete` y `multipass delete --purge`? ¿Cuál equivale a *Terminate* en AWS, y qué sigue costando dinero si solo paras una EC2?
2. Ana tiene que poder reiniciar nginx con `sudo` y nada más. Escribe la regla y cómo la creas sin riesgo de romper `sudo`.
3. `/srv/equipo` es `root:devs` con permisos `2770`. Luis, de `devs`, crea un archivo, y Ana, también de `devs`, no puede modificarlo. ¿Qué dos piezas revisas?
4. ¿Por qué en un script de aprovisionamiento se escribe `apt-get update && apt-get install -y nginx`, y no solo el `install`?
5. Una app tarda 20 segundos en apagarse y alguien propone usar siempre `kill -9`. ¿Qué le respondes?
6. `systemctl status miapp` dice `active (running)`, pero la web no responde. ¿Qué haces?
7. Tras reiniciar el servidor, `miapp` no está corriendo. Da dos causas posibles y el comando que distingue cada una.
8. Escribe el comando para ver los errores de nginx en el journal entre las 14:00 y las 14:30 de hoy.
9. En una VM de 1 GB, `free -h` muestra `free 80Mi` y `available 600Mi`. ¿Tiene un problema de memoria?
10. Una app se reinicia sola cada pocas horas y su log no muestra ningún error. ¿Qué sospechas y dónde lo confirmas?
11. Copias tu llave privada a otro equipo y SSH se niega a usarla: `UNPROTECTED PRIVATE KEY FILE`. ¿Por qué, y cómo lo arreglas?
12. **(Bloque A)** En un log con líneas como `Invalid user admin from 203.0.113.9 port 51234`, saca las 3 IPs que más lo intentan.
13. **(Bloque A)** ¿Por qué falla `sudo echo "x" >> /etc/archivo`? Explícalo con lo que sabes de redirecciones.
14. **(Bloque A)** Un servicio de systemd no ve una variable que exportaste en tu `~/.bashrc`. ¿Por qué? ¿Dónde se la pones?
15. **Caso final.** La web de `servidor-01` no responde. Escribe en orden tus primeros cinco comandos y qué esperas aprender de cada uno.

## Tu chuleta

En 10 minutos y **sin mirar**, escribe en `notas/fase-1/chuleta-bloque-b.md` los comandos del bloque agrupados por tarea: VM, usuarios y sudo, paquetes, procesos, servicios, logs, recursos y SSH. Después repasa las clases 08 a 15 y añade lo que faltaba marcado con ➕.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `stop` apaga la VM y conserva su disco; `delete` la marca como borrada, pero aún se puede recuperar con `recover`; `delete --purge` la elimina para siempre, como *Terminate*. Una EC2 parada no paga CPU, pero **sí** su volumen EBS (y una IP elástica sin usar). *(Clase 08.)*

**2.** `sudo visudo -f /etc/sudoers.d/ana` y dentro `ana ALL=(root) /usr/bin/systemctl restart nginx`. `visudo` comprueba la sintaxis antes de guardar: un error en sudoers puede dejar a todos sin `sudo`. Después, `sudo -l -U ana` para comprobarlo. *(Clase 09.)*

**3.** (1) Que el archivo tenga el **grupo** `devs`: el setgid del directorio (el `2` de `2770`) se encarga, y `ls -l` lo confirma. (2) Que el grupo tenga **permiso de escritura**: si Luis lo creó con umask `022`, nació `rw-r--r--` y el grupo solo puede leer. Arreglo: `chmod g+w`, umask `002` para quien crea, o mejor, ACLs por defecto en el directorio. *(Clases 06 y 09.)*

**4.** En una máquina recién creada (una EC2, un contenedor) el índice local está vacío o viejo: el `install` fallaría con `Unable to locate package` o instalaría versiones antiguas. `&&` hace que solo se instale si `update` funcionó, `-y` evita la pregunta y `apt-get` tiene una salida estable para scripts. *(Clase 10.)*

**5.** `SIGKILL` no se puede atrapar: la app muere sin cerrar conexiones ni terminar de escribir, y se cortan peticiones o se corrompen datos. Lo correcto: `SIGTERM`, esperar y solo como último recurso `-9`. Kubernetes y ECS hacen lo mismo con un tiempo de gracia. Y conviene investigar por qué tarda tanto en apagarse. *(Clase 11.)*

**6.** «Running» no es «funcionando». Pruebo con una petición real (`curl -s -o /dev/null -w "%{http_code}\n" localhost:8080`), leo sus logs (`journalctl -u miapp -n 50`) y reviso los permisos de lo que tiene que leer: en la clase 12 respondía 404 porque `appsvc` no podía leer `index.html`. *(Clase 12.)*

**7.** (a) No estaba **habilitado**: `systemctl is-enabled miapp` dice `disabled`. (b) Estaba habilitado, pero **falló al arrancar**: `systemctl status miapp` dice `failed`, y `journalctl -b -u miapp` muestra por qué en este arranque. *(Clases 12 y 13.)*

**8.** `journalctl -u nginx -p err --since "14:00" --until "14:30" --no-pager`. Una hora sin fecha significa «hoy». *(Clase 13.)*

**9.** No. Linux usa la memoria libre como caché de disco y la devuelve cuando alguien la pide. La columna que importa es `available`: 600 MiB disponibles está bien. Preocuparía un `available` bajo con mucho swap en uso. *(Clase 14.)*

**10.** El **OOM killer**: el kernel la mató con `SIGKILL` por falta de memoria, y por eso la app no pudo escribir nada. Se confirma en el log del kernel: `journalctl -k | grep -iE "out of memory|killed process"`. *(Clase 14.)*

**11.** La copia se creó con permisos demasiado abiertos (por ejemplo `664`, según tu umask), y SSH se niega a usar una llave privada que otros podrían leer. Arreglo: `chmod 600 llave` y `~/.ssh` en `700`. *(Clases 06 y 15.)*

**12.** `grep "Invalid user" archivo | awk '{print $(NF-2)}' | sort | uniq -c | sort -rn | head -3`. Contar los campos **desde el final** (`NF-2`, la antepenúltima palabra) funciona aunque cambie lo que hay delante. *(Clases 05 y 13.)*

**13.** Tu shell, que no es root, abre el archivo para el `>>` **antes** de ejecutar nada; `sudo` solo eleva a `echo`, que no toca el archivo. Así sí funciona: `echo "x" | sudo tee -a /etc/archivo`, porque quien abre el archivo es `tee`, que corre como root. *(Clases 04 y 10.)*

**14.** Los servicios no nacen de tu shell: son hijos de systemd, y `~/.bashrc` solo lo leen los shells interactivos. La variable va en la unit, con `Environment=VARIABLE=valor` (o `EnvironmentFile=`), y después `daemon-reload` y `restart`. *(Clases 07 y 12.)*

**15.** Una secuencia razonable, de lo general a lo concreto:
1. `curl -sI localhost` desde la propia VM: si responde, el problema está en la red o el firewall; si no, en el servicio.
2. `systemctl status nginx`: ¿activo, `failed`, desde cuándo?
3. `journalctl -u nginx -n 50 --no-pager` y `sudo tail /var/log/nginx/error.log`: el error concreto.
4. `sudo nginx -t`: ¿la configuración es válida?
5. `df -h`, `free -h` y `uptime`: ¿falta disco, memoria o CPU?

No hay un único orden correcto. Lo que importa es que cada comando responda una pregunta y que no cambies nada hasta saber qué pasa. *(Clases 12, 13 y 14.)*
</details>

## Siguiente

[Clase 16 — Tu primer script](clase-16-primer-script.md)
