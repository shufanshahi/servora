# Servora app

The Flutter client for Servora (Android application id `com.servora.app`).

Built with Flutter, Riverpod (state), go_router (navigation) and dio (HTTP). Screens depend
on providers, providers on repositories, and repositories on one API client.

## Prerequisites

- Flutter 3.50 or newer (`flutter --version`)
- Android SDK with an emulator or a physical Android device (`flutter doctor`)
- The backend running (see [../backend/README.md](../backend/README.md) or run
  `docker compose up --build` from the repository root)

## Setup and run

```bash
cd frontend
flutter pub get
flutter run                      # uses the emulator-friendly default API URL
```

## Pointing the app at the API

The API address is a build-time setting, passed with `--dart-define`. It is **not** a secret;
anything compiled into an app can be extracted, so never put keys here. (The AI provider key
lives only on the backend.)

| Where the app runs | `API_BASE_URL` | How |
|---|---|---|
| Android emulator | `http://10.0.2.2:3000` (the default) | `flutter run` |
| Physical device on the same Wi-Fi | `http://<your-computer-LAN-IP>:3000` | `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000` |
| Hosted backend | `https://<your-host>` | `flutter build apk --release --dart-define=API_BASE_URL=https://<your-host>` |

Why `10.0.2.2`: inside the Android emulator, `localhost` is the emulator itself. Android maps
the special address `10.0.2.2` to your computer, where the backend listens on port 3000.

For a physical device, find your computer's LAN address (for example `hostname -I`) and make
sure the phone is on the same network and no firewall blocks port 3000.

### Check the API is reachable first

A tiny script uses the app's own HTTP client to call `/health`, so you can test an address
before running the app:

```bash
dart run tool/check_api.dart                          # default: http://10.0.2.2:3000
dart run tool/check_api.dart http://192.168.1.20:3000
```

(`10.0.2.2` only resolves inside the Android emulator, so on your computer use `localhost`
or the LAN address.)

## Tests and checks

```bash
flutter analyze
flutter test
```

## Build the APK

With the Android SDK installed:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<your-host>
# -> build/app/outputs/flutter-apk/app-release.apk
```

Or with only Docker (no Flutter or Android SDK needed; the first run downloads the toolchain,
several GB, and is slow):

```bash
cd frontend
docker compose --profile apk run --rm apk-builder
API_BASE_URL=https://<your-host> docker compose --profile apk run --rm apk-builder
# -> out/app-release.apk
```

The same command works from the repository root. The builder is opt-in: a plain
`docker compose up` never starts it.

## Project layout

```
lib/
  main.dart  app.dart
  core/
    config/    AppConfig (API_BASE_URL)
    network/   dio client, envelope parsing, failure mapping
    error/     AppFailure: the one error type the UI sees
    router/    go_router, bottom-navigation shell, auth redirect
    theme/     colours, spacing, ThemeData
    layout/    responsive helpers
    widgets/   shared buttons, fields, cards, status badge, loading/empty/error views
  features/    one folder per feature: data/ domain/ presentation/
test/
tool/          small developer scripts
```
