# Peel

A native macOS app for removing image backgrounds on your Mac. Drag in an
image, get a transparent PNG out. Processing runs on-device with CoreML — no
accounts, no servers.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

## Install

Download the latest `Peel-<version>.dmg` from
[GitHub Releases](../../releases), open it, and drag Peel into Applications.
Release builds are Developer ID signed and notarized.

## How it works

Peel runs the RMBG-2.0 segmentation model through CoreML, using the Apple
Neural Engine where available. The app links the
[RMBG2Swift](https://github.com/VincentGourbin/RMBG2Swift) package, which
downloads the selected model from Hugging Face and caches it under
`~/Library/Caches/models`. The standard model is about 233 MB; the high-quality
model is about 461 MB. After that first download, removal works offline.

## Usage

- **Drag** an image onto the window, or press **⌘O** to open one
- **Paste** an image from the clipboard with **⌘V**
- When the result appears, **⌘S** saves a transparent PNG, **⌘C** copies it,
  or drag the cut-out straight into another app
- Drop or open another image to start over

Supported input: PNG, JPEG, HEIC, WebP, TIFF, BMP, GIF.

## Privacy

Peel processes images locally on your Mac. Images are not uploaded to a server.
The app uses the network only to download CoreML model files from Hugging Face
when a model is not already installed. Peel stores lightweight preferences, such
as the selected model option, in `UserDefaults`.

## Building

```sh
xcodebuild build -project Peel.xcodeproj -scheme Peel -destination 'platform=macOS'
xcodebuild test  -project Peel.xcodeproj -scheme Peel -destination 'platform=macOS' -only-testing:PeelTests
```

Xcode resolves the RMBG2Swift Swift Package automatically on first build.

## Releasing

Release builds are packaged as signed and notarized disk images:

```sh
VERSION=1.0 scripts/release/release.sh
```

See [docs/RELEASING.md](docs/RELEASING.md) for local and GitHub Actions release
setup.

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
