# Clase 20 — Rutas, gateway y NAT

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** C. Redes

## Objetivo

- Leer una **tabla de rutas** y predecir por dónde saldrá un paquete (la regla del **prefijo más largo**).
- Entender el **gateway por defecto** y seguir el camino de un paquete con `traceroute`.
- Entender **NAT**: por qué tu VM, tu PC y medio barrio salen a internet con la misma IP pública.
- Traducirlo todo a AWS: tablas de rutas, **Internet Gateway** y **NAT Gateway**.

## Por qué importa

En AWS, lo que hace **pública** una subred no es su nombre: es una ruta `0.0.0.0/0 → Internet Gateway` en su tabla de rutas. Una instancia privada que no puede hacer `apt update` casi siempre tiene un problema de rutas o de NAT. Y el NAT Gateway es de las primeras sorpresas en la factura de AWS. Entender rutas y NAT es entender cómo se mueve el tráfico en una VPC.

## Teoría

### La tabla de rutas

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

### La regla de oro: gana el prefijo más largo

Si varias rutas coinciden con el destino, gana la **más específica** (prefijo más largo). Para ir a `192.168.1.50`, coinciden `default` (`/0`) y `192.168.1.0/24`: gana la `/24`. Para ir a `8.8.8.8` solo coincide `default`.

`ip route get <IP>` te dice qué ruta usaría el kernel. No hace falta adivinar.

### El viaje fuera de tu red

```
 VM 10.x.x.5 ──► tu PC (router de la VM) ──► router de casa 192.168.1.1 ──► operador ──► … ──► 8.8.8.8
              salto 1                     salto 2                       salto 3…
```

Cada router solo decide el **siguiente salto**. `traceroute` o `tracepath` muestran cada salto.

### NAT: traducir direcciones

Las IPs privadas (`10.x`, `192.168.x`) **no existen en internet**. Para salir, un router **reemplaza la IP de origen** por la suya pública y recuerda la conversión para devolver las respuestas:

```
 VM 10.x.x.5:40000 ─► [NAT en tu PC] ─► 192.168.1.13:40000 ─► [NAT en el router de casa] ─► IP_PÚBLICA:40000 ─► internet
                       cambia origen                          cambia origen otra vez
 ◄── la respuesta deshace el camino, traducción a traducción ───────────────────────────────────────────────┘
```

- **SNAT / masquerade**: muchas máquinas privadas salen con una sola IP pública. Las conexiones solo se pueden **iniciar desde dentro**: desde internet no se puede llegar a la VM.
- **DNAT / port forwarding**: "lo que llegue al puerto 8080 de mi IP pública, mándalo a 10.x.x.5:80". Así se publican servicios internos.

Por eso tu VM, tu PC y tu móvil salen a internet con **la misma IP pública**.

### En AWS

| Pieza de AWS | Equivale a |
|--------------|-----------|
| **Route table** | la tabla de `ip route`, asociada a una subred |
| Ruta `local` (p. ej. `10.0.0.0/16 → local`) | "toda la VPC se ve entre sí". Viene por defecto y no se puede quitar |
| **Internet Gateway (IGW)** | la puerta a internet. Hace NAT **1:1** entre la IP privada de la instancia y su IP pública. En los dos sentidos |
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

## Práctica guiada

### 1. Las tablas de tu PC y de la VM

En tu PC:
```bash
ip route
ip route get 8.8.8.8
ip route get 192.168.1.1
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
ip route get $IP
```

🔮 **Predice:** ¿qué interfaz y qué gateway usará cada uno?

En la VM (`ssh servidor-01`):
```bash
ip route
ip route get 8.8.8.8
```

La VM tiene como gateway una IP que **es tu PC** (normalmente la `.1` de la red de Multipass). Compruébalo en tu PC con `ip -br addr show mpqemubr0`.

### 2. El camino de los paquetes

En la VM:
```bash
traceroute -n -m 8 8.8.8.8        # instalado en la clase 10
```

Identifica: salto 1 = tu PC, salto 2 = tu router de casa (`192.168.1.1`), después tu operador. Algunos saltos muestran `* * *`: no responden a traceroute, pero dejan pasar el tráfico.

### 3. NAT en acción

Tu IP pública, vista desde fuera:
```bash
curl -s https://checkip.amazonaws.com          # en tu PC
ssh servidor-01 curl -s https://checkip.amazonaws.com
```

🔮 **Predice:** ¿será la misma IP en ambos casos?

La misma: la VM sale a través de **dos** NATs (tu PC y tu router). La IP pública **no** aparece en ninguna interfaz de tu PC (`ip -br addr`): la tiene tu router.

### 4. Ver la traducción

En tu PC, en dos terminales, captura el **mismo** tráfico a ambos lados de tu PC:
```bash
sudo tcpdump -i mpqemubr0 -nn icmp       # lado de la VM
sudo tcpdump -i wlo1 -nn icmp            # lado del wifi
```
En la VM: `ping -c 3 8.8.8.8`.

En `mpqemubr0` el origen es la IP de la VM (`10.x.x.x`). En `wlo1` el origen es **`192.168.1.13`**, la de tu PC. Acabas de ver el NAT reescribiendo paquetes. La regla está en el firewall de tu PC:
```bash
sudo nft list ruleset 2>/dev/null | grep -i -B2 -A2 masquerade | head -20
sudo iptables -t nat -S 2>/dev/null | grep -i masquerade      # si lo anterior no muestra nada
```

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

1. Con `ip route get`, explica por qué un paquete de tu PC a `172.17.0.5` iría por `docker0` y uno a `172.18.0.5` por el wifi.
2. Una instancia EC2 está en una subred cuya tabla tiene solo `10.0.0.0/16 → local`. Le asignas una IP pública. ¿Puedes entrar por SSH desde tu casa? ¿Por qué?
3. Una instancia privada (con ruta `0.0.0.0/0 → NAT Gateway`) puede hacer `apt update`. ¿Puede alguien de internet conectar a su puerto 22? ¿Por qué?
4. Dibuja en tus notas el camino completo de un paquete desde la VM hasta `8.8.8.8`, indicando en cada salto qué IP de origen lleva.

## Cierre

En `notas/fase-1/clase-20.md`:

1. ¿Qué es el gateway por defecto y cuándo se usa?
2. Explica la regla del prefijo más largo con un ejemplo de tu propia tabla de rutas.
3. ¿Qué diferencia hay entre un Internet Gateway y un NAT Gateway? ¿Qué hace "pública" a una subred en AWS?
4. **Repaso (clase 19, sin mirar):** ¿qué diferencia hay entre escuchar en `127.0.0.1` y en `0.0.0.0`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El router al que se envían los paquetes cuyo destino **no** coincide con ninguna ruta más específica: lo que no está en tus redes directas. En casa es el router; en la VM, tu PC; en AWS, el router de la VPC, que reenvía según la tabla de rutas de la subred.

**2.** Si varias rutas coinciden, gana la de prefijo más largo. En tu PC, `192.168.1.50` coincide con `default` (`/0`) y con `192.168.1.0/24`: gana la `/24` y se entrega directamente por el wifi, sin pasar por el router. `8.8.8.8` solo coincide con `default`: va a `192.168.1.1`.

**3.** El **Internet Gateway** conecta la VPC con internet en **ambos sentidos**: traduce 1:1 la IP privada a la pública de cada instancia. El **NAT Gateway** permite que instancias **sin IP pública** inicien conexiones hacia internet, pero nadie de fuera puede iniciar conexiones hacia ellas. Una subred es "pública" cuando su tabla de rutas tiene `0.0.0.0/0 → Internet Gateway`.

**4.** `127.0.0.1`: solo aceptan conexiones de la propia máquina. `0.0.0.0`: por cualquier interfaz, incluidas las de red, así que otras máquinas pueden conectar (si el firewall lo permite).

**Reto:** 1) `172.17.0.5` cae en `172.17.0.0/16` (docker0). `172.18.0.5` no cae en ninguna ruta específica, así que usa `default`. 2) **No**: aunque tenga IP pública, la subred no tiene ruta a un Internet Gateway; las respuestas no tienen por dónde salir. 3) **No**: el NAT solo traduce conexiones **iniciadas desde dentro**. Desde fuera no existe ninguna ruta ni traducción hacia esa instancia.
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

[Clase 21 — DNS](clase-21-dns.md)
