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
            - 5.230.159.9/24
            routes:
              - to: 0.0.0.0/0
                via: 5.230.159.1
                on-link: true
            nameservers:
                addresses:
                - 8.8.8.8
                search:
                - ghostnet.de
EOF

# IP alias
echo "Menambahkan IP alias ke $NETPLAN_ALIAS..."
cat > $NETPLAN_ALIAS <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
EOF

# IP dari subnet 5.230.102.0/27
for i in {70..85}; do
  echo "      - 5.230.102.$i/27" >> $NETPLAN_ALIAS
done

# IP dari subnet 94.249.211.0/24
for i in {39..71}; do
  echo "      - 94.249.211.$i/24" >> $NETPLAN_ALIAS
done

# IP dari subnet 94.249.210.0/24
for i in {104..112}; do
  echo "      - 94.249.210.$i/24" >> $NETPLAN_ALIAS
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

# Konfigurasi untuk 5.230.102.x
for i in {70..85}; do
  echo "http_port 5.230.102.$i:3128" >> $SQUID_CONF
  echo "acl ip102_$i myip 5.230.102.$i" >> $SQUID_CONF
  echo "tcp_outgoing_address 5.230.102.$i ip102_$i" >> $SQUID_CONF
done

# Konfigurasi untuk 94.249.211.x
for i in {39..71}; do
  echo "http_port 94.249.211.$i:3128" >> $SQUID_CONF
  echo "acl ip211_$i myip 94.249.211.$i" >> $SQUID_CONF
  echo "tcp_outgoing_address 94.249.211.$i ip211_$i" >> $SQUID_CONF
done

# Konfigurasi untuk 94.249.210.x
for i in {104..112}; do
  echo "http_port 94.249.210.$i:3128" >> $SQUID_CONF
  echo "acl ip210_$i myip 94.249.210.$i" >> $SQUID_CONF
  echo "tcp_outgoing_address 94.249.210.$i ip210_$i" >> $SQUID_CONF
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
for i in {70..85}; do
  echo "http://$USER:$PASS@5.230.102.$i:3128" >> $PROXY_TXT
done
for i in {39..71}; do
  echo "http://$USER:$PASS@94.249.211.$i:3128" >> $PROXY_TXT
done
for i in {104..112}; do
  echo "http://$USER:$PASS@94.249.210.$i:3128" >> $PROXY_TXT
done

# ========= RESTART SQUID =========

echo "Merestart layanan Squid..."
systemctl restart squid
systemctl enable squid

echo "✅ Setup selesai! Proxy tersimpan di $PROXY_TXT."
