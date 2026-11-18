locals {
  cluster_name = "${var.env}-${var.eks_name}"
}

resource "aws_iam_role" "eks" {
  name = "${local.cluster_name}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${local.cluster_name}-eks-cluster"
    Environment = var.env
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks_compute" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks_block_storage" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks_load_balancing" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks_networking" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role" "eks_auto_node_role" {
  name        = "${var.env}-${var.org}-AmazonEKSAutoNodeRole"
  description = "Allows EKS Auto Mode nodes to connect to EKS clusters and pull container images from ECR."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Name        = "${var.env}-${var.org}-AmazonEKSAutoNodeRole"
    Environment = var.env
  }
}

resource "aws_iam_instance_profile" "eks_auto_node_profile" {
  name = "${var.env}-${var.org}-AmazonEKSAutoNodeRole"
  role = aws_iam_role.eks_auto_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_worker" {
  role       = aws_iam_role.eks_auto_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_minimal" {
  role       = aws_iam_role.eks_auto_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_ecr" {
  role       = aws_iam_role.eks_auto_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_eks_cluster" "eks" {
  name     = local.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.eks.arn

  bootstrap_self_managed_addons = false
  enabled_cluster_log_types     = var.enabled_cluster_log_types

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_auto_node_role.arn
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = var.service_ipv4_cidr

    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  zonal_shift_config {
    enabled = true
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    subnet_ids              = var.private_subnet_ids
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name        = local.cluster_name
    Environment = var.env
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_iam_role_policy_attachment.eks_compute,
    aws_iam_role_policy_attachment.eks_block_storage,
    aws_iam_role_policy_attachment.eks_load_balancing,
    aws_iam_role_policy_attachment.eks_networking,
    aws_iam_role_policy_attachment.eks_auto_node_worker,
    aws_iam_role_policy_attachment.eks_auto_node_minimal,
    aws_iam_role_policy_attachment.eks_auto_node_ecr,
  ]
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer

  tags = {
    Name        = "${local.cluster_name}-oidc"
    Environment = var.env
  }
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"
}

# IAM Role & Pod Identity Association for AWS Load Balancer Controller
resource "aws_iam_role" "eks_lb_controller" {
  name = "${var.env}-AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.env}-AmazonEKSLoadBalancerControllerRole"
    Environment = var.env
  }
}

resource "aws_eks_pod_identity_association" "eks_lb_controller" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.eks_lb_controller.arn

  depends_on = [aws_eks_addon.pod_identity]
}

resource "aws_iam_role_policy_attachment" "eks_lb_controller_elbfull" {
  role       = aws_iam_role.eks_lb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_role_policy_attachment" "eks_lb_controller_vpcfull" {
  role       = aws_iam_role.eks_lb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

resource "aws_iam_role_policy_attachment" "eks_lb_controller_acm" {
  role       = aws_iam_role.eks_lb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCertificateManagerReadOnly"
}
