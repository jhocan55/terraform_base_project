# WordPress on AWS EKS with Terraform + Helm (ALB Ingress + TLS)

Creates VPC, EKS, EBS CSI + gp3 StorageClass, RDS MariaDB, ALB Controller, external-dns, cert-manager, and WordPress (Bitnami) with external DB and TLS.

## Run
```bash
cp terraform.tfvars.example terraform.tfvars
# EDIT: domain_name, wp_fqdn, db_password, aws_profile

terraform init
terraform apply -auto-approve

terraform output wordpress_fqdn
