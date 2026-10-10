# Clase 49 — Consumir APIs con requests

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

## Objetivo

- Hacer peticiones HTTP con `requests`: parámetros, cabeceras, *timeout*, código de estado y cuerpo JSON.
- Distinguir los fallos de red (DNS, conexión rechazada, tiempo agotado) de las respuestas de error (404, 500), y tratar cada uno.
- Reintentar con esperas crecientes sin colgar el programa.
- Consumir una API pública real (la de GitHub) y sobrevivir a un error de red. Es un criterio de salida de esta fase.

## Por qué importa

La nube se maneja con APIs: AWS, GitHub, Docker Hub, Slack, el monitoreo… Todo lo que haces en una consola web tiene una API detrás, y automatizar consiste en hablar con ella desde un programa. Además, `requests` es el corazón de Vigía v1: cada chequeo es una petición HTTP cuyo resultado hay que clasificar bien, incluso cuando no llega respuesta.

## Teoría

### Una petición

```python
import requests

r = requests.get("https://api.github.com/repos/EduardoGua/my-devops-journey",
                 headers={"Accept": "application/vnd.github+json"},
                 timeout=10)
r.status_code                   # 200
r.ok                            # True si el código es menor que 400
r.headers["Content-Type"]       # 'application/json; charset=utf-8'
datos = r.json()                # el cuerpo JSON como diccionario
datos["default_branch"]         # 'main'
r.elapsed.total_seconds()       # cuánto tardó la respuesta
```

`params={"per_page": 5}` añade `?per_page=5` a la URL, ya codificado. Para enviar datos, `requests.post(url, json={...})`. Repasa en la clase 32 los métodos y los códigos de estado.

### Siempre con `timeout`

Sin `timeout`, `requests` espera **indefinidamente** a que el servidor responda. Un servidor colgado colgaría tu programa (y tu cron, y tu pipeline). La regla no tiene excepciones: **toda petición lleva `timeout`**. Puede ser un número (`timeout=10`) o una pareja `(conectar, leer)`: `timeout=(3, 10)`.

### Dos clases de "fallo"

| Qué pasa | Qué hace `requests` | En Vigía v0 era |
|----------|---------------------|-----------------|
| el servidor responde 404, 500… | devuelve la respuesta normalmente, con ese `status_code` | `404 … DOWN` |
| el nombre no resuelve | lanza `ConnectionError` | `000 … DOWN` |
| la conexión se rechaza | lanza `ConnectionError` | `000 … DOWN` |
| nadie responde a tiempo | lanza `Timeout` (`ConnectTimeout` o `ReadTimeout`) | `000 … DOWN` a los 10 s |

Una respuesta 404 o 500 **no** es una excepción: el servidor contestó. Si quieres que lo sea, `r.raise_for_status()` lanza `HTTPError` cuando el código es 400 o más. Todas las excepciones de `requests` heredan de `requests.exceptions.RequestException`.

```python
from requests.exceptions import ConnectionError, RequestException, Timeout

try:
    r = requests.get(url, timeout=10)
except Timeout:                  # ¡antes que ConnectionError!
    ...
except ConnectionError:
    ...
except RequestException:         # cualquier otro problema de requests
    ...
```

El orden importa: `ConnectTimeout` es a la vez `Timeout` **y** `ConnectionError`. Python usa el primer `except` que encaja, así que si pusieras `ConnectionError` primero, un tiempo agotado al conectar se clasificaría como "conexión fallida".

### Redirecciones

`requests.get` sigue las redirecciones por defecto: pides `http://github.com`, recibes un 301 y `requests` va solo a `https://github.com/` y te da el 200 final (`r.history` guarda los pasos intermedios). Con `allow_redirects=False` te quedas con el 301. Vigía hará esto último, para que un 3xx cuente como UP igual que en la v0.

### Reintentar con cabeza

```python
for intento in range(1, 4):
    try:
        r = requests.get(url, timeout=5)
        break
    except (Timeout, ConnectionError):
        if intento == 3:
            raise
        time.sleep(2 ** intento)          # 2, 4… segundos: backoff exponencial (clase 18)
```

Reintenta solo lo que es seguro repetir (un `GET`) y ante fallos que pueden ser pasajeros (red, tiempo agotado, un 503). Nunca reintentes sin límite.

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
mkdir -p ~/my-devops-journey/labs/clase-49 && cd ~/my-devops-journey/labs/clase-49
```

`requests` ya está en tu entorno desde la clase 46.

### 1. Una petición desde el intérprete

```bash
python
```

```python
>>> import requests
>>> r = requests.get("https://example.com", timeout=10)
>>> r.status_code, r.ok, r.headers["Content-Type"]
>>> r.elapsed.total_seconds()
>>> r.text[:60]
>>> r = requests.get("http://github.com", timeout=10)
>>> r.status_code, r.url, [paso.status_code for paso in r.history]
>>> r = requests.get("http://github.com", timeout=10, allow_redirects=False)
>>> r.status_code, r.headers["Location"]
>>> exit()
```

🔮 **Predice** qué códigos verás con y sin `allow_redirects=False`.

### 2. Una API pública: GitHub

```bash
cat > repo_github.py <<'EOF'
#!/usr/bin/env python3
"""repo_github.py: muestra datos públicos de un repositorio de GitHub."""
import sys

import requests

API = "https://api.github.com"


def datos_repo(dueno: str, repo: str) -> dict:
    r = requests.get(f"{API}/repos/{dueno}/{repo}",
                     headers={"Accept": "application/vnd.github+json"}, timeout=10)
    print(f"(te quedan {r.headers.get('X-RateLimit-Remaining')} peticiones de "
          f"{r.headers.get('X-RateLimit-Limit')} esta hora)", file=sys.stderr)
    r.raise_for_status()
    return r.json()


def main() -> int:
    dueno = sys.argv[1] if len(sys.argv) > 1 else "EduardoGua"
    repo = sys.argv[2] if len(sys.argv) > 2 else "my-devops-journey"
    try:
        datos = datos_repo(dueno, repo)
    except requests.exceptions.HTTPError as e:
        print(f"Error: GitHub respondió {e.response.status_code} para {dueno}/{repo}", file=sys.stderr)
        return 1
    except requests.exceptions.RequestException as e:
        print(f"Error de red: {type(e).__name__}. ¿Hay conexión?", file=sys.stderr)
        return 1
    print(f"{datos['full_name']} · rama {datos['default_branch']} · "
          f"{datos['stargazers_count']} estrellas · último push {datos['pushed_at']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
python repo_github.py
python repo_github.py torvalds linux
python repo_github.py EduardoGua no-existe-este-repo ; echo "código: $?"
```

La API sin autenticar permite 60 peticiones por hora desde tu IP; las cabeceras `X-RateLimit-*` te dicen cuántas te quedan. `dueno` y `repo` toman los argumentos si los hay y, si no, unos valores por defecto (en la clase 48 lo harías con `argparse`).

Ahora el criterio de salida: **corta la red** (desactiva el wifi o desenchufa el cable) y vuelve a ejecutarlo.

```bash
python repo_github.py ; echo "código: $?"
```

Sale `Error de red: ConnectionError. ¿Hay conexión?` y código 1, sin traza. Vuelve a conectar la red.

### 3. Revisar una URL como lo hará Vigía

```bash
cat > revisar.py <<'EOF'
#!/usr/bin/env python3
"""revisar.py: revisa URLs y clasifica cada resultado."""
import sys
import time

import requests
from requests.exceptions import ConnectionError, RequestException, Timeout


def revisar(url: str, timeout: float = 10) -> dict:
    """Devuelve código, segundos, estado y, si no hubo respuesta, el motivo."""
    inicio = time.perf_counter()
    try:
        r = requests.get(url, timeout=timeout, allow_redirects=False)
        codigo, error = r.status_code, None
    except Timeout:
        codigo, error = 0, "timeout"
    except ConnectionError:
        codigo, error = 0, "connection"
    except RequestException as e:
        codigo, error = 0, type(e).__name__
    segundos = time.perf_counter() - inicio
    estado = "UP" if 200 <= codigo < 400 else "DOWN"
    return {"url": url, "codigo": codigo, "segundos": round(segundos, 3), "estado": estado, "error": error}


if __name__ == "__main__":
    for url in sys.argv[1:]:
        print(revisar(url, timeout=3))
EOF
time python revisar.py https://example.com https://example.com/no-existe http://github.com \
  https://no-existe.invalid http://192.0.2.1 example.com
```

🔮 **Predice** la línea de cada URL y el tiempo total. La última, `example.com` sin `https://`, no es una URL completa: `requests` lanza `MissingSchema`, que cae en el `except RequestException`. Vigía v1 la rechazará antes, al validar la configuración.

### 4. Reintentos con espera creciente

```bash
cat > con_reintentos.py <<'EOF'
import sys
import time

import requests
from requests.exceptions import ConnectionError, Timeout


def get_con_reintentos(url: str, intentos: int = 3, timeout: float = 2) -> requests.Response:
    for intento in range(1, intentos + 1):
        try:
            return requests.get(url, timeout=timeout)
        except (Timeout, ConnectionError) as e:
            print(f"intento {intento}/{intentos}: {type(e).__name__}", file=sys.stderr)
            if intento == intentos:
                raise
            time.sleep(2 ** (intento - 1))       # 1 s, 2 s…


try:
    r = get_con_reintentos(sys.argv[1])
    print("respuesta:", r.status_code)
except (Timeout, ConnectionError):
    print("no respondió tras los reintentos", file=sys.stderr)
    sys.exit(1)
EOF
python con_reintentos.py https://example.com
time python con_reintentos.py http://192.0.2.1 ; echo "código: $?"
```

🔮 **Predice** cuánto tardará la segunda: 3 intentos de 2 s más esperas de 1 y 2 s, unos 9 segundos.

## Rómpelo

**1. Sin `timeout`:**
```bash
python -c 'import requests; requests.get("http://192.0.2.1")'
```
Se queda esperando hasta que el sistema operativo se rinde con la conexión (más de dos minutos). Pulsa `Ctrl+C`. Así se cuelga un cron o un pipeline. Repite con `timeout=3`: `ConnectTimeout` a los 3 segundos.

**2. `except` en el orden equivocado:**
```bash
python -c '
import requests
from requests.exceptions import ConnectionError, Timeout
try:
    requests.get("http://192.0.2.1", timeout=2)
except ConnectionError:
    print("lo clasifico como: conexión fallida")
except Timeout:
    print("lo clasifico como: tiempo agotado")
'
```
Dice "conexión fallida", pero fue un tiempo agotado: `ConnectTimeout` hereda de las dos y gana el primer `except` que encaja. Pon siempre `Timeout` antes.

**3. Esperar un error que no llega:**
```bash
python -c '
import requests
r = requests.get("https://example.com/no-existe", timeout=10)
print("¿falló?", r.status_code)
r.raise_for_status()
'
```
La primera línea imprime 404 sin excepción: para `requests`, el servidor contestó y eso no es un error. Solo `raise_for_status()` lo convierte en `HTTPError`. Comprueba siempre el código.

**4. Pedir JSON a una página HTML:**
```bash
python -c 'import requests; requests.get("https://example.com", timeout=10).json()'
```
`requests.exceptions.JSONDecodeError: Expecting value: line 1 column 1 (char 0)`. La respuesta era HTML. Antes de llamar a `.json()`, comprueba el código y, si dudas, `r.headers["Content-Type"]`.

**5. Apagar la verificación TLS:**
```bash
python -c 'import requests; print(requests.get("https://expired.badssl.com/", timeout=10, verify=False).status_code)'
```
Funciona, pero con un aviso `InsecureRequestWarning`: con `verify=False` aceptas cualquier certificado, también el de un atacante en medio (clase 32). Sin `verify=False`, `requests` rechaza el certificado vencido con `SSLError`. En producción, `verify=False` es un error grave, no un arreglo.

## Reto

1. `repos_usuario.py <usuario>`: lista los repositorios públicos de un usuario de GitHub (`/users/<usuario>/repos`, con `params={"per_page": 100}`), ordenados por estrellas, con nombre, estrellas y lenguaje. Si el usuario no existe, mensaje claro y código 1; si no hay red, otro mensaje y código 1; nunca una traza.
2. Modifica `revisar.py` para que lea las URLs de un `config.yaml` como el de la clase 47 (`urls` y `timeout`) y muestre una tabla alineada en lugar de diccionarios.
3. ¿Qué devuelve `revisar("https://expired.badssl.com/")`? Explica por qué, para un usuario, ese sitio está caído aunque el servidor funcione.

## Cierre

En `notas/fase-4/clase-49.md`:

1. ¿Por qué toda petición debe llevar `timeout`? ¿Qué pasa sin él?
2. ¿Qué diferencia hay entre recibir un 503 y recibir un `ConnectionError`? ¿Cómo lo trata Vigía?
3. ¿Por qué el `except Timeout` va antes que el `except ConnectionError`?
4. **Repaso (clase 48, sin mirar):** ¿por qué los mensajes del log van a stderr y no a stdout?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque sin `timeout`, `requests` espera indefinidamente si el servidor acepta la conexión y no responde, o hasta que el sistema operativo abandona la conexión (minutos). Tu programa queda colgado, y con él el cron o el pipeline que lo lanzó.

**2.** Un 503 es una respuesta: el servidor contestó "no disponible", y `requests` la devuelve con `status_code=503`. Un `ConnectionError` es que no hubo respuesta HTTP (nombre que no resuelve, conexión rechazada), y `requests` lanza una excepción. Para Vigía los dos son DOWN, pero el primero se guarda con código 503 y el segundo con código 0 y el motivo en `error`.

**3.** Porque `ConnectTimeout` hereda a la vez de `Timeout` y de `ConnectionError`, y Python usa el primer `except` que encaja. Con `ConnectionError` primero, un tiempo agotado al conectar se clasificaría mal.

**4.** Para que stdout lleve solo los datos (que puedes redirigir a un archivo o pasar por un pipe) y los mensajes no los contaminen. Desde cron, puedes mandar cada flujo a un sitio distinto.

**Reto 1 (la parte central):**
```python
r = requests.get(f"https://api.github.com/users/{usuario}/repos",
                 params={"per_page": 100}, timeout=10)
if r.status_code == 404:
    print(f"Error: el usuario {usuario} no existe", file=sys.stderr)
    return 1
r.raise_for_status()
for repo in sorted(r.json(), key=lambda x: x["stargazers_count"], reverse=True):
    print(f"{repo['name']:<30} {repo['stargazers_count']:>6} ★  {repo['language'] or '-'}")
```
(dentro de un `try` con `except requests.exceptions.RequestException` para los fallos de red)

**Reto 3:** `{'codigo': 0, 'estado': 'DOWN', 'error': 'connection', …}`: `requests` rechaza el certificado vencido con `SSLError`, que hereda de `ConnectionError`. Un navegador mostraría un aviso de seguridad y la mayoría de usuarios no podría entrar: para ellos el sitio está caído. Por eso Vigía v0.2 avisa antes de que el certificado venza.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| request / response | petición / respuesta |
| timeout | tiempo de espera |
| rate limit | límite de peticiones |
| retry / backoff | reintento / espera creciente |
| redirect | redirección |

🎙️ *"Every HTTP call in my code has a timeout, treats network errors differently from HTTP error codes, and retries idempotent requests with exponential backoff."*

## Siguiente

[Clase 50 — Automatizar el sistema: subprocess, shutil y variables de entorno](clase-50-automatizar-el-sistema.md)
