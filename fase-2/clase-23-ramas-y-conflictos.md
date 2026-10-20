# Clase 23 — Ramas, merge y conflictos

**Dónde:** tu Ubuntu (`~/git-lab`) · **Tiempo:** 90 min · **Bloque:** A. Git y GitHub

> 💡 **La idea de hoy:** cada cambio se hace en su propia **rama**, y después se **fusiona** (*merge*) con `main`. Si `main` no se movió, Git solo adelanta el puntero (*fast-forward*); si las dos ramas avanzaron, crea un commit de merge que une las dos historias. Cuando las dos cambiaron **las mismas líneas**, hay un **conflicto**: Git no adivina, te marca las dos versiones y decides tú.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Una rama es un puntero a un commit, y `HEAD` dice en qué rama estás (clase 22, pieza 3).
> - `git log --oneline --graph --all` dibuja la historia (clase 22, pieza 4).
> - `git reflog` encuentra commits que ya no están en ninguna rama (clase 22, Rómpelo 3).
> - `sed -i 's/viejo/nuevo/' archivo` cambia un texto dentro de un archivo (clase 19).

> 🔤 **Palabras nuevas de hoy:**
> - **merge** (fusión): unir los cambios de una rama con otra.
> - **fast-forward**: un merge en el que Git solo adelanta el puntero, sin commit nuevo.
> - **merge de tres vías**: un merge que compara las dos puntas con su ancestro común y crea un commit con dos padres.
> - **conflicto**: las dos ramas cambiaron las mismas líneas; decides tú cómo quedan.
> - **stash**: guardar aparte los cambios sin commit, para recuperarlos después.
> - **rebase**: reaplicar tus commits sobre otra base; crea commits nuevos, con otros hashes.

## Objetivo

- Trabajar con ramas: crear, cambiar, fusionar y borrar.
- Distinguir un merge **fast-forward** de un merge **de tres vías**.
- **Resolver conflictos** con calma y método.
- Entender `rebase` y su regla de oro. Guardar trabajo a medias con `stash`.

## Por qué importa

En un equipo, nadie trabaja directamente en `main`: cada cambio va en una rama, pasa por revisión (pull request, clase 24) y se fusiona. En los equipos de plataforma, muchas personas tocan los mismos archivos (un `main.tf`, un `values.yaml`, el pipeline), así que los **conflictos son rutina**. Resolverlos bien, sin pánico y sin borrar el trabajo de otros, es una habilidad muy valorada.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida en un repositorio de prácticas; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 45 min: en la 3 resuelves tu primer conflicto); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Primero, un repositorio nuevo con un archivo de configuración separado por secciones (verás en la pieza 2 por qué importa):

```bash
cd ~/git-lab
rm -rf ramas && mkdir ramas && cd ramas
git init -b main
printf "server_port=8080\n\n# rendimiento\nworkers=2\n\n# logs\nlog_level=info\n" > app.conf
echo "# Servicio" > README.md
git add . && git commit -m "Configuración inicial"
```

## Las piezas

### Pieza 1 — Una rama por cambio, y el *fast-forward*

```
main:     A ── B ──────────── M        ← merge de la rama de trabajo
                \            /
feature:         C ── D ────┘
```

Convención de nombres habitual: `feature/health-check`, `fix/permisos-backend`, `docs/readme`.

Si `main` **no avanzó** desde que creaste la rama, fusionar es fácil: Git solo **mueve el puntero** de `main` hasta la punta de la rama. Es un **fast-forward**, y no hay commit de merge.

```
antes:  main → B          feature → D (B ── C ── D)
después: main → D         (la historia es una línea recta)
```

**Pruébalo:**

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

👀 **Qué deberías ver:** `Actualizando …` y `Fast-forward`; en el gráfico, una línea recta con `main` en el último commit; y `Eliminada la rama feature/readme`.

✋ **Sin mirar:** creas una rama, haces dos commits y nadie ha tocado `main`. ¿Qué tipo de merge hará Git? ¿Habrá commit de merge?

<details>
<summary>Comprueba</summary>

Un fast-forward: Git solo adelanta el puntero de `main`, sin commit de merge.
</details>

**En resumen:** una rama por cambio; si `main` no avanzó, el merge es un fast-forward: Git solo mueve el puntero.

### Pieza 2 — El merge de tres vías

Si **ambas** ramas avanzaron, Git compara las dos puntas con su **ancestro común** (el commit del que salieron) y crea un **commit de merge** con dos padres.

**Pruébalo:** dos cambios en líneas distintas del mismo archivo, uno en cada rama.

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

👀 **Qué deberías ver:** antes del merge, el gráfico con dos ramas que se separan; después, el commit `Merge feature/workers` uniéndolas; y en `app.conf`, **los dos** cambios: `workers=4` y `log_level=warning`.

Cambiaron **líneas distintas** del mismo archivo y Git combinó ambas sin problemas.

> Detalle importante: si las dos líneas cambiadas fueran **contiguas** (una justo debajo de la otra), Git lo trataría como conflicto, porque no puede asegurar que los dos cambios sean independientes. Por eso `app.conf` tiene líneas en blanco y comentarios entre secciones: archivos de configuración bien separados generan menos conflictos en equipo.

**En resumen:** si las dos ramas avanzaron, Git crea un commit de merge con dos padres; los cambios en líneas distintas se combinan solos.

### Pieza 3 — Conflictos, y el método para resolverlos

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

**Pruébalo: tu primer conflicto.**

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

👀 **Qué deberías ver:** `CONFLICTO (contenido): Conflicto de fusión en app.conf`; en `git status`, `modificados por ambos: app.conf`; y en el archivo, los tres marcadores con `server_port=8000` arriba y `server_port=9090` abajo.

Resuélvelo: imagina que hablas con quien hizo el otro cambio y acordáis el **8000** (el proxy nuevo manda). Edita `app.conf` con `nano`, deja la línea correcta y **borra los tres marcadores**:

```bash
nano app.conf
grep -n '<<<<<<<\|=======\|>>>>>>>' app.conf || echo "sin marcadores"
git add app.conf
git commit --no-edit
git log --oneline --graph --all
```

👀 **Qué deberías ver:** `sin marcadores` y, en el gráfico, el commit de merge que une las dos ramas.

✋ **Sin mirar:** estás a mitad de un merge con conflictos y no entiendes qué pasa. ¿Cómo vuelves a como estaba todo antes?

<details>
<summary>Comprueba</summary>

`git merge --abort`. Lo probarás en el Rómpelo 1.
</details>

**En resumen:** en un conflicto, entiende las dos intenciones, deja el resultado correcto sin marcadores, `git add` y `git commit`. Y comprueba que funciona.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana vuelve con `cd ~/git-lab/ramas`.

### Pieza 4 — `stash`: guardar el trabajo a medias

`git stash` guarda aparte tus cambios sin commit y te deja el directorio limpio, por ejemplo para cambiar de rama ante una urgencia. `git stash pop` los recupera.

**Pruébalo:**

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

👀 **Qué deberías ver:** después del `stash`, `Directorio de trabajo y estado de índice WIP on main… guardados` y un `git status` limpio; el arreglo urgente fusionado con un fast-forward; y, con `stash pop`, `README.md` otra vez en `Cambios no rastreados para el commit`.

**En resumen:** `git stash` guarda aparte lo que estás haciendo; `git stash pop` lo devuelve.

### Pieza 5 — `rebase`, y su regla de oro

`rebase` **reescribe** tus commits como si hubieras empezado la rama desde la punta actual de `main`. El resultado es una historia lineal.

```
antes:   main: A ── B ── E          feature: A ── B ── C ── D
rebase:  feature: A ── B ── E ── C' ── D'     (C' y D' son commits NUEVOS, con otros hashes)
```

**Regla de oro:** haz rebase **solo** de ramas que nadie más ha descargado. Reescribir commits ya compartidos rompe el trabajo de los demás.

**Pruébalo** con una rama que solo existe en tu PC:

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

👀 **Qué deberías ver:** antes, dos ramas que se separan; después del rebase, una sola línea en la que `Activa SSL` va **detrás** de `Añade sección de despliegue`, y con un hash distinto al de antes.

La rama `feature/ssl` ahora parte de la punta de `main`. Fusionarla será un fast-forward:

```bash
git switch main && git merge feature/ssl
git log --oneline --graph
```

✋ **Sin mirar:** tu compañero ya descargó tu rama `feature/x`. ¿Puedes hacerle un rebase?

<details>
<summary>Comprueba</summary>

No: el rebase crea commits nuevos, y su copia tendría los viejos. Para integrar `main` en una rama compartida, `git merge main`.
</details>

**En resumen:** `rebase` deja la historia lineal pero crea commits nuevos; solo en ramas que nadie más tiene.

## Tu chuleta de la clase

| Comando | Qué hace |
|---------|----------|
| `git switch -c rama` · `git switch rama` | crear una rama y cambiarte a ella · cambiarte |
| `git branch` · `git branch -d rama` | ver las ramas · borrar una ya fusionada |
| `git merge rama` · `git merge --no-ff rama` | fusionar · fusionar siempre con commit de merge |
| `git merge --abort` · `git merge --continue` | deshacer un merge a medias · terminarlo tras resolver |
| `git status` · `grep -n '<<<<<<<' archivo` | qué está en conflicto · marcadores que quedan |
| `git stash` · `git stash pop` · `git stash list` | guardar lo que estás haciendo · recuperarlo · ver lo guardado |
| `git rebase main` · `--continue` · `--abort` | reaplicar tu rama sobre `main` · seguir tras un conflicto · volver atrás |
| `git log --oneline --graph --all` | ver las ramas y cómo se unen |

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

En `~/git-lab/ramas`, en la terminal. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Crea dos ramas que cambien **la misma línea** de `README.md` y, cada una, una línea **distinta** de `app.conf`. Fusiona las dos en `main`. ¿Cuántos conflictos esperas? Compruébalo.

Si en el Rómpelo 2 te quedaste sin `README.md`, recréalo antes: `echo '# Servicio' > README.md && git add README.md && git commit -m 'Recupera README'`.

> 🧩 **Ejemplo resuelto:** dos ramas que cambian sitios distintos: una, `README.md`; la otra, `app.conf`.
> ```bash
> git switch main
> git switch -c r1 && echo "Contacto: plataforma" >> README.md && git commit -am "Añade contacto"
> git switch main && git switch -c r2 && sed -i 's/log_level=warning/log_level=error/' app.conf && git commit -am "Solo errores en el log"
> git switch main && git merge r1 && git merge r2 -m "Merge r2"
> ```
> Cero conflictos: ninguna línea la cambiaron las dos ramas. El primero es un fast-forward; el segundo, un merge de tres vías.

**Ahora tú, con huecos:**
```bash
git switch main
git switch -c ra && sed -i '1s/.*/# Servicio web/' README.md && sed -i 's/server_port=8000/server_port=____/' app.conf && git commit -am "ra"
git switch main && git switch -c rb && sed -i '1s/.*/# ____/' README.md && sed -i 's/log_level=error/log_level=____/' app.conf && git commit -am "rb"
git switch main && git merge ra && git merge rb
git status
```

<details>
<summary>Pista</summary>

La línea 1 de `README.md` la cambian las dos ramas: ahí habrá conflicto. `server_port` y `log_level` están en secciones distintas de `app.conf`: esas se combinan solas.
</details>

**2.** ¿Qué hace `git merge --no-ff`? Pruébalo y mira el gráfico.

> 🧩 **Ejemplo resuelto:** un merge normal de una rama con un commit.
> ```bash
> git switch -c docs/a && echo "a" >> README.md && git commit -am "docs a"
> git switch main && git merge docs/a
> git log --oneline --graph -3
> ```
> Fast-forward: una línea recta, sin rastro de que existió la rama.

**Ahora tú, con huecos:**
```bash
git switch -c docs/b && echo "b" >> README.md && git commit -am "docs b"
git switch main && git merge ____ docs/b -m "Merge docs/b"
git log --oneline --graph -3
```

<details>
<summary>Pista</summary>

La opción está en el enunciado. Fíjate en el gráfico: ¿aparece un commit de merge aunque se pudiera hacer fast-forward? ¿Qué ventaja tiene ver siempre ese commit si un día quieres deshacer la funcionalidad entera?
</details>

**3.** ¿Por qué hacer rebase de una rama que tu compañero ya descargó le causa problemas? Completa el esquema.

> 🧩 **Ejemplo resuelto:** el rebase de la pieza 5, en una rama solo tuya.
> ```
> antes:     main: A ── B ── E        tu rama: A ── B ── C ── D
> después:   tu rama: A ── B ── E ── C' ── D'
> ```
> Nadie más tenía `C` ni `D`: no pasa nada.

**Ahora tú, con huecos:**
```
tu compañero tiene:   A ── B ── C ── D
tú, tras el rebase:   A ── B ── E ── C' ── D'
→ Para Git, C y C' son commits ____ (tienen otro hash).
→ Cuando él haga git pull, Git verá dos historias ____ y le pedirá un merge con
  los mismos cambios repetidos: ____ y ____.
```

<details>
<summary>Pista</summary>

Relee la clase 22, pieza 3: el hash depende del contenido **y del padre**. `C'` tiene otro padre (`E`), así que es otro commit.
</details>

## Cierre

En `notas/fase-2/clase-23.md`:

1. ¿Cuándo hace Git un fast-forward y cuándo un merge de tres vías? *(2 líneas. Empieza así: «Un fast-forward cuando `main` no tiene commits nuevos desde…, y solo mueve… Un merge de tres vías cuando…»)*
2. Describe tu método para resolver un conflicto. ¿Qué compruebas al final? *(3 líneas. Empieza así: «Miro con `git status` qué archivos…; entiendo las dos versiones y dejo…; `git add` y `git commit`. Al final compruebo que…»)*
3. ¿Qué diferencia hay entre merge y rebase? ¿Cuál es la regla de oro del rebase? *(2–3 líneas. Empieza así: «El merge une las historias sin reescribir nada… El rebase crea commits nuevos… La regla de oro:…»)*
4. **Repaso (clase 22, sin mirar):** ¿qué es `git reflog` y cuándo te salva? *(2 líneas. Empieza así: «Es el historial de todos los sitios donde ha estado `HEAD`… Me salva cuando…»)*

Después, escríbeme `examíname clase-23`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** **Fast-forward**: cuando la rama de destino no tiene commits nuevos desde que se creó la otra; Git solo avanza el puntero. **Tres vías**: cuando ambas ramas tienen commits propios; Git combina las dos puntas usando el ancestro común y crea un commit de merge con dos padres.

**2.** `git status` para ver los archivos en conflicto; abrir cada uno y entender **ambas** intenciones (leer los mensajes de commit, hablar con el autor si hace falta); escribir el resultado correcto y borrar los marcadores; `git add`; `git commit` (o `--continue`). Al final se comprueba que no quedan marcadores (`grep '<<<<<<<'`) y que **funciona**: la configuración es válida (`nginx -t`, `terraform validate`…) y los tests pasan. Un conflicto "resuelto" que rompe la build no está resuelto.

**3.** **Merge** une historias y conserva lo que pasó, con un commit de merge si hace falta: no reescribe nada. **Rebase** reaplica tus commits sobre otra base y crea commits nuevos (otros hashes): la historia queda lineal, pero reescrita. Regla de oro: no hagas rebase de commits que ya has compartido (que están en un remoto y otros pueden tener).

**4.** El historial de todos los movimientos de `HEAD` en tu repo local, incluidos commits que ya no están en ninguna rama. Te salva tras un `reset --hard` equivocado, un rebase que salió mal o una rama borrada: buscas el hash y vuelves a él.

**Reto 1:** **un** conflicto, en la línea 1 de `README.md`; los cambios de `app.conf` se fusionan solos. Resuélvelo con el método de la pieza 3.
**Reto 2:** `git merge --no-ff docs/b`. Fuerza un commit de merge aunque se pudiera hacer fast-forward: deja constancia de que "esta funcionalidad entró como un bloque" y facilita revertirla entera (`git revert -m 1 <merge>`).
**Reto 3:** commits **distintos**; dos historias **que se separan** (divergentes), y el merge le traería `C` y `C'`, `D` y `D'`: los mismos cambios dos veces, con posibles conflictos. Por eso solo se hace rebase de ramas que nadie más tiene.
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

[Clase 24 — GitHub y pull requests](clase-24-github-y-pull-requests.md)
