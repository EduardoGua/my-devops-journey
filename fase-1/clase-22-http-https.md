# Clase 22 — HTTP y HTTPS

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 120 min (puedes partirla en dos sesiones) · **Bloque:** C. Redes

## Objetivo

- Leer peticiones y respuestas HTTP: método, ruta, cabeceras, cuerpo y **código de estado**.
- Interpretar los códigos que verás en producción, en especial **502, 503 y 504**.
- Configurar nginx con **dos sitios** en la misma IP (cabecera `Host`) y como **proxy inverso** delante de una app.
- Entender **TLS**: certificados, autoridades de certificación y qué comprueba el cliente. Montar HTTPS con un certificado propio.

## Por qué importa

Casi todo lo que desplegarás habla HTTP: webs, APIs, health checks y los propios servicios de AWS, cuya API es HTTPS. Un **Application Load Balancer** es, en el fondo, un nginx gestionado: hace de proxy inverso, termina TLS con certificados de **ACM**, enruta por `Host` y ruta, y devuelve 502, 503 o 504 cuando tu app falla. Si entiendes esta clase, entenderás el ALB.

## Teoría

### Petición y respuesta

```
PETICIÓN (cliente → servidor)                 RESPUESTA (servidor → cliente)
─────────────────────────────                  ──────────────────────────────
GET /api/productos?id=7 HTTP/1.1               HTTP/1.1 200 OK
Host: tienda.com                               Content-Type: application/json
User-Agent: curl/8.5.0                         Content-Length: 42
Accept: application/json                       Cache-Control: max-age=60
                                               
(cuerpo vacío en un GET)                       {"id":7,"nombre":"Taza","precio":9.5}
```

Es **texto** (en HTTP/1.1) sobre TCP, como viste con `nc` en la clase 19.

### Métodos

| Método | Uso | ¿Idempotente? |
|--------|-----|---------------|
| `GET` | leer | sí |
| `POST` | crear o ejecutar una acción | **no** |
| `PUT` | reemplazar | sí |
| `PATCH` | modificar en parte | no necesariamente |
| `DELETE` | borrar | sí |
| `HEAD` | como GET, solo cabeceras | sí |

*Idempotente* = repetirlo da el mismo resultado. Importa para los **reintentos**: reintentar un `GET` es seguro; reintentar un `POST /pagar` puede cobrar dos veces.

### Códigos de estado

| Código | Significado | Quién tiene el problema |
|--------|-------------|-------------------------|
| **200** OK · **201** Created · **204** No Content | éxito | — |
| **301** / **308** permanente · **302** / **307** temporal | redirección (mira `Location:`) | — |
| **304** Not Modified | usa tu caché | — |
| **400** Bad Request | petición mal formada | cliente |
| **401** Unauthorized | **no autenticado** (¿quién eres?) | cliente |
| **403** Forbidden | **no autorizado** (sé quién eres, pero no puedes) | cliente / permisos |
| **404** Not Found | no existe | cliente / ruta |
| **429** Too Many Requests | límite de peticiones | cliente |
| **500** Internal Server Error | la app falló | **tu app** |
| **502** Bad Gateway | el proxy **no obtuvo respuesta válida** del backend (caído, conexión rechazada) | **backend** detrás del proxy/ALB |
| **503** Service Unavailable | no hay backend disponible (sin destinos sanos, mantenimiento) | **capacidad / salud** |
| **504** Gateway Timeout | el backend **tardó demasiado** | **backend lento** |

Los 5xx de un ALB te dicen **dónde** buscar: 502 → la app está caída o cierra conexiones; 503 → el target group no tiene destinos sanos; 504 → la app o la base de datos van lentas.

### Cabeceras importantes

| Cabecera | Para qué |
|----------|----------|
| `Host` | **qué sitio** quieres. Permite servir muchos dominios desde una sola IP (*virtual hosts*) |
| `Content-Type` | formato del cuerpo (`text/html`, `application/json`) |
| `Location` | a dónde redirige (con 3xx) |
| `Cache-Control` | cuánto tiempo puede cachearse (CDNs como CloudFront) |
| `X-Forwarded-For` | la IP **real** del cliente cuando hay un proxy o ALB delante |
| `Authorization` | credenciales (un token) |

### Proxy inverso

```
 Cliente ──HTTP──► nginx :80 (proxy inverso) ──HTTP──► app :8080 (solo en localhost o red privada)
                   · termina TLS
                   · enruta por Host y ruta
                   · añade X-Forwarded-For
                   · devuelve 502/504 si la app falla
```

### HTTPS = HTTP dentro de TLS

TLS aporta tres cosas:
1. **Cifrado**: nadie en el camino puede leer el contenido (recuerda el `tcpdump -A` de la clase 16).
2. **Integridad**: nadie puede modificarlo sin que se note.
3. **Autenticidad**: el servidor demuestra que **es** `tienda.com` con un **certificado**.

Un **certificado** contiene un nombre (`tienda.com`, en el campo SAN), la clave pública del servidor, unas fechas de validez y la **firma de una autoridad de certificación** (CA). Tu sistema confía en una lista de CAs (`/etc/ssl/certs`). El cliente comprueba que:
- la cadena de firmas llega a una CA en la que confía,
- el nombre coincide con el que pidió,
- no ha caducado.

Si algo falla: `certificate verify failed`, `NET::ERR_CERT_…`. **Un certificado caducado tumba un servicio igual que un servidor apagado**, y es de las caídas más evitables.

En AWS: **ACM** emite certificados gratis para el ALB y CloudFront, y los **renueva solo**. Fuera de AWS, **Let's Encrypt** (`certbot`).

## Práctica guiada

En tu PC: `IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')`.

### 1. `curl` como navaja suiza

```bash
curl -s http://$IP/ | head -5                 # cuerpo
curl -I http://$IP/                           # solo cabeceras (HEAD)
curl -v http://$IP/ 2>&1 | grep -E '^[<>]'    # > petición  < respuesta
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" http://$IP/
curl -s -o /dev/null -w "%{http_code}\n" http://$IP/no-existe
curl -sI http://github.com | head -5          # una redirección real
curl -sIL http://github.com | grep -iE "^(HTTP|location)"   # -L sigue redirecciones
```

### 2. Dos sitios en la misma IP

En la VM (`ssh servidor-01`):
```bash
sudo mkdir -p /var/www/tienda /var/www/blog
echo "<h1>TIENDA</h1>" | sudo tee /var/www/tienda/index.html
echo "<h1>BLOG</h1>"   | sudo tee /var/www/blog/index.html

sudo tee /etc/nginx/sites-available/tienda <<'EOF'
server {
    listen 80;
    server_name tienda.lab;
    root /var/www/tienda;
}
EOF
sudo tee /etc/nginx/sites-available/blog <<'EOF'
server {
    listen 80;
    server_name blog.lab;
    root /var/www/blog;
}
EOF
sudo ln -s /etc/nginx/sites-available/tienda /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/blog /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

🔮 **Predice:** desde tu PC, ¿qué devolverá cada línea si **solo cambia la cabecera `Host`**?

```bash
curl -s -H "Host: tienda.lab" http://$IP/
curl -s -H "Host: blog.lab"   http://$IP/
curl -s -H "Host: otro.lab"   http://$IP/ | head -3
curl -s http://$IP/ | head -3
```

Misma IP, mismo puerto, **distinto sitio según `Host`**. Si ningún `server_name` coincide, nginx usa el sitio por defecto. Así funcionan el hosting compartido y las reglas por *host* de un ALB.

> ⚠️ Trampa real: si pruebas **dentro de la VM** con `curl -H "Host: tienda.lab" localhost`, quizá te responda el sitio por defecto. `localhost` puede resolverse primero a `::1` (IPv6). El sitio por defecto escucha en IPv6 (`listen [::]:80`) y los tuyos solo en IPv4 (`listen 80`). Usa `127.0.0.1`, o añade `listen [::]:80;` a tus sitios. Es el tipo de detalle que cuesta una tarde de depuración.

### 3. Proxy inverso delante de `miapp`

En la VM:
```bash
sudo tee /etc/nginx/sites-available/api <<'EOF'
server {
    listen 80;
    server_name api.lab;

    location / {
        # 127.0.0.1 y no "localhost", por lo mismo que en el aviso anterior
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 3s;
    }
}
EOF
sudo ln -s /etc/nginx/sites-available/api /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Desde tu PC:
```bash
curl -s -H "Host: api.lab" http://$IP/
```

La respuesta viene de `miapp` (puerto 8080) **a través de** nginx.

## Rómpelo: fabrica tus propios 5xx

**1. 502 Bad Gateway: el backend está caído.**
```bash
ssh servidor-01 sudo systemctl stop miapp
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: api.lab" http://$IP/
ssh servidor-01 sudo tail -2 /var/log/nginx/error.log
```
Lee el error: `connect() failed (111: Connection refused) while connecting to upstream`. nginx llegó al puerto 8080 y nadie respondía. **Un 502 no es un fallo de nginx: es de lo que hay detrás.**
```bash
ssh servidor-01 sudo systemctl start miapp
```

**2. 504 Gateway Timeout: el backend es lento.**
En la VM, en otra sesión, sustituye temporalmente `miapp` por una app que tarda 10 segundos:
```bash
sudo systemctl stop miapp
python3 - <<'EOF'
import http.server, time
class Lenta(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(10)
        self.send_response(200); self.end_headers(); self.wfile.write(b"por fin\n")
http.server.HTTPServer(("127.0.0.1", 8080), Lenta).serve_forever()
EOF
```
Desde tu PC:
```bash
curl -s -o /dev/null -w "%{http_code} en %{time_total}s\n" -H "Host: api.lab" http://$IP/
```
`504` en unos 3 segundos: el `proxy_read_timeout` de nginx se agotó. En un ALB el equivalente es el *idle timeout*. Para la app lenta con `Ctrl+C` y `sudo systemctl start miapp`.

**3. 403: permisos de archivo.**
```bash
ssh servidor-01 sudo chmod 600 /var/www/blog/index.html
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: blog.lab" http://$IP/
ssh servidor-01 sudo tail -1 /var/log/nginx/error.log
ssh servidor-01 sudo chmod 644 /var/www/blog/index.html
```
Los workers de nginx (`www-data`, clase 11) no pueden leer el archivo: `Permission denied` en el log y un **403** para el cliente. Todo encaja con las clases 06 y 11.

## HTTPS con tu propio certificado

### 4. Un certificado autofirmado

En la VM:
```bash
sudo openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout /etc/ssl/private/tienda.key -out /etc/ssl/certs/tienda.crt \
  -subj "/CN=tienda.lab" -addext "subjectAltName=DNS:tienda.lab"
sudo chmod 600 /etc/ssl/private/tienda.key
openssl x509 -in /etc/ssl/certs/tienda.crt -noout -subject -issuer -dates -ext subjectAltName
```

"Autofirmado" = el emisor (*issuer*) es **él mismo**: ninguna CA lo respalda. Sirve para laboratorios, no para producción.

Añade HTTPS al sitio de la tienda:
```bash
sudo tee /etc/nginx/sites-available/tienda <<'EOF'
server {
    listen 80;
    server_name tienda.lab;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name tienda.lab;
    ssl_certificate     /etc/ssl/certs/tienda.crt;
    ssl_certificate_key /etc/ssl/private/tienda.key;
    root /var/www/tienda;
}
EOF
sudo nginx -t && sudo systemctl reload nginx
```

### 5. Lo que comprueba el cliente

En tu PC (`--resolve` hace de `/etc/hosts` solo para ese comando):
```bash
curl -sI --resolve tienda.lab:80:$IP http://tienda.lab/ | grep -iE "^(HTTP|location)"
curl -s --resolve tienda.lab:443:$IP https://tienda.lab/
```

🔮 **Predice:** ¿funcionará el segundo?

Falla con `SSL certificate problem: self-signed certificate`: tu PC **no confía** en ese emisor.

```bash
curl -sk --resolve tienda.lab:443:$IP https://tienda.lab/          # -k: no verificar (¡solo para probar!)
scp servidor-01:/etc/ssl/certs/tienda.crt /tmp/tienda.crt
curl -s --cacert /tmp/tienda.crt --resolve tienda.lab:443:$IP https://tienda.lab/   # confía en ese cert concreto
curl -s --cacert /tmp/tienda.crt --resolve otra.lab:443:$IP https://otra.lab/       # nombre que no coincide
```

El último falla aunque confíes en el certificado: el **nombre** no coincide. Las tres comprobaciones (cadena, nombre y fecha) son independientes.

> `curl -k` o `verify=False` "para que funcione" desactiva la autenticidad: cualquiera en el camino podría suplantar al servidor. En código de producción **no se usa**.

### 6. Un certificado real

```bash
echo | openssl s_client -connect github.com:443 -servername github.com 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

Mira el emisor (una CA real) y la fecha `notAfter`. Esta línea es la base de cualquier monitor de **caducidad de certificados**.

## Reto

1. Añade a `api.lab` una ruta `/salud` que nginx responda directamente con `200` y el texto `ok`, sin llamar a la app (pista: `location = /salud { return 200 "ok\n"; }`). Es un *health check* de nivel proxy. ¿Qué limitación tiene frente a uno que llama a la app?
2. ¿Cuántos días le quedan al certificado de `amazon.com`?
3. Haz que `miapp` vea la IP real del cliente: ¿qué cabecera llega? Captúrala con `sudo tcpdump -i lo -A port 8080` en la VM mientras haces un `curl` desde tu PC.
4. Explica qué código esperarías del ALB en cada caso: (a) tu app devuelve una excepción no controlada; (b) ninguna instancia pasa el health check; (c) la consulta a la base de datos tarda 70 s.

## Cierre

En `notas/fase-1/clase-22.md`:

1. Diferencia entre 401 y 403, y entre 502, 503 y 504. ¿Dónde mirarías primero en cada uno?
2. ¿Cómo sabe nginx qué sitio servir si `tienda.lab` y `blog.lab` comparten IP y puerto?
3. ¿Qué comprueba un cliente al conectar por HTTPS? ¿Por qué `curl -k` es peligroso fuera de un laboratorio?
4. **Repaso (clase 21, sin mirar):** ¿por qué `dig` y `getent` pueden dar respuestas distintas para el mismo nombre?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **401**: no autenticado; falta la credencial o es inválida. **403**: autenticado (o anónimo), pero sin permiso para ese recurso; también nginx sin permiso de lectura en el archivo. **502**: el proxy o el ALB no obtuvo una respuesta válida del backend (caído, conexión rechazada, se cerró a mitad) → mirar si la app está viva, su puerto y sus logs. **503**: no hay backend disponible → health checks del target group y capacidad. **504**: el backend no respondió a tiempo → lentitud de la app, de la base de datos o de una dependencia, y los timeouts.

**2.** Por la cabecera **`Host`** de la petición HTTP: nginx la compara con los `server_name` de sus bloques `server` y sirve el que coincide (o el de por defecto si no coincide ninguno). Con HTTPS, el nombre llega además antes del cifrado mediante **SNI**, para elegir el certificado.

**3.** Que el certificado esté firmado por una cadena que termina en una **CA de confianza**, que el **nombre** pedido coincida con el del certificado (SAN) y que esté **dentro de sus fechas** de validez. `-k` desactiva esas comprobaciones: el canal sigue cifrado, pero **no sabes con quién hablas**, así que un atacante en el camino podría hacerse pasar por el servidor (*man-in-the-middle*) y leerlo todo.

**4.** `dig` pregunta directamente a un servidor DNS e ignora `/etc/hosts`. `getent` sigue el orden de `/etc/nsswitch.conf` (primero `/etc/hosts`, después DNS), igual que las aplicaciones.

**Reto:** 1) Solo demuestra que **nginx** responde, no que la app ni la base de datos funcionen. Un buen health check llama a un endpoint de la app que comprueba sus dependencias críticas. 2) `echo | openssl s_client -connect amazon.com:443 -servername amazon.com 2>/dev/null | openssl x509 -noout -enddate`. 3) `X-Forwarded-For: <IP de tu PC>`. 4) (a) **500** si la app devuelve el error (o **502** si la app se cae y cierra la conexión); (b) **503**; (c) **504** (el idle timeout por defecto del ALB es de 60 s).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| request / response | petición / respuesta |
| status code | código de estado |
| reverse proxy | proxy inverso |
| upstream / backend | servidor de detrás |
| TLS termination | terminación TLS |
| certificate authority (CA) | autoridad de certificación |
| health check | comprobación de salud |

🎙️ *"A 502 from the load balancer means the backend failed or refused the connection; a 503 means there are no healthy targets; a 504 means the backend was too slow."*

## Siguiente

[Clase 23 — Firewall](clase-23-firewall.md)
