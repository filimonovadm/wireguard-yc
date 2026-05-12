# WireGuard VPN on Yandex Cloud

WireGuard server on a Yandex Cloud VM with client management scripts.

## Requirements

- [Terraform](https://terraform.io) >= 1.0
- Yandex Cloud account with IAM token
- SSH key pair

## Setup

### 1. Create VM with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — fill in `yc_token`:

```bash
yc iam create-token
```

Then apply:

```bash
terraform init
terraform apply
```

Terraform outputs the VM's external IP.

### 2. Install WireGuard on VM

```bash
ssh wgadmin@<external-ip> "sudo bash -s" < scripts/setup.sh
```

### 3. Add a client

```bash
ssh wgadmin@<external-ip> "sudo bash -s" < scripts/add-client.sh iphone
```

Prints a QR code — scan it with the WireGuard app on iOS/Android.

### 4. Remove a client

```bash
ssh wgadmin@<external-ip> "sudo bash -s -- client-name" < scripts/remove-client.sh
```

## Notes

- VM zone: `ru-central1-a` — required for IP forwarding to work in YC
- WireGuard port: `51820` UDP
- VPN subnet: `10.0.0.0/24`, server at `10.0.0.1`
- IAM token expires in 12h — regenerate with `yc iam create-token` before each `terraform apply`
- Client configs stored at `/etc/wireguard/clients/` on the server
