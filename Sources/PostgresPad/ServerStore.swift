import Foundation
import SwiftUI

/// Owns the list of registered servers (persisted to Application Support)
/// and the database tree state for each of them.
@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [ServerConfig] = []
    /// Databases discovered per server; nil / missing means "not loaded yet".
    @Published private(set) var databases: [UUID: [String]] = [:]
    @Published private(set) var loadingServers: Set<UUID> = []
    @Published private(set) var serverErrors: [UUID: String] = [:]

    init() {
        load()
    }

    // MARK: - Server CRUD

    func add(_ server: ServerConfig) {
        servers.append(server)
        save()
    }

    func update(_ server: ServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
        save()
        // Credentials may have changed; drop stale connections and tree state.
        databases[server.id] = nil
        serverErrors[server.id] = nil
        Task { await PostgresService.shared.disconnect(serverID: server.id) }
    }

    func remove(_ server: ServerConfig) {
        servers.removeAll { $0.id == server.id }
        databases[server.id] = nil
        serverErrors[server.id] = nil
        save()
        Task { await PostgresService.shared.disconnect(serverID: server.id) }
    }

    func server(id: UUID) -> ServerConfig? {
        servers.first { $0.id == id }
    }

    // MARK: - Database tree

    func refreshDatabases(for server: ServerConfig) {
        guard !loadingServers.contains(server.id) else { return }
        loadingServers.insert(server.id)
        serverErrors[server.id] = nil
        Task {
            do {
                let names = try await PostgresService.shared.listDatabases(on: server)
                self.databases[server.id] = names
            } catch {
                self.serverErrors[server.id] = describePostgresError(error)
            }
            self.loadingServers.remove(server.id)
        }
    }

    func disconnect(_ server: ServerConfig) {
        databases[server.id] = nil
        serverErrors[server.id] = nil
        Task { await PostgresService.shared.disconnect(serverID: server.id) }
    }

    // MARK: - Persistence

    private static var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PostgresPad", isDirectory: true)
            .appendingPathComponent("servers.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storageURL) else { return }
        if let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = decoded
        }
    }

    private func save() {
        do {
            let directory = Self.storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(servers)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            // Persistence is best-effort; the in-memory list keeps working.
            NSLog("PostgresPad: failed to save servers: \(error)")
        }
    }
}
