# Clase 03 — Archivos y directorios

**Dónde:** tu Ubuntu · **Tiempo:** 60 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** crear, copiar, mover y borrar son cuatro verbos con una misma trampa: **Linux no pregunta y no tiene papelera**. Por eso el hábito profesional es *mirar antes de tocar*: `pwd` para saber dónde estás, `echo` para ver qué abarca un comodín y una copia `.bak` antes de editar algo importante.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Moverte con `cd` y con rutas absolutas y relativas (clase 02).
> - Leer una línea de `ls -l` (clase 02).
> - El shell interpreta lo que escribes **antes** de lanzar el programa (clase 01).

> 🔤 **Palabras nuevas de hoy:**
> - **comodín** (`*`, `?`): un patrón que el shell convierte en una lista de archivos.
> - **sobrescribir**: reemplazar un archivo que ya existía, perdiendo lo que tenía.
> - **recursivo** (`-r`): que actúa también sobre todo lo que hay dentro de una carpeta.
> - **copia de seguridad** (`.bak`): una copia de un archivo antes de tocarlo.
> - **tarball** (`.tar.gz`): muchos archivos empaquetados y comprimidos en uno.
> - **nano**: el editor de texto sencillo de la terminal.

## Objetivo

- Crear, copiar, mover, renombrar y borrar archivos y directorios **sin miedo y sin accidentes**.
- Leer archivos de cualquier tamaño: `cat`, `less`, `head`, `tail` y `tail -f`.
- Editar con `nano`, el editor que encontrarás en casi cualquier servidor.
- Usar comodines (`*`, `?`, `[ ]`) y comprobarlos **antes** de borrar.

## Por qué importa

Editar configuraciones, hacer copias de seguridad antes de un cambio y seguir un log en tiempo real con `tail -f` son tareas diarias en operaciones. Y `rm` en Linux **no tiene papelera**: un `rm -rf` en el sitio equivocado es uno de los incidentes más famosos del oficio.

## Cómo va esta clase

Siete piezas cortas: crear, editar, copiar, mover, leer, comodines con borrado y comprimir. En cada una lees **una** idea y la pruebas enseguida en la terminal; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 30 min); el segundo, las **piezas 5 a 7**, el Rómpelo, el reto y el cierre. La pieza 5 necesita **dos terminales**.

```bash
mkdir -p ~/my-devops-journey/labs/clase-03
cd ~/my-devops-journey/labs/clase-03
```

## Las piezas

### Pieza 1 — Crear

```bash
touch notas.txt              # un archivo vacío (o le actualiza la fecha si ya existe)
mkdir -p logs/2026/10        # una carpeta; con -p, toda la ruta de una vez, sin fallar si ya existe
```

**Pruébalo:**

```bash
touch app.log error.log notas.txt
mkdir -p config/nginx/sites backups
ls -l
tree
```

👀 **Qué deberías ver:** tres archivos de tamaño `0` y dos carpetas (líneas que empiezan por `d`). `tree` dibuja `config/nginx/sites` entera, creada con un solo `mkdir -p`.

✋ **Sin mirar:** ¿con qué comando creas `a/b/c` de una vez?

<details>
<summary>Comprueba</summary>

`mkdir -p a/b/c`.
</details>

**En resumen:** `touch` crea archivos; `mkdir -p`, rutas enteras.

### Pieza 2 — Escribir y editar con nano

`nano` es el editor sencillo de la terminal, y está en casi cualquier servidor. Atajos (`^` significa `Ctrl`):

| Atajo | Acción |
|-------|--------|
| `Ctrl+O`, luego `Enter` | guardar |
| `Ctrl+X` | salir (si hay cambios, pregunta) |
| `Ctrl+W` | buscar |
| `Ctrl+K` / `Ctrl+U` | cortar / pegar una línea |

> **Si un día te ves dentro de `vim`** (muchos servidores y contenedores solo traen `vi`/`vim`, y comandos como `git commit` o `crontab -e` pueden abrirlo): no se sale con `Ctrl+C`. Pulsa `Esc` y escribe `:q!` + `Enter` para salir **sin guardar**, o `:wq` + `Enter` para **guardar y salir**. Con eso sobrevives; si algún día quieres aprender vim de verdad, ejecuta `vimtutor`.

**Pruébalo.** Escribe tres líneas, guarda y sal:

```bash
nano notas.txt
cat notas.txt
wc -l notas.txt
```

👀 **Qué deberías ver:** tus tres líneas, y `3 notas.txt`: `wc -l` cuenta las líneas.

✋ **Sin mirar:** te ves dentro de `vim` y quieres salir sin guardar nada. ¿Qué pulsas?

<details>
<summary>Comprueba</summary>

`Esc`, y después `:q!` + `Enter`.
</details>

**En resumen:** `nano` para editar; de `vim` se sale con `Esc` y `:q!`.

### Pieza 3 — Copiar antes de tocar

```bash
cp original copia            # copiar (para carpetas: cp -r)
```

⚠️ `cp` **sobrescribe sin preguntar** si el destino ya existe. Con `-i` pregunta antes. Por eso, la regla de oro: antes de editar una configuración, se hace una copia `.bak`.

**Pruébalo:**

```bash
echo "server_port=80" > config/app.conf
cp config/app.conf config/app.conf.bak
ls config/
```

🔮 **Predice:** `cp config backups/` ¿funcionará?

```bash
cp config backups/
cp -r config backups/
tree
```

👀 **Qué deberías ver:** `app.conf` y `app.conf.bak` en `config/`. El primer `cp` se niega: `cp: -r not specified; omitting directory 'config'` (en inglés: el `cp` de Ubuntu 26.04 aún no está traducido). Con `-r` (recursivo), `tree` muestra `backups/config/` con todo dentro.

✋ **Sin mirar:** ¿por qué se copia una configuración a `.bak` antes de editarla?

<details>
<summary>Comprueba</summary>

Para poder volver atrás si el cambio rompe algo: en Linux no hay "deshacer".
</details>

**En resumen:** `cp` sobrescribe en silencio; `-r` para carpetas, `-i` para que pregunte, y un `.bak` antes de tocar.

### Pieza 4 — Mover y renombrar

```bash
mv viejo nuevo               # renombrar...
mv archivo carpeta/          # ...o mover: para Linux es la misma operación
```

`mv` también sobrescribe sin preguntar (`-i` para que pregunte).

**Pruébalo:**

```bash
mv notas.txt apuntes.txt       # renombrar
mv apuntes.txt backups/        # mover
mv backups/apuntes.txt .       # volver aquí (. = directorio actual)
ls
```

👀 **Qué deberías ver:** `notas.txt` ya no está; `apuntes.txt` sí, otra vez en la carpeta actual, después de su viaje a `backups/`.

✋ **Sin mirar:** ¿qué diferencia hay entre `mv informe.txt viejo.txt` y `mv informe.txt viejo/`?

<details>
<summary>Comprueba</summary>

El primero **renombra** el archivo; el segundo lo **mueve** dentro de la carpeta `viejo`.
</details>

**En resumen:** renombrar y mover son la misma operación: `mv`.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, `cd ~/my-devops-journey/labs/clase-03` y a la pieza 5.

### Pieza 5 — Leer archivos, grandes y en directo

```bash
cat archivo                  # entero, de golpe (para archivos cortos)
less archivo                 # página a página: q sale, /palabra busca, G va al final
head -n 5 archivo            # las 5 primeras líneas
tail -n 5 archivo            # las 5 últimas
tail -f archivo.log          # las últimas, y se queda mirando las nuevas en directo
```

**Pruébalo:**

```bash
cat /etc/services | wc -l
head -n 15 /etc/services
tail -n 5 /etc/services
less /etc/services             # busca /ssh, pulsa n para la siguiente coincidencia, q para salir
```

Ahora un log en directo. Abre **dos terminales** en `labs/clase-03`. En la primera:

```bash
tail -f app.log
```

En la segunda:

```bash
echo "$(date) usuario entró" >> app.log
echo "$(date) ERROR: base de datos no responde" >> app.log
```

👀 **Qué deberías ver:** `/etc/services` tiene unas 365 líneas: demasiadas para `cat`, cómodas con `less`. Y las dos líneas aparecen en la primera terminal en cuanto se escriben. Así se sigue un servicio en producción mientras reproduces un fallo. Sal con `Ctrl+C`.

✋ **Sin mirar:** quieres ver qué escribe un servicio mientras reproduces un fallo. ¿Qué comando usas?

<details>
<summary>Comprueba</summary>

`tail -f` sobre su log: muestra las últimas líneas y se queda esperando las nuevas.
</details>

**En resumen:** `cat` para lo corto, `less` para lo largo, `head` y `tail` para los extremos, `tail -f` para lo que está pasando.

### Pieza 6 — Comodines, y borrar sin papelera

Un comodín es un patrón que el **shell** convierte en la lista de archivos que coinciden, **antes** de ejecutar el comando:

| Patrón | Coincide con |
|--------|--------------|
| `*` | cualquier cosa, incluso nada: `*.log` son todos los que acaban en `.log` |
| `?` | exactamente un carácter: `app?.log` |
| `[1-3]` | un carácter de ese conjunto: `dia[1-3].txt` |

El comando nunca ve el `*`: recibe la lista ya hecha. Por eso **`echo` es tu red de seguridad**: `echo *.log` te enseña exactamente lo que recibiría `rm *.log`, sin borrar nada.

Y `rm archivo` borra **para siempre**: no hay papelera ni «deshacer». Para una carpeta con cosas dentro, `rm -r carpeta`. Antes de cualquier `rm` importante: `pwd` para saber dónde estás y `echo` con el mismo patrón para ver qué se va a borrar.

**Pruébalo:**

```bash
touch dia1.txt dia2.txt dia3.txt dia10.txt informe.pdf
echo *.txt
echo dia?.txt
echo dia[12].txt
```

🔮 **Predice:** ¿qué imprimirá `echo *.csv` si no hay ningún `.csv`?

```bash
echo *.csv
```

👀 **Qué deberías ver:** `dia10.txt dia1.txt dia2.txt dia3.txt`; `dia1.txt dia2.txt dia3.txt` (`dia10` tiene dos caracteres tras `dia`); `dia1.txt dia2.txt`; y `*.csv`, tal cual. Si nada coincide, bash deja el patrón **sin cambiar**. Un `rm *.csv` sin coincidencias intentaría borrar un archivo llamado literalmente `*.csv`.

✋ **Sin mirar:** antes de `rm *.tmp`, ¿qué escribes para ver qué se borraría?

<details>
<summary>Comprueba</summary>

`echo *.tmp` (o `ls *.tmp`): la misma lista que recibiría `rm`, sin borrar nada.
</details>

**En resumen:** el shell expande el comodín; `echo` lo enseña antes de que `rm` lo borre para siempre.

### Pieza 7 — Empaquetar y comprimir: `tar` y `gzip`

Un **tarball** (`.tar.gz`) es un solo archivo que contiene muchos, comprimido. Es el formato de los backups, de los logs viejos (`.gz`) y de buena parte del software que descargarás.

| Comando | Qué hace |
|---------|----------|
| `tar czf copia.tar.gz carpeta/` | **c**rea un archivo comprimido con g**z**ip (**f** = nombre del archivo) |
| `tar tzf copia.tar.gz` | lis**t**a el contenido **sin** extraer |
| `tar xzf copia.tar.gz -C destino/` | e**x**trae dentro de `destino/` |
| `gzip archivo` / `gunzip archivo.gz` | comprime / descomprime un solo archivo (reemplaza el original) |
| `zcat`, `zless`, `zgrep` | leen un `.gz` sin descomprimirlo |

> Truco para recordar `tar`: **c**rear, **x**traer, lis**t**ar, siempre con **f**ile. `z` = gzip.

**Pruébalo:**

```bash
tar czf backup-config-$(date +%F).tar.gz config/
ls -lh *.tar.gz
tar tzf backup-config-*.tar.gz
mkdir -p restaurado && tar xzf backup-config-*.tar.gz -C restaurado/
tree restaurado
```

🔮 **Predice:** ¿cuánto ocupará `servicios.txt.gz` comparado con el original (`ls -lh /etc/services`)?

```bash
cp /etc/services servicios.txt && gzip servicios.txt
ls -lh /etc/services servicios.txt.gz
zgrep -c tcp servicios.txt.gz
```

👀 **Qué deberías ver:** un `backup-config-<fecha>.tar.gz` pequeño, su lista (`config/`, `config/app.conf`, `config/nginx/`…) y la misma carpeta dentro de `restaurado/`. Y el `.gz`: unos `5,4K` frente a los `13K` del original. El texto se comprime muy bien: por eso los logs rotados se guardan en `.gz`. `zgrep` cuenta las líneas con `tcp` (unas 220) sin descomprimir nada.

✋ **Sin mirar:** ¿qué letras usas para **ver** lo que hay dentro de un `.tar.gz` sin extraerlo?

<details>
<summary>Comprueba</summary>

`tar tzf archivo.tar.gz`: **t** listar, **z** gzip, **f** el archivo.
</details>

**En resumen:** `tar czf` empaqueta, `tzf` lista, `xzf` extrae; `gzip` comprime uno solo.

## Tu chuleta de la clase

| Comando | Qué hace | Opciones clave |
|---------|----------|----------------|
| `touch f` | Crea un archivo vacío (o actualiza su fecha si ya existe) | |
| `mkdir d` | Crea un directorio | `-p`: crea toda la ruta y no falla si ya existe |
| `cp a b` | Copia | `-r`: directorios · `-i`: pregunta antes de sobrescribir · `-a`: conserva permisos y fechas |
| `mv a b` | Mueve **o renombra** (es la misma operación) | `-i` |
| `rm f` | Borra **para siempre** | `-r`: directorios · `-i`: pregunta · `-f`: no pregunta nunca |
| `rmdir d` | Borra un directorio **solo si está vacío** | |
| `cat f` | Muestra el archivo entero | |
| `less f` | Lo muestra página a página (`q` sale, `/` busca, `G` va al final) | |
| `head -n 5 f` | Las primeras 5 líneas | |
| `tail -n 5 f` | Las últimas 5 líneas | `-f`: se queda esperando y muestra lo nuevo en directo |
| `file f` | Te dice qué tipo de archivo es | |
| `wc -l f` | Cuenta las líneas | |
| `tar czf` · `tar tzf` · `tar xzf … -C d/` | crear · listar · extraer un `.tar.gz` | |
| `gzip f` · `gunzip f.gz` · `zgrep` | comprimir · descomprimir · buscar en un `.gz` | |

## Rómpelo

**1. `cp` sobrescribe en silencio:**
```bash
echo "versión buena" > importante.txt
echo "versión vieja" > viejo.txt
cp viejo.txt importante.txt
cat importante.txt            # la versión buena se perdió
cp -i viejo.txt importante.txt   # ahora pregunta; responde n
```

**2. `rm` no tiene papelera:**
```bash
rm importante.txt
ls ~/.local/share/Trash/files/ 2>/dev/null   # no está en la papelera
```
La papelera del escritorio es cosa del gestor de archivos, no de `rm`.

**3. `rmdir` frente a `rm -r`:**
```bash
rmdir config        # falla: no está vacío
rm -ri config       # pregunta archivo por archivo; responde y
```

**4. El peligro real** (léelo, **no lo ejecutes**):
```bash
cd /ruta/que/no/existe
rm -rf *
```
Si el `cd` falla, el shell sigue en el directorio anterior y `rm -rf *` borra **ese** directorio. Las defensas: comprobar con `pwd`, usar `&&` (clase 04: `cd dir && rm …` solo borra si el `cd` funcionó) y previsualizar con `echo` o `ls`.

## Reto

En `labs/clase-03/reto/`, sin mirar arriba, en la terminal. En tus notas, marca cada punto con ✅ o ❌ al compararlo con la solución. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Crea `logs/2026/10/` de un solo comando.

> 🧩 **Ejemplo resuelto:** la pieza 1: `mkdir -p config/nginx/sites` creó las tres carpetas de una vez.

**Ahora tú, con huecos:** `mkdir ____ logs/2026/10`

<details>
<summary>Pista</summary>

`mkdir` con la opción que crea toda la ruta de una vez.
</details>

**2.** Crea `web-1.log`, `web-2.log`, `web-3.log` y `db.log` dentro de `logs/2026/10/`.

> 🧩 **Ejemplo resuelto:** la pieza 1: `touch app.log error.log notas.txt` creó tres archivos con un solo comando.

**Ahora tú, con huecos:** `touch logs/2026/10/web-1.log ____ ____ ____`

<details>
<summary>Pista</summary>

`touch` acepta varios nombres en el mismo comando, cada uno con su ruta: `touch ruta/a ruta/b`.
</details>

**3.** Mueve solo los `web-*.log` a `logs/web/` (créalo). Antes, comprueba el patrón con `echo`.

> 🧩 **Ejemplo resuelto:** mover los `dia?.txt` de la pieza 6 a una carpeta `dias/`.
> ```bash
> mkdir -p dias
> echo dia?.txt          # dia1.txt dia2.txt dia3.txt: los que quiero
> mv dia?.txt dias/
> ```

**Ahora tú, con huecos:** `mkdir -p logs/web`, `echo logs/2026/10/____` y, si salen los tres, `mv logs/2026/10/____ ____`.

<details>
<summary>Pista</summary>

El patrón es `web-*.log`. Si el `echo` enseña los tres, cambia `echo` por `mv` y añade el destino al final.
</details>

**4.** Haz una copia de seguridad de toda la carpeta `logs` como `logs.bak`, conservando fechas y permisos.

> 🧩 **Ejemplo resuelto:** la pieza 3: `cp -r config backups/` copió una carpeta entera.

**Ahora tú, con huecos:** `cp -____ logs logs.bak`

<details>
<summary>Pista</summary>

La opción que además de copiar carpetas conserva fechas y permisos está en la chuleta: `-a` (ya incluye `-r`).
</details>

**5.** Borra `logs/2026` entero y comprueba que `logs.bak` sigue intacta.

> 🧩 **Ejemplo resuelto:** el Rómpelo 3: `rm -ri config` borró una carpeta con cosas dentro, preguntando por cada una.

**Ahora tú, con huecos:** `echo logs/2026` (comprueba que es lo que quieres), `rm -____ logs/2026` y `tree ____`.

<details>
<summary>Pista</summary>

`rm -r` borra una carpeta con todo lo que tiene. Después, `tree logs.bak`: debe seguir con los cuatro archivos.
</details>

**6.** Empaqueta `logs.bak` en `logs-<fecha de hoy>.tar.gz`, lista su contenido **sin** extraerlo y extráelo dentro de una carpeta `restore/`.

> 🧩 **Ejemplo resuelto:** la pieza 7: `tar czf backup-config-$(date +%F).tar.gz config/`, después `tar tzf` y `tar xzf … -C restaurado/`.

**Ahora tú, con huecos:**
```bash
tar ____ logs-$(date +%F).tar.gz logs.bak/
tar ____ logs-*.tar.gz
mkdir -p restore && tar ____ logs-*.tar.gz -C ____
```

<details>
<summary>Pista</summary>

**c** crear, **t** listar, **x** extraer, siempre con **z** y **f**.
</details>

## Cierre

En `notas/fase-1/clase-03.md`:

1. Diferencia entre `>` y `>>` al escribir en un archivo (adelanto de la clase 04: ya lo usaste en las piezas 3 y 5). Pon un ejemplo de un archivo de un servidor real que `>` destrozaría. *(2 líneas. Empieza así: «`>` vacía el archivo y… `>>`… Por ejemplo, `> /etc/passwd` destrozaría…»)*
2. ¿Por qué `echo patrón` antes de `rm patrón` es buena idea? ¿Quién expande el `*`? *(2 líneas. Empieza así: «Porque quien expande el `*` es el…, y `echo` me enseña…»)*
3. ¿Para qué sirve `tail -f` en operaciones? Describe una situación concreta. *(2 líneas. Empieza así: «Para ver un log en directo mientras… Por ejemplo: `tail -f …` mientras…»)*
4. **Repaso (clase 02, sin mirar):** desde `/var/log/nginx`, ¿a dónde te lleva `cd ../..`? ¿Y `cd /`? *(1 línea. Empieza así: «`cd ../..` me lleva a… y `cd /`, a…»)*

Después, escríbeme `examíname clase-03`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `>` **trunca**: vacía el archivo y escribe desde cero. `>>` **añade** al final. Ejemplos reales: `echo "algo" > /etc/ssh/sshd_config` deja el servidor SSH sin configuración y puede impedirte entrar; `> /etc/passwd` destruye la lista de usuarios; `> /etc/nginx/nginx.conf` tumba la web en el próximo reinicio. No vale con decir "un archivo importante": hay que nombrar uno.

**2.** Porque el **shell** expande el patrón antes de ejecutar el comando. `echo` muestra exactamente la lista que recibiría `rm`, sin borrar nada. Así detectas que el patrón coincide con más (o con menos) de lo que pensabas.

**3.** Para ver un log en directo mientras ocurre algo: reproduces el fallo (recargas la web, lanzas una petición, reinicias el servicio) y ves el error en el momento en que aparece, sin abrir el archivo una y otra vez. Ejemplo: `tail -f /var/log/nginx/error.log` mientras pruebas la web que devuelve 502.

**4.** `cd ../..` → `/var` (dos niveles arriba: `nginx` → `log` → `var`). `cd /` → la raíz, `/`.

**Reto (una solución):**
```bash
mkdir -p reto/logs/2026/10 && cd reto
touch logs/2026/10/web-{1,2,3}.log logs/2026/10/db.log   # o uno a uno
mkdir -p logs/web
echo logs/2026/10/web-*.log
mv logs/2026/10/web-*.log logs/web/
cp -a logs logs.bak
rm -r logs/2026
tree
```
`{1,2,3}` es la *expansión de llaves*: genera las tres palabras aunque los archivos no existan. Es distinta de `*`, que solo coincide con archivos que ya existen.

Punto 6:
```bash
tar czf "logs-$(date +%F).tar.gz" logs.bak
tar tzf logs-*.tar.gz
mkdir -p restore && tar xzf logs-*.tar.gz -C restore/
```
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| to overwrite | sobrescribir |
| recursive | recursivo (`-r`) |
| wildcard / glob | comodín |
| backup | copia de seguridad |
| to follow a log | seguir un log en directo |
| tarball / archive | paquete `.tar.gz` |

🎙️ *"Before I edit a config file on a server, I always make a backup copy, and I preview any wildcard with `echo` or `ls` before deleting."*

## Siguiente

[Clase 04 — Redirecciones, pipes y códigos de salida](clase-04-redirecciones-y-pipes.md)
