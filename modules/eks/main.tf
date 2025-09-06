# Cluster role (optional)
resource "aws_iam_role" "eks_cluster" {
  count              = var.cluster_role_arn == "" ? 1 : 0
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.cluster_role_arn == "" ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  count      = var.cluster_role_arn == "" ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn != "" ? var.cluster_role_arn : aws_iam_role.eks_cluster[0].arn

  vpc_config { subnet_ids = var.subnet_ids }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy
  ]
}

# Node role (optional)
data "aws_iam_policy_document" "eks_nodes_assume" {
  statement {
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_nodes" {
  count              = var.node_role_arn == "" ? 1 : 0
  name               = "${var.cluster_name}-eks-nodes-role"
  assume_role_policy = data.aws_iam_policy_document.eks_nodes_assume.json
}
resource "aws_iam_role_policy_attachment" "nodes_worker" {
  count      = var.node_role_arn == "" ? 1 : 0
  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "nodes_cni" {
  count      = var.node_role_arn == "" ? 1 : 0
  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  count      = var.node_role_arn == "" ? 1 : 0
  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "nodes_ssm" {
  count      = var.node_role_arn == "" ? 1 : 0
  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = var.node_role_arn != "" ? var.node_role_arn : aws_iam_role.eks_nodes[0].arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  instance_types = var.instance_types

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
    aws_iam_role_policy_attachment.nodes_ssm
  ]
}
