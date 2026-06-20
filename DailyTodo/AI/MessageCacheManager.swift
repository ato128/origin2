//
//  MessageCacheManager.swift
//  DailyTodo
//

import Foundation
import CryptoKit

final class MessageCacheManager {
    static let shared = MessageCacheManager()
    private init() {}

    private let storeKey = "ai_msg_cache_v1"
    private let ttl: TimeInterval = 7 * 24 * 3600

    struct CacheEntry: Codable {
        let response: String
        let savedAt: Date
    }

    func hash(for message: String) -> String {
        let normalized = message
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func lookup(_ hash: String) -> String? {
        guard let entry = allEntries()[hash] else { return nil }
        guard Date().timeIntervalSince(entry.savedAt) < ttl else {
            remove(hash)
            return nil
        }
        return entry.response
    }

    func store(hash: String, response: String) {
        var all = allEntries()
        all[hash] = CacheEntry(response: response, savedAt: .now)
        let pruned = all.filter { Date().timeIntervalSince($0.value.savedAt) < ttl }
        if let data = try? JSONEncoder().encode(pruned) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func remove(_ hash: String) {
        var all = allEntries()
        all.removeValue(forKey: hash)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func allEntries() -> [String: CacheEntry] {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let entries = try? JSONDecoder().decode([String: CacheEntry].self, from: data)
        else { return [:] }
        return entries
    }
}
