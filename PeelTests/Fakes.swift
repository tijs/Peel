//
//  Fakes.swift
//  PeelTests
//

import AppKit
@testable import Peel

/// A configurable stand-in for the real CoreML engine, so the state machine can
/// be tested without the 233 MB model.
final class FakeRemover: BackgroundRemoving, @unchecked Sendable {
    enum Behavior {
        case succeed
        case fail(RemovalError)
    }

    let behavior: Behavior
    let delay: Duration
    /// A sentinel returned on success so tests can prove the *result* image is
    /// surfaced (not the original input).
    let output: NSImage

    init(behavior: Behavior = .succeed, delay: Duration = .zero, output: NSImage = TestImage.make()) {
        self.behavior = behavior
        self.delay = delay
        self.output = output
    }

    func removeBackground(from _: NSImage) async throws -> NSImage {
        if delay != .zero { try? await Task.sleep(for: delay) }
        switch behavior {
        case .succeed: return output
        case let .fail(error): throw error
        }
    }
}

/// Records the progress closure `prepare` is handed so a test can fire a late
/// callback (after preparation resolved) and prove the staleness guard drops it.
final class ProgressRemover: BackgroundRemoving, @unchecked Sendable {
    let output: NSImage
    private let prepareEvents: [(Double, String)]
    private(set) nonisolated(unsafe) var lastProgress: (@Sendable (Double, String) -> Void)?

    init(output: NSImage = TestImage.make(), prepareEvents: [(Double, String)] = []) {
        self.output = output
        self.prepareEvents = prepareEvents
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        lastProgress = progress
        for event in prepareEvents { progress(event.0, event.1) }
    }

    func removeBackground(from _: NSImage) async throws -> NSImage { output }
}

/// Suspends inside `prepare` after emitting one progress event, so a test can
/// observe `downloadProgress` while preparation is genuinely in flight.
final class GatedRemover: BackgroundRemoving, @unchecked Sendable {
    let output: NSImage
    private let event: (Double, String)
    private nonisolated(unsafe) var continuation: CheckedContinuation<Void, Never>?
    private(set) nonisolated(unsafe) var isSuspended = false

    init(event: (Double, String), output: NSImage = TestImage.make()) {
        self.event = event
        self.output = output
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        progress(event.0, event.1)
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.isSuspended = true
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }

    func removeBackground(from _: NSImage) async throws -> NSImage { output }
}

/// A trivial engine that returns the input untouched, for `BackgroundRemover`
/// dedup tests that only care how often the factory ran.
struct PassthroughEngine: ImageMatteEngine {
    func removeBackground(from image: NSImage) async throws -> NSImage { image }
}

/// Counts factory/provisioner invocations across concurrent callers.
actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

/// Lets a test flip the model option `BackgroundRemover` reads between calls.
final class OptionBox: @unchecked Sendable {
    nonisolated(unsafe) var value: ModelOption
    init(_ value: ModelOption) { self.value = value }
}

/// Stand-in for the real download+compile pipeline so `ModelManager.download`'s
/// state machine can be tested without a network or the CoreML compiler.
final class FakeProvisioner: ModelProvisioning, @unchecked Sendable {
    enum Behavior {
        case succeed
        case fail(Error)
    }

    let behavior: Behavior
    private let gated: Bool
    private(set) nonisolated(unsafe) var callCount = 0
    private nonisolated(unsafe) var continuation: CheckedContinuation<Void, Never>?

    init(behavior: Behavior = .succeed, gated: Bool = false) {
        self.behavior = behavior
        self.gated = gated
    }

    func provision(
        _: ModelOption,
        into _: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        callCount += 1
        progress(0.5)
        if gated {
            await withCheckedContinuation { self.continuation = $0 }
        }
        if case let .fail(error) = behavior { throw error }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

/// A `URLProtocol` that returns a canned HTTP response, so `ModelFileDownloader`
/// can be exercised without a live HuggingFace download.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data("model-bytes".utf8)

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // URLProtocol requires these as `class func` overrides; they can't be `static`.
    // swiftlint:disable static_over_final_class
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    // swiftlint:enable static_over_final_class

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: Self.statusCode,
                  httpVersion: nil,
                  headerFields: nil
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum TestImage {
    /// A small opaque bitmap suitable for encoding tests.
    static func make(size: CGSize = CGSize(width: 8, height: 8), color: NSColor = .red) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
