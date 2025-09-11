locals {
  # Standard namespaces
  ns_cert_manager = "cert-manager"
  ns_kube_system  = "kube-system"
  ns_wordpress    = "wordpress"
}

# -------------------------------
# AWS Load Balancer Controller
# (Assumes IRSA role + policy already created/bound in your modules)
# -------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = local.ns_kube_system
  create_namespace = false

  # Ensure we pass clusterName and serviceAccount if using IRSA
  values = [yamlencode({
    clusterName = module.eks.cluster_name
    serviceAccount = {
      create = false
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.alb_controller_irsa_role_arn # <- adjust to your output
      }
    }
    region = var.region
    vpcId  = module.vpc.vpc_id
  })]

  # Make sure it waits for the CRDs it manages
  depends_on = [module.eks]
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

  depends_on = [module.eks]
}

# Give time for CRDs to register so kubernetes_manifest doesn't race
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
              ingress = {
                class = "alb"
              }
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
# external-dns (IRSA)
# -------------------------------
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = local.ns_kube_system
  create_namespace = false

  values = [yamlencode({
    provider = "aws"
    domainFilters = [var.domain_name] # or use zoneIdFilters
    policy = "sync"
    registry = "txt"
    txtOwnerId = module.eks.cluster_name

    serviceAccount = {
      create = false
      name   = "external-dns"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.external_dns_irsa_role_arn # <- adjust to your output
      }
    }
  })]

  depends_on = [module.eks]
}

# -------------------------------
# Bitnami WordPress (external DB + ALB ingress)
# -------------------------------
resource "helm_release" "wordpress" {
  name             = "wordpress"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "wordpress"
  namespace        = local.ns_wordpress
  create_namespace = true

  # Pin a proven chart version if you prefer:
  # version = "22.2.5"

  values = [yamlencode({
    mariadb = { enabled = false }
    externalDatabase = {
      host     = module.rds.endpoint          # <- adjust to your output
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
        "kubernetes.io/ingress.class"                   = "alb"
        "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"         = "ip"
        "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/actions.ssl-redirect"= "{\"Type\":\"redirect\",\"RedirectConfig\":{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}}"
        "alb.ingress.kubernetes.io/group.name"          = "wordpress"
        "alb.ingress.kubernetes.io/certificate-arn"     = "" # not required when using cert-manager HTTP-01
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

    # Bitnami chart auth: you can set or let it auto-generate
    # wordpressUsername = "admin"
    # wordpressPassword = "CHANGEME"
  })]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns,
    kubernetes_manifest.letsencrypt_clusterissuer
  ]
}
