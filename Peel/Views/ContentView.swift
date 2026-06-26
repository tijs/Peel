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
                        Text("Model: \(models.selected.displayName)")
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
