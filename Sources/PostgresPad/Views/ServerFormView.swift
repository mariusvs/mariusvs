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
        .frame(width: 440, height: 460)
    }
}
