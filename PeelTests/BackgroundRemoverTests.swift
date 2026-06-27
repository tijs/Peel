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

    /// A generic engine-creation failure is normalized to `modelFailure` so the
    /// UI shows the friendly "Background removal failed" message.
    @Test func wrapsGenericFactoryErrorAsModelFailure() async {
        let remover = BackgroundRemover(makeEngine: { _, _ in throw GenericError() })

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
        let remover = BackgroundRemover(makeEngine: { _, _ in throw RemovalError.emptyImage })

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
}
