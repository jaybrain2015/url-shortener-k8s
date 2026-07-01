variable "network_name" {
  description = "Name of the private network"
  type        = string
  default     = "shortener-network"
}

variable "ip_range" {
  description = "The IP range for the private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "admin_ip" {
  description = "Your IP address allowed to reach SSH and the k8s API"
  type        = string
  default     = "37.0.163.218/32"
}