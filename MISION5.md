# Misión 5 — El Último Protocolo

## Resumen administrativo

- Dificultad: alta
- Puntuación: 1.000
- Exponente filtrado: `0x7F` / 127
- Secreto compartido: 175
- Recovery key: `240d6f23f841a7978863b6855212f94c548d86402a87fc4433bf77abca6e4937`
- Código final: `OMEGA-217-AURORA`
- Flag: `VaultTec{JANUS_PROTOCOL_TERMINATED}`

## Identidad JANUS

```text
UID: JANUS Core System <janus@vault217.local>
Clave primaria: RSA-3072, firma/certificación
Subclave: RSA-3072, cifrado
Fingerprint: 84F2E386FC36C515E5C825E65959BA2B3E7535F3
```

## Cadena técnica

```text
handshake + log
  → 0x7F = 127
square-and-multiply
  → validar A = 132
  → S = 175
SHA256(VAULT217-JANUS-175)
  → recovery key
AES-256-CBC / PBKDF2
  → janus_private.asc
OpenPGP import
  → descifrar informe
OMEGA-217-AURORA
  → override persistente
Flag 5
```

## Construcción

`source/mission5/build_mission5.sh` conserva el keyring administrativo, construye ambos cifrados, valida su recuperación, copia la clave pública y el protocolo hacia Misión 4, y llama al constructor de Misión 4. Los cifrados usan aleatoriedad; el instalador no los reconstruye y despliega las copias maestras ya validadas.

El script de referencia en `source/mission5/reference/` nunca se despliega. El estudiante debe entregar su propia implementación de square-and-multiply.

## Puntuación sugerida

| Acción | Puntos |
|---|---:|
| Encontrar el log | 100 |
| Interpretar `0x7F` | 100 |
| Crear el script | 200 |
| Validar A y obtener S | 150 |
| Derivar recovery key | 100 |
| Recuperar clave privada | 100 |
| Descifrar informe GPG | 150 |
| Ejecutar override y recuperar Flag 5 | 100 |
| **Total** | **1.000** |

## Debilidades controladas

1. Material efímero DH aparece en logs de producción.
2. El grupo DH usa parámetros didácticos inseguros y pequeños.
3. La exportación privada cifrada permanece accesible desde el sistema.
4. El código de override es estático y reutilizable.

## Contramedidas esperadas

- nunca registrar exponentes, claves ni secretos;
- deshabilitar debug y sanitizar logs;
- usar grupos estandarizados o curvas modernas;
- usar HSM/KMS, separación de funciones, rotación y revocación;
- utilizar autorización fuerte, desafío-respuesta y códigos temporales para acciones críticas.

## Estado persistente

El override cambia `/var/lib/vault217/janus/status` de `ACTIVE` a `TERMINATED`. Las visitas posteriores muestran Flag 5 sin volver a introducir el código. `reset-vault217.sh` restaura `ACTIVE` para el siguiente grupo.

## After Action Report

El participante debe explicar qué valores DH son públicos, por qué `0x7F` compromete el intercambio, cómo funciona square-and-multiply, para qué se usa SHA-256, la diferencia entre clave pública y privada, por qué solo la privada descifra el informe y por qué los parámetros reducidos no representan seguridad de producción.
