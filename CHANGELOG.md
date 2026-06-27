# Changelog

## 1.1 - 2026-06-27

- First-run model download now shows a real progress bar instead of a frozen spinner, with live percentage in the toolbar.
- The toolbar shows whether the selected model is downloaded, downloading, or ready; Settings reflects the install state after a first-run download.
- Default to the smaller Standard model so the first download is lighter.
- The result preview no longer stretches wider than the original image.
- Verify downloaded model files against a pinned checksum before they are used, and fetch them from a fixed model revision.
- Save errors are now shown instead of failing silently.
- Faster, smoother result export: the PNG is prepared once rather than on every redraw, and large images are decoded off the main thread.
- Build on Swift 6 with strict concurrency checking.

## 1.0 - 2026-06-26

- Initial public release.
