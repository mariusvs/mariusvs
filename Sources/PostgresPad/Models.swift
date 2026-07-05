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

    var displayName: String {
        name.isEmpty ? "\(host):\(port)" : name
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
