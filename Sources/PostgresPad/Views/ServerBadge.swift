import SwiftUI

/// Tints a server badge can use. Stored in the config by name so the
/// model stays plain Codable data.
enum ServerTint: String, CaseIterable, Identifiable {
    case blue, purple, pink, red, orange, yellow, green, teal, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .gray: return .gray
        }
    }
}

/// SF Symbols offered as server logos.
enum ServerSymbol: String, CaseIterable, Identifiable {
    case rack = "server.rack"
    case cloud = "cloud.fill"
    case drive = "externaldrive.fill"
    case laptop = "laptopcomputer"
    case globe = "globe"
    case leaf = "leaf.fill"
    case bolt = "bolt.fill"
    case flask = "testtube.2"
    case shield = "lock.shield.fill"
    case box = "shippingbox.fill"

    var id: String { rawValue }
}

/// The rounded-square logo shown next to a server everywhere in the UI,
/// so connections are easy to tell apart at a glance.
struct ServerBadgeView: View {
    let server: ServerConfig
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: server.symbolName)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private var tint: Color {
        (ServerTint(rawValue: server.tintName) ?? .blue).color
    }
}
