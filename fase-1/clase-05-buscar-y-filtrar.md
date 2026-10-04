# Clase 05 — Buscar y filtrar: find, grep y compañía

**Dónde:** tu Ubuntu · **Tiempo:** 75 min · **Bloque:** A. Linux en tu equipo

## Objetivo

- Encontrar archivos por nombre, tipo, tamaño o fecha con `find`.
- Buscar texto con `grep` y sus opciones clave.
- Analizar un log real de nginx con `cut`, `sort`, `uniq`, `awk` y `sed`, y **responder preguntas de un incidente** con datos.

## Por qué importa

"La web va lenta desde las 14:00", "nos están atacando", "¿qué endpoint da errores?". Todas se responden filtrando logs. Hay herramientas grandes para eso (CloudWatch Logs Insights, Grafana Loki), pero en el servidor, en el minuto uno del incidente, tienes `grep` y un pipe. Quien sabe filtrar un log en 30 segundos tiene ventaja en cualquier entrevista técnica.

## Teoría

### `find`: buscar archivos

```
find  DÓNDE  CRITERIOS  [ACCIÓN]
find  /etc   -name "*.conf"  -type f
```

| Criterio | Significado |
|----------|-------------|
| `-name "*.log"` | nombre (con comodines, **entre comillas** para que no los expanda el shell) |
| `-iname` | igual, sin distinguir mayúsculas |
| `-type f` / `-type d` | solo archivos / solo directorios |
| `-size +100M` | más de 100 MB (`-size -1k`: menos de 1 KB) |
| `-mtime -1` | modificado hace menos de 1 día (`+7`: hace más de 7) |
| `-maxdepth 2` | no bajar más de 2 niveles |
| `-exec cmd {} \;` | ejecuta `cmd` con cada resultado (`{}` = el archivo) |

### `grep`: buscar texto

| Opción | Efecto |
|--------|--------|
| `-i` | ignora mayúsculas |
| `-n` | número de línea |
| `-c` | solo cuenta coincidencias |
| `-v` | invierte: líneas que **no** coinciden |
| `-r` | recursivo en un directorio |
| `-l` | solo nombres de archivo |
| `-w` | palabra completa |
| `-E` | expresiones regulares extendidas: `-E "error\|fail"` |
| `-o` | solo la parte que coincide |
| `-A 3` / `-B 3` | 3 líneas de contexto después / antes |

**Expresiones regulares mínimas:** `^` inicio de línea · `$` fin · `.` cualquier carácter · `*` repetir el anterior · `[0-9]` un dígito · `|` alternativa (con `-E`).

### La caja de herramientas del pipe

| Herramienta | Uso típico |
|-------------|------------|
| `cut -d' ' -f1` | campo 1, separado por espacios |
| `awk '{print $1, $9}'` | campos 1 y 9. Más flexible que `cut` |
| `awk '$9 >= 500'` | filas cuyo campo 9 sea ≥ 500 |
| `sort` / `sort -n` / `sort -rn` | orden alfabético / numérico / numérico al revés |
| `uniq -c` | agrupa líneas iguales **contiguas** y las cuenta |
| `head -n 10` | las 10 primeras |
| `wc -l` | cuenta líneas |
| `sed 's/viejo/nuevo/g'` | sustituye texto |

El patrón más usado del oficio, **el top-N**:
```bash
... | sort | uniq -c | sort -rn | head
```

### El formato de un log de nginx

```
203.0.113.6 - - [03/Oct/2026:08:00:08 +0000] "POST /login HTTP/1.1" 200 1879 "-" "Mozilla/5.0 ..."
$1           $2 $3 $4                    $5     $6    $7     $8      $9  $10
IP cliente          fecha y hora              método ruta          estado bytes
```

(Campos separados por espacios, como los cuenta `awk`.)

**Códigos de estado HTTP:** 2xx éxito · 3xx redirección · 4xx error del cliente (404 no existe, 401 sin autenticar) · 5xx error del servidor (500 error interno, 502 el servidor de detrás no respondió). Se ven a fondo en la clase 22.

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
find /etc -name "*.conf" -type f 2>/dev/null | head
find /etc -name "*.conf" -type f 2>/dev/null | wc -l
find ~ -maxdepth 2 -type d -name ".*"          # directorios ocultos en tu casa
find /var/log -type f -size +1M 2>/dev/null     # logs grandes
find ~/my-devops-journey -type f -mtime -1      # lo que tocaste en las últimas 24 h
```

🔮 **Predice:** ¿por qué hace falta `2>/dev/null` en `/etc` y `/var/log`?

### 2. `grep` básico sobre el log

```bash
head -3 $LOG
wc -l $LOG
grep -c "POST /login" $LOG
grep "/api/orders" $LOG | head -3
grep -v "200" $LOG | head -3
grep -n "502" $LOG | head -3
grep -E " (500|502) " $LOG | wc -l
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
grep "^198.51.100.7 " $LOG | awk '{print $6, $7, $9}' | sort | uniq -c | sort -rn
grep "^198.51.100.7 " $LOG | grep " 401 " | head -2
grep "^198.51.100.7 " $LOG | grep " 401 " | tail -2
```

Más de cien `POST /login` con 401 en dos minutos, todas con `python-requests`: es un **ataque de fuerza bruta** contra el login. La respuesta en el mundo real sería bloquear esa IP (firewall, WAF) y limitar intentos (rate limit).

**¿Qué rutas fallan con 5xx?**
```bash
awk '$9 >= 500 {print $7}' $LOG | sort | uniq -c | sort -rn
```

**¿A qué hora se concentran los 5xx?**
```bash
awk '$9 >= 500' $LOG | cut -d: -f2 | sort | uniq -c
```

`cut -d: -f2` corta por `:` y se queda con el campo 2, que es la hora. Hay un pico a las 14:00. Si cruzas ese dato con la ruta, sabrás qué se rompió y cuándo:
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

`sed -i` modifica el archivo **en el sitio**. Con `.bak` deja una copia de seguridad: úsalo siempre en servidores.

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

Sobre `$LOG`, un comando o pipeline por pregunta:
1. ¿Cuántas peticiones hizo `curl` (el campo del agente contiene `curl/`)?
2. ¿Cuáles son las 3 rutas que más 404 devuelven?
3. ¿Cuántas IPs **distintas** visitaron la web?
4. ¿Cuántos bytes en total se sirvieron (suma del campo 10)? Pista: `awk '{s += $10} END {print s}'`.
5. Busca en `/etc`, sin entrar en subdirectorios de más de 2 niveles, los archivos que contienen la palabra `Port` y muestra solo sus nombres (pista: `grep -rl`).

## Bandit: empieza la práctica paralela

Desde hoy, los días que te sobren 20–30 minutos: [Bandit](bandit.md).

## Cierre

En `notas/fase-1/clase-05.md`:

1. Explica el patrón `sort | uniq -c | sort -rn | head` paso a paso. ¿Por qué hace falta el primer `sort`?
2. Con los datos del log, redacta en 3–4 líneas un **resumen del incidente**, como si se lo contaras a tu jefe: qué pasó, cuándo, qué afectó y qué harías.
3. ¿Por qué `grep " 401 "` y `awk '$9 == 401'` dieron números distintos? ¿Qué lección sacas?
4. **Repaso (clase 04, sin mirar):** ¿qué hace `2>/dev/null` y por qué lo usaste con `find`?

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
awk '{print $1}' $LOG | sort -u | wc -l                           # sort -u = sort | uniq
awk '{s += $10} END {print s}' $LOG
grep -rl "Port" /etc 2>/dev/null       # para limitar profundidad: find /etc -maxdepth 2 -type f -exec grep -l "Port" {} + 2>/dev/null
```
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
