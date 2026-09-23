variable "aws_region" {
  description = "AWS Region where the infrastructure will be created"
  type        = string
  default     = "us-east-1"
}

variable "ec2_instance_type" {
  description = "Instance type for the two app servers and the database server"
  type        = string
  default     = "t3.small"
}

variable "github_owner" {
  description = "GitHub owner of the fork containing the Ansible playbooks"
  type        = string
  default     = "Dmitriy-O"
}

variable "github_repository" {
  description = "GitHub repository containing the Ansible playbooks"
  type        = string
  default     = "django-sample-app"
}

variable "github_branch" {
  description = "GitHub branch containing the Ansible playbooks"
  type        = string
  default     = "main"
}

variable "enable_ansible" {
  description = "Run Ansible through SSM after the code and secrets are ready"
  type        = bool
  default     = false
}
