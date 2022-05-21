#
# VPC
#
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${var.env}"
  }
}

# Internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.env}-${aws_vpc.main.id}"
  }
}

# Subnets
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  count = length(var.public_subnet_cidr_blocks)
  cidr_block = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-${var.env}-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  count             = length(var.private_subnet_cidr_blocks)
  cidr_block        = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-private-${var.env}-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  count             = length(var.db_subnet_cidr_blocks)
  cidr_block        = element(var.db_subnet_cidr_blocks, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-db-${var.env}-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

# NAT gateway

resource "aws_eip" "nat_gateway" {
  count = length(aws_subnet.private[*].id)
  vpc = true

  tags = {
    Name = "eip-nat-gateway-${var.env}-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_nat_gateway" "main" {
  count             = length(aws_subnet.private[*].id)
  connectivity_type = "public"
  allocation_id     = element(aws_eip.nat_gateway[*].id, count.index)
  subnet_id         = element(aws_subnet.public[*].id, count.index)

  depends_on        = [aws_internet_gateway.main]

  tags = {
    Name = "nat-gateway-${var.env}-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

# Route table (public)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "rt-public-${var.env}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

# Route tables (private)
resource "aws_route_table" "private" {
  count = length(aws_subnet.private[*].id)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.main[*].id, count.index)
  }

  tags = {
    Name = "rt-private-${var.env}-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private[*].id)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

# Route table (db)
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "rt-db-${var.env}"
  }
}

resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.db[*].id)
  subnet_id      = element(aws_subnet.db[*].id, count.index)
  route_table_id = aws_route_table.db.id
}
