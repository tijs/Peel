//
//  ImageImport.swift
//  Peel
//

import AppKit

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

    /// Writes an image to the general pasteboard as PNG (preserving transparency).
    /// Returns whether the image could be encoded.
    @discardableResult
    static func copyToPasteboard(_ image: NSImage) -> Bool {
        guard let png = PeelImage.pngData(from: image) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        return true
    }

    /// Reads an image off the general pasteboard, if one is present.
    static func pasteboardImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        // A copied file shows up as a URL; prefer it so the export keeps the name.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first(where: PeelImage.isSupported),
           let image = try? PeelImage.loadImage(at: url) {
            return image
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           let image = images.first, image.size.width > 0 {
            return image
        }
        return nil
    }
}
