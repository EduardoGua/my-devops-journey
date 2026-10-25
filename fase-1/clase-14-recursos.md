# Clase 14 — Recursos: CPU, memoria y disco

**Dónde:** VM `servidor-01` · **Tiempo:** 120 min (puedes partirla en dos sesiones) · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** un servidor tiene tres recursos que se agotan: la **CPU** (cuánto puede hacer a la vez), la **memoria** (lo que tiene a mano) y el **disco** (lo que guarda), como los fuegos, la encimera y la despensa de una cocina. Cuando algo va lento o se cae, la primera pregunta es cuál de los tres es el cuello de botella, porque la solución es distinta para cada uno.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los procesos, `kill` por PID y que `SIGKILL` no deja despedirse (clase 11).
> - `top` y `ps aux --sort` para ver qué gasta más (clase 11).
> - El log del kernel, `journalctl -k` (clase 13), y `/proc`, la ventana al kernel (clase 02).

> 🔤 **Palabras nuevas de hoy:**
> - **núcleo** (*core*): cada unidad de la CPU capaz de ejecutar un proceso a la vez.
> - **carga** (*load average*): cuántos procesos quieren CPU o esperan al disco, de media.
> - **caché** (de disco): datos del disco que Linux guarda en la memoria libre para leerlos rápido si los vuelves a pedir.
> - **swap**: disco usado como memoria de emergencia; muy lento.
> - **OOM killer**: el kernel matando un proceso porque se acabó la memoria.
> - **inodo**: el registro de cada archivo en el sistema de archivos (sus permisos, su dueño y dónde están sus datos).
> - **enlace duro** (*hard link*): un segundo nombre que apunta al mismo inodo.
> - **montar**: colgar un disco de una carpeta del árbol, como `/datos`.
> - **fstab** (`/etc/fstab`): el archivo que dice qué discos se montan automáticamente al encender el servidor.
> - **volumen EBS**: un disco de AWS que conectas a una instancia.

## Objetivo

- Interpretar la **carga** (load average) y el uso de CPU, incluido el *steal* de la nube.
- Leer la memoria de verdad: `free`, `available`, cache, swap y el **OOM killer**.
- Diagnosticar un **disco lleno**, incluidos los dos casos traicioneros: inodos agotados y archivos borrados que siguen abiertos.
- Conectar, formatear, montar y ampliar un **disco nuevo**, como harás con un volumen EBS, sin poner en riesgo el arranque.

## Por qué importa

Las alarmas más comunes en CloudWatch son de CPU alta, memoria alta y disco lleno. Un disco lleno tumba bases de datos, impide escribir logs y rompe despliegues. Un proceso que agota la memoria muere sin dejar rastro en sus propios logs. Saber cuál de los tres recursos es el cuello de botella decide si **arreglas la app** o **cambias el tipo de instancia**.

## Cómo va esta clase

Siete piezas: la CPU, la memoria, el disco y sus trampas. En cada una lees **una** idea y la pruebas enseguida en el servidor; no pases a la siguiente sin haber ejecutado la anterior.

Es una clase larga: hazla en dos mañanas. El primer día, las **piezas 1 a 3** (unos 50 min); el segundo, las **piezas 4 a 7**, el Rómpelo, el reto y el cierre.

Prepara la VM: entra, instala las herramientas de hoy y, desde tu PC, haz un snapshot por si algo sale mal:

```bash
multipass shell servidor-01
sudo apt install -y stress-ng sysstat lsof
exit
multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-recursos && multipass start servidor-01
multipass shell servidor-01
```

## Las piezas

### Pieza 1 — La CPU

Cada **núcleo** de CPU ejecuta un proceso a la vez (`nproc` te dice cuántos hay). La **carga** (*load average*) es cuántos procesos, de media, quieren CPU o están esperando al disco:

```bash
uptime
# 10:00:00 up 2:13,  1 user,  load average: 0.52, 0.80, 1.10
#                                            1 min  5 min  15 min
```

Las tres cifras son la media del último minuto, de los últimos 5 y de los últimos 15: te dicen si la cosa va a más o a menos. Se leen **comparadas con el número de núcleos**:

| Carga dividida entre núcleos | Lectura |
|------------------------------|---------|
| menos de 0,7 | holgado |
| cerca de 1 | todos los núcleos ocupados, al límite |
| más de 1 | hay procesos **esperando turno** |

Ojo: la carga cuenta también los procesos que esperan al disco (estado `D`). Por eso una carga alta con la CPU tranquila suele significar **disco lento**.

En `top` (y en `vmstat`), la línea `%Cpu(s)` reparte el tiempo de la CPU en cinco siglas:

| Campo | Significado |
|-------|-------------|
| `us` | CPU ocupada con tus programas |
| `sy` | CPU ocupada con el kernel |
| `wa` | CPU esperando al disco (*I/O wait*) |
| `id` | CPU libre |
| `st` | **steal**: el hipervisor (clase 08) dio tu tiempo de CPU a otra VM. En la nube, un `st` alto indica una instancia sin créditos de CPU (familia `t3`) o un servidor físico saturado |

**Pruébalo:**

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

👀 **Qué deberías ver:** en `top`, `us` cerca de 100 e `id` cerca de 0. Después, la carga del primer minuto todavía por encima de 1 (hacia 1,5) aunque `stress-ng` ya terminó: es una media. En `vmstat`, la columna `id` (CPU libre) cerca de 100.

✋ **Sin mirar:** una VM de 2 núcleos tiene una carga de 4. ¿Qué significa?

<details>
<summary>Comprueba</summary>

Que hay el doble de trabajo del que cabe en los núcleos: la mitad de los procesos espera turno (o espera al disco).
</details>

**En resumen:** compara la carga con el número de núcleos: por encima de 1 por núcleo, hay cola.

### Pieza 2a — Leer la memoria

```bash
free -h
#        total   used   free   shared  buff/cache  available
# Mem:   962Mi   310Mi  120Mi  1Mi     532Mi       500Mi
```

- **free**: memoria sin usar. Linux procura que haya poca: memoria vacía es memoria desperdiciada.
- **buff/cache**: Linux usa la memoria libre para guardar datos del disco que quizá vuelvas a pedir (una *caché* del disco), y los **libera** en cuanto un programa necesita sitio.
- **available**: lo que de verdad pueden usar los programas, contando lo que se puede retirar de la caché. **Esta es la columna que importa.**
- **swap**: cuando la memoria se llena, el kernel usa una parte del disco como memoria. Funciona, pero es lentísimo.

**Pruébalo:**

```bash
free -h
ps aux --sort=-%mem | head -5
```

👀 **Qué deberías ver:** cerca de 1 GB de memoria total, con `available` bastante mayor que `free`, y los 4 procesos que más memoria usan.

Consume memoria poco a poco y observa cómo baja `available`:

```bash
stress-ng --vm 1 --vm-bytes 400M --timeout 30s &
watch -n1 free -h
```

Sal de `watch` con `Ctrl+C`.

**En resumen:** en `free -h`, la columna que dice cuánta memoria queda de verdad es `available`, no `free`.

### Pieza 2b — El OOM killer

Si aun así la memoria se llena, el kernel llama al **OOM killer** (*Out Of Memory*): elige un proceso, normalmente el que más memoria usa, y lo **mata** con `SIGKILL` (clase 11). Ese proceso no llega a escribir nada en su log: la única pista queda en el **log del kernel**.

**Pruébalo:** **agota** la memoria.

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

👀 **Qué deberías ver:** una línea `Out of memory: Killed process … (python3)` que dice **qué proceso** murió y **cuánta memoria** usaba. Cuando una app "se reinicia sola sin errores en su log", lo primero que hay que mirar es esto.

✋ **Sin mirar:**
1. `free -h` dice `free 80Mi` y `available 600Mi`. ¿Falta memoria?
2. Una app se reinicia sola y su log no dice nada. ¿Qué sospechas?

<details>
<summary>Comprueba</summary>

1. No: lo que cuenta es `available`, y 600 MiB está bien. 2. El OOM killer: busca en el log del kernel.
</details>

**En resumen:** si una app muere sin dejar rastro en su propio log, busca al OOM killer en `journalctl -k`.

### Pieza 3 — El disco: cuánto queda y cuánto ocupa cada cosa

Dos preguntas, dos comandos:

```bash
df -h            # ¿cuánto sitio QUEDA en cada disco?
du -sh carpeta   # ¿cuánto OCUPA esta carpeta?
```

`df` pregunta al sistema de archivos cuánto espacio libre le queda, y `du` suma lo que ocupan los archivos de cada carpeta. Normalmente cuadran. Cuando no cuadran, hay una de las trampas de las piezas 5 y 7.

**Pruébalo:**

```bash
lsblk
df -h
df -i
sudo du -xh / --max-depth=1 2>/dev/null | sort -h
sudo du -sh /var/* 2>/dev/null | sort -h | tail -5
```

👀 **Qué deberías ver:** tu disco (por ejemplo `sda` o `vda`); el uso de `/` en espacio y en inodos (los verás en la pieza 6); y qué carpetas de `/` y de `/var` ocupan más (las más grandes, al final).

**En resumen:** `df` = cuánto queda; `du` = cuánto ocupa cada cosa.

> ⏸️ Fin del primer día. Para salir de la VM, `exit`.

### Pieza 4 — El disco lleno, y la reserva de root

Con el disco al 100 %, todo lo que necesita **escribir** falla. Pero ext4 guarda en reserva una parte del disco (un 5 % por defecto) que solo puede usar root, y `df` calcula el espacio disponible para usuarios normales. Así el sistema sigue en pie y tú puedes entrar a arreglarlo.

**Pruébalo:** llena el disco.

```bash
df -h /
sudo fallocate -l 50G /relleno 2>&1      # más de lo que hay
sudo fallocate -l $(df --output=avail -B1 / | tail -1) /relleno
df -h /
```

👀 **Qué deberías ver:** el primer `fallocate` falla (no hay 50 GB); el segundo crea un archivo con todo el espacio disponible para usuarios normales, y `df -h /` marca el 100 %.

🔮 **Predice:** con el disco al 100 %, ¿qué fallará?

```bash
echo hola > ~/prueba.txt
sudo apt install -y cowsay
logger "¿se escribe esto?"
curl -s -o /dev/null -w "%{http_code}\n" localhost
```

Lee cada error. nginx quizá siga respondiendo, porque leer no necesita espacio, pero no podrá escribir sus logs. Una base de datos, en cambio, dejaría de aceptar escrituras.

¿Algo de lo que corre como **root** (el `sudo apt`, el journal) sigue funcionando? No es un fallo del ejercicio: es la reserva de root. Mírala:

```bash
sudo tune2fs -l $(findmnt -no SOURCE /) | grep -i reserved
```

Libera:

```bash
sudo rm /relleno
df -h /
```

👀 **Qué deberías ver:** `Reserved block count` con un número de bloques (el 5 % del disco) y, después del `rm`, `/` otra vez con su espacio libre.

**En resumen:** con el disco lleno falla todo lo que escribe; la reserva de root deja que el sistema y tú sigáis funcionando para arreglarlo.

### Pieza 5 — Trampa 1: un archivo borrado que un proceso sigue usando

Si borras un archivo que un proceso tiene **abierto**, desaparece su nombre, pero el espacio no se libera hasta que ese proceso lo cierra. `df` dice «lleno» y `du` no encuentra nada. Pasa constantemente con logs borrados a mano. Se mira con `lsof +L1`.

**Pruébalo:**

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

👀 **Qué deberías ver:** `df` sigue contando los 2 GB y `du` no los encuentra. `lsof +L1` muestra el proceso que retiene el archivo borrado (`tail`), con `(deleted)` al final de la línea.

Para liberarlo, ese proceso tiene que cerrarlo: reiniciarlo, matarlo o, en servicios como nginx, enviarle la señal de reabrir logs. Mata **ese** proceso por su PID, el de la columna `PID` de `lsof`:

```bash
sudo kill <PID>
df -h /
```

**Lección:** para vaciar un log que está en uso no se borra: se **trunca**, con `sudo truncate -s 0 archivo` o `: | sudo tee archivo`. El proceso sigue escribiendo en el mismo archivo, que ahora está vacío.

**En resumen:** si `df` y `du` no cuadran, mira con `lsof +L1` si alguien sigue usando un archivo borrado. Los logs en uso se truncan, no se borran.

### Pieza 6 — Trampa 2: se acaban los inodos

Cada archivo necesita un **inodo**, un registro con sus permisos, su dueño y dónde están sus datos. El número de inodos es fijo. Con millones de archivos diminutos se acaban los inodos aunque quede espacio: `No space left on device` con `df -h` al 60 %. Se mira con `df -i`.

**Pruébalo:** un sistema de archivos diminuto en memoria, con solo 500 inodos.

```bash
sudo mkdir -p /mnt/mini
sudo mount -t tmpfs -o size=50M,nr_inodes=500 tmpfs /mnt/mini
df -h /mnt/mini; df -i /mnt/mini
cd /mnt/mini
for i in $(seq 1 600); do sudo touch archivo-$i || { echo "falló en el $i"; break; }; done
df -h /mnt/mini; df -i /mnt/mini
cd ~ && sudo umount /mnt/mini
```

(Un bucle: repite `touch` con `archivo-1` … `archivo-600` y se para en el primero que falle; los bucles, en la clase 18.)

👀 **Qué deberías ver:** `No space left on device` y `falló en el …` antes de llegar a 600, y al final `df -i` al 100 % mientras `df -h` casi no ha cambiado.

"No space left on device" con casi todo el espacio libre: se acabaron los inodos. Pasa con colas de correo, sesiones de PHP, cachés con millones de archivos o `node_modules` gigantes.

**En resumen:** si dice "No space left" con espacio libre, mira `df -i`: se acabaron los inodos.

### Pieza 7 — Montar un disco: datos tapados y `/etc/fstab`

En AWS, para añadir espacio a una instancia conectas un **volumen EBS**, le das formato (`mkfs`) y lo **montas** en una carpeta, por ejemplo `/datos`.

Ahí aparece la **segunda causa** de que `df -h` diga que `/` está lleno y `du` no encuentre el espacio: si alguien escribió archivos grandes dentro de `/datos` **antes** de montar el disco nuevo, el disco montado encima **tapa** lo que había en esa carpeta. Esos archivos siguen ocupando sitio en el disco raíz (`/`), pero `du` ya no los ve porque mira dentro del disco nuevo. Al desmontar (`sudo umount /datos`), reaparecen.

Para que un disco se monte solo al encender el servidor se añade a `/etc/fstab` con la opción **`nofail`** («si este disco no está, arranca igualmente»). Sin `nofail`, un volumen que falta o una línea mal escrita dejan al servidor **sin arrancar**, y en una EC2 no llega a aceptar conexiones por SSH. Después de tocar `/etc/fstab`, prueba siempre con `sudo mount -a` y `sudo findmnt --verify` antes de reiniciar.

**Pruébalo:** mira qué monta hoy tu VM al arrancar.

```bash
cat /etc/fstab
findmnt /
```

👀 **Qué deberías ver:** las líneas de `/etc/fstab` (discos, puntos de montaje y opciones) y qué dispositivo está montado en `/`.

> 📎 **Práctica guiada completa (opcional):** en [extra-disco-nuevo.md](extra-disco-nuevo.md) tienes el laboratorio paso a paso para crear un disco virtual, formatearlo (`mkfs.ext4`), ver cómo tapa un archivo al montarlo, añadirlo a `/etc/fstab` por UUID con `nofail` y ampliarlo en caliente con `resize2fs`.

**En resumen:** montar un disco encima de una carpeta con datos tapa esos datos (siguen ocupando en `/`, pero `du` no los ve); y en `/etc/fstab`, pon siempre `nofail` en los discos extra.

## Tu chuleta de la clase

| Recurso | Comandos |
|---------|----------|
| CPU | `nproc` (núcleos) · `uptime` (carga) · `top` (en vivo; `P` ordena por CPU) · `vmstat 1` (cada segundo) |
| Memoria | `free -h` · `ps aux --sort=-%mem \| head` (quién más usa) · `journalctl -k \| grep -i "killed process"` (el OOM killer) |
| Disco | `df -h` (lo que queda) · `df -i` (inodos que quedan) · `du -sh dir` (lo que ocupa) · `du -xh / --max-depth=1 \| sort -h` (dónde está el espacio; `-x`: sin cruzar a otros discos) · `lsblk` (discos y particiones) · `lsof +L1` (borrados pero abiertos) |
| Disco nuevo | `mkfs.ext4` (formato) · `mount` / `umount` · `blkid` (UUID) · `/etc/fstab` + `mount -a` + `findmnt --verify` · `resize2fs` (ampliar) |

## Rómpelo

Ya rompiste memoria y disco. Ahora haz el **diagnóstico a ciegas**. Guarda cuatro "sospechosos" en un archivo y deja que la máquina elija uno al azar sin decirte cuál:

```bash
cat > ~/sospechosos.sh <<'FIN'
stress-ng --cpu 2 --timeout 300s > /dev/null 2>&1 &
stress-ng --vm 1 --vm-bytes 700M --timeout 300s > /dev/null 2>&1 &
sudo fallocate -l $(( $(df --output=avail -B1 / | tail -1) - 300000000 )) /var/tmp/x   # línea de preparación: no hace falta entenderla
stress-ng --hdd 2 --timeout 300s > /dev/null 2>&1 &
FIN
sed -n "$(shuf -i 1-4 -n 1)p" ~/sospechosos.sh | bash
clear
```

Encuentra cuál fue (CPU, memoria, disco lleno o disco saturado de escrituras) con `uptime`, `top`, `free -h`, `df -h` y `vmstat 1`. Escribe tu razonamiento **antes** de comprobarlo con `pgrep -a stress-ng; ls -lh /var/tmp/x`. Limpia con `pkill stress-ng; sudo rm -f /var/tmp/x`. Hazlo dos veces (o baraja el orden sin repetir con `shuf -i 1-4 > ~/orden.txt` y ejecuta una línea por ronda).

## Reto

En la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Cuánto swap tiene la VM? Mira también el valor de `vm.swappiness` con `cat /proc/sys/vm/swappiness`.

> 🧩 **Ejemplo resuelto:** ¿cuánta memoria y cuánto swap tiene la VM?
> ```bash
> free -h
> ```
> La fila `Mem:` es la memoria. La de debajo es el swap: en la VM se llama `Swap:` (en tu PC, en español, sale como `Inter:`).

**Ahora tú, con huecos:**
```bash
free -h | grep ____
cat /proc/sys/vm/swappiness
```

<details>
<summary>Pista</summary>

Busca la fila del swap por su nombre. `swappiness` va de 0 a 100: cuanto más alto, antes empieza Linux a usar el swap.
</details>

**2.** ¿Qué pasaría si en `/etc/fstab` añades un disco extra sin `nofail` y ese disco no está al arrancar?

> 🧩 **Ejemplo resuelto:** mirar qué discos monta tu VM al encender.
> ```bash
> cat /etc/fstab
> ```
> Cada línea es un disco que se monta al arrancar. La cuarta columna son sus opciones: ahí es donde iría `nofail`.

**Ahora tú, con huecos:** `Sin nofail, si el disco no está, el arranque ____ y la EC2 no llega a aceptar conexiones por ____.`

<details>
<summary>Pista</summary>

Relee el párrafo de `nofail` de la pieza 7.
</details>

**3.** Escribe una línea que imprima la carga del último minuto, la memoria `available` en MB y el % de uso del disco `/`. Lo convertirás en un script de verdad en el bloque C.

> 🧩 **Ejemplo resuelto:** una línea con dos datos: tu usuario y la carga.
> ```bash
> echo "user=$(whoami) load=$(cut -d' ' -f1 /proc/loadavg)"
> ```
> Un `echo` con un `$( )` por cada dato. `cut -d' ' -f1 /proc/loadavg` saca el primer número de la carga.

**Ahora tú, con huecos:** `echo "load=$(cut -d' ' -f1 /proc/loadavg) mem=$(free -m | awk '/Mem/ {print $____}')MB disk=$(df --output=____ / | tail -1)"`

<details>
<summary>Pista</summary>

En la fila `Mem:` de `free -m`, `available` es la columna 7. Y la columna de `df` que da el porcentaje se llama `pcent`.
</details>

## Cierre

En `notas/fase-1/clase-14.md`:

1. La carga es 4,0 en una máquina de 2 núcleos, pero la CPU está al 10 %. ¿Qué sospechas y cómo lo confirmas? *(2–3 líneas. Empieza así: «Sospecho del disco, porque la carga cuenta también… Lo confirmaría con…»)*
2. Una app Java se reinicia sola de vez en cuando y en su log no hay ningún error. ¿Qué miras y qué buscas? *(2 líneas. Empieza así: «Miraría el log del kernel con…, buscando…, porque el OOM killer…»)*
3. `df -h` dice 100 % en `/`, pero `du` solo suma la mitad. Explica las dos causas posibles que viste hoy y cómo distinguirlas. *(3 líneas. Empieza así: «Una causa es un archivo borrado que… (lo veo con…). La otra…»)*
4. **Repaso (clase 13, sin mirar):** ¿con qué comando ves los errores del arranque anterior del sistema? *(1 línea con el comando. Empieza así: `journalctl -b …`)*

Después, escríbeme `examíname clase-14`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La carga cuenta también los procesos que esperan **disco** (estado `D`). Con la CPU ociosa, la sospecha es I/O: un disco lento o saturado. Se confirma con `top` (`wa` alto), `vmstat 1` (columna `b` y `wa`), `iostat -x 1` (`%util` del disco) y `ps aux` buscando procesos en estado `D`. En AWS, un volumen EBS sin IOPS suficientes da exactamente este síntoma.

**2.** El **OOM killer**: `journalctl -k | grep -i "killed process"` o `dmesg -T | grep -i oom`. El proceso muere con SIGKILL y no puede escribir nada en su log. La línea del kernel dice qué proceso murió y cuánta memoria usaba. Después: ajustar la memoria de la app (el heap de Java), revisar si hay una fuga o elegir una instancia con más RAM.

**3.** (a) Un **archivo borrado pero abierto** por un proceso: `df` cuenta su espacio, `du` no lo ve. Se detecta con `lsof +L1` y se resuelve haciendo que el proceso lo cierre (reinicio o reapertura de logs). (b) Datos **ocultos bajo un punto de montaje**: si se escribió en `/datos` antes de montar otro disco encima, esos archivos quedan tapados. (c) El espacio **reservado para root** (5 % en ext4) y los metadatos explican diferencias pequeñas. Las dos de hoy: un archivo borrado pero abierto (`lsof +L1`) y datos tapados por un montaje (desmontas y miras la carpeta).

**4.** `journalctl -b -1 -p err` (requiere journal persistente).

**Reto 1:** `Swap: 0B` (las VMs de Multipass vienen sin swap) y `swappiness` 60.

**Reto 2:** systemd esperaría al disco y, al no aparecer, el arranque fallaría y el sistema entraría en modo de emergencia. En una EC2, la instancia no llegaría a aceptar SSH, y habría que leer la consola del sistema y reparar `fstab` montando el disco raíz en otra instancia.

**Reto 3:**
```bash
echo "load=$(cut -d' ' -f1 /proc/loadavg) mem_avail=$(free -m | awk '/Mem/ {print $7}')MB disk=$(df --output=pcent / | tail -1 | tr -d ' ')"
```
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
