//
//  ContentView.swift
//  Peel
//

import SwiftUI

/// Root view. Routes between the empty drop zone, processing, and result states.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .idle, .failed:
                DropZoneView()
            case .processing:
                ProcessingView()
            case .result:
                ResultView()
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .animation(.smooth(duration: 0.25), value: model.phase)
    }
}

#Preview("Idle") {
    ContentView()
        .environment(AppModel(remover: PreviewRemover()))
}

/// A trivial engine for previews that echoes the input.
private struct PreviewRemover: BackgroundRemoving {
    func removeBackground(from image: NSImage) async throws -> NSImage { image }
}
