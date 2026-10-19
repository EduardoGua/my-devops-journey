# Clase 05 — Buscar y filtrar: find, grep y compañía

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** `find` busca **archivos** (por nombre, tamaño o fecha) y `grep` busca **texto dentro** de los archivos. Con pipes encadenas filtros pequeños como en una **cadena de montaje**: cada herramienta hace una sola cosa (cortar una columna, ordenar, contar) y pasa el resultado a la siguiente. Así respondes las preguntas de un incidente con datos y no con corazonadas.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Un pipe (`|`) pasa el stdout de un programa a la entrada del siguiente, y se construye pieza a pieza (clase 04).
> - `2> /dev/null` descarta los errores, que salen por stderr (clase 04).
> - Un comodín entre comillas le llega tal cual al programa: el shell no lo expande (clase 03).

> 🔤 **Palabras nuevas de hoy:**
> - **log**: el registro de lo que pasa; aquí, una línea por cada visita a una web.
> - **patrón**: el texto que buscas, con o sin comodines.
> - **campo** o trozo: cada dato de una línea, separado por espacios (`$1`, `$9`…).
> - **código de estado HTTP**: el número que dice cómo fue cada visita (200: bien; 404: no existe; 500: falló el servidor).
> - **top-N**: los N que más se repiten.

## Objetivo

- Encontrar archivos por nombre, tipo, tamaño o fecha con `find`.
- Buscar texto con `grep` y sus opciones clave.
- Analizar un log real de nginx con `cut`, `sort`, `uniq`, `awk` y `sed`, y **responder preguntas de un incidente** con datos.

## Por qué importa

"La web va lenta desde las 14:00", "nos están atacando", "¿qué endpoint da errores?". Todas se responden filtrando logs. Hay herramientas grandes para eso (CloudWatch Logs Insights, Grafana Loki), pero en el servidor, en el minuto uno del incidente, tienes `grep` y un pipe. Quien sabe filtrar un log en 30 segundos tiene ventaja en cualquier entrevista técnica.

## Teoría

Cuatro piezas. Las dos primeras son buscar; las dos últimas, sacar respuestas de lo que encuentras.

### 1. `find`: buscar **archivos**

`find` recorre carpetas y te da los archivos que cumplen unas condiciones. Siempre se escribe en el mismo orden: **dónde busco** y **qué condiciones** tiene que cumplir lo que busco.

```
find  /etc   -name "*.conf"   -type f
      └┬─┘   └──────┬──────┘  └──┬──┘
     dónde    que se llame así   que sea un archivo
```

Las cuatro condiciones que más usarás:

| Condición | Significa |
|-----------|-----------|
| `-name "*.log"` | por el nombre. El patrón va **entre comillas**: así el `*` le llega a `find` y no lo expande el shell (clase 03) |
| `-type f` · `-type d` | solo archivos · solo directorios |
| `-size +100M` | que ocupe más de 100 MB |
| `-mtime -1` | modificado hace menos de un día |

**En resumen:** `find DÓNDE CONDICIONES` busca **archivos**. El patrón del nombre, siempre entre comillas.

### 2. `grep`: buscar **texto dentro** de los archivos

`grep texto archivo` imprime las **líneas** del archivo que contienen ese texto. Nada más. Cinco opciones lo cambian:

| Opción | Qué cambia |
|--------|------------|
| `-c` | en vez de las líneas, dice **cuántas** hay |
| `-v` | al revés: las líneas que **no** lo contienen |
| `-i` | no distingue mayúsculas de minúsculas |
| `-n` | pone delante el número de línea |
| `-E "500\|502"` | busca **esto o aquello** |

Y dos símbolos para afinar dónde está el texto: `^` significa «al **principio** de la línea» y `$`, «al **final**». `grep "^198"` encuentra las líneas que **empiezan** por 198, no las que lo tienen en cualquier sitio.

**En resumen:** `grep texto archivo` imprime las líneas que contienen ese texto; con `-c`, las cuenta.

### 3. Leer una línea de log

Un log de nginx tiene una línea por cada visita a la web. Parece un churro, pero cada trozo separado por espacios es un dato, y `awk` los numera así:

```
203.0.113.6 - - [03/Oct/2026:08:00:08 +0000] "POST /login HTTP/1.1" 200 1879 "-" "Mozilla/5.0 ..."
    $1      $2 $3          $4             $5    $6     $7     $8    $9   $10
 quién pidió          cuándo                  método  qué página    estado  bytes
```

Los que más vas a usar: **$1** (la IP de quien visita), **$7** (la página que pidió) y **$9** (el código de estado: cómo le fue).

El código de estado dice cómo fue cada petición, igual que el código de salida de los programas en la clase 04: **2xx** bien · **3xx** redirigido a otro sitio · **4xx** el cliente pidió mal (404: no existe; 401: sin permiso) · **5xx** falló el servidor (500: error interno; 502: el servidor de detrás no respondió). Los verás a fondo en la clase 32.

**En resumen:** cada trozo de la línea es un dato: `$1` quién, `$7` qué página y `$9` cómo le fue.

### 4. Encadenar filtros con `|`

Para responder preguntas con un log se conectan con `|` herramientas pequeñas. Cada una hace **una sola cosa** y le pasa el resultado a la siguiente:

| Comando | Qué hace |
|--------|----------|
| `awk '{print $9}'` | se queda solo con el trozo 9 de cada línea |
| `awk '$9 >= 500'` | deja pasar solo las líneas cuyo trozo 9 es 500 o más |
| `sort` | ordena: las líneas iguales quedan juntas |
| `uniq -c` | junta las iguales **que están seguidas** y pone delante cuántas hay |
| `sort -rn` | ordena por ese número, de mayor a menor |
| `head -5` | se queda con las 5 primeras |

Juntas forman la cadena más usada del oficio, **el top-N**: «¿cuáles son los N que más se repiten?».

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -5    # las 5 IPs que más visitan
```

Ya la construiste pieza a pieza en la clase 04 con `cut`. Hoy cambias `cut` por `awk`, que cuenta los trozos separados por espacios aunque haya varios seguidos.

**En resumen:** `awk` saca un trozo, `sort | uniq -c | sort -rn` cuenta y ordena, y `head` se queda con los primeros.

### ✋ Antes de practicar: tres preguntas, sin mirar

1. Quieres los archivos `.log` de `/var/log`. ¿`find` o `grep`?
2. Quieres saber cuántas líneas de un log contienen `ERROR`. ¿Qué escribes?
3. En la cadena top-N, ¿por qué va `sort` **antes** de `uniq -c`?

<details>
<summary>Comprueba</summary>

1. `find`: buscas **archivos** por su nombre (`find /var/log -name "*.log"`). 2. `grep -c ERROR archivo.log`. 3. Porque `uniq -c` solo junta las líneas iguales que están **seguidas**: primero hay que ordenarlas para que queden juntas.
</details>

### Tu chuleta de la clase

Para consultar mientras practicas. Las opciones con ➕ son extra: no las necesitas hoy.

| `find` | | `grep` | | Pipeline | |
|--------|-|--------|-|-------------------|-|
| `-name "*.log"` | por nombre | `-c` | cuenta | `awk '{print $1, $9}'` | trozos 1 y 9 |
| `-type f` / `d` | archivo / directorio | `-v` | las que no | `awk '$9 >= 500'` | filtra filas |
| `-size +100M` | más de 100 MB | `-i` | sin mayúsculas | `cut -d: -f1` | trozo 1, cortando por `:` |
| `-mtime -1` / `+7` | hace menos de 1 día / más de 7 | `-n` | nº de línea | `sort` / `-n` / `-rn` | orden alfabético / numérico / al revés |
| ➕ `-iname` | nombre sin mayúsculas | `-E "a\|b"` | esto o aquello | `uniq -c` | cuenta iguales seguidas |
| ➕ `-maxdepth 2` | no bajar más de 2 niveles | ➕ `-r` / `-l` | en carpetas / solo nombres | `head` / `wc -l` | primeras / cuenta líneas |
| ➕ `-exec cmd {} \;` | ejecuta `cmd` con cada uno | ➕ `-o`, `-w`, `-A 3` | solo lo que coincide, palabra entera, contexto | `sed 's/viejo/nuevo/g'` | sustituye texto |

## Práctica guiada

```bash
cd ~/my-devops-journey
ls -lh recursos/clase-05/access.log
mkdir -p labs/clase-05 && cd labs/clase-05
LOG=~/my-devops-journey/recursos/clase-05/access.log
```

`LOG=...` guarda la ruta en una variable; `$LOG` la usa. Lo verás a fondo en la clase 07.

### 1. `find`

```bash
find /etc -name "*.conf" -type f 2>/dev/null | head        # archivos de configuración (los 10 primeros)
find /etc -name "*.conf" -type f 2>/dev/null | wc -l       # ¿cuántos hay?
find ~ -maxdepth 2 -type d -name ".*"                     # carpetas ocultas en tu casa, sin bajar más de 2 niveles
find /var/log -type f -size +1M 2>/dev/null | head        # logs grandes (casi todos del journal, clase 13)
find ~/my-devops-journey -type f -mtime -1                # lo que tocaste en las últimas 24 h
```

🔮 **Predice:** ¿por qué hace falta `2>/dev/null` en `/etc` y `/var/log`? Pruébalo sin él en uno de los dos.

<details>
<summary>Compruébalo</summary>

Hay carpetas en las que tu usuario no tiene permiso para entrar, y `find` se queja de cada una por **stderr** (clase 04). `2>/dev/null` descarta esos errores y te deja ver solo los resultados.
</details>

### 2. `grep` básico sobre el log

```bash
head -3 $LOG                          # cómo son las líneas
wc -l $LOG                            # cuántas visitas hay en total
grep -c "POST /login" $LOG            # cuántas veces intentaron iniciar sesión
grep "/api/orders" $LOG | head -3     # las 3 primeras visitas a /api/orders
grep -v "200" $LOG | head -3          # líneas que NO contienen 200
grep -n "502" $LOG | head -3          # líneas con 502, con su número de línea delante
grep -E " (500|502) " $LOG | wc -l    # cuántas tienen 500 o 502 (los espacios evitan coincidir con otros números)
```

👀 **Qué deberías ver:** las 3 primeras líneas del log; `2120` visitas en total; `228` intentos de iniciar sesión; y `102` líneas con 500 o 502.

### 3. Las preguntas de un incidente

**¿Cuántas peticiones por código de estado?**
```bash
awk '{print $9}' $LOG | sort | uniq -c | sort -rn
```

👀 **Qué deberías ver:** `1611 200` arriba del todo y, debajo, el resto de códigos: 404, 401, 304, 500, 301 y 502.

**¿Qué IPs hacen más peticiones?**
```bash
awk '{print $1}' $LOG | sort | uniq -c | sort -rn | head -5
```

👀 **Qué deberías ver:** `198.51.100.7` con 169 visitas, muy por encima de las demás (unas 66 cada una).

🔮 **Predice:** una IP destaca mucho por encima del resto. ¿Qué podría estar haciendo?

```bash
grep "^198.51.100.7 " $LOG | awk '{print $6, $7, $9}' | sort | uniq -c | sort -rn   # qué pidió: método, página y estado
grep "^198.51.100.7 " $LOG | grep " 401 " | head -2                                 # sus primeros 401...
grep "^198.51.100.7 " $LOG | grep " 401 " | tail -2                                 # ...y los últimos: mira la hora
```

El `^` y el espacio del final hacen que solo coincidan las líneas que **empiezan** por esa IP exacta.

Más de cien `POST /login` con 401 en dos minutos, todas con `python-requests`: es un **ataque de fuerza bruta** contra el login. La respuesta en el mundo real sería bloquear esa IP (firewall, WAF) y limitar intentos (rate limit).

**¿Qué rutas fallan con 5xx?**
```bash
awk '$9 >= 500 {print $7}' $LOG | sort | uniq -c | sort -rn
```

**¿A qué hora se concentran los 5xx?**
```bash
awk '$9 >= 500' $LOG | cut -d: -f2 | sort | uniq -c
```

`cut -d: -f2` corta cada línea por los dos puntos y se queda con el trozo 2. Fíjate en por qué es la hora:
```
203.0.113.6 - - [03/Oct/2026:08:00:08 +0000] "GET / ...
└──────── trozo 1 ─────────┘ 2  3  └──── trozo 4 ...
```
Hay un pico a las 14:00. Si cruzas ese dato con la ruta, sabrás qué se rompió y cuándo:
```bash
awk '$9 >= 500' $LOG | grep "2026:14:" | awk '{print $7}' | sort | uniq -c
```

¿Por qué `"2026:14:"` y no solo `":14:"`? Porque `":14:"` también coincidiría con el **minuto** 14 de cualquier hora (`10:14:22`). Incluir lo que va delante de la hora hace el patrón exacto.

### 📄 Para leer: el resumen del incidente

No tienes que escribir nada: lee cómo quedan los datos que acabas de sacar cuando se los cuentas a tu jefe. Fíjate en que cada frase lleva un dato del log (hora, ruta, IP, cuántas peticiones) y una acción.

> Hubo dos problemas. Primero, hacia las 14:00 se triplicaron los errores 5xx (21 en esa hora, frente a unos 8 en las demás), sobre todo en `/api/orders`: los pedidos fallaban. Revisaría los logs de la aplicación de pedidos a esa hora y si hubo algún cambio o despliegue. Segundo, desde la IP 198.51.100.7 hubo un ataque de fuerza bruta: unos 120 `POST /login` con 401 entre las 19:25 y las 19:27, con `python-requests`. La bloquearía en el firewall, limitaría los intentos de login y comprobaría que ninguna cuenta llegó a entrar.

Son **dos** sucesos distintos, a horas distintas: el ataque no causó los errores de las 14:00. Mezclarlos es el error típico cuando se saca una conclusión sin mirar los datos.

### 4. Guardar el informe

```bash
{
  echo "== Informe $(date +%F) =="
  echo "Total peticiones: $(wc -l < $LOG)"
  echo "Errores 5xx: $(awk '$9 >= 500' $LOG | wc -l)"
  echo "Top 3 IPs:"
  awk '{print $1}' $LOG | sort | uniq -c | sort -rn | head -3
} > informe.txt
cat informe.txt
```

👀 **Qué deberías ver:** cuatro partes: la fecha, `Total peticiones: 2120`, `Errores 5xx: 102` y las 3 IPs que más visitan.

Las llaves `{ }` agrupan varios comandos para redirigirlos juntos.

### 5. `sed`: sustituir

```bash
echo "server_port=80" | sed 's/80/8080/'
sed 's/HTTP\/1.1/H1/' $LOG | head -2       # no modifica el archivo, solo la salida
cp $LOG copia.log
sed -i.bak 's/198.51.100.7/IP-BLOQUEADA/g' copia.log
grep -c IP-BLOQUEADA copia.log
ls                                          # sed -i.bak guardó una copia del original
```

👀 **Qué deberías ver:** `server_port=8080`; dos líneas del log con `H1`; `169` (las líneas que cambió); y en el `ls`, `copia.log` y `copia.log.bak`.

`sed 's/viejo/nuevo/g'` se lee «**s**ustituye *viejo* por *nuevo*, **g** = todas las veces en cada línea». En `HTTP\/1.1`, la `\` delante de `/` es necesaria porque `/` separa las partes del `s/…/…/`.

Sin opciones, `sed` no toca el archivo: solo cambia lo que sale por pantalla. `sed -i` modifica el archivo **en el sitio**, y con `.bak` deja antes una copia de seguridad: úsalo siempre así en servidores.

## Rómpelo

**1. Un falso positivo:**
```bash
grep -c " 401 " $LOG
awk '$9 == 401' $LOG | wc -l
```
¿Por qué salen números distintos? Busca la línea extra:
```bash
grep " 401 " $LOG | awk '$9 != 401'
```
`grep " 401 "` también coincide con una respuesta de **401 bytes**. Buscar texto suelto es rápido, pero impreciso. Cuando el formato tiene columnas, filtra por **columna** (`awk`). En un incidente, un número mal contado lleva a una conclusión equivocada.

**2. `uniq` sin `sort`:**
```bash
awk '{print $9}' $LOG | uniq -c | head
```
Salen muchas líneas con el mismo código: `uniq` solo junta repeticiones **seguidas**. Hay que ordenar antes.

**3. El comodín sin comillas en `find`:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
cd ~/my-devops-journey/labs/clase-05
touch a.conf
find /etc -name *.conf 2>/dev/null | head -3
```
El shell expandió `*.conf` a `a.conf` (el archivo de este directorio) **antes** de llamar a `find`, que buscó literalmente `a.conf`. Por eso el patrón va entre comillas.

## Reto

Sobre `$LOG`, un comando o pipeline por pregunta. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** ¿Cuántas peticiones hizo `curl` (el agente de esas líneas contiene `curl/`)?

> 🧩 **Ejemplo resuelto:** ¿cuántas peticiones hizo `python-requests`?
> ```bash
> grep -c 'python-requests' $LOG
> ```
> `grep -c` cuenta las líneas que contienen ese texto. Sale 626.

**Ahora tú, con huecos:** `grep -c '____' $LOG`

<details>
<summary>Pista</summary>

Solo cambia el texto que buscas: el que aparece en las líneas de `curl`.
</details>

**2.** ¿Cuáles son las 3 rutas que más 404 devuelven?

> 🧩 **Ejemplo resuelto:** las 3 rutas que más 500 devuelven.
> ```bash
> awk '$9 == 500 {print $7}' $LOG | sort | uniq -c | sort -rn | head -3
> ```
> `awk` deja pasar las líneas con estado 500 y saca su página (`$7`). El resto es la cadena top-N. Sale `/api/orders` arriba, con 12.

**Ahora tú, con huecos:** `awk '$9 == ____ {print $7}' $LOG | sort | uniq -c | sort -rn | head -3`

<details>
<summary>Pista</summary>

Es el ejemplo con otro código de estado.
</details>

**3.** ¿Cuántas IPs **distintas** visitaron la web?

> 🧩 **Ejemplo resuelto:** ¿cuántas páginas distintas se pidieron?
> ```bash
> awk '{print $7}' $LOG | sort | uniq | wc -l
> ```
> `awk` saca la página de cada visita, `sort` junta las iguales, `uniq` (sin `-c`) deja una línea por página distinta y `wc -l` las cuenta. Salen 8.

**Ahora tú, con huecos:** `awk '{print $____}' $LOG | sort | uniq | wc -l`

<details>
<summary>Pista</summary>

¿En qué trozo de la línea está la IP? Está en la pieza 3 de la teoría.
</details>

**4.** ¿Cuántos bytes en total se sirvieron (la suma del trozo 10)?

> 🧩 **Ejemplo resuelto:** contar las líneas del log con `awk`.
> ```bash
> awk '{n += 1} END {print n}' $LOG
> ```
> En cada línea suma 1 a `n`; al final (`END`), imprime `n`. Sale 2120, lo mismo que `wc -l`.

**Ahora tú, con huecos:** `awk '{s += $____} END {print s}' $LOG`

<details>
<summary>Pista</summary>

En vez de sumar 1 en cada línea, suma el trozo que guarda los bytes.
</details>

**5.** Busca en `/etc` los archivos que contienen la palabra `Port` y muestra solo sus **nombres**.

> 🧩 **Ejemplo resuelto:** los archivos de `/etc` que contienen la palabra `localhost`.
> ```bash
> grep -rl "localhost" /etc 2>/dev/null
> ```
> `-r` busca dentro de todas las carpetas, `-l` enseña solo el nombre de cada archivo que coincide y `2>/dev/null` tira las quejas de permisos.

**Ahora tú, con huecos:** `grep -____ "Port" /etc 2>/dev/null`

<details>
<summary>Pista</summary>

Las mismas dos letras del ejemplo: `r` y `l`.
</details>

## Bandit: empieza la práctica paralela

Desde hoy, los días que te sobren 20–30 minutos: [Bandit](bandit.md).

## Cierre

En `notas/fase-1/clase-05.md`:

1. Explica el patrón `sort | uniq -c | sort -rn | head` paso a paso. ¿Por qué hace falta el primer `sort`? *(3–4 líneas, una por pieza. Empieza así: «`sort` junta… `uniq -c`… `sort -rn`… y `head`… El primer `sort` hace falta porque…»)*
2. **Solo para leer, no se responde ni se califica:** relee el resumen del incidente de la práctica guiada (después del paso 3) y fíjate en qué dato del log sostiene cada frase.
3. ¿Por qué `grep " 401 "` y `awk '$9 == 401'` dieron números distintos? ¿Qué lección sacas? *(2 líneas. Empieza así: «`grep` encontró también una línea en la que 401 era…, mientras que `awk` mira solo… Lección: …»)*
4. **Repaso (clase 04, sin mirar):** ¿qué hace `2>/dev/null` y por qué lo usaste con `find`? *(2 líneas. Empieza así: «Manda stderr a… Con `find` hacía falta porque…»)*

Después, escríbeme `examíname clase-05`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `sort` junta las líneas iguales, `uniq -c` cuenta cada grupo y pone el número delante, `sort -rn` ordena por ese número de mayor a menor y `head` se queda con el top 10. El primer `sort` hace falta porque `uniq` solo agrupa líneas iguales **contiguas**.

**2.** No se califica: era solo para leer el ejemplo de la práctica.

**3.** `grep` busca texto en cualquier parte de la línea, y una línea tenía **401 bytes** en el campo de tamaño. `awk '$9 == 401'` mira solo la columna del estado. Lección: cuando el dato tiene estructura, se filtra por columna. Y siempre se valida un número antes de sacar conclusiones.

**4.** Manda la salida de errores (stderr, flujo 2) a `/dev/null`, que la descarta. `find` recorre directorios donde un usuario normal no tiene permiso y llena la pantalla de "Permiso denegado". Así solo ves los resultados.

**Reto:**
```bash
grep -c 'curl/' $LOG                                              # 484
awk '$9 == 404 {print $7}' $LOG | sort | uniq -c | sort -rn | head -3
awk '{print $1}' $LOG | sort | uniq | wc -l
awk '{s += $10} END {print s}' $LOG
grep -rl "Port" /etc 2>/dev/null
```
En la 3, `uniq` sin `-c` deja una línea por IP distinta, y `sort -u` hace lo mismo en un solo paso.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| regular expression (regex) | expresión regular |
| to filter / to parse logs | filtrar / analizar logs |
| status code | código de estado |
| brute-force attack | ataque de fuerza bruta |
| false positive | falso positivo |

🎙️ *"During an incident, the first thing I do is check the logs: I group errors by status code, endpoint and time to find where and when it started."*

## Siguiente

[Clase 06 — Permisos](clase-06-permisos.md)
