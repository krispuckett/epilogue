import SwiftUI

// MARK: - Rich Text Editor
/// Markdown-aware text editor with formatting toolbar
/// Combines TrackedTextEditor with FormattingToolbar for seamless rich text editing

struct RichTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool

    @StateObject private var cursorTracker = TextEditorCursorTracker()
    @State private var toolbarView: UIView?
    @Environment(\.dismiss) private var dismiss

    init(
        text: Binding<String>,
        placeholder: String = "Start writing...",
        isFocused: FocusState<Bool>.Binding
    ) {
        self._text = text
        self.placeholder = placeholder
        self._isFocused = isFocused
    }

    var body: some View {
        VStack(spacing: 0) {
            // Text editor area
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .allowsHitTesting(false)
                }

                // Custom tracked text editor with toolbar
                TrackedTextEditorWrapper(
                    text: $text,
                    placeholder: placeholder,
                    cursorTracker: cursorTracker,
                    onDismiss: { isFocused = false }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Wrapper to manage toolbar
private struct TrackedTextEditorWrapper: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let cursorTracker: TextEditorCursorTracker
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = UIColor.white
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.keyboardType = .default
        textView.returnKeyType = .default

        // Store reference to textView in coordinator
        context.coordinator.textView = textView

        // Create toolbar with callback-based formatting
        let toolbar = ToolbarContainer(
            onFormat: { syntax in
                context.coordinator.insertMarkdown(syntax)
            },
            onDismiss: onDismiss
        )
        let hostingController = UIHostingController(rootView: toolbar)
        hostingController.view.backgroundColor = .clear

        let size = hostingController.view.systemLayoutSizeFitting(
            CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        textView.inputAccessoryView = hostingController.view

        // Track this textView
        cursorTracker.trackTextView(textView)

        // Store hosting controller to prevent deallocation
        context.coordinator.hostingController = hostingController

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            if selectedRange.location <= text.count {
                uiView.selectedRange = selectedRange
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, cursorTracker: cursorTracker)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let cursorTracker: TextEditorCursorTracker
        var textView: UITextView?
        var hostingController: UIHostingController<ToolbarContainer>?

        init(text: Binding<String>, cursorTracker: TextEditorCursorTracker) {
            _text = text
            self.cursorTracker = cursorTracker
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func insertMarkdown(_ syntax: MarkdownSyntax) {
            guard let textView = textView else { return }

            print("📝 Coordinator.insertMarkdown:")
            print("  - Current text: '\(textView.text ?? "")'")
            print("  - Cursor position: \(cursorTracker.cursorPosition)")
            print("  - Selected range: \(cursorTracker.selectedRange?.description ?? "nil")")

            let result = MarkdownParser.insertMarkdown(
                in: textView.text ?? "",
                syntax: syntax,
                cursorPosition: cursorTracker.cursorPosition,
                selectedRange: cursorTracker.selectedRange
            )

            print("  - New text: '\(result.text)'")
            print("  - New cursor: \(result.cursorPosition)")

            // Update UITextView directly
            textView.text = result.text
            textView.selectedRange = NSRange(location: result.cursorPosition, length: 0)

            // Update binding
            text = result.text

            print("  - Text after update: '\(textView.text ?? "")'")
        }
    }
}

// MARK: - Toolbar Container
private struct ToolbarContainer: View {
    let onFormat: (MarkdownSyntax) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            FormatButton(icon: MarkdownSyntax.bold.systemIcon, syntax: .bold) {
                onFormat(.bold)
                SensoryFeedback.light()
            }

            FormatButton(icon: MarkdownSyntax.italic.systemIcon, syntax: .italic) {
                onFormat(.italic)
                SensoryFeedback.light()
            }

            FormatButton(icon: MarkdownSyntax.highlight.systemIcon, syntax: .highlight) {
                onFormat(.highlight)
                SensoryFeedback.light()
            }

            FormatButton(icon: MarkdownSyntax.blockquote.systemIcon, syntax: .blockquote) {
                onFormat(.blockquote)
                SensoryFeedback.light()
            }

            FormatButton(icon: MarkdownSyntax.bulletList.systemIcon, syntax: .bulletList) {
                onFormat(.bulletList)
                SensoryFeedback.light()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.clear)
                .glassEffect()
        )
    }
}

// MARK: - Simplified Rich Text Editor (No Cursor Tracking)
/// Fallback version using standard TextEditor with markdown toolbar
/// Use this if TrackedTextEditor has issues

struct SimpleRichTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool

    @StateObject private var cursorTracker = TextEditorCursorTracker()

    var body: some View {
        VStack(spacing: 0) {
            // Standard TextEditor
            TextEditor(text: $text)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                // Simplified toolbar without precise cursor tracking
                HStack(spacing: 12) {
                    FormatButton(icon: MarkdownSyntax.bold.systemIcon, syntax: .bold) {
                        insertAtEnd(.bold)
                    }

                    FormatButton(icon: MarkdownSyntax.italic.systemIcon, syntax: .italic) {
                        insertAtEnd(.italic)
                    }

                    FormatButton(icon: MarkdownSyntax.highlight.systemIcon, syntax: .highlight) {
                        insertAtEnd(.highlight)
                    }

                    Divider()
                        .frame(height: 24)
                        .background(Color.white.opacity(0.1))

                    FormatButton(icon: MarkdownSyntax.blockquote.systemIcon, syntax: .blockquote) {
                        insertAtEnd(.blockquote)
                    }

                    FormatButton(icon: MarkdownSyntax.bulletList.systemIcon, syntax: .bulletList) {
                        insertAtEnd(.bulletList)
                    }

                    Spacer()

                    Button("Done") {
                        isFocused = false
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(.clear)
                        .glassEffect()
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 0.5)
                }
            }
        }
    }

    /// Insert markdown at end of text (fallback when cursor position unavailable)
    private func insertAtEnd(_ syntax: MarkdownSyntax) {
        let (prefix, suffix) = syntax.insertSyntax

        switch syntax {
        case .bold, .italic, .highlight:
            text += prefix + suffix
        case .blockquote, .bulletList, .numberedList, .header1, .header2:
            if !text.isEmpty && !text.hasSuffix("\n") {
                text += "\n"
            }
            text += prefix
        }
    }
}

// MARK: - Preview Provider
struct RichTextEditor_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var text = """
        # Sample Note

        This is a **bold** statement and this is *italic*.

        > A quote from the book

        - First point
        - Second point
        """
        @FocusState private var isFocused: Bool

        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    RichTextEditor(
                        text: $text,
                        placeholder: "Start writing...",
                        isFocused: $isFocused
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .background(DesignSystem.Colors.surfaceBackground)
                .navigationTitle("Edit Note")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    isFocused = true
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}
