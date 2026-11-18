# Servora

Service booking and management: customers browse services, book appointments,
manage their bookings, and ask an AI assistant for help.

- **Backend**: Node.js 22, Express 5, TypeScript, PostgreSQL 17
- **Frontend**: Flutter (Android app, plus a web build served by nginx in Docker)

## Contents

| Path | What it is |
|---|---|
| [`backend/`](backend) | REST API. Docs: [backend/README.md](backend/README.md) |
| [`frontend/`](frontend) | Flutter app. Docs: [frontend/README.md](frontend/README.md) |
| [`docs/DATABASE.md`](docs/DATABASE.md) | Database schema, ER diagram, migrations and setup |
| [`docs/API.md`](docs/API.md) | Every endpoint with parameters and example responses |
| [`backend/docs/openapi.yaml`](backend/docs/openapi.yaml) | Machine-readable OpenAPI 3 spec (also served at `/docs`) |
| [`apk/servora.apk`](apk) | Ready-to-install Android APK for testing |
| [`docker-compose.yml`](docker-compose.yml) | Starts the whole stack together |

## Quick start (Docker)

Prerequisites: Docker with Docker Compose v2.20 or newer (the root compose file uses `include`).

```bash
cp backend/.env.example backend/.env          # once: the API needs a JWT_SECRET
docker compose up -d --build --wait           # PostgreSQL + API + web app; migrations are applied
docker compose exec api npm run seed:prod     # once: service catalogue and the demo user
```

| What | URL |
|---|---|
| Web app | http://localhost:8080 |
| API | http://localhost:3000 (try `/health` and `/services`) |
| Interactive API docs | http://localhost:3000/docs |
| PostgreSQL | `localhost:5433` (user, password and database: `servora`) |

Sign in with the demo account `demo@servora.test` / `Demo1234`, or register a new one.

```bash
docker compose logs -f api     # follow logs
docker compose down            # stop (add -v to also delete the database volume)
```

### Run one part on its own

Each part has its own Dockerfile and compose file:

| Part | Command | Starts |
|---|---|---|
| Backend | `cd backend && docker compose up -d --build --wait` | PostgreSQL and the API (`:3000`) |
| Frontend | `cd frontend && docker compose up -d --build` | The web app (`:8080`), which needs an API to talk to |
| Everything | `docker compose up -d --build --wait` (repo root) | All of the above |

The root `docker-compose.yml` only `include`s the two compose files, so each service is defined
once and nothing can drift out of sync.

## Install the Android app (APK)

[`apk/servora.apk`](apk/servora.apk) is a release build of the app (package `com.servora.app`).
SHA-256 is in [`apk/servora.apk.sha256`](apk/servora.apk.sha256).

1. Start the backend (Quick start above).
2. Install the APK:
   - **Emulator**: `adb install -r apk/servora.apk`, or drag the file onto the emulator window.
   - **Phone**: copy the file to the phone, open it and allow installing from this source.
3. Open **Servora** and sign in with `demo@servora.test` / `Demo1234`.

**Which API does the APK talk to?** The address is fixed when the app is built. This APK uses
`http://10.0.2.2:3000`, the address the Android *emulator* uses to reach the computer running
the backend. So it works out of the box on an emulator with the backend on port 3000.

A physical phone cannot reach `10.0.2.2`. To test on a phone, rebuild the APK pointing at your
computer's LAN address (phone and computer on the same Wi-Fi) or at a hosted backend:

```bash
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.20:3000
# -> frontend/build/app/outputs/flutter-apk/app-release.apk
```

The release build allows plain `http://` so that local testing works. For a real deployment,
host the API behind HTTPS and remove `android:usesCleartextTraffic` from
[`AndroidManifest.xml`](frontend/android/app/src/main/AndroidManifest.xml). The APK is signed
with the debug key, which is fine for testing but not for store distribution.

## Run without Docker

Backend (needs Node.js 22+ and a PostgreSQL, which `docker compose up -d --wait db` provides):

```bash
cd backend
cp .env.example .env
npm ci
docker compose up -d --wait db
npm run migrate
npm run seed
npm run dev          # http://localhost:3000
```

Frontend (needs the Flutter SDK, version 3.50 or newer):

```bash
cd frontend
flutter pub get
flutter run          # emulator; see frontend/README.md for other targets
```

## Configuration

The API reads its settings from environment variables. Docker Compose reads them from
`backend/.env`; every variable is documented in
[backend/README.md](backend/README.md#configuration).

| Variable | Notes |
|---|---|
| `JWT_SECRET` | **Required.** Signs login tokens. The placeholder in `.env.example` is fine locally and is refused when `NODE_ENV=production`. Generate a real one with `node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"` |
| `CORS_ORIGINS` | Browser origins allowed to call the API. Includes the web app (`http://localhost:8080`) by default. The mobile app is not subject to CORS |
| `AI_API_KEY` | Optional. Enables the AI assistant. Without it `POST /ai/chat` answers `503 AI_UNAVAILABLE` and the rest of the app works normally |
| `API_HOST_PORT`, `DB_HOST_PORT`, `WEB_HOST_PORT` | Change the published ports (3000, 5433, 8080) |
| `API_BASE_URL` | Frontend build setting: where the app finds the API. Docker web build default `http://localhost:3000`; the Android build default `http://10.0.2.2:3000`. Rebuild after changing it |

Nothing secret is stored in the repository. Docker uses safe local defaults; real deployments
must set their own database credentials and secrets.

## Documentation index

- Database: [docs/DATABASE.md](docs/DATABASE.md)
- API: [docs/API.md](docs/API.md) and [live docs at /docs](http://localhost:3000/docs)
- Backend details (auth, tests, AI assistant, layout): [backend/README.md](backend/README.md)
- App details (screens, sign-in, tests, APK build): [frontend/README.md](frontend/README.md)
