# Clase 20 — Tareas programadas: cron y un backup con rotación

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** C. Scripting con Bash

## Objetivo

- Programar tareas con `cron` y leer y escribir su sintaxis de cinco campos.
- Conocer el **entorno de cron** y escribir scripts que funcionen igual en tu terminal que en cron.
- Guardar la salida en un log y saber dónde mirar si una tarea no se ejecutó.
- Escribir un **backup con fecha y rotación** (borra las copias de más de 7 días) y programarlo. Es uno de los criterios para cerrar la fase 1.
- Saber cuándo conviene un *timer* de systemd en lugar de cron.

## Por qué importa

Backups, limpieza de logs, informes diarios, comprobaciones de salud: todo lo periódico se programa. En servidores Linux lo verás con cron y con timers de systemd. La misma sintaxis de cron vuelve en los **CronJob de Kubernetes** (fase 9), en los `schedule` de GitHub Actions (fase 7) y en las reglas programadas de AWS. "El backup no se ejecutaba y nadie se dio cuenta" es un incidente clásico: hoy aprendes a comprobarlo. Y en la clase 21, cron lanzará Vigía cada 5 minutos.

## Teoría

### La línea de cron

```
┌───────────── minuto (0–59)
│ ┌─────────── hora (0–23)
│ │ ┌───────── día del mes (1–31)
│ │ │ ┌─────── mes (1–12)
│ │ │ │ ┌───── día de la semana (0–7: 0 y 7 son domingo)
│ │ │ │ │
* * * * *  comando
```

| Expresión | Significa |
|-----------|-----------|
| `*/5 * * * *` | cada 5 minutos |
| `0 21 * * *` | todos los días a las 21:00 |
| `30 6 * * 1-5` | a las 6:30, de lunes a viernes |
| `0 */6 * * *` | cada 6 horas, en punto |
| `0 3 1 * *` | el día 1 de cada mes a las 3:00 |
| `@reboot` | una vez, al arrancar el sistema |

Para comprobar una expresión, [crontab.guru](https://crontab.guru) la traduce a palabras.

### Los comandos

| Comando | Qué hace |
|---------|----------|
| `crontab -e` | edita **tu** crontab. La primera vez te pregunta el editor: elige `nano` |
| `crontab -l` | lo muestra |
| `crontab archivo` | reemplaza tu crontab por el contenido del archivo |
| `crontab -r` | ⚠️ **lo borra entero, sin preguntar**. La `r` está al lado de la `e` en el teclado |

Antes de tocarlo, haz una copia: `crontab -l > ~/crontab.respaldo`.

Cada usuario tiene su propio crontab. Las tareas del sistema viven en `/etc/crontab`, `/etc/cron.d/` y `/etc/cron.daily/`. En tu portátil, las de `/etc/cron.daily/` las lanza **anacron**, que recupera las ejecuciones perdidas si el equipo estaba apagado.

### El entorno de cron: aquí falla casi todo

Comprobado en Ubuntu 26.04, un trabajo de tu crontab arranca así:

| | En tu terminal | En cron |
|--|----------------|---------|
| `PATH` | largo; incluye `~/bin` si lo añadiste | solo `/usr/bin:/bin` |
| Shell que lee la línea del crontab | bash | `/bin/sh` (dash) |
| Directorio de trabajo | donde estés | tu `HOME` |
| `~/.bashrc`, alias y variables exportadas | sí | **no** |
| Terminal | sí | no |
| Salida del comando | la pantalla | **se pierde**: no hay correo configurado, y cron solo deja `No MTA installed, discarding output` en su log |

De ahí salen cuatro reglas:
1. **Rutas absolutas** en el crontab: `/home/educo/bin/backup.sh`, no `backup.sh`.
2. Dentro del script, no supongas en qué carpeta estás: usa rutas absolutas o calcula la carpeta del script con `DIR="$(cd "$(dirname "$0")" && pwd)"`.
3. **Redirige la salida a un log**: `>> /home/educo/logs/backup.log 2>&1`.
4. **El `%` es especial** en una línea de crontab: cron lo convierte en un salto de línea y corta el comando ahí. `date +%F` en el crontab rompe la línea. Escápalo (`\%`) o, mejor, pon la lógica en un script.

Y una de hardware: si tu portátil está apagado o suspendido a la hora programada, cron **no** recupera esa ejecución.

### Comprobar que se ejecutó

```bash
journalctl -u cron --since "10 min ago" --no-pager
```

Cada ejecución deja una línea `CRON[1234]: (educo) CMD (…el comando…)`. Si la tarea no aparece ahí, cron no la lanzó. Si aparece pero no hizo lo esperado, mira **tu** log.

### cron frente a un timer de systemd (clase 12)

| | cron | timer de systemd |
|--|------|------------------|
| Definición | una línea | dos archivos (`.service` y `.timer`) |
| Logs | solo los que tú redirijas | automáticos en el journal (`journalctl -u nombre`) |
| Si el equipo estaba apagado | esa ejecución se pierde | `Persistent=true` la lanza al volver |
| Dónde lo verás | casi cualquier servidor; la misma sintaxis en Kubernetes y en CI | las tareas del propio sistema en distribuciones modernas |

Para Vigía usarás cron: es más simple y su sintaxis te servirá en la fase 9.

## Práctica guiada

### 0. Preparación

```bash
mkdir -p ~/my-devops-journey/labs/clase-20 ~/bin ~/logs ~/backups
cd ~/my-devops-journey/labs/clase-20
crontab -l > ~/crontab.respaldo 2>/dev/null ; echo "respaldo hecho"
```

Si nunca usaste cron, `crontab -l` dice `no crontab for educo` y el respaldo queda vacío. Es normal.

### 1. El entorno de cron, visto con tus ojos

```bash
crontab -e
```

Añade al final esta línea, guarda y sal:

```
* * * * * env > /tmp/env-cron.txt; pwd >> /tmp/env-cron.txt
```

🔮 **Predice:** ¿qué `PATH` tendrá? ¿En qué carpeta se ejecutará? ¿Estarán tus variables y tus alias?

Espera a que cambie el minuto (`date`) y compara:

```bash
cat /tmp/env-cron.txt
env | wc -l ; wc -l < /tmp/env-cron.txt
diff <(env | sort) <(sort /tmp/env-cron.txt) | head -30
journalctl -u cron --since "5 min ago" --no-pager | tail -5
```

Cron tiene menos de diez variables; tu terminal, decenas. Fíjate en `PATH=/usr/bin:/bin` y en `SHELL=/bin/sh`.

Vuelve a `crontab -e` y **borra esa línea**.

### 2. El script de backup

```bash
nano ~/bin/backup.sh
```

```bash
#!/bin/bash
# backup.sh — comprime una carpeta con la fecha en el nombre y borra las copias de más de 7 días
# Uso: backup.sh <carpeta> [destino]
set -euo pipefail

ORIGEN="${1:?Uso: $0 <carpeta> [destino]}"
DESTINO="${2:-$HOME/backups}"
DIAS=7

log() { echo "$(date '+%F %T') [$1] ${*:2}"; }

[[ -d $ORIGEN ]] || { log ERROR "$ORIGEN no es un directorio"; exit 1; }
mkdir -p "$DESTINO"

BASE="$(basename "$ORIGEN")"
ARCHIVO="$DESTINO/$BASE-$(date +%F_%H%M%S).tar.gz"
tar -czf "$ARCHIVO" -C "$(dirname "$ORIGEN")" "$BASE"
log INFO "creado $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))"

BORRADOS="$(find "$DESTINO" -maxdepth 1 -name "$BASE-*.tar.gz" -mtime +"$DIAS" -print -delete | wc -l)"
log INFO "rotación: $BORRADOS copias de más de $DIAS días borradas"
```

Línea por línea, lo nuevo:
- `basename` y `dirname` separan `/home/educo/datos` en `datos` y `/home/educo`.
- `tar -C carpeta-padre nombre` guarda la ruta **relativa** (`datos/…`), no la absoluta. Así el backup se restaura en cualquier sitio.
- La fecha incluye la hora (`%F_%H%M%S`). 🔮 ¿Qué pasaría con solo `%F` si lo ejecutas dos veces el mismo día?
- `find … -mtime +7 -print -delete` borra las copias de más de 7 días y las imprime, y `wc -l` las cuenta.
- Aquí `log` escribe en stdout porque, desde cron, stdout y stderr irán al mismo archivo.

```bash
chmod +x ~/bin/backup.sh
shellcheck ~/bin/backup.sh
mkdir -p ~/datos-prueba && echo "importante" > ~/datos-prueba/a.txt
~/bin/backup.sh ~/datos-prueba
ls -l ~/backups
tar -tzf ~/backups/datos-prueba-*.tar.gz
```

### 3. Probar la rotación sin esperar una semana

`touch -d` cambia la fecha de modificación de un archivo: puedes fabricar backups "viejos".

```bash
touch -d "8 days ago" ~/backups/datos-prueba-2026-01-01_000000.tar.gz
touch -d "3 days ago" ~/backups/datos-prueba-2026-01-02_000000.tar.gz
ls -l --time-style=+%F ~/backups
```

🔮 **Predice:** tras el siguiente backup, ¿cuál de los dos desaparecerá?

```bash
~/bin/backup.sh ~/datos-prueba
ls -l --time-style=+%F ~/backups
```

### 4. Programarlo

Primero, cada minuto, para verlo funcionar:

```bash
crontab -e
```

```
# backup de mis notas del curso (en pruebas: cada minuto)
* * * * * /home/educo/bin/backup.sh /home/educo/my-devops-journey/notas >> /home/educo/logs/backup.log 2>&1
```

Espera un par de minutos y comprueba **las tres cosas**: el log de cron, tu log y el resultado.

```bash
journalctl -u cron --since "5 min ago" --no-pager | grep backup
cat ~/logs/backup.log
ls -l ~/backups
```

Cuando funcione, cambia el horario a uno diario en el que tu portátil suela estar encendido, por ejemplo `0 21 * * *`, y borra las copias de prueba que sobran.

Un backup en el mismo disco protege de un borrado accidental, pero no de que el disco muera. En la fase 6 lo subirás a S3.

## Rómpelo

**1. El comando que cron no encuentra.** Añade esta línea a tu crontab:
```
* * * * * backup.sh /home/educo/datos-prueba >> /home/educo/logs/roto.log 2>&1
```
Tras un minuto: `cat ~/logs/roto.log` → `/bin/sh: 1: backup.sh: not found`. En tu terminal funciona porque `~/bin` está en tu PATH; en cron, el PATH es `/usr/bin:/bin`. Quita la línea.

**2. El `%` traidor.** Añade:
```
* * * * * echo "hoy es $(date +%F)" >> /home/educo/logs/fecha.log 2>&1
```
🔮 **Predice:** ¿qué habrá en `~/logs/fecha.log` dentro de un minuto?

No habrá ni siquiera archivo. Mira lo que vio cron:
```bash
journalctl -u cron --since "3 min ago" --no-pager | grep -E "hoy es|MTA"
```
El comando quedó cortado en el `%` (`CMD (echo "hoy es $(date +)`), así que la redirección al log nunca llegó a ejecutarse, y el error de sintaxis acabó en la salida descartada (`No MTA installed, discarding output`). Un fallo **totalmente silencioso**. Cambia `%F` por `\%F`, comprueba que ya escribe y después quita la línea.

**3. La carpeta en la que cron te deja.** Añade:
```
* * * * * echo "¿dónde estoy?" > donde.txt
```
Tras un minuto, busca `donde.txt`: está en tu HOME (`ls ~/donde.txt`), no en la carpeta de la clase. En un script, una ruta relativa se resuelve desde la carpeta actual, y en cron esa carpeta es tu HOME. Quita la línea y borra el archivo.

**4. `crontab -r` y la vuelta atrás:**
```bash
crontab -l > ~/crontab.respaldo
crontab -r
crontab -l
crontab ~/crontab.respaldo
crontab -l
```
Un respaldo de un segundo te salva del error de teclado más caro de cron.

## Reto

1. **Sin mirar la clase**, escribe desde cero `~/bin/backup2.sh` con el mismo comportamiento que `backup.sh`. Después compáralos con `diff`. Este es un criterio de salida de la fase 1: repítelo otro día hasta que te salga sin ayuda.
2. Escribe la línea de crontab que, los domingos a las 20:00, borre los archivos de `~/logs` con más de 30 días. Explica cada campo.
3. Traduce a palabras: `15 2 * * 1-5`, `*/10 8-18 * * *` y `0 0 1 1 *`.
4. Opcional: convierte el backup en un **timer de systemd de usuario** (sin `sudo`). Crea `~/.config/systemd/user/backup.service` (`Type=oneshot`, `ExecStart=%h/bin/backup.sh %h/my-devops-journey/notas`) y `backup.timer` (`OnCalendar=*-*-* 21:00:00`, `Persistent=true`, `WantedBy=timers.target`). Actívalo con `systemctl --user daemon-reload && systemctl --user enable --now backup.timer`, y míralo con `systemctl --user list-timers` y `journalctl --user -u backup.service`. ¿Qué ventaja tiene `Persistent=true` en un portátil? (`%h` es tu HOME dentro de una unit.)

## Cierre

En `notas/fase-1/clase-20.md`:

1. Escribe la línea de crontab que ejecute `/home/educo/bin/informe.sh` de lunes a viernes a las 7:30 y guarde su salida y sus errores en `/home/educo/logs/informe.log`. Explica cada campo.
2. Da tres diferencias entre el entorno de tu terminal y el de cron, y cómo escribes los scripts para que no te afecten.
3. ¿Cómo compruebas si una tarea de cron se ejecutó y, si se ejecutó, si falló?
4. **Repaso (clase 19, sin mirar):** ¿qué hace cada parte de `set -euo pipefail`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `30 7 * * 1-5 /home/educo/bin/informe.sh >> /home/educo/logs/informe.log 2>&1`. Minuto 30, hora 7, cualquier día del mes, cualquier mes, días de la semana 1 a 5 (lunes a viernes). `>>` añade al log sin borrarlo y `2>&1` manda también los errores.

**2.** Tres de: el PATH es solo `/usr/bin:/bin` (usa rutas absolutas); la línea la ejecuta `/bin/sh`, no bash (pon la lógica en un script con su shebang); el directorio de trabajo es tu HOME (no uses rutas relativas o calcula la carpeta del script); no carga `~/.bashrc` ni tus alias ni tus variables exportadas (define en el script lo que necesites); la salida se pierde (redirígela a un log); el `%` corta la línea (escápalo o usa un script).

**3.** `journalctl -u cron` muestra una línea `CMD (…)` por cada ejecución: si no está, cron no la lanzó (horario mal escrito, crontab sin guardar, equipo apagado). Si está, el resultado se mira en el log al que rediriges la salida y en lo que el script debía producir (el archivo de backup). El código de salida del script, escrito por su función `log`, dice si terminó bien.

**4.** `-e`: salir en cuanto un comando falle. `-u`: error si se usa una variable no definida. `-o pipefail`: un pipe falla si falla cualquiera de sus comandos, no solo el último.

**Reto 2:** `0 20 * * 0 /usr/bin/find /home/educo/logs -type f -mtime +30 -delete`. Minuto 0, hora 20, cualquier día del mes y cualquier mes, día de la semana 0 (domingo).

**Reto 3:** a las 2:15 de lunes a viernes · cada 10 minutos entre las 8:00 y las 18:50 · a medianoche del 1 de enero.

**Reto 4:** con `Persistent=true`, si el portátil estaba apagado o suspendido a las 21:00, systemd lanza el backup en cuanto vuelve a estar encendido. Cron, en cambio, se lo salta. Un detalle: los timers de usuario solo corren mientras tienes la sesión iniciada, salvo que actives `loginctl enable-linger`.

**Un detalle de `-mtime +7`:** `find` redondea la edad hacia abajo en días completos, así que `+7` significa "8 días o más". Una copia de 7 días y medio todavía se conserva.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| cron job / scheduled task | tarea programada |
| backup rotation / retention | rotación / retención de copias |
| absolute path | ruta absoluta |
| missed run | ejecución perdida |
| silent failure | fallo silencioso |

🎙️ *"A backup that isn't monitored doesn't exist. I log every run, rotate old copies, check that the job actually ran, and test restoring from it."*

## Fin del bloque C

Ya escribes scripts que validan su entrada, fallan de forma segura, dejan rastro y se ejecutan solos. Con eso construyes tu primer proyecto de portafolio.

## Siguiente

[Clase 21 — Proyecto: Vigía v0](clase-21-vigia-v0.md)
