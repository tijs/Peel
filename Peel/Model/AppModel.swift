//
//  AppModel.swift
//  Peel
//

import AppKit
import Observation

/// Drives the single-window flow: idle → processing → result (or failure).
///
/// Holds no CoreML knowledge — it talks to a `BackgroundRemoving`, so the whole
/// state machine is testable with a fake engine.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case processing
        case result
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var originalImage: NSImage?
    private(set) var resultImage: NSImage?
    private(set) var sourceURL: URL?
    private(set) var errorMessage: String?

    /// First-run model-download progress in 0...1, or nil once the model is ready
    /// (cached from a prior run) or inference has started.
    private(set) var downloadProgress: Double?
    /// Human-readable status shown during the processing phase.
    private(set) var statusText = "Removing background…"

    private let remover: BackgroundRemoving

    /// Identifies the in-flight job so a stale completion can't clobber newer state
    /// after the user resets or drops another image mid-inference.
    private var generation = 0

    /// True only while awaiting model preparation, so a progress callback that
    /// arrives after preparation resolved can't re-show the download bar during
    /// inference.
    private var acceptingProgress = false

    init(remover: BackgroundRemoving) {
        self.remover = remover
    }

    /// Loads an image from disk and runs it through the engine.
    func loadAndProcess(url: URL) async {
        do {
            let image = try PeelImage.loadImage(at: url)
            await process(image, sourceURL: url)
        } catch {
            fail(with: error)
        }
    }

    /// Runs an already-decoded image (e.g. from the clipboard or a dropped bitmap).
    func process(_ image: NSImage, sourceURL: URL? = nil) async {
        generation += 1
        let token = generation

        originalImage = image
        self.sourceURL = sourceURL
        resultImage = nil
        errorMessage = nil
        downloadProgress = nil
        statusText = "Removing background…"
        acceptingProgress = true
        phase = .processing

        do {
            try await remover.prepare { fraction, status in
                Task { @MainActor in
                    guard self.generation == token, self.acceptingProgress else { return }
                    self.downloadProgress = fraction
                    self.statusText = status
                }
            }
            acceptingProgress = false
            guard token == generation else { return }
            downloadProgress = nil
            statusText = "Removing background…"

            let output = try await remover.removeBackground(from: image)
            guard token == generation else { return }
            resultImage = output
            phase = .result
        } catch {
            guard token == generation else { return }
            fail(with: error)
        }
    }

    /// Returns to the empty drop zone, abandoning any in-flight work.
    func reset() {
        generation += 1
        acceptingProgress = false
        phase = .idle
        originalImage = nil
        resultImage = nil
        sourceURL = nil
        errorMessage = nil
        downloadProgress = nil
    }

    private func fail(with error: Error) {
        acceptingProgress = false
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        phase = .failed
    }
}
