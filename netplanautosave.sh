#!/bin/bash

# Jalankan hanya sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root."
  exit
fi

# ========= KONFIGURASI DASAR =========

NETPLAN_MAIN="/etc/netplan/50-cloud-init.yaml"
NETPLAN_ALIAS="/etc/netplan/89-ips.yaml"
SQUID_CONF="/etc/squid/squid.conf"
PROXY_TXT="proxy.txt"
USER="vodkaace"
PASS="indonesia"

echo "Mengupdate konfigurasi Netplan..."

# IP utama
cat > $NETPLAN_MAIN <<EOF
network:
    version: 2
    ethernets:
        eth0:
            addresses:
            - 5.230.72.15/24
            routes:
              - to: 0.0.0.0/0
                via: 5.230.72.1
                on-link: true
            nameservers:
                addresses:
                - 8.8.8.8
                search:
                - ghostnet.de
EOF

# IP alias (94.249.191.2 - 254)
echo "Menambahkan IP alias ke $NETPLAN_ALIAS..."
cat > $NETPLAN_ALIAS <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
EOF

for i in {2..254}; do
  echo "      - 89.144.7.$i/24" >> $NETPLAN_ALIAS
done

chmod 600 $NETPLAN_ALIAS
netplan apply

# ========= INSTALLASI =========

echo "Menginstall Squid dan Apache2-utils..."
apt update && apt install -y squid apache2-utils

echo "Optimasi sistem untuk banyak koneksi..."
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

cat >> /etc/sysctl.conf <<EOF
fs.file-max = 100000
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
EOF

sysctl -p

# ========= USER AUTENTIKASI =========

echo "Membuat user proxy..."
htpasswd -b -c /etc/squid/passwd $USER $PASS

# ========= KONFIGURASI SQUID =========

echo "Membuat konfigurasi Squid..."
cat > $SQUID_CONF <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
EOF

# Listener & outgoing IP
for i in {2..254}; do
  echo "http_port 94.249.191.$i:3128" >> $SQUID_CONF
done

for i in {2..254}; do
  echo "acl ip$i myip 94.249.191.$i" >> $SQUID_CONF
  echo "tcp_outgoing_address 94.249.191.$i ip$i" >> $SQUID_CONF
done

# Tambahan akhir konfigurasi
cat >> $SQUID_CONF <<EOF

http_access deny all
via off
forwarded_for delete

# Optimasi performa
max_filedescriptors 65535
cache_mem 256 MB
maximum_object_size_in_memory 8 KB
cache_dir ufs /var/spool/squid 1000 16 256
connect_timeout 30 seconds
request_timeout 30 seconds
read_timeout 30 seconds
EOF

# ========= SIMPAN FILE PROXY =========

echo "Menyimpan daftar proxy ke $PROXY_TXT..."
> $PROXY_TXT
for i in {2..254}; do
  echo "http://$USER:$PASS@94.249.191.$i:3128" >> $PROXY_TXT
done

# ========= RESTART SQUID =========

echo "Merestart layanan Squid..."
systemctl restart squid
systemctl enable squid

echo "✅ Setup selesai! Proxy tersimpan di $PROXY_TXT."
