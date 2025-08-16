import SwiftUI
import SwiftData

// MARK: - Award Winning Notes View
struct AwardWinningNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @StateObject private var intelligenceEngine = NoteIntelligenceEngine.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    // Queries
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var notes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var quotes: [CapturedQuote]
    @Query(sort: \CapturedQuestion.timestamp, order: .reverse) private var questions: [CapturedQuestion]
    
    // View State
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var editingNote: Note?
    @State private var isProcessingAI = false
    @State private var showingSectionsNavigator = false
    @State private var scrollToSection: SmartSection?
    @State private var expandedSections: Set<UUID> = []
    
    // Animation States
    @State private var appearAnimation = false
    
    // Computed properties
    private var allNotes: [Note] {
        var items: [Note] = []
        items += notes.map { $0.toNote() }
        items += quotes.map { $0.toNote() }
        return items.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    private var filteredSections: [SmartSection] {
        if searchText.isEmpty {
            return intelligenceEngine.smartSections
        } else {
            // Semantic search when available
            return intelligenceEngine.smartSections.map { section in
                var filtered = section
                filtered.notes = section.notes.filter { note in
                    note.content.localizedCaseInsensitiveContains(searchText) ||
                    (note.bookTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
                return filtered
            }.filter { !$0.notes.isEmpty }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean black background
                Color.black.ignoresSafeArea()
                
                // Main Content
                VStack(spacing: 0) {
                    // Clean search bar at top
                    if isSearchFocused || !searchText.isEmpty {
                        searchHeader
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Stacked cards sections with beautiful card preservation
                    ScrollView {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 24) {
                                if filteredSections.isEmpty && !intelligenceEngine.isProcessing {
                                    emptyStateView
                                        .padding(.top, 40)
                                } else if intelligenceEngine.isProcessing && filteredSections.isEmpty {
                                    loadingView
                                        .padding(.top, 40)
                                } else {
                                    ForEach(filteredSections) { section in
                                        StackedCardsSection(
                                            section: section,
                                            expandedSections: $expandedSections,
                                            onNoteTap: { note in
                                                editingNote = note
                                                HapticManager.shared.lightTap()
                                            },
                                            onDelete: deleteNote
                                        )
                                        .id(section.id)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .onChange(of: scrollToSection) { _, newSection in
                                if let section = newSection {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        proxy.scrollTo(section.id, anchor: .top)
                                    }
                                    // Auto-expand the section we're scrolling to
                                    expandedSections.insert(section.id)
                                    scrollToSection = nil
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable {
                        await refreshContent()
                    }
                }
            }
            .ambientSectionsNavigator(
                isShowing: $showingSectionsNavigator,
                sections: filteredSections,
                onSectionTap: { section in
                    scrollToSection = section
                }
            )
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showingSectionsNavigator.toggle()
                        }
                        HapticManager.shared.lightTap()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isSearchFocused.toggle()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(item: $editingNote) { note in
                InlineEditSheet(note: note)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                Task {
                    await intelligenceEngine.processNotes(allNotes, quotes: allNotes.filter { $0.type == .quote }, questions: questions)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                .font(.system(size: 16))
                .opacity(isSearchFocused ? 1 : 0.6)
                .animation(.spring(response: 0.3), value: isSearchFocused)
            
            TextField("Search thoughts, quotes, questions...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .onSubmit {
                    Task {
                        await performSemanticSearch()
                    }
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        isSearchFocused = true
                    }
                }
            
            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        searchText = ""
                        isSearchFocused = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSearchFocused ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
    }
    
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Capture Your First Thought", systemImage: "sparkles")
        } description: {
            Text("Start by creating a note, saving a quote, or asking a question")
        } actions: {
            Button("Create Note") {
                createNewNote()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
        }
        .padding(.top, 100)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
            
            Text("Organizing your thoughts...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Actions
    
    private func refreshContent() async {
        await intelligenceEngine.processNotes(allNotes, quotes: allNotes.filter { $0.type == .quote }, questions: questions)
    }
    
    private func performSemanticSearch() async {
        isProcessingAI = true
        // Perform semantic search
        let results = await intelligenceEngine.semanticSearch(query: searchText, in: allNotes)
        // Update sections with results
        isProcessingAI = false
    }
    
    private func createNewNote() {
        let newNote = Note(
            type: .note,
            content: "",
            bookId: nil,
            bookTitle: nil,
            author: nil,
            pageNumber: nil,
            dateCreated: Date(),
            id: UUID()
        )
        editingNote = newNote
        HapticManager.shared.success()
    }
    
    private func deleteNote(_ note: Note) {
        // Find and delete the corresponding SwiftData model
        if note.type == .quote {
            if let quote = quotes.first(where: { $0.id == note.id }) {
                modelContext.delete(quote)
            }
        } else {
            if let capturedNote = notes.first(where: { $0.id == note.id }) {
                modelContext.delete(capturedNote)
            }
        }
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
        } catch {
            print("Failed to delete note: \(error)")
            HapticManager.shared.error()
        }
    }
}

// MARK: - Inline Edit Sheet
struct InlineEditSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var editedContent: String = ""
    @State private var showingSaveIndicator = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Smart toolbar
                    HStack(spacing: 16) {
                        ForEach(["bold", "italic", "quote.bubble", "link", "sparkles"], id: \.self) { icon in
                            Button {
                                applyFormatting(icon)
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                        }
                        
                        Spacer()
                        
                        if showingSaveIndicator {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Editor
                    TextEditor(text: $editedContent)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .focused($isFocused)
                        .onChange(of: editedContent) { _, _ in
                            autoSave()
                        }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editedContent = note.content
            isFocused = true
        }
    }
    
    private func applyFormatting(_ format: String) {
        switch format {
        case "bold":
            editedContent = "**\(editedContent)**"
        case "italic":
            editedContent = "*\(editedContent)*"
        case "quote.bubble":
            editedContent = "> \(editedContent)"
        case "link":
            editedContent = "[\(editedContent)](url)"
        case "sparkles":
            // AI assist
            break
        default:
            break
        }
    }
    
    private func autoSave() {
        // Debounce and save
        withAnimation(.spring(response: 0.2)) {
            showingSaveIndicator = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.spring(response: 0.2)) {
                showingSaveIndicator = false
            }
        }
    }
    
    private func saveAndDismiss() {
        // Save the note
        HapticManager.shared.success()
        dismiss()
    }
}

#Preview {
    AwardWinningNotesView()
        .preferredColorScheme(.dark)
}