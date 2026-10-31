#!/usr/bin/env bash
set -e

FLUTTER_DIR="$HOME/flutter"

echo "=== Checking Flutter SDK ==="
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Cloning Flutter SDK (stable channel)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  echo "Flutter SDK already exists in $FLUTTER_DIR."
fi

# Add Flutter and Dart binaries to PATH
export PATH="$FLUTTER_DIR/bin:$PATH"

echo "=== Flutter Version ==="
flutter --version

echo "=== Enabling Web Support ==="
flutter config --enable-web

echo "=== Getting Packages ==="
flutter pub get

echo "=== Detecting Target Environment ==="
GIT_BRANCH="${VERCEL_GIT_COMMIT_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}"
echo "Current Branch / Commit Ref: $GIT_BRANCH"

echo "=== Building Flutter Web Release ==="
if [ "$GIT_BRANCH" = "qa" ] || [ "$ENV" = "qa" ] || [[ "$GIT_BRANCH" == *"qa"* ]]; then
  echo "Targeting QA environment (-t lib/main_qa.dart --dart-define=ENV=qa)..."
  flutter build web --release -t lib/main_qa.dart --dart-define=ENV=qa
else
  echo "Targeting standard environment (-t lib/main.dart)..."
  flutter build web --release -t lib/main.dart
fi

echo "=== Ensuring custom flutter_service_worker.js is in place ==="
if [ -f "web/flutter_service_worker.js" ]; then
  cp web/flutter_service_worker.js build/web/flutter_service_worker.js || true
fi

echo "=== Generating version.json for auto-update detection ==="
BUILD_TIME=$(date +%s%3N)
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "v1")
cat <<EOF > build/web/version.json
{
  "version": "$GIT_HASH",
  "buildTime": $BUILD_TIME,
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
echo "Generated version.json: buildTime=$BUILD_TIME, gitHash=$GIT_HASH"

echo "=== Cache busting main.dart.js in flutter_bootstrap.js ==="
if [ -f "build/web/flutter_bootstrap.js" ]; then
  sed -i "s/main\.dart\.js/main\.dart\.js?v=$BUILD_TIME/g" build/web/flutter_bootstrap.js 2>/dev/null || true
fi

echo "=== Injecting build version into index.html ==="
if [ -f "build/web/index.html" ]; then
  sed -i "s/%%REMAKI_BUILD_TIME%%/$BUILD_TIME/g" build/web/index.html 2>/dev/null || true
  sed -i "s/%%REMAKI_GIT_HASH%%/$GIT_HASH/g" build/web/index.html 2>/dev/null || true
fi

echo "=== Versioning service worker cache ==="
if [ -f "build/web/flutter_service_worker.js" ]; then
  sed -i "s/remaki-cache-v3/remaki-cache-$BUILD_TIME/g" build/web/flutter_service_worker.js 2>/dev/null || true
fi

