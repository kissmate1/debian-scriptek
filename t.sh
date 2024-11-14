#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (alapértelmezett szín visszaállítása)

# Frissítsük a csomaglistát
echo -e "${GREEN}Csomaglista frissítése...${NC}"
apt-get update -y > /dev/null 2>&1 && echo -e "${GREEN}Csomaglista sikeresen frissítve.${NC}" || { echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"; exit 1; }

# Telepítsük a szükséges csomagokat
echo -e "${GREEN}Szükséges csomagok telepítése...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm nfs-common nfs-kernel-server samba samba-common-bin > /dev/null 2>&1 && echo -e "${GREEN}Csomagok sikeresen telepítve.${NC}" || { echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"; exit 1; }

# Node-RED telepítése
echo -e "${GREEN}Node-RED telepítése...${NC}"
npm install -g node-red@latest > /dev/null 2>&1 && echo -e "${GREEN}Node-RED sikeresen telepítve.${NC}" || { echo -e "${RED}Hiba a Node-RED telepítésekor!${NC}"; exit 1; }

# Node-RED rendszerindító fájl létrehozása
echo -e "${GREEN}Node-RED rendszerindító fájl létrehozása...${NC}"
cat <<EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED graphical event wiring tool
Wants=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/.node-red
ExecStart=/usr/bin/env node-red start --max-old-space-size=256
Restart=always
Environment="NODE_OPTIONS=--max-old-space-size=256"
Nice=10
EnvironmentFile=-/etc/nodered/.env
SyslogIdentifier=Node-RED
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Node-RED indítása
echo -e "${GREEN}Node-RED indítása...${NC}"
systemctl daemon-reload > /dev/null 2>&1 && systemctl enable nodered.service > /dev/null 2>&1 && systemctl start nodered.service > /dev/null 2>&1 && echo -e "${GREEN}Node-RED sikeresen elindítva.${NC}" || { echo -e "${RED}Hiba a Node-RED indításakor!${NC}"; exit 1; }

# NFS fájlmegosztás beállítása IP-cím megadása nélkül
echo -e "${GREEN}NFS fájlmegosztás beállítása...${NC}"
mkdir -p /mnt/nfs_share > /dev/null 2>&1
echo "/mnt/nfs_share *(rw,sync,no_subtree_check)" >> /etc/exports > /dev/null 2>&1  # IP-cím nélkül
exportfs -a > /dev/null 2>&1 && systemctl restart nfs-kernel-server > /dev/null 2>&1 && echo -e "${GREEN}NFS fájlmegosztás sikeresen beállítva.${NC}" || { echo -e "${RED}Hiba az NFS fájlmegosztás beállításakor!${NC}"; exit 1; }

# Samba fájlmegosztás beállítása IP-cím megadása nélkül
echo -e "${GREEN}Samba fájlmegosztás beállítása...${NC}"
mkdir -p /srv/samba/share > /dev/null 2>&1
cat <<EOF >> /etc/samba/smb.conf
[share]
   path = /srv/samba/share
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   force group = nogroup
EOF
systemctl restart smbd > /dev/null 2>&1 && systemctl enable smbd > /dev/null 2>&1 && echo -e "${GREEN}Samba fájlmegosztás sikeresen beállítva.${NC}" || { echo -e "${RED}Hiba a Samba fájlmegosztás beállításakor!${NC}"; exit 1; }

# Összegzés
echo -e "${GREEN}A telepítés sikeresen befejeződött.${NC}"

# Háttérben futtatjuk az auto_backup.sh scriptet
echo -e "${GREEN}Indítjuk az auto_backup.sh scriptet nohup használatával...${NC}"
nohup /path/to/auto_backup.sh > /dev/null 2>&1 &

echo -e "${GREEN}A rendszer állapotának automatikus mentése mostantól háttérben fut.${NC}"
