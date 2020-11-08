# variable "name" {
#   type = "string"
# }

# variable "domain" {
#   type = "string"
# }

# # Route53 Hosted Zone
# # https://www.terraform.io/docs/providers/aws/d/route53_zone.html
# data "aws_route53_zone" "this" {
#   name         = var.domain
#   private_zone = false
# }

# # ACM
# # - TLS証明書の発行
# # https://www.terraform.io/docs/providers/aws/r/acm_certificate.html
# resource "aws_acm_certificate" "this" {
#   domain_name = var.domain

#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # Route53 record
# # - TLS証明書発行時にドメインの所有を証明するために作成
# # https://www.terraform.io/docs/providers/aws/r/route53_record.html
# resource "aws_route53_record" "this" {
#   depends_on = ["aws_acm_certificate.this"]

#   # data は既存のリソースを参照します。
#   # 基本的に resource ではTerraformで管理されていない場合新規に作成します。
#   # しかし、既存のリソースを使用したいケースやTerraformで管理したくないリソースは往々にして存在します。
#   # そういったリソースの情報をTerraformで管理せず参照するために使用します。
#   zone_id = data.aws_route53_zone.this.id

#   ttl = 60

#   name    = aws_acm_certificate.this.domain_validation_options.0.resource_record_name
#   type    = aws_acm_certificate.this.domain_validation_options.0.resource_record_type
#   records = [aws_acm_certificate.this.domain_validation_options.0.resource_record_value]
# }

# # ACM Validate
# # - TLS証明書発行時にドメインの所有を証明するために作成
# # - (ACMでドメインを使用して所有証明をする場合は基本的にCNAMEレコードとワンセットで定義する。)
# # https://www.terraform.io/docs/providers/aws/r/acm_certificate_validation.html
# resource "aws_acm_certificate_validation" "this" {
#   certificate_arn = aws_acm_certificate.this.arn

#   validation_record_fqdns = [aws_route53_record.this.0.fqdn]
# }

# # Output
# output "acm_id" {
#   value = aws_acm_certificate.this.id
# }
