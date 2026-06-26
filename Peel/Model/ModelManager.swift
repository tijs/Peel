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

    /// Whether the option's model files exist on disk.
    func isInstalled(_ option: ModelOption) -> Bool {
        guard let cacheDirectory else { return false }
        let manager = FileManager.default
        return manager.fileExists(atPath: cacheDirectory.appendingPathComponent(option.compiledFilename).path)
            || manager.fileExists(atPath: cacheDirectory.appendingPathComponent(option.packageFilename).path)
    }

    /// Re-scans the cache and updates `installed`.
    func refreshInstalled() {
        installed = Set(ModelOption.allCases.filter(isInstalled))
    }

    /// Downloads (and compiles) the option's model, reporting progress. No-op if
    /// a download for that option is already running.
    func download(_ option: ModelOption) async {
        guard progress[option] == nil else { return }
        lastError[option] = nil
        progress[option] = 0

        let downloader = ModelDownloader(configuration: option.configuration()) { fraction, _ in
            Task { @MainActor in
                // Only update while the download is still considered active.
                if self.progress[option] != nil { self.progress[option] = fraction }
            }
        }
        do {
            _ = try await downloader.getCompiledModelURL()
        } catch {
            lastError[option] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        progress[option] = nil
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
