import SwiftUI
import UIKit

// MARK: - Notes View
struct NotesView: View {
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var selectedFilter: NoteType? = nil
    @State private var showingAddNote = false
    @State private var searchText = ""
    
    var filteredNotes: [Note] {
        var filtered = notesViewModel.notes
        
        // Apply type filter
        if let selectedFilter = selectedFilter {
            filtered = filtered.filter { $0.type == selectedFilter }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.bookTitle?.localizedCaseInsensitiveContains(searchText) == true ||
                note.author?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    var body: some View {
        ZStack {
            // Midnight scholar background
            Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
                .ignoresSafeArea(.all)
            
            // Soft vignette effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.2)
                ]),
                center: .center,
                startRadius: 200,
                endRadius: 400
            )
            .ignoresSafeArea(.all)
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Filter chips at the top
                    HStack(spacing: 12) {
                        // All notes chip
                        FilterChip(
                            title: "All (\(notesViewModel.notes.count))",
                            isSelected: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )
                        
                        // Type-specific chips
                        ForEach(NoteType.allCases, id: \.self) { type in
                            let count = notesViewModel.notes.filter { $0.type == type }.count
                            FilterChip(
                                title: "\(type.displayName) (\(count))",
                                icon: type.icon,
                                isSelected: selectedFilter == type,
                                action: { selectedFilter = selectedFilter == type ? nil : type }
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Notes list
                    if filteredNotes.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: selectedFilter?.icon ?? "note.text")
                                .font(.system(size: 60))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                            
                            Text(selectedFilter == nil ? "No notes yet" : "No \(selectedFilter?.displayName.lowercased() ?? "notes") yet")
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                            
                            Text("Tap + to add your first \(selectedFilter?.displayName.lowercased() ?? "note")")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        // Notes layout
                        VStack(spacing: 20) {
                            ForEach(filteredNotes) { note in
                                NoteCard(note: note)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 1.05).combined(with: .opacity)
                                    ))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                }
            }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddNote = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: filteredNotes.count)
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet { newNote in
                notesViewModel.addNote(newNote)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetNotesFilter"))) { _ in
            // Reset filter to show all notes when coming from command bar
            selectedFilter = nil
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), lineWidth: 1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Note Card
struct NoteCard: View {
    let note: Note
    @State private var isPressed = false
    @State private var showingOptions = false
    @State private var showingEditSheet = false
    
    var body: some View {
        if note.type == .quote {
            QuoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions, showingEditSheet: $showingEditSheet)
        } else {
            RegularNoteCard(note: note, isPressed: $isPressed, showingEditSheet: $showingEditSheet)
        }
    }
}

// MARK: - Quote Card (Literary Design)
struct QuoteCard: View {
    let note: Note
    @Binding var isPressed: Bool
    @Binding var showingOptions: Bool
    @Binding var showingEditSheet: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var firstLetter: String {
        String(note.content.prefix(1))
    }
    
    var restOfContent: String {
        String(note.content.dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large transparent opening quote
            Text("\"")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.68))
                .offset(x: -10, y: 20)
                .frame(height: 0)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: 56))
                    .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102))
                    .padding(.trailing, 4)
                    .offset(y: -8)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102))
                    .lineSpacing(11) // Line height 1.5
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.top, 20)
            
            // Attribution section
            VStack(alignment: .leading, spacing: 12) {
                // Thin horizontal rule with gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.1), location: 0),
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(1.0), location: 0.5),
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.top, 20)
                
                // Attribution text - reordered: Author -> Source -> Page
                VStack(alignment: .leading, spacing: 6) {
                    if let author = note.author {
                        Text(author.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.8))
                    }
                    
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.6))
                    }
                    
                    if let pageNumber = note.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.5))
                    }
                }
            }
        }
        .padding(32) // Generous padding
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.96)) // #FAF8F5
                .shadow(color: Color(red: 0.8, green: 0.7, blue: 0.6).opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            HapticManager.shared.lightTap()
            showingEditSheet = true
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            HapticManager.shared.mediumImpact()
            showingOptions = true
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
        .popover(isPresented: $showingOptions) {
            QuoteOptionsPopover(note: note)
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditNoteSheet(note: note) { updatedNote in
                notesViewModel.updateNote(updatedNote)
            }
        }
    }
}

// MARK: - Regular Note Card
struct RegularNoteCard: View {
    let note: Note
    @Binding var isPressed: Bool
    @Binding var showingEditSheet: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Date
                Text(note.formattedDate)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                
                Spacer()
                
                // Note indicator
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
            }
            
            // Content
            Text(note.content)
                .font(.custom("SF Pro Display", size: 16))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            // Book info (if available)
            if let bookTitle = note.bookTitle {
                HStack(spacing: 4) {
                    Text("re:")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                    
                    Text(bookTitle)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                    
                    if let pageNumber = note.pageNumber {
                        Text("• p. \(pageNumber)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
            }
            HapticManager.shared.lightTap()
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            EditNoteSheet(note: note) { updatedNote in
                notesViewModel.updateNote(updatedNote)
            }
        }
    }
}

// MARK: - Quote Options Popover
struct QuoteOptionsPopover: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Share as image
            Button(action: shareAsImage) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Share as Image")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Copy text
            Button(action: copyText) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                    Text("Copy Quote")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Edit
            Button(action: edit) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                    Text("Edit")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 200)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    private func shareAsImage() {
        HapticManager.shared.lightTap()
        // TODO: Generate beautiful image with quote
        dismiss()
    }
    
    private func copyText() {
        HapticManager.shared.lightTap()
        UIPasteboard.general.string = note.content
        dismiss()
    }
    
    private func edit() {
        HapticManager.shared.lightTap()
        // TODO: Open edit sheet
        dismiss()
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    let onSave: (Note) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var noteType: NoteType = .note
    @State private var content = ""
    @State private var bookTitle = ""
    @State private var author = ""
    @State private var pageNumber = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.105, blue: 0.102)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Type picker
                    HStack(spacing: 12) {
                        ForEach(NoteType.allCases, id: \.self) { type in
                            Button(action: { noteType = type }) {
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text(type.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundStyle(noteType == type ? .white : .white.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background {
                                    if noteType == type {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), lineWidth: 1)
                                            }
                                    } else {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.white.opacity(0.05))
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: noteType)
                        }
                        
                        Spacer()
                    }
                    
                    // Content input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(noteType == .quote ? "Quote" : "Note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                        
                        TextField(noteType == .quote ? "Enter quote..." : "Enter note...", text: $content, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    }
                            }
                            .lineLimit(5...)
                    }
                    
                    // Optional book info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Book Information (Optional)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                        
                        VStack(spacing: 12) {
                            TextField("Book title", text: $bookTitle)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                }
                            
                            TextField("Author", text: $author)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                }
                            
                            TextField("Page number", text: $pageNumber)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                }
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Add \(noteType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        let newNote = Note(
            type: noteType,
            content: content.trimmingCharacters(in: .whitespaces),
            bookTitle: bookTitle.isEmpty ? nil : bookTitle,
            author: author.isEmpty ? nil : author,
            pageNumber: pageNumber.isEmpty ? nil : Int(pageNumber),
            dateCreated: Date()
        )
        
        HapticManager.shared.success()
        onSave(newNote)
        dismiss()
    }
}


// MARK: - Token-Based Edit Note Sheet
struct EditNoteSheet: View {
    let note: Note
    let onSave: (Note) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editingQuote = ""
    @State private var editingBookTitle = ""
    @State private var editingAuthor = ""
    @State private var editingPageNumber = ""
    @State private var hasChanges = false
    @State private var animateIn = false
    @FocusState private var activeToken: TokenType?
    @State private var dragOffset = CGSize.zero
    
    enum TokenType: CaseIterable {
        case quote, bookTitle, author, pageNumber
    }
    
    var body: some View {
        ZStack {
            // No background dimming - just clear
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissEditor()
                }
            
            VStack {
                Spacer()
                
                // Floating glass card
                VStack(spacing: 0) {
                    // Handle bar
                    Capsule()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Quote/Note token - large and beautiful
                            if note.type == .quote {
                                QuoteTokenView(
                                    text: $editingQuote,
                                    isEditing: activeToken == .quote,
                                    onEdit: { activeToken = .quote },
                                    onEndEdit: { checkForChanges() }
                                )
                                .focused($activeToken, equals: .quote)
                            } else {
                                NoteTokenView(
                                    text: $editingQuote,
                                    isEditing: activeToken == .quote,
                                    onEdit: { activeToken = .quote },
                                    onEndEdit: { checkForChanges() }
                                )
                                .focused($activeToken, equals: .quote)
                            }
                            
                            // Attribution tokens
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    // Book token
                                    if !editingBookTitle.isEmpty || activeToken == .bookTitle {
                                        AttributionTokenView(
                                            icon: "books.vertical.fill",
                                            text: $editingBookTitle,
                                            placeholder: "Add book title",
                                            isEditing: activeToken == .bookTitle,
                                            onEdit: { activeToken = .bookTitle },
                                            onEndEdit: { checkForChanges() }
                                        )
                                        .focused($activeToken, equals: .bookTitle)
                                    }
                                    
                                    // Author token
                                    if !editingAuthor.isEmpty || activeToken == .author {
                                        AttributionTokenView(
                                            icon: "person.fill",
                                            text: $editingAuthor,
                                            placeholder: "Add author",
                                            isEditing: activeToken == .author,
                                            onEdit: { activeToken = .author },
                                            onEndEdit: { checkForChanges() }
                                        )
                                        .focused($activeToken, equals: .author)
                                    }
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    // Page number token
                                    if !editingPageNumber.isEmpty || activeToken == .pageNumber {
                                        AttributionTokenView(
                                            icon: "doc.text.fill",
                                            text: $editingPageNumber,
                                            placeholder: "Page",
                                            isEditing: activeToken == .pageNumber,
                                            onEdit: { activeToken = .pageNumber },
                                            onEndEdit: { checkForChanges() },
                                            isSmall: true
                                        )
                                        .focused($activeToken, equals: .pageNumber)
                                        .keyboardType(.numberPad)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Add token buttons
                                HStack(spacing: 8) {
                                    if editingBookTitle.isEmpty && activeToken != .bookTitle {
                                        AddTokenButton(icon: "books.vertical.fill", label: "Book") {
                                            activeToken = .bookTitle
                                        }
                                    }
                                    
                                    if editingAuthor.isEmpty && activeToken != .author {
                                        AddTokenButton(icon: "person.fill", label: "Author") {
                                            activeToken = .author
                                        }
                                    }
                                    
                                    if editingPageNumber.isEmpty && activeToken != .pageNumber {
                                        AddTokenButton(icon: "doc.text.fill", label: "Page") {
                                            activeToken = .pageNumber
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .opacity(activeToken == nil ? 1 : 0.3)
                                .animation(.spring(response: 0.3), value: activeToken)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, hasChanges ? 80 : 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.03))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
                .offset(y: animateIn ? 0 : 400)
                .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                dismissEditor()
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                
                // Floating save button
                if hasChanges {
                    Button(action: saveNote) {
                        HStack {
                            Text("Save Changes")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                                }
                                .overlay {
                                    Capsule()
                                        .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), lineWidth: 1)
                                }
                        }
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 8)
                    }
                    .padding(.bottom, 20)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.2).combined(with: .opacity)
                    ))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .presentationBackground(.clear)
        .onAppear {
            // Initialize with note data
            editingQuote = note.content
            editingBookTitle = note.bookTitle ?? ""
            editingAuthor = note.author ?? ""
            editingPageNumber = note.pageNumber != nil ? "\(note.pageNumber!)" : ""
            
            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
            
            // Focus quote
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                activeToken = .quote
            }
        }
    }
    
    private func checkForChanges() {
        let contentChanged = editingQuote != note.content
        let bookChanged = editingBookTitle != (note.bookTitle ?? "")
        let authorChanged = editingAuthor != (note.author ?? "")
        let pageChanged = editingPageNumber != (note.pageNumber != nil ? "\(note.pageNumber!)" : "")
        
        // Smart extraction when quote content changes
        if contentChanged && activeToken == .quote {
            extractSmartTokens()
        }
        
        withAnimation(.spring(response: 0.3)) {
            hasChanges = contentChanged || bookChanged || authorChanged || pageChanged
        }
    }
    
    private func extractSmartTokens() {
        
        // Extract page numbers
        if editingPageNumber.isEmpty {
            let pagePatterns = [
                "page\\s*(\\d+)",
                "p\\.\\s*(\\d+)",
                "pg\\s*(\\d+)"
            ]
            
            for pattern in pagePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: editingQuote, range: NSRange(editingQuote.startIndex..., in: editingQuote)),
                   let pageRange = Range(match.range(at: 1), in: editingQuote) {
                    editingPageNumber = String(editingQuote[pageRange])
                    break
                }
            }
        }
        
        // Extract book titles
        if editingBookTitle.isEmpty {
            let bookPatterns = [
                "from\\s+\"([^\"]+)\"",
                "in\\s+\"([^\"]+)\"",
                "—\\s*([A-Z][^,\\n]+)"
            ]
            
            for pattern in bookPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: editingQuote, range: NSRange(editingQuote.startIndex..., in: editingQuote)),
                   let titleRange = Range(match.range(at: 1), in: editingQuote) {
                    let title = String(editingQuote[titleRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "")
                    if title.count > 3 {
                        editingBookTitle = title
                        break
                    }
                }
            }
        }
        
        // Extract author names
        if editingAuthor.isEmpty {
            let authorPatterns = [
                "—\\s*([A-Z][a-z]+\\s+[A-Z][a-z]+)",
                "by\\s+([A-Z][a-z]+\\s+[A-Z][a-z]+)"
            ]
            
            for pattern in authorPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: editingQuote, range: NSRange(editingQuote.startIndex..., in: editingQuote)),
                   let authorRange = Range(match.range(at: 1), in: editingQuote) {
                    editingAuthor = String(editingQuote[authorRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
    }
    
    private func saveNote() {
        let updatedNote = Note(
            type: note.type,
            content: editingQuote.trimmingCharacters(in: .whitespacesAndNewlines),
            bookTitle: editingBookTitle.isEmpty ? nil : editingBookTitle,
            author: editingAuthor.isEmpty ? nil : editingAuthor,
            pageNumber: editingPageNumber.isEmpty ? nil : Int(editingPageNumber),
            dateCreated: note.dateCreated,
            id: note.id
        )
        
        HapticManager.shared.success()
        onSave(updatedNote)
        dismissEditor()
    }
    
    private func dismissEditor() {
        activeToken = nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animateIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dismiss()
        }
    }
}

// MARK: - Quote Token View
struct QuoteTokenView: View {
    @Binding var text: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                TextEditor(text: $text)
                    .font(.custom("Georgia", size: 22))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .lineSpacing(6)
                    .frame(minHeight: 120)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1.5)
                            }
                    }
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Quote mark
                        Text("\"")
                            .font(.custom("Georgia", size: 48))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3))
                            .offset(x: -4, y: 8)
                            .frame(height: 0)
                        
                        // Quote text
                        Text(text.isEmpty ? "Tap to add quote..." : text)
                            .font(.custom("Georgia", size: 22))
                            .foregroundStyle(text.isEmpty ? 
                                Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4) :
                                Color(red: 0.98, green: 0.97, blue: 0.96)
                            )
                            .italic(text.isEmpty)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.02))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .scaleEffect(isEditing ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Note Token View (for regular notes)
struct NoteTokenView: View {
    @Binding var text: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                TextEditor(text: $text)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .lineSpacing(4)
                    .frame(minHeight: 100)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1.5)
                            }
                    }
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Note icon
                        HStack {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                            
                            Spacer()
                        }
                        
                        // Note text
                        Text(text.isEmpty ? "Tap to add note..." : text)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(text.isEmpty ? 
                                Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4) :
                                Color(red: 0.98, green: 0.97, blue: 0.96)
                            )
                            .italic(text.isEmpty)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.02))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .scaleEffect(isEditing ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Attribution Token View
struct AttributionTokenView: View {
    let icon: String
    @Binding var text: String
    let placeholder: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    var isSmall: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: isSmall ? 12 : 14, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                .frame(width: isSmall ? 16 : 18)
            
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: isSmall ? 14 : 16, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    Text(text.isEmpty ? placeholder : text)
                        .font(.system(size: isSmall ? 14 : 16, weight: .medium, design: .serif))
                        .foregroundStyle(text.isEmpty ? 
                            Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5) :
                            Color(red: 0.98, green: 0.97, blue: 0.96)
                        )
                        .italic(text.isEmpty)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, isSmall ? 12 : 16)
        .padding(.vertical, isSmall ? 6 : 10)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(isEditing ? 0.08 : 0.03))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isEditing ? 
                                Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) :
                                Color.white.opacity(0.2),
                            lineWidth: isEditing ? 1.5 : 1
                        )
                }
        }
        .scaleEffect(isEditing ? 1.05 : 1.0)
        .shadow(color: isEditing ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : .clear, radius: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Add Token Button
struct AddTokenButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotesView()
        .environmentObject(NotesViewModel())
}
