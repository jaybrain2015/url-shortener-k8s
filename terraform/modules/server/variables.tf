variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "shortener-k3s"
}

variable "server_type" {
  description = "Hetzner server type (size)"
  type        = string
  default     = "cpx22"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "ssh_key_name" {
  description = "Name of the SSH key already uploaded to Hetzner"
  type        = string
}

variable "network_id" {
  description = "ID of the network to attach to (passed in from the network module)"
  type        = number
}

variable "firewall_id" {
  description = "ID of the firewall to apply (passed in from the network module)"
  type        = number
}