import SwiftUI
import SwiftData

struct NoteEditSheet: View {
    let note: Note
    @State private var editedContent: String
    @State private var editedAuthor: String
    @State private var editedBookTitle: String
    @State private var editedLocation: String  // Flexible: "Page 42" or "3:16"
    @FocusState private var isTextFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var notesViewModel: NotesViewModel

    init(note: Note) {
        self.note = note
        self._editedContent = State(initialValue: note.content)
        self._editedAuthor = State(initialValue: note.author ?? "")
        self._editedBookTitle = State(initialValue: note.bookTitle ?? "")
        // Initialize location from locationReference, or format from pageNumber
        if let locationRef = note.locationReference, !locationRef.isEmpty {
            self._editedLocation = State(initialValue: locationRef)
        } else if let page = note.pageNumber {
            self._editedLocation = State(initialValue: "\(page)")
        } else {
            self._editedLocation = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Drag indicator
                HStack {
                    Spacer()
                    Capsule()
                        .fill(DesignSystem.Colors.textQuaternary)
                        .frame(width: 36, height: 5)
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Glass header with Done button
                HStack {
                    Spacer()

                    Button("Done") {
                        saveAndDismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 8)
                    .glassEffect(
                        .regular.interactive(),
                        in: .capsule
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.bottom, 16)

                // Content area
                VStack(alignment: .leading, spacing: 0) {
                    // Rich text editor - constrained height based on content
                    RichTextEditor(
                        text: $editedContent,
                        placeholder: note.type == .quote ? "Enter quote text..." : "What are you thinking about?",
                        isFocused: $isTextFocused
                    )
                    .frame(minHeight: 44)  // Minimum one line
                    .fixedSize(horizontal: false, vertical: true)  // Size to content

                    // Attribution section for quotes - directly below content
                    if note.type == .quote {
                        attributionSection
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)

                Spacer()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
            .onAppear {
                isTextFocused = true
                notesViewModel.isEditingNote = true
            }
            .onDisappear {
                notesViewModel.isEditingNote = false
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isTextFocused)
        }
    }

    // MARK: - Attribution Section (Plain stacked text, tap to edit)

    @ViewBuilder
    private var attributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thin horizontal rule
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 0),
                    .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5), location: 0.5),
                    .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.bottom, 12)

            // Stacked attribution - larger text for easy editing
            VStack(alignment: .leading, spacing: 8) {
                // Author
                TextField("Author", text: $editedAuthor)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.9))
                    .textFieldStyle(.plain)

                // Book title
                TextField("Book title", text: $editedBookTitle)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                    .textFieldStyle(.plain)

                // Page/Location
                TextField("Page or location", text: $editedLocation)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .textFieldStyle(.plain)
            }
        }
    }

    private func saveAndDismiss() {
        // Detect if content has markdown formatting
        let hasMarkdown = detectMarkdown(in: editedContent)

        // Parse location - try to extract page number if it's numeric
        let pageNumber: Int?
        let locationReference: String?

        let trimmedLocation = editedLocation.trimmingCharacters(in: .whitespaces)
        if trimmedLocation.isEmpty {
            pageNumber = note.pageNumber  // Keep existing
            locationReference = nil
        } else if let page = Int(trimmedLocation) {
            // Pure numeric - treat as page number
            pageNumber = page
            locationReference = nil
        } else {
            // Non-numeric (verse reference, etc.) - store as locationReference
            pageNumber = nil
            locationReference = trimmedLocation
        }

        // Create updated Note struct
        let updatedNote = Note(
            type: note.type,
            content: editedContent,
            bookId: note.bookId,
            bookTitle: editedBookTitle.isEmpty ? nil : editedBookTitle,
            author: editedAuthor.isEmpty ? nil : editedAuthor,
            pageNumber: pageNumber,
            locationReference: locationReference,
            dateCreated: note.dateCreated,
            id: note.id,
            ambientSessionId: note.ambientSessionId,
            source: note.source,
            contentFormat: hasMarkdown ? "markdown" : "plaintext"
        )

        // Try to update in SwiftData first (for quotes from ambient sessions, etc.)
        var updatedInSwiftData = false

        if note.type == .quote {
            // Try to find and update CapturedQuote in SwiftData
            let quoteId = note.id
            let fetchDescriptor = FetchDescriptor<CapturedQuote>(
                predicate: #Predicate { quote in
                    quote.id == quoteId
                }
            )
            if let quotes = try? modelContext.fetch(fetchDescriptor),
               let capturedQuote = quotes.first {
                capturedQuote.text = editedContent
                capturedQuote.author = editedAuthor.isEmpty ? nil : editedAuthor
                capturedQuote.pageNumber = pageNumber
                try? modelContext.save()
                updatedInSwiftData = true
            }
        } else {
            // Try to find and update CapturedNote in SwiftData
            let noteId = note.id
            let fetchDescriptor = FetchDescriptor<CapturedNote>(
                predicate: #Predicate { n in
                    n.id == noteId
                }
            )
            if let notes = try? modelContext.fetch(fetchDescriptor),
               let capturedNote = notes.first {
                capturedNote.content = editedContent
                capturedNote.pageNumber = pageNumber
                capturedNote.contentFormat = hasMarkdown ? "markdown" : "plaintext"
                try? modelContext.save()
                updatedInSwiftData = true
            }
        }

        // If not in SwiftData, CREATE a new note (this is a new note, not an update)
        if !updatedInSwiftData {
            // Post notification to create in SwiftData (handled by ContentView)
            if note.type == .quote {
                var quoteData: [String: Any] = [
                    "quote": editedContent
                ]
                if let bookId = note.bookId {
                    quoteData["bookId"] = bookId.uuidString
                }
                if let bookTitle = note.bookTitle, !bookTitle.isEmpty {
                    quoteData["bookTitle"] = bookTitle
                }
                if !editedAuthor.isEmpty {
                    quoteData["attribution"] = editedAuthor
                }
                if let page = pageNumber {
                    quoteData["pageNumber"] = page
                }
                NotificationCenter.default.post(
                    name: Notification.Name("SaveQuote"),
                    object: quoteData
                )
            } else {
                var noteData: [String: Any] = [
                    "content": editedContent
                ]
                if let bookId = note.bookId {
                    noteData["bookId"] = bookId.uuidString
                }
                if let bookTitle = note.bookTitle, !bookTitle.isEmpty {
                    noteData["bookTitle"] = bookTitle
                }
                if !editedAuthor.isEmpty {
                    noteData["bookAuthor"] = editedAuthor
                }
                NotificationCenter.default.post(
                    name: Notification.Name("CreateNewNote"),
                    object: noteData
                )
            }
        } else {
            // Post notification so views can refresh (for existing note updates)
            NotificationCenter.default.post(
                name: Notification.Name("NoteUpdated"),
                object: updatedNote
            )
        }

        dismiss()
    }

    /// Detects if text contains markdown formatting
    private func detectMarkdown(in text: String) -> Bool {
        // Check inline patterns
        let inlinePatterns = [
            "\\*\\*.*?\\*\\*",  // Bold
            "__.*?__",           // Bold alternative
            "\\*.*?\\*",         // Italic
            "_.*?_",             // Italic alternative
            "==.*?=="            // Highlight
        ]

        for pattern in inlinePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Check line-start patterns by splitting into lines
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("> ") ||     // Blockquote
               line.hasPrefix("# ") ||     // Header 1
               line.hasPrefix("## ") ||    // Header 2
               line.hasPrefix("- ") ||     // Bullet list
               line.range(of: "^\\d+\\. ", options: .regularExpression) != nil {  // Numbered list
                return true
            }
        }

        return false
    }
}