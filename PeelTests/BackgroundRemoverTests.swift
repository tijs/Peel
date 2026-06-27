//
//  BackgroundRemoverTests.swift
//  PeelTests
//

import AppKit
@testable import Peel
import Testing

@MainActor
struct BackgroundRemoverTests {
    private struct GenericError: Error {}

    private func tempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A generic engine-creation failure is normalized to `modelFailure` so the
    /// UI shows the friendly "Background removal failed" message.
    @Test func wrapsGenericFactoryErrorAsModelFailure() async {
        let remover = BackgroundRemover(cacheDirectory: nil, makeEngine: { _, _ in throw GenericError() })

        do {
            _ = try await remover.removeBackground(from: TestImage.make())
            Issue.record("expected an error")
        } catch let error as RemovalError {
            guard case .modelFailure = error else {
                Issue.record("expected .modelFailure, got \(error)")
                return
            }
        } catch {
            Issue.record("expected RemovalError, got \(error)")
        }
    }

    /// A `RemovalError` from the factory is surfaced unchanged rather than being
    /// re-wrapped into a less specific `modelFailure`.
    @Test func passesThroughRemovalErrorFromFactory() async {
        let remover = BackgroundRemover(cacheDirectory: nil, makeEngine: { _, _ in throw RemovalError.emptyImage })

        await #expect(throws: RemovalError.emptyImage) {
            try await remover.removeBackground(from: TestImage.make())
        }
    }

    /// Repeated preparation for the same option coalesces to a single engine
    /// creation — the guard against the double-download bug.
    @Test func coalescesEngineCreationForSameOption() async throws {
        let counter = CallCounter()
        let remover = BackgroundRemover(
            option: { .standard },
            cacheDirectory: nil,
            makeEngine: { _, _ in
                await counter.increment()
                return PassthroughEngine()
            }
        )

        try await remover.prepare { _, _ in }
        try await remover.prepare { _, _ in }

        #expect(await counter.count == 1)
    }

    /// Distinct options keep distinct engines, so switching the default model
    /// builds the new one without discarding the old.
    @Test func createsDistinctEnginesPerOption() async throws {
        let counter = CallCounter()
        let option = OptionBox(.standard)
        let remover = BackgroundRemover(
            option: { option.value },
            cacheDirectory: nil,
            makeEngine: { _, _ in
                await counter.increment()
                return PassthroughEngine()
            }
        )

        try await remover.prepare { _, _ in }
        option.value = .highQuality
        try await remover.prepare { _, _ in }

        #expect(await counter.count == 2)
    }

    /// On first use the model is fetched through the integrity-verifying
    /// provisioner before the engine is built, so the engine never triggers
    /// RMBG2's own unverified download.
    @Test func provisionsThroughVerifiedPathOnFirstUse() async throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let provisioner = FakeProvisioner(behavior: .succeed)
        let remover = BackgroundRemover(
            option: { .standard },
            cacheDirectory: directory,
            provisioner: provisioner,
            makeEngine: { _, _ in PassthroughEngine() }
        )

        try await remover.prepare { _, _ in }

        #expect(provisioner.callCount == 1)
    }

    /// When the model is already cached, provisioning is skipped so a cached
    /// install isn't needlessly re-downloaded on every launch.
    @Test func skipsProvisioningWhenAlreadyInstalled() async throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // A compiled artifact present in the cache counts as installed.
        try Data().write(to: directory.appendingPathComponent(ModelOption.standard.compiledFilename))
        let provisioner = FakeProvisioner(behavior: .succeed)
        let remover = BackgroundRemover(
            option: { .standard },
            cacheDirectory: directory,
            provisioner: provisioner,
            makeEngine: { _, _ in PassthroughEngine() }
        )

        try await remover.prepare { _, _ in }

        #expect(provisioner.callCount == 0)
    }
}
