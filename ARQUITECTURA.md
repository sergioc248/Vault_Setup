# Arquitectura de Vault 217 — Misiones 1 a 5

## Plataforma

- Fedora Linux 44 KDE
- VirtualBox
- Interfaz de laboratorio: `enp0s8`
- Red host-only observada: `192.168.56.0/24`
- Hostname: `vault217`

## Servicios

| Puerto | Servicio | Uso narrativo |
|---|---|---|
| 22/tcp | OpenSSH (`sshd`) | Terminales remotas de mantenimiento y supervisor |
| 80/tcp | Apache (`httpd`) | Terminal público de Vault-Tec |

`httpd`, `sshd` y el backend local `php-fpm` se habilitan con systemd. SELinux permanece en `Enforcing`. PHP-FPM no abre un puerto de red público: Apache se comunica por el socket Unix `/run/php-fpm/www.sock`.

## Usuarios

| Usuario | Rol | Sudo | Acceso AURORA |
|---|---|---|---|
| `maint217` | Mantenimiento | No | No |
| `ncole` | Supervisor Nathan Cole | No | No |

`ncole` es el único usuario del reto incluido en el grupo suplementario `overseer`. Este grupo permite leer capturas forenses, pero no la imagen de Camera 04 ni el código PHP.

## Flujo

1. Nmap descubre la víctima y los puertos 22/80.
2. La web conduce a `robots.txt` y `/archive/`.
3. `remote-access.conf.bak` revela la cuenta de mantenimiento.
4. SSH como `maint217` entrega Flag 1 y `WO-217-184.txt`.
5. La orden permite deducir `ncole` y remite al perfil público.
6. CeWL obtiene `SunsetSarsaparilla` del perfil de Nathan Cole.
7. Hydra valida la contraseña de `ncole` contra SSH.
8. SSH como `ncole` entrega Flag 2 y la transición a Misión 3.
9. La transmisión Base64 reconstruida pasa una comprobación SHA-256 y revela `LOCKDOWN-184`.
10. `ncole` copia `/vault217/security/captures/lockdown-184.pcap` mediante SCP.
11. El flujo HTTP de Camera 04 revela `VT217-AURORA-CAM04`.
12. El token reutilizado en el archivo web entrega Flag 3 y `cam04.jpg`.
13. La metadata de la imagen conduce a Media Archive Policy 7-B y a `AURORA-B04-2077`.
14. Steghide extrae `shaw_package.tar`.
15. El perfil público de Eleanor Shaw y el ciclo 23 producen `SCI-076-C23`.
16. AES-256-CBC/PBKDF2 recupera el archivo AURORA y entrega Flag 4.
17. La clave pública JANUS, el fragmento DH y la ubicación final preparan la Misión 5.
18. El log del Supervisor expone `0x7F`; un script propio valida `A = 132` y calcula `S = 175`.
19. SHA-256 deriva la contraseña que recupera la identidad privada OpenPGP de JANUS.
20. La clave privada descifra `AURORA_FINAL_REPORT.gpg` y revela el código de terminación.
21. `/janus/override/` persiste el estado terminado y entrega Flag 5.

## Evidencias de Misión 3

| Artefacto | Propietario | Permisos | Propósito |
|---|---|---:|---|
| `/home/ncole/transmissions/transmission.b64` | `root:ncole` | `0440` | Mensaje codificado |
| `/home/ncole/transmissions/transmission.sha256` | `root:ncole` | `0440` | Integridad del mensaje reconstruido |
| `/vault217/security/captures/lockdown-184.pcap` | `root:overseer` | `0640` | Tráfico ARP, DNS, TCP y HTTP |
| `/vault217/security/camera_archive/cam04.jpg` | `root:apache` | `0640` | Entrada de Misión 4 |
| `/var/www/html/internal/cameras/*.php` | `root:apache` | `0640` | Validación de cámara/token y descarga |

`cam04.jpg` permanece fuera del web root. Solo `download.php` puede leerla, y únicamente la entrega cuando recibe la cámara y el token correctos.

## Evidencias de Misión 4

| Artefacto | Ubicación administrativa | Propósito |
|---|---|---|
| Imagen base | `source/mission4/cam04-base.jpg` | Original visual sin payload |
| Imagen final | `source/cam04.jpg` | Metadata y paquete Steghide |
| Constructor | `source/mission4/build_mission4.sh` | Construcción y validación reproducible |
| Paquete exterior | `source/mission4/build/shaw_package.tar` | README, ciclo, AES y hash |
| Archivo AES | `source/mission4/build/aurora_emergency.enc` | Archivo AURORA cifrado |
| Fuente AURORA | `source/mission4/emergency/AURORA_EMERGENCY/` | Contenido administrativo sin cifrar |
| Identidad pública | `source/mission4/emergency/AURORA_EMERGENCY/janus_public.asc` | Identidad OpenPGP JANUS |

La imagen usa Steghide con `AURORA-B04-2077`. El archivo interior utiliza AES-256-CBC, PBKDF2-HMAC-SHA256, 100000 iteraciones y `SCI-076-C23`.

## Evidencias de Misión 5

| Artefacto | Propietario | Permisos | Propósito |
|---|---|---:|---|
| `/home/ncole/system_archive/janus_init_debug.log` | `root:ncole` | `0440` | Exponente efímero filtrado |
| `/vault217/aurora/final/janus_private.asc.enc` | `root:overseer` | `0640` | Identidad privada protegida por AES |
| `/vault217/aurora/final/AURORA_FINAL_REPORT.gpg` | `root:overseer` | `0640` | Informe cifrado para JANUS |
| `/var/www/html/janus/override/index.php` | `root:apache` | `0640` | Interfaz de terminación |
| `/var/lib/vault217/janus/status` | `apache:apache` | `0660` | Estado persistente ACTIVE/TERMINATED |

`/vault217/aurora` usa permisos `0711`: las cuentas pueden atravesar la ruta, pero no leer el informe plano protegido. `/vault217/aurora/final` pertenece a `root:overseer`; `ncole` puede copiar los cifrados y `maint217` no tiene acceso.

La identidad administrativa vive en `source/mission5/admin/gnupg`, protegida por `0700`. El participante recibe únicamente la clave pública y una exportación privada cifrada.

## Límites de seguridad

- Los usuarios del reto no pertenecen a `wheel`.
- Los artefactos son propiedad de root y de solo lectura para su grupo.
- Los homes tienen permisos `0750` y están aislados entre sí.
- El informe plano de `/vault217/aurora` permanece `root:root 0600`.
- `/internal/` responde HTTP 403, mientras que el endpoint concreto `/internal/cameras/archive.php` está disponible.
- No se instala Fail2ban, deliberadamente, para permitir Hydra en el laboratorio.
- El token de Camera 04 viaja en HTTP claro dentro de una captura ficticia y es reutilizable de forma deliberada.
- Los parámetros DH son pequeños deliberadamente y no son seguros para producción.
- El override usa un código estático como debilidad controlada y permanece terminado hasta ejecutar el reset.
