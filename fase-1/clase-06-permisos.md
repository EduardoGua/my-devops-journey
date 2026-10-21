# Clase 06 — Permisos: usuarios, grupos y rwx

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** cada archivo tiene un dueño, un grupo y **tres bloques de permisos**: uno para el dueño, otro para los del grupo y otro para el resto (otros). Cada bloque dice si se puede leer (`r`), escribir (`w`) o ejecutar (`x`), y el kernel te aplica **solo el primer bloque que te corresponde**. En un directorio, los permisos significan otra cosa: `r` deja ver la lista de nombres, `w` crear o borrar dentro y `x` entrar en él.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Leer una línea de `ls -l`: tipo, permisos, dueño y grupo (clase 02).
> - `./script` pide al kernel ejecutar un archivo (clase 01, pieza 4: el paso 4 de «Qué pasa cuando pulsas Enter»).
> - Crear un archivo de una línea con `echo … >` o `printf … >` (clase 04).

> 🔤 **Palabras nuevas de hoy:**
> - **dueño**, **grupo** y **otros**: los tres «quiénes» de cada archivo.
> - **r / w / x**: leer, escribir y ejecutar.
> - **root**: el administrador del sistema, que se salta casi todos los permisos.
> - **chmod**: el comando que cambia los permisos.
> - **umask**: la máscara que decide con qué permisos nacen los archivos nuevos.

## Objetivo

- Leer cualquier permiso (`rwxr-x---`, `750`) y saber **qué puede hacer cada quien**.
- Entender que `r`, `w` y `x` significan cosas **distintas en archivos y en directorios**.
- Cambiar permisos con `chmod` (simbólico y numérico) y entender `umask`.
- Saber por qué `chmod 777` nunca es la solución.

## Por qué importa

"Permission denied" es uno de los errores más comunes en producción: nginx no puede leer la web, una app no puede escribir su log, SSH rechaza tu llave porque los permisos son demasiado abiertos. Y los permisos son la base de la **seguridad**: el mismo principio de *mínimo privilegio* que aplicarás en IAM de AWS empieza aquí.

## Cómo va esta clase

Seis piezas. En cada una lees **un** concepto y lo pruebas enseguida en la terminal; no pases a la pieza siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 35 min); el segundo, las **piezas 5 y 6**, el Rómpelo, el reto y el cierre.

Primero, la carpeta de hoy:

```bash
mkdir -p ~/my-devops-journey/labs/clase-06 && cd ~/my-devops-journey/labs/clase-06
```

## Las piezas

### Pieza 1 — Quién eres

Cada programa que ejecutas corre **como un usuario** (normalmente, tú). Cada usuario pertenece a uno o varios **grupos**, y cada archivo tiene **un dueño** y **un grupo**.

**Pruébalo:**

```bash
id
ls -l /etc/passwd
```

👀 **Qué deberías ver:** `id` muestra tu usuario (`uid=1000(educo)`), tu grupo principal (`gid=1000(educo)`) y todos tus grupos, entre ellos `sudo`. En la línea de `ls -l`, la tercera columna es el dueño (`root`) y la cuarta, el grupo (`root`).

**En resumen:** cada programa corre como un usuario, y cada archivo tiene un dueño y un grupo.

### Pieza 2 — Tres bloques de permisos

Las 9 letras que ves con `ls -l` son tres bloques de permisos, de tres letras cada uno:

```
-rwxr-x---  1 educo devs  ... script.sh
 └┬┘└┬┘└┬┘
  │  │  └── el resto del mundo (otros, «o»):   ---  nada
  │  └───── los del grupo devs (grupo, «g»):   r-x  leer y ejecutar
  └──────── la dueña, educo (dueño, «u»):      rwx  todo
```

Cada letra es un permiso: **r** para leer, **w** para escribir y **x** para ejecutar. Un guion (`-`) es un permiso que falta.

El kernel mira **en orden** y te aplica **solo el primer bloque que te corresponde**:
1. ¿Eres el dueño? Te aplica el bloque del dueño, y no sigue mirando.
2. Si no, ¿estás en el grupo? Te aplica el del grupo.
3. Si no, te aplica el de otros.

(La excepción es **root**, el administrador, que se salta casi todas las comprobaciones.)

**Pruébalo:**

```bash
ls -l /etc/passwd /etc/shadow
```

Para cada línea, di en voz alta quién es el dueño, quién es el grupo y qué permite cada bloque.

🔮 **Predice:** tú no eres `root` ni estás en el grupo `shadow`. ¿Qué bloque de `/etc/shadow` te toca? ¿Podrás leerlo?

```bash
cat /etc/shadow
```

👀 **Qué deberías ver:** `cat: /etc/shadow: Permission denied` (en inglés: el `cat` de Ubuntu 26.04 aún no está traducido). El archivo es `rw-r-----`, de `root` y del grupo `shadow`, y tú caes en el bloque de otros (`---`). Guarda los *hashes* de las contraseñas (una versión cifrada de cada una), por eso solo root y el grupo `shadow` pueden leerlo.

✋ **Sin mirar:** un archivo es `---rwxrwx` y tú eres su dueño. ¿Puedes leerlo?

<details>
<summary>Comprueba</summary>

No: el kernel te aplica el bloque del dueño (`---`) y no sigue mirando, aunque el grupo y el resto tengan todo. Lo verás con tus propios ojos en el Rómpelo 1.
</details>

**En resumen:** tres bloques de permisos (dueño, grupo y otros), y el kernel te aplica solo el primero que te toca.

### Pieza 3 — Los permisos en números

Cada permiso vale un número: **r = 4**, **w = 2**, **x = 1**. Se suman los de cada bloque, así que cada bloque queda en una cifra del 0 al 7:

| Cifra | Permisos | Cuenta |
|-------|--------|--------|
| `7` | `rwx` | 4 + 2 + 1 |
| `6` | `rw-` | 4 + 2 |
| `5` | `r-x` | 4 + 1 |
| `4` | `r--` | 4 |
| `0` | `---` | nada |

Tres cifras, una por bloque, en el mismo orden (dueño, grupo y otros). `640` se lee así: **6** el dueño lee y escribe, **4** el grupo solo lee y **0** los demás nada → `rw-r-----`.

**Pruébalo:** `stat` muestra los permisos de las dos formas a la vez (`%a` en números, `%A` en letras y `%n` el nombre):

```bash
stat -c '%a %A %n' /etc/passwd /etc/shadow
```

👀 **Qué deberías ver:** `644 -rw-r--r-- /etc/passwd` y `640 -rw-r----- /etc/shadow`. Comprueba cada cifra con la tabla: `6` = `rw-` (4 + 2), `4` = `r--` y `0` = `---`.

✋ **Sin mirar:** traduce `rwxr-xr--` a números.

<details>
<summary>Comprueba</summary>

`754`: `rwx` = 7, `r-x` = 5 y `r--` = 4.
</details>

**En resumen:** r = 4, w = 2 y x = 1. Se suman por bloque y salen tres cifras: dueño, grupo y otros.

### Pieza 4 — Cambiar los permisos: `chmod`

Hay dos formas de escribirlo:

```bash
chmod 640 archivo           # con números: fija los 9 permisos de golpe
chmod u+x script.sh         # con letras: AÑADE (+) la x al dUeño (u)
chmod g-w,o-r archivo       # QUITA (-) la w al Grupo y la r a los Otros
```

Con letras: **u** = dueño (*user*), **g** = grupo, **o** = otros; **+** añade y **-** quita. Los números sirven para dejar los permisos exactamente como quieres; las letras, para cambiar un permiso sin tocar los demás.

`chown usuario:grupo archivo` cambia el dueño y el grupo. Solo lo puede hacer root: lo practicarás en el servidor (clase 09).

**Pruébalo con un script:**

```bash
printf '#!/bin/bash\necho "hola desde el script"\n' > hola.sh
ls -l hola.sh
./hola.sh
```

🔮 **Predice:** ¿funcionará? Mira la columna de permisos antes de pulsar Enter.

```bash
chmod u+x hola.sh
ls -l hola.sh
./hola.sh
bash hola.sh        # esto funciona incluso sin x: bash LEE el archivo (necesita r)
```

👀 **Qué deberías ver:** el primer `./hola.sh` falla con *Permiso denegado* (el mensaje es de bash, que está traducido). Después del `chmod`, aparece la `x` en el bloque del dueño (`-rwxrw-r--`) y sale `hola desde el script` las dos veces.

`./hola.sh` pide al kernel **ejecutar** el archivo (hace falta `x`). `bash hola.sh` ejecuta `bash`, que solo **lee** el archivo (basta con `r`).

**Y con un archivo privado:**

```bash
echo "secreto" > privado.txt
ls -l privado.txt          # nace 664 con tu umask (pieza 6)
chmod 600 privado.txt
ls -l privado.txt
```

👀 **Qué deberías ver:** primero `-rw-rw-r--` y, después del `chmod`, `-rw-------`: ahora solo tú puedes leerlo.

**En resumen:** `chmod 640` lo fija todo con números; `chmod g-w` cambia un solo permiso con letras.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 5 — En un directorio, los permisos significan otra cosa

Esta es la pieza que más sorprende: léela despacio.

En un **archivo**, los permisos significan lo que esperas: `r` leerlo, `w` modificarlo y `x` ejecutarlo como programa. Un **directorio**, en cambio, es por dentro **una lista de nombres** de archivos, y sus permisos se aplican a esa lista:

| Permiso | En un archivo | En un directorio |
|---------|---------------|------------------|
| `r` | leer el contenido | **listar** los nombres de dentro (`ls`) |
| `w` | modificar el contenido | **crear, borrar y renombrar** archivos dentro |
| `x` | ejecutarlo | **entrar** (`cd`) y acceder a los archivos de dentro |

De ahí salen tres sorpresas, que vas a ver ahora mismo:
- Borrar un archivo depende de la `w` del **directorio**, no del archivo: borrar es quitar un nombre de la lista del directorio.
- Con `r` pero sin `x`, ves los nombres pero no puedes abrir ningún archivo de dentro.
- Para leer `/a/b/c.txt` necesitas la `x` de los tres directorios del camino (`/`, `/a` y `/a/b`) y la `r` del archivo.

**Pruébalo, primero con dos directorios del sistema:**

```bash
ls -ld /root ~
```

👀 **Qué deberías ver:** `/root` es `drwx------` de `root`: tú caes en otros (`---`) y ni siquiera puedes entrar. Tu carpeta personal es tuya y tiene todo en el bloque del dueño.

**Ahora con una carpeta de prueba.** Vas a quitarle permisos a `caja` y ver qué puedes hacer en cada caso. Antes de cada bloque, 🔮 **predice** qué funcionará y qué no, y apúntalo.

```bash
mkdir caja && echo "dato" > caja/dato.txt
ls -ld caja
```

**Sin ningún permiso (000):**
```bash
chmod 000 caja
ls caja
cat caja/dato.txt
cd caja
ls -ld caja
```

**Solo la `r` (400):**
```bash
chmod 400 caja
ls caja
cat caja/dato.txt
```

**Solo la `x` (100):**
```bash
chmod 100 caja
ls caja
cat caja/dato.txt
```

**`r` y `x`, sin `w` (500):**
```bash
chmod 500 caja
cat caja/dato.txt
rm caja/dato.txt
touch caja/nuevo.txt
```

Deja la caja en un estado normal:
```bash
chmod 755 caja
```

<details>
<summary>Compruébalo después de predecir</summary>

| Permisos de `caja` | `ls caja` (listar) | `cat caja/dato.txt` (abrir un archivo de dentro) | Crear o borrar dentro |
|--------------------|--------------------|--------------------------------------------------|-----------------------|
| `000` | ❌ | ❌ | ❌ |
| `400` (`r`) | ✅ ves el nombre | ❌ falta la `x` para entrar | ❌ |
| `100` (`x`) | ❌ falta la `r` para listar | ✅ si sabes el nombre, accedes directo | ❌ |
| `500` (`r` y `x`) | ✅ | ✅ | ❌ crear y borrar cambian la lista del directorio: hace falta `w` |

¿Y `ls -ld caja` con `000`? Funciona: no entra en `caja`, lee su información (permisos, dueño) en el directorio padre, donde sí tienes permisos.
</details>

✋ **Sin mirar:** quieres poder borrar archivos de una carpeta. ¿Qué permiso necesitas, y dónde: en los archivos o en la carpeta?

<details>
<summary>Comprueba</summary>

La `w` de la **carpeta**: borrar es quitar un nombre de la lista del directorio. Lo acabas de ver con `500`: sin `w`, `rm` falló aunque el archivo era tuyo.
</details>

**En resumen:** en un directorio, `r` es listar, `w` crear o borrar dentro y `x` entrar.

### Pieza 6 — `umask`: los permisos de los archivos nuevos

Los archivos nuevos no nacen con permisos al azar: los decide una máscara, la **umask**. Con la de Ubuntu para tu usuario (`002`), un archivo nuevo nace `664` (`rw-rw-r--`) y un directorio nuevo, `775`. La máscara **quita** permisos: con `002`, le quita la `w` a los otros.

`umask 077` cambia la máscara **solo en esa terminal**: al cerrarla, vuelve la de siempre.

**Pruébalo:**

```bash
umask
touch con-umask-normal.txt && mkdir dir-normal
umask 077
touch con-umask-077.txt && mkdir dir-077
ls -ld con-umask-* dir-*
umask 002             # restaura (o cierra la terminal)
```

👀 **Qué deberías ver:** `umask` responde `0002`. Con la máscara normal, el archivo nace `rw-rw-r--` y la carpeta `rwxrwxr-x`. Con `077`, la máscara quita **todo** al grupo y al resto: nacen `rw-------` y `rwx------`, privados desde el primer momento.

**En resumen:** la umask decide qué permisos les faltan a los archivos que nacen.

## Tu chuleta de la clase

| Números | Letras | Uso típico |
|---------|--------|------------|
| `755` | `rwxr-xr-x` | scripts, directorios públicos |
| `644` | `rw-r--r--` | archivos de configuración o de una web |
| `700` | `rwx------` | directorio privado (`~/.ssh`) |
| `600` | `rw-------` | archivo privado (llave SSH, contraseñas) |
| `750` | `rwxr-x---` | directorio de un equipo (dueño y grupo) |
| `777` | `rwxrwxrwx` | ❌ cualquiera hace cualquier cosa: nunca es la solución |

| Comando | Qué hace |
|---------|----------|
| `ls -l archivo` · `ls -ld carpeta` | ver los permisos (`-d`: de la carpeta, no de lo que hay dentro) |
| `stat -c '%a %A %n' archivo` | los permisos en números y en letras a la vez |
| `chmod 640 f` · `chmod u+x f` · `chmod -R 750 d` | cambiar permisos: números, letras, recursivo (¡cuidado!) |
| `umask` · `umask 077` | ver la máscara · cambiarla en esta terminal |
| `id` | quién eres y en qué grupos estás |

**Para reconocerlos** (no hace falta más hoy): una `s` en lugar de la `x` del dueño es el **setuid**: el programa corre con los permisos de su dueño, no con los tuyos (`/usr/bin/passwd` lo tiene para poder escribir en `/etc/shadow`; `stat` lo muestra como un `4` delante: `4755`). Una `t` al final es el **sticky bit**: en `/tmp` todos pueden crear archivos, pero cada uno solo puede borrar los suyos (míralo con `ls -ld /tmp`).

## Rómpelo

**1. La trampa del dueño:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
echo "texto" > trampa.txt
chmod 077 trampa.txt      # ----rwxrwx: el dueño no tiene nada, el resto todo
ls -l trampa.txt
cat trampa.txt
```
No puedes leerlo **aunque grupo y otros tengan todo**, y tu usuario está en tu grupo. El kernel ve que eres el dueño, aplica los permisos del dueño (`---`) y **no sigue mirando**. Arréglalo con `chmod 644 trampa.txt` (como dueño puedes cambiar los permisos aunque no puedas leer el archivo).

**2. Por qué 777 no es la respuesta:**
```bash
chmod 777 privado.txt
ls -l privado.txt
```
Ahora **cualquier usuario y cualquier proceso** de la máquina puede leerlo, modificarlo o reemplazarlo. Si un atacante entra con el usuario de la web, puede cambiar tus scripts y esperar a que tú los ejecutes. El arreglo correcto para un "Permission denied" es averiguar **qué usuario** necesita **qué permiso** y dar solo eso. Devuélvelo a `chmod 600 privado.txt`.

**3. SSH exige permisos estrictos:**
```bash
ls -ld ~/.ssh
ls -l ~/.ssh
```
Tu llave privada (`id_ed25519`) está en `600` y `~/.ssh` en `700`. Si la llave tuviera permisos más abiertos, `ssh` se negaría a usarla ("UNPROTECTED PRIVATE KEY FILE"). Es un error clásico en EC2 con los archivos `.pem`: se arregla con `chmod 400 llave.pem`.

## Reto

En `labs/clase-06/`, en la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Crea `equipo/` con permisos para que el dueño haga todo, el grupo pueda entrar y leer, y los demás nada. Usa números.

> 🧩 **Ejemplo resuelto:** una carpeta `privada/` donde el dueño hace todo y nadie más puede nada.
> ```bash
> mkdir privada && chmod 700 privada
> ls -ld privada
> ```
> 7 = `rwx` para el dueño; 0 y 0 = nada para el grupo y el resto. `ls -ld` muestra `drwx------`.

**Ahora tú, con huecos:** `mkdir equipo && chmod ____ equipo`

<details>
<summary>Pista</summary>

Dueño, todo: 7. Grupo, entrar y leer (`r-x`): 4 + 1 = 5. Los demás, nada: 0.
</details>

**2.** Dentro, crea `config.ini` para que el dueño pueda leer y escribir y el grupo solo leer. Usa **letras**, partiendo de los permisos con los que nace.

> 🧩 **Ejemplo resuelto:** un archivo `nota.txt` (nace `rw-rw-r--`) que el resto no pueda leer.
> ```bash
> touch nota.txt && chmod o-r nota.txt
> ls -l nota.txt
> ```
> `o-r` quita (`-`) la `r` a los otros (`o`). Queda `-rw-rw----`.

**Ahora tú, con huecos:** `touch equipo/config.ini && chmod g-____,o-____ equipo/config.ini`

<details>
<summary>Pista</summary>

Nace `rw-rw-r--` y lo quieres `rw-r-----`. ¿Qué letra le sobra al grupo? ¿Y al resto?
</details>

**3.** Calcula sin ejecutar: con `umask 027`, ¿con qué permisos nacen un archivo y una carpeta? Compruébalo después.

> 🧩 **Ejemplo resuelto:** con `umask 077`, la máscara quita **todo** al grupo y al resto.
> ```bash
> umask 077
> touch prueba.txt && mkdir prueba-dir
> ls -ld prueba.txt prueba-dir
> umask 002
> ```
> El archivo nace `-rw-------` y la carpeta `drwx------`. Al final, `umask 002` deja la máscara como siempre.

**Ahora tú, con huecos:** `Con 027 → archivo: `rw-` `___` `---` · carpeta: `rwx` `___` `---``

<details>
<summary>Pista</summary>

Solo tienes que pensar el bloque del grupo: el `2` le quita la `w`. Un archivo parte de `rw-` y una carpeta de `rwx`: ¿qué les queda sin la `w`?
</details>

**4.** Ejecuta `find /usr/bin -perm -4000 2>/dev/null`: son los programas con setuid. Elige dos que conozcas e investiga por qué lo necesitan.

> 🧩 **Ejemplo resuelto:** por qué `passwd` tiene setuid.
> ```bash
> ls -l /usr/bin/passwd /etc/shadow
> ```
> `/etc/shadow` solo lo puede modificar root (`-rw-r-----`, dueño root). Cuando cambias tu contraseña, `passwd` tiene que escribir ahí. La `s` de `-rwsr-xr-x` hace que corra como su dueño, root, aunque lo lances tú.

**Ahora tú, con huecos:** `Para `su`: `ls -l /usr/bin/su` y `man su`. ¿Qué necesita hacer `su` que solo puede hacer root? → ____`

<details>
<summary>Pista</summary>

Lee la primera frase de `DESCRIPTION` en `man su`: ¿qué hace `su`? Hacerse pasar por otro usuario es algo que un usuario normal no puede hacer solo.
</details>

## Cierre

En `notas/fase-1/clase-06.md`:

1. Explica `rwxr-x---` **en un directorio**: qué puede hacer cada categoría. *(3 líneas, una por quién. Empieza así: «El dueño puede… El grupo puede… El resto…»)*
2. Con el directorio en `000`, ¿qué pasó con `ls caja`, con `cat caja/dato.txt` y con `ls -ld caja`? ¿Por qué el último sí funcionó? *(3 líneas. Empieza así: «`ls caja` falló porque faltaba el permiso… `cat` falló porque faltaba… `ls -ld` funcionó porque…»)*
3. Un compañero propone `chmod -R 777 /var/www` porque nginx da "Permission denied". ¿Qué le respondes y qué harías tú? *(3 líneas. Empieza así: «No, porque 777 deja que cualquiera… Yo miraría con qué usuario corre nginx y le daría solo…»)*
4. **Repaso (clase 05, sin mirar):** ¿con qué pipeline sacarías las 5 IPs que más peticiones hacen en un log de nginx? *(una línea. Empieza así: `awk '{print $…}' access.log | …`)*

Después, escríbeme `examíname clase-06`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Dueño (`rwx`): listar, crear y borrar archivos dentro, y entrar. Grupo (`r-x`): listar y entrar (y leer los archivos si sus propios permisos lo permiten), pero no crear ni borrar. Otros (`---`): nada, ni siquiera entrar.

**2.** `ls caja` → *Permiso denegado*: falta `r` para listar. `cat caja/dato.txt` → *Permission denied* (las uutils aún no lo traducen): falta `x` para atravesar el directorio. `ls -ld caja` funciona porque no entra en `caja`: lee su información (permisos, dueño) en el directorio **padre**, donde sí tienes permisos.

**3.** No: `777` da escritura a todo el mundo y convierte la web en un punto de entrada para cualquiera que comprometa un proceso de la máquina. Lo correcto: ver qué usuario ejecuta nginx (`ps aux | grep nginx` → `www-data`), qué permiso falta y en qué tramo de la ruta (`namei -l /var/www/html/index.html` lo enseña), y dar lo mínimo: archivos `644`, directorios `755`, y si hace falta, dueño o grupo `www-data` con `chown`.

**4.** `awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -5`

**Reto:**
```bash
mkdir equipo && chmod 750 equipo
touch equipo/config.ini && chmod g-w,o-r equipo/config.ini     # nace rw-rw-r--: sobran la w del grupo y la r del resto
# umask 027: archivo 666-027 → 640 (rw-r-----) · directorio 777-027 → 750 (rwxr-x---)
find /usr/bin -perm -4000 -ls
```
Ejemplos de setuid: `passwd` (escribe en `/etc/shadow`), `su` (cambia de usuario), `mount` (monta discos).
¿Y `sudo`? No sale en la lista: en Ubuntu 26.04, `/usr/bin/sudo` es un **enlace** a *sudo-rs*, el sudo reescrito en Rust, y `find` no sigue enlaces. `ls -l "$(readlink -f /usr/bin/sudo)"` muestra su `s`. El `sudo.ws` que sí aparece es el sudo clásico, que sigue instalado.
(Detalle: la máscara no "resta", **apaga bits**. Con `umask 027` coincide con la resta, pero la regla exacta es `permisos AND NOT umask`.)
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| owner / group / others | dueño / grupo / otros |
| read / write / execute | leer / escribir / ejecutar |
| least privilege | mínimo privilegio |
| permission denied | permiso denegado |
| file mode | permisos de un archivo |

🎙️ *"When I see 'permission denied', I check which user the process runs as and the permissions along the whole path, then I grant the minimum needed. Never 777."*

## Siguiente

[Clase 07 — Variables de entorno, PATH y el shell](clase-07-entorno-y-path.md)
