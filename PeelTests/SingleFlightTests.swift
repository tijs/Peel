//
//  SingleFlightTests.swift
//  PeelTests
//

@testable import Peel
import Testing

/// Counts how many times the coalesced work actually ran.
private actor Counter {
    private(set) var count = 0
    func increment() { count += 1 }
}

struct SingleFlightTests {
    /// The core guard against the double-download bug: many concurrent callers
    /// during an in-flight run must trigger the work exactly once.
    @Test func coalescesConcurrentRuns() async {
        let flight = SingleFlight<Int>()
        let counter = Counter()

        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 20 {
                group.addTask {
                    await (try? flight.run {
                        await counter.increment()
                        try? await Task.sleep(for: .milliseconds(30))
                        return 42
                    }) ?? -1
                }
            }
            var collected: [Int] = []
            for await value in group { collected.append(value) }
            return collected
        }

        #expect(results.allSatisfy { $0 == 42 })
        #expect(await counter.count == 1)
    }

    @Test func cachesSuccessfulValueAcrossCalls() async throws {
        let flight = SingleFlight<Int>()
        let counter = Counter()

        for _ in 0 ..< 3 {
            _ = try await flight.run {
                await counter.increment()
                return 7
            }
        }

        #expect(await counter.count == 1)
    }

    /// A failed run must not be cached — a later caller can retry.
    @Test func failureAllowsRetry() async {
        let flight = SingleFlight<Int>()
        let counter = Counter()

        await #expect(throws: RemovalError.self) {
            try await flight.run {
                await counter.increment()
                throw RemovalError.modelFailure("first attempt")
            }
        }

        let value = try? await flight.run {
            await counter.increment()
            return 5
        }

        #expect(value == 5)
        #expect(await counter.count == 2)
    }
}
