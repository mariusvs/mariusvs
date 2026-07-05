import AppKit
import SwiftUI

/// Monospaced SQL editor backed by NSTextView, with as-you-type
/// completions (SQL keywords, functions, and live schema identifiers)
/// using the native completion popup. Esc also opens it manually.
struct SQLEditorView: NSViewRepresentable {
    @Binding var text: String
    var completionWords: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

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

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
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

        init(_ parent: SQLEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Auto-open the completion popup once a word is 2+ characters.
            guard !isCompleting else { return }
            let range = textView.rangeForUserCompletion
            guard range.location != NSNotFound, range.length >= 2 else { return }
            isCompleting = true
            textView.complete(nil)
            isCompleting = false
        }

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
    }
}
