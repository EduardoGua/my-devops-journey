# Clase 26 — Cómo viaja una petición: el modelo de capas

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** A. Redes

> 💡 **La idea de hoy:** enviar algo por la red es un problema demasiado grande para resolverlo de una vez, así que se reparte en **capas**: una lleva el paquete al vecino del mismo cable (MAC), otra lo lleva de máquina a máquina (IP), otra lo entrega al programa correcto (puerto) y la de arriba dice qué significa (HTTP). Cuando algo "no conecta", se pregunta **capa por capa, de abajo arriba**, hasta encontrar la que falla.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La VM `servidor-01` con nginx en el puerto 80 y tu `miapp` en el 8080 (clases 10 y 12).
> - `ssh servidor-01` y la variable `IP` con la dirección de la VM (clase 15).
> - `curl` para pedir una página (clase 17) y `systemctl stop|start` (clase 12).

> 🔤 **Palabras nuevas de hoy:**
> - **capa**: cada nivel de la red, que resuelve un problema concreto.
> - **MAC**: la dirección de la tarjeta de red; sirve para llegar al vecino del mismo cable.
> - **IP**: la dirección de la máquina; sirve para cruzar redes.
> - **puerto**: el número que dice a qué programa de la máquina va el paquete.
> - **ARP**: el protocolo que pregunta «¿quién tiene esta IP?» para averiguar su MAC.
> - **handshake TCP**: los tres paquetes (SYN, SYN-ACK, ACK) con los que empieza una conexión.
> - **tcpdump**: la herramienta que captura los paquetes y te los enseña.

## Objetivo

- Entender las **capas** de red (TCP/IP y su relación con OSI) y qué resuelve cada una.
- Ver con tus propios ojos, con `tcpdump`, una petición HTTP: ARP, el *handshake* TCP, la petición, la respuesta y el cierre.
- Usar las capas como **método de diagnóstico**: de abajo arriba.

## Por qué importa

"No conecta" es el problema más frecuente de la nube, y tiene muchas causas: ruta, firewall, security group, proceso caído, DNS, certificado. Quien piensa en capas lo resuelve en minutos: *"¿llega el paquete? ¿responde el puerto? ¿responde la app?"*. Además, AWS habla en capas: un **NLB** es de capa 4, un **ALB** es de capa 7, y un **security group** filtra en las capas 3 y 4.

## Cómo va esta clase

Cuatro piezas. En cada una lees **una** idea (en la 3 y la 4, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Hoy trabajas con **dos terminales**: una en tu PC y otra dentro de la VM (`ssh servidor-01`). Mira el prompt antes de cada comando.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, la **pieza 4**, el Rómpelo, el reto y el cierre.

En **tu PC**, guarda la IP de la VM (repítelo cada vez que abras una terminal nueva):

```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
```

## Las piezas

### Pieza 1 — Cada capa resuelve un problema

```
 Capa (TCP/IP)        ¿Qué problema resuelve?                Dirección        Ejemplos
 ─────────────────────────────────────────────────────────────────────────────────────────────
 4 Aplicación         ¿Qué quiere decir el programa?          URL, nombres     HTTP, DNS, SSH, TLS
 3 Transporte         ¿A qué PROGRAMA va, y llega entero?     PUERTO           TCP, UDP
 2 Red (Internet)     ¿A qué MÁQUINA va, cruzando redes?      IP               IP, ICMP (ping)
 1 Enlace             ¿Cómo llega al vecino del mismo cable?  MAC              Ethernet, Wi-Fi, ARP
```

Para entenderlo, compáralo con el correo postal: la carta (HTTP) va en un sobre con el nombre del departamento (puerto), dentro de un paquete con la dirección del edificio (IP). El cartero del barrio lo lleva de casa en casa usando la dirección del portal (MAC). En cada oficina de correos (router) se cambia de cartero (de MAC), pero la dirección del edificio (IP) no cambia en todo el viaje.

**Pruébalo**, en tu PC, de abajo arriba:

```bash
ip -br link          # capa 1-2: interfaces y su MAC
ip -br addr          # capa 3: IPs
ip route             # capa 3: rutas
```

👀 **Qué deberías ver:** tus interfaces (`lo`, la del Wi-Fi o el cable y la `mpqemubr0` de Multipass) con su MAC (`xx:xx:xx:xx:xx:xx`); sus IPs, con una `10.x.x.1` en `mpqemubr0`; y tus rutas, con una `default via …` hacia tu router.

✋ **Sin mirar:** ¿qué dirección usa la capa de transporte para saber a qué **programa** va el paquete?

<details>
<summary>Comprueba</summary>

El **puerto**: 80 para nginx, 22 para SSH, 8080 para tu `miapp`.
</details>

**En resumen:** MAC para el vecino, IP para la máquina, puerto para el programa y, arriba, el protocolo de la aplicación.

### Pieza 2 — ARP: de la IP a la MAC

Para enviar un paquete a una máquina de **tu misma red**, tu PC necesita su MAC. ARP la pregunta a toda la red: «¿quién tiene la IP 10.x.x.x?», y la máquina que la tiene contesta con su MAC. Cada máquina guarda las respuestas en su **tabla de vecinos**.

**Pruébalo.** En la VM (`ssh servidor-01`):

```bash
ip neigh             # tabla ARP: IP → MAC de los vecinos
ip -br link          # la MAC de la propia VM
```

En tu PC:

```bash
ip neigh | grep $IP
ping -c 2 $IP
ip neigh | grep $IP
```

👀 **Qué deberías ver:** en la VM, la IP de tu PC con su MAC, y la MAC de la interfaz de la VM. En tu PC, la IP de la VM asociada a una MAC (`REACHABLE` o `STALE`) que es **la misma** que la VM dice tener. (Si al principio no aparecía, el `ping` obligó a preguntar por ARP.)

✋ **Sin mirar:** ¿qué pregunta hace ARP y qué recibe como respuesta?

<details>
<summary>Comprueba</summary>

«¿Quién tiene esta IP?», y la respuesta es la MAC de la máquina que la tiene.
</details>

**En resumen:** dentro de una red, ARP traduce IP → MAC, y la tabla `ip neigh` guarda las respuestas.

### Pieza 3 — Encapsulación, y el viaje de un `curl`

Al enviar, cada capa **envuelve** lo de la de arriba con su cabecera. Al recibir, cada capa quita la suya:

```
[ Ethernet: MAC origen→destino [ IP: 10.0.0.1→10.0.0.5 [ TCP: puerto 51234→80 [ HTTP: GET / ] ] ] ]
```

Y este es el viaje completo de `curl http://10.x.x.x/`:

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

(Si fuese un nombre como `ejemplo.com`, antes de todo habría una consulta **DNS**: clase 31. Si fuese a otra red, el paso 1 buscaría la MAC del **router**: clase 30.)

**Pruébalo.** En la VM, captura todo lo que pase por el puerto 80:

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

👀 **Qué deberías ver:** unos diez paquetes: `[S]`, `[S.]` y `[.]` (el handshake); dos `[P.]` (la petición y la respuesta) con sus `[.]`; y los `[F.]` del cierre.

Para con `Ctrl+C`. Ahora mira el **contenido**:

```bash
sudo tcpdump -i any -nn -A port 80
```

Repite el `curl` desde tu PC.

👀 **Qué deberías ver:** `GET / HTTP/1.1`, las cabeceras (`Host:`, `User-Agent: curl/…`) y el HTML de la respuesta, en texto legible. **Cualquiera en el camino puede leer HTTP**: por eso existe HTTPS (clase 32).

✋ **Sin mirar:** ¿por qué con `-A` puedes leer la petición entera?

<details>
<summary>Comprueba</summary>

Porque HTTP viaja en texto claro, sin cifrar: `-A` solo enseña los bytes del paquete como texto.
</details>

**En resumen:** cada capa envuelve a la de arriba; una petición HTTP es ARP, el handshake (`[S]`, `[S.]`, `[.]`), los datos (`[P.]`) y el cierre (`[F.]`).

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Diagnóstico de abajo arriba, con los nombres de OSI

En entrevistas y en AWS te hablarán de "capa 7" o "capa 4". Eso viene del modelo **OSI**, más teórico:

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

Con esos nombres, el método para "no conecta":

| Pregunta | Herramienta | Si falla… |
|----------|-------------|-----------|
| ¿Tengo red e IP? | `ip -br addr`, `ip route` | interfaz caída o sin IP |
| ¿Llego a la máquina? (capa 3) | `ping IP` | ruta, o ICMP bloqueado (¡ojo!) |
| ¿Responde el puerto? (capa 4) | `nc -zv IP 80` | servicio caído, firewall o SG |
| ¿Responde la aplicación? (capa 7) | `curl -v http://IP/` | error de la app o de su configuración |

⚠️ Que `ping` falle **no** demuestra que la máquina esté caída: muchos firewalls (y los security groups de AWS por defecto) bloquean ICMP. Y que `ping` funcione no demuestra que la web vaya.

**Pruébalo**, desde tu PC, una capa por línea:

```bash
ping -c 3 $IP                        # capa 3
nc -zv $IP 80                        # capa 4: ¿el puerto acepta conexiones?
nc -zv $IP 8080                      # tu miapp
curl -v http://$IP/ 2>&1 | head -20  # capa 7
```

👀 **Qué deberías ver:** respuestas al `ping`; `Connection to … 80 port [tcp/http] succeeded!` y lo mismo con el 8080; y en `curl -v`, las líneas con `*` (la conexión, capas 3-4), las de `>` (la petición) y las de `<` (la respuesta, con `HTTP/1.1 200 OK`).

✋ **Sin mirar:** `ping` a una EC2 no responde. ¿Está caída?

<details>
<summary>Comprueba</summary>

No necesariamente: los security groups bloquean ICMP por defecto. Prueba la capa 4 (`nc -zv IP 22` o el puerto de la app) antes de sacar conclusiones.
</details>

**En resumen:** pregunta de abajo arriba: ¿IP y ruta?, ¿llego (`ping`)?, ¿responde el puerto (`nc -zv`)?, ¿responde la app (`curl -v`)?

## Tu chuleta de la clase

| Comando | Capa | Qué responde |
|---------|------|--------------|
| `ip -br link` · `ip -br addr` · `ip route` | 1-3 | interfaces y MAC · IPs · rutas |
| `ip neigh` | 1-2 | la tabla ARP: IP → MAC de los vecinos |
| `ping -c 3 IP` | 3 | ¿llego a la máquina? (si ICMP no está bloqueado) |
| `nc -zv -w 3 IP PUERTO` | 4 | ¿acepta conexiones ese puerto? |
| `curl -v http://IP/` | 7 | ¿responde la aplicación, y qué responde? |
| `sudo tcpdump -i any -nn port 80` · `-A` | todas | los paquetes que pasan · también su contenido |

| Mensaje | Significa |
|---------|-----------|
| `Connection refused` | llegaste a la máquina, pero nadie escucha en ese puerto |
| timeout | nadie contestó: algo descarta el paquete, o no hay camino |
| `No route to host` | un router, o tu propia máquina, dice que no hay camino |

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

Con tus dos terminales. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Captura una conexión SSH tuya a la VM. ¿Puedes leer los comandos que escribes, como con HTTP? ¿Por qué?

> 🧩 **Ejemplo resuelto:** el contenido de una petición HTTP, como en la pieza 3.
> ```bash
> sudo tcpdump -i any -nn -A port 80          # en la VM
> curl -s http://$IP/ > /dev/null             # en tu PC
> ```
> Se lee `GET / HTTP/1.1` y el HTML: HTTP va en texto claro.

**Ahora tú, con huecos:**
```bash
sudo tcpdump -i any -nn -A -c 40 port ____ > /tmp/captura-ssh.txt     # en la VM: la salida va a un archivo
ssh servidor-01 'echo hola'                                          # en tu PC
grep -c hola /tmp/captura-ssh.txt                                    # en la VM, cuando tcpdump termine
```

La captura va a un archivo a propósito: tú estás conectado a la VM **por SSH**. Si vieras la salida en pantalla, cada línea que te llega sería un paquete SSH más que capturar, y la captura no pararía nunca.

<details>
<summary>Pista</summary>

SSH usa el puerto 22. `grep -c` cuenta las líneas en las que aparece `hola`. ¿Qué hace SSH con todo lo que envía, desde la clase 15?
</details>

**2.** Mira con `tcpdump` los mensajes de un `ping`. ¿De qué tipo son?

> 🧩 **Ejemplo resuelto:** filtrar la captura por un **puerto**: `sudo tcpdump -i any -nn port 80`.

**Ahora tú, con huecos:** en la VM, `sudo tcpdump -i any -nn ____`; en tu PC, `ping -c 3 $IP`.

<details>
<summary>Pista</summary>

`ping` no usa puertos: usa ICMP. A `tcpdump` se le puede pedir un protocolo por su nombre, en minúsculas.
</details>

**3.** ¿Qué capa usa cada uno: `ping`, `nc -zv` y `curl`?

> 🧩 **Ejemplo resuelto:** `ping` → capa **3**: envía ICMP sobre IP, sin puertos.

**Ahora tú, con huecos:** `nc -zv` → capa ____ (abre una conexión ____ y la cierra) · `curl` → capa ____ (habla ____ sobre TCP sobre IP).

<details>
<summary>Pista</summary>

Mira la tabla del método en la pieza 4.
</details>

**4.** Escribe la encapsulación de tu `curl` con las IPs, los puertos y las MACs **reales** de hoy.

> 🧩 **Ejemplo resuelto:** la de la pieza 3, con datos inventados:
> ```
> [ Ethernet: MAC aa:aa:aa:aa:aa:01→52:54:00:12:34:56 [ IP: 10.0.0.1→10.0.0.5 [ TCP: puerto 51234→80 [ HTTP: GET / ] ] ] ]
> ```

**Ahora tú, con huecos**, en tus notas:
```
[ Ethernet: MAC ____→____ [ IP: ____→____ [ TCP: puerto ____→80 [ HTTP: GET / ] ] ] ]
```

<details>
<summary>Pista</summary>

Las MACs: `ip -br link` en tu PC (la de `mpqemubr0`) y en la VM. Las IPs: `ip -br addr` en los dos. El puerto de origen lo elige tu PC al azar: lo ves en `tcpdump`, al lado de tu IP (`10.x.x.1.51234 > …`).
</details>

## Cierre

En `notas/fase-3/clase-26.md`:

1. Explica las 4 capas de TCP/IP: qué resuelve cada una y qué dirección usa. *(4 líneas, una por capa. Empieza así: «Enlace: entrega al vecino de la misma red, con la MAC… Red:… Transporte:… Aplicación:…»)*
2. Cuenta el *handshake* TCP y qué viste en `tcpdump`. *(2 líneas. Empieza así: «El cliente envía SYN, el servidor… y el cliente… En `tcpdump` se ve `[S]`…»)*
3. "Connection refused" frente a "timeout": qué significa cada uno y qué revisarías en AWS en cada caso. *(2–3 líneas. Empieza así: «Refused: llegué a la máquina, pero… Revisaría… Timeout: nadie contestó… Revisaría el security group,…»)*
4. **Repaso (clase 15, sin mirar):** ¿por qué al cambiar la configuración de SSH se deja una sesión abierta? *(2 líneas. Empieza así: «Porque si la configuración nueva tiene un error, las conexiones nuevas…, pero la sesión abierta…»)*

Después, escríbeme `examíname clase-26`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Enlace**: entrega entre vecinos de la misma red física, usando direcciones **MAC** (ARP traduce IP → MAC). **Red**: lleva el paquete de máquina a máquina a través de redes, con direcciones **IP** y routers. **Transporte**: entrega al **programa** correcto mediante el **puerto**; TCP además garantiza el orden y la entrega. **Aplicación**: el significado del mensaje (HTTP, DNS, SSH).

**2.** El cliente envía **SYN** (quiere conectar), el servidor responde **SYN-ACK** (acepta) y el cliente confirma con **ACK**. En `tcpdump`: `[S]`, `[S.]`, `[.]`. Después, paquetes `[P.]` con la petición y la respuesta, y el cierre con `[F.]`.

**3.** **Refused**: el paquete llegó y el kernel respondió con RST porque nadie escucha en ese puerto. Hay que mirar el **servicio**: ¿está activo? ¿en qué puerto y en qué IP escucha? (`ss -tlnp`, clase 29). **Timeout**: no llegó respuesta. Algo **descarta** el paquete o no hay camino: en AWS se revisa el **security group** (regla de entrada para ese puerto y origen), la **NACL**, la **tabla de rutas** (¿hay Internet Gateway?), si la instancia tiene IP pública y si está encendida.

**4.** Porque si la configuración nueva tiene un error, las conexiones **nuevas** fallan, pero la sesión que ya está abierta sigue funcionando y permite deshacer el cambio. Sin ella, puedes perder el acceso al servidor.

**Reto:** 1) `port 22`, y `grep -c` da `0`. No: SSH **cifra** todo después del intercambio inicial; `echo hola` no aparece por ningún sitio, solo bytes ilegibles. 2) `icmp`: `ICMP echo request` (de tu PC) y `ICMP echo reply` (de la VM). 3) `nc -zv`: capa **4** (abre una conexión **TCP** y la cierra). `curl`: capa **7** (habla **HTTP** sobre TCP sobre IP). 4) Las MACs de `mpqemubr0` (tu PC) y de la interfaz de la VM; las IPs `10.x.x.1` (tu PC) y la de la VM; el puerto de origen, el número alto que viste en `tcpdump`.
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

[Clase 27 — Direcciones IP y CIDR](clase-27-ip-y-cidr.md)
