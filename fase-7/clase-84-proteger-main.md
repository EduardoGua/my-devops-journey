# Clase 84 — Comprobaciones obligatorias y leer un job fallido

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Integración continua

> 💡 **La idea de hoy:** un pipeline que avisa pero no impide es una sugerencia. Un **ruleset** en `main` convierte las comprobaciones en **obligatorias**: nada entra sin PR, nada se une en rojo y nadie, ni siquiera tú, se lo salta. Y cuando un job falla, se lee con método: el primer error, el código de salida y qué es distinto entre el runner y tu máquina.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - La CI de `lab-actions` con sus casillas `lint`, `test` e `imagen` (clase 83).
> - `git push --force`, `git reset --hard` y los PR (clase 24); `git revert` (clase 22).
> - `gh api` y `jq` (clases 24 y 47); los códigos de salida (clase 04).
> - Que el runner está en UTC (clase 82, reto 3).

> 🔤 **Palabras nuevas de hoy:**
> - **ruleset**: un conjunto de reglas sobre ramas o etiquetas de un repositorio.
> - **comprobación obligatoria** (*required status check*): una casilla que tiene que estar en verde para unir un PR.
> - **lista de excepciones** (*bypass list*): quién puede saltarse las reglas.
> - **`--log-failed`**: el log solo de los steps que fallaron.
> - **anotación**: un aviso que un step pega a una línea concreta del código.
> - **prueba inestable** (*flaky test*): la que a veces pasa y a veces falla sin cambiar nada.

## Objetivo

- Proteger `main` con un **ruleset**:
  - nada entra sin pull request;
  - nada se une sin las comprobaciones en verde;
  - nadie reescribe ni borra la rama.
- Comprobar que un PR con una prueba rota **no se puede unir**: el primer criterio de salida de la fase.
- Leer un job fallido con método: el primer error, el código de salida y "¿qué es distinto del runner a mi máquina?".
- Repetir solo lo que falló y activar los logs de depuración cuando hagan falta.

## Por qué importa

Un pipeline que avisa pero no impide es una sugerencia. La protección de `main` convierte las pruebas en **obligatorias**:
- un viernes a última hora, con prisa, nadie puede saltárselas, ni siquiera tú;
- un PR rojo no entra;
- `main` siempre contiene algo que pasó todo.

Y leer un job fallido es una habilidad diaria: la mitad del trabajo con pipelines es entender por qué algo que en tu máquina funciona falla en el runner.

## Costo esperado

> 💰 **0 USD.** Los rulesets son gratis en los repositorios públicos.

## Cómo va esta clase

Cinco piezas. En cada una lees **una** idea y la pruebas enseguida en `lab-actions`; no pases a la siguiente sin haber hecho la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 y 2** (unos 35 min, con `main` protegida y el PR rojo bloqueado); el segundo, las **piezas 3 a 5**, el Rómpelo, el reto y el cierre.

## Las piezas

### Pieza 1 — Un ruleset para `main`

Un **ruleset** es un conjunto de reglas sobre ramas o etiquetas. Las más usadas para `main`:

| Regla | Qué impide |
|-------|------------|
| *Require a pull request before merging* | el `push` directo: todo cambio entra por un PR |
| *Require status checks to pass* | unir un PR hasta que las comprobaciones elegidas (`lint`, `test`, `imagen`) estén en verde |
| *Block force pushes* | reescribir el historial de `main` con `git push --force` (clase 24) |
| *Restrict deletions* | borrar la rama |

- **Las aprobaciones:** en un equipo se pide al menos una aprobación de otra persona. Trabajando solo, déjalo en 0: la regla del PR sigue obligando a pasar por el pipeline.
- **La lista de excepciones** (*bypass list*): quién puede saltarse las reglas. Para que el criterio de salida sea verdad, **déjala vacía**: ni siquiera el dueño del repositorio debe poder colarse.
- **La protección clásica de ramas** (*Branch protection rules*) hace casi lo mismo y la verás en repositorios antiguos. Los rulesets son su sustituto: se pueden apilar, exportar como JSON y aplicar a varias ramas.

**Pruébalo.** En `lab-actions`: **Settings → Rules → Rulesets → New ruleset → New branch ruleset**.

1. Nombre: `proteger-main`. *Enforcement status*: **Active**.
2. *Target branches* → *Add target* → **Include default branch**.
3. Marca:
   - *Restrict deletions*;
   - *Block force pushes*;
   - *Require a pull request before merging*, con 0 aprobaciones;
   - *Require status checks to pass*. Pulsa *Add checks* y añade `lint`, `test` e `imagen`. Aparecen en la lista porque ya corrieron alguna vez.
4. *Bypass list*: **vacía**. Crea el ruleset.

Lo mismo se puede leer como código, con la API. Así queda escrito y se puede aplicar a otro repositorio (reto 1, y la clase 90):

```bash
cd ~/lab-actions
gh api "repos/{owner}/{repo}/rulesets" --jq '.[] | {id, name, enforcement}'
gh api "repos/{owner}/{repo}/rulesets/<id>" > proteger-main.json
jq '.rules[].type' proteger-main.json
```

`gh` sustituye `{owner}` y `{repo}` por los del repositorio en el que estás.

👀 **Qué deberías ver:** `{"enforcement": "active", "id": …, "name": "proteger-main"}` y, en las reglas, `"deletion"`, `"non_fast_forward"`, `"pull_request"` y `"required_status_checks"`: las cuatro que marcaste.

✋ **Sin mirar:** ¿por qué dejas vacía la lista de excepciones, aunque el repositorio sea tuyo?

<details>
<summary>Comprueba</summary>

Porque quien esté en ella puede unir un PR rojo o hacer `push` directo; si te incluyes "por si acaso", la garantía de que `main` siempre pasó las pruebas deja de existir.
</details>

**En resumen:** PR obligatorio, comprobaciones obligatorias, sin `force push` ni borrado, y nadie en la lista de excepciones.

### Pieza 2 — Intentar saltárselo

Con el ruleset activo, las dos formas de colarse en `main` (el `push` directo y unir un PR rojo) están cerradas. Compruébalo: un criterio de salida no se da por bueno hasta que lo ves fallar.

🔮 **Predice:** ¿qué responde GitHub a un `push` directo? ¿Y `gh pr merge` con una prueba en rojo?

**Pruébalo:**

```bash
git switch main && git pull
echo "# directo" >> README.md && git commit -qam "Un push directo"
git push
git reset --hard origin/main
git switch -c prueba-rota
sed -i 's/"ok"}/"OK"}/' tests/test_app.py
git commit -qam "Rompo una prueba a propósito" && git push -u origin prueba-rota
gh pr create --fill
gh pr checks --watch
gh pr merge --squash
```

👀 **Qué deberías ver:** el `push` rechazado (*Repository rule violations found… Changes must be made through a pull request*), y `git reset --hard` deshace tu commit local (clase 24). Después, en el PR, `test` en rojo, y `gh pr merge` se niega: la regla exige `test` en verde. En la web, el botón de *Merge* está bloqueado y dice qué comprobación falta. Ese es el primer criterio de salida de la fase. Deja el PR abierto: lo arreglas en la pieza 3.

✋ **Sin mirar:** ¿qué garantiza un ruleset con comprobaciones obligatorias sobre el contenido de `main`?

<details>
<summary>Comprueba</summary>

Que todo lo que hay en `main` pasó por un PR con `lint`, `test` e `imagen` en verde.
</details>

**En resumen:** ni `push` directo ni PR rojo: el ruleset lo impide, también a ti.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, lo primero: `cd ~/lab-actions && git switch prueba-rota`.

### Pieza 3 — Cómo se lee un job fallido

1. **El primer error, no el último.** Un fallo provoca otros; los de abajo suelen ser consecuencia del de arriba.
2. **El código de salida:** `Process completed with exit code 1` solo dice que **un** comando terminó mal. El mensaje útil está justo encima.
3. **¿Qué es distinto en el runner?**
   - Una máquina **limpia:** solo tiene lo que instalas en el workflow.
   - Su reloj está en **UTC**.
   - Linux distingue mayúsculas en los nombres de archivo.
   - Tiene otra red.
   - Sus versiones de las herramientas pueden ser distintas de las tuyas.
4. **Reprodúcelo en tu máquina** con los mismos pasos que el workflow. Si allí funciona, la diferencia del punto 3 es la pista.

**Pruébalo:**

```bash
gh run list --branch prueba-rota --limit 1
gh run view <id> --log-failed | head -40
```

Busca en el log: el step que falló, la línea `assert` con los dos valores (el esperado y el obtenido) y el resumen final de `pytest`. Arréglalo, sube el commit y une el PR:

```bash
git revert --no-edit HEAD && git push
gh pr checks --watch && gh pr merge --squash --delete-branch
```

👀 **Qué deberías ver:** solo el log del job `test`, con `E       AssertionError: assert {'status': 'ok'} == {'status': 'OK'}`, el resumen `1 failed, 1 passed` y, al final, `Process completed with exit code 1`. Tras el `revert`, las tres casillas en verde y el PR unido.

✋ **Sin mirar:** una prueba falla en el runner y pasa en tu portátil. ¿Qué buscas primero?

<details>
<summary>Comprueba</summary>

El primer error del log, y después qué es distinto entre los dos entornos: lo que no instala el workflow, la zona horaria (UTC), las versiones, las mayúsculas, la red.
</details>

**En resumen:** primer error → mensaje encima del código de salida → diferencias con tu máquina → reproducirlo.

### Pieza 4 — Repetir y depurar

Un job puede fallar sin que tu código tenga la culpa: una descarga que se cortó, un servicio externo caído. Entonces no hace falta repetir todo.

| Orden | Qué hace |
|-------|----------|
| `gh pr checks` | el estado de cada comprobación del PR |
| `gh run view <id> --log-failed` | solo el log de los steps que fallaron |
| `gh run rerun <id> --failed` | repetir solo los jobs que fallaron |
| `gh run rerun <id> --debug` | repetir con los logs de depuración del runner y de cada step |

**Pruébalo:**

```bash
gh run list --limit 3
gh run rerun <id> --debug
gh run watch
gh run view <id> --log | grep -m5 '##\[debug\]'
```

👀 **Qué deberías ver:** la ejecución repetida y, en su log, líneas `##[debug]` con lo que hace por dentro cada action (variables, rutas, comandos). Es mucho ruido: úsalo solo cuando el log normal no basta. `--failed` hace lo mismo, pero solo con los jobs que fallaron.

✋ **Sin mirar:** una descarga se cortó y falló solo el job `imagen`. ¿Qué orden repite solo ese job?

<details>
<summary>Comprueba</summary>

`gh run rerun <id> --failed`.
</details>

**En resumen:** `--failed` para repetir lo que falló; `--debug` cuando el log normal no basta.

### Pieza 5 — Anotaciones

Un step puede marcar errores en líneas concretas del código con un **comando de workflow**: una línea con un formato especial (`::warning file=…,line=…::mensaje`) que GitHub entiende. `ruff` y otras herramientas pueden emitir sus errores así.

**Pruébalo.** En una rama nueva, añade al job `lint` de `ci.yml`:

```yaml
      - run: echo "::warning file=app.py,line=1::Ejemplo de anotación desde el pipeline"
```

```bash
git switch main && git pull && git switch -c anotacion
git commit -qam "Una anotación de ejemplo" && git push -u origin anotacion && gh pr create --fill
```

👀 **Qué deberías ver:** en la pestaña *Files changed* del PR, el aviso pegado a la línea 1 de `app.py`, y también en el resumen de la ejecución. Cierra el PR sin unir: `gh pr close anotacion --delete-branch`.

✋ **Sin mirar:** ¿cómo hace un step para que un aviso aparezca junto a una línea concreta del código en el PR?

<details>
<summary>Comprueba</summary>

Imprimiendo un comando de workflow: `::warning file=archivo,line=N::mensaje` (o `::error`).
</details>

**En resumen:** `::warning` y `::error` con `file` y `line` pegan avisos al código del PR.

## Tu chuleta de la clase

| Escribes o abres | Qué hace |
|------------------|----------|
| **Settings → Rules → Rulesets → New branch ruleset** | crear un ruleset |
| *Require a pull request* · *Require status checks* · *Block force pushes* · *Restrict deletions* | las cuatro reglas de `main` |
| `gh api "repos/{owner}/{repo}/rulesets"` · `…/rulesets/<id>` | leer los rulesets como JSON |
| `gh api --method POST "repos/{owner}/{repo}/rulesets" --input archivo.json` | crear uno desde JSON |
| `gh pr checks [--watch]` · `gh pr merge --squash` | estado y unión del PR |
| `gh run view <id> --log-failed` | el log de lo que falló |
| `gh run rerun <id> --failed` · `--debug` | repetir lo fallido · con depuración |
| `echo "::warning file=…,line=…::…"` | una anotación en el PR |

## Rómpelo: diagnostica estos fallos

Cinco extractos reales de logs de jobs fallidos. Para cada uno, escribe en tus notas **una línea**: «Causa: ____ → Arreglo: ____», **antes** de mirar la autocorrección.

**A.**
```
Run pytest -v
ImportError while importing test module '/home/runner/work/lab-actions/lab-actions/tests/test_vigia.py'.
E   ModuleNotFoundError: No module named 'yaml'
Error: Process completed with exit code 2.
```

**B.**
```
Run ruff check .
app.py:2:8: F401 [*] `json` imported but unused
Found 1 error.
[*] 1 fixable with the `--fix` option.
Error: Process completed with exit code 1.
```

**C.**
```
FAILED tests/test_fechas.py::test_hoy - AssertionError: assert '2026-10-20' == '2026-10-19'
```
(En tu portátil, a las 20:00 del día 19, la prueba pasa.)

**D.**
```
Error: Unable to resolve action `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b0`, unable to find version `3d3c42e5aac5ba805825da76410c181273ba90b0`
```

**E.**
```
Run bash scripts/humo.sh http://127.0.0.1:8000
FALLO: http://127.0.0.1:8000 no responde
Run docker logs saludo
ERROR:    Error loading ASGI app. Could not import module "app".
```

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Aplica tu ruleset, desde el JSON, a otro repositorio de prueba (y bórralo después). Es protección de ramas como código.

> 🧩 **Ejemplo resuelto:** la pieza 1 guardó tu ruleset con `gh api "repos/{owner}/{repo}/rulesets/<id>" > proteger-main.json`.

**Ahora tú, con huecos:**
```bash
gh repo create lab-reglas --public --add-readme
jq 'del(.id, .node_id, .source, .source_type, .created_at, .updated_at, ._links, .current_user_can_bypass)' \
  proteger-main.json > nuevo.json
gh api --method ____ "repos/TU_USUARIO/lab-reglas/rulesets" --input ____
gh api "repos/TU_USUARIO/lab-reglas/rulesets" --jq '.[].name'
gh auth refresh -s delete_repo && gh repo delete TU_USUARIO/lab-reglas --yes
```
Completa: «El último `gh api` responde ____».

<details>
<summary>Pista</summary>

Crear es `POST`, con el JSON limpio como entrada. Los campos que borra `jq` solo existen en un ruleset ya creado, y la API los rechaza al crear uno nuevo. Borrar un repositorio necesita un permiso extra de `gh`: por eso el `refresh`.
</details>

**2.** Activa en el ruleset *Require branches to be up to date before merging*. ¿Qué te obliga a hacer cuando dos PR tocan `main` uno detrás de otro, y por qué lo usan los equipos grandes?

> 🧩 **Ejemplo resuelto:** sin esa opción, un PR que pasó las pruebas contra el `main` de ayer se puede unir aunque hoy `main` haya cambiado.

**Ahora tú, con huecos:** «Me obliga a ____ mi rama con `main` antes de unir, y las pruebas vuelven a correr. Lo usan los equipos grandes porque dos PR que pasan por separado pueden ____ al juntarse».

<details>
<summary>Pista</summary>

En la página del PR aparecerá un botón *Update branch*. Piensa en dos cambios que tocan funciones distintas que se llaman entre sí.
</details>

**3.** Busca en la documentación de GitHub qué es una ***merge queue*** y qué problema de la regla anterior resuelve.

> 🧩 **Ejemplo resuelto:** el problema del reto 2: con muchos PR al día, cada uno tiene que actualizarse y volver a pasar las pruebas cada vez que otro entra antes.

**Ahora tú, con huecos:** «Una *merge queue* ____ los PR aprobados y prueba cada uno junto con ____. Resuelve que, con la regla del reto 2, cada PR tenga que…».

<details>
<summary>Pista</summary>

Busca *Managing a merge queue* en `docs.github.com`. Lee solo la introducción.
</details>

## Destruir al terminar

Nada que destruir. El ruleset de `lab-actions` puede quedarse.

## Cierre

En `notas/fase-7/clase-84.md`:

1. ¿Qué cuatro reglas pusiste en `main` y qué impide cada una? *(4 líneas, una por regla. Empieza así: «Require a pull request: nada de push directo.»)*
2. ¿Por qué la lista de excepciones debe quedar vacía para que el criterio de salida sea verdad? *(1–2 líneas. Empieza así: «Porque quien esté en la lista puede…»)*
3. Una prueba pasa en tu portátil y falla en el runner. Nombra tres diferencias entre los dos entornos que podrían explicarlo. *(3 líneas, una por diferencia. Empieza así: «El runner está limpio: le falta lo que no instala el workflow.»)*
4. **Repaso (clase 83, sin mirar):** ¿para qué sirve `concurrency` con `cancel-in-progress`? *(1–2 líneas. Empieza así: «Para que, al subir un commit nuevo a la misma rama,…»)*

Después, escríbeme `examíname clase-84`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Rómpelo:**
- **A.** La prueba importa `yaml` (PyYAML), pero no está en `requirements-dev.txt` ni en `requirements.txt`. En tu portátil funciona porque lo instalaste a mano. Arreglo: añadir `PyYAML==6.0.3` al archivo que toca. El runner solo tiene lo que el workflow instala.
- **B.** Un `import json` que sobra. `ruff check --fix .` lo quita; después, commit.
- **C.** La zona horaria. El runner está en **UTC**: a las 20:00 del día 19 en Colombia (UTC−5) ya es la 01:00 del día 20 en UTC. La prueba depende de la hora local. Arreglo: trabajar con fechas en UTC en el código (como `checked_at` en Vigía) o fijar la fecha en la prueba.
- **D.** El SHA tiene una errata: el último carácter es `0` y no `1`, y ese commit no existe en el repositorio de la action. Al fijar por SHA, cópialo de `git ls-remote`, nunca a mano.
- **E.** La imagen no encuentra `app.py`. Lo más probable es un `.dockerignore` que lo excluye, o un `COPY` que lo deja en otra carpeta. La prueba de humo lo detectó y el step de `if: failure()` mostró la causa.

**Cierre:**
1. *Require a pull request* (nada de `push` directo), *Require status checks* (`lint`, `test` e `imagen` en verde antes de unir), *Block force pushes* (nadie reescribe el historial de `main`) y *Restrict deletions* (nadie borra `main`).
2. Porque quien esté en la lista puede unir un PR rojo o hacer `push` directo. Si te incluyes "por si acaso", el día de prisa lo usarás, y la garantía de que `main` siempre pasó las pruebas deja de existir.
3. Tres de estas:
   - el runner está **limpio** y le falta lo que no instala el workflow;
   - su reloj está en **UTC**;
   - otras **versiones** de Python o de las herramientas;
   - distingue **mayúsculas** en los nombres de archivo;
   - otra **red**, sin acceso a tus servicios locales;
   - no tiene **tus variables de entorno** ni tus archivos fuera del repositorio.
4. Para que, al subir un commit nuevo a la misma rama o PR, GitHub cancele la ejecución anterior, que ya no sirve: ahorras minutos y ves antes el resultado que importa.

**Reto 1:** `--method POST` y `--input nuevo.json`; el último `gh api` responde `proteger-main`.

**Reto 2:** te obliga a **actualizar** tu rama con `main` (botón *Update branch* o `git merge main`) antes de unir, y las pruebas vuelven a correr con el código combinado. Lo usan los equipos grandes porque dos PR que pasan por separado pueden **romperse** al juntarse.

**Reto 3:** una *merge queue* **pone en cola** los PR aprobados y prueba cada uno junto con **los que tiene delante en la cola**, antes de unirlos en orden. Resuelve que, con la regla del reto 2, cada PR tenga que actualizarse y repetir sus pruebas a mano cada vez que otro entra antes.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| ruleset / branch protection | conjunto de reglas / protección de ramas |
| required status checks | comprobaciones obligatorias |
| bypass list | lista de excepciones |
| failing job / flaky test | job que falla / prueba inestable |
| to re-run failed jobs | repetir los jobs fallidos |

🎙️ *"Main is protected by a ruleset: changes only come through pull requests, lint, tests and the image check are required, force pushes are blocked and nobody can bypass it. When a job fails, I read the first error, compare the runner with my machine, and re-run only the failed jobs."*

## Siguiente

[Clase 85 — Secretos, variables y permisos](clase-85-secretos-y-permisos.md)
