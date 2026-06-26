//
//  ModelManager.swift
//  Peel
//

import Foundation
import Observation
import RMBG2Swift

/// Tracks which RMBG-2 builds are installed, downloads them on request, and
/// persists which one inference should use by default.
///
/// `defaults` and `cacheDirectory` are injectable so the logic can be tested
/// against a temp directory and an isolated `UserDefaults`.
@MainActor
@Observable
final class ModelManager {
    /// The model inference uses by default. Persisted across launches.
    var selected: ModelOption {
        didSet { defaults.set(selected.rawValue, forKey: Self.selectedKey) }
    }

    /// Options whose model files are present in the cache.
    private(set) var installed: Set<ModelOption> = []
    /// In-flight download progress per option, 0...1 (absent when idle).
    private(set) var progress: [ModelOption: Double] = [:]
    /// A short status for an in-flight download (e.g. "Downloading…").
    private(set) var status: [ModelOption: String] = [:]
    /// The last download error per option, if any.
    private(set) var lastError: [ModelOption: String] = [:]

    private let defaults: UserDefaults
    let cacheDirectory: URL?

    private static let selectedKey = "defaultModelOption"

    init(defaults: UserDefaults = .standard, cacheDirectory: URL? = ModelManager.defaultCacheDirectory) {
        self.defaults = defaults
        self.cacheDirectory = cacheDirectory
        selected = defaults.string(forKey: Self.selectedKey)
            .flatMap(ModelOption.init(rawValue:)) ?? .standard
        refreshInstalled()
    }

    /// Whether the option's model is fully present on disk.
    ///
    /// Either the compiled `.mlmodelc` exists, or the `.mlpackage` is complete —
    /// i.e. it contains the weights blob. A package missing its weights (an
    /// interrupted download) does not count as installed.
    func isInstalled(_ option: ModelOption) -> Bool {
        guard let cacheDirectory else { return false }
        let manager = FileManager.default
        if manager.fileExists(atPath: cacheDirectory.appendingPathComponent(option.compiledFilename).path) {
            return true
        }
        let weights = cacheDirectory
            .appendingPathComponent(option.packageFilename)
            .appendingPathComponent(ModelOption.weightsSubpath)
        return manager.fileExists(atPath: weights.path)
    }

    /// Re-scans the cache and updates `installed`.
    func refreshInstalled() {
        installed = Set(ModelOption.allCases.filter(isInstalled))
    }

    /// Downloads and compiles the option's model. No-op if a download for that
    /// option is already running.
    ///
    /// The files are fetched with real byte-level progress (the first 90%), then
    /// the package compiles the already-present package (the final 10%).
    func download(_ option: ModelOption) async {
        guard progress[option] == nil, let cacheDirectory else { return }
        lastError[option] = nil
        status[option] = "Downloading…"
        progress[option] = 0

        do {
            let fileDownloader = ModelFileDownloader(cacheDirectory: cacheDirectory)
            try await fileDownloader.download(option) { fraction in
                Task { @MainActor in
                    guard self.progress[option] != nil else { return }
                    self.progress[option] = fraction * 0.9
                }
            }

            status[option] = "Finishing…"
            progress[option] = 0.9
            let compiler = ModelDownloader(configuration: option.configuration()) { fraction, _ in
                Task { @MainActor in
                    guard self.progress[option] != nil else { return }
                    self.progress[option] = 0.9 + fraction * 0.1
                }
            }
            _ = try await compiler.getCompiledModelURL()
        } catch {
            lastError[option] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        progress[option] = nil
        status[option] = nil
        refreshInstalled()
    }

    /// The standard cache location used by RMBG2Swift, container-relative under
    /// the app sandbox: `…/Caches/models/VincentGOURBIN/RMBG-2-CoreML`.
    nonisolated static var defaultCacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("models")
            .appendingPathComponent("VincentGOURBIN")
            .appendingPathComponent("RMBG-2-CoreML")
    }
}
