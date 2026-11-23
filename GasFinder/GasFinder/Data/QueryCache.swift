//
// QueryCache.swift
//  GasFinder
//
//  Created by pedro.candon.local on 20/11/2026.
//

import Foundation

/// In-memory cache keyed by query with a time-to-live (TTL).
///
/// Entries are returned only while they are younger than `ttl`; expired
/// entries are evicted on read. The clock is injected so tests can advance
/// time deterministically.
actor QueryCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let value: Value
        let storedAt: Date
    }

    private var entries: [Key: Entry] = [:]
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date

    init(ttl: TimeInterval = 120, now: @escaping @Sendable () -> Date = { Date() }) {
        self.ttl = ttl
        self.now = now
    }

    /// Returns the cached value for `key` if present and not expired,
    /// `nil` otherwise. Expired entries are removed.
    func value(for key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        guard now().timeIntervalSince(entry.storedAt) < ttl else {
            entries[key] = nil
            return nil
        }
        return entry.value
    }

    func set(_ value: Value, for key: Key) {
        entries[key] = Entry(value: value, storedAt: now())
    }

    func removeAll() {
        entries.removeAll()
    }
}
