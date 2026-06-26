//
//  ModelOptionTests.swift
//  PeelTests
//

@testable import Peel
import Testing

struct ModelOptionTests {
    @Test func rawValuesAreStableForPersistence() {
        // These strings are written to UserDefaults — they must not drift.
        #expect(ModelOption.standard.rawValue == "standard")
        #expect(ModelOption.highQuality.rawValue == "highQuality")
        #expect(ModelOption(rawValue: "highQuality") == .highQuality)
        #expect(ModelOption(rawValue: "nonsense") == nil)
    }

    @Test func eachOptionHasDistinctModelArtifactNames() {
        let compiled = ModelOption.allCases.map(\.compiledFilename)
        let packages = ModelOption.allCases.map(\.packageFilename)
        #expect(Set(compiled).count == ModelOption.allCases.count)
        #expect(Set(packages).count == ModelOption.allCases.count)
    }

    @Test func artifactNamesUseExpectedExtensions() {
        for option in ModelOption.allCases {
            #expect(option.compiledFilename.hasSuffix(".mlmodelc"))
            #expect(option.packageFilename.hasSuffix(".mlpackage"))
        }
    }

    @Test func everyOptionHasDisplayMetadata() {
        for option in ModelOption.allCases {
            #expect(!option.displayName.isEmpty)
            #expect(!option.summary.isEmpty)
            #expect(option.approximateSize.contains("MB"))
        }
    }
}
