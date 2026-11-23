//
// QueryCacheTests.swift
//  GasFinder
//
//  Created by pedro.candon.local on 20/11/2026.
//

import XCTest
@testable import GasFinder

// MARK: - Test doubles
/// Deterministic clock so cache expiry can be tested without sleeping.
final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _current: Date

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        _current = start
    }

    var current: Date {
        lock.lock()
        defer { lock.unlock() }
        return _current
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _current = _current.addingTimeInterval(interval)
    }

    var provider: @Sendable () -> Date {
        { self.current }
    }
}

// MARK: - Tests
final class QueryCacheTests: XCTestCase {
    func test_returnsStoredValueWhileFresh() async {
        let clock = FakeClock()
        let cache = QueryCache<String, Int>(ttl: 120, now: clock.provider)

        await cache.set(42, for: "key")
        clock.advance(by: 119)

        let value = await cache.value(for: "key")
        XCTAssertEqual(value, 42)
    }

    func test_returnsNilAndEvictsAfterTTL() async {
        let clock = FakeClock()
        let cache = QueryCache<String, Int>(ttl: 120, now: clock.provider)

        await cache.set(42, for: "key")
        clock.advance(by: 120)

        let value = await cache.value(for: "key")
        XCTAssertNil(value)

        await cache.set(7, for: "key")
        let refreshed = await cache.value(for: "key")
        XCTAssertEqual(refreshed, 7)
    }

    func test_overwritesValueForSameKey() async {
        let clock = FakeClock()
        let cache = QueryCache<String, Int>(ttl: 120, now: clock.provider)

        await cache.set(1, for: "key")
        clock.advance(by: 60)
        await cache.set(2, for: "key")
        clock.advance(by: 59)

        let value = await cache.value(for: "key")
        XCTAssertEqual(value, 2)
    }

    func test_missingKey_returnsNil() async {
        let cache = QueryCache<String, Int>(ttl: 120)

        let value = await cache.value(for: "missing")
        XCTAssertNil(value)
    }
}
