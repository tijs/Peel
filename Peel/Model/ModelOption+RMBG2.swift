//
//  ModelOption+RMBG2.swift
//  Peel
//

import CoreML
import RMBG2Swift

extension ModelOption {
    /// The package model variant backing this option.
    nonisolated var variant: ModelVariant {
        switch self {
        case .standard: .quantized
        case .highQuality: .full
        }
    }

    /// A CoreML configuration for this option.
    ///
    /// Defaults to `.cpuAndGPU`: RMBG-2's convolutions exceed the Apple Neural
    /// Engine's kernel-memory limit, so `.all` makes CoreML fail an ANE compile.
    nonisolated func configuration(computeUnits: MLComputeUnits = .cpuAndGPU) -> RMBG2Configuration {
        RMBG2Configuration(modelVariant: variant, computeUnits: computeUnits)
    }
}
