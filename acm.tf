# Lookup public hosted zone only when needed and when no explicit ID provided
locals {
  use_zone_lookup = var.enable_acm && var.route53_zone_id == ""
}

data "aws_route53_zone" "this" {
  count        = local.use_zone_lookup ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# Request a public ACM certificate only if enabled
resource "aws_acm_certificate" "wp" {
  count               = var.enable_acm ? 1 : 0
  domain_name         = var.wp_fqdn
  validation_method   = "DNS"
  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.namespace}-wp-cert" }
}

# Create DNS validation records in Route 53 when enabled
resource "aws_route53_record" "wp_cert_validation" {
  for_each = var.enable_acm ? {
    for dvo in aws_acm_certificate.wp[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = var.route53_zone_id != "" ? var.route53_zone_id : data.aws_route53_zone.this[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
  allow_overwrite = true
}

# Finalize ACM validation when enabled
resource "aws_acm_certificate_validation" "wp" {
  count                   = var.enable_acm ? 1 : 0
  certificate_arn         = aws_acm_certificate.wp[0].arn
  validation_record_fqdns = [for r in aws_route53_record.wp_cert_validation : r.value.fqdn]
}
