# WordPress on AWS EKS with Terraform + Helm (ALB Ingress + TLS)

Provision an AWS environment (VPC, EKS cluster, EBS CSI driver + gp3 StorageClass, RDS MariaDB, AWS Load Balancer Controller, external-dns, cert-manager) and deploy Bitnami WordPress configured to use the external RDS database with automatic DNS + TLS.

## Features
- Isolated VPC with public + private subnets
- EKS with managed node group (gp3 storage via EBS CSI)
- RDS MariaDB (separate from WordPress pod lifecycle)
- ALB Ingress (HTTP->HTTPS) + ACM-issued certificates via cert-manager
- external-dns auto-manages Route53 records
- Parameterized domain + WordPress FQDN
- Terraform outputs for quick access

## Prerequisites
- AWS account + credentials (profile configured in ~/.aws/credentials)
- Route53 hosted zone matching your domain_name
- Tools: terraform >= 1.5, kubectl, helm, awscli
- (Optional) jq for output parsing

## Configuration
Copy and edit variables:
```bash
cp terraform.tfvars.example terraform.tfvars
# Required to edit in terraform.tfvars:
# domain_name     = "example.com"
# wp_fqdn         = "blog.example.com"
# db_password     = "StrongPassword123!"
# aws_profile     = "myprofile"
```

## Deploy
```bash
terraform init
terraform apply -auto-approve
```

Get WordPress FQDN (wait until ALB + DNS + cert ready):
```bash
terraform output -raw wordpress_fqdn
```

Check status:
```bash
kubectl get pods -A
kubectl get ingress -n wordpress
```

## Login
Default Bitnami admin user:
```bash
terraform output -raw wordpress_admin_user
terraform output -raw wordpress_admin_password
```

## Cleanup
```bash
terraform destroy
```
(Verify RDS or EBS volumes you want to retain before confirming.)

## Notes
- First TLS issuance may take several minutes.
- external-dns requires the hosted zone to exist beforehand.
- RDS credentials are stored only in Terraform state and Kubernetes secret (not committed).
- Modify node group size or instance types via variables if scaling is needed.
