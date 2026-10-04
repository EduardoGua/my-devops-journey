# Clase 25 — Git por dentro

**Dónde:** tu Ubuntu · **Tiempo:** 90 min · **Bloque:** D. Git y GitHub

## Objetivo

- Entender las **tres zonas** de Git (directorio de trabajo, *staging* y repositorio) y moverte entre ellas.
- Saber qué es realmente un **commit**, una **rama** y `HEAD`, mirando dentro de `.git`.
- Deshacer con seguridad: `restore`, `reset`, `revert` y el salvavidas `reflog`.
- Escribir commits que tu equipo agradezca.

## Por qué importa

En DevOps **todo** vive en Git: el código, los Dockerfiles, los pipelines, la infraestructura (Terraform) y los manifiestos de Kubernetes. *GitOps* despliega a partir de commits. Quien entiende Git por dentro no entra en pánico ante un merge raro o un commit perdido, y sabe por qué borrar un secreto del último commit **no** lo elimina.

Llevas usando la receta `add` / `commit` / `push` desde la clase 01. Hoy aprendes qué hace.

## Teoría

### Las tres zonas

```
  Directorio de trabajo        Staging (índice)            Repositorio (.git)
  (tus archivos)               (lo que irá en el commit)   (historia, inmutable)
        │      git add  ──────────►   │      git commit ─────────►  │
        │  ◄────── git restore        │  ◄── git restore --staged   │
        │  ◄──────────────────── git restore --source=<commit> ──── │
```

`git status` te dice en qué zona está cada cambio. **El staging** te permite elegir qué entra en un commit: puedes cambiar 5 archivos y hacer 2 commits con sentido.

### Qué es un commit

Una **instantánea completa** del proyecto (no un "diff"), más:
- autor, fecha y mensaje,
- un puntero al commit **padre** (o dos, en un merge),
- un identificador: el **hash SHA** de todo su contenido.

Si cambias **un solo bit** del contenido, del mensaje o de un padre, el hash cambia. Por eso la historia de Git es **inmutable**: "modificar" un commit en realidad **crea uno nuevo**.

### Ramas y HEAD: solo punteros

```
          A ◄── B ◄── C          ← commits (cada uno apunta a su padre)
                      ▲
                     main        ← una rama es un archivo con un hash: .git/refs/heads/main
                      ▲
                     HEAD        ← "dónde estoy": normalmente apunta a una rama
```

Crear una rama es crear un archivo de 41 bytes. Por eso en Git las ramas son baratas y se usan para todo.

### Deshacer: qué herramienta para qué

| Situación | Comando | ¿Reescribe la historia? |
|-----------|---------|------------------------|
| Descartar cambios **no añadidos** de un archivo | `git restore archivo` | no (¡pero pierdes ese cambio!) |
| Sacar algo del staging | `git restore --staged archivo` | no |
| Corregir el **último** commit (mensaje o un archivo olvidado), **antes de hacer push** | `git commit --amend` | sí |
| Volver la rama a un commit anterior, **solo en local** | `git reset --hard <hash>` | sí |
| Deshacer un commit **ya publicado** | `git revert <hash>` (crea un commit inverso) | **no**: la opción segura en equipo |
| "Perdí algo" | `git reflog` | — |

Regla de oro: **no reescribas historia que ya has compartido** (`push`). Usa `revert`.

### Un buen mensaje de commit

```
Añade health check al servicio backend          ← resumen: imperativo, ≤ 50 caracteres

El ALB necesita un endpoint que compruebe       ← cuerpo (opcional): el PORQUÉ, no el qué
también la conexión a la base de datos.
```

❌ `cambios`, `fix`, `asdf`, `actualizo cosas`. ✅ `Corrige permisos de /srv/miapp para appsvc`.

## Práctica guiada

Trabaja **fuera** de tu repo del curso, para no meter un repositorio dentro de otro:

```bash
mkdir -p ~/git-lab && cd ~/git-lab
rm -rf practica && mkdir practica && cd practica
git init -b main
git config user.name >/dev/null || git config --global user.name "Eduardo"
git config user.email >/dev/null || echo "Configura tu email: git config --global user.email ..."
```

### 1. Las tres zonas

```bash
echo "# Mi servidor" > README.md
echo "server_port=80" > app.conf
git status
git add README.md
git status
```

🔮 **Predice:** ¿en qué zona está cada archivo ahora?

```bash
git commit -m "Añade README"
git status
git add app.conf && git commit -m "Añade configuración inicial"
git log --oneline
```

### 2. Diferencias en cada zona

```bash
echo "server_port=8080" > app.conf
git diff                    # trabajo vs staging
git add app.conf
git diff                    # vacío: ya no hay diferencia entre trabajo y staging
git diff --staged           # staging vs último commit
git commit -m "Cambia el puerto a 8080 para no requerir root"
```

### 3. Mira dentro de `.git`

```bash
ls .git
cat .git/HEAD
cat .git/refs/heads/main
git log --oneline -1
```

El contenido de `refs/heads/main` es el hash del último commit: **eso es una rama**.

```bash
git cat-file -p HEAD                 # el commit: tree, parent, autor, mensaje
git cat-file -p HEAD^{tree}          # el árbol: archivos y sus blobs
git cat-file -p $(git rev-parse HEAD:app.conf)   # el contenido de app.conf en ese commit
```

`HEAD^` o `HEAD~1` es el padre del commit actual.

### 4. Historia útil

```bash
git log --oneline --graph --all
git log -p -1                        # el último commit con su diff
git show HEAD~1                      # un commit concreto
git log --oneline -- app.conf        # solo los commits que tocaron ese archivo
git blame app.conf                   # quién cambió cada línea y en qué commit
```

### 5. `.gitignore`

```bash
echo "secreto=1234" > .env
echo "log de prueba" > app.log
git status
printf ".env\n*.log\n" > .gitignore
git status
git add .gitignore && git commit -m "Ignora secretos y logs"
```

Mira el `.gitignore` de tu repo del curso: `cat ~/my-devops-journey/.gitignore`. Ahora sabes por qué está cada línea.

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

Los commits "perdidos" siguen en `.git` durante semanas. Casi nada se pierde de verdad en Git **si llegó a hacerse commit**. Lo que nunca llegó a un commit (el paso 1 con cambios sin guardar), sí se pierde.

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

1. En `practica`, cambia dos archivos y haz **dos commits separados** usando el staging (pista: `git add` de uno y commit, luego el otro). ¿Y si quieres añadir solo **parte** de un archivo? Investiga `git add -p`.
2. Corrige el mensaje del último commit con `git commit --amend`. Compara el hash antes y después. ¿Por qué cambia?
3. En **tu repo del curso**, ejecuta `git log --oneline | head -20` y `git shortlog -sn`. ¿Tus mensajes de commit pasarían una revisión? Escribe uno de ejemplo bien hecho para tu próximo cierre.

## Cierre

En `notas/fase-1/clase-25.md`:

1. Explica las tres zonas de Git y qué comando mueve cambios entre ellas.
2. ¿Qué es una rama, físicamente? ¿Y `HEAD`?
3. ¿Por qué `git rm` de un secreto no lo elimina? ¿Qué hay que hacer?
4. **Repaso (clase 24, sin mirar):** a través de un proxy, ¿qué te indica un error rápido (refused) frente a uno lento (timeout)?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Directorio de trabajo**: los archivos tal como los editas. **Staging (índice)**: lo que preparas para el próximo commit. **Repositorio**: los commits guardados en `.git`. `git add` pasa del trabajo al staging, `git commit` del staging al repositorio, `git restore --staged` saca algo del staging, `git restore` descarta cambios del directorio de trabajo, y `git restore --source=<commit>` recupera la versión de un commit.

**2.** Una rama es un archivo en `.git/refs/heads/` que contiene el hash de un commit: un **puntero** que avanza con cada commit nuevo. `HEAD` es el puntero a "dónde estás": normalmente apunta a una rama (`ref: refs/heads/main`); en *detached HEAD*, apunta directamente a un commit.

**3.** Porque `git rm` crea un commit **nuevo** sin el archivo, pero los commits anteriores (inmutables) lo siguen conteniendo, y ya pueden estar en clones, forks o en caché de GitHub. Hay que **rotar** el secreto (invalidarlo y emitir uno nuevo), revisar si se usó, y después limpiar la historia (`git filter-repo` o BFG) y forzar el push, avisando al equipo.

**4.** Refused (rápido): se llegó a la máquina del backend, pero nadie escucha en ese puerto e IP (servicio parado, escucha en 127.0.0.1, puerto equivocado). Timeout (lento): algo descarta los paquetes (firewall o security group), no hay ruta o la máquina está apagada.

**Reto 2:** el hash cambia porque `--amend` **no modifica** el commit: crea uno nuevo con otro mensaje y otro contenido, y el hash depende de todo eso. Por eso no se hace `--amend` de algo ya publicado.
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

[Clase 26 — Ramas, merge y conflictos](clase-26-ramas-y-conflictos.md)
