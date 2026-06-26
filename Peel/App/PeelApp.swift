//
//  PeelApp.swift
//  Peel
//

import SwiftUI

@main
struct PeelApp: App {
    @State private var model: AppModel
    @State private var models: ModelManager

    init() {
        let models = ModelManager()
        _models = State(initialValue: models)
        _model = State(initialValue: AppModel(
            remover: BackgroundRemover(option: { await MainActor.run { models.selected } })
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image…", action: openImage)
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Copy Result", action: copyResult)
                    .keyboardShortcut("c", modifiers: .command)
                    .disabled(model.phase != .result)
                Button("Paste Image", action: pasteImage)
                    .keyboardShortcut("v", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(models)
        }
    }

    private func openImage() {
        guard let url = ImageImport.runOpenPanel() else { return }
        Task { await model.loadAndProcess(url: url) }
    }

    private func pasteImage() {
        guard let image = ImageImport.pasteboardImage() else { return }
        Task { await model.process(image) }
    }

    private func copyResult() {
        guard let result = model.resultImage else { return }
        ImageImport.copyToPasteboard(result)
    }
}
