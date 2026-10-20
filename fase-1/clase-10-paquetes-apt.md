# Clase 10 — Paquetes con apt

**Dónde:** VM `servidor-01` · **Tiempo:** 60 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** `apt` se parece a una tienda de aplicaciones: los programas salen de un **repositorio**. `apt update` descarga el **índice** al día (qué programas hay y en qué versión) y `apt install` trae el programa junto con todo lo que necesita para funcionar (sus *dependencias*), después de comprobar su firma para saber que viene del repositorio oficial.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `sudo` ejecuta un comando como root (clase 09).
> - `&&` ejecuta lo segundo solo si lo primero salió bien (clase 04).
> - `which` dice dónde está un programa, y `$( )` mete su resultado dentro de otro comando (clases 07 y 04).

> 🔤 **Palabras nuevas de hoy:**
> - **paquete** (`.deb`): un archivo con un programa listo para instalar.
> - **repositorio**: el servidor de donde salen los paquetes.
> - **índice de paquetes**: la lista de lo que hay en el repositorio y en qué versión.
> - **dependencia**: otro paquete que un programa necesita para funcionar.
> - **firma**: la prueba criptográfica de que un paquete viene del repositorio oficial y nadie lo ha modificado.

## Objetivo

- Instalar, actualizar, quitar y purgar software con `apt`.
- Entender **repositorios**, **dependencias** y **firmas**.
- Investigar paquetes: qué contienen, qué versión hay y de dónde vienen.
- Instalar **nginx**, el servidor web que usarás durante todo el curso.

## Por qué importa

Cada servidor se aprovisiona instalando paquetes: en el *user-data* de una EC2, en un `Dockerfile` (`RUN apt-get install …`) o en un pipeline. Mantenerlos actualizados es la defensa número uno contra vulnerabilidades conocidas. Y saber **qué versión** tienes y **de dónde** vino es básico cuando algo deja de funcionar tras una actualización.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida en el servidor; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 30 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Todo se hace dentro de la VM:

```bash
multipass shell servidor-01
```

## Las piezas

### Pieza 1 — El repositorio y el índice

```
 Repositorio de Ubuntu (internet)          Tu servidor
 ┌────────────────────────────┐            ┌──────────────────────────────┐
 │ índice: nginx 1.24, curl…  │ apt update │ /var/lib/apt/lists/          │
 │ paquetes .deb firmados     │──────────► │   (copia LOCAL del índice)   │
 └────────────────────────────┘            │                              │
               │          apt install nginx│                              │
               └──────────────────────────►│ descarga .deb + dependencias │
                                           │ verifica la firma            │
                                           │ dpkg los instala             │
                                           └──────────────────────────────┘
```

- Un **repositorio** es un servidor con miles de programas empaquetados. Ubuntu tiene configurados los suyos en `/etc/apt/sources.list.d/`.
- El **índice** dice qué programas hay y en qué versión. Tu servidor guarda **una copia local** del índice, que se queda vieja si no la actualizas.
- `apt update` descarga el **índice** nuevo. **No instala nada.**
- `apt install` mira el índice, descarga el programa y lo instala.

**Pruébalo:**

```bash
ls /etc/apt/sources.list.d/
cat /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
apt list --upgradable | head
```

👀 **Qué deberías ver:** los archivos de repositorios; el de Ubuntu por dentro (líneas `URIs:` y `Suites:`); `apt update` descargando índices (`Hit`, `Get`); y los paquetes que tienen versión nueva. Nada se instaló: solo se actualizó el índice.

✋ **Sin mirar:**
1. Acabas de crear un servidor y `apt install curl` dice `Unable to locate package`. ¿Qué te faltó hacer?
2. ¿`apt update` instala las versiones nuevas de tus programas?

<details>
<summary>Comprueba</summary>

1. `sudo apt update`: el índice local estaba vacío o viejo. 2. No: solo actualiza el **índice**. Instalar las versiones nuevas es `apt upgrade` (pieza 4).
</details>

**En resumen:** `apt update` actualiza el índice; `apt install` trae el programa.

### Pieza 2 — Paquetes y dependencias: instalar nginx

- Un **paquete** (`.deb`) es un archivo con el programa, su configuración por defecto y unos datos con su versión y lo que necesita.
- Lo que necesita son sus **dependencias**: otros paquetes sin los que no funciona. `apt` las trae solas.
- Cada paquete viene **firmado**: `apt` comprueba la firma y rechaza lo que no venga del repositorio oficial o haya sido manipulado.

**Pruébalo.** Primero, los datos del paquete; mira su línea `Depends`:

```bash
apt show nginx | head -20
```

🔮 **Predice:** después de instalarlo, ¿estará nginx ya funcionando o tendrás que arrancarlo tú?

```bash
sudo apt install -y nginx
curl -s localhost | head -5
systemctl status nginx --no-pager
```

<details>
<summary>Qué deberías ver</summary>

La información del paquete nginx (versión, dependencias como `nginx-common`, descripción), la instalación, el principio de su página de bienvenida (`<!DOCTYPE html>`…) y nginx en `active (running)`: ya funciona solo.
</details>

En Ubuntu, instalar un servicio suele **arrancarlo y activarlo** automáticamente. (En otras distribuciones, como Amazon Linux, no.)

**En resumen:** un paquete lleva el programa y sus datos: su versión, sus dependencias y su firma. `apt` trae las dependencias solas.

### Pieza 3 — `dpkg`, el que instala por debajo

Quien instala de verdad los paquetes es `dpkg`. `apt` organiza todo lo demás: busca, descarga y resuelve dependencias. Por eso, para saber **qué archivos** puso un paquete, o **qué paquete** puso un archivo, le preguntas a `dpkg`.

**Pruébalo:**

```bash
apt policy nginx
dpkg -L nginx-common | grep etc | head
dpkg -S /usr/sbin/nginx
dpkg -S "$(which curl)"
ls /etc/nginx/
```

👀 **Qué deberías ver:** la versión instalada y de qué repositorio viene; varios archivos de `/etc/nginx` que instaló `nginx-common`; el nombre del paquete que instaló cada archivo (`nginx` y `curl`); y las carpetas de configuración de nginx.

`nginx` es un paquete pequeño que **depende** de otros: los archivos de configuración los trae `nginx-common`.

**En resumen:** `apt` busca y descarga; `dpkg` instala y sabe qué archivo es de qué paquete.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Para salir de la VM, `exit`.

### Pieza 4 — Los cinco del día a día

```bash
sudo apt update              # 1. actualizar el índice (siempre lo primero)
sudo apt install nginx       # 2. instalar un programa (y sus dependencias)
sudo apt upgrade             # 3. actualizar todo lo que ya tienes a la versión del índice
sudo apt remove nginx        # 4. desinstalar, pero DEJAR su configuración en /etc
sudo apt purge nginx         # 5. desinstalar y BORRAR también su configuración
```

La diferencia entre `remove` y `purge` es la configuración: con `remove`, si lo reinstalas, recupera tu configuración; con `purge`, empieza de cero. Lo verás en el Rómpelo 1.

**Pruébalo: las herramientas que usarás en el curso.**

```bash
sudo apt install -y htop jq net-tools dnsutils traceroute tcpdump netcat-openbsd ufw rsync acl
```

`dnsutils` trae `dig`; `net-tools`, el antiguo `netstat`; `tcpdump` captura tráfico; `netcat-openbsd` es `nc`. Muchos ya vienen instalados: `apt` simplemente te dirá que ya están en la versión más reciente.

Ahora, actualiza todo el sistema:

```bash
sudo apt upgrade -y
cat /var/run/reboot-required 2>/dev/null || echo "no hace falta reiniciar"
```

👀 **Qué deberías ver:** la lista de paquetes que se actualizaron y, al final, `no hace falta reiniciar` o `*** System restart required ***`.

Si se actualizó el kernel, el nuevo **no se usa hasta reiniciar**. En producción, reiniciar se planifica.

✋ **Sin mirar:** quieres desinstalar nginx y que no quede ni rastro de su configuración. ¿`remove` o `purge`?

<details>
<summary>Comprueba</summary>

`purge`.
</details>

**En resumen:** update, install, upgrade, remove y purge: con esos cinco haces casi todo.

### Pieza 5 — Sin preguntas: `apt-get` en scripts y las actualizaciones automáticas

`apt` es para usarlo a mano: tiene colores y barras de progreso. En **scripts** y **Dockerfiles** se usa `apt-get`, porque su salida no cambia entre versiones, con `-y` para que no pregunte nada. Y en los servidores, Ubuntu instala solo los **parches de seguridad** cada día con `unattended-upgrades`.

**Pruébalo** como lo haría un script:

```bash
sudo apt-get update && sudo apt-get install -y tree
tree -L 1 /etc/nginx
```

👀 **Qué deberías ver:** el `update` y la instalación sin ninguna pregunta, y el árbol de carpetas de `/etc/nginx`.

Y las actualizaciones automáticas:

```bash
systemctl status unattended-upgrades --no-pager
cat /etc/apt/apt.conf.d/20auto-upgrades
```

👀 **Qué deberías ver:** el servicio en `active (running)`, y en el archivo dos líneas con `"1"`: actualizar el índice y aplicar los parches de seguridad, una vez al día. Es buena práctica en servidores, combinada con un control de cuándo se reinicia.

**En resumen:** a mano, `apt`; en scripts, `apt-get … -y`, y siempre después de un `update`. Los parches de seguridad se instalan solos.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `sudo apt update` | actualiza el índice local. No instala nada |
| `sudo apt install pkg` · `sudo apt upgrade` | instala con sus dependencias · actualiza lo que ya tienes |
| `sudo apt remove pkg` · `sudo apt purge pkg` | desinstala dejando / borrando su configuración |
| `sudo apt autoremove` | quita las dependencias que ya nadie usa |
| `apt search texto` · `apt show pkg` | busca paquetes · información: versión, tamaño, dependencias |
| `apt policy pkg` | versión instalada, versión candidata y de qué repositorio viene |
| `apt list --installed` | lo que tienes instalado |
| `dpkg -L pkg` · `dpkg -S /ruta/archivo` | qué archivos instaló un paquete · qué paquete instaló un archivo |
| `sudo apt-get update && sudo apt-get install -y pkg` | lo mismo, para scripts y Dockerfiles |
| `sudo apt-mark hold pkg` / `unhold` | congela su versión / la descongela |

## Rómpelo

**1. `remove` frente a `purge`:**
```bash
sudo cp /etc/nginx/nginx.conf /tmp/nginx.conf.bak
echo "# mi cambio" | sudo tee -a /etc/nginx/nginx.conf
sudo apt remove -y nginx nginx-common
ls /etc/nginx/                     # ¡la configuración sigue ahí!
dpkg -l | grep nginx               # estado "rc": removed, config-files
sudo apt install -y nginx
tail -1 /etc/nginx/nginx.conf      # tu cambio sobrevivió
```
`remove` conserva la configuración por si reinstalas. Si una configuración rota te persigue entre reinstalaciones, la solución es `purge`. Restaura el original:
```bash
sudo cp /tmp/nginx.conf.bak /etc/nginx/nginx.conf
```

(Has usado `sudo tee -a`: `sudo echo "x" >> /etc/archivo` **no funciona**, porque la redirección `>>` la hace tu shell, que no es root. `tee` sí se ejecuta como root y escribe el archivo.)

**2. El bloqueo de apt:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
Abre **dos** `multipass shell servidor-01`. En la primera: `sudo apt install -y cowsay` y, mientras corre, en la segunda: `sudo apt install -y sl`.
Verás `Could not get lock /var/lib/dpkg/lock-frontend`: solo puede haber un apt a la vez. En una EC2 recién creada pasa mucho, porque `unattended-upgrades` o `cloud-init` están usando apt en los primeros minutos. **No se borra el archivo de lock**: se espera a que el otro proceso termine.

**3. Un paquete que no existe:**
```bash
sudo apt install -y paquete-que-no-existe
```
`Unable to locate package`. Las causas reales: un nombre mal escrito, que el paquete esté en otro repositorio, o que nunca se hizo `apt update` (pasa mucho en contenedores recién creados).

**4. Congelar una versión:**
```bash
sudo apt-mark hold nginx
apt-mark showhold
sudo apt-mark unhold nginx
```
Se usa cuando una versión nueva rompe algo y necesitas tiempo para adaptarte. No debe quedarse congelada para siempre, porque dejarías de recibir parches.

## Reto

En la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Qué paquete instaló el comando `ss`? ¿Y `ip`?

> 🧩 **Ejemplo resuelto:** ¿qué paquete instaló `curl`?
> ```bash
> dpkg -S "$(which curl)"
> ```
> `which curl` da la ruta del programa (`/usr/bin/curl`) y `dpkg -S` dice qué paquete instaló ese archivo: `curl`.

**Ahora tú, con huecos:** `dpkg -S "$(which ____)"`

<details>
<summary>Pista</summary>

Ejecútalo dos veces, una con cada nombre. Hazlo en la VM: en tu PC, por cómo es tu PATH, `which` puede dar `/bin/…` y `dpkg` solo conoce la ruta `/usr/bin/…`.
</details>

**2.** ¿Cuántos paquetes hay instalados en la VM?

> 🧩 **Ejemplo resuelto:** ¿cuántos paquetes tienen una versión nueva disponible?
> ```bash
> apt list --upgradable 2>/dev/null | wc -l
> ```
> `apt list` saca un paquete por línea, `2>/dev/null` descarta un aviso que `apt` escribe por stderr y `wc -l` cuenta. La primera línea es `Listing...`, así que el número real es uno menos.

**Ahora tú, con huecos:** `apt list --____ 2>/dev/null | wc -l`

<details>
<summary>Pista</summary>

La opción de `apt list` que enseña lo instalado está en la chuleta.
</details>

**3.** Instala `cowsay` y luego quítalo **sin dejar rastro**, incluidas las dependencias que ya no se usan.

> 🧩 **Ejemplo resuelto:** instalar el paquete `sl` (un tren que cruza tu terminal), probarlo y quitarlo.
> ```bash
> sudo apt install -y sl
> /usr/games/sl
> sudo apt remove -y sl
> ```
> `remove` quita el programa, pero deja su configuración. En el reto quieres borrarlo **todo**.

**Ahora tú, con huecos:**
```bash
sudo apt install -y cowsay
sudo apt ____ -y cowsay
sudo apt ____ -y
```

<details>
<summary>Pista</summary>

El primer hueco desinstala borrando también la configuración. El segundo quita las dependencias que ya nadie usa. Los dos están en la chuleta.
</details>

**4.** Escribe la línea que pondrías en un script de aprovisionamiento para instalar `nginx` y `curl` sin preguntas y sin fallar por un índice desactualizado.

> 🧩 **Ejemplo resuelto:** la línea para instalar `jq` en un script.
> ```bash
> sudo apt-get update && sudo apt-get install -y jq
> ```
> Primero el índice, y solo si salió bien (`&&`), la instalación sin preguntas (`-y`).

**Ahora tú, con huecos:** `sudo apt-get ____ && sudo apt-get install ____ nginx curl`

<details>
<summary>Pista</summary>

Es el ejemplo con otros dos paquetes.
</details>

## Cierre

En `notas/fase-1/clase-10.md`:

1. ¿Qué diferencia hay entre `apt update` y `apt upgrade`? *(2 líneas. Empieza así: «`apt update` descarga…, pero no… `apt upgrade`…»)*
2. ¿Por qué `sudo echo "x" >> /etc/archivo` falla y `echo "x" | sudo tee -a /etc/archivo` funciona? *(2–3 líneas. Empieza así: «Porque el `>>` lo hace mi shell, que no es root, antes de… Con `tee`, quien abre el archivo es…»)*
3. Acabas de lanzar una EC2 y `apt install` falla con "Could not get lock". ¿Qué pasa y qué haces? *(2 líneas. Empieza así: «Otro proceso, como cloud-init o las actualizaciones automáticas, está usando… Yo esperaría a que…, sin borrar…»)*
4. **Repaso (clase 09, sin mirar):** ¿por qué se edita sudoers con `visudo` y no con `nano` directamente? *(1–2 líneas. Empieza así: «Porque `visudo` comprueba…, y un error en sudoers…»)*

Después, escríbeme `examíname clase-10`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `update` descarga el **índice** actualizado de los repositorios: qué versiones existen. No instala nada. `upgrade` instala las versiones nuevas de los paquetes ya instalados, según ese índice. Por eso se hace `update` antes.

**2.** En `sudo echo "x" >> /etc/archivo`, la redirección `>>` la procesa **tu shell** (sin privilegios) antes de ejecutar nada; `sudo` solo eleva a `echo`, que no abre el archivo. Con `tee`, el programa que abre y escribe el archivo se ejecuta con `sudo`, así que tiene permiso.

**3.** Otro proceso de apt/dpkg está en marcha. En una instancia nueva suele ser `cloud-init` o `unattended-upgrades`. Se comprueba con `ps aux | grep -E "apt|dpkg"` y se **espera** a que termine (en scripts, con un bucle o con `cloud-init status --wait`). Nunca se borra el lock: podrías corromper la base de datos de paquetes.

**4.** Porque `visudo` comprueba la sintaxis antes de guardar. Un error en sudoers puede romper `sudo` para todos los usuarios, y en un servidor sin acceso root directo (como una EC2) eso te deja sin forma de administrarlo.

**Reto:**
```bash
dpkg -S "$(which ss)"      # iproute2
dpkg -S "$(which ip)"      # iproute2
apt list --installed 2>/dev/null | wc -l     # menos 1, por la línea «Listing...»; o: dpkg -l | grep -c '^ii'
sudo apt install -y cowsay && sudo apt purge -y cowsay && sudo apt autoremove -y
sudo apt-get update && sudo apt-get install -y nginx curl
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| package manager | gestor de paquetes |
| repository | repositorio |
| dependency | dependencia |
| to upgrade / to patch | actualizar / parchear |
| lock file | archivo de bloqueo |
| provisioning | aprovisionamiento |

🎙️ *"In provisioning scripts I use `apt-get update && apt-get install -y` in the same step, so the package index is never stale."*

## Siguiente

[Clase 11 — Procesos y señales](clase-11-procesos-y-senales.md)
