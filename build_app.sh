#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p Resources
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "🎨 Generating Naval Command AppIcon.icns..."
    swift scripts/generate_icon.swift
    iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
    rm -rf Resources/AppIcon.iconset
fi

echo "🔨 Building Battleship (Release)..."
swift build -c release

APP_DIR="$SCRIPT_DIR/Battleship.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/Battleship" "$MACOS_DIR/Battleship"
cp "Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
chmod +x "$MACOS_DIR/Battleship"

codesign --force --deep --sign - --identifier "com.battleship.command.mac" "$APP_DIR"

echo "✅ Packaged $APP_DIR"
