#!/bin/bash
set -euo pipefail

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.0.0.0/24}"
WG_SERVER_IP="${WG_SERVER_IP:-10.0.0.1}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

apt-get update -qq
apt-get install -y -qq wireguard qrencode iptables-persistent

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

cd "$WG_DIR"
wg genkey | tee server_private_key | wg pubkey > server_public_key

SERVER_PRIVATE_KEY=$(cat server_private_key)
OUTBOUND_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')

cat > "$WG_DIR/$WG_INTERFACE.conf" <<EOF
[Interface]
Address = ${WG_SERVER_IP}/24
SaveConfig = true
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${OUTBOUND_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${OUTBOUND_IFACE} -j MASQUERADE
EOF

chmod 600 "$WG_DIR/$WG_INTERFACE.conf"
rm -f server_private_key

wg-quick up "$WG_INTERFACE"
systemctl enable "wg-quick@$WG_INTERFACE"

echo "WireGuard server is up"
echo "Server public key: $(cat $WG_DIR/server_public_key)"
echo "Server IP: $(curl -s ifconfig.me)"
echo "Port: $WG_PORT"
