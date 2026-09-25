locals {
  ansible_ssm_parameters = {
    SourceType = "GitHub"
    SourceInfo = jsonencode({
      owner      = var.github_owner
      repository = var.github_repository
      path       = "ansible"
      getOptions = "branch:${var.github_branch}"
      tokenInfo  = "{{ssm-secure:/django-ansible-lab/github-token}}"
    })
    InstallDependencies = "True"
    Check               = "False"
  }
  deploy_extra_variables = "db_host=${aws_instance.db.private_ip} alb_host=${aws_lb.app.dns_name}"
}

################
resource "aws_ssm_association" "database" {
  count                            = var.enable_ansible ? 1 : 0
  name                             = "AWS-ApplyAnsiblePlaybooks"
  association_name                 = "django-ansible-lab-database"
  wait_for_success_timeout_seconds = 3600

  parameters = merge(local.ansible_ssm_parameters, {
    PlaybookFile = "db.yml"
  })

  targets {
    key    = "InstanceIds"
    values = [aws_instance.db.id]
  }

  depends_on = [aws_iam_role_policy.read_app_secrets]
}

################
resource "aws_ssm_association" "webservers" {
  count                            = var.enable_ansible ? 1 : 0
  name                             = "AWS-ApplyAnsiblePlaybooks"
  association_name                 = "django-ansible-lab-webservers"
  wait_for_success_timeout_seconds = 3600

  parameters = merge(local.ansible_ssm_parameters, {
    PlaybookFile = "webservers.yml"
  })

  targets {
    key    = "InstanceIds"
    values = aws_instance.app[*].id
  }

  depends_on = [aws_ssm_association.database]
}

################
resource "aws_ssm_association" "deploy_first" {
  count                            = var.enable_ansible ? 1 : 0
  name                             = "AWS-ApplyAnsiblePlaybooks"
  association_name                 = "django-ansible-lab-deploy-first"
  wait_for_success_timeout_seconds = 3600

  parameters = merge(local.ansible_ssm_parameters, {
    PlaybookFile   = "deploy.yml"
    ExtraVariables = local.deploy_extra_variables
  })

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app[0].id]
  }

  depends_on = [aws_ssm_association.webservers]
}

################
resource "aws_ssm_association" "deploy_second" {
  count                            = var.enable_ansible ? 1 : 0
  name                             = "AWS-ApplyAnsiblePlaybooks"
  association_name                 = "django-ansible-lab-deploy-second"
  wait_for_success_timeout_seconds = 3600

  parameters = merge(local.ansible_ssm_parameters, {
    PlaybookFile   = "deploy.yml"
    ExtraVariables = local.deploy_extra_variables
  })

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app[1].id]
  }

  depends_on = [aws_ssm_association.deploy_first]
}
