# Clase 09 — Usuarios, grupos y sudo

**Dónde:** VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** en un servidor hay dos preguntas distintas: **¿quién eres?** (autenticación: tu contraseña o tu llave) y **¿qué puedes hacer?** (autorización: tus grupos, tus permisos y las reglas de sudo). Funciona como un hotel: en recepción comprueban tu identidad una vez y te dan una tarjeta que solo abre tu habitación. La regla de oro es el **mínimo privilegio**, la misma que aplicarás con IAM en AWS.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los tres juegos de llaves (dueño, grupo y resto) y los permisos en números, como `750` (clase 06).
> - La umask, el molde con el que nacen los archivos (clase 06).
> - `bash -c '…'` lanza un shell hijo que ejecuta lo que va entre comillas (clase 07).

> 🔤 **Palabras nuevas de hoy:**
> - **autenticación**: demostrar quién eres (con una contraseña o una llave).
> - **autorización**: lo que te dejan hacer una vez dentro.
> - **sudo**: ejecutar un comando como root, si la lista te lo permite.
> - **sudoers**: esa lista: quién puede usar `sudo` y para qué.
> - **usuario de servicio**: una cuenta para un programa, no para una persona (`www-data`).
> - **setgid** en una carpeta: el sello de equipo que pone su grupo a todo lo que se crea dentro.

## Objetivo

- Crear, modificar, bloquear y borrar usuarios y grupos.
- Entender `/etc/passwd`, `/etc/group` y `/etc/shadow`.
- Montar un **directorio compartido de equipo** con los permisos correctos.
- Dar permisos de administrador **limitados** con `sudo` (mínimo privilegio).
- Distinguir **autenticación** (quién eres) de **autorización** (qué puedes hacer).

## Por qué importa

En un servidor real conviven personas (cada administrador con su cuenta) y servicios (`www-data` para nginx, `postgres` para la base de datos). Cada uno debe poder hacer **solo lo que necesita**. Es la misma idea que IAM en AWS: usuarios, grupos y políticas. Si la entiendes aquí, IAM será un cambio de interfaz, no un concepto nuevo.

## Teoría

Cuatro piezas, con la imagen del hotel de *La idea de hoy*.

### 1. Dos preguntas distintas: ¿quién eres? y ¿qué puedes hacer?

En un hotel, la recepción comprueba **quién eres** una vez (tu documento) y te da una tarjeta que solo abre **lo que te corresponde** (tu habitación y el gimnasio). En un servidor es igual:

| | Pregunta | En el hotel | En Linux | En AWS |
|-|----------|-------------|----------|--------|
| **Autenticación** | ¿Quién eres? | el documento en recepción | contraseña, llave SSH | contraseña + MFA, access keys |
| **Autorización** | ¿Qué puedes hacer? | lo que abre tu tarjeta | permisos de archivos, grupos, sudoers | políticas IAM |

Primero se autentica y después se autoriza. Puedes haber entrado (autenticado) y aun así no tener permiso para leer un archivo concreto (no autorizado).

**En resumen:** autenticación = ¿quién eres?; autorización = ¿qué puedes hacer? Primero una y después la otra.

### 2. El registro de huéspedes: `/etc/passwd`

Linux apunta a cada usuario en una línea de `/etc/passwd`:

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

Las contraseñas no están ahí, sino cifradas en `/etc/shadow`, que solo puede leer root (lo viste en la clase 06). Los **grupos** y sus miembros están en `/etc/group`.

No todos los usuarios son personas. `www-data` (el de nginx) o `nobody` son **usuarios de servicio**: su shell es `/usr/sbin/nologin`, porque existen para ser **dueños de procesos y archivos**, no para que alguien entre con ellos. Ya lo viste en la clase 04: son la mayoría de las cuentas.

**En resumen:** cada usuario es una línea de `/etc/passwd`; las contraseñas están en `/etc/shadow` y los grupos en `/etc/group`.

### 3. Dar de alta y organizar en equipos

Los cuatro comandos que más usarás:

```bash
sudo adduser ana               # dar de alta a Ana (pregunta la contraseña y crea su casa)
sudo groupadd devs             # crear el equipo "devs"
sudo usermod -aG devs ana      # AÑADIR a Ana al equipo devs
id ana                         # ver quién es Ana y en qué equipos está
```

⚠️ En `usermod -aG`, la `-a` significa **añadir**. Sin ella, `-G` **sustituye** todos los grupos de la persona por los que pongas, y la saca de los demás. Es uno de los errores más típicos (lo provocarás en el Rómpelo 2).

**En resumen:** `adduser` da de alta, `groupadd` crea un equipo y `usermod -aG` añade a alguien a él (¡con la `-a`!).

### 4. `sudo`: la llave maestra, con registro

`sudo comando` ejecuta ese comando **como root**, el administrador, pero solo si **la lista de recepción** te lo permite. Esa lista es `/etc/sudoers`. Tres detalles:
- Te pide **tu** contraseña, no la de root: demuestras que eres tú.
- **Apunta cada uso** en el log del sistema: quién, cuándo y qué. Es una auditoría.
- En Ubuntu, estar en el grupo `sudo` te da la llave maestra para **todo**.

Lo profesional es dar solo lo necesario. Una regla de sudoers se lee así:

```
ana  ALL=(root)  /usr/bin/journalctl, /usr/bin/systemctl restart nginx
│    │    │      └─ SOLO estos comandos
│    │    └─ como el usuario root
│    └─ en cualquier máquina
└─ quién
```

La lista se edita **siempre con `visudo`**, que revisa que lo que escribiste es correcto antes de guardar. Un error en sudoers puede dejar a **todo el mundo** sin `sudo`. Las reglas propias van en archivos aparte, dentro de `/etc/sudoers.d/`.

**En resumen:** `sudo` presta la llave maestra solo a quien está en la lista, y apunta cada uso. La lista se edita con `visudo`.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Ana entra con su contraseña, pero no puede leer `/srv/proyecto`. ¿Falló la autenticación o la autorización?
2. ¿Qué pasa si escribes `sudo usermod -G devs luis`, sin la `-a`?
3. ¿Por qué no se edita `/etc/sudoers` con `nano` directamente?

<details>
<summary>Comprueba</summary>

1. La autorización: entró (autenticada), pero no tiene permiso. 2. Luis pasa a estar **solo** en `devs` y pierde los demás grupos. 3. Porque `visudo` revisa la sintaxis antes de guardar; con `nano`, un error dejaría a todos sin `sudo`.
</details>

### Tu chuleta de la clase

| Comando | Para qué |
|---------|----------|
| `sudo adduser ana` | crear un usuario (interactivo, crea su casa). Recomendado en Ubuntu |
| `sudo useradd -m -s /bin/bash ana` | lo mismo, sin preguntas: el que se usa en scripts |
| `sudo passwd ana` | poner o cambiar su contraseña |
| `sudo groupadd devs` | crear un grupo |
| `sudo usermod -aG devs ana` | **añadir** a un grupo (⚠️ sin `-a`, sustituye) |
| `sudo gpasswd -d ana devs` | sacar de un grupo |
| `sudo usermod -L ana` / `-U ana` | bloquear / desbloquear su contraseña |
| `sudo userdel -r ana` | borrar el usuario y su casa |
| `id ana` · `groups ana` · `getent group devs` | ver usuario y grupos · ver los miembros de un grupo |
| `sudo -u ana comando` | ejecutar un comando como Ana |
| `su - ana` | abrir un shell como Ana (pide **su** contraseña) |
| `sudo visudo -f /etc/sudoers.d/ana` · `sudo -l -U ana` | editar una regla de sudo con revisión · ver qué puede hacer Ana |

## Práctica guiada

```bash

👀 **Qué deberías ver:** Ana y Luis con `devs` entre sus grupos, Carla sin él, y una línea `devs:x:…:ana,luis`.
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

👀 **Qué deberías ver:** tu usuario, `ubuntu`, que está en el grupo `sudo`; las últimas cuentas del sistema; las líneas de root, www-data, nobody y ubuntu; y, gracias a `sudo`, las tres primeras líneas de `/etc/shadow`.

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

👀 **Qué deberías ver:** `drwxrws---`, con dueño `root` y grupo `devs`. La `s` en el juego del grupo es el sello de equipo.

El `2` inicial activa el **setgid** en el directorio (verás una `s` en el grupo). Funciona como un **sello de equipo**: todo lo que se crea dentro sale con el sello `devs`, en vez del grupo personal de quien lo crea. Sin él, los archivos de Ana serían del grupo `ana` y Luis no podría editarlos.

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

<details>
<summary>Compruébalo después de predecir</summary>

- `ls -l /srv/proyecto` como `ubuntu` **falla**: `ubuntu` no está en `devs`, y el directorio no da nada a "otros". Por eso el siguiente lleva `sudo`.
- Los dos archivos son del grupo `devs` gracias al setgid. ✅
- `plan.txt` (creado con umask 002) es `rw-rw-r--`, y Luis puede añadir. ✅
- `borrador.txt` (creado con umask 022) es `rw-r--r--`, y Luis **no** puede escribir. ❌ El umask 022 quitó la escritura al grupo. Muchos servicios, scripts y el propio sudo trabajan con 022.
- Carla no puede ni leer: no está en `devs`.
</details>

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

👀 **Qué deberías ver:** en la lista de Ana aparece la regla nueva: `(root) /usr/bin/journalctl`.

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

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
sudo ls /srv/proyecto
sudo rm /srv/proyecto/*.txt
sudo ls /srv/proyecto
```
🔮 ¿Se borró algo? No: `rm` se queja de que no existe `'/srv/proyecto/*.txt'`. El comodín lo expande **tu shell** (usuario `ubuntu`) **antes** de ejecutar `sudo`, y tu shell no puede leer `/srv/proyecto`, así que deja el patrón tal cual (clase 03). Es la misma trampa que `sudo echo … >> archivo` (clase 10). Si quieres que el comodín lo expanda root: `sudo bash -c 'rm /srv/proyecto/*.txt'`. No lo ejecutes ahora: necesitas esos archivos.
## Reto

En la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Crea el usuario de servicio `appsvc`: sin casa, con shell `/usr/sbin/nologin` y como usuario de sistema. Comprueba que nadie puede entrar con él.

> 🧩 **Ejemplo resuelto:** mirar cómo es `www-data`, otro usuario de servicio.
> ```bash
> grep "^www-data:" /etc/passwd
> ```
> Su UID está por debajo de 1000 (es del sistema) y su shell es `/usr/sbin/nologin`: así son los usuarios de servicio.

**Ahora tú, con huecos:**
```bash
sudo useradd --____ --no-create-home --shell ____ appsvc
sudo su - appsvc
```

<details>
<summary>Pista</summary>

El primer hueco es la opción que lo hace «de sistema». El segundo, el shell que no deja entrar, el mismo de `www-data`.
</details>

**2.** Crea, **como Ana**, el archivo `/srv/proyecto/config.txt`, y deja sus permisos para que los de `devs` puedan leerlo pero **solo Ana** pueda modificarlo.

> 🧩 **Ejemplo resuelto:** crear, como Luis, `/srv/proyecto/notas.txt`, que solo pueda leer y escribir él.
> ```bash
> sudo -u luis touch /srv/proyecto/notas.txt
> sudo chmod 600 /srv/proyecto/notas.txt
> sudo ls -l /srv/proyecto/notas.txt
> ```
> `sudo -u luis` crea el archivo **como Luis**, así que él es el dueño. `600`: él lee y escribe; el grupo y el resto, nada.

**Ahora tú, con huecos:**
```bash
sudo -u ____ touch /srv/proyecto/config.txt
sudo chmod ____ /srv/proyecto/config.txt
```

<details>
<summary>Pista</summary>

Dueña, leer y escribir: 6. Grupo, solo leer: 4. Los demás, nada: 0.
</details>

**3.** Da a Luis permiso para ejecutar con sudo **solo** `apt update`, sin `apt install`. Pruébalo.

> 🧩 **Ejemplo resuelto:** la regla de Ana de la práctica 4.
> ```bash
> sudo visudo -f /etc/sudoers.d/ana
> # dentro:  ana ALL=(root) /usr/bin/journalctl
> ```
> Quién (`ana`), en qué máquinas (`ALL`), como quién (`root`) y qué comando exacto.

**Ahora tú, con huecos:**
```bash
sudo visudo -f /etc/sudoers.d/luis
# dentro:  luis ALL=(root) /usr/bin/apt ____
```

<details>
<summary>Pista</summary>

Escribir el argumento detrás del comando limita la regla a ese argumento exacto. Para probar: `su - luis`, y después `sudo apt update` (funciona) y `sudo apt install cowsay` (denegado).
</details>

**4.** Borra a Carla con su casa y comprueba que no queda rastro en `/etc/passwd` ni en `/home`.

> 🧩 **Ejemplo resuelto:** dar de alta y de baja a un usuario de prueba, `temporal`.
> ```bash
> sudo useradd -m temporal
> sudo userdel -r temporal
> grep temporal /etc/passwd; ls /home
> ```
> `-m` le crea casa al darlo de alta; `-r` la borra al darlo de baja. El `grep` no imprime nada y en `/home` no queda su carpeta.

**Ahora tú, con huecos:**
```bash
sudo userdel -____ carla
grep carla /etc/passwd; ls /home
```

<details>
<summary>Pista</summary>

La misma opción del ejemplo para darle de baja.
</details>

## Cierre

En `notas/fase-1/clase-09.md`:

1. Diferencia entre autenticación y autorización, con un ejemplo de **este** laboratorio para cada una. *(2–3 líneas. Empieza así: «La autenticación es… En el lab, cuando… La autorización es… En el lab, cuando…»)*
2. ¿Para qué sirve el setgid (`2770`) en `/srv/proyecto`? ¿Qué pasaría sin él? ¿Y por qué Luis no pudo escribir en `borrador.txt` aunque el grupo era correcto? *(3 líneas. Empieza así: «El setgid hace que… Sin él, los archivos… Luis no pudo escribir en el borrador porque nació con…»)*
3. ¿Por qué darle a Ana solo `journalctl` en sudoers es mejor que meterla en el grupo `sudo`? Relaciónalo con IAM en AWS. *(2 líneas. Empieza así: «Por mínimo privilegio: si roban la cuenta de Ana… En AWS es igual: …»)*
4. **Repaso (clase 08, sin mirar):** ¿qué diferencia hay entre parar y terminar una instancia en AWS, y cuál sigue costando dinero? *(2 líneas. Empieza así: «Parar (*stop*) apaga…, pero… Terminar…»)*

Después, escríbeme `examíname clase-09`.

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
sudo -u ana touch /srv/proyecto/config.txt && sudo chmod 640 /srv/proyecto/config.txt   # ana: rw- · devs: r-- · resto: ---
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
