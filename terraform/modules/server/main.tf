terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

data "hcloud_ssh_key" "main" {
  name = var.ssh_key_name
}

resource "hcloud_server" "main" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"

  ssh_keys = [data.hcloud_ssh_key.main.id]

  firewall_ids = [var.firewall_id]

  network {
    network_id = var.network_id
  }

  labels = {
    project = "url-shortener"
  }
}