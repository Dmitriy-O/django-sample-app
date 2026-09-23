# postgres-setup

Installs PostgreSQL 16 on the private database instance, restricts access
to the application subnets, and creates the `hc` database and `hc_app` user.

Run using `db.yml` through AWS Systems Manager. Before running, create
the SecureString parameter `/django-ansible-lab/db-password` and grant
the database EC2 instance role permission to read that parameter.
Never commit the password to Git or store it in Terraform variables.
