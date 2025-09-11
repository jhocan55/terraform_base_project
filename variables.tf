variable "aws_region" {
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

# --------- NEW / MISSING (to satisfy main.tf references) ---------

variable "namespace" {
  description = "Project namespace prefix used for names (e.g. 'demo', 'prod')"
  type        = string
  default     = "demo"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.namespace))
    error_message = "namespace must be lowercase alphanumeric and dashes."
  }
}

variable "cluster_version" {
  description = "EKS Kubernetes version (e.g., 1.29)"
  type        = string
  default     = "1.29"
}

variable "instance_types" {
  description = "Node group instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_size" {
  description = "EKS node group desired size"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "EKS node group min size"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "EKS node group max size"
  type        = number
  default     = 3
}

variable "db_instance_class" {
  description = "RDS instance class (MariaDB)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}
