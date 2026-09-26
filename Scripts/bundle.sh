#!/usr/bin/env bash
# Build MonitorGlue with SPM and assemble a signed .app bundle.
#
# Environment:
#   FLAVOR         direct (default) — GitHub download, Ko-fi link, hardened runtime
#                  appstore         — Mac App Store, no Ko-fi link, App Sandbox
#   SIGN_IDENTITY  codesign identity. Unset: the local self-signed identity, else ad-hoc.
#   BUNDLE_ID      override CFBundleIdentifier (used for side-by-side test builds)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="MonitorGlue"
CONFIG="release"
FLAVOR="${FLAVOR:-direct}"
DIST="$ROOT/dist"

case "$FLAVOR" in
    direct)
        SWIFT_FLAGS=()
        BUILD_PATH="$ROOT/.build"
        APP="$DIST/$APP_NAME.app"            # unchanged path: the login item points here
        ENTITLEMENTS="$ROOT/Resources/Direct.entitlements"
        ;;
    appstore)
        SWIFT_FLAGS=(-Xswiftc -DAPP_STORE)
        BUILD_PATH="$ROOT/.build-appstore"   # separate cache so the flag never leaks across
        APP="$DIST/appstore/$APP_NAME.app"
        ENTITLEMENTS="$ROOT/Resources/AppStore.entitlements"
        ;;
    *) echo "error: FLAVOR must be direct or appstore (got '$FLAVOR')" >&2; exit 1 ;;
esac

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
    echo "==> Generating app icon…"
    "$ROOT/Scripts/make_icon.sh"
fi

echo "==> Building ($CONFIG, $FLAVOR)…"
swift build -c "$CONFIG" --build-path "$BUILD_PATH" ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"}

BIN="$(swift build -c "$CONFIG" --build-path "$BUILD_PATH" --show-bin-path)/$APP_NAME"
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
if [[ -n "${BUNDLE_ID:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
fi

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    # A real Apple certificate: hardened runtime + secure timestamp, as notarization and the
    # App Store both require.
    echo "==> Signing with '$SIGN_IDENTITY'…"
    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
else
    # Local builds: prefer a stable self-signed identity so the Accessibility (TCC) grant
    # survives rebuilds. Falls back to ad-hoc (grant must be re-approved after each rebuild).
    IDENTITY="Monitor Glue Self-Signed"
    if security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
        echo "==> Signing with stable identity '$IDENTITY'…"
        codesign --force --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
    else
        echo "==> No stable identity found — ad-hoc signing (run Scripts/make_cert.sh to make the"
        echo "    Accessibility permission persist across rebuilds)."
        codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP"
    fi
fi

echo "==> Done: $APP"
