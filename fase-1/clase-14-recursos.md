# Clase 14 — Recursos: CPU, memoria y disco

**Dónde:** VM `servidor-01` · **Tiempo:** 120 min (puedes partirla en dos sesiones) · **Bloque:** B. Administrar un servidor

## Objetivo

- Interpretar la **carga** (load average) y el uso de CPU, incluido el *steal* de la nube.
- Leer la memoria de verdad: `free`, `available`, cache, swap y el **OOM killer**.
- Diagnosticar un **disco lleno**, incluidos los dos casos traicioneros: inodos agotados y archivos borrados que siguen abiertos.
- Conectar, formatear, montar y ampliar un **disco nuevo**, como harás con un volumen EBS, sin poner en riesgo el arranque.

## Por qué importa

Las alarmas más comunes en CloudWatch son de CPU alta, memoria alta y disco lleno. Un disco lleno tumba bases de datos, impide escribir logs y rompe despliegues. Un proceso que agota la memoria muere sin dejar rastro en sus propios logs. Saber cuál de los tres recursos es el cuello de botella decide si **arreglas la app** o **cambias el tipo de instancia**.

## Teoría

### CPU y load average

```bash
uptime
# 10:00:00 up 2:13,  1 user,  load average: 0.52, 0.80, 1.10
#                                            1 min  5 min  15 min
```

La **carga** es el número medio de procesos que quieren CPU (en estado `R`) o esperan disco (en estado `D`). Se compara con el número de núcleos (`nproc`):

| Load / núcleos | Lectura |
|----------------|---------|
| < 0,7 | holgado |
| ≈ 1 | al límite |
| > 1 | hay cola: algo espera |

Si la carga es alta pero la CPU está ociosa, el problema suele ser el **disco** (procesos en `D`, mucho `wa` en `top`).

Línea `%Cpu(s)` de `top`:

| Campo | Significado |
|-------|-------------|
| `us` | tiempo de tus programas |
| `sy` | tiempo del kernel |
| `wa` | esperando disco (I/O wait) |
| `id` | ocioso |
| `st` | **steal**: el hipervisor dio tu CPU a otra VM. En la nube, un `st` alto indica una instancia sin créditos de CPU (familia `t3`) o un host saturado |

### Memoria

```bash
free -h
#        total   used   free   shared  buff/cache  available
# Mem:   962Mi   310Mi  120Mi  1Mi     532Mi       500Mi
```

- **free**: memoria sin usar para nada. Linux procura que sea poca: la RAM vacía es RAM desperdiciada.
- **buff/cache**: Linux usa la memoria libre como caché de disco y la **devuelve** cuando alguien la pide.
- **available**: lo que los programas pueden usar de verdad. **Esta es la columna que importa.**
- **swap**: disco usado como memoria extra. Es muy lento: si hay mucho swap en uso, la máquina se arrastra.

Si la memoria se agota, el kernel invoca al **OOM killer** (*Out Of Memory*): elige un proceso (normalmente el que más usa) y lo **mata con SIGKILL**. Ese proceso no deja nada en su log; la evidencia está en el **log del kernel**.

### Disco

| Comando | Responde a |
|---------|------------|
| `df -h` | ¿cuánto espacio queda en cada sistema de archivos? |
| `df -i` | ¿cuántos **inodos** quedan? |
| `du -sh dir` | ¿cuánto ocupa este directorio? |
| `du -xh / --max-depth=1 \| sort -h` | ¿dónde está el espacio? (`-x`: no cruzar a otros discos) |
| `lsblk` | discos y particiones |
| `lsof +L1` | archivos **borrados** que siguen abiertos |

Un **inodo** es la ficha de un archivo (permisos, dueño, dónde están sus datos). Cada sistema de archivos tiene un número fijo. Millones de archivos diminutos pueden agotarlos con gigas libres: `No space left on device` con `df -h` al 60 %.

Un mismo inodo puede tener **varios nombres**: los **enlaces duros** (`ln original otro-nombre`; `ls -li` muestra el número de inodo y cuántos nombres tiene). El espacio de un archivo solo se libera cuando desaparece su **último nombre** y **ningún proceso** lo tiene abierto. Un enlace simbólico (`ln -s`, clase 02) es otra cosa: un archivo pequeño que contiene una ruta.

Un archivo borrado que un proceso **sigue teniendo abierto** no libera su espacio hasta que ese proceso lo cierra. `df` dice "lleno", `du` no encuentra el espacio. Pasa constantemente con logs borrados a mano.

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

Lee cada error. nginx quizá siga respondiendo, porque leer no necesita espacio, pero no podrá escribir sus logs. Una base de datos, en cambio, dejaría de aceptar escrituras. Libera:

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

1. Escribe un **one-liner** de salud que imprima en una línea: carga del 1.er minuto, memoria `available` en MB y % de uso del disco `/`. (Pistas: `cut -d' ' -f1 /proc/loadavg`, `free -m | awk '/Mem/ {print $7}'`, `df --output=pcent / | tail -1`.) Será el embrión de tu proyecto P3.
2. ¿Qué tamaño tienen los 5 archivos más grandes de todo el sistema? (`sudo find / -xdev -type f -size +50M -exec ls -lh {} + 2>/dev/null | sort -k5 -h | tail -5`)
3. ¿Cuánto swap tiene la VM? Busca qué es `vm.swappiness` (`cat /proc/sys/vm/swappiness`).
4. Crea un archivo, hazle un enlace duro y un enlace simbólico, y borra el original. ¿Cuál de los dos sigue funcionando? Explícalo con `ls -li`.
5. ¿Qué pasaría si en el `fstab` del paso 7 no hubieras puesto `nofail` y el disco no estuviera al arrancar?

## Cierre

En `notas/fase-1/clase-14.md`:

1. La carga es 4,0 en una máquina de 2 núcleos, pero la CPU está al 10 %. ¿Qué sospechas y cómo lo confirmas?
2. Una app Java se reinicia sola de vez en cuando y en su log no hay ningún error. ¿Qué miras y qué buscas?
3. `df -h` dice 100 % en `/`, pero `du` solo suma la mitad. Explica las dos causas posibles que viste hoy y cómo distinguirlas.
4. **Repaso (clase 13, sin mirar):** ¿con qué comando ves los errores del arranque anterior del sistema?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La carga cuenta también los procesos que esperan **disco** (estado `D`). Con la CPU ociosa, la sospecha es I/O: un disco lento o saturado. Se confirma con `top` (`wa` alto), `vmstat 1` (columna `b` y `wa`), `iostat -x 1` (`%util` del disco) y `ps aux` buscando procesos en estado `D`. En AWS, un volumen EBS sin IOPS suficientes da exactamente este síntoma.

**2.** El **OOM killer**: `journalctl -k | grep -i "killed process"` o `dmesg -T | grep -i oom`. El proceso muere con SIGKILL y no puede escribir nada en su log. La línea del kernel dice qué proceso murió y cuánta memoria usaba. Después: ajustar la memoria de la app (el heap de Java), revisar si hay una fuga o elegir una instancia con más RAM.

**3.** (a) Un **archivo borrado pero abierto** por un proceso: `df` cuenta su espacio, `du` no lo ve. Se detecta con `lsof +L1` y se resuelve haciendo que el proceso lo cierre (reinicio o reapertura de logs). (b) Datos **ocultos bajo un punto de montaje**: si se escribió en `/mnt/datos` antes de montar el disco, esos archivos quedan tapados. (c) El espacio **reservado para root** (5 % en ext4) y los metadatos explican diferencias pequeñas. Las dos de hoy: el archivo fantasma (`lsof +L1`) y, si el error es "No space left" con espacio libre, los **inodos** (`df -i`).

**4.** `journalctl -b -1 -p err` (requiere journal persistente).

**Reto 1:**
```bash
echo "load=$(cut -d' ' -f1 /proc/loadavg) mem_avail=$(free -m | awk '/Mem/ {print $7}')MB disk=$(df --output=pcent / | tail -1 | tr -d ' ')"
```

**Reto 4:** el enlace **duro** sigue funcionando: es otro nombre del mismo inodo, y los datos no se liberan mientras quede un nombre. El **simbólico** queda roto: apuntaba a una ruta que ya no existe.

**Reto 5:** systemd esperaría al disco y, al no aparecer, el arranque fallaría y el sistema entraría en modo de emergencia. En una EC2, la instancia no llegaría a aceptar SSH, y habría que leer la consola del sistema y reparar `fstab` montando el disco raíz en otra instancia.
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
