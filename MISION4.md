# Misión 4 — Sombras de AURORA

## Resumen administrativo

- Dificultad: media-alta
- Puntuación: 1.000
- Evidencia inicial: `cam04.jpg`
- Passphrase Steghide: `AURORA-B04-2077`
- Passphrase AES: `SCI-076-C23`
- Flag: `VaultTec{AURORA_Was_Never_The_Machine}`
- Continuidad: clave pública JANUS, fragmento DH y ubicación del archivo final

## Cadena técnica

```text
cam04.jpg
  → metadata + imagen
Policy 7-B
  → PROJECT-ROOM-YEAR
AURORA-B04-2077
  → Steghide
shaw_package.tar
  → README + ciclo + personal web
SCI-076-C23
  → AES-256-CBC / PBKDF2
aurora_emergency.tar
  → SHA-256 + extracción
Flag 4 + material JANUS
```

## Construcción

La base inmutable está en `source/mission4/cam04-base.jpg`. `source/mission4/build_mission4.sh` genera las capas, utiliza una sal OpenSSL aleatoria y publica el resultado validado como `source/cam04.jpg`. El instalador y el restaurador no reconstruyen la imagen: despliegan esa copia maestra para mantener hashes estables.

La metadata final es:

```text
Software: VaultCam Security System 4.7
Artist: E. Shaw
Image Description: AURORA / B04 / 2077
Comment: Consult public record: Media Archive Policy 7-B
```

## Puntuación sugerida

| Acción | Puntos |
|---|---:|
| Analizar la imagen | 100 |
| Identificar la metadata | 100 |
| Interpretar Política 7-B | 100 |
| Construir la primera passphrase | 100 |
| Extraer `shaw_package.tar` | 150 |
| Construir la passphrase AES | 150 |
| Descifrar y verificar AURORA | 150 |
| Recuperar Flag 4 y material JANUS | 150 |
| **Total** | **1.000** |

## Debilidades controladas

1. La metadata expone proyecto, sala, año y política interna.
2. Las dos passphrases se derivan de información predecible o públicamente accesible.
3. La esteganografía oculta la existencia de datos, pero no sustituye controles criptográficos ni de acceso.

## Contramedidas esperadas

- eliminar metadata sensible antes de distribuir archivos;
- utilizar claves aleatorias y un gestor de secretos;
- rotar secretos y separar identificadores de autenticadores;
- analizar medios con controles DLP y herramientas forenses;
- no confiar en seguridad por ocultamiento.

## After Action Report

El participante debe diferenciar esteganografía y cifrado, explicar el papel de la metadata, documentar la derivación de ambas passphrases, identificar AES/PBKDF2 y SHA-256, describir el giro narrativo de AURORA y justificar cómo el material JANUS conduce a Misión 5.

## Continuidad hacia Misión 5

`janus_public.asc` contiene la identidad OpenPGP RSA-3072 de JANUS y una subclave RSA-3072 de cifrado. `recovery_protocol.txt` define la derivación SHA-256 y los parámetros AES. Los dos archivos finales ya están disponibles para `ncole`; la clave privada sin cifrar nunca se despliega.
