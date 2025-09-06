output "wordpress_fqdn" {
  value       = var.wp_fqdn
  description = "WordPress external DNS (Route53), served via ALB Ingress with TLS"
}

output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "RDS MariaDB endpoint"
}
