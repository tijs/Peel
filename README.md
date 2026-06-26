# Peel

A native macOS app for removing image backgrounds on your Mac. Drag in an
image, get a transparent PNG out. Processing runs on-device with CoreML — no
accounts, no servers.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

## How it works

Peel runs the RMBG-2.0 segmentation model through CoreML, using the Apple
Neural Engine where available. The app links the
[RMBG2Swift](https://github.com/VincentGourbin/RMBG2Swift) package, which
downloads the quantized model (~233 MB) from Hugging Face on first launch and
caches it under `~/Library/Caches/models`. After that first download, removal
works offline.

## Usage

- **Drag** an image onto the window, or press **⌘O** to open one
- **Paste** an image from the clipboard with **⌘V**
- When the result appears, **⌘S** saves a transparent PNG, **⌘C** copies it,
  or drag the cut-out straight into another app
- Drop or open another image to start over

Supported input: PNG, JPEG, HEIC, WebP, TIFF, BMP, GIF.

## Building

```sh
xcodebuild build -project Peel.xcodeproj -scheme Peel -destination 'platform=macOS'
xcodebuild test  -project Peel.xcodeproj -scheme Peel -destination 'platform=macOS' -only-testing:PeelTests
```

Xcode resolves the RMBG2Swift Swift Package automatically on first build.

## Model backup

The model is fetched at runtime from Hugging Face. A local copy lives under
`ModelBackup/` (git-ignored, ~244 MB) as a fallback should the upstream
download ever become unavailable.

## Licensing

- **App code:** MIT (see [LICENSE](LICENSE))
- **RMBG-2.0 model:** CC BY-NC 4.0 — **non-commercial use only**. The model is
  not bundled in this repository; it is downloaded from
  [briaai/RMBG-2.0](https://huggingface.co/briaai/RMBG-2.0) at runtime under its
  own terms.
