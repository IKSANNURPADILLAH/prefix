#!/bin/bash

# === CONFIGURABLE PART ===
INTERFACE="eth0"  # Ganti kalau bukan eth0

# Subnet 1 - via 5.230.29.1
SUBNET1_GATEWAY="5.230.29.1"
SUBNET1_NET="5.230.29.0/26"
SUBNET1_IPS=(
    5.230.29.23
)

# Subnet 2 - via 5.231.219.33
SUBNET2_GATEWAY="5.231.219.33"
SUBNET2_NET="5.231.219.32/27"
SUBNET2_IPS=(
    5.231.219.34
    5.231.219.35
    5.231.219.36	
    5.231.219.37
    5.231.219.38	
    5.231.219.39
    5.231.219.40
    5.231.219.41
    5.231.219.42
    5.231.219.43
    5.231.219.44
    5.231.219.45
    5.231.219.46
    5.231.219.47
    5.231.219.48
    5.231.219.49
    5.231.219.50
    5.231.219.51
    5.231.219.52
    5.231.219.53
    5.231.219.54
    5.231.219.55
    5.231.219.56
    5.231.219.57
    5.231.219.58
    5.231.219.59
    5.231.219.60
    5.231.219.61
    5.231.219.62
)

# Subnet 3 - via 178.18.145.65
SUBNET3_GATEWAY="178.18.145.65"
SUBNET3_NET="178.18.145.64/27"
SUBNET3_IPS=(
    178.18.145.66
    178.18.145.67
    178.18.145.68
    178.18.145.69
    178.18.145.70
    178.18.145.71
    178.18.145.72
    178.18.145.73
    178.18.145.74
    178.18.145.75
    178.18.145.76
    178.18.145.77
    178.18.145.78
    178.18.145.79
    178.18.145.80
    178.18.145.81
    178.18.145.82
    178.18.145.83
    178.18.145.84
    178.18.145.85
    178.18.145.86
    178.18.145.87
    178.18.145.88
    178.18.145.89
    178.18.145.90
    178.18.145.91
    178.18.145.92
    178.18.145.93
    178.18.145.94
)

# === SETUP START ===
echo "[+] Menambahkan semua IP ke interface $INTERFACE..."

for ip in "${SUBNET1_IPS[@]}"; do
    ip addr add "$ip/26" dev "$INTERFACE"
done

for ip in "${SUBNET2_IPS[@]}"; do
    ip addr add "$ip/27" dev "$INTERFACE"
done

for ip in "${SUBNET3_IPS[@]}"; do
    ip addr add "$ip/27" dev "$INTERFACE"
done

echo "[+] Menambahkan tabel routing balance ke /etc/iproute2/rt_tables..."
if ! grep -q "balance" /etc/iproute2/rt_tables; then
    echo "100 balance" >> /etc/iproute2/rt_tables
fi

echo "[+] Membuat routing table balance..."
ip route flush table balance
ip route add default scope global \
    nexthop via "$SUBNET1_GATEWAY" dev "$INTERFACE" weight 1 \
    nexthop via "$SUBNET2_GATEWAY" dev "$INTERFACE" weight 1 \
    nexthop via "$SUBNET3_GATEWAY" dev "$INTERFACE" weight 1 \
    table balance

echo "[+] Menambahkan ip rule untuk ketiga subnet..."

ip rule add from "$SUBNET1_NET" table balance
ip rule add from "$SUBNET2_NET" table balance
ip rule add from "$SUBNET3_NET" table balance

echo "[✓] Selesai!"
echo "    Gunakan perintah berikut untuk cek:"
echo "    - ip rule show"
echo "    - ip route show table balance"
echo "    - curl https://ifconfig.me (beberapa kali)"
