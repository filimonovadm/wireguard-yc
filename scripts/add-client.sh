#!/bin/bash
set -euo pipefail

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="${WG_PORT:-51820}"
CLIENTS_DIR="$WG_DIR/clients"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <client_name>" >&2
  exit 1
fi

CLIENT_NAME="$1"
mkdir -p "$CLIENTS_DIR"

SERVER_PUBLIC_KEY=$(cat "$WG_DIR/server_public_key")
SERVER_IP=$(curl -s ifconfig.me)

LAST_IP_FILE="$WG_DIR/last-client-ip.txt"
if [[ ! -f "$LAST_IP_FILE" ]]; then
  echo "10.0.0.1" > "$LAST_IP_FILE"
fi

LAST_OCTET=$(cat "$LAST_IP_FILE" | awk -F. '{print $4}')
NEXT_OCTET=$((LAST_OCTET + 1))
CLIENT_IP="10.0.0.${NEXT_OCTET}"
echo "$CLIENT_IP" > "$LAST_IP_FILE"

wg genkey | tee "$CLIENTS_DIR/$CLIENT_NAME.key" | wg pubkey > "$CLIENTS_DIR/$CLIENT_NAME.pub"
CLIENT_PRIVATE_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME.key")
CLIENT_PUBLIC_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME.pub")

cat > "$CLIENTS_DIR/$CLIENT_NAME.conf" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 21
EOF

rm -f "$CLIENTS_DIR/$CLIENT_NAME.key"

wg set "$WG_INTERFACE" peer "$CLIENT_PUBLIC_KEY" allowed-ips "${CLIENT_IP}/32"
wg-quick save "$WG_INTERFACE"

echo "Client '$CLIENT_NAME' added: $CLIENT_IP"
echo ""
echo "Config saved to: $CLIENTS_DIR/$CLIENT_NAME.conf"
echo ""
echo "QR code:"
qrencode -t ansiutf8 < "$CLIENTS_DIR/$CLIENT_NAME.conf"
