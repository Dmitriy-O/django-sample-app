#!/usr/bin/env python3
"""Check the real module using temporary files and synthetic credentials."""

import ast
import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


MODULE = (
    Path(sys.argv[1]).resolve()
    if len(sys.argv) > 1
    else Path(__file__).resolve().parents[1] / "library/django_configurator.py"
)

PASSWORD = "test-only-password-never-used-for-a-real-database"

FIXTURE = '''import os
def envsecret(name, default=""):
    return os.environ.get(name, default)
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": "fixture", "PORT": "5432", "OPTIONS": {"sslmode": "prefer"}}}
DEBUG = True
ALLOWED_HOSTS = ["localhost"]
'''

CHECKS = []


def check(condition, label):
    if not condition:
        raise RuntimeError(label)

    CHECKS.append(label)
    print("PASS: " + label)


def invoke(arguments, environment):
    process = subprocess.run(
        [sys.executable, str(MODULE)],
        input=json.dumps({"ANSIBLE_MODULE_ARGS": arguments}),
        text=True,
        capture_output=True,
        env=environment,
        timeout=30,
    )

    try:
        result = json.loads(process.stdout)
    except json.JSONDecodeError:
        raise RuntimeError(
            "Module did not return JSON; check that this Python has Ansible installed"
        )

    expected_code = 1 if result.get("failed") else 0

    if process.returncode != expected_code:
        raise RuntimeError("Module exit code does not match its JSON result")

    return result


def inspect_settings(path, environment):
    program = '''import json, os, runpy, sys
s = runpy.run_path(sys.argv[1])
d = s["DATABASES"]["default"]
print(json.dumps({
    "debug": s["DEBUG"],
    "hosts": s["ALLOWED_HOSTS"],
    "database": {k: d[k] for k in ("ENGINE", "HOST", "NAME", "USER", "PORT", "OPTIONS")},
    "password_matches": d["PASSWORD"] == os.environ["DB_PASSWORD"],
    "label": s["APP_LABEL"]
}))
'''

    process = subprocess.run(
        [sys.executable, "-c", program, str(path)],
        text=True,
        capture_output=True,
        env=environment,
        timeout=30,
        check=True,
    )

    return json.loads(process.stdout)


def main():
    if not MODULE.is_file():
        raise RuntimeError(
            "django_configurator.py was not found at the selected path"
        )

    environment = os.environ.copy()
    environment.update(
        DB="postgres",
        DB_HOST="127.0.0.1",
        DB_NAME="test_hc",
        DB_USER="test_hc_app",
        DB_PASSWORD=PASSWORD,
    )
    environment.pop("ALLOWED_HOSTS", None)

    with tempfile.TemporaryDirectory(
        prefix="django-configurator-check-"
    ) as directory:
        path = Path(directory) / "settings.py"
        path.write_text(FIXTURE, encoding="utf-8")
        path.chmod(0o640)

        arguments = dict(
            path=str(path),
            environment="production",
            db_host="127.0.0.1",
            db_name="test_hc",
            db_user="test_hc_app",
            db_password=PASSWORD,
            additional_settings={
                "ALLOWED_HOSTS": ["test.example", "localhost"],
                "APP_LABEL": "test fixture",
            },
        )

        first = invoke(arguments, environment)

        check(
            not first.get("failed") and first.get("changed") is True,
            "first run changes the file",
        )
        check(
            first.get("message") == "Django settings updated",
            "success message is returned",
        )

        source = path.read_text(encoding="utf-8")
        ast.parse(source)

        check(
            PASSWORD not in source,
            "password literal is absent from settings.py",
        )
        check(
            stat.S_IMODE(path.stat().st_mode) == 0o640,
            "file permissions are preserved",
        )

        configuration = inspect_settings(path, environment)

        check(
            configuration["debug"] is False,
            "production sets DEBUG=False",
        )
        check(
            configuration["hosts"] == ["test.example", "localhost"],
            "ALLOWED_HOSTS is applied",
        )
        check(
            configuration["database"] == {
                "ENGINE": "django.db.backends.postgresql",
                "HOST": "127.0.0.1",
                "NAME": "test_hc",
                "USER": "test_hc_app",
                "PORT": "5432",
                "OPTIONS": {"sslmode": "prefer"},
            },
            "database settings are applied and PORT/OPTIONS are preserved",
        )
        check(
            configuration["password_matches"],
            "password is read from the process environment",
        )
        check(
            configuration["label"] == "test fixture",
            "additional setting is applied",
        )

        before = (path.read_bytes(), path.stat().st_mtime_ns)
        repeated = invoke(arguments, environment)

        check(
            not repeated.get("failed") and repeated.get("changed") is False,
            "repeat run returns changed=False",
        )
        check(
            before == (path.read_bytes(), path.stat().st_mtime_ns),
            "repeat run preserves file bytes and mtime",
        )

        preview = invoke(
            dict(
                arguments,
                environment="development",
                _ansible_check_mode=True,
            ),
            environment,
        )

        check(
            not preview.get("failed") and preview.get("changed") is True,
            "check mode predicts the development change",
        )
        check(
            before == (path.read_bytes(), path.stat().st_mtime_ns),
            "check mode does not write the file",
        )

        development = invoke(
            dict(arguments, environment="development"),
            environment,
        )

        check(
            not development.get("failed")
            and inspect_settings(path, environment)["debug"] is True,
            "development sets DEBUG=True on the temporary file",
        )

        before_errors = (path.read_bytes(), path.stat().st_mtime_ns)

        cases = [
            (
                "missing file",
                dict(path=str(Path(directory) / "missing.py")),
            ),
            (
                "invalid environment",
                dict(environment="staging"),
            ),
            (
                "empty password",
                dict(db_password=""),
            ),
            (
                "invalid database name",
                dict(db_name="invalid-name"),
            ),
            (
                "wildcard host",
                dict(additional_settings={"ALLOWED_HOSTS": ["*"]}),
            ),
            (
                "missing production hosts",
                dict(additional_settings={}),
            ),
            (
                "secret in additional settings",
                dict(additional_settings={"SECRET_KEY": "test-only"}),
            ),
        ]

        for label, overrides in cases:
            result = invoke(
                dict(arguments, **overrides),
                environment,
            )

            check(
                result.get("failed") is True and bool(result.get("msg")),
                label + " is rejected with a message",
            )

        result = invoke(
            arguments,
            dict(environment, DB_HOST="different.example"),
        )

        check(
            result.get("failed") is True,
            "mismatched process environment is rejected",
        )
        check(
            before_errors == (path.read_bytes(), path.stat().st_mtime_ns),
            "rejected inputs leave the file unchanged",
        )

        path.write_text(
            FIXTURE + "\n# BEGIN ANSIBLE DJANGO CONFIGURATION\n",
            encoding="utf-8",
        )

        broken = path.read_bytes()
        result = invoke(arguments, environment)

        check(
            result.get("failed") is True and path.read_bytes() == broken,
            "incomplete managed block is rejected without writing",
        )

    print(
        "ALL {} CHECKS PASSED; temporary files removed".format(len(CHECKS))
    )


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print("FAIL: " + str(error), file=sys.stderr)
        sys.exit(1)
