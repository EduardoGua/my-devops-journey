# Clase 10 — Paquetes con apt

**Dónde:** VM `servidor-01` · **Tiempo:** 60 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** `apt` funciona como una **tienda de aplicaciones con catálogo**. `apt update` descarga el catálogo al día (qué programas hay y en qué versión) y `apt install` trae el programa junto con todo lo que necesita para funcionar (sus *dependencias*), después de comprobar su firma para saber que viene de la tienda oficial.

## Objetivo

- Instalar, actualizar, quitar y purgar software con `apt`.
- Entender **repositorios**, **dependencias** y **firmas**.
- Investigar paquetes: qué contienen, qué versión hay y de dónde vienen.
- Instalar **nginx**, el servidor web que usarás durante todo el curso.

## Por qué importa

Cada servidor se aprovisiona instalando paquetes: en el *user-data* de una EC2, en un `Dockerfile` (`RUN apt-get install …`) o en un pipeline. Mantenerlos actualizados es la defensa número uno contra vulnerabilidades conocidas. Y saber **qué versión** tienes y **de dónde** vino es básico cuando algo deja de funcionar tras una actualización.

## Teoría

Cuatro piezas, con la imagen de la tienda de *La idea de hoy*.

### 1. El catálogo y la tienda

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

- La **tienda** es un **repositorio**: un servidor con miles de programas empaquetados. Ubuntu tiene configurados los suyos en `/etc/apt/sources.list.d/`.
- El **catálogo** es el índice: qué programas hay y en qué versión. Tu servidor guarda **una copia local** del catálogo, que se queda vieja si no la actualizas.
- `apt update` descarga el **catálogo** nuevo. **No instala nada.**
- `apt install` mira el catálogo, descarga el programa y lo instala.

### 2. Paquetes, dependencias y firmas

- Un **paquete** (`.deb`) es una caja con el programa, su configuración por defecto y una etiqueta con su versión y lo que necesita.
- Lo que necesita son sus **dependencias**: otros paquetes sin los que no funciona. `apt` las trae solas.
- Cada caja viene **firmada**: `apt` comprueba la firma y rechaza lo que no venga de la tienda oficial o haya sido manipulado.
- Por debajo, quien instala de verdad las cajas es `dpkg`. `apt` es el dependiente amable que lo organiza todo.

### 3. Los cinco del día a día

```bash
sudo apt update              # 1. actualizar el catálogo (siempre lo primero)
sudo apt install nginx       # 2. instalar un programa (y sus dependencias)
sudo apt upgrade             # 3. actualizar todo lo que ya tienes a la versión del catálogo
sudo apt remove nginx        # 4. desinstalar, pero DEJAR su configuración en /etc
sudo apt purge nginx         # 5. desinstalar y BORRAR también su configuración
```

`remove` frente a `purge` es como devolver un mueble guardando o tirando las instrucciones de montaje: con `remove`, si lo reinstalas, recupera tu configuración. Lo verás en el Rómpelo 1.

### 4. `apt` para ti, `apt-get` para los scripts

`apt` es para usarlo a mano: tiene colores y barras de progreso. En **scripts** y **Dockerfiles** se usa `apt-get`, porque su salida no cambia entre versiones, con `-y` para que no pregunte nada:

```bash
sudo apt-get update && sudo apt-get install -y nginx
```

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Acabas de crear un servidor y `apt install curl` dice `Unable to locate package`. ¿Qué te faltó hacer?
2. ¿`apt update` instala las versiones nuevas de tus programas?
3. Quieres desinstalar nginx y que no quede ni rastro de su configuración. ¿`remove` o `purge`?

<details>
<summary>Comprueba</summary>

1. `sudo apt update`: el catálogo local estaba vacío o viejo. 2. No: solo actualiza el **catálogo**. Instalar las versiones nuevas es `apt upgrade`. 3. `purge`.
</details>

### Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `sudo apt update` | actualiza el catálogo local. No instala nada |
| `sudo apt install pkg` · `sudo apt upgrade` | instala con sus dependencias · actualiza lo que ya tienes |
| `sudo apt remove pkg` · `sudo apt purge pkg` | desinstala dejando / borrando su configuración |
| `sudo apt autoremove` | quita las dependencias que ya nadie usa |
| `apt search texto` · `apt show pkg` | busca paquetes · información: versión, tamaño, dependencias |
| `apt policy pkg` | versión instalada, versión candidata y de qué repositorio viene |
| `apt list --installed` | lo que tienes instalado |
| `dpkg -L pkg` · `dpkg -S /ruta/archivo` | qué archivos instaló un paquete · qué paquete instaló un archivo |
| `sudo apt-mark hold pkg` / `unhold` | congela su versión / la descongela |

## Práctica guiada

```bash
multipass shell servidor-01
```

### 1. El índice

```bash
ls /etc/apt/sources.list.d/
cat /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
apt list --upgradable | head
```

### 2. Instalar nginx

🔮 **Predice:** después de instalarlo, ¿estará nginx ya funcionando o tendrás que arrancarlo tú?

```bash
apt show nginx | head -20
sudo apt install -y nginx
curl -s localhost | head -5
systemctl status nginx --no-pager
```

En Ubuntu, instalar un servicio suele **arrancarlo y activarlo** automáticamente. (En otras distribuciones, como Amazon Linux, no.)

### 3. Investigar un paquete

```bash
apt policy nginx
dpkg -L nginx-common | grep etc | head
dpkg -S /usr/sbin/nginx
dpkg -S "$(which curl)"
ls /etc/nginx/
```

`nginx` es un paquete pequeño que **depende** de otros (`nginx-common`…). Mira la línea `Depends` de `apt show nginx`.

### 4. Herramientas que usarás

```bash
sudo apt install -y htop tree jq net-tools dnsutils traceroute tcpdump netcat-openbsd ufw rsync acl
```

`dnsutils` trae `dig`; `net-tools`, el antiguo `netstat`; `tcpdump` captura tráfico; `netcat-openbsd` es `nc`. Muchos ya vienen instalados: `apt` simplemente te dirá que ya están en la versión más reciente. Los usarás en el resto del curso.

### 5. Actualizar el sistema

```bash
sudo apt upgrade -y
cat /var/run/reboot-required 2>/dev/null || echo "no hace falta reiniciar"
```

Si se actualizó el kernel, el nuevo **no se usa hasta reiniciar**. En producción, reiniciar se planifica.

### 6. Actualizaciones de seguridad automáticas

```bash
systemctl status unattended-upgrades --no-pager
cat /etc/apt/apt.conf.d/20auto-upgrades
```

Ubuntu instala solo los **parches de seguridad** cada día. Es buena práctica en servidores, combinada con un control de cuándo se reinicia.

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

En la VM. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** ¿Qué paquete instaló el comando `ss`? ¿Y `ip`?

<details>
<summary>Pista</summary>

`dpkg -S /ruta/del/archivo` dice qué paquete instaló un archivo. ¿Y la ruta de `ss`? Te la da `which`. Puedes juntarlos con `$( )`, como en la clase 04.
</details>

**2.** ¿Cuántos paquetes hay instalados en la VM?

<details>
<summary>Pista</summary>

`apt list --installed` los lista, uno por línea. ¿Con qué cuentas líneas?
</details>

**3.** Instala `cowsay` y luego quítalo **sin dejar rastro**, incluidas las dependencias que ya no se usan.

<details>
<summary>Pista</summary>

Dos órdenes de la pieza 3 y la chuleta: la que desinstala **borrando** también la configuración, y la que quita las dependencias que ya nadie usa.
</details>

**4.** Escribe la línea que pondrías en un script de aprovisionamiento para instalar `nginx` y `curl` sin preguntas y sin fallar por un catálogo desactualizado.

<details>
<summary>Pista</summary>

Está en la pieza 4 de la teoría: `apt-get`, `&&` y `-y`.
</details>

## Cierre

En `notas/fase-1/clase-10.md`:

1. ¿Qué diferencia hay entre `apt update` y `apt upgrade`?
2. ¿Por qué `sudo echo "x" >> /etc/archivo` falla y `echo "x" | sudo tee -a /etc/archivo` funciona?
3. Acabas de lanzar una EC2 y `apt install` falla con "Could not get lock". ¿Qué pasa y qué haces?
4. **Repaso (clase 09, sin mirar):** ¿por qué se edita sudoers con `visudo` y no con `nano` directamente?

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
apt list --installed 2>/dev/null | wc -l     # o: dpkg -l | grep -c '^ii'
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
