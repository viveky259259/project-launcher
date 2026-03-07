#!/bin/bash
set -e

# ─── Load .env ───
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "ERROR: .env file not found. Create one from .env.example"
  exit 1
fi

# ─── Configuration ───
APP_NAME="Project Launcher"
BUNDLE_ID="com.stringswaytech.projectbrowser"
SIGNING_IDENTITY="Developer ID Application: Vivek Yadav (${TEAM_ID})"
KEYCHAIN_PROFILE="ProjectLauncherNotarize"

# Read version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/${APP_NAME// /}.zip"
DMG_PATH="build/${APP_NAME// /}-${VERSION}.dmg"

echo "══════════════════════════════════════════════"
echo "  $APP_NAME v$VERSION — Release Build"
echo "══════════════════════════════════════════════"
echo ""

# ─── Step 0: Store credentials in keychain ───
echo "▸ Step 0/7: Storing notarization credentials in keychain..."
xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  2>/dev/null || true
echo "  ✓ Credentials stored as '$KEYCHAIN_PROFILE'"
echo ""

# ─── Step 1: Clean & Build ───
echo "▸ Step 1/7: Cleaning and building macOS app..."
flutter clean
flutter pub get
flutter build macos --release \
  --dart-define=PADDLE_API_KEY="$PADDLE_API_KEY" \
  --dart-define=PADDLE_IS_SANDBOX="$PADDLE_IS_SANDBOX"
echo "  ✓ Built $APP_PATH"
echo ""

# ─── Step 2: Code Sign ───
echo "▸ Step 2/7: Code signing app bundle..."
# Sign all nested frameworks and dylibs first, then the app
find "$APP_PATH/Contents/Frameworks" -type f -name "*.dylib" -exec \
  codesign --force --verify --verbose --options runtime \
  --sign "$SIGNING_IDENTITY" {} \;

find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" -exec \
  codesign --force --verify --verbose --options runtime \
  --sign "$SIGNING_IDENTITY" {} \;

# Sign the main app bundle
codesign --deep --force --verify --verbose \
  --options runtime \
  --sign "$SIGNING_IDENTITY" \
  "$APP_PATH"
echo "  ✓ Signed with: $SIGNING_IDENTITY"
echo ""

# ─── Step 3: Verify Signature ───
echo "▸ Step 3/7: Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -2
spctl --assess --type exec --verbose "$APP_PATH" 2>&1 || true
echo "  ✓ Signature verified"
echo ""

# ─── Step 4: Notarize App ───
echo "▸ Step 4/7: Creating ZIP and submitting for notarization..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo "  Uploading $ZIP_SIZE..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
echo "  ✓ Notarization accepted"
echo ""

# ─── Step 5: Staple ───
echo "▸ Step 5/7: Stapling notarization ticket to app..."
xcrun stapler staple "$APP_PATH"
echo "  ✓ Ticket stapled"
echo ""

# ─── Step 6: Create DMG ───
echo "▸ Step 6/7: Creating DMG installer..."
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
echo ""

# ─── Step 7: Sign & Notarize DMG ───
echo "▸ Step 7/7: Signing and notarizing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
xcrun stapler staple "$DMG_PATH"
echo "  ✓ DMG signed, notarized, and stapled"
echo ""

# ─── Cleanup ───
rm -f "$ZIP_PATH"

# ─── Summary ───
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo "══════════════════════════════════════════════"
echo "  Release complete!"
echo ""
echo "  App:      $APP_NAME"
echo "  Version:  $VERSION"
echo "  Bundle:   $BUNDLE_ID"
echo "  App size: $APP_SIZE"
echo "  DMG:      $DMG_PATH ($DMG_SIZE)"
echo ""
echo "  Signed:       ✓"
echo "  Notarized:    ✓"
echo "  Stapled:      ✓"
echo "  Ready to distribute!"
echo "══════════════════════════════════════════════"
