provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  enable_irsa = true
  openid_connect_audiences = ["sts.amazonaws.com"]

  vpc_id                   = var.vpc_id
  subnet_ids = var.subnets_ids
  control_plane_subnet_ids = var.subnets_ids
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profile_defaults = {
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional.arn
    }
  }

  # Fargate Profile(s)
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "*"
        }
      ]
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true
  create_aws_auth_configmap = false
  aws_auth_roles = var.configmap_auth_roles 

  aws_auth_accounts = [
    var.aws_account_id
  ]

  tags = var.tags
}

module "eks_iam_service_account" {
    source  = "git::https://github.com/cnasser-caylent/terraform-aws-eks-iamserviceaccount.git?ref=main"
    service_account_namespace   = "crossplane-system"
    policy_files                = ["crossplane-policy.json"]
    policy_name_prefix          = "tf"
    iam_role_name               = "aws-provider-role-tf" 
    oidc_provider               = trimprefix ("${module.eks.cluster_oidc_issuer_url}", "https://")
    service_account_name        = "provider-aws"
  depends_on = [
    module.eks
  ]
}

resource "aws_iam_policy" "additional" {
  name = "crossplane-eks-additional"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "terraform-aws-eks-crossplane" {
  source  = "git::https://github.com/cnasser-caylent/terraform-aws-eks-crossplane.git?ref=main"
  depends_on = [
    module.eks
  ]
}
