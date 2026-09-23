################
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

################
resource "aws_security_group" "alb" {
  name        = "django-ansible-alb"
  description = "Security group for the public application load balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "django-ansible-alb"
    Project = "django-ansible-lab"
  }
}

################
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet to the load balancer"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

################
resource "aws_security_group" "app" {
  name        = "django-ansible-app"
  description = "Security group for the private Django instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "django-ansible-app"
    Project = "django-ansible-lab"
  }
}

################
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "HTTP from the load balancer to Django instances"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.app.id
}

################
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from the load balancer"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

################
resource "aws_security_group" "db" {
  name        = "django-ansible-db"
  description = "Security group for the private PostgreSQL instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "django-ansible-db"
    Project = "django-ansible-lab"
  }
}

################
resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL from Django instances to the database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

################
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL only from Django instances"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

################
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS for SSM, packages, and application dependencies"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

################
resource "aws_vpc_security_group_egress_rule" "db_https" {
  security_group_id = aws_security_group.db.id
  description       = "HTTPS for SSM and package installation"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

################
resource "aws_instance" "app" {
  count = 2

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.app_private[count.index].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -euo pipefail
    systemctl enable --now amazon-ssm-agent
  USERDATA

  tags = {
    Name    = "django-ansible-app-${count.index + 1}"
    Project = "django-ansible-lab"
    Role    = "app"
  }
}

################
resource "aws_instance" "db" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.db_private.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -euo pipefail
    systemctl enable --now amazon-ssm-agent
  USERDATA

  tags = {
    Name    = "django-ansible-db"
    Project = "django-ansible-lab"
    Role    = "db"
  }
}
