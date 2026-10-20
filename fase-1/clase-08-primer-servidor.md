# Clase 08 — Tu primer servidor (Multipass)

**Dónde:** tu Ubuntu → VM `servidor-01` · **Tiempo:** 60 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** una **máquina virtual** es un ordenador completo (con su propio kernel, su disco y su IP) que vive dentro del tuyo. Puedes crearla, romperla y volver atrás con un **snapshot** en segundos. Una instancia EC2 de AWS es exactamente eso, solo que el ordenador anfitrión está en un centro de datos de Amazon.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Terminal, shell y kernel son piezas distintas (clase 01): hoy tendrás un kernel nuevo, el de la VM.
> - Mirar el prompt `usuario@máquina` antes de cada comando (clase 01): desde hoy, de verdad importa.
> - `ls`, `cat`, los pipes y las redirecciones funcionan igual dentro de la VM: es otro Ubuntu (clases 02 a 04).

> 🔤 **Palabras nuevas de hoy:**
> - **máquina virtual (VM)**: un ordenador completo que vive dentro del tuyo.
> - **hipervisor**: el programa que reparte el hardware real entre las VMs (en tu PC, KVM).
> - **host** y **guest**: tu PC (el anfitrión) y la VM (el invitado).
> - **snapshot**: un punto de guardado del disco de la VM.
> - **instancia**: el nombre que le da AWS a una VM en la nube.

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

## Cómo va esta clase

Cinco piezas. En cada una entiendes **una** idea y la haces enseguida en la terminal; no pases a la siguiente sin haber ejecutado la anterior. Mira el prompt antes de cada comando: desde hoy hay dos máquinas, tu PC y la VM.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (instalar, crear y entrar: unos 30 min, la primera descarga tarda); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

## Las piezas

### Pieza 1 — Qué es una máquina virtual, y crear la tuya

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

**Pruébalo: instala Multipass y crea tu servidor.**

```bash
sudo snap install multipass
multipass version
```

Si `multipass version` dice que no puede conectar con el demonio, espera 30 segundos y repite: el servicio está arrancando.

```bash
multipass find | head -15             # imágenes disponibles (como el catálogo de AMIs)
multipass launch lts --name servidor-01 --cpus 1 --memory 1G --disk 10G
```

La primera vez descarga la imagen (unos minutos). Después:

```bash
multipass list
multipass info servidor-01
```

👀 **Qué deberías ver:** la VM en `Running`, con una IPv4 del tipo `10.x.x.x`, su versión de Ubuntu y su disco.

Anota en tu cierre: la **IP** (IPv4), la versión de Ubuntu y el disco.

**En resumen:** una VM es un ordenador completo dentro del tuyo; una EC2 es lo mismo, en un centro de datos de Amazon.

### Pieza 2 — Entrar: ahora estás en otro ordenador

Al entrar en la VM, tu terminal habla con **otro** shell, en **otro** kernel. El prompt `usuario@máquina` es lo que te dice dónde estás.

**Pruébalo:**

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

👀 **Qué deberías ver:** `ubuntu`, `servidor-01`, un kernel distinto del de tu PC, una IP `10.x.x.x`, alrededor de 1 GB de memoria y 10 GB de disco, `status: done` y, en el último, `root`.

✋ **Sin mirar:** tu VM tiene su propio kernel. ¿Qué pieza de tu PC reparte el hardware real entre él y la VM?

<details>
<summary>Comprueba</summary>

El **hipervisor** (KVM).
</details>

**En resumen:** dentro de la VM todo es suyo: kernel, IP, memoria y disco. El prompt te dice en qué máquina estás.

### Pieza 3 — ¿Tiene internet tu servidor?

La VM sale a internet **a través de tu PC**: tu PC reenvía su tráfico. Compruébalo antes de seguir, porque las próximas clases instalan paquetes dentro de la VM. (`multipass exec` ejecuta un comando dentro de la VM sin entrar en ella; lo verás con calma en la pieza 4.)

**Pruébalo:**

```bash
multipass exec servidor-01 -- curl -sI -m 10 http://archive.ubuntu.com/ubuntu/ | head -1
```

Si ves una línea `HTTP/1.1 200 OK` (o un `30x`), todo está bien: **sáltate el resto de esta pieza**.

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

👀 **Qué deberías ver:** después del arreglo, la línea `HTTP/1.1 200 OK` (o un `30x`).

Anota en tu cierre si te hizo falta: es tu primer incidente de red resuelto.

**En resumen:** la VM sale a internet a través de tu PC; si tu firewall no reenvía su tráfico, la VM se queda sin red.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Puedes dejar la VM encendida, o apagarla con `multipass stop servidor-01` y encenderla mañana con `multipass start servidor-01`.

### Pieza 4 — Trabajar en la VM sin entrar: `exec` y `transfer`

Para un comando suelto o para copiar un archivo no hace falta entrar en la VM. En `multipass exec`, el `--` separa las opciones de multipass del comando que se ejecuta dentro. Es muy útil en scripts.

**Pruébalo:**

```bash
multipass exec servidor-01 -- uptime
multipass exec servidor-01 -- df -h /
```

👀 **Qué deberías ver:** cuánto lleva encendida la VM y su disco, sin haber entrado en ella.

Ahora, un archivo de tu PC a la VM:

```bash
echo "hola desde el host" > /tmp/saludo.txt
multipass transfer /tmp/saludo.txt servidor-01:/home/ubuntu/
multipass exec servidor-01 -- cat /home/ubuntu/saludo.txt
```

👀 **Qué deberías ver:** `hola desde el host`: el archivo viajó de tu PC a la VM.

**En resumen:** `multipass exec X -- comando` ejecuta dentro sin entrar; `multipass transfer` copia archivos.

### Pieza 5 — Apagar, borrar y el snapshot

Un **snapshot** congela el disco de la VM tal como está, como un punto de guardado: si después rompes algo, vuelves a ese momento en segundos. Durante todo el bloque B harás uno antes de cada experimento peligroso. Solo se pueden hacer con la VM **parada**. En AWS se hace lo mismo con los discos de las EC2 (*EBS snapshots*).

Tres comandos que no conviene confundir, porque en AWS uno de ellos te sigue costando dinero:

| Multipass | Qué hace | En AWS |
|-----------|----------|--------|
| `stop` | **apaga** la VM; el disco se conserva | *Stop*: no pagas CPU, **sí** el disco |
| `delete` | la marca como borrada, pero **aún se puede recuperar** | (no existe en AWS) |
| `delete --purge` | la **destruye** para siempre | *Terminate* |

**Pruébalo:**

```bash
multipass stop servidor-01
multipass list                         # Stopped: no gasta CPU ni RAM, el disco se conserva
multipass snapshot servidor-01 --name limpio --comment "recién instalado"
multipass list --snapshots
multipass start servidor-01
```

👀 **Qué deberías ver:** `servidor-01` en `Stopped`; después, el snapshot `limpio` en la lista; y al final, la VM otra vez en `Running`.

✋ **Sin mirar:**
1. Vas a probar algo que puede romper la VM. ¿Qué haces antes?
2. Apagas una EC2 con *Stop*. ¿Dejas de pagar del todo?

<details>
<summary>Comprueba</summary>

1. Un **snapshot** con la VM parada. 2. No: el disco (el volumen EBS) se sigue cobrando. Solo *Terminate* lo detiene.
</details>

**En resumen:** antes de romper algo, haz un snapshot. Y en AWS, `stop` sigue cobrando el disco.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `multipass launch lts --name X --cpus 1 --memory 1G --disk 10G` | crear una VM |
| `multipass list` · `multipass info X` | ver tus VMs · ver una (IP, disco, versión) |
| `multipass shell X` | entrar (salir: `exit`) |
| `multipass exec X -- comando` | ejecutar algo dentro sin entrar |
| `multipass transfer archivo X:/ruta/` | copiar un archivo a la VM |
| `multipass stop X` · `multipass start X` | apagar · encender |
| `multipass snapshot X --name N` · `multipass restore X.N` | crear un snapshot (con la VM parada) · volver a él |
| `multipass delete X` · `recover X` · `delete --purge X` | marcarla como borrada · recuperarla · destruirla |

## Rómpelo

**1. Destroza algo y vuelve atrás:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
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

En tu PC y en la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Cuántas IPs tiene `servidor-01`? ¿Y tu PC? ¿Ves en tu PC alguna interfaz que antes no existía?

> 🧩 **Ejemplo resuelto:** ver las interfaces de red de la VM sin entrar en ella.
> ```bash
> multipass exec servidor-01 -- ip -br addr
> ```
> `lo` es la interfaz interna de la propia máquina (`127.0.0.1`); la otra (`ens3` o parecida) es la de la red virtual, con su `10.x.x.x`.

**Ahora tú, con huecos:** `ip -br ____          # ahora en tu PC: busca una interfaz que empiece por mp`

<details>
<summary>Pista</summary>

Es el mismo comando del ejemplo, pero en tu PC, sin `multipass exec`.
</details>

**2.** Desde tu PC, haz `ping -c 3` a la IP de `servidor-01`. ¿Responde?

> 🧩 **Ejemplo resuelto:** hacerle ping a tu propio PC.
> ```bash
> ping -c 3 127.0.0.1
> ```
> `-c 3` envía tres pruebas y para. Cada línea `64 bytes from…` es una respuesta.

**Ahora tú, con huecos:** `ping -c 3 ____`

<details>
<summary>Pista</summary>

La IP de la VM te la da `multipass list`.
</details>

**3.** Sin entrar en la VM, averigua cuánto tiempo lleva encendida y qué versión de kernel tiene.

> 🧩 **Ejemplo resuelto:** ver la memoria de la VM sin entrar.
> ```bash
> multipass exec servidor-01 -- free -h
> ```
> `multipass exec servidor-01 --` ejecuta dentro de la VM lo que pongas detrás.

**Ahora tú, con huecos:**
```bash
multipass exec servidor-01 -- ____
multipass exec servidor-01 -- ____
```

<details>
<summary>Pista</summary>

Los dos comandos de la clase 01: el que dice cuánto lleva encendida la máquina y el que da la versión del kernel (`uname` con una opción).
</details>

**4.** Deja `servidor-01` **encendido** y con el snapshot `limpio` creado: lo usarás en las próximas clases. (Si ya lo creaste en la pieza 5, solo compruébalo).

> 🧩 **Ejemplo resuelto:** crear un snapshot con el nombre `prueba`.
> ```bash
> multipass stop servidor-01
> multipass snapshot servidor-01 --name prueba
> multipass start servidor-01
> ```
> La VM tiene que estar **parada** para crear el snapshot: por eso primero `stop` y al final `start`.

**Ahora tú, con huecos:** `multipass list --____`

<details>
<summary>Pista</summary>

La opción de `multipass list` que enseña los snapshots está en la chuleta.
</details>

## Cierre

En `notas/fase-1/clase-08.md`:

1. ¿Qué es una máquina virtual y qué hace el hipervisor? ¿Qué tiene que ver con EC2? *(3 líneas. Empieza así: «Una VM es… El hipervisor… Una EC2 es…»)*
2. ¿Para qué sirve un snapshot? Describe una situación en el trabajo en la que te salvaría. *(2 líneas. Empieza así: «Un snapshot guarda… Me salvaría si antes de…»)*
3. ¿Qué diferencia hay entre `stop`, `delete` y `delete --purge`? ¿Cuál de ellas sigue costando dinero en AWS (piensa en el disco)? *(3 líneas, una por comando. Empieza así: «`stop` apaga… `delete`… `delete --purge`… En AWS sigue costando…»)*
4. **Repaso (clase 07, sin mirar):** ¿por qué un comando que funciona en tu terminal puede fallar dentro de un servicio o un cron? *(2 líneas. Empieza así: «Porque un servicio o cron arranca con otro entorno, sin mi… Se arregla con…»)*

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
