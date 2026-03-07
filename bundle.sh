#!/bin/bash
set -e

BIN_NAME="mdview"
APP_NAME="MdViewer"
APP_DIR="target/release/${APP_NAME}.app"

echo "Building release..."
cargo build --release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "target/release/${BIN_NAME}" "$APP_DIR/Contents/MacOS/${BIN_NAME}"

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
    <string>10.15</string>
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

echo "Done! App bundle at: $APP_DIR"
echo ""
echo "To install: cp -r \"$APP_DIR\" /Applications/"
echo "To run:     open \"$APP_DIR\" --args /path/to/file.md"
