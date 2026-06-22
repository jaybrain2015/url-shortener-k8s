output "server_ip" {
  description = "Public IP of the k3s server"
  value       = module.server.server_ip
}