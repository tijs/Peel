//
//  BackgroundRemover.swift
//  Peel
//

import AppKit
import RMBG2Swift

/// The on-device inference engine `BackgroundRemover` drives, one per model build.
///
/// Abstracted so the engine creation and error handling in `BackgroundRemover`
/// can be exercised with a fake, free of the 233 MB model and the ANE.
protocol ImageMatteEngine: Sendable {
    func removeBackground(from image: NSImage) async throws -> NSImage
}

/// Creates an `ImageMatteEngine` for a configuration, optionally reporting
/// download/compile progress. On first run this downloads and compiles the model.
typealias ImageMatteEngineFactory = @Sendable (
    _ configuration: RMBG2Configuration,
    _ progress: (@Sendable (Double, String) -> Void)?
) async throws -> ImageMatteEngine

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
    private let makeEngine: ImageMatteEngineFactory
    private let provisioner: ModelProvisioning
    private let cacheDirectory: URL?
    private var loaders: [ModelOption: SingleFlight<ImageMatteEngine>] = [:]

    /// - Parameters:
    ///   - option: Supplies the model build to use, read fresh each call so a
    ///     change to the default in Settings takes effect on the next image.
    ///   - cacheDirectory: Where the model is cached. When set, the model is
    ///     fetched through the integrity-verifying provisioner before RMBG2 is
    ///     constructed, so RMBG2 finds the files present and never runs its own
    ///     unverified download. Pass nil (as tests do) to skip provisioning.
    ///   - provisioner: Downloads and compiles the model, verifying the weights.
    ///   - makeEngine: Creates the inference engine. Defaults to the real RMBG-2
    ///     factory; tests inject a fake to drive the error and dedup paths.
    init(
        option: @escaping @Sendable () async -> ModelOption = { .standard },
        cacheDirectory: URL? = ModelManager.defaultCacheDirectory,
        provisioner: ModelProvisioning = RMBG2ModelProvisioner(),
        makeEngine: @escaping ImageMatteEngineFactory = BackgroundRemover.makeRMBG2Engine
    ) {
        currentOption = option
        self.cacheDirectory = cacheDirectory
        self.provisioner = provisioner
        self.makeEngine = makeEngine
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        _ = try await engine(for: currentOption(), reporting: progress)
    }

    func removeBackground(from image: NSImage) async throws -> NSImage {
        let engine = try await engine(for: currentOption(), reporting: nil)
        return try await engine.removeBackground(from: image)
    }

    /// Returns the shared engine for `option`, creating (and on first run,
    /// downloading) it once. Generic creation failures are normalized to
    /// `RemovalError.modelFailure`; a `RemovalError` thrown by the factory is
    /// surfaced unchanged.
    private func engine(
        for option: ModelOption,
        reporting progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> ImageMatteEngine {
        let loader = loaders[option] ?? {
            let loader = SingleFlight<ImageMatteEngine>()
            loaders[option] = loader
            return loader
        }()

        do {
            return try await loader.run { [makeEngine, provisioner, cacheDirectory] in
                // Fetch and verify the model through our own path first. RMBG2's
                // initializer skips downloading when the package is already in
                // the cache, so this closes the gap where its built-in (
                // unverified) downloader would otherwise run on first use.
                if let cacheDirectory, !ModelManager.isInstalled(option, inCache: cacheDirectory) {
                    try await provisioner.provision(option, into: cacheDirectory) { fraction in
                        progress?(fraction, fraction >= 0.9 ? "Finishing…" : "Downloading…")
                    }
                }
                return try await makeEngine(option.configuration(), progress)
            }
        } catch let error as RemovalError {
            throw error
        } catch {
            throw RemovalError.modelFailure(error.localizedDescription)
        }
    }

    /// The production factory: builds an `RMBG2` model and adapts it.
    static let makeRMBG2Engine: ImageMatteEngineFactory = { configuration, progress in
        if let progress {
            return try await RMBG2Engine(model: RMBG2(
                configuration: configuration,
                progress: { fraction, status in progress(fraction, status) }
            ))
        }
        return try await RMBG2Engine(model: RMBG2(configuration: configuration))
    }
}

/// Adapts RMBG2Swift's model to `ImageMatteEngine`, mapping its CGImage result
/// back to an `NSImage` and normalizing inference failures.
private struct RMBG2Engine: ImageMatteEngine {
    let model: RMBG2

    func removeBackground(from image: NSImage) async throws -> NSImage {
        do {
            let result = try await model.removeBackground(from: image)
            let cgImage = result.image
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        } catch {
            throw RemovalError.modelFailure(error.localizedDescription)
        }
    }
}
