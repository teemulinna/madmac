#!/bin/bash
set -euo pipefail

# MadMac build script — works with CommandLineTools (no Xcode.app needed)
# Creates a proper .app bundle with Info.plist and Resources

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/MadMac.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building MadMac..."

# 1. Build CM6 editor bundle (if not already built)
EDITOR_JS="$PROJECT_ROOT/madmac-app/Resources/editor/editor.js"
if [ ! -f "$EDITOR_JS" ] || [ "$EDITOR_JS" -ot "$PROJECT_ROOT/madmac-editor/src/editor.ts" ]; then
    echo "  -> Building CM6 editor bundle..."
    cd "$PROJECT_ROOT/madmac-editor"
    npm run build
fi

# 2. Compile Swift sources
echo "  -> Compiling Swift..."
SWIFT_FILES=$(find "$PROJECT_ROOT/madmac-app/Sources" -name '*.swift' -type f)
mkdir -p "$MACOS"

swiftc \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework AppKit \
    -framework WebKit \
    -framework UniformTypeIdentifiers \
    -O \
    -o "$MACOS/MadMac" \
    $SWIFT_FILES

# 3. Create .app bundle structure
echo "  -> Creating app bundle..."
mkdir -p "$RESOURCES/editor"

# Copy Info.plist
cp "$PROJECT_ROOT/madmac-app/Info.plist" "$CONTENTS/Info.plist"

# Copy editor resources
cp "$PROJECT_ROOT/madmac-app/Resources/editor/editor.js" "$RESOURCES/editor/editor.js"
[ -f "$PROJECT_ROOT/madmac-app/Resources/editor/editor.js.map" ] && \
    cp "$PROJECT_ROOT/madmac-app/Resources/editor/editor.js.map" "$RESOURCES/editor/editor.js.map"

# Copy KaTeX fonts (required for math rendering)
if [ -d "$PROJECT_ROOT/madmac-editor/node_modules/katex/dist/fonts" ]; then
    mkdir -p "$RESOURCES/editor/fonts"
    cp "$PROJECT_ROOT/madmac-editor/node_modules/katex/dist/fonts/"*.woff2 "$RESOURCES/editor/fonts/"
fi

# Copy PDF export presets
if [ -d "$PROJECT_ROOT/madmac-app/Resources/presets" ]; then
    mkdir -p "$RESOURCES/presets"
    cp "$PROJECT_ROOT/madmac-app/Resources/presets/"*.typ "$RESOURCES/presets/"
fi

# Copy app icon
if [ -f "$PROJECT_ROOT/madmac-app/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/madmac-app/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# 4. Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# 5. Sign with ad-hoc signature (needed for WKWebView)
echo "  -> Signing (ad-hoc)..."
codesign --force --sign - --entitlements /dev/stdin "$APP_BUNDLE" <<ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

echo "==> Build complete: $APP_BUNDLE"
echo "    Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "    Run with: open $APP_BUNDLE"
echo "    Test with: open -a $APP_BUNDLE /path/to/file.md"
