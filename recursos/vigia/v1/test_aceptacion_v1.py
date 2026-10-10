"""Pruebas de aceptación de Vigía v1.

Comprueban tu Vigía desde fuera, como lo usaría otra persona: lanzan
`python -m vigia check` contra un servidor HTTP falso, miran la base de datos
SQLite y arrancan `python -m vigia serve` para preguntar a la API.
No dependen de cómo organices tu código por dentro.

Ejecútalas desde la raíz de tu repo, con tu entorno virtual activo:

    cd ~/vigia
    source .venv/bin/activate
    pytest ~/my-devops-journey/recursos/vigia/v1 -v

En la clase 54 (todavía sin API), solo las del chequeo:

    pytest ~/my-devops-journey/recursos/vigia/v1 -v -m "not api"

Si tu proyecto está en otra carpeta: VIGIA_DIR=/ruta/al/proyecto pytest …
"""

import json
import os
import socket
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

PROYECTO = Path(os.environ.get("VIGIA_DIR", os.getcwd()))
COLUMNAS = {"id", "url", "status_code", "seconds", "up", "error", "checked_at"}


class ServidorFalso(BaseHTTPRequestHandler):
    """Responde según la ruta: así probamos cada caso sin depender de internet."""

    alternancia = 0

    def do_GET(self):
        if self.path == "/ok":
            self._responder(200)
        elif self.path == "/redir":
            self.send_response(301)
            self.send_header("Location", "/ok")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif self.path == "/missing":
            self._responder(404)
        elif self.path == "/error":
            self._responder(500)
        elif self.path == "/slow":
            time.sleep(3)
            self._responder(200)
        elif self.path == "/toggle":
            ServidorFalso.alternancia += 1
            self._responder(200 if ServidorFalso.alternancia % 2 else 503)
        else:
            self._responder(404)

    def _responder(self, codigo):
        cuerpo = b"vigia-test"
        try:
            self.send_response(codigo)
            self.send_header("Content-Length", str(len(cuerpo)))
            self.end_headers()
            self.wfile.write(cuerpo)
        except (BrokenPipeError, ConnectionResetError):
            pass  # el cliente ya se fue (pasa con /slow)

    def log_message(self, *args):
        pass


@pytest.fixture(scope="module")
def servidor():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), ServidorFalso)
    srv.daemon_threads = True
    hilo = threading.Thread(target=srv.serve_forever, daemon=True)
    hilo.start()
    yield f"http://127.0.0.1:{srv.server_address[1]}"
    srv.shutdown()


def vigia(*args, timeout=90):
    """Ejecuta `python -m vigia …` desde la carpeta de tu proyecto."""
    return subprocess.run(
        [sys.executable, "-m", "vigia", *args],
        cwd=PROYECTO, capture_output=True, text=True, timeout=timeout,
    )


def escribir_config(ruta, urls, database, timeout=1):
    lineas = [f"timeout: {timeout}", f"database: {database}", "urls:"]
    lineas += [f"  - {u}" for u in urls]
    ruta.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    return ruta


def filas(db):
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    try:
        return [dict(f) for f in con.execute("SELECT * FROM checks ORDER BY id")]
    finally:
        con.close()


def detalle(r):
    return f"\n--- código {r.returncode}\n--- stdout:\n{r.stdout}\n--- stderr:\n{r.stderr}"


# ---------------------------------------------------------------------------
# vigia check
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def primera_revision(servidor, tmp_path_factory):
    carpeta = tmp_path_factory.mktemp("revision")
    db = carpeta / "vigia.db"
    urls = [f"{servidor}/ok", f"{servidor}/redir", f"{servidor}/missing",
            f"{servidor}/error", f"{servidor}/slow", "http://no-existe.invalid/"]
    cfg = escribir_config(carpeta / "config.yaml", urls, db)
    inicio = time.perf_counter()
    r = vigia("check", "--config", str(cfg))
    return {"r": r, "db": db, "urls": urls, "cfg": cfg, "duracion": time.perf_counter() - inicio}


@pytest.mark.api
def test_ayuda_menciona_los_dos_comandos():
    r = vigia("--help")
    assert r.returncode == 0, detalle(r)
    assert "check" in r.stdout and "serve" in r.stdout, detalle(r)


def test_check_devuelve_1_si_alguna_url_esta_caida(primera_revision):
    r = primera_revision["r"]
    assert r.returncode == 1, "con sitios caídos, check debe salir con 1" + detalle(r)


def test_la_tabla_checks_tiene_las_columnas_del_contrato(primera_revision):
    con = sqlite3.connect(primera_revision["db"])
    columnas = {fila[1] for fila in con.execute("PRAGMA table_info(checks)")}
    con.close()
    assert COLUMNAS <= columnas, f"faltan columnas: {COLUMNAS - columnas}"


def test_una_fila_por_url_en_orden(primera_revision):
    datos = filas(primera_revision["db"])
    assert [d["url"] for d in datos] == primera_revision["urls"]


@pytest.mark.parametrize("ruta, codigo, arriba", [
    ("/ok", 200, 1),
    ("/redir", 301, 1),
    ("/missing", 404, 0),
    ("/error", 500, 0),
    ("/slow", 0, 0),
])
def test_codigo_y_estado_de_cada_caso(primera_revision, servidor, ruta, codigo, arriba):
    fila = next(d for d in filas(primera_revision["db"]) if d["url"] == servidor + ruta)
    assert fila["status_code"] == codigo, f"{ruta}: {fila}"
    assert fila["up"] == arriba, f"{ruta}: {fila}"


def test_un_nombre_que_no_existe_cuenta_como_caido(primera_revision):
    fila = next(d for d in filas(primera_revision["db"]) if "no-existe.invalid" in d["url"])
    assert (fila["status_code"], fila["up"]) == (0, 0), fila


def test_error_solo_cuando_no_hubo_respuesta(primera_revision):
    for fila in filas(primera_revision["db"]):
        if fila["status_code"] == 0:
            assert fila["error"], f"sin respuesta HTTP, 'error' debe explicar por qué: {fila}"
        else:
            assert fila["error"] is None, f"con respuesta HTTP, 'error' debe ser NULL: {fila}"


def test_el_timeout_se_respeta(primera_revision, servidor):
    lenta = next(d for d in filas(primera_revision["db"]) if d["url"] == servidor + "/slow")
    assert 0.8 <= lenta["seconds"] < 2.5, f"con timeout 1, /slow debe cortarse en ~1 s: {lenta}"
    assert primera_revision["duracion"] < 20, "la revisión completa tardó demasiado"


def test_tiempos_y_fechas_validos(primera_revision):
    for fila in filas(primera_revision["db"]):
        assert isinstance(fila["seconds"], float) and fila["seconds"] >= 0, fila
        fecha = datetime.fromisoformat(fila["checked_at"])
        assert fecha.tzinfo is not None, f"checked_at debe llevar zona horaria: {fila}"


def test_una_segunda_revision_anade_historial(primera_revision):
    antes = len(filas(primera_revision["db"]))
    vigia("check", "--config", str(primera_revision["cfg"]))
    assert len(filas(primera_revision["db"])) == 2 * antes, "check debe añadir filas, no reemplazarlas"


def test_check_devuelve_0_si_todo_esta_arriba(servidor, tmp_path):
    cfg = escribir_config(tmp_path / "config.yaml", [f"{servidor}/ok", f"{servidor}/redir"],
                          tmp_path / "vigia.db")
    r = vigia("check", "--config", str(cfg))
    assert r.returncode == 0, detalle(r)


def test_database_relativa_se_resuelve_desde_la_carpeta_del_config(servidor, tmp_path):
    cfg = escribir_config(tmp_path / "config.yaml", [f"{servidor}/ok"], "datos.db")
    r = vigia("check", "--config", str(cfg))
    assert r.returncode == 0, detalle(r)
    assert (tmp_path / "datos.db").exists(), \
        "una ruta relativa en 'database' debe interpretarse desde la carpeta del config"


@pytest.mark.parametrize("contenido", [
    None,                                         # el archivo no existe
    "urls: [https://example.com\n",               # YAML roto
    "timeout: 5\n",                               # sin 'urls'
    "urls: []\n",                                 # lista vacía
    "urls:\n  - example.com\n",                   # URL sin http:// ni https://
    "timeout: -1\nurls:\n  - https://example.com\n",  # timeout inválido
])
def test_configuracion_invalida_sale_con_2(tmp_path, contenido):
    cfg = tmp_path / "config.yaml"
    if contenido is not None:
        cfg.write_text(contenido, encoding="utf-8")
    r = vigia("check", "--config", str(cfg))
    assert r.returncode == 2, detalle(r)
    assert "Traceback" not in r.stderr, "un error de configuración no debe mostrar una traza" + detalle(r)


# ---------------------------------------------------------------------------
# vigia serve
# ---------------------------------------------------------------------------

def puerto_libre():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def pedir(url):
    with urllib.request.urlopen(url, timeout=5) as respuesta:
        return respuesta.status, json.loads(respuesta.read())


@pytest.fixture
def api(servidor, tmp_path):
    db = tmp_path / "vigia.db"
    cfg = escribir_config(tmp_path / "config.yaml",
                          [f"{servidor}/ok", f"{servidor}/missing", f"{servidor}/toggle"], db)
    vigia("check", "--config", str(cfg))
    puerto = puerto_libre()
    proceso = subprocess.Popen(
        [sys.executable, "-m", "vigia", "serve", "--config", str(cfg), "--port", str(puerto)],
        cwd=PROYECTO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    base = f"http://127.0.0.1:{puerto}"
    for _ in range(60):
        try:
            pedir(base + "/health")
            break
        except (urllib.error.URLError, ConnectionError, OSError):
            if proceso.poll() is not None:
                pytest.fail("`vigia serve` terminó antes de responder:\n" + proceso.stdout.read())
            time.sleep(0.25)
    else:
        proceso.terminate()
        pytest.fail("`vigia serve` no respondió en /health en 15 s")
    yield {"base": base, "cfg": cfg, "db": db}
    proceso.terminate()
    proceso.wait(timeout=10)


@pytest.mark.api
def test_health_responde_ok(api):
    codigo, cuerpo = pedir(api["base"] + "/health")
    assert codigo == 200 and cuerpo.get("status") == "ok", cuerpo


@pytest.mark.api
def test_status_tiene_un_sitio_por_url_y_los_contadores(api, servidor):
    codigo, cuerpo = pedir(api["base"] + "/status")
    assert codigo == 200
    sitios = {s["url"]: s for s in cuerpo["sites"]}
    assert set(sitios) == {f"{servidor}/ok", f"{servidor}/missing", f"{servidor}/toggle"}, cuerpo
    assert sitios[f"{servidor}/ok"]["up"] is True
    assert sitios[f"{servidor}/missing"]["up"] is False
    assert sitios[f"{servidor}/missing"]["status_code"] == 404
    for s in sitios.values():
        assert {"url", "up", "status_code", "seconds", "checked_at"} <= set(s), s
    assert cuerpo["up"] + cuerpo["down"] == 3, cuerpo
    assert cuerpo["up"] == sum(s["up"] for s in sitios.values()), cuerpo


@pytest.mark.api
def test_status_muestra_el_ultimo_resultado(api, servidor):
    toggle = f"{servidor}/toggle"
    _, antes = pedir(api["base"] + "/status")
    estado_antes = next(s["up"] for s in antes["sites"] if s["url"] == toggle)
    vigia("check", "--config", str(api["cfg"]))
    _, despues = pedir(api["base"] + "/status")
    estado_despues = next(s["up"] for s in despues["sites"] if s["url"] == toggle)
    assert estado_antes != estado_despues, \
        "/status debe mostrar la revisión más reciente de cada URL, no la primera"
