# Clase 15 — SSH a fondo

**Dónde:** tu Ubuntu + VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** para entrar por SSH demuestras quién eres **firmando** con tu llave **privada**, que nunca sale de tu PC. Tu llave **pública**, que dejas en cada servidor, sirve para **comprobar** esa firma, pero no para firmar. Y el servidor también se identifica con su propia llave (su *host key*, que reconoces por su *huella*), para que sepas que no hablas con un impostor.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los permisos `700` y `600`, y que `~/.ssh` ya existe en tu PC (clase 06).
> - Ana y Luis en la VM (clase 09), y los intentos de entrada de bots que viste en el journal (clase 13).
> - `systemctl restart` y `journalctl -u` sobre el servicio `ssh` (clases 12 y 13).

> 🔤 **Palabras nuevas de hoy:**
> - **par de llaves**: la privada (firma) y la pública (comprueba la firma).
> - **passphrase**: la contraseña que protege tu llave privada en el disco.
> - **host key**: el par de llaves con el que se identifica un servidor.
> - **huella** (*fingerprint*): un resumen corto que identifica la host key de un servidor.
> - **known_hosts**: la lista de servidores que tu PC ya conoce.
> - **túnel**: llevar un puerto de tu PC hasta otro de un servidor, a través de SSH.
> - **bastión**: un servidor que hace de puerta para llegar a otros que no están en internet.

## Objetivo

- Entender cómo funciona SSH: llaves de usuario, llaves del servidor y `known_hosts`.
- Entrar en tu VM con **tu propia llave** y un alias cómodo en `~/.ssh/config`.
- **Endurecer** el servidor SSH sin quedarte fuera.
- Copiar archivos (`scp`, `rsync`) y crear **túneles** (`-L`) para llegar a servicios privados.
- Saber qué hacer si una llave privada se filtra.

## Por qué importa

SSH es la puerta de cada servidor Linux. En AWS, una EC2 se crea con un *key pair*, el *security group* decide quién llega al puerto 22 y un bastión con túneles da acceso a bases de datos en subredes privadas. Un SSH mal configurado (contraseñas activadas, root permitido, abierto a todo internet) es una de las vías de entrada más explotadas por los bots que viste en la clase 13.

## Cómo va esta clase

Siete piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Hoy trabajas sobre todo desde **tu PC**, conectándote a la VM: mira el prompt para saber dónde estás.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 45 min); el segundo, las **piezas 5 a 7**, el Rómpelo, el reto y el cierre.

Primero, en **tu PC**, guarda la IP de la VM en una variable (si partes la clase, repítelo el segundo día):

```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
```

## Las piezas

### Pieza 1 — La llave privada y la pública

Cuando creas un par de llaves, obtienes dos archivos que van juntos:
- la **privada** (`lab_ed25519`): la que **firma**. Solo la tienes tú;
- la **pública** (`lab_ed25519.pub`): la que **comprueba** esas firmas. Se puede enseñar a cualquiera: la pegas en los servidores, en GitHub o en AWS.

Al conectarte, el servidor te pone delante un documento único (un *reto*); tu PC lo **firma** con la privada y el servidor **comprueba** la firma con la llave pública que guarda en `~/.ssh/authorized_keys`. Si coinciden, entras. La privada **nunca viaja por la red**: solo viaja la firma de ese documento.

Por eso la pública no es peligrosa (con ella no se puede firmar) y la privada sí: quien la tenga **es** tú para todos esos servidores. Una *passphrase* la protege en el disco: si te la roban, no sirve sin la frase.

**Pruébalo: una llave solo para el laboratorio.**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/lab_ed25519 -C "lab-servidor-01"
```

Pon una **passphrase**. Después:

```bash
ls -l ~/.ssh/lab_ed25519*
cat ~/.ssh/lab_ed25519.pub
```

👀 **Qué deberías ver:** dos archivos, la privada (`-rw-------`) y la `.pub` (`-rw-r--r--`), y una sola línea que empieza por `ssh-ed25519` y termina en `lab-servidor-01`: el tipo, la llave y el comentario. Eso es lo único que viaja al servidor.

**Ahora instala la pública en la VM.** La imagen de Multipass no permite contraseñas, así que usamos `multipass exec` (en AWS, este paso lo hace el *key pair* al crear la instancia):

```bash
multipass exec servidor-01 -- bash -c "echo '$(cat ~/.ssh/lab_ed25519.pub)' >> ~/.ssh/authorized_keys"
multipass exec servidor-01 -- cat /home/ubuntu/.ssh/authorized_keys
```

👀 **Qué deberías ver:** dos líneas: la llave de Multipass y la tuya, que acaba en `lab-servidor-01`.

✋ **Sin mirar:** ¿qué archivo pegas en el servidor: la llave pública o la privada?

<details>
<summary>Comprueba</summary>

La **pública** (`.pub`). La privada nunca sale de tu PC.
</details>

**En resumen:** la privada firma y nunca sale de tu PC; la pública, que dejas en los servidores, comprueba la firma.

### Pieza 2 — El servidor también se identifica: la *host key*

El servidor tiene su propio par de llaves, su **host key**. La primera vez que te conectas, tu PC te enseña la **huella** (*fingerprint*) de esa llave y te pregunta si te fías. Si dices que sí, la apunta en `~/.ssh/known_hosts`.

Las siguientes veces la compara. Si un día la huella **cambia**, SSH se niega a conectar y avisa a gritos: podría ser un impostor en medio (un ataque *man-in-the-middle*) o, simplemente, un servidor reinstalado. Nunca se acepta sin averiguar cuál de las dos es.

Las llaves de las piezas 1 y 2, juntas:

```
   TU PC (cliente)                                   SERVIDOR
   ~/.ssh/lab_ed25519      (privada: NUNCA sale)     /etc/ssh/ssh_host_ed25519_key     (privada del servidor)
   ~/.ssh/lab_ed25519.pub  (pública) ─── copiada ──► ~/.ssh/authorized_keys            ("estas llaves pueden entrar")
   ~/.ssh/known_hosts ◄──── recuerda ─────────────── /etc/ssh/ssh_host_ed25519_key.pub (pública del servidor)
```

**Pruébalo: la primera conexión.** 🔮 **Predice:** ¿qué te preguntará SSH la primera vez?

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

👀 **Qué deberías ver:** la misma huella (`SHA256:…`) en las dos terminales y, al final, la línea de `known_hosts` con la IP de la VM.

✋ **Sin mirar:** SSH te avisa de que la huella del servidor ha cambiado. ¿Qué haces?

<details>
<summary>Comprueba</summary>

No aceptar a ciegas: averiguar si el servidor se reinstaló, comprobando la huella por otra vía, y solo entonces borrar la vieja (`ssh-keygen -R IP`).
</details>

**En resumen:** la primera vez apuntas la host key del servidor; si un día cambia, no aceptes sin averiguar por qué.

### Pieza 3 — SSH es estricto con los permisos

Si alguien más pudiera leer tu llave privada o cambiar la lista de llaves públicas autorizadas (`authorized_keys`), SSH no se fía y se niega a funcionar. Exige (clase 06):

| Ruta | Permiso |
|------|---------|
| `~/.ssh/` | `700` |
| llave privada | `600` |
| `authorized_keys` | `600` (o `644`) |
| la casa del usuario | sin escritura para grupo ni otros |

**Pruébalo**, en tu PC y en la VM:

```bash
ls -ld ~/.ssh
ls -l ~/.ssh
multipass exec servidor-01 -- ls -la /home/ubuntu/.ssh
```

👀 **Qué deberías ver:** `~/.ssh` en `drwx------` (700), las llaves privadas en `-rw-------` (600) y las `.pub` en `-rw-r--r--`; en la VM, `authorized_keys` en `-rw-------`.

**En resumen:** `~/.ssh` en `700` y la llave privada en `600`: si no, SSH no se fía.

### Pieza 4 — El agente y los alias: menos que escribir

Dos ayudas que usarás a diario:
- **`ssh-agent`** guarda tu llave ya desbloqueada mientras dura la sesión: escribes la passphrase **una sola vez**.
- **`~/.ssh/config`** guarda alias: en vez de `ssh -i ~/.ssh/lab_ed25519 ubuntu@10.x.x.x`, escribes `ssh servidor-01`.

**Pruébalo, primero el agente:**

```bash
eval "$(ssh-agent -s)"     # en el escritorio de Ubuntu normalmente ya hay uno
ssh-add ~/.ssh/lab_ed25519
ssh-add -l
ssh -i ~/.ssh/lab_ed25519 ubuntu@$IP hostname
```

👀 **Qué deberías ver:** `Identity added…`, tu llave en la lista del agente, y `servidor-01` sin que te pida la passphrase.

**Ahora el alias:**

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

👀 **Qué deberías ver:** el prompt `ubuntu@servidor-01`, sin escribir ni el usuario, ni la IP, ni la llave. Sal con `exit`.

Desde ahora, en todo el curso: `ssh servidor-01`.

**En resumen:** `ssh-add` te ahorra la passphrase y `~/.ssh/config` te ahorra escribir usuario, IP y llave.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 5 — Copiar archivos y abrir un túnel

SSH no solo abre un shell remoto: también **copia archivos** (`scp`, y `rsync`, que solo copia lo que cambió) y **lleva un puerto** de tu PC hasta el servidor, cifrado (un **túnel**, `ssh -L`).

**Pruébalo, primero copiando:**

```bash
echo "informe local" > /tmp/informe.txt
scp /tmp/informe.txt servidor-01:/tmp/
ssh servidor-01 cat /tmp/informe.txt
scp servidor-01:/etc/nginx/nginx.conf /tmp/nginx-de-la-vm.conf
mkdir -p /tmp/web && echo "<h1>Desplegado con rsync</h1>" > /tmp/web/index.html
rsync -avz /tmp/web/ servidor-01:/tmp/web/
rsync -avz /tmp/web/ servidor-01:/tmp/web/      # la 2.ª vez no copia nada: solo transfiere diferencias
```

👀 **Qué deberías ver:** `informe local`; la copia de `nginx.conf` en tu `/tmp`; y, en el segundo `rsync`, ningún archivo en la lista: no había nada nuevo que copiar.

**Ahora un túnel.** `miapp` (clase 12) escucha en el puerto 8080 de la VM. Imagina que el firewall no deja llegar a él desde fuera:

```bash
ssh -N -L 9090:localhost:8080 servidor-01 &
curl -s localhost:9090
kill %1
```

👀 **Qué deberías ver:** `<h1>Mi app en servidor-01</h1>`: tu PC llegó al puerto 8080 de la VM por el túnel.

Tu PC abrió su puerto **9090** y lo envió, cifrado, por SSH hasta el **8080** de la VM. Así se accede en AWS a una base de datos en una subred privada a través de un **bastión**: `ssh -L 5432:mi-db.xxxx.rds.amazonaws.com:5432 bastion`.

**En resumen:** `scp` copia, `rsync` sincroniza (solo lo que cambia) y `ssh -L` lleva un puerto de tu PC hasta el servidor.

### Pieza 6 — Endurecer el servidor SSH

La configuración del servidor SSH está en `/etc/ssh/sshd_config`. Cuatro ajustes la hacen mucho más segura:

| Directiva | Valor seguro | Por qué |
|-----------|--------------|---------|
| `PasswordAuthentication` | `no` | Sin contraseñas, la fuerza bruta no tiene nada que adivinar |
| `PermitRootLogin` | `no` | Entras con tu usuario y elevas con sudo (que deja rastro) |
| `AllowUsers` | lista explícita | Solo esos usuarios pueden entrar |
| `MaxAuthTries` | `3` | Corta los intentos por conexión |

Ubuntu lee también los archivos de `/etc/ssh/sshd_config.d/*.conf`, y **la primera vez que aparece un ajuste es la que gana**. Por eso tus cambios van en un archivo con un número bajo (`00-…`).

**Regla de supervivencia:** al cambiar la configuración de SSH, **deja abierta una sesión** y prueba desde **otra**. Si te equivocas, aún tienes la primera para arreglarlo. En una EC2 sin otra forma de entrar, un error aquí significa perder la instancia.

**Pruébalo.** Abre **dos** terminales con `ssh servidor-01`. Trabaja en la primera; la segunda es tu sesión de seguridad.

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

👀 **Qué deberías ver:** `ubuntu` en el primero, y `Permission denied (publickey)` en el segundo.

✋ **Sin mirar:** vas a desactivar las contraseñas en el servidor SSH. ¿Qué haces antes de reiniciar el servicio?

<details>
<summary>Comprueba</summary>

Dejar abierta una sesión de seguridad y probar desde otra (y revisar la sintaxis con `sudo sshd -t`).
</details>

**En resumen:** sin contraseñas, sin root y solo los usuarios de la lista. Y siempre con una sesión de seguridad abierta.

### Pieza 7 — Acceso para otra persona: la llave de Ana

Para dar acceso a alguien, **esa persona** crea su par de llaves y te manda **solo la pública**. Tú la pones en el `authorized_keys` de **su** usuario, con los permisos de la pieza 3.

**Pruébalo.** Ana (clase 09) necesita entrar. Genera **su** llave (en la vida real la genera ella):

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

👀 **Qué deberías ver:** `ana`: entró con su llave, y la pieza 6 la deja pasar porque está en `AllowUsers`.

**En resumen:** cada persona, su llave; tú solo recibes la pública y la pones en su `authorized_keys` con `700` y `600`.

## Tu chuleta de la clase

| Comando | Para qué |
|---------|----------|
| `ssh-keygen -t ed25519 -f ~/.ssh/nombre -C "comentario"` | crear un par de llaves |
| `ssh -i ~/.ssh/llave usuario@IP` | entrar con una llave concreta |
| `ssh-add ~/.ssh/llave` · `ssh-add -l` | darle la llave al agente (la passphrase, una sola vez) · ver cuáles tiene |
| `~/.ssh/config` (`Host`, `HostName`, `User`, `IdentityFile`) | alias: `ssh servidor-01` |
| `scp archivo servidor:/ruta/` · `rsync -avz dir/ servidor:/ruta/` | copiar archivos · sincronizar carpetas (solo copia lo que cambia) |
| `ssh -N -L 9090:localhost:8080 servidor` | túnel: tu puerto 9090 llega al 8080 del servidor |
| `ssh-keygen -lf archivo.pub` · `ssh-keygen -R IP` | ver una huella · olvidar la huella guardada de un servidor |
| `sudo sshd -t` · `sudo sshd -T` | revisar la sintaxis de la configuración · ver la configuración efectiva |

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

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
Con tu sesión de seguridad abierta, cambia `AllowUsers ubuntu ana` por `AllowUsers ana` en `00-endurecido.conf` y reinicia ssh. Intenta `ssh servidor-01` desde una terminal nueva: rechazado. **`multipass shell` también deja de funcionar**, porque usa SSH con el usuario `ubuntu` por debajo. Arréglalo **desde la sesión que dejaste abierta**:
```bash
sudo sed -i 's/^AllowUsers ana$/AllowUsers ubuntu ana/' /etc/ssh/sshd_config.d/00-endurecido.conf
sudo sshd -t && sudo systemctl restart ssh
```
Si hubieras cerrado todas las sesiones, la única salida sería restaurar un snapshot. En AWS: desmontar el disco y montarlo en otra instancia, o usar Session Manager si lo tenías configurado. Por eso en AWS se recomienda **SSM Session Manager**: no depende del puerto 22.

## Reto

En tu PC y en la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade a `~/.ssh/config` una entrada `ana-lab` para entrar como Ana con `ssh ana-lab`.

> 🧩 **Ejemplo resuelto:** la entrada `servidor-01` de la pieza 4.
> ```bash
> Host servidor-01
>     HostName 10.x.x.x
>     User ubuntu
>     IdentityFile ~/.ssh/lab_ed25519
>     IdentitiesOnly yes
> ```
> El nombre del alias (`Host`), a qué IP va, con qué usuario y con qué llave.

**Ahora tú, con huecos:**
```bash
Host ____
    HostName 10.x.x.x
    User ____
    IdentityFile ~/.ssh/____
    IdentitiesOnly yes
```

<details>
<summary>Pista</summary>

Tres cambios respecto al ejemplo: el nombre del alias, el usuario y la llave de Ana (la que creaste en la pieza 7).
</details>

**2.** Usa `rsync` para «desplegar» una carpeta local `web/` en `/var/www/html/` de la VM, y comprueba el resultado en el navegador con `http://IP`.

> 🧩 **Ejemplo resuelto:** el `rsync` de la pieza 5.
> ```bash
> rsync -avz /tmp/web/ servidor-01:/tmp/web/
> ssh servidor-01 ls /tmp/web
> ```
> `rsync` copia la carpeta a la VM, y `ssh servidor-01 comando` ejecuta algo allí para comprobarlo.

**Ahora tú, con huecos:**
```bash
rsync -avz web/ servidor-01:/tmp/web/
# y dentro de la VM:
sudo cp -r /tmp/web/* /var/www/____/
```

<details>
<summary>Pista</summary>

`ubuntu` no puede escribir en `/var/www/html/`, así que copias primero a `/tmp` y después, con `sudo`, a su sitio. El hueco es la última carpeta de esa ruta.
</details>

**3.** **Incidente simulado:** alguien sube por error la llave **privada** `ana_lab` a un repo público. Escribe en orden los pasos para cerrar el incidente y ejecútalos en la VM.

> 🧩 **Ejemplo resuelto:** el paso «revisar»: ¿quién ha entrado con llave en los últimos 7 días?
> ```bash
> sudo journalctl -u ssh --since "7 days ago" --no-pager | grep "Accepted publickey"
> ```
> Cada línea es una entrada con llave: quién, desde qué IP y cuándo.

**Ahora tú, con huecos:**
```bash
1. Revocar:    sudo nano /home/ana/.ssh/authorized_keys   → borra la línea que termina en ____
2. Reemplazar: ssh-keygen -t ed25519 -f ~/.ssh/ana_lab_v2 -C "ana-v2"   → pega en el servidor la nueva llave ____
3. Revisar:    el comando del ejemplo, buscando "Accepted publickey for ____"
```

<details>
<summary>Pista</summary>

Tres verbos, en este orden: **revocar** (quitar del servidor la llave pública de la llave filtrada), **reemplazar** (una llave nueva, como en la pieza 7) y **revisar** (si alguien la usó).
</details>

## Cierre

En `notas/fase-1/clase-15.md`:

1. ¿Por qué la llave pública se puede compartir y la privada no? Explica qué hace cada una al conectar. *(3 líneas. Empieza así: «La pública solo comprueba…, así que con ella nadie puede… La privada firma…, y quien la tenga…»)*
2. ¿Qué significa el aviso `REMOTE HOST IDENTIFICATION HAS CHANGED` y qué haces cuando lo ves? *(2 líneas. Empieza así: «Que la host key del servidor no coincide con la que apunté… Antes de aceptar, compruebo…»)*
3. Una llave privada se publicó en GitHub. ¿Por qué borrar el archivo del repo **no** cierra el incidente? ¿Qué pasos sí lo cierran? *(3 líneas. Empieza así: «Porque Git guarda… y los bots… Lo cierran: revocar…, reemplazar… y revisar…»)*
4. **Repaso (clase 14, sin mirar):** `df` dice que el disco está lleno pero `du` no encuentra el espacio. ¿Qué compruebas? *(2 líneas. Empieza así: «Un archivo borrado que un proceso sigue usando, con `lsof +L1`. Y si es *No space left* con espacio libre…»)*

Después, escríbeme `examíname clase-15`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La pública solo sirve para **verificar** firmas: el servidor la usa para comprobar que quien se conecta tiene la privada. Con ella no se puede entrar a ningún sitio. La privada **firma** el reto del servidor: quien la tenga puede hacerse pasar por ti en cada servidor (y en GitHub, o donde sea) que tenga tu pública. Por eso nunca sale de tu máquina, se protege con `600` y con una passphrase.

**2.** La huella (host key) del servidor no coincide con la que tu cliente guardó en `known_hosts`. Puede ser un ataque *man-in-the-middle* o un cambio legítimo (servidor reinstalado, IP reasignada a otra máquina, algo muy común en la nube). No se acepta a ciegas: se confirma por otra vía (consola de AWS, el administrador, `ssh-keygen -lf` desde una sesión de confianza) y solo entonces se borra la entrada vieja con `ssh-keygen -R host`.

**3.** Porque git guarda el **historial**: el archivo sigue en commits anteriores, en clones y en forks, y los bots escanean GitHub en busca de secretos en **minutos**. La llave debe considerarse comprometida. Pasos: (1) **revocarla**: quitar la pública de **todos** los `authorized_keys` (y de GitHub o AWS si estaba ahí); (2) generar un **par nuevo** e instalar la pública nueva; (3) **revisar los logs** de acceso (`journalctl -u ssh`, `auth.log`) por si alguien la usó; (4) después, limpiar el historial del repo. Lo esencial es **rotar**: lo publicado nunca se "despublica".

**4.** Un archivo borrado que sigue abierto por un proceso (`sudo lsof +L1`). Si el error es "No space left" con espacio libre, los inodos (`df -i`).

**Reto 3 (en la VM):**
```bash
sudo nano /home/ana/.ssh/authorized_keys                    # revocar: borra la línea que termina en "ana"
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

Ya administras un servidor: usuarios, paquetes, procesos, servicios, logs, recursos y acceso seguro. El bloque C te enseña a **automatizar** todo eso con scripts de Bash. Antes, el repaso del bloque.

## Siguiente

[Repaso del bloque B](repaso-bloque-b.md)
