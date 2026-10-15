# Clase 12 — systemd: servicios

**Dónde:** VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** `systemd` es el **encargado del edificio**: al encender arranca los servicios en orden, los vigila y los vuelve a levantar si se caen. Tú le dejas las instrucciones en un archivo *unit* (qué ejecutar, con qué usuario, qué hacer si falla) y él se ocupa. Dos preguntas que nunca debes confundir: ¿está funcionando **ahora**? (`start`) y ¿arrancará **después de reiniciar**? (`enable`).

## Objetivo

- Gestionar servicios con `systemctl`: arrancar, parar, reiniciar, recargar, activar en el arranque.
- Leer `systemctl status` como un profesional.
- **Escribir tu propio servicio**: un archivo *unit* que ejecuta una app con su usuario, se reinicia si muere y arranca con la máquina.
- Diagnosticar un servicio que no arranca.

## Por qué importa

Toda aplicación en un servidor corre como servicio: nginx, bases de datos, tu API, el agente de CloudWatch, el agente de SSM. "El servicio está caído" es la incidencia más común de operaciones, y `systemctl status` + `journalctl -u` es la respuesta de los primeros 30 segundos. Además, escribir un unit file es exactamente lo que harás para desplegar una app en una EC2 sin contenedores.

## Teoría

Cinco piezas, con la imagen del encargado del edificio de *La idea de hoy*.

### 1. El encargado del edificio

`systemd` es el **PID 1**: el primer proceso que arranca el kernel, padre de todos los demás (lo viste en el árbol de la clase 11). Hace de **encargado**:
- al encender, **arranca** los servicios en el orden correcto;
- mientras funcionan, los **vigila** y los vuelve a levantar si se caen;
- y apunta todo lo que dicen en su registro, el *journal* (clase 13).

### 2. Las fichas de instrucciones: las *units*

Cada cosa que gestiona el encargado tiene una **ficha de instrucciones**, una *unit*. Hoy usarás dos tipos:
- `.service`: un programa que debe estar funcionando (`nginx.service`).
- `.timer`: algo que debe ejecutarse a ciertas horas (`apt-daily.timer`), la alternativa moderna a cron.

Las fichas viven en dos sitios, y esto importa:

| Dónde | Qué hay | ¿Las tocas? |
|-------|---------|-------------|
| `/usr/lib/systemd/system/` | las fichas **del fabricante**, que instalan los paquetes | **No**: una actualización las sobrescribe |
| `/etc/systemd/system/` | **las tuyas** y tus cambios | **Sí**: tienen prioridad sobre las del fabricante |

### 3. Leer una ficha

Así es la ficha del servicio que vas a crear hoy. Cada `#` explica la línea de debajo:

```ini
[Unit]
Description=Mi aplicación web
# arrancar después de que haya red
After=network-online.target
Wants=network-online.target

[Service]
# NUNCA root si no hace falta
User=appsvc
WorkingDirectory=/srv/miapp
# configuración por variables (clase 07)
Environment=PORT=8080
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /srv/miapp
# si muere con error, reiniciar a los 3 segundos
Restart=on-failure
RestartSec=3

[Install]
# "actívame en el arranque normal"
WantedBy=multi-user.target
```

Tres secciones: `[Unit]` dice **qué es** y cuándo arrancarlo; `[Service]` dice **cómo ejecutarlo** (con qué usuario, qué comando y qué hacer si falla); `[Install]` dice si debe arrancar **al encender** el servidor.

⚠️ Los comentarios (`#`) van **en su propia línea**. Un `#` al final de una línea con valor **no** es un comentario: pasaría a formar parte del valor.

### 4. Hablar con el encargado: `systemctl`

Lo esencial son seis órdenes:

```bash
systemctl status nginx          # ¿cómo está? (estado, PID y sus últimas líneas de log)
sudo systemctl start nginx      # arráncalo AHORA
sudo systemctl stop nginx       # páralo
sudo systemctl restart nginx    # páralo y arráncalo
sudo systemctl enable nginx     # arráncalo CADA VEZ que se encienda el servidor
sudo systemctl daemon-reload    # vuelve a leer las fichas (después de editar una)
```

La confusión más cara del oficio es la de `start` y `enable`. Son dos preguntas **independientes**:
- **¿Está abierto ahora?** Es `start`, y lo dice `is-active`.
- **¿Abrirá mañana, cuando se reinicie?** Es `enable`, y lo dice `is-enabled`.

Arrancas un servicio a mano, compruebas que funciona y te vas… pero no lo habilitaste. Semanas después la EC2 se reinicia y la web no vuelve. Por eso se usa `sudo systemctl enable --now x`: lo habilita **y** lo arranca.

### 5. Para entrevistas: qué pasa al encender un servidor

```
firmware (BIOS/UEFI) ─► gestor de arranque (GRUB) ─► kernel (+ initramfs) ─► systemd (PID 1) ─► targets y servicios ─► login
  comprueba el hardware    elige y carga el kernel      monta el disco raíz       arranca todo en orden      (multi-user.target)
```

En una EC2 no ves la pantalla, pero sí la **consola del sistema** (*Get system log* / *EC2 serial console*). Ahí se diagnostica una instancia que no arranca, por ejemplo por un `fstab` roto (clase 14).

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Instalas un servicio, haces `enable` y te vas. ¿Está funcionando ahora mismo?
2. Has editado una ficha en `/etc/systemd/system/`. ¿Qué tienes que hacer antes de reiniciar el servicio?
3. ¿Por qué no se edita una ficha de `/usr/lib/systemd/system/`?

<details>
<summary>Comprueba</summary>

1. No necesariamente: `enable` solo hace que arranque **al encender**. Para arrancarlo ya, `start` (o las dos cosas con `enable --now`). 2. `sudo systemctl daemon-reload`, para que el encargado vuelva a leer las fichas. 3. Porque es del fabricante: la próxima actualización del paquete la sobrescribiría. Tus cambios van en `/etc/systemd/system/`.
</details>

### Tu chuleta de la clase

| `systemctl …` | Efecto |
|---------------|--------|
| `status x` | estado, PID, memoria y las últimas líneas de log |
| `start` / `stop` / `restart x` | arrancar / parar / parar y arrancar |
| `reload x` | recargar la configuración **sin cortar** (si el servicio lo soporta) |
| `enable` / `disable x` | arrancar (o no) **al encender**. ⚠️ No lo arranca ahora |
| `enable --now x` | habilitar y arrancar a la vez |
| `is-active x` · `is-enabled x` | respuesta corta, ideal para scripts |
| `daemon-reload` | releer las fichas tras editarlas |
| `list-units --type=service --failed` | qué servicios fallaron |
| `cat x` · `edit x` · `revert x` | ver la ficha efectiva · cambiar solo unas líneas (*drop-in*) · deshacer esos cambios |
| `reset-failed x` | limpiar el estado `failed` para poder arrancarlo otra vez |

Otros tipos de unit que verás: `.target` (un grupo de units, como `multi-user.target`, «el arranque normal»), `.socket` y `.mount`. Un *drop-in* es un archivo `/etc/systemd/system/x.service.d/override.conf` que cambia solo algunas líneas de una ficha: lo crea `systemctl edit x`.

## Práctica guiada

```bash
multipass shell servidor-01
```

### 1. Leer un status

```bash
systemctl status nginx --no-pager
```

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
             └ de dónde sale la unit                       └ ¿arranca con el sistema?
     Active: active (running) since ...; 2h ago
             └ ¿está corriendo ahora?
   Main PID: 1234 (nginx)
     Memory: 4.1M
     CGroup: /system.slice/nginx.service
             ├─1234 "nginx: master process ..."
             └─1235 "nginx: worker process"
oct 05 10:00:00 servidor-01 systemd[1]: Started nginx.service ...   ← últimas líneas de log
```

```bash
systemctl is-active nginx; systemctl is-enabled nginx
systemctl cat nginx
systemctl list-units --type=service --state=running --no-pager
systemctl list-units --failed --no-pager
```

### 2. Parar, arrancar y recargar

🔮 **Predice:** tras `stop`, ¿qué devolverá `curl`?

```bash
sudo systemctl stop nginx
curl -s -m 3 localhost || echo "no responde"
sudo systemctl start nginx
curl -s -o /dev/null -w "%{http_code}\n" localhost
sudo systemctl reload nginx
systemctl status nginx --no-pager | head -5
```

### 3. Tu propio servicio

Prepara la app y su usuario:

```bash
id appsvc 2>/dev/null || sudo useradd --system --no-create-home --shell /usr/sbin/nologin appsvc
sudo mkdir -p /srv/miapp
echo "<h1>Mi app en servidor-01</h1>" | sudo tee /srv/miapp/index.html
sudo chown -R appsvc:appsvc /srv/miapp
```

Escribe la unit:

```bash
sudo nano /etc/systemd/system/miapp.service
```

Copia el ejemplo de la teoría tal cual. Después:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now miapp
systemctl status miapp --no-pager
curl -s localhost:8080
ps -o user,pid,cmd -C python3
```

Comprueba que el proceso corre como `appsvc`, no como root.

### 4. Auto-reparación

🔮 **Predice:** si matas el proceso con `SIGKILL`, ¿qué hará systemd?

```bash
sudo kill -9 $(systemctl show -p MainPID --value miapp)
sleep 1; systemctl status miapp --no-pager | head -5
sleep 3; systemctl status miapp --no-pager | head -5
curl -s localhost:8080
```

systemd detectó la muerte, esperó `RestartSec=3` y lo levantó con un **PID nuevo**.

¿Y con un `stop` normal?
```bash
sudo systemctl stop miapp
sleep 5; systemctl is-active miapp
sudo systemctl start miapp
```
No se reinicia: `Restart=on-failure` solo actúa ante fallos, no ante una parada pedida.

### 5. ¿Sobrevive a un reinicio?

```bash
sudo reboot
```

Espera 20 segundos y, desde tu PC:
```bash
multipass exec servidor-01 -- systemctl is-active miapp nginx
multipass exec servidor-01 -- curl -s localhost:8080
```

Ambos `active`, porque están `enabled`.

## Rómpelo

Snapshot primero (desde tu PC): `multipass stop servidor-01 && multipass snapshot servidor-01 --name pre-systemd && multipass start servidor-01`.

**1. Una ruta mal escrita:**
```bash
sudo sed -i 's|/usr/bin/python3|/usr/bin/pyton3|' /etc/systemd/system/miapp.service
sudo systemctl restart miapp
```
🔮 **Predice:** ¿qué crees que pasará? Lee el mensaje con atención.

`restart` te avisa de que la unit cambió en disco y no hiciste `daemon-reload`: **systemd todavía usa la versión vieja**. Recarga y repite:
```bash
sudo systemctl daemon-reload
sudo systemctl restart miapp
systemctl status miapp --no-pager
journalctl -u miapp -n 20 --no-pager
```
Busca en el log la línea que dice **exactamente** qué falló (algo como `Unable to locate executable '/usr/bin/pyton3'` y `status=203/EXEC`). Corrígelo:
```bash
sudo sed -i 's|/usr/bin/pyton3|/usr/bin/python3|' /etc/systemd/system/miapp.service
sudo systemctl daemon-reload && sudo systemctl restart miapp && systemctl is-active miapp
```

**2. Activo, pero sin funcionar:**
```bash
sudo chown root:root /srv/miapp/index.html
sudo chmod 600 /srv/miapp/index.html
sudo systemctl restart miapp
systemctl is-active miapp
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080
```
El servicio está `active`, pero responde con un **error** (404): `appsvc` ya no puede leer el archivo. **"Running" no significa "funcionando"**: comprueba siempre con una petición real. Arréglalo:
```bash
sudo chown appsvc:appsvc /srv/miapp/index.html && sudo chmod 644 /srv/miapp/index.html
curl -s localhost:8080
```

Y si el permiso que falta es el del **directorio de trabajo**, el servicio ni siquiera arranca. Pruébalo:
```bash
sudo chmod 700 /srv/miapp && sudo chown root:root /srv/miapp
sudo systemctl restart miapp
systemctl status miapp --no-pager | head -8
```
Busca `status=200/CHDIR`: systemd no pudo entrar en `WorkingDirectory`. Restaura:
```bash
sudo chown appsvc:appsvc /srv/miapp && sudo chmod 755 /srv/miapp && sudo systemctl restart miapp && systemctl is-active miapp
```

**3. Un bucle de reinicios:**
```bash
sudo systemctl edit miapp
```
Escribe en la zona indicada (entre los comentarios) y guarda:
```ini
[Service]
ExecStart=
ExecStart=/bin/false
RestartSec=500ms
```
La primera línea `ExecStart=` vacía **borra** el valor heredado; la segunda pone uno que siempre falla; `RestartSec` corto acelera los reintentos.
```bash
sudo systemctl restart miapp
watch -n1 systemctl status miapp --no-pager
```
Verás cómo reintenta (`activating (auto-restart)`) hasta que systemd se rinde y lo deja en `failed`. En el log aparece `Start request repeated too quickly`: por defecto, más de 5 arranques en 10 segundos bloquean nuevos intentos. Así un servicio roto no consume la máquina reiniciándose sin fin. Para volver a arrancarlo después hay que limpiar ese estado con `systemctl reset-failed`. Sal de `watch` con `Ctrl+C` y deshaz:
```bash
sudo systemctl revert miapp
sudo systemctl reset-failed miapp
sudo systemctl restart miapp && systemctl is-active miapp
```

## Reto

En la VM. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Con un drop-in, cambia el `RestartSec` de `miapp` a 10 sin tocar el archivo original. Comprueba el resultado.

<details>
<summary>Pista</summary>

`sudo systemctl edit miapp` abre un archivo casi vacío. Escribe entre los comentarios `[Service]` y, debajo, `RestartSec=10`. Guarda y mira el resultado con `systemctl cat miapp`.
</details>

**2.** Elige tres servicios de `systemctl list-unit-files --type=service --state=enabled` y comprueba con `systemctl is-active` si están funcionando ahora. ¿Alguno está habilitado pero no activo? ¿Por qué podría ser?

<details>
<summary>Pista</summary>

`systemctl is-active nombre` responde `active` o `inactive`. Recuerda las dos preguntas de la pieza 4: ¿abrirá al encender? y ¿está abierto ahora? Pueden tener respuestas distintas.
</details>

**3.** (El más largo.) Crea un **timer** que cada minuto añada la fecha y la carga del sistema a `/var/log/latido.log`. Necesitas dos fichas: `latido.service` (`Type=oneshot`, con `ExecStart=/bin/sh -c 'echo "$(date) $(cat /proc/loadavg)" >> /var/log/latido.log'`) y `latido.timer` (con `[Timer] OnCalendar=minutely` y `[Install] WantedBy=timers.target`).

<details>
<summary>Pista</summary>

Crea cada ficha con `sudo nano /etc/systemd/system/latido.service` (y `latido.timer`), con la forma `[Unit]`/`[Service]` del ejemplo de la teoría. El `.service` no necesita `[Install]`: lo arranca el timer. Después, `sudo systemctl daemon-reload` y `sudo systemctl enable --now latido.timer`. Comprueba con `systemctl list-timers` y, pasado un minuto, con `cat /var/log/latido.log`.
</details>

## Cierre

En `notas/fase-1/clase-12.md`:

1. Diferencia entre `start` y `enable`. Cuenta el incidente típico que provoca confundirlos.
2. Un servicio no arranca. Escribe tus **tres primeros comandos** y qué buscas en cada uno.
3. ¿Por qué tu servicio corre con `User=appsvc` y no como root? ¿Qué gana la seguridad?
4. **Repaso (clase 11, sin mirar):** ¿qué hace `SIGHUP` en nginx y qué comando de systemctl lo usa?

Después, escríbeme `examíname clase-12`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `start` lo arranca **ahora**. `enable` hace que arranque **en cada inicio del sistema**, pero no lo arranca en el momento. El incidente: alguien arranca un servicio a mano, comprueba que funciona y se va. Semanas después la instancia se reinicia (mantenimiento de AWS, un parche del kernel) y el servicio no vuelve. La web cae "sin que nadie tocara nada". Por eso: `enable --now` y comprobar `is-enabled`.

**2.** (a) `systemctl status x`: si está activo o failed, el código de salida, el PID y las últimas líneas de log. (b) `journalctl -u x -n 50 --no-pager` (o `-xeu x`): el error completo, por ejemplo un ejecutable inexistente, un permiso denegado o un puerto ocupado. (c) `systemctl cat x`: la unit efectiva, para revisar rutas, usuario y variables. Después, comprobar con una petición real (`curl`) o con `ss -tlnp` (clase 29).

**3.** Por mínimo privilegio: si la app tiene una vulnerabilidad y alguien la explota, el atacante obtiene los permisos de `appsvc` (solo puede tocar `/srv/miapp`), no los de root, que le darían la máquina entera. Además, un error de la propia app no puede borrar el sistema.

**4.** `SIGHUP` hace que nginx relea su configuración y renueve los workers sin cortar las conexiones. `systemctl reload nginx` lo envía por debajo (lo define `ExecReload` en la unit).

**Reto 2:** un servicio puede estar habilitado y no activo por dos motivos: es de tipo `oneshot` (hace su trabajo al arrancar y termina, como `latido.service`) o falló al arrancar (`systemctl status` lo dirá, con `failed`).

**Reto 3 (las dos fichas):**
```ini
# /etc/systemd/system/latido.service
[Unit]
Description=Escribe un latido

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "$(date) $(cat /proc/loadavg)" >> /var/log/latido.log'
```
```ini
# /etc/systemd/system/latido.timer
[Unit]
Description=Latido cada minuto

[Timer]
OnCalendar=minutely

[Install]
WantedBy=timers.target
```
`sudo systemctl daemon-reload && sudo systemctl enable --now latido.timer`. Al terminar, desactívalo: `sudo systemctl disable --now latido.timer`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| daemon | demonio (proceso en segundo plano) |
| unit file | archivo de unidad |
| to enable at boot | activar en el arranque |
| restart policy | política de reinicio |
| drop-in override | modificación parcial de una unit |

🎙️ *"A running service is not necessarily a working service. After a restart I always verify with a real request, like curl against the health endpoint."*

## Siguiente

[Clase 13 — Logs y journalctl](clase-13-logs.md)
