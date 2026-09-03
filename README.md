# Roomy

Temporary display scaling from the macOS menu bar. More workspace on a small MacBook, then back to normal when you quit.

Roomy is free. No accounts. No cloud. No paid plans.

## How it works

1. Launch Roomy — it snapshots your current display mode.
2. Pick a scale from the menu (e.g. **More Space**).
3. Quit Roomy — it restores the snapshot.

If the app is force-quit and the temporary mode sticks, open Roomy again and click **Restore original**.

## Requirements

- macOS 14 or later
- Xcode 15+ (to build)

## Build & run

```bash
open Roomy.xcodeproj
```

Select the **Roomy** scheme, then Run (⌘R). The app appears only in the menu bar (no Dock icon).

Or from the terminal:

```bash
xcodebuild -project Roomy.xcodeproj -scheme Roomy -configuration Debug \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Roomy.app
```

Smoke-test display apply/restore (briefly changes your screen):

```bash
swift Scripts/smoke_display.swift
```

## Menu

- **Roomy**
- **Restore original** — jump back to the snapshot without quitting
- Scaled modes for the main display (Larger Text → More Space)
- **Quit Roomy** — restore + exit

## Privacy

Session snapshots are stored only at:

`~/Library/Application Support/Roomy/session.json`

Nothing is sent anywhere.

## License

MIT — see [LICENSE](LICENSE).
