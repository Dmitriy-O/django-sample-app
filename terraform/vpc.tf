################
resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "django-ansible-lab-vpc"
    Project = "configuration-management"
  }
}

################
data "aws_availability_zones" "available" {
  state = "available"
}

################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "django-ansible-lab-igw"
  }
}

################
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "django-ansible-lab-public-${count.index + 1}"
  }
}

################
resource "aws_subnet" "app_private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "django-ansible-lab-app-private-${count.index + 1}"
  }
}

################
resource "aws_subnet" "db_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 20)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "django-ansible-lab-db-private"
  }
}

################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "django-ansible-lab-public-routes"
  }
}

################
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

################
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "django-ansible-lab-nat-ip"
  }
}

################
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_route_table_association.public]

  tags = {
    Name = "django-ansible-lab-nat"
  }
}

################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "django-ansible-lab-private-routes"
  }
}

################
resource "aws_route_table_association" "app_private" {
  count = 2

  subnet_id      = aws_subnet.app_private[count.index].id
  route_table_id = aws_route_table.private.id
}

################
resource "aws_route_table_association" "db_private" {
  subnet_id      = aws_subnet.db_private.id
  route_table_id = aws_route_table.private.id
}
