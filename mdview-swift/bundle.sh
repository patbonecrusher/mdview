#!/bin/bash
set -e

APP="MdViewer.app"
CONTENTS="$APP/Contents"
SIGNING_IDENTITY="Developer ID Application: Patrick Laplante (VZU8A7CZL3)"

echo "==> Building release binary..."
swift build -c release 2>&1

echo "==> Generating app icon..."
swift generate_icon.swift
iconutil -c icns assets/mdview.iconset -o assets/mdview.icns

echo "==> Creating app bundle..."
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp .build/release/MdViewer "$CONTENTS/MacOS/mdview"
cp assets/mdview.icns "$CONTENTS/Resources/mdview.icns"

cat > "$CONTENTS/Info.plist" << 'PLIST'
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
    <string>13.0</string>
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

# Icon files stay in assets/ for reuse

# Sign if identity is available
if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    echo "==> Signing app..."
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" --deep "$APP"
    codesign -vvv "$APP"

    if [ "$1" = "--notarize" ]; then
        echo "==> Creating zip for notarization..."
        ditto -c -k --keepParent "$APP" MdViewer.zip

        echo "==> Submitting for notarization..."
        xcrun notarytool submit MdViewer.zip \
            --keychain-profile "notarize-profile" \
            --wait

        echo "==> Stapling notarization ticket..."
        xcrun stapler staple "$APP"

        rm -f MdViewer.zip
        echo ""
        echo "==> Done! App is signed, notarized, and stapled."
    else
        echo ""
        echo "==> Done! App is signed with Developer ID."
        echo "    To also notarize, run: ./bundle.sh --notarize"
    fi
else
    echo ""
    echo "==> Done! App bundle at: $APP (unsigned)"
fi

echo "    Run with: open $APP"
echo "    Or copy to /Applications: cp -r $APP /Applications/"
