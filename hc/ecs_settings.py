from .settings import *

MIDDLEWARE = [
    "hc.healthcheck.HealthCheckMiddleware",
    *MIDDLEWARE,
]

if DATABASES["default"]["ENGINE"] == "django.db.backends.postgresql":
    DATABASES["default"]["OPTIONS"]["connect_timeout"] = 3
