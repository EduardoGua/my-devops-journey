# Clase 28 — P1: Runbook de incidentes

**Dónde:** VM nueva `incidentes` + tu PC · **Tiempo:** 3–4 sesiones · **Bloque:** E. Proyectos · **Proyecto de portfolio**

## Objetivo

Resolver **siete incidentes reales**, sin saber de antemano qué se ha roto, sobre una pequeña tienda online (nginx + API en Python), y documentarlos como un **runbook profesional en inglés** que pondrás en tu GitHub.

Este proyecto demuestra lo que piden las ofertas junior: *"troubleshooting Linux systems"*, *"incident response"*, *"documentation"*.

## Qué es un runbook

Un **runbook** es la guía que usa la persona de guardia cuando salta una alerta a las 3 de la mañana: síntomas, cómo investigar, cómo arreglarlo y cómo evitar que se repita. Los equipos de SRE y de plataforma los escriben después de cada incidente. Un buen runbook permite que **otra persona** resuelva el mismo problema en minutos.

## La tienda

```
 Tu PC ──HTTP :80──► VM "incidentes"
                     ├── ufw: 22, 80
                     ├── nginx :80  (sitio "shop")
                     │     ├── /       → archivos de /var/www/shop
                     │     └── /api/   → proxy a http://api.shop.internal:8080
                     ├── /etc/hosts: api.shop.internal → 127.0.0.1
                     └── shopapp.service (python, usuario shopapp) en 127.0.0.1:8080
                           ├── necesita la variable DB_HOST
                           └── escribe cada petición en /var/lib/shop/requests.log
```

**Comprender esta arquitectura antes de empezar ya es la mitad del diagnóstico.** Estúdiala 5 minutos.

## Preparación

Desde tu PC:
```bash
multipass launch lts --name incidentes --cpus 1 --memory 1G --disk 8G
multipass transfer ~/my-devops-journey/recursos/clase-28/incidentes.sh incidentes:/home/ubuntu/
multipass exec incidentes -- chmod +x /home/ubuntu/incidentes.sh
multipass exec incidentes -- sudo /home/ubuntu/incidentes.sh preparar
```

Debe terminar con `✅ La tienda funciona.` Haz un snapshot del estado sano:
```bash
multipass stop incidentes && multipass snapshot incidentes --name sana && multipass start incidentes
```

Comprueba desde tu PC:
```bash
IPI=$(multipass info incidentes | awk '/IPv4/ {print $2}')
curl -s http://$IPI/ ; curl -s http://$IPI/api/
```

Añade la llave y una entrada `incidentes` en tu `~/.ssh/config` (como en la clase 24) para trabajar con `ssh incidentes`.

> 🙈 **Regla de honor:** no leas `incidentes.sh` más allá de su cabecera hasta terminar el proyecto. Si lo lees, el ejercicio se convierte en seguir instrucciones, y en una entrevista se notará.

## Cómo trabajar cada incidente

```bash
ssh incidentes sudo ./incidentes.sh lista            # los 7 avisos, como los reportaría un usuario
ssh incidentes sudo ./incidentes.sh romper 1          # provoca el incidente 1 sobre una tienda sana
```

Después:
1. **Empieza desde fuera, como el usuario:** `curl -sv http://$IPI/` y `/api/`. Anota el síntoma exacto (código, tiempo, mensaje).
2. **Sigue tu checklist de la clase 24**, capa a capa. Anota **cada comando** y lo que te enseñó.
3. Formula una hipótesis, compruébala y **arréglalo tú**, a mano. El script no lo arregla por ti.
4. Verifica: `ssh incidentes sudo ./incidentes.sh comprobar` → `✅`. **Y además desde tu PC con `curl`**: algunos fallos solo se ven desde fuera.
5. Escribe la entrada del runbook (plantilla más abajo).
6. Siguiente incidente: `sudo ./incidentes.sh romper N` ya parte de una tienda sana.

Si te quedas atascado **más de 30 minutos** en uno, usa las pistas graduales del final. Una sola pista cada vez.

## Entregable

Crea la carpeta del proyecto en tu repo:
```bash
mkdir -p ~/my-devops-journey/projects/p1-incident-runbook
```

### `README.md` (en inglés)

```markdown
# P1 — Linux Incident Runbook

Seven production-style incidents on a small web stack (nginx reverse proxy + Python API
managed by systemd, behind ufw), diagnosed blind and documented as an on-call runbook.

## Architecture
(the diagram, in your own words)

## Troubleshooting method
(your layer-by-layer checklist from class 24)

## Incidents
| # | Symptom | Root cause | Time to resolve |
|---|---------|------------|-----------------|
| 1 | ... | ... | 25 min |

## What I learned
(3-5 bullet points)
```

### Un archivo por incidente: `incident-01.md` … `incident-07.md`

```markdown
# Incident 01 — <short title>

## Symptom
What the user saw. Exact output: `curl -sv ...` → `HTTP/1.1 403 Forbidden`

## Impact
What was down, what still worked.

## Investigation
1. `command` → what it showed and what I concluded
2. ...
(include the dead ends: they show your reasoning)

## Root cause
One or two sentences. The real cause, not the symptom.

## Fix
The exact commands, and how I verified it.

## Prevention
How to stop it happening again or detect it sooner (monitoring, config management, review...).
```

El inglés no tiene que ser perfecto: frases cortas y claras. Es práctica para tus futuros postmortems.

## Rómpelo: las pistas

Úsalas **solo** tras 30 minutos atascado, y de una en una.

<details><summary>Incidente 1 — pista</summary>

El código de estado te dice exactamente de qué familia es el fallo. ¿Qué dice `/var/log/nginx/error.log`? Repasa la clase 06 y con qué usuario corren los workers de nginx (clase 11).
</details>

<details><summary>Incidente 2 — pista</summary>

502 = nginx no consigue hablar con el backend. ¿Está vivo el servicio? ¿Y **dónde** escucha (`ss -tlnp`)? Compáralo con lo que espera nginx.
</details>

<details><summary>Incidente 3 — pista</summary>

`systemctl status shopapp` y `journalctl -u shopapp -n 30`. Lee la traza de Python hasta el final: la última línea dice qué falta. Después, mira la unit con `systemctl cat`.
</details>

<details><summary>Incidente 4 — pista</summary>

Una app que de repente devuelve 500 al **escribir**… Lee su log (`journalctl -u shopapp`). Después: `df -h` y `du`. Y recuerda que `ls` no enseña los directorios que empiezan por punto.
</details>

<details><summary>Incidente 5 — pista</summary>

Si nginx no arranca, ¿por qué? `systemctl status nginx`, `nginx -t`. ¿Cómo encuentra nginx a `api.shop.internal`? (clase 21: `getent hosts`).
</details>

<details><summary>Incidente 6 — pista</summary>

¿Refused o timeout desde tu PC? ¿Funciona `curl 127.0.0.1` **dentro** de la VM? Si dentro funciona y fuera no, ¿qué hay en medio? (clase 23)
</details>

<details><summary>Incidente 7 — pista</summary>

`df` y `du` no cuadran (clase 14). ¿Hay algún archivo borrado que siga abierto? `lsof +L1`.
</details>

## Cierre

En `notas/fase-1/clase-28.md`:

1. ¿Qué incidente te costó más y por qué? ¿Qué harías distinto la próxima vez?
2. ¿En cuántos incidentes la causa estaba en una capa distinta de donde se veía el síntoma? Pon un ejemplo.
3. Prepara la historia de **un** incidente con el formato **STAR** (Situación, Tarea, Acción, Resultado) en inglés, para contarla en una entrevista en 2 minutos.
4. **Repaso (clase 27, sin mirar):** ¿por qué no se hace `git push --force` a una rama compartida?

## Autocorrección

<details>
<summary>Ábrelo solo cuando hayas resuelto los 7 incidentes</summary>

| # | Causa raíz | Pista decisiva | Arreglo |
|---|------------|----------------|---------|
| 1 | `index.html` con dueño root y permisos `600`: los workers (`www-data`) no pueden leerlo | `403` + `Permission denied` en `error.log` | `chmod 644 /var/www/shop/index.html` |
| 2 | La unit pone `PORT=8081`, pero nginx envía al 8080 | `502` + `Connection refused` en `error.log`; `ss -tlnp` → `:8081` | corregir `Environment=PORT=8080`, `daemon-reload`, `restart` |
| 3 | Falta `DB_HOST` en la unit: la app muere al arrancar (`KeyError: 'DB_HOST'`) y systemd la reintenta en bucle (`activating (auto-restart)`), y puede acabar en `failed` | `502`; `journalctl -u shopapp` con la traza | restaurar `Environment=DB_HOST=db.shop.internal` (mejor con un drop-in), `daemon-reload`, `reset-failed`, `restart` |
| 4 | Disco lleno por archivos ocultos en `/var/lib/shop/.cache/` | `500` en `/api/`; log: `No space left on device`; `df -h` al 100 %; `du -sh /var/lib/shop/.[!.]*` | borrar `/var/lib/shop/.cache` |
| 5 | Falta `api.shop.internal` en `/etc/hosts`: nginx no arranca (`host not found in upstream`) | tienda entera caída (refused); `nginx -t` | volver a añadir `127.0.0.1 api.shop.internal`, `nginx -t`, `start nginx` |
| 6 | ufw con `DENY` en el 80 | **timeout** desde fuera, OK desde dentro; `ufw status` | `ufw delete deny 80/tcp && ufw allow 80/tcp` |
| 7 | Un `tail -f` mantiene abierto un log de varios GB ya borrado | `df` lleno, `du` no lo encuentra; `lsof +L1` | matar ese proceso (`kill <PID>`) |

**Prevenciones que valen nota:** gestionar la configuración como código y revisarla en PRs (2, 3 y 5); validar antes de aplicar (`nginx -t`, `systemd-analyze verify`); alarmas de disco al 80 % y rotación de logs (4 y 7); health checks **externos**, no solo locales (6); DNS interno real en lugar de `/etc/hosts` (5); permisos aplicados por una herramienta, no a mano (1).

**4.** Porque reescribe la rama remota con tu versión y **borra** los commits que otros subieron y tú no tenías. Se pierde su trabajo y se rompe la historia de quien ya la descargó.
</details>

## Al terminar

- `multipass stop incidentes` (o bórrala: `multipass delete --purge incidentes`; los snapshots se van con ella).
- Sube el proyecto: ramita, PR y merge, como en la clase 27.
- Actualiza `projects/README.md`: estado de P1 → ✅.

## Siguiente

[Clase 29 — P2: Servidor reproducible con cloud-init](clase-29-p2-cloud-init.md)
