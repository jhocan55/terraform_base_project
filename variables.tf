variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "domain_name" {
  description = "Base domain (must exist as Route53 hosted zone)"
  type        = string
}

variable "wp_fqdn" {
  description = "WordPress hostname (e.g., blog.example.com)"
  type        = string
}

variable "db_name" {
  description = "RDS DB name"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "wpadmin"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "acme_email" {
  description = "Email used for Let's Encrypt registration"
  type        = string
}
