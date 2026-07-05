import Foundation

/// Remembers the last tables the user ran a SELECT against, per
/// server + database, so the editor can offer them for quick insertion.
/// Persisted to Application Support alongside the server list.
@MainActor
final class RecentTablesStore {
    static let shared = RecentTablesStore()
    static let capacity = 10

    /// Keyed by "\(serverID)/\(database)".
    private var storage: [String: [String]] = [:]

    private init() {
        load()
    }

    static func key(serverID: UUID, database: String) -> String {
        "\(serverID.uuidString)/\(database)"
    }

    func tables(for key: String) -> [String] {
        storage[key] ?? []
    }

    /// Moves (or inserts) the table at the front of the MRU list.
    func record(_ table: String, for key: String) {
        var list = storage[key] ?? []
        list.removeAll { $0.caseInsensitiveCompare(table) == .orderedSame }
        list.insert(table, at: 0)
        if list.count > Self.capacity {
            list.removeLast(list.count - Self.capacity)
        }
        storage[key] = list
        save()
    }

    /// Extracts the table a SELECT statement reads from, for recording.
    /// Intentionally simple: first identifier after the first FROM;
    /// subqueries (`FROM (`) are ignored.
    static func selectedTable(in statement: String) -> String? {
        guard statement.range(
            of: #"^\s*select\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil else { return nil }

        guard let fromRange = statement.range(
            of: #"\bfrom\s+"#,
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }

        let rest = statement[fromRange.upperBound...]
        guard let identifierRange = rest.range(
            of: #"^("[^"]+"|[A-Za-z_][A-Za-z0-9_$]*(\.[A-Za-z_][A-Za-z0-9_$]*)?)"#,
            options: .regularExpression
        ) else { return nil }

        return String(rest[identifierRange])
    }

    // MARK: - Persistence

    private static var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PostgresPad", isDirectory: true)
            .appendingPathComponent("recent-tables.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storageURL),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return }
        storage = decoded
    }

    private func save() {
        do {
            let directory = Self.storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(storage)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            NSLog("PostgresPad: failed to save recent tables: \(error)")
        }
    }
}
