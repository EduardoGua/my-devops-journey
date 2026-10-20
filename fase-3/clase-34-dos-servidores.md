# Clase 34 — Dos servidores: tu primera red

**Dónde:** tu PC + VMs `servidor-01` y `servidor-02` · **Tiempo:** 120 min · **Bloque:** A. Redes

> Esta clase cierra el bloque de redes. Junta todo: capas, IPs, puertos, rutas, DNS, HTTP y firewall, en una arquitectura de **dos niveles** como las de AWS.

> 💡 **La idea de hoy:** la arquitectura más común de la nube tiene dos capas: una **pública**, que recibe las peticiones (un proxy o un balanceador), y una **privada**, con la app, que **solo** acepta tráfico de la capa pública. Cuando algo falla, se busca **salto a salto**, del cliente al backend, con una lista de comprobaciones que siempre sigues en el mismo orden.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Crear una VM con Multipass y entrar por SSH con tu llave y `~/.ssh/config` (clases 08 y 15).
> - Un servicio de systemd con su propio usuario (clase 12, pieza 3).
> - Misma subred o no (clase 27), `/etc/hosts` y `getent` (clase 31, pieza 4).
> - nginx como proxy inverso, y el 502 y el 504 (clase 32).
> - `ufw` con reglas desde un origen, y DROP frente a REJECT (clase 33).

> 🔤 **Palabras nuevas de hoy:**
> - **arquitectura de dos niveles**: una capa pública delante y una privada detrás.
> - **backend**: el servicio de la capa privada al que el proxy pasa las peticiones.
> - **upstream**: en nginx, el servidor (o servidores) de detrás.
> - **checklist de diagnóstico**: la lista de comprobaciones, en orden, para encontrar en qué salto está el fallo.
> - **movimiento lateral**: un atacante que entra en una máquina y desde ella salta a otras de la red.

## Objetivo

- Montar una arquitectura **web → backend** con dos servidores: el público y el privado.
- Aplicar **mínimo privilegio en red**: el backend solo acepta tráfico del servidor web.
- Usar **nombres** en lugar de IPs para conectar servicios.
- Practicar un **método de diagnóstico** repetible con averías que no conoces de antemano.

## Por qué importa

Es el patrón más común de la nube: un ALB o un proxy en la capa pública y la app o la base de datos en la privada, protegidas por security groups que solo aceptan tráfico de la capa anterior. Cuando se rompe, alguien tiene que encontrar **en qué salto** está el fallo. Esta clase es tu simulador de ese momento.

## Cómo va esta clase

Seis piezas que montan la arquitectura paso a paso, y un Rómpelo largo con averías a ciegas. En cada pieza lees **una** idea y la haces enseguida; no pases a la siguiente sin haber terminado la anterior. Trabajas en tres sitios (tu PC, `servidor-01` y `servidor-02`): mira el prompt antes de cada comando.

Es una clase larga: hazla en dos mañanas. El primer día, las **piezas 1 a 3** (unos 45 min); el segundo, las **piezas 4 a 6** y el Rómpelo. El reto y el cierre pueden ir a un tercer día.

## Las piezas

### Pieza 1 — La arquitectura, y el segundo servidor

```
   Tu PC (internet)
        │  HTTP :80
        ▼
 ┌─ servidor-01 ("capa pública") ─┐        ┌─ servidor-02 ("capa privada") ──┐
 │ nginx :80                      │  HTTP  │ backend :8080 (systemd)         │
 │   proxy_pass → backend:8080 ───┼───────►│ ufw: 8080 SOLO desde servidor-01│
 │ ufw: 22, 80                    │        │ ufw: 22                         │
 └────────────────────────────────┘        └─────────────────────────────────┘
   Equivale en AWS a: ALB/EC2 en subred pública ──► EC2 en subred privada
                      sg-web: 80 desde 0.0.0.0/0    sg-backend: 8080 desde sg-web
```

**Pruébalo: lanza el segundo servidor.** Desde tu PC:

```bash
multipass launch lts --name servidor-02 --cpus 1 --memory 1G --disk 8G
multipass list
IP1=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
IP2=$(multipass info servidor-02 | awk '/IPv4/ {print $2}')
echo "servidor-01=$IP1  servidor-02=$IP2"
```

👀 **Qué deberías ver:** las dos VMs en `Running`, cada una con su IPv4 `10.x.x.x`. Apunta las dos IPs: las necesitarás dentro de las VMs, donde estas variables no existen.

Antes de seguir, calcula **en papel** (clase 27): ¿están en la misma subred? ¿Necesitan un router para hablar entre ellas?

Comprueba que se ven: `multipass exec servidor-01 -- ping -c 2 $IP2`. Si no hay respuesta, aplica el arreglo de Docker de la pieza 3 de la clase 08.

Añade tu llave de laboratorio y una entrada en `~/.ssh/config` (como en la clase 15):

```bash
multipass exec servidor-02 -- bash -c "echo '$(cat ~/.ssh/lab_ed25519.pub)' >> ~/.ssh/authorized_keys"
cat >> ~/.ssh/config <<EOF

Host servidor-02
    HostName $IP2
    User ubuntu
    IdentityFile ~/.ssh/lab_ed25519
    IdentitiesOnly yes
EOF
ssh servidor-02 hostname
```

👀 **Qué deberías ver:** respuestas al `ping` y, al final, `servidor-02`.

✋ **Sin mirar:** las dos VMs están en la misma `/24` de Multipass. ¿Pasa su tráfico por tu PC como router?

<details>
<summary>Comprueba</summary>

No como router: están en la misma subred, así que se hablan directamente (ARP + MAC), aunque físicamente el puente `mpqemubr0` de tu PC las conecte.
</details>

**En resumen:** capa pública delante (servidor-01) y capa privada detrás (servidor-02), en la misma red, como dos subredes de una VPC.

### Pieza 2 — El backend, como servicio de systemd

El backend es un servicio como tu `miapp` de la clase 12: un usuario propio sin login, una unit de systemd y `Restart=on-failure`. Escucha en `0.0.0.0` porque tiene que recibir tráfico **de otra máquina** (clase 29).

**Pruébalo.** Entra en servidor-02:

```bash
ssh servidor-02
```

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin appsvc
sudo mkdir -p /srv/backend
echo '{"servicio":"backend","servidor":"servidor-02","estado":"ok"}' | sudo tee /srv/backend/index.html
sudo chown -R appsvc:appsvc /srv/backend

sudo tee /etc/systemd/system/backend.service <<'EOF'
[Unit]
Description=Backend de la clase 34
After=network-online.target

[Service]
User=appsvc
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 0.0.0.0 --directory /srv/backend
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now backend
curl -s 127.0.0.1:8080
```

👀 **Qué deberías ver:** `{"servicio":"backend","servidor":"servidor-02","estado":"ok"}`.

**En resumen:** el backend es un servicio de systemd con su propio usuario, escuchando en `0.0.0.0:8080`.

### Pieza 3 — Nombres en vez de IPs

Las IPs de las VMs pueden cambiar al recrearlas. En AWS, la IP privada de una instancia nueva también es otra. Usa nombres. Sin un DNS interno (en AWS sería una **zona privada de Route 53**), lo resolvemos con `/etc/hosts`.

**Pruébalo.** En **servidor-01** (cambia `<IP2>` por la IP de servidor-02 que apuntaste):

```bash
echo "<IP2> backend.interno" | sudo tee -a /etc/hosts
getent hosts backend.interno
curl -s -m 5 http://backend.interno:8080
```

👀 **Qué deberías ver:** `backend.interno` con la IP de servidor-02, y el JSON del backend: servidor-01 ya llega a él **por nombre**.

**En resumen:** los servicios se conectan por nombre; aquí con `/etc/hosts`, y en AWS con una zona privada de Route 53.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, en tu PC, vuelve a definir `IP1` e `IP2` (las dos líneas `multipass info` de la pieza 1).

### Pieza 4 — El firewall del backend: solo desde la web

Mínimo privilegio en red: el backend solo debe aceptar el 8080 **desde servidor-01**. Nadie más (ni tu PC) tiene por qué llegar a él directamente.

**Pruébalo.** En servidor-02 (cambia `<IP1>` por la IP de servidor-01):

```bash
sudo ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw allow from <IP1> to any port 8080 proto tcp
sudo ufw enable
sudo ufw status numbered
```

🔮 **Predice:** ¿qué pasará con cada una de estas pruebas?

```bash
# desde servidor-01
curl -s -m 5 http://backend.interno:8080

# desde tu PC
curl -s -m 5 http://$IP2:8080 || echo "FALLA desde mi PC"
```

<details>
<summary>Compruébalo</summary>

Desde servidor-01 funciona (el JSON); desde tu PC, **timeout** y `FALLA desde mi PC`. Es lo que haría un `sg-backend` con origen `sg-web`.
</details>

✋ **Sin mirar:** desde tu PC, ¿por qué el backend da timeout y no refused?

<details>
<summary>Comprueba</summary>

Porque `ufw` **descarta** (DROP) lo que no está permitido: tu PC no recibe ninguna respuesta.
</details>

**En resumen:** el backend acepta el 8080 solo desde la capa web; para todos los demás, timeout.

### Pieza 5 — La web hace de proxy

servidor-01 recibe las peticiones de `api.lab` y se las pasa al backend **por su nombre**.

**Pruébalo.** En servidor-01, sustituye el sitio de la API (clase 32) para que apunte al backend:

```bash
sudo tee /etc/nginx/sites-available/api <<'EOF'
server {
    listen 80;
    server_name api.lab;

    location = /salud { return 200 "ok\n"; }

    location / {
        proxy_pass http://backend.interno:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
EOF
sudo nginx -t && sudo systemctl reload nginx
```

Desde tu PC:

```bash
curl -s -H "Host: api.lab" http://$IP1/
```

👀 **Qué deberías ver:** el JSON de servidor-02. Tu petición viaja: **PC → servidor-01:80 (nginx) → servidor-02:8080 (backend) → vuelta**.

Comprueba que el backend ve a servidor-01 como cliente, y no a tu PC:

```bash
ssh servidor-02 sudo journalctl -u backend -n 3 --no-pager
```

👀 **Qué deberías ver:** las peticiones con la IP de **servidor-01** (`<IP1> - - [...] "GET / HTTP/1.0" 200 -`).

> ⚠️ nginx resuelve `backend.interno` **al arrancar o recargar**. Si cambias `/etc/hosts`, recarga nginx para que lo vea. En AWS pasa lo mismo con nombres de ALB o RDS cuyas IPs cambian. Es un clásico "funcionaba y dejó de funcionar".

✋ **Sin mirar:** cambias la IP de `backend.interno` en `/etc/hosts`, pero nginx sigue yendo a la vieja. ¿Qué te falta?

<details>
<summary>Comprueba</summary>

`sudo systemctl reload nginx`: nginx resolvió el nombre al arrancar y no se entera del cambio.
</details>

**En resumen:** el cliente solo ve la capa web; nginx pasa la petición al backend por su nombre, y el backend ve a nginx como cliente.

### Pieza 6 — Tu checklist de diagnóstico

Cuando una petición falla atravesando varias capas, se comprueba **salto a salto**, del cliente al backend, siempre en el mismo orden. Así no se salta ninguna capa y se llega a la causa por el camino corto.

**Pruébalo:** copia esta checklist en `notas/fase-3/clase-34-checklist.md` y ejecuta cada comando ahora, con todo funcionando, para saber qué aspecto tiene la respuesta **buena**. La usarás en el Rómpelo, en Vigía v0.2, en el P1 y en todo tu trabajo. Es para "el cliente recibe un error de `api.lab`":

```
DESDE EL CLIENTE
[ ] 1. ¿Qué devuelve exactamente?   curl -sv -H "Host: api.lab" http://IP1/   (código, tiempo, error)
       200 → no hay fallo · 502 → el backend falla · 504 → el backend tarda · timeout/refused → capa web

EN LA CAPA WEB (servidor-01)
[ ] 2. ¿nginx vivo y escuchando?    systemctl is-active nginx · ss -tlnp | grep :80
[ ] 3. ¿Qué dice nginx?             sudo tail /var/log/nginx/error.log   (refused / timed out / host not found)
[ ] 4. ¿Resuelve el nombre?         getent hosts backend.interno
[ ] 5. ¿Llega al puerto?            nc -zv -w3 backend.interno 8080      (refused vs timeout)
[ ] 6. ¿Responde la app?            curl -s -m5 http://backend.interno:8080

EN LA CAPA BACKEND (servidor-02)
[ ] 7. ¿Servicio vivo?              systemctl status backend · journalctl -u backend -n 30
[ ] 8. ¿Escucha dónde debe?         sudo ss -tlnp | grep python          (¿0.0.0.0? ¿8080?)
[ ] 9. ¿Responde en local?          curl -s 127.0.0.1:8080
[ ] 10. ¿Firewall?                  sudo ufw status numbered · journalctl -k | grep "UFW BLOCK"
```

👀 **Qué deberías ver:** con todo sano, `200` en el paso 1, `active` y el `:80` en el 2, un `error.log` sin errores nuevos en el 3, la IP de servidor-02 en el 4, `succeeded` en el 5, el JSON en el 6 y el 9, `active (running)` en el 7, `0.0.0.0:8080` en el 8, y tus reglas en el 10.

**En resumen:** del cliente al backend, salto a salto y siempre en el mismo orden: código, proxy, nombre, puerto, app, servicio, escucha y firewall.

## Tu chuleta de la clase

| Comando | Para qué |
|---------|----------|
| `multipass launch lts --name X …` · `multipass info X` | crear una VM · ver su IP |
| `curl -sv -H "Host: api.lab" http://IP1/` | el síntoma, desde el cliente |
| `sudo tail /var/log/nginx/error.log` | qué le pasó a nginx con el backend |
| `getent hosts backend.interno` | ¿resuelve el nombre? |
| `nc -zv -w3 backend.interno 8080` | ¿llega al puerto? (refused o timeout) |
| `systemctl status backend` · `sudo ss -tlnp` | ¿vivo? ¿escucha dónde debe? |
| `sudo ufw status numbered` · `journalctl -k \| grep "UFW BLOCK"` | ¿lo bloquea el firewall? |

| Desde el cliente | Apunta a |
|------------------|----------|
| refused, rápido | el **proceso**: parado, otra IP u otro puerto |
| timeout, lento | algo que **descarta**: firewall o SG, rutas, máquina caída |

## Rómpelo: averías a ciegas

Copia el generador de averías a servidor-02, **sin leerlo**:
```bash
scp ~/my-devops-journey/recursos/clase-34/averia.sh servidor-02:
```

Para cada ronda:
1. En servidor-02: `sudo ./averia.sh`. Provoca **una** avería al azar entre cuatro posibles y no te dice cuál.
2. Desde tu PC, empieza por el paso 1 de tu checklist: `curl -sv -H "Host: api.lab" http://$IP1/`.
3. Sigue la checklist **en orden**, anotando cada comando y su resultado, hasta encontrar la causa. **Arréglala tú.**
4. Comprueba que `api.lab` vuelve a responder **200** desde tu PC.
5. Compara con `sudo ./averia.sh --solucion`.
6. `sudo ./averia.sh --reset` y otra ronda.

**Haz rondas hasta encontrar las 4 averías distintas.** Para cada una, apunta en la tabla del cierre: síntoma en el cliente → pista decisiva.

### Averías extra, sin script

Provócalas tú y resuélvelas, o pide a alguien que las provoque:
- En servidor-01, cambia la IP de `backend.interno` en `/etc/hosts` por una que no existe (`10.255.0.99`) y recarga nginx.
- En servidor-01, cambia `proxy_pass` al puerto `8008` (errata).
- En servidor-02, `sudo chmod 700 /srv/backend && sudo chown root /srv/backend` y reinicia el backend.
- Para servidor-02 (`multipass stop servidor-02`). ¿Qué ve el cliente?

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Haz que `/salud` de `api.lab` compruebe **de verdad** el backend, en lugar de responder `ok` directamente. ¿Qué devuelve cuando el backend está caído? ¿Por qué es mejor para un balanceador?

> 🧩 **Ejemplo resuelto:** la `/salud` de la pieza 5 la responde nginx solo: `location = /salud { return 200 "ok\n"; }`. Con el backend parado, sigue diciendo `ok`.

**Ahora tú, con huecos:** en servidor-01, cambia esa línea por `location = /salud { ____ http://backend.interno:8080/; }`, recarga nginx y prueba `curl -s -o /dev/null -w "%{http_code}\n" -H "Host: api.lab" http://$IP1/salud` con el backend vivo y con `sudo systemctl stop backend` en servidor-02.

<details>
<summary>Pista</summary>

La directiva que pasa la petición al backend es la misma del `location /`. Con el backend parado, ¿qué código viste en la clase 32 cuando nginx no obtiene respuesta?
</details>

**2.** Añade un **segundo** backend: lanza `servidor-03` con el mismo servicio y configura en nginx un `upstream` con los dos. Para uno y comprueba que la web sigue respondiendo.

> 🧩 **Ejemplo resuelto:** un `upstream` con **un** solo servidor, que funciona igual que el `proxy_pass` de la pieza 5:
> ```nginx
> upstream backends {
>     server backend.interno:8080;
> }
> server {
>     # ...
>     location / { proxy_pass http://backends; }
> }
> ```
> El bloque `upstream` va **fuera** del `server`, al principio del archivo.

**Ahora tú, con huecos:** repite las piezas 1 a 4 para `servidor-03` (con su llave, su `backend.service` y su `ufw`), añade `<IP3> ____` al `/etc/hosts` de servidor-01, y deja el `upstream` así:
```nginx
upstream backends {
    server backend.interno:8080;
    server ____:8080;
}
```
Recarga nginx, para el backend de servidor-02 y repite `curl -s -H "Host: api.lab" http://$IP1/` varias veces.

<details>
<summary>Pista</summary>

El segundo nombre puede ser `backend2.interno`. Busca `upstream` en la documentación de nginx: reparte las peticiones entre los servidores y, si uno no acepta la conexión, prueba con el otro. Acabas de construir un balanceador de carga casero.
</details>

## Antes de cerrar: limpieza

- **Para** las VMs que no uses: `multipass stop servidor-02 servidor-03`. La RAM de tu PC te lo agradecerá. Es la misma costumbre que en AWS.
- Los snapshots ocupan disco. Lista los que tienes (`multipass list --snapshots`) y borra los que ya no necesites: `multipass delete --purge servidor-01.pre-rutas`. Conserva al menos uno reciente de cada VM.

## Cierre

En `notas/fase-3/clase-34.md`:

1. Completa la arquitectura con tus IPs, puertos y reglas reales, y su equivalente en AWS. *(Copia la plantilla y rellena los huecos.)*
   ```
   Tu PC → servidor-01 (IP ____, nginx en el :__, ufw: __ y __)
         → servidor-02 (IP ____, backend en el :____, ufw: 22, y 8080 solo desde ____)
   En AWS: servidor-01 = subred ____ con sg-web (80 desde ____)
           servidor-02 = subred ____ con sg-backend (8080 desde ____)
   ```
2. Para cada una de las 4 averías del script: síntoma visto desde el cliente y pista decisiva. *(Una fila por avería.)*
   ```
   | Avería | Desde el cliente | Pista decisiva |
   |--------|------------------|----------------|
   |        |                  |                |
   ```
3. ¿Por qué es mejor que el backend acepte el 8080 solo de servidor-01, en lugar de "de toda la red"? ¿Qué ataque evita? *(2 líneas. Empieza así: «Por mínimo privilegio en red: si otra máquina de la red cae en manos de un atacante… Evita el movimiento lateral…»)*
4. **Repaso (clase 33, sin mirar):** ¿qué diferencia hay entre DROP y REJECT, y qué síntoma da cada uno? *(2 líneas. Empieza así: «DROP descarta en silencio y da… REJECT…»)*

Después, escríbeme `examíname clase-34`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** servidor-01: su IP, nginx en el `:80`, ufw con `22` y `80`. servidor-02: su IP, backend en el `:8080`, ufw con `22` y `8080` solo desde la IP de servidor-01. En AWS: servidor-01 en una subred **pública**, con `sg-web` (80 desde `0.0.0.0/0`); servidor-02 en una subred **privada**, con `sg-backend` (8080 desde `sg-web`).

**2.** Las cuatro averías:
| Avería | Desde el cliente | Pista decisiva |
|--------|------------------|----------------|
| Servicio parado | `502` (rápido) | error.log: `Connection refused`. En servidor-02: `systemctl status backend` → inactive |
| Escucha en 127.0.0.1 | `502` (rápido) | `nc` desde servidor-01: refused. En servidor-02: `ss -tlnp` → `127.0.0.1:8080`, y `curl 127.0.0.1:8080` **sí** responde |
| Firewall DENY | `504`, tras esperar (o 502 con *timed out* al conectar) | error.log: `upstream timed out` / `Connection timed out`. `nc` desde servidor-01: **timeout**. `ufw status` y `[UFW BLOCK]` |
| Puerto 8081 | `502` (rápido) | refused en el 8080. `ss -tlnp` → escucha en `:8081` |

La clave: **refused** (rápido) apunta al **proceso** (parado, IP o puerto). **Timeout** (lento) apunta a algo que **descarta** paquetes (firewall o SG, rutas, máquina caída).

**3.** Por mínimo privilegio en red: si otra máquina de la red se ve comprometida (o un portátil en la misma VPN), no puede llegar al backend directamente y saltarse los controles de la capa web (autenticación, rate limit, logs). Reduce la **superficie de ataque** y el movimiento lateral.

**4.** DROP descarta en silencio y produce un **timeout**. REJECT responde con un rechazo inmediato: **connection refused**.

**Reto 1:** `proxy_pass`. Con el backend vivo, `200`; con el backend caído, **`502`**. Es mejor para un balanceador porque así deja de enviar tráfico a un servidor cuyo backend no funciona, en lugar de creer que está sano solo porque nginx responde.

**Reto 2:** `backend2.interno` en `/etc/hosts` y en el `upstream`:
```nginx
upstream backends {
    server backend.interno:8080;
    server backend2.interno:8080;
}
server {
    # ...
    location / { proxy_pass http://backends; }
}
```
nginx reparte las peticiones (round robin) y, si un backend falla al conectar, reintenta con el otro: con servidor-02 parado, todas las respuestas llegan de servidor-03.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| two-tier architecture | arquitectura de dos niveles |
| upstream | servidor de detrás (en nginx) |
| lateral movement | movimiento lateral (de un atacante) |
| attack surface | superficie de ataque |
| troubleshooting checklist | lista de diagnóstico |

🎙️ *"When a request fails through a proxy, I check hop by hop: the error code at the client, the proxy's error log, DNS resolution of the backend, the port, and finally the backend service itself."*

## Fin del bloque de redes

Ya sabes cómo viaja una petición, cómo se direcciona y enruta, cómo se resuelve, se cifra y se filtra, y cómo diagnosticarla salto a salto. Esa es la base de cualquier VPC. Ahora lo aplicas a Vigía (v0.2) y a los dos laboratorios integradores.

## Siguiente

[Clase 35 — Proyecto: Vigía v0.2](clase-35-vigia-v0.2.md)
