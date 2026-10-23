# Clase 11 — Procesos y señales

**Dónde:** VM `servidor-01` · **Tiempo:** 75 min · **Bloque:** B. Administrar un servidor

> 💡 **La idea de hoy:** un **programa** es un archivo en el disco y un **proceso** es ese programa *mientras se ejecuta* (como una receta escrita frente al plato que se está cocinando), con su número (PID), su dueño y su padre. Para hablar con un proceso le envías **señales**: primero se le pide por favor que termine (`SIGTERM`) y solo si no hace caso se le fuerza (`SIGKILL`).

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - El paso 4 de «Qué pasa cuando pulsas Enter»: el kernel crea un proceso (clase 01, pieza 4).
> - `/proc` lo genera el kernel cuando lo lees: sus archivos no están en el disco (clase 02).
> - nginx funciona en tu VM desde la clase 10.

> 🔤 **Palabras nuevas de hoy:**
> - **proceso**: un programa en ejecución.
> - **PID**: el número único de cada proceso; **PPID**, el de su padre.
> - **señal**: un aviso del kernel a un proceso (`SIGTERM`, `SIGKILL`…).
> - **primer / segundo plano**: ocupando tu terminal, o funcionando por detrás mientras la usas.
> - **trabajo** (*job*): un proceso que lanzaste desde esta terminal; `jobs` los numera ([1], [2]…) y `%1` es el número 1.
> - **master / worker**: en nginx, el proceso jefe y los que atienden a los clientes.
> - **Kubernetes / ECS**: plataformas que ejecutan aplicaciones en contenedores y las sustituyen por versiones nuevas sin que lo hagas a mano (fases 5, 6 y 9).

## Objetivo

- Entender qué es un proceso: PID, padre, usuario, estado.
- Inspeccionarlos con `ps`, `pstree`, `top`/`htop` y `/proc`.
- Enviar **señales** con criterio: por qué primero `SIGTERM` y solo después `SIGKILL`.
- Manejar trabajos en primer y segundo plano: `&`, `Ctrl+Z`, `bg`, `fg`, `nohup`.

## Por qué importa

"La CPU está al 100 %", "la app no responde", "hay que reiniciar el servicio sin cortar a los usuarios". Todo eso son procesos y señales. Cuando Kubernetes o ECS paran un contenedor, le envían `SIGTERM`, esperan un tiempo de gracia y después envían `SIGKILL`. Si tu app no gestiona `SIGTERM`, pierde peticiones en cada despliegue.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida en el servidor; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 30 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

Todo se hace dentro de la VM:

```bash
multipass shell servidor-01
```

## Las piezas

### Pieza 1 — Programa y proceso

- Un **programa** es un archivo guardado en el disco (`/usr/sbin/nginx`). Por sí solo no hace nada.
- Un **proceso** es ese programa **mientras se ejecuta**: tiene su número (el **PID**), un dueño (el usuario que lo lanzó) y un **padre** (el proceso que lo lanzó, su PPID). Del mismo programa pueden estar corriendo muchos procesos a la vez.

Todos los procesos descienden del **PID 1** (`systemd`), el primero que arranca el kernel:

```
systemd (1)
├── sshd ── sshd-session ── bash ── ps      ← tu sesión
├── nginx (master, root) ─┬─ nginx (worker, www-data)
│                         └─ nginx (worker, www-data)
└── cron
```

> 🔁 **Vuelve a la clase 01.** El paso 4 de «Qué pasa cuando pulsas Enter» era «el kernel crea un proceso nuevo». Ese proceso es **hijo de tu shell**. Por dentro, el shell se **clona** (`fork`) y el clon se **convierte** en el programa que pediste (`exec`). Por eso el hijo hereda las variables de entorno de la clase 07.

**Pruébalo:**

```bash
echo "Mi shell es el PID $$"
sleep 30 &
ps -o pid,ppid,cmd
```

👀 **Qué deberías ver:** el PID de tu shell y, en la lista, el `sleep 30` con un **PPID igual a ese número**: el `sleep` es hijo de tu shell. (El `&` lo deja corriendo mientras sigues; lo verás en la pieza 4. En 30 segundos termina solo.)

✋ **Sin mirar:** ¿cuántos procesos pueden estar ejecutando el mismo programa a la vez?

<details>
<summary>Comprueba</summary>

Muchos: cada vez que se ejecuta el programa nace un proceso nuevo. nginx, por ejemplo, tiene un *master* y varios *workers*: lo verás en la pieza 2.
</details>

**En resumen:** un programa es el archivo; un proceso, ese programa ejecutándose, con su PID y su padre.

### Pieza 2 — Ver los procesos

Tres formas de mirarlos:

```bash
ps aux          # la lista de todos los procesos, una foto fija
pstree -p       # el árbol de familia, con los PIDs
top             # en directo, ordenado por lo que más CPU gasta (q para salir)
```

En la columna `STAT` de `ps` verás sobre todo dos estados: **R** (*running*, ejecutándose ahora) y **S** (*sleeping*, esperando algo: que llegue una petición, que pulses una tecla). Lo normal es que casi todo esté en S. Los demás estados están en la chuleta.

**Pruébalo:**

```bash
ps aux | head
ps aux | wc -l
pstree -p | head -20
ps -ef --forest | grep -A3 '[n]ginx'    # todos, en árbol; -A3: y las 3 líneas siguientes
```

👀 **Qué deberías ver:** las primeras líneas de la lista completa; cuántos hay; el árbol que empieza en `systemd(1)`; y los procesos de nginx colgando de su master.

(El truco `[n]ginx` evita que `grep` se encuentre a sí mismo en la lista.)

**En resumen:** `ps aux` es una foto fija, `pstree` el árbol de familia y `top` el directo.

### Pieza 3 — El proceso por dentro: su usuario y `/proc`

Cada proceso tiene un dueño, y los de un mismo programa no siempre tienen el mismo.

🔮 **Predice:** ¿con qué usuario corre el proceso nginx *master* y con cuál los *workers*? ¿Por qué crees que es así?

```bash
ps -o user,pid,ppid,cmd -C nginx     # -C nginx: solo los procesos de ese programa
```

El master corre como **root** porque necesita abrir el puerto 80 (los puertos < 1024 requieren privilegios). Los workers, que atienden a los clientes, corren como **www-data**. Si un atacante compromete un worker, no es root. Es mínimo privilegio aplicado a procesos.

Para mirar un proceso por dentro, el kernel muestra cada uno como una carpeta, `/proc/<PID>`, llena de archivos que no están en el disco: los genera al leerlos. Ahí están su estado, su programa, su carpeta de trabajo y mucho más.

**Pruébalo** con el master:

```bash
PID=$(pgrep -o nginx)          # -o: el más antiguo, el master
sudo ls /proc/$PID
sudo cat /proc/$PID/status | head -10
sudo ls -l /proc/$PID/cwd /proc/$PID/exe
```

👀 **Qué deberías ver:** la carpeta del proceso en `/proc`; su estado (`State:`); y su carpeta de trabajo y su programa (dos flechas `->`).

**En resumen:** el master de nginx corre como root y los workers como www-data. Cada proceso es una carpeta en `/proc/<PID>`: ahí lees su estado sin ninguna herramienta extra.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Para salir de la VM, `exit`; mañana vuelves con `multipass shell servidor-01` y sigues en la pieza 4.

### Pieza 4 — Primer y segundo plano

Normalmente, un comando ocupa tu terminal hasta que termina: está en **primer plano**. Puedes mandarlo a **segundo plano** para seguir usando la terminal mientras se ejecuta.

Para leer (lo pruebas justo debajo):

```bash
sleep 300 &       # el & lo lanza directamente en segundo plano
jobs              # tus trabajos en esta terminal: [1], [2]...
fg %1             # traer el trabajo 1 al primer plano
```

`Ctrl+Z` **pausa** el que está en primer plano (no lo mata) y `bg %1` lo deja seguir en segundo plano. `nohup comando &` hace que siga vivo aunque cierres la terminal.

**Pruébalo con un proceso que devora CPU:**

```bash
yes > /dev/null &
jobs
top
```

En `top`: mira `%CPU` de `yes`, pulsa `P` (ordenar por CPU) y `q` para salir. Después termínalo (`kill`, lo verás a fondo en la pieza 5):

```bash
kill %1                 # %1 = el trabajo 1 de este shell
jobs
```

👀 **Qué deberías ver:** en `top`, `yes` arriba del todo, cerca del 100 % de CPU; después del `kill`, un aviso `Terminated` y `jobs` vacío.

**Ahora pausa y reanuda:**

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

👀 **Qué deberías ver:** primero `Stopped`, después `Running` y, con `fg`, el `sleep` vuelve a ocupar la terminal. `Ctrl+C` para terminarlo.

✋ **Sin mirar:** ¿qué hace `Ctrl+Z`: termina el proceso o lo pausa?

<details>
<summary>Comprueba</summary>

Lo **pausa**: sigue existiendo, en estado `T`.
</details>

**En resumen:** `&` lo manda al segundo plano, `jobs` los lista, `fg` trae uno de vuelta y `Ctrl+Z` pausa el que tienes delante.

### Pieza 5 — Señales

Una **señal** es un aviso que el kernel entrega a un proceso. Tres que usarás siempre:

| Señal | Cómo se envía | Qué le pide al proceso |
|-------|---------------|------------------------|
| `SIGTERM` (15) | `kill PID` | que **termine**: puede acabar lo que está haciendo, guardar y cerrar con orden |
| `SIGINT` (2) | `Ctrl+C` | lo mismo, desde el teclado |
| `SIGKILL` (9) | `kill -9 PID` | nada: el kernel lo **mata en el acto**. No puede guardar ni cerrar nada |

El proceso puede **atrapar** las señales y reaccionar (despedirse, guardar datos)… todas menos `SIGKILL`, que no se puede atrapar. Por eso el orden correcto es: **`kill PID` → esperar unos segundos → solo si sigue vivo, `kill -9 PID`**.

**Pruébalo: TERM frente a KILL.** Crea un programa que se despide con educación:

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

`trap '…' TERM` dice qué hacer al recibir SIGTERM; `while true; do sleep 1; done` mantiene vivo el script (los bucles, en la clase 18).

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

👀 **Qué deberías ver:** con `SIGTERM`, las dos líneas de despedida (`recibí SIGTERM…` y `listo, adiós`). Con `SIGKILL`, ninguna: el kernel lo eliminó sin avisar, y `jobs` dice `Killed`. En una base de datos, eso puede significar datos a medio escribir.

✋ **Sin mirar:** una app no responde. ¿Qué señal envías primero y cuál solo como último recurso?

<details>
<summary>Comprueba</summary>

Primero `SIGTERM` (`kill PID`); `SIGKILL` (`kill -9`) solo si no hace caso.
</details>

**En resumen:** primero `kill PID` (SIGTERM); solo si no termina, `kill -9 PID` (SIGKILL).

### Pieza 6 — SIGHUP: recargar sin cortar

Una cuarta señal que usarás con servicios: `SIGHUP` (1), que se envía con `kill -HUP PID`. Muchos servicios la entienden como «**vuelve a leer tu configuración**» (recargar), sin terminar.

🔮 **Predice:** después de enviarle `SIGHUP` al master de nginx, ¿cambiará su PID? ¿Y los de los workers?

**Pruébalo:**

```bash
ps -o pid,cmd -C nginx
sudo kill -HUP $(pgrep -o nginx)
ps -o pid,cmd -C nginx
```

👀 **Qué deberías ver:** el master sigue con el mismo PID, pero los **workers son nuevos**: nginx releyó la configuración y renovó sus workers **sin cortar el servicio**. Eso es lo que hace por debajo `systemctl reload nginx` (clase 12).

**En resumen:** `kill -HUP PID` pide a un servicio que vuelva a leer su configuración; nginx lo hace sin cortar el servicio.

## Tu chuleta de la clase

| Comando | Para qué |
|---------|----------|
| `ps aux` · `ps -ef --forest` | todos los procesos · con su padre (PPID) y en árbol |
| `pstree -p` · `pgrep -a nombre` | el árbol con PIDs · buscar PIDs por nombre |
| `top` / `htop` | monitor en vivo (`q` sale; en `top`, `P` ordena por CPU; en `htop`, `F9` envía señales) |
| `kill PID` · `kill -9 PID` · `kill -HUP PID` | SIGTERM · SIGKILL · SIGHUP |
| `pkill nombre` | envía la señal por nombre (¡mira antes con `pgrep -a` qué coincide!) |
| `cmd &` · `jobs` · `fg %1` · `bg %1` | segundo plano · ver · traer · reanudar en segundo plano |
| `nohup cmd &` | sobrevive al cierre de la terminal |
| `nice -n 10 cmd` · `renice` | bajar o subir la prioridad de CPU |

| Estado (`STAT`) | Significa |
|-----------------|-----------|
| `R` | *Running*: usando CPU o listo para usarla |
| `S` | *Sleeping*: esperando algo. Lo más común |
| `D` | Espera **ininterrumpible**, casi siempre de disco o red. Ni `kill -9` lo mata hasta que vuelve |
| `T` | Detenido (`Ctrl+Z`, `SIGSTOP`) |
| `Z` | Zombi: terminó, pero su padre no ha recogido su código de salida |

`SIGSTOP` (19) y `SIGCONT` (18) pausan y reanudan un proceso, como `Ctrl+Z` y `bg`.

## Rómpelo

**1. Matar un worker:**
```bash
ps -o pid,cmd -C nginx
sudo kill -9 <PID de un worker>
ps -o pid,cmd -C nginx
curl -s -o /dev/null -w "%{http_code}\n" localhost    # solo imprime el código de estado HTTP (200 = bien, clase 05)
```
El master detecta la muerte del worker y **lanza otro**. La web sigue respondiendo. Es *auto-reparación* a pequeña escala; Kubernetes hace lo mismo con contenedores.

**2. Una conexión que se corta mata los trabajos:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.

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

En la VM. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Qué proceso tiene el PID 1 y cuánto tiempo lleva vivo?

> 🧩 **Ejemplo resuelto:** ¿cuánto lleva vivo tu propio shell?
> ```bash
> ps -o pid,etime,cmd -p $$
> ```
> `$$` es el PID de tu shell; `-o pid,etime,cmd` elige las columnas: el PID, el tiempo que lleva vivo (`etime`) y el comando.

**Ahora tú, con huecos:** `ps -o pid,etime,cmd -p ____`

<details>
<summary>Pista</summary>

El PID que pide el reto está en el enunciado.
</details>

**2.** Lanza tres `sleep 500 &` y termínalos **todos** con un solo comando, sin afectar a otros `sleep` que pudiera haber. ¿Qué riesgo tiene `pkill` en un servidor real?

> 🧩 **Ejemplo resuelto:** con dos `sleep 400`.
> ```bash
> sleep 400 &
> sleep 400 &
> pgrep -af "sleep 400"
> pkill -f "sleep 400"
> ```
> `pgrep -af` enseña **antes** qué coincidiría; `pkill -f` manda la señal a todos los que coinciden con ese texto.

**Ahora tú, con huecos:**
```bash
pgrep -af "____"
pkill -f "____"
```

<details>
<summary>Pista</summary>

Para el riesgo: ¿qué pasaría con `pkill python` en un servidor con varias aplicaciones en Python?
</details>

**3.** Lanza dos `yes > /dev/null &`, uno con `nice -n 19` delante y otro sin él. En `top`, compara su `NI` y su `%CPU`. ¿Qué pasa? Termina los dos.

> 🧩 **Ejemplo resuelto:** lanzar un solo `yes` con la prioridad más baja y comprobarla.
> ```bash
> nice -n 19 yes > /dev/null &
> ps -o pid,ni,cmd -C yes
> kill %1
> ```
> La columna `NI` sale con 19: la prioridad más baja. Solo se nota cuando dos procesos compiten por la CPU.

**Ahora tú, con huecos:**
```bash
____ -n 19 yes > /dev/null &
yes > /dev/null &
top                  # mira las columnas NI y %CPU; sal con q
pkill ____
```

<details>
<summary>Pista</summary>

El primer hueco es el comando que baja la prioridad. El último, el nombre del programa que quieres terminar.
</details>

**4.** Encuentra los 5 procesos que más memoria usan.

> 🧩 **Ejemplo resuelto:** los 3 procesos que más CPU usan.
> ```bash
> ps aux --sort=-%cpu | head -4
> ```
> `--sort=-%cpu` ordena por CPU, de mayor a menor (el `-` es «al revés»). `head -4` porque la primera línea es la cabecera, como el `total` de la clase 04.

**Ahora tú, con huecos:** `ps aux --sort=-%____ | head -____`

<details>
<summary>Pista</summary>

En `ps aux`, la columna de la memoria se llama `%MEM`.
</details>

## Cierre

En `notas/fase-1/clase-11.md`:

1. ¿Qué diferencia hay entre programa y proceso? Usa nginx como ejemplo. *(2–3 líneas. Empieza así: «El programa es… El proceso es… De nginx corren…»)*
2. ¿Por qué se envía primero `SIGTERM` y solo después `SIGKILL`? ¿Qué pasa en Kubernetes o ECS al desplegar una versión nueva? *(3 líneas. Empieza así: «SIGTERM deja que la app… SIGKILL… En Kubernetes, al desplegar, primero… y si no…»)*
3. ¿Por qué nginx usa un master como root y workers como www-data? *(2 líneas. Empieza así: «El master necesita ser root para… Los workers corren como www-data porque…»)*
4. **Repaso (clase 10, sin mirar):** ¿qué diferencia hay entre `apt remove` y `apt purge`? *(1–2 líneas. Empieza así: «`remove` desinstala pero deja… `purge`…»)*

Después, escríbeme `examíname clase-11`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** El programa es el archivo en disco (`/usr/sbin/nginx`). Un proceso es una instancia en ejecución de ese programa, con PID, memoria, usuario y padre. Del mismo binario de nginx corren varios procesos: un master y varios workers, cada uno con su PID.

**2.** `SIGTERM` permite que el proceso termine **ordenadamente**: acabar las peticiones en curso, cerrar conexiones, vaciar buffers y guardar estado. `SIGKILL` lo mata en el acto, sin limpieza, y puede corromper datos o cortar a usuarios. En Kubernetes y ECS, al parar un contenedor se envía `SIGTERM`, se espera un *grace period* (30 s por defecto en Kubernetes) y, si sigue vivo, se envía `SIGKILL`. Una app que ignora `SIGTERM` corta peticiones en cada despliegue.

**3.** El master necesita root para abrir el puerto 80 (los puertos < 1024 son privilegiados) y leer la configuración. Los workers procesan datos que llegan de internet, potencialmente maliciosos, así que corren sin privilegios. Si alguien explota un fallo en un worker, obtiene los permisos de `www-data`, no de root. Es mínimo privilegio.

**4.** `remove` desinstala el programa, pero deja sus archivos de configuración en `/etc`. `purge` borra también la configuración.

**Reto:** 1) `systemd`; el `etime` es el tiempo desde el arranque. 2) `pkill -f "sleep 500"`. Riesgo: `pkill` busca por patrón y puede coincidir con procesos que no querías (un `pkill python` mata **todos** los Python de la máquina, incluidas otras apps). Con `-f` busca en la línea de comandos completa, y `sudo pkill -f patrón` puede llegar a matar al propio `sudo`, cuya línea también contiene el patrón. Antes se comprueba con `pgrep -af patrón` qué coincide, y si hay duda, se mata por PID. 3) El proceso con `nice 19` recibe mucha menos CPU cuando compiten: la prioridad solo importa cuando hay escasez. `kill %1 %2` o `pkill yes`. 4) `ps aux --sort=-%mem | head -6`: la cabecera y los 5 que más memoria usan.
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
