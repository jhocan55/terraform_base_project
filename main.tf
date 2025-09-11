# --- Networking ---
module "networking" {
  source          = "./modules/networking"
  namespace       = var.namespace
  cluster_name    = "${var.namespace}-eks"
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}

# --- EKS ---
module "eks" {
  source          = "./modules/eks"
  cluster_name    = "${var.namespace}-eks"
  cluster_version = var.cluster_version
  subnet_ids      = module.networking.private_subnet_ids
  instance_types  = var.instance_types
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size

  # leave empty to let the module create IAM roles
  cluster_role_arn = ""
  node_role_arn    = ""
}

# --- RDS (MariaDB) ---
module "rds" {
  source         = "./modules/rds"
  namespace      = var.namespace
  vpc_id         = module.networking.vpc_id
  db_subnet_ids  = module.networking.private_subnet_ids

  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = var.db_instance_class
  multi_az       = var.db_multi_az

  # Only allow from the EKS cluster security group
  allowed_cidr_blocks         = []
  # fixed
  allowed_security_group_ids = [ module.eks.cluster_security_group_id ]

}
