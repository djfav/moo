terraform {
  # https://www.terraform.io/language/settings/terraform-cloud
  cloud {
    organization = "djfav"
    workspaces {
      name = "moo"
    }
  }

  # https://www.terraform.io/language/providers/requirements
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.9.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.40.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "~> 0.3.13"
    }
    checkly = {
      source  = "checkly/checkly"
      version = "~> 1.6.3"
    }
  }
}

# https://registry.terraform.io/providers/integrations/github/latest/docs
provider "github" {
  # export GITHUB_TOKEN
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  region = var.aws_region
  # export AWS_ACCESS_KEY_ID
  # export AWS_SECRET_ACCESS_KEY

  default_tags {
    tags = {
      Terraform = "true"
      Workspace = terraform.workspace
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/random/latest/docs
provider "random" {}

# https://registry.terraform.io/providers/BetterStackHQ/better-uptime/latest/docs
provider "betteruptime" {
  api_token = var.betteruptime_api_token
}

# https://registry.terraform.io/providers/checkly/checkly/latest/docs
provider "checkly" {
  api_key    = var.checkly_api_key
  account_id = var.checkly_account_id
}

module "git" {
  source                  = "./modules/git"
  git_repo_name           = terraform.workspace
  git_repo_description    = var.git_repo_description
  git_repo_homepage_url   = "https://${var.api_subdomain_name}.${var.registered_domain_name}/${terraform.workspace}"
  git_repo_topics         = ["api", "cowsay", "demo", "quotes"]
  git_repo_visibility     = var.git_repo_visibility
  aws_access_key_id_name  = "AWS_ACCESS_KEY_ID"
  aws_access_key_id_value = var.aws_access_key_id
  aws_access_key_name     = "AWS_SECRET_ACCESS_KEY"
  aws_access_key_value    = var.aws_access_key
  aws_region_name         = "AWS_REGION"
  aws_region_value        = var.aws_region
}

module "ecr" {
  source        = "./modules/ecr"
  ecr_repo_name = terraform.workspace
}

module "db" {
  source        = "./modules/db"
  db_table_name = terraform.workspace
}

module "lambda" {
  source             = "./modules/lambda"
  function_name      = terraform.workspace
  db_table_arn       = module.db.db_table_arn
  aws_region         = var.aws_region
  aws_account_number = var.aws_account_number
}

module "dns" {
  source                 = "./modules/dns"
  registered_domain_name = var.registered_domain_name
  api_subdomain_name     = var.api_subdomain_name
}

module "api" {
  source                  = "./modules/api"
  api_gateway_name        = terraform.workspace
  lambda_function_arn     = module.lambda.lambda_function_arn
  certificate_arn         = module.dns.certificate_arn
  certificate_domain_name = module.dns.certificate_domain_name
  hosted_zone_id          = module.dns.hosted_zone_id
  aws_region              = var.aws_region
  aws_account_number      = var.aws_account_number
}

module "ops" {
  source                  = "./modules/ops"
  registered_domain_name  = module.dns.registered_domain_name
  certificate_domain_name = module.dns.certificate_domain_name
  hosted_zone_id          = module.dns.hosted_zone_id
  api_gateway_name        = module.api.api_gateway_name
  aws_region              = var.aws_region
}
