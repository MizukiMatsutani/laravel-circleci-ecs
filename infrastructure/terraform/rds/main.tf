variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_ids" {
  type = list
}

variable "database_name" {
  type = string
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type = string
}

locals {
  name = "${var.name}-rds"
}

# Security Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "this" {
  name        = local.name
  description = local.name

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.name
  }
}

# Security Group Rule
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule
resource "aws_security_group_rule" "mysql" {
  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr] # vpc内からのみアクセス可能とする
  #  security_group_id = "xxxxxx" # セキュリティグループ指定の方法（cidr_blocksは指定できない）
}

# Subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
resource "aws_db_subnet_group" "this" {
  name        = local.name
  description = local.name
  subnet_ids  = flatten(var.subnet_ids)
}

# Cluster Parameter Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group
resource "aws_rds_cluster_parameter_group" "this" {
  name   = "${local.name}-cluster-parameter-group"
  family = "aurora-mysql5.7"

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Tokyo"
  }
}

# DB Parameter Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group
resource "aws_db_parameter_group" "this" {
  name   = "${local.name}-db-parameter-group"
  family = "aurora-mysql5.7"
}

# RDS (Cluseter)
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
resource "aws_rds_cluster" "this" {
  cluster_identifier = local.name

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  engine         = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.03.2"
  port           = "3306"

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  backup_retention_period         = 7
  preferred_backup_window         = "09:30-10:00"         # UTC
  preferred_maintenance_window    = "wed:10:30-wed:11:00" # UTC
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  storage_encrypted               = true
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  skip_final_snapshot             = true # TODO: 本番環境ならtrueにしてfinal_snapshot_identifierを指定しなければならない
  #   final_snapshot_identifier = "${local.name}-final-snapshot"
}

# Cluster Instance
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance
resource "aws_rds_cluster_instance" "this" {
  identifier         = local.name
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  count          = 1
  instance_class = "db.t2.small"

  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = aws_db_parameter_group.this.name
}

output "endpoint" {
  value = aws_rds_cluster.this.endpoint
}
