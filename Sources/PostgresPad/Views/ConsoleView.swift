import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Centre pane: SQL editor above, query results below.
struct ConsoleView: View {
    let server: ServerConfig?
    let database: String?

    @State private var sqlText: String = ""
    @State private var results: [QueryResult] = []
    @State private var errorMessage: String?
    @State private var isRunning = false
    @State private var transactionOpen = false
    @State private var schemaWords: [String] = []

    var body: some View {
        if let server, let database {
            console(server: server, database: database)
                .task(id: "\(server.id.uuidString)/\(database)") {
                    transactionOpen = await PostgresService.shared
                        .isTransactionOpen(on: server, database: database)
                    schemaWords = (try? await PostgresService.shared
                        .schemaIdentifiers(on: server, database: database)) ?? []
                }
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
                SQLEditorView(
                    text: $sqlText,
                    completionWords: SQLCompletions.all + schemaWords
                )
            }
            .frame(minHeight: 140, idealHeight: 220)

            VStack(spacing: 0) {
                resultsArea
                Divider()
                statusBar(server: server)
            }
            .frame(minHeight: 160, maxHeight: .infinity)
        }
    }

    // MARK: - Header

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
            if server.isProduction {
                ProdTagView()
            }
            Spacer()
            if transactionOpen {
                Button("Roll Back") {
                    endTransaction(commit: false, server: server, database: database)
                }
                .controlSize(.small)
                .disabled(isRunning)
                .help("Discard all uncommitted changes")

                Button("Commit") {
                    endTransaction(commit: true, server: server, database: database)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isRunning)
                .help("Commit the open transaction")
            }
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

    // MARK: - Results

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

    // MARK: - Status bar

    private func statusBar(server: ServerConfig) -> some View {
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

            if transactionOpen {
                Label("Open transaction — not committed", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }

            if let display = displayedResult, display.hasRows {
                Menu {
                    Button("CSV…") { export(result: display, asCSV: true) }
                    Button("Tab-delimited Text…") { export(result: display, asCSV: false) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Export the displayed result set")
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - Actions

    private func run(server: ServerConfig, database: String) {
        let script = sqlText
        isRunning = true
        errorMessage = nil
        Task {
            do {
                results = try await PostgresService.shared.execute(
                    script: script,
                    on: server,
                    database: database
                )
            } catch {
                results = []
                errorMessage = describePostgresError(error)
            }
            transactionOpen = await PostgresService.shared
                .isTransactionOpen(on: server, database: database)
            if errorMessage != nil && transactionOpen {
                errorMessage! += "\n\nThe transaction is now aborted — roll back to continue."
            }
            isRunning = false
        }
    }

    private func endTransaction(commit: Bool, server: ServerConfig, database: String) {
        Task {
            do {
                if commit {
                    try await PostgresService.shared
                        .commitTransaction(on: server, database: database)
                } else {
                    try await PostgresService.shared
                        .rollbackTransaction(on: server, database: database)
                }
                errorMessage = nil
            } catch {
                errorMessage = describePostgresError(error)
            }
            transactionOpen = await PostgresService.shared
                .isTransactionOpen(on: server, database: database)
        }
    }

    // MARK: - Export

    private func export(result: QueryResult, asCSV: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [asCSV ? .commaSeparatedText : .plainText]
        panel.nameFieldStringValue = asCSV ? "results.csv" : "results.txt"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let content = asCSV ? Self.csv(from: result) : Self.tabDelimited(from: result)
            do {
                try Data(content.utf8).write(to: url, options: .atomic)
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    static func csv(from result: QueryResult) -> String {
        var lines = [result.columns.map(csvField).joined(separator: ",")]
        for row in result.rows {
            lines.append(row.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func tabDelimited(from result: QueryResult) -> String {
        var lines = [result.columns.joined(separator: "\t")]
        for row in result.rows {
            lines.append(row.map { value in
                value.replacingOccurrences(of: "\t", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
            }.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
