# Backend S3 pour l'état partagé
terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-201900446058"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Configuration du provider
provider "aws" {
  region = "us-east-1"
}

# Tags communs
locals {
  common_tags = {
    Project     = "petclinic"
    Team        = var.team_name
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
  name_prefix = "petclinic-${var.team_name}"
}

# ============================================
# MODULE NETWORK
# ============================================
module "network" {
  source = "../../modules/network"

  project_name = "petclinic"
  team_name    = var.team_name
  tags         = local.common_tags
}

# ============================================
# MODULE DATABASE
# ============================================
module "database" {
  source = "../../modules/database"

  project_name       = "petclinic"
  team_name          = var.team_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  app_sg_id          = module.network.app_sg_id
  db_password        = var.db_password
  tags               = local.common_tags
}

# ============================================
# MODULE COMPUTE
# ============================================
module "compute" {
  source = "../../modules/compute"

  project_name               = "petclinic"
  team_name                  = var.team_name
  region                     = "us-east-1"
  private_subnet_ids         = module.network.private_subnet_ids
  app_sg_id                  = module.network.app_sg_id
  alb_target_group_arn       = module.network.alb_target_group_arn
  db_address                 = module.database.db_address
  db_username                = module.database.db_username
  db_credentials_secret_arn  = module.database.db_credentials_secret_arn
  image_tag                  = var.image_tag
  tags                       = local.common_tags
}

# ============================================
# OUTPUTS
# ============================================
output "alb_dns_name" {
  description = "URL de l'application"
  value       = module.network.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint de la base de données"
  value       = module.database.db_address
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = module.compute.ecs_cluster_name
}

output "ecr_repository_url" {
  description = "URL du repository ECR"
  value       = module.compute.ecr_repository_url
}

