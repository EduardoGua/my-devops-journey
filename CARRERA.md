# La carrera — experiencia y peso a largo plazo

**Versión:** 1.0 · 2026-10-20 · **Opcional:** no es parte de las fases ni de sus criterios de salida.

Este archivo es para decidir con datos lo que no son clases: la experiencia laboral, la formación formal, el inglés, los contactos, el dinero y el equipo. Cubre el tramo **desde hoy hasta que estés asentado en tu primer empleo cloud o DevOps**.

- Lo que viene después (de junior a mid, senior y arquitecto) está en `~/Documentos/ruta-junior-a-arquitecto-nube.md`, que sigue cerrado hasta terminar la fase 8 o hasta que lleves meses en un empleo cloud.
- Las certificaciones, con su orden, su precio y su preparación, están en la [sección 9 de `PLAN.md`](PLAN.md#9-opcional-certificaciones-con-peso).
- Los salarios, convocatorias y condiciones se comprobaron el 2026-10-20 y están al final, con sus fuentes. Antes de decidir algo con dinero o con meses de tu tiempo, pídeme que los revise.

## 1. La idea en cinco frases

1. Casi nadie entra a un puesto DevOps sin experiencia previa: se entra por **operaciones** (NOC, soporte, administración de sistemas) o por desarrollo, y se sube desde dentro.
2. Lo que más pesa al contratar a alguien junior es **haber operado sistemas que otros usan**: incidentes, turnos y tickets. Lo que más pesa después es el **impacto que puedes medir**.
3. Las certificaciones abren filtros, pero no sustituyen ni la experiencia ni el proyecto.
4. El **inglés** es lo que más cambia tus opciones: amplía el mercado al que puedes postular y separa un sueldo local de uno remoto.
5. Tu plan ya apunta bien: un primer empleo NOC pronto, Vigía como prueba de lo que sabes hacer, y la ruta como formación mientras trabajas.

## 2. Qué pesa al contratarte

De más a menos, para un puesto junior en Bogotá. Es mi lectura de las ofertas y del oficio, no una regla: las multinacionales, los bancos y las consultoras filtran más por título e inglés; las empresas pequeñas, más por proyecto y experiencia.

| # | Señal | Por qué pesa | Cómo se consigue | Tú hoy |
|---|-------|--------------|------------------|--------|
| 1 | **Experiencia laboral en operaciones** (NOC, soporte, sysadmin) | demuestra que trabajas con sistemas reales, turnos, presión y procesos | un puesto de entrada (sección 3) | el objetivo del hito NOC |
| 2 | **Un referido** | quien te recomienda responde por ti: es el camino más corto a una entrevista | comunidad y contactos (sección 6) | por construir |
| 3 | **Un proyecto defendible** | prueba lo que sabes hacer, con sus fallos y sus decisiones | Vigía, de la v0 a la v7, con sus *What broke* | en marcha |
| 4 | **Inglés conversacional** (B2) | abre multinacionales, soporte bilingüe y trabajo remoto | sección 5 | lectura cerca de B1; la escucha, lo más débil |
| 5 | **Título en sistemas** (técnico, tecnólogo o profesional) | pasa los filtros automáticos de RR. HH. y, más adelante, los de visados | sección 4 | por decidir |
| 6 | **Una certificación Associate** (la SAA) | aparece como requisito en ofertas de nivel medio | `PLAN.md`, sección 9 | después de la fase 8 |
| 7 | Certificaciones de entrada, cursos e insignias (CCST, CLF…) | suman, pero solas no deciden | ya están en la ruta | en camino |

Lo que **resta** peso: un cargo inflado en LinkedIn ("DevOps Engineer" sin haberlo sido), experiencia inventada, una lista de certificados sin ningún proyecto y un GitHub con ejercicios copiados y nada propio.

## 3. La experiencia laboral, que es lo que más pesa

### 3.1 Los puestos de entrada a TI

Ninguno se llama "DevOps", y todos cuentan como experiencia en TI. Los salarios son orientativos: las muestras son pequeñas, así que mira cada oferta. Como referencia, el salario mínimo de 2026 es de 1.750.905 COP.

| Puesto | Qué suelen pedir | Qué te da para el camino cloud | Salario orientativo |
|--------|------------------|--------------------------------|---------------------|
| **Analista NOC N1** (ya en tu ruta) | redes, monitoreo (Zabbix), tickets con SLA, ITIL, SSH, turnos 7x24 | incidentes reales, guardias y monitoreo: lo más cercano a SRE desde abajo | muchas ofertas pagan cerca del mínimo |
| **Soporte o mesa de ayuda N1** | Windows, cuentas y accesos, tickets, trato con usuarios | procesos de TI, escalado, documentación | mira cada oferta |
| **Soporte técnico bilingüe** (empresas de *outsourcing*) | inglés **B2**, bachillerato, a veces experiencia en soporte | más sueldo, inglés todos los días y, si el producto es software o nube, *troubleshooting* técnico | unos 2,0–3,3 millones COP brutos al mes |
| **Soporte de proveedores de internet o telecomunicaciones** | redes básicas, atención por teléfono o en sitio | redes reales, equipos del cliente, escalado al NOC | mira cada oferta |
| **Aprendiz del SENA** en un área de TI (sección 4) | estar matriculado en un técnico o tecnólogo | experiencia formal en una empresa, con un pago mensual | ligado al salario mínimo |
| **Analista de infraestructura o sysadmin junior** | 1–2 años de soporte o NOC, Linux y redes | el paso directo hacia cloud y DevOps | suele ser más que N1 |

Desde el hito Cloud/DevOps se suman: soporte cloud, junior cloud, junior DevOps, SRE junior y las prácticas o "semilleros" de consultoras (búscalos como *semillero DevOps*, *academia cloud* o *práctica de infraestructura*).

Un aviso sobre el soporte bilingüe: muchas vacantes son de atención al cliente sin nada técnico. Te sirve si el producto es software, telecomunicaciones o nube, y si hay un nivel 2 al que subir. Si solo es atender llamadas comerciales, te paga el inglés pero te aleja del camino.

### 3.2 Cómo convertir un puesto de entrada en experiencia cloud

Lo que te hará pasar de N1 a N2, y de ahí a cloud, es lo que hagas **además de cerrar tickets**. Seis hábitos:

1. **Automatiza algo repetitivo**, con permiso: un script que revisa lo que todos revisan a mano, una plantilla de ticket, un tablero de Zabbix o Grafana. Es el Bash, el Python y la observabilidad de tu ruta, aplicados a un problema real.
2. **Escribe el runbook** de la avería que más se repite. Casi nunca existe, y es tu P1 hecho en el trabajo.
3. **Mide antes y después:** minutos ahorrados por semana, tickets que ya no llegan, tiempo de resolución. Sin número es una anécdota; con número, una historia STAR.
4. **Pide hacer sombra** al equipo de infraestructura o de cloud una hora a la semana, y ofrécete para lo que nadie quiere (documentar, inventariar, limpiar alertas). Así te conocen por dentro.
5. **Mira las vacantes internas** cada mes: N2, infraestructura, cloud. La movilidad interna es la vía más corta, porque ya conocen tu trabajo.
6. **Apunta tus logros cada semana, en una línea**, en una nota privada: `semana · qué hice · herramienta · impacto`. Es la materia prima del CV, de las historias STAR y de la conversación para subir de puesto.

Nunca subas a GitHub nada del trabajo (código, datos, nombres de clientes ni capturas internas). Cuéntalo en tus historias, sin datos que identifiquen a la empresa.

### 3.3 Experiencia que puedes construir tú, sin inflarla

- **Vigía** es experiencia de proyecto, no laboral: va en *Projects*, con su enlace, su versión y lo que se rompió.
- **Trabajos pequeños reales:** la web, el correo o las copias de seguridad de un negocio familiar, una ONG o un conocido. Cuentan si fueron reales y puedes explicar qué hiciste. Ponlos como *Freelance* solo si hubo un cliente de verdad.
- **Contribuciones de código abierto:** una documentación corregida o un error pequeño arreglado en una herramienta que usas (kind, podinfo, un provider de Terraform…). Un PR aceptado en un proyecto conocido es una línea pública que cualquiera puede comprobar.
- **Una charla corta** (5–10 minutos) sobre Vigía en un meetup. Para un perfil junior pesa mucho, y es la defensa de la clase 125 delante de gente.

## 4. La formación formal

En Colombia, muchas ofertas filtran por "técnico, tecnólogo o profesional en sistemas o afines" antes de mirar nada más. Si no tienes un título así, esto es lo que tienes a tu alcance:

| Opción | Coste | Qué te da | En contra |
|--------|-------|-----------|-----------|
| **Tecnólogo del SENA en Gestión de Redes de Datos** (virtual) | gratis | un título tecnológico oficial. La **etapa productiva** (unos 6 meses, al final) suele hacerse con un **contrato de aprendizaje**: experiencia formal en una empresa, con un pago mensual. Las empresas con 15 o más trabajadores están obligadas a tener aprendices, así que hay plazas | unas 4 h diarias en la etapa lectiva: compite con la ruta y con el trabajo |
| **Homologar después a Ingeniería de Sistemas** en la UNAD (universidad pública a distancia) | la UNAD abre convocatorias de **gratuidad de la matrícula** para estratos 1 a 3 sin título universitario previo; cubre parte de los créditos de cada periodo | el título profesional en menos tiempo: la UNAD tiene un acuerdo de homologación para ese tecnólogo desde 2020 | varios años de estudio; tiene sentido cuando ya trabajes en TI |
| **Solo la ruta y las certificaciones** | lo de `PLAN.md` | lo más rápido para el primer empleo | algunas empresas grandes te descartarán por filtro |

Mi recomendación es **decidirlo al llegar al hito NOC**, con esta regla:
- **Si en 3–4 meses de postular no consigues** un puesto NOC o de soporte, el tecnólogo del SENA con contrato de aprendizaje es una forma real de entrar en una empresa por la vía del aprendiz. La ruta sigue, más despacio.
- **Si lo consigues,** prioriza el empleo y la ruta. El tecnólogo (y después la ingeniería) puede esperar a que tengas un horario estable, salvo que tu empresa lo pague o lo pida para subir de puesto.
- **A largo plazo,** un título profesional pesa en tres sitios: las empresas grandes con filtros rígidos, los visados de trabajo en otros países y los puestos de liderazgo o de arquitectura.

Las fechas de inscripción del SENA y de la UNAD, y las condiciones del contrato de aprendizaje, cambian cada año (la reforma laboral de 2025 tocó a los aprendices): compruébalas antes de decidir.

## 5. El inglés: lo que más amplía tus opciones

Hoy lees cerca de un B1, escribes con dudas, hablas menos y entiendes de oído alrededor de un 10 %. En el mercado, cada nivel abre una puerta:

| Nivel | Qué te abre |
|-------|-------------|
| el actual (lectura cerca de B1) | ofertas locales en español; documentación técnica, despacio |
| **B1 conversacional** | entrevistas técnicas en las que te piden leer y explicar algo en inglés; equipos que documentan en inglés |
| **B2** | soporte bilingüe, multinacionales en Bogotá y la mayoría de las ofertas "bilingües" |
| **B2 alto o C1** | trabajo remoto para empresas de fuera, con sueldo en dólares |

Metas razonables, a tu ritmo:
- **Al hito NOC:** entender la idea general de un vídeo técnico lento, con subtítulos en inglés.
- **Al hito Cloud/DevOps:** explicar Vigía en inglés durante 2 minutos sin leer, y entender una entrevista grabada.
- **Uno o dos años después:** un B2 medido.

Cómo hacerlo sin que se coma la ruta (es lo que propone tu `plan-aprender-ingles-autodidacta.txt`, empezando por la escucha):
1. **Escucha primero:** 15–20 minutos al día de algo que entiendas al 70–80 %, con subtítulos en inglés; cuando sea fácil, sin ellos. Y 5 minutos repitiendo frases cortas en voz alta, justo después del audio (*shadowing*).
2. **El vocabulario técnico ya lo tienes:** la sección *Inglés* y la frase 🎙️ de cada clase siguen yendo a Anki.
3. **Hablar:** desde la fase 7, una vez por semana, explícame Vigía en inglés como en una entrevista. Cuando puedas, un club de conversación gratuito (bibliotecas públicas, Meetup).
4. **Medirlo:** un EF SET al cerrar cada fase. Es gratis, dura 50 minutos y el certificado se pone en LinkedIn.

## 6. Comunidad y contactos

Muchos empleos llegan por un referido antes de publicarse. Cuatro hábitos que piden poco tiempo:

1. **Un meetup al mes**, presencial o virtual: los grupos de usuarios de AWS, de Kubernetes y la CNCF, y de DevOps en Bogotá (búscalos en Meetup y LinkedIn). Llega pronto, haz una pregunta y conecta en LinkedIn con dos personas al salir.
2. **Una publicación por versión de Vigía**, con la plantilla de huecos de la clase 125: qué hace, qué se rompió y qué aprendiste.
3. **Pregunta por el trabajo, no por vacantes:** "¿cómo es un día en tu equipo?" abre más puertas que "¿hay vacantes?".
4. **Devuelve cuando puedas:** responder dudas de quien va un paso detrás, o dar la charla de Vigía. Así te recuerdan.

## 7. Lo práctico que se suele olvidar

| Necesidad | Por qué | Qué hacer |
|-----------|---------|-----------|
| **Memoria del portátil** | tu ASUS VivoBook (X413FA) tiene unos 8 GB: alcanza para kind y Grafana, pero se queda corto para varios nodos o para preparar la CKA con `kubeadm` en VMs | antes de la fase 9, comprueba si admite 16 GB. En muchos VivoBook 14 una parte va soldada y hay una ranura libre: mira la ficha de ASUS o el buscador de Kingston o Crucial con tu modelo exacto |
| **Disco** | las imágenes de Docker y los nodos de kind ocupan; hoy tienes unos 92 GB libres | `docker system df` y `docker image prune` al cerrar cada fase |
| **Exámenes en línea** | los de AWS, HashiCorp y la Linux Foundation se pueden presentar en casa, con supervisión: piden cámara, conexión estable, un cuarto en silencio y la mesa vacía | haz la prueba técnica del sistema unos días antes; si tu casa no ayuda, hay centros de examen en Bogotá |
| **Dinero** | unos 370 USD en exámenes a lo largo de la ruta, más la cuenta de AWS | aparta un poco cada mes; compra los exámenes en promoción; nada de *bootcamps* caros |
| **Turnos** | un NOC 7x24 cambia tus horarios cada pocas semanas | ten una "semana mínima": 3 sesiones de 30 minutos y Anki. Recalcula las fechas con lo que hagas de verdad |
| **Salud** | turnos de noche y estudio a la vez acaban agotando | dormir es parte del plan: mejor una fase más lenta que abandonar |
| **Trabajo remoto para fuera** (más adelante) | suele ser por prestación de servicios, sin contrato laboral | RUT, factura electrónica, seguridad social como independiente y declaración de renta: consulta a un contador antes de firmar |

## 8. El camino, por etapas

Los tiempos dependen de tus horas reales (con unas 3 clases por semana, más despacio que la Ruta) y del mercado. Úsalos como orden, no como promesa.

| Etapa | Puesto | Qué tiene que pasar para subir | Tiempo orientativo |
|-------|--------|--------------------------------|--------------------|
| 0 | estudiante (fases 1–3 y NOC) | CCST, P1 a P3, Vigía v0.2 y postular | hasta el hito NOC |
| 1 | NOC N1, soporte N1 o aprendiz | incidentes reales, una automatización medida, fases 4 a 7 y el CLF | 6–18 meses |
| 2 | N2, sysadmin, analista de infraestructura o soporte cloud | ser responsable de algo (un servicio, un proceso), Terraform, la SAA y Vigía v5 o más | 1–2 años |
| 3 | junior cloud, DevOps o SRE | operar producción con supervisión, guardias, revisar el código de otros y que revisen el tuyo | desde 1–3 años en TI |
| 4 | mid, senior y más allá | `ruta-junior-a-arquitecto-nube.md` | años |

Sobre el dinero, para que tus expectativas sean realistas: un DevOps junior en Colombia gana, según las fuentes, unos 3–5 millones COP al mes. Las cifras en dólares que circulan (por ejemplo, unos 2.800 USD de media según Talently) son sobre todo de trabajo remoto para empresas de fuera, que pide inglés B2 alto y experiencia.

Especializaciones que encajan con tu camino, para decidirlas después del primer año en TI, no ahora:
- **SRE:** si te gustan los incidentes, el monitoreo y los SLO de la fase 10. El NOC es su entrada natural.
- **Automatización de redes** (*NetDevOps*): redes (CCST, quizá CCNA) más Python y Ansible. Pocas personas tienen las dos partes, y viene directa de tu fase NOC.
- **Plataforma y DevOps:** pipelines, Kubernetes e infraestructura como código.
- **Seguridad en la nube:** IAM, *hardening* y auditoría.

## 9. Después de la ruta: qué estudiar y cuándo

La regla del archivo de arquitecto sirve desde el primer empleo: **10 % estudio y 90 % impacto**, y cada tema nuevo, pegado a un problema real de tu trabajo. Lo que la ruta deja fuera a propósito (`PLAN.md`, sección 8) entra solo cuando un empleo lo pida: Ansible (sobre todo si vas hacia *NetDevOps*), GitOps con Argo CD o Flux, EKS en producción, OpenTelemetry, la seguridad de la cadena de suministro y FinOps.

Sobre la IA: cada vez más equipos usan asistentes de IA para escribir scripts, infraestructura como código o consultas. Úsalos, pero sabiendo revisar lo que generan: en las entrevistas, y en una caída a las 3 de la mañana, te van a pedir los fundamentos, sin asistente. Por eso los exámenes de la ruta se hacen sin apuntes ni IA.

## 10. Lo que resta peso, y cómo evitarlo

- **Coleccionar certificaciones** sin proyecto ni experiencia: con las de `PLAN.md` basta.
- **Inventar o inflar** el cargo, los años o los clientes: se descubre en la primera pregunta técnica o al verificar referencias.
- **Postular solo a "DevOps":** los puestos de entrada son la puerta; saltárselos hace el camino mucho más largo.
- **Dejar el inglés para después:** es lo más lento de construir.
- **Abandonar Vigía:** un proyecto sin cambios en un año parece abandonado. Actualiza sus versiones (pídeme `revisa la fase N`) y añádele lo que aprendas en el trabajo.
- **Pagar *bootcamps* caros:** con esta ruta, solo pagas exámenes.

## 11. La revisión cada tres meses

Una vez por trimestre, unos 20 minutos, pídeme `revisa la carrera` y repasamos:
- las horas reales y las fechas de los hitos;
- tu último EF SET;
- las postulaciones: cuántas, a qué puestos y cuántas respuestas;
- los contactos nuevos y los meetups;
- los logros apuntados cada semana;
- qué dato de este archivo ha caducado.

## Datos que caducan

| Dato | Valor | Comprobado | Fuente |
|------|-------|------------|--------|
| Salario mínimo de 2026 | 1.750.905 COP | 2026-10-20 | Moving to Colombia (blog) |
| Soporte técnico bilingüe en Bogotá | unos 2,0–3,3 millones COP brutos al mes; inglés B2 | 2026-10-20 | oferta de Foundever en Computrabajo; Moving to Colombia |
| DevOps junior en Colombia | unos 3–5 millones COP al mes, con muestras pequeñas; unos 2.800 USD de media en remoto | 2026-10-20 | Glassdoor, Indeed y Talently |
| Contrato de aprendizaje del SENA | lo paga la empresa; es incompatible con el apoyo de sostenimiento del SENA | 2026-10-20 | SENA y blogs; las cifras exactas, por confirmar |
| Homologación del tecnólogo en Gestión de Redes de Datos a Ingeniería de Sistemas | Acuerdo 065 de 2020 de la UNAD | 2026-10-20 | sgeneral.unad.edu.co |
| Gratuidad de la matrícula en la UNAD | estratos 1 a 3, sin título universitario previo, por convocatorias | 2026-10-20 | RTVC Noticias, Caracol |
| AWS re/Start con Colsubsidio | 12 semanas, 420 h, voucher del CLF; para afiliados | 2026-10-20 | awsrestart-colsubsidio.com |

**Fuentes:**
- [Soporte técnico bilingüe: oferta de Foundever](https://foundevercolombia.pandape.computrabajo.com/Detail/12779690)
- [Empleos bilingües en Colombia, Moving to Colombia](https://colombiamove.com/blog/es/bilingual-call-center-bpo-jobs-colombia/)
- [Vacantes bilingües, Alcaldía de Bogotá](https://bogota.gov.co/mi-ciudad/desarrollo-economico/trabajo-en-bogota-hay-100-vacantes-asesores-comerciales-bilingues-2026)
- [Sueldo de DevOps junior, Glassdoor](https://www.glassdoor.com/Salaries/medell%C3%ADn-junior-devops-engineer-salary-SRCH_IL.0,8_IM3063_KO9,31_IP2.htm)
- [Sueldo de DevOps, Indeed](https://co.indeed.com/career/devops/salaries)
- [Salario de un DevOps en Colombia, Talently](https://talently.tech/en/tools/colombia/salary/developer/devops)
- [Contrato de aprendizaje, SENA](https://ejecucionformacion.sena.edu.co/etapa-productiva/alternativas/contrato-aprendizaje)
- [Acuerdo 065 de 2020, UNAD](https://sgeneral.unad.edu.co/images/documentos/consejoAcademico/acuerdos/2020/COAC_ACUE_065_20200714.pdf)
- [Gratuidad de la matrícula en la UNAD, RTVC Noticias](https://www.rtvcnoticias.com/actualidad/unad-abre-inscripciones-para-acceder-matricula-gratuita-en-el-periodo-2026-i)
- [AWS re/Start Acelerado, Colsubsidio](https://awsrestart-colsubsidio.com/)
- [Ofertas de Ingeniero DevOps AWS, elempleo.com](https://www.elempleo.com/co/ofertas-empleo/trabajo-ingeniero-devops-aws)
