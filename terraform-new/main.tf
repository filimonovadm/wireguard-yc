terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "yandex_vpc_subnet" "wireguard_new" {
  name           = "wireguard-new-subnet"
  zone           = var.zone
  network_id     = var.network_id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

resource "yandex_compute_instance" "wireguard_new" {
  name        = "wireguard-gateway-new"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd8snjpoq85qqv0mk9gi"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.wireguard_new.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      ssh_public_key = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = false
  }
}

output "external_ip" {
  value       = yandex_compute_instance.wireguard_new.network_interface[0].nat_ip_address
  description = "External IP of new WireGuard server — check if it's in 158.160.x.x range"
}
