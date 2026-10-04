#!/bin/bash
# Install the prnt.li Quick Actions and their helper scripts.
#
# Quick Actions live in ~/Library/Services and are invoked either from
# Finder's right-click > Quick Actions, or from System Settings >
# Keyboard > Keyboard Shortcuts > Services.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$ROOT/build/workflows"
SERVICES="$HOME/Library/Services"
BIN="$HOME/.local/bin"

if [ ! -d "$STAGE" ]; then
    echo "Run ./make-workflows.sh first."
    exit 1
fi

echo "==> Installing helper scripts to $BIN"
mkdir -p "$BIN"
# The workflows locate the uploader relative to their own path, so both
# scripts must live in the same directory.
install -m 755 "$ROOT/bin/prntshot-upload"   "$BIN/prntshot-upload"
install -m 755 "$ROOT/bin/prntshot-capture.sh" "$BIN/prntshot-capture.sh"
install -m 755 "$ROOT/bin/prntshot-files.sh"   "$BIN/prntshot-files.sh"

echo "==> Installing workflows to $SERVICES"
mkdir -p "$SERVICES"
for wf in "$STAGE"/*.workflow; do
    name="$(basename "$wf")"
    rm -rf "$SERVICES/$name"
    cp -R "$wf" "$SERVICES/$name"
    echo "    $name"
done

echo "==> Removing any stale prntshot app bundles"
# An earlier menu-bar-app build registered a service also called
# "Upload to prnt.li". Two services sharing one name makes the entry
# ambiguous, and the colliding one wins, so it never appears as bindable.
# This approach no longer uses an app bundle, so clear any that linger.
for stale in "/Applications/prntshot.app" "$ROOT/build/prntshot.app"; do
    if [ -d "$stale" ]; then
        rm -rf "$stale"
        echo "    removed $stale"
    fi
done

echo "==> Refreshing the Services cache"
# sharedservicesd caches the service list; restarting it makes the new
# Quick Actions appear without a logout.
pkill -x sharedservicesd 2>/dev/null || true
killall -u "$(id -un)" cfprefsd 2>/dev/null || true
sleep 2

echo
echo "Installed."
echo
echo "Assign the keyboard shortcuts:"
echo "  System Settings > Keyboard > Keyboard Shortcuts > Services"
echo
echo "  'Screenshot and Upload' -> e.g. cmd+shift+7"
echo "  'Upload to prnt.li'     -> e.g. cmd+shift+8"
echo
echo "Screen Recording: if prompted, allow Automator (or Terminal)."
echo "That is the only permission needed — no Accessibility grant required."