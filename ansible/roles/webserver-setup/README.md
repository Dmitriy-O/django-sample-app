# webserver-setup

Installs Python 3.12, system packages needed by the Django application,
and Nginx on an Amazon Linux 2023 application instance.

Run through `webservers.yml` on each application instance using
AWS Systems Manager. The `deploy` role installs the Nginx proxy configuration.
