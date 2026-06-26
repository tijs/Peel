//
//  PeelImage.swift
//  Peel
//

import AppKit
import UniformTypeIdentifiers

/// Pure helpers for reading, validating, and exporting images.
///
/// Kept free of UI and model dependencies so the logic is testable in isolation.
/// Members are `nonisolated` (the project defaults to `MainActor` isolation) so
/// they can run off the main actor — e.g. when a drag exports PNG data.
enum PeelImage {
    /// Content types Peel will accept as input.
    nonisolated static let supportedTypes: [UTType] = [.png, .jpeg, .heic, .heif, .webP, .tiff, .bmp, .gif]

    /// Whether `url` points at an image type Peel can read, judged by its UTType.
    nonisolated static func isSupported(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return supportedTypes.contains { type.conforms(to: $0) }
    }

    /// Loads an image from disk, throwing a typed error rather than returning nil.
    nonisolated static func loadImage(at url: URL) throws -> NSImage {
        guard isSupported(url) else { throw RemovalError.unreadableImage }
        guard let image = NSImage(contentsOf: url) else { throw RemovalError.unreadableImage }
        guard image.size.width > 0, image.size.height > 0 else { throw RemovalError.emptyImage }
        return image
    }

    /// Encodes an image as PNG, preserving any alpha channel.
    ///
    /// Returns nil only when the image has no rasterizable representation.
    nonisolated static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = image.size
        return rep.representation(using: .png, properties: [:])
    }

    /// A default filename for an exported result, derived from the source URL.
    ///
    /// `picture.jpg` becomes `picture-removed.png`; a nil source falls back to a
    /// generic name.
    nonisolated static func exportFilename(for sourceURL: URL?) -> String {
        let base = sourceURL?.deletingPathExtension().lastPathComponent ?? "image"
        return "\(base)-removed.png"
    }
}
