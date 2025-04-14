#!/bin/bash

# === KONFIGURASI SAMA DENGAN SETUP ===
INTERFACE="eth0"
IP_PREFIX="5.231.234"
START=0
END=255
EXCLUDE=(300 990)  # Sama seperti sebelumnya
SQUID_CONF="/etc/squid/squid.conf"
PASSWD_FILE="/etc/squid/passwd"
PORT_START=3128

# === FUNGSI CEK EXCLUDE ===
is_excluded() {
    local num=$1
    for ex in "${EXCLUDE[@]}"; do
        if [[ "$num" -eq "$ex" ]]; then
            return 0
        fi
    done
    return 1
}

# === HAPUS IP ALIAS ===
echo "[~] Menghapus IP alias dari interface $INTERFACE"
for i in $(seq $START $END); do
    if is_excluded "$i"; then
        echo "[!] Lewatkan IP $IP_PREFIX.$i (excluded)"
        continue
    fi
    IP="$IP_PREFIX.$i"
    if ip addr show dev "$INTERFACE" | grep -q "$IP"; then
        sudo ip addr del "$IP/24" dev "$INTERFACE"
        echo "[-] IP $IP dihapus dari $INTERFACE"
    fi
done

# === KEMBALIKAN KONFIGURASI SQUID JIKA ADA BACKUP ===
BACKUP=$(ls -t "$SQUID_CONF.bak."* 2>/dev/null | head -n 1)
if [[ -f "$BACKUP" ]]; then
    echo "[~] Mengembalikan konfigurasi squid dari backup: $BACKUP"
    sudo cp "$BACKUP" "$SQUID_CONF"
else
    echo "[!] Tidak ditemukan backup konfigurasi Squid."
fi

# === HAPUS USER AUTH FILE ===
if [[ -f "$PASSWD_FILE" ]]; then
    echo "[~] Menghapus file user autentikasi: $PASSWD_FILE"
    sudo rm -f "$PASSWD_FILE"
fi

# === HAPUS FILE HASIL KONFIGURASI ===
if [[ -f "hasil.txt" ]]; then
    echo "[~] Menghapus file hasil.txt"
    rm -f hasil.txt
fi

# === HAPUS FIREWALL RULES (UFW) ===
if command -v ufw > /dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "[~] Menghapus rule UFW untuk port Squid"
    for i in $(seq $START $END); do
        if is_excluded "$i"; then
            continue
        fi
        PORT=$((PORT_START + i - START))
        sudo ufw delete allow "$PORT/tcp"
    done
fi

# === HAPUS OVERRIDE SYSTEMD (OPTIONAL) ===
if [[ -f /etc/systemd/system/squid.service.d/override.conf ]]; then
    echo "[~] Menghapus override systemd untuk Squid"
    sudo rm -f /etc/systemd/system/squid.service.d/override.conf
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
fi

# === RESTART SQUID ===
echo "[~] Merestart Squid..."
sudo systemctl restart squid
echo "[✅] Cleanup selesai."
