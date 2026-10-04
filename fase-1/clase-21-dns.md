# Clase 21 — DNS

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** C. Redes

## Objetivo

- Entender cómo se resuelve un nombre: resolutor, raíz, TLD, servidor **autoritativo** y **caché** (TTL).
- Conocer los registros: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS` y `PTR`.
- Usar `dig` como un profesional y saber cómo resuelve **Linux** (`/etc/hosts`, `systemd-resolved`).
- Diagnosticar un fallo de DNS y distinguirlo de un fallo de red.

## Por qué importa

Hay un dicho en operaciones: *"It's always DNS"*. Migraciones que "no funcionan" porque el TTL aún no expiró, servicios que no encuentran la base de datos por un nombre mal escrito, certificados que fallan por un CNAME… En AWS usarás **Route 53** para dominios públicos y **zonas privadas** para nombres internos, y cada balanceador, cada RDS y cada endpoint se usa **por nombre**, nunca por IP.

## Teoría

### Qué resuelve

Los humanos y las configuraciones usan **nombres** (`api.tienda.com`), pero la red necesita **IPs**. DNS es la guía telefónica distribuida de internet. Las IPs cambian (un balanceador de AWS cambia sus IPs con el tiempo) y el nombre es lo estable.

### El viaje de una consulta

```
  Tu app: "¿IP de www.ejemplo.com?"
     │
     ▼
  Resolutor LOCAL (systemd-resolved, 127.0.0.53) ── ¿lo tengo en caché? ── sí → responde
     │ no
     ▼
  Resolutor RECURSIVO (el de tu operador, 8.8.8.8, o en AWS el de la VPC: la IP .2)
     │  1. Pregunta a un servidor RAÍZ (.)            → "pregunta a los de .com"
     │  2. Pregunta a los servidores de .com (TLD)    → "pregunta a ns1.ejemplo.com"
     │  3. Pregunta al AUTORITATIVO de ejemplo.com    → "www = 93.184.215.14, TTL 300"
     ▼
  Guarda la respuesta en caché durante TTL segundos y responde
```

- El **autoritativo** es la fuente de la verdad de un dominio. En AWS, si usas Route 53, tu *hosted zone* es el autoritativo.
- El **TTL** (*time to live*) dice cuántos segundos puede guardarse la respuesta en caché. Si cambias un registro con TTL 86400, parte del mundo seguirá usando la IP vieja **hasta un día**. Por eso, **antes de una migración se baja el TTL** (a 60, por ejemplo) con antelación.

### Tipos de registro

| Tipo | Qué guarda | Ejemplo |
|------|------------|---------|
| `A` | nombre → IPv4 | `tienda.com → 203.0.113.10` |
| `AAAA` | nombre → IPv6 | `tienda.com → 2001:db8::10` |
| `CNAME` | nombre → **otro nombre** (alias) | `www.tienda.com → tienda.com` |
| `MX` | servidores de correo del dominio, con prioridad | `10 mail.tienda.com` |
| `TXT` | texto: verificaciones, SPF, DKIM | `"v=spf1 include:amazonses.com -all"` |
| `NS` | qué servidores son autoritativos | `ns-1447.awsdns-52.org` |
| `PTR` | IP → nombre (DNS inverso) | `10.113.0.203.in-addr.arpa → tienda.com` |
| `SOA` | datos de la zona | |

Un `CNAME` no puede estar en la **raíz** del dominio (`tienda.com`), solo en subdominios. Route 53 lo resuelve con registros **ALIAS**, que apuntan a un ALB o a CloudFront desde la raíz.

### Cómo resuelve Linux

```
  programa (curl, python…) ──► /etc/nsswitch.conf  "hosts: files … dns"
                                 1) files → /etc/hosts
                                 2) dns   → /etc/resolv.conf → 127.0.0.53 (systemd-resolved) → servidores DNS reales
```

⚠️ **`dig` no lee `/etc/hosts`**: pregunta directamente a un servidor DNS. Para ver lo que verá **tu aplicación** usa `getent hosts nombre`, que sigue el mismo camino que los programas. Es una confusión muy común al depurar.

## Práctica guiada

### 1. `dig` básico

En tu PC:
```bash
dig example.com
```

Lee las secciones: `QUESTION` (qué preguntaste), `ANSWER` (la respuesta con su **TTL**), y al final `SERVER` (quién respondió) y `Query time`.

```bash
dig +short example.com
dig +noall +answer www.github.com
```

🔮 **Predice:** ¿qué tipo de registro devolverá `www.github.com`?

`www.github.com` es un **CNAME** que apunta a `github.com`, que tiene el `A`. `dig` sigue la cadena por ti.

### 2. Otros tipos

```bash
dig +short MX gmail.com
dig +short TXT gmail.com
dig +short NS amazon.com            # Amazon usa Route 53 (awsdns)
dig +short AAAA google.com
dig +short -x 8.8.8.8               # inverso (PTR)
```

### 3. El viaje completo

```bash
dig +trace example.com
```

Verás las tres etapas de la teoría: los servidores **raíz** (`.`), los de **`.com`** y los **autoritativos** de `example.com`.

### 4. Caché y TTL

```bash
dig +noall +answer github.com
sleep 10
dig +noall +answer github.com
```

🔮 **Predice:** ¿qué le pasa al número de la segunda columna?

El TTL **baja**: la respuesta viene de una caché que cuenta hacia atrás. Compara con una pregunta directa a otro resolutor:
```bash
dig +noall +answer github.com @8.8.8.8
dig +noall +answer github.com @1.1.1.1
```

### 5. El resolutor de tu sistema

```bash
cat /etc/resolv.conf
resolvectl status | head -20
grep hosts /etc/nsswitch.conf
```

`resolv.conf` apunta a `127.0.0.53`: es `systemd-resolved`, el resolutor local con caché, que reenvía a los servidores DNS reales (los de tu operador, que aparecen en `resolvectl`).

### 6. `/etc/hosts`: el atajo local

En tu PC, da un nombre a tu VM:
```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
echo "$IP servidor-01.lab" | sudo tee -a /etc/hosts
```

🔮 **Predice** qué devolverá cada uno:
```bash
getent hosts servidor-01.lab
dig +short servidor-01.lab
curl -s http://servidor-01.lab | head -3
```

`getent` y `curl` lo encuentran (leen `/etc/hosts`); `dig` no. `/etc/hosts` es útil para probar, por ejemplo, una web nueva **antes de cambiar el DNS real**. Pero si se olvida ahí, provoca fallos misteriosos: "en mi máquina va a otro servidor".

## Rómpelo

Snapshot primero (desde tu PC): `multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-dns && multipass start servidor-01`.

**1. Un DNS que no responde.** En la VM:
```bash
IFACE=$(ip route | awk '/default/ {print $5; exit}')
GHIP=$(dig +short github.com | tail -1); echo "IP de GitHub: $GHIP"   # apúntala ANTES de romper el DNS
resolvectl status $IFACE | grep -i "dns server"
sudo resolvectl dns $IFACE 192.0.2.1          # una IP que no existe
sudo resolvectl flush-caches
```

🔮 **Predice** cuáles fallan y cuáles no:
```bash
curl -s -m 10 -o /dev/null -w "%{http_code}\n" https://github.com || echo "FALLA"
ping -c 2 -W 2 $GHIP
ping -c 2 -W 2 github.com
dig +short github.com
dig +short github.com @8.8.8.8
```

La **red funciona** (el ping por IP responde, y `dig @8.8.8.8` también), pero **los nombres no se resuelven**. El síntoma en las aplicaciones: `Could not resolve host`, `Name or service not known`, `Temporary failure in name resolution`. **Diagnóstico clave: si por IP funciona y por nombre no, es DNS.**

Restaura. `netplan apply` vuelve a aplicar la configuración de red de la VM, incluidos sus DNS (tu sesión puede congelarse un par de segundos):
```bash
sudo netplan apply
sudo resolvectl flush-caches
dig +short github.com
```
Si aun así no resuelve, restaura el snapshot `pre-dns`.

**2. Una caché que miente.** En la VM, añade `1.2.3.4 github.com` a `/etc/hosts` con `sudo tee -a`. Ejecuta `getent hosts github.com` y `curl -m 5 https://github.com`. Todo apunta a una IP equivocada, **solo en esta máquina**. Quítalo con `sudo sed -i '/github.com/d' /etc/hosts`. Ahora imagina ese error en una sola de veinte instancias de un Auto Scaling Group: así nacen los fallos intermitentes.

## Reto

1. ¿Qué TTL tiene el registro `A` de `amazon.com`? ¿Y el de `github.com`? ¿Por qué crees que alguien elige un TTL corto?
2. ¿Qué servidores de correo tiene `outlook.com`? ¿Cuál se usa primero?
3. Vas a mover `tienda.com` de un servidor viejo a un ALB nuevo. Ahora tiene TTL 86400. Escribe el plan **en orden**, con tiempos, para que el cambio sea rápido y reversible.
4. Al terminar la clase, **quita** `servidor-01.lab` de tu `/etc/hosts`… o déjalo a propósito y anótalo, porque lo usarás en las clases 22–24. Decide y escríbelo.

## Cierre

En `notas/fase-1/clase-21.md`:

1. Explica el camino de una consulta DNS, del resolutor al autoritativo. ¿Qué papel juega la caché?
2. ¿Qué es el TTL y por qué se baja **antes** de una migración y no durante?
3. Una app no conecta a `db.interna`. ¿Cómo distingues si es un problema de DNS o de red? ¿Por qué usarías `getent` y no solo `dig`?
4. **Repaso (clase 20, sin mirar):** ¿qué hace pública a una subred en AWS?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La app pregunta al resolutor local. Si no lo tiene en caché, un resolutor recursivo pregunta a un servidor **raíz** (que le indica los del TLD), luego al **TLD** (`.com`, que le indica los autoritativos del dominio) y por último al **autoritativo**, que da la respuesta definitiva con un TTL. Cada resolutor guarda la respuesta en **caché** durante ese TTL, y así las siguientes consultas son inmediatas y no recorren la jerarquía.

**2.** El TTL es el tiempo (en segundos) que una respuesta puede guardarse en caché. Se baja **antes** porque las cachés del mundo guardaron el valor viejo **con el TTL viejo**: si lo bajas el mismo día del cambio, quien preguntó ayer seguirá con la IP vieja hasta que caduque su TTL largo. Se baja con antelación (al menos un TTL antiguo antes), se hace el cambio, se verifica y después se vuelve a subir.

**3.** Probar por **IP** (`nc -zv IP puerto`) y por **nombre** (`getent hosts db.interna`). Si por IP conecta y el nombre no resuelve (o resuelve a otra IP), es DNS. Si el nombre resuelve bien pero la IP no conecta, es red (security group, rutas, servicio). Se usa `getent` porque sigue el mismo camino que las aplicaciones, incluido `/etc/hosts`; `dig` pregunta solo al servidor DNS y puede darte una respuesta distinta de la que ve la app.

**4.** Que su tabla de rutas tenga `0.0.0.0/0` hacia un **Internet Gateway**.

**Reto 3 (plan de migración):**
1. Días antes: bajar el TTL de `tienda.com` de 86400 a 60.
2. Esperar al menos 24 h (el TTL viejo) para que todas las cachés caduquen.
3. Probar el ALB nuevo directamente (por su nombre de AWS o con `/etc/hosts` en tu máquina).
4. Cambiar el registro (en Route 53, un ALIAS al ALB).
5. Verificar con `dig @8.8.8.8` y `dig @1.1.1.1` y vigilar los logs de ambos servidores.
6. Si algo va mal, volver atrás: con TTL 60, en un minuto se revierte.
7. Cuando todo esté estable, volver a subir el TTL y apagar el servidor viejo días después.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| name resolution | resolución de nombres |
| recursive resolver | resolutor recursivo |
| authoritative name server | servidor autoritativo |
| record (A, CNAME…) | registro |
| TTL (time to live) | tiempo de vida en caché |
| propagation | propagación |

🎙️ *"Before a DNS migration I lower the TTL at least one old TTL in advance, so the switch and a possible rollback both take effect quickly."*

## Siguiente

[Clase 22 — HTTP y HTTPS](clase-22-http-https.md)
