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

`.env.example` contains a **placeholder** `JWT_SECRET` that is fine for local development and
is refused when `NODE_ENV=production`. If you set up the project before authentication was
added, re-copy `.env.example` (or add the new variables) or the API will not start.

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

### Run the whole backend in Docker

```bash
cp .env.example .env         # once: provides the required JWT_SECRET to Docker Compose
docker compose up --build    # PostgreSQL + API on http://localhost:3000, migrations applied on start
docker compose down          # stop (add -v to delete the database volume)
```

Compose reads `JWT_SECRET` (and the other settings) from `backend/.env`, and stops with a clear
message if it is missing. The container runs in development mode by default because this
compose file is for local use; a real deployment sets `NODE_ENV=production` and its own secret.

The API image is multi-stage, runs as a non-root user, and contains no secrets: configuration
arrives only through environment variables. The same stack also starts from the repository
root (`docker compose up --build` there).

## Tests

The suite needs PostgreSQL running (`docker compose up -d --wait db`). It creates and migrates
its own `servora_test` database, so your development data is never touched.

```bash
npm test
```

## Authentication

| Endpoint | Purpose |
|---|---|
| `POST /auth/register` | Create an account (name, email, password) and sign in |
| `POST /auth/login` | Sign in with email and password |

Both return `{ user, accessToken, expiresAt }`. Send the token on protected routes as
`Authorization: Bearer <accessToken>`. Full request and response examples are in
[docs/openapi.yaml](docs/openapi.yaml).

**How it works**

- **Passwords** are hashed with bcrypt (cost 12 by default, a random salt per user) and
  never stored, returned or logged in plain text. Passwords need 8+ characters with a letter
  and a number, and at most 72 bytes (bcrypt ignores anything beyond that).
- **Emails** are unique case-insensitively, enforced by the database (a `citext` unique
  constraint), so two simultaneous sign-ups cannot both succeed.
- **Login errors are non-revealing**: a wrong password and an unknown email return the same
  `INVALID_CREDENTIALS` response, and a bcrypt comparison runs in both cases so timing does
  not reveal which emails exist.
- **Tokens** are signed JWTs (HS256, pinned) holding only the user id, valid for 7 days.
  Tampered, expired, unsigned or wrongly signed tokens get `401 UNAUTHENTICATED`.
- **Rate limiting**: register and login share one budget of 10 attempts per client IP per
  15 minutes (`429 RATE_LIMITED` after that). Behind a reverse proxy set `TRUST_PROXY` so the
  real client IP is used.
- **Protecting a route**: mount `createRequireAuth(tokens)` before the handler and read the
  user with `getAuth(req)`.

**Trade-off: there is no refresh token.** One access token lasts 7 days and cannot be revoked
before it expires, so a stolen token is usable until then. For a single-client app this keeps
the design small and easy to reason about; the app signs the user out and returns to login on
any 401. Mitigations: HTTPS only in production, tokens kept in secure storage on the device, a
modest lifetime, and rate-limited login. Refresh tokens with rotation and server-side
revocation would be the next improvement.

**Generate a production secret**

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

**Demo user (local development only)**

```bash
npm run seed    # creates or resets demo@servora.test / Demo1234
```

The seed is safe to run repeatedly. It refuses to run when `NODE_ENV=production` because the
demo password is public.

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
| `JWT_SECRET` | **yes** | - | Signs login tokens. At least 32 random characters; the API refuses to start otherwise |
| `JWT_EXPIRES_IN_SECONDS` | no | `604800` (7 days) | How long a login token stays valid |
| `BCRYPT_COST` | no | `12` | bcrypt work factor for password hashing (4-15) |
| `AUTH_RATE_LIMIT_MAX` | no | `10` | Register/login attempts allowed per client IP per window |
| `AUTH_RATE_LIMIT_WINDOW_SECONDS` | no | `900` | Length of that window |
| `PUBLIC_BASE_URL` | no | `http://localhost:3000` | Base for absolute URLs (images) |
| `TRUST_PROXY` | no | `0` | Number of reverse proxies in front of the API (use `1` on most hosts) |
| `TEST_DATABASE_URL` | no | `...:5433/servora_test` | Test database (tests only) |

## API conventions

Every response is JSON in one of two envelopes.

```jsonc
// success (list responses also carry pagination meta)
{ "success": true, "data": { ... }, "meta": { "page": 1, "limit": 20, "total": 42 } }

// failure
{ "success": false, "error": { "code": "VALIDATION_ERROR", "message": "Validation failed",
  "details": [{ "field": "email", "message": "Invalid email address" }] } }
```

Requests are validated before any business logic runs; unknown fields are dropped.
Passwords, tokens and request bodies are never written to logs.

### Error codes

<!-- error-codes:start -->
| Code | HTTP status | Meaning |
|---|---|---|
| `BAD_REQUEST` | 400 | Malformed request, for example a body that is not valid JSON |
| `UNAUTHENTICATED` | 401 | Missing, invalid or expired credentials |
| `FORBIDDEN` | 403 | Authenticated but not allowed to perform the action |
| `NOT_FOUND` | 404 | Unknown route or resource (also used for resources owned by someone else) |
| `CONFLICT` | 409 | Generic state conflict; domain conflicts use their own codes |
| `PAYLOAD_TOO_LARGE` | 413 | Request body exceeds the 100 KB limit |
| `VALIDATION_ERROR` | 422 | Input failed validation; see `error.details` per field |
| `RATE_LIMITED` | 429 | Too many requests from this client |
| `INTERNAL_ERROR` | 500 | Unexpected server fault; details are only in server logs |
| `EMAIL_TAKEN` | 409 | Registration with an email that already has an account (compared case-insensitively) |
| `INVALID_CREDENTIALS` | 401 | Wrong email or password; identical for both so registered emails are not revealed |
<!-- error-codes:end -->

Later features add their own codes (for example `EMAIL_TAKEN`, `SLOT_UNAVAILABLE`) to
this table; a test fails if the table and `src/http/errors.ts` ever disagree.

## Layout

```
src/
  config/      validated environment configuration
  http/        Express app, routes, middleware, response helpers
  modules/     one folder per domain (routes -> controller -> service -> repository)
  db/          database pool and SQL migrations
test/          integration and unit tests
```
