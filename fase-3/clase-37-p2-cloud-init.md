# Clase 37 — P2: Servidor reproducible con cloud-init

**Dónde:** tu PC + VMs que crearás y destruirás · **Tiempo:** 2 bloques largos (unas 4–6 h) · **Bloque:** B. Proyectos y examen · **Laboratorio integrador**

> 💡 **La idea de hoy:** en vez de configurar un servidor a mano, escribes **un archivo** que lo describe entero (usuarios, SSH endurecido, paquetes, nginx, firewall) y **cloud-init** lo aplica en el primer arranque. Si el servidor se rompe, lo destruyes y lo recreas idéntico en minutos. Es lo mismo que el *user-data* de una EC2, y el primer paso hacia la infraestructura como código.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Usuarios sin contraseña y llaves SSH, y SSH endurecido en `sshd_config.d` (clases 09 y 15).
> - Paquetes y `unattended-upgrades` (clase 10).
> - nginx con un sitio propio y un `/health` (clases 12 y 32).
> - `ufw`, con OpenSSH siempre primero (clase 33).
> - Scripts que salen con 0 solo si todo va bien (clases 17 y 19).

> 🔤 **Palabras nuevas de hoy:**
> - **cloud-init**: el programa que configura una VM en su primer arranque.
> - **user-data**: la configuración que le das a cloud-init (en AWS, al lanzar la EC2).
> - **YAML**: el formato del archivo, con la sangría hecha de espacios.
> - **`fail2ban`**: el servicio que banea las IPs que fallan varias veces al entrar por SSH.
> - **reproducible**: que se puede recrear idéntico, desde cero, con un comando.

## Objetivo

Escribir **un único archivo** que convierta un Ubuntu recién creado en un servidor web **endurecido y verificado**, sin tocarlo a mano: usuario con llave, SSH sin contraseñas ni root, firewall, nginx con health check y actualizaciones automáticas. Después, demostrar que es **reproducible**: destruir el servidor y recrearlo idéntico en minutos.

Este proyecto junta las fases 1 a 3 y es el puente directo a AWS: el mismo archivo funciona como **user-data** de una EC2.

## Por qué importa

> *"Treat servers like cattle, not pets."*

Un servidor configurado a mano (una **mascota**) es irrepetible: nadie recuerda los 40 comandos que se le aplicaron, y si muere, se pierde. Un servidor definido en código (**ganado**) se recrea igual cuantas veces haga falta: para escalar, para recuperarse de un desastre o para tener staging igual a producción. Esa es la idea central de DevOps, y la que llevarás a Docker (fase 5), Terraform (fase 8) y Kubernetes (fase 9).

## Requisitos del proyecto

El servidor `web-01` debe cumplir **todo** esto nada más arrancar, sin intervención:

| # | Requisito | Clase |
|---|-----------|-------|
| R1 | Usuario `deploy` con tu llave pública, sin contraseña utilizable | 09, 15 |
| R2 | SSH: sin contraseñas, sin root y con `MaxAuthTries 3` | 15 |
| R3 | Paquetes actualizados y `unattended-upgrades` activo | 10 |
| R4 | nginx sirve una página propia y `GET /health` → `200 ok` | 12, 32 |
| R5 | Firewall: solo entran 22 y 80. Todo lo demás, descartado | 33 |
| R6 | `fail2ban` activo (banea IPs tras intentos de SSH fallidos) | 13, 15 |
| R7 | La configuración se puede recrear **idéntica** en < 5 minutos | 08 |
| R8 | Un script `verify.sh` comprueba R1–R6 **desde fuera** y sale con código 0 solo si todo está bien | 04, 19, 26, 29 |

## Práctica guiada

Cinco pasos. La teoría de cloud-init está en el paso 2, justo donde empiezas a usarla. Si la haces en dos sesiones, la primera termina con el paso 3 (todos los requisitos en el YAML) y la segunda empieza con `verify.sh`.

### 1. Estructura

```bash
mkdir -p ~/my-devops-journey/projects/p2-cloud-init-server
cd ~/my-devops-journey/projects/p2-cloud-init-server
```

Tu llave pública **no** irá escrita en el repo: el YAML tendrá un marcador que sustituirás al lanzar. Así el archivo sirve a cualquier persona y no publicas ni siquiera tu pública por costumbre.

### 2. Empieza pequeño

**cloud-init** es el programa que se ejecuta en el **primer arranque** de casi cualquier imagen Linux de la nube (AWS, Azure, GCP… y Multipass). Lee una configuración (*user-data*) y la aplica: usuarios, paquetes, archivos, comandos.

```
multipass launch --cloud-init p2.yaml   ≈   EC2 → Launch instance → Advanced → User data: p2.yaml
                         │
                         ▼
             primer arranque: cloud-init lee el YAML
             ├── crea usuarios y llaves
             ├── instala paquetes
             ├── escribe archivos
             └── ejecuta comandos (runcmd)
```

Formato **YAML** (la primera línea **debe** ser exactamente `#cloud-config`). Las claves que usarás:

| Clave | Para qué |
|-------|----------|
| `package_update`, `package_upgrade`, `packages` | `apt update`, `upgrade` e instalar |
| `users` | crear usuarios, grupos, sudo y llaves SSH. ⚠️ incluye `- default` para conservar el usuario `ubuntu` (Multipass lo necesita) |
| `ssh_pwauth`, `disable_root` | contraseñas por SSH y acceso de root |
| `write_files` | crear archivos con contenido y permisos |
| `runcmd` | comandos que se ejecutan al final, **una sola vez** |
| `final_message` | mensaje al terminar (útil en los logs) |

Para depurar, dentro de la VM:
- `cloud-init status --wait --long`: espera a que termine y dice si hubo errores.
- `/var/log/cloud-init-output.log`: la salida de todo lo que ejecutó.
- `sudo cloud-init schema --system`: valida la configuración que recibió.

**YAML es estricto con la indentación**: usa **espacios** (nunca tabuladores). Un error de sangría puede hacer que se ignore una sección entera sin avisar mucho.

**Ahora, tu primer YAML.** Primero, solo el usuario. Crea `cloud-init.yaml`:
```yaml
#cloud-config
hostname: web-01

users:
  - default
  - name: deploy
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - __SSH_PUBKEY__
```

Lanza una VM de prueba con la llave sustituida:
```bash
sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/lab_ed25519.pub)|" cloud-init.yaml > /tmp/p2.yaml
multipass launch lts --name web-01 --memory 1G --disk 8G --cloud-init /tmp/p2.yaml
IPW=$(multipass info web-01 | awk '/IPv4/ {print $2}')
ssh -i ~/.ssh/lab_ed25519 -o IdentitiesOnly=yes deploy@$IPW 'whoami; hostname'
```

¿Funciona? Destrúyela (`multipass delete --purge web-01`) y añade el siguiente requisito. **Un requisito cada vez**: si añades 8 cosas y falla, no sabrás cuál fue.

### 3. Ve completando

Añade, uno a uno, lanzando y verificando cada vez:
- **R3**: `package_update`, `package_upgrade`, `packages` con `nginx`, `ufw`, `fail2ban`, `unattended-upgrades`.
- **R2**: `ssh_pwauth: false`, `disable_root: true` y un `write_files` con `/etc/ssh/sshd_config.d/00-hardening.conf` (como en la clase 15). Recuerda que `AllowUsers` debe incluir `deploy` **y** `ubuntu`, o Multipass dejará de poder entrar.
- **R4**: `write_files` con la página y el sitio de nginx (`location = /health { return 200 "ok\n"; }`), y en `runcmd`, enlazar el sitio, quitar el `default`, `nginx -t` y recargar.
- **R5**: en `runcmd`, las reglas de ufw (¡OpenSSH primero!) y `ufw --force enable`.
- **R6**: en `runcmd`, `systemctl enable --now fail2ban`.
- Y al final de `runcmd`: `sshd -t && systemctl restart ssh`.

Cuando falle algo:
```bash
multipass exec web-01 -- cloud-init status --long
multipass exec web-01 -- sudo tail -50 /var/log/cloud-init-output.log
```

Valida la sintaxis **antes** de lanzar:
```bash
cloud-init schema -c cloud-init.yaml
```

### 4. `verify.sh`: pruebas automáticas desde fuera

Crea `verify.sh`, que reciba la IP como argumento y compruebe R1, R2, R4, R5 y R6. Estructura sugerida:

```bash
#!/bin/bash
# Uso: ./verify.sh <IP> [llave privada]
set -u
IP="${1:?Uso: $0 <IP> [llave]}"
KEY="${2:-$HOME/.ssh/lab_ed25519}"
FALLOS=0

check() {   # check "descripción" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "✅ $desc"; else echo "❌ $desc"; FALLOS=$((FALLOS + 1)); fi
}

SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
SSH="ssh -i $KEY $SSH_OPTS"
remoto() { $SSH deploy@"$IP" "$@"; }   # ejecuta un comando en el servidor como deploy

check "R1 deploy entra con llave"            remoto true
# check "R2 el servidor no ofrece contraseñas" ...
# check "R2 PermitRootLogin no"                ...   (pista: 'sudo sshd -T' muestra la configuración efectiva)
# check "R4 /health responde 200"              ...
# check "R5 lo que no es 22/80 no llega"       ...   (lee el aviso de abajo antes de escribirla)
# check "R6 fail2ban activo"                   ...

echo "Fallos: $FALLOS"
exit $(( FALLOS > 0 ))
```

Completa las comprobaciones. Y aquí está la lección más importante del proyecto: **un test que no puede fallar no prueba nada.** Tres trampas reales:

- **"Las contraseñas se rechazan"**: si lo pruebas con `ssh -o BatchMode=yes ...`, tu **cliente** ni siquiera intenta una contraseña, así que el test "pasa" aunque el servidor las acepte. Hay que preguntar al **servidor** qué métodos ofrece. Con `-o PreferredAuthentications=none -o PubkeyAuthentication=no`, sshd responde con la lista: `Permission denied (publickey)` es lo correcto; `(publickey,password)` es un fallo.
- **"root no puede entrar"**: si intentas `ssh root@...` con tu llave, falla siempre, porque tu llave no está en la cuenta de root, haya o no `PermitRootLogin no`. Comprueba la configuración efectiva: `sudo sshd -T | grep -x 'permitrootlogin no'`.
- **"El 8080 está cerrado"**: si no hay nada escuchando en el 8080, cualquier conexión falla, **haya o no firewall**. Para probar el firewall, levanta **algo** que escuche en otro puerto (`sudo systemd-run --unit=verify-probe python3 -m http.server 8081 --bind 0.0.0.0`), comprueba que desde dentro responde, que desde fuera **no** se llega, y páralo.

Prueba tus pruebas: lanza una VM **sin** cloud-init (`multipass launch lts --name sin-config`) y pásale `verify.sh`. La mayoría de las comprobaciones deben salir ❌ y el código de salida debe ser 1. Si algo sale ✅ en esa VM, pregúntate si tu test mide lo que crees.

### 5. La prueba de fuego: reproducibilidad

```bash
time (
  multipass delete --purge web-01
  sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/lab_ed25519.pub)|" cloud-init.yaml > /tmp/p2.yaml
  multipass launch lts --name web-01 --memory 1G --disk 8G --cloud-init /tmp/p2.yaml
  IPW=$(multipass info web-01 | awk '/IPv4/ {print $2}')
  multipass exec web-01 -- cloud-init status --wait
  ssh-keygen -R "$IPW" >/dev/null 2>&1      # servidor nuevo = host key nueva (clase 15)
  ./verify.sh "$IPW"
)
```

Todo en verde y en menos de 5 minutos: **R7 cumplido**. Guarda la salida para el README.

El `ssh-keygen -R` no es un truco: un servidor recreado tiene **otra** host key. Si recibe la misma IP, SSH se negará a conectar (clase 15). Con servidores "ganado" esto es normal, y en la nube se resuelve publicando las host keys o usando certificados de SSH; aquí basta con olvidar la vieja.

Opcional: convierte ese bloque en un script `rebuild.sh`.

## Rómpelo

1. Mete un **tabulador** en la indentación del YAML y lanza. ¿Qué detecta `cloud-init schema`? ¿Y qué pasa si no lo validas?
2. Quita `- default` de `users` y lanza. Prueba `multipass shell web-01`. ¿Por qué falla? (Pista: ¿con qué usuario entra Multipass?)
3. Pon `ufw --force enable` **antes** de `ufw allow OpenSSH` en `runcmd`. ¿Te quedas fuera? Razona por qué podría no pasar aquí (piensa en el orden y en el tiempo) y por qué en otro contexto sí pasaría.
4. Desde **servidor-01** (no desde tu PC: si baneas a tu PC, también dejará de funcionar `multipass shell` durante los 10 minutos del baneo), haz 6 intentos de SSH seguidos contra `web-01` con un usuario inexistente: `for i in 1 2 3 4 5 6; do ssh -o BatchMode=yes noexiste@<IP de web-01> true; done`. Después mira `sudo fail2ban-client status sshd` en `web-01`. ¿Aparece la IP de servidor-01 en *Banned IP list*? ¿Puede servidor-01 conectar ahora a cualquier puerto de web-01? Desbanéala: `sudo fail2ban-client set sshd unbanip <IP>`.

## Entregable

`projects/p2-cloud-init-server/`:
- `cloud-init.yaml`: con el marcador `__SSH_PUBKEY__`, **nunca** con una llave real.
- `verify.sh`: ejecutable, código 0 solo si todo pasa.
- `rebuild.sh` (opcional).
- `README.md` **en inglés**, a partir de este modelo (lo escribió Claude). Copia y rellena los huecos: no hace falta escribir más.

````markdown
# P2 — Reproducible hardened server (cloud-init)

One `cloud-init.yaml` builds a hardened nginx server from scratch, and `verify.sh`
checks it from outside. Rebuild time: ____ minutes.

## What it does
- R1: user `deploy` with my SSH key, no usable password
- R2: SSH without passwords or root, `MaxAuthTries 3`
- R3: updated packages and `unattended-upgrades`
- R4: nginx serves my page and `GET /health` → `200 ok`
- R5: firewall: only 22 and 80 come in
- R6: `fail2ban` bans IPs after failed SSH logins

## How to use it
```bash
sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/lab_ed25519.pub)|" cloud-init.yaml > /tmp/p2.yaml
multipass launch lts --name web-01 --cloud-init /tmp/p2.yaml
./verify.sh <IP>
```
On AWS, the same file goes in **User data** when you launch an EC2 instance
(the firewall part would be a security group instead of ufw).

## verify.sh
```
(paste the green output of verify.sh)
```

## Decisions and limits
- `deploy` has passwordless sudo because ____. To improve: ____.
- ____
````

Súbelo con rama y PR. Actualiza `projects/README.md`: P2 → ✅.

## Cierre

En `notas/fase-3/clase-37.md`:

1. ¿Qué significa *cattle, not pets*? ¿Qué ganas al definir un servidor en un archivo? *(2–3 líneas. Empieza así: «Que los servidores se tratan como ganado y no como mascotas: si uno se rompe, no se cura a mano, se… Definirlo en un archivo me da…»)*
2. ¿Qué equivalencia hay entre este proyecto y lanzar una EC2? ¿Qué partes cambiarían en AWS (piensa en el firewall y en las llaves)? *(2–3 líneas. Empieza así: «El YAML es el user-data de la EC2… En AWS, el firewall sería… y la llave…»)*
3. ¿Por qué `verify.sh` comprueba desde **fuera** y no con comandos dentro de la VM? *(2 líneas. Empieza así: «Porque así compruebo lo que ve un cliente de verdad: algo puede funcionar dentro y fallar fuera, como…»)*
4. **Repaso (clase 36, sin mirar):** cuenta en voz alta tu incidente favorito del P1 con el formato STAR. *(Después, escribe sus 4 líneas, una por letra. Empieza así: «S: … T: … A: … R: …»)*

Después, escríbeme `examíname clase-37`.

## Autocorrección

<details>
<summary>Una solución de referencia (ábrela solo al terminar la tuya)</summary>

**cloud-init.yaml**
```yaml
#cloud-config
hostname: web-01
timezone: UTC

package_update: true
package_upgrade: true
packages:
  - nginx
  - ufw
  - fail2ban
  - unattended-upgrades

users:
  - default
  - name: deploy
    gecos: Deploy user
    shell: /bin/bash
    groups: [adm]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - __SSH_PUBKEY__

ssh_pwauth: false
disable_root: true

write_files:
  - path: /etc/ssh/sshd_config.d/00-hardening.conf
    permissions: "0644"
    content: |
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      MaxAuthTries 3
      AllowUsers deploy ubuntu
  - path: /var/www/p2/index.html
    permissions: "0644"
    content: |
      <!doctype html>
      <title>P2</title>
      <h1>Provisioned by cloud-init</h1>
  - path: /etc/nginx/sites-available/p2
    permissions: "0644"
    content: |
      server {
          listen 80 default_server;
          listen [::]:80 default_server;
          server_name _;
          root /var/www/p2;
          location = /health { return 200 "ok\n"; }
      }

runcmd:
  - rm -f /etc/nginx/sites-enabled/default
  - ln -sf /etc/nginx/sites-available/p2 /etc/nginx/sites-enabled/p2
  - nginx -t && systemctl reload nginx
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow OpenSSH
  - ufw allow 80/tcp
  - ufw --force enable
  - systemctl enable --now fail2ban
  - sshd -t && systemctl restart ssh

final_message: "P2 ready after $UPTIME seconds"
```

**verify.sh completo**
```bash
#!/bin/bash
# Uso: ./verify.sh <IP> [llave privada]
# Comprueba desde FUERA que el servidor cumple R1-R6. Sale con 0 solo si todo pasa.
set -u
IP="${1:?Uso: $0 <IP> [llave]}"
KEY="${2:-$HOME/.ssh/lab_ed25519}"
FALLOS=0

check() {   # check "descripción" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "✅ $desc"; else echo "❌ $desc"; FALLOS=$((FALLOS + 1)); fi
}

SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
SSH="ssh -i $KEY $SSH_OPTS"
remoto() { $SSH deploy@"$IP" "$@"; }

check "R1 deploy entra con llave"            remoto true
check "R2 el servidor no ofrece contraseñas" bash -c "ssh $SSH_OPTS -o PubkeyAuthentication=no -o PreferredAuthentications=none deploy@$IP true 2>&1 | grep -q 'Permission denied (publickey)\.'"
check "R2 PermitRootLogin no"                bash -c "$SSH deploy@$IP 'sudo sshd -T' | grep -qx 'permitrootlogin no'"
check "R2 MaxAuthTries 3"                    bash -c "$SSH deploy@$IP 'sudo sshd -T' | grep -qx 'maxauthtries 3'"
check "R3 unattended-upgrades habilitado"    remoto "systemctl is-enabled --quiet unattended-upgrades"
check "R4 /health responde 200"              bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://$IP/health)\" = 200 ]"
check "R4 la portada es la nuestra"          bash -c "curl -s -m 5 http://$IP/ | grep -q 'cloud-init'"

# R5: una sonda que SÍ escucha en el 8081, para que el test pueda fallar si no hay firewall
remoto "sudo systemd-run --quiet --unit=verify-probe python3 -m http.server 8081 --bind 0.0.0.0" >/dev/null 2>&1
sleep 1
check "R5 sonda escuchando en el 8081 (dentro)" remoto "curl -s -o /dev/null -m 3 http://127.0.0.1:8081/"
check "R5 el 8081 NO es accesible desde fuera"  bash -c "! nc -z -w 3 $IP 8081"
remoto "sudo systemctl stop verify-probe" >/dev/null 2>&1
check "R5 ufw activo con entrada denegada"   bash -c "$SSH deploy@$IP 'sudo ufw status verbose' | grep -q 'Default: deny (incoming)'"

check "R6 fail2ban activo"                   remoto "systemctl is-active --quiet fail2ban"

echo "Fallos: $FALLOS"
exit $(( FALLOS > 0 ))
```

Este script se probó contra un servidor endurecido (11 ✅, código 0) y contra uno sin endurecer (fallan R2, R4 y R5, código 1). `unattended-upgrades` ya viene activo en Ubuntu, así que R3 pasa casi siempre: tu cloud-init lo **garantiza** también en otras imágenes.

**Cierre:**
1. Las mascotas se cuidan a mano y son irremplazables; el ganado se define en código y se reemplaza sin drama. Ganas reproducibilidad, documentación viva (el archivo **es** la documentación), revisión en PRs, recuperación rápida y entornos idénticos.
2. El YAML va tal cual en *user-data*. En AWS: el firewall de entrada sería sobre todo el **security group** (ufw puede quedarse como segunda capa); la llave la inyecta el *key pair* o, mejor aún, no se abre el 22 y se usa **SSM Session Manager**; la imagen sería una AMI; y después todo eso se escribiría en **Terraform**.
3. Porque es lo que experimenta un usuario o un atacante: dentro de la VM, `curl localhost` funciona aunque el firewall bloquee el exterior (incidente 6 del P1). Las pruebas desde fuera validan el **resultado**, no la intención.
</details>

## Siguiente

[Clase 38 — Examen de fundamentos](clase-38-examen.md)
