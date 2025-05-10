#!/bin/bash

# Jalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Harus dijalankan sebagai root."
  exit 1
fi

echo "📦 Membuat skrip checker Squid..."

cat > /usr/local/bin/squid-checker.sh <<'EOF'
#!/bin/bash
if ! pgrep -x squid >/dev/null; then
    systemctl restart squid
fi
EOF

chmod +x /usr/local/bin/squid-checker.sh

echo "🛠️ Membuat service systemd..."

cat > /etc/systemd/system/squid-checker.service <<EOF
[Unit]
Description=Squid Auto Checker

[Service]
Type=oneshot
ExecStart=/usr/local/bin/squid-checker.sh
EOF

echo "⏱️ Membuat timer systemd..."

cat > /etc/systemd/system/squid-checker.timer <<EOF
[Unit]
Description=Jalankan squid-checker.sh setiap 5 menit

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=squid-checker.service

[Install]
WantedBy=timers.target
EOF

echo "🚀 Mengaktifkan timer..."

systemctl daemon-reload
systemctl enable --now squid-checker.timer

echo "✅ Selesai! Squid checker aktif otomatis setiap 5 menit."
