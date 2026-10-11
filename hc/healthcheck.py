from django.db import DatabaseError, connection
from django.http import JsonResponse, HttpResponseNotAllowed


class HealthCheckMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path != "/_health/":
            return self.get_response(request)

        if request.method not in ("GET", "HEAD"):
            return HttpResponseNotAllowed(["GET", "HEAD"])

        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        except DatabaseError:
            return JsonResponse({"status": "unavailable"}, status=503)

        return JsonResponse({"status": "ok"})
