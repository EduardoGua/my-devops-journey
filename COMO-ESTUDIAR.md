# Cómo estudiar este curso

Léelo una vez entero. Después vuelve solo cuando tengas una duda sobre el método.

## Cómo leer las clases

Las clases son archivos Markdown con partes plegables (la autocorrección). Para verlas bien:
- **VS Code** (ya lo tienes): `code ~/my-devops-journey`, abre la clase y pulsa `Ctrl+Shift+V` para la vista previa. Ponla en una mitad de la pantalla y la terminal en la otra.
- **GitHub**: en la web de tu repo se ven igual de bien, también desde el móvil para repasar.

Con `cat`, `less` o `nano` las respuestas de la autocorrección se ven **sin plegar**: no uses esas herramientas para leer las clases.

## Tu semana (7 horas)

Es la rutina de la Ruta 2.0, adaptada a las clases:

| Cuándo | Qué | Tiempo |
|--------|-----|--------|
| Todos los días | Anki: tu mazo de DevOps y tu mazo de inglés | 10 min |
| 4 días entre semana | Sesión corta: 5 min de calentamiento (escribe **sin mirar** lo que recuerdes de la última sesión y después compruébalo en tu nota), 35 min de clase y 5 min para anotar dónde te quedaste | 45 min |
| Tu día libre | Bloque largo: la versión de Vigía que toca o, si no toca ninguna, la clase más pesada de la semana | 3 h |
| Una vez al mes | Sumar tus horas, apuntarlas en la Ruta 2.0 y recalcular la fecha del hito | 20 min |

**Una clase ocupa casi siempre dos sesiones cortas:**
1. Sesión 1: Objetivo, Teoría y Práctica guiada.
2. Sesión 2: Rómpelo, Reto, Cierre y Autocorrección.

Si una clase dura 90 minutos o más, o es de VM (arrancar la máquina y retomar el contexto cuesta tiempo), llévala al bloque largo. Si te quedas a mitad, anota el apartado exacto y empieza por ahí la próxima vez. Media clase bien hecha vale más que una clase entera a medias.

**Ritmo esperado:** unas 3 clases por semana mientras el bloque largo es para clases (fase 1 hasta la clase 20), y 2 cuando el bloque largo es para Vigía. Con 5 h por semana: tres sesiones cortas y un bloque de 2 h. Con 10 h: cinco o seis sesiones cortas y un bloque de 4 h.

## Tu rutina en cada clase

1. Abre [`PROGRESO.md`](PROGRESO.md): tu clase es la primera sin marcar.
2. Haz la clase **con la terminal abierta al lado**, escribiendo tú cada comando. No los copies y pegues: escribirlos es parte del aprendizaje.
3. Crea tus notas con las preguntas ya copiadas y responde en ese archivo:
   ```bash
   bash ~/my-devops-journey/recursos/nueva-nota.sh 04      # el número de la clase
   ```
4. **Corrígete** con la sección "Autocorrección" de la clase y **califica** cada respuesta (✅ 🟡 ❌). Sin calificación, la clase no está cerrada: es lo que te dice qué repasar.
5. Pasa a Anki: los términos de la sección Inglés y cada pregunta del cierre que tuviste en 🟡 o ❌. Etiquétalas por tema (`tema::Linux`, `tema::Redes`…) para poder suspender las fases que aún no empiezas.
6. Marca la clase en `PROGRESO.md` con la fecha y anota el tiempo en el registro. Esa columna te da las horas del mes para la Ruta.
7. Guarda en GitHub (ver más abajo).

## Cómo está hecha cada clase

| Sección | Para qué |
|---------|----------|
| 💡 **La idea de hoy** | La clase en dos frases y con una imagen cotidiana. Léela antes de empezar: es el gancho del que cuelga todo lo demás |
| **Objetivo** | Lo que sabrás hacer al terminar |
| **Por qué importa** | Dónde lo usarás en Cloud/DevOps y en AWS |
| **Teoría** | Lo justo para entender la práctica |
| **Práctica guiada** | Comandos paso a paso. Antes de los importantes verás 🔮 **Predice**: piensa (o escribe) qué crees que pasará *antes* de ejecutarlo |
| **Rómpelo** | Provocas un fallo y lo diagnosticas. Es la parte que más enseña |
| **Reto** | Un problema sin guía, para comprobar que lo entendiste y no solo lo seguiste |
| **Cierre** | 3 preguntas de esta clase + 1 de repaso de una clase anterior |
| **Autocorrección** | Las respuestas, escondidas. Ábrelas **después** de escribir las tuyas |
| **Inglés** | Vocabulario y una frase de entrevista |

Las clases de **proyecto** (Vigía y los laboratorios P1 y P2) cambian un poco: requisitos, pistas graduales que abres de una en una, un Rómpelo para probar tu entrega y un entregable.

A veces verás un recuadro **🔁 Vuelve a la clase…**: una idea que ya viste regresa con más detalle. No es repetición: cada vuelta añade una capa.

### Por qué funciona este método

Cuatro ideas de la investigación sobre el aprendizaje, y dónde las aplica el curso:

| Idea | Qué significa | Dónde la ves |
|------|---------------|--------------|
| **Recuperar, no releer** | Sacar algo de tu memoria lo fija mucho más que volver a leerlo. Releer da sensación de dominio, pero se olvida pronto | el calentamiento sin mirar, el cierre, Anki |
| **Espaciar** | Repasar un tema cuando ya lo estás olvidando refuerza más que repasarlo enseguida | la pregunta 4 del cierre, los repasos de bloque, Anki |
| **Mezclar** | Practicar temas mezclados te obliga a elegir qué herramienta usar, que es lo que pasa en el trabajo | los repasos de bloque y los Rómpelo |
| **Equivocarse antes de saber** | Predecir y fallar marca ese momento como importante | el 🔮 Predice y el Rómpelo |

Lo que **no** funciona aunque lo parezca: subrayar, releer la clase o ver vídeos sin escribir comandos.

### Por qué el 🔮 Predice

Cuando predices y fallas, tu cerebro marca ese momento como importante y lo recuerdas. Cuando solo ejecutas y miras, se olvida pronto. Predecir mal es útil: es justo la confusión que estás corrigiendo.

## Autocorrección: eres tu propio profesor

Al terminar el cierre, abre la autocorrección y califica cada respuesta:

| Nota | Significa |
|------|-----------|
| ✅ | Coincide con la idea clave, dicha con tus palabras |
| 🟡 | Idea a medias o te falta el porqué |
| ❌ | Incorrecta o confundes conceptos |

Para cada 🟡 o ❌, añade debajo de tu respuesta una línea con `Corrección:` y la idea bien explicada **con tus palabras**. No copies la respuesta del curso.

Si quieres una segunda opinión, escríbeme `revisa clase-XX` y la reviso con el listón de una entrevista.

Lo que puedes pedirme, tal cual:

| Pídeme | Y hago |
|--------|--------|
| `revisa clase-XX` | reviso tu cierre y tus notas de esa clase |
| `revisa la fase N` | **antes de empezar cada fase:** compruebo que sus versiones, precios y comandos siguen al día, corrijo lo que haya cambiado y le añado lo que ya tiene la fase 1 (la idea de hoy y los repasos de bloque) |
| `revisa examen …` | corrijo tu examen (fundamentos, fases 4 a 7 o fases 8 a 10) con su rúbrica |
| `haz de entrevistador para <puesto>` | un simulacro de entrevista, técnica y de comportamiento |
| `cierra la ruta` | al terminar la clase 125: revisamos tu progreso, tu CV y los próximos tres meses |

## Deudas: máximo dos

Una **deuda** es un 🟡 o ❌ sin corrección escrita, o una parte de la clase que no terminaste.
- Con **dos deudas abiertas** no se empieza una clase nueva: primero se cierran.
- Así nada se acumula hasta el examen.

## Repaso

- **La pregunta 4 del cierre** es de una clase anterior y se responde **sin mirar tus notas**. Si fallas, esa clase vuelve a ser deuda.
- **Repaso de bloque** (fase 1: al terminar los bloques A, B y C): unas 12 preguntas que mezclan todas las clases del bloque y algunas de los anteriores, sin mirar, y al final tu propia chuleta de memoria. Unos 45 minutos. Lo que falles va a Anki y te dice qué clase repasar.
- **Anki, cada día:** las tarjetas que vas creando en el paso 5. En un día pesado, 10 minutos de Anki cuentan como día cumplido.
- **Antes de cambiar de fase:** una sesión para repasar y marcar los criterios de salida en `PROGRESO.md`, solo los que cumples sin mirar.

## Proyecto, inglés y portafolio

- **Vigía** vive en su propio repositorio (`~/vigia`), fuera de este. Desde la fase 2, sus mensajes de commit y su README van en **inglés**: es práctica diaria sin tiempo extra, y quien revise tu GitHub lo verá.
- Las notas del curso siguen en español.

## Guardar en GitHub al terminar cada clase

```bash
cd ~/my-devops-journey
git status                     # revisa qué va a subir: nunca llaves ni contraseñas
git add .
git commit -m "Clase 03: archivos y directorios"
git push
```

La clase 22 explica qué pasa por dentro. Hasta entonces, usa esta receta tal cual. Tu repo público también es tu portafolio: un historial de commits constante dice mucho de ti.

## ¿Tu Ubuntu o el servidor?

Cada clase indica arriba dónde se practica.

| Dónde | Para qué |
|-------|----------|
| **Tu Ubuntu** | Lo que no puede romper el sistema: archivos, texto, scripts, Git, Docker y Terraform |
| **`servidor-01` (VM)** | Lo que en tu PC sería peligroso o imposible: usuarios y sudo, servicios, firewall, llenar el disco y configurar SSH. También todo lo que imita un servidor remoto, como una EC2 |
| **`servidor-01` + `servidor-02`** | Redes de verdad entre dos máquinas |

Regla de oro: **si el comando empieza con `sudo` y cambia la configuración del sistema, va en la VM.** Instalar una herramienta de desarrollo como `shellcheck` en tu Ubuntu está bien.

## Cuando te atascas

1. Lee el error **completo** y despacio. La mitad de las veces dice exactamente qué pasa.
2. Consulta el manual del comando: `man comando` o `comando --help`.
3. Busca el **mensaje de error exacto** en internet. Eso está bien.
4. Si llevas **15 minutos** atascado en lo mismo, para. Tráeme el comando, la salida completa y lo que ya probaste. Si un tema no te entra, pídeme que te guíe con preguntas en lugar de darte la respuesta.

Lo que **no** se hace: buscar la solución del reto o pedirle a una IA que lo resuelva por ti. En la entrevista y en el trabajo estarás solo con el error.

**Reglas para no soltar la ruta** (de la Ruta 2.0): nunca dejes pasar dos semanas sin tocar el proyecto; si pierdes una semana, no dupliques horas para recuperarla, retoma el ritmo normal y recalcula; cada 8 semanas, una semana liviana de solo Anki y lectura; lo difícil va en el bloque largo, y los días cansados son para Anki, lectura y Bandit.

## Dónde va cada cosa

| Ruta | Qué es |
|------|--------|
| [`PLAN.md`](PLAN.md) | El mapa: las 10 fases, Vigía, certificaciones y empleo |
| [`PROGRESO.md`](PROGRESO.md) | Dónde vas, qué toca hoy, criterios de salida y el registro de clases |
| [`fase-1/`](fase-1/README.md) … [`fase-10/`](fase-10/README.md) | Las 125 clases, una carpeta por fase. Cada README dice qué necesitas, sus criterios de salida y sus datos que caducan |
| `notas/fase-N/` | **Tus** cierres, uno por clase |
| `labs/` | Lo que creas al practicar en tu Ubuntu |
| `projects/` | Los laboratorios integradores P1 y P2 |
| `recursos/` | Archivos que usan las clases (logs de ejemplo, scripts de averías…) y las pruebas de aceptación de Vigía, en `recursos/vigia/v1/` … `v7/` |
| `~/vigia` | Tu proyecto de portafolio, en su propio repositorio |
| Ruta Cloud & DevOps 2.0 | El registro mensual de horas y el recálculo de fechas |
