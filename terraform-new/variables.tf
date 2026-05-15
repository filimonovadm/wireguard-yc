variable "yc_token" {
  type      = string
  sensitive = true
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "network_id" {
  type        = string
  description = "Existing VPC network ID (same network as the original subnet)"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "zone" {
  type        = string
  default     = "ru-central1-b"
  description = "Availability zone to try (ru-central1-b for 158.160.x.x range)"
}
