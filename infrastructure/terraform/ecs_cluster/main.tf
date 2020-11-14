variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "https_listener_arn" {
  type = string
}

variable "subnet_ids" {
  type = list
}

variable "db_host" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_database" {
  type = string
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.name}-laravel"

  # アカウントID
  account_id = data.aws_caller_identity.current.account_id

  # プロビジョニングを実行するリージョン
  region = data.aws_region.current.name
}

# ECR
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "app" {
  name = "app"
}

resource "aws_ecr_repository" "nginx" {
  name = "nginx"
}

# タスク定義
data "template_file" "container_definitions" {
  template = jsonencode(yamldecode(file("./ecs_cluster/container_definitions.yaml")))

  vars = {
    tag = "latest-master" # TODO workspaceをつかって、環境ごとのtagを取るようにしたほうがいい？

    account_id   = local.account_id
    region       = local.region
    name         = local.name
    awslog_group = "/${local.name}/ecs"

    app_repo_url   = aws_ecr_repository.app.repository_url
    nginx_repo_url = aws_ecr_repository.nginx.repository_url

    db_host     = var.db_host
    db_username = var.db_username
    db_password = var.db_password
    db_database = var.db_database
  }
}

# ECS Cluster
# https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html
resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
}

# ECS Task Definition
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
resource "aws_ecs_task_definition" "this" {
  family = local.name

  container_definitions = data.template_file.container_definitions.rendered # renderedでtemplateにvarをマージしてくれる

  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  task_role_arn      = aws_iam_role.task_execution.arn
  execution_role_arn = aws_iam_role.task_execution.arn

  volume {
    name = "php-socket"
  }
}

# ClundWatch log group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
resource "aws_cloudwatch_log_group" "this" {
  name              = "/${local.name}/ecs"
  retention_in_days = "7"
}

# IAM Role
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "task_execution" {
  name = "${var.name}-TaskExecution"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM Role Policy
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy
resource "aws_iam_role_policy" "task_execution" {
  role = aws_iam_role.task_execution.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# IAM Role Policy Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ALB Target Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "this" {
  name = local.name

  vpc_id = var.vpc_id

  port        = 80
  target_type = "ip"
  protocol    = "HTTP"

  health_check {
    port = 80
  }
}

# ALB listener rule
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule
resource "aws_lb_listener_rule" "this" {
  listener_arn = var.https_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.id
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
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
resource "aws_security_group_rule" "this_http" {
  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  #  security_group_id = "xxxxxx" # セキュリティグループ指定の方法（cidr_blocksは指定できない） # TODO: LBのセキュリティグループ指定すべき？
}

resource "aws_security_group_rule" "this_ssh" {
  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"] # TODO: 会社IPに限定すべき
}

# ECS Service
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
resource "aws_ecs_service" "this" {
  depends_on = [aws_lb_listener_rule.this]

  name = "${var.name}-service"

  launch_type = "FARGATE"

  desired_count                      = 1      # 必要数
  health_check_grace_period_seconds  = "7200" # コンテナの立ち上げ猶予時間
  deployment_maximum_percent         = 200    # 最大2台の意味（必要数 * 200%）
  deployment_minimum_healthy_percent = 100    # 最低1台の意味（必要数 * 100%）

  cluster = aws_ecs_cluster.this.name

  task_definition = aws_ecs_task_definition.this.arn

  network_configuration {
    subnets         = flatten(var.subnet_ids)
    security_groups = [aws_security_group.this.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "nginx"
    container_port   = "80"
  }
}
