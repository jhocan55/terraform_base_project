variable "namespace"  { type = string }
variable "vpc_id"     { type = string }
variable "db_subnet_ids" { type = list(string) }

variable "db_name"     { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "instance_class" { type = string }
variable "multi_az"    { type = bool }

variable "allowed_security_group_ids" {
  type    = list(string)
  default = []
}
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = []
}

# Optional: reuse an existing DB subnet group instead of creating one
variable "existing_db_subnet_group_name" {
  type        = string
  default     = ""
  description = "If non-empty, use this DB subnet group and do not create a new one"
}

# Optional: reuse an existing RDS security group instead of creating one
variable "existing_rds_security_group_id" {
  type        = string
  default     = ""
  description = "If non-empty, use this SG and do not create a new security group"
}
