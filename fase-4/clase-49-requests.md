# Clase 49 — Consumir APIs con requests

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** B. Python para operaciones

> 💡 **La idea de hoy:** la nube se maneja con APIs, y hablar con ellas desde un programa es hacer peticiones HTTP. Con `requests` cada petición es una línea, pero hay que distinguir dos cosas que en Vigía v0 se veían igual: que el servidor **responda con un error** (404, 500, 503) y que **no haya respuesta** (el nombre no resuelve, la conexión se rechaza o nadie contesta a tiempo). Lo primero llega como un `status_code`; lo segundo, como una excepción. Y toda petición lleva `timeout`.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los métodos y los códigos de estado HTTP, las redirecciones 3xx y los certificados TLS (clase 32).
> - Vigía v0: `curl -w '%{http_code}'`, que da `000` cuando no hay respuesta (clase 21).
> - Los reintentos con espera creciente de Bash (clase 18).
> - `try`/`except` y que una excepción puede heredar de otra (clase 44); el entorno virtual con `requests` instalado (clase 46).

> 🔤 **Palabras nuevas de hoy:**
> - **petición / respuesta** (*request / response*): lo que envías al servidor y lo que te devuelve.
> - **`timeout`**: el máximo de segundos que esperas una respuesta.
> - **redirección**: una respuesta 3xx que te manda a otra URL (cabecera `Location`).
> - **límite de peticiones** (*rate limit*): cuántas peticiones te deja hacer una API por hora.
> - **`User-Agent`**: la cabecera que dice qué programa hace la petición.
> - **backoff exponencial**: esperar cada vez el doble entre reintentos (1 s, 2 s, 4 s…).

## Objetivo

- Hacer peticiones HTTP con `requests`: parámetros, cabeceras, *timeout*, código de estado y cuerpo JSON.
- Distinguir los fallos de red (DNS, conexión rechazada, tiempo agotado) de las respuestas de error (404, 500), y tratar cada uno.
- Reintentar con esperas crecientes sin colgar el programa.
- Consumir una API pública real (la de GitHub) y sobrevivir a un error de red. Es un criterio de salida de esta fase.

## Por qué importa

La nube se maneja con APIs: AWS, GitHub, Docker Hub, Slack, el monitoreo… Todo lo que haces en una consola web tiene una API detrás, y automatizar consiste en hablar con ella desde un programa. Además, `requests` es el corazón de Vigía v1: cada chequeo es una petición HTTP cuyo resultado hay que clasificar bien, incluso cuando no llega respuesta.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior. La 5 junta todo en la función que usará Vigía.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
mkdir -p ~/my-devops-journey/labs/clase-49 && cd ~/my-devops-journey/labs/clase-49
```

`requests` ya está en tu entorno desde la clase 46. Necesitas conexión a internet.

## Las piezas

### Pieza 1 — Una petición, siempre con `timeout`

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

- `params={"per_page": 5}` añade `?per_page=5` a la URL, ya codificado. Para enviar datos, `requests.post(url, json={...})`.
- **Toda petición lleva `timeout`.** Sin él, `requests` espera **indefinidamente** a que el servidor responda, y un servidor colgado colgaría tu programa (y tu cron, y tu pipeline). Puede ser un número (`timeout=10`) o una pareja `(conectar, leer)`: `timeout=(3, 10)`.
- Un programa educado **se identifica** con la cabecera `User-Agent`. La de `requests` es genérica (`python-requests/2.34.2`) y algunos sitios la bloquean para frenar robots (Rómpelo 6). Para un programa tuyo, usa una propia: `headers={"User-Agent": "Vigia/1.0 (+https://github.com/TU_USUARIO/vigia)"}`.

**Pruébalo:**

```bash
python
```

```python
>>> import requests
>>> r = requests.get("https://example.com", timeout=10)
>>> r.status_code, r.ok, r.headers["Content-Type"]
>>> r.elapsed.total_seconds()
>>> r.text[:60]
```

👀 **Qué deberías ver:** `(200, True, 'text/html; charset=utf-8')`; un tiempo de unas décimas de segundo; y el principio del HTML, que empieza por `<!doctype html>`. Esta página no es JSON: `r.text` es el cuerpo como texto. No salgas todavía del intérprete.

✋ **Sin mirar:** ¿qué añade `params={"per_page": 5}` a la URL?

<details>
<summary>Comprueba</summary>

`?per_page=5`, ya codificado: no tienes que montar la URL a mano.
</details>

**En resumen:** `requests.get(url, timeout=…)` devuelve una respuesta con `status_code`, `headers`, `text` y `.json()`; sin `timeout`, nunca.

### Pieza 2 — Redirecciones

`requests.get` sigue las redirecciones por defecto: pides `http://github.com`, recibes un 301 y `requests` va solo a `https://github.com/` y te da el 200 final. `r.history` guarda los pasos intermedios. Con `allow_redirects=False` te quedas con el 301. Vigía hará esto último, para que un 3xx cuente como UP igual que en la v0.

🔮 **Predice** qué códigos verás con y sin `allow_redirects=False`.

**Pruébalo** (en el mismo intérprete):

```python
>>> r = requests.get("http://github.com", timeout=10)
>>> r.status_code, r.url, [paso.status_code for paso in r.history]
>>> r = requests.get("http://github.com", timeout=10, allow_redirects=False)
>>> r.status_code, r.headers["Location"]
>>> exit()
```

👀 **Qué deberías ver:** `(200, 'https://github.com/', [301])`: el 301 quedó en el historial. Y sin seguir la redirección, `(301, 'https://github.com/')`: la cabecera `Location` dice adónde ir.

✋ **Sin mirar:** pides `http://github.com` sin más opciones. ¿Qué `status_code` recibes, y dónde quedó el 301?

<details>
<summary>Comprueba</summary>

200, el de la página final. El 301 quedó en `r.history`.
</details>

**En resumen:** `requests` sigue las redirecciones solo; `allow_redirects=False` te da la respuesta 3xx tal cual.

### Pieza 3 — Dos clases de "fallo"

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

El orden importa: `ConnectTimeout` es a la vez `Timeout` **y** `ConnectionError`. Python usa el primer `except` que encaja, así que si pusieras `ConnectionError` primero, un tiempo agotado al conectar se clasificaría como "conexión fallida" (lo verás en el Rómpelo 2).

🔮 **Predice** qué imprimirá cada URL: una página que no existe, un dominio que no existe y una IP de documentación (192.0.2.1) a la que nadie responde.

**Pruébalo:**

```bash
python -c '
import requests
from requests.exceptions import ConnectionError, Timeout
for url in ["https://example.com/no-existe", "https://no-existe.invalid", "http://192.0.2.1"]:
    try:
        r = requests.get(url, timeout=3)
        print(url, "→ respuesta", r.status_code)
    except Timeout as e:
        print(url, "→ excepción", type(e).__name__)
    except ConnectionError as e:
        print(url, "→ excepción", type(e).__name__)
'
```

👀 **Qué deberías ver:** `→ respuesta 404` para la primera: el servidor contestó. `→ excepción ConnectionError` para la segunda, al instante: el nombre no resuelve. Y `→ excepción ConnectTimeout` para la tercera, a los 3 segundos.

✋ **Sin mirar:** ¿un 500 hace que `requests.get` lance una excepción?

<details>
<summary>Comprueba</summary>

No: devuelve la respuesta con `status_code=500`. Solo `r.raise_for_status()` la convierte en `HTTPError`.
</details>

**En resumen:** los códigos de error llegan como respuesta; la falta de respuesta llega como excepción, y `Timeout` se captura antes que `ConnectionError`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `source ~/my-devops-journey/labs/.venv/bin/activate` y `cd ~/my-devops-journey/labs/clase-49`.

### Pieza 4 — Una API pública: GitHub

La API de GitHub sin autenticar permite **60 peticiones por hora** desde tu IP; las cabeceras `X-RateLimit-Limit` y `X-RateLimit-Remaining` te dicen cuántas te quedan. Este programa pide los datos de un repositorio y trata los dos tipos de fallo de la pieza 3.

**Pruébalo:**

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

👀 **Qué deberías ver:** una línea con el nombre, la rama, las estrellas y la fecha del último push de tu repositorio y del de Linux, cada una precedida de `(te quedan … peticiones de 60 esta hora)`; y para el repositorio que no existe, `Error: GitHub respondió 404 para EduardoGua/no-existe-este-repo` y `código: 1`, sin traza. `dueno` y `repo` toman los argumentos si los hay y, si no, unos valores por defecto (con lo de la clase 48 lo harías con `argparse`).

Ahora el criterio de salida: **corta la red** (desactiva el wifi o desenchufa el cable) y vuelve a ejecutarlo.

```bash
python repo_github.py ; echo "código: $?"
```

👀 **Qué deberías ver:** `Error de red: ConnectionError. ¿Hay conexión?` y `código: 1`, sin traza. Vuelve a conectar la red.

✋ **Sin mirar:** ¿qué cabecera te dice cuántas peticiones te quedan en la API de GitHub?

<details>
<summary>Comprueba</summary>

`X-RateLimit-Remaining` (y `X-RateLimit-Limit`, el total por hora: 60 sin autenticar).
</details>

**En resumen:** con `raise_for_status()` y dos `except` (`HTTPError` y `RequestException`) un programa sobrevive a un 404 y a un corte de red con un mensaje claro.

### Pieza 5 — Revisar una URL como lo hará Vigía

La función `revisar` junta todo: `timeout`, sin seguir redirecciones, los `except` en el orden correcto y un diccionario con el resultado. `time.perf_counter()` mide el tiempo también cuando no hubo respuesta (y no hay `r.elapsed`).

**Pruébalo:**

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

🔮 **Predice** la línea de cada URL y el tiempo total.

👀 **Qué deberías ver:** `200 UP` para `example.com`; `404 DOWN` con `error: None` para la página que no existe (el servidor contestó); `301 UP` para `http://github.com`; `0 DOWN` con `error: 'connection'` para el dominio que no existe; `0 DOWN` con `error: 'timeout'` y unos 3 segundos para 192.0.2.1; y `0 DOWN` con `error: 'MissingSchema'` para la última. `example.com` sin `https://` no es una URL completa: `requests` lanza `MissingSchema`, que cae en el `except RequestException`. Vigía v1 la rechazará antes, al validar la configuración. En total, unos 4 segundos: casi todo es la espera de 192.0.2.1.

✋ **Sin mirar:** en `revisar`, ¿qué `codigo`, `estado` y `error` devuelve una URL cuyo nombre no resuelve?

<details>
<summary>Comprueba</summary>

`codigo` 0, `estado` `DOWN` y `error` `'connection'`: el mismo `000 … DOWN` de Vigía v0, pero ahora con el motivo.
</details>

**En resumen:** `revisar` devuelve siempre un diccionario: con respuesta, su código; sin respuesta, código 0 y el motivo en `error`.

### Pieza 6 — Reintentar con cabeza

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

🔮 **Predice** cuánto tardará la segunda ejecución: 3 intentos de 2 s más esperas de 1 y 2 s.

**Pruébalo:**

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

👀 **Qué deberías ver:** `respuesta: 200` a la primera. En la segunda, `intento 1/3: ConnectTimeout`, `intento 2/3…` e `intento 3/3…`, luego `no respondió tras los reintentos`, unos 9 segundos en total y `código: 1`.

✋ **Sin mirar:** ¿qué peticiones es seguro reintentar, y ante qué fallos?

<details>
<summary>Comprueba</summary>

Las que se pueden repetir sin efectos extra, como un `GET`, y ante fallos pasajeros: red, tiempo agotado o un 503. Siempre con un número máximo de intentos.
</details>

**En resumen:** un bucle con `try`, `time.sleep(2 ** …)` entre intentos y un `raise` en el último: reintentos con límite y espera creciente.

## Tu chuleta de la clase

| Escribes | Qué hace |
|----------|----------|
| `requests.get(url, timeout=10)` | una petición; el `timeout`, siempre |
| `params={…}` · `headers={…}` · `requests.post(url, json={…})` | parámetros · cabeceras · enviar JSON |
| `r.status_code` · `r.ok` · `r.headers[…]` · `r.text` · `r.json()` · `r.elapsed` | leer la respuesta |
| `allow_redirects=False` · `r.history` | no seguir redirecciones · los pasos seguidos |
| `r.raise_for_status()` | convertir un 4xx/5xx en `HTTPError` |
| `except Timeout` → `except ConnectionError` → `except RequestException` | los fallos sin respuesta, en este orden |
| `time.perf_counter()` | medir el tiempo, haya o no respuesta |
| `time.sleep(2 ** (intento - 1))` | backoff exponencial entre reintentos |
| `headers={"User-Agent": "Vigia/1.0 (+…)"}` | identificar tu programa |

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

**6. El `User-Agent` que algunos sitios bloquean:**
```bash
python -c '
import requests
print("por defecto:", requests.get("https://www.wikipedia.org", timeout=10).status_code)
agente = {"User-Agent": "Vigia/1.0 (+https://github.com/TU_USUARIO/vigia)"}
print("identificado:", requests.get("https://www.wikipedia.org", timeout=10, headers=agente).status_code)
'
```
Comprobado en octubre de 2026: **403** con el `User-Agent` de `requests` y **200** con uno propio (con `curl`, también 200). Wikipedia exige que los programas se identifiquen. Para un monitor, un 403 así sería una falsa alarma: Vigía v1 enviará su propio `User-Agent`.

## Reto

En `labs/clase-49/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** `repos_usuario.py <usuario>`: lista los repositorios públicos de un usuario de GitHub, ordenados por estrellas, con nombre, estrellas y lenguaje. Si el usuario no existe, mensaje claro y código 1; si no hay red, otro mensaje y código 1; nunca una traza.

> 🧩 **Ejemplo resuelto:** `datos_repo` y `main` de la pieza 4: piden `/repos/{dueno}/{repo}` y tratan el 404 y el corte de red.

**Ahora tú, con huecos** (la parte central, dentro de un `try` con `except requests.exceptions.RequestException`, como en `main`):
```python
r = requests.get(f"https://api.github.com/users/{usuario}/____",
                 params={"per_page": ____}, timeout=10)
if r.status_code == ____:
    print(f"Error: el usuario {usuario} no existe", file=sys.stderr)
    return 1
r.raise_for_status()
for repo in sorted(r.json(), key=lambda x: x["____"], reverse=True):
    print(f"{repo['name']:<30} {repo['stargazers_count']:>6} ★  {repo['language'] or '-'}")
```

<details>
<summary>Pista</summary>

La API devuelve 30 repositorios por página si no pides más; el máximo es 100. `repo['language']` puede ser `None`, y por eso el `or '-'`. Ordenar con `key=lambda` es lo de la clase 41.
</details>

**2.** Modifica `revisar.py` para que lea las URLs de un `config.yaml` como el de la clase 47 (`urls` y `timeout`) y muestre una tabla alineada en lugar de diccionarios.

> 🧩 **Ejemplo resuelto:** la pieza 3 de la clase 47: `with open("config.yaml", encoding="utf-8") as f: config = yaml.safe_load(f)`.

**Ahora tú, con huecos** (sustituye el bloque `if __name__ == "__main__":` y añade `import yaml` arriba):
```python
if __name__ == "__main__":
    with open("config.yaml", encoding="utf-8") as f:
        config = yaml.safe_load(f)
    for url in config["____"]:
        res = revisar(url, timeout=config["____"])
        print(f"{res['estado']:<5} {res['codigo']:>3} {res['segundos']:>7.3f} s  {res['url']}  {res['error'] or ''}")
```

<details>
<summary>Pista</summary>

Copia el archivo con `cp ../clase-47/config.yaml .`. `:<5` alinea a la izquierda en 5 caracteres y `:>3`, a la derecha (clase 41).
</details>

**3.** ¿Qué devuelve `revisar("https://expired.badssl.com/")`? Explica por qué, para un usuario, ese sitio está caído aunque el servidor funcione.

> 🧩 **Ejemplo resuelto:** el Rómpelo 5: sin `verify=False`, `requests` rechaza el certificado vencido con `SSLError`.

**Ahora tú, con huecos:** ejecuta `python -c 'from revisar import revisar; print(revisar("https://expired.badssl.com/"))'` y completa: «Devuelve `codigo` ____ y `error` ____, porque `SSLError` hereda de ____. Para un usuario está caído porque el navegador ____».

<details>
<summary>Pista</summary>

`python -c 'import requests; print(requests.exceptions.SSLError.__mro__)'` muestra de qué clases hereda.
</details>

## Cierre

En `notas/fase-4/clase-49.md`:

1. ¿Por qué toda petición debe llevar `timeout`? ¿Qué pasa sin él? *(2 líneas. Empieza así: «Porque sin `timeout`, requests espera… y mi programa…»)*
2. ¿Qué diferencia hay entre recibir un 503 y recibir un `ConnectionError`? ¿Cómo lo trata Vigía? *(2–3 líneas. Empieza así: «Un 503 es una respuesta: el servidor contestó… Un `ConnectionError` es que no hubo… Para Vigía los dos son DOWN, pero…»)*
3. ¿Por qué el `except Timeout` va antes que el `except ConnectionError`? *(1–2 líneas. Empieza así: «Porque `ConnectTimeout` hereda de las dos, y Python…»)*
4. **Repaso (clase 48, sin mirar):** ¿por qué los mensajes del log van a stderr y no a stdout? *(1–2 líneas. Empieza así: «Para que stdout lleve solo los datos y…»)*

Después, escríbeme `examíname clase-49`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque sin `timeout`, `requests` espera indefinidamente si el servidor acepta la conexión y no responde, o hasta que el sistema operativo abandona la conexión (minutos). Tu programa queda colgado, y con él el cron o el pipeline que lo lanzó.

**2.** Un 503 es una respuesta: el servidor contestó "no disponible", y `requests` la devuelve con `status_code=503`. Un `ConnectionError` es que no hubo respuesta HTTP (nombre que no resuelve, conexión rechazada), y `requests` lanza una excepción. Para Vigía los dos son DOWN, pero el primero se guarda con código 503 y el segundo con código 0 y el motivo en `error`.

**3.** Porque `ConnectTimeout` hereda a la vez de `Timeout` y de `ConnectionError`, y Python usa el primer `except` que encaja. Con `ConnectionError` primero, un tiempo agotado al conectar se clasificaría mal.

**4.** Para que stdout lleve solo los datos (que puedes redirigir a un archivo o pasar por un pipe) y los mensajes no los contaminen. Desde cron, puedes mandar cada flujo a un sitio distinto.

**Reto 1:** `repos`, `100`, `404` y `stargazers_count`. Completo:
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

**Reto 2:** `config["urls"]` y `config["timeout"]`.

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
