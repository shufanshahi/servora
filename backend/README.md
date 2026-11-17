# Servora backend

REST API for Servora, built with Node.js, Express 5, TypeScript and PostgreSQL.

## Prerequisites

- Node.js 22 or newer and npm
- Docker with Docker Compose (for PostgreSQL)

## Setup

```bash
cd backend
cp .env.example .env      # then adjust values if needed
npm ci
```

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Start the API with auto-reload on `PORT` (default 3000) |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run the compiled server from `dist/` |
| `npm test` | Run the test suite (Vitest + Supertest) |
| `npm run lint` | Lint with ESLint |
| `npm run format` | Format with Prettier |
| `npm run typecheck` | Type-check without emitting |

## Database

PostgreSQL runs in Docker, published on host port **5433** (so it does not clash with a
local PostgreSQL on 5432).

```bash
docker compose up -d db      # start PostgreSQL and wait with: docker compose up -d --wait db
npm run migrate              # apply SQL migrations in src/db/migrations
npm run migrate:down         # roll back the latest migration
npm run migrate:create <name># create a new SQL migration file
```

Migrations enable the `citext` and `btree_gist` extensions. The test suite uses its own
`servora_test` database, creates it on demand and applies the migrations before running.

## Check it works

```bash
npm run dev
curl http://localhost:3000/health
# {"success":true,"data":{"status":"ok","uptimeSeconds":1}}
```

## Configuration

Environment variables are validated at startup; the process exits with a readable
message if a required value is missing. See [`.env.example`](.env.example).

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `DATABASE_URL` | yes | - | PostgreSQL connection string |
| `PORT` | no | `3000` | HTTP port |
| `NODE_ENV` | no | `development` | `development`, `test` or `production` |
| `CORS_ORIGINS` | no | empty | Comma-separated allowed browser origins |
| `PUBLIC_BASE_URL` | no | `http://localhost:3000` | Base for absolute URLs (images) |
| `TEST_DATABASE_URL` | no | `...:5433/servora_test` | Test database (tests only) |

## Layout

```
src/
  config/      validated environment configuration
  http/        Express app, routes, middleware, response helpers
  modules/     one folder per domain (routes -> controller -> service -> repository)
  db/          database pool and SQL migrations
test/          integration and unit tests
```
