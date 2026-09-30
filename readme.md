# Vault 217

Laboratorio CTF de cinco misiones con temática Vault-Tec. Esta carpeta configura la máquina víctima.

## Requisitos

- Fedora Linux 44 KDE en VirtualBox.
- Interfaz host-only `enp0s8`.
- Acceso `sudo`.

## Uso

```bash
sudo ./install-vault217.sh   # instala y despliega el laboratorio
sudo ./verify-vault217.sh    # comprueba servicios, usuarios y artefactos
sudo ./reset-vault217.sh     # restaura el estado inicial
```

Los scripts MUST ejecutarse como root.

## Servicios

| Puerto | Servicio |
|---|---|
| 22/tcp | OpenSSH |
| 80/tcp | Apache con PHP-FPM |

SELinux permanece en `Enforcing`.

## Estructura

| Ruta | Contenido |
|---|---|
| `source/web/` | Sitio web y endpoints PHP |
| `source/homes/` | Homes de `maint217` y `ncole` |
| `source/mission3/` | Transmisión y generador del PCAP |
| `source/mission4/` | Esteganografía y paquete cifrado |
| `source/mission5/` | Claves GPG e informe final |

## Documentación

| Archivo | Contenido |
|---|---|
| `ARQUITECTURA.md` | Plataforma, servicios y flujo |
| `MISION1.md` a `MISION5.md` | Guía de cada misión |
| `SOLUCIONARIO.md` | Soluciones completas |
| `checklist-validacion.md` | Lista de validación |
| `CAMBIOS.md` | Bitácora de cambios |

`SOLUCIONARIO.md` y los archivos `MISION*.md` contienen credenciales y flags. No los entregue a los participantes.
