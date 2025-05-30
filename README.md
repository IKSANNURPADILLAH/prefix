# Cara ganti interface ke netplan

```bash
sudo mv /etc/network/interfaces /etc/network/interfaces.bak
mkdir /etc/netplan
chmod 600 /etc/netplan
nano /etc/netplan/50-cloud-init.yaml
```
## Isi dengan settingan default, contohnya
```bash
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
```
## Paste komen ini
```bash
apt update
apt install -y netplan.io
sudo systemctl enable --now systemd-networkd
sudo systemctl disable --now networking
sudo systemctl disable --now NetworkManager
sudo netplan apply
```
## Silahkan reboot manual
