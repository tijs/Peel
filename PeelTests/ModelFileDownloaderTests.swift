//
//  ModelFileDownloaderTests.swift
//  PeelTests
//

import Foundation
@testable import Peel
import Testing

/// Serialized because the stub protocol carries its canned response in static
/// state shared across the suite.
@Suite(.serialized)
struct ModelFileDownloaderTests {
    private func tempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func nonOKStatusThrowsModelFailure() async throws {
        StubURLProtocol.statusCode = 404
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let downloader = ModelFileDownloader(cacheDirectory: directory, urlSession: StubURLProtocol.session())

        do {
            try await downloader.download(.standard) { _ in }
            Issue.record("expected a download failure")
        } catch let error as RemovalError {
            guard case let .modelFailure(detail) = error else {
                Issue.record("expected .modelFailure, got \(error)")
                return
            }
            #expect(detail.contains("404"))
        }
    }

    /// A download whose weights don't match the published digest is rejected, so
    /// a tampered or corrupted model is never moved into the cache.
    @Test func mismatchedWeightsFailIntegrityCheck() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data("not the real weights".utf8)
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let downloader = ModelFileDownloader(cacheDirectory: directory, urlSession: StubURLProtocol.session())

        do {
            try await downloader.download(.standard) { _ in }
            Issue.record("expected an integrity failure")
        } catch let error as RemovalError {
            guard case let .modelFailure(detail) = error else {
                Issue.record("expected .modelFailure, got \(error)")
                return
            }
            #expect(detail.contains("integrity"))
        }

        // The unverified weights file must not have been left in the cache.
        let weights = directory
            .appendingPathComponent(ModelOption.standard.packageFilename)
            .appendingPathComponent(ModelOption.weightsSubpath)
        #expect(!FileManager.default.fileExists(atPath: weights.path))
    }

    @Test func sha256MatchesKnownVector() throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("abc.txt")
        try Data("abc".utf8).write(to: file)

        // NIST SHA-256 test vector for "abc".
        #expect(
            try ModelFileDownloader.sha256(ofFileAt: file)
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    @Test func progressFractionGuardsAgainstUnknownTotal() {
        #expect(DownloadProgressDelegate.fraction(written: 50, expected: 100) == 0.5)
        #expect(DownloadProgressDelegate.fraction(written: 100, expected: 100) == 1.0)
        // A missing Content-Length (expected <= 0) reports no fraction rather
        // than a fake 0%.
        #expect(DownloadProgressDelegate.fraction(written: 10, expected: 0) == nil)
    }
}
