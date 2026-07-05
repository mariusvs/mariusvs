import Foundation
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import PostgresNIO

/// Owns all live Postgres connections, keyed by (server, database).
/// Connections are opened lazily on first use and reused afterwards.
actor PostgresService {
    static let shared = PostgresService()

    private struct ConnectionKey: Hashable {
        let serverID: UUID
        let database: String
    }

    private var connections: [ConnectionKey: PostgresConnection] = [:]
    private var nextConnectionID = 0
    private let logger = Logger(label: "postgrespad.sql")

    // MARK: - Public API

    /// Lists non-template databases on the server, connecting through the
    /// server's maintenance database.
    func listDatabases(on server: ServerConfig) async throws -> [String] {
        let connection = try await connection(for: server, database: server.maintenanceDatabase)
        let stream = try await connection.query(
            "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname",
            logger: logger
        )
        var names: [String] = []
        for try await row in stream {
            let cells = row.makeRandomAccess()
            if let name = try? cells[0].decode(String.self) {
                names.append(name)
            }
        }
        return names
    }

    /// Executes a script (one or more `;`-separated statements) sequentially
    /// against the given database. Stops at the first failing statement.
    func execute(script: String, on server: ServerConfig, database: String) async throws -> [QueryResult] {
        let statements = SQLScriptSplitter.split(script)
        guard !statements.isEmpty else { return [] }

        let connection = try await connection(for: server, database: database)
        var results: [QueryResult] = []
        for statement in statements {
            let start = Date()
            let stream = try await connection.query(
                PostgresQuery(unsafeSQL: statement),
                logger: logger
            )
            var columns: [String] = []
            var rows: [[String]] = []
            for try await row in stream {
                let cells = row.makeRandomAccess()
                if columns.isEmpty {
                    columns = (0..<cells.count).map { cells[$0].columnName }
                }
                rows.append((0..<cells.count).map { Self.displayValue(for: cells[$0]) })
            }
            results.append(QueryResult(
                statement: statement,
                columns: columns,
                rows: rows,
                duration: Date().timeIntervalSince(start)
            ))
        }
        return results
    }

    /// Closes every open connection to the given server.
    func disconnect(serverID: UUID) async {
        let keys = connections.keys.filter { $0.serverID == serverID }
        for key in keys {
            if let connection = connections.removeValue(forKey: key) {
                try? await connection.close()
            }
        }
    }

    // MARK: - Connection handling

    private func connection(for server: ServerConfig, database: String) async throws -> PostgresConnection {
        let key = ConnectionKey(serverID: server.id, database: database)
        if let existing = connections[key], !existing.isClosed {
            return existing
        }
        connections.removeValue(forKey: key)

        let tls: PostgresConnection.Configuration.TLS
        if server.useTLS {
            let context = try NIOSSLContext(configuration: .makeClientConfiguration())
            tls = .require(context)
        } else {
            tls = .disable
        }

        let configuration = PostgresConnection.Configuration(
            host: server.host,
            port: server.port,
            username: server.username,
            password: server.password.isEmpty ? nil : server.password,
            database: database,
            tls: tls
        )

        nextConnectionID += 1
        let connection = try await PostgresConnection.connect(
            on: MultiThreadedEventLoopGroup.singleton.any(),
            configuration: configuration,
            id: nextConnectionID,
            logger: logger
        )
        connections[key] = connection
        return connection
    }

    // MARK: - Cell rendering

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Renders an arbitrary Postgres cell to a human-readable string.
    /// PostgresNIO delivers cells in binary wire format, so we try the
    /// concrete decoders in order of likelihood and fall back to raw bytes.
    static func displayValue(for cell: PostgresCell) -> String {
        guard var buffer = cell.bytes else { return "NULL" }

        if let value = try? cell.decode(String.self) { return value }
        if let value = try? cell.decode(Int.self) { return String(value) }
        if let value = try? cell.decode(Double.self) { return String(value) }
        if let value = try? cell.decode(Bool.self) { return value ? "true" : "false" }
        if let value = try? cell.decode(Decimal.self) { return "\(value)" }
        if let value = try? cell.decode(UUID.self) { return value.uuidString.lowercased() }
        if let value = try? cell.decode(Date.self) { return dateFormatter.string(from: value) }

        // jsonb binary format is a 0x01 version byte followed by JSON text.
        if cell.dataType == .jsonb, cell.format == .binary, buffer.readableBytes > 1 {
            buffer.moveReaderIndex(forwardBy: 1)
            if let json = buffer.readString(length: buffer.readableBytes) {
                return json
            }
        }

        // Text-format cells are plain UTF-8 regardless of type.
        if cell.format == .text,
           let text = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) {
            return text
        }

        let bytes = buffer.readableBytesView.prefix(64)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let suffix = buffer.readableBytes > 64 ? "…" : ""
        return "\\x\(hex)\(suffix)"
    }
}

// MARK: - Error formatting

/// Extracts a readable message from PostgresNIO errors for the console.
func describePostgresError(_ error: Error) -> String {
    if let psqlError = error as? PSQLError {
        var parts: [String] = []
        if let severity = psqlError.serverInfo?[.severity] {
            parts.append(severity)
        }
        if let message = psqlError.serverInfo?[.message] {
            parts.append(message)
        }
        if let detail = psqlError.serverInfo?[.detail] {
            parts.append(detail)
        }
        if let hint = psqlError.serverInfo?[.hint] {
            parts.append("Hint: \(hint)")
        }
        if !parts.isEmpty {
            return parts.joined(separator: " — ")
        }
        return String(reflecting: psqlError)
    }
    return String(describing: error)
}
