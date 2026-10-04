# Clase 01 — La terminal, el shell y el kernel

**Dónde:** tu Ubuntu · **Tiempo:** 60 min · **Bloque:** A. Linux en tu equipo

## Objetivo

Al terminar sabrás:
- Distinguir **terminal**, **shell** y **kernel**, y explicar qué hace cada uno cuando escribes un comando.
- Leer el *prompt* y la estructura de cualquier comando: `comando -opciones argumentos`.
- Encontrar ayuda sin internet: `man`, `--help` y `type`.

## Por qué importa

Un servidor en la nube (una EC2 en AWS) **no tiene escritorio**. Solo tienes una línea de texto por SSH. Todo lo que harás como Cloud/DevOps pasa por esa línea: instalar, revisar logs, reiniciar servicios, depurar. Si la terminal es tu casa, la nube deja de ser magia.

## Teoría

### Las cuatro capas

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
- Una **distribución** (Ubuntu, Debian, Amazon Linux, Red Hat) es el kernel Linux más un conjunto de programas, un gestor de paquetes y una configuración. Cuando en AWS elijas una AMI de "Amazon Linux 2023" o "Ubuntu 24.04", estarás eligiendo una distribución.

> **Analogía:** un restaurante. Tú (cliente) hablas con el camarero (shell), que lleva la comanda a la cocina (kernel), que es la única que toca los fogones (hardware). La terminal es la mesa donde te sientas.

### El prompt

```
educo@miequipo:~/my-devops-journey$
└─┬─┘ └───┬───┘ └────────┬───────┘└┬┘
usuario  máquina    dónde estás     $ = usuario normal  (# = root, el administrador)
```

Fíjate siempre en el prompt **antes** de ejecutar algo. En el trabajo tendrás muchas terminales abiertas a la vez, conectadas a distintos servidores, y el prompt te dice en cuál estás.

### Anatomía de un comando

```
ls   -l -a   /etc
│    │       └── argumento: sobre qué actúa
│    └────────── opciones (flags): cómo actúa. "-la" es lo mismo que "-l -a"
└─────────────── comando: qué programa
```

Opciones largas: `--all` equivale a `-a`. Las largas se leen mejor en scripts. Las cortas son más rápidas de escribir.

## Práctica guiada

Abre una terminal (`Ctrl+Alt+T`).

### 1. ¿Quién, dónde y qué sistema?

```bash
whoami
hostname
pwd
date
```

🔮 **Predice:** ¿qué crees que mostrará `echo $SHELL`?

```bash
echo $SHELL
```

Debería ser `/bin/bash`: la ruta del programa que es tu shell. Comprueba que el shell es un proceso más, con su número:

```bash
ps -p $$
```

`$$` es "el número de proceso de este shell". Verás `bash`.

### 2. El kernel y la distribución

```bash
uname -r              # versión del kernel
uname -a              # todo lo que sabe uname
cat /etc/os-release   # la distribución
nproc                 # cuántos núcleos de CPU
uptime                # cuánto tiempo lleva encendida y la carga
```

Fíjate: el kernel tiene su propia versión (algo como `7.0.0-…`), distinta de la de Ubuntu (`26.04`). **Son cosas diferentes.**

### 3. Un shell dentro de otro

🔮 **Predice:** si escribes `bash`, ¿se abre otra ventana?

```bash
ps -p $$
bash
ps -p $$
exit
ps -p $$
```

No se abre ninguna ventana, pero el número de proceso cambia: arrancaste **un shell dentro de otro**, en la misma terminal. `exit` cierra el shell interior y vuelves al primero. Es la prueba de que shell y terminal son cosas distintas.

### 4. Pedir ayuda sin internet

```bash
type cd
type ls
type -a ls
ls -l /usr/bin/ls
```

Tres tipos de cosas pueden responder a un nombre:
- **builtin**: `cd` es una orden incorporada en el propio bash.
- **alias**: un atajo. En Ubuntu, `ls` es un alias de `ls --color=auto` (por eso ves colores).
- **programa**: un archivo en disco. `type -a ls` muestra todas las respuestas en orden; la real es `/usr/bin/ls`.

`ls -l /usr/bin/ls` te enseñará una flecha `->` hacia `.../coreutils/ls`. Ubuntu 26.04 usa **uutils**, las herramientas básicas reescritas en Rust. Se comportan casi igual que las clásicas (GNU coreutils). Si algún día un servidor responde distinto a tu PC, esa puede ser la razón: Amazon Linux, por ejemplo, usa las GNU.

Esto importa para pedir ayuda: `man` documenta programas, y los builtins se consultan con `help`:

```bash
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

### 5. Atajos que usarás miles de veces

| Atajo | Qué hace |
|-------|----------|
| `Tab` | Autocompleta comandos y rutas. Pulsa dos veces para ver las opciones |
| `↑` / `↓` | Historial de comandos |
| `Ctrl+R` | Busca en el historial (escribe parte de un comando anterior) |
| `Ctrl+C` | Cancela lo que se está ejecutando |
| `Ctrl+D` | "Fin de la entrada"; en un shell vacío, lo cierra |
| `Ctrl+L` | Limpia la pantalla |
| `Ctrl+A` / `Ctrl+E` | Ir al inicio / final de la línea |

Pruébalos todos ahora, en especial `Ctrl+R`.

## Rómpelo

**1. Un comando que no existe:**
```bash
lsss
ls /esto-no-existe
```
Son dos errores **distintos**. El primero lo da el **shell**: no encontró ningún programa llamado `lsss`. El segundo lo da **`ls`**: el programa sí existe, pero la ruta que le diste no. Lee siempre quién se queja: la primera palabra del error suele decirlo.

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

Sin mirar la práctica, responde con comandos (escribe en tu cierre el comando que usaste):
1. ¿Cuántos núcleos de CPU tiene tu máquina?
2. ¿En qué directorio está el programa `ls`? (pista: `type` o `which`)
3. Con `man`, encuentra la opción de `ls` que ordena por fecha de modificación.
4. ¿`pwd` es un builtin o un programa?

## Cierre

Crea `notas/fase-1/clase-01.md` (plantilla en [`../notas/README.md`](../notas/README.md)) y responde **con tus palabras**:

1. ¿Qué diferencia hay entre terminal, shell y kernel? Usa tu propia analogía.
2. Escribes `ls -l /etc` y pulsas Enter. Cuenta en 3–5 pasos qué ocurre hasta que ves la lista.
3. `lsss` y `ls /esto-no-existe` fallan de forma distinta. ¿Quién da cada error y por qué?
4. *(Calentamiento, sin clase previa)* ¿Por qué un Cloud/DevOps necesita dominar la terminal si AWS tiene consola web?

Añade también las respuestas del **Reto**.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** La **terminal** es la ventana: muestra texto y recibe teclas. El **shell** es un programa (bash) que interpreta lo que escribes y lanza otros programas. El **kernel** es el núcleo del sistema operativo: el único que gestiona CPU, memoria, disco y red, y al que los programas piden todo mediante llamadas al sistema. Idea clave: *la terminal no es el shell*. Puedes tener un shell sin ventana (por SSH, o un script) y un shell dentro de otro en la misma ventana.

**2.** (a) La terminal envía lo que tecleaste al shell. (b) bash separa la línea en comando (`ls`), opciones (`-l`) y argumento (`/etc`). (c) Busca un programa llamado `ls` en los directorios del `PATH` y encuentra `/usr/bin/ls`. (d) Le pide al kernel que cree un proceso con ese programa. (e) `ls` pide al kernel el contenido de `/etc`; el kernel lo lee del disco (y comprueba permisos). (f) `ls` escribe el resultado en su salida, la terminal lo dibuja, el proceso termina y el shell vuelve a mostrar el prompt.

**3.** `lsss`: el **shell** no encuentra ningún programa con ese nombre (`command not found`) y no llega a ejecutarse nada. `ls /esto-no-existe`: el shell sí encontró `ls` y lo ejecutó, pero **`ls`** informa de que la ruta no existe (`No such file or directory`). Saber quién falla te dice dónde buscar: en el nombre del comando o en sus argumentos.

**4.** Porque los servidores no tienen interfaz gráfica: se administran por SSH. La automatización (scripts, CI/CD, Terraform, AWS CLI) es texto, y la consola web no sirve para repetir tareas, depurar dentro de una instancia ni trabajar a escala.

**Reto:** 1) `nproc` · 2) `which ls` o `type -a ls` → `/usr/bin/ls` (`type ls` a secas solo te dice que es un alias) · 3) `-t` (`ls -lt`) · 4) `type pwd` → builtin (también existe `/usr/bin/pwd`, pero bash usa el suyo).
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
