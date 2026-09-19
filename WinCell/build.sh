#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/build/WinCell.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" Sources/main.swift -o "$APP/Contents/MacOS/WinCell" -framework AppKit -framework AVFoundation -framework Carbon
# Builds contain code only. All media is loaded from the user's library at runtime.
rm -rf "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Resources"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WinCell</string>
<key>CFBundleIdentifier</key><string>local.wincell.menubar</string>
<key>CFBundleName</key><string>WinCell</string>
<key>CFBundleDisplayName</key><string>WinCell</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
