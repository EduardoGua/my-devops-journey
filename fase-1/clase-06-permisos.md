# Clase 06 — Permisos: usuarios, grupos y rwx

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

## Objetivo

- Leer cualquier permiso (`rwxr-x---`, `750`) y saber **qué puede hacer cada quien**.
- Entender que `r`, `w` y `x` significan cosas **distintas en archivos y en directorios**.
- Cambiar permisos con `chmod` (simbólico y numérico) y entender `umask`.
- Saber por qué `chmod 777` nunca es la solución.

## Por qué importa

"Permission denied" es uno de los errores más comunes en producción: nginx no puede leer la web, una app no puede escribir su log, SSH rechaza tu llave porque los permisos son demasiado abiertos. Y los permisos son la base de la **seguridad**: el mismo principio de *mínimo privilegio* que aplicarás en IAM de AWS empieza aquí.

## Teoría

### Usuarios y grupos

Cada proceso corre como un **usuario**, y cada usuario pertenece a uno o varios **grupos**. Cada archivo tiene un **dueño** y un **grupo**.

```bash
id          # uid=1000(educo) gid=1000(educo) groups=1000(educo),27(sudo),...
```

### Los nueve bits

```
-rwxr-x---  1 educo devs  ... script.sh
 └┬┘└┬┘└┬┘
  │  │  └── otros (o): todos los demás
  │  └───── grupo (g): miembros del grupo "devs"
  └──────── dueño (u): educo
```

El kernel comprueba **en orden** y aplica **solo la primera categoría que te corresponde**:
1. ¿Eres el dueño? → se usan los permisos del dueño (y nada más).
2. Si no, ¿estás en el grupo? → permisos del grupo.
3. Si no → permisos de otros.

(La excepción es **root**, que se salta casi todas las comprobaciones.)

### `rwx` en archivos y en directorios

| Bit | En un **archivo** | En un **directorio** |
|-----|-------------------|----------------------|
| `r` (4) | leer el contenido | **listar** los nombres de dentro (`ls`) |
| `w` (2) | modificar el contenido | **crear, borrar y renombrar** archivos dentro |
| `x` (1) | ejecutarlo como programa | **entrar** (`cd`) y acceder a lo de dentro por su nombre |

Consecuencias que sorprenden:
- Borrar un archivo depende del permiso `w` del **directorio**, no del archivo.
- Un directorio con `r` pero sin `x` te deja ver nombres, pero no abrir nada.
- Para leer `/a/b/c.txt` necesitas `x` en `/`, `/a` y `/a/b`, y `r` en `c.txt`.

### Notación numérica (octal)

`r = 4`, `w = 2`, `x = 1`. Se suman por categoría:

| Octal | Permisos | Uso típico |
|-------|----------|------------|
| `755` | `rwxr-xr-x` | scripts, directorios públicos |
| `644` | `rw-r--r--` | archivos de configuración o de una web |
| `700` | `rwx------` | directorio privado (`~/.ssh`) |
| `600` | `rw-------` | archivo privado (llave SSH, contraseñas) |
| `750` | `rwxr-x---` | directorio de un equipo (dueño y grupo) |
| `777` | `rwxrwxrwx` | ❌ cualquiera hace cualquier cosa |

### `chmod`

```bash
chmod 640 archivo           # numérico: fija los 9 bits
chmod u+x script.sh         # simbólico: añade x al dueño
chmod g-w,o-r archivo       # quita w al grupo y r a otros
chmod -R 750 directorio     # recursivo (¡cuidado!)
```

`chown usuario:grupo archivo` cambia dueño y grupo. Cambiar el dueño requiere ser root: lo practicarás en el servidor (clase 09).

### `umask`: el molde de los archivos nuevos

Los archivos nuevos nacen con `666` menos la máscara y los directorios con `777` menos la máscara. Con `umask 002` (la típica de Ubuntu para tu usuario), un archivo nace con `664` y un directorio con `775`. `umask` cambia la máscara **solo en ese shell**: al cerrar la terminal vuelve a la de siempre.

### Bits especiales (para reconocerlos)

- **setuid** (`s` en lugar de la `x` del dueño): el programa corre con los permisos de **su dueño**. `/usr/bin/passwd` lo tiene para poder escribir en `/etc/shadow`.
- **sticky bit** (`t` al final): en `/tmp` todos pueden crear archivos, pero solo el dueño puede borrar los suyos.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-06 && cd ~/my-devops-journey/labs/clase-06
id
umask
```

### 1. Leer permisos del sistema

```bash
ls -l /etc/passwd /etc/shadow /usr/bin/passwd
ls -ld /tmp /root ~
cat /etc/shadow
```

🔮 **Predice antes del `cat`:** ¿podrás leer `/etc/shadow`? Mira sus permisos.

`/etc/shadow` guarda los hashes de las contraseñas: solo root y el grupo `shadow` pueden leerlo.

### 2. Un script sin permiso de ejecución

```bash
printf '#!/bin/bash\necho "hola desde el script"\n' > hola.sh
ls -l hola.sh
./hola.sh
```

🔮 **Predice:** ¿funcionará? Mira la columna de permisos antes.

```bash
chmod u+x hola.sh
ls -l hola.sh
./hola.sh
bash hola.sh        # esto funciona incluso sin x: bash LEE el archivo (necesita r)
```

`./hola.sh` pide al kernel **ejecutar** el archivo (hace falta `x`). `bash hola.sh` ejecuta `bash`, que solo **lee** el archivo (basta con `r`).

### 3. Archivos privados

```bash
echo "secreto" > privado.txt
ls -l privado.txt          # 664 con tu umask
chmod 600 privado.txt
ls -l privado.txt
```

### 4. Directorios: r, w y x por separado

```bash
mkdir caja && echo "dato" > caja/dato.txt
ls -ld caja
```

Para cada bloque, 🔮 **predice** qué funcionará y qué no **antes** de ejecutarlo:

**Sin nada (000):**
```bash
chmod 000 caja
ls caja
cat caja/dato.txt
cd caja
ls -ld caja           # esto sí funciona: lee la información del directorio desde el padre
```

**Solo lectura (r--, 400):**
```bash
chmod 400 caja
ls caja               # ves el NOMBRE...
cat caja/dato.txt     # ...pero no puedes abrirlo: falta x
```

**Solo paso (--x, 100):**
```bash
chmod 100 caja
ls caja               # no puedes listar...
cat caja/dato.txt     # ...pero si sabes el nombre, entras directo
```

**Lectura y paso, sin escritura (r-x, 500):**
```bash
chmod 500 caja
cat caja/dato.txt
rm caja/dato.txt      # no puedes borrar: borrar es escribir en el DIRECTORIO
touch caja/nuevo.txt
```

```bash
chmod 755 caja        # deja la caja en un estado normal
```

### 5. `umask` en acción

```bash
umask
touch con-umask-normal.txt && mkdir dir-normal
umask 077
touch con-umask-077.txt && mkdir dir-077
ls -ld con-umask-* dir-*
umask 002             # restaura (o cierra la terminal)
```

## Rómpelo

**1. La trampa del dueño:**
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

1. Crea `equipo/` con permisos para que el dueño haga todo, el grupo pueda entrar y leer, y los demás nada. Usa notación numérica.
2. Dentro, crea `config.ini` que el dueño pueda leer y escribir y el grupo solo leer. Notación **simbólica**, partiendo de lo que tenga al crearse.
3. Calcula sin ejecutar: con `umask 027`, ¿con qué permisos nacen un archivo y un directorio? Compruébalo después.
4. Encuentra en `/usr/bin` los programas con setuid: `find /usr/bin -perm -4000`. Elige dos e investiga (`man`) por qué lo necesitan.

## Cierre

En `notas/fase-1/clase-06.md`:

1. Explica `rwxr-x---` **en un directorio**: qué puede hacer cada categoría.
2. Con el directorio en `000`, ¿qué pasó con `ls caja`, con `cat caja/dato.txt` y con `ls -ld caja`? ¿Por qué el último sí funcionó?
3. Un compañero propone `chmod -R 777 /var/www` porque nginx da "Permission denied". ¿Qué le respondes y qué harías tú?
4. **Repaso (clase 05, sin mirar):** ¿con qué pipeline sacarías las 5 IPs que más peticiones hacen en un log de nginx?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Dueño (`rwx`): listar, crear y borrar archivos dentro, y entrar. Grupo (`r-x`): listar y entrar (y leer los archivos si sus propios permisos lo permiten), pero no crear ni borrar. Otros (`---`): nada, ni siquiera entrar.

**2.** `ls caja` → *Permission denied*: falta `r` para listar. `cat caja/dato.txt` → *Permission denied*: falta `x` para atravesar el directorio. `ls -ld caja` funciona porque no entra en `caja`: lee su información (permisos, dueño) en el directorio **padre**, donde sí tienes permisos.

**3.** No: `777` da escritura a todo el mundo y convierte la web en un punto de entrada para cualquiera que comprometa un proceso de la máquina. Lo correcto: ver qué usuario ejecuta nginx (`ps aux | grep nginx` → `www-data`), qué permiso falta y en qué tramo de la ruta (`namei -l /var/www/html/index.html` lo enseña), y dar lo mínimo: archivos `644`, directorios `755`, y si hace falta, dueño o grupo `www-data` con `chown`.

**4.** `awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -5`

**Reto:**
```bash
mkdir equipo && chmod 750 equipo
touch equipo/config.ini && chmod u=rw,g=r,o= equipo/config.ini
# umask 027: archivo 666-027 → 640 (rw-r-----) · directorio 777-027 → 750 (rwxr-x---)
find /usr/bin -perm -4000 -ls
```
Ejemplos de setuid: `passwd` (escribe en `/etc/shadow`), `sudo` (eleva privilegios), `su`, `mount`.
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
