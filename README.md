# Roomy

Temporary display scaling from the macOS menu bar. More workspace on a small MacBook, then back to normal when you quit.

Free. No accounts. No cloud. No paid plans.

## How it works

1. Launch Roomy. It remembers your current display size.
2. Pick a larger size from the menu. The numbers depend on your display.
3. Quit Roomy. The screen goes back to what it was at launch.

If the app is force-quit and the size sticks, open Roomy again and click **Restore original**.

## Requirements

- macOS 14 or later
- Xcode 15+ (to build)

## Build & run

```bash
open Roomy.xcodeproj
```

Select the **Roomy** scheme, then Run (⌘R). The app appears only in the menu bar (no Dock icon).

From the terminal:

```bash
xcodebuild -project Roomy.xcodeproj -scheme Roomy -configuration Debug \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Roomy.app
```

Smoke-test apply/restore (briefly changes your screen):

```bash
swift Scripts/smoke_display.swift
```

## Menu

- **Restore original** — jump back without quitting
- Sizes for the main display. **Default** is the middle option; **Roomy** is the largest sharp (Retina) size. Everything else is just the resolution.
- Below that: even larger sizes with smaller, less sharp text (see below)
- **Quit Roomy** — restore and exit

## Sharp sizes vs. extra space

The upper list uses Retina scaling: crisp text, like System Settings → Displays → “Looks like”.

The lower list, **More space, smaller text**, runs the screen at its real pixel count. You get more room. Text and buttons get smaller and a bit less sharp.

## Privacy

Session snapshots stay on this Mac only:

`~/Library/Application Support/Roomy/session.json`

Nothing is sent anywhere.

## License

MIT — see [LICENSE](LICENSE).
