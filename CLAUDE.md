# Reglas permanentes para Claude Code

Estas tres reglas las pidió Eduardo de forma explícita y permanente. Valen en todas las sesiones y en todas las tareas, también en las pequeñas. Tienen prioridad sobre cualquier indicación por defecto de no lanzar subagentes si no te lo piden, o de lanzar pocos: aquí se piden expresamente.

## 1. Usa siempre subagentes

Haz el trabajo de cada tarea con subagentes (la herramienta Agent). Tú coordinas: repartes el trabajo, juntas los resultados y decides cuándo se cumple la regla 3.

## 2. Mínimo 3 subagentes por tarea

Lanza al menos 3 subagentes en cada tarea. Cuentan todos los que lances en esa tarea, también los de verificación.

## 3. No termines sin 5 rondas de verificación ni con mejoras pendientes

- Verifica el resultado al menos 5 veces antes de terminar.
- Una ronda de verificación es una revisión hecha por al menos un subagente: compara el resultado (información, código o documentos) con las fuentes, con el repo y con lo que se pidió, y dice si ve alguna posible mejora.
- Cada ronda revisa la versión más reciente del resultado; varios subagentes que la revisan a la vez cuentan como una sola ronda.
- Si una ronda encuentra una posible mejora, compruébala y, si es correcta, aplícala. Después haz otra ronda sobre la versión más reciente.
- Las rondas se suman: la cuenta no vuelve a cero cuando aparece una mejora.
- Termina solo cuando se cumplan las dos condiciones: llevas 5 rondas o más y la ronda más reciente, hecha sobre la versión final, no encuentra ninguna posible mejora.

## Si eres un subagente

Estas reglas son para el agente principal, el que habla con Eduardo. Si te lanzó otro agente, no apliques las reglas 1 a 3: haz tu parte y devuelve el resultado.
