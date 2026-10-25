# Extra (Clase 14) — Conectar, montar y ampliar un disco nuevo

**Dónde:** VM `servidor-01` · **Tiempo:** 25 min · **Cuándo:** opcional al terminar la [Clase 14](clase-14-recursos.md), o antes de la fase 6 (EBS)

> 💡 **La idea:** en AWS, para añadir espacio a una instancia creas un **volumen EBS** y lo conectas: aparece como un disco **vacío** (`/dev/nvme1n1`). Antes de usarlo hay que darle formato (`mkfs`), montarlo (`mount`) y dejar el montaje en `/etc/fstab` con `nofail` para que sobreviva a un reinicio sin poner en riesgo el arranque. En la VM simulamos ese disco con un archivo (un *loop device*).

## Paso 1 — Crear y «conectar» el disco

```bash
sudo truncate -s 1G /var/tmp/volumen-ebs.img                        # el "volumen" de 1 GB
DEV=$(sudo losetup -fP --show /var/tmp/volumen-ebs.img); echo $DEV  # "conectarlo": aparece como /dev/loopN
lsblk
```

🔮 **Predice:** ¿puedes guardar algo ya en ese disco?

No: está en crudo, sin **sistema de archivos**.

## Paso 2 — Formatear y montar (y ver cómo un montaje tapa datos)

Dale formato y móntalo sobre `/datos` habiendo dejado antes un archivo dentro:

```bash
sudo mkfs.ext4 -L datos $DEV
sudo mkdir -p /datos
echo "escrito ANTES de montar" | sudo tee /datos/oculto.txt
sudo mount $DEV /datos
df -h /datos
ls /datos
```

👀 **Qué deberías ver:** `/datos` con cerca de 1 GB, y en `ls` solo `lost+found`.

¿Dónde está `oculto.txt`? El disco montado **tapa** lo que había en esa carpeta. El archivo sigue ocupando sitio en `/`, pero nadie lo ve mientras el montaje esté encima: es la segunda causa de que `df` y `du` no cuadren. Reaparecerá al desmontar.

## Paso 3 — Hacer el montaje permanente en `/etc/fstab` con `nofail`

Usa siempre el **UUID** del sistema de archivos: los nombres de dispositivo (`/dev/loopN`, `/dev/nvme1n1`) pueden cambiar entre arranques; el UUID no.

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

`nofail` significa «si este disco no está, arranca igualmente». Sin él, un volumen que falta o una línea mal escrita dejan al servidor **sin arrancar**, y en una EC2 no puedes entrar por SSH a arreglarlo (la consola del sistema de la clase 12 te dirá por qué).

**Regla:** después de tocar `/etc/fstab`, ejecuta siempre `sudo mount -a` y `sudo findmnt --verify` **antes** de reiniciar.

## Paso 4 — Ampliar el volumen en caliente (`resize2fs`)

En AWS amplías el volumen con *Modify volume* y después estiras el sistema de archivos:

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

👀 **Qué deberías ver:** ahora sí, `/datos` con cerca de 2 GB.

En una EC2 con particiones, el orden es `growpart` (ampliar la partición) y después `resize2fs` (ext4) o `xfs_growfs` (XFS, el de Amazon Linux). Es una tarea real habitual y una pregunta frecuente de entrevista.

## Paso 5 — Limpiar

En este orden:

```bash
sudo umount /datos
ls /datos                               # oculto.txt reaparece
sudo cp /etc/fstab.bak /etc/fstab       # quita la línea de fstab ANTES de quitar el disco
sudo losetup -d $DEV
sudo rm /var/tmp/volumen-ebs.img /datos/oculto.txt
sudo findmnt --verify
```

**En resumen:** un disco nuevo necesita formato (`mkfs`), montaje (`mount`) y una línea en `/etc/fstab` con su UUID y `nofail`; al ampliarlo, crece primero el disco y después el sistema de archivos (`resize2fs`).

## Volver

[Clase 14 — Recursos: CPU, memoria y disco](clase-14-recursos.md)
