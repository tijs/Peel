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

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                if let original = model.originalImage {
                    ImageCard(title: "Original", checkerboard: false) {
                        Image(nsImage: original).resizable().scaledToFit()
                    }
                }
                if let result = model.resultImage {
                    let exported = ExportedImage(
                        data: PeelImage.pngData(from: result) ?? Data(),
                        filename: PeelImage.exportFilename(for: model.sourceURL)
                    )
                    ImageCard(title: "Result", checkerboard: true) {
                        Image(nsImage: result)
                            .resizable()
                            .scaledToFit()
                            .draggable(exported)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar
        }
        .padding(20)
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

            Button {
                copyToPasteboard()
            } label: {
                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)

            Button {
                save()
            } label: {
                Label("Save…", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
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
        guard let result = model.resultImage, let png = PeelImage.pngData(from: result) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = PeelImage.exportFilename(for: model.sourceURL)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? png.write(to: url)
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
