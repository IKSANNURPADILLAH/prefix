#!/bin/bash
set -e

# === KONFIGURASI ===
INTERFACE="eth0"
PORT_START=3129
USERNAME="vodkaace"
PASSWORD="indonesia"
PASSWD_FILE="/etc/squid/passwd"
SQUID_CONF="/etc/squid/squid.conf"
HASIL_FILE="hasil.txt"

PREFIXES=("5.230.10" "94.249.210" "94.249.211")
STARTS=(70 104 39)
ENDS=(85 112 71)
NETMASKS=("255.255.255.224" "255.255.255.0" "255.255.255.0")

# === BACKUP interfaces utama dulu ===
echo "[+] Backup /etc/network/interfaces"
sudo cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)

# === BIKIN KONFIGURASI ALIAS ===
ALIAS_CONF=""
ALIAS_INDEX=1

for idx in "${!PREFIXES[@]}"; do
  PREFIX="${PREFIXES[$idx]}"
  START="${STARTS[$idx]}"
  END="${ENDS[$idx]}"
  NETMASK="${NETMASKS[$idx]}"

  for i in $(seq $START $END); do
    IP="$PREFIX.$i"
    ALIAS_CONF+="

auto ${INTERFACE}:$ALIAS_INDEX
iface ${INTERFACE}:$ALIAS_INDEX inet static
    address $IP
    netmask $NETMASK
"
    ALIAS_INDEX=$((ALIAS_INDEX+1))
  done
done

# === TAMBAHKAN ALIAS KE /etc/network/interfaces TANPA GANGGU eth0 DEFAULT ===
echo "[+] Menambahkan IP alias ke /etc/network/interfaces"
echo "$ALIAS_CONF" | sudo tee -a /etc/network/interfaces > /dev/null

# === RELOAD NETWORK ===
echo "[+] Reload network interface (jika gagal, reboot manual)"
if command -v ifreload &>/dev/null; then
  sudo ifreload -a || echo "[!] ifreload gagal, silakan reboot manual."
else
  echo "[!] ifreload tidak tersedia, coba restart manual:"
  echo "    sudo ifdown $INTERFACE && sudo ifup $INTERFACE"
  echo "    atau reboot VPS Anda."
fi

# === INSTALL SQUID + AUTH ===
echo "[+] Instalasi squid dan apache2-utils"
sudo apt update
sudo apt install squid apache2-utils -y

echo "[+] Setup user squid"
if [ ! -f "$PASSWD_FILE" ]; then
  sudo htpasswd -cb "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
else
  sudo htpasswd -b "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
fi

# Set permission file passwd agar squid bisa baca
sudo chown proxy:proxy "$PASSWD_FILE"
sudo chmod 640 "$PASSWD_FILE"

# === BACKUP KONFIGURASI SQUID ===
echo "[+] Backup squid.conf"
sudo cp "$SQUID_CONF" "$SQUID_CONF.bak.$(date +%s)"

# === TULIS KONFIGURASI SQUID BARU ===
echo "[+] Menulis konfigurasi squid.conf"

sudo tee "$SQUID_CONF" > /dev/null <<EOF
# Minimal squid config with auth and multiple outgoing IP/ports

http_port 3128
visible_hostname proxy-server

# DNS
dns_nameservers 8.8.8.8 8.8.4.4

# Authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSWD_FILE
auth_param basic realm Private Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

# Default deny all
http_access deny all

# Logging
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log
cache_store_log none
logfile_rotate 0
buffered_logs on
dns_v4_first on

EOF

# === TAMBAH PORT DAN IP OUTGOING ===
PORT_OFFSET=0
: > "$HASIL_FILE"

for idx in "${!PREFIXES[@]}"; do
  PREFIX="${PREFIXES[$idx]}"
  START="${STARTS[$idx]}"
  END="${ENDS[$idx]}"

  for i in $(seq $START $END); do
    PORT=$((PORT_START + PORT_OFFSET))
    IP="$PREFIX.$i"

    echo "http_port $PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
    echo "acl to$PORT myport $PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
    echo "tcp_outgoing_address $IP to$PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
    echo "" | sudo tee -a "$SQUID_CONF" > /dev/null

    echo "$USERNAME:$PASSWORD:$IP:$PORT" >> "$HASIL_FILE"
    PORT_OFFSET=$((PORT_OFFSET + 1))
  done
done

# === BUKA PORT DI FIREWALL UFW (JIKA PERLU) ===
if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
  echo "[+] Membuka port proxy di UFW"
  for ((p=PORT_START; p<PORT_START+PORT_OFFSET; p++)); do
    sudo ufw allow "$p/tcp"
  done
fi

# === SYSTEMD LIMIT ===
echo "[+] Set limit file descriptor squid"
sudo mkdir -p /etc/systemd/system/squid.service.d
cat <<EOF | sudo tee /etc/systemd/system/squid.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF

# === RESTART SQUID ===
echo "[+] Restarting squid"
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart squid

echo ""
echo "✅ Proxy setup selesai!"
echo "📄 Proxy list ada di file: $HASIL_FILE"
echo "⚠️ Jika IP alias belum aktif, silakan reboot VPS Anda."
