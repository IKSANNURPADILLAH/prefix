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

# 3. Install Squid dan Apache Utils (untuk htpasswd)
echo "Menginstall Squid dan Apache2-utils..."
apt update && apt install -y squid apache2-utils

# 4. Atur batas file descriptor untuk sistem
echo "Meningkatkan batas file descriptor..."

echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# Atur kernel parameters untuk mendukung koneksi banyak
echo "Mengatur parameter kernel untuk koneksi tinggi..."

cat >> /etc/sysctl.conf <<EOF
fs.file-max = 100000
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
EOF

# Terapkan pengaturan sysctl
sysctl -p

# 5. Membuat file password untuk Squid
echo "Membuat user proxy vodkaace..."
htpasswd -b -c /etc/squid/passwd vodkaace indonesia

# 6. Konfigurasi Squid untuk menangani banyak koneksi
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

# Meningkatkan jumlah file descriptor yang dapat dibuka oleh Squid
max_filedescriptors 65535

# Alokasi memori untuk cache
cache_mem 256 MB

# Menangani banyak koneksi
maximum_object_size_in_memory 8 KB
cache_dir ufs /var/spool/squid 1000 16 256

# Mengatur jumlah koneksi per peer
tcp_outgoing_address 89.144.7.1

# Menyesuaikan waktu timeout
connect_timeout 30 seconds
request_timeout 30 seconds
read_timeout 30 seconds
EOF

# 7. Restart Squid dan aktifkan agar berjalan otomatis saat boot
echo "Restarting Squid..."
systemctl restart squid
systemctl enable squid

# 8. Menampilkan informasi selesai
echo "Selesai! Proxy Anda berjalan di port 3128 dengan IP 89.144.7.1 - 89.144.7.254."
echo "Proses instalasi dan konfigurasi telah selesai."
