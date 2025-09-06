########################################
# IRSA OIDC provider (needed by IRSA roles)
########################################
data "tls_certificate" "eks" { url = module.eks.cluster_oidc_issuer_url }

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

########################################
# EBS CSI driver via IRSA + EKS Add-on
########################################
data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.namespace}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  resolve_conflicts        = "OVERWRITE"
  depends_on               = [aws_iam_role_policy_attachment.ebs_csi]
}

# StorageClass (gp3) used by WordPress PVC
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = { "storageclass.kubernetes.io/is-default-class" = "false" }
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters          = { type = "gp3" }
  depends_on          = [aws_eks_addon.ebs_csi]
}

########################################
# AWS Load Balancer Controller (IRSA + Helm)
########################################
data "aws_iam_policy_document" "alb_irsa" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_irsa" {
  name               = "${var.namespace}-alb-irsa"
  assume_role_policy = data.aws_iam_policy_document.alb_irsa.json
}

# NOTE: Replace with the full, official policy from AWS docs for production use.
resource "aws_iam_policy" "alb_controller" {
  name   = "${var.namespace}-alb-controller-policy"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_irsa.arn
  }

  depends_on = [aws_iam_role_policy_attachment.alb_attach]
}

########################################
# external-dns (IRSA + Helm)
########################################
data "aws_iam_policy_document" "extdns_irsa" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}

resource "aws_iam_role" "extdns_irsa" {
  name               = "${var.namespace}-external-dns-irsa"
  assume_role_policy = data.aws_iam_policy_document.extdns_irsa.json
}

resource "aws_iam_policy" "extdns" {
  name = "${var.namespace}-external-dns-policy"
  policy = <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["route53:ChangeResourceRecordSets"],
    "Resource": ["arn:aws:route53:::hostedzone/*"]
  },{
    "Effect":"Allow",
    "Action": ["route53:ListHostedZones", "route53:ListResourceRecordSets"],
    "Resource": ["*"]
  }]
}
JSON
}

resource "aws_iam_role_policy_attachment" "extdns_attach" {
  role       = aws_iam_role.extdns_irsa.name
  policy_arn = aws_iam_policy.extdns.arn
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "9.0.3"

  set { 
    name = "provider"         
    value = "aws" 
    }
  set { 
    name = "policy"           
    value = "sync" 
  }
  set { 
    name = "sources[0]"       
    value = "ingress" 
  }
  set { 
    name = "domainFilters[0]" 
    value = var.domain_name 
  }
  set { 
    name = "registry"         
    value = "txt" 
  }
  set { 
    name = "txtOwnerId"       
    value = module.eks.cluster_name 
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.extdns_irsa.arn
  }

  depends_on = [aws_iam_role_policy_attachment.extdns_attach]
}

########################################
# cert-manager (Helm) + ClusterIssuer (HTTP-01 via ALB)
########################################
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.4"
  create_namespace = true
  set {
    name  = "installCRDs"
    value = "true"
  }
}

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
        solvers = [{
          http01 = { ingress = { class = "alb" } }
        }]
      }
    }
  }
  depends_on = [helm_release.cert_manager, helm_release.aws_load_balancer_controller]
}

########################################
# WordPress (Bitnami) via Helm using external RDS
########################################
resource "helm_release" "wordpress" {
  name             = "wordpress"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "wordpress"
  namespace        = "default"
  create_namespace = true

  wait         = true
  atomic       = true
  timeout      = 1800
  force_update = true
  replace      = true

  values = [file("${path.module}/helm/values-wordpress.yaml")]

  set {
    name  = "ingress.hostname"
    value = var.wp_fqdn
  }

  set {
    name  = "externalDatabase.host"
    value = module.rds.endpoint
  }
  set {
    name  = "externalDatabase.user"
    value = var.db_username
  }
  set {
    name  = "externalDatabase.password"
    value = var.db_password
  }
  set {
    name  = "externalDatabase.database"
    value = var.db_name
  }

  set {
    name  = "persistence.storageClass"
    value = kubernetes_storage_class_v1.gp3.metadata[0].name
  }

  depends_on = [
    module.eks,
    aws_eks_addon.ebs_csi,
    kubernetes_storage_class_v1.gp3,
    module.rds,
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns,
    helm_release.cert_manager,
    kubernetes_manifest.letsencrypt_clusterissuer
  ]
}
