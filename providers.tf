terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws         = { source = "hashicorp/aws",        version = ">= 5.0.0" }
    kubernetes  = { source = "hashicorp/kubernetes", version = ">= 2.29.0" }
    helm        = { source = "hashicorp/helm",       version = ">= 2.13.1" }
    time        = { source = "hashicorp/time",       version = ">= 0.11.0" }
  }
}

# Determine final AWS region (region takes precedence over aws_region)
locals {
  effective_region = coalesce(var.region, var.aws_region, "eu-west-3")
}

# Use the calculated region for the AWS provider
provider "aws" {
  region  = local.effective_region
  profile = var.aws_profile
}

# --- IMPORTANT ---
# Use a kubeconfig path (default: ~/.kube/config). This avoids needing module outputs
# or data sources at provider configuration time and prevents "no client config".
provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

# Helm v3 uses nested kubernetes block
provider "helm" {
  kubernetes = {
    config_path = pathexpand(var.kubeconfig_path)
  }
}
