//
//  ProcessingView.swift
//  Peel
//

import SwiftUI

/// Shown while inference runs. On first launch it also reports model-download
/// progress, which can take a while for the ~233 MB download.
struct ProcessingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if let original = model.originalImage {
                    Image(nsImage: original)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.3)
                        .blur(radius: 2)
                }
                ProgressView()
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                Text(model.statusText)
                    .font(.headline)
                if let progress = model.downloadProgress {
                    ProgressView(value: progress)
                        .frame(maxWidth: 280)
                    Text("Preparing the model on first launch — this happens only once.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

#Preview("Inference") {
    @Previewable @State var model = AppModel(remover: SlowRemover())
    ProcessingView()
        .environment(model)
        .frame(width: 480, height: 420)
        .task { await model.process(NSImage(systemSymbolName: "leaf", accessibilityDescription: nil) ?? NSImage()) }
}

private struct SlowRemover: BackgroundRemoving {
    func removeBackground(from image: NSImage) async throws -> NSImage {
        try? await Task.sleep(for: .seconds(30))
        return image
    }
}
