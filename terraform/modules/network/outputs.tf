output "network_id" {
  description = "The ID of the created network"
  value       = hcloud_network.main.id
}

output "firewall_id" {
  description = "The ID of the firewall"
  value       = hcloud_firewall.main.id
}