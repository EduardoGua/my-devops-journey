# Clase 29 — Puertos, TCP y UDP

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** A. Redes

> 💡 **La idea de hoy:** la IP lleva el paquete a la **máquina**; el **puerto** lo entrega al **programa** que escucha en ella. Un servidor escucha en un puerto conocido (80, 22, 5432) y en una **dirección** concreta: si escucha en `127.0.0.1`, solo lo alcanza la propia máquina, por muchas reglas de firewall que abras. **TCP** abre una conexión y garantiza la entrega; **UDP** envía y no espera nada.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La capa de transporte entrega al programa por su puerto, y el handshake TCP es `[S]`, `[S.]`, `[.]` (clase 26, piezas 1 y 3).
> - `Connection refused` frente a timeout (clase 26, Rómpelo).
> - `nc -zv`, `tcpdump` y la variable `IP` con la dirección de la VM (clase 26).
> - nginx corre como root para abrir el puerto 80 y baja a `www-data` (clase 11, pieza 3).

> 🔤 **Palabras nuevas de hoy:**
> - **puerto**: el número (0–65535) que identifica a un programa dentro de una máquina.
> - **socket**: la pareja `IP:puerto`.
> - **puerto efímero**: el puerto de origen que tu sistema elige al azar para cada conexión saliente.
> - **dirección de escucha**: la IP en la que un servidor acepta conexiones (`127.0.0.1`, `0.0.0.0`…).
> - **`ss`**: el comando que lista los sockets: qué escucha, dónde y quién.
> - **TCP / UDP**: con conexión y garantías / sin conexión ni garantías.

## Objetivo

- Entender qué es un **puerto** y un **socket**, y conocer los puertos que verás cada día.
- Diferenciar **TCP** y **UDP** y saber cuándo se usa cada uno.
- Leer `ss -tulpn` y saber **qué escucha, dónde y quién**.
- Entender la **dirección de escucha** (`127.0.0.1` frente a `0.0.0.0`), la causa más frecuente de "en local funciona y desde fuera no".

## Por qué importa

Cada regla de un security group es **protocolo + puerto + origen**. Cada contenedor publica puertos. Cada balanceador tiene *listeners* en puertos y comprueba la salud de tus apps en otro puerto. Y uno de los fallos más típicos de quien empieza en la nube es una app que escucha en `127.0.0.1` y por eso nunca recibe el tráfico, por muchas reglas que abra.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea (en la 2 y la 3, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Hoy necesitas **dos terminales en la VM** (`ssh servidor-01`) y una en tu PC: mira el prompt antes de cada comando.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

En **tu PC**:

```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
```

## Las piezas

### Pieza 1 — Puertos y sockets

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

Los que debes saber de memoria:

| Puerto | Servicio | | Puerto | Servicio |
|--------|----------|-|--------|----------|
| 22/tcp | SSH | | 3306/tcp | MySQL |
| 53/udp+tcp | DNS | | 5432/tcp | PostgreSQL |
| 80/tcp | HTTP | | 6379/tcp | Redis |
| 443/tcp | HTTPS | | 8080/tcp | HTTP alternativo |
| 123/udp | NTP (hora) | | 2049/tcp | NFS / Amazon EFS |
| 25/tcp | SMTP | | 3389/tcp | RDP (Windows) |

**Pruébalo.** En la VM:

```bash
sudo ss -tulpn
sudo ss -tnp state established
```

🔮 **Predice:** ¿qué verás en la conexión establecida del puerto 22? ¿Cuál es tu puerto de origen?

👀 **Qué deberías ver:** en la primera lista, quién escucha en el 22 (`sshd`), el 80 (`nginx`) y el 8080 (`python3`, tu `miapp`). En la segunda, tu propia conexión SSH: puerto local `:22` y, al otro lado, la IP de tu PC con un puerto **efímero** alto, como `10.x.x.1:51234`.

✋ **Sin mirar:** tu PC se conecta a la VM por SSH. ¿Qué puerto usa en la VM, y qué tipo de puerto usa en tu PC?

<details>
<summary>Comprueba</summary>

El 22, en la VM; en tu PC, un puerto efímero que eligió el sistema para esa conexión.
</details>

**En resumen:** la IP lleva a la máquina y el puerto al programa; el servidor usa un puerto conocido y el cliente, uno efímero.

### Pieza 2 — `ss`, tu radar, y la dirección de escucha

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

La columna *Local Address* dice **dónde** escucha cada servidor, y eso decide quién puede conectar:

| Escucha en | ¿Quién puede conectar? |
|------------|------------------------|
| `127.0.0.1:8000` | **solo** procesos de la propia máquina |
| `10.x.x.5:8000` | quien llegue por esa interfaz |
| `0.0.0.0:8000` (o `*:8000`) | por **cualquier** interfaz de la máquina |
| `[::]:8000` | todas las interfaces IPv6 (y a menudo también IPv4) |

**Pruébalo.** En la VM, una web mínima **solo en localhost**:

```bash
mkdir -p /tmp/web19 && echo "hola desde la VM" > /tmp/web19/index.html
python3 -m http.server 8000 --bind 127.0.0.1 --directory /tmp/web19 &
ss -tlnp | grep 8000
curl -s localhost:8000
```

👀 **Qué deberías ver:** `LISTEN … 127.0.0.1:8000` y `hola desde la VM`: desde la propia VM, funciona.

Desde **tu PC**:

```bash
curl -s -m 3 http://$IP:8000 || echo "FALLA"
```

🔮 **Predice:** ¿será *refused* o *timeout*? ¿Por qué?

<details>
<summary>Compruébalo</summary>

`FALLA`, al instante: es un **refused**. El paquete llega a la VM, pero en la IP `10.x.x.5` nadie escucha en el 8000: el servidor solo escucha en `127.0.0.1`.
</details>

En la VM, relánzalo escuchando en todas las interfaces:

```bash
kill %1
python3 -m http.server 8000 --bind 0.0.0.0 --directory /tmp/web19 &
ss -tlnp | grep 8000
```

Desde tu PC: `curl -s http://$IP:8000`.

👀 **Qué deberías ver:** `LISTEN … 0.0.0.0:8000` en la VM y, en tu PC, `hola desde la VM`. **Es el mismo programa con otra dirección de escucha.** Así se comportan Flask, Node o Postgres según cómo se configuren. Y dentro de un contenedor, una app que escucha en `127.0.0.1` no recibe nada aunque publiques el puerto (fase 5).

`kill %1` al terminar.

✋ **Sin mirar:** en `ss` ves `*:80` en la columna *Local Address*. ¿Qué significa?

<details>
<summary>Comprueba</summary>

Que escucha en el puerto 80 en **todas** las interfaces: lo mismo que `0.0.0.0:80`.
</details>

**En resumen:** `ss -tulpn` dice qué escucha, dónde y quién; `127.0.0.1` es solo para la propia máquina y `0.0.0.0`, para todas sus interfaces.

### Pieza 3 — Hablar TCP a mano, y los estados de una conexión

Una conexión TCP pasa por estados, y `ss` te los enseña:

| Estado | Significado |
|--------|-------------|
| `LISTEN` | servidor esperando conexiones |
| `ESTAB` | conexión establecida |
| `TIME-WAIT` | cerrada hace poco; el kernel la retiene unos segundos. Miles indican muchas conexiones cortas |
| `SYN-SENT` | el cliente envió SYN y espera: si se queda así, algo descarta los paquetes |

Y TCP no es más que un canal: lo que escribes en un extremo sale por el otro. HTTP, por ejemplo, es solo **texto** sobre TCP.

**Pruébalo, primero un chat sobre TCP.** En la VM, un servidor TCP en el puerto 9000:

```bash
nc -l 9000
```

En tu PC:

```bash
nc $IP 9000
```

Escribe en cualquiera de los dos lados: aparece en el otro. Mientras está abierto, en **otra terminal** de la VM:

```bash
ss -tnp | grep 9000
```

👀 **Qué deberías ver:** una conexión `ESTAB` entre `10.x.x.5:9000` y el puerto efímero de tu PC. `Ctrl+C` para cerrar.

**Ahora, HTTP a mano**, desde tu PC, con nginx en la VM:

```bash
printf 'GET / HTTP/1.1\r\nHost: servidor-01\r\nConnection: close\r\n\r\n' | nc $IP 80 | head -15
```

👀 **Qué deberías ver:** `HTTP/1.1 200 OK`, las cabeceras de nginx (`Server: nginx/…`, `Content-Type: text/html`) y el principio del HTML. Escribiste a mano lo que `curl` y el navegador envían por ti.

✋ **Sin mirar:** en `ss` ves muchas conexiones en `SYN-SENT` hacia el mismo destino. ¿Qué sospechas?

<details>
<summary>Comprueba</summary>

Que algo descarta los paquetes (un firewall, un security group o una ruta): el SYN sale, pero no vuelve el SYN-ACK.
</details>

**En resumen:** `ESTAB` es una conexión viva y `SYN-SENT` atascado, paquetes que se pierden; y HTTP es texto sobre TCP.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — TCP frente a UDP

| | TCP | UDP |
|-|-----|-----|
| Conexión | sí (handshake) | no: envía y ya |
| Garantías | orden, reenvío de lo perdido, control de flujo | ninguna |
| Coste | más lento al empezar | mínimo |
| Usos | web, SSH, bases de datos, APIs | DNS, vídeo y voz en directo, juegos, NTP, métricas (StatsD) |

Con UDP, "el puerto parece abierto" no se puede comprobar como con TCP: no hay handshake ni RST fiable. Si no hay respuesta, no sabes si llegó.

**Pruébalo.** En la VM, en una terminal, `sudo tcpdump -i any -nn port 9001`; en la otra:

```bash
nc -u -l 9001
```

En tu PC:

```bash
nc -u $IP 9001
```

Escribe algo.

👀 **Qué deberías ver:** el texto llega, y en `tcpdump` **no hay handshake**: solo un paquete `UDP` por mensaje, sin `[S]` ni `[S.]`.

Ahora cierra el servidor (`Ctrl+C` en la VM) y vuelve a escribir desde tu PC. 🔮 ¿Te avisa de algo? Con UDP, a menudo **no te enteras** de que nadie escucha.

✋ **Sin mirar:** ¿por qué con UDP no puedes comprobar si un puerto está abierto como haces con `nc -zv` en TCP?

<details>
<summary>Comprueba</summary>

Porque no hay handshake: no llega un SYN-ACK que diga «aquí hay alguien» ni un RST fiable que diga «aquí no hay nadie».
</details>

**En resumen:** TCP conecta y garantiza; UDP envía y no espera, y por eso es rápido y no avisa de nada.

### Pieza 5 — Los puertos privilegiados

Por debajo del 1024, solo root (o un programa con un permiso especial) puede escuchar. Por eso nginx arranca como root y baja de privilegios (clase 11), y por eso muchas apps escuchan en el 8080, con un proxy o un balanceador delante.

**Pruébalo.** En la VM, como `ubuntu`:

```bash
python3 -m http.server 80 --directory /tmp/web19
```

👀 **Qué deberías ver:** `PermissionError: [Errno 13] Permission denied`. El puerto 80 está ocupado por nginx, pero el kernel ni siquiera llega a comprobarlo: un usuario normal no puede escuchar en puertos < 1024.

✋ **Sin mirar:** ¿por qué tantas apps escuchan en el 8080 y no en el 80?

<details>
<summary>Comprueba</summary>

Para no tener que correr como root: el 8080 no es privilegiado. Delante se pone un proxy o un balanceador que escucha en el 80 o el 443.
</details>

**En resumen:** los puertos < 1024 necesitan root; las apps usan puertos altos con un proxy delante.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `sudo ss -tulpn` | qué escucha (TCP y UDP), dónde y qué proceso |
| `ss -tnp state established` · `ss -tn \| grep PUERTO` | las conexiones vivas · las de un puerto |
| `sudo ss -tlnp 'sport = :8080'` · `sudo lsof -i :8080` | quién ocupa un puerto |
| `python3 -m http.server 8000 --bind 127.0.0.1` | una web de prueba (`--bind 0.0.0.0` para todas las interfaces) |
| `nc -l 9000` · `nc IP 9000` | servidor y cliente TCP a mano |
| `nc -u -l 9001` · `nc -u IP 9001` | lo mismo con UDP |
| `nc -zv -w1 IP 20-90` | qué puertos TCP aceptan conexiones (solo en tus máquinas) |

| Dirección de escucha | Quién puede conectar |
|----------------------|----------------------|
| `127.0.0.1` | solo la propia máquina |
| `0.0.0.0` · `*` · `[::]` | cualquiera que llegue por cualquier interfaz |

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
En la VM: `nc -l 9000`. Desde tu PC: `nc $IP 9000`. En la VM, en otra sesión: `ss -tn | grep 9000`. Observa que el servidor ve **tu** IP y tu puerto efímero. Los security groups son *stateful*: si permites la entrada al 9000, la respuesta hacia tu puerto efímero sale sola. Las NACLs de AWS **no** lo son: hay que permitir los efímeros de forma explícita (clase 33).

## Reto

Con tus terminales en la VM y en tu PC. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Lista los procesos que escuchan **en todas las interfaces** en la VM. ¿Alguno no debería estar expuesto?

> 🧩 **Ejemplo resuelto:** los que escuchan **solo** en la propia máquina.
> ```bash
> sudo ss -tlnp | grep 127.0.0.1
> ```
> Suelen salir servicios internos, como el resolvedor de DNS local (`127.0.0.53:53`). Nadie de fuera puede llegar a ellos.

**Ahora tú, con huecos:** `sudo ss -tlnp | grep -E "____|\*|\[::\]"`

<details>
<summary>Pista</summary>

La dirección que significa «todas las interfaces» en IPv4 es la del último punto de la pieza 2. Una base de datos en esa lista sería sospechosa.
</details>

**2.** Escanea desde tu PC los puertos 20 a 90 de la VM. ¿Qué encuentras? (Escanear máquinas que no son tuyas **no** se hace.)

> 🧩 **Ejemplo resuelto:** un solo puerto.
> ```bash
> nc -zv -w1 $IP 22
> ```
> `Connection to … 22 port [tcp/ssh] succeeded!`: el 22 acepta conexiones.

**Ahora tú, con huecos:** `nc -zv -w1 $IP ____-____ 2>&1 | grep succeeded`

<details>
<summary>Pista</summary>

`nc -zv` acepta un rango, escrito como `inicio-fin`. Los que fallan escriben en stderr: por eso el `2>&1` antes del `grep`.
</details>

**3.** ¿Qué puerto **de origen** usó tu PC para su último `curl` a la VM?

> 🧩 **Ejemplo resuelto:** en el Rómpelo 3, `ss -tn | grep 9000` en la VM enseñaba tu IP y tu puerto efímero al otro lado de la conexión `nc`.

**Ahora tú, con huecos:** en la VM, `sudo tcpdump -i any -nn -c 3 port ____`; en tu PC, `curl -s http://$IP/ > /dev/null`. En la primera línea, lee `10.x.x.1.____ > 10.x.x.5.80`.

<details>
<summary>Pista</summary>

`curl` va a nginx, en el puerto 80. En `tcpdump`, el puerto va pegado a la IP, detrás del último punto.
</details>

**4.** ¿Por qué el DNS usa UDP para las consultas normales y TCP para las respuestas grandes?

> 🧩 **Ejemplo resuelto:** por qué una videollamada usa UDP. Un trozo de audio perdido hace un segundo ya no sirve: mejor seguir con el siguiente que esperar a reenviarlo, que es lo que haría TCP.

**Ahora tú, con huecos:** una consulta DNS normal cabe en ____ paquete, y con UDP no hay ____, así que es más rápida. Si la respuesta es demasiado ____, se repite por ____.

<details>
<summary>Pista</summary>

Piensa en lo que cuesta el handshake de TCP (pieza 3 de la clase 26) frente a una pregunta y una respuesta de un solo paquete.
</details>

## Cierre

En `notas/fase-3/clase-29.md`:

1. ¿Qué es un puerto? ¿Qué diferencia hay entre el puerto del servidor y el puerto efímero del cliente? *(2–3 líneas. Empieza así: «Un puerto es el número que identifica… El servidor escucha en uno fijo y conocido para… El cliente usa uno efímero que…»)*
2. Una API responde con `curl localhost:5000` dentro de la EC2, pero no desde fuera, y el security group permite el 5000. ¿Qué sospechas primero y con qué comando lo confirmas? *(2 líneas. Empieza así: «Que la app escucha en `127.0.0.1`… Lo confirmo con `sudo ss -tlnp | grep 5000`, buscando…»)*
3. TCP frente a UDP: diferencias y dos ejemplos de uso de cada uno. *(2–3 líneas. Empieza así: «TCP abre una conexión y garantiza…, por ejemplo… UDP…»)*
4. **Repaso (clase 28, sin mirar):** ¿por qué cada capa de subredes se repite en al menos dos AZs? *(2 líneas. Empieza así: «Porque una subred vive en una sola AZ, y si esa AZ cae…»)*

Después, escríbeme `examíname clase-29`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Un número (0–65535) que identifica a qué **programa** de una máquina va el tráfico. El servidor escucha en un puerto **fijo y conocido** (80, 443, 5432) para que los clientes sepan dónde llamar. El cliente usa un puerto **efímero** que su sistema elige al azar para cada conexión, y así el servidor sabe a dónde devolver la respuesta. La conexión es la combinación de ambos más las IPs.

**2.** Que la app **escucha en `127.0.0.1`** y no en `0.0.0.0`. Se confirma con `sudo ss -tlnp | grep 5000`: si pone `127.0.0.1:5000`, solo es accesible desde la propia máquina. Se arregla configurando la app para escuchar en `0.0.0.0` (p. ej. `flask run --host=0.0.0.0`). Si el destino no responde nada (timeout) en vez de refused, revisarías también firewall, NACL y rutas.

**3.** TCP: con conexión, fiable y ordenado, más coste inicial. Web, SSH, bases de datos. UDP: sin conexión ni garantías, mínimo coste. DNS, streaming en directo, VoIP, NTP, juegos.

**4.** Porque una subred vive en una sola AZ y una AZ puede caer. Con cada capa repetida en dos o más, el servicio sigue funcionando desde la otra.

**Reto:** 1) `0.0.0.0`. Normalmente `22` (sshd), `80` (nginx) y `8080` (miapp, que escucha en todas porque `http.server` usa `0.0.0.0` por defecto). Algo como una base de datos en `0.0.0.0` sería sospechoso. 2) `20-90`: el `22` y el `80` abiertos. 3) `port 80`; el número alto que va detrás de la IP de tu PC. 4) Un paquete; no hay handshake; demasiado grande (o en transferencias de zona); se repite por TCP.
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

[Clase 30 — Rutas, gateway y NAT](clase-30-rutas-y-nat.md)
