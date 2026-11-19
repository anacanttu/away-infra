data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # a = onde tudo roda de fato; b = existe só por exigência do ALB e do RDS
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # 10.20.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-${var.project}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${var.project}" }
}

# --- Subnets públicas: pub-a 10.20.1.0/24, pub-b 10.20.2.0/24 ---
resource "aws_subnet" "pub_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = local.az_a
  map_public_ip_on_launch = true
  tags                    = { Name = "pub-a" }
}

resource "aws_subnet" "pub_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = local.az_b
  map_public_ip_on_launch = true
  tags                    = { Name = "pub-b" }
}

# --- Subnets privadas: priv-a 10.20.10.0/24, priv-b 10.20.20.0/24 ---
resource "aws_subnet" "priv_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone = local.az_a
  tags              = { Name = "priv-a" }
}

# priv-b não tem instâncias: só existe para o DB Subnet Group (RDS exige 2 AZs)
resource "aws_subnet" "priv_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20)
  availability_zone = local.az_b
  tags              = { Name = "priv-b" }
}

# --- NAT Gateway (1 só, em pub-a) ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "eip-nat-${var.project}" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.pub_a.id
  tags          = { Name = "nat-${var.project}" }

  depends_on = [aws_internet_gateway.main]
}

# --- Rotas ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "rt-public-${var.project}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "rt-private-${var.project}" }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.pub_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.pub_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "priv_a" {
  subnet_id      = aws_subnet.priv_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "priv_b" {
  subnet_id      = aws_subnet.priv_b.id
  route_table_id = aws_route_table.private.id
}
