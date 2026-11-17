#!/bin/sh
set -e

: "${API_BASE_URL:?API_BASE_URL must be set}"
echo "Building Servora release APK for API: ${API_BASE_URL}"

flutter build apk --release --dart-define=API_BASE_URL="${API_BASE_URL}"

mkdir -p /out
cp build/app/outputs/flutter-apk/app-release.apk /out/app-release.apk
# The container runs as root; make the file usable by the host user.
chmod a+rw /out/app-release.apk
echo "APK written to out/app-release.apk"
