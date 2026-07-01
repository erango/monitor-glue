#!/usr/bin/env bash
# Build MonitorGlue with SPM and assemble an ad-hoc-signed .app bundle.
# Works with Command Line Tools only (no full Xcode required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="MonitorGlue"
CONFIG="release"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
    echo "==> Generating app icon…"
    "$ROOT/Scripts/make_icon.sh"
fi

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
    echo "error: built binary not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# App icon (optional): drop AppIcon.icns into Resources/ to include it.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

# Prefer a stable self-signed identity so the Accessibility (TCC) grant survives rebuilds.
# Falls back to ad-hoc (grant must be re-approved after each rebuild).
IDENTITY="Monitor Glue Self-Signed"
if security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
    echo "==> Signing with stable identity '$IDENTITY'…"
    codesign --force --deep --sign "$IDENTITY" "$APP"
else
    echo "==> No stable identity found — ad-hoc signing (run Scripts/make_cert.sh to make the"
    echo "    Accessibility permission persist across rebuilds)."
    codesign --force --deep --sign - "$APP"
fi

echo "==> Done: $APP"
