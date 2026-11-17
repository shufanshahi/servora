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

## How sign-in works

- **One source of truth.** `core/session/` owns who is signed in (`SessionNotifier`: unknown,
  authenticated, or unauthenticated). The router redirect and the API client both read it, so
  they can never disagree.
- **Persistent session.** After login or registration the token, its expiry and the user are saved
  with `flutter_secure_storage` (Android Keystore-backed), never in plain preferences. On launch the
  app reads them, shows a splash screen briefly, then goes straight to Home, or to the sign-in
  screen if nothing valid is saved.
- **Expiry.** A saved token that has expired is deleted on launch and the sign-in screen explains
  "Your session has expired". If the server rejects a token that a request carried (HTTP 401) the
  session is cleared and the user is returned to sign-in with the same message. A *failed login*
  (wrong password) never signs anyone out: it carries no token.
- **Logout** removes the token and cached user from the device and replaces the navigation stack,
  so Back cannot return to a signed-in screen.
- **Forms** validate with the same rules and wording as the API (`AuthValidators`), show server
  messages on the right field (for example "An account with this email already exists" under
  Email), block double submits, and keep what was typed when a request fails or the device is
  offline.
- **No refresh token** (see the trade-off in [../backend/README.md](../backend/README.md)): a token
  lasts 7 days, and the user simply signs in again after that.

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

The first build downloads Gradle and the Android dependencies and can take a long time; later
builds are much faster. Install the APK on a device or emulator with
`adb install -r build/app/outputs/flutter-apk/app-release.apk`.

## Project layout

```
lib/
  main.dart  app.dart
  core/
    config/    AppConfig (API_BASE_URL)
    network/   dio client, envelope parsing, failure mapping
    session/   who is signed in: session state, secure token store
    error/     AppFailure: the one error type the UI sees
    router/    go_router, bottom-navigation shell, auth redirect
    theme/     colours, spacing, ThemeData
    layout/    responsive helpers
    widgets/   shared buttons, fields, cards, status badge, loading/empty/error views
  features/    one folder per feature: data/ domain/ presentation/
test/
tool/          small developer scripts
```
