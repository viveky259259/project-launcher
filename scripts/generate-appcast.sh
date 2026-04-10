#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════
#  Generate Sparkle appcast.xml from GitHub Releases
#
#  Usage:
#    ./scripts/generate-appcast.sh              # Generate from all releases
#    ./scripts/generate-appcast.sh v2.3.3       # Generate for a specific version
#
#  Prerequisites:
#    - gh CLI authenticated
#    - Sparkle EdDSA private key in Keychain (from generate_keys)
#    - sign_update tool from Sparkle pod
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SIGN_UPDATE="$PROJECT_DIR/macos/Pods/Sparkle/bin/sign_update"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"
GITHUB_REPO="viveky259259/project-launcher"
SPECIFIC_VERSION="${1:-}"

if [ ! -f "$SIGN_UPDATE" ]; then
  echo "ERROR: sign_update not found at $SIGN_UPDATE"
  echo "Run 'cd macos && pod install' first."
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

echo "Generating appcast.xml for $GITHUB_REPO..."

# Start XML
cat > "$APPCAST_FILE" <<'HEADER'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Project Launcher Updates</title>
    <link>https://raw.githubusercontent.com/viveky259259/project-launcher/main/appcast.xml</link>
    <description>Project Launcher release updates</description>
    <language>en</language>
HEADER

# Get releases (latest first)
if [ -n "$SPECIFIC_VERSION" ]; then
  RELEASES="$SPECIFIC_VERSION"
else
  RELEASES=$(gh release list --repo "$GITHUB_REPO" --limit 10 --json tagName --jq '.[].tagName')
fi

DOWNLOAD_DIR=$(mktemp -d)
trap "rm -rf $DOWNLOAD_DIR" EXIT

for TAG in $RELEASES; do
  VERSION="${TAG#v}"  # Strip leading 'v'
  echo "  Processing $TAG (version $VERSION)..."

  # Find DMG asset
  DMG_NAME=$(gh release view "$TAG" --repo "$GITHUB_REPO" --json assets --jq '.assets[].name' | grep -i '\.dmg$' | head -1)

  if [ -z "$DMG_NAME" ]; then
    echo "    ⚠ No DMG found for $TAG, skipping"
    continue
  fi

  DMG_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG/$DMG_NAME"

  # Download DMG to get size and signature
  DMG_PATH="$DOWNLOAD_DIR/$DMG_NAME"
  echo "    Downloading $DMG_NAME..."
  gh release download "$TAG" --repo "$GITHUB_REPO" --pattern "$DMG_NAME" --dir "$DOWNLOAD_DIR" --clobber

  # Get file size
  FILE_SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH" 2>/dev/null)

  # Sign with EdDSA (uses key from Keychain, stored by generate_keys)
  SIGNATURE=$("$SIGN_UPDATE" "$DMG_PATH" 2>/dev/null | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')

  if [ -z "$SIGNATURE" ]; then
    # Fallback: sign_update may just output the signature directly
    SIGNATURE=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1 | head -1)
  fi

  # Get release date
  PUB_DATE=$(gh release view "$TAG" --repo "$GITHUB_REPO" --json publishedAt --jq '.publishedAt')
  # Convert to RFC 2822 format
  PUB_DATE_RFC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$PUB_DATE" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null || echo "$PUB_DATE")

  # Get release notes
  RELEASE_NOTES=$(gh release view "$TAG" --repo "$GITHUB_REPO" --json body --jq '.body' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

  # Write item
  cat >> "$APPCAST_FILE" <<ITEM
    <item>
      <title>Version $VERSION</title>
      <description><![CDATA[$RELEASE_NOTES]]></description>
      <pubDate>$PUB_DATE_RFC</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
      <enclosure
        url="$DMG_URL"
        length="$FILE_SIZE"
        type="application/octet-stream"
        sparkle:edSignature="$SIGNATURE"
      />
    </item>
ITEM

  echo "    ✓ Added $TAG (${FILE_SIZE} bytes)"

  # Clean up downloaded DMG to save space
  rm -f "$DMG_PATH"
done

# Close XML
cat >> "$APPCAST_FILE" <<'FOOTER'
  </channel>
</rss>
FOOTER

echo ""
echo "✓ Appcast written to $APPCAST_FILE"
echo "  Commit and push to main to make it live."
