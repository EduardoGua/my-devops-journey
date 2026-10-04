# Examen de la fase 1 — Respuestas

> ⛔ Ábrelo **solo** después de haber terminado el examen completo. Si lo lees antes, el examen deja de medir lo que sabes.

## Parte A

**A1.** La terminal es la ventana que muestra texto y recibe teclas. El shell (bash) es un programa que interpreta los comandos y lanza otros programas. El kernel es el núcleo que gestiona el hardware (CPU, memoria, disco, red), y los programas le piden todo mediante llamadas al sistema. *(Clase 01)*

**A2.** `2>&1` envía stderr a donde apunta stdout **en ese momento**. Las redirecciones se aplican de izquierda a derecha: en `> f 2>&1`, stdout ya apunta a `f` y stderr lo sigue; en `2>&1 > f`, stderr se copia a la pantalla (donde estaba stdout) y luego solo stdout se mueve a `f`. *(Clase 04)*

**A3.** El dueño puede listar, crear y borrar dentro, y entrar. El grupo puede listar y entrar, pero no crear ni borrar. Los demás no pueden nada, ni siquiera entrar. *(Clase 06)*

**A4.** `777` da escritura a cualquier usuario y proceso: un riesgo de seguridad grave. Lo correcto es ver con qué usuario corre nginx (`www-data`), qué permiso falta y en qué tramo de la ruta (`namei -l`), y dar el mínimo: archivos `644`, directorios `755` y el grupo adecuado si hace falta. *(Clases 06, 11)*

**A5.** Porque cron y systemd arrancan con un entorno mínimo: un PATH reducido, sin `~/.bashrc` ni alias ni variables exportadas. Se arregla con rutas absolutas o definiendo el PATH y las variables en el script o en la unit. *(Clase 07)*

**A6.** `SIGTERM` pide terminar y se puede atrapar para cerrar ordenadamente. `SIGKILL` lo mata el kernel sin opción de limpieza. Kubernetes envía `SIGTERM`, espera el *grace period* (30 s por defecto) y después `SIGKILL`. *(Clase 11)*

**A7.** `start` arranca ahora; `enable` hace que arranque en el boot (sin arrancarlo ahora). Incidente: arrancas un servicio a mano, funciona, no lo habilitas, y en el siguiente reinicio no vuelve. *(Clase 12)*

**A8.** El OOM killer: `journalctl -k | grep -i "killed process"` o `dmesg -T | grep -i oom`. El kernel mata el proceso con SIGKILL y este no puede escribir nada en su log. *(Clase 14)*

**A9.** (1) Un archivo borrado que un proceso mantiene abierto: `sudo lsof +L1`. (2) Datos escondidos bajo un punto de montaje. Además, si el error es "No space left" con espacio libre, los inodos: `df -i`. *(Clase 14)*

**A10.** Quien tiene la privada puede autenticarse como tú en cualquier servidor que tenga tu pública. Si se filtra: quitar la pública de todos los `authorized_keys` (y de GitHub o AWS), generar un par nuevo, revisar los logs de acceso por si se usó y limpiar donde se publicó. Borrarla del repo no basta. *(Clases 15, 25)*

**A11.** SYN → SYN-ACK → ACK. *Refused*: se llegó a la máquina, pero ningún proceso escucha en ese puerto (respuesta RST inmediata). *Timeout*: no hubo respuesta: firewall o security group que descarta, sin ruta o máquina apagada. *(Clase 16)*

**A12.** Una ruta `0.0.0.0/0 → Internet Gateway` en su tabla de rutas. El NAT Gateway permite que las instancias de subredes privadas inicien conexiones a internet (actualizaciones, APIs) sin que nadie de fuera pueda iniciar conexiones hacia ellas. *(Clase 20)*

**A13.** El tiempo que una respuesta DNS puede guardarse en caché. Se baja con antelación (al menos un TTL viejo antes) para que, al hacer el cambio, las cachés caduquen rápido y el cambio y una posible vuelta atrás surtan efecto en minutos. *(Clase 21)*

**A14.** 502: el backend falló o rechazó la conexión. 503: no hay destinos sanos o disponibles. 504: el backend tardó demasiado en responder. *(Clase 22)*

**A15.** Dos de: los SG son *stateful* y las NACLs *stateless*; los SG solo tienen *allow* y las NACLs *allow* y *deny* con orden numérico; los SG se aplican a la interfaz (instancia) y las NACLs a la subred; los SG pueden usar otro SG como origen. *(Clase 23)*

## Parte B

**B1.** `/26`, bloque 64 → 130 cae en 128–191. Red `172.16.77.128`, broadcast `172.16.77.191`. **62** hosts útiles en una red normal y **59** en AWS (64 − 5).

**B2.** **Sí.** `/23` → corte en el 3.er octeto, máscara `254`, bloque 2 → redes en `.0`, `.2`, `.4`… `10.0.1.20` y `10.0.0.200` están ambas en el bloque `10.0.0.0` – `10.0.1.255`: misma red `10.0.0.0/23`.

**B3.** 4 = 2² → `/18`, saltos de 64 en el 3.er octeto: `10.20.0.0/18`, `10.20.64.0/18`, `10.20.128.0/18`, `10.20.192.0/18`.

**B4.** `/22` = 1.024 − 5 = **1.019** ≥ 1.000. (`/23` = 507 no alcanza.)

**B5.** Que cualquier IP de internet puede intentar conectar a PostgreSQL. Bien: origen = el **security group de la app** (`sg-app`), y la base de datos en una subred privada.

## Parte C (respuestas modelo: valen otros órdenes razonables)

**C1.** Hipótesis: el servicio no estaba `enabled`.
`systemctl status nginx` (o el servicio de la app) → *inactive* · `systemctl is-enabled nginx` → *disabled* · `journalctl -b -u nginx` → nada desde el arranque · `ss -tlnp` → nadie en el 80. Arreglo: `systemctl enable --now`. También posible: la IP pública cambió (sin IP elástica) y el DNS apunta a la vieja.

**C2.** Timeout = algo descarta los paquetes. Como dentro funciona, el servicio está bien. `nc -zv -w5 IP 8080` desde fuera → timeout · en AWS: reglas de entrada del **security group** (¿8080 desde tu IP?), NACL, ruta al IGW · dentro: `sudo ufw status`/`nft list ruleset` y `journalctl -k | grep BLOCK`.

**C3.** Refused al instante = se llega a la máquina pero nadie escucha **en esa interfaz**. `sudo ss -tlnp | grep 8080` → muy probablemente `127.0.0.1:8080`. Arreglo: configurar la app para escuchar en `0.0.0.0`. (También posible: un firewall local con REJECT.)

**C4.** 502 = nginx no obtiene respuesta del backend. `tail /var/log/nginx/error.log` → *connection refused* / *upstream prematurely closed* · `systemctl status <app>` · `journalctl -u <app> -n 50` · `ss -tlnp` (¿escucha en el puerto que espera nginx?) · `curl` al backend directamente.

**C5.** `df -h` (¿qué sistema de archivos está lleno?) · `df -i` (¿inodos?) · `sudo du -xh / --max-depth=1 | sort -h` y seguir bajando · `sudo lsof +L1` (archivos borrados abiertos) · limpiar con `apt clean`, `journalctl --vacuum-size=200M`, logs viejos… y **después** buscar la causa y poner una alarma de disco.

## Parte D (criterios)

**D1:** `groupadd ops`; `useradd -m -G ops` (o `adduser` + `usermod -aG`); `mkdir /srv/ops && chown root:ops /srv/ops && chmod 2770 /srv/ops`; `visudo -f /etc/sudoers.d/maria` con `maria ALL=(root) /usr/bin/systemctl restart nginx`. Comprobado con `sudo -l -U maria` y probando como `pedro` (sin sudo) y como alguien de fuera de `ops`.

**D2:** usuario `--system --shell /usr/sbin/nologin`; unit con `User=horasvc`, `ExecStart=/usr/bin/python3 -m http.server 8090 --bind 127.0.0.1 --directory …`, `Restart=on-failure`, `WantedBy=multi-user.target`; `daemon-reload` y `enable --now`; nginx con `location /hora/ { proxy_pass http://127.0.0.1:8090/; }`, `nginx -t` y reload. `curl http://IP/hora/` desde el PC → 200. *Escuchar en 127.0.0.1 ya es una buena decisión.*

**D3:** `ufw default deny incoming`, `allow OpenSSH`, `allow 80/tcp`, `enable`. Desde el PC: `nc -zv -w3 IP 8090` → timeout (o refused si el servicio escucha en 127.0.0.1) y `curl IP/hora/` → 200. Razón: un solo punto de entrada (el proxy) que centraliza TLS, logs y control; el servicio interno no queda expuesto. Es el patrón de ALB + subred privada.

## Parte E (puntos clave que deben aparecer)

**E1:** DNS resolution (cache → resolver → root/TLD/authoritative) → TCP handshake to port 443 → TLS handshake and certificate validation → HTTP request with Host header → server/proxy/app processes it → response with status code → browser renders it.

**E2:** Confirm and scope the problem (is it down for everyone? since when? what changed?) → check from outside (curl, status code, timeout vs refused) → work bottom-up: DNS, network/firewall, process and port, application logs → fix, verify from outside, communicate → write a postmortem.

**E3:** STAR: Situation (the shop API returned 502), Task (restore service), Action (checked nginx error log → connection refused → `ss` showed the app on the wrong port → fixed the unit file, `daemon-reload`, verified with curl), Result (service restored; proposed config review and validation to prevent it).
