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
