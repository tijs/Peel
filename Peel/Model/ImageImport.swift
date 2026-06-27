//
//  ImageImport.swift
//  Peel
//

import AppKit
import UniformTypeIdentifiers

/// Bridges the AppKit panels and pasteboard used to bring an image into Peel.
/// Centralised here so the drop zone and the menu commands share one path.
@MainActor
enum ImageImport {
    /// Presents an open panel limited to supported image types; returns the choice.
    static func runOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = PeelImage.supportedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Open"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Writes an image to a pasteboard as PNG (preserving transparency).
    /// Returns whether the image could be encoded. The pasteboard is injectable
    /// so tests can round-trip through an isolated pasteboard.
    @discardableResult
    static func copyToPasteboard(_ image: NSImage, to pasteboard: NSPasteboard = .general) -> Bool {
        guard let png = PeelImage.pngData(from: image) else { return false }
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        return true
    }

    /// Presents a save panel and writes the image as PNG.
    ///
    /// Returns normally (without writing) if the user cancels the panel; throws
    /// `RemovalError.exportFailed` if encoding or the disk write fails, so the
    /// caller can tell the user instead of silently losing their export.
    static func savePNG(_ image: NSImage, filename: String) throws {
        guard let png = PeelImage.pngData(from: image) else {
            throw RemovalError.exportFailed("the image couldn’t be encoded as PNG")
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url)
        } catch {
            throw RemovalError.exportFailed(error.localizedDescription)
        }
    }

    /// Presents a modal alert describing a failed export.
    static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t save the image"
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.runModal()
    }

    /// Reads an image off a pasteboard, if one is present. The pasteboard is
    /// injectable so the read logic can be tested through an isolated pasteboard.
    static func pasteboardImage(from pasteboard: NSPasteboard = .general) -> NSImage? {
        // A copied file shows up as a URL; prefer it so the export keeps the name.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first(where: PeelImage.isSupported),
           let image = try? PeelImage.loadImage(at: url) {
            return image
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           let image = images.first,
           let normalized = PeelImage.normalizedImage(from: image) {
            return normalized
        }
        return nil
    }
}
