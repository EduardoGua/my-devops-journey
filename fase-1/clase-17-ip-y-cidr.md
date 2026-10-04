# Clase 17 — Direcciones IP y CIDR

**Dónde:** papel y lápiz + tu PC + VM · **Tiempo:** 90 min · **Bloque:** C. Redes

> Esta es probablemente **la clase más importante del bloque de redes**. Hazla con papel. No avances hasta poder calcular una subred sin herramientas.

## Objetivo

- Leer una dirección IPv4 **en binario** y entender qué parte es red y qué parte es máquina.
- Dominar la notación **CIDR** (`10.0.1.0/24`): dirección de red, broadcast, rango útil y número de hosts.
- Saber si dos IPs están **en la misma subred**.
- Conocer los rangos **privados** y las direcciones especiales que verás en AWS.

## Por qué importa

Al crear una VPC en AWS, lo primero que te pide es un bloque CIDR (`10.0.0.0/16`). Después, cada subred (`10.0.1.0/24`), cada regla de security group (`0.0.0.0/0`, `203.0.113.5/32`) y cada tabla de rutas está escrita en CIDR. Si no lo dominas, crearás subredes que se solapan, reglas que abren más de lo que crees o VPCs que no podrás conectar entre sí. Es también una pregunta clásica de entrevista.

## Teoría

### Una IPv4 son 32 bits

```
   192   .   168   .    1    .   130
11000000 . 10101000 . 00000001 . 10000010
└──8──┘    └──8──┘    └──8──┘    └──8──┘   = 32 bits, 4 octetos (cada uno de 0 a 255)
```

**Pasar un octeto a binario.** Cada posición vale:

```
 128  64  32  16   8   4   2   1
```

130 = 128 + 2 → `10000010`. 168 = 128 + 32 + 8 → `10101000`. 255 = todos a 1 → `11111111`.

Método: de izquierda a derecha, si el valor cabe, pon 1 y réstalo; si no, pon 0.

### Red y host

Una IP tiene dos partes: la **red** (qué subred es) y el **host** (qué máquina dentro de ella). El **prefijo** CIDR (`/24`) dice **cuántos bits, desde la izquierda, son de red**.

```
192.168.1.130/24
11000000.10101000.00000001 . 10000010
└───────── 24 bits de RED ──┘ └ 8 bits HOST ┘
```

La **máscara** es lo mismo escrito como IP: 24 unos y después ceros → `255.255.255.0`.

### Las tres cifras que se calculan siempre

Con `n` bits de host (`n = 32 - prefijo`):
- **Direcciones totales** = 2ⁿ
- **Dirección de red**: todos los bits de host a 0. Es la primera y **no se asigna a máquinas**.
- **Broadcast**: todos los bits de host a 1. Es la última y **no se asigna**.
- **Hosts útiles** = 2ⁿ − 2 (en una red normal)

> **En AWS** se reservan **5** direcciones por subred: la de red, `.1` (router de la VPC), `.2` (DNS), `.3` (reservada) y el broadcast. Una `/24` en AWS tiene **251** IPs útiles, no 254.

### La tabla que conviene memorizar

| Prefijo | Máscara | Direcciones | Uso típico |
|---------|---------|-------------|------------|
| `/32` | 255.255.255.255 | 1 | **una sola IP** (p. ej. "solo mi IP" en un security group) |
| `/28` | 255.255.255.240 | 16 | la subred más pequeña que permite AWS |
| `/27` | 255.255.255.224 | 32 | |
| `/26` | 255.255.255.192 | 64 | |
| `/25` | 255.255.255.128 | 128 | |
| `/24` | 255.255.255.0 | 256 | una subred típica |
| `/20` | 255.255.240.0 | 4.096 | subred por defecto de AWS |
| `/16` | 255.255.0.0 | 65.536 | una VPC típica (el máximo en AWS) |
| `/8` | 255.0.0.0 | 16.777.216 | todo `10.x.x.x` |
| `/0` | 0.0.0.0 | todas | **cualquier IP** (`0.0.0.0/0`) |

Truco: cada bit menos de prefijo **duplica** el tamaño. `/24` = 256, `/23` = 512, `/25` = 128.

### El método rápido: el tamaño de bloque

Para prefijos que no son múltiplo de 8, trabaja **solo con el octeto donde se corta**:

1. Mira en qué octeto cae el corte (`/26` → el 4.º; `/20` → el 3.º).
2. **Tamaño de bloque** = 256 − valor de la máscara en ese octeto. `/26` → máscara `.192` → bloque 64.
3. Las redes empiezan en múltiplos del bloque: 0, 64, 128, 192…
4. Tu IP cae en uno de esos bloques: ahí tienes la red. El broadcast es el siguiente inicio de bloque menos 1.

**Ejemplo:** `192.168.1.130/26`
- Bloque = 256 − 192 = **64** → redes en .0, .64, .128, .192
- 130 está entre 128 y 191 → **red `192.168.1.128`**, **broadcast `192.168.1.191`**
- Hosts: `.129` a `.190` → **62** útiles

**Ejemplo con el corte en el 3.er octeto:** `172.16.40.10/20`
- `/20` = 8 + 8 + **4** → el corte está en el 3.er octeto, máscara `255.255.240.0`
- Bloque = 256 − 240 = **16** → redes en .0, .16, .32, .48…
- 40 está entre 32 y 47 → **red `172.16.32.0`**, **broadcast `172.16.47.255`**
- Hosts: 2¹² − 2 = **4.094**

### ¿Misma subred?

Dos IPs están en la misma subred si su **parte de red** es idéntica. Con el método del bloque: si caen en el **mismo bloque**. `192.168.10.5/25` y `192.168.10.130/25`: los bloques son 0–127 y 128–255, así que **no** están en la misma subred, y para hablar necesitan un router.

### Rangos privados (RFC 1918)

No se enrutan por internet. Se usan dentro de casas, empresas y **VPCs**:

| Rango | CIDR |
|-------|------|
| `10.0.0.0` – `10.255.255.255` | `10.0.0.0/8` |
| `172.16.0.0` – `172.31.255.255` | `172.16.0.0/12` ⚠️ no todo `172.x` |
| `192.168.0.0` – `192.168.255.255` | `192.168.0.0/16` |

### Direcciones especiales

| Dirección | Significado |
|-----------|-------------|
| `127.0.0.1` (`127.0.0.0/8`) | *loopback*: la propia máquina |
| `0.0.0.0` | en un servidor: "escucho en todas las interfaces". En una regla o ruta (`0.0.0.0/0`): "cualquier destino u origen" |
| `169.254.0.0/16` | *link-local*. En AWS, `169.254.169.254` es el **servicio de metadatos** de cada instancia |
| `100.64.0.0/10` | CGNAT: la IP "privada" que te da a veces tu operador |

### IPv6 en una línea

128 bits en hexadecimal (`2001:db8::1`). Hay tantas direcciones que no hace falta NAT. AWS lo soporta. En este curso nos centramos en IPv4, pero un `::/0` en un security group significa "cualquier IPv6": revísalo igual que `0.0.0.0/0`.

## Práctica guiada

### 1. Binario a mano

Convierte **en papel** y comprueba después:

| Decimal | Tu respuesta |
|---------|--------------|
| 10 | |
| 172 | |
| 192 | |
| 224 | |
| 240 | |
| 248 | |
| 77 | |

Comprobación en tu PC:
```bash
for n in 10 172 192 224 240 248 77; do python3 -c "print($n, format($n, '08b'))"; done
```

### 2. Tus redes reales

En tu PC y en la VM:
```bash
ip -br addr
```

Para cada IP con prefijo (`10.x.x.x/24`, `192.168.1.x/24`…), calcula en papel: red, broadcast, número de hosts. ¿Tu PC y la VM están en la misma subred en la red de Multipass?

### 3. La calculadora (para comprobar, no para pensar)

En la VM:
```bash
sudo apt install -y ipcalc
ipcalc 192.168.1.130/26
ipcalc 172.16.40.10/20
```

En tu PC, con Python:
```bash
python3 -c "import ipaddress as i; n=i.ip_interface('192.168.1.130/26').network; print(n, n.broadcast_address, n.num_addresses-2)"
```

### 4. Metadatos de una instancia

Cuando estés en AWS (fase 5), dentro de una EC2:
```bash
curl http://169.254.169.254/latest/meta-data/      # (requiere token con IMDSv2)
```
La instancia aprende de ahí su IP, su región y **sus credenciales temporales**. Por eso un fallo que permita a un atacante hacer peticiones desde tu servidor (SSRF) contra esa IP es tan grave. Recuerda este número.

## Rómpelo: ejercicios de papel

Resuelve **sin calculadora**. Después comprueba con `ipcalc` o Python. Escribe cada resultado en tus notas.

| # | Pregunta |
|---|----------|
| 1 | `10.0.5.77/24`: red, broadcast y hosts útiles |
| 2 | `192.168.1.130/26`: red, broadcast, primer y último host |
| 3 | `10.0.0.200/28`: red, broadcast y hosts útiles |
| 4 | `10.20.30.40/27`: red y broadcast |
| 5 | `172.16.40.10/20`: red, broadcast y hosts útiles |
| 6 | `10.0.130.9/17`: red y broadcast |
| 7 | ¿`192.168.10.5/25` y `192.168.10.130/25` están en la misma subred? |
| 8 | ¿`172.32.0.5` es privada? ¿Y `172.20.0.5`? |
| 9 | ¿Cuántas IPs útiles tiene una subred `/24` **en AWS**? ¿Y una `/28`? |
| 10 | ¿`10.1.0.5` pertenece a `10.0.0.0/16`? |
| 11 | ¿Cuántas subredes `/24` caben en una `/16`? |
| 12 | Una regla de entrada dice `22/TCP desde 0.0.0.0/0`. ¿Qué significa? ¿Cómo la escribirías para permitir solo tu IP `203.0.113.25`? |

## Reto

1. Un compañero propone VPC `10.0.0.0/16` con subredes `10.0.0.0/24` y `10.0.0.128/25`. ¿Qué problema hay?
2. ¿Cuál es el CIDR más pequeño que contiene `10.0.0.0` y `10.0.3.255` a la vez?
3. Necesitas una subred para 500 máquinas en AWS. ¿Qué prefijo mínimo usarías? Recuerda las 5 reservadas.

## Cierre

En `notas/fase-1/clase-17.md`:

1. Explica con tus palabras qué significa el `/24` de `10.0.1.0/24`. ¿Qué parte es fija y qué parte varía?
2. Describe paso a paso el método del tamaño de bloque con `10.0.0.200/28`.
3. ¿Por qué `0.0.0.0/0` en un security group es peligroso en el puerto 22, pero normal en el 443 de una web pública?
4. **Repaso (clase 16, sin mirar):** ¿qué significa `Connection refused` frente a un `timeout`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Binario:** 10 = `00001010` · 172 = `10101100` · 192 = `11000000` · 224 = `11100000` · 240 = `11110000` · 248 = `11111000` · 77 = `01001101`.

**Ejercicios:**
1. Red `10.0.5.0`, broadcast `10.0.5.255`, 254 hosts.
2. Red `192.168.1.128`, broadcast `.191`, hosts `.129`–`.190` (62).
3. Bloque 16: red `10.0.0.192`, broadcast `10.0.0.207`, 14 hosts.
4. Bloque 32: red `10.20.30.32`, broadcast `10.20.30.63`.
5. Red `172.16.32.0`, broadcast `172.16.47.255`, 4.094 hosts.
6. `/17`: corte en el 3.er octeto, máscara 128, bloque 128. 130 cae en 128–255: red `10.0.128.0`, broadcast `10.0.255.255`.
7. **No**: una cae en 0–127 y la otra en 128–255.
8. `172.32.0.5` **no** es privada (el rango privado es 172.16–172.31). `172.20.0.5` **sí**.
9. `/24` en AWS: 256 − 5 = **251**. `/28`: 16 − 5 = **11**.
10. **No**: `10.0.0.0/16` va de `10.0.0.0` a `10.0.255.255`.
11. 2⁸ = **256**.
12. "SSH abierto a **cualquier IP de internet**". Solo tu IP: `203.0.113.25/32`.

**Cierre:**
1. Los primeros 24 bits (`10.0.1`) son la **red** y son fijos para toda la subred. Los 8 últimos son el **host** y varían de `.0` a `.255`: 256 direcciones, 254 asignables (251 en AWS).
2. `/28` → corte en el 4.º octeto, máscara 240 → bloque 256 − 240 = 16 → redes en 0, 16, 32… 192, 208… → 200 cae en 192–207 → red `.192`, broadcast `.207`, hosts `.193`–`.206`.
3. `0.0.0.0/0` = todo internet. En el 22 expone el acceso **administrativo** a bots y fuerza bruta: debe limitarse a tu IP, a una VPN o a un bastión (o usar SSM y no abrir el 22). En el 443 de una web pública, que te visite todo internet **es el objetivo**.
4. **Refused**: llegaste a la máquina, pero nadie escucha en ese puerto (respondió con RST). **Timeout**: no hubo respuesta: firewall o security group que descarta, sin ruta o máquina apagada.

**Reto:** 1) Se **solapan**: `10.0.0.0/24` ya incluye `10.0.0.128`–`10.0.0.255`. 2) `10.0.0.0/22` (4 × 256 = 1.024 direcciones: de `10.0.0.0` a `10.0.3.255`). 3) `/23` = 512 − 5 = 507 ≥ 500 ✅ (`/24` = 251 no alcanza).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| subnet mask | máscara de subred |
| CIDR block | bloque CIDR |
| network / broadcast address | dirección de red / de difusión |
| private address range | rango de direcciones privadas |
| overlapping CIDRs | rangos solapados |

🎙️ *"A /24 has 256 addresses, but in AWS only 251 are usable because AWS reserves five in every subnet."*

## Siguiente

[Clase 18 — Subnetting: diseñar redes como en una VPC](clase-18-subnetting.md)
