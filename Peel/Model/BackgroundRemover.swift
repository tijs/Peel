//
//  BackgroundRemover.swift
//  Peel
//

import AppKit
import RMBG2Swift

/// Real background-removal engine backed by RMBG-2.0 running on-device via CoreML.
///
/// The engine for a given model build is created lazily on first use — that
/// initialization downloads the model from HuggingFace and caches it under
/// `…/Caches/models`, so every run after the first is offline and fast. Creation
/// is coalesced per build through `SingleFlight`, so two images dropped in quick
/// succession on first launch trigger only one download. Each `ModelOption` keeps
/// its own engine, so switching the default model doesn't discard the other.
///
/// The compute units come from `ModelOption.configuration()` (`.cpuAndGPU`):
/// RMBG-2's convolutions exceed the Apple Neural Engine's 64 KB kernel-memory
/// limit, so `.all` makes CoreML fail an ANE compile ("Convolution configuration
/// cannot fit in KMEM"), stalling the first inference. The GPU has no such limit.
actor BackgroundRemover: BackgroundRemoving {
    private let currentOption: @Sendable () async -> ModelOption
    private var loaders: [ModelOption: SingleFlight<RMBG2>] = [:]

    /// - Parameter option: Supplies the model build to use, read fresh each call
    ///   so a change to the default in Settings takes effect on the next image.
    init(option: @escaping @Sendable () async -> ModelOption = { .standard }) {
        currentOption = option
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        _ = try await engine(for: currentOption(), reporting: progress)
    }

    func removeBackground(from image: NSImage) async throws -> NSImage {
        let engine = try await engine(for: currentOption(), reporting: nil)
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

    /// Returns the shared engine for `option`, creating (and on first run,
    /// downloading) it once.
    private func engine(
        for option: ModelOption,
        reporting progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> RMBG2 {
        let loader = loaders[option] ?? {
            let loader = SingleFlight<RMBG2>()
            loaders[option] = loader
            return loader
        }()

        do {
            return try await loader.run {
                let configuration = option.configuration()
                if let progress {
                    return try await RMBG2(
                        configuration: configuration,
                        progress: { fraction, status in progress(fraction, status) }
                    )
                } else {
                    return try await RMBG2(configuration: configuration)
                }
            }
        } catch let error as RemovalError {
            throw error
        } catch {
            throw RemovalError.modelFailure(error.localizedDescription)
        }
    }
}
