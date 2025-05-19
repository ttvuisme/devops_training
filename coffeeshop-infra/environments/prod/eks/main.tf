data "aws_availability_zones" "available" {
  state = "available" # Explicitly filter only available AZs
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source              = "../../../modules/vpc"
  vpc_cidr            = "10.10.0.0/16"
  name_prefix         = "coffeeshop-${terraform.workspace}"
  public_subnet_count = 2
  azs                 = slice(data.aws_availability_zones.available.names, 0, 2)

}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids

  # Security improvements
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true # Enable private access
  cluster_additional_security_group_ids = [] # Add any necessary SGs

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      # Use launch_template for better control
      create_launch_template = true
      launch_template_name   = "coffeeshop-${terraform.workspace}"

      # Disk configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true # Ensure this is set
          }
        }
      }

      # Required for CSI driver
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      
        CloudWatchAgentPolicy    = aws_iam_policy.cloudwatch_agent_policy.arn
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }

    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa_role.iam_role_arn
    }
  }
}

module "ebs_csi_driver_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.34.0"

  role_name_prefix = "AmazonEKS_EBS_CSI_Driver_"
  attach_ebs_csi_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  
  # Add these for better permission boundaries
  role_permissions_boundary_arn = null # Set if your org requires it
  role_path                     = "/delegatedadmin/developer/"
  role_description              = "IRSA role for EBS CSI Driver"
}

# Add this to ensure proper ordering
resource "time_sleep" "wait_30_seconds" {
  depends_on = [module.eks]

  create_duration = "30s"
}

# IAM policy for CloudWatch agent
resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "EKSCloudWatchAgentPolicy"
  description = "Permissions for CloudWatch agent on EKS nodes"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

# Outputs for debugging
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ebs_csi_role_arn" {
  value = module.ebs_csi_driver_irsa_role.iam_role_arn
}