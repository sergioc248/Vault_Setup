#!/usr/bin/env bash
set -u

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

failures=0
check() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '[PASS] %s\n' "$description"
  else
    printf '[FAIL] %s\n' "$description"
    failures=$((failures + 1))
  fi
}

verify_transmission() {
  local tempdir rc
  tempdir="$(mktemp -d)"
  base64 -d /home/ncole/transmissions/transmission.b64 > "$tempdir/transmission.txt" || { rm -rf "$tempdir"; return 1; }
  (cd "$tempdir" && sha256sum -c /home/ncole/transmissions/transmission.sha256)
  rc=$?
  rm -rf "$tempdir"
  return "$rc"
}

verify_pcap() {
  python3 - /vault217/security/captures/lockdown-184.pcap <<'PY'
from scapy.all import ARP, DNS, Raw, TCP, rdpcap
import sys

packets = rdpcap(sys.argv[1])
assert 40 <= len(packets) <= 70
assert any(ARP in p for p in packets)
assert any(DNS in p for p in packets)
assert any(TCP in p for p in packets)
payload = b"\n".join(bytes(p[Raw].load) for p in packets if Raw in p)
for marker in (
    b"camera=01", b"camera=02", b"camera=03", b"camera=04",
    b"401 Unauthorized", b"200 OK", b"VT217-AURORA-CAM04",
):
    assert marker in payload, marker
PY
}

verify_mission4() {
  local tempdir rc=0
  tempdir="$(mktemp -d)"
  steghide extract -sf /vault217/security/camera_archive/cam04.jpg -p 'AURORA-B04-2077' -xf "$tempdir/shaw_package.tar" -f >/dev/null 2>&1 || rc=1
  if (( rc == 0 )); then
    tar --warning=no-timestamp -C "$tempdir" -xf "$tempdir/shaw_package.tar" || rc=1
  fi
  if (( rc == 0 )); then
    for file in README_SHAW.txt experiment_cycle.txt aurora_emergency.enc aurora_emergency.sha256; do
      test -f "$tempdir/shaw_package/$file" || rc=1
    done
  fi
  if (( rc == 0 )); then
    grep -q 'EMPLOYEE-ID + "-C" + CYCLE' "$tempdir/shaw_package/README_SHAW.txt" || rc=1
    grep -q '^23$' "$tempdir/shaw_package/experiment_cycle.txt" || rc=1
  fi
  if (( rc == 0 )); then
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$tempdir/shaw_package/aurora_emergency.enc" -out "$tempdir/aurora_emergency.tar" -pass pass:SCI-076-C23 || rc=1
  fi
  if (( rc == 0 )); then
    (cd "$tempdir" && sha256sum -c shaw_package/aurora_emergency.sha256) || rc=1
  fi
  if (( rc == 0 )); then
    tar --warning=no-timestamp -C "$tempdir" -xf "$tempdir/aurora_emergency.tar" || rc=1
  fi
  if (( rc == 0 )); then
    grep -qx 'VaultTec{AURORA_Was_Never_The_Machine}' "$tempdir/AURORA_EMERGENCY/flag4.txt" || rc=1
    grep -q '^p = 467$' "$tempdir/AURORA_EMERGENCY/handshake_fragment.txt" || rc=1
    grep -q '^g = 2$' "$tempdir/AURORA_EMERGENCY/handshake_fragment.txt" || rc=1
    grep -q '^A = 132$' "$tempdir/AURORA_EMERGENCY/handshake_fragment.txt" || rc=1
    grep -q '^B = 363$' "$tempdir/AURORA_EMERGENCY/handshake_fragment.txt" || rc=1
    grep -q 'VAULT217-JANUS-S' "$tempdir/AURORA_EMERGENCY/recovery_protocol.txt" || rc=1
    mkdir -m 0700 "$tempdir/gnupg"
    gpg --homedir "$tempdir/gnupg" --batch --import-options show-only --import "$tempdir/AURORA_EMERGENCY/janus_public.asc" || rc=1
  fi
  rm -rf "$tempdir"
  return "$rc"
}

verify_mission5() {
  local tempdir rc=0 fingerprint
  tempdir="$(mktemp -d)"
  mkdir -m 0700 "$tempdir/gnupg"
  steghide extract -sf /vault217/security/camera_archive/cam04.jpg -p 'AURORA-B04-2077' -xf "$tempdir/shaw_package.tar" -f >/dev/null 2>&1 || rc=1
  (( rc == 0 )) && tar --warning=no-timestamp -C "$tempdir" -xf "$tempdir/shaw_package.tar" || rc=1
  (( rc == 0 )) && openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$tempdir/shaw_package/aurora_emergency.enc" -out "$tempdir/aurora_emergency.tar" -pass pass:SCI-076-C23 || rc=1
  (( rc == 0 )) && tar --warning=no-timestamp -C "$tempdir" -xf "$tempdir/aurora_emergency.tar" || rc=1
  (( rc == 0 )) && openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -md sha256 -in /vault217/aurora/final/janus_private.asc.enc -out "$tempdir/janus_private.asc" -pass pass:240d6f23f841a7978863b6855212f94c548d86402a87fc4433bf77abca6e4937 || rc=1
  if (( rc == 0 )); then
    gpg --homedir "$tempdir/gnupg" --batch --import "$tempdir/AURORA_EMERGENCY/janus_public.asc" >/dev/null 2>&1 || rc=1
    gpg --homedir "$tempdir/gnupg" --batch --import "$tempdir/janus_private.asc" >/dev/null 2>&1 || rc=1
  fi
  if (( rc == 0 )); then
    fingerprint="$(gpg --homedir "$tempdir/gnupg" --batch --with-colons --list-keys 'janus@vault217.local' | awk -F: '$1 == "fpr" { print $10; exit }')"
    [[ "$fingerprint" == '84F2E386FC36C515E5C825E65959BA2B3E7535F3' ]] || rc=1
    gpg --homedir "$tempdir/gnupg" --batch --with-colons --list-secret-keys "$fingerprint" | grep -q '^sec:' || rc=1
    gpg --homedir "$tempdir/gnupg" --batch --with-colons --list-keys "$fingerprint" | awk -F: '$1 == "sub" && $12 ~ /e/ { found=1 } END { exit !found }' || rc=1
  fi
  if (( rc == 0 )); then
    gpg --homedir "$tempdir/gnupg" --batch --yes --output "$tempdir/AURORA_FINAL_REPORT.txt" --decrypt /vault217/aurora/final/AURORA_FINAL_REPORT.gpg >/dev/null 2>&1 || rc=1
    grep -q 'JANUS performed exactly as designed' "$tempdir/AURORA_FINAL_REPORT.txt" || rc=1
    grep -q 'OMEGA-217-AURORA' "$tempdir/AURORA_FINAL_REPORT.txt" || rc=1
  fi
  rm -rf "$tempdir"
  return "$rc"
}

verify_override() {
  local state='/var/lib/vault217/janus/status' rc=0 page code
  printf 'ACTIVE\n' > "$state"
  chown apache:apache "$state"
  chmod 0660 "$state"
  restorecon "$state" >/dev/null 2>&1
  page="$(curl -fsS http://127.0.0.1/janus/override/)" || rc=1
  grep -q 'AURORA PROTOCOL ACTIVE' <<<"$page" || rc=1
  ! grep -q 'VaultTec{JANUS_PROTOCOL_TERMINATED}' <<<"$page" || rc=1
  code="$(curl -sS -o /dev/null -w '%{http_code}' -d 'override_code=WRONG' http://127.0.0.1/janus/override/)"
  [[ "$code" == 403 ]] || rc=1
  grep -qx 'ACTIVE' "$state" || rc=1
  page="$(curl -fsS -d 'override_code=OMEGA-217-AURORA' http://127.0.0.1/janus/override/)" || rc=1
  grep -q 'VaultTec{JANUS_PROTOCOL_TERMINATED}' <<<"$page" || rc=1
  grep -qx 'TERMINATED' "$state" || rc=1
  curl -fsS http://127.0.0.1/janus/override/ | grep -q 'VaultTec{JANUS_PROTOCOL_TERMINATED}' || rc=1
  printf 'ACTIVE\n' > "$state"
  chown apache:apache "$state"
  chmod 0660 "$state"
  restorecon "$state" >/dev/null 2>&1
  return "$rc"
}

check "httpd is active" systemctl is-active --quiet httpd
check "httpd is enabled" systemctl is-enabled --quiet httpd
check "sshd is active" systemctl is-active --quiet sshd
check "sshd is enabled" systemctl is-enabled --quiet sshd
check "php-fpm is active" systemctl is-active --quiet php-fpm
check "php-fpm is enabled" systemctl is-enabled --quiet php-fpm
check "SSH configuration is valid" /usr/sbin/sshd -t
check "Apache configuration is valid" apachectl configtest
check "PHP CLI is installed" php --version
check "Scapy is importable" python3 -c 'import scapy'
check "Steghide is installed" steghide --version
check "ExifTool is installed" exiftool -ver
check "GnuPG is installed" gpg --version
check "archive.php syntax is valid" php -l /var/www/html/internal/cameras/archive.php
check "download.php syntax is valid" php -l /var/www/html/internal/cameras/download.php
check "JANUS override PHP syntax is valid" php -l /var/www/html/janus/override/index.php
check "maint217 exists" id maint217
check "ncole exists" id ncole
check "maint217 is not in wheel" bash -c '! id -nG maint217 | grep -qw wheel'
check "ncole is not in wheel" bash -c '! id -nG ncole | grep -qw wheel'
check "ncole belongs to overseer" bash -c 'id -nG ncole | grep -qw overseer'
check "maint217 is not in overseer" bash -c '! id -nG maint217 | grep -qw overseer'
check "web root responds" curl -fsS http://127.0.0.1/
check "robots.txt responds" curl -fsS http://127.0.0.1/robots.txt
check "backup is exposed" bash -c 'curl -fsS http://127.0.0.1/archive/remote-access.conf.bak | grep -q REMOTE_USER=maint217'
check "personnel profile contains dictionary word" bash -c 'curl -fsS http://127.0.0.1/personnel/nathan-cole.html | grep -q SunsetSarsaparilla'
check "Eleanor Shaw profile exposes SCI-076" bash -c 'curl -fsS http://127.0.0.1/personnel/eleanor-shaw.html | grep -q SCI-076'
check "Public Records links the policy index" bash -c 'curl -fsS http://127.0.0.1/records/ | grep -q /policies/'
check "Media Policy 7-B exposes the identifier convention" bash -c 'curl -fsS http://127.0.0.1/policies/media-policy-7b.txt | grep -q PROJECT-ROOM-YEAR'
check "internal area is denied" bash -c '[[ $(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1/internal/) == 403 ]]'
check "camera archive requests a token" bash -c 'page=$(curl -fsS http://127.0.0.1/internal/cameras/archive.php) && grep -q "ARCHIVE TOKEN REQUIRED" <<<"$page" && ! grep -q "VaultTec{The_Wire_Remembers}" <<<"$page"'
check "camera archive rejects a bad token" bash -c '[[ $(curl -sS -o /dev/null -w "%{http_code}" -d "camera=04&token=WRONG" http://127.0.0.1/internal/cameras/archive.php) == 403 ]]'
check "camera archive accepts the recovered token" bash -c 'curl -fsS -d "camera=04&token=VT217-AURORA-CAM04" http://127.0.0.1/internal/cameras/archive.php | grep -q "VaultTec{The_Wire_Remembers}"'
check "camera download rejects a missing token" bash -c '[[ $(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1/internal/cameras/download.php?camera=04") == 403 ]]'
check "camera download returns the source image" bash -c 'curl -fsS "http://127.0.0.1/internal/cameras/download.php?camera=04&token=VT217-AURORA-CAM04" | cmp - /vault217/security/camera_archive/cam04.jpg'
check "Flag 1 has expected value" grep -qx 'VaultTec{Welcome_To_Vault_217}' /home/maint217/flag1.txt
check "Flag 2 has expected value" grep -qx 'VaultTec{Overseer_Access_Granted}' /home/ncole/flag2.txt
check "maint217 cannot read ncole flag" runuser -u maint217 -- test ! -r /home/ncole/flag2.txt
check "ncole cannot read maint217 flag" runuser -u ncole -- test ! -r /home/maint217/flag1.txt
check "maint217 cannot read AURORA" runuser -u maint217 -- test ! -r /vault217/aurora/PROJECT_AURORA_FINAL_REPORT
check "ncole cannot read AURORA" runuser -u ncole -- test ! -r /vault217/aurora/PROJECT_AURORA_FINAL_REPORT
check "ncole can read the security capture" runuser -u ncole -- test -r /vault217/security/captures/lockdown-184.pcap
check "maint217 cannot read the security capture" runuser -u maint217 -- test ! -r /vault217/security/captures/lockdown-184.pcap
check "ncole cannot read the camera image directly" runuser -u ncole -- test ! -r /vault217/security/camera_archive/cam04.jpg
check "maint217 cannot read the camera image directly" runuser -u maint217 -- test ! -r /vault217/security/camera_archive/cam04.jpg
check "ncole cannot read the PHP token source" runuser -u ncole -- test ! -r /var/www/html/internal/cameras/archive.php
check "ncole can read the JANUS debug log" runuser -u ncole -- grep -q 0x7F /home/ncole/system_archive/janus_init_debug.log
check "maint217 cannot read the JANUS debug log" runuser -u maint217 -- test ! -r /home/ncole/system_archive/janus_init_debug.log
check "ncole can read the encrypted final report" runuser -u ncole -- test -r /vault217/aurora/final/AURORA_FINAL_REPORT.gpg
check "ncole can read the encrypted JANUS private key" runuser -u ncole -- test -r /vault217/aurora/final/janus_private.asc.enc
check "maint217 cannot read final archive files" runuser -u maint217 -- test ! -r /vault217/aurora/final/AURORA_FINAL_REPORT.gpg
check "ncole cannot read the override PHP source" runuser -u ncole -- test ! -r /var/www/html/janus/override/index.php
check "Base64 output passes SHA-256 verification" verify_transmission
check "PCAP contains the required protocol evidence" verify_pcap
check "Camera image has VaultCam software metadata" bash -c '[[ $(exiftool -s -s -s -Software /vault217/security/camera_archive/cam04.jpg) == "VaultCam Security System 4.7" ]]'
check "Camera image has Eleanor Shaw metadata" bash -c '[[ $(exiftool -s -s -s -Artist /vault217/security/camera_archive/cam04.jpg) == "E. Shaw" ]]'
check "Camera image has the AURORA identifier" bash -c '[[ $(exiftool -s -s -s -ImageDescription /vault217/security/camera_archive/cam04.jpg) == "AURORA / B04 / 2077" ]]'
check "Camera image points to Policy 7-B" bash -c '[[ $(exiftool -s -s -s -Comment /vault217/security/camera_archive/cam04.jpg) == "Consult public record: Media Archive Policy 7-B" ]]'
check "Camera image contains no C2PA metadata" bash -c '! strings /vault217/security/camera_archive/cam04.jpg | grep -qi c2pa'
check "Mission 4 steganography and AES chain is valid" verify_mission4
check "DH parameters produce public value 132 and secret 175" python3 -c 'assert pow(2, 0x7F, 467) == 132; assert pow(363, 0x7F, 467) == 175'
check "JANUS recovery SHA-256 is correct" bash -c '[[ $(printf %s VAULT217-JANUS-175 | sha256sum | cut -d" " -f1) == 240d6f23f841a7978863b6855212f94c548d86402a87fc4433bf77abca6e4937 ]]'
check "Mission 5 OpenPGP recovery chain is valid" verify_mission5
check "JANUS override persists and can be reset" verify_override
check "SELinux is enforcing" bash -c '[[ $(getenforce) == Enforcing ]]'
check "firewall allows SSH" firewall-cmd --query-service=ssh
check "firewall allows HTTP" firewall-cmd --query-service=http
check "port 22 is listening" bash -c 'ss -lnt | grep -qE "LISTEN.+:22[[:space:]]"'
check "port 80 is listening" bash -c 'ss -lnt | grep -qE "LISTEN.+:80[[:space:]]"'

echo
if (( failures == 0 )); then
  echo "Vault 217 passed all automated checks."
  exit 0
fi
echo "$failures check(s) failed."
exit 1
