terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Lets `terraform plan` run in CI without real AWS credentials.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

variable "create_eks" {
  type    = bool
  default = false
}

# ECR — uses our reusable module
module "ecr" {
  source = "./modules/ecr"
  name   = "my-microservice"
}

# VPC — only created when create_eks = true.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  count   = var.create_eks ? 1 : 0

  name            = "my-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}

# 3) EKS — only created when create_eks = true.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  count   = var.create_eks ? 1 : 0

  cluster_name    = "my-cluster"
  cluster_version = "1.30"
  vpc_id          = module.vpc[0].vpc_id
  subnet_ids      = module.vpc[0].private_subnets
}

output "ecr_url" {
  value = module.ecr.repository_url
}
