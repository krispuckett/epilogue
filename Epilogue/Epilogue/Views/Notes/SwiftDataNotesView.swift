import SwiftUI
import SwiftData

// MARK: - SwiftData Notes View

struct SwiftDataNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    // Queries
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var notes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var quotes: [CapturedQuote]
    @Query(sort: \CapturedQuestion.timestamp, order: .reverse) private var questions: [CapturedQuestion]
    
    @State private var searchText = ""
    @State private var openOptionsNoteId: UUID? = nil
    @State private var contextMenuNote: Note? = nil
    @State private var contextMenuSourceRect: CGRect = .zero
    @State private var editingNote: Note? = nil
    @State private var isInitialLoad = true
    
    // Batch selection
    @StateObject private var selectionManager = BatchSelectionManager()
    
    // Deleted notes for undo
    @State private var deletedNotes: [UUID: (note: Any, type: String)] = [:]
    
    // Computed properties for filtered content
    private var allNotes: [Note] {
        var items: [Note] = []
        
        // Convert all SwiftData models to Note type
        items += notes.map { $0.toNote() }
        items += quotes.map { $0.toNote() }
        
        // Debug logging removed to prevent state modification during view update
        // Use onAppear or onChange for logging if needed
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { note in
                note.content.localizedCaseInsensitiveContains(searchText) ||
                (note.bookTitle?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.author?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return items.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    // Delete note from SwiftData with undo support
    private func deleteNote(_ note: Note) {
        // Store for undo
        if let capturedNote = notes.first(where: { $0.id == note.id }) {
            deletedNotes[note.id] = (capturedNote, "note")
            modelContext.delete(capturedNote)
        } else if let capturedQuote = quotes.first(where: { $0.id == note.id }) {
            deletedNotes[note.id] = (capturedQuote, "quote")
            modelContext.delete(capturedQuote)
        }
        
        // Save the context
        do {
            try modelContext.save()
            SyncStatusManager.shared.incrementPendingChanges()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    // Delete question from SwiftData  
    private func deleteQuestion(_ question: CapturedQuestion) {
        modelContext.delete(question)
        
        // Save the context
        do {
            try modelContext.save()
            SyncStatusManager.shared.incrementPendingChanges()
            SensoryFeedback.light()
        } catch {
            print("Error deleting question: \(error)")
        }
    }
    
    // Restore deleted note
    private func restoreNote(_ noteId: UUID) {
        guard let (deletedItem, type) = deletedNotes[noteId] else { return }
        
        if type == "note", let capturedNote = deletedItem as? CapturedNote {
            modelContext.insert(capturedNote)
        } else if type == "quote", let capturedQuote = deletedItem as? CapturedQuote {
            modelContext.insert(capturedQuote)
        }
        
        deletedNotes.removeValue(forKey: noteId)
        
        do {
            try modelContext.save()
            SyncStatusManager.shared.incrementPendingChanges()
        } catch {
            print("Error restoring note: \(error)")
        }
    }
    
    // Batch delete selected notes
    private func batchDeleteNotes(_ noteIds: Set<UUID>) {
        let notesToDelete = allNotes.filter { noteIds.contains($0.id) }
        
        for note in notesToDelete {
            deleteNote(note)
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        StandardizedSearchField(
            text: $searchText,
            placeholder: "Search notes and quotes"
        )
    }
    
    private var notesContent: some View {
        VStack(spacing: 0) {
            
            if allNotes.isEmpty && questions.isEmpty {
                if isInitialLoad {
                    // Show skeleton only during initial load
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            NoteCardSkeleton()
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                    .onAppear {
                        // Set initial load to false after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation {
                                isInitialLoad = false
                            }
                        }
                    }
                } else {
                    // Keep search empty for query results; general empty is overlaid to center in view
                    if !searchText.isEmpty {
                        EmptyStateView.noSearchResults
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                }
            } else {
                // Content is available, show the list
                LazyVStack(spacing: 16) {
                    ForEach(allNotes) { note in
                        SelectableNoteCard(
                            note: note,
                            selectionManager: selectionManager,
                            content: AnyView(noteCardView(for: note)),
                            onTap: {
                                // Handle note tap
                            }
                        )
                        .id(note.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.smooth) {
                                    deleteNote(note)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                if note.type == .quote {
                                    ShareQuoteService.shareQuote(note)
                                } else {
                                    let activityController = UIActivityViewController(
                                        activityItems: [note.content],
                                        applicationActivities: nil
                                    )
                                    
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootViewController = windowScene.windows.first?.rootViewController {
                                        rootViewController.present(activityController, animated: true)
                                    }
                                }
                                SensoryFeedback.success()
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Color(red: 0.2, green: 0.6, blue: 1.0))
                            
                            Button {
                                editingNote = note
                                SensoryFeedback.light()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(DesignSystem.Colors.primaryAccent)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                    
                    ForEach(questions) { question in
                        CapturedQuestionCard(question: question)
                            .id(question.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation(.smooth) {
                                        deleteQuestion(question)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    // Reset initial load flag when content appears
                    if isInitialLoad {
                        DispatchQueue.main.async {
                            isInitialLoad = false
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 120) // Increased to account for tab bar + quick actions
    }
    
    @ViewBuilder
    private func noteCardView(for note: Note) -> some View {
        NoteCard(
            note: note,
            isSelectionMode: selectionManager.isSelectionMode,
            isSelected: selectionManager.isSelected(note.id),
            onSelectionToggle: { 
                selectionManager.toggleSelection(for: note.id)
            },
            openOptionsNoteId: $openOptionsNoteId,
            onContextMenuRequest: { note, rect in
                contextMenuNote = note
                contextMenuSourceRect = rect
            }
        )
        .environmentObject(notesViewModel)
        .id(note.id)
        .overlay(highlightOverlay(for: note))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }
    
    @ViewBuilder
    private func highlightOverlay(for note: Note) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
            .stroke(DesignSystem.Colors.primaryAccent, lineWidth: 1.5)
            .opacity(navigationCoordinator.highlightedNoteID == note.id ? 0.8 : 0)
            .blur(radius: 0.5)
            .animation(DesignSystem.Animation.easeStandard, value: navigationCoordinator.highlightedNoteID)
    }
    
    @ViewBuilder
    private var contextMenuOverlay: some View {
        if let contextMenuNote = contextMenuNote {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    self.contextMenuNote = nil
                }
            
            SwiftDataNoteContextMenu(
                note: contextMenuNote,
                sourceRect: contextMenuSourceRect,
                isPresented: Binding(
                    get: { self.contextMenuNote != nil },
                    set: { if !$0 { self.contextMenuNote = nil } }
                ),
                onDelete: {
                    deleteNote(contextMenuNote)
                    self.contextMenuNote = nil
                },
                onEdit: {
                    editingNote = contextMenuNote
                    self.contextMenuNote = nil
                }
            )
            .zIndex(1000)
        }
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    // Background
                    Color.black.ignoresSafeArea()
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            notesContent
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollIndicators(.visible)
                        .scrollContentBackground(.hidden)
                        .onChange(of: navigationCoordinator.highlightedNoteID) { _, noteID in
                            if let noteID = noteID {
                                withAnimation {
                                    proxy.scrollTo(noteID, anchor: .center)
                                }
                                // Clear after scrolling
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    navigationCoordinator.highlightedNoteID = nil
                                }
                            }
                        }
                        .onChange(of: navigationCoordinator.highlightedQuoteID) { _, quoteID in
                            if let quoteID = quoteID {
                                withAnimation {
                                    proxy.scrollTo(quoteID, anchor: .center)
                                }
                                // Clear after scrolling
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    navigationCoordinator.highlightedQuoteID = nil
                                }
                            }
                        }
                    }
                    
                    contextMenuOverlay
                    
                    // Undo snackbar overlay
                    UndoSnackbar()
                    
                    // Centered empty state overlay
                    if allNotes.isEmpty && questions.isEmpty && !isInitialLoad && searchText.isEmpty {
                        ModernEmptyStates.noNotes
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    }
                }
            .navigationTitle(selectionManager.isSelectionMode ? "" : "Notes")
            .navigationBarTitleDisplayMode(selectionManager.isSelectionMode ? .inline : .large)
            .searchable(text: $searchText, prompt: "Search notes and quotes")
            .toolbar {
                if selectionManager.isSelectionMode {
                    // Replace entire toolbar with selection navigation bar
                    ToolbarItem(placement: .principal) {
                        BatchSelectionNavigationBar(
                            selectionManager: selectionManager,
                            allItems: allNotes,
                            onDelete: batchDeleteNotes
                        )
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // Selection mode button
                        Button {
                            selectionManager.enterSelectionMode()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .sheet(item: $editingNote) { note in
                NoteEditSheet(note: note)
                    .environmentObject(notesViewModel)
            }
            .overlay {
                if selectionManager.showingDeleteConfirmation {
                    ZStack {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(DesignSystem.Animation.springStandard) {
                                    selectionManager.showingDeleteConfirmation = false
                                }
                            }
                        
                        // Toast
                        BatchDeleteConfirmationToast(
                            selectionManager: selectionManager,
                            onConfirm: {
                                let selectedItems = selectionManager.selectedItems
                                batchDeleteNotes(selectedItems)
                                selectionManager.performDelete()
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    }
                    .zIndex(1000)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EditNote"))) { notification in
                if let note = notification.object as? Note {
                    editingNote = note
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NoteUpdated"))) { notification in
                if let updatedNote = notification.object as? Note {
                    // Force refresh by triggering SwiftUI update
                    Task {
                        // This will cause the view to re-query from NotesViewModel
                        await MainActor.run {
                            // Trigger a view update
                            _ = notesViewModel.notes
                        }
                    }
                }
            }
            } // End NavigationStack
            
            // Batch selection now handled in navigation bar
        }
    }
}

// MARK: - SwiftData Note Context Menu
struct SwiftDataNoteContextMenu: View {
    let note: Note
    let sourceRect: CGRect
    @Binding var isPresented: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var containerOpacity: Double = 0
    @State private var containerScale: CGFloat = 0.8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backdrop
                popoverMenu(in: geometry)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                containerOpacity = 1
                containerScale = 1
            }
        }
    }
    
    private var backdrop: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .onTapGesture {
                dismissMenu()
            }
    }
    
    @ViewBuilder
    private func popoverMenu(in geometry: GeometryProxy) -> some View {
        menuContent()
            .frame(width: 200)
            .glassEffect(in: RoundedRectangle(cornerRadius: 24))
            .overlay(menuBorder)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .scaleEffect(containerScale)
            .opacity(containerOpacity)
            .position(calculatePosition(in: geometry))
    }
    
    private var menuBorder: some View {
        RoundedRectangle(cornerRadius: 24)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.textQuaternary,
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
    
    private func calculatePosition(in geometry: GeometryProxy) -> CGPoint {
        let menuHeight: CGFloat = note.type == .quote ? 220 : 180
        let menuWidth: CGFloat = 200
        let padding: CGFloat = 8
        
        var x = sourceRect.midX
        if x - menuWidth/2 < padding {
            x = menuWidth/2 + padding
        } else if x + menuWidth/2 > geometry.size.width - padding {
            x = geometry.size.width - menuWidth/2 - padding
        }
        
        var y = sourceRect.midY
        if y + menuHeight/2 > geometry.size.height - 100 {
            y = geometry.size.height - 100 - menuHeight/2
        }
        if y - menuHeight/2 < 100 {
            y = 100 + menuHeight/2
        }
        
        return CGPoint(x: x, y: y)
    }
    
    @ViewBuilder
    private func menuContent() -> some View {
        VStack(spacing: 0) {
            if note.type == .quote {
                shareButton
            }
            
            copyButton
            
            editButton
            
            deleteButton
        }
    }
    
    private var shareButton: some View {
        ContextMenuButton(
            icon: "square.and.arrow.up",
            title: "Share as Image",
            action: {
                shareAsImage()
                dismissMenu()
            }
        )
    }
    
    private var copyButton: some View {
        ContextMenuButton(
            icon: "doc.on.doc",
            title: note.type == .quote ? "Copy Quote" : "Copy Note",
            action: {
                copyText()
                dismissMenu()
            }
        )
    }
    
    private var editButton: some View {
        ContextMenuButton(
            icon: "pencil",
            title: "Edit",
            action: {
                dismissMenu()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onEdit()
                }
            }
        )
    }
    
    private var deleteButton: some View {
        ContextMenuButton(
            icon: "trash",
            title: "Delete",
            isDestructive: true,
            action: {
                dismissMenu()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    SensoryFeedback.warning()
                    onDelete()
                }
            }
        )
    }
    
    private func dismissMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            containerOpacity = 0
            containerScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
    
    private func shareAsImage() {
        SensoryFeedback.medium()
        let shareView = ShareableQuoteView(note: note)
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            let activityController = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                activityController.popoverPresentationController?.sourceView = rootViewController.view
                rootViewController.present(activityController, animated: true)
            }
        }
    }
    
    private func copyText() {
        SensoryFeedback.success()
        var textToCopy = note.content
        
        if note.type == .quote {
            if let author = note.author {
                textToCopy = "\"\(note.content)\"\n\n— \(author)"
                if let bookTitle = note.bookTitle {
                    textToCopy += ", \(bookTitle)"
                }
                if let pageNumber = note.pageNumber {
                    textToCopy += ", p. \(pageNumber)"
                }
            } else {
                textToCopy = "\"\(note.content)\""
            }
        }
        
        SecureClipboard.copyText(textToCopy)
    }
}

// MARK: - Context Menu Button (reusable)
private struct ContextMenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                
                Spacer()
            }
            .foregroundStyle(isDestructive ? Color.red : .white)
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Shareable Quote View
private struct ShareableQuoteView: View {
    let note: Note
    
    var body: some View {
        VStack(spacing: 20) {
            // Large quote mark
            Text("\u{201C}")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quote content
            Text(note.content)
                .font(.custom("Georgia", size: 28))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Attribution
            if let author = note.author {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 60, height: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(author.uppercased())
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .kerning(1.5)
                        
                        if let bookTitle = note.bookTitle {
                            Text(bookTitle)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .italic()
                        }
                        
                        if let pageNumber = note.pageNumber {
                            Text("Page \(pageNumber)")
                                .font(.system(size: 12, weight: .regular))
                                .opacity(0.8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(40)
        .frame(width: 600, height: 600)
        .background(Color(red: 0.98, green: 0.97, blue: 0.96))
    }
}

// MARK: - Captured Question Card

struct CapturedQuestionCard: View {
    let question: CapturedQuestion
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Question")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                Text(question.timestamp ?? Date(), style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            // Content
            Text(question.content ?? "")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            // Book context if available
            if let book = question.book {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text(book.title)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                    
                    if let pageNumber = question.pageNumber {
                        Text("• p.\(pageNumber)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            
            if question.isAnswered ?? false {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green.opacity(0.6))
                    Text("Answered")
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.6))
                }
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = question.content
                SensoryFeedback.light()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            if let book = question.book {
                Button {
                    // Navigate to book
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToBook"),
                        object: book
                    )
                } label: {
                    Label("View Book", systemImage: "book.closed")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Question",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                withAnimation(.smooth) {
                    modelContext.delete(question)
                    try? modelContext.save()
                    SensoryFeedback.light()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This question will be permanently deleted.")
        }
    }
}
