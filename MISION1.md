# Misión 1 — Señal desde el Yermo

## Resumen administrativo

- Dificultad: inicial
- Puntuación: 1.000
- Acceso inicial: red host-only de laboratorio
- Servicios objetivo: HTTP y SSH
- Usuario obtenido: `maint217`
- Contraseña: `VaultTec-MNT-217`
- Flag: `VaultTec{Welcome_To_Vault_217}`
- Continuidad: identidad de Nathan Cole y convención de nombres de usuario

## Objetivo narrativo

Una estación de la Brotherhood of Steel detectó una señal automatizada procedente de Vault 217. El participante debe identificar el sistema que origina la transmisión, determinar qué servicios siguen activos y obtener acceso al terminal remoto de mantenimiento.

## Situación inicial

El participante conoce únicamente:

- la red virtual del laboratorio;
- que existe un sistema Vault-Tec activo;
- que debe investigar el origen de la señal.

No conoce:

- la dirección IP;
- los puertos abiertos;
- los usuarios;
- las contraseñas;
- el sistema operativo de la víctima.

## Cadena técnica

```text
red del laboratorio
  → descubrimiento de hosts
Vault 217
  → enumeración completa
HTTP + SSH
  → terminal web
robots.txt
  → /archive/
remote-access.conf.bak
  → maint217 / VaultTec-MNT-217
SSH
  → Flag 1
WO-217-184.txt
  → Nathan Cole + política de usuarios
Misión 2
```

## Servicios y rutas relevantes

```text
22/tcp  OpenSSH
80/tcp  Apache HTTP Server
```

Rutas web:

```text
/
/maintenance/
/records/
/robots.txt
/archive/
/archive/remote-access.conf.bak
```

## Evidencia vulnerable

El archivo:

```text
/var/www/html/archive/remote-access.conf.bak
```

se publica accidentalmente mediante HTTP y contiene:

```text
REMOTE_ACCESS=true
PROTOCOL=SSH
REMOTE_USER=maint217
TEMP_ACCESS_CODE=VaultTec-MNT-217
```

Los otros documentos del archivo proporcionan contexto y actúan como señuelos razonables.

## Cuenta de mantenimiento

```text
Usuario: maint217
Contraseña: VaultTec-MNT-217
Shell: /bin/bash
Sudo: no
Grupo wheel: no
Acceso AURORA: no
```

El home contiene:

```text
/home/maint217/
├── README.txt
├── flag1.txt
├── terminal_notes.txt
└── work_orders/
    ├── WO-217-184.txt
    ├── WO-217-185.txt
    └── WO-217-191.txt
```

Los artefactos importantes son propiedad de `root:maint217` y de solo lectura para impedir que un participante destruya la evidencia.

## Flag 1

Ruta:

```text
/home/maint217/flag1.txt
```

Contenido:

```text
VaultTec{Welcome_To_Vault_217}
```

## Continuidad hacia Misión 2

`WO-217-184.txt` revela:

```text
Nombre: Nathan Cole
Personnel ID: OVR-001
Convención: primera inicial + apellido
Ejemplo: Arthur Maxson → amaxson
Pista: el Supervisor deriva contraseñas de intereses personales
```

El estudiante debe razonar:

```text
Nathan Cole
  → primera inicial + apellido
  → ncole
```

La orden también indica que el terminal público conserva información del personal. Así, la evidencia de Misión 1 dirige de forma explícita, pero no automática, al perfil requerido en Misión 2.

## Puntuación sugerida

| Acción | Puntos |
|---|---:|
| Identificar la configuración de red | 100 |
| Descubrir Vault 217 | 150 |
| Enumerar puertos y servicios | 150 |
| Identificar el terminal web | 100 |
| Investigar `robots.txt` y `/archive/` | 150 |
| Recuperar las credenciales expuestas | 150 |
| Acceder por SSH y obtener Flag 1 | 100 |
| Interpretar `WO-217-184.txt` | 100 |
| **Total** | **1.000** |

## Debilidad controlada

### Backup sensible dentro del web root

Un archivo de configuración de respaldo contiene una cuenta y una contraseña temporal todavía válida.

### Riesgo

- acceso remoto no autorizado;
- uso de credenciales en otros servicios;
- exposición de estructura y procedimientos internos;
- movimiento hacia información de mayor sensibilidad.

### Contramedidas esperadas

- no almacenar backups en directorios públicos;
- eliminar credenciales de archivos de configuración;
- utilizar gestores de secretos;
- revisar artefactos antes del despliegue;
- rotar credenciales temporales;
- preferir autenticación SSH mediante claves.

## Conceptos evaluados

- configuración de red;
- descubrimiento de hosts;
- enumeración de puertos;
- identificación de servicios;
- reconocimiento web;
- interpretación de `robots.txt`;
- exposición accidental de información;
- autenticación SSH.

## After Action Report

El participante debe explicar:

- cómo determinó la red que debía analizar;
- cómo distinguió la víctima de otros hosts;
- qué implican los puertos 22 y 80;
- por qué `robots.txt` no constituye un control de acceso;
- cómo encontró el backup;
- qué información sensible contenía;
- por qué una credencial temporal todavía válida representa un riesgo;
- cómo la orden de trabajo conduce a `ncole`.

## Insignia

### Explorador del Yermo Digital

Demuestra descubrimiento de infraestructura, enumeración de servicios, reconocimiento web, interpretación de información expuesta y acceso remoto inicial.

## Validación administrativa

`verify-vault217.sh` comprueba:

- disponibilidad de HTTP y SSH;
- existencia de `robots.txt`;
- exposición deliberada del backup;
- existencia y aislamiento de `maint217`;
- ausencia de privilegios administrativos;
- valor de Flag 1;
- separación respecto a `ncole` y AURORA.

`reset-vault217.sh` restaura contraseña, artefactos, propietarios y permisos después de cada grupo.
