//
//  ModelFileDownloader.swift
//  Peel
//

import Foundation

/// Downloads an RMBG-2 model package straight into the on-disk cache, reporting
/// real byte-level progress.
///
/// We do this instead of leaning on RMBG2Swift's built-in downloader because the
/// latter reports only coarse step progress — it jumps from 60% to 90% with no
/// feedback across the entire ~458 MB weights download, which looks frozen and
/// can stall on HuggingFace's Xet CDN. Once the files are in place, the package
/// compiles them (it skips downloading when the `.mlpackage` already exists).
struct ModelFileDownloader {
    /// The cache directory the package reads from (`…/RMBG-2-CoreML`).
    let cacheDirectory: URL

    private static let baseURL = "https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML/resolve/main"

    /// Relative paths inside an `.mlpackage`. `weight.bin` is ~99% of the bytes.
    private static let relativePaths = [
        "Manifest.json",
        "Data/com.apple.CoreML/model.mlmodel",
        ModelOption.weightsSubpath
    ]

    /// Downloads `option`'s package files into the cache, reporting overall
    /// progress in 0...1 (dominated by the weights file).
    func download(
        _ option: ModelOption,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let packageDirectory = cacheDirectory.appendingPathComponent(option.packageFilename)

        for relativePath in Self.relativePaths {
            guard let url = URL(string: "\(Self.baseURL)/\(option.packageFilename)/\(relativePath)") else {
                throw RemovalError.modelFailure("Bad model URL for \(relativePath)")
            }
            let destination = packageDirectory.appendingPathComponent(relativePath)
            // Only the large weights file gets byte-level progress.
            let report: (@Sendable (Double) -> Void)? = relativePath == ModelOption.weightsSubpath ? progress : nil
            try await downloadFile(from: url, to: destination, reporting: report)
        }
    }

    private func downloadFile(
        from url: URL,
        to destination: URL,
        reporting: (@Sendable (Double) -> Void)?
    ) async throws {
        let delegate = reporting.map(DownloadProgressDelegate.init)
        let (temporaryURL, response) = try await URLSession.shared.download(from: url, delegate: delegate)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw RemovalError.modelFailure("Model download failed (HTTP \(code)).")
        }

        let manager = FileManager.default
        try manager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.moveItem(at: temporaryURL, to: destination)
    }
}

/// Bridges `URLSessionDownloadTask` byte progress to a Sendable callback.
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    /// Required by the protocol; the async `download(from:delegate:)` returns the file.
    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didFinishDownloadingTo _: URL
    ) {}
}
