#!/bin/bash
# === KONFIGURASI UMUM ===
INTERFACE="eth0"
PORT_START=3128
USERNAME="vodkaace"
PASSWORD="indonesia"
PASSWD_FILE="/etc/squid/passwd"
SQUID_CONF="/etc/squid/squid.conf"
HASIL_FILE="hasil.txt"

# === KONFIGURASI PREFIX MULTI ===
PREFIXES=("	5.230.29" "	5.175.131" "5.231.251")
STARTS=(2 112 2)
ENDS=(62 126 13)
EXCLUDES=("58" "127" "14")
NETMASKS=(26 25 25)                   #sesuaikan /prefix nya

# === FUNGSI CEK EXCLUDE ===
is_excluded() {
    local num=$1
    shift
    local arr=("$@")
    for ex in "${arr[@]}"; do
        if [[ "$num" -eq "$ex" ]]; then
            return 0
        fi
    done
    return 1
}

# === CEK INTERFACE ===
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "[!] Interface $INTERFACE tidak ditemukan." >&2
    exit 1
fi

# === TAMBAHKAN IP KE INTERFACE ===
echo "[+] Menambahkan IP ke interface $INTERFACE"
for idx in "${!PREFIXES[@]}"; do
    PREFIX="${PREFIXES[$idx]}"
    START="${STARTS[$idx]}"
    END="${ENDS[$idx]}"
    IFS=' ' read -r -a EXCLUDE <<< "${EXCLUDES[$idx]}"
    NETMASK="${NETMASKS[$idx]}"

    for i in $(seq $START $END); do
        if is_excluded "$i" "${EXCLUDE[@]}"; then
            echo "[!] Melewati IP $PREFIX.$i (dikecualikan)"
            continue
        fi
        IP="$PREFIX.$i"
        if ! ip addr show dev $INTERFACE | grep -q "$IP"; then
            sudo ip addr add "$IP/$NETMASK" dev $INTERFACE
        fi
    done
done

# === INSTALL PAKET ===
echo "[+] Menginstall Squid dan Apache utils"
sudo apt update
sudo apt install squid apache2-utils -y

# === SETUP AUTH USER ===
echo "[+] Menambahkan user proxy $USERNAME"
if [ ! -f "$PASSWD_FILE" ]; then
    sudo htpasswd -cb "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
else
    sudo htpasswd -b "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
fi

# === BACKUP KONFIGURASI LAMA ===
echo "[+] Membackup konfigurasi Squid lama"
sudo cp "$SQUID_CONF" "$SQUID_CONF.bak.$(date +%s)"

# === BUAT KONFIGURASI SQUID BARU ===
echo "[+] Menulis konfigurasi baru ke $SQUID_CONF"
sudo tee "$SQUID_CONF" > /dev/null <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSWD_FILE
auth_param basic realm Private Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log
cache_store_log none
logfile_rotate 0
buffered_logs on
dns_v4_first on

EOF

PORT_OFFSET=0
for idx in "${!PREFIXES[@]}"; do
    PREFIX="${PREFIXES[$idx]}"
    START="${STARTS[$idx]}"
    END="${ENDS[$idx]}"
    IFS=' ' read -r -a EXCLUDE <<< "${EXCLUDES[$idx]}"

    for i in $(seq $START $END); do
        if is_excluded "$i" "${EXCLUDE[@]}"; then
            echo "[!] Melewati konfigurasi untuk IP $PREFIX.$i"
            continue
        fi

        PORT=$((PORT_START + PORT_OFFSET))
        IP="$PREFIX.$i"

        echo "http_port $PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
        echo "acl to$PORT myport $PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
        echo "tcp_outgoing_address $IP to$PORT" | sudo tee -a "$SQUID_CONF" > /dev/null
        echo "" | sudo tee -a "$SQUID_CONF" > /dev/null

        PORT_OFFSET=$((PORT_OFFSET + 1))
    done
done

# === BUKA FIREWALL JIKA PERLU ===
if command -v ufw > /dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "[+] Membuka port di firewall (UFW)"
    for ((p=PORT_START; p<PORT_START+PORT_OFFSET; p++)); do
        sudo ufw allow "$p/tcp" comment "Allow Squid proxy port $p"
    done
fi

# === SIMPAN KE FILE HASIL ===
echo "[+] Menyimpan hasil konfigurasi ke $HASIL_FILE"
: > "$HASIL_FILE"

PORT_OFFSET=0
for idx in "${!PREFIXES[@]}"; do
    PREFIX="${PREFIXES[$idx]}"
    START="${STARTS[$idx]}"
    END="${ENDS[$idx]}"
    IFS=' ' read -r -a EXCLUDE <<< "${EXCLUDES[$idx]}"

    for i in $(seq $START $END); do
        if is_excluded "$i" "${EXCLUDE[@]}"; then
            continue
        fi

        PORT=$((PORT_START + PORT_OFFSET))
        IP="$PREFIX.$i"
        echo "$USERNAME:$PASSWORD:$IP:$PORT" >> "$HASIL_FILE"
        PORT_OFFSET=$((PORT_OFFSET + 1))
    done
done

# === SETUP LIMIT SYSTEMD ===
sudo mkdir -p /etc/systemd/system/squid.service.d
cat <<EOF | sudo tee /etc/systemd/system/squid.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF

# === RESTART SQUID DENGAN ANIMASI ===
echo "[+] Restarting Squid"
echo -n "Loading"
loading_animation() {
    local pid=$1
    local delay=0.1
    local spin='|/-\'
    while ps -p $pid > /dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\rLoading ${spin:$i:1}"
            sleep $delay
        done
    done
    echo -ne "\r[+] Restart Squid Done     \n"
}

(
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart squid
) &
loading_animation $!

echo "Cek limit file descriptor Squid:"
cat /proc/$(pidof squid)/limits | grep "Max open files"
echo "✅ Setup selesai! Proxy siap digunakan."
echo "📄 Hasil disimpan di: $HASIL_FILE"
