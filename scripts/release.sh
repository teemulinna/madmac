#!/bin/bash
set -euo pipefail

# madmac release script — builds, packages, creates GitHub release
# Usage: ./scripts/release.sh 0.2.0

VERSION="${1:?Usage: $0 <version>}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/MadMac.app"
DMG_NAME="madmac-${VERSION}.dmg"
ZIP_NAME="madmac-${VERSION}.zip"

echo "==> Releasing madmac v${VERSION}"

# 1. Update version in Info.plist
echo "  -> Setting version to ${VERSION}..."
sed -i '' "s|<string>[0-9]*\.[0-9]*\.[0-9]*</string><!-- VERSION -->|<string>${VERSION}</string><!-- VERSION -->|" \
    "$PROJECT_ROOT/madmac-app/Info.plist" 2>/dev/null || true
# Also update CFBundleShortVersionString
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PROJECT_ROOT/madmac-app/Info.plist"

# 2. Build
echo "  -> Building..."
"$PROJECT_ROOT/scripts/build.sh"

# 3. Create zip
echo "  -> Creating ${ZIP_NAME}..."
cd "$BUILD_DIR"
rm -f "$ZIP_NAME"
ditto -c -k --keepParent MadMac.app "$ZIP_NAME"

# 4. Create DMG
echo "  -> Creating ${DMG_NAME}..."
rm -f "$DMG_NAME"
hdiutil create -volname "madmac" -srcfolder MadMac.app -ov -format UDZO "$DMG_NAME"

echo "  -> Artifacts:"
ls -lh "$BUILD_DIR/$DMG_NAME" "$BUILD_DIR/$ZIP_NAME"

# 5. Create GitHub release (if gh is available)
if command -v gh &>/dev/null; then
    echo "  -> Creating GitHub release v${VERSION}..."
    cd "$PROJECT_ROOT"
    gh release create "v${VERSION}" \
        "$BUILD_DIR/$DMG_NAME" \
        "$BUILD_DIR/$ZIP_NAME" \
        --title "madmac v${VERSION}" \
        --notes "## madmac v${VERSION}

### Installation
- **DMG**: Download \`${DMG_NAME}\`, open, drag to Applications
- **Zip**: Download \`${ZIP_NAME}\`, unzip, move to Applications
- **Homebrew**: \`brew install --cask teemulinna/tap/madmac\`
"
    echo "  -> Release created: https://github.com/teemulinna/madmac/releases/tag/v${VERSION}"
else
    echo "  -> gh CLI not found. Upload manually:"
    echo "     $BUILD_DIR/$DMG_NAME"
    echo "     $BUILD_DIR/$ZIP_NAME"
fi

echo "==> Done!"
