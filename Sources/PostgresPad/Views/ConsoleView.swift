import SwiftUI

/// Centre pane: SQL editor above, query results below.
struct ConsoleView: View {
    let server: ServerConfig?
    let database: String?

    @State private var sqlText: String = ""
    @State private var results: [QueryResult] = []
    @State private var errorMessage: String?
    @State private var isRunning = false

    var body: some View {
        if let server, let database {
            console(server: server, database: database)
        } else {
            ContentUnavailableView(
                "No Database Selected",
                systemImage: "cylinder.split.1x2",
                description: Text("Select a server or database in the sidebar to open a console.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func console(server: ServerConfig, database: String) -> some View {
        VSplitView {
            VStack(spacing: 0) {
                header(server: server, database: database)
                Divider()
                TextEditor(text: $sqlText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(.background)
                    .padding(4)
            }
            .frame(minHeight: 140, idealHeight: 220)

            VStack(spacing: 0) {
                resultsArea
                Divider()
                statusBar
            }
            .frame(minHeight: 160, maxHeight: .infinity)
        }
    }

    private func header(server: ServerConfig, database: String) -> some View {
        HStack(spacing: 8) {
            ServerBadgeView(server: server, size: 18)
            Text(server.displayName)
                .fontWeight(.medium)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(database)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
            Spacer()
            Button {
                run(server: server, database: database)
            } label: {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Run", systemImage: "play.fill")
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isRunning || sqlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Execute the console contents (⌘↩)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var resultsArea: some View {
        if let errorMessage {
            ScrollView {
                Text(errorMessage)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        } else if let display = displayedResult {
            ResultsGridView(result: display)
        } else {
            ContentUnavailableView(
                "No Results",
                systemImage: "tablecells",
                description: Text("Write a query above and press ⌘↩ to run it.")
            )
        }
    }

    /// Shows the last statement that produced rows, falling back to the
    /// last statement overall (e.g. after a script of INSERTs).
    private var displayedResult: QueryResult? {
        results.last(where: { $0.hasRows }) ?? results.last
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if isRunning {
                Text("Running…")
            } else if errorMessage != nil {
                Label("Error", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            } else if !results.isEmpty {
                let totalDuration = results.reduce(0) { $0 + $1.duration }
                let statementLabel = results.count == 1
                    ? "1 statement"
                    : "\(results.count) statements"
                Label(statementLabel, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let display = displayedResult, display.hasRows {
                    Text("\(display.rows.count) row\(display.rows.count == 1 ? "" : "s")")
                }
                Text(String(format: "%.0f ms", totalDuration * 1000))
            } else {
                Text("Ready")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func run(server: ServerConfig, database: String) {
        let script = sqlText
        isRunning = true
        errorMessage = nil
        Task {
            do {
                let newResults = try await PostgresService.shared.execute(
                    script: script,
                    on: server,
                    database: database
                )
                results = newResults
            } catch {
                results = []
                errorMessage = describePostgresError(error)
            }
            isRunning = false
        }
    }
}
