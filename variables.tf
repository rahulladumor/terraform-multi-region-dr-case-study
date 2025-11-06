variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "database_name" {
  description = "Aurora database name"
  type        = string
  default     = "drdb"
}

variable "master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for Route 53"
  type        = string
}

variable "alert_email" {
  description = "Email for CloudWatch alerts"
  type        = string
}
