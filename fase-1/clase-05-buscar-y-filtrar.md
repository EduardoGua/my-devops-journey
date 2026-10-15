# Clase 05 — Buscar y filtrar: find, grep y compañía

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

> 💡 **La idea de hoy:** `find` busca **archivos** (por nombre, tamaño o fecha) y `grep` busca **texto dentro** de los archivos. Con pipes encadenas filtros pequeños como en una **cadena de montaje**: cada herramienta hace una sola cosa (cortar una columna, ordenar, contar) y pasa el resultado a la siguiente. Así respondes las preguntas de un incidente con datos y no con corazonadas.

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

### 3. Leer una línea de log

Un log de nginx tiene una línea por cada visita a la web. Parece un churro, pero cada trozo separado por espacios es un dato, y `awk` los numera así:

```
203.0.113.6 - - [03/Oct/2026:08:00:08 +0000] "POST /login HTTP/1.1" 200 1879 "-" "Mozilla/5.0 ..."
    $1      $2 $3          $4             $5    $6     $7     $8    $9   $10
 quién pidió          cuándo                  método  qué página    estado  bytes
```

Los que más vas a usar: **$1** (la IP de quien visita), **$7** (la página que pidió) y **$9** (el código de estado: cómo le fue).

El código de estado es la «nota» de cada petición, como la de los programas en la clase 04: **2xx** bien · **3xx** redirigido a otro sitio · **4xx** el cliente pidió mal (404: no existe; 401: sin permiso) · **5xx** falló el servidor (500: error interno; 502: el servidor de detrás no respondió). Los verás a fondo en la clase 32.

### 4. La cadena de montaje

Para responder preguntas con un log se empalman con `|` herramientas pequeñas. Cada una hace **una sola cosa** y le pasa el resultado a la siguiente, como en una cadena de montaje:

| Puesto | Qué hace |
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

| `find` | | `grep` | | Cadena de montaje | |
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

Hay carpetas en las que tu usuario no tiene permiso para entrar, y `find` se queja de cada una por la **manguera 2** (clase 04). `2>/dev/null` tira esas quejas a la papelera y te deja ver solo los resultados.
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

### 3. Las preguntas de un incidente

**¿Cuántas peticiones por código de estado?**
```bash
awk '{print $9}' $LOG | sort | uniq -c | sort -rn
```

**¿Qué IPs hacen más peticiones?**
```bash
awk '{print $1}' $LOG | sort | uniq -c | sort -rn | head -5
```

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
```bash
cd ~/my-devops-journey/labs/clase-05
touch a.conf
find /etc -name *.conf 2>/dev/null | head -3
```
El shell expandió `*.conf` a `a.conf` (el archivo de este directorio) **antes** de llamar a `find`, que buscó literalmente `a.conf`. Por eso el patrón va entre comillas.

## Reto

Sobre `$LOG`, un comando o pipeline por pregunta. Si llevas **5 minutos** atascado en un punto, abre su pista: está para usarla. Atascarse un rato ayuda; atascarse media hora, no.

**1.** ¿Cuántas peticiones hizo `curl` (el agente de esas líneas contiene `curl/`)?

<details>
<summary>Pista</summary>

`grep -c` cuenta las líneas que contienen un texto.
</details>

**2.** ¿Cuáles son las 3 rutas que más 404 devuelven?

<details>
<summary>Pista</summary>

Es como «¿qué rutas fallan con 5xx?» de la práctica 3, pero con `$9 == 404` en lugar de `$9 >= 500`, y con `head -3` al final.
</details>

**3.** ¿Cuántas IPs **distintas** visitaron la web?

<details>
<summary>Pista</summary>

Saca las IPs con `awk '{print $1}'` y ordénalas con `sort`. `uniq` **sin** `-c` deja una sola línea por cada IP distinta. Ya solo te falta contar líneas.
</details>

**4.** ¿Cuántos bytes en total se sirvieron (la suma del trozo 10)?

<details>
<summary>Pista</summary>

Ejecuta `awk '{s += $10} END {print s}' $LOG`. Se lee así: en cada línea, suma el trozo 10 a `s`; al final (`END`), imprime `s`. Aquí lo que se pide es entender cada parte, no inventarlo.
</details>

**5.** Busca en `/etc` los archivos que contienen la palabra `Port` y muestra solo sus **nombres**.

<details>
<summary>Pista</summary>

`grep -r` busca dentro de todas las carpetas, y `-l` enseña solo los nombres de archivo: juntos, `-rl`. Tira a la papelera las quejas de permisos.
</details>

## Bandit: empieza la práctica paralela

Desde hoy, los días que te sobren 20–30 minutos: [Bandit](bandit.md).

## Cierre

En `notas/fase-1/clase-05.md`:

1. Explica el patrón `sort | uniq -c | sort -rn | head` paso a paso. ¿Por qué hace falta el primer `sort`?
2. Con los datos del log, redacta en 3–4 líneas un **resumen del incidente**, como si se lo contaras a tu jefe: qué pasó, cuándo, qué afectó y qué harías.
3. ¿Por qué `grep " 401 "` y `awk '$9 == 401'` dieron números distintos? ¿Qué lección sacas?
4. **Repaso (clase 04, sin mirar):** ¿qué hace `2>/dev/null` y por qué lo usaste con `find`?

Después, escríbeme `examíname clase-05`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** `sort` junta las líneas iguales, `uniq -c` cuenta cada grupo y pone el número delante, `sort -rn` ordena por ese número de mayor a menor y `head` se queda con el top 10. El primer `sort` hace falta porque `uniq` solo agrupa líneas iguales **contiguas**.

**2.** Debe incluir dos sucesos con datos: (a) **errores 5xx** (500/502) concentrados hacia las **14:00**, sobre todo en **`/api/orders`**, probablemente un fallo del servicio o la base de datos que hay detrás de pedidos. Acción: revisar los logs de esa aplicación a esa hora, ver si hubo un despliegue y vigilar su backend. (b) **Fuerza bruta** desde **198.51.100.7**: 120 `POST /login` con 401 en unos dos minutos (~19:25), con `python-requests`. Acción: bloquear la IP, limitar intentos de login y revisar que ninguna cuenta haya entrado.

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
