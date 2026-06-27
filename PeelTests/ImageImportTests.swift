//
//  ImageImportTests.swift
//  PeelTests
//

import AppKit
@testable import Peel
import Testing

@MainActor
struct ImageImportTests {
    private func isolatedPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("PeelTests.\(UUID().uuidString)"))
    }

    @Test func copyEncodesImageOntoPasteboard() {
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.releaseGlobally() }

        #expect(ImageImport.copyToPasteboard(TestImage.make(), to: pasteboard))
        #expect(pasteboard.data(forType: .png) != nil)
    }

    @Test func pasteboardImageRoundTripsACopiedImage() {
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.releaseGlobally() }

        #expect(ImageImport.copyToPasteboard(TestImage.make(), to: pasteboard))
        #expect(ImageImport.pasteboardImage(from: pasteboard) != nil)
    }

    @Test func pasteboardImageIsNilWhenEmpty() {
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.releaseGlobally() }

        #expect(ImageImport.pasteboardImage(from: pasteboard) == nil)
    }
}
