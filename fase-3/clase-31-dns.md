# Clase 31 — DNS

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** A. Redes

> 💡 **La idea de hoy:** las personas y las configuraciones usan **nombres** (`api.tienda.com`), pero la red necesita **IPs**. El **DNS** traduce unos en otras: tu resolutor pregunta, de arriba abajo, hasta llegar al servidor que manda en ese dominio, y guarda la respuesta en **caché** el tiempo que diga su **TTL**. Cuando "por IP funciona y por nombre no", el problema es DNS.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - DNS es un protocolo de la capa de aplicación que va sobre UDP (clase 26, pieza 1, y clase 29, pieza 4).
> - `ping` por IP y `curl` por nombre (clases 26 y 29).
> - `sudo tee -a` para añadir una línea a un archivo de root (clase 10).
> - Hacer un snapshot de la VM antes de romper algo (clase 08).

> 🔤 **Palabras nuevas de hoy:**
> - **resolutor**: el servidor que busca la respuesta por ti (el de tu operador, `8.8.8.8` o el de la VPC).
> - **autoritativo**: el servidor que manda en un dominio; su respuesta es la verdad.
> - **registro**: cada dato de un dominio: `A` (IPv4), `CNAME` (alias), `MX` (correo)…
> - **TTL**: cuántos segundos se puede guardar una respuesta en caché.
> - **`dig`**: la herramienta para preguntar al DNS.
> - **`/etc/hosts`**: un archivo local con nombres e IPs que tu máquina consulta antes que el DNS.

## Objetivo

- Entender cómo se resuelve un nombre: resolutor, raíz, TLD, servidor **autoritativo** y **caché** (TTL).
- Conocer los registros: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS` y `PTR`.
- Usar `dig` como un profesional y saber cómo resuelve **Linux** (`/etc/hosts`, `systemd-resolved`).
- Diagnosticar un fallo de DNS y distinguirlo de un fallo de red.

## Por qué importa

Hay un dicho en operaciones: *"It's always DNS"*. Migraciones que "no funcionan" porque el TTL aún no expiró, servicios que no encuentran la base de datos por un nombre mal escrito, certificados que fallan por un CNAME… En AWS usarás **Route 53** para dominios públicos y **zonas privadas** para nombres internos, y cada balanceador, cada RDS y cada endpoint se usa **por nombre**, nunca por IP.

## Cómo va esta clase

Cuatro piezas. En cada una lees **una** idea (en la 3 y la 4, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Casi todo se hace en **tu PC**; el Rómpelo, en la VM.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min); el segundo, la **pieza 4**, el Rómpelo, el reto y el cierre.

## Las piezas

### Pieza 1 — Qué resuelve el DNS, y `dig`

Los humanos y las configuraciones usan **nombres** (`api.tienda.com`), pero la red necesita **IPs**. El DNS es como una guía telefónica, repartida por miles de servidores: das el nombre y te devuelve la IP. Las IPs cambian (un balanceador de AWS cambia sus IPs con el tiempo) y el nombre es lo estable.

`dig` le pregunta al DNS y te enseña la respuesta completa.

**Pruébalo.** En tu PC:

```bash
dig example.com
```

👀 **Qué deberías ver:** la sección `QUESTION` (qué preguntaste), la `ANSWER` (la respuesta: `example.com.  …  IN  A  <IP>`, con su **TTL** en la segunda columna) y, al final, `SERVER` (quién respondió, `127.0.0.53`) y `Query time`.

```bash
dig +short example.com
dig +noall +answer www.github.com
```

🔮 **Predice:** ¿qué tipo de registro devolverá `www.github.com`?

<details>
<summary>Compruébalo</summary>

`www.github.com` es un **CNAME** que apunta a `github.com`, que tiene el `A`. `dig` sigue la cadena por ti y te enseña las dos líneas.
</details>

✋ **Sin mirar:** ¿por qué se configura una app con el **nombre** de un balanceador de AWS y no con su IP?

<details>
<summary>Comprueba</summary>

Porque las IPs del balanceador cambian con el tiempo; el nombre siempre apunta a las actuales.
</details>

**En resumen:** el DNS traduce nombres en IPs; `dig nombre` pregunta y enseña la respuesta con su TTL.

### Pieza 2 — Los tipos de registro

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

**Pruébalo:**

```bash
dig +short MX gmail.com
dig +short TXT gmail.com
dig +short NS amazon.com            # Amazon usa Route 53 (awsdns)
dig +short AAAA google.com
dig +short -x 8.8.8.8               # inverso (PTR)
```

👀 **Qué deberías ver:** los servidores de correo de Gmail, cada uno con su prioridad (`5 gmail-smtp-in.l.google.com.`…); textos como `"v=spf1 …"`; servidores `ns-….awsdns-….` para Amazon; una IPv6 de Google; y `dns.google.` para `8.8.8.8`.

✋ **Sin mirar:** quieres que `www.tienda.com` lleve al mismo sitio que `tienda.com`. ¿Qué registro creas en `www`?

<details>
<summary>Comprueba</summary>

Un `CNAME`: `www.tienda.com → tienda.com`.
</details>

**En resumen:** `A` y `AAAA` dan IPs, `CNAME` es un alias, `MX` el correo, `TXT` textos, `NS` quién manda y `PTR` el inverso.

### Pieza 3 — El viaje de una consulta, y la caché

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

**Pruébalo, primero el viaje completo:**

```bash
dig +trace example.com
```

👀 **Qué deberías ver:** las tres etapas del dibujo: los servidores **raíz** (`.  IN NS a.root-servers.net.`…), los de **`.com`** (`… gtld-servers.net.`) y, al final, los **autoritativos** de `example.com` con la respuesta.

**Ahora, la caché:**

```bash
dig +noall +answer github.com
sleep 10
dig +noall +answer github.com
```

🔮 **Predice:** ¿qué le pasa al número de la segunda columna?

<details>
<summary>Compruébalo</summary>

El TTL **baja** unos 10 segundos: la segunda respuesta viene de la caché de tu resolutor local, que cuenta hacia atrás.
</details>

Compara con una pregunta directa a otros resolutores:

```bash
dig +noall +answer github.com @8.8.8.8
dig +noall +answer github.com @1.1.1.1
```

👀 **Qué deberías ver:** la misma IP, pero con TTL distintos: cada resolutor tiene su propia caché, y cada uno la guardó en un momento distinto.

✋ **Sin mirar:** cambias un registro que tenía TTL 3600. ¿Cuánto puede tardar alguien en ver el cambio?

<details>
<summary>Comprueba</summary>

Hasta una hora (3.600 segundos): lo que le quede de TTL a la respuesta que tiene en caché.
</details>

**En resumen:** el resolutor pregunta a la raíz, al TLD y al autoritativo, y guarda la respuesta durante su TTL; por eso los cambios tardan en verse.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — Cómo resuelve Linux, y el atajo de `/etc/hosts`

```
  programa (curl, python…) ──► /etc/nsswitch.conf  "hosts: files … dns"
                                 1) files → /etc/hosts
                                 2) dns   → /etc/resolv.conf → 127.0.0.53 (systemd-resolved) → servidores DNS reales
```

⚠️ **`dig` no lee `/etc/hosts`**: pregunta directamente a un servidor DNS. Para ver lo que verá **tu aplicación** usa `getent hosts nombre`, que sigue el mismo camino que los programas. Es una confusión muy común al depurar.

**Pruébalo, primero el resolutor de tu sistema:**

```bash
cat /etc/resolv.conf
resolvectl status | head -20
grep hosts /etc/nsswitch.conf
```

👀 **Qué deberías ver:** `nameserver 127.0.0.53` (es `systemd-resolved`, el resolutor local con caché); en `resolvectl`, los servidores DNS reales a los que reenvía (los de tu router u operador); y `hosts: files … dns`: primero `/etc/hosts`, después el DNS.

**Ahora, el atajo local.** En tu PC, da un nombre a tu VM:

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

<details>
<summary>Compruébalo</summary>

`getent` y `curl` lo encuentran (leen `/etc/hosts`); `dig` no devuelve nada (pregunta al DNS, que no conoce ese nombre).
</details>

`/etc/hosts` es útil para probar, por ejemplo, una web nueva **antes de cambiar el DNS real**. Pero si se olvida ahí, provoca fallos misteriosos: "en mi máquina va a otro servidor".

✋ **Sin mirar:** `dig` dice que `api.tienda.com` es `203.0.113.10`, pero tu `curl` llega a otro servidor. ¿Qué miras primero?

<details>
<summary>Comprueba</summary>

`/etc/hosts` (o `getent hosts api.tienda.com`): lo que ve la aplicación puede no ser lo que dice `dig`.
</details>

**En resumen:** las aplicaciones miran primero `/etc/hosts` y después el DNS; `getent hosts` enseña lo que ven ellas, y `dig`, solo lo que dice el DNS.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `dig nombre` · `dig +short nombre` | la respuesta completa · solo el resultado |
| `dig +noall +answer nombre` | solo la sección de respuesta, con su TTL |
| `dig +short MX dominio` · `TXT` · `NS` · `AAAA` | otros tipos de registro |
| `dig +short -x IP` | DNS inverso (PTR) |
| `dig +trace nombre` | el viaje completo: raíz, TLD y autoritativo |
| `dig nombre @8.8.8.8` | preguntar a un resolutor concreto |
| `getent hosts nombre` | lo que ve tu aplicación (incluye `/etc/hosts`) |
| `resolvectl status` · `sudo resolvectl flush-caches` | qué DNS usa tu sistema · vaciar su caché |

| Síntoma | Qué es |
|---------|--------|
| por IP funciona y por nombre no | DNS |
| `Could not resolve host` · `Name or service not known` · `Temporary failure in name resolution` | DNS |
| `dig` y la app no coinciden | `/etc/hosts` |

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

**2. Un `/etc/hosts` olvidado.** En la VM, añade `1.2.3.4 github.com` a `/etc/hosts` con `sudo tee -a`. Ejecuta `getent hosts github.com` y `curl -m 5 https://github.com`. Todo apunta a una IP equivocada, **solo en esta máquina**. Quítalo con `sudo sed -i '/github.com/d' /etc/hosts`. Ahora imagina ese error en una sola de veinte instancias de un Auto Scaling Group: así nacen los fallos intermitentes.

## Reto

En tu PC. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Qué TTL tiene el registro `A` de `amazon.com`? ¿Y el de `github.com`? ¿Por qué alguien elige un TTL corto?

> 🧩 **Ejemplo resuelto:**
> ```bash
> dig +noall +answer example.com
> ```
> La segunda columna es el TTL que le queda a esa respuesta, en segundos.

**Ahora tú, con huecos:** `dig +noall +answer ____` · `dig +noall +answer ____` → TTL de amazon.com: ____ · de github.com: ____

<details>
<summary>Pista</summary>

Pregunta varias veces: si el TTL baja, viene de caché; el valor «de verdad» es el más alto que veas, o el que da `dig +trace` al final. Un TTL corto permite cambiar de IP rápido (y volver atrás rápido), a cambio de más consultas.
</details>

**2.** ¿Qué servidores de correo tiene `outlook.com`? ¿Cuál se usa primero?

> 🧩 **Ejemplo resuelto:** `dig +short MX gmail.com` → líneas como `5 gmail-smtp-in.l.google.com.` y `10 alt1.gmail-smtp-in.l.google.com.`. Se prueba primero el de **menor** número.

**Ahora tú, con huecos:** `dig +short ____ outlook.com` → se usa primero el de prioridad ____

<details>
<summary>Pista</summary>

El tipo de registro del correo, y la regla del número más bajo.
</details>

**3.** Vas a mover `tienda.com` de un servidor viejo a un ALB nuevo. Ahora tiene TTL 86400. Ordena el plan para que el cambio sea rápido y reversible.

> 🧩 **Ejemplo resuelto:** si el registro **ya** tuviera TTL 60, el plan sería corto: probar el ALB, cambiar el registro, verificar, y si algo falla, volver a cambiarlo; en un minuto todo el mundo ve la marcha atrás.

**Ahora tú, con huecos:** ordena estos pasos (escribe las letras en orden) y completa la espera:
```
A. Cambiar el registro (en Route 53, un ALIAS al ALB).
B. Bajar el TTL de 86400 a 60.
C. Volver a subir el TTL y apagar el servidor viejo días después.
D. Esperar al menos ____ horas.
E. Probar el ALB nuevo directamente (por su nombre de AWS o con /etc/hosts).
F. Verificar con dig @8.8.8.8 y dig @1.1.1.1, y vigilar los logs de los dos servidores.
G. Si algo va mal, volver atrás: con TTL 60, en un minuto.

Orden: B, ____, ____, ____, ____, ____, ____
```

<details>
<summary>Pista</summary>

Las cachés guardaron la respuesta con el TTL **viejo**: hay que esperar a que caduque antes de que el TTL nuevo, el corto, mande. ¿Cuántas horas son 86400 segundos?
</details>

**4.** Al terminar la clase, ¿quitas `servidor-01.lab` de tu `/etc/hosts` o lo dejas para las clases 32 a 34?

> 🧩 **Ejemplo resuelto:** «Lo quito ahora con `sudo sed -i '/servidor-01.lab/d' /etc/hosts`, porque no quiero un nombre olvidado.»

**Ahora tú, con huecos:** «Decido ____ `servidor-01.lab` porque ____. Lo apunto en mi nota para ____.»

<details>
<summary>Pista</summary>

Las dos opciones valen. Lo importante es **saber** que está ahí: el Rómpelo 2 mostró qué pasa con una línea olvidada.
</details>

## Cierre

En `notas/fase-3/clase-31.md`:

1. Explica el camino de una consulta DNS, del resolutor al autoritativo. ¿Qué papel juega la caché? *(3 líneas. Empieza así: «La app pregunta al resolutor local; si no lo tiene en caché, el recursivo pregunta a un servidor raíz, que…, luego al TLD… y al autoritativo… La caché…»)*
2. ¿Qué es el TTL y por qué se baja **antes** de una migración y no durante? *(2 líneas. Empieza así: «El TTL es el tiempo que una respuesta puede… Se baja antes porque las cachés guardaron la respuesta con…»)*
3. Una app no conecta a `db.interna`. ¿Cómo distingues si es un problema de DNS o de red? ¿Por qué usarías `getent` y no solo `dig`? *(3 líneas. Empieza así: «Pruebo por IP con… y por nombre con… Si por IP conecta y el nombre no resuelve, es… Uso `getent` porque…»)*
4. **Repaso (clase 30, sin mirar):** ¿qué hace pública a una subred en AWS? *(1 línea. Empieza así: «Que su tabla de rutas tenga…»)*

Después, escríbeme `examíname clase-31`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La app pregunta al resolutor local. Si no lo tiene en caché, un resolutor recursivo pregunta a un servidor **raíz** (que le indica los del TLD), luego al **TLD** (`.com`, que le indica los autoritativos del dominio) y por último al **autoritativo**, que da la respuesta definitiva con un TTL. Cada resolutor guarda la respuesta en **caché** durante ese TTL, y así las siguientes consultas son inmediatas y no recorren la jerarquía.

**2.** El TTL es el tiempo (en segundos) que una respuesta puede guardarse en caché. Se baja **antes** porque las cachés del mundo guardaron el valor viejo **con el TTL viejo**: si lo bajas el mismo día del cambio, quien preguntó ayer seguirá con la IP vieja hasta que caduque su TTL largo. Se baja con antelación (al menos un TTL antiguo antes), se hace el cambio, se verifica y después se vuelve a subir.

**3.** Probar por **IP** (`nc -zv IP puerto`) y por **nombre** (`getent hosts db.interna`). Si por IP conecta y el nombre no resuelve (o resuelve a otra IP), es DNS. Si el nombre resuelve bien pero la IP no conecta, es red (security group, rutas, servicio). Se usa `getent` porque sigue el mismo camino que las aplicaciones, incluido `/etc/hosts`; `dig` pregunta solo al servidor DNS y puede darte una respuesta distinta de la que ve la app.

**4.** Que su tabla de rutas tenga `0.0.0.0/0` hacia un **Internet Gateway**.

**Reto:** 1) `dig +noall +answer amazon.com` y `dig +noall +answer github.com`; los valores cambian con el tiempo, y suelen ser cortos (de un minuto a unos pocos): así pueden cambiar de IP y volver atrás rápido. 2) `MX`; el de **menor** número de prioridad. 3) **Orden: B, D, E, A, F, G, C**, y la espera es de **24 horas** (86400 s, el TTL viejo). 4) Cualquiera de las dos, con su motivo y apuntada en la nota.
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

[Clase 32 — HTTP y HTTPS](clase-32-http-https.md)
