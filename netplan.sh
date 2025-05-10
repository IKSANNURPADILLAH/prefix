#!/bin/bash
# AUTOPROXY SETUP + NETPLAN IP ADDER

set -euo pipefail

# === KONFIGURASI ===
INTERFACE="eth0"
IP_PREFIX="94.249.191"
START=0
END=255
PORT_START=3128
USERNAME="vodkaace"
PASSWORD="indonesia"
PASSWD_FILE="/etc/squid/passwd"
SQUID_CONF="/etc/squid/squid.conf"
HASIL_FILE="hasil.txt"
NETMASK="24"
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

# === CEK INTERFACE ===
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "[!] Interface $INTERFACE tidak ditemukan. Periksa kembali." >&2
    exit 1
fi

# === TAMBAHKAN IP KE NETPLAN YAML ===
echo "[+] Menyisipkan IP tambahan ke $NETPLAN_FILE"

if [ ! -f "$NETPLAN_FILE" ]; then
    echo "[!] File $NETPLAN_FILE tidak ditemukan. Buat konfigurasi netplan terlebih dahulu." >&2
    exit 1
fi

# Backup terlebih dahulu
cp "$NETPLAN_FILE" "$NETPLAN_FILE.bak.$(date +%s)"

# Sisipkan IP ke bagian addresses:
sed_insert=""
for i in $(seq $START $END); do
    sed_insert+="            - $IP_PREFIX.$i/$NETMASK\n"
done

# Sisipkan setelah baris addresses:
awk -v insert="$sed_insert" '
/^[[:space:]]*addresses:/ {
    print $0
    print insert
    next
}
{ print }
' "$NETPLAN_FILE" > /tmp/netplan-temp.yaml && mv /tmp/netplan-temp.yaml "$NETPLAN_FILE"

# Terapkan konfigurasi
echo "[+] Menjalankan netplan apply"
netplan apply

# === INSTALL PAKET ===
echo "[+] Menginstall Squid dan Apache utils"
apt update
apt install squid apache2-utils -y

# === SETUP USER ===
echo "[+] Menambahkan user proxy $USERNAME"
if [ ! -f "$PASSWD_FILE" ]; then
    htpasswd -cb "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
else
    htpasswd -b "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
fi

# === BACKUP KONFIGURASI LAMA ===
echo "[+] Membackup konfigurasi Squid lama"
cp "$SQUID_CONF" "$SQUID_CONF.bak.$(date +%s)"

# === TULIS KONFIGURASI BARU ===
echo "[+] Menulis konfigurasi baru ke $SQUID_CONF"
cat > "$SQUID_CONF" <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSWD_FILE
auth_param basic realm Private Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
access_log none
cache_log /var/log/squid/cache.log
cache_store_log none
logfile_rotate 0
buffered_logs on
dns_v4_first on
EOF

for i in $(seq $START $END); do
    PORT=$((PORT_START + i - START))
    IP="$IP_PREFIX.$i"
    cat >> "$SQUID_CONF" <<EOF
http_port $PORT
acl to$i myport $PORT
tcp_outgoing_address $IP to$i

EOF
done

# === BUKA PORT DI UFW ===
if command -v ufw > /dev/null && ufw status | grep -q "Status: active"; then
    echo "[+] Membuka port di firewall (UFW)"
    for i in $(seq $START $END); do
        PORT=$((PORT_START + i - START))
        ufw allow "$PORT/tcp" comment "Allow Squid proxy port $PORT"
    done
fi

# === SIMPAN HASIL LOGIN ===
echo "[+] Menyimpan hasil konfigurasi ke $HASIL_FILE"
: > "$HASIL_FILE"
for i in $(seq $START $END); do
    PORT=$((PORT_START + i - START))
    IP="$IP_PREFIX.$i"
    echo "$USERNAME:$PASSWORD@$IP:$PORT" >> "$HASIL_FILE"
done

# === SET LIMIT FILE DESCRIPTOR ===
mkdir -p /etc/systemd/system/squid.service.d
cat > /etc/systemd/system/squid.service.d/override.conf <<EOF
[Service]
LimitNOFILE=65535
EOF

# === RESTART SQUID ===
echo "[+] Restarting Squid"
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart squid

# === STATUS ===
if systemctl is-active --quiet squid; then
    echo "✅ Squid berhasil dijalankan."
else
    echo "❌ Squid gagal dijalankan. Cek log: journalctl -xeu squid"
    exit 1
fi

echo "📄 File hasil login: $HASIL_FILE"
echo "✅ Selesai."
