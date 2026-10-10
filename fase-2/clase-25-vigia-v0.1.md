# Clase 25 — Proyecto: Vigía v0.1

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 1 bloque largo (unas 3 h) · **Bloque:** B. Proyecto · **Proyecto de portafolio**

## Objetivo

Publicar Vigía en GitHub y trabajar en él como en un equipo: `.gitignore`, una rama y un pull request por cambio, `main` protegida, mensajes de commit en inglés y la etiqueta `v0.1`. Al terminar, quien visite tu perfil verá Vigía arriba, con un README que explica qué hace y cómo ejecutarlo.

Es la versión que cierra la fase 2: aplicas a tu propio proyecto todo lo de las clases 22 a 24.

## Requisitos

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Repo público `vigia` en tu GitHub, con la etiqueta `v0` publicada | 24 |
| R2 | `main` protegida con un *ruleset*: PR obligatorio, sin *force push* y sin nadie en la lista de *bypass* | 24 |
| R3 | `.gitignore` con logs, `.env` y archivos temporales del editor | 22 |
| R4 | Al menos **tres cambios**, cada uno en su rama, con su PR (*What / Why / How I tested*) y fusionado con *squash* | 23, 24 |
| R5 | Mensajes de commit en inglés, en imperativo, con un resumen de 50 caracteres o menos | 22 |
| R6 | El README explica cómo instalarlo desde cero (`git clone` …) y cómo programarlo con cron | — |
| R7 | Etiqueta anotada `v0.1` publicada, y una *release* en GitHub | esta clase |
| R8 | Vigía fijado (*pinned*) en tu perfil de GitHub | — |

Tres cambios que encajan bien en R4 (puedes elegir otros):
1. Añadir el `.gitignore`.
2. Añadir la opción `-h` / `--help` con un `case` (clase 17).
3. Documentar la instalación y la programación con cron en el README.

## Teoría: etiquetas y *releases*

Una **etiqueta** (*tag*) es un nombre fijo para un commit. Una rama avanza con cada commit nuevo; una etiqueta no se mueve nunca. Por eso se usan para marcar versiones.

```
A ── B ── C ── D ── E      ← main (avanza)
          ▲         ▲
          v0        v0.1    ← etiquetas (fijas)
```

| Comando | Qué hace |
|---------|----------|
| `git tag -a v0.1 -m "mensaje"` | crea una etiqueta **anotada** (guarda autor, fecha y mensaje) en el commit actual |
| `git tag` | lista las etiquetas |
| `git show v0.1` | muestra la etiqueta y su commit |
| `git push origin v0.1` | la publica: `git push` normal **no** sube etiquetas |
| `git switch --detach v0` | mira el código tal como estaba en esa versión |

Una **release** de GitHub es una página construida sobre una etiqueta, con notas de la versión y archivos descargables. Muchos proyectos publican así sus versiones.

Regla: **una etiqueta publicada no se mueve**. Si te equivocaste, creas otra (`v0.1.1`). Moverla sería reescribir historia compartida (clase 22).

## Práctica guiada

### 1. Publicar el repo

```bash
cd ~/vigia
git status
git log --oneline --decorate
gh repo create vigia --public --source=. --remote=origin --push
git push origin v0
git ls-remote --tags origin
```

`gh repo create … --push` crea el repo en GitHub, lo conecta como `origin` y sube `main`. La etiqueta `v0` necesita su propio `push`.

### 2. Proteger `main`

En la web del repo, igual que en la clase 24: **Settings → Rules → Rulesets → New branch ruleset**, con *Require a pull request before merging* y *Block force pushes*, aplicado a la rama por defecto y **sin** nadie en *Bypass list*.

🔮 **Predice:** ¿qué pasará con este push?

```bash
echo "# test" >> README.md && git commit -am "Test direct push"
git push
```

Rechazado. Deshaz el commit local: `git reset --hard origin/main`.

### 3. El primer PR: `.gitignore`

```bash
git switch main && git pull
git switch -c add-gitignore
printf '*.log\n.env\n*.swp\n*~\n' > .gitignore
git add .gitignore
git commit -m "Add .gitignore for logs and secrets"
git push -u origin add-gitignore
gh pr create --title "Add .gitignore for logs and secrets" --body "## What
Ignore log files, .env files and editor backups.

## Why
Logs and secrets must never reach a public repository.

## How I tested
Created test.log and .env locally; git status does not show them."
gh pr view --web
```

Revisa el PR en la web como lo haría un compañero (pestaña *Files changed*) y fusiónalo:

```bash
gh pr merge --squash --delete-branch
git switch main && git pull
git log --oneline --decorate -5
```

### 4. Los otros dos cambios

Repite el ciclo para `--help` y para la documentación. Una rama por cambio, commits pequeños y un PR que explique qué, por qué y cómo lo probaste. Antes de cada rama: `git switch main && git pull`.

Para el README, la sección de instalación puede ser así:

````markdown
## Install
```bash
git clone https://github.com/<your-user>/vigia.git
cd vigia
./vigia.sh            # writes results to ~/vigia.log
```
````

### 5. Comprobar el README desde cero

El README tiene que funcionar para alguien que no eres tú. Pruébalo en una carpeta limpia:

```bash
cd /tmp && rm -rf vigia-prueba
git clone git@github.com:<tu-usuario>/vigia.git vigia-prueba
cd vigia-prueba
VIGIA_LOG=/tmp/vigia-prueba.log ./vigia.sh ; echo "código: $?"
cat /tmp/vigia-prueba.log
```

Si algo falla (un permiso de ejecución que no se subió, un paso que falta en el README), arréglalo con otro PR.

### 6. Etiqueta y *release*

```bash
cd ~/vigia && git switch main && git pull
git tag -a v0.1 -m "v0.1: published on GitHub, PR workflow"
git push origin v0.1
gh release create v0.1 --title "v0.1" --notes "First public version: Bash uptime checks scheduled with cron."
git log --oneline --decorate -6
```

### 7. Fijarlo en tu perfil

En `github.com/<tu-usuario>`, **Customize your pins** y elige `vigia`. Comprueba que la descripción del repo (el texto corto de arriba a la derecha en la página del repo, en el engranaje de *About*) dice qué es Vigía en una frase.

## Rómpelo

**1. Borrar un archivo por error y recuperarlo con Git.** Un criterio de salida de la fase 2.
```bash
git switch main && git pull && git switch -c test-recover
git rm urls.txt && git commit -m "Remove URL list by mistake"
ls urls.txt
git restore --source=HEAD~1 urls.txt
cat urls.txt
```
El archivo vuelve desde el commit anterior. Termina el arreglo con un commit (`git add urls.txt && git commit -m "Restore URL list"`) o, mejor aún en una rama compartida, con `git revert HEAD`. Después borra la rama: `git switch main && git branch -D test-recover`.

**2. Un conflicto a propósito.** Otro criterio de salida.
Crea dos ramas desde el mismo `main` que cambien **la misma línea** del README (la frase de descripción, por ejemplo). Abre un PR para cada una y fusiona la primera. La segunda dirá *This branch has conflicts*. Resuélvelo en local como en la clase 23:
```bash
git switch <segunda-rama>
git pull origin main          # aparece el conflicto
# edita el README, deja la versión buena y quita las marcas <<<<<<< ======= >>>>>>>
git add README.md && git commit --no-edit && git push
```
El PR se actualiza solo y vuelve a poder fusionarse.

**3. La etiqueta en el commit equivocado.**
```bash
git tag -a v0.1-mal -m "etiqueta de prueba" HEAD~1
git push origin v0.1-mal
git tag -d v0.1-mal
git push origin --delete v0.1-mal
```
Se puede borrar, pero si alguien ya la había descargado, en su clon sigue existiendo. Por eso, con una versión real ya publicada, no se mueve: se crea `v0.1.1`.

## Cierre

En `notas/fase-2/clase-25.md`:

1. ¿Qué diferencia hay entre una rama y una etiqueta? ¿Para qué usas cada una?
2. ¿Por qué Vigía tiene su propio repositorio en lugar de vivir dentro de `my-devops-journey`?
3. Copia la descripción de uno de tus PR y revísala como lo haría otra persona: ¿se entiende sin ver el código? ¿Qué le falta?
4. **Repaso (clase 24, sin mirar):** ¿qué es `origin/main` y por qué no se actualiza solo?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Comprueba tu entrega:**
- [ ] `github.com/<tu-usuario>/vigia` es público, con el README y la release `v0.1`.
- [ ] Un push directo a `main` es rechazado.
- [ ] En *Pull requests → Closed* hay al menos tres PR fusionados con descripción.
- [ ] `git ls-remote --tags origin` muestra `v0` y `v0.1`.
- [ ] Un clon limpio funciona siguiendo solo el README.
- [ ] Vigía aparece fijado en tu perfil.

**1.** Las dos son punteros a un commit. La rama **avanza** con cada commit nuevo: sirve para trabajar en algo. La etiqueta **no se mueve**: sirve para marcar una versión concreta (`v0.1`) a la que siempre puedes volver o que puedes desplegar.

**2.** Porque es un proyecto independiente, con su propio historial, versiones, README, issues y, más adelante, su propio pipeline de CI/CD. Dentro del repo del curso se mezclaría con tus notas y no se podría clonar, etiquetar ni desplegar por separado. Y un repositorio dentro de otro da problemas: Git no lo trata como archivos normales.

**3.** Una buena descripción se entiende sin abrir el código: qué cambia, por qué hacía falta y cómo se comprobó. Lo que suele faltar es el **porqué** y la prueba concreta ("ejecuté X y obtuve Y").

**4.** Es tu copia local de cómo estaba la rama `main` del remoto la última vez que hablaste con él (`fetch`, `pull` o `push`). Git no consulta la red por su cuenta: solo se actualiza cuando se lo pides.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| tag / release | etiqueta / versión publicada |
| release notes | notas de la versión |
| pinned repository | repositorio fijado |
| to clone from scratch | clonar desde cero |
| reviewer | revisor |

🎙️ *"Every change to my project goes through a pull request with a clear description, and each version is an annotated tag with release notes, so anyone can see what changed and when."*

## Al terminar la fase 2

1. Marca la clase 25 y Vigía v0.1 en [`PROGRESO.md`](../PROGRESO.md).
2. Revisa los **criterios de salida de la fase 2** en `PROGRESO.md`.
3. Desde ahora, Vigía cambia **siempre** con rama y PR.

## Siguiente

[Fase 3 — Clase 26: Cómo viaja una petición](../fase-3/clase-26-modelo-de-capas.md)
