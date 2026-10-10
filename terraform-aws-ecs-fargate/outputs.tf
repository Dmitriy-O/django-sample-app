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
