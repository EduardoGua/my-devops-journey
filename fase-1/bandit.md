# Bandit — la prueba de la fase 1

**Cuándo:** al terminar la fase 1 (después de la clase 21 y del repaso del bloque C), en sesiones de 20–30 minutos. Puedes seguir con la fase 2 a la vez: **nunca en lugar de la clase del día.**
**Objetivo:** niveles 0–20 (hasta entrar en `bandit20`) antes del examen de fundamentos (clase 38). La mayoría de niveles usan las clases 01–21; del 13 al 17 necesitas además la clase 29 (fase 3), sin pistas de la clase: es tu examen práctico de Linux.

## Qué es

[OverTheWire Bandit](https://overthewire.org/wargames/bandit/) es un juego gratuito: te conectas por SSH a un servidor y, en cada nivel, tienes que encontrar la contraseña del siguiente usando comandos de Linux. Es el mejor entrenamiento para la terminal que existe, y aparece en muchos CVs de juniors de seguridad y DevOps.

```bash
ssh bandit0@bandit.labs.overthewire.org -p 2220
# contraseña del nivel 0: bandit0
```

## Reglas

1. **Sin buscar soluciones.** Las instrucciones de cada nivel indican qué comandos pueden servir: usa `man`.
2. **Las contraseñas no van a git.** Guárdalas en `~/bandit-claves.local`, fuera del repo. Y si algún día la guardas dentro, el `.gitignore` la ignora (`bandit-claves*`).
3. **Una línea por nivel** en tu registro, que **sí** va al repo, explicando la técnica, nunca la contraseña.

## Registro

Crea `notas/bandit.md`:

```markdown
| Nivel | Técnica (sin la contraseña) | Clase relacionada |
|-------|-----------------------------|-------------------|
| 0→1 | (lo que hiciste) | 01 |
| 1→2 | (lo que hiciste) | 03 |
```

## Qué clase te ayuda en cada tramo

| Niveles | Te apoyas en |
|---------|--------------|
| 0–6 | Clases 02, 03 (rutas, archivos raros, ocultos) y 05 (`find -size`). Nuevo para ti: `find -user/-group` (míralo con `man`) |
| 7–12 | Clase 05 (`grep`, `sort`, `uniq`), 07 (`tr`) y 03 (archivos comprimidos). Nuevos para ti: `strings`, `base64` (míralos con `man`) |
| 13–17 | Clases 15 (llaves SSH) y 29 (`nc`, puertos, `openssl s_client`) |
| 18–20 | Clase 07 (shell), 06 (setuid) y 29 (`nc`, si pasas al 21) |

Actualiza en `PROGRESO.md` el nivel en el que vas.
