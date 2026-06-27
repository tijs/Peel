//
//  ResultView.swift
//  Peel
//

import SwiftUI
import UniformTypeIdentifiers

/// Shows the original next to the cut-out result and offers export actions.
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @State private var didCopy = false
    /// The encoded PNG payload for drag-out, computed once per result image
    /// rather than on every `body` evaluation (e.g. each `didCopy` toggle).
    @State private var exported: ExportedImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                if let original = model.originalImage {
                    ImageCard(title: "Original", checkerboard: false) {
                        Image(nsImage: original).resizable().scaledToFit()
                    }
                }
                if let result = model.resultImage {
                    ImageCard(title: "Result", checkerboard: true) {
                        resultImage(result)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar
        }
        .padding(20)
        .task(id: model.resultImage) { updateExport() }
    }

    /// The result image, draggable as a PNG file once its payload is encoded.
    @ViewBuilder
    private func resultImage(_ result: NSImage) -> some View {
        let view = Image(nsImage: result).resizable().scaledToFit()
        if let exported {
            view.draggable(exported)
        } else {
            view
        }
    }

    /// Encodes the export payload for the current result, off the render path.
    /// Skips attaching a drag payload when encoding fails rather than handing
    /// other apps an empty file.
    private func updateExport() {
        guard let result = model.resultImage, let data = PeelImage.pngData(from: result) else {
            exported = nil
            return
        }
        exported = ExportedImage(data: data, filename: PeelImage.exportFilename(for: model.sourceURL))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                model.reset()
            } label: {
                Label("New Image", systemImage: "arrow.uturn.backward")
            }

            Spacer()

            Text("Tip: drag the result straight into another app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // ⌘C / ⌘S live on the menu commands in PeelApp; registering them
            // here too would be a second, drift-prone source of truth.
            Button {
                copyToPasteboard()
            } label: {
                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
            }

            Button {
                save()
            } label: {
                Label("Save…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
    }

    // MARK: - Export

    private func copyToPasteboard() {
        guard let result = model.resultImage, ImageImport.copyToPasteboard(result) else { return }
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }

    private func save() {
        guard let result = model.resultImage else { return }
        do {
            try ImageImport.savePNG(result, filename: PeelImage.exportFilename(for: model.sourceURL))
        } catch {
            ImageImport.presentError(error)
        }
    }
}

/// A titled image panel; the result panel sits over a transparency checkerboard.
private struct ImageCard<Content: View>: View {
    let title: String
    let checkerboard: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ZStack {
                if checkerboard { CheckerboardBackground() }
                content.padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.2))
            )
        }
    }
}

/// A PNG payload that can be dragged into Finder or other apps as a file.
struct ExportedImage: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { $0.filename }
    }
}

#Preview {
    @Previewable @State var model = AppModel(remover: Echo())
    ResultView()
        .environment(model)
        .frame(width: 560, height: 460)
        .task {
            let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil) ?? NSImage()
            await model.process(image)
        }
}

private struct Echo: BackgroundRemoving {
    func removeBackground(from image: NSImage) async throws -> NSImage { image }
}
