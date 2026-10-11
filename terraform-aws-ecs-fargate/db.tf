resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db"
  description = "Private subnets for PostgreSQL"

  subnet_ids = [
    for subnet in aws_subnet.private : subnet.id
  ]

  tags = {
    Name = "${var.project_name}-db"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db"
  description = "PostgreSQL access from application tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  description                  = "PostgreSQL connections from application tasks"

  ip_protocol = "tcp"
  from_port   = var.db_port
  to_port     = var.db_port
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-postgres17"
  family      = "postgres17"
  description = "PostgreSQL settings for the container lab"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.project_name}-postgres17"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = var.db_name
  username                    = var.db_master_username
  manage_master_user_password = true
  port                        = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible        = false
  multi_az                   = false
  auto_minor_version_upgrade = true
  backup_retention_period    = 1
  copy_tags_to_snapshot      = true

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-db-final"

  tags = {
    Name = "${var.project_name}-db"
  }
}
