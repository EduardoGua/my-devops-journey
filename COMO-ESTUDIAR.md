# Cómo estudiar este curso

Léelo una vez entero. Después vuelve solo cuando tengas una duda sobre el método.

## Tu rutina

1. Abre [`PROGRESO.md`](PROGRESO.md). Ahí está la clase que toca.
2. Haz la clase **con la terminal abierta al lado**, escribiendo tú cada comando. No los copies y pegues: escribirlos es parte del aprendizaje.
3. Escribe tu cierre en `notas/fase-N/clase-XX.md`.
4. **Corrígete** con la sección "Autocorrección" de la clase.
5. Marca la clase en `PROGRESO.md` y guarda en GitHub (ver más abajo).

**Duración:** cada clase lleva entre 60 y 90 minutos. Si un día tienes menos tiempo, haz hasta donde llegues y continúa al día siguiente desde ese punto. Media clase bien hecha vale más que una clase entera a medias.

**Ritmo recomendado:** 4–5 clases por semana. Si puedes estudiar 15 h semanales, añade los retos opcionales y Bandit.

## Cómo está hecha cada clase

| Sección | Para qué |
|---------|----------|
| **Objetivo** | Lo que sabrás hacer al terminar |
| **Por qué importa** | Dónde lo usarás en Cloud/DevOps y en AWS |
| **Teoría** | Lo justo para entender la práctica |
| **Práctica guiada** | Comandos paso a paso. Antes de los importantes verás 🔮 **Predice**: piensa (o escribe) qué crees que pasará *antes* de ejecutarlo |
| **Rómpelo** | Provocas un fallo y lo diagnosticas. Es la parte que más enseña |
| **Reto** | Un problema sin guía, para comprobar que lo entendiste y no solo lo seguiste |
| **Cierre** | 3 preguntas de esta clase + 1 de repaso de una clase anterior |
| **Autocorrección** | Las respuestas, escondidas. Ábrelas **después** de escribir las tuyas |
| **Inglés** | Vocabulario y una frase de entrevista |

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

## Deudas: máximo dos

Una **deuda** es un 🟡 o ❌ sin corrección escrita, o una parte de la clase que no terminaste.
- Con **dos deudas abiertas** no se empieza una clase nueva: primero se cierran.
- Así nada se acumula hasta el examen.

## Repaso: la pregunta 4 del cierre

La última pregunta de cada cierre es de una clase anterior y se responde **sin mirar tus notas**. Si fallas, esa clase vuelve a ser deuda. Es el repaso espaciado, ya incluido en el curso.

**Una vez por semana (15 min):** relee tus cierres de la semana y los términos en inglés.

## Guardar en GitHub al terminar cada clase

```bash
cd ~/my-devops-journey
git status                     # revisa qué va a subir: nunca llaves ni contraseñas
git add .
git commit -m "Clase 03: archivos y directorios"
git push
```

La clase 25 explica qué pasa por dentro. Hasta entonces, usa esta receta tal cual. Tu repo público también es tu portfolio: un historial de commits constante dice mucho de ti.

## ¿Tu Ubuntu o el servidor?

Cada clase indica arriba dónde se practica.

| Dónde | Para qué |
|-------|----------|
| **Tu Ubuntu** | Lo que no puede romper el sistema: archivos, texto, Git, scripts, Docker y Terraform |
| **`servidor-01` (VM)** | Lo que en tu PC sería peligroso o imposible: usuarios y sudo, servicios, firewall, llenar el disco y configurar SSH. También todo lo que imita un servidor remoto, como una EC2 |
| **`servidor-01` + `servidor-02`** | Redes de verdad entre dos máquinas |

Regla de oro: **si el comando empieza con `sudo` y cambia la configuración del sistema, va en la VM.**

## Cuando te atascas

1. Lee el error **completo** y despacio. La mitad de las veces dice exactamente qué pasa.
2. Consulta el manual del comando: `man comando` o `comando --help`.
3. Busca el **mensaje de error exacto** en internet. Eso está bien.
4. Si llevas **15 minutos** atascado en lo mismo, para. Tráeme el comando, la salida completa y lo que ya probaste.

Lo que **no** se hace: buscar la solución del reto o pedirle a una IA que lo resuelva por ti. En la entrevista y en el trabajo estarás solo con el error.

## Dónde va cada cosa

| Ruta | Qué es |
|------|--------|
| [`PLAN.md`](PLAN.md) | El mapa completo: fases, proyectos y puertas |
| [`PROGRESO.md`](PROGRESO.md) | Dónde vas, qué toca hoy y el registro de clases |
| [`fase-1/`](fase-1/README.md) | Las clases de la fase actual |
| `notas/fase-1/` | **Tus** cierres, uno por clase |
| `labs/` | Lo que creas al practicar en tu Ubuntu |
| `projects/` | Los proyectos de portfolio (P1, P2…) |
| `recursos/` | Archivos que usan las clases (logs de ejemplo, configuraciones…) |
