# deploy

Runs on each private application EC2 through `deploy.yml` and AWS Systems Manager.

Updates the application from the GitHub fork, installs requirements and Gunicorn
in a Python 3.12 virtual environment, reads DB_PASSWORD and SECRET_KEY from
SSM Parameter Store, writes an EC2-local environment file, applies migrations,
collects static files, and configures Gunicorn and Nginx.

The SSM association supplies `db_host` and `site_root`. Run the database
association first, then webserver-setup, then deploy.
