//
//  ModelOption.swift
//  Peel
//

import Foundation

/// A user-selectable RMBG-2 model build.
///
/// Pure metadata — no CoreML/package dependency — so it can be stored in
/// preferences and exercised in tests. The package mapping lives in
/// `ModelOption+RMBG2.swift`.
enum ModelOption: String, CaseIterable, Identifiable {
    /// INT8-quantized build. Smaller download, auto-installed on first run.
    case standard
    /// Full-precision (FP32) build. Larger download, sharper edges.
    case highQuality

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .highQuality: "High Quality"
        }
    }

    var summary: String {
        switch self {
        case .standard: "INT8 · faster, smaller download"
        case .highQuality: "Full precision · sharper edges, slower"
        }
    }

    /// Approximate download size, for display.
    var approximateSize: String {
        switch self {
        case .standard: "233 MB"
        case .highQuality: "461 MB"
        }
    }

    /// Compiled CoreML artifact name in the model cache (`.mlmodelc`).
    var compiledFilename: String {
        switch self {
        case .standard: "RMBG-2-native-int8.mlmodelc"
        case .highQuality: "RMBG-2-native.mlmodelc"
        }
    }

    /// Downloaded (uncompiled) package name in the model cache (`.mlpackage`).
    var packageFilename: String {
        switch self {
        case .standard: "RMBG-2-native-int8.mlpackage"
        case .highQuality: "RMBG-2-native.mlpackage"
        }
    }
}
