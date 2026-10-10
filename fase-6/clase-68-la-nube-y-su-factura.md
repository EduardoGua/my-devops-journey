# Clase 68 — La nube y su factura: regiones, zonas, precios y créditos

**Dónde:** navegador (consola y CloudShell) + tu Ubuntu · **Tiempo:** 90 min · **Bloque:** A. Cuenta, costos e identidad

## Objetivo

- Explicar qué ofrece la nube frente a un centro de datos propio, y el **modelo de responsabilidad compartida**: qué protege AWS, qué proteges tú y cómo cambia según el servicio.
- Distinguir **regiones**, **zonas de disponibilidad** y **ubicaciones de borde**, y elegir una región con criterio.
- Usar **CloudShell**, una terminal con la AWS CLI dentro del navegador.
- Entender cómo cobra AWS (por tiempo, por GB, por petición y por salida de datos) y sus modelos de compra, y estimar un coste con la **Pricing Calculator**.

## Por qué importa

El dominio 1 del CLF-C02 (conceptos de la nube) y el 4 (facturación) suman el 36 % del examen. Pero no se trata solo del examen: en el trabajo te preguntarán "¿cuánto va a costar esto?" antes de crear nada. Y los errores caros más comunes son de este tema:
- una región equivocada;
- tráfico que sale de AWS sin que nadie lo esperara;
- una instancia "parada" que seguía cobrando.

## Costo esperado

> 💰 **0 USD.** CloudShell es gratis y el único recurso que crearás (un grupo de logs vacío) no cuesta nada y se borra al momento.

## Teoría

### Lo que ofrece la nube

Con un centro de datos propio, compras servidores para el pico de demanda que imaginas, esperas semanas a que lleguen y los pagas aunque estén parados. AWS resume las ventajas de la nube en seis:

| Ventaja | Qué significa |
|---------|---------------|
| Gasto variable en vez de fijo | pagas por lo que usas, no por adelantado (de *CapEx* a *OpEx*) |
| Economías de escala | AWS compra a una escala enorme y baja sus precios |
| Dejar de adivinar la capacidad | escalas hacia arriba o hacia abajo según la demanda real (**elasticidad**) |
| Velocidad y agilidad | un servidor nuevo tarda minutos, no semanas |
| No mantener centros de datos | tu equipo trabaja en el producto, no en el hardware |
| Global en minutos | despliegas en otro continente cambiando de región |

Los **modelos de despliegue** son tres:
- **nube**: todo en AWS;
- **híbrido**: una parte en AWS y otra en tu centro de datos, conectados;
- ***on-premises***: todo en tu centro de datos.

Y los **modelos de servicio**:

| Modelo | Qué gestionas tú | Qué te da AWS | Ejemplo |
|--------|------------------|---------------|---------|
| **IaaS** | el sistema operativo y lo que haya encima | servidores, redes, discos | EC2 |
| **PaaS** | solo tu código y tus datos | la plataforma que los ejecuta | Elastic Beanstalk, Lambda |
| **SaaS** | solo usarlo | el programa terminado | WorkSpaces, Amazon Connect |

### El modelo de responsabilidad compartida

La frase del examen:
- **AWS se encarga de la seguridad *de* la nube**: edificios, hardware, red física, el hipervisor y el software de sus servicios gestionados.
- **Tú, de la seguridad *en* la nube**: tus datos, quién accede (IAM), la configuración de tus firewalls, el cifrado que elijas y, en EC2, el sistema operativo.

La frontera se mueve según el servicio:

| Quién se encarga de… | EC2 | RDS (base de datos gestionada) | Lambda |
|-----------------------|-----|---------------------------------|--------|
| el hardware y el centro de datos | AWS | AWS | AWS |
| parches del sistema operativo | **tú** | AWS | AWS |
| parches del motor de base de datos o del *runtime* | **tú** | AWS (tú eliges la ventana de mantenimiento) | AWS |
| security groups y red | **tú** | **tú** | **tú**, si la conectas a una VPC |
| tus datos, IAM y cifrado | **tú** | **tú** | **tú** |

Cuanto más gestionado es el servicio, menos te toca a ti. Hay controles **compartidos**, en los que cada parte hace lo suyo: los parches (AWS parchea su infraestructura, tú tus instancias), la configuración y la formación de las personas.

### La infraestructura global

```
Región us-east-1 (Norte de Virginia)
├── Zona us-east-1a  (uno o más centros de datos)
├── Zona us-east-1b  ─┐ separadas kilómetros entre sí, con energía y red propias,
├── Zona us-east-1c   │ unidas por enlaces privados de baja latencia
└── …                ─┘
Ubicaciones de borde (cientos, en ciudades de todo el mundo): CloudFront y Route 53
```

- **Región:** una zona geográfica con varias **zonas de disponibilidad** (AZ, *Availability Zones*), normalmente tres o más. Cada región es independiente: tus recursos no salen de ella salvo que tú los copies.
- **Zona de disponibilidad:** uno o más centros de datos con energía, refrigeración y red propias. Las AZ **no comparten puntos únicos de fallo**: un incendio o un corte en una no tumba las demás. **Alta disponibilidad** significa repartir la aplicación entre varias AZ.
- **Ubicación de borde:** un punto de presencia cerca de los usuarios que sirve contenido en caché (CloudFront) y responde DNS (Route 53).

¿Cuándo usar **varias regiones**? Para recuperarte de un desastre regional, para tener baja latencia en otro continente o por **soberanía de datos**: la ley exige que ciertos datos no salgan de un país.

**Cómo elegir región**, en este orden:
1. la ley y el cumplimiento normativo;
2. la latencia hasta tus usuarios;
3. que tenga los servicios que necesitas;
4. el precio, que cambia de una región a otra.

Para el curso, `us-east-1`: es de las más baratas, recibe antes los servicios nuevos y casi toda la documentación la usa de ejemplo.

| Alcance | Ejemplos |
|---------|----------|
| **Global** | IAM, Route 53, CloudFront, la facturación |
| **Regional** | VPC, buckets de S3 (aunque su nombre es único en todo el mundo), Lambda, ECR |
| **De zona** | instancias EC2, subredes, volúmenes EBS |

### Cómo cobra AWS

| Se cobra por… | Ejemplos (en `us-east-1`) |
|----------------|---------------------------|
| **tiempo** encendido (por segundo, con un mínimo de 60 s, en EC2 Linux) | t3.micro 0,0104 USD/h · t3.small 0,0208 USD/h · IPv4 pública 0,005 USD/h · NAT Gateway 0,045 USD/h |
| **almacenamiento** por GB y mes | disco gp3 0,08 USD/GB-mes · S3 Standard unos 0,023 USD/GB-mes |
| **peticiones** | S3, por cada mil; Lambda, por millón |
| **datos procesados o transferidos** | NAT Gateway 0,045 USD/GB · salida a internet |

La **transferencia de datos** es la parte que más sorprende:
- la **entrada** a AWS es gratis;
- la **salida** a internet se cobra (los primeros 100 GB al mes son gratis);
- **entre zonas** de la misma región se cobra un poco;
- **entre regiones**, más.

Una instancia **parada** no paga cómputo, pero sigue pagando su **disco**. Y si tiene una Elastic IP, también la dirección.

**Modelos de compra de EC2**:

| Modelo | Cómo funciona | Para qué |
|--------|---------------|----------|
| **Bajo demanda** (*On-Demand*) | pagas por segundo, sin compromiso | cargas impredecibles, pruebas, **todo este curso** |
| **Savings Plans** | te comprometes a gastar X USD/h durante 1 o 3 años; hasta un 72 % de descuento | cargas estables, con flexibilidad de tipo y región |
| **Instancias reservadas** | reservas un tipo de instancia 1 o 3 años; hasta un 72 % | cargas estables y previsibles |
| **Spot** | capacidad sobrante, hasta un 90 % más barata, pero AWS puede recuperarla avisando 2 minutos antes | trabajos que se pueden interrumpir: lotes, CI |
| **Dedicated Hosts** | un servidor físico entero para ti | licencias por servidor físico (*BYOL*) y requisitos de cumplimiento |
| **Dedicated Instances** | instancias en hardware que no compartes con otros clientes | cumplimiento normativo |
| **Capacity Reservations** | reservas capacidad en una AZ, sin descuento | garantizar que habrá sitio en un evento |

En el plan gratuito no puedes comprar Savings Plans ni instancias reservadas. Para el examen, tienes que saber cuándo conviene cada uno.

**Herramientas de costos:**
- **Pricing Calculator:** estimar antes de crear.
- **Budgets:** avisos.
- **Cost Explorer:** analizar el gasto.
- **Cost and Usage Report:** el detalle completo, línea a línea.
- **Etiquetas de asignación de costos:** repartir el gasto por proyecto.
- **Facturación consolidada de AWS Organizations:** una factura para varias cuentas.

## Práctica guiada

### 1. CloudShell (10 min)

En la consola, como `eduardo` y en `us-east-1`, pulsa el icono de terminal (`>_`) de la barra superior. CloudShell es una terminal Linux con la AWS CLI ya instalada y con **tus credenciales de la consola**:

```bash
aws --version
aws sts get-caller-identity
echo "$AWS_REGION"
```

🔮 **Predice:** ¿qué ARN devuelve `get-caller-identity`? `arn:aws:iam::<tu cuenta>:user/eduardo`. No has configurado ninguna llave: CloudShell usa la sesión de la consola.

Lo que debes saber de CloudShell:
- **Precio:** gratis.
- **Persistencia:** solo tu `$HOME`, con 1 GB por región. Si no lo usas en una región durante 120 días, borra ese `$HOME`.
- **Sesión:** se cierra tras 20–30 minutos sin tocar el teclado o el ratón.
- **Red:** puede salir a internet, pero nadie puede conectarse a él.

### 2. Regiones y zonas (15 min)

```bash
aws ec2 describe-regions --query 'length(Regions)'
aws ec2 describe-regions --query 'Regions[].RegionName' --output text | tr '\t' '\n' | sort
aws ec2 describe-regions --all-regions --query 'Regions[?OptInStatus==`not-opted-in`].RegionName' --output text
aws ec2 describe-availability-zones --query 'AvailabilityZones[].[ZoneName,ZoneId,State]' --output table
```

- Las regiones más nuevas son ***opt-in***: vienen desactivadas y hay que activarlas a propósito. La tercera orden las lista.
- Cada AZ tiene dos nombres:
  - el **nombre** (`us-east-1a`) se asigna **al azar en cada cuenta**, para repartir la carga;
  - el **ID** (`use1-az6`) es el mismo para todo el mundo.

  Si alguna vez coordinas con otra cuenta "pongámoslo en la misma zona", usad el ID.

Ahora, desde **tu Ubuntu** (no desde CloudShell, que ya está dentro de AWS), mide cuánto tarda en abrirse una conexión TCP con cuatro regiones:

```bash
for r in us-east-1 us-west-2 sa-east-1 eu-west-1; do
  curl -o /dev/null -s -w "$r %{time_connect}s\n" "https://ec2.$r.amazonaws.com/"
done
```

🔮 **Predice:** ¿cuál será la más rápida desde tu casa? La conexión TCP necesita un viaje de ida y vuelta (clase 29), así que `time_connect` es, más o menos, la latencia.

Si la región más cercana gana por unas decenas de milisegundos, para tus laboratorios da igual: `us-east-1` sigue siendo la elección por precio y servicios. Para una aplicación con usuarios reales, esos milisegundos sí importarían.

### 3. Global, regional, de zona (10 min)

En CloudShell:

```bash
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,IsDefault]' --output text
aws ec2 describe-vpcs --region eu-west-1 --query 'Vpcs[].[VpcId,CidrBlock,IsDefault]' --output text
aws iam list-users --query 'Users[].UserName' --output text
aws iam list-users --region eu-west-1 --query 'Users[].UserName' --output text
```

🔮 **Predice:** ¿verás la misma VPC en las dos regiones? ¿Y los mismos usuarios? Cada región tiene su **VPC por defecto**, que AWS creó al abrir la cuenta: mismo rango (`172.31.0.0/16`), distinto ID. Los usuarios de IAM son los mismos en todas, porque IAM es global. En la clase 71 crearás tu propia VPC en vez de usar la que viene por defecto.

### 4. Leer un precio (25 min)

Abre la **Pricing Calculator** (`calculator.aws`) → *Create estimate* y estima lo que costará Vigía v3:

1. **Amazon EC2:**
   - `us-east-1`, Linux, **t3.small**, bajo demanda;
   - uso: 730 horas al mes (24/7);
   - un disco gp3 de 8 GB.
2. **Amazon VPC:** una dirección **IPv4 pública** durante 730 horas.

Debería salirte algo así:

| Pieza | Cálculo | USD/mes |
|-------|---------|---------|
| t3.small | 0,0208 × 730 h | 15,18 |
| disco gp3 de 8 GB | 0,08 × 8 GB | 0,64 |
| IPv4 pública | 0,005 × 730 h | 3,65 |
| **Total encendida todo el mes** | | **≈ 19,50** |

Ahora cambia el uso a **4 horas al día, 20 días al mes** (80 h):

| Pieza | Cálculo | USD/mes |
|-------|---------|---------|
| t3.small | 0,0208 × 80 h | 1,66 |
| IPv4 pública | 0,005 × 80 h | 0,40 |
| disco (si lo borras con la instancia) | | céntimos |
| **Total** | | **≈ 2** |

Esa diferencia es la regla "destruir al terminar" convertida en dinero. Guarda el enlace de la estimación (*Share*) en tus notas.

Una pregunta de transferencia de datos. Cuando la EC2 de Vigía descargue su imagen de ECR, ¿cuánto pagará?
- ECR en la **misma región**: nada.
- Si la descarga pasara por un **NAT Gateway**: 0,045 USD por GB procesado. Por eso, en la clase 72, el NAT Gateway se crea, se prueba y se borra el mismo día.

### 5. Etiquetas y Cost Explorer (15 min)

1. **Billing and Cost Management → Cost allocation tags.** Las etiquetas que tú pones (como `Proyecto`) solo aparecen en los informes de costos si las **activas** aquí. La lista estará vacía hasta que algún recurso use la etiqueta y pasen unas horas. Apúntate volver tras la clase 71 y activar `Proyecto`.
2. **Cost Explorer:**
   - mira los últimos 7 días, agrupados por *Service*: seguramente todo a 0;
   - cambia la agrupación a *Usage type*. Cuando tengas gasto, ahí verás **qué** lo produce, por ejemplo `BoxUsage:t3.small` o `PublicIPv4:InUseAddress`.
3. En la página de inicio de *Billing*, mira de nuevo los créditos y los días restantes. Que se convierta en costumbre semanal.

## Rómpelo

**1. "Mi recurso ha desaparecido".** En CloudShell, crea algo en la región equivocada a propósito: un grupo de logs, que vacío no cuesta nada.

```bash
aws logs create-log-group --log-group-name /lab/perdido --region eu-west-1
aws logs describe-log-groups --log-group-name-prefix /lab/ --query 'logGroups[].logGroupName'
aws logs describe-log-groups --log-group-name-prefix /lab/ --region eu-west-1 --query 'logGroups[].logGroupName'
```

En la consola, abre CloudWatch → *Log groups* con `us-east-1` seleccionada: no está. Cambia el selector a *Europe (Ireland)*: ahí está. Bórralo:

```bash
aws logs delete-log-group --log-group-name /lab/perdido --region eu-west-1
```

Es la pregunta número uno de quien empieza con AWS, y casi siempre la respuesta es la región. Una instancia olvidada en otra región cobra igual, aunque tu consola no la muestre.

**2. Lo que CloudShell olvida:**

```bash
echo hola > /tmp/temporal.txt
echo hola > ~/persistente.txt
```

*Actions → Restart*. ¿Qué archivo sigue ahí? Después cambia la región de la consola a `eu-west-1`, abre CloudShell y busca `~/persistente.txt`. No está: el `$HOME` es **por región**. Vuelve a `us-east-1` y bórralo.

**3. Una región sin activar.** Elige una región de la lista *opt-in* del paso 2 y lanza:

```bash
aws ec2 describe-instances --region <región opt-in>
```

Falla: tus credenciales no valen en una región que la cuenta no ha activado. Las regiones nuevas no se activan solas, por seguridad.

## Reto

1. En la Pricing Calculator, ¿cuánto cuesta un **NAT Gateway** encendido un mes que procesa 10 GB? Compáralo con la t3.small.
2. Compara el precio de una t3.small en `us-east-1`, `sa-east-1` (São Paulo) y `eu-west-1` (Irlanda). ¿Cuál es la más cara y cuánto más?
3. El **Well-Architected Framework** es la guía de AWS para diseñar bien, y entra en el examen. Busca sus **seis pilares** y escribe una frase de cada uno.

## Destruir al terminar

- El grupo de logs de `eu-west-1`, si no lo borraste en el Rómpelo 1.
- `~/persistente.txt` de CloudShell en `us-east-1`.

## Cierre

En `notas/fase-6/clase-68.md`:

1. En una EC2, ¿quién parchea el sistema operativo? ¿Y en Lambda? ¿Por qué cambia?
2. ¿Qué diferencia hay entre una región y una zona de disponibilidad? ¿Cómo consigues alta disponibilidad con ellas?
3. Una instancia **parada**, ¿cuesta dinero? ¿Qué sigue cobrando?
4. **Repaso (clase 67, sin mirar):** ¿qué cuatro cosas haces lo primero en una cuenta nueva de AWS?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** En EC2, tú: es IaaS y el sistema operativo es tuyo. En Lambda, AWS: tú solo pones el código, y AWS gestiona el servidor, el sistema y el *runtime*. Cuanto más gestionado es el servicio, más responsabilidades pasan a AWS.

**2.** Una región es una zona geográfica (Norte de Virginia, Irlanda…). Una AZ es uno o más centros de datos dentro de la región, con energía y red propias. Las AZ de una región están lo bastante lejos para no fallar juntas y lo bastante cerca para tener poca latencia. Alta disponibilidad: repartir la aplicación entre **varias AZ**, de modo que si una cae, las otras siguen.

**3.** Sí. No paga cómputo, pero sigue pagando el **disco EBS**, y la Elastic IP si la tiene. Una IPv4 pública automática se libera al parar la instancia: deja de cobrar, pero al arrancar recibes otra distinta.

**4.** Proteger el raíz (contraseña fuerte, MFA y ninguna llave de acceso), crear un usuario administrador con MFA para el día a día, configurar un presupuesto con aviso y anotar la región y la fecha de fin del plan gratuito.

**Reto 1:** 0,045 × 730 = 32,85 USD + 10 GB × 0,045 = 0,45 USD → unos **33 USD al mes**, más del doble que la t3.small, y eso que el NAT Gateway no ejecuta tu aplicación: solo deja salir a internet a lo que está en una subred privada.

**Reto 3:**
- **Excelencia operativa:** operar y mejorar con procesos automatizados.
- **Seguridad:** proteger datos y sistemas.
- **Fiabilidad:** recuperarse de fallos y cumplir lo prometido.
- **Eficiencia del rendimiento:** usar los recursos adecuados y adaptarse a la demanda.
- **Optimización de costos:** no pagar lo que no aporta valor.
- **Sostenibilidad:** minimizar el impacto ambiental.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| shared responsibility model | modelo de responsabilidad compartida |
| Region / Availability Zone / edge location | región / zona de disponibilidad / ubicación de borde |
| high availability / elasticity | alta disponibilidad / elasticidad |
| On-Demand / Spot / Savings Plans / Reserved Instances | bajo demanda / Spot / planes de ahorro / instancias reservadas |
| data transfer out | transferencia de datos de salida |
| cost allocation tag | etiqueta de asignación de costos |

🎙️ *"Before building anything I estimate it with the Pricing Calculator. A small instance left running for a month costs about twenty dollars; running it only while I work costs a couple. That is why every lab ends by destroying what it created."*

## Siguiente

[Clase 69 — IAM I: usuarios, grupos y políticas](clase-69-iam-usuarios-y-politicas.md)
