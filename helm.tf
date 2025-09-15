locals {
  ns_cert_manager = "cert-manager"  # unused now (kept for consistency)
  ns_kube_system  = "kube-system"
  ns_wordpress    = "wordpress"
}

# -------------------------------
# AWS Load Balancer Controller
# -------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  count            = var.enable_apps ? 1 : 0
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = local.ns_kube_system
  create_namespace = false

  values = [yamlencode({
      clusterName    = module.eks.cluster_name
      region         = local.effective_region
      serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
    }
  })]
}

# -------------------------------
# external-dns
# -------------------------------
resource "helm_release" "external_dns" {
  count            = var.enable_apps ? 1 : 0
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = local.ns_kube_system
  create_namespace = false

  values = [yamlencode({
    provider      = "aws"
    policy        = "sync"
    registry      = "txt"
    txtOwnerId    = module.eks.cluster_name
    domainFilters = [var.domain_name]
    serviceAccount = {
      create = true
      name   = "external-dns"
    }
  })]
}

# -------------------------------
# WordPress (disabled by default)
# -------------------------------
resource "helm_release" "wordpress" {
  count            = var.enable_apps ? 1 : 0
  name             = "wordpress"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "wordpress"
  namespace        = local.ns_wordpress
  create_namespace = true

  values = [yamlencode({
    mariadb = { enabled = false }
    externalDatabase = {
      host     = module.rds.endpoint
      user     = var.db_username
      password = var.db_password
      database = var.db_name
      port     = 3306
    }
    service = { type = "ClusterIP" }
    ingress = {
      enabled          = true
      ingressClassName = "alb"
      hostname         = var.wp_fqdn
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"          = "ip"
        "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\":\"redirect\",\"RedirectConfig\":{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}}"
        "alb.ingress.kubernetes.io/group.name"           = "wordpress"
      }
      tls = [{
        hosts      = [var.wp_fqdn]
        secretName = "wp-tls"
      }]
      extraPaths = [{
        path = "/*"
        backend = {
          serviceName = "ssl-redirect"
          servicePort = "use-annotation"
        }
      }]
    }
  })]
}
