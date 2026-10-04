# Clase 29 — P2: Servidor reproducible con cloud-init

**Dónde:** tu PC + VMs que crearás y destruirás · **Tiempo:** 3–4 sesiones · **Bloque:** E. Proyectos · **Proyecto de portfolio**

## Objetivo

Escribir **un único archivo** que convierta un Ubuntu recién creado en un servidor web **endurecido y verificado**, sin tocarlo a mano: usuario con llave, SSH sin contraseñas ni root, firewall, nginx con health check y actualizaciones automáticas. Después, demostrar que es **reproducible**: destruir el servidor y recrearlo idéntico en minutos.

Este proyecto junta toda la fase 1 y es el puente directo a AWS: el mismo archivo funciona como **user-data** de una EC2.

## Por qué importa

> *"Treat servers like cattle, not pets."*

Un servidor configurado a mano (una **mascota**) es irrepetible: nadie recuerda los 40 comandos que se le aplicaron, y si muere, se pierde. Un servidor definido en código (**ganado**) se recrea igual cuantas veces haga falta: para escalar, para recuperarse de un desastre o para tener staging igual a producción. Esa es la idea central de DevOps, y la que llevarás a Terraform (fase 6), Docker (fase 3) y Kubernetes (fase 7).

## Teoría: cloud-init

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

## Requisitos del proyecto

El servidor `web-01` debe cumplir **todo** esto nada más arrancar, sin intervención:

| # | Requisito | Clase |
|---|-----------|-------|
| R1 | Usuario `deploy` con tu llave pública, sin contraseña utilizable | 09, 15 |
| R2 | SSH: sin contraseñas, sin root y con `MaxAuthTries 3` | 15 |
| R3 | Paquetes actualizados y `unattended-upgrades` activo | 10 |
| R4 | nginx sirve una página propia y `GET /health` → `200 ok` | 12, 22 |
| R5 | Firewall: solo entran 22 y 80. Todo lo demás, descartado | 23 |
| R6 | `fail2ban` activo (banea IPs tras intentos de SSH fallidos) | 13, 15 |
| R7 | La configuración se puede recrear **idéntica** en < 5 minutos | 08 |
| R8 | Un script `verify.sh` comprueba R1–R6 **desde fuera** y sale con código 0 solo si todo está bien | 04, 16, 19 |

## Práctica guiada

### 1. Estructura

```bash
mkdir -p ~/my-devops-journey/projects/p2-cloud-init-server
cd ~/my-devops-journey/projects/p2-cloud-init-server
```

Tu llave pública **no** irá escrita en el repo: el YAML tendrá un marcador que sustituirás al lanzar. Así el archivo sirve a cualquier persona y no publicas ni siquiera tu pública por costumbre.

### 2. Empieza pequeño

Primero, solo el usuario. Crea `cloud-init.yaml`:
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

SSH="ssh -i $KEY -o IdentitiesOnly=yes -o ConnectTimeout=5 -o BatchMode=yes"

check "R1 deploy entra con llave"            $SSH deploy@"$IP" true
# check "R2 contraseñas rechazadas"          ... (pista: la prueba "pasa" si ssh FALLA → usa '!' con bash -c)
# check "R2 root rechazado"                  ...
# check "R4 /health responde 200"            ...
# check "R5 puerto 8080 cerrado (timeout)"   ...
# check "R6 fail2ban activo"                 ...

echo "Fallos: $FALLOS"
exit $(( FALLOS > 0 ))
```

Completa las comprobaciones. Deben **fallar** si el servidor no cumple. Pruébalo: lanza una VM **sin** cloud-init (`multipass launch lts --name sin-config`) y pásale `verify.sh`. Deben salir ❌, y el código de salida debe ser 1.

### 5. La prueba de fuego: reproducibilidad

```bash
time (
  multipass delete --purge web-01
  sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/lab_ed25519.pub)|" cloud-init.yaml > /tmp/p2.yaml
  multipass launch lts --name web-01 --memory 1G --disk 8G --cloud-init /tmp/p2.yaml
  IPW=$(multipass info web-01 | awk '/IPv4/ {print $2}')
  multipass exec web-01 -- cloud-init status --wait
  ./verify.sh "$IPW"
)
```

Todo en verde y en menos de 5 minutos: **R7 cumplido**. Guarda la salida para el README.

Opcional: convierte ese bloque en un script `rebuild.sh`.

## Rómpelo

1. Mete un **tabulador** en la indentación del YAML y lanza. ¿Qué detecta `cloud-init schema`? ¿Y qué pasa si no lo validas?
2. Quita `- default` de `users` y lanza. Prueba `multipass shell web-01`. ¿Por qué falla? (Pista: ¿con qué usuario entra Multipass?)
3. Pon `ufw --force enable` **antes** de `ufw allow OpenSSH` en `runcmd`. ¿Te quedas fuera? Razona por qué podría no pasar aquí (piensa en el orden y en el tiempo) y por qué en otro contexto sí pasaría.
4. Desde otra VM o desde tu PC, haz 5 intentos de SSH fallidos seguidos contra `web-01` con un usuario inexistente. Después mira `sudo fail2ban-client status sshd` en `web-01`. ¿Te baneó? ¿Cómo te desbaneas? (`sudo fail2ban-client set sshd unbanip <IP>`)

## Entregable

`projects/p2-cloud-init-server/`:
- `cloud-init.yaml`: con el marcador `__SSH_PUBKEY__`, **nunca** con una llave real.
- `verify.sh`: ejecutable, código 0 solo si todo pasa.
- `rebuild.sh` (opcional).
- `README.md` **en inglés**:
  - qué hace (requisitos R1–R8 como lista),
  - cómo usarlo (Multipass y, como referencia, cómo se pondría como *user-data* en EC2),
  - la salida de `verify.sh` en verde y el tiempo de reconstrucción,
  - decisiones y límites (por ejemplo: `deploy` tiene sudo sin contraseña. ¿Por qué? ¿Qué mejorarías?),
  - qué aprendiste.

Súbelo con rama y PR. Actualiza `projects/README.md`: P2 → ✅.

## Cierre

En `notas/fase-1/clase-29.md`:

1. ¿Qué significa *cattle, not pets*? ¿Qué ganas al definir un servidor en un archivo?
2. ¿Qué equivalencia hay entre este proyecto y lanzar una EC2? ¿Qué partes cambiarían en AWS (piensa en el firewall y en las llaves)?
3. ¿Por qué `verify.sh` comprueba desde **fuera** y no con comandos dentro de la VM?
4. **Repaso (clase 28, sin mirar):** cuenta en 4 líneas tu incidente favorito del P1 con el formato STAR.

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

**Comprobaciones de verify.sh**
```bash
check "R1 deploy entra con llave"          $SSH deploy@"$IP" true
check "R2 contraseñas rechazadas"          bash -c "! ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o BatchMode=yes -o ConnectTimeout=5 deploy@$IP true"
check "R2 root rechazado"                  bash -c "! $SSH root@$IP true"
check "R4 /health responde 200"            bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://$IP/health)\" = 200 ]"
check "R4 página propia"                   bash -c "curl -s -m 5 http://$IP/ | grep -q 'cloud-init'"
check "R5 puerto 8080 no accesible"        bash -c "! nc -z -w 3 $IP 8080"
check "R5 ufw activo"                      $SSH deploy@"$IP" "sudo ufw status | grep -q 'Status: active'"
check "R6 fail2ban activo"                 $SSH deploy@"$IP" "systemctl is-active --quiet fail2ban"
check "R3 unattended-upgrades activo"      $SSH deploy@"$IP" "systemctl is-enabled --quiet unattended-upgrades"
```

**Cierre:**
1. Las mascotas se cuidan a mano y son irremplazables; el ganado se define en código y se reemplaza sin drama. Ganas reproducibilidad, documentación viva (el archivo **es** la documentación), revisión en PRs, recuperación rápida y entornos idénticos.
2. El YAML va tal cual en *user-data*. En AWS: el firewall de entrada sería sobre todo el **security group** (ufw puede quedarse como segunda capa); la llave la inyecta el *key pair* o, mejor aún, no se abre el 22 y se usa **SSM Session Manager**; la imagen sería una AMI; y después todo eso se escribiría en **Terraform**.
3. Porque es lo que experimenta un usuario o un atacante: dentro de la VM, `curl localhost` funciona aunque el firewall bloquee el exterior (incidente 6 del P1). Las pruebas desde fuera validan el **resultado**, no la intención.
</details>

## Siguiente

[Clase 30 — Examen de la fase 1](clase-30-examen.md)
