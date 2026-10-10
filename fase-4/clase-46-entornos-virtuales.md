# Clase 46 — Entornos virtuales y dependencias

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** B. Python para operaciones

## Objetivo

- Entender por qué Ubuntu no te deja instalar paquetes con `pip` en el Python del sistema.
- Crear, activar y desactivar un **entorno virtual** (`venv`), y usarlo también sin activarlo, como haría cron.
- Instalar dependencias con `pip` y fijarlas en `requirements.txt` para reproducir el entorno en otra máquina.
- Instalar herramientas de línea de comandos con `pipx`, empezando por `ruff`, el `shellcheck` de Python.

## Por qué importa

Cada proyecto necesita sus librerías, en sus versiones. Si las instalas todas en el mismo sitio, tarde o temprano dos proyectos piden versiones incompatibles, o una actualización rompe una herramienta del sistema. El entorno virtual aísla las dependencias de cada proyecto, y `requirements.txt` permite que tu portátil, el servidor, el contenedor de Docker (fase 5) y el pipeline de CI (fase 7) tengan **exactamente** las mismas versiones. "En mi máquina funciona" empieza a desaparecer aquí.

## Teoría

### El Python del sistema es de Ubuntu

Herramientas de Ubuntu como `apt` o `netplan` están escritas en Python y dependen de las librerías que instala `apt`. Si `pip` cambiara esas librerías, podría romperlas. Por eso Ubuntu marca su Python como **gestionado externamente** (la norma PEP 668), y `pip install` fuera de un entorno virtual falla con `externally-managed-environment`.

Hay tres formas correctas de instalar algo de Python:

| Qué quieres | Cómo | Ejemplo |
|-------------|------|---------|
| una librería para **tu proyecto** | `pip` dentro de un entorno virtual | `requests` para Vigía |
| un **programa** de Python para usar en la terminal | `pipx` (crea un entorno aislado para él) | `ruff` |
| una librería que necesita **otro programa del sistema** | `apt install python3-…` | rara vez lo necesitarás |

Lo que **no** se hace: `pip install --break-system-packages` o `sudo pip install`. El nombre de la opción ya avisa.

### `venv`: un Python solo para tu proyecto

```bash
python3 -m venv .venv               # crea la carpeta .venv con su propio python y pip
source .venv/bin/activate           # actívalo: tu prompt muestra (.venv)
which python                        # …/.venv/bin/python (dentro sí existe "python")
pip install requests                # se instala en .venv, no en el sistema
deactivate                          # vuelves al Python del sistema
```

**Activar** solo cambia el PATH de tu terminal (clase 07) para que `python` y `pip` sean los de `.venv`. Sin activar, puedes llamarlos por su ruta: `.venv/bin/python script.py`. Es lo que pondrás en cron, que no activa nada.

La carpeta `.venv` **no** se sube a Git: pesa, depende de tu máquina y se recrea en un minuto. Tu `.gitignore` del curso ya la ignora.

### `requirements.txt`: la lista de la compra

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

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-46 && cd ~/my-devops-journey/labs/clase-46
```

### 1. El muro de Ubuntu

```bash
pip install requests
```

Lee el mensaje entero: `error: externally-managed-environment`, y debajo te propone `apt install python3-xyz` o crear un entorno virtual. Es la protección de la que habla la teoría.

### 2. El entorno virtual de tus laboratorios

Para las clases 46 a 53 usarás un solo entorno, en la carpeta `labs`:

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

A partir de aquí, cada sesión de estas clases empieza con `source ~/my-devops-journey/labs/.venv/bin/activate`.

### 3. Instalar y congelar

```bash
pip install requests
pip list
pip show requests
pip freeze > clase-46/requirements.txt
cat clase-46/requirements.txt
```

Pediste un paquete y llegaron cinco: `requests` depende de `urllib3`, `idna`, `certifi` y `charset-normalizer`. `pip show` las muestra en `Requires`. `pip freeze` las fija todas, porque cualquiera de ellas podría cambiar el comportamiento.

```bash
cat > clase-46/version.py <<'EOF'
import requests
r = requests.get("https://example.com", timeout=10)
print(f"requests {requests.__version__}: example.com respondió {r.status_code}")
EOF
python clase-46/version.py
```

### 4. Reproducir el entorno desde cero

```bash
cd /tmp && rm -rf prueba-venv && mkdir prueba-venv && cd prueba-venv
python3 -m venv .venv
.venv/bin/pip install -q -r ~/my-devops-journey/labs/clase-46/requirements.txt
.venv/bin/pip freeze | diff - ~/my-devops-journey/labs/clase-46/requirements.txt && echo "idénticos"
.venv/bin/python ~/my-devops-journey/labs/clase-46/version.py
cd ~/my-devops-journey/labs
```

Sin activar nada: `.venv/bin/pip` y `.venv/bin/python` son los del entorno. `diff` sin salida significa que los dos entornos tienen exactamente lo mismo.

### 5. Herramientas con `pipx`: `ruff`

`pipx` instala un programa de Python en su propio entorno y lo deja disponible en tu PATH. Ya lo tienes instalado.

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

`ruff` es a Python lo que `shellcheck` a Bash (clase 19): lee el código sin ejecutarlo y avisa de errores típicos, como un `import` que no se usa o `== None`, que debe escribirse `is None`. Muchos de sus avisos se arreglan solos con `ruff check --fix`. Lo usarás en Vigía y en el pipeline de la fase 7.

Si `ruff` no se encuentra después de instalarlo, ejecuta `pipx ensurepath` y abre una terminal nueva.

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
`intérprete erróneo: No existe el archivo o el directorio`: los scripts de `.venv/bin` guardan la ruta absoluta de donde se creó el entorno (es el mismo mensaje que el del script con finales de Windows de la clase 16). Un entorno virtual no se copia ni se mueve: se **recrea** desde `requirements.txt`. Por eso no se sube a Git.

**4. La versión sin fijar:**
```bash
grep -c "==" clase-46/requirements.txt
```
Imagina que `requirements.txt` solo dijera `requests`, sin versión. Hoy instalaría la 2.34; dentro de seis meses, la que haya salido, que podría cambiar algo o traer un fallo nuevo. Tu contenedor de producción sería distinto del que probaste. Por eso se fijan las versiones exactas, y se actualizan **a propósito**, probando, no por sorpresa.

## Reto

1. Crea `~/my-devops-journey/labs/clase-46/miniproyecto/` con su propio `.venv`, instala `requests` y `PyYAML`, escribe un `requirements.txt` con versiones fijas y un `requirements-dev.txt` que lo incluya y añada `pytest`.
2. Escribe `chequeo.py`, que lea de un archivo `sitios.yaml` una lista de URLs (`yaml.safe_load`; lo verás a fondo en la clase 47) y muestre el código HTTP de cada una con `requests` (con `timeout=10`).
3. Demuestra que es reproducible: borra el `.venv`, recréalo desde `requirements-dev.txt` y vuelve a ejecutar `chequeo.py`.
4. Pásale `ruff check` a tus scripts de las clases 39 a 45 y arregla los avisos.

## Cierre

En `notas/fase-4/clase-46.md`:

1. ¿Por qué Ubuntu no te deja hacer `pip install` en el Python del sistema? ¿Qué tres alternativas correctas tienes?
2. ¿Qué cambia exactamente cuando activas un entorno virtual? ¿Cómo usas el entorno desde cron, que no lo activa?
3. ¿Para qué sirve fijar versiones exactas en `requirements.txt`? ¿Qué podría pasar sin ellas?
4. **Repaso (clase 45, sin mirar):** ¿por qué un archivo tuyo llamado `random.py` puede romper un programa?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque ese Python lo usan herramientas del propio Ubuntu con las librerías que instala `apt`, y `pip` podría cambiarlas y romperlas (PEP 668: entorno gestionado externamente). Alternativas: un entorno virtual con `pip` para las librerías de tus proyectos, `pipx` para programas de línea de comandos, y `apt install python3-…` para librerías que necesita el sistema.

**2.** Solo el PATH de esa terminal (y el prompt): `.venv/bin` pasa delante, así que `python` y `pip` son los del entorno. Desde cron se llama al intérprete del entorno por su ruta absoluta: `/home/educo/proyecto/.venv/bin/python script.py`.

**3.** Para que cualquier máquina (tu portátil, el servidor, el contenedor, el CI) instale exactamente lo que probaste. Sin versiones fijas, cada instalación trae la última publicada: un cambio o un fallo de una dependencia, o de una dependencia de una dependencia, puede romper tu aplicación sin que hayas tocado nada.

**4.** Porque Python busca primero en la carpeta del script o en la actual, y tu archivo tapa el módulo estándar del mismo nombre.

**Reto (lo esencial):**
```bash
cd ~/my-devops-journey/labs/clase-46 && mkdir -p miniproyecto && cd miniproyecto
python3 -m venv .venv && source .venv/bin/activate
pip install requests PyYAML
pip freeze > requirements.txt
printf -- '-r requirements.txt\npytest\n' > requirements-dev.txt
pip install -r requirements-dev.txt && pip freeze | grep -i pytest   # fija también su versión
```
En `requirements-dev.txt` conviene fijar la versión de `pytest` igual que las demás (`pytest==…`).
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
