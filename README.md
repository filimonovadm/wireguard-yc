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

## Security hardening

After setup, run these steps on the server:

**1. Change SSH port**

```bash
sudo sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

Update your local `~/.ssh/config`:

```
Host wireguard
    HostName <external-ip>
    User wgadmin
    Port 2222
```

**2. Install fail2ban**

```bash
sudo apt-get install -y fail2ban
sudo tee /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = 2222
maxretry = 5
bantime = 3600
findtime = 600
EOF
sudo systemctl restart fail2ban
```

**3. Create a Security Group in Yandex Cloud**

Allow only:
- TCP 2222 (SSH)
- UDP 51820 (WireGuard)
- ICMP (ping)
- All egress

Attach it to the VM via YC console or CLI:

```bash
yc compute instance update-network-interface <instance-id> \
  --network-interface-index 0 \
  --security-group-id <sg-id>
```

## After VM recreation checklist

Every time a VM is recreated or restarted, the public IP changes. Before updating the client:

**1. Verify the IP is in the official Yandex Cloud range:**

```bash
whois <new-ip> | grep netname
```

Must return `RU-YANDEXCLOUD-*`. If it returns anything else (e.g. `STUB-*`) — the VPN will not work for most sites. Recreate the VM to get a new IP.

**2. Update SSH config locally:**

```
Host web-gateway-yandex
    HostName <new-ip>
    Port 2222
```

**3. Generate a new QR code for the client:**

```bash
ssh web-gateway-yandex "qrencode -t ansiutf8 < /etc/wireguard/clients/<name>.conf"
```

## Notes

- VM zone: `ru-central1-d` works (Yandex Cloud `178.154.x.x` range). Avoid zones that issue `111.88.x.x` addresses
- WireGuard port: `51820` UDP
- VPN subnet: `10.0.0.0/24`, server at `10.0.0.1`
- IAM token expires in 12h — regenerate with `yc iam create-token` before each `terraform apply`
- Client configs stored at `/etc/wireguard/clients/` on the server
