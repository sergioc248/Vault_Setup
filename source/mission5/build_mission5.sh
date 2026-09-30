#!/usr/bin/env bash
set -euo pipefail

MISSION_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd -- "$MISSION_DIR/.." && pwd)"
GNUPG_HOME="$MISSION_DIR/admin/gnupg"
BUILD_DIR="$MISSION_DIR/build"
REPORT="$MISSION_DIR/final_report/AURORA_FINAL_REPORT.txt"
M4_EMERGENCY="$SOURCE_DIR/mission4/emergency/AURORA_EMERGENCY"
RECOVERY_KEY='240d6f23f841a7978863b6855212f94c548d86402a87fc4433bf77abca6e4937'

for command in gpg openssl python3 sha256sum; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done
test -f "$REPORT"
test -f "$MISSION_DIR/recovery_protocol.txt"

mkdir -p "$GNUPG_HOME" "$BUILD_DIR" "$M4_EMERGENCY"
chmod 0700 "$GNUPG_HOME"

if ! gpg --homedir "$GNUPG_HOME" --batch --with-colons --list-keys 'janus@vault217.local' 2>/dev/null | grep -q '^pub:'; then
  cat > "$MISSION_DIR/admin/janus-key.batch" <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 3072
Key-Usage: sign
Subkey-Type: RSA
Subkey-Length: 3072
Subkey-Usage: encrypt
Name-Real: JANUS Core System
Name-Email: janus@vault217.local
Expire-Date: 0
%commit
EOF
  gpg --homedir "$GNUPG_HOME" --batch --generate-key "$MISSION_DIR/admin/janus-key.batch"
  rm -f "$MISSION_DIR/admin/janus-key.batch"
fi

FINGERPRINT="$(gpg --homedir "$GNUPG_HOME" --batch --with-colons --list-keys 'janus@vault217.local' | awk -F: '$1 == "fpr" { print $10; exit }')"
test -n "$FINGERPRINT"
printf '%s\n' "$FINGERPRINT" > "$MISSION_DIR/admin/janus-fingerprint.txt"

gpg --homedir "$GNUPG_HOME" --batch --yes --armor --output "$BUILD_DIR/janus_public.asc" --export "$FINGERPRINT"
gpg --homedir "$GNUPG_HOME" --batch --yes --trust-model always --output "$BUILD_DIR/AURORA_FINAL_REPORT.gpg" --encrypt --recipient "$FINGERPRINT" "$REPORT"

PRIVATE_TEMP="$(mktemp "$BUILD_DIR/janus_private.asc.XXXXXX")"
trap 'rm -f "$PRIVATE_TEMP"' EXIT
gpg --homedir "$GNUPG_HOME" --batch --yes --armor --output "$PRIVATE_TEMP" --export-secret-keys "$FINGERPRINT"
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -md sha256 -salt -in "$PRIVATE_TEMP" -out "$BUILD_DIR/janus_private.asc.enc" -pass "pass:$RECOVERY_KEY"
rm -f "$PRIVATE_TEMP"
trap - EXIT

cp "$BUILD_DIR/janus_public.asc" "$M4_EMERGENCY/janus_public.asc"
cp "$MISSION_DIR/recovery_protocol.txt" "$M4_EMERGENCY/recovery_protocol.txt"

VALIDATION_HOME="$(mktemp -d "$BUILD_DIR/validation-gnupg.XXXXXX")"
PRIVATE_CHECK="$(mktemp "$BUILD_DIR/private-check.XXXXXX")"
REPORT_CHECK="$(mktemp "$BUILD_DIR/report-check.XXXXXX")"
trap 'rm -rf "$VALIDATION_HOME" "$PRIVATE_CHECK" "$REPORT_CHECK"' EXIT
chmod 0700 "$VALIDATION_HOME"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -md sha256 -in "$BUILD_DIR/janus_private.asc.enc" -out "$PRIVATE_CHECK" -pass "pass:$RECOVERY_KEY"
gpg --homedir "$VALIDATION_HOME" --batch --import "$BUILD_DIR/janus_public.asc" >/dev/null 2>&1
gpg --homedir "$VALIDATION_HOME" --batch --import "$PRIVATE_CHECK" >/dev/null 2>&1
gpg --homedir "$VALIDATION_HOME" --batch --yes --output "$REPORT_CHECK" --decrypt "$BUILD_DIR/AURORA_FINAL_REPORT.gpg" >/dev/null 2>&1
cmp "$REPORT" "$REPORT_CHECK"
grep -q 'OMEGA-217-AURORA' "$REPORT_CHECK"
rm -rf "$VALIDATION_HOME" "$PRIVATE_CHECK" "$REPORT_CHECK"
trap - EXIT

"$SOURCE_DIR/mission4/build_mission4.sh"

echo "Mission 5 artifacts built and Mission 4 image refreshed."
echo "JANUS fingerprint: $FINGERPRINT"
sha256sum "$BUILD_DIR/janus_public.asc" "$BUILD_DIR/janus_private.asc.enc" "$BUILD_DIR/AURORA_FINAL_REPORT.gpg" "$SOURCE_DIR/cam04.jpg"
