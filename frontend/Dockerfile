# syntax=docker/dockerfile:1
#
# Builds the Servora release APK inside a container, so nothing but Docker is needed.
# This is a build tool, not a server: running it writes app-release.apk to /out.
#
#   docker compose --profile apk run --rm apk-builder
#
# The heavy toolchain layers (Flutter, Android SDK) come first so they are cached;
# only the COPY of the app sources changes between builds.
FROM eclipse-temurin:21-jdk-noble

ARG FLUTTER_VERSION=3.50.0
ARG CMDLINE_TOOLS_VERSION=16111833
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK=28.2.13676358

ENV FLUTTER_HOME=/opt/flutter \
    ANDROID_HOME=/opt/android-sdk \
    PUB_CACHE=/root/.pub-cache \
    GRADLE_USER_HOME=/root/.gradle \
    CI=true
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH=$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl unzip xz-utils zip ca-certificates libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK, pinned to the version the app was developed with.
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
    && git config --global --add safe.directory "${FLUTTER_HOME}"

# Android command-line tools, then only the SDK pieces a release build needs.
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
       "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools" \
    && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses >/dev/null 2>&1 || true
RUN sdkmanager "platform-tools" "platforms/${ANDROID_PLATFORM}" "build-tools/${ANDROID_BUILD_TOOLS}" "ndk/${ANDROID_NDK}" \
    && flutter config --no-analytics --android-sdk "${ANDROID_HOME}" \
    && flutter precache --android

WORKDIR /app

# Resolve dependencies first so they are cached until pubspec changes.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter pub get --offline

# The API the built app will talk to. Override per build/run; the default reaches a
# backend on the host machine from the Android emulator.
ARG API_BASE_URL=http://10.0.2.2:3000
ENV API_BASE_URL=${API_BASE_URL}

COPY --chmod=755 docker-build-apk.sh /usr/local/bin/docker-build-apk.sh
ENTRYPOINT ["docker-build-apk.sh"]
