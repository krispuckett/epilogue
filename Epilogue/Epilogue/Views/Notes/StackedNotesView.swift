import SwiftUI
import SwiftData

// MARK: - Notes View Style
enum NotesViewStyle: String, CaseIterable {
    case grid = "grid"
    case stack = "stack"
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .stack: return "square.stack.3d.up"
        }
    }
}

// MARK: - Enhanced Stacked Notes View
struct StackedNotesView: View {
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @StateObject private var intelligenceEngine = NoteIntelligenceEngine.shared
    @StateObject private var syncStatus = SyncStatusManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    // Queries
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var notes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var quotes: [CapturedQuote]
    @Query(sort: \CapturedQuestion.timestamp, order: .reverse) private var questions: [CapturedQuestion]
    
    // Search & Filter
    @Binding var searchText: String
    @Binding var searchScope: NotesView.SearchScope
    @Binding var selectedFilter: FilterType?
    
    // State Management
    @State private var expandedSectionIds: Set<UUID> = []
    @State private var dragOffset: CGSize = .zero
    @State private var activeCardId: UUID?
    @State private var editingNote: Note?
    @State private var showingContextMenu = false
    @State private var contextMenuNote: Note?
    @State private var contextMenuSourceRect: CGRect = .zero
    @State private var deletedNotes: [Note] = []
    @State private var highlightedNoteId: UUID?
    @State private var scrollToNoteId: UUID?
    @State private var sectionLayouts: [UUID: CGRect] = [:]
    @State private var visibleSections: Set<UUID> = []
    
    // Persistence
    @AppStorage("expandedSections") private var persistedExpandedSections: String = ""
    @AppStorage("lastScrollPosition") private var lastScrollPosition: Double = 0
    @AppStorage("notesViewStyle") private var viewStyle: NotesViewStyle = .grid
    
    // Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory
    @Namespace private var animation
    
    // Computed properties
    private var allNotes: [Note] {
        var items: [Note] = []
        items += notes.map { $0.toNote() }
        items += quotes.map { $0.toNote() }
        items += questions.map { $0.toNote() }
        return items.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    private var filteredNotes: [Note] {
        var filtered = allNotes
        
        // Apply search
        if !searchText.isEmpty {
            let tokens = parseSearchTokens(searchText)
            filtered = filtered.filter { note in
                tokens.allSatisfy { token in
                    note.content.localizedCaseInsensitiveContains(token) ||
                    note.bookTitle?.localizedCaseInsensitiveContains(token) ?? false ||
                    note.author?.localizedCaseInsensitiveContains(token) ?? false
                }
            }
        }
        
        // Apply scope
        switch searchScope {
        case .quotes:
            filtered = filtered.filter { $0.type == .quote }
        case .notes:
            filtered = filtered.filter { $0.type == .note }
        case .books:
            // Filter by book context
            filtered = filtered.filter { $0.bookTitle != nil }
        case .all:
            break
        }
        
        // Apply filter
        if let filter = selectedFilter {
            switch filter {
            case .quotes:
                filtered = filtered.filter { $0.type == .quote }
            case .notes:
                filtered = filtered.filter { $0.type == .note }
            case .questions:
                // Questions aren't stored as notes, skip
                break
            default:
                break
            }
        }
        
        return filtered
    }
    
    private var sections: [SmartSection] {
        intelligenceEngine.smartSections.filter { section in
            section.notes.contains { note in
                filteredNotes.contains { $0.id == note.id }
            }
        }
    }
    
    private var cardSpacing: CGFloat {
        switch sizeCategory {
        case .extraSmall, .small: return 60
        case .medium: return 65
        case .large: return 70
        case .extraLarge: return 75
        case .extraExtraLarge: return 80
        case .extraExtraExtraLarge: return 85
        default: return 65
        }
    }
    
    var body: some View {
        ZStack {
            // Dark background matching Epilogue theme
            Color.black
                .ignoresSafeArea()
            
            if filteredNotes.isEmpty {
                emptyStateView
            } else {
                scrollContent
            }
        }
        .sheet(item: $editingNote) { note in
            InlineEditSheet(note: note)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .topTrailing) {
            if let note = contextMenuNote {
                NoteContextMenu(
                    note: note,
                    sourceRect: contextMenuSourceRect,
                    isPresented: $showingContextMenu
                )
                .environmentObject(notesViewModel)
                .onChange(of: showingContextMenu) { _, isShowing in
                    if !isShowing {
                        contextMenuNote = nil
                    }
                }
            }
        }
        .onAppear {
            loadPersistedState()
            Task {
                await processNotes()
            }
        }
        .onChange(of: filteredNotes) { _ in
            Task {
                await processNotes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Handle orientation change
            maintainExpandState()
        }
    }
    
    // MARK: - Main Scroll Content
    @ViewBuilder
    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(sections) { section in
                        IntelligentSectionView(
                            section: section,
                            isExpanded: Binding(
                                get: { expandedSectionIds.contains(section.id) },
                                set: { newValue in
                                    if newValue {
                                        expandedSectionIds.insert(section.id)
                                    } else {
                                        expandedSectionIds.remove(section.id)
                                    }
                                    savePersistedState()
                                }
                            ),
                            onNoteTap: { note in
                                handleNoteTap(note)
                            },
                            onLongPress: { note, rect in
                                handleLongPress(note, rect: rect)
                            },
                            onDoubleTap: { note in
                                handleDoubleTap(note)
                            },
                            onDelete: { note in
                                deleteNoteWithUndo(note)
                            },
                            onSwipe: { note, direction in
                                handleSwipe(note, direction: direction)
                            }
                        )
                        .id(section.id)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        sectionLayouts[section.id] = geometry.frame(in: .global)
                                        updateVisibleSections(geometry.frame(in: .global))
                                    }
                                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                                        sectionLayouts[section.id] = newFrame
                                        updateVisibleSections(newFrame)
                                    }
                            }
                        )
                        .opacity(visibleSections.contains(section.id) ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.3), value: visibleSections.contains(section.id))
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollToNoteId) { noteId in
                if let noteId = noteId,
                   let sectionId = sections.first(where: { $0.notes.contains { $0.id == noteId } })?.id {
                    withAnimation {
                        proxy.scrollTo(sectionId, anchor: .center)
                        expandedSectionIds.insert(sectionId)
                    }
                }
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    handlePinchGesture(value)
                }
        )
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(searchText.isEmpty ? "No notes yet" : "No notes found")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            
            if !searchText.isEmpty {
                Text("Try adjusting your search")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
    
    // MARK: - Actions
    private func toggleSection(_ sectionId: UUID, proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .linear(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.85)) {
            if expandedSectionIds.contains(sectionId) {
                expandedSectionIds.remove(sectionId)
                HapticManager.shared.lightTap()
            } else {
                expandedSectionIds.insert(sectionId)
                HapticManager.shared.lightTap()
                proxy.scrollTo(sectionId, anchor: .top)
            }
        }
        savePersistedState()
    }
    
    private func handleNoteTap(_ note: Note) {
        activeCardId = note.id
        HapticManager.shared.mediumTap()
        
        // Highlight for navigation
        if navigationCoordinator.highlightedNoteID == note.id {
            navigationCoordinator.highlightedNoteID = nil
        } else {
            navigationCoordinator.highlightedNoteID = note.id
        }
    }
    
    private func handleLongPress(_ note: Note, rect: CGRect) {
        contextMenuNote = note
        contextMenuSourceRect = rect
        showingContextMenu = true
        HapticManager.shared.mediumTap()
    }
    
    private func handleDoubleTap(_ note: Note) {
        editingNote = note
        HapticManager.shared.lightTap()
    }
    
    private func handleSwipe(_ note: Note, direction: SwipeDirection) {
        switch direction {
        case .left:
            deleteNoteWithUndo(note)
        case .right:
            shareNote(note)
        default:
            break
        }
    }
    
    private func deleteNoteWithUndo(_ note: Note) {
        deletedNotes.append(note)
        deleteNote(note)
        
        // Show undo option
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let lastDeleted = deletedNotes.last {
                // Show undo toast
                HapticManager.shared.success()
            }
        }
    }
    
    private func deleteNote(_ note: Note) {
        // Find and delete the corresponding SwiftData model
        if note.type == .quote {
            if let quote = quotes.first(where: { $0.id == note.id }) {
                modelContext.delete(quote)
            }
        } else if let capturedNote = notes.first(where: { $0.id == note.id }) {
            modelContext.delete(capturedNote)
        } else if let question = questions.first(where: { $0.id == note.id }) {
            modelContext.delete(question)
        }
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
            // Sync status update if needed
        } catch {
            print("Failed to delete note: \(error)")
            HapticManager.shared.error()
        }
    }
    
    private func shareNote(_ note: Note) {
        if note.type == .quote {
            ShareQuoteService.shareFormattedQuote(
                text: note.content,
                author: note.author,
                bookTitle: note.bookTitle
            )
        } else {
            ShareQuoteService.shareFormattedQuote(text: note.content)
        }
        HapticManager.shared.success()
    }
    
    private func handlePinchGesture(_ value: CGFloat) {
        if value > 1.2 {
            // Expand all sections
            expandedSectionIds = Set(sections.map { $0.id })
            HapticManager.shared.lightTap()
        } else if value < 0.8 {
            // Collapse all sections
            expandedSectionIds.removeAll()
            HapticManager.shared.lightTap()
        }
    }
    
    private func shuffleSections() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            // Shuffle logic here
            HapticManager.shared.mediumTap()
        }
    }
    
    private func updateVisibleSections(_ frame: CGRect) {
        let screenHeight = UIScreen.main.bounds.height
        let threshold = screenHeight * 1.5
        
        for (sectionId, sectionFrame) in sectionLayouts {
            if abs(sectionFrame.midY - frame.midY) < threshold {
                visibleSections.insert(sectionId)
            } else {
                visibleSections.remove(sectionId)
            }
        }
    }
    
    // MARK: - Processing
    private func processNotes() async {
        await intelligenceEngine.processNotes(
            filteredNotes,
            quotes: filteredNotes.filter { $0.type == .quote },
            questions: questions
        )
    }
    
    // MARK: - Persistence
    private func loadPersistedState() {
        if !persistedExpandedSections.isEmpty {
            let ids = persistedExpandedSections.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
            expandedSectionIds = Set(ids)
        }
    }
    
    private func savePersistedState() {
        persistedExpandedSections = expandedSectionIds.map { $0.uuidString }.joined(separator: ",")
    }
    
    private func maintainExpandState() {
        // Maintain expand state through orientation changes
        let currentExpanded = expandedSectionIds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expandedSectionIds = currentExpanded
        }
    }
    
    // MARK: - Search Helpers
    private func parseSearchTokens(_ text: String) -> [String] {
        text.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
    }
}

// MARK: - Old NotificationStackSection removed - using StackedSectionView instead
/*
struct NotificationStackSection: View {
    let section: SmartSection
    let isExpanded: Bool
    let cardSpacing: CGFloat
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onNoteTap: (Note) -> Void
    let onLongPress: (Note, CGRect) -> Void
    let onDoubleTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onSwipe: (Note, SwipeDirection) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var sectionSummaryVisible = false
    @State private var cardPool: [UUID: NotificationCard] = [:]
    
    private let maxVisibleCards = 5
    
    private var visibleNotes: [Note] {
        if isExpanded {
            return Array(section.notes.prefix(maxVisibleCards))
        } else {
            return Array(section.notes.prefix(4))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header with AI Summary
            sectionHeader
            
            // Connection lines for related notes
            if isExpanded && section.notes.count > 1 {
                ConnectionLinesView(notes: visibleNotes)
                    .opacity(0.3)
            }
            
            // Card Stack
            if !section.notes.isEmpty {
                cardStack
            }
            
            // AI Insights (pull down to reveal)
            if sectionSummaryVisible {
                aiInsights
            }
        }
        .scaleEffect(breathingScale)
        .onAppear {
            if isExpanded {
                startBreathingAnimation()
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                startBreathingAnimation()
            } else {
                stopBreathingAnimation()
            }
        }
    }
    
    @ViewBuilder
    private var sectionHeader: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Title with semantic grouping
                    Text(section.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(section.color)
                    
                    Text("(\(section.notes.count))")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                    
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(reduceMotion ? 0 : (isExpanded ? 180 : 0)))
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Section \(section.title) with \(section.notes.count) notes, \(isExpanded ? "expanded" : "collapsed"). Tap to \(isExpanded ? "collapse" : "expand")")
        .onTapGesture(count: 2) {
            // Double tap for summary
            withAnimation {
                sectionSummaryVisible.toggle()
            }
        }
    }
    
    @ViewBuilder
    private var cardStack: some View {
        if isExpanded {
            // Expanded: Show all cards with proper spacing
            VStack(spacing: -cardSpacing + 20) {
                ForEach(Array(visibleNotes.enumerated()), id: \.element.id) { index, note in
                    NotificationCard(
                        note: note,
                        showFull: true,
                        isHighlighted: false,
                        onTap: { onNoteTap(note) },
                        onLongPress: { rect in onLongPress(note, rect) },
                        onDoubleTap: { onDoubleTap(note) },
                        onDelete: { onDelete(note) },
                        onSwipe: { direction in onSwipe(note, direction) }
                    )
                    .offset(y: CGFloat(index) * cardSpacing)
                    .zIndex(Double(100 - index))
                    .transition(
                        reduceMotion ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .glassAppear),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
                    .animation(
                        reduceMotion ? .linear(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.02),
                        value: isExpanded
                    )
                    .parallaxEffect(multiplier: 0.1 * CGFloat(index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, CGFloat(visibleNotes.count - 1) * cardSpacing + 20)
        } else {
            // Collapsed: Show stacked cards with peek
            ZStack(alignment: .top) {
                ForEach(Array(visibleNotes.enumerated().reversed()), id: \.element.id) { index, note in
                    if index == 0 {
                        // Top card - full content
                        NotificationCard(
                            note: note,
                            showFull: true,
                            isHighlighted: false,
                            onTap: onToggle,
                            onLongPress: { rect in onLongPress(note, rect) },
                            onDoubleTap: { onDoubleTap(note) },
                            onDelete: { onDelete(note) },
                            onSwipe: { direction in onSwipe(note, direction) }
                        )
                        .zIndex(100)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
                    } else {
                        // Background cards - just peek
                        NotificationCardPeek(
                            note: note,
                            offset: CGFloat(index) * 14,
                            scale: 1.0 - (CGFloat(index) * 0.03),
                            depth: CGFloat(index)
                        )
                        .zIndex(Double(10 - index))
                    }
                }
                
                // Show "+X more" indicator if there are more notes
                if section.notes.count > 4 {
                    moreNotesIndicator
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, CGFloat(min(3, section.notes.count - 1) * 14 + 16))
        }
    }
    
    @ViewBuilder
    private var aiInsights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Insights")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            
            Text("AI analysis of this section")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    @ViewBuilder
    private var moreNotesIndicator: some View {
        Text("+\(section.notes.count - 4) more")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
            .offset(y: 3 * 14 + 8)
            .zIndex(1)
    }
    
    // MARK: - Helpers
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathingScale = 1.01
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.linear(duration: 0.1)) {
            breathingScale = 1.0
        }
    }
}
*/

// MARK: - Old Enhanced Notification Card - moved to StackedSectionView
/*
struct NotificationCard: View {
    let note: Note
    let showFull: Bool
    let isHighlighted: Bool
    let onTap: () -> Void
    let onLongPress: (CGRect) -> Void
    let onDoubleTap: () -> Void
    let onDelete: () -> Void
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isPressed = false
    @GestureState private var longPressLocation: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    Text(note.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Content
                Text(note.content)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(showFull ? nil : 3)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // Author if available
                if let author = note.author {
                    HStack {
                        Text(author)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Spacer()
                        
                        if note.type == .quote {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isHighlighted ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1),
                                lineWidth: isHighlighted ? 2 : 0.5
                            )
                    )
            )
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .offset(x: dragOffset.width)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isPressed)
            .onTapGesture {
                HapticManager.shared.mediumTap()
                onTap()
            }
            .onTapGesture(count: 2) {
                HapticManager.shared.lightTap()
                onDoubleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                HapticManager.shared.mediumTap()
                onLongPress(geometry.frame(in: .global))
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 100 {
                            onSwipe(value.translation.width > 0 ? .right : .left)
                            HapticManager.shared.success()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
            )
        }
        .frame(height: showFull ? nil : 100)
    }
}
*/

/*
// MARK: - Old Enhanced Notification Card Peek - moved to StackedSectionView
struct NotificationCardPeek: View {
    let note: Note
    let offset: CGFloat
    let scale: CGFloat
    let depth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Just show a hint of content
            HStack {
                if let bookTitle = note.bookTitle {
                    Text(bookTitle.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8 - depth * 0.1))
                        .tracking(0.5)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            Text(note.content)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7 - depth * 0.1))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.8 - depth * 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08 - depth * 0.02), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 4 + depth * 2, x: 0, y: 2 + depth)
        )
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .offset(y: offset)
        .scaleEffect(scale)
    }
}
*/

// MARK: - Connection Lines View (still used)
struct ConnectionLinesView: View {
    let notes: [Note]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Draw connection lines between related notes
                for i in 0..<notes.count - 1 {
                    let startY = CGFloat(i) * 85 + 40
                    let endY = CGFloat(i + 1) * 85 + 40
                    
                    path.move(to: CGPoint(x: 40, y: startY))
                    path.addCurve(
                        to: CGPoint(x: 40, y: endY),
                        control1: CGPoint(x: 60, y: startY + 20),
                        control2: CGPoint(x: 60, y: endY - 20)
                    )
                }
            }
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: 1, dash: [5, 3])
            )
        }
        .frame(height: CGFloat(notes.count) * 85)
    }
}

// MARK: - Swipe Direction
enum SwipeDirection {
    case left, right, up, down
}

// MARK: - Filter Type
enum FilterType: String, CaseIterable {
    case all = "All"
    case quotes = "Quotes"
    case notes = "Notes"
    case questions = "Questions"
}

// MARK: - Search Scope (Using NotesView.SearchScope)
// SearchScope is defined in NotesView.swift

// MARK: - Preview
#Preview {
    StackedNotesView(
        searchText: .constant(""),
        searchScope: .constant(NotesView.SearchScope.all),
        selectedFilter: .constant(nil)
    )
    .environmentObject(NotesViewModel())
    .environmentObject(NavigationCoordinator.shared)
    .preferredColorScheme(.dark)
}