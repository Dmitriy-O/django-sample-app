output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name."
  value       = aws_ecr_repository.app.name
}
output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "availability_zones" {
  description = "Availability zones selected for the lab."
  value       = local.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs for ALB and Fargate."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs for RDS."
  value       = [for subnet in aws_subnet.private : subnet.id]
}
output "db_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.main.identifier
}

output "db_address" {
  description = "PostgreSQL DNS address."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.main.port
}

output "db_master_secret_arn" {
  description = "ARN of the administrator secret managed by RDS."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "app_security_group_id" {
  description = "Security group for application tasks."
  value       = aws_security_group.app.id
}
output "app_url" {
  description = "HTTP address of the application load balancer."
  value       = "http://${aws_lb.app.dns_name}:${var.alb_listener_port}"
}

output "target_group_arn" {
  description = "Target group ARN for application health checks."
  value       = aws_lb_target_group.app.arn
}
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "migration_task_definition_arn" {
  value = aws_ecs_task_definition.migrate.arn
}

output "django_secret_arn" {
  value = aws_secretsmanager_secret.django.arn
}

output "ecs_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
