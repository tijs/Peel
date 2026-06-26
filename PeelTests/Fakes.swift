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
