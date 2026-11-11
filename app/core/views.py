import os
import socket

from django.db import connection
from django.http import HttpResponse, JsonResponse

from .models import Visit


def index(request):
    """Writes a row to PostgreSQL on every request: proves the DB connection works."""
    host = socket.gethostname()
    Visit.objects.create(hostname=host)
    return JsonResponse({
        "app": os.environ.get("APP_NAME", "django-app"),
        "version": os.environ.get("APP_VERSION", "dev"),
        "served_by": host,
        "total_visits": Visit.objects.count(),
    })


def healthz(request):
    """Liveness: the process is alive. Does NOT touch the DB."""
    return HttpResponse("ok\n")


def readyz(request):
    """Readiness: the app can serve traffic, i.e. the DB is reachable."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception as exc:  # noqa: BLE001
        return HttpResponse(f"db not ready: {exc}\n", status=503)
    return HttpResponse("ready\n")
