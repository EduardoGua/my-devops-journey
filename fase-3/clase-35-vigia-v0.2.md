# Clase 35 — Proyecto: Vigía v0.2

**Dónde:** tu Ubuntu + GitHub · **Tiempo:** 1 bloque largo (unas 3 h) · **Bloque:** B. Proyectos y examen · **Proyecto de portafolio**

> 💡 **La idea de hoy:** Vigía ya sabe si una web responde; hoy aprende a medir **dos capas más**: cuánto tarda la **resolución DNS** y cuántos días le quedan al **certificado TLS**. Un certificado caducado tumba una web igual que un servidor apagado, y con este aviso te enteras dos semanas antes.

> 📚 **Lo que ya sabes y hoy vas a usar:**
> - `dig` y la caché de `systemd-resolved` (clase 31).
> - `openssl s_client` y `openssl x509 -enddate` para las fechas de un certificado (clase 32, pieza 6 y reto 2).
> - Recortar texto con `${URL#*://}` y `${h%%/*}` (clase 16, pieza 4).
> - Funciones, `set -euo pipefail`, `|| true` y `logger` (clase 19).
> - El ciclo rama → PR → squash y la etiqueta con su *release* (clases 24 y 25).

> 🔤 **Palabras nuevas de hoy:**
> - **`dns_ms`**: los milisegundos que tarda la consulta DNS de una URL.
> - **`cert_days`**: los días que le quedan al certificado antes de vencer.
> - **desglose de una petición**: el tiempo de cada fase (DNS, TCP, TLS, primer byte y total) que da `curl -w`.

## Objetivo

Que Vigía mida las capas que acabas de estudiar: cuánto tarda la **resolución DNS** (`dig`) y cuántos días faltan para que **venza el certificado TLS** (`openssl`). Y completar en el README, en inglés, la sección de qué pasa desde que escribes una URL hasta que ves la página, con mediciones reales de tus sitios. Partes de un modelo ya escrito (en el Entregable): tú pones tus números.

Esa sección del README es la respuesta a una de las preguntas más típicas de entrevista, y es uno de los criterios de salida de esta fase: explicarlo **en voz alta**, sin notas. Escrita, te sirve para repasarla.

## Requisitos

| # | Requisito | Clases |
|---|-----------|--------|
| R1 | Cada línea del log añade dos campos al final: `dns_ms` (milisegundos de la consulta DNS, con `dig`) y `cert_days` (días hasta que vence el certificado; `-` si la URL es `http://` o no hay certificado) | 31, 32 |
| R2 | Si al certificado le quedan menos de 14 días, Vigía escribe un aviso en stderr y en el journal (`logger -t vigia`) | 13, 19 |
| R3 | El host se saca de la URL con expansión de parámetros, sin `cut` ni `sed`, y funciona con puertos y rutas (`https://ejemplo.com:8443/salud` → `ejemplo.com`) | 16 |
| R4 | Una función por capa: `medir_http`, `medir_dns` y `dias_certificado` | 19 |
| R5 | Ningún fallo de DNS o de TLS detiene el script, y nada espera más de 10 segundos | 19, 31, 32 |
| R6 | README: sección *What happens when you type a URL*, con el desglose de `curl -w` de uno de tus sitios | 26, 29, 31, 32 |
| R7 | Cambios con rama y PR, `shellcheck` sin avisos, el formato nuevo del log documentado y etiqueta `v0.2` con su *release* | 19, 24, 25 |

Nuevo formato del log:

```
fecha url código tiempo estado dns_ms cert_days
2026-12-02T21:05:01-05:00 https://example.com 200 0.261431 UP 12 76
2026-12-02T21:05:02-05:00 http://example.com/ 200 0.168687 UP 5 -
```

## Las herramientas

### DNS con `dig`

```bash
dig +noall +stats example.com | grep "Query time"
dig +noall +stats example.com | awk '/Query time/ {print $4}'
```

`+noall +stats` oculta la respuesta y deja solo las estadísticas. `+time=3 +tries=1` limita la espera a 3 segundos y un solo intento.

🔮 **Predice:** ejecuta la segunda línea tres veces seguidas. ¿Dará siempre lo mismo? ¿Por qué?

### Certificado con `openssl`

```bash
H=example.com
echo | timeout 10 openssl s_client -connect "$H:443" -servername "$H" 2>/dev/null \
  | openssl x509 -noout -enddate
```

Sale algo como `notAfter=Dec 25 22:56:35 2026 GMT`. `s_client` abre una conexión TLS como haría un navegador (el `echo |` la cierra en cuanto termina el saludo) y `x509` lee el certificado que llegó. `-servername` envía el nombre del sitio (SNI), imprescindible cuando un servidor aloja varios dominios (clase 32). `timeout 10` corta si el servidor no responde.

Para convertir la fecha en días que faltan:

```bash
FIN="Dec 25 22:56:35 2026 GMT"
echo $(( ($(date -d "$FIN" +%s) - $(date +%s)) / 86400 ))
```

`date +%s` da la fecha en segundos desde 1970: restas, divides entre 86 400 (los segundos de un día) y tienes los días.

### El desglose de una petición con `curl -w`

```bash
curl -s -o /dev/null --max-time 10 -w '
   DNS resuelto:        %{time_namelookup} s
   TCP conectado:       %{time_connect} s
   TLS completado:      %{time_appconnect} s
   Primer byte:         %{time_starttransfer} s
   Total:               %{time_total} s
' https://example.com
```

Cada valor es el tiempo **acumulado** desde el principio. Restando uno del anterior sabes cuánto tardó cada fase: DNS, saludo TCP (clase 26), saludo TLS (clase 32) y lo que tarda el servidor en empezar a responder. Esta es la evidencia de tu README.

## Plan de trabajo

1. Rama nueva: `git switch main && git pull && git switch -c measure-dns-and-tls`.
2. Escribe `host_de`, `medir_dns` y `dias_certificado` en un archivo de pruebas aparte (`/tmp/funciones.sh`, con unas llamadas de ejemplo al final) y pruébalas **sueltas**. Cuando den lo esperado, cópialas a `vigia.sh`.
3. Intégralas en `revisar` y en el formato del log.
4. Pasa la lista de casos difíciles del Rómpelo.
5. README (sección nueva y formato del log), PR, merge, etiqueta `v0.2` y release.

## Pistas

<details><summary>Pista 1 — sacar el host de la URL</summary>

Tres recortes, de izquierda a derecha: quitar el esquema (`${URL#*://}`), quitar la ruta (`${h%%/*}`) y quitar el puerto (`${h%%:*}`).
</details>

<details><summary>Pista 2 — el script muere cuando el host no existe</summary>

Con `set -o pipefail`, si `openssl s_client` o `openssl x509` fallan (no hay conexión, no hay certificado), todo el pipe falla y `set -e` mata el script. Igual que con `curl` en la v0: captura el resultado con `|| true` y decide después. Si la fecha llega vacía, el certificado es `-`.
</details>

<details><summary>Pista 3 — ¿por qué el DNS siempre da 0 ms?</summary>

Tu Ubuntu pregunta a `systemd-resolved` (`127.0.0.53`, clase 31), que guarda las respuestas en caché durante el TTL. La primera consulta viaja por la red; las siguientes salen de la caché local. Decide qué quieres medir y escríbelo en el README: lo que vive un usuario de tu equipo (con caché) o lo que tarda un resolvedor público (`dig @1.1.1.1 …`), que también tiene su propia caché.
</details>

<details><summary>Pista 4 — comparar con decimales</summary>

Los días del certificado son enteros, así que `(( dias < 14 ))` basta. Pero `-` no es un número: compruébalo antes (`[[ $dias != "-" ]] && (( dias < 14 ))`).
</details>

## Rómpelo

```bash
cat > /tmp/urls-v02.txt <<'EOF'
https://example.com
http://example.com/
https://expired.badssl.com/
https://no-existe.invalid
https://github.com:443/EduardoGua
http://192.0.2.1
EOF
time VIGIA_LOG=/tmp/v02.log ./vigia.sh /tmp/urls-v02.txt ; echo "código: $?"
cat /tmp/v02.log
```

🔮 **Predice** la línea de cada URL antes de ejecutar:

| URL | Qué simula | Debe salir |
|-----|------------|------------|
| `http://example.com/` | sin TLS | `cert_days` = `-` |
| `expired.badssl.com` | un certificado vencido (badssl.com es un sitio de pruebas) | `000 … DOWN`, días **negativos** y un aviso. `curl` rechaza el certificado (código 60): para un usuario, la web está caída |
| `no-existe.invalid` | un nombre que no existe | `000 … DOWN`; `dig` responde igualmente (con NXDOMAIN) y da su tiempo; `cert_days` = `-` |
| `github.com:443/EduardoGua` | puerto y ruta en la URL | el host es `github.com` |
| `192.0.2.1` | nadie responde | `DOWN` a los 10 s, y el script sigue |

Si `badssl.com` no responde el día que lo pruebes, busca otro sitio de pruebas de certificados vencidos y anótalo en tus notas.

## Entregable

- `vigia.sh` con las tres funciones nuevas, `shellcheck` sin avisos.
- README actualizado:
  - el formato nuevo del log (siete campos) y qué significa cada uno;
  - la sección **What happens when you type a URL**, a partir del modelo de abajo, con tu desglose real de `curl -w`;
  - *What broke and how I found it* de esta versión, con los cuatro campos de abajo.
- PR fusionado, etiqueta `v0.2` y release.

### Modelo para adaptar (lo escribió Claude)

Cópialo en tu README y rellena los huecos con tu desglose de `curl -w` de uno de tus sitios. No hace falta escribir más.

```markdown
## What happens when you type a URL

Example: `curl https://____`, measured from my laptop on ____ (date).

1. **DNS:** my laptop asks `systemd-resolved` (127.0.0.53) for the IP of the host.
   If the answer is not in its cache, a recursive resolver asks the root servers,
   the TLD servers and the authoritative servers. *(____ ms)*
2. **TCP:** my laptop opens a connection to port 443 with the three-way handshake
   (SYN, SYN-ACK, ACK). *(____ ms)*
3. **TLS:** the server sends its certificate. My laptop checks the chain of trust,
   the name and the dates, and both sides agree on the encryption keys. *(____ ms)*
4. **HTTP:** my laptop sends `GET / HTTP/1.1` with the `Host` header, and the server
   answers `200 OK`. Time to first byte: *____ ms*.
5. **Total:** *____ ms*. On this site the slowest part is ____, because ____.
```

Y para *What broke and how I found it*, una línea por campo:

```markdown
## What broke and how I found it (v0.2)

- **Symptom:** ____
- **What I checked:** ____
- **Cause:** ____
- **Fix:** ____
```

Un ejemplo de esa sección, ya relleno: *Symptom:* the script stopped on `no-existe.invalid`. *What I checked:* `bash -x vigia.sh` showed `openssl` failing inside a pipe. *Cause:* with `pipefail`, the failing pipe killed the script. *Fix:* `|| true` and an empty date becomes `-`.

## Cierre

En `notas/fase-3/clase-35.md`:

1. Con los números de tu desglose de `curl -w`, ¿qué fase de la petición tarda más en uno de tus sitios? ¿A qué crees que se debe? *(2 líneas. Empieza así: «En `<sitio>`, la fase que más tarda es…, con … ms. Creo que se debe a…»)*
2. ¿Por qué la segunda consulta DNS seguida tarda 0 ms? ¿Es un problema para Vigía? *(2 líneas. Empieza así: «Porque la respuesta sale de la caché de `systemd-resolved` durante su TTL… Para Vigía…»)*
3. ¿Qué ve un usuario cuando un certificado vence? ¿Por qué conviene saberlo 14 días antes? *(2 líneas. Empieza así: «El navegador muestra un aviso de… y la mayoría… Conviene saberlo antes para…»)*
4. **Repaso (clase 34, sin mirar):** recita en voz alta tu checklist de diagnóstico capa a capa para "la web no carga". *(Después, escribe solo el nombre de cada paso, uno por línea. Empieza así: «1. Qué devuelve el cliente. 2. …»)*

Después, escríbeme `examíname clase-35`.

## Autocorrección

<details>
<summary>Ábrelo solo cuando tu versión funcione y hayas hecho el Rómpelo</summary>

**Comprueba tu entrega:**
- [ ] `shellcheck vigia.sh` no dice nada.
- [ ] Con la lista del Rómpelo: 3 `UP`, 3 `DOWN`, un aviso del certificado vencido, código 1, unos 13 s.
- [ ] `journalctl -t vigia` muestra el aviso.
- [ ] El README explica los siete campos y tiene la sección *What happens when you type a URL* con números reales.
- [ ] `git tag` muestra `v0.2`, y GitHub tiene la release.

**Las funciones nuevas de una solución de referencia:**
```bash
host_de() {          # host_de <url> → imprime solo el host
  local h="${1#*://}"
  h="${h%%/*}"
  echo "${h%%:*}"
}

medir_dns() {        # medir_dns <host> → milisegundos de la consulta, o "-"
  local ms
  ms="$(dig +noall +stats +time=3 +tries=1 "$1" | awk '/Query time/ {print $4}')" || true
  echo "${ms:--}"
}

dias_certificado() { # dias_certificado <host> → días hasta que vence, o "-"
  local fin
  fin="$(echo | timeout "$TIMEOUT" openssl s_client -connect "$1:443" -servername "$1" 2>/dev/null \
         | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)" || true
  if [[ -z $fin ]]; then echo "-"; return; fi
  echo $(( ($(date -d "$fin" +%s) - $(date +%s)) / 86400 ))
}
```
(El `cut` aquí no rompe R3: R3 se refiere a sacar el host de la URL.)

Y dentro de `revisar`, después de medir:
```bash
dias="-"
[[ $url == https://* ]] && dias="$(dias_certificado "$host")"
...
if [[ $dias != "-" ]] && (( dias < AVISO_DIAS )); then
  logger -t vigia "certificado de $host vence en $dias días" || true
  echo "Aviso: el certificado de $host vence en $dias días" >&2
fi
```
Probado en Ubuntu 26.04: `expired.badssl.com` da `000 … DOWN 6 -4198` (su certificado venció en abril de 2015) y `no-existe.invalid` da `000 … DOWN 7 -`.

**Cierre:**
1. Depende de tu sitio. Lo habitual: en uno lejano o con TLS, el saludo TLS y el primer byte pesan más; en uno con caché DNS, el DNS es casi 0. Si el primer byte tarda mucho, el servidor es lento generando la respuesta; si lo que tarda es la conexión, la distancia o la red.
2. Porque `systemd-resolved` guarda la respuesta en caché hasta que vence su TTL. No es un error: es lo que vive un usuario. Pero si quieres detectar un DNS lento o roto, tienes que preguntar sin caché o a otro resolvedor, y explicar en el README qué mides.
3. El navegador bloquea la página con un aviso de seguridad a pantalla completa ("La conexión no es privada"), y las APIs y `curl` rechazan la conexión: para el usuario, el sitio está caído. Con 14 días de margen hay tiempo de renovarlo sin prisas, o de descubrir que la renovación automática está rota.
4. Desde fuera hacia dentro, o de abajo arriba: ¿qué dice el cliente (código, refused o timeout)? → ¿resuelve el DNS? → ¿hay ruta y llega (`ping`, `traceroute`)? → ¿está abierto el puerto (`nc -zv`, firewall o security group)? → ¿escucha el proceso, y en qué IP (`ss -tlnp`)? → ¿qué dicen los logs del servicio y del proxy?
</details>

## Inglés

| Término | Significado |
|---------|-------------|
| name resolution / lookup | resolución de nombres |
| certificate expiry | vencimiento del certificado |
| time to first byte (TTFB) | tiempo hasta el primer byte |
| TLS handshake | saludo TLS |
| breakdown | desglose |

🎙️ *"My monitor tracks DNS lookup time and certificate expiry as well as HTTP status, so I can see which layer is slow and renew a certificate weeks before it expires."*

## Siguiente

[Clase 36 — P1: Runbook de incidentes](clase-36-p1-incidentes.md)
