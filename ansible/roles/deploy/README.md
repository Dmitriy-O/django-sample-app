# deploy

Runs on each private application EC2 through `deploy.yml` and AWS Systems Manager.

Updates the application from the GitHub fork, installs requirements and Gunicorn
in a Python 3.12 virtual environment, reads DB_PASSWORD and SECRET_KEY from
SSM Parameter Store, writes an EC2-local environment file, updates a managed
block in hc/settings.py using django_configurator, applies migrations, prepares
static files, and configures Gunicorn and Nginx. The module never writes the
database password into settings.py. The role compares the GitHub branch commit
with the deployed commit. It skips Git when they match, preserving the managed
settings block on repeat runs. On a new commit it updates the checkout and
reapplies the settings before running migrations.

The SSM association supplies `db_host` and `alb_host`. Run the database
association first, then webserver-setup, then deploy.
