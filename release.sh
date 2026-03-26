#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════
#  Project Launcher — Unified Release Pipeline
#
#  Usage:
#    ./release.sh patch                  # 2.2.1+6 → 2.2.2+7
#    ./release.sh minor                  # 2.2.1+6 → 2.3.0+7
#    ./release.sh major                  # 2.2.1+6 → 3.0.0+7
#    ./release.sh patch --dry-run        # Preview without executing
#    ./release.sh patch --yes            # Skip confirmation prompt
#    ./release.sh minor --notes "..."    # Manual changelog
# ═══════════════════════════════════════════════════════════════

BUMP_TYPE=""
DRY_RUN=false
AUTO_YES=false
CUSTOM_NOTES=""

# ─── Parse arguments ───
while [[ $# -gt 0 ]]; do
  case "$1" in
    patch|minor|major) BUMP_TYPE="$1"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) AUTO_YES=true; shift ;;
    --notes) CUSTOM_NOTES="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./release.sh <patch|minor|major> [--dry-run] [--yes] [--notes \"...\"]"
      echo ""
      echo "Arguments:"
      echo "  patch|minor|major   Version bump type (required)"
      echo "  --dry-run           Preview the release without executing"
      echo "  --yes, -y           Skip confirmation prompt"
      echo "  --notes \"...\"       Custom release notes (default: auto from commits)"
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$BUMP_TYPE" ]; then
  echo "ERROR: Bump type required. Usage: ./release.sh <patch|minor|major>"
  exit 1
fi

# ─── Phase 1: PREPARE ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 1/8: PREPARE"
echo "══════════════════════════════════════════════════"

# Load .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep -v '^$' | xargs)
else
  echo "ERROR: .env file not found. Create one from .env.example"
  exit 1
fi

# Validate required env vars
REQUIRED_VARS="APPLE_ID TEAM_ID APP_SPECIFIC_PASSWORD"
for var in $REQUIRED_VARS; do
  if [ -z "${!var}" ]; then
    echo "ERROR: Missing required env var: $var"
    exit 1
  fi
done

# Validate tools
for cmd in flutter gh codesign xcrun hdiutil; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required command not found: $cmd"
    exit 1
  fi
done

# Validate gh auth
if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

# Validate clean git tree
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: Git working tree is dirty. Commit or stash changes first."
  git status --short
  exit 1
fi

echo "  ✓ Environment validated"

# ─── Phase 2: VERSION ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 2/8: VERSION"
echo "══════════════════════════════════════════════════"

# Read current version
CURRENT_VERSION_LINE=$(grep '^version:' pubspec.yaml)
CURRENT_VERSION=$(echo "$CURRENT_VERSION_LINE" | sed 's/version: //' | sed 's/+.*//')
CURRENT_BUILD=$(echo "$CURRENT_VERSION_LINE" | sed 's/.*+//')

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Calculate new version
case "$BUMP_TYPE" in
  patch) NEW_PATCH=$((PATCH + 1)); NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH" ;;
  minor) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
  major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
esac
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "  Current: $CURRENT_VERSION+$CURRENT_BUILD"
echo "  New:     $NEW_VERSION+$NEW_BUILD ($BUMP_TYPE bump)"

# ─── Configuration ───
APP_NAME="Project Launcher"
BUNDLE_ID="com.stringswaytech.projectbrowser"
SIGNING_IDENTITY="Developer ID Application: Vivek Yadav (${TEAM_ID})"
KEYCHAIN_PROFILE="ProjectLauncherNotarize"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/${APP_NAME// /}.zip"
DMG_PATH="build/${APP_NAME// /}-${NEW_VERSION}.dmg"
TAG="v$NEW_VERSION"

# Generate changelog
if [ -n "$CUSTOM_NOTES" ]; then
  RELEASE_NOTES="$CUSTOM_NOTES"
else
  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
  if [ -n "$LAST_TAG" ]; then
    RELEASE_NOTES=$(git log "$LAST_TAG"..HEAD --oneline --no-merges 2>/dev/null || echo "Release $TAG")
  else
    RELEASE_NOTES="Initial release $TAG"
  fi
fi

# ─── Dry run output ───
if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "══════════════════════════════════════════════════"
  echo "  DRY RUN — Nothing will be executed"
  echo "══════════════════════════════════════════════════"
  echo ""
  echo "  Version:  $CURRENT_VERSION+$CURRENT_BUILD → $NEW_VERSION+$NEW_BUILD"
  echo "  Tag:      $TAG"
  echo "  DMG:      $DMG_PATH"
  echo "  Signing:  $SIGNING_IDENTITY"
  echo ""
  echo "  Release notes:"
  echo "$RELEASE_NOTES" | sed 's/^/    /'
  echo ""
  echo "  Pipeline: version → build → sign → notarize → package → publish → homebrew"
  exit 0
fi

# ─── Confirmation ───
if [ "$AUTO_YES" != true ]; then
  echo ""
  echo "  Release notes:"
  echo "$RELEASE_NOTES" | sed 's/^/    /'
  echo ""
  read -p "  Proceed with release $TAG? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
  fi
fi

# Update pubspec.yaml
sed -i '' "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml
echo "  ✓ pubspec.yaml updated to $NEW_VERSION+$NEW_BUILD"

# Git commit and tag
git add pubspec.yaml
git commit -m "release: v$NEW_VERSION"
git tag "$TAG"
echo "  ✓ Git commit and tag $TAG created"

# ─── Phase 3: BUILD ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 3/8: BUILD"
echo "══════════════════════════════════════════════════"

echo "  ▸ Storing notarization credentials..."
xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  2>/dev/null || true

echo "  ▸ Building Rust library (universal binary)..."
cd rust
cargo build --release --target x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin
mkdir -p target/universal-apple-darwin/release
lipo -create \
  target/x86_64-apple-darwin/release/libproject_launcher_core.dylib \
  target/aarch64-apple-darwin/release/libproject_launcher_core.dylib \
  -output target/universal-apple-darwin/release/libproject_launcher_core.dylib
cd ..
echo "  ✓ Rust universal binary built"

echo "  ▸ Building Flutter macOS app..."
flutter clean
flutter pub get
flutter build macos --release \
  --dart-define=PADDLE_API_KEY="$PADDLE_API_KEY" \
  --dart-define=PADDLE_IS_SANDBOX="$PADDLE_IS_SANDBOX"
echo "  ✓ Flutter app built"

echo "  ▸ Copying native library to app bundle..."
mkdir -p "$APP_PATH/Contents/Frameworks"
cp rust/target/universal-apple-darwin/release/libproject_launcher_core.dylib \
   "$APP_PATH/Contents/Frameworks/"
echo "  ✓ Native library bundled"

# ─── Phase 4: SIGN ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 4/8: SIGN"
echo "══════════════════════════════════════════════════"

echo "  ▸ Signing nested frameworks and dylibs..."
find "$APP_PATH/Contents/Frameworks" -type f -name "*.dylib" -exec \
  codesign --force --verify --verbose --options runtime \
  --sign "$SIGNING_IDENTITY" {} \;

find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" -exec \
  codesign --force --verify --verbose --options runtime \
  --sign "$SIGNING_IDENTITY" {} \;

echo "  ▸ Signing main app bundle..."
codesign --deep --force --verify --verbose \
  --options runtime \
  --sign "$SIGNING_IDENTITY" \
  "$APP_PATH"
echo "  ✓ Signed with: $SIGNING_IDENTITY"

# ─── Phase 5: VERIFY ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 5/8: VERIFY"
echo "══════════════════════════════════════════════════"

codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -2
spctl --assess --type exec --verbose "$APP_PATH" 2>&1 || true
echo "  ✓ Signature verified"

# ─── Phase 6: NOTARIZE ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 6/8: NOTARIZE"
echo "══════════════════════════════════════════════════"

echo "  ▸ Creating ZIP for notarization..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

echo "  ▸ Submitting app for notarization ($ZIP_SIZE)..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
echo "  ✓ App notarization accepted"

echo "  ▸ Stapling ticket to app..."
xcrun stapler staple "$APP_PATH"
echo "  ✓ App stapled"

# ─── Phase 7: PACKAGE ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 7/8: PACKAGE"
echo "══════════════════════════════════════════════════"

echo "  ▸ Creating DMG..."
DMG_STAGING=$(mktemp -d)
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -sf /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"
rm -rf "$DMG_STAGING"
echo "  ✓ DMG created"

echo "  ▸ Signing and notarizing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
xcrun stapler staple "$DMG_PATH"
echo "  ✓ DMG signed, notarized, and stapled"

# Cleanup notarization ZIP
rm -f "$ZIP_PATH"

# ─── Phase 8: PUBLISH ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 8/8: PUBLISH"
echo "══════════════════════════════════════════════════"

echo "  ▸ Pushing commit and tag to origin..."
git push origin HEAD
git push origin "$TAG"
echo "  ✓ Pushed $TAG"

echo "  ▸ Creating GitHub Release..."
gh release create "$TAG" \
  --title "$TAG" \
  --notes "$RELEASE_NOTES" \
  "$DMG_PATH"
RELEASE_URL="https://github.com/viveky259259/project-launcher/releases/tag/$TAG"
echo "  ✓ GitHub Release created: $RELEASE_URL"

echo "  ▸ Updating Homebrew tap..."
TAP_DIR=$(mktemp -d)
gh repo clone viveky259259/homebrew-project-launcher "$TAP_DIR" -- --quiet
DMG_SHA=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
sed -i '' "s/version \".*\"/version \"$NEW_VERSION\"/" "$TAP_DIR/Casks/project-launcher.rb"
sed -i '' "s/sha256 \".*\"/sha256 \"$DMG_SHA\"/" "$TAP_DIR/Casks/project-launcher.rb"
cd "$TAP_DIR"
git add -A
git commit -m "Update project-launcher to $NEW_VERSION"
git push origin main
cd -
rm -rf "$TAP_DIR"
echo "  ✓ Homebrew tap updated to $NEW_VERSION (sha256: ${DMG_SHA:0:12}...)"

# ─── Summary ───
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo ""
echo "══════════════════════════════════════════════════"
echo "  Release complete!"
echo ""
echo "  App:      $APP_NAME"
echo "  Version:  $NEW_VERSION+$NEW_BUILD"
echo "  Bundle:   $BUNDLE_ID"
echo "  App size: $APP_SIZE"
echo "  DMG:      $DMG_PATH ($DMG_SIZE)"
echo ""
echo "  Signed:       ✓"
echo "  Notarized:    ✓"
echo "  Stapled:      ✓"
echo "  Published:    ✓  $RELEASE_URL"
echo "  Homebrew:     ✓  brew tap viveky259259/project-launcher"
echo "══════════════════════════════════════════════════"
