# Clase 01 — La terminal, el shell y el kernel

**Dónde:** tu Ubuntu · **Tiempo:** 60 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** cuando escribes un comando trabajan tres piezas en cadena: la **terminal** muestra el texto y recoge tus teclas, el **shell** entiende lo que pediste y lanza el programa, y el **kernel** es el único que toca el hardware. Saber qué pieza se queja te dice dónde buscar el fallo.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Nada de Linux todavía, y no hace falta: solo saber usar un ordenador y escribir con el teclado.

> 🔤 **Palabras nuevas de hoy:**
> - **terminal**: la ventana donde escribes comandos.
> - **shell** (bash): el programa que entiende lo que escribes y lanza otros programas.
> - **kernel**: el núcleo del sistema; el único que toca el hardware.
> - **prompt**: el texto que espera tu comando (`educo@miequipo:~$`).
> - **comando, opción y argumento**: qué programa, cómo actúa y sobre qué (`ls -l /etc`).
> - **distribución**: el kernel Linux más sus programas (Ubuntu, Amazon Linux…).

## Objetivo

Al terminar sabrás:
- Distinguir **terminal**, **shell** y **kernel**, y explicar qué hace cada uno cuando escribes un comando.
- Leer el *prompt* y la estructura de cualquier comando: `comando -opciones argumentos`.
- Encontrar ayuda sin internet: `man`, `--help` y `type`.

## Por qué importa

Un servidor en la nube (una EC2 en AWS) **no tiene escritorio**. Solo tienes una línea de texto por SSH. Todo lo que harás como Cloud/DevOps pasa por esa línea: instalar, revisar logs, reiniciar servicios, depurar. Si la terminal es tu casa, la nube deja de ser magia.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la pruebas enseguida en la terminal; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 25 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

Abre una terminal: `Ctrl+Alt+T`. Hoy no hace falta ninguna carpeta.

## Las piezas

### Pieza 1 — Terminal, shell y kernel

```
  ┌──────────────────────────────────────────┐
  │  TERMINAL (la ventana)                   │  ← Dibuja texto y recibe teclas. Nada más.
  │  ┌────────────────────────────────────┐  │
  │  │  SHELL (bash)                      │  │  ← Programa que lee lo que escribes,
  │  │                                    │  │    lo interpreta y lanza otros programas.
  │  └────────────────────────────────────┘  │
  └──────────────────────────────────────────┘
                     │ llamadas al sistema (system calls)
                     ▼
  ┌──────────────────────────────────────────┐
  │  KERNEL (Linux)                          │  ← El núcleo: reparte CPU y memoria, habla con
  │                                          │    el disco y la red, y controla permisos.
  └──────────────────────────────────────────┘
                     │
                     ▼
  ┌──────────────────────────────────────────┐
  │  HARDWARE: CPU · RAM · disco · red       │
  └──────────────────────────────────────────┘
```

- La **terminal** es solo la ventana. Puedes cerrarla, abrir otra o usar otra aplicación de terminal: el shell es otra cosa.
- El **shell** (en Ubuntu, `bash`) es **un programa más**. Su trabajo: leer tu línea, entenderla y pedirle al kernel que ejecute lo que pediste.
- El **kernel** es el único que toca el hardware. Ningún programa lee el disco directamente: se lo pide al kernel.

> **Analogía:** un restaurante. Tú (cliente) hablas con el camarero (shell), que lleva la comanda a la cocina (kernel), que es la única que toca los fogones (hardware). La terminal es la mesa donde te sientas.

**Pruébalo.** El shell es un programa, con su ruta y su número de proceso:

```bash
echo $SHELL
ps -p $$
```

`$$` es "el número de proceso de este shell".

🔮 **Predice:** si escribes `bash`, ¿se abre otra ventana?

```bash
bash
ps -p $$
exit
ps -p $$
```

👀 **Qué deberías ver:** `/bin/bash`, la ruta del programa que es tu shell, y una tabla con `PID`, `TTY`, `TIME` y `CMD bash`. Al escribir `bash` no se abre ninguna ventana, pero el número de proceso (`PID`) cambia: arrancaste **un shell dentro de otro**, en la misma terminal. `exit` cierra el shell interior y vuelves al primero, con su número de antes. Es la prueba de que shell y terminal son cosas distintas.

✋ **Sin mirar:** cierras la ventana de la terminal. ¿Has cerrado el shell, la terminal o las dos cosas?

<details>
<summary>Comprueba</summary>

Las dos: la ventana era la terminal, y el shell que corría dentro termina con ella (lo verás en el Rómpelo 3).
</details>

**En resumen:** la terminal dibuja, el shell interpreta y el kernel ejecuta.

### Pieza 2 — El kernel y la distribución

Una **distribución** (Ubuntu, Debian, Amazon Linux, Red Hat) es el kernel Linux más un conjunto de programas, un gestor de paquetes y una configuración. Cuando en AWS elijas una AMI de "Amazon Linux 2023" o "Ubuntu 24.04", estarás eligiendo una distribución. El kernel tiene su propia versión, distinta de la de la distribución.

**Pruébalo:**

```bash
uname -r              # versión del kernel
uname -a              # todo lo que sabe uname
cat /etc/os-release   # la distribución
nproc                 # cuántos núcleos de CPU
uptime                # cuánto tiempo lleva encendida y la carga
```

👀 **Qué deberías ver:** el kernel, algo como `7.0.0-38-generic`; en `/etc/os-release`, `PRETTY_NAME="Ubuntu 26.04.1 LTS"` y `VERSION_ID="26.04"`; un número de núcleos (por ejemplo, `8`); y en `uptime`, la hora, cuánto lleva encendida (`up 1 day, 16:08`) y tres números de carga. El kernel (`7.0…`) y Ubuntu (`26.04`) tienen versiones diferentes: **son cosas diferentes**.

✋ **Sin mirar:** ¿quién es el único que toca el hardware: el shell o el kernel?

<details>
<summary>Comprueba</summary>

El kernel. El shell, como cualquier otro programa, se lo pide.
</details>

**En resumen:** la distribución es el kernel más sus programas; cada uno tiene su versión.

### Pieza 3 — El prompt y la anatomía de un comando

```
educo@miequipo:~/my-devops-journey$
└─┬─┘ └───┬───┘ └────────┬───────┘└┬┘
usuario  máquina    dónde estás     $ = usuario normal  (# = root, el administrador)
```

Fíjate siempre en el prompt **antes** de ejecutar algo. En el trabajo tendrás muchas terminales abiertas a la vez, conectadas a distintos servidores, y el prompt te dice en cuál estás.

```
ls   -l -a   /etc
│    │       └── argumento: sobre qué actúa
│    └────────── opciones (flags): cómo actúa. "-la" es lo mismo que "-l -a"
└─────────────── comando: qué programa
```

Opciones largas: `--all` equivale a `-a`. Las largas se leen mejor en scripts. Las cortas son más rápidas de escribir.

**Pruébalo.** Lo que dice tu prompt, con comandos:

```bash
whoami
hostname
pwd
date
```

Y la misma petición escrita de tres formas:

```bash
ls -l -a /etc | head -3
ls -la /etc | head -3
ls -l --all /etc | head -3
```

👀 **Qué deberías ver:** tu usuario, el nombre de la máquina y la carpeta en la que estás: los mismos tres datos que el prompt. Y las tres versiones de `ls` dan **la misma** salida (`| head -3` solo corta a tres líneas; lo verás en la clase 04).

✋ **Sin mirar:** en `ls -l /etc`, ¿cuál es el comando, cuál la opción y cuál el argumento?

<details>
<summary>Comprueba</summary>

`ls` es el comando, `-l` la opción y `/etc` el argumento.
</details>

**En resumen:** el prompt dice quién, dónde y en qué máquina; un comando es programa, opciones y argumentos.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, una terminal nueva y a la pieza 4.

### Pieza 4 — Qué pasa cuando pulsas Enter

```
 Escribes  ls -l /etc  y pulsas Enter
   │
 1 │ TERMINAL  envía lo que tecleaste al shell
 2 │ SHELL     lo parte en palabras:  ls │ -l │ /etc
 3 │ SHELL     busca un programa llamado ls en las carpetas del PATH  →  /usr/bin/ls
 4 │ KERNEL    a petición del shell, crea un PROCESO nuevo que ejecuta /usr/bin/ls
 5 │ ls        pide al kernel el contenido de /etc; el kernel comprueba permisos y lee el disco
 6 │ ls        escribe el resultado, la TERMINAL lo dibuja y el proceso termina
 7 ▼ SHELL     vuelve a mostrar el prompt
```

Cada paso puede fallar, y el mensaje de error te dice en cuál estás. `lsss` falla en el paso 3: el shell no encuentra ningún programa con ese nombre. `ls /esto-no-existe` llega hasta el paso 5: el programa existe, pero la ruta no (los dos, en el Rómpelo 1). Volverás a esta cadena con más detalle en la clase 07 (paso 3), en la 11 (paso 4) y en la 16 (cuando el programa es un script tuyo).

**Pruébalo.** El paso 3, por dentro: dónde encuentra el shell el programa `ls`.

```bash
which ls
ls -l /usr/bin/ls
```

👀 **Qué deberías ver:** `/usr/bin/ls` o `/bin/ls`: en Ubuntu, `/bin` es un enlace a `/usr/bin`, así que son el mismo archivo. Y en `ls -l`, una flecha `->` hacia `../lib/cargo/bin/coreutils/ls`. Ubuntu 26.04 usa **uutils**, las herramientas básicas reescritas en Rust. Se comportan casi igual que las clásicas (GNU coreutils). Si algún día un servidor responde distinto a tu PC, esa puede ser la razón: Amazon Linux, por ejemplo, usa las GNU.

✋ **Sin mirar:** `lsss` falla. ¿En qué paso de la cadena?

<details>
<summary>Comprueba</summary>

En el 3: el shell busca un programa con ese nombre en el PATH y no lo encuentra. No llega a crearse ningún proceso.
</details>

**En resumen:** la terminal envía, el shell parte y busca, el kernel crea el proceso, el programa trabaja y el shell vuelve.

### Pieza 5 — Pedir ayuda sin internet

Tres tipos de cosas pueden responder a un nombre:
- **builtin**: una orden incorporada en el propio bash, como `cd`.
- **alias**: un atajo. En Ubuntu, `ls` es un alias de `ls --color=auto` (por eso ves colores).
- **programa**: un archivo en disco, como `/usr/bin/ls`.

`type` dice cuál es. Y eso importa para pedir ayuda: `man` documenta programas, `--help` da la ayuda rápida de un programa, y los builtins se consultan con `help`.

**Pruébalo:**

```bash
type cd
type ls
type -a ls
help cd
ls --help | head -20
man ls
```

Dentro de `man`:

| Tecla | Acción |
|-------|--------|
| `Espacio` / `b` | página siguiente / anterior |
| `/palabra` + `Enter` | buscar; `n` salta a la siguiente coincidencia |
| `q` | salir |

Usa `/human` en `man ls` para encontrar la opción que muestra tamaños legibles (K, M, G).

👀 **Qué deberías ver:** `cd es una orden interna del intérprete de ordenes` (un builtin), `` ls es un alias de `ls --color=auto' `` y, con `type -a ls`, además las rutas del programa (`ls is /usr/bin/ls`; esa parte sale en inglés). `help cd` empieza con `Modifica el directorio de trabajo del shell.` Y en `man ls`, `/human` te lleva a `-h, --human-readable`.

✋ **Sin mirar:** ¿por qué `man cd` no te sirve, y qué usas en su lugar?

<details>
<summary>Comprueba</summary>

Porque `cd` no es un programa con su manual: es un builtin de bash. Su ayuda está en `help cd`.
</details>

**En resumen:** `type` dice qué es un nombre; `man` y `--help` para programas, `help` para builtins.

### Pieza 6 — Atajos que usarás miles de veces

| Atajo | Qué hace |
|-------|----------|
| `Tab` | Autocompleta comandos y rutas. Pulsa dos veces para ver las opciones |
| `↑` / `↓` | Historial de comandos |
| `Ctrl+R` | Busca en el historial (escribe parte de un comando anterior) |
| `Ctrl+C` | Cancela lo que se está ejecutando |
| `Ctrl+D` | "Fin de la entrada"; en un shell vacío, lo cierra |
| `Ctrl+L` | Limpia la pantalla |
| `Ctrl+A` / `Ctrl+E` | Ir al inicio / final de la línea |

**Pruébalo.** Escribe `unam` y pulsa `Tab`. Después `Ctrl+R`, escribe `os-rel` y pulsa `Enter`. Por último, `sleep 100` y cancélalo con `Ctrl+C`.

👀 **Qué deberías ver:** `Tab` completa `uname`; `Ctrl+R` encuentra tu `cat /etc/os-release` de la pieza 2 y lo vuelve a ejecutar; y `Ctrl+C` corta el `sleep` y te devuelve el prompt (verás `^C`).

✋ **Sin mirar:** ¿qué diferencia hay entre `Ctrl+C` y `Ctrl+D`?

<details>
<summary>Comprueba</summary>

`Ctrl+C` cancela lo que se está ejecutando. `Ctrl+D` dice "fin de la entrada": a un programa que lee lo que escribes, le indica que ya terminaste; en un shell vacío, lo cierra.
</details>

**En resumen:** `Tab`, `↑` y `Ctrl+R` ahorran teclear; `Ctrl+C` cancela y `Ctrl+D` termina la entrada.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `whoami` · `hostname` · `pwd` · `date` | quién soy · cómo se llama la máquina · dónde estoy · qué hora es |
| `uname -r` · `cat /etc/os-release` | versión del kernel · qué distribución es |
| `nproc` · `uptime` | cuántos núcleos · cuánto lleva encendida |
| `echo $SHELL` · `ps -p $$` | qué shell uso · el proceso de mi shell |
| `which cmd` | dónde está el programa |
| `type cmd` · `type -a cmd` | qué es un comando (builtin, alias o programa) · todas sus versiones |
| `man cmd` · `cmd --help` · `help cmd` | el manual · ayuda rápida · ayuda de un builtin |

## Rómpelo

**1. Un comando que no existe:**
```bash
lsss
ls /esto-no-existe
```
Son dos errores **distintos**. El primero lo da el **shell**: `Orden «lsss» no encontrada. Quizá quiso decir:`, y una lista de nombres parecidos (`less`, `lsns`…) con el paquete que los trae. Esas sugerencias las añade Ubuntu; en un servidor mínimo verás solo `lsss: orden no encontrada`. El segundo lo da **`ls`**: `ls: no se puede acceder a '/esto-no-existe': No existe el archivo o directorio`. El programa sí existe, pero la ruta que le diste no. Lee siempre quién se queja: el mensaje de `ls` empieza por `ls:`, el programa que se ejecutó.

**2. Un comando que "se cuelga":**
```bash
cat
```
Parece congelado. No lo está: `cat` sin argumentos lee lo que escribas. Escribe `hola` y Enter (te lo repite). Sal con `Ctrl+D` (fin de la entrada) o `Ctrl+C` (cancelar). En un servidor verás comandos "colgados" que en realidad esperan entrada: así se diagnostican.

**3. Cerrar la ventana mata lo que corre dentro:**
Abre una segunda terminal y ejecuta `sleep 600`. En la primera:
```bash
ps -ef | grep "sleep 600"
```
Cierra la segunda ventana y repite el comando. El `sleep` desapareció: al cerrar la terminal, el shell y sus hijos reciben una señal y terminan. Por eso, en un servidor, los programas importantes no se lanzan "en una terminal": los gestiona `systemd` (clase 12).

## Reto

En la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**. Atascarse un rato ayuda; atascarse media hora, no.

**1.** ¿Cuántos núcleos de CPU tiene tu máquina?

> 🧩 **Ejemplo resuelto:** ¿qué versión del kernel tienes?
> ```bash
> uname -r
> ```
> `7.0.0-38-generic`: un comando de una palabra, con una opción.

**Ahora tú, con huecos:** `____` → «Mi máquina tiene ____ núcleos».

<details>
<summary>Pista</summary>

Es un comando de una sola palabra de la pieza 2. Viene del inglés *number of processors*.
</details>

**2.** ¿En qué directorio está el programa `ls`?

> 🧩 **Ejemplo resuelto:** dónde está el programa `bash`.
> ```bash
> which bash
> ```
> `/bin/bash` (o `/usr/bin/bash`: en Ubuntu, `/bin` apunta a `/usr/bin`).

**Ahora tú, con huecos:** `which ____` → «`ls` está en el directorio ____».

<details>
<summary>Pista</summary>

`which` da la ruta completa del programa; el directorio es todo menos el último nombre. (`type ls` a secas solo te dice que es un alias.)
</details>

**3.** Con `man`, encuentra la opción de `ls` que ordena por fecha de modificación.

> 🧩 **Ejemplo resuelto:** la pieza 5: en `man ls`, `/human` y `Enter` llevan a `-h, --human-readable`, la opción de los tamaños legibles.

**Ahora tú, con huecos:** `man ls`, `/____` y `Enter` (con `n` para la siguiente) → «la opción es `-__`».

<details>
<summary>Pista</summary>

En inglés, la fecha de modificación es *modification time*. Busca la línea que dice *Sort by modification time*.
</details>

**4.** ¿`pwd` es un builtin o un programa?

> 🧩 **Ejemplo resuelto:** la pieza 5: `type cd` → `cd es una orden interna del intérprete de ordenes`, así que `cd` es un builtin.

**Ahora tú, con huecos:** `type ____` → «`pwd` es ____». Y con `type -a pwd`: «además existe ____».

<details>
<summary>Pista</summary>

*Orden interna* es la forma en que bash, en español, dice *builtin*.
</details>

## Cierre

Crea `notas/fase-1/clase-01.md` (plantilla en [`../notas/Notas.md`](../notas/Notas.md)) y responde **con tus palabras**:

1. ¿Qué diferencia hay entre terminal, shell y kernel? Usa tu propia analogía. *(3 líneas. Empieza así: «La terminal es como… El shell es… El kernel es…»)*
2. Escribes `ls -l /etc` y pulsas Enter. Cuenta en 3–5 pasos qué ocurre hasta que ves la lista. *(3–5 pasos numerados. Empieza así: «1. La terminal le pasa lo que escribí al shell. 2. El shell…»)*
3. `lsss` y `ls /esto-no-existe` fallan de forma distinta. ¿Quién da cada error y por qué? *(2 líneas. Empieza así: «`lsss` lo da el shell porque… `ls /esto-no-existe` lo da `ls` porque…»)*
4. *(Calentamiento, sin clase previa)* ¿Por qué un Cloud/DevOps necesita dominar la terminal si AWS tiene consola web? *(2 líneas. Empieza así: «Porque los servidores no tienen…, y la automatización…»)*

Después, escríbeme `examíname clase-01`.

Del **Reto**, anota solo los resultados (núcleos, ruta…) y marca cada punto con ✅ o ❌.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La **terminal** es la ventana: muestra texto y recibe teclas. El **shell** es un programa (bash) que interpreta lo que escribes y lanza otros programas. El **kernel** es el núcleo del sistema operativo: el único que gestiona CPU, memoria, disco y red, y al que los programas piden todo mediante llamadas al sistema. Idea clave: *la terminal no es el shell*. Puedes tener un shell sin ventana (por SSH, o un script) y un shell dentro de otro en la misma ventana.

**2.** (a) La terminal envía lo que tecleaste al shell. (b) bash separa la línea en comando (`ls`), opciones (`-l`) y argumento (`/etc`). (c) Busca un programa llamado `ls` en los directorios del `PATH` y encuentra `/usr/bin/ls`. (d) Le pide al kernel que cree un proceso con ese programa. (e) `ls` pide al kernel el contenido de `/etc`; el kernel lo lee del disco (y comprueba permisos). (f) `ls` escribe el resultado en su salida, la terminal lo dibuja, el proceso termina y el shell vuelve a mostrar el prompt.

**3.** `lsss`: el **shell** no encuentra ningún programa con ese nombre (`command not found`) y no llega a ejecutarse nada. `ls /esto-no-existe`: el shell sí encontró `ls` y lo ejecutó, pero **`ls`** informa de que la ruta no existe (`No such file or directory`). Saber quién falla te dice dónde buscar: en el nombre del comando o en sus argumentos.

**4.** Porque los servidores no tienen interfaz gráfica: se administran por SSH. La automatización (scripts, CI/CD, Terraform, AWS CLI) es texto, y la consola web no sirve para repetir tareas, depurar dentro de una instancia ni trabajar a escala.

**Reto:** 1) `nproc` · 2) `which ls` → `/usr/bin/ls` o `/bin/ls`, el mismo archivo: el directorio es `/usr/bin` (`type ls` a secas solo te dice que es un alias) · 3) `/time`, y la opción es `-t` (`ls -lt`) · 4) `type pwd` → `pwd es una orden interna del intérprete de ordenes`, un builtin; `type -a pwd` muestra que además existe el programa `/usr/bin/pwd`, pero bash usa el suyo.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| shell | intérprete de comandos |
| kernel | núcleo del sistema operativo |
| prompt | el indicador donde escribes |
| flag / option | opción de un comando |
| builtin | orden incorporada en el shell |
| system call | llamada al sistema |

🎙️ *"The terminal is just a window. The shell interprets my commands, and the kernel is the only thing that actually talks to the hardware."*

## Siguiente

[Clase 02 — El sistema de archivos y las rutas](clase-02-sistema-de-archivos.md)
