//
//  AppModelTests.swift
//  PeelTests
//

import AppKit
@testable import Peel
import Testing

@MainActor
struct AppModelTests {
    @Test func startsIdle() {
        let model = AppModel(remover: FakeRemover())
        #expect(model.phase == .idle)
        #expect(model.originalImage == nil)
        #expect(model.resultImage == nil)
    }

    @Test func successfulRemovalSurfacesResult() async {
        let output = TestImage.make(color: .green)
        let model = AppModel(remover: FakeRemover(output: output))
        let input = TestImage.make()

        await model.process(input)

        #expect(model.phase == .result)
        #expect(model.originalImage === input)
        #expect(model.resultImage === output)
        #expect(model.errorMessage == nil)
    }

    @Test func failureSurfacesMessage() async {
        let model = AppModel(remover: FakeRemover(behavior: .fail(.modelFailure("boom"))))

        await model.process(TestImage.make())

        #expect(model.phase == .failed)
        #expect(model.resultImage == nil)
        #expect(model.errorMessage?.contains("boom") == true)
    }

    @Test func resetReturnsToIdle() async {
        let model = AppModel(remover: FakeRemover())
        await model.process(TestImage.make())
        #expect(model.phase == .result)

        model.reset()

        #expect(model.phase == .idle)
        #expect(model.originalImage == nil)
        #expect(model.resultImage == nil)
        #expect(model.sourceURL == nil)
    }

    @Test func loadingUnsupportedURLFails() async {
        let model = AppModel(remover: FakeRemover())
        let bogus = URL(fileURLWithPath: "/tmp/not-an-image.txt")

        await model.loadAndProcess(url: bogus)

        #expect(model.phase == .failed)
        #expect(model.errorMessage != nil)
    }

    /// A job superseded by `reset()` must not clobber the newer idle state when it
    /// finally completes — this guards the generation token in `AppModel`.
    @Test func staleCompletionAfterResetIsIgnored() async {
        let model = AppModel(remover: FakeRemover(delay: .milliseconds(80)))

        let job = Task { await model.process(TestImage.make()) }
        // Let the job enter the processing phase, then abandon it.
        try? await Task.sleep(for: .milliseconds(20))
        #expect(model.phase == .processing)
        model.reset()

        await job.value
        #expect(model.phase == .idle)
        #expect(model.resultImage == nil)
    }
}
