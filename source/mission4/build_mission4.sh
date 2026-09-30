#!/usr/bin/env bash
set -euo pipefail

MISSION_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd -- "$MISSION_DIR/.." && pwd)"
BASE_IMAGE="$MISSION_DIR/cam04-base.jpg"
BUILD_DIR="$MISSION_DIR/build"
PACKAGE_SOURCE="$MISSION_DIR/shaw_package"
EMERGENCY_SOURCE="$MISSION_DIR/emergency"
FINAL_IMAGE="$SOURCE_DIR/cam04.jpg"
STEGO_PASSWORD='AURORA-B04-2077'
ARCHIVE_PASSWORD='SCI-076-C23'
FIXED_DATE='2077-10-22 23:40:02 UTC'

for command in exiftool steghide openssl tar sha256sum gpg; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done
test -f "$BASE_IMAGE"
test -f "$PACKAGE_SOURCE/README_SHAW.txt"
test -f "$EMERGENCY_SOURCE/AURORA_EMERGENCY/flag4.txt"
test -f "$EMERGENCY_SOURCE/AURORA_EMERGENCY/janus_public.asc"
test -f "$EMERGENCY_SOURCE/AURORA_EMERGENCY/recovery_protocol.txt"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/package/shaw_package" "$BUILD_DIR/validation"

tar --sort=name --format=posix --pax-option=delete=atime,delete=ctime --mtime="$FIXED_DATE" --owner=0 --group=0 --numeric-owner -C "$MISSION_DIR/emergency" -cf "$BUILD_DIR/aurora_emergency.tar" AURORA_EMERGENCY
(cd "$BUILD_DIR" && sha256sum aurora_emergency.tar > aurora_emergency.sha256)
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$BUILD_DIR/aurora_emergency.tar" -out "$BUILD_DIR/aurora_emergency.enc" -pass "pass:$ARCHIVE_PASSWORD"

cp "$PACKAGE_SOURCE/README_SHAW.txt" "$PACKAGE_SOURCE/experiment_cycle.txt" "$BUILD_DIR/package/shaw_package/"
cp "$BUILD_DIR/aurora_emergency.enc" "$BUILD_DIR/aurora_emergency.sha256" "$BUILD_DIR/package/shaw_package/"
tar --sort=name --format=posix --pax-option=delete=atime,delete=ctime --mtime="$FIXED_DATE" --owner=0 --group=0 --numeric-owner -C "$BUILD_DIR/package" -cf "$BUILD_DIR/shaw_package.tar" shaw_package

cp "$BASE_IMAGE" "$BUILD_DIR/cam04-sanitized.jpg"
exiftool -overwrite_original -all= "$BUILD_DIR/cam04-sanitized.jpg" >/dev/null
steghide embed -cf "$BUILD_DIR/cam04-sanitized.jpg" -ef "$BUILD_DIR/shaw_package.tar" -sf "$BUILD_DIR/cam04-stego.jpg" -p "$STEGO_PASSWORD" -f >/dev/null
exiftool -overwrite_original -Software='VaultCam Security System 4.7' -Artist='E. Shaw' -ImageDescription='AURORA / B04 / 2077' -Comment='Consult public record: Media Archive Policy 7-B' "$BUILD_DIR/cam04-stego.jpg" >/dev/null

steghide extract -sf "$BUILD_DIR/cam04-stego.jpg" -p "$STEGO_PASSWORD" -xf "$BUILD_DIR/validation/shaw_package.tar" -f >/dev/null
cmp "$BUILD_DIR/shaw_package.tar" "$BUILD_DIR/validation/shaw_package.tar"
tar --warning=no-timestamp -C "$BUILD_DIR/validation" -xf "$BUILD_DIR/validation/shaw_package.tar"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$BUILD_DIR/validation/shaw_package/aurora_emergency.enc" -out "$BUILD_DIR/validation/aurora_emergency.tar" -pass "pass:$ARCHIVE_PASSWORD"
(cd "$BUILD_DIR/validation" && sha256sum -c shaw_package/aurora_emergency.sha256)
tar --warning=no-timestamp -C "$BUILD_DIR/validation" -xf "$BUILD_DIR/validation/aurora_emergency.tar"
grep -qx 'VaultTec{AURORA_Was_Never_The_Machine}' "$BUILD_DIR/validation/AURORA_EMERGENCY/flag4.txt"
mkdir -m 0700 "$BUILD_DIR/validation/gnupg"
gpg --homedir "$BUILD_DIR/validation/gnupg" --batch --import-options show-only --import "$BUILD_DIR/validation/AURORA_EMERGENCY/janus_public.asc" >/dev/null 2>&1
exiftool -s -s -s -Software -Artist -ImageDescription -Comment "$BUILD_DIR/cam04-stego.jpg" | grep -Fx 'VaultCam Security System 4.7' >/dev/null
if strings "$BUILD_DIR/cam04-stego.jpg" | grep -qi 'c2pa'; then
  echo "C2PA metadata remains in generated image" >&2
  exit 1
fi

install -m 0600 "$BUILD_DIR/cam04-stego.jpg" "$FINAL_IMAGE"
echo "Mission 4 image built and validated: $FINAL_IMAGE"
sha256sum "$FINAL_IMAGE" "$BUILD_DIR/shaw_package.tar" "$BUILD_DIR/aurora_emergency.enc" "$BUILD_DIR/aurora_emergency.tar"
