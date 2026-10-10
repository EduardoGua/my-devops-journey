# Clase 18 — Bucles: for, while y leer archivos

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** C. Scripting con Bash

## Objetivo

- Repetir una acción sobre una lista, sobre archivos o con un contador.
- Leer un archivo línea a línea, ignorando comentarios y líneas vacías: es lo que hará Vigía con su lista de URLs.
- Escribir un bucle de **reintentos con límite**: "espera a que el servicio responda, pero no para siempre".
- Evitar las trampas clásicas: `for f in $(ls)`, la variable que se pierde tras un pipe y la última línea sin salto.

## Por qué importa

Los scripts de operaciones repiten: revisar 20 servidores, comprimir 300 logs, esperar a que la base de datos arranque antes de lanzar la aplicación. El patrón "reintenta N veces con una pausa" aparece en todos los scripts de despliegue y de CI. Y leer una lista línea a línea es el corazón de Vigía.

## Teoría

### `for` sobre una lista

```bash
for SERVIDOR in web-01 web-02 db-01; do
  echo "Revisando $SERVIDOR"
done
```

### `for` sobre archivos: comodines, nunca `ls`

```bash
for F in /var/log/*.log; do
  echo "$F ocupa $(du -h "$F" | cut -f1)"
done
```

El comodín entrega cada archivo como un elemento, aunque su nombre tenga espacios. `$(ls)` los parte (lo verás en Rómpelo).

### `for` con contador

```bash
for (( i = 1; i <= 5; i++ )); do echo "intento $i"; done
for i in {1..5}; do echo "intento $i"; done          # lo mismo, si el límite es fijo
```

### `while`: mientras un comando tenga éxito

```bash
while ! curl -fs -o /dev/null http://localhost:8080; do
  echo "esperando…"; sleep 2
done
```

`while` repite mientras el comando devuelva 0, igual que `if` decide con el código de salida. Ese ejemplo tiene un problema grave: si el servicio no arranca nunca, espera para siempre. Siempre pon un límite (práctica 5).

`curl -f` (*fail*) hace que curl devuelva un código de error si la respuesta HTTP es 400 o superior. Sin `-f`, un 404 o un 500 cuentan como éxito para curl.

### Leer un archivo línea a línea

```bash
while read -r URL || [[ -n $URL ]]; do
  [[ -z $URL || $URL == \#* ]] && continue      # salta líneas vacías y comentarios
  echo "procesando: $URL"
done < urls.txt
```

| Pieza | Para qué |
|-------|----------|
| `read -r URL` | lee una línea en `URL`. `-r` impide que interprete las `\` |
| `\|\| [[ -n $URL ]]` | procesa la **última línea** aunque no termine en salto de línea |
| `continue` | pasa a la siguiente vuelta. `break` sale del bucle |
| `\#*` | "empieza por `#`" (se escapa porque `#` abre un comentario) |
| `< urls.txt` al final | el archivo entra por stdin al bucle entero |

`read` recorta los espacios del principio y del final de cada línea, y eso es lo que quieres para una lista de URLs. Si alguna vez necesitas la línea **exacta**, usa `IFS= read -r LINEA`.

`read` también reparte una línea en varias variables, separando por espacios: `read -r A B RESTO` pone la primera palabra en `A`, la segunda en `B` y todo lo demás en `RESTO`. Por convención, `_` es la variable que se usa para lo que no te interesa.

### ¿Bucle o `awk`?

Para **procesar texto** (contar, filtrar, sumar columnas), `awk` y los pipes de la clase 05 son mucho más rápidos. Usa un bucle cuando tengas que **hacer algo** por cada elemento: lanzar una petición, comprimir un archivo o conectarte a un servidor.

## Práctica guiada

```bash
mkdir -p ~/my-devops-journey/labs/clase-18 && cd ~/my-devops-journey/labs/clase-18
```

### 1. `for`

```bash
for S in web-01 web-02 db-01; do echo "ping a $S"; done
for F in /etc/*.conf; do echo "$F"; done | head -5
for (( i = 3; i > 0; i-- )); do echo "$i…"; sleep 1; done; echo "¡despegue!"
```

### 2. Un archivo de configuración

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

`cat -A` muestra los finales de línea como `$`. La última línea (`github.com`) **no** tiene `$`: no termina en salto de línea. Pasa a menudo con archivos editados a mano.

### 3. Leerlo línea a línea

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

### 4. Bucle + la clase 17

```bash
while read -r URL || [[ -n $URL ]]; do
  [[ -z $URL || $URL == \#* ]] && continue
  ../clase-17/revisar-url.sh "$URL"
done < urls.txt
```

Esto ya se parece mucho a Vigía. En la clase 21 le añadirás el tiempo de respuesta, un log, robustez y cron.

### 5. Reintentos con límite

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

Ahora un servidor que "tarda en arrancar": lo lanzas en segundo plano con 5 segundos de retraso (clase 11) y esperas por él.

```bash
(sleep 5; python3 -m http.server 8018 --bind 127.0.0.1 > /dev/null 2>&1) &
./esperar-url.sh http://localhost:8018 6 ; echo "código: $?"
pkill -f "http.server 8018"
```

`pkill -f` busca en la línea de comandos completa, así que encuentra el `python3` aunque lo hayas lanzado dentro de un paréntesis.

### 6. Leer la salida de un comando

```bash
df -h --output=target,pcent | tail -n +2 | while read -r MONTAJE USO; do
  echo "$MONTAJE está al $USO"
done
```

`tail -n +2` salta la cabecera y `read` reparte cada línea en dos variables.

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

1. `contar-codigos.sh <log>`: lee el log de nginx de la clase 05 (`~/my-devops-journey/recursos/clase-05/access.log`) línea a línea y cuenta cuántas respuestas son 2xx, 3xx, 4xx y 5xx. Pista: el código es el campo 9, así que `read -r _ _ _ _ _ _ _ _ CODIGO _` lo deja en `CODIGO`, y un `case` decide el grupo. Compara el tiempo con el de awk: `time ./contar-codigos.sh …` frente a `time awk '{print substr($9,1,1)"xx"}' … | sort | uniq -c`. ¿Qué concluyes?
2. `comprimir-logs.sh <carpeta>`: comprime con `gzip` cada `*.log` de la carpeta que ocupe más de 1 KB (`stat -c %s archivo` da el tamaño en bytes) e imprime qué hizo. Si no hay logs, no debe hacer nada raro. Prepara la prueba con `head -c 2000 /dev/urandom > grande.log` y `echo hola > pequeno.log`.
3. Cambia `esperar-url.sh` para que la pausa crezca: 1, 2, 4, 8… segundos (*backoff exponencial*). ¿Por qué crees que los clientes de AWS reintentan así y no a intervalos fijos?

## Cierre

En `notas/fase-1/clase-18.md`:

1. ¿Por qué `for F in $(ls)` es un error? ¿Qué usas en su lugar?
2. Explica cada parte de `while read -r URL || [[ -n $URL ]]; do … done < archivo`.
3. ¿Por qué un contador dentro de `cmd | while …` vale 0 al terminar? ¿Cómo lo arreglas?
4. **Repaso (clase 17, sin mirar):** ¿qué evalúa realmente `if`?

## Autocorrección

<details>
<summary>Ábrelo solo después de escribir tus respuestas</summary>

**1.** Porque el shell parte la salida de `ls` por los espacios (y expande comodines), así que un archivo llamado `informe final.txt` se convierte en dos elementos que no existen. Además, la salida de `ls` está pensada para personas, no para scripts. Se usa un comodín: `for F in *.txt`, que entrega cada archivo entero.

**2.** `read -r URL` lee una línea en la variable `URL` sin interpretar las `\`. `|| [[ -n $URL ]]` hace que, si `read` falla porque la última línea no termina en salto de línea pero sí trae texto, esa línea se procese igualmente. `< archivo` conecta el archivo a la entrada del bucle completo, y el bucle corre en tu propio shell, así que las variables que cambies dentro siguen ahí al salir.

**3.** Cada lado de un pipe corre en un proceso hijo. El `while` incrementa su **copia** de la variable, y esa copia desaparece cuando el pipe termina. El padre conserva el valor original. Se arregla redirigiendo en lugar de usar un pipe: `while …; done < archivo`, o `done < <(comando)` si lees la salida de un comando.

**4.** El código de salida del comando que le sigue: 0 es verdadero (`then`) y cualquier otro valor es falso (`else`).

**Reto 1 (una solución):**
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
Con el log del curso: `2xx: 1611  3xx: 155  4xx: 252  5xx: 102`. `awk` tarda una fracción de lo que tarda el bucle: para analizar texto, awk; para actuar por cada elemento, bucle.

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

**Reto 3:** dentro del bucle, `sleep "$PAUSA"; PAUSA=$(( PAUSA * 2 ))`, empezando con `PAUSA=1`. Si miles de clientes reintentan a la vez y a intervalos fijos, golpean al servicio justo cuando intenta recuperarse. Con esperas que crecen (y algo de azar, el *jitter*), la carga se reparte y el servicio tiene tiempo de levantarse.
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
