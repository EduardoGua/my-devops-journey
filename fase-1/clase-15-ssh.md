# Clase 15 — SSH a fondo

**Dónde:** tu Ubuntu + VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** B. Administrar un servidor

## Objetivo

- Entender cómo funciona SSH: llaves de usuario, llaves del servidor y `known_hosts`.
- Entrar en tu VM con **tu propia llave** y un alias cómodo en `~/.ssh/config`.
- **Endurecer** el servidor SSH sin quedarte fuera.
- Copiar archivos (`scp`, `rsync`) y crear **túneles** (`-L`) para llegar a servicios privados.
- Saber qué hacer si una llave privada se filtra.

## Por qué importa

SSH es la puerta de cada servidor Linux. En AWS, una EC2 se crea con un *key pair*, el *security group* decide quién llega al puerto 22 y un bastión con túneles da acceso a bases de datos en subredes privadas. Un SSH mal configurado (contraseñas activadas, root permitido, abierto a todo internet) es una de las vías de entrada más explotadas por los bots que viste en la clase 13.

## Teoría

### Dos pares de llaves

```
   TU PC (cliente)                                   SERVIDOR
   ~/.ssh/lab_ed25519      (privada: NUNCA sale)     /etc/ssh/ssh_host_ed25519_key     (privada del servidor)
   ~/.ssh/lab_ed25519.pub  (pública) ─── copiada ──► ~/.ssh/authorized_keys            ("estas llaves pueden entrar")
   ~/.ssh/known_hosts ◄──── recuerda ─────────────── /etc/ssh/ssh_host_ed25519_key.pub (pública del servidor)
```

1. **El servidor demuestra quién es** con su *host key*. La primera vez, tu cliente pregunta si confías en su huella (*fingerprint*) y la guarda en `known_hosts`. Si otro día la huella cambia, SSH **se niega a conectar** y avisa: podría ser un ataque *man-in-the-middle*, o simplemente un servidor reinstalado.
2. **Tú demuestras quién eres** con tu llave: el servidor te envía un reto, tu cliente lo **firma con la llave privada** y el servidor comprueba la firma con la pública de `authorized_keys`. La llave privada nunca viaja por la red.

Por eso **la pública se puede enseñar** (se pega en servidores, en GitHub, en AWS) y **la privada no**: quien la tiene **es** tú para esos servidores. Una *passphrase* cifra la privada en el disco, así que si te la roban no sirve sin la frase.

### Permisos obligatorios

SSH se niega a funcionar si los permisos son demasiado abiertos:

| Ruta | Permiso |
|------|---------|
| `~/.ssh/` | `700` |
| llave privada | `600` |
| `authorized_keys` | `600` (o `644`) |
| la casa del usuario | sin escritura para grupo ni otros |

### Configuración del servidor (`/etc/ssh/sshd_config`)

| Directiva | Valor seguro | Por qué |
|-----------|--------------|---------|
| `PasswordAuthentication` | `no` | Sin contraseñas, la fuerza bruta no tiene nada que adivinar |
| `PermitRootLogin` | `no` | Entras con tu usuario y elevas con sudo (que deja rastro) |
| `AllowUsers` | lista explícita | Solo esos usuarios pueden entrar |
| `MaxAuthTries` | `3` | Corta los intentos por conexión |

Ubuntu lee también los archivos de `/etc/ssh/sshd_config.d/*.conf`, y **la primera vez que aparece una directiva es la que gana**. Por eso las personalizaciones van en un archivo con un número bajo (`00-…`).

**Regla de supervivencia:** al cambiar la configuración de SSH, **mantén abierta una sesión** y prueba desde **otra**. Si te equivocas, todavía tienes la primera para arreglarlo. En una EC2 sin otra vía de acceso, un error aquí significa perder la instancia.

## Práctica guiada

En **tu PC**:
```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
```

### 1. Una llave solo para el laboratorio

```bash
ssh-keygen -t ed25519 -f ~/.ssh/lab_ed25519 -C "lab-servidor-01"
```

Pon una **passphrase**. Después:
```bash
ls -l ~/.ssh/lab_ed25519*
cat ~/.ssh/lab_ed25519.pub
```

Una línea: tipo, la llave y el comentario. Eso es lo único que viaja al servidor.

### 2. Instalar la pública en la VM

La imagen de Multipass no permite contraseñas, así que usamos `multipass exec` (en AWS, este paso lo hace el *key pair* al crear la instancia):

```bash
multipass exec servidor-01 -- bash -c "echo '$(cat ~/.ssh/lab_ed25519.pub)' >> ~/.ssh/authorized_keys"
multipass exec servidor-01 -- cat /home/ubuntu/.ssh/authorized_keys
```

Verás dos llaves: la de Multipass y la tuya.

### 3. Primera conexión

🔮 **Predice:** ¿qué te preguntará SSH la primera vez?

```bash
ssh -i ~/.ssh/lab_ed25519 ubuntu@$IP
```

Te muestra la **huella** del servidor. Compárala **antes de aceptar**. Desde otra terminal:
```bash
multipass exec servidor-01 -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```
Si coinciden, escribe `yes`. Después te pedirá la passphrase de tu llave. Sal con `exit` y mira lo que se guardó:
```bash
grep "$IP" ~/.ssh/known_hosts || ssh-keygen -F $IP
```

### 4. ssh-agent: la passphrase una sola vez

```bash
eval "$(ssh-agent -s)"     # en el escritorio de Ubuntu normalmente ya hay uno
ssh-add ~/.ssh/lab_ed25519
ssh-add -l
ssh -i ~/.ssh/lab_ed25519 ubuntu@$IP hostname
```

### 5. `~/.ssh/config`: alias

```bash
nano ~/.ssh/config
```
Añade (con la IP real):
```
Host servidor-01
    HostName 10.x.x.x
    User ubuntu
    IdentityFile ~/.ssh/lab_ed25519
    IdentitiesOnly yes
```
```bash
chmod 600 ~/.ssh/config
ssh servidor-01
```

Desde ahora, en todo el curso: `ssh servidor-01`.

### 6. Copiar archivos

```bash
echo "informe local" > /tmp/informe.txt
scp /tmp/informe.txt servidor-01:/tmp/
ssh servidor-01 cat /tmp/informe.txt
scp servidor-01:/etc/nginx/nginx.conf /tmp/nginx-de-la-vm.conf
mkdir -p /tmp/web && echo "<h1>Desplegado con rsync</h1>" > /tmp/web/index.html
rsync -avz /tmp/web/ servidor-01:/tmp/web/
rsync -avz /tmp/web/ servidor-01:/tmp/web/      # la 2.ª vez no copia nada: solo transfiere diferencias
```

### 7. Un túnel

`miapp` (clase 12) escucha en el puerto 8080 de la VM. Imagina que el firewall no deja llegar a él desde fuera:
```bash
ssh -N -L 9090:localhost:8080 servidor-01 &
curl -s localhost:9090
kill %1
```

Tu PC abrió su puerto **9090** y lo envió, cifrado, por SSH hasta el **8080** de la VM. Así se accede en AWS a una base de datos en una subred privada a través de un **bastión**: `ssh -L 5432:mi-db.xxxx.rds.amazonaws.com:5432 bastion`.

### 8. Endurecer el servidor

Abre **dos** terminales con `ssh servidor-01`. Trabaja en la primera; la segunda es tu red de seguridad.

```bash
sudo sshd -T | grep -Ei "^(passwordauthentication|permitrootlogin|pubkeyauthentication|maxauthtries)"
ls /etc/ssh/sshd_config.d/
```

Crea tu configuración:
```bash
sudo tee /etc/ssh/sshd_config.d/00-endurecido.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
AllowUsers ubuntu ana
EOF
sudo sshd -t && echo "sintaxis OK"
sudo systemctl restart ssh
```

Desde **tu PC**, en una terminal nueva:
```bash
ssh servidor-01 whoami                                      # debe funcionar
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no ubuntu@$IP   # debe rechazar
```

### 9. Acceso para Ana

Ana (clase 09) necesita entrar. Genera **su** llave (en la vida real la genera ella y te manda **solo la pública**):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ana_lab -N "" -C "ana"
```
En la VM:
```bash
sudo install -d -m 700 -o ana -g ana /home/ana/.ssh
echo "<pega aquí el contenido de ana_lab.pub>" | sudo tee /home/ana/.ssh/authorized_keys
sudo chown ana:ana /home/ana/.ssh/authorized_keys && sudo chmod 600 /home/ana/.ssh/authorized_keys
```
Desde tu PC:
```bash
ssh -i ~/.ssh/ana_lab -o IdentitiesOnly=yes ana@$IP whoami
```

## Rómpelo

**1. Permisos abiertos:**
```bash
sudo chmod 666 /home/ana/.ssh/authorized_keys      # en la VM
```
Desde tu PC: `ssh -i ~/.ssh/ana_lab -o IdentitiesOnly=yes ana@$IP` → rechazado. En la VM busca el motivo:
```bash
sudo journalctl -u ssh -n 10 --no-pager | grep -i -E "bad|mode|owner"
sudo chmod 600 /home/ana/.ssh/authorized_keys
```

**2. El servidor "cambió de identidad":**
En la VM, regenera las host keys (como si el servidor se hubiera reinstalado):
```bash
sudo rm /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server
sudo systemctl restart ssh
```
Desde tu PC: `ssh servidor-01`. Lee el aviso **entero** (`REMOTE HOST IDENTIFICATION HAS CHANGED`). Aquí, la causa la conoces y la provocaste tú. Si no la conocieras, **no se acepta sin investigar**. Comprueba la huella nueva por otra vía y después:
```bash
ssh-keygen -R $IP
ssh servidor-01
```

**3. Echarse a uno mismo:**
Con tu sesión de seguridad abierta, cambia `AllowUsers ubuntu ana` por `AllowUsers ana` en `00-endurecido.conf` y reinicia ssh. Intenta `ssh servidor-01` desde una terminal nueva: rechazado. **`multipass shell` también deja de funcionar**, porque usa SSH con el usuario `ubuntu` por debajo. Arréglalo **desde la sesión que dejaste abierta**:
```bash
sudo sed -i 's/^AllowUsers ana$/AllowUsers ubuntu ana/' /etc/ssh/sshd_config.d/00-endurecido.conf
sudo sshd -t && sudo systemctl restart ssh
```
Si hubieras cerrado todas las sesiones, la única salida sería restaurar un snapshot. En AWS: desmontar el disco y montarlo en otra instancia, o usar Session Manager si lo tenías configurado. Por eso en AWS se recomienda **SSM Session Manager**: no depende del puerto 22.

## Reto

1. Añade a `~/.ssh/config` una entrada `ana-lab` para entrar como Ana con `ssh ana-lab`.
2. Usa `rsync` para "desplegar" una carpeta local `web/` en `/var/www/html/` de la VM. (Pista: el usuario `ubuntu` no puede escribir ahí. Copia a `/tmp` y mueve con sudo, o usa `--rsync-path="sudo rsync"`.) Comprueba el resultado en el navegador con `http://IP`.
3. **Incidente simulado:** alguien sube por error la llave `ana_lab` (la privada) a un repo público. Escribe los pasos **en orden** para cerrar el incidente y ejecútalos en la VM.

## Cierre

En `notas/fase-1/clase-15.md`:

1. ¿Por qué la llave pública se puede compartir y la privada no? Explica qué hace cada una al conectar.
2. ¿Qué significa el aviso `REMOTE HOST IDENTIFICATION HAS CHANGED` y qué haces cuando lo ves?
3. Una llave privada se publicó en GitHub. ¿Por qué borrar el archivo del repo **no** cierra el incidente? ¿Qué pasos sí lo cierran?
4. **Repaso (clase 14, sin mirar):** `df` dice que el disco está lleno pero `du` no encuentra el espacio. ¿Qué compruebas?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La pública solo sirve para **verificar** firmas: el servidor la usa para comprobar que quien se conecta tiene la privada. Con ella no se puede entrar a ningún sitio. La privada **firma** el reto del servidor: quien la tenga puede hacerse pasar por ti en cada servidor (y en GitHub, o donde sea) que tenga tu pública. Por eso nunca sale de tu máquina, se protege con `600` y con una passphrase.

**2.** La huella (host key) del servidor no coincide con la que tu cliente guardó en `known_hosts`. Puede ser un ataque *man-in-the-middle* o un cambio legítimo (servidor reinstalado, IP reasignada a otra máquina, algo muy común en la nube). No se acepta a ciegas: se confirma por otra vía (consola de AWS, el administrador, `ssh-keygen -lf` desde una sesión de confianza) y solo entonces se borra la entrada vieja con `ssh-keygen -R host`.

**3.** Porque git guarda el **historial**: el archivo sigue en commits anteriores, en clones y en forks, y los bots escanean GitHub en busca de secretos en **minutos**. La llave debe considerarse comprometida. Pasos: (1) **revocarla**: quitar la pública de **todos** los `authorized_keys` (y de GitHub o AWS si estaba ahí); (2) generar un **par nuevo** e instalar la pública nueva; (3) **revisar los logs** de acceso (`journalctl -u ssh`, `auth.log`) por si alguien la usó; (4) después, limpiar el historial del repo. Lo esencial es **rotar**: lo publicado nunca se "despublica".

**4.** Un archivo borrado que sigue abierto por un proceso (`sudo lsof +L1`). Si el error es "No space left" con espacio libre, los inodos (`df -i`).

**Reto 3 (en la VM):**
```bash
sudo sed -i '/ ana$/d' /home/ana/.ssh/authorized_keys      # revocar la pública vieja (comentario "ana")
# en tu PC: ssh-keygen -t ed25519 -f ~/.ssh/ana_lab_v2 -C "ana-v2"   → instalar la nueva pública
sudo journalctl -u ssh --since "-7 days" --no-pager | grep "Accepted publickey for ana"
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| key pair | par de llaves |
| host key / fingerprint | llave del servidor / huella |
| passphrase | frase de paso |
| port forwarding / tunnel | reenvío de puertos / túnel |
| bastion host / jump host | bastión |
| to rotate a key | rotar una llave |

🎙️ *"If a private key leaks, deleting it from the repo isn't enough. I treat it as compromised: revoke it everywhere, issue a new key and check the access logs."*

## Fin del bloque B

Ya administras un servidor: usuarios, paquetes, procesos, servicios, logs, recursos y acceso seguro. El bloque C conecta servidores entre sí: **redes**.

## Siguiente

[Clase 16 — Cómo viaja una petición](clase-16-modelo-de-capas.md)
