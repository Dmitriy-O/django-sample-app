resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "HTTP access to the application load balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP requests from the internet"

  ip_protocol = "tcp"
  from_port   = var.alb_listener_port
  to_port     = var.alb_listener_port
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  description                  = "Forward requests to application tasks"

  ip_protocol = "tcp"
  from_port   = var.app_port
  to_port     = var.app_port
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Application requests from the load balancer"

  ip_protocol = "tcp"
  from_port   = var.app_port
  to_port     = var.app_port
}

resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]
  subnets         = [for subnet in aws_subnet.public : subnet.id]

  depends_on = [
    aws_route.public_internet,
    aws_route_table_association.public
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-web"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  protocol    = "HTTP"
  port        = var.app_port

  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/_health/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-web"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  protocol          = "HTTP"
  port              = var.alb_listener_port

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
