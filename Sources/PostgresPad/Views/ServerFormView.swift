import SwiftUI

/// Sheet used both to register a new server and to edit an existing one.
struct ServerFormView: View {
    enum Mode {
        case create
        case edit(ServerConfig)
    }

    let mode: Mode
    let onSave: (ServerConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServerConfig
    @State private var portText: String

    init(mode: Mode, onSave: @escaping (ServerConfig) -> Void) {
        self.mode = mode
        self.onSave = onSave
        let initial: ServerConfig
        switch mode {
        case .create: initial = ServerConfig()
        case .edit(let server): initial = server
        }
        _draft = State(initialValue: initial)
        _portText = State(initialValue: String(initial.port))
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !draft.host.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.username.trimmingCharacters(in: .whitespaces).isEmpty
            && Int(portText).map { (1...65535).contains($0) } == true
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Connection") {
                    TextField("Name", text: $draft.name, prompt: Text("Optional label"))
                    TextField("Host", text: $draft.host)
                    TextField("Port", text: $portText)
                    Toggle("Use TLS", isOn: $draft.useTLS)
                }
                Section("Authentication") {
                    TextField("Username", text: $draft.username)
                    SecureField("Password", text: $draft.password)
                    TextField("Maintenance database", text: $draft.maintenanceDatabase)
                }
                Section("Logo") {
                    LabeledContent("Preview") {
                        ServerBadgeView(server: draft, size: 26)
                    }
                    symbolPicker
                    tintPicker
                }
                Section {
                    Text("Passwords are currently stored in plain text in Application Support. Keychain support is planned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add Server") {
                    var server = draft
                    server.port = Int(portText) ?? 5432
                    if server.maintenanceDatabase.trimmingCharacters(in: .whitespaces).isEmpty {
                        server.maintenanceDatabase = "postgres"
                    }
                    onSave(server)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(12)
        }
        .frame(width: 440, height: 600)
    }

    // MARK: - Logo pickers

    private var symbolPicker: some View {
        HStack(spacing: 6) {
            ForEach(ServerSymbol.allCases) { symbol in
                Button {
                    draft.symbolName = symbol.rawValue
                } label: {
                    Image(systemName: symbol.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 26, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(draft.symbolName == symbol.rawValue
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(draft.symbolName == symbol.rawValue
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.3),
                                    lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(symbol.rawValue)
            }
        }
    }

    private var tintPicker: some View {
        HStack(spacing: 8) {
            ForEach(ServerTint.allCases) { tint in
                Button {
                    draft.tintName = tint.rawValue
                } label: {
                    Circle()
                        .fill(tint.color.gradient)
                        .frame(width: 20, height: 20)
                        .overlay {
                            if draft.tintName == tint.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(tint.rawValue.capitalized)
            }
        }
    }
}
