#!/bin/bash

# Update dan install squid + htpasswd
apt update && apt install -y squid apache2-utils

# Backup konfigurasi squid default
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Buat file konfigurasi squid.conf
cat <<EOF > /etc/squid/squid.conf
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Squid Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

http_port 3128
http_port 3129

access_log /var/log/squid/access.log

# Tingkatkan limit file descriptor
max_filedescriptors 65535
EOF

# Buat user untuk autentikasi
USERNAME="vodkaace"
PASSWORD="indonesia"
htpasswd -b -c /etc/squid/passwd $USERNAME $PASSWORD

# Buat systemd override untuk LimitNOFILE
mkdir -p /etc/systemd/system/squid.service.d
cat <<EOF > /etc/systemd/system/squid.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF

# Reload systemd dan restart squid
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart squid
systemctl enable squid

# Buka port 3128 di firewall
ufw allow 3128/tcp

echo "http://vodkaace:indonesia@$(curl -s ipinfo.io/ip):3128"
echo "http://vodkaace:indonesia@$(curl -s ipinfo.io/ip):3129"
