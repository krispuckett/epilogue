import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - Text Editor Cursor Tracker
/// Tracks cursor position and selection in TextEditor for markdown insertion
/// Uses UITextView introspection to access cursor position

class TextEditorCursorTracker: ObservableObject {
    @Published var cursorPosition: Int = 0
    @Published var selectedRange: NSRange?

    weak var textView: UITextView?

    func trackTextView(_ textView: UITextView) {
        self.textView = textView
        updateFromTextView()
    }

    /// Called by the coordinator when selection changes
    func updateFromTextView() {
        guard let textView = textView else { return }
        // Dispatch to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in
            self?.cursorPosition = textView.selectedRange.location
            self?.selectedRange = textView.selectedRange.length > 0 ? textView.selectedRange : nil
        }
    }

    func updateCursor(to position: Int) {
        guard let textView = textView else { return }
        textView.selectedRange = NSRange(location: position, length: 0)
        updateFromTextView()
    }
}

// MARK: - TextEditor with Cursor Tracking
/// A TextEditor wrapper that provides cursor position tracking
struct TrackedTextEditor: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let foregroundColor: UIColor
    let tracker: TextEditorCursorTracker
    var inputAccessoryView: UIView?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = foregroundColor
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.keyboardType = .default
        textView.returnKeyType = .default

        // Add custom input accessory view (toolbar)
        if let accessoryView = inputAccessoryView {
            textView.inputAccessoryView = accessoryView
        }

        // Track this textView
        tracker.trackTextView(textView)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text

            // Restore cursor position if text was updated programmatically
            if selectedRange.location <= text.count {
                uiView.selectedRange = selectedRange
            }
        }
        // Update tracker reference in case it changed
        tracker.textView = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, tracker: tracker)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let tracker: TextEditorCursorTracker

        init(text: Binding<String>, tracker: TextEditorCursorTracker) {
            _text = text
            self.tracker = tracker
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            tracker.updateFromTextView()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            tracker.updateFromTextView()
        }
    }
}

// MARK: - String Extension for Cursor Operations
extension String {
    /// Safely insert text at a given position
    func inserting(_ insertion: String, at position: Int) -> String {
        guard position >= 0 && position <= count else { return self }

        let index = self.index(self.startIndex, offsetBy: position)
        var result = self
        result.insert(contentsOf: insertion, at: index)
        return result
    }

    /// Get NSRange for selected text
    func nsRange(from range: Range<String.Index>) -> NSRange {
        return NSRange(range, in: self)
    }

    /// Get Range from NSRange
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = from16.samePosition(in: self),
            let to = to16.samePosition(in: self)
        else { return nil }

        return from..<to
    }
}
