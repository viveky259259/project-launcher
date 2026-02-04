#!/bin/bash

# Project Launcher Installer
# This script installs the addproject command and optionally the app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
APP_INSTALL_DIR="/Applications"

echo "=== Project Launcher Installer ==="
echo ""

# Install addproject command
echo "Installing 'addproject' command..."
if [ -w "$INSTALL_DIR" ]; then
    cp "$SCRIPT_DIR/scripts/addproject" "$INSTALL_DIR/addproject"
    chmod +x "$INSTALL_DIR/addproject"
else
    sudo cp "$SCRIPT_DIR/scripts/addproject" "$INSTALL_DIR/addproject"
    sudo chmod +x "$INSTALL_DIR/addproject"
fi
echo "✓ 'addproject' command installed to $INSTALL_DIR"

# Install the app
echo ""
echo "Installing Project Launcher app..."
APP_PATH="$SCRIPT_DIR/build/macos/Build/Products/Release/project_launcher.app"

if [ -d "$APP_PATH" ]; then
    if [ -d "$APP_INSTALL_DIR/Project Launcher.app" ]; then
        rm -rf "$APP_INSTALL_DIR/Project Launcher.app"
    fi
    cp -R "$APP_PATH" "$APP_INSTALL_DIR/Project Launcher.app"
    echo "✓ App installed to $APP_INSTALL_DIR/Project Launcher.app"
else
    echo "⚠ App not built yet. Run 'flutter build macos' first."
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  1. Open 'Project Launcher' from Applications"
echo "  2. In any terminal, navigate to a project and run 'addproject'"
echo "  3. The project will appear in the app automatically"
echo ""
