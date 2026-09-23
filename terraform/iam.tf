################
resource "aws_iam_role" "ec2_ssm" {
  name = "django-ansible-lab-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "django-ansible-lab-ec2-ssm"
  }
}

################
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

################
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "django-ansible-lab-ec2-ssm"
  role = aws_iam_role.ec2_ssm.name

  tags = {
    Name = "django-ansible-lab-ec2-ssm"
  }
}

################
data "aws_caller_identity" "current" {}

################
resource "aws_iam_role_policy" "read_app_secrets" {
  name = "django-ansible-lab-read-app-secrets"
  role = aws_iam_role.ec2_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = [
        "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/django-ansible-lab/db-password",
        "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/django-ansible-lab/django-secret-key"
      ]
    }]
  })
}
