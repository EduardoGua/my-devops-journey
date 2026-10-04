# Clase 24 — Dos servidores: tu primera red

**Dónde:** tu PC + VMs `servidor-01` y `servidor-02` · **Tiempo:** 120 min · **Bloque:** C. Redes

> Esta clase cierra el bloque de redes. Junta todo: capas, IPs, puertos, rutas, DNS, HTTP y firewall, en una arquitectura de **dos niveles** como las de AWS.

## Objetivo

- Montar una arquitectura **web → backend** con dos servidores: el público y el privado.
- Aplicar **mínimo privilegio en red**: el backend solo acepta tráfico del servidor web.
- Usar **nombres** en lugar de IPs para conectar servicios.
- Practicar un **método de diagnóstico** repetible con averías que no conoces de antemano.

## Por qué importa

Es el patrón más común de la nube: un ALB o un proxy en la capa pública y la app o la base de datos en la privada, protegidas por security groups que solo aceptan tráfico de la capa anterior. Cuando se rompe, alguien tiene que encontrar **en qué salto** está el fallo. Esta clase es tu simulador de ese momento.

## La arquitectura

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

## Práctica guiada

### 1. Lanza el segundo servidor

Desde tu PC:
```bash
multipass launch lts --name servidor-02 --cpus 1 --memory 1G --disk 8G
multipass list
IP1=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
IP2=$(multipass info servidor-02 | awk '/IPv4/ {print $2}')
echo "servidor-01=$IP1  servidor-02=$IP2"
```

Antes de seguir, calcula **en papel** (clase 17): ¿están en la misma subred? ¿Necesitan un router para hablar entre ellas?

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

### 2. El backend en servidor-02

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
Description=Backend de la clase 24
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

### 3. Nombres en vez de IPs

Las IPs de las VMs pueden cambiar al recrearlas. En AWS, la IP privada de una instancia nueva también es otra. Usa nombres. Sin un DNS interno (en AWS sería una **zona privada de Route 53**), lo resolvemos con `/etc/hosts`:

```bash
# en servidor-01
echo "<IP2> backend.interno" | sudo tee -a /etc/hosts
getent hosts backend.interno
```

### 4. El firewall del backend: solo desde la web

En servidor-02:
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

Desde servidor-01 funciona; desde tu PC, **timeout**. Es lo que haría un `sg-backend` con origen `sg-web`.

### 5. La web hace de proxy

En servidor-01, sustituye el sitio de la API (clase 22) para que apunte al backend:
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

Tu petición viaja: **PC → servidor-01:80 (nginx) → servidor-02:8080 (backend) → vuelta**. Comprueba que el backend ve a servidor-01 como cliente, y no a tu PC:
```bash
ssh servidor-02 sudo journalctl -u backend -n 3 --no-pager
```

> ⚠️ nginx resuelve `backend.interno` **al arrancar o recargar**. Si cambias `/etc/hosts`, recarga nginx para que lo vea. En AWS pasa lo mismo con nombres de ALB o RDS cuyas IPs cambian. Es un clásico "funcionaba y dejó de funcionar".

### 6. Tu checklist de diagnóstico

Escribe esto en `notas/fase-1/clase-24-checklist.md`. Lo usarás en el proyecto P1 y en todo tu trabajo. Para "el cliente recibe un error de `api.lab`":

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

## Rómpelo: averías a ciegas

Copia el generador de averías a servidor-02, **sin leerlo**:
```bash
scp ~/my-devops-journey/recursos/clase-24/averia.sh servidor-02:
```

Para cada ronda:
1. En servidor-02: `sudo ./averia.sh`. Provoca **una** avería al azar entre cuatro posibles y no te dice cuál.
2. Desde tu PC, empieza por el paso 1 de tu checklist: `curl -sv -H "Host: api.lab" http://$IP1/`.
3. Sigue la checklist **en orden**, anotando cada comando y su resultado, hasta encontrar la causa. **Arréglala tú.**
4. Comprueba que `api.lab` vuelve a responder **200** desde tu PC.
5. Compara con `sudo ./averia.sh --solucion`.
6. `sudo ./averia.sh --reset` y otra ronda.

**Haz rondas hasta encontrar las 4 averías distintas.** Para cada una, anota en tus notas: síntoma en el cliente → pista decisiva → causa → arreglo.

### Averías extra, sin script

Provócalas tú y resuélvelas, o pide a alguien que las provoque:
- En servidor-01, cambia la IP de `backend.interno` en `/etc/hosts` por una que no existe (`10.255.0.99`) y recarga nginx.
- En servidor-01, cambia `proxy_pass` al puerto `8008` (errata).
- En servidor-02, `sudo chmod 700 /srv/backend && sudo chown root /srv/backend` y reinicia el backend.
- Para servidor-02 (`multipass stop servidor-02`). ¿Qué ve el cliente?

## Reto

1. Haz que `/salud` de `api.lab` compruebe **de verdad** el backend (`proxy_pass` a una ruta del backend), en lugar de responder `ok` directamente. ¿Qué devuelve cuando el backend está caído? ¿Por qué es mejor para un balanceador?
2. Añade un **segundo** backend: lanza `servidor-03` con el mismo servicio y configura en nginx un `upstream` con los dos. Para uno y comprueba que la web sigue respondiendo. (Pista: busca `upstream` en la documentación de nginx.) Acabas de construir un balanceador de carga casero.
3. Cuando termines, **para** las VMs que no uses: `multipass stop servidor-02 servidor-03`. La RAM de tu PC te lo agradecerá. Es la misma costumbre que en AWS.

## Cierre

En `notas/fase-1/clase-24.md`:

1. Dibuja la arquitectura con IPs, puertos y reglas de firewall reales, y su equivalente en AWS (subredes, SGs).
2. Para cada una de las 4 averías del script: síntoma visto desde el cliente y pista decisiva.
3. ¿Por qué es mejor que el backend acepte el 8080 solo de servidor-01, en lugar de "de toda la red"? ¿Qué ataque evita?
4. **Repaso (clase 23, sin mirar):** ¿qué diferencia hay entre DROP y REJECT, y qué síntoma da cada uno?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

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

**Reto 2 (pista de configuración):**
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
nginx reparte las peticiones (round robin) y, si un backend falla al conectar, reintenta con el otro.
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

## Fin del bloque C

Ya sabes cómo viaja una petición, cómo se direcciona y enruta, cómo se resuelve, se cifra y se filtra, y cómo diagnosticarla salto a salto. Esa es la base de cualquier VPC.

## Siguiente

[Clase 25 — Git por dentro](clase-25-git-por-dentro.md)
