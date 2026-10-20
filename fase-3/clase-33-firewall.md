# Clase 33 — Firewall

**Dónde:** VM `servidor-01` + tu PC · **Tiempo:** 90 min · **Bloque:** A. Redes

> 💡 **La idea de hoy:** un firewall mira cada paquete que llega y lo compara con una lista de **reglas**; la primera que coincide decide, y si no coincide ninguna, manda la **política por defecto** (en un servidor: denegar la entrada). Si **descarta** el paquete, el cliente ve un timeout; si lo **rechaza**, un refused. Y como recuerda las conexiones (*stateful*), las respuestas pasan solas. Los **security groups** de AWS funcionan igual.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Timeout frente a `Connection refused`, y qué significa cada uno (clase 26, Rómpelo).
> - Puertos, `ss -tlnp` y los puertos efímeros de las respuestas (clase 29).
> - El gateway de la VM es tu PC (clase 30, pieza 1).
> - Dejar una sesión abierta al cambiar algo que te puede dejar fuera (clase 15, pieza 6).
> - Restaurar un snapshot de la VM (clase 08, pieza 5).

> 🔤 **Palabras nuevas de hoy:**
> - **regla**: «si el paquete es así, haz esto» (permitir, descartar o rechazar).
> - **política por defecto**: lo que se hace con un paquete que no coincide con ninguna regla.
> - **DROP / REJECT**: descartar en silencio / rechazar con una respuesta.
> - **stateful**: que recuerda las conexiones y deja pasar sus respuestas.
> - **`ufw`**: el firewall sencillo de Ubuntu.
> - **security group / NACL**: el firewall de AWS de cada interfaz (stateful) / de cada subred (stateless).

## Objetivo

- Entender un firewall de paquetes: políticas por defecto, reglas, **estado** (*stateful*) y la diferencia entre **descartar** y **rechazar**.
- Configurar `ufw` en el servidor **sin quedarte fuera**, y saber recuperarte si pasa.
- Traducirlo a AWS: **Security Groups** frente a **Network ACLs**.

## Por qué importa

En AWS no hay un servidor sin firewall: cada instancia, base de datos y balanceador tiene **security groups**, y cada subred, una **NACL**. "No conecta" tras un despliegue suele ser una regla que falta. "Nos hackearon" suele empezar por una regla de más (`0.0.0.0/0` en el 22 o en la base de datos). Diseñar reglas mínimas y depurarlas leyendo el síntoma (timeout o refused) es trabajo diario.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea (en la 1, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Primero, la red de seguridad. Desde tu PC:

```bash
multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-firewall && multipass start servidor-01
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
```

Ten **dos** sesiones abiertas en la VM (`ssh servidor-01`): una para trabajar y otra de seguridad. Recuerda que `multipass shell` **también usa SSH**.

## Las piezas

### Pieza 1 — Cómo decide un firewall, y `ufw`

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

`ufw` (*uncomplicated firewall*) es la interfaz sencilla de Ubuntu sobre el filtro de paquetes del kernel (nftables):

| Comando | Efecto |
|---------|--------|
| `ufw status verbose` / `numbered` | estado y reglas |
| `ufw default deny incoming` | política de entrada |
| `ufw allow 22/tcp` · `ufw allow OpenSSH` | permitir un puerto o una app |
| `ufw allow from 10.0.0.5 to any port 5432 proto tcp` | permitir solo desde un origen |
| `ufw deny 80/tcp` | descartar (DROP) |
| `ufw reject 8080/tcp` | rechazar (REJECT) |
| `ufw delete <n>` | borrar la regla número n (solo esa: la copia IPv6 tiene otro número) |
| `ufw delete allow 80/tcp` | borrar una regla escribiéndola igual que se creó (borra IPv4 e IPv6 a la vez) |
| `ufw enable` / `disable` | activar / desactivar |
| `ufw logging on` | registrar bloqueos (`[UFW BLOCK]` en el log del kernel) |

**Pruébalo, primero el estado inicial.** En la VM:

```bash
sudo ufw status verbose
sudo ss -tlnp
```

👀 **Qué deberías ver:** `Estado: inactivo` (o `Status: inactive`) y los puertos que escuchan: 22, 80 y 8080. Haz el inventario: ¿cuáles **deben** ser accesibles desde fuera?

**Ahora, actívalo sin quedarte fuera.** El orden importa: **primero permitir SSH, después activar**.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw show added
sudo ufw enable
sudo ufw status verbose
```

👀 **Qué deberías ver:** en `show added`, la regla `ufw allow OpenSSH`; después del `enable`, `Firewall is active…`; y en el estado, `Default: deny (incoming), allow (outgoing)` con `OpenSSH ALLOW IN Anywhere` (y su copia `(v6)`).

Desde tu PC, en una terminal **nueva**: `ssh servidor-01 hostname`. Si responde `servidor-01`, puedes seguir.

✋ **Sin mirar:** vas a activar `ufw` en un servidor al que solo llegas por SSH. ¿Qué regla añades **antes** del `enable`?

<details>
<summary>Comprueba</summary>

`sudo ufw allow OpenSSH` (o `22/tcp`). Sin ella, la política por defecto cortaría las conexiones SSH nuevas.
</details>

**En resumen:** el firewall aplica la primera regla que coincide y, si no hay ninguna, la política por defecto; con `ufw`, primero `allow OpenSSH` y después `enable`.

### Pieza 2 — DROP frente a REJECT

| Acción | Qué ve el cliente | Síntoma (clase 26) |
|--------|-------------------|--------------------|
| **DROP / deny** | nada: el paquete desaparece | **timeout** |
| **REJECT** | un rechazo inmediato | **connection refused** |

Los security groups de AWS **descartan** en silencio: por eso una regla que falta en AWS se ve como **timeout**.

**Pruébalo, primero lo que la política por defecto ya no deja pasar.** 🔮 **Predice:** desde tu PC, ¿timeout o refused en cada caso?

```bash
curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://$IP/ || echo "FALLA (¿qué tipo?)"
nc -zv -w 5 $IP 8080
```

👀 **Qué deberías ver:** los dos esperan 5 segundos y fallan: **timeout**. La política por defecto descarta. Es exactamente lo que verías con un security group sin la regla del puerto.

Mira la evidencia en la VM:

```bash
sudo ufw logging on
```

Repite el `curl` desde tu PC y en la VM:

```bash
sudo journalctl -k -n 5 --no-pager | grep "UFW BLOCK"
```

👀 **Qué deberías ver:** líneas `[UFW BLOCK]` con el origen (`SRC=` la IP de tu PC), el destino (`DST=` la de la VM), el protocolo (`PROTO=TCP`) y el puerto (`DPT=80`).

**Ahora, DROP y REJECT lado a lado.** En la VM, levanta dos puertos de prueba y trata cada uno de una forma:

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

👀 **Qué deberías ver:** el 9001 tarda unos 5 s y da timeout; el 9002 falla al instante con *refused*. Mismo efecto de seguridad, síntoma distinto.

Limpia:

```bash
kill %1 %2
sudo ufw status numbered          # cada regla aparece dos veces: IPv4 y (v6)
sudo ufw delete deny 9001/tcp     # borra las dos copias de una vez
sudo ufw delete reject 9002/tcp
sudo ufw status numbered
```

✋ **Sin mirar:** tu `nc` tarda 5 segundos y después falla. ¿El firewall hace DROP o REJECT?

<details>
<summary>Comprueba</summary>

DROP: descarta en silencio, y el cliente espera hasta agotar su tiempo.
</details>

**En resumen:** DROP = timeout, REJECT = refused al instante; los security groups de AWS hacen DROP.

### Pieza 3 — Abrir con criterio

Se abre solo lo necesario, y solo **para quien lo necesita**: la web, para todos; el puerto de la app, solo para quien la consulta. Es mínimo privilegio aplicado a la red.

**Pruébalo.** En la VM, abre la web a todos:

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

👀 **Qué deberías ver:** en la lista numerada, `80/tcp ALLOW IN Anywhere` y `8080/tcp ALLOW IN 10.x.x.1`; desde tu PC, `200` y la página de `miapp`.

✋ **Sin mirar:** ¿por qué permitir el 8080 solo desde tu PC y no desde cualquier sitio, si total es tu laboratorio?

<details>
<summary>Comprueba</summary>

Por mínimo privilegio: si nadie más necesita llegar a la app directamente, cuantas menos máquinas puedan, menos superficie de ataque. Es el hábito que usarás con los security groups.
</details>

**En resumen:** abre solo los puertos necesarios, y cada uno solo desde los orígenes que lo necesitan.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Deja `ufw` activo con estas reglas.

### Pieza 4 — Con estado (*stateful*)

Un firewall *stateful* recuerda las conexiones. Si permites la entrada al puerto 80, las **respuestas** salen solas, sin regla. Y si tu servidor inicia una conexión (un `apt update`), la respuesta entra sola. Es el caso de ufw y de los **security groups**. Las **NACLs** de AWS **no tienen estado**: cada sentido necesita su propia regla, incluidos los **puertos efímeros** de vuelta (1024–65535).

**Pruébalo.** En la VM:

```bash
sudo apt update
```

👀 **Qué deberías ver:** `apt update` descarga los índices sin problema, aunque **no** hay ninguna regla de entrada para las respuestas de los servidores de Ubuntu: el firewall recuerda que la conexión la inició la VM.

✋ **Sin mirar:** un security group permite la entrada al 443. ¿Necesita una regla de salida para que las respuestas lleguen al cliente?

<details>
<summary>Comprueba</summary>

No: es stateful y deja salir las respuestas de las conexiones que dejó entrar. Una NACL, en cambio, sí la necesitaría.
</details>

**En resumen:** un firewall con estado deja pasar las respuestas de las conexiones permitidas; uno sin estado necesita reglas para los dos sentidos.

### Pieza 5 — En AWS: Security Groups y Network ACLs

| | Security Group | Network ACL |
|-|----------------|-------------|
| Se aplica a | la interfaz de red (instancia, RDS, ALB…) | la **subred** entera |
| Estado | **stateful** | **stateless** |
| Reglas | solo **allow** (lo no permitido se deniega) | **allow y deny**, numeradas, gana la de menor número |
| Por defecto | deniega toda la entrada, permite toda la salida | la NACL por defecto permite todo |
| Origen de una regla | CIDR **o otro security group** | solo CIDR |

Lo más potente de los SG es usar **otro SG como origen**: "la base de datos acepta el 5432 **desde el SG de la app**". Así no dependes de IPs que cambian con el Auto Scaling. En la práctica, casi todo se resuelve con SGs, y las NACLs se usan como una segunda capa gruesa (por ejemplo, bloquear un rango de IPs atacante).

**Pruébalo, en papel.** ¿Security group o NACL para cada caso?

1. Que la base de datos solo acepte conexiones de las instancias de la app.
2. Bloquear para toda una subred un rango de IPs que te está atacando.
3. Abrir el 443 de un balanceador a internet.

<details>
<summary>Comprueba</summary>

1. **Security group**, con `sg-app` como origen. 2. **NACL**: es la que admite reglas *deny* y se aplica a toda la subred. 3. **Security group** del ALB: `443` desde `0.0.0.0/0`.
</details>

✋ **Sin mirar:** ¿puedes poner una regla *deny* en un security group?

<details>
<summary>Comprueba</summary>

No: los security groups solo tienen reglas *allow*. Lo que no está permitido se deniega. Para un *deny* explícito, una NACL.
</details>

**En resumen:** security group = stateful, solo allow, por interfaz y con otros SGs como origen; NACL = stateless, allow y deny, por subred.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `sudo ufw status verbose` · `numbered` | el estado y las políticas · las reglas numeradas |
| `sudo ufw default deny incoming` · `default allow outgoing` | las políticas seguras |
| `sudo ufw allow OpenSSH` → `sudo ufw enable` | en ese orden, siempre |
| `sudo ufw allow 80/tcp` · `allow from IP to any port N proto tcp` | abrir a todos · abrir solo a un origen |
| `sudo ufw deny N/tcp` · `sudo ufw reject N/tcp` | descartar (timeout) · rechazar (refused) |
| `sudo ufw delete allow 80/tcp` · `sudo ufw insert 1 …` | borrar una regla · poner una al principio |
| `sudo ufw logging on` · `sudo journalctl -k \| grep "UFW BLOCK"` | registrar bloqueos · verlos |

| | Security Group | NACL |
|-|----------------|------|
| ¿Dónde? | interfaz | subred |
| ¿Estado? | sí | no: hay que permitir los efímeros |
| ¿Reglas? | solo allow | allow y deny, por número |

## Rómpelo: quedarte fuera (a propósito)

Comprueba que tienes el snapshot `pre-firewall`. En la VM:
```bash
sudo ufw status numbered
sudo ufw delete allow OpenSSH     # borra la regla de IPv4 y la de IPv6
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

Después de restaurar, **vuelve a aplicar** la configuración buena de las piezas 1 y 3 (deny incoming, OpenSSH, 80 y 8080 desde tu PC).

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Diseña los security groups de la VPC de la clase 28: `sg-alb` (internet → 443), `sg-app` (desde el ALB → 8080) y `sg-db` (desde la app → 5432). ¿Qué regla de entrada **no** debe existir nunca en `sg-db`?

> 🧩 **Ejemplo resuelto:** el security group de un bastión al que solo entras tú.
>
> | SG | Entrada | Origen |
> |----|---------|--------|
> | `sg-bastion` | 22/tcp | `203.0.113.25/32` (tu IP) |

**Ahora tú, con huecos:**

| SG | Entrada | Origen |
|----|---------|--------|
| `sg-alb` | ____/tcp (y 80 para redirigir) | `____` |
| `sg-app` | 8080/tcp | `____` |
| `sg-db` | 5432/tcp | `____` |

Nunca en `sg-db`: ____

<details>
<summary>Pista</summary>

Usa otro security group como origen siempre que puedas (pieza 5). Solo el balanceador está abierto a todo internet.
</details>

**2.** Diseña la NACL (sin estado) de la subred pública: HTTPS desde internet, y que las respuestas vuelvan. ¿Qué regla de **salida** necesitas que con un SG no haría falta?

> 🧩 **Ejemplo resuelto:** una regla de entrada para SSH solo desde tu IP: `100 allow tcp 22 desde 203.0.113.25/32`.

**Ahora tú, con huecos:**
```
Entrada: 100 allow tcp ____ desde ____
Salida:  100 allow tcp ____-____ hacia ____
```

<details>
<summary>Pista</summary>

La respuesta del servidor va al **puerto efímero** del cliente (pieza 4 y clase 29). Sin estado, nadie la deja salir si no hay una regla.
</details>

**3.** En la VM, permite el 8080 solo desde tu PC y **rechaza** (no descartes) el resto de intentos al 8080. ¿Importa el orden de las reglas? Pruébalo.

> 🧩 **Ejemplo resuelto:** `sudo ufw insert 1 allow from $HOSTIP to any port 9000 proto tcp` pone esa regla la **primera** de la lista.

**Ahora tú, con huecos.** Primero, en el orden **equivocado**, para ver qué pasa:
```bash
sudo ufw delete allow from $HOSTIP to any port 8080 proto tcp
sudo ufw reject ____/tcp
sudo ufw allow from $HOSTIP to any port 8080 proto tcp      # se añade AL FINAL de la lista
sudo ufw status numbered
```
Desde tu PC: `nc -zv -w 3 $IP 8080`. ¿Funciona o te rechaza? Después, arréglalo:
```bash
sudo ufw delete allow from $HOSTIP to any port 8080 proto tcp
sudo ufw insert ____ allow from $HOSTIP to any port 8080 proto tcp
sudo ufw status numbered
```
Y repite el `nc` desde tu PC.

<details>
<summary>Pista</summary>

ufw aplica la **primera** regla que coincide. Mira en `status numbered` qué número tiene cada regla del 8080. (Desde la propia VM no puedes probar el rechazo: el tráfico de una máquina a sí misma va por `lo`, y ufw siempre lo deja pasar. Lo verás desde `servidor-02` en la clase 34.)
</details>

## Cierre

En `notas/fase-3/clase-33.md`:

1. Diferencia entre DROP y REJECT. ¿Cuál usan los security groups y qué síntoma produce? *(2 líneas. Empieza así: «DROP descarta sin responder, y el cliente ve… REJECT… Los security groups…»)*
2. ¿Qué significa que un firewall tenga estado? ¿Por qué las NACLs necesitan reglas para los puertos efímeros? *(2–3 líneas. Empieza así: «Que recuerda las conexiones y deja pasar sus respuestas… Las NACLs no recuerdan nada, y la respuesta de mi servidor va al puerto efímero…»)*
3. ¿Por qué es mejor "permitir el 5432 desde `sg-app`" que "permitir el 5432 desde `10.0.10.0/24`"? *(2 líneas. Empieza así: «Porque `sg-app` dice a quién se permite y no dónde está: si la app escala o cambia de IP… Con un CIDR, cualquier otra cosa en esa subred…»)*
4. **Repaso (clase 32, sin mirar):** ¿qué significan 502, 503 y 504 en un ALB? *(1–2 líneas. Empieza así: «502: el backend… 503:… 504:…»)*

Después, escríbeme `examíname clase-33`.

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

**Reto 3:** `reject 8080/tcp` e `insert 1`. Sí importa: en el orden equivocado, el `reject 8080` va antes que tu `allow`, y **tu PC también recibe el refused**. Con `insert 1`, el `allow from <tu PC>` queda el primero: tu PC llega a `miapp` y el resto recibe el rechazo.
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

[Clase 34 — Dos servidores: tu primera red](clase-34-dos-servidores.md)
