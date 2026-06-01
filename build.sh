#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeMonitor"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
SOURCES="$PROJECT_DIR/Sources"

echo "Building ClaudeMonitor..."

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

swiftc \
    "$SOURCES/Types.swift" \
    "$SOURCES/SystemMonitor.swift" \
    "$SOURCES/ProcessDetector.swift" \
    "$SOURCES/MenuBuilder.swift" \
    "$SOURCES/MenuBarController.swift" \
    "$SOURCES/main.swift" \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework AppKit \
    -framework Foundation \
    -O \
    -whole-module-optimization

cp "$PROJECT_DIR/Info.plist" "$CONTENTS/Info.plist"

if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    mkdir -p "$CONTENTS/Resources"
    cp "$PROJECT_DIR/AppIcon.icns" "$CONTENTS/Resources/"
fi

echo "Built: $APP_BUNDLE"
echo ""
echo "Run: open '$APP_BUNDLE'"
