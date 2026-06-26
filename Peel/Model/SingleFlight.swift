//
//  SingleFlight.swift
//  Peel
//

/// Coalesces concurrent async work so an expensive one-time operation runs at
/// most once, even when several callers await it before it finishes.
///
/// Used to guard the first-run model download: dropping a second image while the
/// 233 MB download is in flight must not kick off a second download.
actor SingleFlight<Value: Sendable> {
    private var value: Value?
    private var task: Task<Value, Error>?

    /// Returns the cached value, or runs `make` once and caches its result.
    /// Concurrent callers awaiting an in-flight run share the same task.
    func run(_ make: @Sendable @escaping () async throws -> Value) async throws -> Value {
        if let value { return value }
        if let task { return try await task.value }

        let task = Task { try await make() }
        self.task = task
        do {
            let result = try await task.value
            value = result
            self.task = nil
            return result
        } catch {
            // Leave `value` unset so a later caller can retry the failed work.
            self.task = nil
            throw error
        }
    }
}
