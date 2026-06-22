terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  # token is read automatically from the HCLOUD_TOKEN environment variable
}

module "network" {
  source = "./modules/network"
}

module "server" {
  source = "./modules/server"

  ssh_key_name = var.ssh_key_name
  network_id   = module.network.network_id
  firewall_id  = module.network.firewall_id
}