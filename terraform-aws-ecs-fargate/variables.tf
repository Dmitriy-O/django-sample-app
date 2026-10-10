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
