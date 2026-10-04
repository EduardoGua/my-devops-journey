# Clase 09 — Usuarios, grupos y sudo

**Dónde:** VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** B. Administrar un servidor

## Objetivo

- Crear, modificar, bloquear y borrar usuarios y grupos.
- Entender `/etc/passwd`, `/etc/group` y `/etc/shadow`.
- Montar un **directorio compartido de equipo** con los permisos correctos.
- Dar permisos de administrador **limitados** con `sudo` (mínimo privilegio).
- Distinguir **autenticación** (quién eres) de **autorización** (qué puedes hacer).

## Por qué importa

En un servidor real conviven personas (cada administrador con su cuenta) y servicios (`www-data` para nginx, `postgres` para la base de datos). Cada uno debe poder hacer **solo lo que necesita**. Es la misma idea que IAM en AWS: usuarios, grupos y políticas. Si la entiendes aquí, IAM será un cambio de interfaz, no un concepto nuevo.

## Teoría

### Autenticación y autorización

| | Pregunta | En Linux | En AWS |
|-|----------|----------|--------|
| **Autenticación** | ¿Quién eres? | contraseña, llave SSH | contraseña + MFA, access keys |
| **Autorización** | ¿Qué puedes hacer? | permisos de archivos, grupos, sudoers | políticas IAM |

Primero se autentica y después se autoriza. Puedes estar autenticado (entraste) y aun así no estar autorizado a leer un archivo concreto.

### Los archivos de usuarios

```
/etc/passwd   →  ana:x:1001:1001:Ana Ruiz:/home/ana:/bin/bash
                 │   │  │    │      │         │         └─ shell
                 │   │  │    │      │         └─ casa
                 │   │  │    │      └─ comentario
                 │   │  │    └─ GID del grupo principal
                 │   │  └─ UID (0 = root; personas desde 1000; servicios < 1000)
                 │   └─ "x" = la contraseña está en /etc/shadow
                 └─ nombre

/etc/shadow   →  hashes de contraseñas (solo root)
/etc/group    →  devs:x:1003:ana,luis    (grupo:x:GID:miembros)
```

Los usuarios de servicio (`www-data`, `nobody`) suelen tener como shell `/usr/sbin/nologin`: existen para ser **dueños de procesos y archivos**, no para que nadie entre con ellos.

### Comandos

| Comando | Para qué |
|---------|----------|
| `sudo adduser ana` | Crear un usuario (interactivo, crea su casa). Recomendado en Ubuntu |
| `sudo useradd -m -s /bin/bash ana` | Lo mismo, a bajo nivel (el que se usa en scripts) |
| `sudo passwd ana` | Poner o cambiar la contraseña |
| `sudo groupadd devs` | Crear un grupo |
| `sudo usermod -aG devs ana` | **Añadir** a un grupo. ⚠️ Sin `-a` **reemplaza** todos sus grupos |
| `sudo gpasswd -d ana devs` | Quitar de un grupo |
| `sudo usermod -L ana` / `-U` | Bloquear / desbloquear la contraseña |
| `sudo userdel -r ana` | Borrar el usuario y su casa |
| `id ana`, `groups ana` | Ver UID y grupos |
| `sudo -u ana comando` | Ejecutar un comando como otro usuario |
| `su - ana` | Abrir un shell como otro usuario (pide **su** contraseña) |

### sudo

`sudo` ejecuta un comando como root **si las reglas de `/etc/sudoers` te autorizan**. Pide **tu** contraseña, no la de root, y registra cada uso en los logs. En Ubuntu, pertenecer al grupo `sudo` da permiso para todo.

Las reglas se escriben **siempre con `visudo`**, que comprueba la sintaxis antes de guardar: un error en sudoers puede dejar a todo el mundo sin `sudo`. Las reglas propias van en archivos separados dentro de `/etc/sudoers.d/`.

```
ana  ALL=(root)  /usr/bin/journalctl, /usr/bin/systemctl restart nginx
│    │    │      └─ SOLO estos comandos
│    │    └─ como el usuario root
│    └─ en cualquier máquina
└─ quién
```

## Práctica guiada

```bash
multipass shell servidor-01
```

Comprueba el prompt: debe decir `ubuntu@servidor-01`.

### 1. Mira lo que hay

```bash
id
tail -5 /etc/passwd
grep -E '^(root|www-data|nobody|ubuntu):' /etc/passwd
getent group sudo
sudo head -3 /etc/shadow
```

### 2. Crea un equipo

```bash
sudo adduser ana          # pon una contraseña que recuerdes; el resto, Enter
sudo adduser luis
sudo adduser carla
sudo groupadd devs
sudo usermod -aG devs ana
sudo usermod -aG devs luis
id ana; id luis; id carla
getent group devs
```

### 3. Un directorio de equipo

Queremos `/srv/proyecto`, donde los miembros de `devs` lean y escriban, y nadie más pueda ni mirar.

```bash
sudo mkdir -p /srv/proyecto
sudo chown root:devs /srv/proyecto
sudo chmod 2770 /srv/proyecto
ls -ld /srv/proyecto
```

El `2` inicial activa el **setgid** en el directorio (verás una `s` en el grupo): todo lo que se cree dentro hereda el grupo `devs` en vez del grupo personal de quien lo crea. Sin él, los archivos de Ana serían del grupo `ana` y Luis no podría editarlos.

Antes de seguir, mira un detalle que va a importar:
```bash
umask
sudo -u ana bash -c 'umask'
```
Probablemente tu sesión tiene `0002`, pero lo que ejecutas con `sudo -u` tiene `0022`: el `sudo` de Ubuntu 26.04 (*sudo-rs*) aplica su propia máscara. Los archivos los crea **el proceso**, y es **su** umask el que cuenta. Por eso en las pruebas siguientes la fijamos a mano: así el resultado no depende de la versión de sudo.

🔮 **Predice** el resultado de cada línea:

```bash
sudo -u ana bash -c 'umask 002; echo "paso 1" >> /srv/proyecto/plan.txt'
sudo -u ana bash -c 'umask 022; echo "borrador" > /srv/proyecto/borrador.txt'
ls -l /srv/proyecto
sudo ls -l /srv/proyecto
sudo -u luis bash -c 'echo "paso 2" >> /srv/proyecto/plan.txt'
sudo -u luis bash -c 'echo "cambio" >> /srv/proyecto/borrador.txt'
sudo -u carla cat /srv/proyecto/plan.txt
```

Qué deberías ver:
- `ls -l /srv/proyecto` como `ubuntu` **falla**: `ubuntu` no está en `devs`, y el directorio no da nada a "otros". Por eso el siguiente lleva `sudo`.
- Los dos archivos son del grupo `devs` gracias al setgid. ✅
- `plan.txt` (creado con umask 002) es `rw-rw-r--`, y Luis puede añadir. ✅
- `borrador.txt` (creado con umask 022) es `rw-r--r--`, y Luis **no** puede escribir. ❌ El umask 022 quitó la escritura al grupo. Muchos servicios, scripts y el propio sudo trabajan con 022.
- Carla no puede ni leer: no está en `devs`.

En equipos reales, un directorio compartido necesita dos piezas: **setgid** (que el grupo sea el correcto) y **permisos de grupo correctos**: umask 002 en quien crea los archivos, o mejor, ACLs por defecto en el directorio (`setfacl -d -m g:devs:rwX /srv/proyecto`), que no dependen de nadie. Con una sola de las dos piezas falla. Arregla el borrador:

```bash
sudo chmod g+w /srv/proyecto/borrador.txt
sudo -u luis bash -c 'echo "cambio" >> /srv/proyecto/borrador.txt' && echo "ahora sí"
```

### 4. sudo con mínimo privilegio

Ana es la responsable de revisar logs. Debe poder leer **todos** los logs del sistema, y nada más como root.

```bash
sudo -l -U ana                         # qué puede hacer con sudo ahora: nada
sudo visudo -f /etc/sudoers.d/ana
```

Escribe esta línea, guarda (`Ctrl+O`, `Enter`) y sal (`Ctrl+X`):
```
ana ALL=(root) /usr/bin/journalctl
```

```bash
sudo chmod 440 /etc/sudoers.d/ana
sudo -l -U ana
```

Pruébalo **siendo** Ana. `su` pide la contraseña de Ana:
```bash
su - ana
whoami
sudo journalctl -n 5            # pide la contraseña de Ana: permitido
sudo cat /etc/shadow            # denegado
sudo apt update                 # denegado
exit
```

### 5. El rastro de sudo

```bash
sudo journalctl _COMM=sudo -n 10
```

Cada uso de sudo, permitido o no, queda registrado con usuario, directorio y comando. Es la base de una **auditoría**, como CloudTrail en AWS.

## Rómpelo

Antes de romper, **snapshot** desde otra terminal en tu PC:
```bash
multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-sudoers && multipass start servidor-01
```

**1. Un error de sintaxis en sudoers:**
```bash
sudo visudo -f /etc/sudoers.d/ana
```
Borra `ALL=` (deja `ana (root) /usr/bin/journalctl`), guarda y sal. `visudo` detecta el error y pregunta `What now?`. Pulsa `e` para volver a editar, corrígelo y guarda. **Por eso se usa visudo**: con `nano` directo, ese error habría roto `sudo` para todos.

**2. El `-a` olvidado:**
```bash
sudo usermod -aG adm luis
id luis
sudo usermod -G adm luis        # sin -a
id luis
```
Luis ya no está en `devs`. Este error en producción deja a alguien sin acceso de golpe. Arréglalo:
```bash
sudo usermod -aG devs luis
```

**3. Los grupos se cargan al iniciar sesión:**
```bash
su - carla                    # en otra pestaña o ventana, deja esta sesión abierta
```
Desde la sesión de `ubuntu`: `sudo usermod -aG devs carla`. En la sesión de Carla: `id` **todavía no** muestra `devs`. Sal (`exit`) y vuelve a entrar con `su - carla`: ahora sí. Si alguien "ya está en el grupo pero sigue sin poder entrar", lo primero es pedirle que cierre la sesión y vuelva a entrar.

**4. Bloquear frente a borrar:**
```bash
sudo usermod -L luis
su - luis                     # falla aunque la contraseña sea correcta
sudo usermod -U luis
```
Cuando alguien deja la empresa, primero se **bloquea** (es reversible y se conserva el rastro) y se borra después, cuando ya está todo revisado. Ojo: bloquear la contraseña no bloquea sus llaves SSH (clase 15).


**5. El comodín y sudo:**
```bash
sudo ls /srv/proyecto
sudo rm /srv/proyecto/*.txt
sudo ls /srv/proyecto
```
🔮 ¿Se borró algo? No: `rm` se queja de que no existe `'/srv/proyecto/*.txt'`. El comodín lo expande **tu shell** (usuario `ubuntu`) **antes** de ejecutar `sudo`, y tu shell no puede leer `/srv/proyecto`, así que deja el patrón tal cual (clase 03). Es la misma trampa que `sudo echo … >> archivo` (clase 10). Si quieres que el comodín lo expanda root: `sudo bash -c 'rm /srv/proyecto/*.txt'`. No lo ejecutes ahora: necesitas esos archivos.
## Reto

1. Crea el usuario de servicio `appsvc`, sin casa, con shell `/usr/sbin/nologin` y como usuario de sistema (`useradd --system`). Comprueba que nadie puede entrar con `su - appsvc`.
2. Haz que `/srv/proyecto/config` sea legible por `devs` pero **solo modificable por Ana**.
3. Da a Luis permiso para ejecutar con sudo **solo** `apt update`, sin `apt install`. ¿Qué comando exacto escribes en sudoers? Pruébalo.
4. Borra a Carla con su casa y comprueba que no queda rastro en `/etc/passwd` ni en `/home`.

## Cierre

En `notas/fase-1/clase-09.md`:

1. Diferencia entre autenticación y autorización, con un ejemplo de **este** laboratorio para cada una.
2. ¿Para qué sirve el setgid (`2770`) en `/srv/proyecto`? ¿Qué pasaría sin él? ¿Y por qué Luis no pudo escribir en `borrador.txt` aunque el grupo era correcto?
3. ¿Por qué darle a Ana solo `journalctl` en sudoers es mejor que meterla en el grupo `sudo`? Relaciónalo con IAM en AWS.
4. **Repaso (clase 08, sin mirar):** ¿qué diferencia hay entre parar y terminar una instancia en AWS, y cuál sigue costando dinero?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Autenticación**: comprobar quién eres. En el lab, `su - ana` pidió la contraseña de Ana y `sudo` pidió de nuevo la suya para confirmar que era ella. **Autorización**: qué puede hacer una identidad ya comprobada. Ana, autenticada, pudo ejecutar `sudo journalctl`, pero se le denegó `sudo cat /etc/shadow` porque sudoers no lo autoriza. Y Carla no pudo leer `plan.txt` porque no estaba en `devs`.

**2.** Con setgid en un directorio, los archivos nuevos heredan el **grupo del directorio** (`devs`) en lugar del grupo personal del creador. Sin él, `plan.txt` habría sido del grupo `ana`, y Luis (que no está en ese grupo) no podría modificarlo: el trabajo en equipo se rompe en cuanto alguien crea un archivo. Luis no pudo escribir en `borrador.txt` porque, aunque el grupo era `devs`, el archivo nació con `rw-r--r--` (umask 022): el grupo solo tenía lectura. **Grupo correcto + permisos de grupo correctos**: hacen falta las dos cosas.

**3.** Por mínimo privilegio. En el grupo `sudo`, Ana podría hacer cualquier cosa como root: leer secretos, borrar el sistema o crear usuarios. Si roban su cuenta, el atacante tiene la máquina entera. Con la regla limitada, un error o un robo solo afecta a la lectura de logs. En AWS es lo mismo: una política IAM con solo las acciones que la persona necesita (por ejemplo `logs:GetLogEvents`), nunca `AdministratorAccess` "por comodidad".

**4.** Parar (*stop*) apaga la instancia y conserva su disco EBS, que **sigue costando**. Terminar (*terminate*) la elimina. Para no pagar nada hay que terminarla y borrar también sus volúmenes y snapshots.

**Reto:**
```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin appsvc
sudo su - appsvc                   # "This account is currently not available."
sudo -u ana mkdir /srv/proyecto/config && sudo chmod 2750 /srv/proyecto/config   # dueño ana: rwx · devs: r-x
# en sudo visudo -f /etc/sudoers.d/luis:
luis ALL=(root) /usr/bin/apt update
sudo userdel -r carla && grep carla /etc/passwd; ls /home
```
En sudoers, escribir los argumentos (`/usr/bin/apt update`) limita el comando **exactamente** a esos argumentos.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| authentication / authorization | autenticación / autorización |
| least privilege | mínimo privilegio |
| service account | cuenta de servicio |
| to lock an account | bloquear una cuenta |
| audit trail | rastro de auditoría |

🎙️ *"Authentication is proving who you are; authorization is what you're allowed to do. I apply least privilege both in Linux with sudoers and in AWS with IAM policies."*

## Siguiente

[Clase 10 — Paquetes con apt](clase-10-paquetes-apt.md)
