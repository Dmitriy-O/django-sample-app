resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app"
  description = "Network access for application tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-app"
  }
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS access to AWS services and external APIs"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_database" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
  description                  = "PostgreSQL access to the database"

  ip_protocol = "tcp"
  from_port   = var.db_port
  to_port     = var.db_port
}
resource "aws_ecs_cluster" "main" {
  name = var.project_name
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 1
}

resource "aws_secretsmanager_secret" "django" {
  name                    = "${var.project_name}/django"
  description             = "Django SECRET_KEY"
  recovery_window_in_days = 7
}
resource "aws_iam_role" "execution" {
  name = "${var.project_name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = var.aws_account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "execution" {
  name = "${var.project_name}-execution"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthentication"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PullApplicationImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "WriteApplicationLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      },
      {
        Sid    = "ReadApplicationSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.django.arn,
          aws_db_instance.main.master_user_secret[0].secret_arn
        ]
      }
    ]
  })
}
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.project_name}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.app_container, {
      healthCheck = {
        command = [
          "CMD",
          "python",
          "-c",
          "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.app_port}/_health/', timeout=3)"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    })
  ])
}

resource "aws_ecs_task_definition" "migrate" {
  family                   = "${var.project_name}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.app_container, {
      command = ["python", "manage.py", "migrate", "--noinput"]
    })
  ])
}
resource "aws_ecs_service" "app" {
  name             = "${var.project_name}-web"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.web.arn
  desired_count    = var.app_desired_count
  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "web"
    container_port   = var.app_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.execution,
    aws_route.public_internet,
    aws_route_table_association.public
  ]
}
locals {
  app_container = {
    name      = "web"
    image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.app_port
      hostPort      = var.app_port
      protocol      = "tcp"
    }]

    environment = [
      for name, value in {
        DJANGO_SETTINGS_MODULE = "hc.ecs_settings"
        DEBUG                  = "False"
        DB                     = "postgres"
        DB_HOST                = aws_db_instance.main.address
        DB_PORT                = tostring(var.db_port)
        DB_NAME                = var.db_name
        DB_USER                = var.db_master_username
        DB_SSLMODE             = "require"
        SITE_ROOT              = "http://${aws_lb.app.dns_name}"
        ALLOWED_HOSTS          = "${aws_lb.app.dns_name},localhost,127.0.0.1"
        } : {
        name  = name
        value = value
      }
    ]

    secrets = [
      {
        name      = "SECRET_KEY"
        valueFrom = aws_secretsmanager_secret.django.arn
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "app"
      }
    }

    stopTimeout = 30
  }
}
