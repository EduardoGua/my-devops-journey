# Bandit — práctica paralela

**Cuándo:** desde la clase 05, los días que te sobren 20–30 minutos. **Nunca en lugar de la clase del día.**
**Objetivo:** niveles 0–20 antes del examen de la fase 1.

## Qué es

[OverTheWire Bandit](https://overthewire.org/wargames/bandit/) es un juego gratuito: te conectas por SSH a un servidor y, en cada nivel, tienes que encontrar la contraseña del siguiente usando comandos de Linux. Es el mejor entrenamiento para la terminal que existe, y aparece en muchos CVs de juniors de seguridad y DevOps.

```bash
ssh bandit0@bandit.labs.overthewire.org -p 2220
# contraseña del nivel 0: bandit0
```

## Reglas

1. **Sin buscar soluciones.** Las instrucciones de cada nivel indican qué comandos pueden servir: usa `man`.
2. **Las contraseñas no van a git.** Guárdalas en `~/bandit-claves.local` (está en `.gitignore` y fuera del repo).
3. **Una línea por nivel** en tu registro, que **sí** va al repo, explicando la técnica, nunca la contraseña.

## Registro

Crea `notas/bandit.md`:

```markdown
| Nivel | Técnica (sin la contraseña) | Clase relacionada |
|-------|-----------------------------|-------------------|
| 0→1 | Leer un archivo con cat | 01 |
| 1→2 | Archivo llamado "-": cat ./- | 03 |
```

## Qué clase te ayuda en cada tramo

| Niveles | Te apoyas en |
|---------|--------------|
| 0–6 | Clases 02, 03 (rutas, archivos raros, ocultos), 05 (`find` por tamaño y dueño) |
| 7–12 | Clase 05 (`grep`, `sort`, `uniq`, `strings`, `base64`, `tr`), 03 (archivos comprimidos) |
| 13–17 | Clase 15 (llaves SSH), 19 (`nc`, puertos, `openssl s_client`) |
| 18–20 | Clase 07 (shell), 06 (setuid) |

Actualiza en `PROGRESO.md` el nivel en el que vas.
