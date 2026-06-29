# Handoff: Monitor Glue — macOS Menu-Bar Utility UI

## Overview
Monitor Glue is a macOS menu-bar utility that remembers, for each unique set of external
monitors, which app windows lived on which display (and at what size/position) and
auto-restores them when that monitor set reconnects. This package documents three product
surfaces:

1. **Menu-bar dropdown** (MenuBarExtra popover, ~320pt wide)
2. **Management window** (resizable, ~720×520pt)
3. **First-run / onboarding** screen (Accessibility permission)

Plus the **menu-bar icon**, **app icon**, and the **status/permission color system**.

## About the Design Files
The file in this bundle (`Monitor Glue.dc.html`) is a **design reference created in HTML** — a
streaming prototype that shows the intended look, hierarchy, copy, states, and interactions. It
is **not production code to ship**. The target app already has a SwiftUI codebase
(`Sources/MonitorGlue/UI/MenuBarContent.swift`, `ManagementView.swift`, plus the data layer in
`LayoutStore.swift`). The task is to **recreate these designs in that existing SwiftUI
environment**, following Apple HIG and the app's established types — not to embed the HTML.

The HTML mock is organized as a single page with a top "tool chrome" bar that lets you switch
between the surfaces, toggle light/dark, toggle the Accessibility-permission state, and switch
list-hierarchy variants. **That top graphite bar is a review harness only — it is NOT part of
the product** and should not be implemented.

## Fidelity
**High-fidelity (hifi).** Final colors, type sizes/weights, spacing, radii, and interaction
states are specified. Recreate pixel-accurately using native AppKit/SwiftUI controls. Where the
mock draws a macOS affordance with HTML (traffic lights, blur, sidebar list), use the real
native equivalent (`NSVisualEffectView` materials, `List`/`Table`, `DisclosureGroup`, SF
Symbols, `.windowBackground`, etc.) rather than reproducing the HTML literally.

## Mapping to the existing codebase
- **Menu-bar dropdown** → `MenuBarContent.swift` (a `MenuBarExtra` with `.menuBarExtraStyle(.window)`)
- **Management window** → `ManagementView.swift` (opened via `openWindow(id:"manager")`)
- **Onboarding** → new view; trigger on first run / when `!permissions.isTrusted`
- **Data** → `MonitorSetRecord` → grouped by app → `WindowLayout` (already exists in `LayoutStore.swift`)
- **Permission** → `Permissions.isTrusted` / `Permissions.requestAccess()`

The mock's data shape mirrors the real model exactly:
`MonitorSetRecord { key, displays:[DisplayInfoRecord{uuid,localizedName,widthPx,heightPx}], lastSeen, windows:[WindowLayout] }`
and `WindowLayout { appBundleID, appName, displayUUID, windowTitle, windowIndex, x, y, width, height, updatedAt }`.

---

## Screens / Views

### 1. Menu-bar dropdown (MenuBarExtra popover)
- **Purpose**: Glanceable status + the two primary actions (Restore now, Open Manager) + Quit.
- **Container**: ~320pt wide, 12pt internal padding, 12px corner radius, vibrancy/material
  background (use `.regularMaterial` / popover material), thin hairline border, drop shadow. A
  caret points up to the menu-bar item.
- **Layout** (vertical stack, 10pt rhythm, hairline dividers between groups):
  1. **Header**: pin/display glyph (accent-tinted, 16pt) + "Monitor Glue" (15pt, semibold).
  2. **Divider**.
  3. **Status block — two states:**
     - **Granted (tracking)**: filled green checkmark (SF Symbol `checkmark.circle.fill`, 15pt) +
       - line 1 "Tracking · 2 displays connected" (13pt, weight ~570, primary)
       - line 2 "Dell U2720Q + LG HDR 4K · 5 windows" (11.5pt, secondary)
       - line 3 "2 monitor sets · 8 windows remembered" (11.5pt, tertiary)
     - **Permission needed**: tinted warning box (orange 10% fill, orange hairline border, 9px
       radius, 10pt padding) containing: triangle warning (orange) + "Accessibility access
       required" (13pt, semibold, orange); body "Monitor Glue needs Accessibility access to read
       and move app windows." (11.5pt, secondary); a prominent **Grant access…** button (accent
       bg, white, 12.5pt/560, 6×12pt padding, 7px radius).
  4. **Divider**.
  5. **Menu rows** (full-width, 6×8pt padding, 6px radius, 13pt; hover = accent background, white
     text & icons; leading icon column is 17pt wide, centered):
     - **Restore windows now** (icon `arrow.uturn.backward`, weight 500, trailing "⌘R" at 11pt/55% opacity). **Disabled** when permission not granted (tertiary color, no hover, no action).
     - **Open Manager…** (icon `rectangle.stack`).
  6. **Divider**.
     - **Quit Monitor Glue** (icon `power`, trailing "⌘Q").
  7. **Divider**.
  8. **Footer** (centered, 9pt gap):
     - "Made with ♥ by @erango" (11.5pt secondary; ♥ in coral `#FF5A5F`; **@erango** is a link in
       accent color, weight 570, → `https://github.com/erango`, underline on hover).
     - **Ko-fi button**: pill, background `#29ABE0`, white text "Buy me a coffee" (12pt/600),
       7px gap, 6×14pt padding, 9px radius, soft shadow; leading coffee-cup glyph (white cup +
       handle + saucer + two steam wisps + small coral `#FF5A5F` heart). → `https://ko-fi.com/erango`.
       (`target="_blank"` in web; in SwiftUI use `Link`/`NSWorkspace.open`.)

### 2. Management window
- **Purpose**: Master view of every remembered monitor set; expand set → app → window; delete at any level.
- **Container**: resizable, design size ~760×548 (spec ~720×520pt min). 11px window radius in mock; real window uses native chrome.
- **Toolbar (unified, 56pt tall, titlebar material, hairline bottom border):**
  - Leading: traffic lights (mock only — native window provides these).
  - Title block: "Remembered Monitors" (15pt, semibold) with a subtitle line:
    - granted → "Accessibility access granted" (11pt, green)
    - not granted → "Accessibility access needed" (11pt, orange)
  - Trailing: **Grant Access…** (accent button, only when not granted) and **Delete All…**
    (subtle filled button `--fill` bg, **red** text/trash icon, hairline border) — shown only
    when sets exist; opens a destructive confirmation dialog.
- **Content area**: scrollable, `--list-bg` background, 14pt padding.
- **Variant A — Grouped list (default):** stack of rounded white cards (10px radius, soft shadow), 12pt gap. Each card:
  - **Set header row** (clickable to expand; 12×13pt padding; hover `--fill`): disclosure
    chevron (rotates 0→90°), 32pt rounded display-glyph tile (`--fill` bg, secondary glyph),
    label (13.5pt/590) e.g. "Dell U2720Q + LG HDR 4K", meta line (11.5pt secondary) =
    "3840 × 2160  ·  3840 × 2160   ·   Last seen Today at 9:14 AM", trailing summary "4 apps · 5
    windows", trailing trash (tertiary → red on hover) for **delete set**.
  - **App rows** (indented to 40pt left; padding vertical = density, see tweaks; hover `--fill`):
    smaller chevron, 22pt app-color tile with white monogram (Safari=`#2E86FF` "S", Xcode=`#4E7CC4`
    "X", Figma=`#9747FF` "F", Slack=`#5B2C5E` "S", Mail=`#1F8BEA` "M", Terminal=`#3A3F49` "›"),
    app name (13pt/500), trailing window count, trailing trash for **delete app on this set**.
    (In the real app, icons should be the actual `NSRunningApplication` icons; monogram tiles are
    a placeholder so the mock avoids shipping brand logos.)
  - **Window rows** (indented to 72pt left): window glyph, title (12.5pt, truncates) e.g.
    "Apple — Start Page", trailing **monospace** frame "40, 64  ·  1280×900" (11pt, tertiary),
    trailing ✕ (`xmark.circle`) for **forget this window**.
- **Variant B — Card overview:** 2-column grid (12pt gap) of summary cards: 44pt accent display
  glyph, label + resolution line, a wrap of app-color monogram tiles (26pt), footer row with
  "N apps · M windows" and "Last seen …", trailing trash. (This is an alternate density option to
  explore — pick one for production; grouped list is the primary.)
- **Variant C — Empty state:** centered display-with-exclamation glyph (46pt, tertiary), "Nothing
  remembered yet" (15pt/600), helper text "Connect an external monitor and arrange your app
  windows. Monitor Glue will remember their positions automatically." (12.5pt secondary, max 340pt).

### 3. Onboarding / first-run
- **Purpose**: Explain the single required permission (Accessibility), why, and link to System Settings.
- **Variant A — Centered (recommended):** ~540pt wide sheet. Top→bottom, centered:
  - 74pt app squircle (brand-blue gradient, white display+pin glyph), 17px radius, glow shadow.
  - Title "Welcome to Monitor Glue" (22pt, weight ~680, -0.02em tracking).
  - Subtitle (13.5pt secondary, max 380pt): "Monitor Glue keeps your windows glued to the right
    monitor — and puts them back when you reconnect a display it recognizes."
  - **Permission callout** (full width, `--fill` bg, 11px radius, 16pt padding, left-aligned):
    accessibility person glyph (accent, 26pt) + "One permission: Accessibility" (13.5pt/600) +
    "It lets Monitor Glue read and move other apps' windows — the only thing it needs to restore
    your layout." (12.5pt secondary).
  - Trust line (11.5pt tertiary, max 400pt): "Monitor Glue never reads window contents — only
    their size and position."
  - **Open Accessibility Settings…** primary button (accent, white, 14pt/570, 10×22pt, 9px radius,
    shadow). In SwiftUI open
    `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
  - Secondary text button "I'll do this later" (accent, 12.5pt/500).
  - **Footer strip** (top hairline, `--content-bg`): clock glyph + "**How it works ·** Arrange
    your windows once. Reconnect a monitor it knows, and they snap back automatically." (11.5pt).
- **Variant B — Split:** ~720×460. Left column (≈52%): 48pt app squircle, "Allow Accessibility
  access" (21pt/680), body, the "How it works" line, then bottom-aligned primary + secondary
  buttons. Right column (≈48%, `--list-bg`, left hairline): a calm illustration — an external
  display card holding one accent window + two neutral windows, a stand, and an accent pin badge
  (top-right) signifying "glued"; caption "Reconnect a known display → windows glued back in place."

---

## Interactions & Behavior
- **Disclosure expand/collapse**: clicking a set header or app row toggles its children; chevron
  rotates 0°↔90° over 150ms ease. Default open state in mock: first set + its Safari app.
- **Hover**: menu rows fill with accent (white text/icon); list rows fill with `--fill`; trash/
  delete controls go tertiary→red; buttons brighten ~6–7%.
- **Restore windows now**: disabled unless permission granted AND a known monitor set is currently
  connected (`!currentSetKey.isEmpty`).
- **Delete actions**: per-window (✕), per-app (trash), per-set (trash) delete immediately; **Delete
  All…** opens a confirmation dialog ("Delete all remembered layouts?" → destructive "Delete
  Everything" / "Cancel"). These map to `LayoutStore.deleteWindow/deleteApp/deleteSet/deleteAll`.
- **Grant access**: calls `Permissions.requestAccess()`; status/permission UI updates reactively.
- **Open Manager…**: `openWindow(id:"manager")` + `NSApp.activate`.
- **External links**: @erango → github.com/erango; Ko-fi → ko-fi.com/erango (open in browser).
- **No entrance animations**: surfaces appear immediately (any fade-in was removed for reliability).

## State Management
Mirrors the existing `AppModel` / `Permissions` / `LayoutStore`:
- `permissions.isTrusted: Bool` — drives the granted vs needs-permission branches everywhere.
- `model.statusText`, `model.currentSetKey` — menu-bar status line and Restore-enabled.
- `LayoutStore.allSets() -> [MonitorSetRecord]` — management list source; group each set's
  `windows` by `appBundleID` (label from `appName`), sort apps alphabetically, windows by
  `windowIndex`.
- Local UI state: which sets/apps are expanded (DisclosureGroup); Delete-All confirmation flag.
- The mock's `surface` / `appearance` / `managerVariant` / `density` switches are **review-harness
  state only** — do not ship them (appearance follows the system; pick one manager variant).

## Design Tokens
Colors are given as **light / dark**. The mock uses approximations of the macOS system palette —
in SwiftUI prefer the semantic equivalents (`.accentColor`, `Color(.systemGreen)`,
`Color(.systemOrange)`, `Color(.systemRed)`, `.secondary`, `.separator`, materials) so it adapts
automatically.

**Surfaces & text**
- Window bg: `#ECECEE` / `#2B2B2E`
- Content bg: `#FFFFFF` / `#1E1E20`
- List/grouped bg: `#F3F3F5` / `#161618`
- Titlebar: `#F7F7F8→#EDEDEF` / `#323236→#28282B`
- Hairline/separator: `rgba(0,0,0,.10)` / `rgba(255,255,255,.10)`
- Control fill: `rgba(0,0,0,.045)` / `rgba(255,255,255,.07)`; hover fill `rgba(0,0,0,.08)` / `rgba(255,255,255,.12)`
- Label: `rgba(0,0,0,.86)` / `rgba(255,255,255,.92)`
- Secondary: `rgba(0,0,0,.5)` / `rgba(255,255,255,.55)`
- Tertiary: `rgba(0,0,0,.32)` / `rgba(255,255,255,.34)`

**Semantic / status**
- Accent (primary action, highlight): `#0A6CF5` / `#0A84FF` (≈ system blue)
- Green (tracking / granted): `#1E9E45` / `#30D158` (system green)
- Orange (permission needed): `#C26A06` / `#FF9F0A` (system orange); warn box bg `rgba(255,159,10,.10/.13)`, border `rgba(194,106,6,.32)` / `rgba(255,159,10,.34)`
- Red (destructive): `#D7372C` / `#FF453A` (system red)

**Brand**
- App icon gradient: `linear-gradient(160deg, #3a8bff, #1457d8)`
- Traffic lights (mock): close `#FF5F57`, min `#FEBC2E`, max `#28C840`
- Ko-fi pill: `#29ABE0`; heart accent `#FF5A5F`
- App monogram tiles: Safari `#2E86FF`, Xcode `#4E7CC4`, Figma `#9747FF`, Slack `#5B2C5E`, Mail `#1F8BEA`, Terminal `#3A3F49`

**Typography** — system font (SF Pro via `-apple-system`); monospace via `ui-monospace`/`SF Mono` for window frames.
- Window/section title 15pt/600; onboarding H1 21–22pt/680 (-0.02em)
- Body 13–13.5pt; row labels 13pt/500; secondary meta 11.5pt; tertiary captions 11pt; uppercase eyebrow labels 10–12pt/600–700, +0.04–0.06em
- Frame coordinates: 11pt monospace

**Radii**: window 11px · cards 10–13px · tiles 5.5–10px · buttons/pills 7–9px · menu rows 6px · app squircle 17–21px
**Spacing**: popover padding 12pt, group rhythm 10pt; window content padding 14pt, card gap 12pt; list indents 40pt (app) / 72pt (window)
**Shadows**: window `0 28px 64px rgba(0,0,0,.34)` + hairline + `0 2px 6px rgba(0,0,0,.12)`; popover `0 18px 50px rgba(0,0,0,.32)` + hairline; cards `0 1px 2.5px rgba(0,0,0,.07/.45)`

## Icons (SF Symbols mapping)
The mock hand-draws simple glyphs; in the app use SF Symbols:
- Menu-bar item / brand: a **display + pin** concept. As a **template image** (single color,
  inherits menu-bar tint). Nearest SF Symbols to start from: `display` + `pin.fill`, or
  `pin.square` — refine to a custom monochrome template asset. App icon = same glyph reversed
  white on the brand-blue squircle. **No Dock icon** (`LSUIElement` / `.accessory` activation).
- Status: `checkmark.circle.fill` (green), `exclamationmark.triangle.fill` (orange)
- Actions: `arrow.uturn.backward` (restore), `rectangle.stack` (manager), `power` (quit), `trash` (delete), `xmark.circle` (forget window)
- List: `display` (monitor set), generic app icon (use real app icons), `macwindow` (window), `chevron.right` (disclosure)
- Onboarding: `figure`/`accessibility` person-in-circle, `clock` (how it works)

## Assets
No external image assets — all glyphs are vector (SF Symbols in the real app). The app icon and
menu-bar template glyph must be produced as real asset catalog entries (the menu-bar one as a
**Template Image**). Real app icons in the management list come from the running applications at
runtime.

## Files
- `Monitor Glue.dc.html` — the full hi-fi prototype (all three surfaces + variants + icon/color
  reference). Open in a browser; use the top bar to switch surfaces, light/dark, permission
  state, and list variants.
