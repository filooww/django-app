# django-app

A small Django application packaged as a Docker image. It is the application part of a DevOps assignment: the image is published to GitHub Container Registry and deployed to a Kubernetes cluster with Helm and Argo CD (see [django-gitops](https://github.com/filooww/django-gitops)).

Every request to `/` writes a row to PostgreSQL and returns the total number of visits, so it is easy to check that the app is connected to the database and that the data survives restarts.

## Project structure

```
django-app/
├── app/
│   ├── manage.py
│   ├── requirements.txt        # pinned dependencies (Django, psycopg, gunicorn)
│   ├── config/
│   │   ├── settings.py         # all settings come from environment variables
│   │   ├── urls.py
│   │   └── wsgi.py             # entry point for Gunicorn
│   └── core/
│       ├── models.py           # Visit model
│       ├── views.py            # /, /healthz, /readyz
│       └── migrations/
├── nginx/dev.conf              # reverse proxy config for local run
├── Dockerfile
├── docker-compose.yaml         # local run: PostgreSQL + migrations + app + nginx
├── .env.example                # example settings
├── .dockerignore
└── .gitignore
```

## Endpoints

| Path | Description | Used for |
|---|---|---|
| `/` | Saves a visit to PostgreSQL, returns JSON with app name, version, pod/container name and total visits | Checking DB connection, load balancing |
| `/healthz` | Always returns `ok`, does not touch the DB | Docker healthcheck, Kubernetes liveness probe |
| `/readyz` | `ready` if the DB is reachable and all migrations are applied, otherwise `503` | Kubernetes readiness probe |

Example response:

```json
{"app": "django-prod", "version": "1.0.2", "served_by": "django-django-6b99956757-8qz5r", "total_visits": 10}
```

## Configuration

All configuration is passed through environment variables, nothing environment-specific is stored in the image.

| Variable | Required | Default | Description |
|---|---|---|---|
| `DJANGO_SECRET_KEY` | yes | | Django secret key |
| `DB_PASSWORD` | yes | | PostgreSQL password |
| `DB_HOST` | no | `localhost` | PostgreSQL host (`db` in Compose, Service name in Kubernetes) |
| `DB_PORT` | no | `5432` | PostgreSQL port |
| `DB_NAME` | no | `app` | Database name |
| `DB_USER` | no | `app` | Database user |
| `DJANGO_DEBUG` | no | `False` | Debug mode |
| `DJANGO_ALLOWED_HOSTS` | no | `*` | Comma-separated list of allowed hosts |
| `APP_NAME`, `APP_VERSION` | no | | Shown in the `/` response |

For the PostgreSQL container (Compose only): `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`. They must match `DB_NAME`, `DB_USER`, `DB_PASSWORD`.

## Docker image

```
ghcr.io/filooww/django-app:<version>
```

- Official `python:3.12-slim` base image, multi-stage build (dependencies are installed into a venv in a separate stage).
- Runs as a non-root user `app` (UID 999).
- No credentials inside the image: `.env` is excluded by `.dockerignore`, all secrets come from environment variables at runtime.
- Started with **Gunicorn**: `gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2`.
- Logs go to stdout, so they are visible in `docker logs` / `kubectl logs`.
- Migrations are a separate command: `python manage.py migrate --noinput` (a one-shot service in Compose, a Job in Kubernetes).

Build and publish a new version:

```bash
docker build -t ghcr.io/filooww/django-app:1.0.2 .
docker push ghcr.io/filooww/django-app:1.0.2
```

Published tags are never overwritten: every change gets a new version.

## Run locally with Docker Compose

```bash
cp .env.example .env      # then change the passwords
docker-compose up -d --build
curl localhost:8080/
```

Startup order is enforced with `depends_on` conditions:

```
db (healthy) → migrate (exited 0) → app (healthy) → nginx
```

- `migrate` runs `manage.py migrate` once and exits.
- `db` and `app` are in the `backend` network (`internal: true`) and are not reachable from outside; only nginx publishes a port (`8080`).
- PostgreSQL data is stored in the named volume `pgdata` and survives `down` / `up` (removed only with `down -v`).
- Containers are hardened: `read_only`, `tmpfs: /tmp`, `cap_drop: ALL`, `no-new-privileges`, CPU and memory limits.

Stop:

```bash
docker-compose down
```
