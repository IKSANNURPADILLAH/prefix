#!/bin/bash

# Jalankan hanya sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root."
  exit
fi

# ========== KONFIGURASI IP ==========

NETPLAN_MAIN="/etc/netplan/50-cloud-init.yaml"
NETPLAN_ALIAS="/etc/netplan/89-ips.yaml"

echo "Mengupdate konfigurasi Netplan..."

# IP utama
cat > $NETPLAN_MAIN <<EOF
network:
    version: 2
    ethernets:
        eth0:
            addresses:
            - 5.230.197.127/24
            routes:
              - to: 0.0.0.0/0
                via: 5.230.197.1
                on-link: true
            nameservers:
                addresses:
                - 8.8.8.8
                search:
                - ghostnet.de
EOF

# IP alias (94.249.191.2 - 94.249.191.254)
echo "Menambahkan IP alias ke $NETPLAN_ALIAS..."

cat > $NETPLAN_ALIAS <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
EOF

for i in {2..254}; do
  echo "      - 94.249.191.$i/24" >> $NETPLAN_ALIAS
done

chmod 600 $NETPLAN_ALIAS
netplan apply

# ========== INSTALLASI SQUID & TOOLS ==========

echo "Menginstall Squid dan Apache2-utils..."
apt update && apt install -y squid apache2-utils

# ========== OPTIMASI SISTEM ==========

echo "Meningkatkan batas file descriptor dan parameter kernel..."
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

cat >> /etc/sysctl.conf <<EOF
fs.file-max = 100000
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
EOF

sysctl -p

# ========== USER AUTH ==========

echo "Membuat user proxy vodkaace..."
htpasswd -b -c /etc/squid/passwd vodkaace indonesia

# ========== KONFIGURASI SQUID ==========

echo "Mengkonfigurasi Squid..."
SQUID_CONF="/etc/squid/squid.conf"
cat > $SQUID_CONF <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

# Listener dan mapping outgoing IP
EOF

# Tambahkan listener dan ACL untuk setiap IP
for i in {2..254}; do
  echo "http_port 94.249.191.$i:3128" >> $SQUID_CONF
done

for i in {2..254}; do
  echo "acl ip$i myip 94.249.191.$i" >> $SQUID_CONF
  echo "tcp_outgoing_address 94.249.191.$i ip$i" >> $SQUID_CONF
done

# Tambahan konfigurasi akhir
cat >> $SQUID_CONF <<EOF

http_access deny all
via off
forwarded_for delete

# Optimasi performa Squid
max_filedescriptors 65535
cache_mem 256 MB
maximum_object_size_in_memory 8 KB
cache_dir ufs /var/spool/squid 1000 16 256
connect_timeout 30 seconds
request_timeout 30 seconds
read_timeout 30 seconds
EOF

# ========== RESTART & ENABLE SQUID ==========

echo "Merestart Squid..."
systemctl restart squid
systemctl enable squid

echo "✅ Selesai! Proxy aktif di 94.249.191.2–254:3128 dengan IP keluar yang sama."
