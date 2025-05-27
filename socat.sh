#!/bin/bash

# ===== CONFIGURATION =====
LISTEN_PORT=443
POOL_HOST="us.cortex.herominers.com"
POOL_PORT=1155
SERVICE_NAME="socat-mining"

# ===== INSTALL SOCAT =====
echo "[+] Installing socat..."
sudo apt update -y
sudo apt install socat -y

# ===== CREATE SYSTEMD SERVICE =====
echo "[+] Creating systemd service..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Socat TCP Forwarding for Mining
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:${LISTEN_PORT},reuseaddr,fork TCP:${POOL_HOST}:${POOL_PORT}
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# ===== ENABLE & START SERVICE =====
echo "[+] Enabling and starting service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now ${SERVICE_NAME}

echo "[✓] Service '${SERVICE_NAME}' is now running and will auto-restart if it dies."
echo "Listening on port ${LISTEN_PORT} -> Forwarded to ${POOL_HOST}:${POOL_PORT}"
