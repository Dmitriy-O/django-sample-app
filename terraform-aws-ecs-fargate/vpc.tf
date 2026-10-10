data "aws_availability_zones" "available" {
  state = "available"

  exclude_zone_ids = ["use1-az3"]

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

locals {
  availability_zones = slice(
    sort(data.aws_availability_zones.available.names),
    0,
    2
  )

  subnet_config = {
    a = {
      availability_zone = local.availability_zones[0]
      public_cidr       = cidrsubnet(var.vpc_cidr, 8, 0)
      private_cidr      = cidrsubnet(var.vpc_cidr, 8, 10)
    }

    b = {
      availability_zone = local.availability_zones[1]
      public_cidr       = cidrsubnet(var.vpc_cidr, 8, 1)
      private_cidr      = cidrsubnet(var.vpc_cidr, 8, 11)
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.subnet_config

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.subnet_config

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.private_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = local.subnet_config

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.subnet_config

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private.id
}
