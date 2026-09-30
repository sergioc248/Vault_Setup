#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SETUP_DIR/source"
test -f "$SOURCE_DIR/web/index.html"
test -f "$SOURCE_DIR/homes/maint217/flag1.txt"
test -f "$SOURCE_DIR/homes/ncole/flag2.txt"
test -f "$SOURCE_DIR/mission3/transmission.txt"
test -f "$SOURCE_DIR/mission3/generate_pcap.py"
test -f "$SOURCE_DIR/cam04.jpg"
test -f "$SOURCE_DIR/mission4/cam04-base.jpg"
test -f "$SOURCE_DIR/mission4/build_mission4.sh"
test -f "$SOURCE_DIR/mission5/build_mission5.sh"
test -f "$SOURCE_DIR/mission5/build/janus_public.asc"
test -f "$SOURCE_DIR/mission5/build/janus_private.asc.enc"
test -f "$SOURCE_DIR/mission5/build/AURORA_FINAL_REPORT.gpg"

echo "[1/10] Installing required packages"
dnf install -y --setopt=install_weak_deps=False httpd openssh-server firewalld rsync policycoreutils-python-utils python3 python3-scapy php php-cli steghide perl-Image-ExifTool openssl tar gnupg2

echo "[2/10] Creating challenge accounts and groups"
groupadd --force overseer
for user in maint217 ncole; do
  if ! id "$user" &>/dev/null; then
    useradd --create-home --shell /bin/bash "$user"
  fi
  usermod --shell /bin/bash "$user"
  gpasswd -d "$user" wheel &>/dev/null || true
done
usermod --append --groups overseer ncole
printf '%s\n' 'maint217:VaultTec-MNT-217' 'ncole:SunsetSarsaparilla' | chpasswd
passwd -u maint217 &>/dev/null || true
passwd -u ncole &>/dev/null || true

echo "[3/10] Building Mission 3 evidence"
base64 -w 76 "$SOURCE_DIR/mission3/transmission.txt" > "$SOURCE_DIR/homes/ncole/transmissions/transmission.b64"
(cd "$SOURCE_DIR/mission3" && sha256sum transmission.txt) > "$SOURCE_DIR/homes/ncole/transmissions/transmission.sha256"
python3 "$SOURCE_DIR/mission3/generate_pcap.py" "$SOURCE_DIR/mission3/generated/lockdown-184.pcap"
php -l "$SOURCE_DIR/web/internal/cameras/archive.php"
php -l "$SOURCE_DIR/web/internal/cameras/download.php"
php -l "$SOURCE_DIR/web/janus/override/index.php"
steghide info "$SOURCE_DIR/cam04.jpg" -p 'AURORA-B04-2077' 2>&1 | grep -q 'shaw_package.tar'
exiftool -s -s -s -ImageDescription "$SOURCE_DIR/cam04.jpg" | grep -Fx 'AURORA / B04 / 2077' >/dev/null
runuser -u vault217 -- gpg --homedir "$SOURCE_DIR/mission5/admin/gnupg" --batch --list-keys 'janus@vault217.local' >/dev/null

echo "[4/10] Deploying the Vault-Tec web terminal"
install -d -o root -g root -m 0755 /var/www/html
rsync -a --delete "$SOURCE_DIR/web/" /var/www/html/
chown -R root:root /var/www/html
find /var/www/html -type d -exec chmod 0755 {} +
find /var/www/html -type f -exec chmod 0644 {} +
cat > /etc/httpd/conf.d/vault217.conf <<'EOF'
ServerName vault217
ServerTokens Prod
ServerSignature Off
<Directory "/var/www/html">
    Options -Indexes
    AllowOverride None
    Require all granted
</Directory>
AddType text/plain .bak .log .txt
EOF
install -d -m 0755 /etc/sysconfig
touch /etc/sysconfig/httpd
grep -q '^OPTIONS=' /etc/sysconfig/httpd || printf '\nOPTIONS=""\n' >> /etc/sysconfig/httpd
cat > /etc/php.d/99-vault217.ini <<'EOF'
expose_php=Off
display_errors=Off
log_errors=On
EOF
chown root:apache /var/www/html/internal/cameras /var/www/html/internal/cameras/archive.php /var/www/html/internal/cameras/download.php
chmod 0750 /var/www/html/internal/cameras
chmod 0640 /var/www/html/internal/cameras/archive.php /var/www/html/internal/cameras/download.php
chown root:apache /var/www/html/janus/override /var/www/html/janus/override/index.php
chmod 0750 /var/www/html/janus/override
chmod 0640 /var/www/html/janus/override/index.php
apachectl configtest

echo "[5/10] Deploying mission evidence"
for user in maint217 ncole; do
  rsync -a --delete "$SOURCE_DIR/homes/$user/" "/home/$user/"
  chown root:"$user" "/home/$user"
  chmod 0750 "/home/$user"
  find "/home/$user" -mindepth 1 -type d -exec chown root:"$user" {} + -exec chmod 0750 {} +
  find "/home/$user" -type f -exec chown root:"$user" {} + -exec chmod 0440 {} +
done
install -d -o root -g root -m 0711 /vault217/aurora
cat > /vault217/aurora/PROJECT_AURORA_FINAL_REPORT <<'EOF'
CLASSIFIED — PROJECT AURORA
Access requires credentials not available in Missions 1 or 2.
EOF
chown root:root /vault217/aurora/PROJECT_AURORA_FINAL_REPORT
chmod 0600 /vault217/aurora/PROJECT_AURORA_FINAL_REPORT
install -d -o root -g overseer -m 0750 /vault217/aurora/final
rm -f /vault217/aurora/final/ARCHIVE_STATUS.txt
install -o root -g overseer -m 0640 "$SOURCE_DIR/mission5/build/AURORA_FINAL_REPORT.gpg" /vault217/aurora/final/AURORA_FINAL_REPORT.gpg
install -o root -g overseer -m 0640 "$SOURCE_DIR/mission5/build/janus_private.asc.enc" /vault217/aurora/final/janus_private.asc.enc

install -d -o root -g root -m 0755 /vault217/security
install -d -o root -g overseer -m 0750 /vault217/security/captures
install -o root -g overseer -m 0640 "$SOURCE_DIR/mission3/generated/lockdown-184.pcap" /vault217/security/captures/lockdown-184.pcap
install -d -o root -g apache -m 0750 /vault217/security/camera_archive
install -o root -g apache -m 0640 "$SOURCE_DIR/cam04.jpg" /vault217/security/camera_archive/cam04.jpg
install -d -o root -g apache -m 0770 /var/lib/vault217/janus
printf 'ACTIVE\n' > /var/lib/vault217/janus/status
chown apache:apache /var/lib/vault217/janus/status
chmod 0660 /var/lib/vault217/janus/status

echo "[6/10] Configuring SSH"
cat > /etc/ssh/sshd_config.d/00-vault217.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication no
PermitRootLogin no
UsePAM yes
MaxAuthTries 6
MaxStartups 100:30:200
LoginGraceTime 60
AllowUsers vault217 maint217 ncole
EOF
cat > /etc/profile.d/vault217-banner.sh <<'EOF'
if [[ $- == *i* ]]; then
  case "${USER:-}" in
    maint217)
      cat <<'BANNER'

VAULT-TEC INDUSTRIES
VAULT 217 REMOTE MAINTENANCE TERMINAL

AUTHORIZED PERSONNEL ONLY
Welcome, Maintenance Technician.
WARNING: Vault 217 remains in AUTONOMOUS MODE.

BANNER
      ;;
    ncole)
      cat <<'BANNER'

VAULT-TEC INDUSTRIES
VAULT 217 OVERSEER TERMINAL

ACCESS LEVEL: OVERSEER
USER: NATHAN COLE
JANUS SECURITY STATUS: LOCKDOWN
PROJECT AURORA: ACCESS DENIED

BANNER
      ;;
  esac
fi
EOF
chmod 0644 /etc/profile.d/vault217-banner.sh
ssh-keygen -A
/usr/sbin/sshd -t

echo "[7/10] Applying SELinux labels"
semanage fcontext -a -t httpd_sys_content_t '/vault217/security/camera_archive(/.*)?' 2>/dev/null || semanage fcontext -m -t httpd_sys_content_t '/vault217/security/camera_archive(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/lib/vault217/janus(/.*)?' 2>/dev/null || semanage fcontext -m -t httpd_sys_rw_content_t '/var/lib/vault217/janus(/.*)?'
restorecon -RF /var/www/html /home/maint217 /home/ncole /vault217 /var/lib/vault217 /etc/ssh/sshd_config.d /etc/profile.d

echo "[8/10] Restricting the firewall to the challenge services"
systemctl enable --now firewalld
ZONE="$(firewall-cmd --get-zone-of-interface=enp0s8 2>/dev/null || true)"
[[ -n "$ZONE" && "$ZONE" != "no zone" ]] || ZONE="$(firewall-cmd --get-default-zone)"
firewall-cmd --permanent --zone="$ZONE" --query-service=ssh >/dev/null || firewall-cmd --permanent --zone="$ZONE" --add-service=ssh
firewall-cmd --permanent --zone="$ZONE" --query-service=http >/dev/null || firewall-cmd --permanent --zone="$ZONE" --add-service=http
firewall-cmd --permanent --zone="$ZONE" --query-port=1025-65535/tcp >/dev/null && firewall-cmd --permanent --zone="$ZONE" --remove-port=1025-65535/tcp
firewall-cmd --permanent --zone="$ZONE" --query-port=1025-65535/udp >/dev/null && firewall-cmd --permanent --zone="$ZONE" --remove-port=1025-65535/udp
firewall-cmd --permanent --zone="$ZONE" --query-service=samba-client >/dev/null && firewall-cmd --permanent --zone="$ZONE" --remove-service=samba-client
firewall-cmd --reload

echo "[9/10] Enabling services and setting identity"
hostnamectl set-hostname vault217
systemctl enable --now sshd httpd php-fpm
systemctl restart sshd php-fpm httpd

echo "[10/10] Protecting administrative sources"
chmod 0700 "$SETUP_DIR"
find "$SETUP_DIR/source" -type d -exec chmod 0700 {} +
find "$SETUP_DIR/source" -type f -exec chmod 0600 {} +
chmod 0700 "$SOURCE_DIR/mission4/build_mission4.sh"
chmod 0700 "$SOURCE_DIR/mission5/build_mission5.sh"
chmod 0700 "$SETUP_DIR"/*.sh
chmod 0600 "$SETUP_DIR"/*.md
chown -R vault217:vault217 "$SETUP_DIR"
echo "Vault 217 installation completed."
