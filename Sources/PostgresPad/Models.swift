import Foundation

/// A saved Postgres server registration.
struct ServerConfig: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var host: String = "localhost"
    var port: Int = 5432
    var username: String = "postgres"
    var password: String = ""
    /// Database used to establish the initial connection and enumerate
    /// the other databases on the server.
    var maintenanceDatabase: String = "postgres"
    var useTLS: Bool = false
    /// SF Symbol and tint shown as the server's logo badge in the sidebar.
    var symbolName: String = "server.rack"
    var tintName: String = "blue"
    /// Production servers never auto-commit: console statements run inside
    /// an explicit transaction until the user commits or rolls back.
    var isProduction: Bool = false

    var displayName: String {
        name.isEmpty ? "\(host):\(port)" : name
    }

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, username, password
        case maintenanceDatabase, useTLS, symbolName, tintName, isProduction
    }
}

extension ServerConfig {
    /// Tolerant decoding so server files written by older versions
    /// (without the badge fields) keep loading.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? "localhost"
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 5432
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "postgres"
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        maintenanceDatabase = try container.decodeIfPresent(String.self, forKey: .maintenanceDatabase) ?? "postgres"
        useTLS = try container.decodeIfPresent(Bool.self, forKey: .useTLS) ?? false
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "server.rack"
        tintName = try container.decodeIfPresent(String.self, forKey: .tintName) ?? "blue"
        isProduction = try container.decodeIfPresent(Bool.self, forKey: .isProduction) ?? false
    }
}

/// What is currently selected in the sidebar tree.
enum SidebarSelection: Hashable {
    case server(UUID)
    case database(UUID, String)

    var serverID: UUID {
        switch self {
        case .server(let id): return id
        case .database(let id, _): return id
        }
    }

    var databaseName: String? {
        if case .database(_, let name) = self { return name }
        return nil
    }
}

/// The outcome of executing a single SQL statement.
struct QueryResult: Sendable {
    var statement: String
    var columns: [String]
    var rows: [[String]]
    var duration: TimeInterval

    var hasRows: Bool { !columns.isEmpty }
}
