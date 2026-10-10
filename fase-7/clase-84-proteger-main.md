# Clase 84 — Comprobaciones obligatorias y leer un job fallido

**Dónde:** GitHub + tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Integración continua

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

## Teoría

### Rulesets

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

### Cómo se lee un job fallido

1. **El primer error, no el último.** Un fallo provoca otros; los de abajo suelen ser consecuencia del de arriba.
2. **El código de salida:** `Process completed with exit code 1` solo dice que **un** comando terminó mal. El mensaje útil está justo encima.
3. **¿Qué es distinto en el runner?**
   - Una máquina **limpia:** solo tiene lo que instalas en el workflow.
   - Su reloj está en **UTC**.
   - Linux distingue mayúsculas en los nombres de archivo.
   - Tiene otra red.
   - Sus versiones de las herramientas pueden ser distintas de las tuyas.
4. **Reprodúcelo en tu máquina** con los mismos pasos que el workflow. Si allí funciona, la diferencia del punto 3 es la pista.

Herramientas de `gh` para esto:

| Orden | Qué hace |
|-------|----------|
| `gh pr checks` | el estado de cada comprobación del PR |
| `gh run view <id> --log-failed` | solo el log de los steps que fallaron |
| `gh run rerun <id> --failed` | repetir solo los jobs que fallaron |
| `gh run rerun <id> --debug` | repetir con los logs de depuración del runner y de cada step |

## Práctica guiada

### 1. El ruleset (15 min)

En `lab-actions`: **Settings → Rules → Rulesets → New ruleset → New branch ruleset**.

1. Nombre: `proteger-main`. *Enforcement status*: **Active**.
2. *Target branches* → *Add target* → **Include default branch**.
3. Marca:
   - *Restrict deletions*;
   - *Block force pushes*;
   - *Require a pull request before merging*, con 0 aprobaciones;
   - *Require status checks to pass*. Pulsa *Add checks* y añade `lint`, `test` e `imagen`. Aparecen en la lista porque ya corrieron alguna vez.
4. *Bypass list*: **vacía**. Crea el ruleset.

Lo mismo se puede hacer como código, con la API. Así queda escrito y se puede aplicar a otro repositorio:

```bash
gh api "repos/{owner}/{repo}/rulesets" --jq '.[] | {id, name, enforcement}'
gh api "repos/{owner}/{repo}/rulesets/<id>" > proteger-main.json
cat proteger-main.json | jq '.rules[].type'
```

`gh` sustituye `{owner}` y `{repo}` por los del repositorio en el que estás. Guarda el JSON en tus notas: en la clase 90 lo aplicarás a Vigía con `gh api --method POST "repos/{owner}/{repo}/rulesets" --input proteger-main.json`, después de quitarle los campos que solo existen en uno ya creado (`id`, `source`, `created_at`…).

### 2. Intentar saltárselo (10 min)

```bash
cd ~/lab-actions && git switch main && git pull
echo "# directo" >> README.md && git commit -qam "Un push directo"
git push
```

🔮 **Predice:** ¿qué responde GitHub? Rechaza el `push`: *Repository rule violations found… Changes must be made through a pull request*. Deshaz tu commit local: `git reset --hard origin/main` (clase 24).

### 3. Un PR rojo no entra (15 min)

```bash
git switch -c prueba-rota
sed -i 's/"ok"}/"OK"}/' tests/test_app.py
git commit -qam "Rompo una prueba a propósito" && git push -u origin prueba-rota
gh pr create --fill
gh pr checks --watch
gh pr merge --squash
```

🔮 **Predice:** ¿qué dice `gh pr merge`? Que no se puede unir: la regla exige `test` en verde. En la web, el botón de *Merge* está bloqueado y dice qué comprobación falta. Ese es el primer criterio de salida de la fase.

### 4. Leer el fallo y arreglarlo (15 min)

```bash
gh run list --branch prueba-rota --limit 1
gh run view <id> --log-failed | head -40
```

Busca en el log:
1. el step que falló;
2. la línea `assert` con los dos valores, el esperado y el obtenido;
3. el resumen final de `pytest`.

Arréglalo, sube el commit y mira cómo el PR pasa a verde y se puede unir:

```bash
git revert --no-edit HEAD && git push
gh pr checks --watch && gh pr merge --squash --delete-branch
```

### 5. Repetir y depurar (10 min)

Un job puede fallar sin que tu código tenga la culpa: una descarga que se cortó, un servicio externo caído. Entonces no hace falta repetir todo:

```bash
gh run list --limit 3
gh run rerun <id> --failed
gh run rerun <id> --debug
```

Con `--debug`, el log incluye líneas `##[debug]` con lo que hace por dentro cada action. Es mucho ruido: úsalo solo cuando el log normal no basta.

### 6. Anotaciones (10 min)

Un step puede marcar errores en líneas concretas del código con un **comando de workflow**. Añade a `lint`, en una rama nueva:

```yaml
      - run: echo "::warning file=app.py,line=1::Ejemplo de anotación desde el pipeline"
```

Abre el PR y mira la pestaña *Files changed*: el aviso aparece pegado a la línea 1 de `app.py`. `ruff` y otras herramientas pueden emitir sus errores así. Quita la línea y cierra el PR.

## Rómpelo: diagnostica estos fallos

Cinco extractos reales de logs de jobs fallidos. Para cada uno, escribe en tus notas la causa y el arreglo **antes** de mirar la autocorrección.

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

1. Exporta tu ruleset a JSON y aplícalo con `gh api --method POST` a otro repositorio tuyo de prueba (créalo y bórralo después). Es protección de ramas como código.
2. Activa en el ruleset *Require branches to be up to date before merging* (`strict_required_status_checks_policy`). ¿Qué te obliga a hacer cuando dos PR tocan `main` uno detrás de otro? ¿Por qué lo usan los equipos grandes?
3. Busca en la documentación de GitHub qué es una ***merge queue*** y qué problema de la regla anterior resuelve.

## Destruir al terminar

Nada que destruir. El ruleset de `lab-actions` puede quedarse.

## Cierre

En `notas/fase-7/clase-84.md`:

1. ¿Qué cuatro reglas pusiste en `main` y qué impide cada una?
2. ¿Por qué la lista de excepciones debe quedar vacía para que el criterio de salida sea verdad?
3. Una prueba pasa en tu portátil y falla en el runner. Nombra tres diferencias entre los dos entornos que podrían explicarlo.
4. **Repaso (clase 83, sin mirar):** ¿para qué sirve `concurrency` con `cancel-in-progress`?

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
