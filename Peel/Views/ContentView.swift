//
//  ContentView.swift
//  Peel
//

import SwiftUI

/// Root view. Routes between the empty drop zone, processing, and result states.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(ModelManager.self) private var models

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                SettingsLink {
                    Label {
                        Text(modelLabel)
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .help("Change model quality")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            content
        }
        .frame(minWidth: 480, minHeight: 420)
        .animation(.smooth(duration: 0.25), value: model.phase)
        // A first-run model download happens inside processing, bypassing
        // ModelManager, so re-scan the cache once it finishes.
        .onChange(of: model.phase) { models.refreshInstalled() }
    }

    /// The selected model plus its install/download state, so the toolbar reads
    /// "Not downloaded" before the first run, live progress during it, and just
    /// the name once installed.
    private var modelLabel: String {
        let name = models.selected.displayName
        if let progress = model.downloadProgress {
            return "Model: \(name) · Downloading \(Int(progress * 100))%"
        }
        if models.installed.contains(models.selected) {
            return "Model: \(name)"
        }
        return "Model: \(name) · Not downloaded"
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle, .failed:
            DropZoneView()
        case .processing:
            ProcessingView()
        case .result:
            ResultView()
        }
    }
}

#Preview("Idle") {
    ContentView()
        .environment(AppModel(remover: PreviewRemover()))
        .environment(ModelManager())
}

/// A trivial engine for previews that echoes the input.
private struct PreviewRemover: BackgroundRemoving {
    func removeBackground(from image: NSImage) async throws -> NSImage { image }
}
