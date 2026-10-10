output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name."
  value       = aws_ecr_repository.app.name
}
