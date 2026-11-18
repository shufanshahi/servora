# syntax=docker/dockerfile:1

# Servora web app: the Flutter app compiled for the browser and served by nginx.
# (The Android app is built with the Flutter toolchain; see README.md.)

# ---- build stage: Flutter SDK + `flutter build web` ----
FROM debian:12-slim AS build

# Keep this in step with the Flutter version the app is developed against.
ARG FLUTTER_VERSION=3.50.0
# Address of the Servora API *as seen from the user's browser* (not from inside Docker).
ARG API_BASE_URL=http://localhost:3000

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app
# Dependencies first so they are cached until pubspec changes.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- runtime stage: static files only ----
FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=5s \
    CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
