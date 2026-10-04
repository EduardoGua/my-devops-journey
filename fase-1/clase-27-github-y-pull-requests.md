# Clase 27 — GitHub y pull requests

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 75 min · **Bloque:** D. Git y GitHub

## Objetivo

- Entender los **remotos**: `clone`, `fetch`, `pull`, `push` y el seguimiento entre ramas.
- Hacer el ciclo profesional completo: **rama → push → pull request → revisión → merge → limpieza**.
- Proteger `main` para que nadie (ni tú) pueda saltarse el PR.
- Resolver un push rechazado porque otra persona cambió el remoto.

## Por qué importa

Así se trabaja en cualquier equipo. Y en DevOps, el pull request es además la **puerta del despliegue**: en el PR se ejecutan los tests y el `terraform plan`, alguien revisa, y al fusionar en `main` el pipeline despliega (fases 4 y 6). Tu GitHub también es tu **CV técnico**: los reclutadores miran tus repos, tus README y tu historial de commits.

## Teoría

### Local y remoto

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

### El flujo de un pull request

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

### SSH frente a HTTPS

Tu repo del curso usa `git@github.com:...` (SSH, con tu llave de la clase 15). Con HTTPS se usa un *token* en lugar de llave. En CI se usan tokens o *deploy keys*, nunca tu llave personal.

## Práctica guiada

### 1. Comprobaciones

```bash
gh auth status
cd ~/my-devops-journey && git remote -v && cd -
git config --global pull.rebase false
```

La última línea le dice a `git pull` que, si tu rama y la remota han divergido, las **fusione** (merge). Sin esa configuración, las versiones modernas de Git se niegan a hacer `pull` en ese caso y te piden que elijas (`fatal: Need to specify how to reconcile divergent branches`). Algunos equipos prefieren `pull.rebase true`; para empezar, merge es lo más seguro.

### 2. Un repositorio de práctica en GitHub

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

Fíjate en `origin/main` en el log: tu copia del remoto.

### 3. El ciclo completo

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

La rama se borró en GitHub y en local, y `main` tiene **un** commit con el cambio.

### 4. Proteger `main`

En la web: **Settings → Rules → Rulesets → New ruleset → New branch ruleset**:
- Nombre: `protect-main` · *Enforcement status*: **Active**
- *Target branches*: **Include default branch**
- ✅ *Require a pull request before merging*
- ✅ *Block force pushes*
- **No** añadas a nadie en *Bypass list*: así la regla se aplica también a ti, que eres admin.

(Si usas la pantalla antigua, *Settings → Branches → Add classic branch protection rule*, marca además *Do not allow bypassing the above settings*. Si no, como dueño del repo podrías saltártela sin darte cuenta.)

Pruébalo:
```bash
echo "cambio directo" >> README.md
git commit -am "Direct change to main"
git push
```

🔮 **Predice:** ¿qué pasará?

GitHub lo **rechaza**. Deshaz ese commit local:
```bash
git reset --hard origin/main
```

En los equipos, `main` siempre está protegida. Un cambio sin revisar no llega a producción.

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
# resuelve como en la clase 26, después:
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
GitHub puede **bloquear el push** si detecta algo con forma de credencial (*push protection*, activada por defecto en repos públicos). Aunque te deje, la lección de las clases 15 y 25 sigue en pie: si un secreto real llega a un remoto, se rota. Limpia:
```bash
git switch main && git branch -D test/secret
git push origin --delete test/secret 2>/dev/null || true
```

## Desde hoy: tu repo del curso como un profesional

A partir de ahora, si quieres, guarda tus cierres con ramas y PRs en `my-devops-journey` (no es obligatorio, pero es buena práctica y deja un historial excelente):
```bash
git switch main && git pull
git switch -c clase-28
# … trabajas, haces commits …
git push -u origin clase-28
gh pr create --fill && gh pr merge --squash --delete-branch
git switch main && git pull
```

## Reto

1. Escribe un buen README en **inglés** para `pr-lab`: qué es, cómo se usa y qué aprendiste. Súbelo con un PR.
2. Configura una plantilla de PR: crea `.github/pull_request_template.md` con las secciones *What*, *Why* y *How I tested*. Abre un PR y comprueba que aparece sola.
3. ¿Qué diferencia hay entre `git fetch` y `git pull`? Demuéstralo: haz un cambio en la web, ejecuta `git fetch` y compara `git log --oneline main` con `git log --oneline origin/main`.

## Cierre

En `notas/fase-1/clase-27.md`:

1. Describe el flujo completo de un cambio con pull request, del `switch -c` a la limpieza.
2. ¿Qué es `origin/main` y por qué no se actualiza solo?
3. Tu push a `main` es rechazado porque el remoto tiene commits nuevos. ¿Qué haces y qué **no** debes hacer?
4. **Repaso (clase 26, sin mirar):** ¿cuál es la regla de oro del rebase?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Actualizar `main` (`git switch main && git pull`) → crear una rama (`git switch -c feature/x`) → commits pequeños con buenos mensajes → `git push -u origin feature/x` → abrir el PR explicando qué, por qué y cómo se probó → revisión y comprobaciones automáticas, aplicando los cambios pedidos → merge (normalmente *squash*) → borrar la rama remota y la local, y `git pull` en `main`.

**2.** Es la copia local del estado de la rama `main` del remoto **la última vez que te comunicaste con él** (`fetch`, `pull` o `push`). Git no consulta la red por su cuenta: solo se actualiza cuando lo pides con `git fetch` o `git pull`.

**3.** Traer los cambios del remoto (`git pull`, que integra `origin/main` en tu rama, resolviendo conflictos si los hay) y volver a hacer push. Y en un equipo, lo normal es no hacer push a `main`, sino usar una rama y un PR. Lo que **no** se hace es `git push --force` a una rama compartida: borraría el trabajo de tus compañeros.

**4.** No hacer rebase de commits que ya están compartidos en un remoto (que otros pueden haber descargado), porque el rebase crea commits nuevos y rompe la historia de los demás.

**Reto 3:** `git fetch` solo descarga y actualiza `origin/main`; tu `main` local no cambia. `git pull` hace `fetch` y además fusiona `origin/main` en tu rama actual.
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

## Fin del bloque D

Ya trabajas con Git como en un equipo. Solo quedan los proyectos que demuestran todo lo aprendido y el examen.

## Siguiente

[Clase 28 — P1: Runbook de incidentes](clase-28-p1-incidentes.md)
