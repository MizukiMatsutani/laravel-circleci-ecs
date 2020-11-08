variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list
}

# 今回はDomein付与(https化)しないため実施しない
# variable "domain" {
#   type = string
# }

# variable "acm_id" {
#   type = string
# }

# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "this" {
  name        = "${var.name}-alb"
  description = "${var.name} alb"

  vpc_id = var.vpc_id

  # セキュリティグループ内のリソースからインターネットへのアクセスを許可する
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-alb"
  }
}

# SecurityGroup Rule
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.this.id

  # セキュリティグループ内のリソースへインターネットからのアクセスを許可する
  type = "ingress" # インバウンドルール

  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}

# 今回はDomein付与(https化)しないため実施しない
# resource "aws_security_group_rule" "https" {
#   security_group_id = aws_security_group.this.id

#   type = "ingress"

#   from_port = 443
#   to_port   = 443
#   protocol  = "tcp"

#   cidr_blocks = ["0.0.0.0/0"]
# }

# ALB
# https://www.terraform.io/docs/providers/aws/d/lb.html
resource "aws_lb" "this" {
  load_balancer_type = "application"
  name               = var.name

  security_groups = [aws_security_group.this.id]
  subnets         = flatten(var.public_subnet_ids)
}

# Listener
# https://www.terraform.io/docs/providers/aws/r/lb_listener.html
resource "aws_lb_listener" "http" {
  port     = "80"
  protocol = "HTTP"

  load_balancer_arn = aws_lb.this.arn

  # 今回はDomein付与(https化)しないため実施しない
  #   default_action {
  #     type = "redirect"

  #     redirect {
  #       port        = "443"
  #       protocol    = "HTTPS"
  #       status_code = "HTTP_301"
  #     }
  #   }

  # "ok" という固定レスポンスを設定する
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "ok"
    }
  }
}

# # 今回はDomein付与(https化)しないため実施しない
# # ALB Listener
# # https://www.terraform.io/docs/providers/aws/r/lb_listener.html
# resource "aws_lb_listener" "https" {
#   port     = "443"
#   protocol = "HTTPS"

#   certificate_arn = var.acm_id

#   load_balancer_arn = aws_lb.this.arn

#   default_action {
#     type = "fixed-response"

#     fixed_response {
#       content_type = "text/plain"
#       status_code  = "200"
#       message_body = "ok"
#     }
#   }
# }

# # Route53 Hosted Zone
# # https://www.terraform.io/docs/providers/aws/d/route53_zone.html
# data "aws_route53_zone" "this" {
#   name         = var.domain
#   private_zone = false
# }

# # Route53 record
# # https://www.terraform.io/docs/providers/aws/r/route53_record.html
# resource "aws_route53_record" "this" {
#   type = "A"

#   name    = var.domain
#   zone_id = data.aws_route53_zone.this.id

#   alias = {
#     name                   = aws_lb.this.dns_name
#     zone_id                = aws_lb.this.zone_id
#     evaluate_target_health = true
#   }
# }

# output "https_listener_arn" {
#   value = aws_lb_listener.https.arn
# }
output "https_listener_arn" {
  value = aws_lb_listener.http.arn # https化しないので、httpのarnを返却
}
