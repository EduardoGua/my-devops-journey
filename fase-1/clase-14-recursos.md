# Clase 14 — Recursos: CPU, memoria y disco

**Dónde:** VM `servidor-01` · **Tiempo:** 120 min (puedes partirla en dos sesiones) · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** un servidor tiene tres recursos que se agotan. Imagínalo como una cocina: los **fuegos** son la CPU (cuánto puede hacer a la vez), la **encimera** es la memoria (lo que tiene a mano) y la **despensa** es el disco (lo que guarda). Cuando algo va lento o se cae, la primera pregunta es cuál de los tres es el cuello de botella, porque la solución es distinta para cada uno.

## Objetivo

- Interpretar la **carga** (load average) y el uso de CPU, incluido el *steal* de la nube.
- Leer la memoria de verdad: `free`, `available`, cache, swap y el **OOM killer**.
- Diagnosticar un **disco lleno**, incluidos los dos casos traicioneros: inodos agotados y archivos borrados que siguen abiertos.
- Conectar, formatear, montar y ampliar un **disco nuevo**, como harás con un volumen EBS, sin poner en riesgo el arranque.

## Por qué importa

Las alarmas más comunes en CloudWatch son de CPU alta, memoria alta y disco lleno. Un disco lleno tumba bases de datos, impide escribir logs y rompe despliegues. Un proceso que agota la memoria muere sin dejar rastro en sus propios logs. Saber cuál de los tres recursos es el cuello de botella decide si **arreglas la app** o **cambias el tipo de instancia**.

## Teoría

Cuatro piezas, con la cocina de *La idea de hoy*: los **fuegos** son la CPU, la **encimera** es la memoria y la **despensa** es el disco.

### 1. La CPU: los fuegos

Cada núcleo de CPU es un **fuego** de la cocina (`nproc` te dice cuántos hay). La **carga** (*load average*) es cuántos platos, de media, quieren fuego o están esperando algo de la despensa:

```bash
uptime
# 10:00:00 up 2:13,  1 user,  load average: 0.52, 0.80, 1.10
#                                            1 min  5 min  15 min
```

Las tres cifras son la media del último minuto, de los últimos 5 y de los últimos 15: te dicen si la cosa va a más o a menos. Se leen **comparadas con el número de fuegos**:

| Carga dividida entre núcleos | Lectura |
|------------------------------|---------|
| menos de 0,7 | holgado |
| cerca de 1 | todos los fuegos ocupados, al límite |
| más de 1 | hay platos **esperando turno** |

Ojo: la carga cuenta también los platos que esperan ingredientes de la despensa (procesos en estado `D`, esperando al disco). Por eso una carga alta con la CPU tranquila suele significar **disco lento**.

### 2. La memoria: la encimera

```bash
free -h
#        total   used   free   shared  buff/cache  available
# Mem:   962Mi   310Mi  120Mi  1Mi     532Mi       500Mi
```

- **free**: encimera vacía. Linux procura que haya poca: una encimera vacía es espacio desperdiciado.
- **buff/cache**: Linux pone en la encimera libre cosas de la despensa que quizá vuelvas a pedir (una *caché* del disco), y las **retira** en cuanto alguien necesita sitio.
- **available**: lo que de verdad pueden usar los programas, contando lo que se puede retirar de la caché. **Esta es la columna que importa.**
- **swap**: cuando la encimera se llena, apoyar cosas en el suelo del pasillo (usar el disco como memoria). Funciona, pero es lentísimo.

Si aun así la encimera se llena, el kernel llama al **OOM killer** (*Out Of Memory*): elige un plato, normalmente el que más espacio ocupa, y lo **tira a la basura** con `SIGKILL` (clase 11). Ese proceso no llega a escribir nada en su log: la única pista queda en el **log del kernel**.

### 3. El disco: la despensa

Dos preguntas, dos comandos:

```bash
df -h            # ¿cuánto sitio QUEDA en cada disco?
du -sh carpeta   # ¿cuánto OCUPA esta carpeta?
```

`df` mira la despensa desde fuera (cuánto cabe aún) y `du` cuenta lo que hay en cada estante. Normalmente cuadran. Cuando no cuadran, hay una de las dos trampas de la pieza 4.

### 4. Dos trampas del disco

**Trampa 1: se acaban las fichas.** Cada archivo necesita una **ficha** en el catálogo de la despensa, llamada **inodo** (sus permisos, su dueño, dónde están sus datos). El número de fichas es fijo. Con millones de archivos diminutos se acaban las fichas aunque los estantes estén medio vacíos: `No space left on device` con `df -h` al 60 %. Se mira con `df -i`.

**Trampa 2: tachado de la lista, pero alguien lo sigue usando.** Si borras un archivo que un proceso tiene **abierto**, desaparece su nombre, pero el espacio no se libera hasta que ese proceso lo cierra. `df` dice «lleno» y `du` no encuentra nada. Pasa constantemente con logs borrados a mano. Se mira con `lsof +L1`.

Relacionado con las fichas: una misma ficha puede tener **varios nombres**, que se llaman **enlaces duros** (`ln original otro-nombre`; `ls -li` muestra el número de ficha y cuántos nombres tiene). El espacio solo se libera cuando desaparece el **último nombre** y **nadie** tiene el archivo abierto. Un enlace simbólico (`ln -s`, clase 02) es otra cosa: un archivo pequeño que contiene una ruta, como un acceso directo.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Una VM de 2 núcleos tiene una carga de 4. ¿Qué significa?
2. `free -h` dice `free 80Mi` y `available 600Mi`. ¿Falta memoria?
3. Una app se reinicia sola y su log no dice nada. ¿Qué sospechas?

<details>
<summary>Comprueba</summary>

1. Que hay el doble de trabajo del que caben en los fuegos: la mitad de los procesos espera turno (o espera al disco). 2. No: lo que cuenta es `available`, y 600 MiB está bien. 3. El OOM killer: busca en el log del kernel.
</details>

### Tu chuleta de la clase

| Recurso | Comandos |
|---------|----------|
| CPU | `nproc` (núcleos) · `uptime` (carga) · `top` (en vivo; `P` ordena por CPU) · `vmstat 1` (cada segundo) |
| Memoria | `free -h` · `ps aux --sort=-%mem \| head` (quién más usa) · `journalctl -k \| grep -i "killed process"` (el OOM killer) |
| Disco | `df -h` (lo que queda) · `df -i` (fichas que quedan) · `du -sh dir` (lo que ocupa) · `du -xh / --max-depth=1 \| sort -h` (dónde está el espacio; `-x`: sin cruzar a otros discos) · `lsblk` (discos y particiones) · `lsof +L1` (borrados pero abiertos) |

La línea `%Cpu(s)` de `top`, en la cocina:

| Campo | Significado |
|-------|-------------|
| `us` | fuegos ocupados con tus programas |
| `sy` | fuegos ocupados con el kernel |
| `wa` | platos esperando a la despensa (*I/O wait*) |
| `id` | fuegos libres |
| `st` | **steal**: el hipervisor (clase 08) prestó tu fuego a otra VM. En la nube, un `st` alto indica una instancia sin créditos de CPU (familia `t3`) o un servidor físico saturado |

## Práctica guiada

```bash
multipass shell servidor-01
sudo apt install -y stress-ng sysstat lsof
```

Snapshot antes (desde tu PC): `multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-recursos && multipass start servidor-01`.

### 1. CPU

```bash
nproc
uptime
stress-ng --cpu 2 --timeout 90s &
top
```

🔮 **Predice:** con 1 núcleo y 2 procesos ocupando CPU, ¿hacia qué valor subirá la carga del primer minuto?

En `top`, observa `us`, `id` y la carga (arriba a la derecha). Sal con `q` y espera a que termine `stress-ng`. Después:

```bash
uptime
vmstat 1 5          # columnas r (en cola), us, sy, id, wa, st
```

### 2. Memoria

```bash
free -h
ps aux --sort=-%mem | head -5
```

Consume memoria poco a poco y observa:
```bash
stress-ng --vm 1 --vm-bytes 400M --timeout 30s &
watch -n1 free -h
```

`Ctrl+C` para salir de `watch`. Ahora **agota** la memoria:

🔮 **Predice:** ¿qué pasará al pedir más memoria de la que tiene la VM?

```bash
python3 -c "
datos = []
while True:
    datos.append(' ' * 50_000_000)   # +50 MB por vuelta
    print(len(datos) * 50, 'MB')
"
```

El programa muestra cifras hasta que termina con `Killed`. No hay ningún error de Python: lo mató el kernel. Busca la evidencia:

```bash
sudo journalctl -k --since "5 min ago" --no-pager | grep -iE "out of memory|killed process"
```

Esa línea dice **qué proceso** murió y **cuánta memoria** usaba. Cuando una app "se reinicia sola sin errores en su log", lo primero que hay que mirar es esto.

### 3. Disco: ¿dónde está el espacio?

```bash
lsblk
df -h
df -i
sudo du -xh / --max-depth=1 2>/dev/null | sort -h
sudo du -sh /var/* 2>/dev/null | sort -h | tail -5
```

### 4. Llenar el disco

```bash
df -h /
sudo fallocate -l 50G /relleno 2>&1      # más de lo que hay
sudo fallocate -l $(( $(df --output=avail -B1 / | tail -1) - 1000000 )) /relleno
df -h /
```

🔮 **Predice:** con el disco al 100 %, ¿qué fallará?

```bash
echo hola > ~/prueba.txt
sudo apt install -y cowsay
logger "¿se escribe esto?"
curl -s -o /dev/null -w "%{http_code}\n" localhost
```

Lee cada error. nginx quizá siga respondiendo, porque leer no necesita espacio, pero no podrá escribir sus logs. Una base de datos, en cambio, dejaría de aceptar escrituras.

¿Algo de lo que corre como **root** (el `sudo apt`, el journal) sigue funcionando? No es un fallo del ejercicio. `df` calcula el espacio disponible para usuarios normales, y ext4 guarda en reserva una parte del disco (un 5 % por defecto) que solo puede usar root. Así el sistema sigue en pie y tú puedes entrar a arreglarlo. Míralo con `sudo tune2fs -l $(findmnt -no SOURCE /) | grep -i reserved`.

Libera:

```bash
sudo rm /relleno
df -h /
```

### 5. El archivo fantasma

```bash
sudo fallocate -l 2G /var/log/enorme.log
df -h /
sudo tail -f /var/log/enorme.log > /dev/null &
sudo rm /var/log/enorme.log
df -h /
```

🔮 **Predice:** ¿ha vuelto el espacio?

```bash
sudo du -sh /var/log
sudo lsof +L1
```

`df` sigue contando los 2 GB y `du` no los encuentra. `lsof +L1` muestra el proceso que retiene el archivo borrado (`tail`). Para liberarlo, ese proceso tiene que cerrarlo: reiniciarlo, matarlo o, en servicios como nginx, enviarle la señal de reabrir logs.

Mata **ese** proceso por su PID, el de la columna `PID` de `lsof`:
```bash
sudo kill <PID>
df -h /
```

(¿Por qué no `sudo pkill -f "tail -f /var/log/enorme.log"`? Porque `pkill -f` busca el patrón en la línea de comandos **completa** de todos los procesos, y la del propio `sudo` que lanza el `pkill` también lo contiene. Puede acabar matando a tu propio `sudo`. Matar por el PID que te dio el diagnóstico es preciso.)

**Lección:** para vaciar un log que está en uso no se borra: se **trunca**, con `sudo truncate -s 0 archivo` o `: | sudo tee archivo`. El proceso sigue escribiendo en el mismo archivo, que ahora está vacío.

### 6. Inodos agotados

Un sistema de archivos diminuto en memoria, con solo 500 inodos:
```bash
sudo mkdir -p /mnt/mini
sudo mount -t tmpfs -o size=50M,nr_inodes=500 tmpfs /mnt/mini
df -h /mnt/mini; df -i /mnt/mini
cd /mnt/mini
for i in $(seq 1 600); do sudo touch archivo-$i 2>/dev/null || { echo "falló en el $i"; break; }; done
df -h /mnt/mini; df -i /mnt/mini
cd ~ && sudo umount /mnt/mini
```

"No space left on device" con casi todo el espacio libre: se acabaron los inodos. Pasa con colas de correo, sesiones de PHP, cachés con millones de archivos o `node_modules` gigantes.

### 7. Un disco nuevo: lo mismo que un volumen EBS

En AWS, para añadir espacio a una instancia creas un **volumen EBS** y lo conectas: aparece como un disco **vacío** (`/dev/nvme1n1`). Antes de usarlo hay que darle formato, montarlo y hacer el montaje permanente. En la VM simulamos ese disco con un archivo (un *loop device*):

```bash
sudo truncate -s 1G /var/tmp/volumen-ebs.img                        # el "volumen" de 1 GB
DEV=$(sudo losetup -fP --show /var/tmp/volumen-ebs.img); echo $DEV  # "conectarlo": aparece como /dev/loopN
lsblk
```

🔮 **Predice:** ¿puedes guardar algo ya en ese disco?

No: está en crudo, sin **sistema de archivos**. Dale formato y móntalo:
```bash
sudo mkfs.ext4 -L datos $DEV
sudo mkdir -p /datos
echo "escrito ANTES de montar" | sudo tee /datos/oculto.txt
sudo mount $DEV /datos
df -h /datos
ls /datos
```

¿Dónde está `oculto.txt`? El disco montado **tapa** lo que había en esa carpeta. El archivo sigue ocupando sitio en `/`, pero nadie lo ve mientras el montaje esté encima: es otra causa de "`df` y `du` no cuadran". Reaparecerá al desmontar.

Haz el montaje **permanente** en `/etc/fstab`, usando el **UUID**: los nombres de dispositivo pueden cambiar entre arranques, el UUID no.
```bash
sudo blkid $DEV
UUID=$(sudo blkid -s UUID -o value $DEV)
sudo cp /etc/fstab /etc/fstab.bak
echo "UUID=$UUID /datos ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo umount /datos
sudo mount -a              # monta todo lo de fstab: si hay un error, mejor verlo AHORA
findmnt /datos
sudo findmnt --verify      # revisa fstab entero
```

`nofail` significa "si este disco no está, arranca igualmente". Sin él, un volumen que falta o una línea mal escrita dejan al servidor **sin arrancar**, y en una EC2 no puedes entrar a arreglarlo (la consola del sistema de la clase 12 te dirá por qué). **Regla:** después de tocar `fstab`, siempre `sudo mount -a` y `sudo findmnt --verify` **antes** de reiniciar.

**Ampliar** el volumen (en AWS: *Modify volume* y después ampliar el sistema de archivos):
```bash
sudo truncate -s 2G /var/tmp/volumen-ebs.img   # el volumen crece
sudo losetup -c $DEV                           # el sistema se entera del nuevo tamaño
df -h /datos
```
🔮 ¿Muestra ya 2 GB? No: el **disco** creció, pero el **sistema de archivos** sigue igual.
```bash
sudo resize2fs $DEV
df -h /datos
```
En una EC2 con particiones, el orden es `growpart` (ampliar la partición) y después `resize2fs` (ext4) o `xfs_growfs` (XFS, el de Amazon Linux). Es una tarea real habitual y una pregunta de entrevista.

Limpia, en este orden:
```bash
sudo umount /datos
ls /datos                               # oculto.txt reaparece
sudo cp /etc/fstab.bak /etc/fstab       # quita la línea de fstab ANTES de quitar el disco
sudo losetup -d $DEV
sudo rm /var/tmp/volumen-ebs.img /datos/oculto.txt
sudo findmnt --verify
```

## Rómpelo

Ya rompiste memoria y disco. Ahora haz el **diagnóstico a ciegas**. Guarda cuatro "sospechosos" en un archivo y deja que la máquina elija uno al azar sin decirte cuál:

```bash
cat > ~/sospechosos.sh <<'FIN'
stress-ng --cpu 2 --timeout 300s > /dev/null 2>&1 &
stress-ng --vm 1 --vm-bytes 700M --timeout 300s > /dev/null 2>&1 &
sudo fallocate -l $(( $(df --output=avail -B1 / | tail -1) - 300000000 )) /var/tmp/x
stress-ng --hdd 2 --timeout 300s > /dev/null 2>&1 &
FIN
sed -n "$(shuf -i 1-4 -n 1)p" ~/sospechosos.sh | bash
clear
```

Encuentra cuál fue (CPU, memoria, disco lleno o disco saturado de escrituras) con `uptime`, `top`, `free -h`, `df -h` y `vmstat 1`. Escribe tu razonamiento **antes** de comprobarlo con `pgrep -a stress-ng; ls -lh /var/tmp/x`. Limpia con `pkill stress-ng; sudo rm -f /var/tmp/x` y repite hasta acertar los cuatro.

## Reto

En la VM. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Crea un archivo, hazle un enlace duro y un enlace simbólico, y borra el original. ¿Cuál de los dos enlaces sigue funcionando? Explícalo con `ls -li`.

<details>
<summary>Pista</summary>

`ln original duro` y `ln -s original simbolico`. Después `rm original` y prueba `cat duro` y `cat simbolico`. `ls -li` enseña el número de ficha (inodo) de cada uno.
</details>

**2.** ¿Cuánto swap tiene la VM? Mira también el valor de `vm.swappiness` con `cat /proc/sys/vm/swappiness`.

<details>
<summary>Pista</summary>

El swap sale en la segunda línea de `free -h`. `swappiness` va de 0 a 100: cuanto más alto, antes empieza Linux a usar el swap.
</details>

**3.** ¿Qué pasaría si en el `fstab` del paso 7 no hubieras puesto `nofail` y el disco no estuviera al arrancar?

<details>
<summary>Pista</summary>

Relee el párrafo de `nofail` del paso 7.
</details>

**4.** Escribe una línea que imprima la carga del último minuto, la memoria `available` en MB y el % de uso del disco `/`. Lo convertirás en un script de verdad en el bloque C.

<details>
<summary>Pista</summary>

Un `echo` con tres `$( )`, uno por dato: `echo "load=$(…) mem=$(…)MB disk=$(…)"`. Las tres piezas: `cut -d' ' -f1 /proc/loadavg`, `free -m | awk '/Mem/ {print $7}'` y `df --output=pcent / | tail -1`. Prueba cada pieza por separado antes de juntarlas.
</details>

**5.** ¿Qué tamaño tienen los 5 archivos más grandes de todo el sistema? Ejecuta `sudo find / -xdev -type f -size +50M -exec ls -lh {} + 2>/dev/null | sort -k5 -h | tail -5` y explica cada pieza.

<details>
<summary>Pista</summary>

Aquí no se pide inventarlo, sino leerlo: `find` busca archivos de más de 50 MB sin salir de este disco (`-xdev`); `-exec ls -lh {} +` los muestra con su tamaño; `sort -k5 -h` ordena por la columna 5 (el tamaño) entendiendo K, M y G; `tail -5` se queda con los 5 últimos, los más grandes.
</details>

## Cierre

En `notas/fase-1/clase-14.md`:

1. La carga es 4,0 en una máquina de 2 núcleos, pero la CPU está al 10 %. ¿Qué sospechas y cómo lo confirmas?
2. Una app Java se reinicia sola de vez en cuando y en su log no hay ningún error. ¿Qué miras y qué buscas?
3. `df -h` dice 100 % en `/`, pero `du` solo suma la mitad. Explica las dos causas posibles que viste hoy y cómo distinguirlas.
4. **Repaso (clase 13, sin mirar):** ¿con qué comando ves los errores del arranque anterior del sistema?

Después, escríbeme `examíname clase-14`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La carga cuenta también los procesos que esperan **disco** (estado `D`). Con la CPU ociosa, la sospecha es I/O: un disco lento o saturado. Se confirma con `top` (`wa` alto), `vmstat 1` (columna `b` y `wa`), `iostat -x 1` (`%util` del disco) y `ps aux` buscando procesos en estado `D`. En AWS, un volumen EBS sin IOPS suficientes da exactamente este síntoma.

**2.** El **OOM killer**: `journalctl -k | grep -i "killed process"` o `dmesg -T | grep -i oom`. El proceso muere con SIGKILL y no puede escribir nada en su log. La línea del kernel dice qué proceso murió y cuánta memoria usaba. Después: ajustar la memoria de la app (el heap de Java), revisar si hay una fuga o elegir una instancia con más RAM.

**3.** (a) Un **archivo borrado pero abierto** por un proceso: `df` cuenta su espacio, `du` no lo ve. Se detecta con `lsof +L1` y se resuelve haciendo que el proceso lo cierre (reinicio o reapertura de logs). (b) Datos **ocultos bajo un punto de montaje**: si se escribió en `/mnt/datos` antes de montar el disco, esos archivos quedan tapados. (c) El espacio **reservado para root** (5 % en ext4) y los metadatos explican diferencias pequeñas. Las dos de hoy: el archivo fantasma (`lsof +L1`) y, si el error es "No space left" con espacio libre, los **inodos** (`df -i`).

**4.** `journalctl -b -1 -p err` (requiere journal persistente).

**Reto 4:**
```bash
echo "load=$(cut -d' ' -f1 /proc/loadavg) mem_avail=$(free -m | awk '/Mem/ {print $7}')MB disk=$(df --output=pcent / | tail -1 | tr -d ' ')"
```

**Reto 1:** el enlace **duro** sigue funcionando: es otro nombre del mismo inodo, y los datos no se liberan mientras quede un nombre. El **simbólico** queda roto: apuntaba a una ruta que ya no existe.

**Reto 3:** systemd esperaría al disco y, al no aparecer, el arranque fallaría y el sistema entraría en modo de emergencia. En una EC2, la instancia no llegaría a aceptar SSH, y habría que leer la consola del sistema y reparar `fstab` montando el disco raíz en otra instancia.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| load average | carga media |
| I/O wait | espera de entrada/salida |
| CPU steal | CPU robada por el hipervisor |
| out of memory (OOM) killer | asesino por falta de memoria |
| inode | inodo |
| disk full | disco lleno |
| volume / to mount | volumen / montar |
| filesystem | sistema de archivos |
| hard link / symbolic link | enlace duro / simbólico |

🎙️ *"When the disk looks full but `du` doesn't add up, I check for deleted files still held open with `lsof +L1`, and for inode exhaustion with `df -i`."*

## Siguiente

[Clase 15 — SSH a fondo](clase-15-ssh.md)
