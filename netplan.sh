#!/bin/bash

# Jalankan hanya sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root."
  exit
fi

# 1. Backup dan edit netplan config
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

echo "Mengupdate file Netplan..."

cat > $NETPLAN_FILE <<EOF
network:
    version: 2
    ethernets:
        eth0:
            addresses:
            - 5.230.232.129/24
            routes:
              - to: 0.0.0.0/0
                via: 5.230.232.1
                on-link: true
            nameservers:
                addresses:
                - 8.8.8.8
                search:
                - ghostnet.de
EOF

# 2. Menambahkan IP alias ke dalam konfigurasi Netplan
echo "Menambahkan IP alias ke /etc/netplan/89-ips.yaml..."

cat > /etc/netplan/89-ips.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
EOF

for i in {1..254}; do
  echo "      - 89.144.7.$i/24" >> /etc/netplan/89-ips.yaml
done

# Set permissions agar tidak terlalu terbuka
chmod 600 /etc/netplan/89-ips.yaml

# Terapkan Netplan
echo "Terapkan Netplan..."
netplan apply

# 3. Install Squid
echo "Menginstall Squid..."
apt update && apt install -y squid apache2-utils

# 4. Buat file password untuk Squid
echo "Membuat user proxy vodkaace..."
htpasswd -b -c /etc/squid/passwd vodkaace indonesia

# 5. Konfigurasi Squid
echo "Mengkonfigurasi Squid..."

SQUID_CONF="/etc/squid/squid.conf"
cat > $SQUID_CONF <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

http_port 3128

# Akses penuh dari mana saja
acl localnet src 0.0.0.0/0
http_access allow localnet
http_access deny all

# Tampilkan IP publik yang digunakan
via off
forwarded_for delete
EOF

# 6. Restart Squid
echo "Restarting Squid..."
systemctl restart squid
systemctl enable squid

echo "Selesai! Proxy Anda berjalan di port 3128 dengan IP 89.144.7.1 - 89.144.7.254."
