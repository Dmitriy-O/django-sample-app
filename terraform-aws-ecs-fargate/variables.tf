variable "aws_region" {
  description = "AWS region for the container lab."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account allowed for this deployment."
  type        = string
  default     = "047472448571"
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "week6-healthchecks"
}
variable "vpc_cidr" {
  description = "IPv4 address range for the lab VPC."
  type        = string
  default     = "10.60.0.0/16"
}
variable "db_engine_version" {
  description = "PostgreSQL version for RDS."
  type        = string
  default     = "17.11"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial database storage in GiB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "hc"
}

variable "db_master_username" {
  description = "Database administrator username."
  type        = string
  default     = "hcadmin"
}

variable "db_port" {
  description = "PostgreSQL connection port."
  type        = number
  default     = 5432
}
variable "app_port" {
  description = "Port used by Gunicorn inside the container."
  type        = number
  default     = 8000
}

variable "alb_listener_port" {
  description = "HTTP port exposed by the application load balancer."
  type        = number
  default     = 80
}
variable "image_tag" {
  description = "Application image tag in ECR"
  type        = string
  default     = "task1-v2-arm64"
}

variable "task_cpu" {
  description = "Fargate CPU units: 512 equals half a vCPU"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 1024
}

variable "app_desired_count" {
  description = "Number of application tasks"
  type        = number
  default     = 1
}
