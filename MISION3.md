# Misión 3 — Ecos del Vault

## Resumen administrativo

- Dificultad: media
- Puntuación: 1.000
- Acceso inicial: SSH como `ncole`
- Flag: `VaultTec{The_Wire_Remembers}`
- Token: `VT217-AURORA-CAM04`
- Evidencia de continuidad: `cam04.jpg`

## Cadena técnica

```text
transmission.b64
  → Base64
transmission.txt
  → SHA-256 válido
LOCKDOWN-184
  → búsqueda en /vault217
lockdown-184.pcap
  → Wireshark / Follow TCP Stream
Camera 04 + token HTTP
  → archivo web
Flag 3 + cam04.jpg
  → Misión 4
```

## Distribución sugerida

| Acción | Puntos |
|---|---:|
| Localizar los fragmentos | 100 |
| Copiar las evidencias | 100 |
| Decodificar Base64 | 150 |
| Verificar SHA-256 | 150 |
| Localizar el PCAP | 100 |
| Identificar el flujo de Camera 04 | 150 |
| Recuperar el token | 100 |
| Obtener Flag 3 y la imagen | 150 |
| **Total** | **1.000** |

## Contenido de la captura

El generador `source/mission3/generate_pcap.py` produce 54 paquetes con tiempos fijos de octubre de 2077. Contiene ARP, DNS y siete conversaciones HTTP. Camera 01, 02 y 03 usan tokens expirados, ausentes o revocados y reciben 401. Camera 04 transmite el token válido y recibe 200.

La solicitud de Camera 04 está dividida entre segmentos TCP. Wireshark puede reconstruirla con Follow TCP Stream.

## Debilidades controladas

1. Un token sensible se transmite mediante HTTP sin TLS.
2. El token sigue siendo reutilizable después de la captura.
3. Una captura forense sensible es accesible desde la cuenta del Supervisor.

## Riesgos y contramedidas esperadas

- Usar TLS para confidencialidad en tránsito.
- Emitir tokens temporales, rotables o de un solo uso.
- Validar sesión, contexto y autorización, no solo un token estático.
- Restringir y auditar el acceso a capturas de red.
- Evitar almacenar secretos en evidencias accesibles a cuentas operativas.

## Elementos para el After Action Report

El participante debe diferenciar codificación, hash y cifrado; explicar por qué Base64 no protege confidencialidad; demostrar cómo SHA-256 valida integridad; identificar el flujo HTTP; explicar la exposición y reutilización del token; y relacionar `cam04.jpg` con la misión siguiente.

## Transición a Misión 4

La imagen descargada es un JPEG de 1408 × 768 con SHA-256 `a448f3dd1efe7526ec2532b9a5968bb4905cd7e850dec663a54549e441d3cbf9`. Contiene metadata narrativa y un paquete Steghide que inicia la Misión 4. La imagen base sin esteganografía se conserva en `source/mission4/cam04-base.jpg`.
