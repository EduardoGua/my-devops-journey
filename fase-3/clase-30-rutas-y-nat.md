# Clase 30 — Rutas, gateway y NAT

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** A. Redes

> 💡 **La idea de hoy:** cada máquina tiene una **tabla de rutas** que dice, para cada destino, por dónde enviar el paquete; lo que no está en ninguna red conocida va al **gateway por defecto**. Y como las IPs privadas no existen en internet, el router que te saca fuera hace **NAT**: cambia tu IP de origen por la suya pública. En AWS es lo mismo: una subred es pública si su tabla de rutas lleva a un **Internet Gateway**, y las privadas salen por un **NAT Gateway**.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Dentro de tu red, ARP traduce IP → MAC y se entrega directamente (clase 26, pieza 2).
> - Saber si dos IPs están en la misma subred (clase 27, pieza 5).
> - Rangos privados y `0.0.0.0/0` = cualquier destino (clase 27, pieza 6).
> - Subredes públicas y privadas de una VPC (clase 28, pieza 4).
> - `tcpdump -i <interfaz> -nn icmp` y `ping` (clases 26 y 29).

> 🔤 **Palabras nuevas de hoy:**
> - **tabla de rutas**: la lista de destinos y por dónde se envía cada uno (`ip route`).
> - **gateway por defecto** (`default`): el router al que va todo lo que no tiene una ruta mejor.
> - **prefijo más largo**: la regla que elige la ruta más específica cuando coinciden varias.
> - **salto**: cada router por el que pasa el paquete.
> - **NAT**: cambiar la IP de origen (o de destino) de un paquete al pasar por un router.
> - **Internet Gateway / NAT Gateway**: en AWS, la salida a internet en los dos sentidos / solo hacia fuera.

## Objetivo

- Leer una **tabla de rutas** y predecir por dónde saldrá un paquete (la regla del **prefijo más largo**).
- Entender el **gateway por defecto** y seguir el camino de un paquete con `traceroute`.
- Entender **NAT**: por qué tu VM, tu PC y medio barrio salen a internet con la misma IP pública.
- Traducirlo todo a AWS: tablas de rutas, **Internet Gateway** y **NAT Gateway**.

## Por qué importa

En AWS, lo que hace **pública** una subred no es su nombre: es una ruta `0.0.0.0/0 → Internet Gateway` en su tabla de rutas. Una instancia privada que no puede hacer `apt update` casi siempre tiene un problema de rutas o de NAT. Y el NAT Gateway es de las primeras sorpresas en la factura de AWS. Entender rutas y NAT es entender cómo se mueve el tráfico en una VPC.

## Cómo va esta clase

Cuatro piezas. En cada una lees **una** idea (en la 1, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Necesitas una terminal en tu PC y otra en la VM (`ssh servidor-01`).

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 30 min); el segundo, las **piezas 3 y 4**, el Rómpelo, el reto y el cierre.

En **tu PC**:

```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
ip -br addr show wlo1        # la IP de tu PC en la red de casa (por ejemplo, 192.168.1.7)
```

(Si tu PC va por cable, la interfaz no se llama `wlo1`: mira cuál tiene la ruta `default` en `ip route` y úsala en toda la clase.)

## Las piezas

### Pieza 1 — La tabla de rutas, y la regla del prefijo más largo

Cada máquina tiene una tabla que dice, para cada destino, **por dónde enviar** el paquete. Así es la de tu PC (`ip route`):

```
default via 192.168.1.1 dev wlo1          ← todo lo demás: al router de casa, por el wifi
172.17.0.0/16 dev docker0                 ← la red de Docker: directamente
192.168.1.0/24 dev wlo1                   ← tu red de casa: directamente, sin router
10.x.x.0/24 dev mpqemubr0                 ← la red de Multipass (cuando está activa)
```

- `dev X` sin `via`: el destino está **en la misma red** → se le entrega directamente (ARP + MAC).
- `via 192.168.1.1`: se entrega al **gateway** (un router), que se encarga del resto.
- `default` = `0.0.0.0/0` = "cualquier destino que no tenga una ruta mejor".

Si varias rutas coinciden con el destino, gana la **más específica** (prefijo más largo). Para ir a `192.168.1.50`, coinciden `default` (`/0`) y `192.168.1.0/24`: gana la `/24`. Para ir a `8.8.8.8` solo coincide `default`. `ip route get <IP>` te dice qué ruta usaría el kernel. No hace falta adivinar.

**Pruébalo.** En tu PC:

```bash
ip route
ip route get 8.8.8.8
ip route get 192.168.1.1
ip route get $IP
```

🔮 **Predice:** ¿qué interfaz y qué gateway usará cada uno?

👀 **Qué deberías ver:** `8.8.8.8 via 192.168.1.1 dev wlo1` (va al router); `192.168.1.1 dev wlo1`, sin `via` (está en tu red); y la VM por `dev mpqemubr0`, también sin `via`.

En la VM (`ssh servidor-01`):

```bash
ip route
ip route get 8.8.8.8
```

👀 **Qué deberías ver:** `default via 10.x.x.1`: el gateway de la VM es una IP que **es tu PC** (la `.1` de la red de Multipass). Compruébalo en tu PC con `ip -br addr show mpqemubr0`.

✋ **Sin mirar:** para ir a `192.168.1.50` coinciden `default` y `192.168.1.0/24`. ¿Cuál gana y por qué?

<details>
<summary>Comprueba</summary>

La `/24`: es más específica (prefijo más largo) que `default`, que es `/0`.
</details>

**En resumen:** lo de tu red va directo (`dev`), lo demás al gateway (`via`), y si coinciden varias rutas gana la de prefijo más largo.

### Pieza 2 — El viaje fuera de tu red: los saltos

```
 VM 10.x.x.5 ──► tu PC (router de la VM) ──► router de casa 192.168.1.1 ──► operador ──► … ──► 8.8.8.8
              salto 1                     salto 2                       salto 3…
```

Cada router solo decide el **siguiente salto**. `traceroute` o `tracepath` muestran cada salto.

**Pruébalo.** En la VM:

```bash
traceroute -n -m 8 8.8.8.8        # instalado en la clase 10
```

👀 **Qué deberías ver:** salto 1 = tu PC (`10.x.x.1`), salto 2 = tu router de casa (`192.168.1.1`), y después tu operador. Algunos saltos muestran `* * *`: no responden a traceroute, pero dejan pasar el tráfico.

**En resumen:** cada router decide solo el siguiente salto; `traceroute -n` los enseña uno por uno.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 3 — NAT: traducir direcciones

Las IPs privadas (`10.x`, `192.168.x`) **no existen en internet**. Para salir, un router **reemplaza la IP de origen** por la suya pública y recuerda la conversión para devolver las respuestas:

```
 VM 10.x.x.5:40000 ─► [NAT en tu PC] ─► 192.168.1.7:40000 ─► [NAT en el router de casa] ─► IP_PÚBLICA:40000 ─► internet
                       cambia origen                         cambia origen otra vez
 ◄── la respuesta deshace el camino, traducción a traducción ──────────────────────────────────────────────┘
```

- **SNAT / masquerade**: muchas máquinas privadas salen con una sola IP pública. Las conexiones solo se pueden **iniciar desde dentro**: desde internet no se puede llegar a la VM.
- **DNAT / port forwarding**: "lo que llegue al puerto 8080 de mi IP pública, mándalo a 10.x.x.5:80". Así se publican servicios internos.

**Pruébalo, primero tu IP pública vista desde fuera:**

```bash
curl -s https://checkip.amazonaws.com          # en tu PC
ssh servidor-01 curl -s https://checkip.amazonaws.com
```

🔮 **Predice:** ¿será la misma IP en ambos casos?

👀 **Qué deberías ver:** la **misma** IP pública dos veces: la VM sale a través de **dos** NATs (tu PC y tu router). Esa IP no aparece en ninguna interfaz de tu PC (`ip -br addr`): la tiene tu router.

**Ahora, la traducción en directo.** En tu PC, en dos terminales, captura el **mismo** tráfico a ambos lados:

```bash
sudo tcpdump -i mpqemubr0 -nn icmp       # lado de la VM
sudo tcpdump -i wlo1 -nn icmp            # lado del wifi
```

En la VM: `ping -c 3 8.8.8.8`.

👀 **Qué deberías ver:** en `mpqemubr0`, el origen es la IP de la VM (`10.x.x.5 > 8.8.8.8`); en `wlo1`, el origen es **la IP de tu PC** (`192.168.1.7 > 8.8.8.8`). Acabas de ver el NAT reescribiendo paquetes.

La regla está en el firewall de tu PC:

```bash
sudo nft list ruleset 2>/dev/null | grep -i -B2 -A2 masquerade | head -20
sudo iptables -t nat -S 2>/dev/null | grep -i masquerade      # si lo anterior no muestra nada
```

👀 **Qué deberías ver:** una regla con `masquerade` para la red de Multipass (`10.x.x.0/24`).

✋ **Sin mirar:** tu VM sale a internet por NAT. ¿Puede alguien de internet abrir una conexión hacia ella?

<details>
<summary>Comprueba</summary>

No: el NAT solo traduce conexiones **iniciadas desde dentro**. Para entrar haría falta un DNAT (*port forwarding*) explícito.
</details>

**En resumen:** al salir, el NAT cambia tu IP privada por la del router; las respuestas vuelven, pero nadie de fuera puede iniciar una conexión.

### Pieza 4 — Lo mismo en AWS: route tables, Internet Gateway y NAT Gateway

| Pieza de AWS | Equivale a |
|--------------|-----------|
| **Route table** | la tabla de `ip route`, asociada a una subred |
| Ruta `local` (p. ej. `10.0.0.0/16 → local`) | "toda la VPC se ve entre sí". Viene por defecto y no se puede quitar |
| **Internet Gateway (IGW)** | la salida a internet. Hace NAT **1:1** entre la IP privada de la instancia y su IP pública. En los dos sentidos |
| **Subred pública** | tabla con `0.0.0.0/0 → igw-…` |
| **NAT Gateway** | SNAT: las instancias **privadas** salen a internet (para `apt update`, por ejemplo), pero nadie entra. Vive en una subred **pública** |
| **Subred privada** | tabla con `0.0.0.0/0 → nat-…`, o sin ruta por defecto |

```
                Internet
                    │
             [Internet Gateway]
                    │
 ┌──────────── VPC 10.0.0.0/16 ─────────────┐
 │ Subred pública 10.0.0.0/24               │  tabla: 10.0.0.0/16→local · 0.0.0.0/0→IGW
 │   [ALB]   [NAT Gateway]                  │
 │                 ▲                         │
 │ Subred privada 10.0.10.0/24               │  tabla: 10.0.0.0/16→local · 0.0.0.0/0→NAT
 │   [EC2 app] ────┘ (sale, nadie entra)     │
 └───────────────────────────────────────────┘
```

> 💸 Un NAT Gateway cuesta **por hora** y **por GB procesado**, aunque no lo uses. Es el gasto sorpresa número uno en cuentas de aprendizaje. Se crea, se prueba y se destruye el mismo día.

Tu laboratorio ya funciona así: la VM es una instancia en una subred **privada**, y tu PC hace de su **NAT Gateway**.

**Pruébalo, en papel.** Clasifica estas tres tablas de rutas como subred **pública**, **privada con salida** o **aislada**:

```
A:  10.0.0.0/16 → local
B:  10.0.0.0/16 → local   ·   0.0.0.0/0 → igw-1a2b
C:  10.0.0.0/16 → local   ·   0.0.0.0/0 → nat-9f8e
```

<details>
<summary>Comprueba</summary>

**A**: aislada (solo habla con la VPC: ni sale ni entra nadie). **B**: pública (ruta por defecto al Internet Gateway). **C**: privada con salida (sale por el NAT Gateway, pero nadie entra).
</details>

**En resumen:** en AWS, una subred es pública si su ruta `0.0.0.0/0` va al Internet Gateway; las privadas salen por un NAT Gateway, que cuesta aunque no lo uses.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `ip route` | la tabla de rutas |
| `ip route get IP` | qué ruta usaría el kernel para ese destino |
| `traceroute -n -m 8 IP` · `tracepath IP` | los saltos hasta un destino |
| `curl -s https://checkip.amazonaws.com` | tu IP pública, vista desde fuera |
| `sudo tcpdump -i INTERFAZ -nn icmp` | los `ping` que pasan por una interfaz |
| `sudo nft list ruleset \| grep -i masquerade` | la regla de NAT de tu PC |
| `sudo ip route del default` · `sudo ip route add default via GW` | quitar / poner la ruta por defecto (temporal) |
| `sudo ip route add blackhole IP/32` | descartar el tráfico hacia una IP |

| En AWS | Ruta `0.0.0.0/0` hacia… |
|--------|-------------------------|
| subred pública | `igw-…` (Internet Gateway) |
| subred privada con salida | `nat-…` (NAT Gateway, en una subred pública) |
| subred aislada | ninguna |

## Rómpelo

Snapshot primero (desde tu PC): `multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-rutas && multipass start servidor-01`.

**1. Sin ruta por defecto.** En la VM:
```bash
ip route
GW=$(ip route | awk '/default/ {print $3; exit}'); echo "gateway: $GW"
sudo ip route del default
ip route
```

🔮 **Predice** antes de cada comando:
```bash
ping -c 2 -W 2 8.8.8.8
ping -c 2 -W 2 $GW
curl -s -m 5 https://checkip.amazonaws.com || echo "sin internet"
```

Internet: `Network is unreachable` (sin ruta). Tu PC: **sigue respondiendo**, porque está en la misma red (ruta `dev` directa). Y tu sesión SSH **sigue viva** por lo mismo. Es exactamente una **subred privada sin NAT** en AWS: la instancia habla con la VPC, pero no con internet. Restaura:
```bash
sudo ip route add default via $GW
ping -c 2 8.8.8.8
```
(Los cambios con `ip route` son temporales: un reinicio los restaura a partir de la configuración de netplan en `/etc/netplan/`.)

**2. Una ruta más específica gana.** En la VM:
```bash
sudo ip route add blackhole 1.1.1.1/32
ip route get 1.1.1.1
ping -c 2 -W 2 1.1.1.1
ping -c 2 -W 2 1.0.0.1
sudo ip route del blackhole 1.1.1.1/32
```
La `/32` gana a `default` (`/0`) solo para esa IP. Una ruta demasiado amplia o mal puesta en una tabla de AWS puede desviar tráfico de esta forma.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Con `ip route get`, explica por qué un paquete de tu PC a `172.17.0.5` iría por `docker0` y uno a `172.18.0.5` por el wifi.

> 🧩 **Ejemplo resuelto:** `ip route get 192.168.1.50` → `dev wlo1`, sin `via`: cae en la ruta `192.168.1.0/24`, que es más específica que `default`.

**Ahora tú, con huecos:** `ip route get 172.17.0.5` → cae en la ruta `____`, así que sale por `____`. `ip route get 172.18.0.5` → no cae en ninguna ruta específica, así que usa `____` y sale por `____`.

<details>
<summary>Pista</summary>

Mira tu `ip route`: ¿qué rango cubre la ruta de `docker0`? ¿Entra en él `172.18.x.x`?
</details>

**2.** Una instancia EC2 está en una subred cuya tabla tiene solo `10.0.0.0/16 → local`. Le asignas una IP pública. ¿Puedes entrar por SSH desde tu casa?

> 🧩 **Ejemplo resuelto:** en el Rómpelo 1 quitaste la ruta `default` de la VM: seguía hablando con tu PC (misma red), pero no con internet.

**Ahora tú, con huecos:** ____, porque la subred no tiene ruta `____` hacia un ____. Aunque tu paquete llegara, la respuesta no tendría ____ hacia tu casa.

<details>
<summary>Pista</summary>

Es la tabla **A** de la pieza 4. ¿Qué tipo de subred era?
</details>

**3.** Una instancia privada (con ruta `0.0.0.0/0 → NAT Gateway`) puede hacer `apt update`. ¿Puede alguien de internet conectar a su puerto 22?

> 🧩 **Ejemplo resuelto:** desde internet nadie puede abrir una conexión hacia tu VM, aunque ella salga a internet por el NAT de tu PC (pieza 3).

**Ahora tú, con huecos:** ____, porque el NAT Gateway solo traduce conexiones iniciadas desde ____.

<details>
<summary>Pista</summary>

Es la tabla **C** de la pieza 4, y la última frase de la definición de NAT Gateway.
</details>

**4.** Escribe el camino de un paquete desde la VM hasta `8.8.8.8`, con la IP de origen que lleva en cada tramo.

> 🧩 **Ejemplo resuelto:** el primer tramo.
> ```
> VM → tu PC:           origen 10.x.x.5
> ```

**Ahora tú, con huecos**, en tus notas:
```
VM → tu PC:            origen 10.x.x.5
tu PC → router:        origen ____          (lo viste en wlo1)
router → internet:     origen ____          (la de checkip)
```

<details>
<summary>Pista</summary>

Cada NAT cambia el origen por su propia IP en la red de salida. Los dos datos los sacaste en la pieza 3.
</details>

## Cierre

En `notas/fase-3/clase-30.md`:

1. ¿Qué es el gateway por defecto y cuándo se usa? *(2 líneas. Empieza así: «Es el router al que se envían los paquetes cuyo destino no… En casa es…; en la VM,…»)*
2. Explica la regla del prefijo más largo con un ejemplo de tu propia tabla de rutas. *(2 líneas. Empieza así: «Si coinciden varias rutas, gana… Por ejemplo, para ir a `192.168.1.50`…»)*
3. ¿Qué diferencia hay entre un Internet Gateway y un NAT Gateway? ¿Qué hace "pública" a una subred en AWS? *(3 líneas. Empieza así: «El Internet Gateway conecta… en los dos sentidos… El NAT Gateway deja que… pero… Una subred es pública cuando su tabla…»)*
4. **Repaso (clase 29, sin mirar):** ¿qué diferencia hay entre escuchar en `127.0.0.1` y en `0.0.0.0`? *(2 líneas. Empieza así: «En `127.0.0.1` solo aceptan conexiones de… En `0.0.0.0`…»)*

Después, escríbeme `examíname clase-30`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El router al que se envían los paquetes cuyo destino **no** coincide con ninguna ruta más específica: lo que no está en tus redes directas. En casa es el router; en la VM, tu PC; en AWS, el router de la VPC, que reenvía según la tabla de rutas de la subred.

**2.** Si varias rutas coinciden, gana la de prefijo más largo. En tu PC, `192.168.1.50` coincide con `default` (`/0`) y con `192.168.1.0/24`: gana la `/24` y se entrega directamente por el wifi, sin pasar por el router. `8.8.8.8` solo coincide con `default`: va a `192.168.1.1`.

**3.** El **Internet Gateway** conecta la VPC con internet en **ambos sentidos**: traduce 1:1 la IP privada a la pública de cada instancia. El **NAT Gateway** permite que instancias **sin IP pública** inicien conexiones hacia internet, pero nadie de fuera puede iniciar conexiones hacia ellas. Una subred es "pública" cuando su tabla de rutas tiene `0.0.0.0/0 → Internet Gateway`.

**4.** `127.0.0.1`: solo aceptan conexiones de la propia máquina. `0.0.0.0`: por cualquier interfaz, incluidas las de red, así que otras máquinas pueden conectar (si el firewall lo permite).

**Reto:** 1) `172.17.0.0/16`, sale por `docker0`; `172.18.0.5` no cae en esa ruta, así que usa `default` y sale por `wlo1`. 2) **No**, porque la subred no tiene ruta `0.0.0.0/0` hacia un **Internet Gateway**; la respuesta no tendría **ruta** hacia tu casa. 3) **No**, porque el NAT solo traduce conexiones **iniciadas desde dentro**: desde fuera no existe ninguna traducción hacia esa instancia. 4) Tu PC → router: origen, la IP de tu PC (por ejemplo `192.168.1.7`); router → internet: origen, tu IP pública (la de `checkip.amazonaws.com`).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| routing table | tabla de rutas |
| default gateway / default route | puerta de enlace / ruta por defecto |
| longest prefix match | coincidencia del prefijo más largo |
| next hop | siguiente salto |
| NAT (Network Address Translation) | traducción de direcciones |
| Internet Gateway / NAT Gateway | (AWS) |

🎙️ *"What makes a subnet public in AWS is its route table: a 0.0.0.0/0 route pointing to an Internet Gateway. Private subnets reach the internet through a NAT Gateway, so they can go out but nobody can come in."*

## Siguiente

[Clase 31 — DNS](clase-31-dns.md)
