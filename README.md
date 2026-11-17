# Servora

Service booking and management: customers browse services, book appointments,
manage their bookings, and ask an AI assistant for help.

| Folder | What it is | Docs |
|---|---|---|
| [`backend/`](backend) | Node.js + Express + PostgreSQL REST API | [backend/README.md](backend/README.md) |
| [`frontend/`](frontend) | Flutter app | [frontend/README.md](frontend/README.md) |

Each folder has its own README. The backend also has Docker files, so you can run it on its own
from `backend/` or from this folder. The Flutter app is built and run with the Flutter toolchain
(see its README).

## Prerequisites

- Docker with Docker Compose v2.20 or newer (the root compose file uses `include`)
- Node.js 22+ only if you want to run the backend outside Docker

## Run everything together

From this folder:

```bash
cp backend/.env.example backend/.env   # once: the API needs a JWT_SECRET (see below)
docker compose up -d --build --wait   # PostgreSQL + API in the background, migrations applied
docker compose exec api npm run seed:prod   # once: fill the service catalogue (and demo user)
curl http://localhost:3000/health
curl "http://localhost:3000/services?q=massage"
# interactive API docs: http://localhost:3000/docs
docker compose down              # stop (add -v to also delete the database volume)
```

The root `docker-compose.yml` simply `include`s the backend's compose file, so there is one
definition of every service and nothing to keep in sync.

| Service | Host port | Notes |
|---|---|---|
| API | `3000` | Override with `API_HOST_PORT` |
| PostgreSQL | `5433` | Override with `DB_HOST_PORT`; 5433 avoids clashing with a local PostgreSQL on 5432 |

## Run the backend on its own

```bash
cd backend
docker compose up -d --build --wait   # same stack, started from the backend folder
```

See [backend/README.md](backend/README.md) for running the API with `npm run dev`, tests,
migrations and configuration, and [frontend/README.md](frontend/README.md) for running the app
and building the APK.

## Configuration

The API needs a `JWT_SECRET` to sign login tokens, and Docker Compose stops with a clear message
if it is missing. `backend/.env.example` has a placeholder that is fine locally (the API refuses
it when `NODE_ENV=production`). Generate a real one for any shared or hosted deployment; the
command is in [backend/README.md](backend/README.md#authentication).

Nothing secret is stored in the repository. Docker uses safe local defaults; override them
with environment variables or a `.env` file next to the compose file. Real deployments must
set their own database credentials and secrets.
