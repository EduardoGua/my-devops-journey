# Clase 13 — Logs y journalctl

**Dónde:** VM `servidor-01` (y tu PC para generar tráfico) · **Tiempo:** 75 min · **Bloque:** B. Administrar un servidor

## Objetivo

- Saber **dónde** están los logs de un servidor Linux y quién los escribe.
- Dominar `journalctl`: por servicio, por tiempo, por prioridad y en directo.
- Leer los logs de nginx y los de autenticación, y **reconstruir qué pasó**.
- Entender la rotación de logs y por qué en la nube se centralizan.

## Por qué importa

Los logs son la **memoria** del servidor. En un incidente, la pregunta "¿qué pasó a las 14:03?" solo se responde con logs. En AWS los enviarás a **CloudWatch Logs**, y en Kubernetes a herramientas como Loki, pero la habilidad es la misma: filtrar por fuente, tiempo y gravedad hasta encontrar la línea que explica el fallo.

## Teoría

### Dos sistemas conviviendo

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

> ⚠️ **rsyslog es opcional.** Si en tu VM no existen `/var/log/syslog` ni `/var/log/auth.log`, es que esa instalación solo usa el journal (cada vez más común en imágenes mínimas y contenedores). No pasa nada: todo está en `journalctl`. En esta clase verás siempre las dos formas.

Lo que un servicio de systemd escribe en **stdout/stderr** acaba en el journal sin configurar nada. Por eso tu `miapp` de la clase 12 ya tiene logs. Es la misma idea que los logs de Docker y Kubernetes: **la app escribe a stdout y la plataforma los recoge.**

### Niveles de gravedad (prioridad syslog)

| Nº | Nombre | Uso |
|----|--------|-----|
| 0–2 | emerg, alert, crit | el sistema está en peligro |
| 3 | **err** | errores |
| 4 | **warning** | avisos |
| 5–6 | notice, info | información normal |
| 7 | debug | detalle para depurar |

`journalctl -p err` muestra la prioridad `err` **y todas las más graves**.

### journalctl esencial

| Comando | Qué muestra |
|---------|-------------|
| `journalctl -u nginx` | un servicio |
| `journalctl -u nginx -f` | en directo (como `tail -f`) |
| `journalctl -n 50` | las últimas 50 líneas |
| `journalctl -e` | salta al final |
| `journalctl --since "10 min ago"` | desde hace 10 minutos |
| `journalctl --since "2026-10-05 14:00" --until "2026-10-05 14:30"` | un intervalo |
| `journalctl -p err -b` | errores desde el último arranque |
| `journalctl -b -1` | el arranque **anterior** (útil tras un reinicio inesperado) |
| `journalctl -k` | solo mensajes del kernel |
| `journalctl _COMM=sudo` | por nombre de proceso (en Ubuntu 26.04, las sesiones SSH aparecen como `sshd-session`; es más fiable usar `-u ssh`) |
| `journalctl -o json-pretty -n 1` | en JSON: así lo consumen las herramientas |
| `journalctl --no-pager` | sin `less`, para pipes y scripts |
| `journalctl --disk-usage` | cuánto ocupa el journal |

### Rotación

Los logs crecen sin parar. `logrotate` (de forma diaria o semanal) renombra `access.log` → `access.log.1`, comprime los viejos (`.gz`) y borra los más antiguos. La configuración está en `/etc/logrotate.d/`. Para leer un log comprimido: `zcat`, `zgrep`, `zless`.

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

### 2. Tus servicios en el journal

```bash
journalctl -u miapp -n 20 --no-pager
journalctl -u nginx --since "1 hour ago" --no-pager
journalctl -b -p warning --no-pager | tail -20
```

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

1. ¿Cuántas veces se ha usado `sudo` hoy en la VM? (`journalctl _COMM=sudo --since today`)
2. Muestra **solo** los errores de nginx de la última hora.
3. Haz que `miapp` escriba algo en el journal al arrancar: añade con un drop-in `ExecStartPre=/bin/echo "miapp arrancando en el puerto 8080"`, reinicia y encuéntralo con `journalctl -u miapp`.
4. ¿Qué IP ha intentado entrar por SSH más veces? Usa el journal (`journalctl -u ssh`) o `/var/log/auth.log` si existe. (Pipeline de la clase 05.)

## Cierre

En `notas/fase-1/clase-13.md`:

1. ¿Qué diferencia hay entre el journal de systemd y los archivos de `/var/log`? ¿Cómo llegan ahí los logs de tu `miapp`?
2. La web dio errores ayer entre las 14:00 y las 14:30. Escribe los comandos para investigarlo con journal y con el log de nginx.
3. ¿Por qué en la nube los logs se envían fuera del servidor (CloudWatch Logs)? Da dos razones.
4. **Repaso (clase 12, sin mirar):** ¿qué diferencia hay entre `systemctl start` y `enable`?

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
journalctl _COMM=sudo --since today --no-pager | grep -c COMMAND
journalctl -u nginx -p err --since "1 hour ago" --no-pager      # y: sudo tail /var/log/nginx/error.log
sudo journalctl -u ssh --no-pager | grep "Invalid user" | awk '{print $(NF-2)}' | sort | uniq -c | sort -rn | head -3
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
