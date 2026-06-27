//
//  ModelFileDownloader.swift
//  Peel
//

import CryptoKit
import Foundation

/// Downloads an RMBG-2 model package straight into the on-disk cache, reporting
/// real byte-level progress.
///
/// We do this instead of leaning on RMBG2Swift's built-in downloader because the
/// latter reports only coarse step progress — it jumps from 60% to 90% with no
/// feedback across the entire ~458 MB weights download, which looks frozen and
/// can stall on HuggingFace's Xet CDN. Once the files are in place, the package
/// compiles them (it skips downloading when the `.mlpackage` already exists).
nonisolated struct ModelFileDownloader {
    /// The cache directory the package reads from (`…/RMBG-2-CoreML`).
    let cacheDirectory: URL

    /// Configuration for the download session. Injected so HTTP-error and
    /// success paths can be tested with a stubbed `URLProtocol` instead of a
    /// live download. (A fresh session is created per file so it can carry a
    /// progress delegate — see `ModelDownloadDelegate`.)
    let sessionConfiguration: URLSessionConfiguration

    init(cacheDirectory: URL, sessionConfiguration: URLSessionConfiguration = .default) {
        self.cacheDirectory = cacheDirectory
        self.sessionConfiguration = sessionConfiguration
    }

    /// Immutable commit the model files are fetched from, instead of the moving
    /// `main` branch. Pinning makes downloads reproducible and means the
    /// `ModelOption.weightsSHA256` digests describe exactly these bytes.
    static let pinnedRevision = "0da071b52c402b293c8b13af9148bac21b4a8456"

    private static let baseURL =
        "https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML/resolve/\(pinnedRevision)"

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
            // Only the large weights file gets byte-level progress, and only it
            // carries a published digest to verify against.
            let isWeights = relativePath == ModelOption.weightsSubpath
            let report: (@Sendable (Double) -> Void)? = isWeights ? progress : nil
            let expectedSHA256: String? = isWeights ? option.weightsSHA256 : nil
            try await downloadFile(from: url, to: destination, expectedSHA256: expectedSHA256, reporting: report)
        }
    }

    private func downloadFile(
        from url: URL,
        to destination: URL,
        expectedSHA256: String?,
        reporting: (@Sendable (Double) -> Void)?
    ) async throws {
        // A session-scoped delegate is required for `didWriteData` progress; the
        // async `URLSession.download(from:delegate:)` convenience API does not
        // deliver it. The session is invalidated to release the delegate.
        let delegate = ModelDownloadDelegate(onProgress: reporting)
        let session = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        let temporaryURL: URL
        let response: URLResponse
        do {
            (temporaryURL, response) = try await delegate.download(url, using: session)
        } catch {
            session.invalidateAndCancel()
            throw error
        }
        session.finishTasksAndInvalidate()

        // Drop the temporary file on any error path so failed downloads don't
        // leak into the temp directory.
        var moved = false
        defer { if !moved { try? FileManager.default.removeItem(at: temporaryURL) } }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw RemovalError.modelFailure("Model download failed (HTTP \(code)).")
        }

        // Verify the downloaded bytes against the published digest before the
        // file is moved into the cache and later loaded as a CoreML model, so a
        // tampered or corrupted download is never compiled or executed.
        if let expectedSHA256 {
            let actual = try Self.sha256(ofFileAt: temporaryURL)
            guard actual == expectedSHA256 else {
                throw RemovalError.modelFailure("Model file failed its integrity check.")
            }
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
        moved = true
    }

    /// Streams a file through SHA-256 in 1 MB chunks so a ~480 MB weights blob is
    /// hashed without being read into memory all at once. Returns lowercase hex.
    static func sha256(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Drives a `URLSessionDownloadTask` with real byte-level progress and bridges
/// its completion to async.
///
/// The async `URLSession.download(from:delegate:)` API does **not** deliver
/// `didWriteData` callbacks, so a classic download task with a session-level
/// delegate is used instead, surfaced through a continuation.
final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: (@Sendable (Double) -> Void)?
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var fileURL: URL?
    private var fileError: Error?

    init(onProgress: (@Sendable (Double) -> Void)?) {
        self.onProgress = onProgress
    }

    /// Runs the download to completion, returning the relocated temporary file
    /// and the HTTP response.
    func download(_ url: URL, using session: URLSession) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    /// The fraction written so far, or nil when the total size is unknown
    /// (the server omitted `Content-Length`), so we don't report a fake 0%.
    static func fraction(written: Int64, expected: Int64) -> Double? {
        guard expected > 0 else { return nil }
        return Double(written) / Double(expected)
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let fraction = Self.fraction(written: totalBytesWritten, expected: totalBytesExpectedToWrite) else {
            return
        }
        onProgress?(fraction)
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // The system deletes `location` once this method returns, so move it to a
        // stable temporary path that the caller takes ownership of.
        let stable = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: stable)
            fileURL = stable
        } catch {
            fileError = error
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { continuation = nil }
        if let error {
            continuation?.resume(throwing: error)
        } else if let fileError {
            continuation?.resume(throwing: fileError)
        } else if let fileURL, let response = task.response {
            continuation?.resume(returning: (fileURL, response))
        } else {
            continuation?.resume(throwing: RemovalError.modelFailure("Model download produced no file."))
        }
    }
}
