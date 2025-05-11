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
            - 5.230.232.136/24
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

# IP alias (94.249.215.2 - 254)
echo "Menambahkan IP alias ke $NETPLAN_ALIAS..."
cat > $NETPLAN_ALIAS <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
EOF

for i in {2..254}; do
  echo "      - 94.249.215.$i/24" >> $NETPLAN_ALIAS
done

chmod 600 $NETPLAN_ALIAS
netplan apply

# ========= INSTALLASI =========

echo "Menginstall Squid dan Apache2-utils..."
apt update && apt install -y squid apache2-utils

# ========= HAPUS LOG DAN CACHE =========

echo "Menghapus log dan cache Squid..."
rm -rf /var/log/squid/*
rm -rf /var/spool/squid/*
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid

# ========= USER AUTENTIKASI =========

echo "Membuat user proxy..."
htpasswd -b -c /etc/squid/passwd $USER $PASS

# ========= KONFIGURASI SQUID =========

echo "Membuat konfigurasi Squid minimal..."
cat > $SQUID_CONF <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
EOF

# Port dan IP keluar
for i in {2..254}; do
  echo "http_port 94.249.215.$i:3128" >> $SQUID_CONF
done

for i in {2..254}; do
  echo "acl ip$i myip 94.249.215.$i" >> $SQUID_CONF
  echo "tcp_outgoing_address 94.249.215.$i ip$i" >> $SQUID_CONF
done

# Tambahan konfigurasi ringan
cat >> $SQUID_CONF <<EOF

http_access deny all
via off
forwarded_for delete

cache deny all
access_log none
cache_log /dev/null
cache_store_log none
EOF

# ========= SIMPAN FILE PROXY =========

echo "Menyimpan daftar proxy ke $PROXY_TXT..."
> $PROXY_TXT
for i in {2..254}; do
  echo "http://$USER:$PASS@94.249.215.$i:3128" >> $PROXY_TXT
done

# ========= RESTART SQUID =========

echo "Merestart layanan Squid..."
systemctl restart squid
systemctl enable squid

echo "✅ Setup selesai! Proxy ringan tersimpan di $PROXY_TXT."
