#!/bin/bash
set -euo pipefail

ZONE="${1:-ru-central1-b}"
SUBNET="${2:-e2lhlfhm6pn8gbab98uv}"
IMAGE="fd83vkt13re8v8cdapql"
CLOUD_INIT="$(dirname "$0")/../terraform/cloud-init.yaml"
VM_NAME="wireguard-gateway-new"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-20}"

ATTEMPT=0
while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  ATTEMPT=$((ATTEMPT+1))
  echo "=== Попытка $ATTEMPT/$MAX_ATTEMPTS ==="

  OP_ID=$(yc compute instance create \
    --name "$VM_NAME" \
    --zone "$ZONE" \
    --platform standard-v2 \
    --cores 2 \
    --memory 1 \
    --core-fraction 5 \
    --create-boot-disk "image-id=$IMAGE,size=10" \
    --network-interface "subnet-id=$SUBNET,nat-ip-version=ipv4" \
    --metadata-from-file "user-data=$CLOUD_INIT" \
    --async --format json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

  echo "Operation: $OP_ID"
  yc operation wait "$OP_ID"

  IP=$(yc compute instance get "$VM_NAME" --format json | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['network_interfaces'][0]['primary_v4_address']['one_to_one_nat']['address'])")

  echo "Получили IP: $IP"

  FIRST=$(echo "$IP" | cut -d. -f1)
  SECOND=$(echo "$IP" | cut -d. -f2)

  if [[ "$FIRST" == "158" && "$SECOND" == "160" ]]; then
    echo "✅ УСПЕХ! IP $IP входит в диапазон 158.160.x.x"
    echo ""
    echo "Установить WireGuard:"
    echo "  ssh wgadmin@$IP \"sudo bash -s\" < scripts/setup.sh"
    exit 0
  else
    echo "❌ Плохой IP ($IP), удаляем..."
    DEL_OP=$(yc compute instance delete "$VM_NAME" --async --format json | \
      python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    yc operation wait "$DEL_OP"
    echo "VM удалена, следующая попытка..."
  fi
done

echo "❌ Не удалось получить 158.160.x.x за $MAX_ATTEMPTS попыток"
exit 1
