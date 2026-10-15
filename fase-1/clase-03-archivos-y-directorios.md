# Clase 03 — Archivos y directorios

**Dónde:** tu Ubuntu · **Tiempo:** 60 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** crear, copiar, mover y borrar son cuatro verbos con una misma trampa: **Linux no pregunta y no tiene papelera**. Por eso el hábito profesional es *mirar antes de tocar*: `pwd` para saber dónde estás, `echo` para ver qué abarca un comodín y una copia `.bak` antes de editar algo importante.

## Objetivo

- Crear, copiar, mover, renombrar y borrar archivos y directorios **sin miedo y sin accidentes**.
- Leer archivos de cualquier tamaño: `cat`, `less`, `head`, `tail` y `tail -f`.
- Editar con `nano`, el editor que encontrarás en casi cualquier servidor.
- Usar comodines (`*`, `?`, `[ ]`) y comprobarlos **antes** de borrar.

## Por qué importa

Editar configuraciones, hacer copias de seguridad antes de un cambio y seguir un log en tiempo real con `tail -f` son tareas diarias en operaciones. Y `rm` en Linux **no tiene papelera**: un `rm -rf` en el sitio equivocado es uno de los incidentes más famosos del oficio.

## Teoría

Cuatro piezas: crear, copiar y mover, borrar sin sustos y leer. Y una quinta, los comodines, que son la mitad de los sustos.

### 1. Crear

```bash
touch notas.txt              # un archivo vacío
mkdir -p logs/2026/10        # una carpeta; con -p, toda la ruta de una vez
```

### 2. Copiar, mover y renombrar

```bash
cp original copia            # copiar (para carpetas: cp -r)
mv viejo nuevo               # renombrar...
mv archivo carpeta/          # ...o mover: para Linux es la misma operación
```

⚠️ `cp` y `mv` **sobrescriben sin preguntar** si el destino ya existe. Con `-i` preguntan antes.

### 3. Borrar: sin papelera

`rm archivo` borra **para siempre**: no hay papelera ni «deshacer». Para una carpeta con cosas dentro, `rm -r carpeta`. Por eso, antes de cualquier `rm` importante: `pwd` para saber dónde estás y `echo` con el mismo patrón para ver qué se va a borrar (pieza 5).

### 4. Leer

```bash
cat archivo                  # entero, de golpe (para archivos cortos)
less archivo                 # página a página: q sale, /palabra busca
head -n 5 archivo            # las 5 primeras líneas
tail -n 5 archivo            # las 5 últimas
tail -f archivo.log          # las últimas, y se queda mirando las nuevas en directo
```

### 5. Comodines: el shell hace la lista

Un comodín es un patrón que el **shell** convierte en la lista de archivos que coinciden, **antes** de ejecutar el comando:

| Patrón | Coincide con |
|--------|--------------|
| `*` | cualquier cosa, incluso nada: `*.log` son todos los que acaban en `.log` |
| `?` | exactamente un carácter: `app?.log` |
| `[1-3]` | un carácter de ese conjunto: `dia[1-3].txt` |

El comando nunca ve el `*`: recibe la lista ya hecha. Por eso **`echo` es tu red de seguridad**: `echo *.log` te enseña exactamente lo que recibiría `rm *.log`, sin borrar nada.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. ¿Con qué comando creas `a/b/c` de una vez?
2. ¿Qué diferencia hay entre `mv informe.txt viejo.txt` y `mv informe.txt viejo/`?
3. Antes de `rm *.tmp`, ¿qué escribes para ver qué se borraría?

<details>
<summary>Comprueba</summary>

1. `mkdir -p a/b/c`. 2. El primero **renombra** el archivo; el segundo lo **mueve** dentro de la carpeta `viejo`. 3. `echo *.tmp` (o `ls *.tmp`).
</details>

### Tu chuleta de la clase

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

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-03
cd ~/my-devops-journey/labs/clase-03
```

### 1. Crear

```bash
touch app.log error.log notas.txt
mkdir -p config/nginx/sites backups
ls -l
tree
```

### 2. Escribir y editar con nano

```bash
nano notas.txt
```

Escribe tres líneas. Atajos de `nano` (`^` significa `Ctrl`):
| Atajo | Acción |
|-------|--------|
| `Ctrl+O`, luego `Enter` | guardar |
| `Ctrl+X` | salir (si hay cambios, pregunta) |
| `Ctrl+W` | buscar |
| `Ctrl+K` / `Ctrl+U` | cortar / pegar una línea |

> **Si un día te ves dentro de `vim`** (muchos servidores y contenedores solo traen `vi`/`vim`, y comandos como `git commit` o `crontab -e` pueden abrirlo): no se sale con `Ctrl+C`. Pulsa `Esc` y escribe `:q!` + `Enter` para salir **sin guardar**, o `:wq` + `Enter` para **guardar y salir**. Con eso sobrevives; si algún día quieres aprender vim de verdad, ejecuta `vimtutor`.

```bash
cat notas.txt
wc -l notas.txt
```

### 3. Copiar antes de tocar: la regla de oro

Antes de editar una configuración se hace una copia:

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

`cp` no copia directorios sin `-r` (recursivo).

### 4. Mover y renombrar

```bash
mv notas.txt apuntes.txt       # renombrar
mv apuntes.txt backups/        # mover
mv backups/apuntes.txt .       # volver aquí (. = directorio actual)
ls
```

### 5. Leer archivos grandes

```bash
cat /etc/services | wc -l
head -n 15 /etc/services
tail -n 5 /etc/services
less /etc/services             # busca /ssh, pulsa n para la siguiente coincidencia, q para salir
```

### 6. `tail -f`: un log en directo

Abre **dos terminales** en `labs/clase-03`.

Terminal 1:
```bash
tail -f app.log
```
Terminal 2:
```bash
echo "$(date) usuario entró" >> app.log
echo "$(date) ERROR: base de datos no responde" >> app.log
```

Las líneas aparecen en la terminal 1 en cuanto se escriben. Así se sigue un servicio en producción mientras reproduces un fallo. Sal con `Ctrl+C`.

### 7. Comodines

```bash
touch dia1.txt dia2.txt dia3.txt dia10.txt informe.pdf
echo *.txt
echo dia?.txt
echo dia[12].txt
echo *.csv
```

🔮 **Predice:** ¿qué imprimirá `echo *.csv` si no hay ningún `.csv`?

Si nada coincide, bash deja el patrón **tal cual**. Un `rm *.csv` sin coincidencias intentaría borrar un archivo llamado literalmente `*.csv`.

### 8. Empaquetar y comprimir: `tar` y `gzip`

Un **tarball** (`.tar.gz`) es un solo archivo que contiene muchos, comprimido. Es el formato de los backups, de los logs viejos (`.gz`) y de buena parte del software que descargarás.

| Comando | Qué hace |
|---------|----------|
| `tar czf copia.tar.gz carpeta/` | **c**rea un archivo comprimido con g**z**ip (**f** = nombre del archivo) |
| `tar tzf copia.tar.gz` | lis**t**a el contenido **sin** extraer |
| `tar xzf copia.tar.gz -C destino/` | e**x**trae dentro de `destino/` |
| `gzip archivo` / `gunzip archivo.gz` | comprime / descomprime un solo archivo (reemplaza el original) |
| `zcat`, `zless`, `zgrep` | leen un `.gz` sin descomprimirlo |

```bash
tar czf backup-config-$(date +%F).tar.gz config/
ls -lh *.tar.gz
tar tzf backup-config-*.tar.gz
mkdir -p restaurado && tar xzf backup-config-*.tar.gz -C restaurado/
tree restaurado

cp /etc/services servicios.txt && gzip servicios.txt
ls -lh servicios.txt.gz
zgrep -c tcp servicios.txt.gz
```

🔮 **Predice:** ¿cuánto ocupará `servicios.txt.gz` comparado con el original (`ls -lh /etc/services`)? El texto se comprime muy bien: por eso los logs rotados se guardan en `.gz`.

> Truco para recordar `tar`: **c**rear, **x**traer, lis**t**ar, siempre con **f**ile. `z` = gzip.

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

En `labs/clase-03/reto/`, sin mirar arriba, en la terminal. En tus notas, marca cada punto con ✅ o ❌ al compararlo con la solución. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** Crea `logs/2026/10/` de un solo comando.

<details>
<summary>Pista</summary>

`mkdir` con la opción que crea toda la ruta de una vez.
</details>

**2.** Crea `web-1.log`, `web-2.log`, `web-3.log` y `db.log` dentro de `logs/2026/10/`.

<details>
<summary>Pista</summary>

`touch` acepta varios nombres en el mismo comando: `touch ruta/a ruta/b`.
</details>

**3.** Mueve solo los `web-*.log` a `logs/web/` (créalo). Antes, comprueba el patrón con `echo`.

<details>
<summary>Pista</summary>

Primero `mkdir -p logs/web`. El patrón es `logs/2026/10/web-*.log`: pruébalo con `echo` y, si salen los tres, cambia `echo` por `mv` y añade el destino al final.
</details>

**4.** Haz una copia de seguridad de toda la carpeta `logs` como `logs.bak`, conservando fechas y permisos.

<details>
<summary>Pista</summary>

`cp` copia carpetas con `-r`. La opción que además conserva fechas y permisos es `-a` (y ya incluye `-r`).
</details>

**5.** Borra `logs/2026` entero y comprueba que `logs.bak` sigue intacta.

<details>
<summary>Pista</summary>

`rm -r` borra una carpeta con todo lo que tiene. Después, `tree logs.bak`.
</details>

**6.** Empaqueta `logs.bak` en `logs-<fecha de hoy>.tar.gz`, lista su contenido **sin** extraerlo y extráelo dentro de una carpeta `restore/`.

<details>
<summary>Pista</summary>

La tabla de `tar` de la práctica 8: **c** crear, **t** listar, **x** extraer, siempre con **z** y **f**. La fecha de hoy la da `$(date +%F)`, como en esa misma práctica. Para extraer en otra carpeta: créala y añade `-C restore/`.
</details>

## Cierre

En `notas/fase-1/clase-03.md`:

1. Diferencia entre `>` y `>>` al escribir en un archivo (adelanto de la clase 04: ya lo usaste en la práctica). Pon un ejemplo de un archivo de un servidor real que `>` destrozaría.
2. ¿Por qué `echo patrón` antes de `rm patrón` es buena idea? ¿Quién expande el `*`?
3. ¿Para qué sirve `tail -f` en operaciones? Describe una situación concreta.
4. **Repaso (clase 02, sin mirar):** desde `/var/log/nginx`, ¿a dónde te lleva `cd ../..`? ¿Y `cd /`?

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
