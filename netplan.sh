#!/bin/bash

# =============================
# Konfigurasi awal
# =============================
INTERFACE=$(ip route | grep default | awk '{print $5}')
SUBNET="89.144.7"
NETMASK="24"
USERNAME="vodkaace"
PASSWORD="indonesia"
SQUID_CONF="/etc/squid/squid.conf"
PASSWD_FILE="/etc/squid/passwd"
OUTPUT_FILE="/root/hasil.txt"
SQUID_OVERRIDE_DIR="/etc/systemd/system/squid.service.d"
LIMIT_NOFILE=65535

# =============================
# Update & install dependencies
# =============================
apt update && apt install -y squid apache2-utils net-tools

# =============================
# Update konfigurasi Netplan
# =============================
NETPLAN_FILE=$(find /etc/netplan -name "*.yaml" | head -n 1)
cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"

echo "Mengupdate Netplan..."
IPS=""
for i in $(seq 2 254); do
    IPS+="      - ${SUBNET}.${i}/32\n"
done

if ! grep -q "${SUBNET}" "$NETPLAN_FILE"; then
    sed -i "/addresses:/a\\${IPS}" "$NETPLAN_FILE"
fi

netplan apply
echo "Netplan diterapkan."

# =============================
# Setup file passwd untuk squid
# =============================
htpasswd -bc "$PASSWD_FILE" "$USERNAME" "$PASSWORD"

# =============================
# Konfigurasi squid multi-port
# =============================
cp "$SQUID_CONF" "${SQUID_CONF}.bak"

cat > "$SQUID_CONF" <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSWD_FILE
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
EOF

PORT=3128
> "$OUTPUT_FILE"
for i in $(seq 2 254); do
    echo "http_port ${SUBNET}.${i}:${PORT}" >> "$SQUID_CONF"
    echo "${SUBNET}.${i}:${PORT}@${USERNAME}:${PASSWORD}" >> "$OUTPUT_FILE"
    ((PORT++))
done

cat >> "$SQUID_CONF" <<EOF
via off
forwarded_for off
max_filedescriptors $LIMIT_NOFILE
cache_mem 64 MB
memory_replacement_policy lru
maximum_object_size_in_memory 64 KB
EOF

# =============================
# Tuning ulimit & systemd
# =============================
echo "Menyesuaikan limit koneksi..."

# Tambahkan limit untuk user squid
if ! grep -q "squid" /etc/security/limits.conf; then
    echo -e "squid soft nofile $LIMIT_NOFILE\nsquid hard nofile $LIMIT_NOFILE" >> /etc/security/limits.conf
fi

# Tambahkan override systemd
mkdir -p "$SQUID_OVERRIDE_DIR"
cat > "$SQUID_OVERRIDE_DIR/override.conf" <<EOF
[Service]
LimitNOFILE=$LIMIT_NOFILE
EOF

# Reload systemd dan restart squid
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable squid
systemctl restart squid

echo -e "\n✅ Proxy selesai di-setup dan siap menangani 200+ koneksi!"
echo "📄 Daftar proxy tersimpan di: $OUTPUT_FILE"
