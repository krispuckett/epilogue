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
    @State private var viewMode: ViewMode = .gallery
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var editingNote: Note?
    @State private var selectedSection: String?
    @State private var scrollPosition: CGFloat = 0
    @State private var densityLevel: DensityLevel = .comfortable
    @State private var showingAISuggestions = false
    @State private var selectedNoteForAI: Note?
    @State private var isProcessingAI = false
    
    // Animation States
    @Namespace private var animation
    @State private var appearAnimation = false
    
    enum ViewMode: String, CaseIterable {
        case gallery = "square.grid.2x2"
        case list = "list.bullet"
        
        var label: String {
            switch self {
            case .gallery: return "Gallery"
            case .list: return "List"
            }
        }
    }
    
    enum DensityLevel: CGFloat {
        case compact = 0.8
        case comfortable = 1.0
        case spacious = 1.3
    }
    
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
                // Background
                backgroundGradient
                
                // Main Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Smart Search Bar
                            searchHeader
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            // View Mode Toggle
                            viewModeToggle
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            
                            // Smart Sections
                            LazyVStack(spacing: 24, pinnedViews: .sectionHeaders) {
                                if filteredSections.isEmpty && !intelligenceEngine.isProcessing {
                                    emptyStateView
                                } else if intelligenceEngine.isProcessing && filteredSections.isEmpty {
                                    loadingView
                                } else {
                                    ForEach(filteredSections) { section in
                                        smartSectionView(section)
                                            .id(section.id)
                                    }
                                }
                            }
                            .padding(.bottom, 140)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                    .refreshable {
                        await refreshContent()
                    }
                    .onChange(of: selectedSection) { _, newSection in
                        if let section = newSection {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(section, anchor: .top)
                            }
                        }
                    }
                }
                
                // Floating Action Button
                floatingActionButton
                
                // AI Suggestions Overlay
                if showingAISuggestions, let note = selectedNoteForAI {
                    aiSuggestionsOverlay(for: note)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    densityButton
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
                withAnimation(.easeOut(duration: 0.3)) {
                    appearAnimation = true
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
    
    private var viewModeToggle: some View {
        HStack {
            Text("View")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)
            
            Picker("View Mode", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.rawValue)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            
            Spacer()
            
            if !intelligenceEngine.suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(intelligenceEngine.suggestedTags.prefix(5)), id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                }
            }
        }
    }
    
    private func tagChip(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    searchText = tag
                }
            }
    }
    
    @ViewBuilder
    private func smartSectionView(_ section: SmartSection) -> some View {
        Section {
            sectionContent(for: section)
                .padding(.horizontal)
        } header: {
            sectionHeader(for: section)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 10)
                )
        }
    }
    
    private func sectionHeader(for section: SmartSection) -> some View {
        HStack {
            Image(systemName: section.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(section.color)
            
            Text(section.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("(\(section.notes.count))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    // Toggle section expansion
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                    .rotationEffect(.degrees(section.isExpanded ? 0 : -90))
            }
        }
    }
    
    @ViewBuilder
    private func sectionContent(for section: SmartSection) -> some View {
        switch viewMode {
        case .gallery:
            galleryLayout(for: section)
        case .list:
            listLayout(for: section)
        }
    }
    
    private func galleryLayout(for section: SmartSection) -> some View {
        LazyVGrid(
            columns: adaptiveColumns(for: section),
            spacing: 16 * densityLevel.rawValue
        ) {
            ForEach(Array(section.notes.enumerated()), id: \.element.id) { index, note in
                noteCard(note: note, isHero: index == 0 && section.type == .goldenQuotes)
                    .matchedGeometryEffect(id: note.id, in: animation)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
            }
        }
    }
    
    private func listLayout(for section: SmartSection) -> some View {
        LazyVStack(spacing: 12 * densityLevel.rawValue) {
            ForEach(section.notes) { note in
                compactNoteCard(note: note)
                    .matchedGeometryEffect(id: note.id, in: animation)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
    }
    
    private func adaptiveColumns(for section: SmartSection) -> [GridItem] {
        let minWidth: CGFloat = section.type == .goldenQuotes ? 350 : 280
        let spacing: CGFloat = 16 * densityLevel.rawValue
        
        return [GridItem(.adaptive(minimum: minWidth), spacing: spacing)]
    }
    
    @ViewBuilder
    private func noteCard(note: Note, isHero: Bool = false) -> some View {
        Group {
            if note.type == .quote {
                SimpleQuoteCard(note: note)
            } else {
                SimpleNoteCard(note: note)
            }
        }
        .scaleEffect(isHero ? 1.05 : 1.0)
        .shadow(color: .black.opacity(isHero ? 0.3 : 0.1), radius: isHero ? 20 : 10)
        .overlay(alignment: .topTrailing) {
            if intelligenceEngine.getSuggestions(for: note).count > 0 {
                aiIndicator(for: note)
            }
        }
        .onTapGesture {
            editingNote = note
            HapticManager.shared.lightTap()
        }
    }
    
    private func compactNoteCard(note: Note) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Type indicator
            Image(systemName: note.type == .quote ? "quote.bubble" : "note.text")
                .font(.system(size: 14))
                .foregroundStyle(note.type == .quote ? Color.yellow : Color.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let book = note.bookTitle {
                        Text(book)
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                    }
                    
                    Text(note.dateCreated, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            if intelligenceEngine.getSuggestions(for: note).count > 0 {
                aiIndicator(for: note)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .onTapGesture {
            editingNote = note
            HapticManager.shared.lightTap()
        }
    }
    
    private func aiIndicator(for note: Note) -> some View {
        Button {
            selectedNoteForAI = note
            showingAISuggestions = true
            HapticManager.shared.lightTap()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(8)
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button {
                    createNewNote()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.55, blue: 0.26),
                                            Color(red: 1.0, green: 0.45, blue: 0.16)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 12, y: 4)
                }
                .scaleEffect(appearAnimation ? 1.0 : 0.8)
                .opacity(appearAnimation ? 1.0 : 0)
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
    }
    
    private var densityButton: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    densityLevel = .compact
                }
            } label: {
                Label("Compact", systemImage: "square.grid.3x3")
            }
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    densityLevel = .comfortable
                }
            } label: {
                Label("Comfortable", systemImage: "square.grid.2x2")
            }
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    densityLevel = .spacious
                }
            } label: {
                Label("Spacious", systemImage: "square.grid.1x2")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
    }
    
    private func aiSuggestionsOverlay(for note: Note) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showingAISuggestions = false
                    }
                }
            
            VStack(spacing: 16) {
                Text("AI Suggestions")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                ForEach(intelligenceEngine.getSuggestions(for: note)) { suggestion in
                    aiSuggestionButton(suggestion, for: note)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(40)
        }
    }
    
    private func aiSuggestionButton(_ suggestion: AISuggestion, for note: Note) -> some View {
        Button {
            handleAISuggestion(suggestion, for: note)
        } label: {
            HStack {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 16))
                
                Text(suggestion.title)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
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
    
    private func handleAISuggestion(_ suggestion: AISuggestion, for note: Note) {
        showingAISuggestions = false
        
        switch suggestion.action {
        case .expand:
            // Expand the note
            break
        case .search(let query):
            searchText = query
        case .findSimilar:
            // Find similar notes
            break
        case .showConnections:
            // Show connections
            break
        case .summarize:
            // Generate summary
            break
        case .transform:
            // Transform note
            break
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