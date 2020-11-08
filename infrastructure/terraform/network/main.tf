variable "name" {
  type = string
}

variable "azs" {
  type    = list
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_suffix_names" {
  default = ["1a", "1c"]
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

# VPC
# https://www.terraform.io/docs/providers/aws/r/vpc.html
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.name
  }
}

# ==========================================================================
# Public Subnet
# ==========================================================================
# https://www.terraform.io/docs/providers/aws/r/subnet.html
resource "aws_subnet" "publics" {
  count = length(var.public_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  availability_zone = var.azs[count.index]
  cidr_block        = var.public_subnet_cidrs[count.index]

  tags = {
    Name = "${var.name}-public-${var.subnet_suffix_names[count.index]}"
  }
}

# Internet Gateway
# - コンソール上から作成するとInternet Gateway とVPCは自動で紐付きませんが、Terraformの場合プロパティでVPCを指定することで自動的に紐づけてくれます。
# https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

# Route Table
# - 経路情報の格納
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

# Route
# - Route Tableへ経路情報を追加
# - インターネット(0.0.0.0/0)へ接続する際はInternet Gatewayを使用するように設定する
# https://www.terraform.io/docs/providers/aws/r/route.html
resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.this.id
}

# Association
# - Route TableとSubnetの紐づけ
# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = element(aws_subnet.publics.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Elasti IP
# - プライベートサブネットからインターネットへ通信するためにNAT Gatewayを使用します。
# - NAT Gatewayは1つのElastic IPが必要なのでその割り当てと、AZ毎に必要なので3つ作成します。
# https://www.terraform.io/docs/providers/aws/r/eip.html
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)

  vpc = true

  tags = {
    Name = "${var.name}-natgw-${var.subnet_suffix_names[count.index]}"
  }
}

# NAT Gateway
# https://www.terraform.io/docs/providers/aws/r/nat_gateway.html
resource "aws_nat_gateway" "this" {
  count = length(var.public_subnet_cidrs)

  subnet_id     = element(aws_subnet.publics.*.id, count.index) # NAT Gatewayを配置するSubnetを指定
  allocation_id = element(aws_eip.nat.*.id, count.index)        # 紐付けるElasti IP

  tags = {
    Name = "${var.name}-${var.subnet_suffix_names[count.index]}"
  }
}

# ==========================================================================
# Private Subnet
# ==========================================================================
resource "aws_subnet" "privates" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  availability_zone = var.azs[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]

  tags = {
    Name = "${var.name}-private${var.subnet_suffix_names[count.index]}"
  }
}

# Route Table
# - NAT GatewayとSubnetの経路設定
resource "aws_route_table" "privates" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private${var.subnet_suffix_names[count.index]}"
  }
}

# Route
resource "aws_route" "privates" {
  count = length(var.private_subnet_cidrs)

  destination_cidr_block = "0.0.0.0/0"

  route_table_id = element(aws_route_table.privates.*.id, count.index)
  nat_gateway_id = element(aws_nat_gateway.this.*.id, count.index)
}

# Association
resource "aws_route_table_association" "privates" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = element(aws_subnet.privates.*.id, count.index)
  route_table_id = element(aws_route_table.privates.*.id, count.index)
}

# Output
# - module内のリソースの情報を、module外へ公開するために使用
output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "public_subnet_ids" {
  value = [aws_subnet.publics.*.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.privates.*.id]
}