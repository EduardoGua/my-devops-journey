# Clase 24 — GitHub y pull requests

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 75 min · **Bloque:** A. Git y GitHub

> 💡 **La idea de hoy:** tu repositorio tiene una copia en GitHub, el **remoto** (`origin`). Con `push` subes tus commits y con `fetch` o `pull` traes los de los demás. En un equipo, ningún cambio entra en `main` directamente: va en una rama, se sube y se abre un **pull request** (PR), donde se revisa y se prueba antes de fusionarlo.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Ramas, merge y conflictos (clase 23).
> - `--amend` y `reset` reescriben la historia; `revert` no (clase 22).
> - Tu llave SSH y `~/.ssh/config` (clase 15): GitHub te reconoce con ella.

> 🔤 **Palabras nuevas de hoy:**
> - **remoto**: la copia del repositorio en otro sitio, como GitHub; el de por defecto se llama `origin`.
> - **`origin/main`**: tu copia local de cómo estaba `main` en GitHub la última vez que hablaste con él.
> - **upstream**: la rama remota enlazada a tu rama local.
> - **pull request (PR)**: la petición de fusionar tu rama, con su descripción, su revisión y sus comprobaciones.
> - **squash**: juntar todos los commits de un PR en uno solo al fusionarlo.
> - **ruleset**: las reglas de GitHub que protegen una rama, como `main`.

## Objetivo

- Entender los **remotos**: `clone`, `fetch`, `pull`, `push` y el seguimiento entre ramas.
- Hacer el ciclo profesional completo: **rama → push → pull request → revisión → merge → limpieza**.
- Proteger `main` para que nadie (ni tú) pueda saltarse el PR.
- Resolver un push rechazado porque otra persona cambió el remoto.

## Por qué importa

Así se trabaja en cualquier equipo. Y en DevOps, el pull request es además **el punto de control antes del despliegue**: en el PR se ejecutan los tests y el `terraform plan`, alguien revisa, y al fusionar en `main` el pipeline despliega (fases 7 y 8). Tu GitHub también es tu **CV técnico**: los reclutadores miran tus repos, tus README y tu historial de commits.

## Cómo va esta clase

Tres piezas, y después un Rómpelo largo con los problemas que verás en cualquier equipo. En cada pieza lees **una** idea y la pruebas enseguida con un repositorio de prácticas en GitHub; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, el Rómpelo, el reto y el cierre.

Primero, tres comprobaciones:

```bash
gh auth status
cd ~/my-devops-journey && git remote -v && cd -
git config --global pull.rebase false
```

👀 **Qué deberías ver:** `Logged in to github.com account …`; tu repo del curso con un `origin` del tipo `git@github.com:…` (dos líneas, `fetch` y `push`); y nada en la tercera.

La última línea le dice a `git pull` que, si tu rama y la remota han divergido, las **fusione** (merge). Sin esa configuración, las versiones modernas de Git se niegan a hacer `pull` en ese caso y te piden que elijas (`fatal: Need to specify how to reconcile divergent branches`). Algunos equipos prefieren `pull.rebase true`; para empezar, merge es lo más seguro.

## Las piezas

### Pieza 1 — Local y remoto

```
     Tu PC                                          GitHub ("origin")
  ┌─────────────────────────┐                    ┌──────────────────────┐
  │ main  ──── feature/x    │ ── git push ─────► │ main   feature/x     │
  │ origin/main (copia de   │ ◄── git fetch ──── │                      │
  │   lo último que viste)  │                    └──────────────────────┘
  └─────────────────────────┘
       git pull = git fetch + git merge (o rebase) de origin/main en tu main
```

- `origin` es solo el **nombre** del remoto por defecto.
- `origin/main` es tu **copia local** de cómo estaba `main` en GitHub la última vez que hiciste `fetch`. No se actualiza sola.
- `git push -u origin feature/x` sube la rama y la deja **enlazada** (*upstream*), así que después basta con `git push` y `git pull`.

Tu repo del curso usa `git@github.com:...` (SSH, con tu llave de la clase 15). Con HTTPS se usa un *token* en lugar de llave. En CI se usan tokens o *deploy keys*, nunca tu llave personal.

**Pruébalo: un repositorio de práctica en GitHub.**

```bash
cd ~/git-lab
rm -rf pr-lab && mkdir pr-lab && cd pr-lab
git init -b main
cat > README.md <<'EOF'
# pr-lab

Practice repository for pull request workflows.

## Service config

See `app.conf`.
EOF
printf "server_port=8080\n\n# performance\nworkers=2\n" > app.conf
git add . && git commit -m "Initial commit"
gh repo create pr-lab --public --source=. --remote=origin --push
git remote -v
git log --oneline --all
```

👀 **Qué deberías ver:** `✓ Created repository …/pr-lab on GitHub` y el push; `origin` con su dirección; y en el log, tu commit con `(HEAD -> main, origin/main)`: tu copia del remoto, en el mismo commit que tu `main`.

✋ **Sin mirar:** ¿qué hace el `-u` de `git push -u origin feature/x`?

<details>
<summary>Comprueba</summary>

Enlaza tu rama local con la remota (*upstream*): desde ese momento, en esa rama, `git push` y `git pull` saben a dónde ir sin más argumentos.
</details>

**En resumen:** `push` sube, `fetch` trae y `pull` trae y fusiona; `origin/main` es tu copia del remoto, y solo se actualiza cuando hablas con él.

### Pieza 2 — El flujo de un pull request

```
1. git switch -c feature/x         (desde un main actualizado)
2. commits pequeños y con sentido
3. git push -u origin feature/x
4. abrir el PR: qué cambia, por qué, cómo se ha probado
5. revisión (y comprobaciones automáticas en CI) → cambios si hace falta
6. merge (normalmente "squash" o "merge commit")
7. borrar la rama y actualizar main local
```

Tres formas de fusionar un PR en GitHub:

| Opción | Resultado en `main` |
|--------|---------------------|
| Create a merge commit | todos tus commits + un commit de merge |
| **Squash and merge** | **un solo commit** con todo el PR (historial muy limpio, muy usado) |
| Rebase and merge | tus commits uno tras otro, sin commit de merge |

**Pruébalo: el ciclo completo.**

```bash
git switch -c feature/health-check
cat >> README.md <<'EOF'

## Health check

`GET /salud` returns `200 ok` when the service is alive.
EOF
git commit -am "Document the health check endpoint"
git push -u origin feature/health-check
```

Abre el PR desde la terminal:

```bash
gh pr create --title "Document the health check endpoint" \
  --body "## What
Adds a Health check section to the README.

## Why
Load balancers and on-call engineers need to know how to check the service.

## How I tested
Rendered the README on GitHub."
```

Revísalo **en la web** como lo haría un compañero:

```bash
gh pr view --web
```

Mira la pestaña *Files changed*. Deja un comentario en una línea (puedes comentar tu propio PR). Después, fusiónalo con *squash*:

```bash
gh pr merge --squash --delete-branch
git switch main
git pull
git log --oneline --graph --all
```

👀 **Qué deberías ver:** la dirección del PR después de `gh pr create`; y al final, en `main`, **un** commit nuevo con el cambio. La rama se borró en GitHub y en local.

✋ **Sin mirar:** ¿qué opción de merge deja **un solo** commit en `main` por cada PR?

<details>
<summary>Comprueba</summary>

*Squash and merge*.
</details>

**En resumen:** rama → push → PR con qué, por qué y cómo se probó → revisión → squash → borrar la rama y `git pull` en `main`.

### Pieza 3 — Proteger `main`

Si `main` no está protegida, cualquiera (tú incluido) puede saltarse el PR con un `push` directo. Un **ruleset** lo impide.

**Pruébalo.** En la web: **Settings → Rules → Rulesets → New ruleset → New branch ruleset**:
- Nombre: `protect-main` · *Enforcement status*: **Active**
- *Target branches*: **Include default branch**
- ✅ *Require a pull request before merging*
- ✅ *Block force pushes*
- **No** añadas a nadie en *Bypass list*: así la regla se aplica también a ti, que eres admin.

(Si usas la pantalla antigua, *Settings → Branches → Add classic branch protection rule*, marca además *Do not allow bypassing the above settings*. Si no, como dueño del repo podrías saltártela sin darte cuenta.)

Intenta saltártela:

```bash
echo "cambio directo" >> README.md
git commit -am "Direct change to main"
git push
```

🔮 **Predice:** ¿qué pasará?

👀 **Qué deberías ver:** GitHub lo **rechaza**, con un mensaje del tipo `GH013: Repository rule violations found` y `Changes must be made through a pull request`. Deshaz ese commit local:

```bash
git reset --hard origin/main
```

En los equipos, `main` siempre está protegida. Un cambio sin revisar no llega a producción.

✋ **Sin mirar:** ¿por qué no te añades a la *Bypass list*, si eres el dueño del repo?

<details>
<summary>Comprueba</summary>

Porque entonces la regla no se aplicaría a ti, y podrías saltarte el PR sin darte cuenta. La protección vale si vale para todos.
</details>

**En resumen:** un ruleset en `main` obliga a pasar por un PR y bloquea los `push --force`, también para ti.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana vuelve con `cd ~/git-lab/pr-lab`.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `git remote -v` | ver los remotos |
| `gh repo create nombre --public --source=. --remote=origin --push` | crear el repo en GitHub y subir lo que tienes |
| `git push -u origin rama` · `git push` | subir una rama y enlazarla · subir, ya enlazada |
| `git fetch` · `git pull` | traer sin tocar tus ramas · traer y fusionar |
| `gh pr create` · `gh pr create --fill` | abrir un PR · abrir uno con el título y el texto de los commits |
| `gh pr view --web` · `gh pr merge --squash --delete-branch` | verlo en la web · fusionarlo en un commit y borrar la rama |
| `git reset --hard origin/main` | dejar tu `main` como la de GitHub (pierdes lo no subido) |
| `git push origin --delete rama` | borrar una rama en GitHub |

## Rómpelo

**1. Push rechazado: el remoto avanzó.**
Pasa constantemente: un compañero (o tú mismo desde la web) añade un commit a **tu** rama mientras trabajas en local.

```bash
git switch main && git pull
git switch -c feature/port
sed -i 's/server_port=8080/server_port=8000/' app.conf
git commit -am "Move service to port 8000"
git push -u origin feature/port
gh pr create --fill
```

Ahora simula al compañero: en la web de GitHub, cambia a la rama `feature/port`, edita `README.md` con el lápiz ✏️ (añade una línea `Port: 8000`) y haz el commit **en esa misma rama**.

Mientras, en tu PC, sin traer nada:

```bash
echo "# timeouts" >> app.conf
git commit -am "Add timeouts section"
git push
```

🔮 **Predice:** ¿qué dirá Git?

Rechazado: `Updates were rejected because the remote contains work that you do not have locally`. Tu rama local y la remota **divergieron**. **No uses `--force`**: borrarías el commit de tu compañero. Trae lo nuevo e intégralo:

```bash
git pull                     # fetch + merge de origin/feature/port
git log --oneline --graph -5
git push
```

Regla: **antes de crear una rama, `git switch main && git pull`**, y antes de seguir trabajando en una rama compartida, `git pull`.

**2. Un conflicto dentro de un PR.**
Crea dos ramas desde el mismo `main` que cambien **la misma línea** del README (por ejemplo, el título). Abre un PR por cada una. Fusiona la primera. La segunda mostrará *This branch has conflicts*. Resuélvelo en local:

```bash
git switch <segunda-rama>
git pull origin main          # trae main y fusiona: aparece el conflicto
# resuelve como en la clase 23, después:
git add README.md && git commit --no-edit && git push
```

El PR se actualiza solo y vuelve a poder fusionarse.

**3. Push protection de secretos.**

```bash
git switch main && git pull && git switch -c test/secret
echo "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" > secret.txt
git add secret.txt && git commit -m "Add config"
git push -u origin test/secret
```

GitHub puede **bloquear el push** si detecta algo con forma de credencial (*push protection*, activada por defecto en repos públicos). Aunque te deje, la lección de las clases 15 y 22 sigue en pie: si un secreto real llega a un remoto, se rota. Limpia:

```bash
git switch main && git branch -D test/secret
git push origin --delete test/secret 2>/dev/null || true
```

## Desde hoy: tu repo del curso como un profesional

A partir de ahora, si quieres, guarda tus cierres con ramas y PRs en `my-devops-journey` (no es obligatorio, pero es buena práctica y deja un historial excelente):

```bash
git switch main && git pull
git switch -c clase-25
# … trabajas, haces commits …
git push -u origin clase-25
gh pr create --fill && gh pr merge --squash --delete-branch
git switch main && git pull
```

## Reto

En `~/git-lab/pr-lab`, cada cambio con su rama y su PR. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Mejora el README de `pr-lab`, en **inglés**, y súbelo con un PR.

> 🧩 **Ejemplo resuelto:** el README de otro repositorio de prácticas.
> ```markdown
> # git-lab
>
> Practice repositories for Git: branches, merges and conflicts.
>
> ## How to use
> 1. `cd practica` and run `git log --oneline --graph --all`.
>
> ## What I learned
> - A branch is just a pointer to a commit.
> ```

**Ahora tú, con huecos:** abre una rama `docs/readme`, deja el README así y ábrele un PR.
```markdown
# pr-lab

Practice repository for ____ workflows on GitHub.

## How to use
1. Create a branch: `git switch -c ____`
2. Push it and open a PR: `gh pr create ____`

## What I learned
- `main` is protected: every change goes through a ____.
```

<details>
<summary>Pista</summary>

Los huecos salen de las piezas 2 y 3: el tipo de flujo, un nombre de rama como `feature/x`, la opción `--fill` y lo que obliga el ruleset.
</details>

**2.** Crea una plantilla de PR con las secciones *What*, *Why* y *How I tested*, y comprueba que aparece sola en el siguiente PR.

> 🧩 **Ejemplo resuelto:** una plantilla mínima, con una sola sección.
> ```bash
> mkdir -p .github
> printf "## What\n\n" > .github/pull_request_template.md
> ```
> GitHub la usa en cada PR nuevo, siempre que el archivo esté ya en `main`.

**Ahora tú, con huecos:**
```bash
git switch main && git pull && git switch -c chore/pr-template
mkdir -p .github
printf "## What\n\n## ____\n\n## ____\n" > .github/pull_request_template.md
git add .github && git commit -m "Add a pull request template"
git push -u origin chore/pr-template && gh pr create --fill && gh pr merge --squash --delete-branch
```
Después, abre otro PR **desde la web** y mira si el cuadro de texto ya trae las tres secciones.

<details>
<summary>Pista</summary>

Las tres secciones son las del PR de la pieza 2. Y la plantilla solo funciona cuando ya está **en `main`**: por eso se fusiona antes de probarla.
</details>

**3.** ¿Qué diferencia hay entre `git fetch` y `git pull`? Demuéstralo con un cambio hecho en la web.

> 🧩 **Ejemplo resuelto:** qué dice `git status` después de un `fetch`.
> ```bash
> git switch main
> git fetch
> git status
> ```
> Si alguien añadió un commit en GitHub, verás `Tu rama está detrás de 'origin/main' por 1 commit`: `fetch` lo trajo a `origin/main`, pero tu `main` no cambió.

**Ahora tú, con huecos:** edita el README **en la web**, directamente en un PR (el ruleset no te deja en `main`), fusiónalo y después:
```bash
git fetch
git log --oneline -1 ____
git log --oneline -1 ____
git pull
git log --oneline -1 main
```

<details>
<summary>Pista</summary>

Compara tu rama `main` con tu copia del remoto, `origin/main`, antes y después del `pull`.
</details>

## Cierre

En `notas/fase-2/clase-24.md`:

1. Describe el flujo completo de un cambio con pull request, del `switch -c` a la limpieza. *(3–4 líneas, en orden. Empieza así: «Actualizo `main` con… Creo una rama con… Hago commits y `git push -u`… Abro el PR con… Tras la revisión, fusiono con… y borro…»)*
2. ¿Qué es `origin/main` y por qué no se actualiza solo? *(2 líneas. Empieza así: «Es mi copia local de cómo estaba… Solo se actualiza cuando…»)*
3. Tu push a `main` es rechazado porque el remoto tiene commits nuevos. ¿Qué haces y qué **no** debes hacer? *(2 líneas. Empieza así: «Traigo los cambios con `git pull`, resuelvo… y vuelvo a… Lo que no hago nunca es…»)*
4. **Repaso (clase 23, sin mirar):** ¿cuál es la regla de oro del rebase? *(1–2 líneas. Empieza así: «No hacer rebase de commits que ya…, porque…»)*

Después, escríbeme `examíname clase-24`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Actualizar `main` (`git switch main && git pull`) → crear una rama (`git switch -c feature/x`) → commits pequeños con buenos mensajes → `git push -u origin feature/x` → abrir el PR explicando qué, por qué y cómo se probó → revisión y comprobaciones automáticas, aplicando los cambios pedidos → merge (normalmente *squash*) → borrar la rama remota y la local, y `git pull` en `main`.

**2.** Es la copia local del estado de la rama `main` del remoto **la última vez que te comunicaste con él** (`fetch`, `pull` o `push`). Git no consulta la red por su cuenta: solo se actualiza cuando lo pides con `git fetch` o `git pull`.

**3.** Traer los cambios del remoto (`git pull`, que integra `origin/main` en tu rama, resolviendo conflictos si los hay) y volver a hacer push. Y en un equipo, lo normal es no hacer push a `main`, sino usar una rama y un PR. Lo que **no** se hace es `git push --force` a una rama compartida: borraría el trabajo de tus compañeros.

**4.** No hacer rebase de commits que ya están compartidos en un remoto (que otros pueden haber descargado), porque el rebase crea commits nuevos y rompe la historia de los demás.

**Reto 1:** `pull request`, una rama como `docs/readme` o `feature/x`, `--fill` y `pull request`.
**Reto 2:** `Why` y `How I tested`.
**Reto 3:** `git log --oneline -1 main` y `git log --oneline -1 origin/main`. `git fetch` solo descarga y actualiza `origin/main`; tu `main` local no cambia hasta el `git pull`, que hace `fetch` y además fusiona `origin/main` en tu rama actual.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| remote / upstream | remoto / rama enlazada |
| pull request (PR) | solicitud de fusión |
| code review | revisión de código |
| squash and merge | fusionar en un solo commit |
| branch protection | protección de rama |
| force push | push forzado |

🎙️ *"Nothing goes straight to main. Every change goes through a pull request with a description, automated checks and at least one review."*

## Fin de las clases de Git

Ya trabajas con Git como en un equipo. Ahora lo aplicas a tu propio proyecto: publicas Vigía.

## Siguiente

[Clase 25 — Proyecto: Vigía v0.1](clase-25-vigia-v0.1.md)
