#!/bin/bash
set -euo pipefail

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
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
PUB_KEY_FILE="$CLIENTS_DIR/$CLIENT_NAME.pub"

if [[ ! -f "$PUB_KEY_FILE" ]]; then
  echo "Client '$CLIENT_NAME' not found" >&2
  exit 1
fi

CLIENT_PUBLIC_KEY=$(cat "$PUB_KEY_FILE")
wg set "$WG_INTERFACE" peer "$CLIENT_PUBLIC_KEY" remove
wg-quick save "$WG_INTERFACE"

rm -f "$CLIENTS_DIR/$CLIENT_NAME.pub" "$CLIENTS_DIR/$CLIENT_NAME.conf"

echo "Client '$CLIENT_NAME' removed"
