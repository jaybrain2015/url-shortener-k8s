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