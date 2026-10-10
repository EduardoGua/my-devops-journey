# Clase 61 — Redes de Docker

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Contenedores

## Objetivo

- Entender las redes de Docker: la red `bridge` por defecto, tus propias redes, `host` y `none`.
- Conectar contenedores entre sí **por nombre**, gracias al DNS interno de Docker.
- Distinguir el puerto **interno** de un contenedor del puerto **publicado** en tu máquina.
- Publicar puertos solo en `127.0.0.1`, y saber por qué Docker se salta las reglas de `ufw`.
- Evitar el error clásico: usar `localhost` para hablar con otro contenedor.

## Por qué importa

Vigía v2 son tres contenedores que hablan entre sí: el chequeo y la API escriben y leen en PostgreSQL. Que se encuentren, y que **solo** la API sea accesible desde fuera, es una decisión de red, la misma que tomaste en papel en la fase 3: subred, DNS, puertos y firewall. Docker crea en tu portátil una pequeña VPC: redes privadas, DNS interno y NAT hacia fuera (clases 28, 30, 31 y 33).

## Teoría

### Los tipos de red

| Red | Qué es |
|-----|--------|
| `bridge` (la de por defecto) | una red privada en tu máquina (`172.17.0.0/16`); los contenedores se ven **por IP**, no por nombre |
| una red tuya (`docker network create lab`) | también tipo *bridge*, pero con **DNS interno**: cada contenedor se encuentra por su nombre |
| `host` | sin aislamiento de red: el contenedor usa la red de tu máquina directamente |
| `none` | sin red |

Docker Compose (clase 62) crea automáticamente una red propia para cada proyecto. Por eso, en Compose, la API encuentra a la base de datos como `db`.

### El DNS interno

En una red propia, cada contenedor tiene como DNS `127.0.0.11`, un servidor que Docker atiende y que traduce los nombres de los contenedores (y de los servicios de Compose) a sus IPs internas. Las IPs cambian al recrear un contenedor; el nombre no. Conecta siempre por nombre.

### Puerto interno y puerto publicado

```
  tu navegador ──► 127.0.0.1:8080 (tu Ubuntu) ──NAT──► web:80 (contenedor)
  otro contenedor de la red ──────────────────────────► web:80
```

- Entre contenedores de la misma red se usa el **puerto interno** (el que escucha la aplicación): `http://web:80`, `postgresql://db:5432`. No hace falta publicar nada.
- `-p` solo sirve para entrar **desde fuera** de Docker. Publica únicamente lo que deba ser accesible: en Vigía, la API sí y la base de datos no.

### `localhost` es el propio contenedor

Dentro de un contenedor, `localhost` y `127.0.0.1` son **él mismo**, no tu máquina ni otro contenedor. `postgresql://localhost:5432` desde la API busca una base de datos dentro del contenedor de la API, y no la encuentra (`Connection refused`). Desde otro contenedor, se usa el nombre: `postgresql://db:5432`.

### Docker y tu firewall

`-p 8080:80` publica el puerto en **todas** las interfaces de tu máquina (`0.0.0.0`), es decir, también en tu red local. Y hay algo peor: Docker escribe sus propias reglas de `iptables` en la tabla `nat`, y el tráfico hacia un puerto publicado se redirige **antes** de llegar a las reglas de `ufw`. Un puerto publicado queda abierto aunque `ufw` diga lo contrario (lo explica la documentación de Docker, en "Docker and ufw").

La defensa más simple: publicar solo en `127.0.0.1` cuando el servicio es para ti (`-p 127.0.0.1:8080:80`). En un servidor de verdad, delante va un firewall de red: el *security group* de AWS (fase 6).

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-61 && cd ~/my-devops-journey/labs/clase-61
docker network ls
```

### 1. La red por defecto: solo por IP

```bash
docker run -d --name uno alpine:3.22 sleep 300
docker run -d --name dos alpine:3.22 sleep 300
docker exec uno ping -c1 -W1 dos
IP_DOS=$(docker inspect dos --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
docker exec uno ping -c1 -W1 "$IP_DOS"
docker rm -f uno dos
```

🔮 **Predice:** ¿podrá `uno` encontrar a `dos` por su nombre? No: `bad address 'dos'`. En la red por defecto no hay DNS para los contenedores; por IP sí llega. (Usa nombres de al menos dos letras: las versiones recientes de Docker rechazan los de una.)

### 2. Una red propia: por nombre

```bash
docker network create lab
docker run -d --name web --network lab nginx:1.29
docker run --rm --network lab alpine:3.22 getent hosts web
docker run --rm --network lab alpine:3.22 sh -c 'wget -qO- http://web:80 | grep title'
docker run --rm --network lab alpine:3.22 grep nameserver /etc/resolv.conf
docker network inspect lab --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}  {{end}}'
```

El nombre `web` se resuelve a su IP interna, y el DNS es `127.0.0.11`: el servidor de nombres de Docker. Fíjate en que **no publicaste ningún puerto**: entre contenedores de la misma red no hace falta.

### 3. El puerto interno manda

```bash
docker run --rm --network lab alpine:3.22 wget -qO- -T 3 http://web:8080
docker run --rm --network lab alpine:3.22 wget -qO- -T 3 http://localhost:80
```

🔮 **Predice** los dos resultados. El primero: `Connection refused`, porque nginx escucha en el 80, y el 8080 solo existiría si lo hubieras publicado **en tu máquina**. El segundo: también rechazado, porque `localhost` es el propio contenedor de Alpine, que no tiene ningún nginx.

### 4. Una base de datos solo para la red interna

```bash
docker run -d --name pg --network lab -e POSTGRES_PASSWORD=prueba postgres:18
sleep 5
docker run --rm --network lab -e PGPASSWORD=prueba postgres:18 psql -h pg -U postgres -tAc "SELECT 'conectado a ' || inet_server_addr()"
docker port pg
```

Un cliente en otro contenedor de la red conecta por el nombre `pg`, y `docker port pg` no muestra nada: PostgreSQL no está publicado en tu máquina. Es exactamente lo que harás con Vigía v2.

### 5. Publicar solo para ti

```bash
docker run -d --name publica -p 8080:80 nginx:1.29
docker run -d --name privada -p 127.0.0.1:8081:80 nginx:1.29
docker port publica ; docker port privada
MI_IP=$(hostname -I | awk '{print $1}')
curl -s -m 3 -o /dev/null -w "publica por mi IP → %{http_code}\n" "http://$MI_IP:8080"
curl -s -m 3 -o /dev/null -w "privada por mi IP → %{http_code}\n" "http://$MI_IP:8081" || echo "privada por mi IP → no llega"
curl -s -o /dev/null -w "privada por 127.0.0.1 → %{http_code}\n" http://127.0.0.1:8081
docker rm -f publica privada
```

🔮 **Predice:** desde la IP de tu red local, ¿cuál responde? Solo `publica`: cualquiera de tu wifi podría verla. `privada` solo responde en `127.0.0.1`.

### 6. Limpieza

```bash
docker rm -f web pg
docker network rm lab
```

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

1. Monta tres contenedores en dos redes: `proxy` (nginx, publicado en `127.0.0.1:8080`) en las redes `frontal` y `trasera`; `api` (la imagen `saludo:2` de la clase 59) solo en `trasera`. Configura nginx para reenviar `/` a `http://api:8000` con un `default.conf` montado en solo lectura (clase 60; pista: `location / { proxy_pass http://api:8000; }`). Comprueba que `curl 127.0.0.1:8080/info` funciona y que la API no tiene puertos publicados. Ojo: nginx resuelve el nombre `api` **al arrancar**, y si no lo encuentra se detiene.
2. ¿Qué IP tiene tu interfaz `docker0` (`ip addr show docker0`) y qué papel juega para los contenedores de la red por defecto? Relaciónalo con la puerta de enlace de la clase 30.
3. Arranca un contenedor con `--network host` y `nginx:1.29`. ¿En qué puerto de tu máquina escucha, si no usaste `-p`? Bórralo enseguida.

## Cierre

En `notas/fase-5/clase-61.md`:

1. ¿Por qué en una red creada por ti los contenedores se encuentran por nombre y en la red por defecto no?
2. Desde la API, ¿por qué falla `postgresql://localhost:5432` y funciona `postgresql://db:5432`?
3. ¿Qué diferencia hay entre `-p 8080:80` y `-p 127.0.0.1:8080:80`? ¿Por qué no basta con `ufw` para proteger un puerto publicado?
4. **Repaso (clase 60, sin mirar):** ¿qué es un volumen anónimo y por qué "pierde" los datos?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque en las redes que creas tú (y en las de Compose) Docker activa su DNS interno (`127.0.0.11`), que traduce los nombres de los contenedores a sus IPs. La red `bridge` por defecto existe por compatibilidad y no tiene ese DNS: allí solo se llega por IP.

**2.** Porque dentro de un contenedor `localhost` es el propio contenedor: busca PostgreSQL dentro de la API, donde no hay nada escuchando. `db` es el nombre del contenedor de la base de datos, que el DNS de Docker resuelve a su IP en la red compartida, y 5432 es su puerto interno.

**3.** `-p 8080:80` publica en todas las interfaces de tu máquina, así que llega cualquiera de tu red; `-p 127.0.0.1:8080:80`, solo tu propia máquina. `ufw` no basta porque Docker redirige el tráfico de los puertos publicados en la tabla `nat` de `iptables`, antes de que pase por las reglas de `ufw`.

**4.** Un volumen sin nombre que Docker crea cuando la imagen declara un `VOLUME` y no montas nada ahí. Al recrear el contenedor, el nuevo recibe otro volumen anónimo vacío, y los datos se quedan en el viejo, huérfano.

**Reto 1 (lo esencial):**
```bash
docker network create frontal && docker network create trasera
docker run -d --name api --network trasera saludo:2
printf 'server {\n  listen 80;\n  location / { proxy_pass http://api:8000; }\n}\n' > default.conf
docker run -d --name proxy --network trasera -p 127.0.0.1:8080:80 \
  -v ./default.conf:/etc/nginx/conf.d/default.conf:ro nginx:1.29
docker network connect frontal proxy
curl -s 127.0.0.1:8080/info
```
El proxy arranca en `trasera`, donde ya puede resolver `api`, y después se une a `frontal`. Si lo arrancas solo en `frontal`, nginx muere al momento con `host not found in upstream "api"` (míralo con `docker logs proxy`). Es la arquitectura de la clase 34 (proxy delante, *backend* sin exponer), ahora con contenedores.

**Reto 3:** en el 80 de tu máquina, directamente: con `--network host` no hay aislamiento de red ni NAT, y `-p` no tiene efecto.
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
