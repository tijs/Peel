//
//  SettingsView.swift
//  Peel
//

import SwiftUI

/// The Settings window (⌘,): pick the default model and manage downloads.
struct SettingsView: View {
    @Environment(ModelManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager
        Form {
            Section {
                Picker("Default model", selection: $manager.selected) {
                    ForEach(ModelOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Default Model")
            } footer: {
                Text(
                    "Used for every removal. An uninstalled model downloads the "
                        + "first time you use it."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Models") {
                ForEach(ModelOption.allCases) { option in
                    ModelRow(option: option)
                }
            }

            if let directory = manager.cacheDirectory {
                Section {
                    LabeledContent("Stored in") {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([directory])
                        } label: {
                            Text(directory.path(percentEncoded: false))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 380)
        // A first-run download happens during processing, outside ModelManager,
        // so re-scan the cache when Settings opens to show the true install state.
        .task { manager.refreshInstalled() }
    }
}

/// One row per model: name, description, and install state / download control.
private struct ModelRow: View {
    @Environment(ModelManager.self) private var manager
    let option: ModelOption

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(option.displayName).fontWeight(.medium)
                    if manager.selected == option {
                        Text("Default")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                Text(option.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = manager.lastError[option] {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var trailing: some View {
        if let fraction = manager.progress[option] {
            VStack(alignment: .trailing, spacing: 3) {
                ProgressView(value: fraction).frame(width: 130)
                HStack(spacing: 6) {
                    if let status = manager.status[option] {
                        Text(status)
                    }
                    Text("\(Int(fraction * 100))%").monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else if manager.installed.contains(option) {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        } else {
            Button("Download \(option.approximateSize)") {
                Task { await manager.download(option) }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(ModelManager())
}
