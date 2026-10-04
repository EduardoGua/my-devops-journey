# Clase 18 — Subnetting: diseñar redes como en una VPC

**Dónde:** papel + tu PC (Python para comprobar) · **Tiempo:** 90 min · **Bloque:** C. Redes

## Objetivo

- **Dividir** un bloque CIDR en subredes iguales sin solapes.
- Diseñar el direccionamiento de una **VPC de AWS real**: subredes públicas, privadas y de base de datos en varias zonas de disponibilidad, con margen para crecer.
- Detectar **solapamientos** y entender por qué impiden conectar redes.
- Dejar escrito tu primer **documento de diseño de red**, que reutilizarás en el proyecto P6.

## Por qué importa

Una VPC mal planificada no se arregla fácilmente: el CIDR principal no se puede cambiar, y las subredes no se redimensionan. Si dos VPCs (o tu VPC y la red de la oficina) usan rangos solapados, **no podrás conectarlas** por peering, VPN o Transit Gateway. Planificar las IPs es de las primeras tareas de un ingeniero cloud, y "diseña la red para esta aplicación" es una pregunta habitual de entrevista.

## Teoría

### Dividir es "pedir prestados" bits

Si alargas el prefijo, divides la red. Cada bit que añades **duplica el número de subredes** y **reduce a la mitad** su tamaño.

```
10.0.0.0/24  (256)
├── 10.0.0.0/25    (128)          +1 bit  →  2 subredes
│   ├── 10.0.0.0/26   (64)        +2 bits →  4 subredes
│   └── 10.0.0.64/26  (64)
└── 10.0.0.128/25  (128)
    ├── 10.0.0.128/26 (64)
    └── 10.0.0.192/26 (64)
```

**Fórmula:** pasar de `/a` a `/b` da **2^(b − a)** subredes de **2^(32 − b)** direcciones cada una.

| De | A | Subredes | Tamaño de cada una |
|----|---|----------|--------------------|
| `/24` | `/26` | 4 | 64 |
| `/16` | `/20` | 16 | 4.096 |
| `/16` | `/24` | 256 | 256 |
| `/16` | `/19` | 8 | 8.192 |

Las subredes se escriben **saltando de bloque en bloque**: `/26` en el 4.º octeto salta de 64 en 64; `/20` en el 3.º salta de 16 en 16 (`10.0.0.0`, `10.0.16.0`, `10.0.32.0`…).

### Anatomía de una VPC típica

```
VPC 10.0.0.0/16  (región us-east-1)
│
├── AZ us-east-1a
│   ├── pública      10.0.0.0/24    ← ALB, NAT Gateway, bastión  (ruta a Internet Gateway)
│   ├── privada-app  10.0.10.0/24   ← EC2 / contenedores de la app (sale por el NAT)
│   └── privada-db   10.0.20.0/24   ← RDS (sin salida a internet)
│
├── AZ us-east-1b
│   ├── pública      10.0.1.0/24
│   ├── privada-app  10.0.11.0/24
│   └── privada-db   10.0.21.0/24
│
└── (espacio libre para crecer: 10.0.30.0 – 10.0.255.255)
```

Qué hay detrás de cada decisión:
- **Una subred vive en una sola AZ.** Para alta disponibilidad, se repite cada capa en al menos **2 AZs**.
- **Pública** = su tabla de rutas tiene salida a un **Internet Gateway**. **Privada** = no la tiene (clase 20). "Pública" no la decide el nombre: la decide **la ruta**.
- **Capas separadas** (web, app, datos): cada capa tiene su security group, y la base de datos no es alcanzable desde internet.
- **Numeración con patrón** (`10.0.0.x` públicas, `10.0.1x.x` app, `10.0.2x.x` datos): cualquiera entiende una IP de un vistazo durante un incidente.
- **Margen**: no gastes el `/16` entero el primer día. Una AZ nueva, una capa nueva o **Kubernetes** (en EKS, **cada pod consume una IP de la VPC**) pueden necesitar muchas IPs.

### Evitar solapes

Antes de elegir un CIDR, pregunta qué otras redes existen: otras VPCs de la empresa, la oficina, la VPN, los entornos dev, staging y prod. Una convención habitual: **un `/16` distinto por VPC**: `10.0.0.0/16` prod, `10.1.0.0/16` staging, `10.2.0.0/16` dev. Y evita `192.168.0.0/16` y `172.17.0.0/16`: el primero es el de las redes domésticas (las VPNs de casa chocan con él) y el segundo lo usa Docker por defecto.

Dos redes se solapan si una contiene **alguna** dirección de la otra. `10.0.0.0/16` y `10.0.128.0/17` se solapan: la segunda está **dentro** de la primera.

## Práctica guiada

### 1. Dividir a mano y comprobar

En papel: divide `10.0.0.0/24` en 4 subredes iguales. Escribe red, broadcast y rango de cada una. Comprueba:

```bash
python3 -c "
import ipaddress as i
for s in i.ip_network('10.0.0.0/24').subnets(new_prefix=26):
    print(s, '→', s[0], '-', s[-1], '|', s.num_addresses, 'direcciones')
"
```

### 2. La VPC por defecto de AWS

Toda cuenta de AWS trae en cada región una VPC por defecto: `172.31.0.0/16`, con una subred `/20` **pública** en cada AZ. Calcula en papel las tres primeras subredes y comprueba:

```bash
python3 -c "
import ipaddress as i
print([str(s) for s in i.ip_network('172.31.0.0/16').subnets(new_prefix=20)][:3])
"
```

(La VPC por defecto sirve para pruebas rápidas. En proyectos reales se crea una propia con subredes privadas.)

### 3. Una herramienta tuya

Crea `~/my-devops-journey/labs/clase-18/subredes.py`:

```python
#!/usr/bin/env python3
"""Uso: subredes.py <CIDR> <nuevo_prefijo>   Ej: subredes.py 10.0.0.0/16 20"""
import ipaddress
import sys

red = ipaddress.ip_network(sys.argv[1])
nuevo = int(sys.argv[2])
for s in red.subnets(new_prefix=nuevo):
    print(f"{str(s):<18} {str(s[0]):>15} - {str(s[-1]):<15}  útiles AWS: {s.num_addresses - 5}")
```

```bash
cd ~/my-devops-journey/labs/clase-18
chmod +x subredes.py
./subredes.py 10.0.0.0/24 26
./subredes.py 10.0.0.0/16 20 | head
```

Úsala para **comprobar** tus cálculos, nunca para sustituirlos.

## Rómpelo: ejercicios de diseño

Resuelve en papel. Comprueba con tu script.

| # | Ejercicio |
|---|-----------|
| 1 | Divide `192.168.0.0/22` en subredes `/24`. ¿Cuántas salen? Escríbelas |
| 2 | Divide `10.10.0.0/16` en 8 subredes iguales. ¿Qué prefijo tienen? Escribe las 3 primeras y la última |
| 3 | ¿Se solapan `10.0.0.0/16` y `10.0.128.0/17`? ¿Y `10.0.0.0/16` y `10.1.0.0/16`? |
| 4 | Tienes `10.0.0.0/24` y necesitas 2 subredes de 100 hosts y 2 de 20 hosts (no de AWS, redes normales). Propón las 4 sin solapes, o demuestra que no caben. Pista: empieza por las grandes |
| 5 | La empresa usa `10.0.0.0/16` en prod y `10.1.0.0/16` en staging. La oficina usa `10.0.0.0/8`. ¿Qué problema hay al montar una VPN desde la oficina? |
| 6 | Una subred `/28` en AWS para un clúster que tendrá 30 pods. ¿Cabe? |

## Proyecto de la clase: tu VPC

Diseña la red de **"TiendaOnline"** en AWS y guárdala en `notas/fase-1/clase-18-diseno-vpc.md`:
- Una VPC para producción, con margen para staging y dev en el futuro **sin solapes**.
- 3 zonas de disponibilidad.
- 3 capas: pública (ALB y NAT), app (contenedores) y datos (RDS).
- La capa app debe aguantar hasta **2.000 IPs por AZ** (va a correr Kubernetes).
- Deja al menos la mitad de la VPC libre.

Entrega:
1. Una tabla con: nombre, AZ, CIDR, IPs útiles en AWS y si es pública o privada.
2. Un diagrama en ASCII como el de la teoría.
3. Tres líneas justificando tus decisiones.
4. Los CIDR que reservarías para staging y dev.

## Cierre

En `notas/fase-1/clase-18.md`:

1. ¿Cuántas subredes `/24` caben en un `/20`? Explica el cálculo.
2. ¿Por qué se repite cada capa de subredes en al menos dos AZs?
3. ¿Por qué es grave que dos VPCs tengan rangos solapados? Pon un ejemplo de cuándo te daría problemas.
4. **Repaso (clase 17, sin mirar):** calcula red y broadcast de `10.0.0.200/28`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Ejercicios:**
1. 4 subredes: `192.168.0.0/24`, `192.168.1.0/24`, `192.168.2.0/24`, `192.168.3.0/24`.
2. 8 = 2³ → `/19` (8.192 direcciones cada una, saltos de 32 en el 3.er octeto): `10.10.0.0/19`, `10.10.32.0/19`, `10.10.64.0/19` … `10.10.224.0/19`.
3. Sí se solapan (la `/17` está dentro de la `/16`). No se solapan `10.0.0.0/16` y `10.1.0.0/16`.
4. Una solución: `10.0.0.0/25` (126 hosts), `10.0.0.128/26` (62)… ¡Cuidado! Para **dos** de 100 necesitas dos `/25`, y eso ya llena el `/24` entero. **No cabe**. La respuesta correcta es detectarlo: hacen falta al menos 2 × 128 + 2 × 32 = 320 direcciones, más que las 256 de un `/24`. Detectar que un diseño no cabe es tan importante como hacerlo.
5. `10.0.0.0/8` de la oficina **contiene** a ambas VPCs: los rangos se solapan, y los routers no sabrán si `10.0.5.3` está en la oficina o en AWS. Hay que renumerar o usar NAT entre redes (complejo y frágil).
6. Una `/28` en AWS tiene 11 IPs útiles: **no** caben 30 pods.

**Cierre:**
1. De `/20` a `/24` hay 4 bits más → 2⁴ = **16** subredes `/24`.
2. Una subred vive en una sola AZ, y una AZ entera puede caer (un centro de datos). Con la capa repetida en dos AZs, el balanceador y los Auto Scaling Groups siguen sirviendo desde la otra.
3. El enrutamiento no puede distinguir destinos cuando la misma IP existe en dos sitios. Peering, VPN y Transit Gateway **rechazan** o se vuelven ambiguos con rangos solapados. Ejemplo: la empresa compra otra que también usa `10.0.0.0/16` y hay que conectar ambas; o dev y prod se crearon con el mismo CIDR "por copiar" y después hay que conectarlas.
4. Red `10.0.0.192`, broadcast `10.0.0.207`.

**Proyecto (una solución válida, hay muchas):**
VPC prod `10.0.0.0/16`; staging `10.1.0.0/16`; dev `10.2.0.0/16`.

| Subred | AZ | CIDR | Útiles AWS | Tipo |
|--------|----|------|-----------|------|
| pub-a | a | 10.0.0.0/24 | 251 | pública |
| pub-b | b | 10.0.1.0/24 | 251 | pública |
| pub-c | c | 10.0.2.0/24 | 251 | pública |
| app-a | a | 10.0.32.0/21 | 2.043 | privada |
| app-b | b | 10.0.40.0/21 | 2.043 | privada |
| app-c | c | 10.0.48.0/21 | 2.043 | privada |
| db-a | a | 10.0.64.0/24 | 251 | privada (sin NAT) |
| db-b | b | 10.0.65.0/24 | 251 | privada (sin NAT) |
| db-c | c | 10.0.66.0/24 | 251 | privada (sin NAT) |

Todo cabe por debajo de `10.0.127.255`: la mitad superior (`10.0.128.0/17`) queda libre. `/21` = 2.048 − 5 = 2.043 ≥ 2.000 ✅.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| subnetting | división en subredes |
| availability zone (AZ) | zona de disponibilidad |
| public / private subnet | subred pública / privada |
| IP address planning | planificación de direcciones IP |
| CIDR overlap | solapamiento de rangos |

🎙️ *"I give each environment its own non-overlapping /16, spread every tier across at least two AZs, and leave room to grow, especially if Kubernetes will consume VPC IPs."*

## Siguiente

[Clase 19 — Puertos, TCP y UDP](clase-19-puertos-tcp-udp.md)
