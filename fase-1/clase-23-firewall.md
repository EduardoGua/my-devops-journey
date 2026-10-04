# Clase 23 — Firewall

**Dónde:** VM `servidor-01` + tu PC · **Tiempo:** 90 min · **Bloque:** C. Redes

## Objetivo

- Entender un firewall de paquetes: políticas por defecto, reglas, **estado** (*stateful*) y la diferencia entre **descartar** y **rechazar**.
- Configurar `ufw` en el servidor **sin quedarte fuera**, y saber recuperarte si pasa.
- Traducirlo a AWS: **Security Groups** frente a **Network ACLs**.

## Por qué importa

En AWS no hay un servidor sin firewall: cada instancia, base de datos y balanceador tiene **security groups**, y cada subred, una **NACL**. "No conecta" tras un despliegue suele ser una regla que falta. "Nos hackearon" suele empezar por una regla de más (`0.0.0.0/0` en el 22 o en la base de datos). Diseñar reglas mínimas y depurarlas leyendo el síntoma (timeout o refused) es trabajo diario.

## Teoría

### Cómo decide un firewall

```
 paquete entrante ──► ¿coincide con la regla 1? ─sí─► aplicar su acción (ACCEPT / DROP / REJECT)
                         │ no
                         ▼
                      ¿regla 2? … ¿regla N?
                         │ ninguna
                         ▼
                      POLÍTICA POR DEFECTO (lo normal en un servidor: denegar la entrada)
```

- **Primera regla que coincide, gana** (en ufw e iptables, y en las NACLs de AWS por su número).
- **Política por defecto segura:** denegar todo lo **entrante** y permitir lo **saliente**. Después abres solo lo necesario.

### DROP frente a REJECT

| Acción | Qué ve el cliente | Síntoma (clase 16) |
|--------|-------------------|--------------------|
| **DROP / deny** | nada: el paquete desaparece | **timeout** |
| **REJECT** | un rechazo inmediato | **connection refused** |

Los security groups de AWS **descartan** en silencio: por eso una regla que falta en AWS se ve como **timeout**.

### Con estado (stateful)

Un firewall *stateful* recuerda las conexiones. Si permites la entrada al puerto 80, las **respuestas** salen solas, sin regla. Y si tu servidor inicia una conexión (un `apt update`), la respuesta entra sola. Es el caso de ufw y de los **security groups**. Las **NACLs** de AWS **no tienen estado**: cada sentido necesita su propia regla, incluidos los **puertos efímeros** de vuelta (1024–65535).

### En AWS

| | Security Group | Network ACL |
|-|----------------|-------------|
| Se aplica a | la interfaz de red (instancia, RDS, ALB…) | la **subred** entera |
| Estado | **stateful** | **stateless** |
| Reglas | solo **allow** (lo no permitido se deniega) | **allow y deny**, numeradas, gana la de menor número |
| Por defecto | deniega toda la entrada, permite toda la salida | la NACL por defecto permite todo |
| Origen de una regla | CIDR **o otro security group** | solo CIDR |

Lo más potente de los SG es usar **otro SG como origen**: "la base de datos acepta el 5432 **desde el SG de la app**". Así no dependes de IPs que cambian con el Auto Scaling. En la práctica, casi todo se resuelve con SGs, y las NACLs se usan como una segunda capa gruesa (por ejemplo, bloquear un rango de IPs atacante).

### ufw

`ufw` (*uncomplicated firewall*) es la interfaz sencilla de Ubuntu sobre el filtro de paquetes del kernel (nftables).

| Comando | Efecto |
|---------|--------|
| `ufw status verbose` / `numbered` | estado y reglas |
| `ufw default deny incoming` | política de entrada |
| `ufw allow 22/tcp` · `ufw allow OpenSSH` | permitir un puerto o una app |
| `ufw allow from 10.0.0.5 to any port 5432 proto tcp` | permitir solo desde un origen |
| `ufw deny 80/tcp` | descartar (DROP) |
| `ufw reject 8080/tcp` | rechazar (REJECT) |
| `ufw delete <n>` | borrar la regla número n |
| `ufw enable` / `disable` | activar / desactivar |
| `ufw logging on` | registrar bloqueos (`[UFW BLOCK]` en el log del kernel) |

## Práctica guiada

### 0. Red de seguridad

Desde tu PC:
```bash
multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-firewall && multipass start servidor-01
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
```

Ten **dos** sesiones abiertas en la VM (`ssh servidor-01`). Recuerda que `multipass shell` **también usa SSH**.

### 1. Estado inicial

En la VM:
```bash
sudo ufw status verbose
sudo ss -tlnp
```

Haz el inventario: ¿qué puertos escuchan y cuáles **deben** ser accesibles desde fuera?

### 2. Activar sin quedarte fuera

**El orden importa: primero permitir SSH, después activar.**
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw show added
sudo ufw enable
sudo ufw status verbose
```

Desde tu PC, en una terminal **nueva**: `ssh servidor-01 hostname`. Si funciona, puedes seguir.

### 3. Lo que ahora no llega

🔮 **Predice:** desde tu PC, ¿timeout o refused en cada caso?

```bash
curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://$IP/ || echo "FALLA (¿qué tipo?)"
nc -zv -w 5 $IP 8080
```

Ambos dan **timeout**: la política por defecto descarta. Es exactamente lo que verías con un security group sin la regla del puerto. Mira la evidencia en la VM:
```bash
sudo ufw logging on
```
Repite el `curl` desde tu PC y en la VM:
```bash
sudo journalctl -k -n 5 --no-pager | grep "UFW BLOCK"
```
Cada línea dice el origen (`SRC=`), el destino (`DST=`), el protocolo y el puerto (`DPT=80`).

### 4. Abrir con criterio

```bash
sudo ufw allow 80/tcp
```

Para el 8080 (`miapp`), solo debe entrar **tu PC**, que para la VM es su gateway:
```bash
HOSTIP=$(ip route | awk '/default/ {print $3; exit}'); echo $HOSTIP
sudo ufw allow from $HOSTIP to any port 8080 proto tcp
sudo ufw status numbered
```

Desde tu PC:
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://$IP/
curl -s http://$IP:8080 | head -2
```

### 5. DROP frente a REJECT, lado a lado

En la VM, levanta dos puertos de prueba y trata cada uno de una forma:
```bash
python3 -m http.server 9001 >/dev/null 2>&1 &
python3 -m http.server 9002 >/dev/null 2>&1 &
sudo ufw deny 9001/tcp
sudo ufw reject 9002/tcp
```

Desde tu PC:
```bash
time nc -zv -w 5 $IP 9001
time nc -zv -w 5 $IP 9002
```

9001 tarda 5 s y da timeout; 9002 falla al instante con *refused*. Mismo efecto de seguridad, síntoma distinto. Limpia:
```bash
kill %1 %2
sudo ufw status numbered
sudo ufw delete <número de la regla 9001>
sudo ufw status numbered          # los números se reordenan: vuelve a mirarlos
sudo ufw delete <número de la regla 9002>
```

### 6. Stateful en acción

```bash
sudo apt update
```

Funciona aunque **no** hay ninguna regla de entrada para las respuestas de los servidores de Ubuntu: el firewall recuerda que la conexión la inició la VM.

## Rómpelo: quedarte fuera (a propósito)

Comprueba que tienes el snapshot `pre-firewall`. En la VM:
```bash
sudo ufw status numbered
sudo ufw delete <número de la regla OpenSSH>     # repite si hay una para IPv6
```

Tu sesión actual **sigue viva** (es una conexión ya establecida, y el firewall tiene estado). Ahora, desde tu PC:
```bash
ssh -o ConnectTimeout=5 servidor-01 hostname
multipass shell servidor-01
```

Las dos fallan. Si cerraras la sesión que tienes abierta, **no habría forma de entrar**. Arréglalo desde esa sesión:
```bash
sudo ufw allow OpenSSH
```

Ahora el caso sin sesión abierta. Vuelve a borrar la regla de SSH y **cierra todas tus sesiones**. Estás fuera. La única salida:
```bash
multipass stop servidor-01
multipass restore servidor-01.pre-firewall --destructive
multipass start servidor-01
```

En AWS, el equivalente es un security group sin el puerto 22 (eso se arregla en la consola: el SG está **fuera** de la máquina) o, mucho peor, un firewall **dentro** de la instancia mal configurado: ahí tendrías que desmontar el disco y repararlo desde otra instancia. **Lección:** el firewall se cambia con una sesión abierta, probando desde otra, y con un plan para volver atrás.

Después de restaurar, **vuelve a aplicar** la configuración buena de los pasos 2 y 4 (deny incoming, OpenSSH, 80 y 8080 desde tu PC).

## Reto

1. **Diseño de security groups** para la VPC de la clase 18. Escribe las reglas de entrada de: `sg-alb` (internet → 443), `sg-app` (desde el ALB → 8080) y `sg-db` (desde la app → 5432). Usa SGs como origen cuando puedas. ¿Qué regla de entrada **no** debe existir nunca en `sg-db`?
2. **Diseño de una NACL** (sin estado) para la subred pública: permite HTTPS desde internet y que las respuestas vuelvan. ¿Qué regla de **salida** necesitas que con un SG no harías falta?
3. En la VM, permite el 8080 solo desde tu PC y **rechaza** (no descartes) el resto de intentos al 8080. ¿Importa el orden de las reglas? Pruébalo.

## Cierre

En `notas/fase-1/clase-23.md`:

1. Diferencia entre DROP y REJECT. ¿Cuál usan los security groups y qué síntoma produce?
2. ¿Qué significa que un firewall tenga estado? ¿Por qué las NACLs necesitan reglas para los puertos efímeros?
3. ¿Por qué es mejor "permitir el 5432 desde `sg-app`" que "permitir el 5432 desde `10.0.10.0/24`"?
4. **Repaso (clase 22, sin mirar):** ¿qué significan 502, 503 y 504 en un ALB?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** DROP descarta el paquete sin responder: el cliente espera y acaba en **timeout**. REJECT responde con un rechazo y el cliente ve **connection refused** al instante. Los security groups de AWS descartan, así que una regla que falta se nota como **timeout**.

**2.** Recuerda las conexiones abiertas: si una conexión se permitió en un sentido, sus paquetes de vuelta pasan automáticamente. Las NACLs no recuerdan nada y evalúan cada paquete aislado: la respuesta de tu servidor web a un cliente sale hacia el **puerto efímero** del cliente (1024–65535), así que hace falta una regla de **salida** para ese rango. Y, al revés, para las respuestas que reciben las conexiones que inicia la instancia, una de **entrada**.

**3.** Porque referencia **a quién** se permite (las instancias que llevan `sg-app`) y no **dónde** está. Si la app escala, cambia de subred o de IP, la regla sigue siendo correcta. Con un CIDR, cualquier otra cosa que se lance en esa subred (por ejemplo, una instancia de pruebas comprometida) podría llegar a la base de datos, y si la app se mueve, la regla se queda obsoleta.

**4.** **502**: el backend falló o rechazó la conexión. **503**: no hay destinos sanos. **504**: el backend tardó demasiado.

**Reto 1:**
| SG | Entrada | Origen |
|----|---------|--------|
| `sg-alb` | 443/tcp (y 80 para redirigir) | `0.0.0.0/0` |
| `sg-app` | 8080/tcp | `sg-alb` |
| `sg-db` | 5432/tcp | `sg-app` |

Nunca en `sg-db`: `5432` (ni ningún puerto) desde `0.0.0.0/0`.

**Reto 2 (NACL pública):** entrada `100 allow tcp 443 desde 0.0.0.0/0` · salida `100 allow tcp 1024-65535 hacia 0.0.0.0/0` (respuestas a los clientes) · más las reglas para que el ALB hable con la app y para el tráfico que inicien las instancias (por ejemplo, entrada de efímeros para las respuestas de `apt`). Con SGs, ninguna de las reglas de respuesta hace falta.

**Reto 3:** sí importa: ufw evalúa en orden, así que la regla `allow from <tu PC>` debe ir **antes** del `reject 8080`. `sudo ufw insert 1 allow from $HOSTIP to any port 8080 proto tcp` pone una regla al principio.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| firewall rule | regla de firewall |
| default policy | política por defecto |
| stateful / stateless | con estado / sin estado |
| inbound / outbound | entrante / saliente |
| to drop / to reject | descartar / rechazar |
| security group / network ACL | (AWS) |

🎙️ *"Security groups are stateful and allow-only, and I prefer referencing other security groups instead of CIDRs. NACLs are stateless, so they need explicit rules for ephemeral return ports."*

## Siguiente

[Clase 24 — Dos servidores: tu primera red](clase-24-dos-servidores.md)
