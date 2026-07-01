# Monitor Glue

Keep your apps **glued** to the right monitor.

macOS only remembers the *last* external display you connected. Switch between, say, a home
monitor and an office monitor, and macOS dumps every window back onto your MacBook's built-in
screen — so you re-drag and re-size windows every single day.

**Monitor Glue** is a lightweight menu-bar app that remembers, for each unique set of external
monitors, which app windows lived on which display and at what size and position. When you
reconnect a monitor it recognizes, it puts your windows back automatically.

## Features

- 🧲 **Per-monitor memory** — every distinct monitor set is tracked separately (home vs office vs café).
- 🔄 **Auto-restore** — reconnect a known monitor and windows snap back to where they belong.
- 👀 **Built-in screen left alone** — only windows on *external* displays are remembered and moved.
- 🛠 **Manager UI** — see remembered monitors, apps, and windows; delete any entry or all of them.
- 🪶 **Tiny & native** — SwiftUI menu-bar app, no Dock icon.

## Install

This app is **unsigned** (distributed via GitHub, not the App Store), so macOS Gatekeeper will
block it on first launch. That's expected.

1. Download `MonitorGlue.zip` from the [latest release](https://github.com/erango/monitor-glue/releases), unzip it, and move `MonitorGlue.app` to `/Applications`.
2. Clear the quarantine flag (required because the app is unsigned):
   ```bash
   xattr -dr com.apple.quarantine /Applications/MonitorGlue.app
   ```
   *(Or: right-click the app → Open → Open.)*
3. Launch it. Grant **Accessibility** access when prompted — Monitor Glue needs it to read and
   move other apps' windows. (System Settings → Privacy & Security → Accessibility.)

## How it works

- A monitor's identity is its stable display **UUID** (`CGDisplayCreateUUIDFromDisplayID`), so
  it's recognized across reconnects even though macOS display IDs change.
- The set of connected external monitors forms a key. While connected, Monitor Glue
  continuously snapshots window positions on those displays into
  `~/Library/Application Support/MonitorGlue/layouts.json`.
- On reconnecting a known set, it matches saved windows (by app → title → index) and
  repositions them via the Accessibility API.

## Build from source

Requires Swift 5.9+ (Command Line Tools are enough — no full Xcode needed).

```bash
./Scripts/make_cert.sh     # once: create a stable self-signed identity (see below)
./Scripts/bundle.sh        # builds and assembles dist/MonitorGlue.app
open dist/MonitorGlue.app
```

**Why `make_cert.sh`:** an ad-hoc signature gets a fresh code hash on every rebuild, so macOS
silently invalidates the Accessibility grant each time (the toggle looks ON in System Settings
but the app still reports "access needed"). `make_cert.sh` creates a stable self-signed
code-signing identity once; `bundle.sh` then signs with it, so the grant survives rebuilds.
It's self-signed (not notarized) — this only stabilizes the permission, it does not change the
Gatekeeper steps above. If a rebuild ever still shows the banner, reset once with
`tccutil reset Accessibility com.erango.monitorglue` and re-grant.

## Notes & limitations

- Local builds signed via `make_cert.sh` keep the Accessibility grant across rebuilds. Release
  binaries built in CI are ad-hoc signed, so **installing a new release may require re-granting
  Accessibility access** once (there's no notarized identity to key the grant to).
- Window repositioning is best-effort. Some apps (Electron, full-screen, tabbed windows) may
  resist exact placement; Monitor Glue logs and skips what it can't place rather than forcing it.

## License

MIT
