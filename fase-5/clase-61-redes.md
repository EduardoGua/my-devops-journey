# Clase 61 — Redes de Docker

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

> 💡 **La idea de hoy:** Docker crea en tu portátil una pequeña red privada, como una VPC: subred, DNS interno y NAT hacia fuera. En una red **creada por ti**, los contenedores se encuentran **por nombre** y hablan por su puerto interno sin publicar nada; `-p` solo sirve para entrar desde fuera. Dos trampas: dentro de un contenedor, `localhost` es él mismo, y un puerto publicado se salta las reglas de `ufw`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Subredes privadas y CIDR (clases 27 y 28); la puerta de enlace y el NAT (clase 30).
> - DNS y `getent hosts` (clase 31); `ufw` e `iptables` (clase 33).
> - La arquitectura de proxy delante y *backend* sin exponer (clase 34).
> - `docker run -d -p`, `inspect` y `exec` (clase 57); tu imagen `saludo:2` (clase 59); `postgres:18` (clase 60).

> 🔤 **Palabras nuevas de hoy:**
> - **red `bridge`**: una red privada de Docker en tu máquina; la de por defecto es `172.17.0.0/16`.
> - **red definida por el usuario** (`docker network create`): una red *bridge* tuya, con DNS interno.
> - **DNS interno** (`127.0.0.11`): el servidor de nombres de Docker, que traduce nombres de contenedores a IPs.
> - **puerto interno / puerto publicado**: el que escucha la aplicación dentro / el que abre `-p` en tu máquina.
> - **descubrimiento de servicios** (*service discovery*): encontrar otro servicio por su nombre, sin saber su IP.

## Objetivo

- Entender las redes de Docker: la red `bridge` por defecto, tus propias redes, `host` y `none`.
- Conectar contenedores entre sí **por nombre**, gracias al DNS interno de Docker.
- Distinguir el puerto **interno** de un contenedor del puerto **publicado** en tu máquina.
- Publicar puertos solo en `127.0.0.1`, y saber por qué Docker se salta las reglas de `ufw`.
- Evitar el error clásico: usar `localhost` para hablar con otro contenedor.

## Por qué importa

Vigía v2 son tres contenedores que hablan entre sí: el chequeo y la API escriben y leen en PostgreSQL. Que se encuentren, y que **solo** la API sea accesible desde fuera, es una decisión de red, la misma que tomaste en papel en la fase 3: subred, DNS, puertos y firewall. Docker crea en tu portátil una pequeña VPC: redes privadas, DNS interno y NAT hacia fuera (clases 28, 30, 31 y 33).

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. Las piezas 2 a 4 usan la misma red `lab`.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre. Si paras entre medias, deja `lab` y `web` creados.

```bash
mkdir -p ~/my-devops-journey/labs/clase-61 && cd ~/my-devops-journey/labs/clase-61
docker network ls
```

`docker network ls` muestra las tres redes que Docker trae de serie: `bridge`, `host` y `none`.

## Las piezas

### Pieza 1 — La red por defecto: solo por IP

| Red | Qué es |
|-----|--------|
| `bridge` (la de por defecto) | una red privada en tu máquina (`172.17.0.0/16`); los contenedores se ven **por IP**, no por nombre |
| una red tuya (`docker network create lab`) | también tipo *bridge*, pero con **DNS interno**: cada contenedor se encuentra por su nombre |
| `host` | sin aislamiento de red: el contenedor usa la red de tu máquina directamente |
| `none` | sin red |

🔮 **Predice:** ¿podrá `uno` encontrar a `dos` por su nombre en la red por defecto?

**Pruébalo:**

```bash
docker run -d --name uno alpine:3.22 sleep 300
docker run -d --name dos alpine:3.22 sleep 300
docker exec uno ping -c1 -W1 dos
IP_DOS=$(docker inspect dos --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
docker exec uno ping -c1 -W1 "$IP_DOS"
docker rm -f uno dos
```

👀 **Qué deberías ver:** `ping: bad address 'dos'`: en la red por defecto no hay DNS para los contenedores. Por IP sí llega: `64 bytes from 172.17.0.3…`. (Usa nombres de al menos dos letras: las versiones recientes de Docker rechazan los de una.)

✋ **Sin mirar:** ¿en qué tipo de red los contenedores **no** se encuentran por nombre?

<details>
<summary>Comprueba</summary>

En la red `bridge` por defecto. Allí solo se llega por IP.
</details>

**En resumen:** la red por defecto da IPs `172.17.x.x` pero no nombres; para nombres, una red tuya.

### Pieza 2 — Una red propia y el DNS interno

En una red propia, cada contenedor tiene como DNS `127.0.0.11`, un servidor que Docker atiende y que traduce los nombres de los contenedores (y de los servicios de Compose) a sus IPs internas. Las IPs cambian al recrear un contenedor; el nombre no. Conecta siempre por nombre. Docker Compose (clase 62) crea automáticamente una red propia para cada proyecto: por eso, en Compose, la API encuentra a la base de datos como `db`.

**Pruébalo:**

```bash
docker network create lab
docker run -d --name web --network lab nginx:1.29
docker run --rm --network lab alpine:3.22 getent hosts web
docker run --rm --network lab alpine:3.22 sh -c 'wget -qO- http://web:80 | grep title'
docker run --rm --network lab alpine:3.22 grep nameserver /etc/resolv.conf
docker network inspect lab --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}  {{end}}'
```

👀 **Qué deberías ver:** `172.18.0.2  web  web`: el nombre se resuelve a su IP interna, en otra subred (`172.18.0.0/16`); `<title>Welcome to nginx!</title>`; `nameserver 127.0.0.11`, el DNS de Docker; y `web 172.18.0.2/16`. Fíjate en que **no publicaste ningún puerto**: entre contenedores de la misma red no hace falta.

✋ **Sin mirar:** ¿por qué conviene conectar por nombre y no por IP?

<details>
<summary>Comprueba</summary>

Porque la IP cambia al recrear el contenedor, y el nombre no.
</details>

**En resumen:** `docker network create` + `--network`: DNS interno en `127.0.0.11` y cada contenedor por su nombre.

### Pieza 3 — El puerto interno manda, y `localhost` es el propio contenedor

```
  tu navegador ──► 127.0.0.1:8080 (tu Ubuntu) ──NAT──► web:80 (contenedor)
  otro contenedor de la red ──────────────────────────► web:80
```

- Entre contenedores de la misma red se usa el **puerto interno** (el que escucha la aplicación): `http://web:80`, `postgresql://db:5432`. No hace falta publicar nada.
- `-p` solo sirve para entrar **desde fuera** de Docker. Publica únicamente lo que deba ser accesible: en Vigía, la API sí y la base de datos no.
- Dentro de un contenedor, `localhost` y `127.0.0.1` son **él mismo**, no tu máquina ni otro contenedor. `postgresql://localhost:5432` desde la API busca una base de datos dentro del contenedor de la API, y no la encuentra.

🔮 **Predice** los dos resultados.

**Pruébalo:**

```bash
docker run --rm --network lab alpine:3.22 wget -qO- -T 3 http://web:8080
docker run --rm --network lab alpine:3.22 wget -qO- -T 3 http://localhost:80
```

👀 **Qué deberías ver:** `wget: can't connect to remote host (172.18.0.2): Connection refused`, porque nginx escucha en el 80, y el 8080 solo existiría si lo hubieras publicado **en tu máquina**. Y `wget: can't connect to remote host: Connection refused` otra vez, porque `localhost` es el propio contenedor de Alpine, que no tiene ningún nginx.

✋ **Sin mirar:** desde otro contenedor de la red, ¿qué URL usas para la base de datos `db`, que escucha en el 5432?

<details>
<summary>Comprueba</summary>

`postgresql://db:5432`: el nombre del contenedor y su puerto interno. Ni `localhost` ni un puerto publicado.
</details>

**En resumen:** entre contenedores, nombre y puerto interno; `localhost` es el propio contenedor.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/my-devops-journey/labs/clase-61`; si borraste la red, `docker network create lab`.

### Pieza 4 — Una base de datos solo para la red interna

Con lo de las piezas 2 y 3, una base de datos puede servir a otros contenedores sin abrir ningún puerto en tu máquina: el cliente la alcanza por su nombre y su puerto interno.

**Pruébalo:**

```bash
docker run -d --name pg --network lab -e POSTGRES_PASSWORD=prueba postgres:18
sleep 5
docker run --rm --network lab -e PGPASSWORD=prueba postgres:18 psql -h pg -U postgres -tAc "SELECT 'conectado a ' || inet_server_addr()"
docker port pg
```

👀 **Qué deberías ver:** `conectado a 172.18.0.3` (la IP interna de `pg`), y `docker port pg` no muestra nada: PostgreSQL no está publicado en tu máquina. Es exactamente lo que harás con Vigía v2.

✋ **Sin mirar:** `docker port pg` no muestra nada. ¿Puede conectarse a `pg` otro contenedor de la red `lab`? ¿Y tu navegador?

<details>
<summary>Comprueba</summary>

El contenedor sí, por `pg:5432`. Tu navegador (o cualquier cosa fuera de Docker), no: no hay ningún puerto publicado.
</details>

**En resumen:** lo que solo usan otros contenedores no se publica; se alcanza por nombre dentro de la red.

### Pieza 5 — Publicar solo para ti, y Docker frente a tu firewall

`-p 8080:80` publica el puerto en **todas** las interfaces de tu máquina (`0.0.0.0`), es decir, también en tu red local. Y hay algo peor: Docker escribe sus propias reglas de `iptables` en la tabla `nat`, y el tráfico hacia un puerto publicado se redirige **antes** de llegar a las reglas de `ufw`. Un puerto publicado queda abierto aunque `ufw` diga lo contrario (lo explica la documentación de Docker, en "Docker and ufw"; lo verás en el Rómpelo 3).

La defensa más simple: publicar solo en `127.0.0.1` cuando el servicio es para ti (`-p 127.0.0.1:8080:80`). En un servidor de verdad, delante va un firewall de red: el *security group* de AWS (fase 6).

🔮 **Predice:** desde la IP de tu red local, ¿cuál de los dos responde?

**Pruébalo:**

```bash
docker run -d --name publica -p 8080:80 nginx:1.29
docker run -d --name privada -p 127.0.0.1:8081:80 nginx:1.29
docker port publica ; docker port privada
MI_IP=$(hostname -I | awk '{print $1}')
curl -s -m 3 -o /dev/null -w "publica por mi IP → %{http_code}\n" "http://$MI_IP:8080"
curl -s -m 3 -o /dev/null -w "privada por mi IP → %{http_code}\n" "http://$MI_IP:8081" || echo "privada por mi IP → no llega"
curl -s -o /dev/null -w "privada por 127.0.0.1 → %{http_code}\n" http://127.0.0.1:8081
docker rm -f publica privada web pg
docker network rm lab
```

👀 **Qué deberías ver:** `docker port` da `80/tcp -> 0.0.0.0:8080` para `publica` y `80/tcp -> 127.0.0.1:8081` para `privada`. Por la IP de tu red, `publica` responde `200`: cualquiera de tu wifi podría verla. `privada` no llega por tu IP y responde `200` solo en `127.0.0.1`. Al final, la limpieza de toda la clase.

✋ **Sin mirar:** `ufw` está activo y no permite el 8080. ¿Está protegido un contenedor publicado con `-p 8080:80`?

<details>
<summary>Comprueba</summary>

No: Docker redirige el tráfico de los puertos publicados en la tabla `nat` de `iptables`, antes de las reglas de `ufw`. Publica en `127.0.0.1` lo que sea solo para ti.
</details>

**En resumen:** `-p 127.0.0.1:puerto:puerto` para lo que es solo tuyo; `ufw` no protege lo que Docker publica.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `docker network ls` · `create lab` · `rm lab` | listar, crear, borrar redes |
| `docker run --network lab …` | arrancar en una red |
| `docker network connect otra contenedor` | unir un contenedor a otra red más |
| `docker network inspect lab --format '{{range .Containers}}…{{end}}'` | quién está en la red |
| `getent hosts nombre` (dentro de un contenedor) | qué IP da el DNS interno |
| `http://nombre:puerto_interno` | hablar con otro contenedor de la red |
| `-p 127.0.0.1:8080:80` | publicar solo para tu máquina |
| `docker port contenedor` | qué puertos tiene publicados |
| `--network host` | sin aislamiento de red |

## Rómpelo

**1. `localhost` para llegar a la base de datos:**
```bash
docker network create lab2
docker run -d --name pg --network lab2 -e POSTGRES_PASSWORD=prueba postgres:18 && sleep 5
docker run --rm --network lab2 -e PGPASSWORD=prueba postgres:18 psql -h localhost -U postgres -c 'SELECT 1'
docker run --rm --network lab2 -e PGPASSWORD=prueba postgres:18 psql -h pg -U postgres -tAc 'SELECT 1'
```
Con `localhost`: `connection refused`, porque busca PostgreSQL en el propio contenedor del cliente. Con el nombre `pg`: `1`. Es el error número uno al pasar una aplicación a Docker, y te lo encontrarás con la `DATABASE_URL` de Vigía.

**2. Dos redes distintas no se ven:**
```bash
docker network create otra
docker run --rm --network otra alpine:3.22 ping -c1 -W1 pg
docker network connect otra pg
docker run --rm --network otra alpine:3.22 ping -c1 -W1 pg
docker rm -f pg && docker network rm lab2 otra
```
Primero `bad address`: `pg` vive en `lab2`. `docker network connect` lo une también a `otra`, y entonces sí. Es como dos subredes sin ruta entre ellas (clase 30). Separar redes sirve para aislar: el proxy público en una red, la base de datos en otra solo con la API.

**3. El firewall que no protege lo publicado:**
```bash
sudo ufw status
sudo iptables -t nat -L DOCKER -n | head
```
Aunque `ufw` esté activo y no permita el 8080, un contenedor publicado con `-p 8080:80` sería accesible desde tu red: su tráfico se redirige en la tabla `nat` (las reglas `DNAT` que ves en la cadena `DOCKER`) antes de pasar por las reglas de `ufw`. No lo pruebes dejando algo publicado: recuerda la regla y publica en `127.0.0.1`.

## Reto

En `labs/clase-61/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Monta un proxy delante de tu API, en dos redes: `proxy` (nginx, publicado en `127.0.0.1:8080`) en las redes `frontal` y `trasera`; `api` (la imagen `saludo:2` de la clase 59) solo en `trasera`, sin puertos publicados. nginx reenvía `/` a `http://api:8000`.

> 🧩 **Ejemplo resuelto:** la pieza 4 (un servicio solo en la red interna) y el Rómpelo 2 (`docker network connect` une un contenedor a otra red).

**Ahora tú, con huecos:**
```bash
docker network create frontal && docker network create trasera
docker run -d --name api --network ____ saludo:2
printf 'server {\n  listen 80;\n  location / { proxy_pass http://____:8000; }\n}\n' > default.conf
docker run -d --name proxy --network trasera -p ____:8080:80 \
  -v ./default.conf:/etc/nginx/conf.d/default.conf:ro nginx:1.29
docker network connect ____ proxy
curl -s 127.0.0.1:8080/info ; echo
docker port api
```

<details>
<summary>Pista</summary>

nginx resuelve el nombre `api` **al arrancar**, y si no lo encuentra se detiene (`host not found in upstream "api"`, míralo con `docker logs proxy`). Por eso el proxy arranca en `trasera`, donde ya está la API, y después se une a `frontal`. El `default.conf` va montado en solo lectura, como en la clase 60.
</details>

**2.** ¿Qué IP tiene tu interfaz `docker0` y qué papel juega para los contenedores de la red por defecto?

> 🧩 **Ejemplo resuelto:** en la clase 30, `ip route` mostraba tu puerta de enlace (`default via 192.168.1.1`): el router por el que sale todo lo que no es de tu red.

**Ahora tú, con huecos:**
```bash
ip -4 addr show docker0 | grep inet
docker run --rm alpine:3.22 ip route | grep ____
```
Completa: «`docker0` tiene la IP ____, y es la ____ de los contenedores de la red por defecto: por ella salen, con NAT, hacia fuera».

<details>
<summary>Pista</summary>

La línea que buscas dentro del contenedor empieza por `default`. Compárala con la IP de `docker0`.
</details>

**3.** Arranca un contenedor con `--network host` y `nginx:1.29`. ¿En qué puerto de tu máquina escucha, si no usaste `-p`? Bórralo enseguida.

> 🧩 **Ejemplo resuelto:** la tabla de la pieza 1: `host` es "sin aislamiento de red".

**Ahora tú, con huecos:**
```bash
docker run -d --name enhost --network host nginx:1.29
ss -tlnp | grep ':____ '
curl -s -o /dev/null -w "%{http_code}\n" localhost:____
docker rm -f enhost
```

<details>
<summary>Pista</summary>

nginx escucha en el puerto que dice su configuración (pieza 2 de la clase 57). Si ese puerto ya está ocupado en tu máquina, el contenedor fallará al arrancar: míralo con `docker logs enhost`.
</details>

## Cierre

En `notas/fase-5/clase-61.md`:

1. ¿Por qué en una red creada por ti los contenedores se encuentran por nombre y en la red por defecto no? *(2 líneas. Empieza así: «Porque en las redes que creo yo Docker activa su DNS interno (127.0.0.11), que… La red bridge por defecto…»)*
2. Desde la API, ¿por qué falla `postgresql://localhost:5432` y funciona `postgresql://db:5432`? *(2 líneas. Empieza así: «Porque dentro de un contenedor `localhost` es…; `db` es el nombre de…, que el DNS de Docker…»)*
3. ¿Qué diferencia hay entre `-p 8080:80` y `-p 127.0.0.1:8080:80`? ¿Por qué no basta con `ufw` para proteger un puerto publicado? *(2–3 líneas. Empieza así: «`-p 8080:80` publica en todas las interfaces, así que…; con `127.0.0.1`, solo… `ufw` no basta porque Docker…»)*
4. **Repaso (clase 60, sin mirar):** ¿qué es un volumen anónimo y por qué "pierde" los datos? *(1–2 líneas. Empieza así: «Es un volumen que Docker crea solo cuando…»)*

Después, escríbeme `examíname clase-61`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque en las redes que creas tú (y en las de Compose) Docker activa su DNS interno (`127.0.0.11`), que traduce los nombres de los contenedores a sus IPs. La red `bridge` por defecto existe por compatibilidad y no tiene ese DNS: allí solo se llega por IP.

**2.** Porque dentro de un contenedor `localhost` es el propio contenedor: busca PostgreSQL dentro de la API, donde no hay nada escuchando. `db` es el nombre del contenedor de la base de datos, que el DNS de Docker resuelve a su IP en la red compartida, y 5432 es su puerto interno.

**3.** `-p 8080:80` publica en todas las interfaces de tu máquina, así que llega cualquiera de tu red; `-p 127.0.0.1:8080:80`, solo tu propia máquina. `ufw` no basta porque Docker redirige el tráfico de los puertos publicados en la tabla `nat` de `iptables`, antes de que pase por las reglas de `ufw`.

**4.** Un volumen sin nombre que Docker crea cuando la imagen declara un `VOLUME` y no montas nada ahí. Al recrear el contenedor, el nuevo recibe otro volumen anónimo vacío, y los datos se quedan en el viejo, huérfano.

**Reto 1:** `--network trasera`, `proxy_pass http://api:8000`, `-p 127.0.0.1:8080:80` y `docker network connect frontal proxy`. `curl` devuelve el JSON de `/info` y `docker port api` no muestra nada. Es la arquitectura de la clase 34 (proxy delante, *backend* sin exponer), ahora con contenedores. Al terminar: `docker rm -f proxy api && docker network rm frontal trasera`.

**Reto 2:** `grep default`. `docker0` tiene la IP `172.17.0.1`, y es la **puerta de enlace** de los contenedores de la red por defecto (`default via 172.17.0.1`): por ella salen hacia fuera, con NAT, como tu portátil sale por tu router.

**Reto 3:** el puerto `80`, directamente en tu máquina: con `--network host` no hay aislamiento de red ni NAT, y `-p` no tiene efecto.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| bridge network / user-defined network | red puente / red definida por el usuario |
| embedded DNS server | servidor DNS integrado |
| published port / exposed port | puerto publicado / puerto expuesto |
| service discovery | descubrimiento de servicios |
| network isolation | aislamiento de red |

🎙️ *"Containers talk to each other by service name on a user-defined network; only the entry point is published, and only on the interface it needs, because Docker's NAT rules bypass ufw."*

## Siguiente

[Clase 62 — Docker Compose](clase-62-compose.md)
