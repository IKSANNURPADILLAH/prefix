#!/bin/bash

# === Konfigurasi dasar ===
USER="vodkaace"
PASS="indonesia"
SQUID_CONF="/etc/squid/squid.conf"
PASS_FILE="/etc/squid/passwd"
START_PORT=3001
LOG_FILE="hasil.txt"

# === List IP Anda ===
IPS=(
  "5.230.77.51"
  "5.230.77.48"
  "5.230.75.235"
  "5.230.75.202"
  "5.230.74.86"
  "5.230.74.82"
  "5.230.71.181"
  "5.230.71.155"
  "5.230.69.11"
  "5.230.66.26"
  "5.230.57.126"
  "5.230.77.52"
)

# === Mulai Logging ke hasil.txt ===
exec > >(tee -i $LOG_FILE)
exec 2>&1

echo "=============================="
echo "🚀 PROSES INSTALASI SQUID PROXY MULTI-IP"
echo "Waktu: $(date)"
echo "=============================="

# === Update dan install dependensi ===
apt update && apt install -y squid apache2-utils ufw

# === Setup user autentikasi ===
echo "🔐 Membuat user proxy: $USER"
htpasswd -cb $PASS_FILE $USER $PASS

# === Backup konfigurasi lama ===
cp $SQUID_CONF ${SQUID_CONF}.bak

# === Tulis konfigurasi baru ===
echo "# Auto-generated Squid Config" > $SQUID_CONF
echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASS_FILE" >> $SQUID_CONF
echo "auth_param basic realm Proxy" >> $SQUID_CONF
echo "acl authenticated proxy_auth REQUIRED" >> $SQUID_CONF
echo "http_access allow authenticated" >> $SQUID_CONF
echo "acl localnet src 0.0.0.0/0" >> $SQUID_CONF
echo "http_access allow localnet" >> $SQUID_CONF
echo "http_access deny all" >> $SQUID_CONF
echo "access_log /var/log/squid/access.log" >> $SQUID_CONF
echo "" >> $SQUID_CONF

# === Loop untuk membuat port dan mapping IP ===
PORT=$START_PORT
echo "📦 Daftar Proxy Siap Pakai (format: http://$USER:$PASS@IP:PORT):" >> $LOG_FILE
for IP in "${IPS[@]}"; do
    for i in {1..2}; do
        echo "http_port $PORT" >> $SQUID_CONF
        echo "acl port$PORT myportname $PORT" >> $SQUID_CONF
        echo "tcp_outgoing_address $IP port$PORT" >> $SQUID_CONF
        echo "" >> $SQUID_CONF
        echo "http://$USER:$PASS@$IP:$PORT" >> $LOG_FILE
        ((PORT++))
    done
done

# === Tambahkan systemd override untuk LimitNOFILE ===
echo "📦 Menambahkan LimitNOFILE=65535 ke konfigurasi systemd..."
mkdir -p /etc/systemd/system/squid.service.d
cat <<EOF > /etc/systemd/system/squid.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF

# === Reload systemd, restart squid ===
echo "🔁 Restart dan enable layanan Squid..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart squid
systemctl enable squid

# === Buka port di firewall ===
echo "🔓 Membuka firewall dari port $START_PORT sampai $((PORT-1))..."
ufw allow $START_PORT:$((PORT-1))/tcp

# === Info akhir ===
echo ""
echo "✅ INSTALASI DAN KONFIGURASI SELESAI"
echo "Total proxy dibuat: $((PORT - START_PORT))"
echo "Username: $USER"
echo "Password: $PASS"
echo "File log hasil lengkap: $(realpath $LOG_FILE)"
echo "Silakan uji dengan CURL atau software proxy client."
