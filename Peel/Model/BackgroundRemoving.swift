//
//  BackgroundRemoving.swift
//  Peel
//

import AppKit

/// Abstraction over the background-removal engine.
///
/// The app depends on this protocol rather than a concrete CoreML type so the
/// UI and state logic can be exercised in tests with a lightweight fake, free of
/// the 233 MB model and the Apple Neural Engine.
protocol BackgroundRemoving: Sendable {
    /// Returns a copy of `image` with its background removed (transparent).
    func removeBackground(from image: NSImage) async throws -> NSImage

    /// Ensures the engine is ready before inference, reporting progress in 0...1
    /// with a human-readable status. On first run this downloads the ~233 MB model;
    /// afterwards it returns immediately.
    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws
}

extension BackgroundRemoving {
    /// Engines that need no preparation (e.g. test fakes) inherit a no-op.
    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {}
}

/// Failures surfaced to the user while removing a background.
enum RemovalError: LocalizedError, Equatable {
    /// The supplied data could not be decoded into an image.
    case unreadableImage
    /// The image decoded but produced no usable bitmap (e.g. zero-sized).
    case emptyImage
    /// The CoreML model failed to load or run.
    case modelFailure(String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "That file isn’t an image Peel can read."
        case .emptyImage:
            return "That image appears to be empty."
        case .modelFailure(let detail):
            return "Background removal failed: \(detail)"
        }
    }
}
