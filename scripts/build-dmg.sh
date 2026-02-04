#!/bin/bash

# Build DMG for Project Launcher

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Project Launcher"
DMG_NAME="ProjectLauncher"
VERSION=$(grep 'version:' "$PROJECT_DIR/pubspec.yaml" | sed 's/version: //' | sed 's/+.*//')

echo "=== Building Project Launcher v$VERSION ==="
echo ""

# Build the Flutter app
echo "Building macOS app..."
cd "$PROJECT_DIR"
flutter build macos --release

APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Create a temporary directory for DMG contents
DMG_DIR="$PROJECT_DIR/build/dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy the app
echo "Copying app to DMG staging area..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create CLI installer script
cat > "$DMG_DIR/Install CLI.command" << 'INSTALLER'
#!/bin/bash

INSTALL_DIR="/usr/local/bin"

echo "Installing 'addproject' command..."

cat > /tmp/addproject << 'ADDPROJECT'
#!/bin/bash

CONFIG_DIR="$HOME/.project_launcher"
CONFIG_FILE="$CONFIG_DIR/projects.json"

if [ -n "$1" ]; then
    if [[ "$1" = /* ]]; then
        TARGET_DIR="$1"
    else
        TARGET_DIR="$(cd "$1" 2>/dev/null && pwd)"
        if [ -z "$TARGET_DIR" ]; then
            echo "Error: Directory does not exist: $1"
            exit 1
        fi
    fi
else
    TARGET_DIR=$(pwd)
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory does not exist: $TARGET_DIR"
    exit 1
fi

PROJECT_NAME=$(basename "$TARGET_DIR")
ADDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[]" > "$CONFIG_FILE"
fi

python3 << PYEOF
import json
config_file = "$CONFIG_FILE"
target_dir = "$TARGET_DIR"
project_name = "$PROJECT_NAME"
added_at = "$ADDED_AT"

try:
    with open(config_file, 'r') as f:
        projects = json.load(f)
except:
    projects = []

for p in projects:
    if p.get('path') == target_dir:
        print(f"Project already exists: {project_name}")
        print(f"  Path: {target_dir}")
        exit(0)

projects.append({"name": project_name, "path": target_dir, "addedAt": added_at})

with open(config_file, 'w') as f:
    json.dump(projects, f, indent=2)

print(f"Added project: {project_name}")
print(f"  Path: {target_dir}")
PYEOF
ADDPROJECT

if [ -w "$INSTALL_DIR" ]; then
    mv /tmp/addproject "$INSTALL_DIR/addproject"
    chmod +x "$INSTALL_DIR/addproject"
else
    sudo mv /tmp/addproject "$INSTALL_DIR/addproject"
    sudo chmod +x "$INSTALL_DIR/addproject"
fi

echo ""
echo "Done! 'addproject' command installed."
echo ""
echo "Usage:"
echo "  addproject           - Add current directory"
echo "  addproject /path     - Add specific path"
echo ""
read -p "Press Enter to close..."
INSTALLER

chmod +x "$DMG_DIR/Install CLI.command"

# Create the DMG
OUTPUT_DMG="$PROJECT_DIR/build/$DMG_NAME-$VERSION.dmg"
rm -f "$OUTPUT_DMG"

echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$OUTPUT_DMG"

# Clean up
rm -rf "$DMG_DIR"

echo ""
echo "=== Build Complete ==="
echo "DMG: $OUTPUT_DMG"
echo "Size: $(du -h "$OUTPUT_DMG" | cut -f1)"
