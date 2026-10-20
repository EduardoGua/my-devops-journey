# Clase 46 — Entornos virtuales y dependencias

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** B. Python para operaciones

> 💡 **La idea de hoy:** cada proyecto necesita sus librerías, en sus versiones. Un **entorno virtual** (`venv`) es una carpeta con un Python solo para ese proyecto, donde `pip` instala sin tocar el Python de Ubuntu. Y `requirements.txt` apunta las versiones exactas, para que tu portátil, el servidor, el contenedor y el pipeline tengan **lo mismo**. "En mi máquina funciona" empieza a desaparecer aquí.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El PATH y `source`, que ejecuta un archivo en tu propio shell (clase 07).
> - Instalar con `apt` y lo peligroso de tocar el sistema (clase 10).
> - `shellcheck`, que revisa un script sin ejecutarlo (clase 19, pieza 6).
> - `.gitignore`: lo que no se sube a Git (clase 22, pieza 5).
> - Rutas absolutas en cron (clase 20, pieza 3).

> 🔤 **Palabras nuevas de hoy:**
> - **entorno virtual** (`venv`): una carpeta (`.venv`) con un Python y un `pip` para un solo proyecto.
> - **`pip`**: el programa que instala librerías de Python desde PyPI.
> - **dependencia**: una librería que tu código necesita (y las que necesita ella).
> - **`requirements.txt`**: la lista de dependencias con sus versiones exactas.
> - **`pipx`**: instala un **programa** de Python en su propio entorno y lo deja en tu PATH.
> - **`ruff`**: el revisor de código de Python, como `shellcheck` para Bash.

## Objetivo

- Entender por qué Ubuntu no te deja instalar paquetes con `pip` en el Python del sistema.
- Crear, activar y desactivar un **entorno virtual** (`venv`), y usarlo también sin activarlo, como haría cron.
- Instalar dependencias con `pip` y fijarlas en `requirements.txt` para reproducir el entorno en otra máquina.
- Instalar herramientas de línea de comandos con `pipx`, empezando por `ruff`, el `shellcheck` de Python.

## Por qué importa

Cada proyecto necesita sus librerías, en sus versiones. Si las instalas todas en el mismo sitio, tarde o temprano dos proyectos piden versiones incompatibles, o una actualización rompe una herramienta del sistema. El entorno virtual aísla las dependencias de cada proyecto, y `requirements.txt` permite que tu portátil, el servidor, el contenedor de Docker (fase 5) y el pipeline de CI (fase 7) tengan **exactamente** las mismas versiones.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

```bash
mkdir -p ~/my-devops-journey/labs/clase-46 && cd ~/my-devops-journey/labs/clase-46
```

## Las piezas

### Pieza 1 — El Python del sistema es de Ubuntu

Herramientas de Ubuntu como `apt` o `netplan` están escritas en Python y dependen de las librerías que instala `apt`. Si `pip` cambiara esas librerías, podría romperlas. Por eso Ubuntu marca su Python como **gestionado externamente** (la norma PEP 668), y `pip install` fuera de un entorno virtual falla.

Hay tres formas correctas de instalar algo de Python:

| Qué quieres | Cómo | Ejemplo |
|-------------|------|---------|
| una librería para **tu proyecto** | `pip` dentro de un entorno virtual | `requests` para Vigía |
| un **programa** de Python para usar en la terminal | `pipx` (crea un entorno aislado para él) | `ruff` |
| una librería que necesita **otro programa del sistema** | `apt install python3-…` | rara vez lo necesitarás |

Lo que **no** se hace: `pip install --break-system-packages` o `sudo pip install`. El nombre de la opción ya avisa.

**Pruébalo:**

```bash
pip install requests
```

👀 **Qué deberías ver:** `error: externally-managed-environment` y `× This environment is externally managed`, y debajo te propone `apt install python3-xyz` o crear un entorno virtual. Es la protección de la que habla esta pieza.

✋ **Sin mirar:** ¿qué dos formas de "saltarse" ese error no se usan nunca?

<details>
<summary>Comprueba</summary>

`pip install --break-system-packages` y `sudo pip install`: las dos pueden romper herramientas del propio Ubuntu.
</details>

**En resumen:** el Python de Ubuntu no se toca con `pip`; las librerías de tus proyectos van en un entorno virtual.

### Pieza 2 — `venv`: un Python solo para tu proyecto

```bash
python3 -m venv .venv               # crea la carpeta .venv con su propio python y pip
source .venv/bin/activate           # actívalo: tu prompt muestra (.venv)
which python                        # …/.venv/bin/python (dentro sí existe "python")
pip install requests                # se instala en .venv, no en el sistema
deactivate                          # vuelves al Python del sistema
```

**Activar** solo cambia el PATH de tu terminal (clase 07) para que `python` y `pip` sean los de `.venv`. Sin activar, puedes llamarlos por su ruta: `.venv/bin/python script.py`. Es lo que pondrás en cron, que no activa nada.

La carpeta `.venv` **no** se sube a Git: pesa, depende de tu máquina y se recrea en un minuto. Tu `.gitignore` del curso ya la ignora.

**Pruébalo: el entorno de tus laboratorios.** Para las clases 46 a 53 usarás un solo entorno, en la carpeta `labs`:

```bash
cd ~/my-devops-journey/labs
python3 -m venv .venv
ls .venv .venv/bin
source .venv/bin/activate
which python pip
python --version
grep -n venv ~/my-devops-journey/.gitignore
```

🔮 **Predice:** ¿qué devolverá `which python` ahora? ¿Y después de `deactivate`?

👀 **Qué deberías ver:** `bin`, `include`, `lib`, `lib64` y `pyvenv.cfg` dentro de `.venv`, y en `bin`, `activate`, `pip` y `python`; tu prompt empezando por `(.venv)`; `which` apuntando a `…/labs/.venv/bin/python` y `…/pip`; `Python 3.14.x`; y la línea `.venv/` en el `.gitignore`.

A partir de aquí, cada sesión de estas clases empieza con `source ~/my-devops-journey/labs/.venv/bin/activate`.

✋ **Sin mirar:** ¿se sube la carpeta `.venv` a Git? ¿Por qué?

<details>
<summary>Comprueba</summary>

No: pesa, depende de la máquina donde se creó y se recrea en un minuto desde `requirements.txt` (pieza 4).
</details>

**En resumen:** `python3 -m venv .venv` crea el entorno, `source .venv/bin/activate` lo usa en tu terminal y `.venv/bin/python` lo usa sin activarlo.

### Pieza 3 — `requirements.txt`: las dependencias, fijadas

```
requests==2.34.2
PyYAML==6.0.3
```

| Comando | Qué hace |
|---------|----------|
| `pip freeze > requirements.txt` | escribe las versiones exactas de todo lo instalado |
| `pip install -r requirements.txt` | instala exactamente esa lista |
| `pip list` / `pip show requests` | qué hay instalado / detalles y dependencias de un paquete |

Formas de indicar la versión: `==2.34.2` (exacta: reproducible), `>=2.30` (como mínimo: arriesgado), `~=2.34.0` (2.34.x: acepta correcciones). En aplicaciones que despliegas, fija versiones exactas: así el contenedor de mañana es igual que el de hoy.

Es habitual separar las dependencias de desarrollo:

```
# requirements-dev.txt
-r requirements.txt          # incluye las de producción
pytest==9.1.1
```

Producción instala `requirements.txt`; tú y el CI, `requirements-dev.txt`.

**Pruébalo**, con el entorno activado:

```bash
pip install requests
pip list
pip show requests
pip freeze > clase-46/requirements.txt
cat clase-46/requirements.txt
cat > clase-46/version.py <<'EOF'
import requests
r = requests.get("https://example.com", timeout=10)
print(f"requests {requests.__version__}: example.com respondió {r.status_code}")
EOF
python clase-46/version.py
```

👀 **Qué deberías ver:** pediste un paquete y llegaron cinco: `requests` depende de `urllib3`, `idna`, `certifi` y `charset-normalizer` (`pip show` las muestra en `Requires`). `requirements.txt` las fija todas, cada una con `==`. Y al final, `requests 2.x.x: example.com respondió 200`.

✋ **Sin mirar:** si solo instalaste `requests`, ¿por qué `pip freeze` apunta cinco paquetes?

<details>
<summary>Comprueba</summary>

Porque `requests` depende de otros cuatro, y cualquiera de ellos podría cambiar el comportamiento: se fijan todos.
</details>

**En resumen:** `pip freeze > requirements.txt` apunta las versiones exactas de todo, dependencias incluidas.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `source ~/my-devops-journey/labs/.venv/bin/activate`.

### Pieza 4 — Reproducir el entorno desde cero

Un entorno no se copia de una máquina a otra: se **recrea** desde `requirements.txt`. Así lo harán el servidor, el contenedor y el pipeline.

**Pruébalo**, en otra carpeta y sin activar nada:

```bash
cd /tmp && rm -rf prueba-venv && mkdir prueba-venv && cd prueba-venv
python3 -m venv .venv
.venv/bin/pip install -q -r ~/my-devops-journey/labs/clase-46/requirements.txt
.venv/bin/pip freeze | diff - ~/my-devops-journey/labs/clase-46/requirements.txt && echo "idénticos"
.venv/bin/python ~/my-devops-journey/labs/clase-46/version.py
cd ~/my-devops-journey/labs
```

👀 **Qué deberías ver:** `idénticos` (el `diff` no encontró ninguna diferencia) y la misma línea de `version.py` que en la pieza 3. `.venv/bin/pip` y `.venv/bin/python` son los del entorno, aunque no esté activado.

✋ **Sin mirar:** ¿cómo usas el `pip` de un entorno sin activarlo?

<details>
<summary>Comprueba</summary>

Por su ruta: `.venv/bin/pip install …` (y `.venv/bin/python script.py` para el intérprete).
</details>

**En resumen:** un entorno se recrea en cualquier sitio con `python3 -m venv .venv` y `.venv/bin/pip install -r requirements.txt`.

### Pieza 5 — Programas de Python con `pipx`: `ruff`

`pipx` instala un programa de Python en su propio entorno y lo deja disponible en tu PATH. Ya lo tienes instalado. `ruff` es a Python lo que `shellcheck` a Bash (clase 19): lee el código sin ejecutarlo y avisa de errores típicos, como un `import` que no se usa o `== None`, que debe escribirse `is None`.

**Pruébalo:**

```bash
pipx install ruff
ruff --version
cat > clase-46/sucio.py <<'EOF'
import os
import sys
x = 1
if x == None:
    print(x)
EOF
ruff check clase-46/sucio.py
```

👀 **Qué deberías ver:** `ruff 0.x.x` y tres avisos con su código: `F401` dos veces (`os` y `sys` importados pero sin usar) y `E711` (comparación con `None`, que debe ser `is None`). Muchos se arreglan solos con `ruff check --fix`. Lo usarás en Vigía y en el pipeline de la fase 7.

Si `ruff` no se encuentra después de instalarlo, ejecuta `pipx ensurepath` y abre una terminal nueva.

✋ **Sin mirar:** ¿por qué `ruff` se instala con `pipx` y no con `pip` dentro del entorno de un proyecto?

<details>
<summary>Comprueba</summary>

Porque es un **programa** que usas en la terminal para todos tus proyectos, no una librería que importe tu código: `pipx` le da su propio entorno y lo deja en el PATH.
</details>

**En resumen:** `pipx install programa` para herramientas de terminal; `ruff check` revisa el código de Python.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `python3 -m venv .venv` | crear un entorno virtual |
| `source .venv/bin/activate` · `deactivate` | usarlo en esta terminal · dejar de usarlo |
| `.venv/bin/python script.py` · `.venv/bin/pip …` | usarlo sin activarlo (cron, scripts) |
| `pip install paquete` · `pip install -r requirements.txt` | instalar uno · instalar la lista |
| `pip freeze > requirements.txt` | fijar las versiones exactas |
| `pip list` · `pip show paquete` | qué hay · detalles y dependencias |
| `paquete==1.2.3` · `>=1.2` · `~=1.2.0` | exacta · como mínimo · solo correcciones |
| `pipx install programa` · `pipx ensurepath` | instalar una herramienta · añadirla al PATH |
| `ruff check archivo.py` · `ruff check --fix` | revisar · arreglar lo automático |

## Rómpelo

**1. Olvidar activar el entorno:**
```bash
deactivate
python3 clase-46/version.py
```
`ModuleNotFoundError: No module named 'requests'`. El `python3` del sistema no ve lo que instalaste en `.venv`. Es el error más frecuente de esta fase: cuando lo veas, mira el prompt y busca el `(.venv)`. Vuelve a activarlo con `source .venv/bin/activate`.

**2. Congelar el entorno equivocado:**
```bash
pip freeze | head
```
Fuera del entorno, `pip freeze` lista las librerías de Python **del sistema** (las que instaló `apt`). Un `requirements.txt` hecho así tendría decenas de paquetes que tu proyecto no usa. Congela siempre con el entorno activado.

**3. Un entorno no se mueve:**
```bash
cd /tmp && mv prueba-venv prueba-movida && prueba-movida/.venv/bin/pip --version ; cd ~/my-devops-journey/labs
```
`intérprete erróneo: No existe el archivo o el directorio`: los scripts de `.venv/bin` guardan la ruta absoluta de donde se creó el entorno. Un entorno virtual no se copia ni se mueve: se **recrea** desde `requirements.txt`. Por eso no se sube a Git.

**4. La versión sin fijar:**
```bash
grep -c "==" clase-46/requirements.txt
```
Imagina que `requirements.txt` solo dijera `requests`, sin versión. Hoy instalaría la 2.34; dentro de seis meses, la que haya salido, que podría cambiar algo o traer un fallo nuevo. Tu contenedor de producción sería distinto del que probaste. Por eso se fijan las versiones exactas, y se actualizan **a propósito**, probando, no por sorpresa.

## Reto

En `labs/clase-46/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Crea `miniproyecto/` con su propio `.venv`, instala `requests` y `PyYAML`, escribe un `requirements.txt` con versiones fijas y un `requirements-dev.txt` que lo incluya y añada `pytest`.

> 🧩 **Ejemplo resuelto:** el entorno de `labs` de la pieza 2, con su `requirements.txt` de la pieza 3.

**Ahora tú, con huecos:**
```bash
mkdir -p miniproyecto && cd miniproyecto
python3 -m venv ____ && source .venv/bin/activate
pip install requests ____
pip ____ > requirements.txt
printf -- '-r ____\npytest==9.1.1\n' > requirements-dev.txt
pip install -r requirements-dev.txt
```

<details>
<summary>Pista</summary>

`-r` dentro de un `requirements-dev.txt` incluye otro archivo de requisitos: el de producción.
</details>

**2.** Escribe `chequeo.py`, que lea de un archivo `sitios.yaml` una lista de URLs y muestre el código HTTP de cada una con `requests` (con `timeout=10`).

> 🧩 **Ejemplo resuelto:** `version.py` (pieza 3) hace la petición para **una** URL fija.

**Ahora tú, con huecos:** con `sitios.yaml` así:
```yaml
urls:
  - https://example.com
  - https://github.com
```
```python
from pathlib import Path
import requests
import yaml

datos = yaml.safe_load(Path("sitios.yaml").read_text(encoding="utf-8"))
for url in datos["____"]:
    r = requests.get(url, timeout=____)
    print(url, r.status_code)
```

<details>
<summary>Pista</summary>

`yaml.safe_load` convierte el YAML en un diccionario de Python: su clave es la palabra de la primera línea del archivo. Lo verás a fondo en la clase 47.
</details>

**3.** Demuestra que es reproducible: borra el `.venv`, recréalo desde `requirements-dev.txt` y vuelve a ejecutar `chequeo.py`.

> 🧩 **Ejemplo resuelto:** la pieza 4, en `/tmp/prueba-venv`.

**Ahora tú, con huecos:**
```bash
deactivate; rm -rf .venv
python3 -m venv .venv
.venv/bin/pip install -q -r ____
.venv/bin/python ____
```

<details>
<summary>Pista</summary>

Instala desde el archivo de **desarrollo**, que ya incluye el de producción.
</details>

**4.** Pásale `ruff check` a tus scripts de las clases 39 a 45 y arregla los avisos.

> 🧩 **Ejemplo resuelto:** `ruff check clase-46/sucio.py` y, después, `ruff check --fix clase-46/sucio.py`.

**Ahora tú, con huecos:** `ruff check ~/my-devops-journey/labs/clase-____ ~/my-devops-journey/labs/clase-____` (y así hasta la 45). Lo que no arregle `--fix`, arréglalo a mano.

<details>
<summary>Pista</summary>

`ruff check` acepta varias carpetas a la vez, o una con comodín: `~/my-devops-journey/labs/clase-4*`.
</details>

## Cierre

En `notas/fase-4/clase-46.md`:

1. ¿Por qué Ubuntu no te deja hacer `pip install` en el Python del sistema? ¿Qué tres alternativas correctas tienes? *(2–3 líneas. Empieza así: «Porque ese Python lo usan herramientas de Ubuntu como…, y `pip` podría… Las alternativas: un entorno virtual para…, `pipx` para… y `apt` para…»)*
2. ¿Qué cambia exactamente cuando activas un entorno virtual? ¿Cómo usas el entorno desde cron, que no lo activa? *(2 líneas. Empieza así: «Solo cambia el PATH de la terminal, para que… Desde cron llamo al intérprete por su ruta:…»)*
3. ¿Para qué sirve fijar versiones exactas en `requirements.txt`? ¿Qué podría pasar sin ellas? *(2 líneas. Empieza así: «Para que cualquier máquina instale exactamente… Sin ellas, cada instalación traería…»)*
4. **Repaso (clase 45, sin mirar):** ¿por qué un archivo tuyo llamado `random.py` puede romper un programa? *(1–2 líneas. Empieza así: «Porque Python busca primero en la carpeta…»)*

Después, escríbeme `examíname clase-46`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque ese Python lo usan herramientas del propio Ubuntu con las librerías que instala `apt`, y `pip` podría cambiarlas y romperlas (PEP 668: entorno gestionado externamente). Alternativas: un entorno virtual con `pip` para las librerías de tus proyectos, `pipx` para programas de línea de comandos, y `apt install python3-…` para librerías que necesita el sistema.

**2.** Solo el PATH de esa terminal (y el prompt): `.venv/bin` pasa delante, así que `python` y `pip` son los del entorno. Desde cron se llama al intérprete del entorno por su ruta absoluta: `/home/educo/proyecto/.venv/bin/python script.py`.

**3.** Para que cualquier máquina (tu portátil, el servidor, el contenedor, el CI) instale exactamente lo que probaste. Sin versiones fijas, cada instalación trae la última publicada: un cambio o un fallo de una dependencia, o de una dependencia de una dependencia, puede romper tu aplicación sin que hayas tocado nada.

**4.** Porque Python busca primero en la carpeta del script o en la actual, y tu archivo tapa el módulo estándar del mismo nombre.

**Reto:** 1) `.venv`, `PyYAML`, `freeze` y `requirements.txt`. 2) `urls` y `10`. 3) `requirements-dev.txt` y `chequeo.py`. 4) Las carpetas de tus clases; `--fix` arregla los `import` sin usar y la mayoría de los detalles de estilo.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| virtual environment | entorno virtual |
| dependency / to pin a version | dependencia / fijar una versión |
| reproducible build | construcción reproducible |
| package index (PyPI) | repositorio de paquetes |
| linter | analizador de código |

🎙️ *"Every Python project I work on has its own virtual environment and pinned requirements, so the same versions run on my laptop, in CI and in the container."*

## Siguiente

[Clase 47 — JSON, CSV y YAML](clase-47-json-csv-yaml.md)
