# Servora

Service booking and management: customers browse services, book appointments,
manage their bookings, and ask an AI assistant for help.

| Folder | What it is | Docs |
|---|---|---|
| [`backend/`](backend) | Node.js + Express + PostgreSQL REST API | [backend/README.md](backend/README.md) |
| `frontend/` | Flutter app (added in a later step) | `frontend/README.md` |

Each folder has its own README and Docker files and can be run on its own, or you can
run everything together from this folder.

## Prerequisites

- Docker with Docker Compose v2.20 or newer (the root compose file uses `include`)
- Node.js 22+ only if you want to run the backend outside Docker

## Run everything together

From this folder:

```bash
docker compose up --build        # PostgreSQL + API, migrations applied automatically
curl http://localhost:3000/health
docker compose down              # stop (add -v to also delete the database volume)
```

The root `docker-compose.yml` simply `include`s the compose file of each folder, so there is
one definition of every service and nothing to keep in sync.

| Service | Host port | Notes |
|---|---|---|
| API | `3000` | Override with `API_HOST_PORT` |
| PostgreSQL | `5433` | Override with `DB_HOST_PORT`; 5433 avoids clashing with a local PostgreSQL on 5432 |

## Run a folder on its own

```bash
cd backend
docker compose up --build        # same stack, scoped to the backend folder
```

See [backend/README.md](backend/README.md) for running the API with `npm run dev`, tests,
migrations and configuration. The `frontend/` folder will document its own run and APK
build commands once it exists.

## Configuration

Nothing secret is stored in the repository. Docker uses safe local defaults; override them
with environment variables or a `.env` file next to the compose file. Real deployments must
set their own database credentials and secrets.
