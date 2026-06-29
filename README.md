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
./Scripts/bundle.sh        # builds and assembles dist/MonitorGlue.app (ad-hoc signed)
open dist/MonitorGlue.app
```

## Notes & limitations

- Because the app is ad-hoc signed, **updating it may require re-granting Accessibility access**
  (the binary's signature changes between builds).
- Window repositioning is best-effort. Some apps (Electron, full-screen, tabbed windows) may
  resist exact placement; Monitor Glue logs and skips what it can't place rather than forcing it.

## License

MIT
