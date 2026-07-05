import SwiftUI

/// Left-hand tree: each registered server expands to the databases
/// discovered on it.
struct SidebarView: View {
    @EnvironmentObject private var store: ServerStore
    @Binding var selection: SidebarSelection?
    @Binding var editingServer: ServerConfig?

    @State private var expandedServers: Set<UUID> = []

    var body: some View {
        List(selection: $selection) {
            Section("Servers") {
                ForEach(store.servers) { server in
                    DisclosureGroup(isExpanded: expansionBinding(for: server)) {
                        databaseRows(for: server)
                    } label: {
                        serverRow(for: server)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.servers.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Click + to register a Postgres server.")
                )
            }
        }
    }

    // MARK: - Rows

    private func serverRow(for server: ServerConfig) -> some View {
        HStack(spacing: 8) {
            ServerBadgeView(server: server, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(server.displayName)
                    if server.isProduction {
                        ProdTagView()
                    }
                }
                Text("\(server.host):\(String(server.port))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.loadingServers.contains(server.id) {
                ProgressView()
                    .controlSize(.small)
            } else if let error = store.serverErrors[server.id] {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(error)
            } else if store.databases[server.id] != nil {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                    .help("Connected")
            }
        }
        .tag(SidebarSelection.server(server.id))
        .contextMenu {
            Button("Connect / Refresh") { store.refreshDatabases(for: server) }
            Button("Disconnect") { store.disconnect(server) }
            Divider()
            Button("Edit Server…") { editingServer = server }
            Button("Remove Server", role: .destructive) {
                if selection?.serverID == server.id { selection = nil }
                store.remove(server)
            }
        }
    }

    @ViewBuilder
    private func databaseRows(for server: ServerConfig) -> some View {
        if let names = store.databases[server.id] {
            if names.isEmpty {
                Text("No databases")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: "cylinder.split.1x2")
                        .tag(SidebarSelection.database(server.id, name))
                }
            }
        } else if let error = store.serverErrors[server.id] {
            Label {
                Text(error)
                    .font(.caption)
                    .lineLimit(3)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(.secondary)
        } else if store.loadingServers.contains(server.id) {
            Text("Connecting…")
                .foregroundStyle(.secondary)
        }
    }

    /// Expanding a server's disclosure triangle lazily connects and loads
    /// its database list the first time.
    private func expansionBinding(for server: ServerConfig) -> Binding<Bool> {
        Binding {
            expandedServers.contains(server.id)
        } set: { expanded in
            if expanded {
                expandedServers.insert(server.id)
                if store.databases[server.id] == nil {
                    store.refreshDatabases(for: server)
                }
            } else {
                expandedServers.remove(server.id)
            }
        }
    }
}
