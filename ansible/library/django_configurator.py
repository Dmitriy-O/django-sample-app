#!/usr/bin/python
"""Manage a small, repeatable configuration block in Django settings.py."""

DOCUMENTATION = r"""
---
module: django_configurator
short_description: Configure Django database and environment settings
description:
  - Adds or updates a marked block in an existing Django settings.py.
  - Reads the database password at runtime from DB_PASSWORD; it never writes it to the file.
options:
  path:
    description: Absolute path to the Django settings.py file.
    type: path
    required: true
  environment:
    description: Deployment environment; development enables Django DEBUG.
    type: str
    choices: [development, production]
    required: true
  db_host:
    description: Database hostname or IP address.
    type: str
    required: true
  db_name:
    description: PostgreSQL database name.
    type: str
    required: true
  db_user:
    description: PostgreSQL application username.
    type: str
    required: true
  db_password:
    description: Database password, passed through a protected environment.
    type: str
    required: true
  additional_settings:
    description: >-
      Additional Django constants. If ALLOWED_HOSTS is omitted, it is read from
      the task environment; development defaults to localhost.
    type: dict
    default: {}
notes:
  - Requires DB, DB_HOST, DB_NAME, DB_USER, and DB_PASSWORD in the task environment.
  - Production also requires ALLOWED_HOSTS in additional_settings or the task environment.
  - The target settings.py must already exist and be a regular file.
"""

EXAMPLES = r"""
- name: Configure the checked-out Django application
  django_configurator:
    path: /opt/django-sample-app/hc/settings.py
    environment: production
    db_host: 10.42.20.250
    db_name: hc
    db_user: hc_app
    db_password: "{{ deploy_db_password.stdout }}"
    additional_settings:
      ALLOWED_HOSTS: [example.com, localhost]
  environment: "{{ deploy_environment }}"
  no_log: true
"""

RETURN = r"""
message:
  description: Summary of the operation without secret values.
  type: str
  returned: always
changed:
  description: Whether settings.py needed an update (including check mode).
  type: bool
  returned: always
"""

import json
import os
import re
import stat
import tempfile
from pathlib import Path

from ansible.module_utils.basic import AnsibleModule


BEGIN = "# BEGIN ANSIBLE DJANGO CONFIGURATION"
END = "# END ANSIBLE DJANGO CONFIGURATION"
IDENTIFIER = re.compile(r"^[A-Z][A-Z0-9_]*$")
DATABASE_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def configuration_block(parameters):
    """Render Python code without embedding the database password."""
    environment = parameters["environment"]
    lines = [
        BEGIN,
        "# The password stays in the protected systemd EnvironmentFile.",
        "DEPLOYMENT_ENVIRONMENT = {!r}".format(environment),
        "DATABASES['default'].update({",
        "    'ENGINE': 'django.db.backends.postgresql',",
        "    'HOST': {!r},".format(parameters["db_host"]),
        "    'NAME': {!r},".format(parameters["db_name"]),
        "    'USER': {!r},".format(parameters["db_user"]),
        "    'PASSWORD': envsecret('DB_PASSWORD', ''),",
        "})",
        "DEBUG = {}".format(environment == "development"),
    ]
    for name, value in sorted(parameters["additional_settings"].items()):
        lines.append("{} = {!r}".format(name, value))
    lines.append(END)
    return "\n".join(lines)


def updated_contents(original, block):
    """Insert the managed block or replace exactly one existing block."""
    if original.count(BEGIN) != original.count(END) or original.count(BEGIN) > 1:
        raise ValueError("settings.py has incomplete or duplicate managed markers")
    if BEGIN in original:
        before, remainder = original.split(BEGIN, 1)
        _, after = remainder.split(END, 1)
        before = before.rstrip("\n")
        after = after.lstrip("\n")
        return before + "\n\n" + block + ("\n\n" + after if after else "\n")
    return original.rstrip("\n") + "\n\n" + block + "\n"


def validate(module):
    """Reject invalid settings and mismatches with the protected environment."""
    p = module.params
    if not p["db_host"] or re.search(r"[^a-zA-Z0-9.:-]", p["db_host"]):
        module.fail_json(msg="db_host must be a hostname or an IP address")
    for name in ("db_name", "db_user"):
        if not DATABASE_IDENTIFIER.fullmatch(p[name]):
            module.fail_json(msg="{} must be a simple database identifier".format(name))
    if not p["db_password"]:
        module.fail_json(msg="db_password must not be empty")
    expected = {
        "DB": "postgres",
        "DB_HOST": p["db_host"],
        "DB_NAME": p["db_name"],
        "DB_USER": p["db_user"],
        "DB_PASSWORD": p["db_password"],
    }
    for name, value in expected.items():
        if os.environ.get(name) != value:
            module.fail_json(msg="{} does not match the deployment environment".format(name))
    if "ALLOWED_HOSTS" not in p["additional_settings"]:
        hosts = [h.strip() for h in os.environ.get("ALLOWED_HOSTS", "").split(",") if h.strip()]
        if not hosts and p["environment"] == "development":
            hosts = ["localhost", "127.0.0.1"]
        p["additional_settings"]["ALLOWED_HOSTS"] = hosts
    for name, value in p["additional_settings"].items():
        if not isinstance(name, str) or not IDENTIFIER.fullmatch(name):
            module.fail_json(msg="additional_settings keys must be uppercase identifiers")
        if name in ("DATABASES", "DEBUG", "SITE_ROOT") or any(
            part in name for part in ("PASSWORD", "SECRET", "TOKEN", "KEY")
        ):
            module.fail_json(msg="additional_settings cannot override managed or secret settings")
        try:
            json.dumps(value, allow_nan=False)
        except (TypeError, ValueError, OverflowError):
            module.fail_json(msg="additional_settings values must be JSON-compatible")
        if p["db_password"] in str(value):
            module.fail_json(msg="additional_settings must not contain the database password")
    hosts = p["additional_settings"].get("ALLOWED_HOSTS")
    if not isinstance(hosts, list) or not hosts or any(
        not isinstance(host, str)
        or re.fullmatch(r"\.?[A-Za-z0-9][A-Za-z0-9.:-]*", host) is None
        for host in hosts
    ):
        module.fail_json(msg="additional_settings must contain explicit ALLOWED_HOSTS")


def write_atomically(module, path, content):
    """Replace the file through Ansible's atomic move and retain its metadata."""
    old = path.stat()
    fd, temporary = tempfile.mkstemp(prefix=".django-settings-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as destination:
            os.fchmod(destination.fileno(), stat.S_IMODE(old.st_mode))
            if os.geteuid() == 0:
                os.fchown(destination.fileno(), old.st_uid, old.st_gid)
            destination.write(content)
            destination.flush()
            os.fsync(destination.fileno())
        module.atomic_move(temporary, str(path))
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    module = AnsibleModule(
        argument_spec=dict(
            path=dict(type="path", required=True),
            environment=dict(type="str", required=True, choices=["development", "production"]),
            db_host=dict(type="str", required=True),
            db_name=dict(type="str", required=True),
            db_user=dict(type="str", required=True),
            db_password=dict(type="str", required=True, no_log=True),
            additional_settings=dict(type="dict", default={}),
        ),
        supports_check_mode=True,
    )
    validate(module)
    path = Path(module.params["path"])
    if path.is_symlink() or not path.is_file():
        module.fail_json(msg="settings.py must exist and must not be a symbolic link")
    try:
        original = path.read_text(encoding="utf-8")
        desired = updated_contents(original, configuration_block(module.params))
        if desired == original:
            module.exit_json(changed=False, message="Django settings already current")
        if not module.check_mode:
            write_atomically(module, path, desired)
    except (OSError, UnicodeError, ValueError) as exc:
        module.fail_json(msg="Could not update Django settings: {}".format(exc))
    module.exit_json(changed=True, message="Django settings updated")


if __name__ == "__main__":
    main()
