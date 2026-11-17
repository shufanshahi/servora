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
docker compose up -d --build --wait   # PostgreSQL + API on http://localhost:3000, migrations applied on start
docker compose down          # stop (add -v to delete the database volume)
```

Compose reads `JWT_SECRET` (and the other settings) from `backend/.env`, and stops with a clear
message if it is missing. The container runs in development mode by default because this
compose file is for local use; a real deployment sets `NODE_ENV=production` and its own secret.

The API image is multi-stage, runs as a non-root user, and contains no secrets: configuration
arrives only through environment variables. The same stack also starts from the repository
root (`docker compose up -d --build --wait` there).

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

## Profile

| Endpoint | Purpose |
|---|---|
| `GET /users/me` | Your id, name, email, phone and creation date (token required) |
| `PATCH /users/me` | Update `name` and/or `phone` |
| `POST /users/me/password` | Change your password (`currentPassword`, `newPassword`) |

`PATCH /users/me` reads only `name` and `phone`: `id`, `email` and any other field in the body are
ignored, so an account cannot be re-pointed or have its credentials touched through it. An empty
name is a `422` and changes nothing. `phone` is optional (6 to 15 digits, with an optional `+` and
spaces, brackets, dashes or dots); send `""` or `null` to remove it. Responses never contain a
password or hash.

Changing the password needs the current one (wrong: `401 INVALID_CREDENTIALS`, nothing changes),
applies the registration rules to the new one and refuses to reuse the current one. It shares the
login rate limiter. Tokens issued earlier stay valid until they expire (there is no server-side
revocation list), so changing a password does not sign out other devices.

`users` has a nullable `phone` column (migration `add-user-phone`). A token for an account that has
been deleted gets `401` from `GET /users/me`; the mobile app uses that call to check a stored
session when it starts.

## Service catalogue

| Endpoint | Purpose |
|---|---|
| `GET /services` | List and search services (public, no token) |
| `GET /services/:id` | One service (public, no token) |

`GET /services` accepts: `q` (text search over name and description), `category`, `minPrice`,
`maxPrice`, `featured`, `sort` (`name`, `price` or `popular`), `order` (`asc` or `desc`), `page`
and `limit` (1-50, default 20). Filters combine, only active services are ever returned, and the
response carries `meta: { page, limit, total }`. Interactive documentation with examples is served
at **`/docs`** (for example http://localhost:3000/docs), generated from
[docs/openapi.yaml](docs/openapi.yaml). The raw specification is at `/docs/openapi.json` and
`/docs/openapi.yaml`, for importing into Postman or generating a client.

### Seeding the demo catalogue

The database starts empty. Fill it with ten demo services (four categories, durations of 30, 45,
60 and 90 minutes, four of them featured):

```bash
# API running on your machine (needs PostgreSQL up and backend/.env, see Setup)
npm run seed

# API running in Docker
docker compose exec api npm run seed:prod
```

The seed is **idempotent**: services are matched by name and updated in place, so you can run it as
often as you like and it never creates duplicates or changes ids. It also resets any service you
edited back to the catalogue values and re-activates it. It creates the demo user too (see
[Authentication](#authentication)), except when `NODE_ENV=production`: services are still seeded
there, but the demo user is skipped unless you set `SEED_ALLOW_PRODUCTION=true`.

### Images

- Images live in `public/images/services/` and are served by the API at
  `/images/services/<name>.jpg`. Only the relative path is stored in the database
  (`services.image_path`); the absolute `imageUrl` in responses is built from `PUBLIC_BASE_URL`.
  **When you host the API, set `PUBLIC_BASE_URL` to its public address** or clients will be given
  `localhost` links. For the Android emulator use `http://10.0.2.2:3000` (the emulator's name for
  your computer), and for a physical phone your computer's LAN address.
- They are small on purpose: 800 x 600 JPEG, under 150 KB each, so the repository stays light.
- Every image is a photograph from [Wikimedia Commons](https://commons.wikimedia.org/) used under
  its licence. Authors, licences and links to the original files are in
  [public/images/services/ATTRIBUTION.md](public/images/services/ATTRIBUTION.md). A test fails if an
  image has no attribution entry or an unsuitable licence.
- **To add or replace an image:** choose a photo whose licence allows reuse (public domain, CC0,
  CC BY or CC BY-SA, never non-commercial or no-derivatives); crop it to 4:3 and save it as an
  800 x 600 JPEG under 150 KB in `public/images/services/`; add or update the service in
  `src/db/seed-services.ts`; add a row to `ATTRIBUTION.md`; run `npm test` and `npm run seed`.

## Appointments

| Endpoint | Purpose |
|---|---|
| `GET /services/:id/availability?date=YYYY-MM-DD` | Slots of one service on one day, each `available` or not (public) |
| `POST /appointments` | Book a service (token required) |
| `GET /appointments` | Your appointments; `scope=upcoming` or `previous`, `page`, `limit` |
| `GET /appointments/:id` | One of your appointments |
| `PATCH /appointments/:id/cancel` | Cancel a `PENDING` appointment |

Every appointment endpoint only ever sees the signed-in user's own bookings; someone else's id is
a plain `404`. Full request and response examples are in `/docs`.

**Booking rules** (all configurable, see [Configuration](#configuration)). Start times sit on a
grid (default every 30 minutes) between opening and closing time in `BUSINESS_TZ`, and the whole
service must finish by closing time. A booking must start at least `MIN_LEAD_MINUTES` from now and
at most `BOOKING_HORIZON_DAYS` ahead. A start time that breaks a rule is `422 VALIDATION_ERROR`
(field `startsAt`). The price is copied from the service when the booking is made, so later price
changes never rewrite history.

**Capacity is one.** The API assumes a service can serve one customer at a time: two active
(non-cancelled) appointments of the same service never overlap. This is enforced by the database
itself with an exclusion constraint, not just by checking first, so simultaneous requests for one
slot cannot both succeed: one gets `201`, the others `409 SLOT_UNAVAILABLE`. Back-to-back bookings
are fine, different services never conflict, and cancelling frees the slot.

**Status progression.**

```
PENDING --(after CONFIRM_DELAY_MINUTES)--> CONFIRMED --(end time passes)--> COMPLETED
   |
   +--(owner cancels)--> CANCELLED
```

`CANCELLED` and `COMPLETED` are final, and only `PENDING` appointments can be cancelled
(`409 INVALID_STATUS_TRANSITION` otherwise). The progression is applied by a timer every 30
seconds and again just before any appointment is read, so a client never sees a stale status.
There is no payment or staff approval step: confirmation is automatic to keep the demo
self-contained.

### The `appointments` table

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key, generated |
| `user_id` | `uuid` | Owner; references `users`, deleted with the user |
| `service_id` | `uuid` | References `services`; a service with bookings cannot be deleted |
| `starts_at` | `timestamptz` | Start instant |
| `ends_at` | `timestamptz` | Start plus the service duration; must be after `starts_at` |
| `time_range` | `tstzrange` | Generated from the two columns above (`[)`), used by the overlap constraint |
| `status` | `appointment_status` | `PENDING` (default), `CONFIRMED`, `COMPLETED`, `CANCELLED` |
| `price_cents` | `integer` | Price when booked |
| `note` | `text` | Optional, at most 500 characters |
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |
| `cancelled_at` | `timestamptz` | Set when cancelled |

The constraint `appointments_no_overlap` is `EXCLUDE USING gist (service_id WITH =, time_range
WITH &&) WHERE (status <> 'CANCELLED')`. Indexes: `(user_id, starts_at)` and `(starts_at)`.

## Check it works

```bash
npm run dev
curl http://localhost:3000/health
# {"success":true,"data":{"status":"ok","uptimeSeconds":1}}
npm run seed                                  # fill the catalogue (once)
curl "http://localhost:3000/services?q=massage"
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
| `BUSINESS_TZ` | no | `UTC` | IANA time zone (for example `Asia/Karachi`) in which opening hours and "today" are interpreted |
| `BOOKING_OPEN_TIME` | no | `09:00` | First bookable start time of the day (`HH:MM`, business time) |
| `BOOKING_CLOSE_TIME` | no | `17:00` | Time by which a booking must end (`HH:MM`, business time) |
| `SLOT_INTERVAL_MINUTES` | no | `30` | Spacing of bookable start times (5-240) |
| `MIN_LEAD_MINUTES` | no | `60` | A booking must start at least this far in the future |
| `BOOKING_HORIZON_DAYS` | no | `30` | How many days ahead bookings are accepted |
| `CONFIRM_DELAY_MINUTES` | no | `2` | How long a booking stays `PENDING` before it is `CONFIRMED` |
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
| `SLOT_UNAVAILABLE` | 409 | The requested time overlaps an existing active booking of the service |
| `INVALID_STATUS_TRANSITION` | 409 | The appointment's current status does not allow the change (only `PENDING` can be cancelled) |
<!-- error-codes:end -->

Later features add their own codes (for example `EMAIL_TAKEN`, `SLOT_UNAVAILABLE`) to
this table; a test fails if the table and `src/http/errors.ts` ever disagree.

## Layout

```
public/        static files served by the API (service images and their attribution)
docs/          openapi.yaml, the source of the interactive docs at /docs
src/
  config/      validated environment configuration
  http/        Express app, routes, middleware, response helpers
  modules/     one folder per domain (routes -> controller -> service -> repository)
  db/          database pool and SQL migrations
test/          integration and unit tests
```
