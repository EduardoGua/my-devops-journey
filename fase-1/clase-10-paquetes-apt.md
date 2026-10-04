# Clase 10 — Paquetes con apt

**Dónde:** VM `servidor-01` · **Tiempo:** 60 min · **Bloque:** B. Administrar un servidor

## Objetivo

- Instalar, actualizar, quitar y purgar software con `apt`.
- Entender **repositorios**, **dependencias** y **firmas**.
- Investigar paquetes: qué contienen, qué versión hay y de dónde vienen.
- Instalar **nginx**, el servidor web que usarás durante todo el curso.

## Por qué importa

Cada servidor se aprovisiona instalando paquetes: en el *user-data* de una EC2, en un `Dockerfile` (`RUN apt-get install …`) o en un pipeline. Mantenerlos actualizados es la defensa número uno contra vulnerabilidades conocidas. Y saber **qué versión** tienes y **de dónde** vino es básico cuando algo deja de funcionar tras una actualización.

## Teoría

### Paquetes y repositorios

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

- Un **paquete** (`.deb`) es un archivo con programas, configuración por defecto y metadatos: versión y **dependencias**.
- Un **repositorio** es un servidor con miles de paquetes y un índice. Ubuntu los configura en `/etc/apt/sources.list.d/`.
- `apt` es la herramienta cómoda. Por debajo, `dpkg` es quien instala de verdad los `.deb`.
- Los paquetes están **firmados**: apt verifica que vienen del repositorio oficial y no fueron manipulados.

### Comandos

| Comando | Qué hace |
|---------|----------|
| `sudo apt update` | Actualiza el **índice** local. No instala nada |
| `sudo apt upgrade` | Instala las versiones nuevas de lo que ya tienes |
| `sudo apt install pkg` | Instala con sus dependencias |
| `sudo apt remove pkg` | Desinstala, pero **deja su configuración** en `/etc` |
| `sudo apt purge pkg` | Desinstala y borra su configuración |
| `sudo apt autoremove` | Quita las dependencias que ya nadie usa |
| `apt search texto` | Busca paquetes |
| `apt show pkg` | Información: versión, tamaño, dependencias |
| `apt policy pkg` | Versión instalada, versión candidata y de qué repositorio viene |
| `apt list --installed` | Lista lo instalado |
| `dpkg -L pkg` | Archivos que instaló un paquete |
| `dpkg -S /ruta/archivo` | Qué paquete instaló ese archivo |
| `sudo apt-mark hold pkg` | Congela la versión (no se actualiza) |

> `apt` es para usar a mano. En **scripts** y Dockerfiles se usa `apt-get`, porque su salida no cambia entre versiones, con `-y` para no pedir confirmación.

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

1. ¿Qué paquete instaló el comando `ss`? ¿Y `ip`?
2. ¿Cuántos paquetes hay instalados en la VM?
3. Instala `cowsay` y luego quítalo **sin dejar rastro**, incluidas las dependencias que ya no se usan.
4. Escribe la línea que pondrías en un script de aprovisionamiento para instalar `nginx` y `curl` sin preguntas y sin fallar por un índice desactualizado.

## Cierre

En `notas/fase-1/clase-10.md`:

1. ¿Qué diferencia hay entre `apt update` y `apt upgrade`?
2. ¿Por qué `sudo echo "x" >> /etc/archivo` falla y `echo "x" | sudo tee -a /etc/archivo` funciona?
3. Acabas de lanzar una EC2 y `apt install` falla con "Could not get lock". ¿Qué pasa y qué haces?
4. **Repaso (clase 09, sin mirar):** ¿por qué se edita sudoers con `visudo` y no con `nano` directamente?

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
