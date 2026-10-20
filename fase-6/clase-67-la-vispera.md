# Clase 67 — La víspera: tu cuenta sin sorpresas

**Dónde:** navegador + móvil · **Tiempo:** 90 min · **Bloque:** A. Cuenta, costos e identidad

> 💡 **La idea de hoy:** antes de crear nada en AWS, la cuenta se deja segura y vigilada. El **usuario raíz** queda con MFA, sin llaves y guardado para lo que solo él puede hacer; un **usuario administrador** con su propio MFA hace el trabajo diario; y un **presupuesto** te avisa por correo si algo se queda encendido. Así se abre una cuenta en una empresa, y "¿qué haces lo primero en una cuenta nueva?" es una pregunta clásica de entrevista.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Root, los usuarios y los grupos de Linux (clase 09): IAM se organiza igual.
> - Que un secreto publicado ya no se puede retirar (clase 22) y que el `.env` va fuera de Git (clase 62).
> - Los tokens con permisos limitados y la verificación en dos pasos de Docker Hub (clase 64).

> 🔤 **Palabras nuevas de hoy:**
> - **usuario raíz** (*root user*): el correo y la contraseña con que creas la cuenta; puede todo.
> - **MFA** (autenticación multifactor): además de la contraseña, un código o una llave de algo que **tienes**.
> - **llave de acceso** (*access key*): un ID y un secreto que dan acceso permanente a la CLI, sin MFA.
> - **IAM**: el servicio de usuarios, grupos y permisos de AWS.
> - **plan gratuito y créditos**: 6 meses con créditos en dólares que pagan lo que usas.
> - ***unblended* / *net unblended***: el coste de lo que consumes / lo que queda por pagar después de los créditos.
> - **región**: un grupo de centros de datos en una zona del mundo; tú usarás `us-east-1`.

## Objetivo

- Crear tu cuenta de AWS en el **plan gratuito** y entender sus condiciones: créditos, duración y qué pasa al terminar.
- Proteger el **usuario raíz**: contraseña larga en el gestor, MFA y ninguna llave de acceso.
- Crear tu **usuario administrador** para el día a día, con su propio MFA, y entrar con él.
- Configurar un aviso de gasto con **AWS Budgets** y saber dónde mirar los créditos y los días que te quedan.
- Fijar tu región, `us-east-1`, y empezar el inventario de lo que vive en tu cuenta.

## Por qué importa

Casi todas las historias de terror de AWS empiezan igual:
- una llave del usuario raíz publicada por error en GitHub, que unos bots usan en minutos para minar criptomonedas;
- un servicio caro que alguien olvidó apagar.

El plan gratuito te protege de los cobros, pero no de quedarte sin créditos: si se acaban, la cuenta se cierra y pierdes lo que necesitas para las fases 7 y 8.

Hoy dejas la cuenta como la dejaría un profesional, y "¿qué haces lo primero en una cuenta nueva de AWS?" es una pregunta clásica de entrevista. Además, la seguridad es el 30 % del examen CLF-C02.

## Costo esperado

> 💰 **0 USD.** La cuenta, IAM, el MFA y los presupuestos de AWS Budgets no cuestan nada.

## Cómo va esta clase

Seis piezas. En cada una lees **una** idea y la aplicas enseguida en la consola; no pases a la siguiente sin haber hecho la anterior. Las pantallas de AWS cambian a menudo: si algo no coincide con lo que lees, sigue el texto de la pantalla. Lo importante son las decisiones: **plan gratuito, cuenta personal, soporte Basic**.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 4** (unos 60 min, con la cuenta creada y protegida); el segundo, las **piezas 5 y 6**, el Rómpelo, el reto y el cierre.

Ten a mano el gestor de contraseñas y el móvil con una app autenticadora.

## Las piezas

### Pieza 1 — El plan gratuito, y crear la cuenta

Al crear la cuenta eliges entre el **plan gratuito** y el **plan de pago**. Tú eliges el gratuito:

| | Plan gratuito |
|--|---------------|
| Créditos | 100 USD al registrarte, y hasta 100 USD más completando actividades guiadas |
| Duración | 6 meses, o hasta que gastes los créditos, lo que llegue antes |
| Cobros | ninguno: lo que usas se descuenta de los créditos, a precio normal |
| Al terminar | la cuenta **se cierra sola**. Tienes 90 días para pasar al plan de pago y recuperarla; después, AWS borra la cuenta y todo lo que tenía |
| Lo que no incluye | servicios que podrían gastar más que los créditos (Savings Plans, instancias reservadas, algunas ofertas del Marketplace) |

"Gratis" no significa ilimitado. Lo que usas se paga con créditos al precio de siempre:

| Si se te olvida encendido un mes entero | Créditos que gasta |
|---|---|
| una EC2 t3.small | unos 15 USD |
| un NAT Gateway | unos 33 USD |

Un par de olvidos y la cuenta se cierra antes de tiempo. Por eso cada clase termina destruyendo lo que creaste.

⚠️ **Lo que pasa la cuenta al plan de pago sin preguntar:**
- unirte a **AWS Organizations**;
- crear una *landing zone* de **Control Tower**;
- otras acciones de empresa, como unirte a la red de partners de AWS.

En este curso no los usarás. Si alguna guía de internet te dice "crea una organización", no lo hagas en esta cuenta.

**Hazlo — antes de abrir la cuenta (10 min):**

1. **El correo:** uno que controles a largo plazo, porque ahí llegan los avisos de seguridad y de facturación. Si usas Gmail, puedes usar un alias como `tunombre+aws@gmail.com`: llega a tu buzón y lo puedes filtrar.
2. **El gestor de contraseñas:** genera una contraseña de 20 caracteres o más y crea la entrada `AWS raíz`.
3. **El nombre de la cuenta:** por ejemplo, `eduardo-devops`. Solo lo ves tú.

**Hazlo — crear la cuenta (20 min):**

1. En `aws.amazon.com`, **Create an AWS account** (arriba a la derecha puedes poner la página en español).
2. Correo y nombre de la cuenta. AWS te manda un código de verificación al correo.
3. La contraseña del raíz, desde el gestor.
4. **Elige el plan gratuito** (*Free plan*).
5. Tipo de cuenta: **Personal**. Rellena tus datos de contacto.
6. Tarjeta: AWS hace una pequeña retención para verificarla y la devuelve. En el plan gratuito no te cobra.
7. Verificación del teléfono, por SMS o llamada.
8. Plan de soporte: **Basic** (gratis).

👀 **Qué deberías ver:** la activación suele tardar unos minutos (como mucho, 24 h) y te llega un correo cuando está lista. Al entrar en la consola, arriba a la derecha, el **ID de la cuenta**: 12 dígitos. Guárdalo en la entrada del gestor, con el correo y la contraseña.

✋ **Sin mirar:** ¿qué pasa con tu cuenta cuando se acaban los créditos o pasan los 6 meses?

<details>
<summary>Comprueba</summary>

Se cierra sola. Tienes 90 días para pasar al plan de pago y recuperarla; después, AWS la borra con todo lo que tenía.
</details>

**En resumen:** plan gratuito = créditos durante 6 meses, sin cobros; lo que usas gasta créditos a precio normal, y unirte a Organizations te pasa al plan de pago.

### Pieza 2 — El usuario raíz y el MFA

El usuario raíz es el correo y la contraseña con que creas la cuenta. Puede **todo**, y hay tareas que **solo** él puede hacer. Por ejemplo:
- cerrar la cuenta;
- cambiar el correo o la contraseña del raíz;
- activar el acceso de IAM a la facturación (pieza 3);
- restaurar los permisos de un administrador que se bloqueó a sí mismo.

La regla: **el raíz se usa solo para esas tareas**. El trabajo diario se hace con un usuario de IAM con permisos de administrador (pieza 4). Si roban la contraseña de ese usuario, lo arreglas con el raíz; si roban el raíz, has perdido la cuenta.

El **MFA** pide, además de la contraseña, una prueba de algo que **tienes**. AWS acepta tres tipos:
- una **passkey** o llave de seguridad (FIDO2);
- una **app autenticadora**, que genera un código de 6 dígitos cada 30 segundos (TOTP);
- un token físico TOTP.

AWS exige MFA en el usuario raíz y permite registrar hasta **8 dispositivos** por usuario. Registra dos (por ejemplo, la app del móvil y una passkey o la app de otro dispositivo): si pierdes el móvil, no te quedas fuera.

**Hazlo (10 min):**

1. Entra como **usuario raíz** en la consola.
2. Arriba a la derecha, tu nombre de cuenta → **Security credentials**.
3. **Multi-factor authentication (MFA)** → **Assign MFA device**:
   - nombre: `raiz-movil`;
   - tipo: *Authenticator app*;
   - escanea el QR con la app y escribe dos códigos seguidos.
4. Si puedes, registra un segundo dispositivo (`raiz-respaldo`).
5. Anota en el gestor dónde está cada MFA. Cierra la sesión y vuelve a entrar como raíz.

👀 **Qué deberías ver:** `raiz-movil` (y `raiz-respaldo`) en la lista de MFA, y al volver a entrar, después de la contraseña, la pantalla que pide el código de 6 dígitos.

✋ **Sin mirar:** ¿por qué conviene registrar dos dispositivos MFA en el raíz?

<details>
<summary>Comprueba</summary>

Para no quedarte fuera de la cuenta si pierdes o se te rompe uno: con el otro sigues entrando.
</details>

**En resumen:** el raíz se guarda para lo que solo él puede hacer, con MFA (mejor dos dispositivos).

### Pieza 3 — Las llaves de acceso, y un ajuste que solo hace el raíz

Una llave de acceso es un par **ID + secreto** que da acceso permanente a la CLI y a los SDK, sin MFA. Es la credencial que más se filtra: termina en un repositorio, en un `.env` o en una captura de pantalla.

- El raíz **nunca** debe tener llaves.
- En este curso **nadie** las tendrá: tú entrarás en la CLI con `aws login`, que da credenciales temporales (clase 70), y las máquinas usarán roles (clases 70 y 72).

🔮 **Predice:** en la página *Security credentials* del raíz, ¿qué debe mostrar la sección **Access keys**?

**Hazlo (5 min):**

1. Todavía como raíz, en *Security credentials*, baja hasta **Access keys**. Si aparece alguna (no debería en una cuenta nueva), bórrala.
2. Menú de la cuenta → **Account** → **IAM user and role access to Billing information**. Debe decir **Activated**: en las cuentas nuevas viene así. Si no, *Edit* → *Activate IAM Access*.

👀 **Qué deberías ver:** "No access keys" en la primera, y **Activated** en la segunda. Sin esto último, ni un administrador de IAM puede ver la facturación: es uno de los ajustes que solo el raíz controla (lo comprobarás en el Rómpelo 1).

✋ **Sin mirar:** ¿por qué una llave de acceso es más peligrosa que una contraseña con MFA?

<details>
<summary>Comprueba</summary>

Porque da acceso permanente sin pedir MFA: quien la copie (de un repositorio, un `.env` o una captura) entra directamente, sin nada más.
</details>

**En resumen:** el raíz sin llaves; en este curso, nadie con llaves permanentes. Y el acceso de IAM a la facturación solo lo activa el raíz.

### Pieza 4 — Tu usuario administrador

En la consola, busca **IAM**. Es un servicio **global**: el selector de región dice *Global*. Los permisos se dan a un **grupo** y el usuario entra en el grupo, como en Linux (clase 09).

**Hazlo (15 min):**

1. **User groups → Create group:**
   - nombre: `administradores`;
   - marca la política `AdministratorAccess`.
2. **Users → Create user:**
   - nombre: `eduardo`;
   - marca *Provide user access to the AWS Management Console*.
3. La consola te recomienda *Identity Center*. Elige **I want to create an IAM user**.

   Identity Center es la forma de las empresas, pero pide una organización de AWS, y eso pasaría tu cuenta al plan de pago. Lo verás como concepto en la clase 70.
4. Contraseña: **Custom password**, generada en el gestor (entrada `AWS eduardo`). Desmarca *must create a new password at next sign-in*: ya es una contraseña fuerte.
5. Permisos: **Add user to group** → `administradores`.
6. Crea el usuario y copia la **URL de inicio de sesión**: `https://<ID de cuenta>.signin.aws.amazon.com/console`.
7. Recordar 12 dígitos es incómodo, así que crea un **alias** de la cuenta. En **IAM → Dashboard**, *Account Alias* → *Create*, por ejemplo `eduardo-devops-2026`. Tiene que ser único en todo AWS. La URL pasa a ser `https://eduardo-devops-2026.signin.aws.amazon.com/console`: guárdala en el gestor.
8. **Cierra la sesión del raíz** y entra por esa URL como `eduardo`.
9. Dale su MFA: menú de la cuenta → **Security credentials** → *Assign MFA device* → `eduardo-movil`.
10. Cierra sesión y vuelve a entrar.

👀 **Qué deberías ver:** arriba a la derecha, `eduardo @ eduardo-devops-2026` (o con el ID de la cuenta); y al volver a entrar, la pantalla del código MFA. Desde hoy, **entras siempre como `eduardo`**.

✋ **Sin mirar:** ¿por qué no creas el usuario con Identity Center, aunque la consola te lo recomiende?

<details>
<summary>Comprueba</summary>

Porque Identity Center pide una organización de AWS, y crearla pasaría tu cuenta al plan de pago.
</details>

**En resumen:** grupo `administradores` con `AdministratorAccess`, usuario `eduardo` dentro, con MFA y su URL de alias.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí. Mañana, entra como `eduardo` por la URL del alias.

### Pieza 5 — Dónde se ve el gasto, y tu aviso

| Herramienta | Para qué | Precio |
|-------------|----------|--------|
| Inicio de *Billing and Cost Management* | créditos restantes y días que le quedan al plan gratuito | gratis |
| **AWS Budgets** | un correo cuando el gasto llega a un umbral | gratis los de seguimiento |
| **Cost Explorer** | gráficas del gasto por servicio, por día y por etiqueta | la consola es gratis; su API cobra por petición |

Un detalle importante para el presupuesto: en el plan gratuito, tu factura (el coste **después** de créditos, *net unblended*) siempre es 0. Si el presupuesto midiera eso, nunca te avisaría. Por eso debe medir el coste **antes** de créditos (*unblended*): lo que estás consumiendo de verdad.

**Hazlo (15 min)**, como `eduardo`, en **Billing and Cost Management**:

1. En la página de inicio, busca el resumen del **plan gratuito**: créditos restantes y días que quedan. Apúntalos en `PROGRESO.md`, en el registro, con la fecha de fin del plan.
2. **Budgets → Create budget → Use a template (simplified) → Monthly cost budget:**
   - nombre: `mensual-10usd`;
   - importe: `10`;
   - tu correo.

   Créalo.
3. Ábrelo, **Edit**, y revisa en el alcance (*Budget scope*) las opciones avanzadas: el coste debe agregarse como **Unblended costs**. Si no, cámbialo. Mira también qué umbrales de aviso creó la plantilla.
4. **Cost Explorer:** ábrelo una vez para activarlo. Tarda hasta 24 h en mostrar datos.

👀 **Qué deberías ver:** los créditos (unos 100 USD) y los días restantes; el presupuesto `mensual-10usd` en la lista, con un gasto de 0 USD y sus umbrales (normalmente, al 85 % y al 100 %). ¿Por qué 10 USD al mes? Si destruyes lo que creas, la fase 6 entera consume pocos dólares. Si un mes llegas a 10, algo se quedó encendido.

✋ **Sin mirar:** ¿por qué tu presupuesto mide *Unblended costs*?

<details>
<summary>Comprueba</summary>

Porque en el plan gratuito el coste después de créditos (*net unblended*) es siempre 0, y el aviso no llegaría nunca. El *unblended* mide lo que consumes, que es lo que gasta tus créditos.
</details>

**En resumen:** créditos y días en el inicio de *Billing*; un presupuesto de 10 USD que mida *Unblended costs*.

### Pieza 6 — La región y el inventario

Muchos servicios son **regionales**: lo que creas en `us-east-1` no aparece si miras en otra región. La consola recuerda la última región que usaste, así que si algo "desaparece", mira primero el selector de región.

**Hazlo (10 min):**

1. Arriba a la derecha, el selector de región: **US East (N. Virginia) us-east-1**.
2. Crea `notas/fase-6/inventario-aws.md`, el registro de lo que vive en tu cuenta:

```markdown
# Inventario de mi cuenta de AWS

Región: us-east-1 · Alias: eduardo-devops-2026 · Plan gratuito hasta: AAAA-MM-DD

| Recurso | Nombre o ID | Creado | ¿Cobra por hora? | Destruir antes de |
|---------|-------------|--------|------------------|-------------------|
| Usuario IAM | eduardo (grupo administradores) | 2026-… | no | — |
| Presupuesto | mensual-10usd | 2026-… | no | — |
```

👀 **Qué deberías ver:** el selector con `N. Virginia` y tu inventario con sus dos primeras filas. Cada vez que algo que cobra se quede vivo más allá de una sesión (pasará en el proyecto), se apunta aquí. La cuenta no debería vivir solo en tu memoria.

✋ **Sin mirar:** creaste algo ayer y hoy no aparece en la consola. ¿Qué miras primero?

<details>
<summary>Comprueba</summary>

El selector de región: seguramente estás mirando otra región distinta de `us-east-1`.
</details>

**En resumen:** todo en `us-east-1`, y un inventario de lo que vive en la cuenta.

## Tu chuleta de la clase

| Qué | Dónde o cómo |
|-----|--------------|
| MFA y llaves del raíz | menú de la cuenta → **Security credentials** |
| Acceso de IAM a la facturación | **Account** → *IAM user and role access to Billing information* (solo el raíz) |
| Usuarios, grupos y alias | **IAM** (servicio global) → *Users*, *User groups*, *Dashboard* |
| URL de inicio de sesión | `https://<alias>.signin.aws.amazon.com/console` |
| Créditos y días restantes | inicio de **Billing and Cost Management** |
| Aviso de gasto | **Budgets** → *Monthly cost budget*, con *Unblended costs* |
| Región del curso | `us-east-1` (N. Virginia), en el selector de arriba a la derecha |
| Lo que nunca haces | usar el raíz a diario, crear llaves del raíz, unirte a Organizations |

## Rómpelo

**1. Un administrador que no ve la factura.**
1. Abre una ventana privada y entra como **raíz**.
2. Desactiva *IAM user and role access to Billing information*.
3. En tu ventana normal, como `eduardo`, recarga *Billing and Cost Management*.
4. Vuelve a activarlo con el raíz y cierra la ventana privada.

¿Qué ves en el paso 3? Acceso denegado, aunque `eduardo` tiene `AdministratorAccess`. "Administrador" no es "raíz": hay ajustes de la cuenta que están por encima de IAM.

**2. Simulacro: has perdido el móvil.**
1. Cierra sesión.
2. En la pantalla de inicio de sesión del raíz, después de la contraseña, busca la opción para solucionar problemas con el MFA (*Troubleshoot MFA*).
3. No completes el proceso: lee qué te pediría.

AWS verifica el correo y llama al **teléfono de la cuenta**. Comprueba en *Account* que ese teléfono es el tuyo y está bien escrito. Con dos MFA registrados, ni siquiera llegarías aquí.

**3. La llave que no debes crear.**
1. Como raíz, en *Security credentials* → *Access keys*, pulsa **Create access key**.
2. Lee el aviso.
3. **Cancela.**

Lo que acabas de ver es el aviso más claro de toda la consola. Las llaves del raíz no tienen ningún uso legítimo en tu día a día.

## Reto

Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Configura una **política de contraseñas** para los usuarios de IAM: mínimo 14 caracteres y que no se puedan reutilizar las 5 últimas. ¿A quién afecta?

> 🧩 **Ejemplo resuelto:** en la pieza 4, la contraseña de `eduardo` la generó el gestor, con 20 caracteres o más.

**Ahora tú, con huecos:** **IAM → Account settings → Password policy → Edit → Custom**: longitud mínima ____; marca *Prevent password reuse* con ____ contraseñas. Completa: «La política afecta a ____; al raíz ____, porque el raíz no es ____».

<details>
<summary>Pista</summary>

La política está dentro de IAM, y el raíz no es un usuario de IAM: es el dueño de la cuenta.
</details>

**2.** Busca en la documentación de AWS la lista de tareas que solo puede hacer el raíz y copia tres que te sorprendan.

> 🧩 **Ejemplo resuelto:** las cuatro de la pieza 2: cerrar la cuenta, cambiar el correo o la contraseña del raíz, activar el acceso de IAM a la facturación y restaurar los permisos de un administrador bloqueado.

**Ahora tú, con huecos:** busca *Tasks that require root user credentials* y apunta: «1. ____ 2. ____ 3. ____».

<details>
<summary>Pista</summary>

Está en la *IAM User Guide*, en `docs.aws.amazon.com`. Lee en inglés despacio: son frases cortas.
</details>

**3.** Rellena los **contactos alternativos** de la cuenta con tu correo. ¿Para qué crees que los usa AWS?

> 🧩 **Ejemplo resuelto:** el Rómpelo 2: AWS usa el teléfono de la cuenta para verificar que eres tú si pierdes el MFA.

**Ahora tú, con huecos:** **Account → Alternate contacts → Edit**: *Billing* ____, *Operations* ____ y *Security* ____. Completa: «AWS los usa para avisar de ____».

<details>
<summary>Pista</summary>

Piensa en qué te escribiría AWS si encontrara una de tus llaves publicada en GitHub, o si un servicio que usas va a cambiar.
</details>

## Destruir al terminar

Nada de lo de hoy cobra, así que no hay nada que destruir. Pero **cierra la sesión del raíz** si sigue abierta en algún navegador, y comprueba que el gestor tiene guardados:
- el raíz;
- `eduardo`;
- el ID de la cuenta y el alias;
- la URL de inicio de sesión;
- dónde está cada MFA.

## Cierre

En `notas/fase-6/clase-67.md`:

1. ¿Qué pasa con tu cuenta cuando se acaban los créditos o pasan 6 meses? ¿Qué acciones la pasarían sola al plan de pago? *(2 líneas. Empieza así: «Se cierra sola, y tengo 90 días para… La pasarían al plan de pago, por ejemplo,…»)*
2. ¿Por qué no trabajas con el usuario raíz? Di dos cosas que solo él puede hacer. *(2 líneas. Empieza así: «Porque puede todo y sin límites: si alguien lo roba,… Solo él puede…»)*
3. ¿Por qué tu presupuesto mide el coste *unblended* y no el *net unblended*? *(1–2 líneas. Empieza así: «Porque en el plan gratuito el coste después de créditos es siempre…»)*
4. **Repaso (clase 66, sin mirar):** ¿por qué el `.env` con la contraseña de PostgreSQL no va en la imagen ni en Git, y cómo llega la contraseña al contenedor? *(2 líneas. Empieza así: «Porque la imagen y el repositorio se comparten:… Compose la lee del `.env` y…»)*

Después, escríbeme `examíname clase-67`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**Comprueba tu cuenta:**
- [ ] El raíz tiene MFA (mejor dos) y ninguna llave de acceso.
- [ ] `eduardo` está en el grupo `administradores`, tiene MFA y entra por la URL del alias.
- [ ] El presupuesto `mensual-10usd` existe y mide *Unblended costs*.
- [ ] `PROGRESO.md` tiene la fecha de fin del plan gratuito y los créditos restantes.
- [ ] `notas/fase-6/inventario-aws.md` existe.

**Cierre:**
1. Se cierra sola, y tienes 90 días para pasar al plan de pago y recuperarla; si no, AWS la borra con todo lo que tenía. La pasan sola al plan de pago, por ejemplo, unirte a AWS Organizations o crear una *landing zone* de Control Tower.
2. Porque puede todo y sin límites: si alguien lo roba, pierdes la cuenta. Por eso se reserva para lo que solo él puede hacer, por ejemplo cerrar la cuenta, activar el acceso de IAM a la facturación o restaurar los permisos de un administrador bloqueado.
3. Porque en el plan gratuito los créditos lo cubren todo y el coste después de créditos (*net unblended*) es siempre 0: el aviso no llegaría nunca. El *unblended* mide lo que consumes, y eso es lo que gasta tus créditos.
4. Porque la imagen y el repositorio se comparten: quien tenga la imagen o un clon tendría la contraseña, para siempre (las capas y el historial de Git la conservan). Compose la lee del `.env`, que está en `.gitignore` y en `.dockerignore`, y se la pasa al contenedor como variable de entorno al arrancarlo.

**Reto 1:** 14 caracteres y 5 contraseñas. Afecta a los usuarios de IAM (como `eduardo`); al raíz no, porque el raíz no es un usuario de IAM.

**Reto 2:** depende de lo que elijas; por ejemplo, cambiar el plan de soporte, registrarse como vendedor en el Marketplace o restaurar una política de un bucket de S3 que bloquea a todos.

**Reto 3:** facturación, operaciones y seguridad, con tu correo. AWS los usa para avisar de problemas de facturación, de cambios o incidencias en los servicios que usas y de alertas de seguridad, como una llave tuya encontrada en un repositorio público.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| root user | usuario raíz de la cuenta |
| multi-factor authentication (MFA) | autenticación multifactor |
| access key | llave de acceso (credencial permanente) |
| free plan / credits | plan gratuito / créditos |
| budget / alert threshold | presupuesto / umbral de aviso |
| account alias | alias de la cuenta |

🎙️ *"The first thing I do in a new AWS account is lock down the root user: a strong password, MFA and no access keys. Then I create an admin user with its own MFA for daily work, and a budget alert so a forgotten resource never surprises me."*

## Siguiente

[Clase 68 — La nube y su factura: regiones, zonas, precios y créditos](clase-68-la-nube-y-su-factura.md)
