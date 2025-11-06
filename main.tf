# Multi-Region Disaster Recovery Infrastructure
# Author: Rahul Ladumor
# Technology: Terraform HCL

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary Region - us-east-1
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
  
  default_tags {
    tags = {
      Project     = "Multi-Region-DR"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Rahul Ladumor"
    }
  }
}

# Secondary Region - us-west-2
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  
  default_tags {
    tags = {
      Project     = "Multi-Region-DR"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Rahul Ladumor"
    }
  }
}

# DR Region - eu-west-1
provider "aws" {
  alias  = "dr"
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Project     = "Multi-Region-DR"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Rahul Ladumor"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "primary" {
  provider = aws.primary
  state    = "available"
}
data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}
data "aws_availability_zones" "dr" {
  provider = aws.dr
  state    = "available"
}

# Primary Region VPC
module "vpc_primary" {
  source = "./modules/vpc"
  providers = {
    aws = aws.primary
  }
  
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = data.aws_availability_zones.primary.names
  environment         = var.environment
  region_name         = "us-east-1"
}

# Secondary Region VPC
module "vpc_secondary" {
  source = "./modules/vpc"
  providers = {
    aws = aws.secondary
  }
  
  vpc_cidr            = "10.1.0.0/16"
  availability_zones  = data.aws_availability_zones.secondary.names
  environment         = var.environment
  region_name         = "us-west-2"
}

# DR Region VPC
module "vpc_dr" {
  source = "./modules/vpc"
  providers = {
    aws = aws.dr
  }
  
  vpc_cidr            = "10.2.0.0/16"
  availability_zones  = data.aws_availability_zones.dr.names
  environment         = var.environment
  region_name         = "eu-west-1"
}

# Aurora Global Database
module "aurora_global" {
  source = "./modules/aurora-global"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
    aws.dr        = aws.dr
  }
  
  cluster_identifier = "${var.environment}-dr-cluster"
  database_name      = var.database_name
  master_username    = var.master_username
  
  primary_vpc_id          = module.vpc_primary.vpc_id
  primary_subnet_ids      = module.vpc_primary.private_subnet_ids
  secondary_vpc_id        = module.vpc_secondary.vpc_id
  secondary_subnet_ids    = module.vpc_secondary.private_subnet_ids
  dr_vpc_id               = module.vpc_dr.vpc_id
  dr_subnet_ids           = module.vpc_dr.private_subnet_ids
  
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  
  tags = {
    Name = "${var.environment}-aurora-global"
  }
}

# DynamoDB Global Tables
module "dynamodb_global" {
  source = "./modules/dynamodb-global"
  
  table_name = "${var.environment}-orders"
  
  hash_key  = "order_id"
  range_key = "created_at"
  
  replica_regions = ["us-east-1", "us-west-2", "eu-west-1"]
  
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  tags = {
    Name = "${var.environment}-orders-table"
  }
}

# S3 Cross-Region Replication
module "s3_replication" {
  source = "./modules/s3-replication"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
    aws.dr        = aws.dr
  }
  
  bucket_prefix = "${var.environment}-data"
  
  enable_versioning = true
  enable_encryption = true
  
  replication_destinations = [
    "us-west-2",
    "eu-west-1"
  ]
  
  tags = {
    Name = "${var.environment}-data-bucket"
  }
}

# Route 53 Health Checks and Failover
module "route53_failover" {
  source = "./modules/route53"
  
  domain_name = var.domain_name
  
  primary_endpoint   = module.alb_primary.dns_name
  secondary_endpoint = module.alb_secondary.dns_name
  dr_endpoint        = module.alb_dr.dns_name
  
  health_check_interval         = 30
  health_check_failure_threshold = 3
  
  primary_weight   = 70
  secondary_weight = 20
  dr_weight        = 10
  
  tags = {
    Name = "${var.environment}-route53-failover"
  }
}

# Application Load Balancers
module "alb_primary" {
  source = "./modules/alb"
  providers = {
    aws = aws.primary
  }
  
  name               = "${var.environment}-alb-primary"
  vpc_id             = module.vpc_primary.vpc_id
  subnet_ids         = module.vpc_primary.public_subnet_ids
  security_group_ids = [module.security_groups_primary.alb_sg_id]
  
  enable_deletion_protection = false
  enable_http2              = true
  
  tags = {
    Name   = "${var.environment}-alb-primary"
    Region = "us-east-1"
  }
}

module "alb_secondary" {
  source = "./modules/alb"
  providers = {
    aws = aws.secondary
  }
  
  name               = "${var.environment}-alb-secondary"
  vpc_id             = module.vpc_secondary.vpc_id
  subnet_ids         = module.vpc_secondary.public_subnet_ids
  security_group_ids = [module.security_groups_secondary.alb_sg_id]
  
  enable_deletion_protection = false
  enable_http2              = true
  
  tags = {
    Name   = "${var.environment}-alb-secondary"
    Region = "us-west-2"
  }
}

module "alb_dr" {
  source = "./modules/alb"
  providers = {
    aws = aws.dr
  }
  
  name               = "${var.environment}-alb-dr"
  vpc_id             = module.vpc_dr.vpc_id
  subnet_ids         = module.vpc_dr.public_subnet_ids
  security_group_ids = [module.security_groups_dr.alb_sg_id]
  
  enable_deletion_protection = false
  enable_http2              = true
  
  tags = {
    Name   = "${var.environment}-alb-dr"
    Region = "eu-west-1"
  }
}

# Security Groups
module "security_groups_primary" {
  source = "./modules/security-groups"
  providers = {
    aws = aws.primary
  }
  
  vpc_id      = module.vpc_primary.vpc_id
  environment = var.environment
  region_name = "us-east-1"
}

module "security_groups_secondary" {
  source = "./modules/security-groups"
  providers = {
    aws = aws.secondary
  }
  
  vpc_id      = module.vpc_secondary.vpc_id
  environment = var.environment
  region_name = "us-west-2"
}

module "security_groups_dr" {
  source = "./modules/security-groups"
  providers = {
    aws = aws.dr
  }
  
  vpc_id      = module.vpc_dr.vpc_id
  environment = var.environment
  region_name = "eu-west-1"
}

# CloudWatch Monitoring
module "monitoring" {
  source = "./modules/monitoring"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
    aws.dr        = aws.dr
  }
  
  environment = var.environment
  
  aurora_cluster_ids = [
    module.aurora_global.primary_cluster_id,
    module.aurora_global.secondary_cluster_id,
    module.aurora_global.dr_cluster_id
  ]
  
  alb_arns = [
    module.alb_primary.arn,
    module.alb_secondary.arn,
    module.alb_dr.arn
  ]
  
  alert_email = var.alert_email
  
  tags = {
    Name = "${var.environment}-monitoring"
  }
}
