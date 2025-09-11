output "wordpress_fqdn" {
  value       = var.wp_fqdn
  description = "WordPress external DNS (Route53), served via ALB Ingress with TLS"
}

output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "RDS MariaDB endpoint"
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region used by this stack"
  value       = var.aws_region
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (present only if enable_acm=true)"
  value       = var.enable_acm ? aws_acm_certificate.wp[0].arn : null
}
