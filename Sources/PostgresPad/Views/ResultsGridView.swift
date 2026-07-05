import SwiftUI

/// Renders a query result as a scrollable grid with a pinned header row.
/// Built by hand (rather than SwiftUI `Table`) so it can handle an
/// arbitrary number of columns decided at runtime.
struct ResultsGridView: View {
    let result: QueryResult

    private var columnWidths: [CGFloat] {
        Self.computeWidths(columns: result.columns, rows: result.rows)
    }

    var body: some View {
        if !result.hasRows {
            ContentUnavailableView(
                "Statement Executed",
                systemImage: "checkmark.circle",
                description: Text("The statement completed but returned no result set.")
            )
        } else {
            let widths = columnWidths
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                            gridRow(row, widths: widths)
                                .background(index.isMultiple(of: 2)
                                    ? Color.clear
                                    : Color.primary.opacity(0.04))
                        }
                    } header: {
                        headerRow(widths: widths)
                    }
                }
            }
        }
    }

    private func headerRow(widths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(result.columns.enumerated()), id: \.offset) { index, name in
                Text(name)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(width: widths[index], alignment: .leading)
                Divider()
            }
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func gridRow(_ row: [String], widths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(value == "NULL" ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(width: widths[index], alignment: .leading)
                Divider()
            }
        }
    }

    /// Sizes each column from its header and a sample of its values,
    /// clamped to a sensible range.
    private static func computeWidths(columns: [String], rows: [[String]]) -> [CGFloat] {
        let charWidth: CGFloat = 7.5
        let padding: CGFloat = 20
        return columns.indices.map { columnIndex in
            var maxLength = columns[columnIndex].count
            for row in rows.prefix(100) where columnIndex < row.count {
                maxLength = max(maxLength, row[columnIndex].count)
            }
            let width = CGFloat(maxLength) * charWidth + padding
            return min(max(width, 70), 380)
        }
    }
}
