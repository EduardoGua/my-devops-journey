# Clase 08 — Tu primer servidor (Multipass)

**Dónde:** tu Ubuntu → VM `servidor-01` · **Tiempo:** 60 min · **Bloque:** B. Administrar un servidor

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
| `--cloud-init archivo.yaml` | *User data* (clase 29) |
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

Un **contenedor** (Docker, fase 3) es otra cosa: comparte el kernel del host. Por eso una VM aísla más y pesa más. Lo compararás bien en la fase 3.

Ya comprobé que tu equipo soporta virtualización por hardware (`/dev/kvm` existe y la CPU tiene las extensiones). Con 7 GB de RAM puedes mantener **dos VMs de 1 GB** encendidas a la vez sin problema.

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

1. ¿Cuántas IPs tiene `servidor-01`? ¿Y tu PC? Compara la salida de `ip -br addr` en ambos. ¿Ves alguna interfaz en tu PC que antes no existía? Relaciónala con Multipass.
2. Desde tu PC, haz `ping -c 3 <IP de servidor-01>`. ¿Responde?
3. Sin entrar en la VM, averigua cuánto tiempo lleva encendida y qué versión de kernel tiene.
4. Deja `servidor-01` **encendido** y con el snapshot `limpio` creado: lo usarás en las próximas clases.

## Cierre

En `notas/fase-1/clase-08.md`:

1. ¿Qué es una máquina virtual y qué hace el hipervisor? ¿Qué tiene que ver con EC2?
2. ¿Para qué sirve un snapshot? Describe una situación en el trabajo en la que te salvaría.
3. ¿Qué diferencia hay entre `stop`, `delete` y `delete --purge`? ¿Cuál de ellas sigue costando dinero en AWS (piensa en el disco)?
4. **Repaso (clase 07, sin mirar):** ¿por qué un comando que funciona en tu terminal puede fallar dentro de un servicio o un cron?

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
