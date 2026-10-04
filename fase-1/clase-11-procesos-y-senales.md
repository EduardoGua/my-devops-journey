# Clase 11 — Procesos y señales

**Dónde:** VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** B. Administrar un servidor

## Objetivo

- Entender qué es un proceso: PID, padre, usuario, estado.
- Inspeccionarlos con `ps`, `pstree`, `top`/`htop` y `/proc`.
- Enviar **señales** con criterio: por qué primero `SIGTERM` y solo después `SIGKILL`.
- Manejar trabajos en primer y segundo plano: `&`, `Ctrl+Z`, `bg`, `fg`, `nohup`.

## Por qué importa

"La CPU está al 100 %", "la app no responde", "hay que reiniciar el servicio sin cortar a los usuarios". Todo eso son procesos y señales. Cuando Kubernetes o ECS paran un contenedor, le envían `SIGTERM`, esperan un tiempo de gracia y después envían `SIGKILL`. Si tu app no gestiona `SIGTERM`, pierde peticiones en cada despliegue.

## Teoría

### Programa frente a proceso

- **Programa**: un archivo en disco (`/usr/sbin/nginx`). No hace nada por sí solo.
- **Proceso**: un programa **en ejecución**, con memoria, un número único (**PID**), un usuario dueño y un **padre** (PPID). Un mismo programa puede tener muchos procesos a la vez.

Todos descienden del **PID 1** (`systemd`), el primer proceso que arranca el kernel:

```
systemd (1)
├── sshd ──── sshd ──── bash ──── ps        ← tu sesión
├── nginx (master, root) ─┬─ nginx (worker, www-data)
│                         └─ nginx (worker, www-data)
└── cron
```

### Estados (columna `STAT` de `ps`)

| Estado | Significado |
|--------|-------------|
| `R` | Running: usando CPU o listo para usarla |
| `S` | Sleeping: esperando algo (red, teclado, un temporizador). Lo más común |
| `D` | Espera **ininterrumpible**, casi siempre de disco o red (NFS). Ni `kill -9` lo mata hasta que vuelve |
| `T` | Detenido (`Ctrl+Z`, `SIGSTOP`) |
| `Z` | Zombie: terminó, pero su padre no ha recogido su código de salida |

### Señales

Una señal es un aviso del kernel a un proceso. El proceso puede **atraparla** (`trap`) y reaccionar, salvo `SIGKILL` y `SIGSTOP`.

| Señal | Nº | Uso |
|-------|----|-----|
| `SIGTERM` | 15 | "Termina, por favor." El proceso puede cerrar conexiones y guardar datos. **Es la que envía `kill` por defecto** |
| `SIGINT` | 2 | La que envía `Ctrl+C` |
| `SIGHUP` | 1 | Originalmente "se colgó la terminal". Muchos demonios la usan para **recargar la configuración** |
| `SIGKILL` | 9 | Muerte inmediata, decidida por el kernel. No se puede atrapar: sin limpieza |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | Pausar / reanudar |

**Orden correcto:** `kill PID` (TERM) → esperar unos segundos → solo si sigue vivo, `kill -9 PID`.

### Comandos

| Comando | Para qué |
|---------|----------|
| `ps aux` | Todos los procesos (usuario, PID, %CPU, %MEM, estado, comando) |
| `ps -ef --forest` | Con PPID y en árbol |
| `pstree -p` | El árbol con PIDs |
| `pgrep -a nombre` | Busca PIDs por nombre |
| `top` / `htop` | Monitor en vivo (`q` sale; en htop `F6` ordena y `F9` envía señales) |
| `kill [-SEÑAL] PID` | Envía una señal |
| `pkill nombre` | Envía una señal por nombre (¡cuidado con lo que coincide!) |
| `cmd &` | Lanza en segundo plano |
| `jobs`, `fg %1`, `bg %1` | Gestiona trabajos de este shell |
| `nohup cmd &` | Sobrevive al cierre de la terminal (ignora SIGHUP) |
| `nice -n 10 cmd` / `renice` | Baja o sube la prioridad de CPU |

## Práctica guiada

```bash
multipass shell servidor-01
```

### 1. Observar

```bash
echo "Mi shell es el PID $$"
ps -f
ps aux | head
ps aux | wc -l
pstree -p | head -20
ps -ef --forest | grep -A3 [n]ginx
```

(El truco `[n]ginx` evita que `grep` se encuentre a sí mismo en la lista.)

🔮 **Predice:** ¿con qué usuario corre el proceso nginx *master* y con cuál los *workers*? ¿Por qué crees que es así?

```bash
ps -o user,pid,ppid,cmd -C nginx
```

El master corre como **root** porque necesita abrir el puerto 80 (los puertos < 1024 requieren privilegios). Los workers, que atienden a los clientes, corren como **www-data**. Si un atacante compromete un worker, no es root. Es mínimo privilegio aplicado a procesos.

### 2. `/proc`: el proceso por dentro

```bash
PID=$(pgrep -o nginx)          # -o: el más antiguo, el master
sudo ls /proc/$PID
sudo cat /proc/$PID/status | head -10
sudo ls -l /proc/$PID/cwd /proc/$PID/exe
cat /proc/loadavg
```

### 3. Un proceso que devora CPU

```bash
yes > /dev/null &
jobs
top
```

En `top`: mira `%CPU` de `yes`, pulsa `P` (ordenar por CPU) y `q` para salir. Después:

```bash
kill %1                 # %1 = el trabajo 1 de este shell
jobs
```

### 4. TERM frente a KILL

Crea un programa que se despide con educación:

```bash
cat > ~/educado.sh <<'EOF'
#!/bin/bash
trap 'echo "[$$] recibí SIGTERM: cierro conexiones y guardo..."; sleep 2; echo "[$$] listo, adiós"; exit 0' TERM
echo "[$$] trabajando. Mi PID es $$"
while true; do sleep 1; done
EOF
chmod +x ~/educado.sh
~/educado.sh &
```

🔮 **Predice** qué mensajes verás con cada señal:

```bash
kill %1                 # SIGTERM
```

Espera a que termine y lánzalo otra vez:

```bash
~/educado.sh &
kill -9 %1              # SIGKILL
jobs
```

Con `SIGKILL` no hubo despedida: el kernel lo eliminó sin avisar. En una base de datos, eso puede significar datos a medio escribir.

### 5. Segundo plano y Ctrl+Z

```bash
sleep 300
```
Pulsa `Ctrl+Z` (lo **detienes**, no lo matas).
```bash
jobs                    # Stopped
bg %1                   # sigue en segundo plano
jobs                    # Running
fg %1                   # vuelve al primer plano
```
`Ctrl+C` para terminarlo.

### 6. SIGHUP para recargar: nginx

```bash
ps -o pid,cmd -C nginx
sudo kill -HUP $(pgrep -o nginx)
ps -o pid,cmd -C nginx
```

🔮 **Predice:** ¿cambiará el PID del master? ¿Y los de los workers?

El master sigue con el mismo PID, pero los **workers son nuevos**: nginx releyó la configuración y renovó sus workers **sin cortar el servicio**. Eso es lo que hace por debajo `systemctl reload nginx` (clase 12).

## Rómpelo

**1. Matar un worker:**
```bash
ps -o pid,cmd -C nginx
sudo kill -9 <PID de un worker>
ps -o pid,cmd -C nginx
curl -s -o /dev/null -w "%{http_code}\n" localhost
```
El master detecta la muerte del worker y **lanza otro**. La web sigue respondiendo. Es *auto-reparación* a pequeña escala; Kubernetes hace lo mismo con contenedores.

**2. Una conexión que se corta mata los trabajos:**
Abre una terminal **nueva** en tu PC, entra con `multipass shell servidor-01` y ejecuta:
```bash
sleep 1000 &
nohup sleep 2000 > /dev/null 2>&1 &
```
Ahora **cierra esa ventana con la X**, sin escribir `exit`. Es lo mismo que si se cae tu wifi en mitad de una sesión SSH. Desde tu otra sesión en la VM:
```bash
pgrep -a sleep
```
Solo sobrevive el de `nohup`. Al cortarse la conexión, bash recibe `SIGHUP` y lo reenvía a todos sus trabajos; `nohup` hace que el proceso ignore esa señal. (Con un `exit` limpio el resultado puede ser otro, porque depende de la configuración del shell. No dependas de eso.)

Pero `nohup` es un parche: lo profesional es un **servicio de systemd**, que reinicia el proceso si muere y arranca con la máquina (clase 12). Limpia con `pkill -f "sleep 2000"`.

**3. Pausar un proceso que alguien necesita:**
```bash
sudo kill -STOP $(pgrep -o nginx)
curl -s -m 3 localhost || echo "sin respuesta"
sudo kill -CONT $(pgrep -o nginx)
curl -s -o /dev/null -w "%{http_code}\n" localhost
```
Aunque el master esté parado, los workers suelen seguir atendiendo, y `curl` puede responder `200`. Cada servicio se comporta distinto ante una señal: **comprueba siempre el efecto** y no lo supongas.

## Reto

1. ¿Qué proceso tiene el PID 1 y cuánto tiempo lleva vivo? (`ps -o pid,etime,cmd -p 1`)
2. Lanza tres `sleep 500 &` y termínalos **todos** con un solo comando, sin afectar a otros `sleep` que pudiera haber en el sistema. (Pista: `pkill -f "sleep 500"`.) ¿Qué riesgo tiene `pkill` en un servidor real?
3. Lanza `yes > /dev/null &` con `nice -n 19` y otro sin `nice`. Observa en `top` el `NI` y el `%CPU` de cada uno. ¿Qué pasa? Termina ambos.
4. Encuentra los 5 procesos que más memoria usan: `ps aux --sort=-%mem | head -6`.

## Cierre

En `notas/fase-1/clase-11.md`:

1. ¿Qué diferencia hay entre programa y proceso? Usa nginx como ejemplo.
2. ¿Por qué se envía primero `SIGTERM` y solo después `SIGKILL`? ¿Qué pasa en Kubernetes o ECS al desplegar una versión nueva?
3. ¿Por qué nginx usa un master como root y workers como www-data?
4. **Repaso (clase 10, sin mirar):** ¿qué diferencia hay entre `apt remove` y `apt purge`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El programa es el archivo en disco (`/usr/sbin/nginx`). Un proceso es una instancia en ejecución de ese programa, con PID, memoria, usuario y padre. Del mismo binario de nginx corren varios procesos: un master y varios workers, cada uno con su PID.

**2.** `SIGTERM` permite que el proceso termine **ordenadamente**: acabar las peticiones en curso, cerrar conexiones, vaciar buffers y guardar estado. `SIGKILL` lo mata en el acto, sin limpieza, y puede corromper datos o cortar a usuarios. En Kubernetes y ECS, al parar un contenedor se envía `SIGTERM`, se espera un *grace period* (30 s por defecto en Kubernetes) y, si sigue vivo, se envía `SIGKILL`. Una app que ignora `SIGTERM` corta peticiones en cada despliegue.

**3.** El master necesita root para abrir el puerto 80 (los puertos < 1024 son privilegiados) y leer la configuración. Los workers procesan datos que llegan de internet, potencialmente maliciosos, así que corren sin privilegios. Si alguien explota un fallo en un worker, obtiene los permisos de `www-data`, no de root. Es mínimo privilegio.

**4.** `remove` desinstala el programa, pero deja sus archivos de configuración en `/etc`. `purge` borra también la configuración.

**Reto:** 1) `systemd`; el `etime` es el tiempo desde el arranque. 2) `pkill -f "sleep 500"`. Riesgo: `pkill` busca por patrón y puede coincidir con procesos que no querías (un `pkill python` mata **todos** los Python de la máquina, incluidas otras apps). Antes se comprueba con `pgrep -a` qué coincide. 3) El proceso con `nice 19` recibe mucha menos CPU cuando compiten: la prioridad solo importa cuando hay escasez. `kill %1 %2` o `pkill yes`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| process ID (PID) | identificador de proceso |
| parent process | proceso padre |
| signal | señal |
| graceful shutdown | apagado ordenado |
| foreground / background | primer / segundo plano |
| zombie process | proceso zombi |

🎙️ *"I always send SIGTERM first so the app can shut down gracefully. SIGKILL is the last resort, because the process can't clean up."*

## Siguiente

[Clase 12 — systemd: servicios](clase-12-systemd.md)
