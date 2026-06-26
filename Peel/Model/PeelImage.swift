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
        guard let normalized = normalizedImage(from: image) else { throw RemovalError.unreadableImage }
        return normalized
    }

    /// Draws any AppKit image representation into a plain sRGB 8-bit RGBA bitmap.
    ///
    /// Photos can hand Peel HDR HEIC/MPP images with gain maps. Normalizing at the
    /// import boundary avoids passing HDR gain-map-backed representations into the
    /// background-removal library or PNG exporter, where ImageIO/CoreGraphics may
    /// emit tone-mapping and unsupported-pixel-format errors.
    nonisolated static func normalizedImage(from image: NSImage) -> NSImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return normalizedImage(from: cgImage)
        }

        let pixelSize = rasterPixelSize(for: image)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)
        let bytesPerRow = width * 4

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        graphicsContext.imageInterpolation = .high

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    /// Encodes an image as PNG, preserving any alpha channel.
    ///
    /// Returns nil only when the image has no rasterizable representation.
    nonisolated static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)
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

    private nonisolated static func rasterPixelSize(for image: NSImage) -> NSSize {
        let bestRepresentation = image.representations.max { lhs, rhs in
            (lhs.pixelsWide * lhs.pixelsHigh) < (rhs.pixelsWide * rhs.pixelsHigh)
        }
        if let bestRepresentation,
           bestRepresentation.pixelsWide > 0,
           bestRepresentation.pixelsHigh > 0 {
            return NSSize(width: bestRepresentation.pixelsWide, height: bestRepresentation.pixelsHigh)
        }

        return NSSize(width: ceil(image.size.width), height: ceil(image.size.height))
    }

    private nonisolated static func cgImage(from image: NSImage) -> CGImage? {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        guard let normalized = normalizedImage(from: image) else { return nil }
        return normalized.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private nonisolated static func normalizedImage(from cgImage: CGImage) -> NSImage {
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = size

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}
