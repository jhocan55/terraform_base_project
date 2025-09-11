# --- EKS ---
module "eks" {
  source          = "./modules/eks"
  cluster_name    = "${var.namespace}-eks"
  cluster_version = var.cluster_version
  subnet_ids      = var.existing_private_subnet_ids
  instance_types  = var.instance_types
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size

  # Use precreated IAM roles
  cluster_role_arn = var.existing_cluster_role_arn
  node_role_arn    = var.existing_node_role_arn
}

# --- RDS (MariaDB) ---
module "rds" {
  source        = "./modules/rds"
  namespace     = var.namespace
  vpc_id        = var.existing_vpc_id
  db_subnet_ids = var.existing_private_subnet_ids

  # Use existing resources to avoid IAM errors
  existing_db_subnet_group_name = var.existing_db_subnet_group_name
  existing_rds_security_group_id = var.existing_rds_security_group_id

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  instance_class = var.db_instance_class
  multi_az       = var.db_multi_az
}
