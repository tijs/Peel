# Changelog

## 1.1 - 2026-06-27

- Verify downloaded model files against a pinned checksum before they are used, and fetch them from a fixed model revision.
- Save errors are now shown instead of failing silently.
- Faster, smoother result export: the PNG is prepared once rather than on every redraw, and large images are decoded off the main thread.
- Build on Swift 6 with strict concurrency checking.

## 1.0 - 2026-06-26

- Initial public release.
