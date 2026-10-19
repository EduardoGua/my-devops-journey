# Fase NOC — Monitoreo, operación y CCST

**Horas:** 70–90 h. Es propia de este repo: viene de tu *Plan 6 meses: Analista NOC N1* (2026-10-19) y no está en la Ruta 2.0.
**Dónde va:** entre la fase 3 (Redes) y la fase 4 (Python).
**Al terminar:** tienes la **CCST Networking** de Cisco, un laboratorio de monitoreo con Zabbix publicado en tu repo (el **P3**) y lo básico de ITIL para trabajar con tickets y SLA. Desde que apruebas la CCST postulas a **Analista NOC N1** y a **soporte o mesa de ayuda N1**, mientras terminas esta fase y sigues con la fase 4.

El NOC (*Network Operations Center*) es el puesto de entrada más cercano a DevOps y SRE: monitoreo, alertas, incidentes, Linux y redes. Lo que más se repite en las ofertas NOC revisadas en Bogotá: redes básicas, Zabbix u otra herramienta de monitoreo, gestión de tickets con SLA, ITIL, acceso por SSH y turnos 7x24. La mesa de ayuda N1 queda más lejos de la infraestructura, pero postulas a las dos a la vez: varias ofertas NOC aceptan un año en mesa de servicio o soporte técnico como experiencia.

## Lo que ya tienes de las fases 1 a 3

El plan NOC dedicaba sus primeras 15 semanas a Linux y redes. Casi todo eso ya está en tus clases, así que aquí no se repite:

| Del plan NOC | Dónde lo cubre la ruta |
|--------------|------------------------|
| Permisos, usuarios y `sudo` | clases 06 y 09 |
| Procesos, servicios y logs: `ps`, `top`, `systemctl`, `journalctl`, `tail -f` | clases 11 a 13 |
| SSH con llaves a una VM | clases 08 y 15 (Multipass en lugar de VirtualBox) |
| Detener un servicio, encontrarlo en los logs y levantarlo | clases 12 y 13, y el P1 |
| Red desde Linux: `ip a`, `ip route`, `ping`, `traceroute`, `ss`, `dig`, `curl` | clases 26 a 34 |
| TCP/IP y OSI, IPv4, máscaras y subredes, DNS y NAT | clases 26 a 31 |
| Runbook "servicio caído en un servidor Linux" | P1 — Runbook de incidentes (clase 36) |

Lo nuevo es lo que piden las ofertas y la ruta no tenía: redes de Cisco con la CCST, Zabbix, ITIL y la búsqueda de un empleo NOC.

## Bloques

| Bloque | Qué | Recurso principal | Horas |
|--------|-----|-------------------|-------|
| A. Redes de Cisco y CCST | switches, MAC y ARP, VLANs, DHCP, Wi-Fi, cableado y fibra, comandos `show` de Cisco IOS y Packet Tracer | Networking Basics, de Cisco Networking Academy (NetAcad) | 30–40 h |
| B. Monitoreo con Zabbix | Zabbix server y agente en dos VMs, ítems, un trigger con aviso y un incidente simulado | documentación oficial de Zabbix | 25–30 h |
| C. Operación con tickets | ITIL a nivel práctico, tickets y una hoja de troubleshooting | esta página | 8–10 h |
| D. ★ Hito NOC | CV, LinkedIn, historias de entrevista y postulaciones | esta página y la [clase 91](../fase-7/clase-91-hito.md) como referencia | 8–10 h, y después 2–3 h por semana aparte |

Esta fase no tiene clases propias todavía. En el bloque A el recurso principal es NetAcad, y en el B, la documentación de Zabbix. Si quieres clases como las de las fases 1 a 3 (con Rómpelo, reto y autocorrección) para los bloques B y C, pídeme `escribe la fase NOC` al terminar la clase 38: así las versiones y los comandos estarán al día.

## Cómo encajan

```
A. CCST ──► CCST aprobada ──► D. ★ Hito NOC: CV, LinkedIn y postulaciones (cada semana, hasta conseguir empleo)
                  │
                  └──► B. Zabbix ──► C. Tickets e ITIL ──► Fase 4 — Python
```

No esperes a terminar el laboratorio de Zabbix para postular: empiezas en cuanto apruebas la CCST. Las postulaciones van aparte de tus 7 h del curso (2 o 3 h por semana). Si no te alcanza, alarga el bloque B, pero no dejes las postulaciones.

---

## A. Redes de Cisco y CCST · 30–40 h

**Meta:** aprobar la [CCST Networking (100-150)](https://www.cisco.com/site/us/en/learn/training-certifications/exams/ccst-networking.html). Es el primer paso de Cisco hacia la CCNA, se presenta en español y no tiene prerrequisitos (precio y duración en *Datos que caducan*).

**Ruta de estudio:** la *Network Technician Career Path* de [NetAcad](https://www.cisco.com/site/us/en/learn/training-certifications/training/netacad/index.html), gratis y a tu ritmo, empezando por **Networking Basics** (unas 22 h). Como la fase 3 ya te dio IP, subredes, DNS y NAT, en esos módulos ve rápido y usa sus cuestionarios como repaso. El tiempo va a lo nuevo:

1. Switches, direcciones MAC y ARP.
2. VLANs básicas.
3. DHCP: cómo un equipo recibe IP, máscara, gateway y DNS.
4. Wi-Fi: estándares, bandas y seguridad (WPA2/WPA3).
5. Cableado de cobre y fibra, a nivel básico.
6. Cisco IOS: los comandos `show` (`show ip interface brief`, `show vlan brief`, `show running-config`) y el diagnóstico con `ping`, `traceroute` e `ipconfig` en Windows.
7. Subnetting: diez ejercicios por sesión hasta que te salgan sin pensar (clase 28).

**Packet Tracer:** el simulador de redes de Cisco. Se descarga desde NetAcad con tu cuenta y tiene instalador para Ubuntu.

**Entregables**

- Networking Basics terminado, con su insignia digital.
- Una red pequeña en Packet Tracer: dos VLANs, DHCP y salida a internet, guardada en `projects/p3-noc-lab/packet-tracer/`.
- El examen final de Networking Basics con un 80 % o más, y la CCST agendada.
- **CCST Networking aprobada.**

## B. Monitoreo con Zabbix · 25–30 h

**Meta:** poder decir en una entrevista "monté Zabbix, configuré alertas y llevé un incidente de la alerta al cierre".

Zabbix, porque es la herramienta que más aparece en las ofertas NOC revisadas: unas piden manejo básico de Zabbix, otras Nagios o Zabbix, y otras Zabbix con SSH, ITIL y cursos de Cisco o MikroTik.

**Laboratorio** (guía: la [documentación oficial de Zabbix](https://www.zabbix.com/documentation/current/))

1. Dos VMs con Multipass:
   - `zabbix-01`, con Zabbix server, el frontend web y su base de datos (2 GB de RAM);
   - `servidor-01`, con el agente de Zabbix y nginx. Puedes crearla con tu cloud-init del P2 (clase 37).
2. Instala Zabbix desde sus paquetes oficiales para Ubuntu, en la versión LTS vigente.
3. Monitorea en `servidor-01` la CPU, el disco, el servicio nginx y un ping (ICMP) a otro equipo.
4. Crea un trigger para "nginx caído" y un aviso por correo o por Telegram.
5. **Rómpelo:** detén nginx (y en otra prueba, llena el disco). Recibe la alerta, abre el ticket (bloque C), arréglalo y ciérralo. Apunta la hora de cada paso.
6. Opcional: un *web scenario* de Zabbix que compruebe las mismas URLs que vigila Vigía. En la entrevista podrás comparar tu monitor con una herramienta del mercado.

Con 8 GB de RAM en tu portátil alcanzan las dos VMs. Al terminar cada sesión, `multipass stop` para liberar memoria.

**El registro del incidente.** Rellenas los campos con tus datos; no hace falta redactar más. Este es el modelo:

```
Incident: INC-001 · Priority: P2 (impact: high, urgency: medium)
Alert:    2027-03-10 21:04 · Zabbix trigger "nginx is down on servidor-01"
Ticket:   opened 21:06 · resolved 21:19 · closed 21:25
Checked:  systemctl status nginx → inactive (dead); journalctl -u nginx → stopped at 21:03
Fix:      sudo systemctl start nginx; the trigger went back to OK at 21:19
Prevent:  also alert on port 80 (net.tcp.service), not only on the process
```

**Entregables**

- `projects/p3-noc-lab/` con un README en inglés: pasos, capturas y la configuración exportada.
- El incidente simulado de punta a punta, con su registro.

## C. Operación con tickets · 8–10 h

ITIL a nivel práctico, sin pagar la certificación:

- **Incidente, problema, solicitud y cambio:** un servicio caído es un incidente; que se caiga cada lunes es un problema; una cuenta nueva es una solicitud; actualizar nginx es un cambio.
- **Prioridad = impacto × urgencia.** El SLA fija en cuánto tiempo hay que responder y resolver según la prioridad.
- **Escalar de N1 a N2:** cuando el arreglo está fuera de tus permisos o de tu runbook, o el SLA se va a vencer. Escalas con lo que ya comprobaste, no con "no funciona".

**Tickets de práctica:** en Jira (plan gratuito) o en los *issues* de un repo de GitHub, con etiquetas de tipo (`incident`, `request`…) y de prioridad (`P1`…`P4`). En las ofertas de la región aparecen ServiceNow y Jira. Los casos te los doy yo: pídeme `tickets de práctica NOC`.

**Hoja de troubleshooting:** una tabla con los comandos que usarías en un turno, sacada de tus chuletas de las fases 1 y 3. Una fila por síntoma, por ejemplo:

| Síntoma | Comandos | Qué miras |
|---------|----------|-----------|
| Una web no responde | `ping`, `dig`, `curl -v`, `ss -tlnp` | dónde se corta: red, DNS, puerto o aplicación |

**Entregables**

- 5 tickets de práctica con tipo, prioridad y estado (abierto → en curso → resuelto → cerrado), uno de ellos escalado a N2.
- La hoja de troubleshooting en `projects/p3-noc-lab/troubleshooting.md`.

## D. ★ Hito NOC: postular · desde que apruebas la CCST

**CV y LinkedIn**

- **CV de una página**, en español, y en inglés para los puestos remotos: la CCST y las insignias de NetAcad, el enlace a tu repo (P1 y P3) y a Vigía.
- **Habilidades con las palabras de las ofertas:** Linux, TCP/IP, DHCP, DNS, VLANs, Zabbix, SSH, gestión de tickets, ITIL y Cisco Packet Tracer.
- **Tu trabajo actual cuenta:** atención al cliente, responsabilidad y disponibilidad para turnos largos. Si haces tareas reales de tecnología (red, equipos, punto de venta), escríbelas y pide un certificado laboral solo con lo que de verdad haces.
- **Titular de LinkedIn:** "Soporte N1 / NOC · Linux · Redes · Zabbix · CCST Networking".

**Postulaciones**

- **5 a 10 por semana** en elempleo, Computrabajo, Magneto y LinkedIn: la mitad a NOC N1 y la otra mitad a soporte o mesa de ayuda N1.
- **Busca con:** "NOC", "monitoreo", "mesa de servicio", "soporte N1", "help desk".
- **Prioriza** las que piden bachiller, estudiante o menos de un año de experiencia. Son pocas, pero existen.
- **Regístralas** en `notas/empleo/postulaciones.md`: fecha, empresa, puesto, enlace, estado y próximo paso.

**Entrevista: cinco historias cortas**

1. Cómo diagnosticas "no hay internet", paso a paso y capa por capa.
2. El incidente simulado de tu laboratorio, de la alerta al cierre.
3. Cómo priorizas tres tickets que llegan a la vez.
4. Por qué aceptas turnos rotativos y nocturnos.
5. Una presentación tuya de 60 segundos en inglés técnico básico.

Para cada una, tres o cuatro puntos con datos (no un texto). Las practicas en voz alta: pídeme `haz de entrevistador para analista NOC`.

## Barreras y cómo atacarlas

La barrera más dura no es el conocimiento sino la experiencia certificada. El plan la ataca postulando a los puestos que menos la piden.

| Barrera | Qué piden las ofertas | Cómo la atacas |
|---------|-----------------------|----------------|
| Experiencia certificada | 1–2 años, con certificados laborales que digan las funciones | Primer empleo en soporte o mesa de ayuda N1 si el NOC no sale; a los 12 meses, postulas a NOC. Documenta las tareas de tecnología que ya haces. |
| Título técnico o tecnólogo | casi todas; alguna NOC pide solo bachiller | La CCST y las insignias de NetAcad compensan en parte: postula igual si cumples lo demás. A largo plazo, el tecnólogo virtual del SENA en Gestión de Redes de Datos (gratis, unas 4 h diarias). |
| Turnos 7x24 | habituales en NOC | Se pagan con recargos. Es el costo del primer año. |
| Inglés | los remotos y mejor pagados piden B2 o más | Tu plan de inglés sigue en paralelo; para las entrevistas, primero el inglés técnico básico. |

Muchas ofertas NOC de entrada pagan cerca del salario mínimo. El salto salarial llega con redes sólidas, inglés y, después, con lo que aprendes en las fases 4 a 7.

## Si consigues el empleo

- **La ruta sigue** en la fase 4, con las horas que te dejen los turnos. Recalcula cada mes la fecha del hito Cloud/DevOps, como siempre.
- **Lo que vivas en el turno es tu material:** incidentes reales, Zabbix y tickets son tus historias STAR para la clase 91, y ese puesto irá primero en la sección *Experience* de tu CV.
- **La CCNA es opcional.** Hazla solo si tu empleo la valora o decides especializarte en redes, porque compite en tiempo con el CLF de la fase 6. Comprueba sus datos en cisco.com antes de pagar.
- **El siguiente salto:** NOC N2, soporte cloud o SRE junior. Es el hito Cloud/DevOps de la clase 91.

## Criterios de salida

Se marcan en [`PROGRESO.md`](../PROGRESO.md), sin mirar:

- CCST Networking aprobada (bloque A)
- Explicas qué es una VLAN y para qué sirve DHCP, y lo muestras en tu red de Packet Tracer (bloque A)
- Zabbix vigila un servidor y la alerta de un servicio caído llega, probada (bloque B)
- Explicas la diferencia entre incidente, problema, solicitud y cambio, y cómo se calcula la prioridad (bloque C)
- Diagnosticas en voz alta "no hay internet", paso a paso (fase 3 y bloque C)

## Datos que caducan

Antes de empezar la fase, pídeme `revisa la fase NOC` y lo compruebo de nuevo.

| Dato | Valor | Verificado | Fuente |
|------|-------|------------|--------|
| CCST Networking (100-150) | 125 USD · 50 min · en español · sin prerrequisitos | 2026-10-19, según tu plan NOC | cisco.com/site/us/en/learn/training-certifications/exams/ccst-networking.html |
| Networking Basics | gratis, unas 22 h | 2026-10-19, según tu plan NOC | NetAcad |
| Zabbix | versión LTS vigente y paquetes para Ubuntu 26.04 | por comprobar | zabbix.com/documentation |
| Packet Tracer | instalador para Ubuntu; compatibilidad con 26.04 | por comprobar | NetAcad |
| Ofertas NOC en Bogotá | redes, Zabbix, tickets con SLA, ITIL, SSH y turnos 7x24; muchas pagan cerca del mínimo | 2026-10-19 | elempleo.com y co.computrabajo.com (enlaces en tu plan NOC) |
| Tecnólogo SENA en Gestión de Redes de Datos | gratis, virtual, unas 4 h diarias; estuvo en la oferta virtual de 2026 | 2026-10-19, según tu plan NOC | sena.edu.co |

## Siguiente fase

Con la CCST aprobada y el P3 publicado, pídeme `revisa la fase 4` y sigue con la [Fase 4 — Python para automatizar](../fase-4/README.md). Las postulaciones siguen cada semana.
