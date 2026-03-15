#!/bin/bash

# Build, sign, bundle FFI, and install Project Launcher to /Applications
# Usage: ./scripts/install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Project Launcher"
SIGN_IDENTITY="Developer ID Application: Vivek Yadav (CU3457GT8T)"
DYLIB_NAME="libproject_launcher_core.dylib"
RUST_DIR="$PROJECT_DIR/rust"
DYLIB_SRC="$RUST_DIR/target/release/$DYLIB_NAME"

cd "$PROJECT_DIR"

# --- Step 1: Build Rust FFI library if needed ---
if [ ! -f "$DYLIB_SRC" ]; then
    echo "==> Building Rust FFI library..."
    cd "$RUST_DIR"
    cargo build --release
    cd "$PROJECT_DIR"
elif [ -n "$(find "$RUST_DIR/src" -newer "$DYLIB_SRC" 2>/dev/null)" ]; then
    echo "==> Rust sources changed, rebuilding FFI library..."
    cd "$RUST_DIR"
    cargo build --release
    cd "$PROJECT_DIR"
else
    echo "==> Rust FFI library up to date"
fi

# --- Step 2: Build Flutter macOS release ---
echo "==> Building Flutter macOS release..."
flutter build macos --release

APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    exit 1
fi

# --- Step 3: Bundle Rust FFI dylib ---
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

if [ -f "$DYLIB_SRC" ]; then
    echo "==> Bundling Rust FFI library..."
    cp "$DYLIB_SRC" "$FRAMEWORKS_DIR/"
else
    echo "WARNING: Rust FFI library not found, app will use Dart fallbacks"
fi

# --- Step 4: Code sign ---
echo "==> Signing app..."

# Sign the dylib first
if [ -f "$FRAMEWORKS_DIR/$DYLIB_NAME" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "$FRAMEWORKS_DIR/$DYLIB_NAME"
fi

# Sign the full app bundle with entitlements
codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime \
    --entitlements "$PROJECT_DIR/macos/Runner/Release.entitlements" "$APP_PATH"

# Verify
codesign --verify --deep --strict "$APP_PATH" 2>/dev/null
echo "    Signature verified OK"

# --- Step 5: Kill existing app if running ---
if pgrep -f "$APP_NAME" > /dev/null 2>&1; then
    echo "==> Stopping running instance..."
    pkill -f "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# --- Step 6: Install to /Applications ---
echo "==> Installing to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_PATH" "/Applications/$APP_NAME.app"

# --- Step 7: Launch ---
echo "==> Launching..."
open "/Applications/$APP_NAME.app"

echo ""
echo "=== Done ==="
echo "Installed: /Applications/$APP_NAME.app"
