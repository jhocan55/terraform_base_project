variable "aws_region"  { default = "eu-west-3" }
variable "aws_profile" { default = "student20" }

variable "namespace"   { default = "datascientest" }

# Route53 domain (must already exist)
variable "domain_name" {
  description = "Root domain name in Route53, e.g. example.com"
  type        = string
}
variable "wp_fqdn" {
  description = "WordPress FQDN, e.g. wordpress.example.com"
  type        = string
}
variable "acme_email" {
  description = "Email for Let's Encrypt registration"
  type        = string
  default     = "admin@example.com"
}

# RDS
variable "db_name"           { default = "wordpress_db" }
variable "db_username"       { default = "wp_user" }
variable "db_password"       { sensitive = true }
variable "db_instance_class" { default = "db.t3.micro" }
variable "db_multi_az"       { default = false }

# EKS
variable "cluster_version" { default = "1.29" }
variable "instance_types"  { default = ["t3.medium"] }
variable "desired_size"    { default = 2 }
variable "min_size"        { default = 1 }
variable "max_size"        { default = 3 }
