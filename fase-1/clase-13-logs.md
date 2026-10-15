# Clase 13 — Logs y journalctl

**Dónde:** VM `servidor-01` (y tu PC para generar tráfico) · **Tiempo:** 75 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** los logs son la **caja negra** del servidor: cuando algo falla, son la única forma de saber qué pasó y cuándo. Casi todo acaba en el *journal* de systemd, que consultas con `journalctl` filtrando por servicio, por hora y por gravedad hasta dar con la línea que lo explica.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Las mangueras 1 y 2 de cada programa (clase 04).
> - `tail -f` para seguir un archivo en directo (clase 03) y la cadena top-N para contar (clase 05).
> - `miapp` y nginx funcionando como servicios en tu VM (clases 10 y 12).

> 🔤 **Palabras nuevas de hoy:**
> - **journal**: el registro central de systemd; se lee con `journalctl`.
> - **gravedad** (o prioridad): cómo de importante es un mensaje (`err`, `warning`, `info`…).
> - **rotación**: renombrar, comprimir y borrar los logs viejos.
> - **rsyslog**: el programa que copia el journal en archivos de texto de `/var/log`.
> - **log estructurado**: un log con campos que tienen nombre, como en JSON.
> - **CloudWatch Logs** (AWS): un servicio que recoge los logs de muchos servidores en un solo sitio, fuera de ellos (fase 6).

## Objetivo

- Saber **dónde** están los logs de un servidor Linux y quién los escribe.
- Dominar `journalctl`: por servicio, por tiempo, por prioridad y en directo.
- Leer los logs de nginx y los de autenticación, y **reconstruir qué pasó**.
- Entender la rotación de logs y por qué en la nube se centralizan.

## Por qué importa

Los logs son la **memoria** del servidor. En un incidente, la pregunta "¿qué pasó a las 14:03?" solo se responde con logs. En AWS los enviarás a **CloudWatch Logs**, y en Kubernetes a herramientas como Loki, pero la habilidad es la misma: filtrar por fuente, tiempo y gravedad hasta encontrar la línea que explica el fallo.

## Teoría

Cuatro piezas. La idea de fondo: los logs son la **caja negra** del servidor, y aprender a buscar en ellos es aprender a reconstruir qué pasó.

### 1. Quién escribe los logs y dónde acaban

```
  procesos y servicios
      │  (stdout/stderr de los servicios, syslog, kernel)
      ▼
  systemd-journald ──────────► journal binario (/var/log/journal/)  → se lee con journalctl
      │
      └─(reenvía)──► rsyslog ──► archivos de texto en /var/log/
                                  ├── syslog     (casi todo)
                                  ├── auth.log   (logins, sudo, ssh)
                                  └── kern.log   (kernel)

  Algunas apps escriben sus propios archivos:
      nginx ──► /var/log/nginx/access.log y error.log
```

Tres caminos:
- **El journal** (`systemd-journald`): el registro que lleva el encargado de la clase 12. Recoge casi todo y se consulta con `journalctl`.
- **Los archivos de texto de `/var/log/`** (`syslog`, `auth.log`): una copia que escribe `rsyslog`, si está instalado.
- **Los archivos propios de algunas apps**, como nginx en `/var/log/nginx/`.

> ⚠️ **rsyslog es opcional.** Si en tu VM no existen `/var/log/syslog` ni `/var/log/auth.log`, esa instalación solo usa el journal (cada vez más común en imágenes mínimas y contenedores). No pasa nada: todo está en `journalctl`. En esta clase verás siempre las dos formas.

Lo que un servicio escribe por sus **mangueras 1 y 2** (clase 04) acaba en el journal sin configurar nada. Por eso tu `miapp` de la clase 12 ya tiene logs. Docker y Kubernetes funcionan igual: **la app escribe por sus mangueras y la plataforma recoge**.

**En resumen:** casi todo va al journal (`journalctl`); algunas apps, como nginx, escriben además sus propios archivos en `/var/log`.

### 2. La gravedad de cada mensaje

Cada línea del journal lleva una etiqueta de gravedad. Las tres que más usarás:

| Nivel | Significa |
|-------|-----------|
| **err** (3) | algo falló |
| **warning** (4) | aviso: todavía funciona, pero ojo |
| **info** (6) | información normal |

Por encima de `err` están `crit`, `alert` y `emerg` (el sistema está en peligro), y por debajo de `info`, `debug` (detalle para depurar). Al filtrar, `journalctl -p err` te enseña `err` **y todo lo más grave**.

**En resumen:** `-p err` te enseña los errores y todo lo más grave.

### 3. Buscar en el journal: cuatro filtros

Buscar en un log es ir **estrechando**: de qué servicio, desde cuándo, cómo de grave. Los cuatro filtros básicos se pueden combinar:

```bash
journalctl -u nginx                     # de qué SERVICIO (-u de unit)
journalctl --since "10 min ago"         # desde CUÁNDO
journalctl -p err                       # a partir de qué GRAVEDAD
journalctl -u nginx -f                  # en DIRECTO, como tail -f (Ctrl+C para salir)
```

Combinados: `journalctl -u nginx -p err --since "1 hour ago"` son «los errores de nginx de la última hora». Añade `-n 20` para ver solo las 20 últimas líneas y `--no-pager` para que no se abra el visor.

**En resumen:** estrecha con `-u` (qué servicio), `--since` (desde cuándo) y `-p` (qué gravedad).

### 4. La rotación: que los logs no llenen el disco

Los logs crecen sin parar. `logrotate`, cada día o cada semana, renombra `access.log` → `access.log.1`, comprime los viejos (`.gz`) y borra los más antiguos. Su configuración está en `/etc/logrotate.d/`. Para leer un log comprimido sin descomprimirlo: `zcat`, `zgrep` y `zless` (clase 03).

**En resumen:** logrotate renombra, comprime y borra los logs viejos para que no llenen el disco.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Tu `miapp` escribe por stdout. ¿Dónde ves lo que escribe?
2. ¿Qué comando muestra los errores de nginx desde hace 10 minutos?
3. En tu VM no existe `/var/log/auth.log`. ¿Se perdieron los intentos de login?

<details>
<summary>Comprueba</summary>

1. En el journal: `journalctl -u miapp`. 2. `journalctl -u nginx -p err --since "10 min ago"`. 3. No: esa VM no tiene rsyslog, pero todo está en el journal (`journalctl -u ssh`).
</details>

### Tu chuleta de la clase

| Comando | Qué muestra |
|---------|-------------|
| `journalctl -u nginx` · `-f` | un servicio · en directo |
| `journalctl -n 50` · `-e` | las últimas 50 líneas · salta al final |
| `journalctl --since "10 min ago"` | desde hace 10 minutos |
| `journalctl --since "2026-10-05 14:00" --until "2026-10-05 14:30"` | un intervalo (sin fecha, la hora es de hoy) |
| `journalctl -p err -b` | errores desde el último arranque |
| `journalctl -b -1` | el arranque **anterior** (útil tras un reinicio inesperado) |
| `journalctl -k` | solo mensajes del kernel |
| `journalctl _COMM=sudo` | por nombre de proceso (en Ubuntu 26.04, las sesiones SSH aparecen como `sshd-session`; es más fiable usar `-u ssh`) |
| `journalctl -o json-pretty -n 1` | en JSON: así lo leen las herramientas |
| `journalctl --no-pager` · `--disk-usage` | sin visor, para pipes · cuánto ocupa el journal |
| `logger -p user.warning "texto"` | escribir tú en el journal |

## Práctica guiada

```bash
multipass shell servidor-01
```

### 1. El paisaje

```bash
ls -lh /var/log/
sudo ls -lh /var/log/nginx/
journalctl --disk-usage
journalctl -n 20 --no-pager
```

👀 **Qué deberías ver:** los archivos de `/var/log` con su tamaño; `access.log` y `error.log` de nginx; cuánto ocupa el journal; y sus 20 últimas líneas.

### 2. Tus servicios en el journal

```bash
journalctl -u miapp -n 20 --no-pager
journalctl -u nginx --since "1 hour ago" --no-pager
journalctl -b -p warning --no-pager | tail -20
```

👀 **Qué deberías ver:** las líneas de arranque de `miapp`; lo que ha dicho nginx en la última hora (quizá nada: `-- No entries --`); y los avisos desde que encendiste la VM.

### 3. Generar tráfico y seguirlo en directo

En la VM:
```bash
sudo tail -f /var/log/nginx/access.log
```

En **tu PC** (otra terminal), con la IP de la VM (`multipass list`):
```bash
IP=$(multipass info servidor-01 | awk '/IPv4/ {print $2}')
curl -s http://$IP/ > /dev/null
curl -s http://$IP/no-existe > /dev/null
for i in $(seq 1 20); do curl -s http://$IP/pagina-$i > /dev/null; done
```

🔮 **Predice:** ¿qué IP de origen y qué código de estado verás en esas líneas?

Las líneas aparecen en directo. La IP de origen es la de tu PC **en la red virtual** de Multipass. Para el `tail` con `Ctrl+C` y analiza con lo de la clase 05:

```bash
sudo awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
sudo grep " 404 " /var/log/nginx/access.log | tail -3
```

👀 **Qué deberías ver:** un `200` y unos 21 `404` (la página que no existe y las 20 `pagina-N`), y las tres últimas líneas con 404.

### 4. Intentos de login fallidos

Desde **tu PC**, intenta entrar con usuarios que no existen (es tu propia VM, es seguro):
```bash
ssh -o ConnectTimeout=3 -o BatchMode=yes noexiste@$IP
ssh -o ConnectTimeout=3 -o BatchMode=yes admin@$IP
ssh -o ConnectTimeout=3 -o BatchMode=yes root@$IP
```

En la VM:
```bash
sudo journalctl -u ssh --since "5 min ago" --no-pager
sudo grep -E "Invalid user|Connection closed" /var/log/auth.log | tail     # solo si existe auth.log
```

Esto es lo que verías en cualquier servidor con SSH abierto a internet: **bots probando usuarios todo el día**. En la clase 15 lo blindarás.

### 5. Escribir en el log del sistema

```bash
logger -p user.warning "Prueba de aviso desde la clase 13"
journalctl -n 3 --no-pager
journalctl -p warning --since "1 min ago" --no-pager
```

👀 **Qué deberías ver:** tu mensaje `Prueba de aviso desde la clase 13` entre las últimas líneas, y también entre los avisos.

En un script, `logger` es la forma correcta de dejar rastro de lo que hace.

### 6. JSON: logs estructurados

```bash
journalctl -u nginx -n 1 -o json-pretty --no-pager
```

Cada entrada tiene campos (`_PID`, `_SYSTEMD_UNIT`, `PRIORITY`, `MESSAGE`…). Los sistemas de logs en la nube indexan esos campos para buscar rápido.

### 7. Rotación

```bash
cat /etc/logrotate.d/nginx
ls -lh /var/log/nginx/
sudo logrotate -f /etc/logrotate.d/nginx
ls -lh /var/log/nginx/
```

Aparece `access.log.1`. La directiva `postrotate` avisa a nginx para que abra el archivo nuevo. Sin ese aviso seguiría escribiendo en el viejo (clase 14).

## Rómpelo

**1. Una configuración rota:**
```bash
sudo cp /etc/nginx/sites-available/default /tmp/default.bak
echo "esto no es configuración válida" | sudo tee -a /etc/nginx/sites-available/default
sudo systemctl restart nginx
```
Investiga **solo con logs**:
```bash
systemctl status nginx --no-pager
journalctl -u nginx -n 20 --no-pager
sudo nginx -t
```
`nginx -t` comprueba la configuración **sin aplicarla** y te dice archivo y línea. Moraleja: **antes de reiniciar, `nginx -t`**. Muchos servicios tienen algo parecido (`sshd -t`, `apachectl configtest`). Restaura:
```bash
sudo cp /tmp/default.bak /etc/nginx/sites-available/default
sudo nginx -t && sudo systemctl restart nginx
```

**2. ¿Qué pasó en el arranque anterior?**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
sudo reboot
```
Después:
```bash
multipass shell servidor-01
journalctl --list-boots --no-pager
journalctl -b -1 -n 20 --no-pager
```
Si `-b -1` dice que no hay datos, el journal de esta VM **no es persistente** y se pierde al reiniciar. Compruébalo con `ls /var/log/journal`. Si el directorio no existe, el journal vive en memoria (`/run/log/journal`). Por eso, en la nube, los logs se **envían fuera** del servidor: si la instancia muere o se reinicia, la evidencia no puede morir con ella.

## Reto

En la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Muestra **solo** los errores de nginx de la última hora.

> 🧩 **Ejemplo resuelto:** los avisos de `miapp` de las dos últimas horas.
> ```bash
> journalctl -u miapp -p warning --since "2 hours ago" --no-pager
> ```
> Tres filtros juntos: el servicio (`-u`), la gravedad (`-p`) y desde cuándo (`--since`).

**Ahora tú, con huecos:** `journalctl -u ____ -p ____ --since "1 hour ago" --no-pager`

<details>
<summary>Pista</summary>

Cambia el servicio y la gravedad: la de los errores está en la pieza 2.
</details>

**2.** ¿Cuántas veces se ha usado `sudo` hoy en la VM?

> 🧩 **Ejemplo resuelto:** ¿cuántas líneas ha escrito `miapp` hoy?
> ```bash
> journalctl -u miapp --since today --no-pager | wc -l
> ```
> `--since today` filtra desde medianoche y `wc -l` cuenta las líneas.

**Ahora tú, con huecos:** `journalctl _COMM=sudo --since today --no-pager | grep -c ____`

<details>
<summary>Pista</summary>

Cada uso de `sudo` deja una línea con la palabra `COMMAND=`. Cuenta solo esas, no todas.
</details>

**3.** Haz que `miapp` escriba un mensaje en el journal al arrancar: añade con un drop-in `ExecStartPre=/bin/echo "miapp arrancando en el puerto 8080"`, reinicia y encuéntralo.

> 🧩 **Ejemplo resuelto:** el drop-in del reto 1 de la clase 12.
> ```bash
> sudo systemctl edit miapp
> #   [Service]
> #   RestartSec=10
> ```
> El mismo mecanismo: en la sección `[Service]` de un drop-in caben varias líneas.

**Ahora tú, con huecos:**
```bash
sudo systemctl edit miapp
#   [Service]
#   ____=/bin/echo "miapp arrancando en el puerto 8080"
sudo systemctl restart miapp
journalctl -u miapp -n 5 --no-pager
```

<details>
<summary>Pista</summary>

El nombre de la línea está en el enunciado: es lo que se ejecuta **antes** (*pre*) de arrancar.
</details>

**4.** (El más difícil.) ¿Qué IP ha intentado entrar por SSH más veces?

> 🧩 **Ejemplo resuelto:** sacar el último trozo de una línea, y el penúltimo.
> ```bash
> echo "uno dos tres cuatro" | awk '{print $NF}'
> echo "uno dos tres cuatro" | awk '{print $(NF-1)}'
> ```
> En `awk`, `NF` es el número de trozos de la línea: `$NF` es el último (`cuatro`) y `$(NF-1)`, el penúltimo (`tres`).

**Ahora tú, con huecos:** `sudo journalctl -u ssh --no-pager | grep "Invalid user" | awk '{print $(NF-____)}' | sort | uniq -c | sort -rn | head -3`

<details>
<summary>Pista</summary>

Mira una línea real: `… from 10.x.x.x port 51234`. Contando desde el final, la IP es la tercera palabra: el último es `$NF`, el penúltimo `$(NF-1)`, el antepenúltimo…
</details>

## Cierre

En `notas/fase-1/clase-13.md`:

1. ¿Qué diferencia hay entre el journal de systemd y los archivos de `/var/log`? ¿Cómo llegan ahí los logs de tu `miapp`? *(3 líneas. Empieza así: «El journal guarda… y se lee con… Los archivos de `/var/log`… Los logs de miapp llegan porque…»)*
2. La web dio errores ayer entre las 14:00 y las 14:30. Escribe los comandos para investigarlo con journal y con el log de nginx. *(2–3 comandos, con una línea de explicación cada uno. Empieza así: `journalctl -u nginx --since "AAAA-MM-DD 14:00" --until …`)*
3. ¿Por qué en la nube los logs se envían fuera del servidor (CloudWatch Logs)? Da dos razones. *(2 líneas. Empieza así: «Primera: si la instancia muere o se reinicia… Segunda: con muchas instancias…»)*
4. **Repaso (clase 12, sin mirar):** ¿qué diferencia hay entre `systemctl start` y `enable`? *(1–2 líneas. Empieza así: «`start` lo arranca ahora; `enable`…»)*

Después, escríbeme `examíname clase-13`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** journald recoge los logs de todo el sistema en un formato binario indexado (por unidad, PID, prioridad o tiempo), que se consulta con `journalctl`. rsyslog recibe una copia y la escribe como **texto** en `/var/log/syslog`, `auth.log`, etc. Algunas apps (nginx) escriben además sus propios archivos. `miapp` escribe en stdout/stderr y, como es un servicio de systemd, journald los captura solos: `journalctl -u miapp`.

**2.**
```bash
journalctl -u nginx --since "2026-10-04 14:00" --until "2026-10-04 14:30" --no-pager
journalctl -p err --since "2026-10-04 14:00" --until "2026-10-04 14:30" --no-pager
sudo grep "04/Oct/2026:14:[0-2]" /var/log/nginx/access.log | awk '$9 >= 500'
sudo zgrep ... /var/log/nginx/access.log.2.gz   # si ya rotó
```
Y el `error.log` de nginx en esa franja.

**3.** (a) Si la instancia muere, se termina o se reinicia sin journal persistente, los logs locales desaparecen justo cuando más falta hacen. (b) Con muchas instancias (un Auto Scaling Group), no puedes entrar en cada una: necesitas buscar en todas a la vez. Otras razones válidas: retención controlada, alarmas sobre los logs, y que un atacante que entra no puede borrar la evidencia ya enviada.

**4.** `start` arranca el servicio ahora. `enable` hace que arranque con el sistema, pero no lo arranca en ese momento.

**Reto:**
```bash
journalctl -u nginx -p err --since "1 hour ago" --no-pager      # 1 (y: sudo tail /var/log/nginx/error.log)
journalctl _COMM=sudo --since today --no-pager | grep -c COMMAND   # 2
sudo journalctl -u ssh --no-pager | grep "Invalid user" | awk '{print $(NF-2)}' | sort | uniq -c | sort -rn | head -3   # 4
```
En la última, la posición del campo de la IP depende del formato del mensaje. Comprueba con una línea real cuál es antes de confiar en el resultado (lección de la clase 05).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| log level / severity | nivel de gravedad |
| log rotation | rotación de logs |
| structured logging | logs estructurados |
| centralized logging | logs centralizados |
| to tail a log | seguir un log |

🎙️ *"Logs should be shipped off the instance to a central place like CloudWatch Logs, because when an instance dies its local logs die with it."*

## Siguiente

[Clase 14 — Recursos: CPU, memoria y disco](clase-14-recursos.md)
