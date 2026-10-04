#!/bin/bash
# Build prntshot-notify.app — a tiny app that posts one notification.
#
# It must be a real .app bundle with its own bundle identifier: notifications
# posted from a bare script (or from Automator) are attributed to a process that
# never registers with the notification system, so the banner is dropped.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$ROOT/build/prntshot-notify.app"
BUNDLE_ID="com.prntshot.notify"

echo "==> Building $BUNDLE_ID"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

swiftc \
    -O \
    -target x86_64-apple-macosx13.0 \
    -framework Foundation \
    -framework UserNotifications \
    -o "$BUNDLE/Contents/MacOS/prntshot-notify" \
    "$ROOT/Sources/prntshot-notify.swift"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>prntshot-notify</string>
    <key>CFBundleDisplayName</key><string>prntshot</string>
    <key>CFBundleExecutable</key><string>prntshot-notify</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- No Dock icon, no menu bar: this only ever posts a notification. -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$BUNDLE" 2>&1 | sed 's/^/    /' || true

echo "Built: $BUNDLE"