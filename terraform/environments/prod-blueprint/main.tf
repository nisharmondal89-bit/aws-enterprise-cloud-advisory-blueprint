terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

variable "project_name" { default = "finpay-ledger" }
variable "use_localstack" { default = false }
variable "enable_managed_analytics" { default = false }

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      dynamodb = "http://localhost:4566"
      s3       = "http://localhost:4566"
      ec2      = "http://localhost:4566"
      iam      = "http://localhost:4566"
      sts      = "http://localhost:4566"
    }
  }
}

module "networking" {
  source       = "../../modules/networking-security"
  project_name = var.project_name
  vpc_cidr     = "10.20.0.0/16"
  azs          = ["us-east-1a", "us-east-1b"]
}

module "data_tier" {
  source                   = "../../modules/purpose-built-data"
  project_name             = var.project_name
  isolated_subnet_ids      = module.networking.isolated_subnet_ids
  enable_managed_analytics = var.enable_managed_analytics
}

output "table_name" { value = module.data_tier.dynamodb_table_name }
output "bucket_name" { value = module.data_tier.staging_bucket_name }

