# Clase 18 — Bucles: for, while y leer archivos

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** C. Scripting con Bash

> 💡 **La idea de hoy:** un bucle es decir «**haz esto con cada uno**»: con cada servidor de una lista, con cada archivo o con cada línea de un archivo. Y en operaciones hay una variante imprescindible: «**reinténtalo, pero no para siempre**».

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - Los comodines, como `*.log` (clase 03).
> - `if`, `[[ ]]`, el código de salida y `$(( ))` para hacer cuentas (clase 17).
> - Tu `revisar-url.sh` (clase 17) y lanzar algo en segundo plano con `&` (clase 11).

> 🔤 **Palabras nuevas de hoy:**
> - **bucle**: repetir algo con cada elemento, o mientras se cumpla algo.
> - **vuelta** (iteración): cada pasada del bucle, con un elemento distinto.
> - **reintento con límite**: volver a probar algo, pero solo N veces.
> - **subshell**: un shell hijo; en un pipe, cada parte corre en uno.
> - **backoff**: esperar cada vez más entre reintentos.

## Objetivo

- Repetir una acción sobre una lista, sobre archivos o con un contador.
- Leer un archivo línea a línea, ignorando comentarios y líneas vacías: es lo que hará Vigía con su lista de URLs.
- Escribir un bucle de **reintentos con límite**: "espera a que el servicio responda, pero no para siempre".
- Evitar las trampas clásicas: `for f in $(ls)`, la variable que se pierde tras un pipe y la última línea sin salto.

## Por qué importa

Los scripts de operaciones repiten: revisar 20 servidores, comprimir 300 logs, esperar a que la base de datos arranque antes de lanzar la aplicación. El patrón "reintenta N veces con una pausa" aparece en todos los scripts de despliegue y de CI. Y leer una lista línea a línea es el corazón de Vigía.

## Cómo va esta clase

Cinco piezas, y todas dicen lo mismo de formas distintas: «**haz esto con cada uno**». En cada una lees **una** idea y la pruebas enseguida; no pases a la siguiente sin haber ejecutado la anterior.

Si la haces en dos mañanas: el primer día, las **piezas 1 a 3** (unos 35 min); el segundo, las **piezas 4 y 5**, el Rómpelo, el reto y el cierre.

Primero, la carpeta de hoy:

```bash
mkdir -p ~/my-devops-journey/labs/clase-18 && cd ~/my-devops-journey/labs/clase-18
```

## Las piezas

### Pieza 1 — `for`: con cada uno de una lista

```bash
for SERVIDOR in web-01 web-02 db-01; do      # con cada uno de estos tres...
  echo "Revisando $SERVIDOR"                 # ...haz esto (SERVIDOR vale uno distinto en cada vuelta)
done
```

La lista puede salir de un **comodín** (clase 03), y así recorres archivos:

```bash
for F in /var/log/*.log; do
  echo "$F ocupa $(du -h "$F" | cut -f1)"
done
```

El comodín entrega cada archivo entero, aunque su nombre tenga espacios. **Nunca** uses `$(ls)` para esto: parte los nombres por los espacios (lo verás en el Rómpelo 1).

Y para repetir un número de veces, con un contador:

```bash
for (( i = 1; i <= 5; i++ )); do echo "intento $i"; done   # i vale 1, 2, 3, 4 y 5
for i in {1..5}; do echo "intento $i"; done                # lo mismo, si el límite es fijo
```

**Pruébalo:**

```bash
for S in web-01 web-02 db-01; do echo "ping a $S"; done
for F in /etc/*.conf; do echo "$F"; done | head -5
for (( i = 3; i > 0; i-- )); do echo "$i…"; sleep 1; done; echo "¡despegue!"
```

👀 **Qué deberías ver:** `ping a web-01`, `web-02` y `db-01`; cinco archivos `.conf` de `/etc`; y la cuenta atrás 3, 2, 1 con `¡despegue!`.

✋ **Sin mirar:**
1. ¿Qué imprime `for X in a b c; do echo "[$X]"; done`?
2. ¿Por qué no se escribe `for F in $(ls)`?

<details>
<summary>Comprueba</summary>

1. `[a]`, `[b]` y `[c]`, uno por línea. 2. Porque `$(ls)` parte los nombres que tienen espacios; el comodín (`for F in *`) los entrega enteros.
</details>

**En resumen:** `for X in lista` hace algo con cada elemento: palabras, archivos o números.

### Pieza 2 — Leer un archivo línea a línea

Es el corazón de Vigía: una lista de URLs en un archivo, y hacer algo con cada una.

```bash
while read -r URL || [[ -n $URL ]]; do
  [[ -z $URL || $URL == \#* ]] && continue      # salta líneas vacías y comentarios
  echo "procesando: $URL"
done < urls.txt
```

Pieza a pieza:

| Parte | Para qué |
|-------|----------|
| `read -r URL` | lee una línea en `URL`. `-r` impide que interprete las `\` |
| `\|\| [[ -n $URL ]]` | procesa la **última línea** aunque no termine en salto de línea |
| `continue` | pasa a la siguiente vuelta. `break` sale del bucle |
| `\#*` | "empieza por `#`" (se escapa porque `#` abre un comentario) |
| `< urls.txt` al final | el archivo entra por stdin al bucle entero |

(`read` recorta los espacios del principio y del final de cada línea: es lo que quieres para una lista de URLs. Si algún día necesitas la línea **exacta**, usa `IFS= read -r LINEA`).

**Pruébalo, primero con un archivo de configuración** que tiene de todo: un comentario, una línea vacía, espacios delante y una última línea sin salto de línea.

```bash
cat > urls.txt <<'EOF'
# Sitios que quiero vigilar
https://example.com

   https://www.wikipedia.org
# esta está mal a propósito
https://no-existe.invalid
EOF
printf 'https://github.com' >> urls.txt
cat -A urls.txt
```

👀 **Qué deberías ver:** `cat -A` muestra los finales de línea como `$`. Cada línea termina en `$`, menos la última (`https://github.com`): no tiene salto de línea. Pasa a menudo con archivos editados a mano.

**Ahora léelo:**

```bash
cat > leer.sh <<'EOF'
#!/bin/bash
# Uso: ./leer.sh <archivo>
ARCHIVO="${1:?Uso: $0 <archivo>}"
N=0
while read -r URL || [[ -n $URL ]]; do
  [[ -z $URL || $URL == \#* ]] && continue
  N=$(( N + 1 ))
  echo "$N: [$URL]"
done < "$ARCHIVO"
echo "Total: $N URLs"
EOF
chmod +x leer.sh
```

🔮 **Predice:** ¿cuántas URLs contará? ¿Saldrá Wikipedia con espacios delante?

```bash
./leer.sh urls.txt
```

<details>
<summary>Qué deberías ver</summary>

4 URLs numeradas de 1 a 4, con Wikipedia **sin** los espacios de delante y GitHub incluida, y `Total: 4 URLs`.
</details>

**En resumen:** `while read -r L … done < archivo` hace algo con cada línea, saltándose las vacías y los comentarios.

### Pieza 3 — ¿Bucle o `awk`? Hacer algo con cada línea

Para **analizar texto** (contar, filtrar, sumar columnas), el pipeline de la clase 05 (`awk | sort | uniq -c`) es mucho más rápido. Usa un bucle cuando tengas que **hacer algo** con cada elemento: lanzar una petición, comprimir un archivo o conectarte a un servidor. Revisar cada URL es justo eso.

**Pruébalo** con el health check de la clase 17:

```bash
while read -r URL || [[ -n $URL ]]; do
  [[ -z $URL || $URL == \#* ]] && continue
  ../clase-17/revisar-url.sh "$URL"
done < urls.txt
```

👀 **Qué deberías ver:** una línea `UP` o `DOWN` por URL: `no-existe.invalid` sale `DOWN 000`.

Esto ya se parece mucho a Vigía. En la clase 21 le añadirás el tiempo de respuesta, un log, robustez y cron.

**En resumen:** para contar o filtrar, un pipeline; para **hacer algo** con cada elemento, un bucle.

> ⏸️ Si partes la clase en dos mañanas, el primer día termina aquí.

### Pieza 4 — `while`: mientras pase algo, y siempre con límite

`while` repite **mientras** un comando deje código de salida 0, igual que `if` decide con él (clase 17):

```bash
while ! curl -fs -o /dev/null http://localhost:8080; do     # mientras NO (!) responda...
  echo "esperando…"; sleep 2                                # ...espera 2 segundos y vuelve a probar
done
```

`curl -f` (*fail*) hace que una respuesta de error de la web (un 404 o un 500) cuente como fallo; sin `-f`, `curl` solo falla si no puede conectar.

Ese ejemplo tiene un problema grave: si el servicio no arranca nunca, **espera para siempre**. Todo bucle de espera necesita un **límite** de intentos. Lo construyes ahora, con un `for` que cuenta los intentos.

**Pruébalo:**

```bash
cat > esperar-url.sh <<'EOF'
#!/bin/bash
# Uso: ./esperar-url.sh <url> [intentos]
# Espera a que la URL responda. Sale con 1 si se agotan los intentos.
URL="${1:?Uso: $0 <url> [intentos]}"
MAX="${2:-5}"
for (( i = 1; i <= MAX; i++ )); do
  if curl -fs -o /dev/null --max-time 2 "$URL"; then
    echo "OK: $URL responde (intento $i)"
    exit 0
  fi
  echo "intento $i/$MAX: $URL no responde, espero 2 s" >&2
  sleep 2
done
echo "ERROR: $URL no respondió tras $MAX intentos" >&2
exit 1
EOF
chmod +x esperar-url.sh
```

Primero contra algo que no existe. 🔮 **Predice:** ¿cuánto tardará y qué código devolverá?

```bash
./esperar-url.sh http://localhost:8018 3 ; echo "código: $?"
```

<details>
<summary>Qué deberías ver</summary>

Tres intentos fallidos, unos 6 segundos en total, `ERROR: … no respondió tras 3 intentos` y `código: 1`.
</details>

Ahora un servidor que "tarda en arrancar": lo lanzas en segundo plano con 5 segundos de retraso (clase 11) y esperas por él.

```bash
(sleep 5; python3 -m http.server 8018 --bind 127.0.0.1 > /dev/null 2>&1) &
./esperar-url.sh http://localhost:8018 6 ; echo "código: $?"
pkill -f "http.server 8018"
```

👀 **Qué deberías ver:** unos intentos fallidos y después `OK: … responde (intento 4)`, con `código: 0`.

`pkill -f` busca en la línea de comandos completa, así que encuentra el `python3` aunque lo hayas lanzado dentro de un paréntesis.

✋ **Sin mirar:** ¿qué le falta a un bucle `while` que espera a que un servicio arranque?

<details>
<summary>Comprueba</summary>

Un **límite** de intentos: si el servicio no arranca nunca, esperaría para siempre.
</details>

**En resumen:** `while` repite mientras el comando salga bien. Ponle siempre un límite.

### Pieza 5 — Leer la salida de un comando, repartida en variables

`read` también reparte una línea en varias variables, separando por espacios: `read -r A B RESTO` pone la primera palabra en `A`, la segunda en `B` y todo lo demás en `RESTO`. Por convención, `_` es la variable para lo que no te interesa. Y el bucle puede leer la salida de un comando, no solo un archivo.

**Pruébalo:**

```bash
df -h --output=target,pcent | tail -n +2 | while read -r MONTAJE USO; do
  echo "$MONTAJE está al $USO"
done
```

👀 **Qué deberías ver:** una línea por disco, como `/ está al 58%`.

`tail -n +2` salta la cabecera y `read` reparte cada línea en dos variables.

**En resumen:** `cmd | while read -r A B; do …; done` hace algo con cada línea de un comando, con cada columna en su variable.

## Tu chuleta de la clase

| Forma | Para qué |
|-------|----------|
| `for X in a b c; do …; done` | con cada elemento de una lista |
| `for F in /ruta/*.log; do …; done` | con cada archivo (nunca con `$(ls)`) |
| `for (( i = 1; i <= N; i++ )); do …; done` · `for i in {1..5}` | contar |
| `while cmd; do …; done` · `while ! cmd; do …; done` | mientras salga bien · mientras falle |
| `while read -r L \|\| [[ -n $L ]]; do …; done < archivo` | cada línea de un archivo, sin perder la última |
| `read -r A B RESTO` | repartir una línea en variables |
| `continue` · `break` | pasar a la siguiente vuelta · salir del bucle |
| `done < <(comando)` | leer la salida de un comando sin usar un pipe (Rómpelo 2) |
| `shopt -s nullglob` | que un comodín sin coincidencias no produzca nada (Rómpelo 4) |

## Rómpelo

**1. `for` sobre `$(ls)`:**
```bash
mkdir -p espacios && cd espacios
touch "informe final.txt" notas.txt
for F in $(ls); do echo "[$F]"; done
for F in *; do echo "[$F]"; done
cd ..
```
Con `$(ls)` salen tres elementos: `informe`, `final.txt` y `notas.txt`. El shell parte la salida de `ls` por los espacios. El comodín `*` no la parte.

**2. La variable que se pierde:**

> Si se te atraganta, sáltalo y vuelve a él después del cierre: no hace falta entenderlo a la primera.
```bash
N=0
cat urls.txt | while read -r L; do N=$(( N + 1 )); done
echo "N=$N"
```
🔮 **Predice** antes de ejecutar. Sale `N=0`: cada parte de un pipe corre en un **proceso hijo** (un *subshell*), y el hijo nunca cambia las variables del padre (clase 07). El contador subió dentro del hijo, que terminó con el pipe. El arreglo: `while …; done < urls.txt`, sin pipe. Para leer la salida de un comando sin pipe: `done < <(comando)`.

**3. La última línea que desaparece:**
```bash
while read -r L; do echo "[$L]"; done < urls.txt | tail -2
```
`github.com` no aparece: `read` devuelve error al llegar al final del archivo sin salto de línea, y el bucle termina sin procesarla. Por eso existe `|| [[ -n $URL ]]`.

**4. Un comodín sin coincidencias:**
```bash
for F in /tmp/no-hay-nada-*.log; do echo "procesando $F"; done
```
Imprime el patrón tal cual: si un comodín no coincide con nada, bash lo deja sin expandir. El script intentaría procesar un archivo llamado literalmente `*.log`. Soluciones: `[[ -e $F ]] || continue` dentro del bucle, o `shopt -s nullglob` al principio del script, que hace que un comodín sin coincidencias no produzca nada.

## Reto

En `labs/clase-18/`. Cada punto sube en tres escalones: un **ejemplo resuelto** parecido, el mismo reto **con huecos** y, si te atascas 5 minutos, la **pista**.

**1.** Cambia `esperar-url.sh` para que la pausa crezca: 1, 2, 4, 8… segundos (*backoff exponencial*). ¿Por qué crees que los clientes de AWS reintentan así y no a intervalos fijos?

> 🧩 **Ejemplo resuelto:** una variable que se duplica en cada vuelta.
> ```bash
> P=1
> for i in 1 2 3 4; do echo "pausa: $P"; P=$(( P * 2 )); done
> ```
> Imprime `pausa: 1`, `2`, `4` y `8`: después de usarla, cada vuelta la multiplica por 2.

**Ahora tú, con huecos:**
```bash
PAUSA=1
for (( i = 1; i <= MAX; i++ )); do
  if curl -fs -o /dev/null --max-time 2 "$URL"; then
    echo "OK: $URL responde (intento $i)"
    exit 0
  fi
  echo "intento $i/$MAX: espero $PAUSA s" >&2
  sleep "$____"
  PAUSA=$(( PAUSA * ____ ))
done
```

<details>
<summary>Pista</summary>

Es el ejemplo dentro del bucle de `esperar-url.sh`. Para el porqué: imagina mil clientes reintentando a la vez contra un servicio que intenta recuperarse.
</details>

**2.** `comprimir-logs.sh <carpeta>`: comprime con `gzip` cada `*.log` de la carpeta que ocupe más de 1 KB e imprime qué hizo. Si no hay logs, no debe hacer nada raro. Prepara la prueba con `head -c 2000 /dev/urandom > grande.log` y `echo hola > pequeno.log`.

> 🧩 **Ejemplo resuelto:** listar los `.log` de `/var/log` con su tamaño en bytes.
> ```bash
> for F in /var/log/*.log; do
>   [[ -e $F ]] || continue
>   echo "$F: $(stat -c %s "$F") bytes"
> done
> ```
> `stat -c %s` da el tamaño en bytes, y `[[ -e $F ]] || continue` salta la vuelta si el comodín no encontró nada (el Rómpelo 4).

**Ahora tú, con huecos:**
```bash
#!/bin/bash
DIR="${1:?Uso: $0 <carpeta>}"
for F in "$DIR"/*.log; do
  [[ -e $F ]] || continue
  if (( $(stat -c %s "$F") > ____ )); then
    ____ "$F" && echo "comprimido: $F"
  fi
done
```

<details>
<summary>Pista</summary>

1 KB son 1024 bytes. El comando que comprime un archivo lo viste en la clase 03.
</details>

**3.** `contar-codigos.sh <log>`: lee el log de la clase 05 (`~/my-devops-journey/recursos/clase-05/access.log`) línea a línea y cuenta cuántas respuestas son 2xx, 3xx, 4xx y 5xx.

> 🧩 **Ejemplo resuelto:** contar cuántas peticiones del log son `POST`.
> ```bash
> LOG=~/my-devops-journey/recursos/clase-05/access.log
> N=0
> while read -r _ _ _ _ _ METODO _; do
>   [[ $METODO == '"POST' ]] && N=$(( N + 1 ))
> done < "$LOG"
> echo "POST: $N"
> ```
> `read` reparte cada línea: cinco `_` para los trozos que no interesan, el sexto en `METODO` (lleva delante la comilla de la línea: `"POST`) y el resto en el último `_`. Sale `POST: 353`.

**Ahora tú, con huecos:**
```bash
#!/bin/bash
LOG="${1:?Uso: $0 <access.log>}"
C2=0; C3=0; C4=0; C5=0
while read -r _ _ _ _ _ _ _ _ CODIGO _; do
  case "$CODIGO" in
    2??) C2=$(( C2 + 1 )) ;;
    3??) ____ ;;
    4??) ____ ;;
    5??) ____ ;;
  esac
done < "____"
echo "2xx: $C2  3xx: $C3  4xx: $C4  5xx: $C5"
```

<details>
<summary>Pista</summary>

Las tres líneas que faltan son como la de `2??`, cada una con su contador. Y el bucle lee del archivo que llegó como argumento.
</details>

➕ **Si te queda energía:** compara la velocidad de tu `contar-codigos.sh` con el pipeline de la clase 05. Fabrica un log grande con `for i in {1..50}; do cat "$LOG"; done > grande.log` (106 000 líneas) y compara `time ./contar-codigos.sh grande.log` con `time awk '{print $9}' grande.log | sort | uniq -c`. ¿Qué concluyes?

## Cierre

En `notas/fase-1/clase-18.md`:

1. ¿Por qué `for F in $(ls)` es un error? ¿Qué usas en su lugar? *(2 líneas. Empieza así: «Porque `$(ls)` parte los nombres que tienen…, así que `informe final.txt`… En su lugar uso…»)*
2. Explica cada parte de `while read -r URL || [[ -n $URL ]]; do … done < archivo`. *(3–4 líneas, una por pieza. Empieza así: «`read -r URL` lee… `|| [[ -n $URL ]]`… `< archivo`…»)*
3. ¿Por qué un contador dentro de `cmd | while …` vale 0 al terminar? ¿Cómo lo arreglas? *(2 líneas. Empieza así: «Porque cada lado del pipe corre en un…, y el contador sube en su copia… Lo arreglo con…»)*
4. **Repaso (clase 17, sin mirar):** ¿qué evalúa realmente `if`? *(1 línea. Empieza así: «`if` ejecuta un comando y mira su…»)*

Después, escríbeme `examíname clase-18`.

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque el shell parte la salida de `ls` por los espacios (y expande comodines), así que un archivo llamado `informe final.txt` se convierte en dos elementos que no existen. Además, la salida de `ls` está pensada para personas, no para scripts. Se usa un comodín: `for F in *.txt`, que entrega cada archivo entero.

**2.** `read -r URL` lee una línea en la variable `URL` sin interpretar las `\`. `|| [[ -n $URL ]]` hace que, si `read` falla porque la última línea no termina en salto de línea pero sí trae texto, esa línea se procese igualmente. `< archivo` conecta el archivo a la entrada del bucle completo, y el bucle corre en tu propio shell, así que las variables que cambies dentro siguen ahí al salir.

**3.** Cada lado de un pipe corre en un proceso hijo. El `while` incrementa su **copia** de la variable, y esa copia desaparece cuando el pipe termina. El padre conserva el valor original. Se arregla redirigiendo en lugar de usar un pipe: `while …; done < archivo`, o `done < <(comando)` si lees la salida de un comando.

**4.** El código de salida del comando que le sigue: 0 es verdadero (`then`) y cualquier otro valor es falso (`else`).

**Reto 3 (una solución):**
```bash
cat > contar-codigos.sh <<'EOF'
#!/bin/bash
# Uso: ./contar-codigos.sh <access.log>
LOG="${1:?Uso: $0 <access.log>}"
C2=0; C3=0; C4=0; C5=0
while read -r _ _ _ _ _ _ _ _ CODIGO _; do
  case "$CODIGO" in
    2??) C2=$(( C2 + 1 )) ;;
    3??) C3=$(( C3 + 1 )) ;;
    4??) C4=$(( C4 + 1 )) ;;
    5??) C5=$(( C5 + 1 )) ;;
  esac
done < "$LOG"
echo "2xx: $C2  3xx: $C3  4xx: $C4  5xx: $C5"
EOF
```
Con el log del curso: `2xx: 1611  3xx: 155  4xx: 252  5xx: 102`. En el extra, con `grande.log`, en el portátil donde se probó, el bucle tardó 1,2 s y el pipeline, una décima: unas diez veces más. Un log de producción de un día puede tener millones de líneas. Para analizar texto, awk; para actuar por cada elemento, bucle.

**Reto 2 (una solución):**
```bash
cat > comprimir-logs.sh <<'EOF'
#!/bin/bash
# Uso: ./comprimir-logs.sh <carpeta>
DIR="${1:?Uso: $0 <carpeta>}"
[[ -d $DIR ]] || { echo "Error: $DIR no es un directorio" >&2; exit 1; }
for F in "$DIR"/*.log; do
  [[ -e $F ]] || continue
  if (( $(stat -c %s "$F") > 1024 )); then
    gzip "$F" && echo "comprimido: $F"
  fi
done
EOF
```

**Reto 1:** dentro del bucle, `sleep "$PAUSA"; PAUSA=$(( PAUSA * 2 ))`, empezando con `PAUSA=1`. Si miles de clientes reintentan a la vez y a intervalos fijos, golpean al servicio justo cuando intenta recuperarse. Con esperas que crecen (y algo de azar, el *jitter*), la carga se reparte y el servicio tiene tiempo de levantarse.
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| loop / to iterate | bucle / recorrer |
| retry with backoff | reintentar con esperas crecientes |
| glob / wildcard | comodín |
| subshell | proceso hijo del shell |
| trailing newline | salto de línea final |

🎙️ *"When a script depends on another service, I never assume it's ready: I retry with a limit and a growing delay, and fail with a clear error if it never comes up."*

## Siguiente

[Clase 19 — Funciones y scripts robustos](clase-19-scripts-robustos.md)
