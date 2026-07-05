import AppKit
import SwiftUI

/// Monospaced SQL editor backed by NSTextView, with as-you-type
/// completions (SQL keywords, functions, and live schema identifiers)
/// using the native completion popup, plus a recent-tables menu:
/// it opens automatically after typing `select ` or `from ` and on ⌘T,
/// inserting `* from <table>` / `<table>` respectively.
struct SQLEditorView: NSViewRepresentable {
    @Binding var text: String
    var completionWords: [String]
    var recentTables: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = SQLTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false

        let coordinator = context.coordinator
        textView.onRecentTablesShortcut = { [weak textView] in
            guard let textView else { return }
            coordinator.recentTablesShortcut(in: textView)
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLEditorView
        private var isCompleting = false
        private weak var activeTextView: NSTextView?

        init(_ parent: SQLEditorView) {
            self.parent = parent
        }

        // MARK: - Text changes

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            guard !isCompleting else { return }

            // `select ` / `from ` just typed → offer recent tables.
            if maybeShowRecentTables(in: textView) { return }

            // Otherwise auto-open the completion popup once a word is 2+
            // characters.
            let range = textView.rangeForUserCompletion
            guard range.location != NSNotFound, range.length >= 2 else { return }
            isCompleting = true
            textView.complete(nil)
            isCompleting = false
        }

        // MARK: - Keyword/schema completions

        func textView(
            _ textView: NSTextView,
            completions words: [String],
            forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            guard let range = Range(charRange, in: textView.string) else { return [] }
            let prefix = textView.string[range].lowercased()
            guard !prefix.isEmpty else { return [] }

            let matches = parent.completionWords.filter {
                let candidate = $0.lowercased()
                return candidate.hasPrefix(prefix) && candidate != prefix
            }
            index?.pointee = 0
            return matches
        }

        // MARK: - Recent tables menu

        /// Shows the menu when the text before the caret ends in
        /// `select ` (inserts `* from <table>`) or `from ` (inserts the
        /// table name). Returns whether it was shown.
        @discardableResult
        private func maybeShowRecentTables(in textView: NSTextView) -> Bool {
            guard !parent.recentTables.isEmpty else { return false }
            let caret = textView.selectedRange().location
            let length = (textView.string as NSString).length
            guard caret != NSNotFound, caret <= length else { return false }
            let before = (textView.string as NSString).substring(to: caret)

            let template: String
            if before.range(of: #"\bselect\s+$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                template = "* from %@"
            } else if before.range(of: #"\bfrom\s+$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                template = "%@"
            } else {
                return false
            }
            showRecentTablesMenu(in: textView, template: template)
            return true
        }

        /// ⌘T: context-aware — completes the select/from clause when the
        /// caret is right after one, otherwise inserts a bare table name.
        func recentTablesShortcut(in textView: NSTextView) {
            guard !parent.recentTables.isEmpty else { return }
            if maybeShowRecentTables(in: textView) { return }
            showRecentTablesMenu(in: textView, template: "%@")
        }

        private func showRecentTablesMenu(in textView: NSTextView, template: String) {
            let menu = NSMenu(title: "Recent Tables")
            menu.autoenablesItems = false

            let header = NSMenuItem(title: "Recent tables", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for table in parent.recentTables.prefix(RecentTablesStore.capacity) {
                let item = NSMenuItem(
                    title: table,
                    action: #selector(insertRecentTable(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = template.replacingOccurrences(of: "%@", with: table)
                menu.addItem(item)
            }

            activeTextView = textView

            // Anchor the menu just below the caret.
            var point = NSPoint(x: 8, y: 8)
            if let window = textView.window {
                let screenRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
                let windowRect = window.convertFromScreen(screenRect)
                point = textView.convert(windowRect.origin, from: nil)
                point.y += 18
            }
            menu.popUp(positioning: nil, at: point, in: textView)
        }

        @objc private func insertRecentTable(_ sender: NSMenuItem) {
            guard let textView = activeTextView,
                  let insertion = sender.representedObject as? String else { return }
            // Suppress the popups the insertion itself would re-trigger.
            isCompleting = true
            textView.insertText(insertion, replacementRange: textView.selectedRange())
            isCompleting = false
        }
    }
}

/// NSTextView subclass so ⌘T can open the recent-tables menu.
final class SQLTextView: NSTextView {
    var onRecentTablesShortcut: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "t" {
            onRecentTablesShortcut?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
