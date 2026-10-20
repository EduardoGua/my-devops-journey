# Clase 32 — HTTP y HTTPS

**Dónde:** tu PC + VM `servidor-01` · **Tiempo:** 120 min (puedes partirla en dos sesiones) · **Bloque:** A. Redes

> 💡 **La idea de hoy:** HTTP es una **petición** de texto (método, ruta y cabeceras) y una **respuesta** con un **código de estado** que dice qué pasó: los 2xx van bien, los 4xx son culpa del cliente y los 5xx, del servidor. Delante de las apps se pone un **proxy inverso** (nginx, un ALB) que elige el sitio por la cabecera `Host` y devuelve 502 o 504 cuando la app falla. **HTTPS** es lo mismo, dentro de TLS: cifrado, y un **certificado** que demuestra con quién hablas.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - HTTP es texto sobre TCP: lo escribiste a mano con `nc` (clase 29, pieza 3).
> - `curl -v`: las líneas `>` son la petición y las `<` la respuesta (clase 26, pieza 4).
> - nginx: sus sitios en `/etc/nginx`, sus logs en `/var/log/nginx/` y sus workers como `www-data` (clases 10, 11 y 13).
> - Tu `miapp` en el puerto 8080, con `systemctl stop|start miapp` (clase 12).
> - Los permisos `644` y `600`, y lo que pasa sin la `r` (clase 06).

> 🔤 **Palabras nuevas de hoy:**
> - **método**: lo que pides hacer: `GET` (leer), `POST` (crear), `DELETE` (borrar)…
> - **código de estado**: el número de la respuesta: `200`, `404`, `502`…
> - **cabecera**: un dato de la petición o de la respuesta, como `Host` o `Content-Type`.
> - **proxy inverso**: el servidor que recibe las peticiones y se las pasa a la app de detrás.
> - **TLS**: la capa que cifra HTTP y autentica al servidor; HTTP + TLS = HTTPS.
> - **certificado**: el documento firmado por una **autoridad de certificación (CA)** que dice «este servidor es `tienda.com`».

## Objetivo

- Leer peticiones y respuestas HTTP: método, ruta, cabeceras, cuerpo y **código de estado**.
- Interpretar los códigos que verás en producción, en especial **502, 503 y 504**.
- Configurar nginx con **dos sitios** en la misma IP (cabecera `Host`) y como **proxy inverso** delante de una app.
- Entender **TLS**: certificados, autoridades de certificación y qué comprueba el cliente. Montar HTTPS con un certificado propio.

## Por qué importa

Casi todo lo que desplegarás habla HTTP: webs, APIs, health checks y los propios servicios de AWS, cuya API es HTTPS. Un **Application Load Balancer** es, en el fondo, un nginx gestionado: hace de proxy inverso, termina TLS con certificados de **ACM**, enruta por `Host` y ruta, y devuelve 502, 503 o 504 cuando tu app falla. Si entiendes esta clase, entenderás el ALB.

## Cómo va esta clase

Seis piezas y un Rómpelo en el que fabricas tus propios errores 5xx. En cada pieza lees **una** idea (en la 1, dos que van juntas) y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Necesitas una terminal en tu PC y otra en la VM (`ssh servidor-01`).

Es una clase larga: hazla en dos mañanas. El primer día, las **piezas 1 a 3** (unos 55 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

En **tu PC** (repítelo el segundo día):

```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}'); echo $IP
```

## Las piezas

### Pieza 1 — Petición y respuesta, y los métodos

```
PETICIÓN (cliente → servidor)                 RESPUESTA (servidor → cliente)
─────────────────────────────                  ──────────────────────────────
GET /api/productos?id=7 HTTP/1.1               HTTP/1.1 200 OK
Host: tienda.com                               Content-Type: application/json
User-Agent: curl/8.5.0                         Content-Length: 42
Accept: application/json                       Cache-Control: max-age=60
                                               
(cuerpo vacío en un GET)                       {"id":7,"nombre":"Taza","precio":9.5}
```

Es **texto** (en HTTP/1.1) sobre TCP, como viste con `nc` en la clase 29. La primera palabra de la petición es el **método**:

| Método | Uso | ¿Idempotente? |
|--------|-----|---------------|
| `GET` | leer | sí |
| `POST` | crear o ejecutar una acción | **no** |
| `PUT` | reemplazar | sí |
| `PATCH` | modificar en parte | no necesariamente |
| `DELETE` | borrar | sí |
| `HEAD` | como GET, solo cabeceras | sí |

*Idempotente* = repetirlo da el mismo resultado. Importa para los **reintentos**: reintentar un `GET` es seguro; reintentar un `POST /pagar` puede cobrar dos veces.

**Pruébalo**, desde tu PC, contra el nginx de la VM:

```bash
curl -s http://$IP/ | head -5                 # cuerpo
curl -I http://$IP/                           # solo cabeceras (HEAD)
curl -v http://$IP/ 2>&1 | grep -E '^[<>]'    # > petición  < respuesta
```

👀 **Qué deberías ver:** el principio del HTML de bienvenida; después, solo las cabeceras (`HTTP/1.1 200 OK`, `Server: nginx/…`, `Content-Type: text/html`); y, con `-v`, la petición (`> GET / HTTP/1.1`, `> Host: …`) y la respuesta (`< HTTP/1.1 200 OK`…).

✋ **Sin mirar:** ¿por qué reintentar un `GET` es seguro y reintentar un `POST /pagar` no?

<details>
<summary>Comprueba</summary>

Porque `GET` es idempotente (repetirlo da lo mismo) y `POST` no: repetirlo puede crear un segundo pago.
</details>

**En resumen:** una petición es método + ruta + cabeceras (+ cuerpo); `GET` lee y es seguro de repetir, `POST` no.

### Pieza 2 — Los códigos de estado

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

Los 5xx de un ALB te dicen **dónde** buscar: 502 → la app está caída o cierra conexiones; 503 → el target group no tiene destinos sanos; 504 → la app o la base de datos van lentas. Los fabricarás tú en el Rómpelo.

**Pruébalo:**

```bash
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" http://$IP/
curl -s -o /dev/null -w "%{http_code}\n" http://$IP/no-existe
curl -sI http://github.com | head -5          # una redirección real
curl -sIL http://github.com | grep -iE "^(HTTP|location)"   # -L sigue redirecciones
```

👀 **Qué deberías ver:** `200` con el tiempo que tardó; `404`; `HTTP/1.1 301 Moved Permanently` con `Location: https://github.com/`; y, con `-L`, el `301` seguido del `200` de la página nueva.

✋ **Sin mirar:** recibes un `301`. ¿Qué cabecera miras para saber a dónde te manda?

<details>
<summary>Comprueba</summary>

`Location`.
</details>

**En resumen:** 2xx bien, 3xx redirección (mira `Location`), 4xx culpa del cliente y 5xx del servidor; 502, 503 y 504 dicen qué falla detrás del proxy.

### Pieza 3 — Las cabeceras, y `Host`: dos sitios en la misma IP

| Cabecera | Para qué |
|----------|----------|
| `Host` | **qué sitio** quieres. Permite servir muchos dominios desde una sola IP (*virtual hosts*) |
| `Content-Type` | formato del cuerpo (`text/html`, `application/json`) |
| `Location` | a dónde redirige (con 3xx) |
| `Cache-Control` | cuánto tiempo puede cachearse (CDNs como CloudFront) |
| `X-Forwarded-For` | la IP **real** del cliente cuando hay un proxy o ALB delante |
| `Authorization` | credenciales (un token) |

**Pruébalo: dos sitios en la misma IP.** En la VM:

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

👀 **Qué deberías ver:** `syntax is ok` y `test is successful` en el `nginx -t`.

🔮 **Predice:** desde tu PC, ¿qué devolverá cada línea si **solo cambia la cabecera `Host`**?

```bash
curl -s -H "Host: tienda.lab" http://$IP/
curl -s -H "Host: blog.lab"   http://$IP/
curl -s -H "Host: otro.lab"   http://$IP/ | head -3
curl -s http://$IP/ | head -3
```

<details>
<summary>Compruébalo</summary>

`<h1>TIENDA</h1>`, `<h1>BLOG</h1>`, y en los dos últimos, la página de bienvenida de nginx.
</details>

Misma IP, mismo puerto, **distinto sitio según `Host`**. Si ningún `server_name` coincide, nginx usa el sitio por defecto. Así funcionan el hosting compartido y las reglas por *host* de un ALB.

> ⚠️ Trampa real: si pruebas **dentro de la VM** con `curl -H "Host: tienda.lab" localhost`, quizá te responda el sitio por defecto. `localhost` puede resolverse primero a `::1` (IPv6). El sitio por defecto escucha en IPv6 (`listen [::]:80`) y los tuyos solo en IPv4 (`listen 80`). Usa `127.0.0.1`, o añade `listen [::]:80;` a tus sitios. Es el tipo de detalle que cuesta una tarde de depuración.

✋ **Sin mirar:** pides con un `Host` que no coincide con ningún `server_name`. ¿Qué sitio responde?

<details>
<summary>Comprueba</summary>

El sitio **por defecto** de nginx.
</details>

**En resumen:** la cabecera `Host` elige el sitio; si no coincide con ningún `server_name`, responde el sitio por defecto.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — El proxy inverso, delante de `miapp`

```
 Cliente ──HTTP──► nginx :80 (proxy inverso) ──HTTP──► app :8080 (solo en localhost o red privada)
                   · termina TLS
                   · enruta por Host y ruta
                   · añade X-Forwarded-For
                   · devuelve 502/504 si la app falla
```

**Pruébalo.** En la VM:

```bash
sudo tee /etc/nginx/sites-available/api <<'EOF'
server {
    listen 80;
    server_name api.lab;

    location / {
        # 127.0.0.1 y no "localhost", por lo mismo que en el aviso de la pieza 3
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

👀 **Qué deberías ver:** `<h1>Mi app en servidor-01</h1>`: la respuesta viene de `miapp` (puerto 8080) **a través de** nginx.

✋ **Sin mirar:** detrás de un proxy, la app ve todas las peticiones como si vinieran de `127.0.0.1`. ¿Cómo sabe la IP real del cliente?

<details>
<summary>Comprueba</summary>

Por la cabecera `X-Forwarded-For`, que añade el proxy. Lo verás en el reto 3.
</details>

**En resumen:** el proxy inverso recibe la petición, se la pasa a la app con `proxy_pass` y le añade `X-Forwarded-For`.

### Pieza 5 — HTTPS: TLS y los certificados

TLS aporta tres cosas:
1. **Cifrado**: nadie en el camino puede leer el contenido (recuerda el `tcpdump -A` de la clase 26).
2. **Integridad**: nadie puede modificarlo sin que se note.
3. **Autenticidad**: el servidor demuestra que **es** `tienda.com` con un **certificado**.

Un **certificado** contiene un nombre (`tienda.com`, en el campo SAN), la clave pública del servidor, unas fechas de validez y la **firma de una autoridad de certificación** (CA). Tu sistema confía en una lista de CAs (`/etc/ssl/certs`). El cliente comprueba que:
- la cadena de firmas llega a una CA en la que confía,
- el nombre coincide con el que pidió,
- no ha caducado.

Si algo falla: `certificate verify failed`, `NET::ERR_CERT_…`. **Un certificado caducado tumba un servicio igual que un servidor apagado**, y es de las caídas más evitables.

En AWS: **ACM** emite certificados gratis para el ALB y CloudFront, y los **renueva solo**. Fuera de AWS, **Let's Encrypt** (`certbot`).

**Pruébalo: un certificado autofirmado.** En la VM:

```bash
sudo openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout /etc/ssl/private/tienda.key -out /etc/ssl/certs/tienda.crt \
  -subj "/CN=tienda.lab" -addext "subjectAltName=DNS:tienda.lab"
sudo chmod 600 /etc/ssl/private/tienda.key
openssl x509 -in /etc/ssl/certs/tienda.crt -noout -subject -issuer -dates -ext subjectAltName
```

👀 **Qué deberías ver:** `subject=CN=tienda.lab` e `issuer=CN=tienda.lab` (iguales: el emisor es **él mismo**, ninguna CA lo respalda); las fechas `notBefore` y `notAfter`, con 30 días entre ellas; y `DNS:tienda.lab` en el SAN. Sirve para laboratorios, no para producción.

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

✋ **Sin mirar:** ¿qué tres cosas comprueba un cliente en el certificado al conectar por HTTPS?

<details>
<summary>Comprueba</summary>

Que la cadena de firmas llega a una CA de confianza, que el nombre coincide con el pedido y que no ha caducado. Lo pruebas en la pieza 6.
</details>

**En resumen:** HTTPS = HTTP dentro de TLS; el certificado tiene un nombre, unas fechas y la firma de una CA.

### Pieza 6 — Lo que comprueba el cliente, una cosa cada vez

`curl` hace las tres comprobaciones de la pieza 5. `--resolve` hace de `/etc/hosts` solo para ese comando.

**Pruébalo.** En tu PC:

```bash
curl -sI --resolve tienda.lab:80:$IP http://tienda.lab/ | grep -iE "^(HTTP|location)"
curl -s --resolve tienda.lab:443:$IP https://tienda.lab/
```

🔮 **Predice:** ¿funcionará el segundo?

👀 **Qué deberías ver:** el primero, `301` con `Location: https://tienda.lab/`. El segundo falla con `SSL certificate problem: self-signed certificate`: tu PC **no confía** en ese emisor.

Ahora una comprobación cada vez:

```bash
curl -sk --resolve tienda.lab:443:$IP https://tienda.lab/          # -k: no verificar (¡solo para probar!)
scp servidor-01:/etc/ssl/certs/tienda.crt /tmp/tienda.crt
curl -s --cacert /tmp/tienda.crt --resolve tienda.lab:443:$IP https://tienda.lab/   # confía en ese cert concreto
curl -s --cacert /tmp/tienda.crt --resolve otra.lab:443:$IP https://otra.lab/       # nombre que no coincide
```

👀 **Qué deberías ver:** `<h1>TIENDA</h1>` con `-k`; otra vez `<h1>TIENDA</h1>` con `--cacert` (ahora sí confías en el emisor); y el último falla con un error de nombre (`no alternative certificate subject name matches…`), aunque confíes en el certificado. Las tres comprobaciones (cadena, nombre y fecha) son independientes.

> `curl -k` o `verify=False` "para que funcione" desactiva la autenticidad: cualquiera en el camino podría suplantar al servidor. En código de producción **no se usa**.

**Y un certificado real:**

```bash
echo | openssl s_client -connect github.com:443 -servername github.com 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

👀 **Qué deberías ver:** `subject=CN=github.com`, un `issuer` que es una CA real (distinto del subject) y las fechas; mira `notAfter`. Esta línea es la base de cualquier monitor de **caducidad de certificados**, como el de Vigía v0.2.

✋ **Sin mirar:** ¿qué significa que un certificado sea **autofirmado**?

<details>
<summary>Comprueba</summary>

Que su emisor es él mismo: ninguna CA de confianza lo firma, así que los clientes no lo aceptan sin más.
</details>

**En resumen:** sin CA de confianza, error de certificado; con un nombre que no coincide, error de nombre; `-k` lo salta todo, y por eso solo vale para probar.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `curl -s URL` · `curl -I URL` · `curl -v URL` | el cuerpo · solo cabeceras · todo, petición y respuesta |
| `curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" URL` | el código y el tiempo |
| `curl -sIL URL` | seguir redirecciones |
| `curl -H "Host: nombre" http://IP/` | pedir un sitio concreto a una IP |
| `curl --resolve nombre:443:IP https://nombre/` | `/etc/hosts` solo para ese comando |
| `curl --cacert cert.crt …` · `curl -k …` | confiar en un certificado · no verificar (solo pruebas) |
| `sudo nginx -t && sudo systemctl reload nginx` | revisar y aplicar la configuración de nginx |
| `openssl x509 -in cert.crt -noout -subject -issuer -dates` | leer un certificado |
| `echo \| openssl s_client -connect host:443 -servername host 2>/dev/null \| openssl x509 -noout -dates` | las fechas de un certificado remoto |

| Código del proxy o ALB | Mira primero |
|------------------------|--------------|
| 502 | ¿la app está viva y en su puerto? Sus logs |
| 503 | los health checks del target group |
| 504 | la lentitud de la app o de la base de datos, y los timeouts |

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

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Añade a `api.lab` una ruta `/salud` que nginx responda directamente con `200` y el texto `ok`, sin llamar a la app. ¿Qué limitación tiene frente a un health check que llama a la app?

> 🧩 **Ejemplo resuelto:** una ruta `/version` que responde nginx solo, dentro del bloque `server` de `api.lab`:
> ```nginx
> location = /version { return 200 "v1\n"; }
> ```
> `sudo nginx -t && sudo systemctl reload nginx` y `curl -s -H "Host: api.lab" http://$IP/version` → `v1`.

**Ahora tú, con huecos:** añade `location = ____ { return ____ "ok\n"; }` al sitio `api`, recarga y prueba con `curl -s -w " %{http_code}\n" -H "Host: api.lab" http://$IP/salud`. Después, para `miapp` y vuelve a probarlo: ¿sigue diciendo `ok`?

<details>
<summary>Pista</summary>

Si sigue diciendo `ok` con la app parada, ¿qué está comprobando de verdad ese health check: la app, o solo nginx?
</details>

**2.** ¿Cuántos días le quedan al certificado de `amazon.com`?

> 🧩 **Ejemplo resuelto:** las fechas del de GitHub, como en la pieza 6:
> ```bash
> echo | openssl s_client -connect github.com:443 -servername github.com 2>/dev/null | openssl x509 -noout -dates
> ```

**Ahora tú, con huecos:**
```bash
FIN=$(echo | openssl s_client -connect ____:443 -servername ____ 2>/dev/null | openssl x509 -noout -____ | cut -d= -f2)
echo "caduca: $FIN · quedan $(( ( $(date -d "$FIN" +%s) - $(date +%s) ) / 86400 )) días"
```

<details>
<summary>Pista</summary>

La opción de `openssl x509` que da solo la fecha de fin es `-enddate`. Es lo que hará Vigía en la clase 35 para avisarte antes de que caduque un certificado.
</details>

**3.** ¿Qué cabecera llega a `miapp` con la IP real del cliente? Captúrala.

> 🧩 **Ejemplo resuelto:** en la clase 26 viste el contenido de una petición con `sudo tcpdump -i any -nn -A port 80`.

**Ahora tú, con huecos:** en la VM, `sudo tcpdump -i lo -nn -A port ____`; en tu PC, `curl -s -H "Host: api.lab" http://$IP/ > /dev/null`. En la captura, busca la línea `____: 10.x.x.1`.

<details>
<summary>Pista</summary>

nginx habla con `miapp` por `127.0.0.1` (la interfaz `lo`) y al puerto de la app. La cabecera es la que añade la línea `proxy_set_header` de la pieza 4.
</details>

**4.** ¿Qué código esperarías del ALB en cada caso?

> 🧩 **Ejemplo resuelto:** en el Rómpelo 1 paraste `miapp` y nginx devolvió **502**: el backend rechazaba la conexión.

**Ahora tú, con huecos:**
- (a) tu app devuelve una excepción no controlada → ____
- (b) ninguna instancia pasa el health check → ____
- (c) la consulta a la base de datos tarda 70 s → ____

<details>
<summary>Pista</summary>

Mira la columna «Quién tiene el problema» de la pieza 2. El *idle timeout* por defecto de un ALB es de 60 segundos.
</details>

## Cierre

En `notas/fase-3/clase-32.md`:

1. Diferencia entre 401 y 403, y entre 502, 503 y 504. ¿Dónde mirarías primero en cada uno? *(3 líneas. Empieza así: «401 es no autenticado y 403… 502: el backend no respondió bien, miro… 503:… 504:…»)*
2. ¿Cómo sabe nginx qué sitio servir si `tienda.lab` y `blog.lab` comparten IP y puerto? *(2 líneas. Empieza así: «Por la cabecera `Host`: nginx la compara con los `server_name`… y si no coincide ninguno…»)*
3. ¿Qué comprueba un cliente al conectar por HTTPS? ¿Por qué `curl -k` es peligroso fuera de un laboratorio? *(2–3 líneas. Empieza así: «Que la cadena llega a una CA de confianza, que el nombre… y que… `-k` desactiva…, así que…»)*
4. **Repaso (clase 31, sin mirar):** ¿por qué `dig` y `getent` pueden dar respuestas distintas para el mismo nombre? *(2 líneas. Empieza así: «Porque `dig` pregunta directamente al DNS e ignora… y `getent`…»)*

Después, escríbeme `examíname clase-32`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **401**: no autenticado; falta la credencial o es inválida. **403**: autenticado (o anónimo), pero sin permiso para ese recurso; también nginx sin permiso de lectura en el archivo. **502**: el proxy o el ALB no obtuvo una respuesta válida del backend (caído, conexión rechazada, se cerró a mitad) → mirar si la app está viva, su puerto y sus logs. **503**: no hay backend disponible → health checks del target group y capacidad. **504**: el backend no respondió a tiempo → lentitud de la app, de la base de datos o de una dependencia, y los timeouts.

**2.** Por la cabecera **`Host`** de la petición HTTP: nginx la compara con los `server_name` de sus bloques `server` y sirve el que coincide (o el de por defecto si no coincide ninguno). Con HTTPS, el nombre llega además antes del cifrado mediante **SNI**, para elegir el certificado.

**3.** Que el certificado esté firmado por una cadena que termina en una **CA de confianza**, que el **nombre** pedido coincida con el del certificado (SAN) y que esté **dentro de sus fechas** de validez. `-k` desactiva esas comprobaciones: el canal sigue cifrado, pero **no sabes con quién hablas**, así que un atacante en el camino podría hacerse pasar por el servidor (*man-in-the-middle*) y leerlo todo.

**4.** `dig` pregunta directamente a un servidor DNS e ignora `/etc/hosts`. `getent` sigue el orden de `/etc/nsswitch.conf` (primero `/etc/hosts`, después DNS), igual que las aplicaciones.

**Reto:** 1) `location = /salud { return 200 "ok\n"; }`. Sigue diciendo `ok` con `miapp` parada: solo demuestra que **nginx** responde, no que la app ni la base de datos funcionen. Un buen health check llama a un endpoint de la app que comprueba sus dependencias críticas. 2) `amazon.com` dos veces y `-enddate`. 3) `port 8080`; `X-Forwarded-For: <IP de tu PC>`. 4) (a) **500** si la app devuelve el error (o **502** si la app se cae y cierra la conexión); (b) **503**; (c) **504** (el idle timeout por defecto del ALB es de 60 s).
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

[Clase 33 — Firewall](clase-33-firewall.md)
