import SwiftUI

/// Right-hand panel. Intentionally empty for now — reserved for future
/// inspectors (table structure, query plans, etc.).
struct InspectorPanelView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Inspector")
                .font(.callout)
                .foregroundStyle(.quaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
