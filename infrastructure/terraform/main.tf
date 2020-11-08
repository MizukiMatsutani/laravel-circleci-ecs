# @see https://y-ohgi.com/introduction-terraform/handson/vpc/
# 事前準備
# - IAMを作成していること
# - terraformをインストールしていること https://github.com/tfutils/tfenv#terraform-version-file
# - aws configure はおわっていること

provider "aws" {
  region = "ap-northeast-1"
}

variable "name" {
  type    = string
  default = "sample"
}

variable "azs" {
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

# @see ./.envrc
variable "rds_master_username" {
  type = string
}
variable "rds_master_password" {
  type = string
}
variable "rds_database_name" {
  type = string
}

# 今回はDomein付与しないため実施しない
# variable "domain" {
#   type = "string"

#   default = "<YOUR DOMAIN>"
# }

# VPC, Subnet, Gateway, Route
module "network" {
  source = "./network"

  name = var.name
  azs  = var.azs
}

# 今回はDomein付与しないため実施しない
# AWS Certificate Manager
# module "acm" {
#   source = "./acm"

#   name = var.name

#   domain = var.domain
# }

# Elastic Load Balancing
module "elb" {
  source = "./elb"

  name = var.name

  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  # 今回はDomein付与しないため実施しない
  # domain            = var.domain
  # acm_id            = module.acm.acm_id
}

# RDS
module "rds" {
  source = "./rds"

  name = var.name

  vpc_id     = module.network.vpc_id
  vpc_cidr   = module.network.vpc_cidr
  subnet_ids = module.network.private_subnet_ids

  database_name   = var.rds_database_name
  master_username = var.rds_master_username
  master_password = var.rds_master_password
}

# Elastic Container Service
module "ecs_cluster" {
  source = "./ecs_cluster"

  name = var.name

  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  https_listener_arn = module.elb.https_listener_arn

  db_host     = module.rds.endpoint
  db_username = var.rds_master_username # TODO: マスターパスワードじゃ、だめじゃないかな
  db_password = var.rds_master_password
  db_database = var.rds_database_name
}
