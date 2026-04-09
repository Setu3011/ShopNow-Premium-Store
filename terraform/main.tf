module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      max_size     = 3
      min_size     = 1

      instance_types = [var.instance_type]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }

      tags = {
        Name = "eks-node-group"
      }
    }
  }

  tags = {
    Environment = "dev"
    Project     = "ShopNow"
  }
}
