#!/bin/bash

# Konfigurasi
WALLET="Q010500cbd87439cd2f5a27681c52e909b02411776ff60509bc2b9a73911eceaab816a8bb2c3f80"
WORKER="agus"
POOL="us.qrl.herominers.com:1166"
THREADS="3"
SCREEN_NAME="xmrig"

# Update dan install dependensi
apt update -y
apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev screen

# Clone dan build xmrig
cd ~
git clone https://github.com/xmrig/xmrig.git
cd xmrig
mkdir build && cd build
cmake ..
make -j$(nproc)

# Jalankan xmrig di dalam screen
screen -dmS $SCREEN_NAME ./xmrig -o $POOL -u ${WALLET}.${WORKER} -p x -a rx -t $THREADS
echo "XMRig is now running in a screen session named '$SCREEN_NAME'."
echo "To attach: screen -r $SCREEN_NAME"
