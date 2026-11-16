import os
from unittest import mock

from django.db import DatabaseError
from django.test import TestCase

from .models import Visit


class IndexViewTests(TestCase):
    def test_saves_visit_to_db(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(Visit.objects.count(), 1)

    def test_counter_grows_with_every_request(self):
        self.client.get("/")
        self.client.get("/")
        data = self.client.get("/").json()

        self.assertEqual(data["total_visits"], 3)

    def test_saves_pod_hostname(self):
        with mock.patch("core.views.socket.gethostname", return_value="django-pod-1"):
            data = self.client.get("/").json()

        self.assertEqual(data["served_by"], "django-pod-1")
        self.assertEqual(Visit.objects.get().hostname, "django-pod-1")

    def test_app_name_and_version_come_from_env(self):
        env = {"APP_NAME": "test-app", "APP_VERSION": "9.9.9"}
        with mock.patch.dict(os.environ, env):
            data = self.client.get("/").json()

        self.assertEqual(data["app"], "test-app")
        self.assertEqual(data["version"], "9.9.9")


class HealthzTests(TestCase):
    def test_returns_ok(self):
        response = self.client.get("/healthz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"ok\n")

    def test_does_not_touch_db(self):
        # liveness must not depend on PostgreSQL
        with self.assertNumQueries(0):
            self.client.get("/healthz")


class ReadyzTests(TestCase):
    def test_ready_when_db_is_up_and_migrated(self):
        response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"ready\n")

    def test_503_when_db_is_down(self):
        broken = mock.Mock()
        broken.cursor.side_effect = DatabaseError("connection refused")
        with mock.patch("core.views.connection", broken):
            response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 503)
        self.assertIn(b"db not ready", response.content)

    def test_503_when_migrations_are_pending(self):
        with mock.patch("core.views.MigrationExecutor") as executor:
            executor.return_value.migration_plan.return_value = [("core.0002", False)]
            response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.content, b"migrations pending: 1\n")
