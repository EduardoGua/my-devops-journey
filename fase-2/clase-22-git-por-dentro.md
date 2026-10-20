# Clase 22 — Git por dentro

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Git y GitHub

> 💡 **La idea de hoy:** un **commit** es una foto completa de tu proyecto, con un identificador (el **hash**) calculado a partir de todo su contenido. Una **rama** es solo un puntero a uno de esos commits. Entre tus archivos y la historia hay una zona intermedia, el **staging**, donde eliges qué entra en cada commit. Como un commit nunca se modifica, casi todo se puede recuperar… y un secreto que entró en un commit sigue ahí aunque lo borres después.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La receta `git add` / `git commit` / `git push` de `COMO-ESTUDIAR.md`, que llevas usando desde la clase 01 al cerrar cada clase.
> - `ls -a` para ver los archivos ocultos, como `.git` (clase 02).
> - Lo que se hace con una llave filtrada: revocar, reemplazar y revisar (clase 15).

> 🔤 **Palabras nuevas de hoy:**
> - **repositorio**: la carpeta `.git`, donde Git guarda toda la historia del proyecto.
> - **commit**: una foto guardada del proyecto, con autor, fecha, mensaje y su padre.
> - **staging** (o **índice**): la lista de cambios que entrarán en el próximo commit.
> - **hash**: el identificador de un commit (`a1b2c3d…`), calculado a partir de su contenido.
> - **rama**: un puntero con nombre a un commit; avanza sola con cada commit nuevo.
> - **HEAD**: el puntero a «dónde estás ahora», normalmente una rama.

## Objetivo

- Entender las **tres zonas** de Git (directorio de trabajo, *staging* y repositorio) y moverte entre ellas.
- Saber qué es realmente un **commit**, una **rama** y `HEAD`, mirando dentro de `.git`.
- Deshacer con seguridad: `restore`, `reset`, `revert` y el salvavidas `reflog`.
- Escribir commits que tu equipo agradezca.

## Por qué importa

En DevOps **todo** vive en Git: el código, los Dockerfiles, los pipelines, la infraestructura (Terraform) y los manifiestos de Kubernetes. *GitOps* despliega a partir de commits. Quien entiende Git por dentro no entra en pánico ante un merge raro o un commit perdido, y sabe por qué borrar un secreto del último commit **no** lo elimina.

Llevas usando la receta `add` / `commit` / `push` desde la clase 01. Hoy aprendes qué hace.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea (en la 3 y la 4, dos que van juntas) y la pruebas enseguida en un repositorio de prácticas; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 40 min); el segundo, las **piezas 4 a 6**, el Rómpelo, el reto y el cierre.

Trabaja **fuera** de tu repo del curso, para no meter un repositorio dentro de otro:

```bash
mkdir -p ~/git-lab && cd ~/git-lab
rm -rf practica && mkdir practica && cd practica
git init -b main
git config user.name >/dev/null || git config --global user.name "Eduardo"
git config user.email >/dev/null || echo "Configura tu email: git config --global user.email ..."
```

👀 **Qué deberías ver:** `Inicializado repositorio Git vacío en …/practica/.git/` (o su versión en inglés). Si sale el aviso del email, configúralo antes de seguir.

## Las piezas

### Pieza 1 — Las tres zonas

```
  Directorio de trabajo        Staging (índice)            Repositorio (.git)
  (tus archivos)               (lo que irá en el commit)   (historia, inmutable)
        │      git add  ──────────►   │      git commit ─────────►  │
        │  ◄────── git restore        │  ◄── git restore --staged   │
        │  ◄──────────────────── git restore --source=<commit> ──── │
```

`git status` te dice en qué zona está cada cambio. **El staging** te permite elegir qué entra en un commit: puedes cambiar 5 archivos y hacer 2 commits con sentido.

**Pruébalo:**

```bash
echo "# Mi servidor" > README.md
echo "server_port=80" > app.conf
git status
git add README.md
git status
```

🔮 **Predice:** ¿en qué zona está cada archivo ahora?

<details>
<summary>Compruébalo</summary>

`README.md` está en el staging (`Cambios a ser confirmados`) y `app.conf` sigue solo en el directorio de trabajo (`Archivos sin seguimiento`).
</details>

```bash
git commit -m "Añade README"
git status
git add app.conf && git commit -m "Añade configuración inicial"
git log --oneline
```

👀 **Qué deberías ver:** después del primer commit, `git status` solo menciona `app.conf`; al final, `git log --oneline` muestra dos commits, cada uno con su hash corto y su mensaje.

✋ **Sin mirar:** cambias cinco archivos, pero quieres hacer dos commits con sentido. ¿Qué zona te lo permite y con qué comando eliges?

<details>
<summary>Comprueba</summary>

El staging: con `git add` eliges qué archivos entran en cada commit.
</details>

**En resumen:** directorio de trabajo → `git add` → staging → `git commit` → repositorio. `git status` te dice dónde está cada cambio.

### Pieza 2 — Ver las diferencias de cada zona

`git diff` compara el directorio de trabajo con el staging: lo que **aún no** has añadido. `git diff --staged` compara el staging con el último commit: lo que **va a entrar** en el próximo.

**Pruébalo:**

```bash
echo "server_port=8080" > app.conf
git diff                    # trabajo vs staging
git add app.conf
git diff                    # vacío: ya no hay diferencia entre trabajo y staging
git diff --staged           # staging vs último commit
git commit -m "Cambia el puerto a 8080 para no requerir root"
```

👀 **Qué deberías ver:** en el primer `git diff`, `-server_port=80` y `+server_port=8080`; después del `add`, el segundo `git diff` no muestra nada y el `--staged` muestra el mismo cambio.

**En resumen:** `git diff` = lo que aún no añadiste; `git diff --staged` = lo que entrará en el commit.

### Pieza 3 — Qué es un commit y qué es una rama, mirando dentro de `.git`

Un commit es una **instantánea completa** del proyecto (no un "diff"), más:
- autor, fecha y mensaje,
- un puntero al commit **padre** (o dos, en un merge),
- un identificador: el **hash SHA** de todo su contenido.

Si cambias **un solo bit** del contenido, del mensaje o de un padre, el hash cambia. Por eso la historia de Git es **inmutable**: "modificar" un commit en realidad **crea uno nuevo**.

Y una rama es solo un puntero:

```
          A ◄── B ◄── C          ← commits (cada uno apunta a su padre)
                      ▲
                     main        ← una rama es un archivo con un hash: .git/refs/heads/main
                      ▲
                     HEAD        ← "dónde estoy": normalmente apunta a una rama
```

Crear una rama es crear un archivo de 41 bytes. Por eso en Git las ramas son baratas y se usan para todo.

**Pruébalo:**

```bash
ls .git
cat .git/HEAD
cat .git/refs/heads/main
git log --oneline -1
```

👀 **Qué deberías ver:** `HEAD` contiene `ref: refs/heads/main`, y `refs/heads/main` contiene un hash largo que **empieza igual** que el del último commit de `git log`: **eso es una rama**.

Ahora, el commit por dentro:

```bash
git cat-file -p HEAD                 # el commit: tree, parent, autor, mensaje
git cat-file -p HEAD^{tree}          # el árbol: archivos y sus blobs
git cat-file -p $(git rev-parse HEAD:app.conf)   # el contenido de app.conf en ese commit
```

👀 **Qué deberías ver:** el commit con sus líneas `tree`, `parent`, `author` y el mensaje; el árbol con `README.md` y `app.conf`, cada uno con su hash (`blob`); y `server_port=8080`.

`HEAD^` o `HEAD~1` es el padre del commit actual.

**En resumen:** un commit es una foto completa con un hash que depende de todo su contenido; una rama es un archivo con el hash de un commit, y `HEAD` apunta a la rama en la que estás.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana vuelve con `cd ~/git-lab/practica`.

### Pieza 4 — Leer la historia, y escribirla bien

La historia sirve para responder preguntas: qué cambió, cuándo y por qué. Por eso cada commit necesita un buen mensaje:

```
Añade health check al servicio backend          ← resumen: imperativo, ≤ 50 caracteres
                                                 
El ALB necesita un endpoint que compruebe       ← cuerpo (opcional): el PORQUÉ, no el qué
también la conexión a la base de datos.
```

❌ `cambios`, `fix`, `asdf`, `actualizo cosas`. ✅ `Corrige permisos de /srv/miapp para appsvc`.

**Pruébalo:**

```bash
git log --oneline --graph --all
git log -p -1                        # el último commit con su diff
git show HEAD~1                      # un commit concreto
git log --oneline -- app.conf        # solo los commits que tocaron ese archivo
git blame app.conf                   # quién cambió cada línea y en qué commit
```

👀 **Qué deberías ver:** tus tres commits en una línea (`--graph` aún no dibuja ramas: solo hay una); el último con su diff; el penúltimo; los dos commits que tocaron `app.conf`; y `server_port=8080` con el hash del commit que lo cambió y tu nombre.

**En resumen:** `git log`, `git show` y `git blame` responden qué, cuándo y quién; el mensaje del commit responde por qué.

### Pieza 5 — `.gitignore`: lo que nunca debe entrar

Algunos archivos no deben llegar nunca a un commit: secretos (`.env`), logs, entornos virtuales o el estado de Terraform. `.gitignore` es una lista de nombres y patrones que Git ignora: no los propone en `git status` ni entran con `git add .`.

**Pruébalo:**

```bash
echo "secreto=1234" > .env
echo "log de prueba" > app.log
git status
printf ".env\n*.log\n" > .gitignore
git status
git add .gitignore && git commit -m "Ignora secretos y logs"
```

👀 **Qué deberías ver:** primero, `.env` y `app.log` como archivos sin seguimiento; después del `.gitignore`, solo `.gitignore`.

Mira el `.gitignore` de tu repo del curso: `cat ~/my-devops-journey/.gitignore`. Ahora sabes por qué está cada línea.

**En resumen:** lo que está en `.gitignore` no entra en los commits; los secretos van ahí **antes** del primer `git add`.

### Pieza 6 — Deshacer: qué herramienta para qué

| Situación | Comando | ¿Reescribe la historia? |
|-----------|---------|------------------------|
| Descartar cambios **no añadidos** de un archivo | `git restore archivo` | no (¡pero pierdes ese cambio!) |
| Sacar algo del staging | `git restore --staged archivo` | no |
| Corregir el **último** commit (mensaje o un archivo olvidado), **antes de hacer push** | `git commit --amend` | sí |
| Volver la rama a un commit anterior, **solo en local** | `git reset --hard <hash>` | sí |
| Deshacer un commit **ya publicado** | `git revert <hash>` (crea un commit inverso) | **no**: la opción segura en equipo |
| "Perdí algo" | `git reflog` | — |

Regla de oro: **no reescribas historia que ya has compartido** (`push`). Usa `revert`.

**Pruébalo** con las dos primeras filas. El resto (`reset`, `reflog` y `revert`) lo provocas en el Rómpelo.

```bash
echo "una línea que sobra" >> README.md
git add README.md
git status                   # en el staging
git restore --staged README.md
git status                   # fuera del staging, pero el cambio sigue en el archivo
git restore README.md
git status                   # limpio
cat README.md
```

👀 **Qué deberías ver:** el cambio en `Cambios a ser confirmados`; después, en `Cambios no rastreados para el commit`; al final, `nada para hacer commit` y `README.md` sin la línea que sobraba.

**En resumen:** `restore --staged` saca del staging, `restore` descarta el cambio, `revert` deshace en público y `reflog` encuentra lo perdido.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `git init -b main` | crear un repositorio con la rama `main` |
| `git status` | en qué zona está cada cambio |
| `git add archivo` · `git commit -m "…"` | al staging · del staging al repositorio |
| `git diff` · `git diff --staged` | lo que aún no añadiste · lo que entrará en el commit |
| `git log --oneline --graph --all` · `git show <hash>` | la historia · un commit concreto |
| `git log -- archivo` · `git blame archivo` | los commits de un archivo · quién cambió cada línea |
| `git cat-file -p HEAD` | un commit por dentro |
| `git restore archivo` · `git restore --staged archivo` | descartar un cambio · sacarlo del staging |
| `git commit --amend` | rehacer el último commit (solo si no hiciste push) |
| `git reset --hard <hash>` · `git revert <hash>` | volver atrás en local · deshacer en público |
| `git reflog` | todos los sitios donde ha estado `HEAD` |

## Rómpelo

**1. Recuperar un archivo borrado:**
```bash
rm README.md
git status
git restore README.md
cat README.md
```

**2. Un secreto en un commit:**
```bash
echo "AWS_SECRET_ACCESS_KEY=abc123-esto-es-un-ejemplo" > credenciales.txt
git add credenciales.txt && git commit -m "Añade configuración"
git rm credenciales.txt && git commit -m "Quita credenciales"
ls credenciales.txt 2>/dev/null || echo "ya no está en la carpeta"
git log --oneline
git show HEAD~1:credenciales.txt
```

🔮 Antes de la última línea: ¿podrás ver el secreto?

**Sí.** El commit anterior sigue teniéndolo, y cualquiera que clone el repo puede verlo. Por eso un secreto que llega a un repo (sobre todo si se hizo `push`) se **rota**: se invalida y se genera otro. Limpiar la historia (con `git filter-repo`) es un paso posterior y no basta por sí solo. Lo mismo que con la llave SSH de la clase 15.

**3. Perder commits y recuperarlos:**
```bash
git log --oneline
git reset --hard HEAD~3
git log --oneline              # ¡faltan 3 commits!
git reflog
```

`reflog` es el diario de **todos** los sitios donde ha estado `HEAD`, incluidos los commits que ya no están en ninguna rama. Busca el hash de "Quita credenciales" y vuelve:
```bash
git reset --hard <hash>
git log --oneline
```

Los commits "perdidos" siguen en `.git` durante semanas. Casi nada se pierde de verdad en Git **si llegó a hacerse commit**. Lo que nunca llegó a un commit (como el cambio que descartaste con `git restore` en la pieza 6), sí se pierde.

**4. `revert`: deshacer en público:**
```bash
echo "server_port=9999" > app.conf && git commit -am "Puerto 9999"
git revert --no-edit HEAD
git log --oneline -3
cat app.conf
```

Hay un commit nuevo que **invierte** el anterior. La historia queda intacta y es honesta: así se deshace un cambio que ya está en `main` compartido.

**5. HEAD separado (*detached HEAD*):**
```bash
git switch --detach HEAD~2
git status
cat app.conf
git switch main
```

Estabas mirando el pasado sin rama. Si haces commits ahí y te vas, quedan huérfanos (aunque `reflog` los conserva un tiempo).

## Reto

En `~/git-lab/practica`, en la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Cambia `README.md` y `app.conf`, y haz **dos commits separados**: uno con cada archivo.

> 🧩 **Ejemplo resuelto:** tienes un archivo nuevo, `notas.txt`, y otro cambiado, `README.md`, y quieres un commit **solo** con `notas.txt`.
> ```bash
> echo "idea" > notas.txt && echo "otra línea" >> README.md
> git add notas.txt
> git commit -m "Añade notas"
> git status
> ```
> El commit solo lleva `notas.txt`; `git status` sigue mostrando `README.md` como cambiado, esperando su propio commit.

**Ahora tú, con huecos:**
```bash
echo "## Uso" >> README.md && echo "log_level=info" >> app.conf
git add ____ && git commit -m "Documenta el uso"
git add ____ && git commit -m "Añade el nivel de log"
git log --oneline -2
```

<details>
<summary>Pista</summary>

Un archivo en cada `git add`: así el staging solo tiene lo que va en ese commit. Para ir más allá: `git add -p` te deja elegir **partes** de un archivo.
</details>

**2.** Corrige el mensaje del último commit con `git commit --amend` y compara el hash antes y después. ¿Por qué cambia?

> 🧩 **Ejemplo resuelto:** olvidaste un archivo en el último commit.
> ```bash
> git log --oneline -1
> echo "x" > olvidado.txt && git add olvidado.txt
> git commit --amend --no-edit
> git log --oneline -1
> ```
> El commit ya lleva `olvidado.txt`, con el mismo mensaje… y otro hash.

**Ahora tú, con huecos:**
```bash
git log --oneline -1
git commit --amend -m "____"
git log --oneline -1
```

<details>
<summary>Pista</summary>

Relee la pieza 3: ¿de qué depende el hash de un commit? ¿El mensaje forma parte de ese contenido?
</details>

**3.** En **tu repo del curso**, mira tus mensajes de commit: ¿pasarían una revisión?

> 🧩 **Ejemplo resuelto:** un mensaje malo y su versión buena.
> ```bash
> cd ~/my-devops-journey
> git log --oneline | head -20
> git shortlog -sn
> ```
> `actualizo cosas` no dice nada; `Clase 05: cierre, reto y labs de buscar y filtrar` dice qué cambió, y en menos de 50 caracteres si quitas los labs.

**Ahora tú, con huecos:** escribe en tu nota el mensaje de tu próximo commit: `Clase 22: ____`

<details>
<summary>Pista</summary>

Qué cambió, no cómo te fue: «Clase 22: cierre y reto de Git por dentro». En imperativo o descriptivo, corto y sin «cambios» ni «fix».
</details>

## Cierre

En `notas/fase-2/clase-22.md`:

1. Explica las tres zonas de Git y qué comando mueve cambios entre ellas. *(3 líneas, una por zona. Empieza así: «El directorio de trabajo son… y `git add` lo pasa al… El staging es… y `git commit`… El repositorio…»)*
2. ¿Qué es una rama, físicamente? ¿Y `HEAD`? *(2 líneas. Empieza así: «Una rama es un archivo en `.git/refs/heads/` que contiene… `HEAD` es…»)*
3. ¿Por qué `git rm` de un secreto no lo elimina? ¿Qué hay que hacer? *(2–3 líneas. Empieza así: «Porque `git rm` crea un commit nuevo, pero los anteriores… Hay que rotar el secreto…»)*
4. **Repaso (clase 21, sin mirar):** en Vigía, ¿por qué una URL caída no detiene el script, aunque uses `set -e`? *(2 líneas. Empieza así: «Porque el fallo de `curl` se trata dentro de un `if` o con `|| true`, y ahí `set -e`…»)*

Después, escríbeme `examíname clase-22`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Directorio de trabajo**: los archivos tal como los editas. **Staging (índice)**: lo que preparas para el próximo commit. **Repositorio**: los commits guardados en `.git`. `git add` pasa del trabajo al staging, `git commit` del staging al repositorio, `git restore --staged` saca algo del staging, `git restore` descarta cambios del directorio de trabajo, y `git restore --source=<commit>` recupera la versión de un commit.

**2.** Una rama es un archivo en `.git/refs/heads/` que contiene el hash de un commit: un **puntero** que avanza con cada commit nuevo. `HEAD` es el puntero a "dónde estás": normalmente apunta a una rama (`ref: refs/heads/main`); en *detached HEAD*, apunta directamente a un commit.

**3.** Porque `git rm` crea un commit **nuevo** sin el archivo, pero los commits anteriores (inmutables) lo siguen conteniendo, y ya pueden estar en clones, forks o en caché de GitHub. Hay que **rotar** el secreto (invalidarlo y emitir uno nuevo), revisar si se usó, y después limpiar la historia (`git filter-repo` o BFG) y forzar el push, avisando al equipo.

**4.** Porque el fallo se trata de forma explícita: el resultado de `curl` se captura con `|| true` (o dentro de un `if`), y la función que revisa cada URL se llama a la izquierda de `||` o en la condición de un `if`. En esas posiciones `set -e` no actúa, así que la caída queda registrada como `DOWN` y el script sigue con las demás URLs.

**Reto:**
```bash
git add README.md && git commit -m "Documenta el uso"
git add app.conf && git commit -m "Añade el nivel de log"
git commit --amend -m "Añade el nivel de log a la configuración"
```
**Reto 2:** el hash cambia porque `--amend` **no modifica** el commit: crea uno nuevo con otro mensaje y otro contenido, y el hash depende de todo eso. Por eso no se hace `--amend` de algo ya publicado.
**Reto 3:** por ejemplo, `Clase 22: cierre y reto de Git por dentro`.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| working tree | directorio de trabajo |
| staging area / index | área de preparación |
| commit hash | identificador del commit |
| to revert / to reset | revertir / restablecer |
| to rewrite history | reescribir la historia |

🎙️ *"For a change that's already been pushed I use `git revert`, which adds an inverse commit, instead of rewriting shared history."*

## Siguiente

[Clase 23 — Ramas, merge y conflictos](clase-23-ramas-y-conflictos.md)
