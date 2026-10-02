#!/usr/bin/env bash
# Build MonitorGlue with SPM and assemble a signed .app bundle.
#
# Environment:
#   CONFIG         release (default) — what ships; the test harness is compiled out
#                  debug             — includes the MG_PREVIEW harness; built into dist/debug/
#   SIGN_IDENTITY  codesign identity. Unset: the local self-signed identity, else ad-hoc.
#   BUNDLE_ID      override CFBundleIdentifier (used for side-by-side test builds)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="MonitorGlue"
CONFIG="${CONFIG:-release}"
DIST="$ROOT/dist"
case "$CONFIG" in
    release) APP="$DIST/$APP_NAME.app" ;;          # the login item points at this path
    debug)   APP="$DIST/debug/$APP_NAME.app" ;;    # never mistaken for, or overwrites, the real one
    *) echo "error: CONFIG must be release or debug (got '$CONFIG')" >&2; exit 1 ;;
esac
ENTITLEMENTS="$ROOT/Resources/MonitorGlue.entitlements"

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
# Sparkle (in-app updates). ditto keeps the framework's internal symlinks intact.
mkdir -p "$APP/Contents/Frameworks"
ditto "$(dirname "$BIN")/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# App icon (optional): drop AppIcon.icns into Resources/ to include it.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi
if [[ -n "${BUNDLE_ID:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
fi

# Sign inside-out, never with --deep: Sparkle's helpers (XPC services, Autoupdate, Updater.app)
# must each be signed individually for notarization, and the app is signed last. Order and the
# Downloader's preserved entitlements follow Sparkle's own documentation.
sign_all() {
    local identity="$1"; shift
    local flags=("$@")
    local fw="$APP/Contents/Frameworks/Sparkle.framework"
    codesign --force ${flags[@]+"${flags[@]}"} --sign "$identity" "$fw/Versions/B/XPCServices/Installer.xpc"
    codesign --force ${flags[@]+"${flags[@]}"} --preserve-metadata=entitlements --sign "$identity" "$fw/Versions/B/XPCServices/Downloader.xpc"
    codesign --force ${flags[@]+"${flags[@]}"} --sign "$identity" "$fw/Versions/B/Autoupdate"
    codesign --force ${flags[@]+"${flags[@]}"} --sign "$identity" "$fw/Versions/B/Updater.app"
    codesign --force ${flags[@]+"${flags[@]}"} --sign "$identity" "$fw"
    codesign --force ${flags[@]+"${flags[@]}"} --entitlements "$ENTITLEMENTS" --sign "$identity" "$APP"
}

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    # A real Apple certificate: hardened runtime + secure timestamp, as notarization requires.
    echo "==> Signing with '$SIGN_IDENTITY'…"
    sign_all "$SIGN_IDENTITY" --options runtime --timestamp
else
    # Local builds: prefer a stable self-signed identity so the Accessibility (TCC) grant
    # survives rebuilds. Falls back to ad-hoc (grant must be re-approved after each rebuild).
    IDENTITY="Monitor Glue Self-Signed"
    if security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
        echo "==> Signing with stable identity '$IDENTITY'…"
        sign_all "$IDENTITY"
    else
        echo "==> No stable identity found — ad-hoc signing (run Scripts/make_cert.sh to make the"
        echo "    Accessibility permission persist across rebuilds)."
        sign_all -
    fi
fi
codesign --verify --deep --strict "$APP"

echo "==> Done: $APP"
