# Clase 50 — Automatizar el sistema: subprocess, shutil y variables de entorno

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** B. Python para operaciones

## Objetivo

- Lanzar comandos del sistema desde Python con `subprocess.run`, leer su salida y su código, y tratar sus errores.
- Evitar la inyección de comandos: argumentos en lista, sin `shell=True`.
- Leer la configuración de **variables de entorno** con valores por defecto.
- Copiar, mover, comprimir y medir el disco con `shutil`.
- Decidir con criterio cuándo escribir un script en Bash y cuándo en Python.

## Por qué importa

Muchas automatizaciones combinan las dos cosas: lógica y datos (lo fuerte de Python) con herramientas del sistema que ya existen (`systemctl`, `git`, `docker`, `aws`). `subprocess` es el puente. Y las variables de entorno son la forma estándar de configurar una aplicación en Docker, Kubernetes, GitHub Actions y AWS (clase 07): la misma imagen sirve para desarrollo y producción cambiando solo el entorno. Vigía v2 leerá así la dirección de su base de datos.

## Teoría

### `subprocess.run`

```python
import subprocess

r = subprocess.run(["systemctl", "is-active", "cron"], capture_output=True, text=True, timeout=10)
r.returncode        # 0 si está activo, 3 si no (clase 17)
r.stdout            # 'active\n'
r.stderr            # los errores del comando
```

| Parámetro | Para qué |
|-----------|----------|
| una **lista** `["cmd", "arg1", "arg2"]` | cada elemento es un argumento: sin comillas ni espacios que se partan |
| `capture_output=True` | guarda stdout y stderr en lugar de mostrarlos |
| `text=True` | te los da como texto (`str`) y no como *bytes* |
| `check=True` | lanza `CalledProcessError` si el código no es 0 |
| `timeout=10` | lanza `TimeoutExpired` si tarda más |

Si el programa no existe, `subprocess.run` lanza `FileNotFoundError`.

### Nunca `shell=True` con datos de fuera

```python
archivo = input()                                   # imagina que viene de un usuario o de un archivo
subprocess.run(f"wc -l {archivo}", shell=True)      # ❌ si archivo = "x; rm -rf ~", se ejecuta
subprocess.run(["wc", "-l", archivo])               # ✅ archivo es SIEMPRE un solo argumento
```

Con `shell=True`, el texto pasa por un shell que interpreta `;`, `|`, `$()`… Es la **inyección de comandos**, una de las vulnerabilidades más comunes. Con una lista no hay shell de por medio. Si necesitas un pipe, haz esa parte en Python.

### Variables de entorno

```python
import os

entorno = os.environ.get("APP_ENV", "desarrollo")   # con valor por defecto
token = os.environ["API_TOKEN"]                     # obligatoria: KeyError si no existe
os.environ.get("NO_EXISTE") is None                 # True
```

Lee la configuración del entorno **al arrancar** y falla pronto, con un mensaje claro, si falta algo obligatorio. Y recuerda la clase 07: un programa hijo hereda una **copia** del entorno. Para pasarle una variable más: `subprocess.run([...], env={**os.environ, "APP_ENV": "pruebas"})`.

### `shutil`

| Función | Equivale a |
|---------|------------|
| `shutil.copy2(origen, destino)` | `cp -p` (conserva fechas) |
| `shutil.copytree(a, b)` | `cp -r` |
| `shutil.move(a, b)` | `mv` |
| `shutil.rmtree(carpeta)` | `rm -rf` (con el mismo peligro) |
| `shutil.which("docker")` | `command -v docker` |
| `shutil.disk_usage("/")` | `df` |
| `shutil.make_archive(base, "gztar", root_dir, base_dir)` | `tar -czf base.tar.gz -C root_dir base_dir` |

### ¿Bash o Python?

| Bash si… | Python si… |
|----------|------------|
| encadenas comandos del sistema | hay lógica, datos o estructuras (listas, diccionarios) |
| cabe en unas 50 líneas | crece, o lo van a mantener otros |
| es el *entrypoint* de un contenedor o un paso corto de CI | hablas con una API, parseas JSON o YAML |
| no necesitas pruebas | necesitas pruebas automáticas y buen manejo de errores |

No es una competición: un buen ingeniero usa los dos, y a menudo uno llama al otro.

## Práctica guiada

```bash
source ~/my-devops-journey/labs/.venv/bin/activate
mkdir -p ~/my-devops-journey/labs/clase-50 && cd ~/my-devops-journey/labs/clase-50
```

### 1. Lanzar comandos

```bash
python
```

```python
>>> import subprocess
>>> r = subprocess.run(["uname", "-r"], capture_output=True, text=True)
>>> r.returncode, r.stdout.strip()
>>> r = subprocess.run(["systemctl", "is-active", "cron"], capture_output=True, text=True)
>>> r.returncode, r.stdout.strip()
>>> r = subprocess.run(["systemctl", "is-active", "no-existe"], capture_output=True, text=True)
>>> r.returncode, r.stdout.strip()
>>> subprocess.run(["ls", "/no-existe"], capture_output=True, text=True).stderr
>>> exit()
```

🔮 **Predice** el código de salida de `is-active` para `cron` y para `no-existe` (clase 17).

### 2. Errores de `subprocess`

```bash
python -c '
import subprocess
try:
    subprocess.run(["ls", "/no-existe"], capture_output=True, text=True, check=True)
except subprocess.CalledProcessError as e:
    print(f"falló con código {e.returncode}: {e.stderr.strip()}")
try:
    subprocess.run(["comando-inventado"])
except FileNotFoundError:
    print("ese programa no existe")
try:
    subprocess.run(["sleep", "5"], timeout=1)
except subprocess.TimeoutExpired:
    print("tardó demasiado")
'
```

### 3. Configuración desde el entorno

```bash
cat > config_env.py <<'EOF'
#!/usr/bin/env python3
"""config_env.py: lee la configuración de variables de entorno."""
import os
import sys

entorno = os.environ.get("APP_ENV", "desarrollo")
timeout = float(os.environ.get("APP_TIMEOUT", "10"))
try:
    base_datos = os.environ["DATABASE_URL"]
except KeyError:
    sys.exit("Error: falta la variable DATABASE_URL")
print(f"entorno={entorno} timeout={timeout} base_datos={base_datos}")
EOF
python config_env.py ; echo "código: $?"
DATABASE_URL=sqlite:///vigia.db python config_env.py
APP_ENV=produccion APP_TIMEOUT=5 DATABASE_URL=postgresql://db:5432/vigia python config_env.py
```

Es el patrón de *la aplicación de doce factores*: el mismo código, configurado por el entorno. Lo verás en Docker Compose (fase 5) y en los Secrets de Kubernetes (fase 9).

### 4. El backup de la clase 20, en Python

```bash
cat > backup.py <<'EOF'
#!/usr/bin/env python3
"""backup.py: comprime una carpeta con la fecha en el nombre y borra las copias viejas."""
import argparse
import logging
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path

log = logging.getLogger("backup")


def hacer_backup(origen: Path, destino: Path) -> Path:
    destino.mkdir(parents=True, exist_ok=True)
    fecha = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    base = destino / f"{origen.name}-{fecha}"
    archivo = shutil.make_archive(str(base), "gztar", root_dir=origen.parent, base_dir=origen.name)
    return Path(archivo)


def rotar(destino: Path, nombre: str, dias: int) -> int:
    limite = time.time() - dias * 86400
    borrados = 0
    for copia in destino.glob(f"{nombre}-*.tar.gz"):
        if copia.stat().st_mtime < limite:
            copia.unlink()
            borrados += 1
    return borrados


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="backup", description="Backup con rotación.")
    parser.add_argument("origen", type=Path)
    parser.add_argument("--destino", type=Path, default=Path.home() / "backups")
    parser.add_argument("--dias", type=int, default=7)
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    origen = args.origen.resolve()
    if not origen.is_dir():
        log.error("%s no es un directorio", origen)
        return 1
    archivo = hacer_backup(origen, args.destino)
    log.info("creado %s (%.1f KB)", archivo, archivo.stat().st_size / 1024)
    log.info("rotación: %d copias de más de %d días borradas",
             rotar(args.destino, origen.name, args.dias), args.dias)
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
mkdir -p datos && echo "importante" > datos/a.txt
python backup.py datos --destino copias
touch -d "8 days ago" copias/datos-2026-01-01_000000.tar.gz
python backup.py datos --destino copias
ls copias
tar -tzf "$(ls -t copias/*.tar.gz | head -1)"
```

🔮 **Predice:** ¿desaparece la copia "vieja"? Compara este script con tu `backup.sh`: hace lo mismo, con más líneas, pero cada pieza es una función que podrías probar por separado (clase 52), y los errores y los argumentos se tratan con las herramientas de las clases 44 y 48. Para algo tan corto, el de Bash era razonable; si mañana hay que subir la copia a S3 (fase 6), el de Python crece mejor.

### 5. Un informe de salud en JSON

```bash
cat > salud.py <<'EOF'
#!/usr/bin/env python3
"""salud.py: estado básico de la máquina, en JSON."""
import json
import os
import shutil
import socket
import subprocess


def servicio_activo(nombre: str) -> bool:
    r = subprocess.run(["systemctl", "is-active", "--quiet", nombre], timeout=10)
    return r.returncode == 0


disco = shutil.disk_usage("/")
informe = {
    "equipo": socket.gethostname(),
    "carga_1min": os.getloadavg()[0],
    "cpus": os.cpu_count(),
    "disco_uso_pct": round(disco.used / disco.total * 100, 1),
    "servicios": {s: servicio_activo(s) for s in ["cron", "ssh", "docker"]},
    "herramientas": {h: shutil.which(h) is not None for h in ["git", "docker", "kubectl"]},
}
print(json.dumps(informe, indent=2, ensure_ascii=False))
EOF
python salud.py
python salud.py | jq '.servicios'
```

Este informe en JSON lo puede consumir otro programa, una API o un sistema de monitoreo. Es la idea de un agente de monitoreo, en 25 líneas.

## Rómpelo

**1. La inyección de comandos:**
```bash
touch "informe.txt"
python -c '
import subprocess
nombre = "informe.txt; echo HE EJECUTADO OTRO COMANDO"
subprocess.run(f"wc -c {nombre}", shell=True)
print("--- con lista:")
subprocess.run(["wc", "-c", nombre])
'
```
Con `shell=True`, el `;` separa comandos y el segundo se ejecuta. Imagina `rm -rf ~` en lugar de `echo`. Con la lista, `wc` recibe un nombre de archivo raro, dice que no existe y no pasa nada más.

**2. Bytes en lugar de texto:**
```bash
python -c 'import subprocess; print(subprocess.run(["uname"], capture_output=True).stdout)'
```
`b'Linux\n'`: sin `text=True`, la salida llega en *bytes*, y `.strip()` o comparar con `"Linux"` no funcionan como esperas.

**3. La ruta vacía que apunta aquí:**
```bash
python -c '
import os
from pathlib import Path
carpeta = Path(os.environ.get("CARPETA_TEMPORAL", ""))
print("borraría:", carpeta.resolve())
'
```
Si la variable no existe, `Path("")` es la carpeta **actual**. Un `shutil.rmtree(carpeta)` borraría el directorio en el que estás. Es la errata de Steam de la clase 16, en Python. Valida siempre las rutas peligrosas antes de usarlas (`if not os.environ.get(...)`), igual que hacía `${DIR:?}` en Bash.

## Reto

1. Mejora `salud.py`: que salga con 1 si algún servicio de la lista está parado o el disco pasa del 90 %, y con 0 si todo va bien, y que la lista de servicios se pueda pasar con `--servicios cron ssh` (`nargs="+"` en `argparse`).
2. `git_resumen.py <carpeta>`: con `subprocess`, muestra la rama actual (`git rev-parse --abbrev-ref HEAD`), el último commit (`git log -1 --format=%s`) y si hay cambios sin guardar (`git status --porcelain`). Pruébalo con tu repo del curso y con una carpeta que no sea un repo, y sin trazas.
3. Haz que `backup.py` lea el destino por defecto de la variable de entorno `BACKUP_DIR` si existe.

## Cierre

En `notas/fase-4/clase-50.md`:

1. ¿Por qué se pasan los argumentos de `subprocess.run` como lista y no como un texto con `shell=True`?
2. ¿Qué diferencia hay entre `os.environ.get("X", "valor")` y `os.environ["X"]`? ¿Cuándo usas cada uno?
3. Da dos situaciones en las que elegirías Bash y dos en las que elegirías Python.
4. **Repaso (clase 49, sin mirar):** ¿por qué toda petición con `requests` debe llevar `timeout`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Con una lista, cada elemento llega al programa como un argumento exacto, sin pasar por un shell: los espacios, `;`, `|` o `$()` dentro de un dato no se interpretan. Con `shell=True`, el texto lo interpreta un shell, y un dato malicioso o simplemente raro puede ejecutar otros comandos (inyección de comandos).

**2.** `get` devuelve el valor por defecto (o `None`) si la variable no existe; `os.environ["X"]` lanza `KeyError`. `get` para lo opcional con un valor razonable por defecto; `[]` (capturando el error para dar un mensaje claro) para lo obligatorio, como una contraseña o la dirección de la base de datos.

**3.** Bash: encadenar unos pocos comandos del sistema, el *entrypoint* de un contenedor, un paso corto de CI. Python: consumir una API o procesar JSON/YAML, lógica con estructuras de datos, una herramienta que crecerá o que necesita pruebas y buen manejo de errores.

**4.** Porque sin `timeout` puede esperar indefinidamente a un servidor que no responde, y el programa (y el cron o el pipeline que lo lanzó) se queda colgado.

**Reto 1 (lo esencial):**
```python
parser.add_argument("--servicios", nargs="+", default=["cron", "ssh"])
...
problemas = [s for s, ok in informe["servicios"].items() if not ok]
if informe["disco_uso_pct"] > 90:
    problemas.append("disco")
sys.exit(1 if problemas else 0)
```

**Reto 2 (lo esencial):**
```python
def git(carpeta, *args):
    r = subprocess.run(["git", "-C", str(carpeta), *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout.strip()
```
`git -C carpeta` ejecuta git como si estuvieras en esa carpeta. Fuera de un repo, git sale con 128 y el `RuntimeError` lleva su mensaje (`fatal: not a git repository…`), que muestras sin traza.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| subprocess / child process | subproceso / proceso hijo |
| command injection | inyección de comandos |
| environment variable | variable de entorno |
| twelve-factor app | aplicación de doce factores |
| glue code | código "pegamento" |

🎙️ *"When Python calls system commands, I pass arguments as a list, never shell=True with external input, and I read configuration from environment variables."*

## Siguiente

[Clase 51 — SQLite desde Python](clase-51-sqlite.md)
