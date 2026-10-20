# Mis notas

Aquí van **tus** cierres: un archivo por clase, con tus palabras. No copies la lección.

```
notas/fase-1/clase-01.md
notas/fase-1/clase-02.md
...
```

## Plantilla

No hace falta copiarla a mano: este comando crea el archivo de la clase con las preguntas del cierre ya puestas.

```bash
bash ~/my-devops-journey/recursos/nueva-nota.sh 04      # el número de la clase
```

Así queda una nota cerrada. La línea `Tiempo:` la rellena `cerrar-clase.sh` con lo que mediste con `sesion.sh`:

```markdown
# Clase 01 — La terminal, el shell y el kernel
Fecha: 2026-10-05
Tiempo: 1 h 10 min en 2 sesiones

## Cierre
1. ...
2. ...
3. ...
4. (repaso, sin mirar) ...

## Autocorrección
Cierre: 1 ✅ · 2 🟡 · 3 ✅ · 4 ✅
Reto: 1 ✅ · 2 ✅ · 3 ❌ · 4 ✅   (el reto se hace en la terminal: aquí solo la marca)

Correcciones (una por cada 🟡 o ❌, con tus palabras, sin copiar la clase):
Corrección cierre 2: ...
Corrección reto 3: ...
```
