variable "namespace"  { type = string }
variable "vpc_id"     { type = string }
variable "db_subnet_ids" { type = list(string) }

variable "db_name"     { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string, sensitive = true }
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
