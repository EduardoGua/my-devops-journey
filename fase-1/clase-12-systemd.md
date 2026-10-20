# Clase 12 — systemd: servicios

**Dónde:** VM `servidor-01` · **Tiempo:** 90 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** `systemd` es el **encargado del edificio**: al encender arranca los servicios en orden, los vigila y los vuelve a levantar si se caen. Tú le dejas las instrucciones en un archivo *unit* (qué ejecutar, con qué usuario, qué hacer si falla) y él se ocupa. Dos preguntas que nunca debes confundir: ¿está funcionando **ahora**? (`start`) y ¿arrancará **después de reiniciar**? (`enable`).

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El PID 1 es `systemd`, el padre de todos los procesos (clase 11).
> - `SIGTERM` y `SIGKILL`: pedir por favor y el apagón (clase 11).
> - El usuario de servicio `appsvc` y los permisos de una carpeta (clases 09 y 06).

> 🔤 **Palabras nuevas de hoy:**
> - **servicio**: un programa que debe estar siempre funcionando, como nginx.
> - **unit**: el archivo con las instrucciones de un servicio.
> - **demonio** (*daemon*): un programa que trabaja en segundo plano, sin terminal.
> - **habilitar** (`enable`): que arranque solo cada vez que se enciende el servidor.
> - **drop-in**: un archivo pequeño que cambia solo unas líneas de una unit.

## Objetivo

- Gestionar servicios con `systemctl`: arrancar, parar, reiniciar, recargar, activar en el arranque.
- Leer `systemctl status` como un profesional.
- **Escribir tu propio servicio**: un archivo *unit* que ejecuta una app con su usuario, se reinicia si muere y arranca con la máquina.
- Diagnosticar un servicio que no arranca.

## Por qué importa

Toda aplicación en un servidor corre como servicio: nginx, bases de datos, tu API, el agente de CloudWatch, el agente de SSM. "El servicio está caído" es la incidencia más común de operaciones, y `systemctl status` + `journalctl -u` es la respuesta de los primeros 30 segundos. Además, escribir un unit file es exactamente lo que harás para desplegar una app en una EC2 sin contenedores.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida en el servidor; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min: en la 3 creas tu propio servicio); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Todo se hace dentro de la VM:

```bash
multipass shell servidor-01
```

## Las piezas

### Pieza 1 — systemd y sus *units*

`systemd` es el **PID 1**: el primer proceso que arranca el kernel, padre de todos los demás (lo viste en el árbol de la clase 11). Se ocupa de tres cosas:
- al encender, **arranca** los servicios en el orden correcto;
- mientras funcionan, los **vigila** y los vuelve a levantar si se caen;
- y apunta todo lo que dicen en su registro, el *journal* (clase 13).

Cada cosa que gestiona systemd tiene un archivo de instrucciones, una **unit**. Hoy usarás dos tipos: `.service`, un programa que debe estar funcionando (`nginx.service`), y `.timer`, algo que debe ejecutarse a ciertas horas (`apt-daily.timer`), la alternativa moderna a cron. Las units viven en dos sitios, y esto importa:

| Dónde | Qué hay | ¿Las tocas? |
|-------|---------|-------------|
| `/usr/lib/systemd/system/` | las units **del fabricante**, que instalan los paquetes | **No**: una actualización las sobrescribe |
| `/etc/systemd/system/` | **las tuyas** y tus cambios | **Sí**: tienen prioridad sobre las del fabricante |

**Pruébalo: lee el estado de nginx.**

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

La unit de nginx es del fabricante: está en `/usr/lib/systemd/system/`. Mírala entera, y mira qué servicios están en marcha y si alguno falló:

```bash
systemctl cat nginx
systemctl list-units --type=service --state=running --no-pager
systemctl list-units --failed --no-pager
```

👀 **Qué deberías ver:** la unit de nginx entera, con sus secciones `[Unit]`, `[Service]` e `[Install]` (las leerás a fondo en la pieza 3); la lista de servicios en marcha; y, si todo va bien, `0 loaded units listed` en los fallidos.

**En resumen:** systemd arranca los servicios, los vigila y los vuelve a levantar si se caen. Cada servicio tiene su unit; las del fabricante no se tocan, y las tuyas van en `/etc/systemd/system/`.

### Pieza 2 — Dar órdenes a systemd: `systemctl`, y `start` frente a `enable`

Lo esencial son seis órdenes:

```bash
systemctl status nginx          # ¿cómo está? (estado, PID y sus últimas líneas de log)
sudo systemctl start nginx      # arráncalo AHORA
sudo systemctl stop nginx       # páralo
sudo systemctl restart nginx    # páralo y arráncalo
sudo systemctl enable nginx     # arráncalo CADA VEZ que se encienda el servidor
sudo systemctl daemon-reload    # vuelve a leer las units (después de editar una)
```

La confusión más cara del oficio es la de `start` y `enable`. Son dos preguntas **independientes**:
- **¿Está abierto ahora?** Es `start`, y lo dice `is-active`.
- **¿Abrirá mañana, cuando se reinicie?** Es `enable`, y lo dice `is-enabled`.

Arrancas un servicio a mano, compruebas que funciona y te vas… pero no lo habilitaste. Semanas después la EC2 se reinicia y la web no vuelve. Por eso se usa `sudo systemctl enable --now x`: lo habilita **y** lo arranca.

**Pruébalo:**

```bash
systemctl is-active nginx; systemctl is-enabled nginx
```

👀 **Qué deberías ver:** `active` y `enabled`: las dos preguntas, contestadas por separado.

🔮 **Predice:** tras `stop`, ¿qué devolverá `curl`? ¿Y qué dirán `is-active` e `is-enabled`?

```bash
sudo systemctl stop nginx
curl -s -m 3 localhost || echo "no responde"
systemctl is-active nginx; systemctl is-enabled nginx
sudo systemctl start nginx
curl -s -o /dev/null -w "%{http_code}\n" localhost
sudo systemctl reload nginx
systemctl status nginx --no-pager | head -5
```

<details>
<summary>Qué deberías ver</summary>

`no responde` tras el `stop`, con `inactive` y… `enabled`: parado ahora, pero arrancará al encender. Después, `200` tras el `start`; y nginx otra vez `active (running)` después del `reload`.
</details>

✋ **Sin mirar:** instalas un servicio, haces `enable` y te vas. ¿Está funcionando ahora mismo?

<details>
<summary>Comprueba</summary>

No necesariamente: `enable` solo hace que arranque **al encender**. Para arrancarlo ya, `start` (o las dos cosas con `enable --now`).
</details>

**En resumen:** `start` = ahora; `enable` = al encender. Casi siempre quieres las dos: `enable --now`.

### Pieza 3 — Leer y escribir una unit: tu propio servicio

Así es la unit del servicio que vas a crear ahora. Cada `#` explica la línea de debajo:

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

**Pruébalo.** Prepara la app y su usuario:

```bash
id appsvc 2>/dev/null || sudo useradd --system --no-create-home --shell /usr/sbin/nologin appsvc
sudo mkdir -p /srv/miapp
echo "<h1>Mi app en servidor-01</h1>" | sudo tee /srv/miapp/index.html
sudo chown -R appsvc:appsvc /srv/miapp
```

Escribe la unit. Está en `/etc/systemd/system/` porque es tuya:

```bash
sudo nano /etc/systemd/system/miapp.service
```

Copia la unit de arriba tal cual. Después:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now miapp
systemctl status miapp --no-pager
curl -s localhost:8080
ps -o user,pid,cmd -C python3
```

👀 **Qué deberías ver:** `active (running)`; tu página, `<h1>Mi app en servidor-01</h1>`; y el proceso de python3 con el usuario `appsvc`, no root.

✋ **Sin mirar:**
1. Has editado una unit en `/etc/systemd/system/`. ¿Qué tienes que hacer antes de reiniciar el servicio?
2. ¿Por qué no se edita una unit de `/usr/lib/systemd/system/`?

<details>
<summary>Comprueba</summary>

1. `sudo systemctl daemon-reload`, para que systemd vuelva a leer las units. 2. Porque es del fabricante: la próxima actualización del paquete la sobrescribiría. Tus cambios van en `/etc/systemd/system/`.
</details>

**En resumen:** `[Unit]` dice qué es, `[Service]` cómo ejecutarlo e `[Install]` si arranca al encender. Tras escribir una unit: `daemon-reload` y `enable --now`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Para salir de la VM, `exit`.

### Pieza 4 — La auto-reparación: `Restart=on-failure`

La línea `Restart=on-failure` de tu unit le dice a systemd que, si el proceso **muere con error**, lo vuelva a levantar, esperando `RestartSec` segundos. Una parada que **tú pides** no es un fallo.

**Pruébalo.** 🔮 **Predice:** si matas el proceso con `SIGKILL`, ¿qué hará systemd?

```bash
sudo kill -9 $(systemctl show -p MainPID --value miapp)
sleep 1; systemctl status miapp --no-pager | head -5
sleep 3; systemctl status miapp --no-pager | head -5
curl -s localhost:8080
```

<details>
<summary>Qué deberías ver</summary>

Al segundo, `activating (auto-restart)`; a los 3 segundos, otra vez `active (running)` con **otro** PID; y tu página respondiendo.
</details>

systemd detectó la muerte, esperó `RestartSec=3` y lo levantó con un **PID nuevo**.

¿Y con un `stop` normal?

```bash
sudo systemctl stop miapp
sleep 5; systemctl is-active miapp
sudo systemctl start miapp
```

👀 **Qué deberías ver:** `inactive`. No se reinicia: `Restart=on-failure` solo actúa ante fallos, no ante una parada pedida.

**En resumen:** con `Restart=on-failure`, systemd levanta el servicio si muere con error, pero respeta un `stop`.

### Pieza 5 — Qué pasa al encender un servidor

Para entrevistas, el orden del arranque:

```
firmware (BIOS/UEFI) ─► gestor de arranque (GRUB) ─► kernel (+ initramfs) ─► systemd (PID 1) ─► targets y servicios ─► login
  comprueba el hardware    elige y carga el kernel      monta el disco raíz       arranca todo en orden      (multi-user.target)
```

Al llegar a systemd, arranca todo lo que está `enabled`. En una EC2 no ves la pantalla, pero sí la **consola del sistema** (*Get system log* / *EC2 serial console*). Ahí se diagnostica una instancia que no arranca, por ejemplo por un `fstab` roto (clase 14).

**Pruébalo: ¿sobreviven tus servicios a un reinicio?**

```bash
sudo reboot
```

Espera 20 segundos y, desde tu PC:

```bash
multipass exec servidor-01 -- systemctl is-active miapp nginx
multipass exec servidor-01 -- curl -s localhost:8080
```

👀 **Qué deberías ver:** `active` dos veces y tu página: los dos arrancaron solos porque están `enabled`.

**En resumen:** firmware → GRUB → kernel → systemd → servicios. Lo que está `enabled` arranca solo al encender.

## Tu chuleta de la clase

| `systemctl …` | Efecto |
|---------------|--------|
| `status x` | estado, PID, memoria y las últimas líneas de log |
| `start` / `stop` / `restart x` | arrancar / parar / parar y arrancar |
| `reload x` | recargar la configuración **sin cortar** (si el servicio lo soporta) |
| `enable` / `disable x` | arrancar (o no) **al encender**. ⚠️ No lo arranca ahora |
| `enable --now x` | habilitar y arrancar a la vez |
| `is-active x` · `is-enabled x` | respuesta corta, ideal para scripts |
| `daemon-reload` | releer las units tras editarlas |
| `list-units --type=service --failed` | qué servicios fallaron |
| `cat x` · `edit x` · `revert x` | ver la unit efectiva · cambiar solo unas líneas (*drop-in*) · deshacer esos cambios |
| `reset-failed x` | limpiar el estado `failed` para poder arrancarlo otra vez |

Otros tipos de unit que verás: `.target` (un grupo de units, como `multi-user.target`, «el arranque normal»), `.socket` y `.mount`. Un *drop-in* es un archivo `/etc/systemd/system/x.service.d/override.conf` que cambia solo algunas líneas de una unit: lo crea `systemctl edit x`.

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

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
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

En la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Con un drop-in, cambia el `RestartSec` de `miapp` a 10 sin tocar el archivo original. Comprueba el resultado.

> 🧩 **Ejemplo resuelto:** cambiar con un drop-in la descripción de `miapp`.
> ```bash
> sudo systemctl edit miapp
> # entre los comentarios, escribe estas dos líneas:
> #   [Unit]
> #   Description=Mi app de prueba
> systemctl cat miapp
> ```
> `systemctl edit` crea el drop-in y recarga solo las units. `systemctl cat` enseña la unit original y, debajo, tu cambio.

**Ahora tú, con huecos:**
```bash
sudo systemctl edit miapp
# entre los comentarios:
#   [____]
#   RestartSec=____
systemctl cat miapp
```

<details>
<summary>Pista</summary>

`RestartSec` vive en la sección de la unit que dice **cómo ejecutarlo** (pieza 3).
</details>

**2.** Elige tres servicios de `systemctl list-unit-files --type=service --state=enabled` y comprueba con `systemctl is-active` si están funcionando ahora. ¿Alguno está habilitado pero no activo? ¿Por qué podría ser?

> 🧩 **Ejemplo resuelto:** las dos preguntas sobre nginx.
> ```bash
> systemctl is-enabled nginx
> systemctl is-active nginx
> ```
> `enabled` (arrancará al encender) y `active` (funciona ahora): dos respuestas independientes.

**Ahora tú, con huecos:**
```bash
systemctl list-unit-files --type=service --state=enabled
systemctl is-active ____
```

<details>
<summary>Pista</summary>

Copia un nombre de la lista en el hueco, y repite con otros dos. Recuerda las dos preguntas de la pieza 2: pueden tener respuestas distintas.
</details>

**3.** (El más largo.) Crea un **timer** que cada minuto añada la fecha y la carga del sistema a `/var/log/latido.log`. Necesitas dos units: `latido.service` (`Type=oneshot`, con `ExecStart=/bin/sh -c 'echo "$(date) $(cat /proc/loadavg)" >> /var/log/latido.log'`) y `latido.timer` (con `[Timer] OnCalendar=minutely` y `[Install] WantedBy=timers.target`).

> 🧩 **Ejemplo resuelto:** un servicio que escribe la fecha **una vez**, sin timer.
> ```bash
> sudo nano /etc/systemd/system/hola.service
> #   [Unit]
> #   Description=Escribe la fecha una vez
> #
> #   [Service]
> #   Type=oneshot
> #   ExecStart=/bin/sh -c 'date >> /var/log/hola.log'
> sudo systemctl daemon-reload
> sudo systemctl start hola
> cat /var/log/hola.log
> ```
> `Type=oneshot` significa «haz tu trabajo y termina». Cada `start` añade una línea. A `latido.service` le basta con eso; el timer solo le dice **cuándo**.

**Ahora tú, con huecos:**
```bash
# /etc/systemd/system/latido.timer
[Unit]
Description=Latido cada minuto

[Timer]
OnCalendar=____

[Install]
WantedBy=____
```

<details>
<summary>Pista</summary>

Los dos valores están en el enunciado. `latido.service` es como `hola.service`, pero con el `ExecStart` del enunciado. Después: `sudo systemctl daemon-reload`, `sudo systemctl enable --now latido.timer`, `systemctl list-timers` y, pasado un minuto, `cat /var/log/latido.log`.
</details>

## Cierre

En `notas/fase-1/clase-12.md`:

1. Diferencia entre `start` y `enable`. Cuenta el incidente típico que provoca confundirlos. *(3 líneas. Empieza así: «`start` lo arranca… `enable` hace que… El incidente: alguien… y cuando la máquina se reinicia…»)*
2. Un servicio no arranca. Escribe tus **tres primeros comandos** y qué buscas en cada uno. *(3 líneas, una por comando. Empieza así: «1. `systemctl status x`, para ver… 2. `journalctl -u x`, para… 3. …»)*
3. ¿Por qué tu servicio corre con `User=appsvc` y no como root? ¿Qué gana la seguridad? *(2 líneas. Empieza así: «Por mínimo privilegio: si alguien ataca la app, solo consigue…»)*
4. **Repaso (clase 11, sin mirar):** ¿qué hace `SIGHUP` en nginx y qué comando de systemctl lo usa? *(1–2 líneas. Empieza así: «SIGHUP hace que nginx… y lo usa `systemctl …`»)*

Después, escríbeme `examíname clase-12`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `start` lo arranca **ahora**. `enable` hace que arranque **en cada inicio del sistema**, pero no lo arranca en el momento. El incidente: alguien arranca un servicio a mano, comprueba que funciona y se va. Semanas después la instancia se reinicia (mantenimiento de AWS, un parche del kernel) y el servicio no vuelve. La web cae "sin que nadie tocara nada". Por eso: `enable --now` y comprobar `is-enabled`.

**2.** (a) `systemctl status x`: si está activo o failed, el código de salida, el PID y las últimas líneas de log. (b) `journalctl -u x -n 50 --no-pager` (o `-xeu x`): el error completo, por ejemplo un ejecutable inexistente, un permiso denegado o un puerto ocupado. (c) `systemctl cat x`: la unit efectiva, para revisar rutas, usuario y variables. Después, comprobar con una petición real (`curl`) o con `ss -tlnp` (clase 29).

**3.** Por mínimo privilegio: si la app tiene una vulnerabilidad y alguien la explota, el atacante obtiene los permisos de `appsvc` (solo puede tocar `/srv/miapp`), no los de root, que le darían la máquina entera. Además, un error de la propia app no puede borrar el sistema.

**4.** `SIGHUP` hace que nginx relea su configuración y renueve los workers sin cortar las conexiones. `systemctl reload nginx` lo envía por debajo (lo define `ExecReload` en la unit).

**Reto 2:** un servicio puede estar habilitado y no activo por dos motivos: es de tipo `oneshot` (hace su trabajo al arrancar y termina, como `latido.service`) o falló al arrancar (`systemctl status` lo dirá, con `failed`).

**Reto 3 (las dos units):**
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
