#!/bin/bash
# ================================
# AUTOPROXY SETUP SCRIPT
# Membuat squid proxy multi-IP + autentikasi
# ================================

set -euo pipefail

# === CONFIGURASI ===
INTERFACE="eth0"
IP_PREFIX="94.249.211"
START=39
END=71
PORT_START=3128
USERNAME="vodkaace"
PASSWORD="indonesia"
PASSWD_FILE="/etc/squid/passwd"
SQUID_CONF="/etc/squid/squid.conf"
HASIL_FILE="hasil.txt"
NETMASKS="24"

# === CEK INTERFACE ===
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "[!] Interface $INTERFACE tidak ditemukan. Periksa kembali." >&2
    exit 1
fi

# === TAMBAHKAN IP KE INTERFACE ===
echo "[+] Menambahkan IP ke interface $INTERFACE"
for i in $(seq $START $END); do
    IP="$IP_PREFIX.$i"
    if ! ip addr show dev $INTERFACE | grep -q "$IP"; then
        sudo ip addr add "$IP/$NETMASKS" dev $INTERFACE
    fi
done

# === INSTALL PAKET YANG DIBUTUHKAN ===
echo "[+] Menginstall Squid dan Apache utils"
sudo apt update
sudo apt install squid apache2-utils -y

# === SETUP AUTH USER ===
echo "[+] Menambahkan user proxy $USERNAME"
if [ ! -f "$PASSWD_FILE" ]; then
    sudo htpasswd -cb "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
else
    sudo htpasswd -b "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
fi

# === BACKUP CONFIG LAMA ===
echo "[+] Membackup konfigurasi Squid lama"
sudo cp "$SQUID_CONF" "$SQUID_CONF.bak.$(date +%s)"

# === BUAT KONFIGURASI BARU ===
echo "[+] Menulis konfigurasi baru ke $SQUID_CONF"
sudo tee "$SQUID_CONF" > /dev/null <<EOF
# === AUTENTIKASI ===
auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSWD_FILE
auth_param basic realm Private Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

# === LOGGING ===
access_log none
cache_log /var/log/squid/cache.log
cache_store_log none
logfile_rotate 0
buffered_logs on
dns_v4_first on

# === PORT & IP KELUAR ===
EOF

for i in $(seq $START $END); do
    PORT=$((PORT_START + i - START))
    IP="$IP_PREFIX.$i"
    echo "http_port $PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
    echo "acl to$i myport $PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
    echo "tcp_outgoing_address $IP to$i" | sudo tee -a "$SQUID_CONF" > /dev/null
    echo "" | sudo tee -a "$SQUID_CONF" > /dev/null
done

# === UFW (FIREWALL) ===
if command -v ufw > /dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "[+] Membuka port di firewall (UFW)"
    for i in $(seq $START $END); do
        PORT=$((PORT_START + i - START))
        sudo ufw allow "$PORT/tcp" comment "Allow Squid proxy port $PORT"
    done
fi

# === SIMPAN HASIL ===
echo "[+] Menyimpan hasil konfigurasi ke $HASIL_FILE"
: > "$HASIL_FILE"
for i in $(seq $START $END); do
    PORT=$((PORT_START + i - START))
    IP="$IP_PREFIX.$i"
    echo "$USERNAME:$PASSWORD@$IP:$PORT" >> "$HASIL_FILE"
done

# === SETUP LIMIT FILE DESCRIPTOR ===
sudo mkdir -p /etc/systemd/system/squid.service.d
cat <<EOF | sudo tee /etc/systemd/system/squid.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF

# === RESTART SQUID ===
echo "[+] Restarting Squid"
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart squid

# === CEK STATUS ===
if systemctl is-active --quiet squid; then
    echo "✅ Squid berhasil dijalankan."
else
    echo "❌ Squid gagal dijalankan. Periksa log dengan: journalctl -xeu squid"
    exit 1
fi

# === TAMPILKAN LIMIT ===
echo "Cek limit file descriptor Squid:"
cat /proc/$(pidof squid)/limits | grep "Max open files"

echo "✅ Setup selesai! Proxy siap digunakan."
echo "📄 Hasil disimpan di: $HASIL_FILE"
