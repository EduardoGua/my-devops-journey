# Clase 26 — Ramas, merge y conflictos

**Dónde:** tu Ubuntu (`~/git-lab`) · **Tiempo:** 90 min · **Bloque:** D. Git y GitHub

## Objetivo

- Trabajar con ramas: crear, cambiar, fusionar y borrar.
- Distinguir un merge **fast-forward** de un merge **de tres vías**.
- **Resolver conflictos** con calma y método.
- Entender `rebase` y su regla de oro. Guardar trabajo a medias con `stash`.

## Por qué importa

En un equipo, nadie trabaja directamente en `main`: cada cambio va en una rama, pasa por revisión (pull request, clase 27) y se fusiona. En los equipos de plataforma, muchas personas tocan los mismos archivos (un `main.tf`, un `values.yaml`, el pipeline), así que los **conflictos son rutina**. Resolverlos bien, sin pánico y sin borrar el trabajo de otros, es una habilidad muy valorada.

## Teoría

### Una rama por cambio

```
main:     A ── B ──────────── M        ← merge de la rama de trabajo
                \            /
feature:         C ── D ────┘
```

Convención de nombres habitual: `feature/health-check`, `fix/permisos-backend`, `docs/readme`.

### Dos tipos de merge

**Fast-forward**: si `main` no avanzó desde que creaste la rama, Git solo **mueve el puntero**. No hay commit de merge.
```
antes:  main → B          feature → D (B ── C ── D)
después: main → D         (la historia es una línea recta)
```

**Merge de tres vías**: si **ambas** ramas avanzaron, Git compara las dos puntas con su **ancestro común** y crea un **commit de merge** con dos padres.

### Conflictos

Hay conflicto cuando ambas ramas cambiaron **las mismas líneas** (o una borró un archivo que la otra modificó). Git no adivina: marca el archivo y te deja decidir.

```
<<<<<<< HEAD
server_port=8080          ← tu versión (la rama en la que estás)
=======
server_port=9090          ← la versión que intentas fusionar
>>>>>>> feature/puerto
```

**Método para resolver:**
1. `git status`: qué archivos están en conflicto.
2. Abre cada uno y **entiende** las dos intenciones. No elijas "la mía" por reflejo.
3. Deja el contenido final correcto (puede ser una combinación) y **borra los marcadores**.
4. `git add archivo` (marca el conflicto como resuelto).
5. `git commit` (o `git merge --continue`).
6. **Comprueba** que funciona (que la configuración es válida, que pasan los tests).

Si te pierdes: `git merge --abort` y vuelves al estado anterior al merge.

### Rebase

`rebase` **reescribe** tus commits como si hubieras empezado la rama desde la punta actual de `main`. El resultado es una historia lineal.

```
antes:   main: A ── B ── E          feature: A ── B ── C ── D
rebase:  feature: A ── B ── E ── C' ── D'     (C' y D' son commits NUEVOS, con otros hashes)
```

**Regla de oro:** haz rebase **solo** de ramas que nadie más ha descargado. Reescribir commits ya compartidos rompe el trabajo de los demás.

### Stash

`git stash` guarda tus cambios sin commit en un cajón y te deja el directorio limpio, por ejemplo para cambiar de rama ante una urgencia. `git stash pop` los recupera.

## Práctica guiada

```bash
cd ~/git-lab
rm -rf ramas && mkdir ramas && cd ramas
git init -b main
printf "server_port=8080\n\n# rendimiento\nworkers=2\n\n# logs\nlog_level=info\n" > app.conf
echo "# Servicio" > README.md
git add . && git commit -m "Configuración inicial"
```

### 1. Fast-forward

```bash
git switch -c feature/readme
echo "Arranca con: systemctl start miapp" >> README.md
git commit -am "Documenta cómo arrancar el servicio"
git log --oneline --graph --all
git switch main
```

🔮 **Predice:** como `main` no ha cambiado, ¿qué tipo de merge será?

```bash
git merge feature/readme
git log --oneline --graph --all
git branch -d feature/readme
```

### 2. Merge de tres vías (sin conflicto)

```bash
git switch -c feature/workers
sed -i 's/workers=2/workers=4/' app.conf
git commit -am "Sube workers a 4 para la carga de la tarde"

git switch main
sed -i 's/log_level=info/log_level=warning/' app.conf
git commit -am "Reduce el ruido de logs en producción"

git log --oneline --graph --all
git merge feature/workers -m "Merge feature/workers"
git log --oneline --graph --all
cat app.conf
```

Cambiaron **líneas distintas** del mismo archivo y Git combinó ambas sin problemas.

> Detalle importante: si las dos líneas cambiadas fueran **contiguas** (una justo debajo de la otra), Git lo trataría como conflicto, porque no puede asegurar que los dos cambios sean independientes. Por eso `app.conf` tiene líneas en blanco y comentarios entre secciones: archivos de configuración bien separados generan menos conflictos en equipo.

### 3. Tu primer conflicto

```bash
git switch -c feature/puerto-9090
sed -i 's/server_port=8080/server_port=9090/' app.conf
git commit -am "Mueve el servicio al 9090"

git switch main
sed -i 's/server_port=8080/server_port=8000/' app.conf
git commit -am "Mueve el servicio al 8000 por el nuevo proxy"

git merge feature/puerto-9090
```

🔮 **Predice:** ¿qué dirá Git y qué verás en `app.conf`?

```bash
git status
cat app.conf
```

Resuélvelo: imagina que hablas con quien hizo el otro cambio y acordáis el **8000** (el proxy nuevo manda). Edita `app.conf` con `nano`, deja la línea correcta y **borra los tres marcadores**:
```bash
nano app.conf
grep -n '<<<<<<<\|=======\|>>>>>>>' app.conf || echo "sin marcadores"
git add app.conf
git commit --no-edit
git log --oneline --graph --all
```

### 4. Stash

```bash
echo "cambio a medias" >> README.md
git status
git stash
git status                               # limpio
git switch -c fix/urgente
echo "timeout=30" >> app.conf && git commit -am "Añade timeout"
git switch main && git merge fix/urgente
git stash pop
git status                               # tu cambio a medias ha vuelto
git restore README.md                    # descártalo para seguir limpio
```

### 5. Rebase de una rama local

```bash
git switch -c feature/ssl
echo "ssl=on" >> app.conf && git commit -am "Activa SSL"
git switch main
echo "## Despliegue" >> README.md && git commit -am "Añade sección de despliegue"
git switch feature/ssl
git log --oneline --graph --all
git rebase main
git log --oneline --graph --all
```

La rama `feature/ssl` ahora parte de la punta de `main`. Fusionarla será un fast-forward:
```bash
git switch main && git merge feature/ssl
git log --oneline --graph
```

## Rómpelo

**1. Abortar un merge que no entiendes:**
```bash
git switch -c rama-a && sed -i 's/workers=4/workers=8/' app.conf && git commit -am "workers 8"
git switch main && sed -i 's/workers=4/workers=1/' app.conf && git commit -am "workers 1"
git merge rama-a
git merge --abort
git status
cat app.conf
```
Todo vuelve a como estaba antes del `merge`. Saber abortar quita el miedo a probar.

**2. Conflicto de borrado:**
```bash
git switch -c borra-readme && git rm README.md && git commit -m "Elimina README obsoleto"
git switch main && echo "Contacto: equipo-plataforma" >> README.md && git commit -am "Añade contacto"
git merge borra-readme
git status
```
Una rama borró el archivo y la otra lo modificó. Decide: si te quedas con el archivo, `git add README.md`; si lo eliminas, `git rm README.md`. Después, `git commit --no-edit`.

**3. Un conflicto durante un rebase:**
```bash
git switch -c rebase-conflicto && sed -i 's/workers=1/workers=16/' app.conf && git commit -am "workers 16"
git switch main && sed -i 's/workers=1/workers=3/' app.conf && git commit -am "workers 3"
git switch rebase-conflicto
git rebase main
git status
```
Resuélvelo como siempre (editar, `git add`), pero en lugar de `commit` se usa `git rebase --continue`. O `git rebase --abort` para volver atrás. Prueba ambos caminos: aborta, repite el rebase y complétalo.

## Reto

1. En `~/git-lab/ramas`, crea dos ramas que modifiquen **la misma línea** de `README.md` y otra línea **distinta** de `app.conf`. Fusiona ambas en `main`. ¿Cuántos conflictos esperas? Compruébalo.
2. ¿Qué hace `git merge --no-ff`? ¿Por qué algunos equipos prefieren ver siempre el commit de merge?
3. Explica con un dibujo por qué hacer rebase de una rama que tu compañero ya descargó le causa problemas.

## Cierre

En `notas/fase-1/clase-26.md`:

1. ¿Cuándo hace Git un fast-forward y cuándo un merge de tres vías?
2. Describe tu método para resolver un conflicto. ¿Qué compruebas al final?
3. ¿Qué diferencia hay entre merge y rebase? ¿Cuál es la regla de oro del rebase?
4. **Repaso (clase 25, sin mirar):** ¿qué es `git reflog` y cuándo te salva?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Fast-forward**: cuando la rama de destino no tiene commits nuevos desde que se creó la otra; Git solo avanza el puntero. **Tres vías**: cuando ambas ramas tienen commits propios; Git combina las dos puntas usando el ancestro común y crea un commit de merge con dos padres.

**2.** `git status` para ver los archivos en conflicto; abrir cada uno y entender **ambas** intenciones (leer los mensajes de commit, hablar con el autor si hace falta); escribir el resultado correcto y borrar los marcadores; `git add`; `git commit` (o `--continue`). Al final se comprueba que no quedan marcadores (`grep '<<<<<<<'`) y que **funciona**: la configuración es válida (`nginx -t`, `terraform validate`…) y los tests pasan. Un conflicto "resuelto" que rompe la build no está resuelto.

**3.** **Merge** une historias y conserva lo que pasó, con un commit de merge si hace falta: no reescribe nada. **Rebase** reaplica tus commits sobre otra base y crea commits nuevos (otros hashes): la historia queda lineal, pero reescrita. Regla de oro: no hagas rebase de commits que ya has compartido (que están en un remoto y otros pueden tener).

**4.** El historial de todos los movimientos de `HEAD` en tu repo local, incluidos commits que ya no están en ninguna rama. Te salva tras un `reset --hard` equivocado, un rebase que salió mal o una rama borrada: buscas el hash y vuelves a él.

**Reto:** 1) **Uno** (en `README.md`); el de `app.conf` se fusiona solo. 2) `--no-ff` fuerza un commit de merge aunque se pudiera hacer fast-forward: deja constancia de que "esta funcionalidad entró como un bloque" y facilita revertirla entera (`git revert -m 1 <merge>`).
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| branch | rama |
| merge conflict | conflicto de fusión |
| fast-forward | avance rápido |
| to rebase | cambiar la base |
| to stash | guardar temporalmente |
| feature branch | rama de funcionalidad |

🎙️ *"When I hit a merge conflict, I don't just pick my side: I understand both changes, combine them, and validate the result before committing."*

## Siguiente

[Clase 27 — GitHub y pull requests](clase-27-github-y-pull-requests.md)
