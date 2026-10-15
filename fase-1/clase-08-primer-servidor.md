# Clase 08 — Tu primer servidor (Multipass)

**Dónde:** tu Ubuntu → VM `servidor-01` · **Tiempo:** 60 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** una **máquina virtual** es un ordenador completo (con su propio kernel, su disco y su IP) que vive dentro del tuyo. Puedes crearla, romperla y volver atrás con un **snapshot** en segundos. Una instancia EC2 de AWS es exactamente eso, solo que el ordenador anfitrión está en un centro de datos de Amazon.

## Objetivo

- Crear, usar, parar y destruir un servidor Ubuntu virtual con **Multipass**.
- Hacer **snapshots** para volver atrás después de romper algo.
- Reconocer en cada paso su equivalente en AWS EC2.

## Por qué importa

En AWS lanzarás instancias EC2: servidores Linux que no ves, que administras por SSH y que destruyes cuando ya no los necesitas. Multipass te da **lo mismo en tu PC, gratis**: un Ubuntu real con su kernel, su red y su IP, que puedes romper sin miedo. Todo el bloque B y el de redes ocurren aquí.

| Multipass | AWS EC2 |
|-----------|---------|
| `multipass launch` | Launch instance |
| imagen `lts` | AMI (Amazon Machine Image) |
| `--cpus`, `--memory` | tipo de instancia (`t3.micro`…) |
| `--disk` | volumen EBS |
| `multipass stop` / `start` | Stop / Start instance |
| `multipass delete --purge` | Terminate instance |
| `multipass snapshot` | EBS snapshot |
| `--cloud-init archivo.yaml` | *User data* (clase 37) |
| `multipass shell` | SSH / Session Manager |

## Teoría

### ¿Qué es una máquina virtual?

```
┌───────────────────── Tu PC (host) ──────────────────────┐
│  Ubuntu 26.04 (kernel del host)                         │
│  ┌─────────────── hipervisor (KVM/QEMU) ─────────────┐  │
│  │  ┌──────────── servidor-01 (VM/guest) ─────────┐  │  │
│  │  │  SU PROPIO kernel Linux                     │  │  │
│  │  │  1 CPU virtual · 1 GB RAM · disco de 10 GB  │  │  │
│  │  │  IP propia en una red virtual (10.x.x.x)    │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

El **hipervisor** (en tu caso, KVM, que viene en el propio kernel Linux) reparte el hardware real entre máquinas virtuales. Cada VM cree que es un ordenador completo. **AWS EC2 funciona igual**: tu instancia es una VM sobre un hipervisor (*Nitro*) en un servidor físico de Amazon.

Un **contenedor** (Docker, fase 5) es otra cosa: comparte el kernel del host. Por eso una VM aísla más y pesa más. Lo compararás bien en la fase 5.

Ya comprobé que tu equipo soporta virtualización por hardware (`/dev/kvm` existe y la CPU tiene las extensiones). Con 7 GB de RAM puedes mantener **dos VMs de 1 GB** encendidas a la vez sin problema.

### El snapshot: tu punto de guardado

Un **snapshot** es como el **punto de guardado de un videojuego**: congela el disco de la VM tal como está. Si después rompes algo, cargas la partida guardada y vuelves a ese momento en segundos. Durante todo el bloque B harás uno antes de cada experimento peligroso. En AWS se hace lo mismo con los discos de las EC2 (*EBS snapshots*).

Tres palabras que no conviene confundir, porque en AWS una de ellas te sigue costando dinero:

| Multipass | Qué hace | En AWS |
|-----------|----------|--------|
| `stop` | **apaga** la VM; el disco se conserva | *Stop*: no pagas CPU, **sí** el disco |
| `delete` | la manda a la **papelera**: aún se puede recuperar | (no existe en AWS) |
| `delete --purge` | la **destruye** para siempre | *Terminate* |

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Tu VM tiene su propio kernel. ¿Qué pieza de tu PC reparte el hardware real entre él y la VM?
2. Vas a probar algo que puede romper la VM. ¿Qué haces antes?
3. Apagas una EC2 con *Stop*. ¿Dejas de pagar del todo?

<details>
<summary>Comprueba</summary>

1. El **hipervisor** (KVM). 2. Un **snapshot**, el punto de guardado. 3. No: el disco (el volumen EBS) se sigue cobrando. Solo *Terminate* lo detiene.
</details>

### Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `multipass launch lts --name X --cpus 1 --memory 1G --disk 10G` | crear una VM |
| `multipass list` · `multipass info X` | ver tus VMs · ver una (IP, disco, versión) |
| `multipass shell X` | entrar (salir: `exit`) |
| `multipass exec X -- comando` | ejecutar algo dentro sin entrar |
| `multipass transfer archivo X:/ruta/` | copiar un archivo a la VM |
| `multipass stop X` · `multipass start X` | apagar · encender |
| `multipass snapshot X --name N` · `multipass restore X.N` | guardar partida (con la VM parada) · cargarla |
| `multipass delete X` · `recover X` · `delete --purge X` | a la papelera · sacarla · destruirla |

## Práctica guiada

### 1. Instalar Multipass

```bash
sudo snap install multipass
multipass version
```

Si `multipass version` dice que no puede conectar con el demonio, espera 30 segundos y repite: el servicio está arrancando.

### 2. Lanzar tu primer servidor

```bash
multipass find | head -15             # imágenes disponibles (como el catálogo de AMIs)
multipass launch lts --name servidor-01 --cpus 1 --memory 1G --disk 10G
```

La primera vez descarga la imagen (unos minutos). Después:

```bash
multipass list
multipass info servidor-01
```

Anota en tu cierre: la **IP** (IPv4), la versión de Ubuntu y el disco.

### 3. Entrar

```bash
multipass shell servidor-01
```

🔮 **Predice:** ¿qué usuario y qué nombre de máquina verás en el prompt?

El prompt cambió: `ubuntu@servidor-01:~$`. **Ahora estás en otro ordenador.** Acostúmbrate a mirar el prompt antes de cada comando: es tu protección contra ejecutar algo en la máquina equivocada.

Dentro de la VM:
```bash
whoami
hostnamectl
uname -r                 # su propio kernel, distinto del de tu PC
ip -br addr              # su IP
free -h                  # su memoria (≈1 GB)
df -h /                  # su disco (≈10 GB)
nproc
cloud-init status        # el sistema de primer arranque (como en EC2)
sudo whoami              # el usuario ubuntu tiene sudo sin contraseña (como en EC2)
exit
```

### 3b. ¿Tiene internet tu servidor?

Compruébalo antes de seguir: las próximas clases instalan paquetes dentro de la VM. (`multipass exec` ejecuta un comando dentro de la VM sin entrar en ella; lo verás con calma en el paso 4.)

```bash
multipass exec servidor-01 -- curl -sI -m 10 http://archive.ubuntu.com/ubuntu/ | head -1
```

Si ves una línea `HTTP/1.1 200 OK` (o un `30x`), todo está bien: **sáltate el resto de este apartado**.

Si no sale nada o da error, es casi seguro un choque conocido entre **Docker y Multipass**. En tu PC está instalado Docker, que pone la regla de "reenvío" del firewall en `DROP` (lo comprobé: `FORWARD DROP`). Esa regla puede bloquear el tráfico que tu PC reenvía desde las VMs hacia internet. Lo entenderás del todo en las clases 30 (NAT) y 33 (firewall). Por ahora, el arreglo:

```bash
sudo iptables -I DOCKER-USER -i mpqemubr0 -j ACCEPT
sudo iptables -I DOCKER-USER -o mpqemubr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
multipass exec servidor-01 -- curl -sI -m 10 http://archive.ubuntu.com/ubuntu/ | head -1
```

`DOCKER-USER` es la cadena que Docker reserva para reglas tuyas y que nunca toca. Estas dos líneas permiten el tráfico que sale de las VMs y sus respuestas. Se pierden al reiniciar el PC. Para que sean permanentes, instala el servicio que está preparado en el repo (es un servicio de systemd: los verás en la clase 12):

```bash
sudo cp ~/my-devops-journey/recursos/clase-08/multipass-docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now multipass-docker
```

Anota en tu cierre si te hizo falta: es tu primer incidente de red resuelto.

### 4. Ejecutar sin entrar

```bash
multipass exec servidor-01 -- uptime
multipass exec servidor-01 -- df -h /
```

Muy útil para scripts: el `--` separa las opciones de multipass del comando que se ejecuta dentro.

### 5. Pasar archivos

```bash
echo "hola desde el host" > /tmp/saludo.txt
multipass transfer /tmp/saludo.txt servidor-01:/home/ubuntu/
multipass exec servidor-01 -- cat /home/ubuntu/saludo.txt
```

### 6. Parar, arrancar y snapshots

```bash
multipass stop servidor-01
multipass list                         # Stopped: no gasta CPU ni RAM, el disco se conserva
multipass snapshot servidor-01 --name limpio --comment "recién instalado"
multipass list --snapshots
multipass start servidor-01
```

Un **snapshot** congela el estado del disco. Antes de cada laboratorio peligroso harás uno, y si destrozas el servidor, vuelves atrás en segundos. Los snapshots solo se pueden hacer con la VM **parada**.

## Rómpelo

**1. Destroza algo y vuelve atrás:**
```bash
multipass shell servidor-01
sudo mv /usr/bin/ls /usr/bin/ls.roto
ls                         # command not found
exit
```
Restaura el snapshot:
```bash
multipass stop servidor-01
multipass restore servidor-01.limpio
```
Te preguntará si quieres guardar antes el estado actual: responde `no`.
```bash
multipass start servidor-01
multipass exec servidor-01 -- ls /
```
`ls` vuelve a funcionar. Es la misma idea que restaurar un volumen EBS desde un snapshot cuando un despliegue rompe un servidor.

**2. Apagar desde dentro:**
```bash
multipass exec servidor-01 -- sudo poweroff
multipass list
multipass start servidor-01
```

**3. Borrar sin miedo (y sin prisa):**
```bash
multipass launch lts --name desechable --memory 512M --disk 5G
multipass delete desechable
multipass list                  # sigue apareciendo como Deleted: aún se puede recuperar
multipass recover desechable
multipass delete --purge desechable
multipass list                  # ahora sí desapareció para siempre
```
En AWS, *Terminate* equivale a `delete --purge`: no hay vuelta atrás.

## Reto

En tu PC y en la VM. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** ¿Cuántas IPs tiene `servidor-01`? ¿Y tu PC? ¿Ves en tu PC alguna interfaz que antes no existía?

<details>
<summary>Pista</summary>

`ip -br addr` en tu PC, y en la VM sin entrar: `multipass exec servidor-01 -- ip -br addr`. En tu PC, busca una interfaz cuyo nombre empiece por `mp`.
</details>

**2.** Desde tu PC, haz `ping -c 3` a la IP de `servidor-01`. ¿Responde?

<details>
<summary>Pista</summary>

La IP te la da `multipass list`.
</details>

**3.** Sin entrar en la VM, averigua cuánto tiempo lleva encendida y qué versión de kernel tiene.

<details>
<summary>Pista</summary>

`multipass exec servidor-01 --` seguido de `uptime`, y después de `uname -r`.
</details>

**4.** Deja `servidor-01` **encendido** y con el snapshot `limpio` creado: lo usarás en las próximas clases.

<details>
<summary>Pista</summary>

Los snapshots se hacen con la VM parada: `stop`, `snapshot` y `start`, como en la práctica 6. Comprueba con `multipass list --snapshots`.
</details>

## Cierre

En `notas/fase-1/clase-08.md`:

1. ¿Qué es una máquina virtual y qué hace el hipervisor? ¿Qué tiene que ver con EC2?
2. ¿Para qué sirve un snapshot? Describe una situación en el trabajo en la que te salvaría.
3. ¿Qué diferencia hay entre `stop`, `delete` y `delete --purge`? ¿Cuál de ellas sigue costando dinero en AWS (piensa en el disco)?
4. **Repaso (clase 07, sin mirar):** ¿por qué un comando que funciona en tu terminal puede fallar dentro de un servicio o un cron?

Después, escríbeme `examíname clase-08`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Una VM es un ordenador simulado por software, con su propio kernel, CPU virtual, memoria, disco y red. El **hipervisor** reparte el hardware real entre varias VMs y las aísla. Una EC2 es exactamente eso: una VM sobre el hipervisor Nitro en un servidor de AWS. Tú alquilas la VM, no la máquina física.

**2.** Guarda el estado del disco en un momento concreto para volver a él. Ejemplo: antes de actualizar paquetes o cambiar la configuración de una base de datos en producción se hace un snapshot del volumen. Si la actualización rompe el servidor, se restaura en minutos en lugar de reconstruirlo a mano.

**3.** `stop` apaga la VM, pero conserva el disco: se puede arrancar otra vez. `delete` la marca como borrada, pero aún se puede recuperar con `recover`. `delete --purge` la elimina para siempre. En AWS, una instancia **parada** no cobra CPU, pero **sí sigue cobrando el volumen EBS** (y una IP elástica sin usar). Solo *Terminate* (y borrar sus volúmenes y snapshots) detiene el gasto. Error típico de principiante: "la paré, pero la factura sigue subiendo".

**4.** Los servicios y el cron arrancan con un entorno mínimo: un PATH reducido, sin `~/.bashrc` ni alias ni tus variables exportadas. Se arregla con rutas completas o definiendo el PATH y las variables dentro del script o del servicio.

**Reto:** 1) La VM tiene `lo` (127.0.0.1) y una interfaz con una IP 10.x.x.x. En tu PC aparece una interfaz nueva tipo `mpqemubr0`: el **puente** (bridge) virtual que conecta tu PC con las VMs, como un switch dentro de tu ordenador. 2) Sí, responde: tu PC y la VM están en la misma red virtual. 3) `multipass exec servidor-01 -- uptime` y `multipass exec servidor-01 -- uname -r`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| virtual machine (VM) | máquina virtual |
| hypervisor | hipervisor |
| host / guest | anfitrión / invitado |
| instance | instancia (una VM en la nube) |
| snapshot | instantánea del disco |
| to terminate | eliminar una instancia (AWS) |

🎙️ *"A stopped EC2 instance doesn't charge for compute, but you still pay for its EBS volumes. To stop paying you have to terminate it and clean up volumes and snapshots."*

## Siguiente

[Clase 09 — Usuarios, grupos y sudo](clase-09-usuarios-y-sudo.md)
