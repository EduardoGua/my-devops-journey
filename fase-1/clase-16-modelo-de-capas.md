# Clase 16 — Cómo viaja una petición: el modelo de capas

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** C. Redes

## Objetivo

- Entender las **capas** de red (TCP/IP y su relación con OSI) y qué resuelve cada una.
- Ver con tus propios ojos, con `tcpdump`, una petición HTTP: ARP, el *handshake* TCP, la petición, la respuesta y el cierre.
- Usar las capas como **método de diagnóstico**: de abajo arriba.

## Por qué importa

"No conecta" es el problema más frecuente de la nube, y tiene muchas causas: ruta, firewall, security group, proceso caído, DNS, certificado. Quien piensa en capas lo resuelve en minutos: *"¿llega el paquete? ¿responde el puerto? ¿responde la app?"*. Además, AWS habla en capas: un **NLB** es de capa 4, un **ALB** es de capa 7, y un **security group** filtra en las capas 3 y 4.

## Teoría

### La idea: cada capa resuelve un problema

```
 Capa (TCP/IP)        ¿Qué problema resuelve?                Dirección        Ejemplos
 ─────────────────────────────────────────────────────────────────────────────────────────────
 4 Aplicación         ¿Qué quiere decir el programa?          URL, nombres     HTTP, DNS, SSH, TLS
 3 Transporte         ¿A qué PROGRAMA va, y llega entero?     PUERTO           TCP, UDP
 2 Red (Internet)     ¿A qué MÁQUINA va, cruzando redes?      IP               IP, ICMP (ping)
 1 Enlace             ¿Cómo llega al vecino del mismo cable?  MAC              Ethernet, Wi-Fi, ARP
```

**Analogía postal:** la carta (HTTP) va en un sobre con el nombre del departamento (puerto), dentro de un paquete con la dirección del edificio (IP). El cartero del barrio lo lleva de casa en casa usando la dirección del portal (MAC). En cada oficina de correos (router) se cambia de cartero (de MAC), pero la dirección del edificio (IP) no cambia en todo el viaje.

### Encapsulación

Al enviar, cada capa **envuelve** lo de la de arriba con su cabecera. Al recibir, cada capa quita la suya:

```
[ Ethernet: MAC origen→destino [ IP: 10.0.0.1→10.0.0.5 [ TCP: puerto 51234→80 [ HTTP: GET / ] ] ] ]
```

### OSI: el modelo de 7 capas

En entrevistas te hablarán de "capa 7" o "capa 4". Eso viene del modelo **OSI**, más teórico:

| OSI | Nombre | Equivale en TCP/IP |
|-----|--------|--------------------|
| 7 | Aplicación | Aplicación |
| 6 | Presentación | Aplicación |
| 5 | Sesión | Aplicación |
| 4 | **Transporte** | Transporte |
| 3 | **Red** | Red |
| 2 | Enlace de datos | Enlace |
| 1 | Física | Enlace |

"**Capa 7**" = entiende HTTP (rutas, cabeceras) → **ALB**, WAF. "**Capa 4**" = solo ve IPs y puertos → **NLB**, **security groups**. "**Capa 3**" = IPs y rutas → **tablas de rutas**, NACLs.

### El viaje de `curl http://10.x.x.x/`

```
 1. ¿Está en mi red? Sí → necesito su MAC → ARP: "¿Quién tiene 10.x.x.x?" → "Yo, mi MAC es 52:54:..."
 2. TCP handshake (tres pasos):
      PC ──SYN──────────────► VM:80      "¿hablamos?"
      PC ◄────────SYN-ACK──── VM:80      "sí, hablamos"
      PC ──ACK──────────────► VM:80      "de acuerdo"
 3. PC ──"GET / HTTP/1.1"─────► VM       (la petición)
 4. PC ◄──"HTTP/1.1 200 OK…"─── VM       (la respuesta)
 5. Cierre: FIN / ACK en ambos sentidos
```

(Si fuese un nombre como `ejemplo.com`, antes de todo habría una consulta **DNS**: clase 21. Si fuese a otra red, el paso 1 buscaría la MAC del **router**: clase 20.)

### Diagnóstico de abajo arriba

| Pregunta | Herramienta | Si falla… |
|----------|-------------|-----------|
| ¿Tengo red e IP? | `ip -br addr`, `ip route` | interfaz caída o sin IP |
| ¿Llego a la máquina? (capa 3) | `ping IP` | ruta, o ICMP bloqueado (¡ojo!) |
| ¿Responde el puerto? (capa 4) | `nc -zv IP 80` | servicio caído, firewall o SG |
| ¿Responde la aplicación? (capa 7) | `curl -v http://IP/` | error de la app o de su configuración |

⚠️ Que `ping` falle **no** demuestra que la máquina esté caída: muchos firewalls (y los security groups de AWS por defecto) bloquean ICMP. Y que `ping` funcione no demuestra que la web vaya.

## Práctica guiada

### 1. Tus capas, de abajo arriba

En tu PC:
```bash
ip -br link          # capa 1-2: interfaces y su MAC
ip -br addr          # capa 3: IPs
ip route             # capa 3: rutas
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
```

### 2. ARP en directo

En la VM (`ssh servidor-01`):
```bash
ip neigh             # tabla ARP: IP → MAC de los vecinos
```

En tu PC:
```bash
ip neigh | grep $IP
ping -c 2 $IP
ip neigh | grep $IP
```

Comprueba que la MAC que tu PC asocia a la VM es la de la interfaz de la VM (`ip -br link` dentro de la VM).

### 3. Ver una petición HTTP completa

En la VM, captura todo lo que pase por el puerto 80:
```bash
sudo tcpdump -i any -nn port 80
```

🔮 **Predice:** ¿cuántos paquetes verás para un solo `curl`? ¿Qué flags crees que tendrán los tres primeros?

En tu PC:
```bash
curl -s http://$IP/ > /dev/null
```

En la salida de `tcpdump` busca los *flags* entre corchetes:
| Flag | Significa |
|------|-----------|
| `[S]` | SYN |
| `[S.]` | SYN-ACK (el `.` es ACK) |
| `[.]` | ACK |
| `[P.]` | PUSH: lleva datos (la petición o la respuesta) |
| `[F.]` | FIN: cierre |
| `[R]` o `[R.]` | RST: rechazo o corte brusco |

Para con `Ctrl+C`. Ahora mira el **contenido** (HTTP va en texto claro):
```bash
sudo tcpdump -i any -nn -A port 80
```
Repite el `curl` desde tu PC. Verás `GET / HTTP/1.1`, las cabeceras y el HTML. **Cualquiera en el camino puede leer HTTP**: por eso existe HTTPS (clase 22).

### 4. Cada capa con su herramienta

Desde tu PC:
```bash
ping -c 3 $IP                        # capa 3
nc -zv $IP 80                        # capa 4: ¿el puerto acepta conexiones?
nc -zv $IP 8080                      # tu miapp
curl -v http://$IP/ 2>&1 | head -20  # capa 7
```

En `curl -v`, las líneas con `*` son la conexión (capas 3-4), las de `>` la petición y las de `<` la respuesta.

## Rómpelo

Mantén `sudo tcpdump -i any -nn port 80` corriendo en la VM.

**1. El servicio está caído:**
```bash
ssh servidor-01 sudo systemctl stop nginx
ping -c 2 $IP
nc -zv $IP 80
curl -v http://$IP/
```
`ping` ✅, pero el puerto ❌ con `Connection refused`. En `tcpdump`: tu `[S]` recibe un **`[R.]`**. El kernel de la VM contesta "aquí no escucha nadie en el 80". **Refused = llegaste a la máquina y no hay proceso en ese puerto.**

```bash
ssh servidor-01 sudo systemctl start nginx
```

**2. Un puerto donde nadie escucha y un destino que no existe:**
```bash
nc -zv -w 3 $IP 81                 # refused: la máquina existe, el puerto no
nc -zv -w 3 192.0.2.1 80           # timeout: nadie contesta (192.0.2.0/24 es un rango de documentación: nunca existe)
```

Dos fallos **distintos** que tienen que sonarte para siempre:

| Síntoma | Qué significa | Causas típicas |
|---------|---------------|----------------|
| **Connection refused** (inmediato) | Llegaste, pero nadie escucha en ese puerto | servicio caído, puerto equivocado, escucha solo en 127.0.0.1 |
| **Timeout** (espera y se rinde) | Nadie contestó | firewall o **security group** que descarta, ruta inexistente, máquina apagada |
| **No route to host** | Un router (o tu propia máquina) dice que no hay camino | IP de tu misma red que no existe (nadie responde al ARP), un firewall que rechaza con ICMP, rutas rotas |

En AWS, un **timeout** al conectar a una EC2 es casi siempre un **security group** o una tabla de rutas. Un **refused** es tu aplicación.

## Reto

1. Captura con `tcpdump` una conexión SSH tuya a la VM (`port 22`). ¿Puedes leer los comandos que escribes, como con HTTP? ¿Por qué?
2. Con `tcpdump -i any -nn icmp` en la VM, haz `ping -c 3` desde tu PC. ¿Qué tipos de mensaje ICMP ves?
3. Explica qué capas usa cada uno: `ping`, `nc -zv`, `curl`.
4. Dibuja (en papel o en ASCII en tus notas) la encapsulación de tu `curl`, con las IPs, puertos y MACs **reales** que viste hoy.

## Cierre

En `notas/fase-1/clase-16.md`:

1. Explica las 4 capas de TCP/IP con la analogía que prefieras. ¿Qué dirección usa cada una?
2. Cuenta el *handshake* TCP y qué viste en `tcpdump`.
3. "Connection refused" frente a "timeout": qué significa cada uno y qué revisarías en AWS en cada caso.
4. **Repaso (clase 15, sin mirar):** ¿por qué al cambiar la configuración de SSH se deja una sesión abierta?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Enlace**: entrega entre vecinos de la misma red física, usando direcciones **MAC** (ARP traduce IP → MAC). **Red**: lleva el paquete de máquina a máquina a través de redes, con direcciones **IP** y routers. **Transporte**: entrega al **programa** correcto mediante el **puerto**; TCP además garantiza el orden y la entrega. **Aplicación**: el significado del mensaje (HTTP, DNS, SSH).

**2.** El cliente envía **SYN** (quiere conectar), el servidor responde **SYN-ACK** (acepta) y el cliente confirma con **ACK**. En `tcpdump`: `[S]`, `[S.]`, `[.]`. Después, paquetes `[P.]` con la petición y la respuesta, y el cierre con `[F.]`.

**3.** **Refused**: el paquete llegó y el kernel respondió con RST porque nadie escucha en ese puerto. Hay que mirar el **servicio**: ¿está activo? ¿en qué puerto y en qué IP escucha? (`ss -tlnp`, clase 19). **Timeout**: no llegó respuesta. Algo **descarta** el paquete o no hay camino: en AWS se revisa el **security group** (regla de entrada para ese puerto y origen), la **NACL**, la **tabla de rutas** (¿hay Internet Gateway?), si la instancia tiene IP pública y si está encendida.

**4.** Porque si la configuración nueva tiene un error, se cierra la puerta para las conexiones **nuevas**, pero la sesión que ya está abierta sigue funcionando y permite deshacer el cambio. Sin ella, puedes perder el acceso al servidor.

**Reto:** 1) No: SSH **cifra** todo después del intercambio inicial. Solo verás bytes ilegibles. 2) `ICMP echo request` (de tu PC) y `ICMP echo reply` (de la VM). 3) `ping`: capa 3 (ICMP sobre IP). `nc -zv`: capa 4 (abre una conexión TCP y la cierra). `curl`: capa 7 (HTTP sobre TCP sobre IP).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| layer | capa |
| encapsulation | encapsulación |
| three-way handshake | saludo de tres pasos |
| packet capture | captura de paquetes |
| connection refused / timed out | conexión rechazada / tiempo agotado |

🎙️ *"I troubleshoot bottom-up: can I reach the host, is the port open, does the application answer? A timeout usually points to a security group or routing; 'connection refused' means nothing is listening."*

## Siguiente

[Clase 17 — Direcciones IP y CIDR](clase-17-ip-y-cidr.md)
