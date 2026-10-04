# Clase 19 — Puertos, TCP y UDP

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** C. Redes

## Objetivo

- Entender qué es un **puerto** y un **socket**, y conocer los puertos que verás cada día.
- Diferenciar **TCP** y **UDP** y saber cuándo se usa cada uno.
- Leer `ss -tulpn` y saber **qué escucha, dónde y quién**.
- Entender la **dirección de escucha** (`127.0.0.1` frente a `0.0.0.0`), la causa más frecuente de "en local funciona y desde fuera no".

## Por qué importa

Cada regla de un security group es **protocolo + puerto + origen**. Cada contenedor publica puertos. Cada balanceador tiene *listeners* en puertos y comprueba la salud de tus apps en otro puerto. Y uno de los fallos más típicos de quien empieza en la nube es una app que escucha en `127.0.0.1` y por eso nunca recibe el tráfico, por muchas reglas que abra.

## Teoría

### Puertos

Una IP identifica una **máquina**. Un **puerto** (0–65535) identifica un **programa** dentro de ella. Un **socket** es la pareja `IP:puerto`. Una conexión TCP queda definida por **5 datos**: protocolo, IP de origen, puerto de origen, IP de destino y puerto de destino.

```
   Tu PC 10.x.x.1:51234  ──TCP──►  VM 10.x.x.5:80 (nginx)
         └ puerto EFÍMERO                └ puerto CONOCIDO
           (el SO elige uno libre)          (el servicio lo reserva)
```

| Rango | Nombre | Notas |
|-------|--------|-------|
| 0–1023 | conocidos / privilegiados | hace falta root (o un permiso especial) para escuchar en ellos |
| 1024–49151 | registrados | apps (8080, 5432…) |
| 32768–60999 | efímeros (en Linux) | puertos de **origen** de tus conexiones salientes |

### Los que debes saber de memoria

| Puerto | Servicio | | Puerto | Servicio |
|--------|----------|-|--------|----------|
| 22/tcp | SSH | | 3306/tcp | MySQL |
| 53/udp+tcp | DNS | | 5432/tcp | PostgreSQL |
| 80/tcp | HTTP | | 6379/tcp | Redis |
| 443/tcp | HTTPS | | 8080/tcp | HTTP alternativo |
| 123/udp | NTP (hora) | | 2049/tcp | NFS / Amazon EFS |
| 25/tcp | SMTP | | 3389/tcp | RDP (Windows) |

### TCP frente a UDP

| | TCP | UDP |
|-|-----|-----|
| Conexión | sí (handshake) | no: envía y ya |
| Garantías | orden, reenvío de lo perdido, control de flujo | ninguna |
| Coste | más lento al empezar | mínimo |
| Usos | web, SSH, bases de datos, APIs | DNS, vídeo y voz en directo, juegos, NTP, métricas (StatsD) |

Con UDP, "el puerto parece abierto" no se puede comprobar como con TCP: no hay handshake ni RST fiable. Si no hay respuesta, no sabes si llegó.

### Estados de una conexión TCP (los que verás en `ss`)

| Estado | Significado |
|--------|-------------|
| `LISTEN` | servidor esperando conexiones |
| `ESTAB` | conexión establecida |
| `TIME-WAIT` | cerrada hace poco; el kernel la retiene unos segundos. Miles indican muchas conexiones cortas |
| `SYN-SENT` | el cliente envió SYN y espera: si se queda así, algo descarta los paquetes |

### La dirección de escucha

| Escucha en | ¿Quién puede conectar? |
|------------|------------------------|
| `127.0.0.1:8000` | **solo** procesos de la propia máquina |
| `10.x.x.5:8000` | quien llegue por esa interfaz |
| `0.0.0.0:8000` (o `*:8000`) | por **cualquier** interfaz de la máquina |
| `[::]:8000` | todas las interfaces IPv6 (y a menudo también IPv4) |

### `ss`, tu radar

```bash
ss -tulpn
#  t=TCP  u=UDP  l=solo LISTEN  p=proceso (con sudo)  n=números, sin traducir a nombres
```

```
Netid State  Local Address:Port  Peer Address:Port  Process
tcp   LISTEN 0.0.0.0:80          0.0.0.0:*          users:(("nginx",pid=812,fd=6))
tcp   LISTEN 127.0.0.1:5432      0.0.0.0:*          users:(("postgres",pid=900,fd=5))
       └ qué protocolo y en qué IP:puerto escucha        └ quién
```

## Práctica guiada

### 1. Qué escucha en la VM

```bash
ssh servidor-01
sudo ss -tulpn
sudo ss -tnp state established
```

🔮 **Predice:** ¿qué verás en la conexión establecida del puerto 22? ¿Cuál es tu puerto de origen?

Busca tu propia conexión SSH: puerto local 22 y el puerto **efímero** de tu PC al otro lado.

### 2. `127.0.0.1` frente a `0.0.0.0`

En la VM, una web mínima **solo en localhost**:
```bash
mkdir -p /tmp/web19 && echo "hola desde la VM" > /tmp/web19/index.html
python3 -m http.server 8000 --bind 127.0.0.1 --directory /tmp/web19 &
ss -tlnp | grep 8000
curl -s localhost:8000
```

Desde **tu PC**:
```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
curl -s -m 3 http://$IP:8000 || echo "FALLA"
```

🔮 **Predice:** ¿será *refused* o *timeout*? ¿Por qué?

En la VM, relánzalo escuchando en todas las interfaces:
```bash
kill %1
python3 -m http.server 8000 --bind 0.0.0.0 --directory /tmp/web19 &
ss -tlnp | grep 8000
```

Desde tu PC: `curl -s http://$IP:8000`. Ahora sí funciona. **Es el mismo programa con otra dirección de escucha.** Así se comportan Flask, Node o Postgres según cómo se configuren. Y dentro de un contenedor, una app que escucha en `127.0.0.1` no recibe nada aunque publiques el puerto (fase 3).

`kill %1` al terminar.

### 3. Hablar TCP a mano con `nc`

En la VM, un servidor TCP en el puerto 9000:
```bash
nc -l 9000
```

En tu PC:
```bash
nc $IP 9000
```

Escribe en cualquiera de los dos lados: aparece en el otro. Es un *chat* sobre TCP sin ninguna aplicación por encima. Mientras está abierto, en otra terminal de la VM:
```bash
ss -tnp | grep 9000
```
Una conexión `ESTAB` con el puerto efímero de tu PC. `Ctrl+C` para cerrar.

### 4. Hablar HTTP a mano

HTTP es solo texto sobre TCP. Desde tu PC, con nginx en la VM:
```bash
printf 'GET / HTTP/1.1\r\nHost: servidor-01\r\nConnection: close\r\n\r\n' | nc $IP 80 | head -15
```

Escribiste a mano lo que `curl` y el navegador envían por ti.

### 5. UDP

En la VM, con `tcpdump` en otra sesión (`sudo tcpdump -i any -nn port 9001`):
```bash
nc -u -l 9001
```

En tu PC:
```bash
nc -u $IP 9001
```

Escribe algo. Llega, pero en `tcpdump` **no hay handshake**: solo un paquete `UDP` por mensaje. Ahora cierra el servidor (`Ctrl+C` en la VM) y vuelve a escribir desde tu PC. 🔮 ¿Te avisa de algo? Con UDP, a menudo **no te enteras** de que nadie escucha.

### 6. Puertos privilegiados

En la VM:
```bash
python3 -m http.server 80 --directory /tmp/web19
```

`Permission denied`: el puerto 80 está ocupado por nginx, pero aunque no lo estuviera, un usuario normal no puede escuchar en puertos < 1024. Por eso nginx arranca como root y baja de privilegios (clase 11), y por eso muchas apps escuchan en el 8080 con un proxy o balanceador delante.

## Rómpelo

**1. Puerto ocupado:**
```bash
python3 -m http.server 8080 --directory /tmp/web19
```
`Address already in use`: es `miapp` (clase 12). Encuentra **quién** lo ocupa:
```bash
sudo ss -tlnp 'sport = :8080'
sudo lsof -i :8080
```
Después de un despliegue que falla al arrancar, este es el primer sospechoso: la versión vieja sigue viva ocupando el puerto.

**2. El puerto equivocado:**
Desde tu PC, `curl -s -m 3 http://$IP:8081`. Refused. Comprueba en la VM con `ss -tlnp` **en qué puerto** escucha de verdad la app. Muchos "no funciona" son una errata en el número de puerto de la configuración, del security group o del health check.

**3. Lo que ve el destino:**
En la VM: `nc -l 9000`. Desde tu PC: `nc $IP 9000`. En la VM, en otra sesión: `ss -tn | grep 9000`. Observa que el servidor ve **tu** IP y tu puerto efímero. Los security groups son *stateful*: si permites la entrada al 9000, la respuesta hacia tu puerto efímero sale sola. Las NACLs de AWS **no** lo son: hay que permitir los efímeros de forma explícita (clase 23).

## Reto

1. Lista, solo con números, los procesos que escuchan **en todas las interfaces** en la VM (`ss -tlnp | grep -E "0.0.0.0|\*|\[::\]"`). ¿Alguno no debería estar expuesto?
2. Con `nc -zv`, escanea desde tu PC los puertos 20–90 de la VM: `nc -zv -w1 $IP 20-90 2>&1 | grep succeeded`. ¿Qué encuentras? (Escanear máquinas que no son tuyas **no** se hace.)
3. ¿Qué puerto **de origen** usó tu PC para el último `curl`? Averígualo con `tcpdump` en la VM.
4. Explica por qué el DNS usa UDP para las consultas normales y TCP para las respuestas grandes.

## Cierre

En `notas/fase-1/clase-19.md`:

1. ¿Qué es un puerto? ¿Qué diferencia hay entre el puerto del servidor y el puerto efímero del cliente?
2. Una API responde con `curl localhost:5000` dentro de la EC2, pero no desde fuera, y el security group permite el 5000. ¿Qué sospechas primero y con qué comando lo confirmas?
3. TCP frente a UDP: diferencias y dos ejemplos de uso de cada uno.
4. **Repaso (clase 18, sin mirar):** ¿por qué cada capa de subredes se repite en al menos dos AZs?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un número (0–65535) que identifica a qué **programa** de una máquina va el tráfico. El servidor escucha en un puerto **fijo y conocido** (80, 443, 5432) para que los clientes sepan dónde llamar. El cliente usa un puerto **efímero** que su sistema elige al azar para cada conexión, y así el servidor sabe a dónde devolver la respuesta. La conexión es la combinación de ambos más las IPs.

**2.** Que la app **escucha en `127.0.0.1`** y no en `0.0.0.0`. Se confirma con `sudo ss -tlnp | grep 5000`: si pone `127.0.0.1:5000`, solo es accesible desde la propia máquina. Se arregla configurando la app para escuchar en `0.0.0.0` (p. ej. `flask run --host=0.0.0.0`). Si el destino no responde nada (timeout) en vez de refused, revisarías también firewall, NACL y rutas.

**3.** TCP: con conexión, fiable y ordenado, más coste inicial. Web, SSH, bases de datos. UDP: sin conexión ni garantías, mínimo coste. DNS, streaming en directo, VoIP, NTP, juegos.

**4.** Porque una subred vive en una sola AZ y una AZ puede caer. Con cada capa repetida en dos o más, el servicio sigue funcionando desde la otra.

**Reto:** 1) Normalmente `22` (sshd), `80` (nginx) y `8080` (miapp, que escucha en todas porque `http.server` usa `0.0.0.0` por defecto). Algo como una base de datos en `0.0.0.0` sería sospechoso. 2) `22` y `80` abiertos. 4) Una consulta DNS cabe en un solo paquete, así que UDP es más rápido (sin handshake). Si la respuesta es demasiado grande (o en transferencias de zona), se repite por TCP.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| port / socket | puerto / socket |
| ephemeral port | puerto efímero |
| to listen on / to bind to | escuchar en / enlazar a |
| stateful / stateless | con estado / sin estado |
| address already in use | dirección ya en uso |

🎙️ *"If an app works with localhost but not from outside, the first thing I check with `ss -tlnp` is whether it's bound to 127.0.0.1 instead of 0.0.0.0."*

## Siguiente

[Clase 20 — Rutas, gateway y NAT](clase-20-rutas-y-nat.md)
