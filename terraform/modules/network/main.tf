terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

resource "hcloud_network" "main" {
  name     = var.network_name
  ip_range = var.ip_range
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_firewall" "main" {
  name = "shortener-firewall"

  # Allow SSH (so you can manage the server)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.admin_ip]
  }

  # Allow HTTP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow HTTPS
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow k3s API (so kubectl can reach the cluster)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = [var.admin_ip]
  }

  # Allow the app's NodePort
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30080"
    source_ips = ["0.0.0.0/0"]
  }
}