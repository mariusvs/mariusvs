import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ServerStore
    @State private var selection: SidebarSelection?
    @State private var showingNewServerSheet = false
    @State private var editingServer: ServerConfig?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, editingServer: $editingServer)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        } detail: {
            HSplitView {
                ConsoleView(server: selectedServer, database: selectedDatabase)
                    .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
                InspectorPanelView()
                    .frame(minWidth: 200, idealWidth: 260, maxWidth: 420, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewServerSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .help("Register a new Postgres server")
            }
        }
        .sheet(isPresented: $showingNewServerSheet) {
            ServerFormView(mode: .create) { server in
                store.add(server)
            }
        }
        .sheet(item: $editingServer) { server in
            ServerFormView(mode: .edit(server)) { updated in
                store.update(updated)
            }
        }
    }

    private var selectedServer: ServerConfig? {
        guard let selection else { return nil }
        return store.server(id: selection.serverID)
    }

    /// The database the console targets: the selected database node, or the
    /// server's maintenance database when only the server row is selected.
    private var selectedDatabase: String? {
        guard let selection else { return nil }
        return selection.databaseName ?? selectedServer?.maintenanceDatabase
    }
}
