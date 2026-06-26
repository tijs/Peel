//
//  BackgroundRemover.swift
//  Peel
//

import AppKit
import RMBG2Swift

/// Real background-removal engine backed by RMBG-2.0 running on-device via CoreML.
///
/// The underlying `RMBG2` is created lazily on first use — that initialization
/// downloads the ~233 MB model from HuggingFace and caches it under
/// `~/Library/Caches/models`, so every run after the first is offline and fast.
/// Creation is coalesced through `SingleFlight`, so two images dropped in quick
/// succession on first launch trigger only one download.
///
/// We pin compute units to `.cpuAndGPU` rather than the default `.all`. RMBG-2's
/// convolutions exceed the Apple Neural Engine's 64 KB kernel-memory limit, so
/// `.all` makes CoreML attempt — and fail — an ANE compile ("Convolution
/// configuration cannot fit in KMEM"), stalling the first inference. The GPU has
/// no such limit and runs the model fine.
actor BackgroundRemover: BackgroundRemoving {
    private let loader = SingleFlight<RMBG2>()

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        _ = try await engine(reporting: progress)
    }

    func removeBackground(from image: NSImage) async throws -> NSImage {
        let engine = try await engine(reporting: nil)
        do {
            let result = try await engine.removeBackground(from: image)
            let cgImage = result.image
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        } catch {
            throw RemovalError.modelFailure(error.localizedDescription)
        }
    }

    /// Returns the shared engine, creating (and on first run, downloading) it once.
    private func engine(
        reporting progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> RMBG2 {
        do {
            return try await loader.run {
                // `.cpuAndGPU` (not the default `.all`) keeps RMBG-2 off the ANE,
                // which can't compile its oversized convolutions. See type doc above.
                if let progress {
                    try await RMBG2(
                        configuration: .cpuAndGPU,
                        progress: { fraction, status in progress(fraction, status) }
                    )
                } else {
                    try await RMBG2(configuration: .cpuAndGPU)
                }
            }
        } catch let error as RemovalError {
            throw error
        } catch {
            throw RemovalError.modelFailure(error.localizedDescription)
        }
    }
}
