locals {
  ns_cert_manager = "cert-manager"
  ns_kube_system  = "kube-system"
  ns_wordpress    = "wordpress"
}

# Wait a short time after EKS is created for DNS/endpoint readiness
resource "time_sleep" "wait_after_eks" {
  depends_on      = [module.eks]
  create_duration = "45s"
}


# -------------------------------
# AWS Load Balancer Controller
# (no IRSA annotation to avoid missing module refs)
# -------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = local.ns_kube_system
  create_namespace = false

  # Minimum values; controller can autodiscover VPC in EKS
  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.region

    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      # No IRSA annotation here to avoid undeclared module reference.
      # Add later: annotations = { "eks.amazonaws.com/role-arn" = module.alb_controller_irsa_role_arn }
    }
  })]

  depends_on = [time_sleep.wait_after_eks]

}

# -------------------------------
# cert-manager (with CRDs)
# -------------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = local.ns_cert_manager
  create_namespace = true
  version          = "v1.15.3"

  values = [yamlencode({
    installCRDs = true
  })]

  depends_on = [time_sleep.wait_after_eks]
}

# Allow CRDs to register before kubernetes_manifest
resource "time_sleep" "after_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "20s"
}

# -------------------------------
# ClusterIssuer (HTTP-01 via ALB)
# -------------------------------
resource "kubernetes_manifest" "letsencrypt_clusterissuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt" }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = { name = "letsencrypt-key" }
        solvers = [
          {
            http01 = {
              ingress = { class = "alb" }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    time_sleep.after_cert_manager
  ]
}

# -------------------------------
# external-dns (no IRSA annotation to avoid missing module refs)
# -------------------------------
resource "helm_release" "external_dns" {
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
      # Add later when you export the IRSA role:
      # annotations = { "eks.amazonaws.com/role-arn" = module.external_dns_irsa_role_arn }
    }
  })]

  depends_on = [module.eks]
}

# -------------------------------
# Bitnami WordPress (external RDS + ALB ingress)
# -------------------------------
resource "helm_release" "wordpress" {
  name             = "wordpress"
  repository       = "https://charts.bitnami.com/bitnami"
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
        # When using cert-manager HTTP-01 you do NOT need to pre-provide a certificate-arn.
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

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns,
    kubernetes_manifest.letsencrypt_clusterissuer
  ]
}
