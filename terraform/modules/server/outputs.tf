output "server_ip" {
  description = "The public IP address of the server"
  value       = hcloud_server.main.ipv4_address
}

output "server_id" {
  description = "The ID of the server"
  value       = hcloud_server.main.id
}