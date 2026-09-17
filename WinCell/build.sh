#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f build.local.sh ]]; then source build.local.sh; fi
APP="$PWD/build/WinCell.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc Sources/main.swift -o "$APP/Contents/MacOS/WinCell" -framework AppKit -framework AVFoundation -framework Carbon
if [[ -n "${WINCELL_ORIGINAL_VIDEO:-}" ]]; then
  cp "$WINCELL_ORIGINAL_VIDEO" "$APP/Contents/Resources/WinCell.mov"
else
  rm -f "$APP/Contents/Resources/WinCell.mov"
fi
if [[ -n "${WINCELL_ORIGINAL_THUMBNAIL:-}" ]]; then
  cp "$WINCELL_ORIGINAL_THUMBNAIL" "$APP/Contents/Resources/OriginalThumbnail.png"
else
  rm -f "$APP/Contents/Resources/OriginalThumbnail.png"
fi
# Reconcile only the generated library so removed source clips do not linger.
mkdir -p "$APP/Contents/Resources/Videos"
VIDEO_DIR="${WINCELL_VIDEO_DIR:-../Finished Videos}"
if [[ -d "$VIDEO_DIR" ]]; then
rsync -a --delete --include='*/' --include='transparent.mov' --include='thumbnail.png' --exclude='*' \
  "$VIDEO_DIR/" "$APP/Contents/Resources/Videos/"
else
  rm -rf "$APP/Contents/Resources/Videos"
  mkdir -p "$APP/Contents/Resources/Videos"
  echo "No local video library found. Building without media."
fi
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
