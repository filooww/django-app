# docker-app

A small Flask web app packaged with Docker and run with Docker Compose behind an Nginx reverse proxy. It shows the app name, environment, container hostname and server time, and has a `/health` endpoint for health checks.

## Project structure

```
docker-app/
├── app/
│   ├── app.py              # Flask app
│   └── requirements.txt    # dependencies
├── nginx.conf              # Nginx reverse proxy config
├── Dockerfile
├── docker-compose.yaml
├── .env.example            # example settings
├── .dockerignore
└── .gitignore
```

## How to run

```bash
cp .env.example .env
docker-compose up -d --build
```

Open http://localhost in the browser. The Flask port is not published, the app is reachable only through Nginx.

Stop and remove the containers:

```bash
docker-compose down
```

## Configuration

Settings are passed through `.env`:

| Variable | Description |
|---|---|
| `APP_NAME` | App name shown on the page |
| `APP_ENV` | Environment name (`development`, `production`) |
| `PORT` | Port Flask listens on inside the container |

`.env` is not committed, only `.env.example`.

## Commands used

| Command | What it does |
|---|---|
| `docker build -t demo-app:1.0 .` | Build the image with a version tag |
| `docker-compose up -d --build` | Build and start the containers |
| `docker ps` | Check that containers are running and healthy |
| `docker-compose logs -f nginx` | Follow Nginx logs |
| `docker-compose exec nginx getent hosts app` | Check that Nginx resolves the app by DNS name |
| `docker stats --no-stream` | Check CPU and memory limits |
| `docker-compose down` | Stop and remove the containers |

## Architecture

```
Browser → localhost:80 → nginx (8080) ──[backend network]──> app:5555 (Flask)
```

- **Nginx reverse proxy**: the only service with a published port. It forwards requests to `http://app:5555`.
- **DNS between containers**: Nginx reaches Flask by the service name `app`, resolved by Docker's built-in DNS.
- **Isolated network**: Flask is only in the `backend` network, marked `internal: true`, so it is not reachable from outside.
- **Multi-stage build**: dependencies are installed in a separate stage, the final image stays small.
- **Pinned images**: `python:3.12-slim` and `nginxinc/nginx-unprivileged:1.27-alpine` instead of `latest`.
- **Health check**: Docker calls `/health`, Nginx starts only after the app is healthy.

## Security

| Setting | Effect |
|---|---|
| Non-root users | Flask runs as `app`, Nginx as `nginx` |
| `read_only: true` | Container file systems are read-only, `/tmp` is a tmpfs |
| `cap_drop: [ALL]` | All Linux capabilities are removed |
| `no-new-privileges` | Processes cannot gain extra privileges |
| CPU and memory limits | App: 0.5 CPU / 256 MB, Nginx: 0.25 CPU / 64 MB |
| Config mounted `:ro` | Nginx config cannot be changed from inside the container |

## Screenshots

Running containers:

![docker ps](screenshots/docker-ps.png)

App in the browser:

![app](screenshots/app.png)
