# -------- Global / provider inputs --------
variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "region" {
  description = "AWS region for all resources. If unset, aws_region (deprecated) is used."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "DEPRECATED: fallback AWS region for backward compatibility. Use region instead."
  type        = string
  default     = ""
}

# -------- Project naming --------
variable "namespace" {
  description = "Project namespace/prefix for names (e.g. demo, prod)"
  type        = string
  default     = "demo"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.namespace))
    error_message = "namespace must be lowercase alphanumeric and dashes."
  }
}

# -------- EKS --------
variable "cluster_version" {
  description = "EKS Kubernetes version (e.g., 1.29)"
  type        = string
  default     = "1.29"
}

variable "instance_types" {
  description = "EKS node group instance types"
  type        = list(string)
  default     = ["t3.medium"]
}
variable "kubeconfig_path" {
  description = "Path to kubeconfig used by kubernetes/helm providers"
  type        = string
  default     = "~/.kube/config"
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

# -------- RDS (MariaDB) --------
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "wpadmin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "existing_db_subnet_group_name" {
  description = "If non-empty, reuse this DB subnet group name instead of creating one"
  type        = string
  default     = ""
}

variable "existing_rds_security_group_id" {
  description = "Existing RDS security group ID to reuse (skip creation)"
  type        = string
  default     = ""
}

# -------- DNS / Ingress / TLS --------
variable "domain_name" {
  description = "Base domain (must exist in Route53)"
  type        = string
}

variable "wp_fqdn" {
  description = "WordPress FQDN (e.g., blog.example.com)"
  type        = string
}

variable "acme_email" {
  description = "Email for Let's Encrypt registration"
  type        = string
}

variable "enable_acm" {
  description = "Create ACM certificate and Route53 DNS validation (set true only if you have the hosted zone)"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID. If empty, lookup by domain_name (public zone)."
  type        = string
  default     = ""
}

variable "enable_apps" {
  description = "Create Helm-based apps (ALB controller, external-dns, wordpress). Set false for minimal infra."
  type        = bool
  default     = false
}

# -------- VPC and IAM --------
variable "existing_vpc_id" {
  description = "ID of an existing VPC to use"
  type        = string
}

variable "existing_private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes and RDS"
  type        = list(string)
}

variable "existing_cluster_role_arn" {
  description = "Precreated IAM role ARN for the EKS control plane"
  type        = string
}

variable "existing_node_role_arn" {
  description = "Precreated IAM role ARN for EKS nodes"
  type        = string
}
