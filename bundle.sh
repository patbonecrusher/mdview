#!/bin/bash
set -e

BIN_NAME="mdview"
APP_NAME="MdViewer"
SIGNING_IDENTITY="Developer ID Application: Patrick Laplante (VZU8A7CZL3)"

# Support CI: use target dir if BINARY_PATH is set, otherwise build locally
if [ -n "$BINARY_PATH" ]; then
    APP_DIR="${APP_NAME}.app"
    BINARY="$BINARY_PATH"
else
    echo "Building release..."
    cargo build --release
    APP_DIR="target/release/${APP_NAME}.app"
    BINARY="target/release/${BIN_NAME}"
fi

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_DIR/Contents/MacOS/${BIN_NAME}"

# Copy icon
cp "assets/mdview.icns" "$APP_DIR/Contents/Resources/mdview.icns"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MdViewer</string>
    <key>CFBundleDisplayName</key>
    <string>MdViewer</string>
    <key>CFBundleIdentifier</key>
    <string>com.mdviewer.app</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>mdview</string>
    <key>CFBundleIconFile</key>
    <string>mdview</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
            </array>
            <key>CFBundleTypeIconFile</key>
            <string>mdview</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Sign if identity is available
if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    echo "Signing app..."
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" --deep "$APP_DIR"
    codesign -vvv "$APP_DIR"

    if [ "$1" = "--notarize" ]; then
        echo "Creating zip for notarization..."
        ditto -c -k --keepParent "$APP_DIR" "${APP_NAME}.zip"

        echo "Submitting for notarization..."
        xcrun notarytool submit "${APP_NAME}.zip" \
            --keychain-profile "notarize-profile" \
            --wait

        echo "Stapling notarization ticket..."
        xcrun stapler staple "$APP_DIR"

        rm -f "${APP_NAME}.zip"
        echo ""
        echo "Done! App is signed, notarized, and stapled."
    else
        echo ""
        echo "Done! App is signed with Developer ID."
        echo "    To also notarize, run: ./bundle.sh --notarize"
    fi
else
    echo ""
    echo "Done! App bundle at: $APP_DIR (unsigned)"
fi

echo "    Run with: open $APP_DIR"
echo "    Install:  cp -r \"$APP_DIR\" /Applications/"
