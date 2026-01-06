import SwiftUI
import SwiftData

// MARK: - Full-Screen Note Editor
/// Minimal, writing-focused editor inspired by Apple Notes and iA Writer

struct NoteEditorView: View {
    enum Mode: Equatable {
        case createNote(book: BookModel? = nil)
        case createQuote(book: BookModel? = nil)
        case editNote(CapturedNote)
        case editQuote(CapturedQuote)

        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.createNote, .createNote), (.createQuote, .createQuote):
                return true
            case let (.editNote(lhs), .editNote(rhs)):
                return lhs.id == rhs.id
            case let (.editQuote(lhs), .editQuote(rhs)):
                return lhs.id == rhs.id
            default:
                return false
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Query existing tags for autocomplete
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var allNotes: [CapturedNote]

    // Content state
    @State private var content: String = ""
    @State private var author: String = ""
    @State private var pageLocation: String = ""
    @State private var tags: [String] = []
    @State private var selectedBook: BookModel?

    // UI state
    @FocusState private var isEditorFocused: Bool
    @State private var showMetadataSheet = false

    // MARK: - Computed Properties

    private var isQuote: Bool {
        switch mode {
        case .createQuote, .editQuote: return true
        default: return false
        }
    }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        isQuote ? "Enter your quote..." : "Start writing..."
    }

    // All existing tags for autocomplete
    private var existingTags: [String] {
        let allTags = allNotes.flatMap { $0.tags ?? [] }
        return Array(Set(allTags)).sorted()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Ambient background
            AmbientChatGradientView()
                .ignoresSafeArea()

            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Writing area
                writingArea
            }
        }
        .sheet(isPresented: $showMetadataSheet) {
            MetadataSheet(
                tags: $tags,
                selectedBook: $selectedBook,
                existingTags: existingTags,
                isQuote: isQuote
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(red: 0.08, green: 0.075, blue: 0.07))
        }
        .onAppear {
            loadExistingContent()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isEditorFocused = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Metadata button
            Button {
                isEditorFocused = false
                showMetadataSheet = true
                SensoryFeedback.light()
            } label: {
                HStack(spacing: 6) {
                    if !tags.isEmpty {
                        Text("\(tags.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(DesignSystem.Colors.primaryAccent)
                            .clipShape(Circle())
                    }
                    Image(systemName: "tag")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            Button {
                save()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canSave ? .white : .white.opacity(0.3))
            }
            .disabled(!canSave)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Writing Area

    private var writingArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Main editor
                RichTextEditor(
                    text: $content,
                    placeholder: placeholder,
                    isFocused: $isEditorFocused
                )
                .frame(minHeight: 300)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Quote attribution (inline, subtle)
                if isQuote && !content.isEmpty {
                    quoteAttribution
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Quote Attribution

    private var quoteAttribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            HStack(spacing: 8) {
                Text("—")
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white.opacity(0.4))

                TextField("Author", text: $author)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white.opacity(0.8))
                    .textFieldStyle(.plain)
            }

            if !author.isEmpty || !pageLocation.isEmpty {
                TextField("Page or location", text: $pageLocation)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .textFieldStyle(.plain)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Load/Save

    private func loadExistingContent() {
        switch mode {
        case .createNote(let book), .createQuote(let book):
            if let book = book {
                selectedBook = book
                author = book.author
            }

        case .editNote(let note):
            content = note.content ?? ""
            tags = note.tags ?? []
            pageLocation = note.pageNumber.map { "\($0)" } ?? ""
            selectedBook = note.book

        case .editQuote(let quote):
            content = quote.text ?? ""
            author = quote.author ?? ""
            pageLocation = quote.pageNumber.map { "\($0)" } ?? ""
            selectedBook = quote.book
        }
    }

    private func save() {
        let hasMarkdown = detectMarkdown(in: content)
        let pageNumber: Int? = Int(pageLocation.trimmingCharacters(in: .whitespaces))

        var savedNote: CapturedNote?
        var savedQuote: CapturedQuote?

        switch mode {
        case .createNote:
            let note = CapturedNote(
                content: content,
                book: selectedBook,
                pageNumber: pageNumber,
                timestamp: Date(),
                source: .manual,
                tags: tags,
                contentFormat: hasMarkdown ? "markdown" : "plaintext"
            )
            modelContext.insert(note)
            savedNote = note

        case .createQuote:
            let quote = CapturedQuote(
                text: content,
                book: selectedBook,
                author: author.isEmpty ? nil : author,
                pageNumber: pageNumber,
                timestamp: Date(),
                source: .manual
            )
            modelContext.insert(quote)
            savedQuote = quote

        case .editNote(let note):
            note.content = content
            note.book = selectedBook
            note.pageNumber = pageNumber
            note.tags = tags
            note.contentFormat = hasMarkdown ? "markdown" : "plaintext"
            savedNote = note

        case .editQuote(let quote):
            quote.text = content
            quote.book = selectedBook
            quote.author = author.isEmpty ? nil : author
            quote.pageNumber = pageNumber
            savedQuote = quote
        }

        try? modelContext.save()

        // Index for knowledge graph
        if let note = savedNote {
            KnowledgeGraphIndexer.shared.onNoteSaved(note)
        }
        if let quote = savedQuote {
            KnowledgeGraphIndexer.shared.onQuoteSaved(quote)
        }

        NotificationCenter.default.post(name: Notification.Name("NoteUpdated"), object: nil)
        SensoryFeedback.success()
        dismiss()
    }

    private func detectMarkdown(in text: String) -> Bool {
        let patterns = ["\\*\\*.*?\\*\\*", "__.*?__", "\\*.*?\\*", "_.*?_", "==.*?=="]
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil { return true }
        }
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("> ") || line.hasPrefix("# ") || line.hasPrefix("## ") ||
               line.hasPrefix("- ") || line.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}

// MARK: - Metadata Sheet

private struct MetadataSheet: View {
    @Binding var tags: [String]
    @Binding var selectedBook: BookModel?
    let existingTags: [String]
    let isQuote: Bool

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BookModel.title) private var allBooks: [BookModel]
    @State private var newTagText: String = ""
    @State private var showBookPicker = false
    @FocusState private var isTagFieldFocused: Bool

    // Filtered suggestions based on input
    private var tagSuggestions: [String] {
        guard !newTagText.isEmpty else { return [] }
        let query = newTagText.lowercased()
        return existingTags
            .filter { $0.lowercased().contains(query) && !tags.contains($0) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Tags section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TAGS")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(1.2)

                        // Current tags
                        if !tags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    tagChip(tag)
                                }
                            }
                        }

                        // Add tag field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))

                                TextField("Add tag...", text: $newTagText)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .textFieldStyle(.plain)
                                    .focused($isTagFieldFocused)
                                    .onSubmit { addTag(newTagText) }
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }

                            // Autocomplete suggestions
                            if !tagSuggestions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(tagSuggestions, id: \.self) { suggestion in
                                            Button {
                                                addTag(suggestion)
                                            } label: {
                                                Text(suggestion)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.white.opacity(0.9))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(DesignSystem.Colors.primaryAccent.opacity(0.3))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    // Quick tags (existing tags not yet added)
                    if !existingTags.isEmpty {
                        let availableTags = existingTags.filter { !tags.contains($0) }.prefix(8)
                        if !availableTags.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SUGGESTED")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .kerning(1.2)

                                FlowLayout(spacing: 8) {
                                    ForEach(Array(availableTags), id: \.self) { tag in
                                        Button {
                                            addTag(tag)
                                        } label: {
                                            Text(tag)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(.white.opacity(0.06))
                                                .clipShape(Capsule())
                                                .overlay {
                                                    Capsule()
                                                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Book section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BOOK")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(1.2)

                        Button {
                            showBookPicker = true
                            SensoryFeedback.light()
                        } label: {
                            HStack {
                                Image(systemName: "book")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.4))

                                Text(selectedBook?.title ?? "Link to a book...")
                                    .font(.system(size: 16))
                                    .foregroundStyle(selectedBook != nil ? .white : .white.opacity(0.4))

                                Spacer()

                                if selectedBook != nil {
                                    Button {
                                        selectedBook = nil
                                        SensoryFeedback.light()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showBookPicker) {
                NoteBookPickerSheet(selectedBook: $selectedBook, books: allBooks)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(red: 0.08, green: 0.075, blue: 0.07))
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    tags.removeAll { $0 == tag }
                }
                SensoryFeedback.light()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.primaryAccent.opacity(0.4))
        .clipShape(Capsule())
    }

    private func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            newTagText = ""
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tags.append(trimmed)
        }
        newTagText = ""
        SensoryFeedback.light()
    }
}

// MARK: - Note Book Picker (Local)

private struct NoteBookPickerSheet: View {
    @Binding var selectedBook: BookModel?
    let books: [BookModel]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredBooks: [BookModel] {
        if searchText.isEmpty {
            return books
        }
        let query = searchText.lowercased()
        return books.filter {
            $0.title.lowercased().contains(query) ||
            $0.author.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Clear selection option
                    if selectedBook != nil {
                        Button {
                            selectedBook = nil
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.5))

                                Text("Remove book link")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.7))

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }

                    ForEach(filteredBooks) { book in
                        Button {
                            selectedBook = book
                            SensoryFeedback.medium()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                // Book cover thumbnail
                                if let coverURL = book.coverImageURL, let url = URL(string: coverURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(.white.opacity(0.1))
                                    }
                                    .frame(width: 40, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 40, height: 60)
                                        .overlay {
                                            Image(systemName: "book.closed")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)

                                    if !book.author.isEmpty {
                                        Text(book.author)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if selectedBook?.id == book.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(selectedBook?.id == book.id ? DesignSystem.Colors.primaryAccent.opacity(0.15) : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selectedBook?.id == book.id ? DesignSystem.Colors.primaryAccent.opacity(0.3) : .white.opacity(0.08), lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .searchable(text: $searchText, prompt: "Search books...")
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NoteEditorView(mode: .createNote())
        .preferredColorScheme(.dark)
}
