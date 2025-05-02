#!/bin/bash

# Update dan install Squid
apt update && apt install -y squid apache2-utils

# Backup konfigurasi default
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Buat file konfigurasi baru
cat <<EOF > /etc/squid/squid.conf
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Squid Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

http_port 3129
via off
forwarded_for off
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Connection allow all
request_header_access Proxy-Connection allow all
request_header_access User-Agent allow all
request_header_access Cookie allow all
request_header_access All deny all

access_log /var/log/squid/access.log
EOF

# Tambahkan user proxy (ganti `username` dan `password`)
USERNAME="vodkaace"
PASSWORD="indonesia"
htpasswd -b -c /etc/squid/passwd $USERNAME $PASSWORD

# Restart Squid
systemctl restart squid
systemctl enable squid

echo "✅ Squid proxy berhasil diinstal dan berjalan di port 3129."
