# Peel — Project Plan

## Overview
A native SwiftUI Mac app for on-device background removal. Drag in an image, get a transparent PNG out. No servers, no accounts, no internet required. Open source, direct download.

## Stack
- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI, macOS 14+ deployment target
- **ML:** CoreML via `RMBG2Swift` Swift Package (`github.com/VincentGourbin/RMBG2Swift`)
- **Model:** `VincentGOURBIN/RMBG-2-CoreML` (233MB, INT8, ANE-compatible)
- **License:** CC BY-NC 4.0 (inherited from RMBG-2.0); app code MIT

---

## Project Structure

```
Peel/
├── Peel.xcodeproj
├── Peel/
│   ├── App/
│   │   └── PeelApp.swift          # @main, app entry
│   ├── Views/
│   │   ├── ContentView.swift      # Root view, state routing
│   │   ├── DropZoneView.swift     # Drag & drop + file picker UI
│   │   ├── ResultView.swift       # Before/after + export controls
│   │   └── ProcessingView.swift   # Loading/progress state
│   ├── Model/
│   │   └── BackgroundRemover.swift # Wraps RMBG2Swift, async/await
│   └── Resources/
│       └── Assets.xcassets
├── README.md
└── LICENSE (MIT)
```

---

## Features (v1.0)

### Input
- [ ] Drag & drop image onto the window (PNG, JPG, HEIC, WebP)
- [ ] File picker button ("Open Image…") via `NSOpenPanel`
- [ ] Paste from clipboard (`⌘V` / Edit menu)

### Processing
- [ ] Run RMBG-2.0 via CoreML on ANE (async, non-blocking UI)
- [ ] Progress indicator during inference
- [ ] Error handling for unsupported formats or model failure

### Output
- [ ] Side-by-side before/after preview with checkerboard background
- [ ] Save as PNG with transparency (`NSSavePanel`)
- [ ] Copy to clipboard (`⌘C`)
- [ ] Drag result image out to Finder or other apps

### UX
- [ ] Single-window app, no sidebar clutter
- [ ] Drop another image to start over
- [ ] Keyboard shortcut: `⌘O` open, `⌘S` save, `⌘C` copy result

---

## Implementation Notes

### BackgroundRemover.swift
```swift
import RMBG2Swift
import AppKit

actor BackgroundRemover {
    private let rmbg = try await RMBG2()

    func removeBackground(from image: NSImage) async throws -> NSImage {
        let result = try await rmbg.removeBackground(from: image)
        return result.image
    }
}
```

### Drag & Drop
Use `.onDrop(of: [.image, .fileURL], ...)` in SwiftUI. Validate file type before passing to the model.

### Clipboard paste
Listen for `⌘V` via `.keyboardShortcut("v", modifiers: .command)` and read `NSPasteboard.general`.

### Model first-launch
The CoreML model is bundled in the app via the Swift package — no download on first run. App size will be ~250MB.

---

## Distribution
- GitHub repo, MIT license for app code
- Releases page with notarized `.dmg`
- README notes CC BY-NC 4.0 on the embedded model (non-commercial use only)
- Notarization via `xcrun notarytool` with an Apple Developer account

---

## Milestones

| # | Task | Notes |
|---|------|-------|
| 1 | Xcode project setup, SPM dependency on RMBG2Swift | |
| 2 | `BackgroundRemover` actor, verify model runs on device | Smoke test first |
| 3 | `DropZoneView` — drag & drop + file picker | |
| 4 | `ProcessingView` — async inference wired up | |
| 5 | `ResultView` — preview, save, copy, drag-out | |
| 6 | Clipboard paste input | |
| 7 | App icon + polish | |
| 8 | Notarized DMG, GitHub release | |

---

## Open Questions
- Minimum macOS version: 14 (Sonoma) is safe for CoreML ML Program format; confirm ANE availability on older hardware if needed
- Whether to bundle the `.mlpackage` directly or rely on the Swift package to vend it — check how `RMBG2Swift` exposes the model asset
