//
//  DropZoneView.swift
//  Peel
//

import SwiftUI
import UniformTypeIdentifiers

/// The empty state: drag an image in, or pick one from disk.
/// Also surfaces the last error when a previous attempt failed.
struct DropZoneView: View {
    @Environment(AppModel.self) private var model
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))

                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    Text("Drag an image here")
                        .font(.title2.weight(.medium))
                    Text("PNG, JPEG, HEIC, WebP — removed on your Mac, nothing uploaded")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Image…", action: openPanel)
                        .controlSize(.large)
                        .padding(.top, 4)
                }
                .padding(40)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
            )

            if model.phase == .failed, let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(24)
        .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted, perform: handleDrop)
    }

    // MARK: - File picker

    private func openPanel() {
        guard let url = ImageImport.runOpenPanel() else { return }
        Task { await model.loadAndProcess(url: url) }
    }

    // MARK: - Drag & drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        // Prefer a file URL so we keep the source name for the export filename.
        if let urlProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let url = Self.url(from: item) else { return }
                Task { @MainActor in await model.loadAndProcess(url: url) }
            }
            return true
        }
        // Fall back to a raw image (e.g. dragged from a browser or Photos).
        if let imageProvider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            _ = imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage,
                      let normalized = PeelImage.normalizedImage(from: image) else { return }
                Task { @MainActor in await model.process(normalized) }
            }
            return true
        }
        return false
    }

    private nonisolated static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }
}

#Preview {
    DropZoneView()
        .environment(AppModel(remover: PreviewEcho()))
        .frame(width: 480, height: 420)
}

private struct PreviewEcho: BackgroundRemoving {
    func removeBackground(from image: NSImage) async throws -> NSImage { image }
}
