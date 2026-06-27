//
//  PeelTests.swift
//  PeelTests
//

import AppKit
@testable import Peel
import Testing

/// Tests for the pure image helpers in `PeelImage`.
struct PeelImageTests {
    @Test func recognisesSupportedExtensions() {
        #expect(PeelImage.isSupported(URL(fileURLWithPath: "/a/photo.png")))
        #expect(PeelImage.isSupported(URL(fileURLWithPath: "/a/photo.JPG")))
        #expect(PeelImage.isSupported(URL(fileURLWithPath: "/a/photo.heic")))
        #expect(PeelImage.isSupported(URL(fileURLWithPath: "/a/photo.webp")))
    }

    @Test func rejectsUnsupportedExtensions() {
        #expect(!PeelImage.isSupported(URL(fileURLWithPath: "/a/notes.txt")))
        #expect(!PeelImage.isSupported(URL(fileURLWithPath: "/a/archive.zip")))
        #expect(!PeelImage.isSupported(URL(fileURLWithPath: "/a/noextension")))
    }

    @Test func loadingUnsupportedTypeThrows() {
        #expect(throws: RemovalError.unreadableImage) {
            try PeelImage.loadImage(at: URL(fileURLWithPath: "/tmp/whatever.txt"))
        }
    }

    @Test func exportFilenameDerivesFromSource() {
        let source = URL(fileURLWithPath: "/Users/me/Pictures/portrait.jpg")
        #expect(PeelImage.exportFilename(for: source) == "portrait-removed.png")
    }

    @Test func exportFilenameFallsBackWhenNoSource() {
        #expect(PeelImage.exportFilename(for: nil) == "image-removed.png")
    }

    @Test func pngDataProducesAValidPNG() throws {
        let image = TestImage.make()
        let data = try #require(PeelImage.pngData(from: image))
        #expect(!data.isEmpty)
        // PNG magic number.
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(Array(data.prefix(8)) == signature)
    }

    /// A zero-sized image has no usable bitmap; normalization rejects it, which
    /// is what backs the `emptyImage` guard in `loadImage`.
    @Test func normalizedImageRejectsZeroSize() {
        #expect(PeelImage.normalizedImage(from: NSImage(size: .zero)) == nil)
    }
}
