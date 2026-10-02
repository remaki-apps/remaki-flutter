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

echo "=== Building Flutter Web Release ==="
flutter build web --release

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

