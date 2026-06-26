//
//  ModelManagerTests.swift
//  PeelTests
//

import Foundation
@testable import Peel
import Testing

@MainActor
struct ModelManagerTests {
    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let suite = "PeelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, suite)
    }

    @Test func defaultsToStandard() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = ModelManager(defaults: defaults, cacheDirectory: nil)
        #expect(manager.selected == .standard)
    }

    @Test func persistsSelectionAcrossInstances() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = ModelManager(defaults: defaults, cacheDirectory: nil)
        manager.selected = .highQuality

        let reloaded = ModelManager(defaults: defaults, cacheDirectory: nil)
        #expect(reloaded.selected == .highQuality)
    }

    @Test func nilCacheMeansNothingInstalled() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = ModelManager(defaults: defaults, cacheDirectory: nil)
        #expect(!manager.isInstalled(.standard))
        #expect(manager.installed.isEmpty)
    }

    @Test func detectsInstalledModelFromCacheFiles() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ModelManager(defaults: defaults, cacheDirectory: directory)
        #expect(!manager.isInstalled(.standard))

        // A file matching the compiled artifact name counts as installed.
        try Data().write(to: directory.appendingPathComponent(ModelOption.standard.compiledFilename))
        manager.refreshInstalled()

        #expect(manager.isInstalled(.standard))
        #expect(manager.installed.contains(.standard))
        #expect(!manager.installed.contains(.highQuality))
    }

    @Test func detectsCompleteUncompiledPackageAsInstalled() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // A downloaded-but-not-yet-compiled .mlpackage with its weights counts.
        let weights = directory
            .appendingPathComponent(ModelOption.highQuality.packageFilename)
            .appendingPathComponent(ModelOption.weightsSubpath)
        try FileManager.default.createDirectory(
            at: weights.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: weights)

        let manager = ModelManager(defaults: defaults, cacheDirectory: directory)
        #expect(manager.isInstalled(.highQuality))
    }

    @Test func ignoresPartialPackageMissingWeights() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // An interrupted download: package dir + manifest, but no weights blob.
        let packageDirectory = directory.appendingPathComponent(ModelOption.highQuality.packageFilename)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        try Data().write(to: packageDirectory.appendingPathComponent("Manifest.json"))

        let manager = ModelManager(defaults: defaults, cacheDirectory: directory)
        #expect(!manager.isInstalled(.highQuality))
    }
}
